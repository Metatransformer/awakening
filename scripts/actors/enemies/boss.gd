class_name Boss
extends Enemy
## The executor for `BossDb`. A loop over a table, not four fights.
##
## Read `scripts/actors/enemies/boss_db.gd`'s header before you change anything
## here -- it holds THE CONTRACT FOR THE EXECUTOR, and every rule below is a
## direct implementation of one of its numbered clauses. Where this file
## deviates it says so out loud.
##
## **It is an `Enemy`, and it reuses `Enemy`'s state machine.** Twelve beats and
## five shapes needed no second FSM: `State.WINDUP` is the tell, `State.STRIKE`
## is the commit, `State.RECOVER` carries the recovery tail AND the guaranteed
## punish window, and `State.CHASE` is the only window in a beat where the thing
## is allowed to walk. That mapping is worth more than a bespoke machine would
## be, because the pieces around it -- the glow guard in `_physics_process`, the
## gravity, `move_and_slide`, `rotation.y = _facing` -- keep working unchanged.
## The parts that are genuinely different are overridden and named:
##
##   `_resolve_def`   stats come from `BossDb`, not `Enemy.DEFS`
##   `_build_combat`  health is ABSOLUTE (contract §2) and there is no hitbox
##   `_style_model`   the authored tint, applied BEFORE `HitFlash.bind`
##   `_on_damaged`    poise: a blow does not interrupt a beat (see below)
##   `freeze`         the chain does not stop it, for the same reason
##   `_drop_loot`     the authored drop, not a roll off `ItemDb`
##
## **Poise, and why it is not a difficulty knob.** `Enemy._on_damaged` throws the
## body into `HURT` and pushes the cooldown, which is right for a skeleton and
## fatal here: the promise this fight makes is that EVERY beat buys the player a
## window (contract §4), and a boss that can be knocked out of its own recovery
## has no beat left to be punished during. It also makes the tell a lie -- you
## read the wind-up, you hit first, and the attack you read never arrives. So a
## blow lands, flashes, shakes and rings, and changes no state at all.
##
## **What is greybox here and what is not.** The scale fit is MEASURED
## (`height / _model_height`) because a magic factor is a correctness bug waiting
## for a reimport; the 180 degrees goes on the MODEL node because `-basis.z is
## forward` is the contract everything else reads facing through (`CLAUDE.md`
## §4). The poses and the ground markers are crude on purpose: gross transforms
## on the model node and flat coloured primitives on the floor. The requirement
## is that a player can tell the three beats apart at 10 m and knows where the
## damage is going to be -- not that any of it is pretty.
##
## **Deviations from the contract, stated as required:**
##
##  1. The contract's §1c says to tint before `bind()` and notes that
##     `mi.get_active_material()` returns the override so "tinting first is
##     enough". Tinting the material `get_active_material` hands back FIRST would
##     mutate the GLB's SHARED material for the life of the process -- the same
##     trap `HitFlash`'s header describes. `_style_model` therefore duplicates
##     into per-surface overrides itself and tints those; `bind()` then sees the
##     tinted override exactly as the contract intends and records the right
##     baseline. Same ordering, no shared-resource mutation.
##  2. `force_beat()` exists for directors only. It does not re-implement the
##     choice rule (§6) -- `pick_beat` is still the only chooser in play.

## Fired the instant a tell begins, at commit, and around the punish window.
## `punish_closed` carries the window MEASURED in game seconds rather than the
## number the table authored, because the thing worth proving is the one the
## player stood in. See `_measured_punish`.
signal beat_started(beat_id: StringName)
signal beat_committed(beat_id: StringName)
signal punish_opened(beat_id: StringName, seconds: float)
signal punish_closed(beat_id: StringName, measured: float)

## Which row of `BossDb.BOSSES` this is.
@export var boss_id: StringName = &"cistern_warden"

# --- Poses -------------------------------------------------------------------
# `Enemy.WINDUP_LEAN_DEG` is 17 degrees, which is right for a 1.7 m skeleton
# across a dark room. `BossDb`'s pose table says a boss gets more, and these are
# the numbers: gross silhouette changes readable in a STILL FRAME. They are
# applied to the MODEL node and never to the body -- the body's yaw is the
# facing contract (`docs/CONTRACT.md` §2.5).
const REAR_DEG := 34.0
const REAR_LIFT := 0.10     ## fraction of height the body hauls up with the arm
const TILT_DEG := 30.0
const CROUCH_DROP := 0.30   ## fraction of height lost -- shorter than the hero
const RISE_STRETCH := 0.22  ## taller than it walks, which is the whole read
const RISE_LIFT := 0.12     ## fraction of height it comes up off the floor
const SPREAD_WIDE := 0.38   ## fraction wider across -- arms out

## How fast it turns while telegraphing. Slow, so sidestepping a committed swing
## actually works; not zero, so standing still is not free either.
const TELL_TRACK_DEG := 70.0
## Turning speed between beats, when it is allowed to walk.
const ROAM_TRACK_DEG := 200.0
## The commit whip, as a fraction of REAR_DEG, and how long it takes to settle.
const COMMIT_WHIP := 0.55
const COMMIT_SETTLE := 0.30
## How long a non-travelling commit stays in `STRIKE`. The damage is resolved on
## the first frame of it; this is the pose's own length, so "it is coming" and
## "it has happened" are two different pictures.
const COMMIT_TIME := 0.22
## Beat one cannot start on the frame the arena seals. A second of the thing
## turning to look at you is the fight's opening line.
const WAKE_DELAY := 1.0

## Where the boss tries to stand between beats, in metres. Inside the shortest
## `max_range` in the game (the Riven Knight's arc, 5.5 m) so that closing is a
## thing it does before a beat rather than during one.
const ROAM_RING := 3.8

## Ground markers. Flat, unshaded, and drawn in the beat's own authored colour.
const MARK_Y := 0.05
const MARK_SEGMENTS := 28

var _row: Dictionary = {}
var _beat: Dictionary = {}
## Cache for `_commitment`. Zero means "not asked yet".
var _top_sev: float = 0.0
var _last_id: StringName = &""
var _forced: StringName = &""
## The tell's own length, kept so `_tick_windup` can measure how far through it
## is. `_timer` counts DOWN and is reused by four states; this is the divisor.
var _tell_total: float = 0.0
## True for the second half of `RECOVER`. The recovery tail and the punish window
## are both "rooted, hitboxes shut, no new tell", so they are one state and this
## is which half of it we are in.
var _punishing: bool = false
var _measured_punish: float = 0.0

## The charge, mid-flight.
var _charging: bool = false
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_left: float = 0.0
var _charge_speed: float = 0.0
var _charge_hit: Array[int] = []

## Live zone discs: {node, at, radius, fuse, damage, knockback, stun}.
var _zones: Array[Dictionary] = []
var _summons: Array[Node3D] = []

## The model's fitted rest, recorded after `Enemy._build_model` has scaled it.
## The poses are measured from HERE and never from one/zero -- zeroing would undo
## the height fit and the art-space 180 in the same stroke.
var _fit_scale: Vector3 = Vector3.ONE
var _fit_pos: Vector3 = Vector3.ZERO

## Where the arena thinks the middle is, for scattering zone discs. Defaults to
## wherever it woke up, so a boss dropped into a test scene with no arena still
## behaves.
var _arena_center: Vector3 = Vector3.ZERO
## What the arena has told us the fence is now, or `-1.0` while the row still
## owns it. See `set_arena_radius` -- this exists so a `shrink` turn has somewhere
## to land that is NOT `_row["arena"]["radius"]`.
var _arena_radius: float = -1.0
var _marker: Node3D = null


func _ready() -> void:
	super()
	# `docs/CONTRACT.md` §5, and the targeting priority chain reads it: Boss
	# outranks Enemy in the lock-on category test.
	add_to_group(&"boss")
	if _model != null:
		_fit_scale = _model.scale
		_fit_pos = _model.position
	_arena_center = _anchor
	# Asleep until an arena wakes it. A boss that charged the moment the player
	# came through the door would have started its fight off screen.
	state = State.IDLE


# --- What the table says ------------------------------------------------------

## `BossDb`'s row, shaped as the `Enemy.DEFS` dictionary the base class reads.
##
## Health is copied ABSOLUTE and the damage is 0, both per contract §2: a boss is
## authored for exactly one floor and its numbers are already that floor's
## numbers, and every quarter-heart it deals comes from a beat rather than from a
## contact hitbox. `Prog` is not consulted anywhere in this file.
func _resolve_def() -> Dictionary:
	_row = BossDb.get_boss(boss_id)
	if _row.is_empty():
		# Empty rather than a fallback boss, exactly as `BossDb.get_boss` chose:
		# a floor asking for a boss that does not exist has a broken manifest and
		# quietly handing it the Warden would ship that bug into the Chord Gate.
		push_error("boss: no row in BossDb for %s" % boss_id)
		return Enemy.DEFS[&"skeleton"]
	# The model is named by the row, and `Enemy._build_model` builds the path out
	# of `kind`. Setting it here rather than in `_ready` is not a shortcut: this
	# function runs FIRST in `Enemy._ready`, before the model is built.
	kind = _row["model"]
	return {
		"health": int(_row["health"]),
		"damage": 0,
		"speed": 2.1,
		"height": float(_row["height"]),
		# It is already awake or it is asleep; the arena decides, never a radius.
		"detect": 99.0,
		"reach": 3.0,
		"windup": 0.5, "recover": 0.5, "cooldown": 1.0,
	}


func title() -> String:
	return String(_row.get("title", "A BOSS"))


func arena_radius() -> float:
	if _arena_radius > 0.0:
		return _arena_radius
	var arena: Dictionary = _row.get("arena", {})
	return float(arena.get("radius", 11.0))


## Told by the arena, so scattered zone discs land inside the ring the player can
## see rather than inside a circle drawn round wherever the boss happens to be.
func set_arena_center(at: Vector3) -> void:
	_arena_center = at


## Told by the arena when the turn WALKS THE FENCE IN -- `docs/BOSSES.md` §5's
## `shrink`, and its first implementation note is this setter's whole reason to
## exist.
##
## `_shape_zone` scatters its discs inside `arena_radius() - radius`, so a Warden
## whose seal has come in from 11.0 m to 8.5 m would otherwise keep drowning the
## floor of the room it is no longer standing in: two and a half metres of pool
## on the far side of a wall the player cannot cross, and none of it a hazard he
## can be asked to answer.
##
## It is a SEPARATE field rather than a write into `_row["arena"]["radius"]` on
## purpose. `BossDb.get_boss` hands back the static Dictionary itself, not a copy,
## so editing the row would shrink the Warden's arena for every fight for the rest
## of the process -- including the next run's, which starts at 8.5 m with no turn
## having happened.
func set_arena_radius(r: float) -> void:
	_arena_radius = maxf(r, 1.0)


# --- Construction -------------------------------------------------------------

## Wider than `Enemy`'s, and that is the whole override. The base clamps the
## capsule radius at 0.55 m, which is correct for a 1.95 m orc and absurd on a
## 3.4 m body -- the Warden came out as a broomstick you could stand inside, and
## every melee beat resolved from a point rather than from a mass.
func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var h := _height()
	cap.radius = h * 0.20
	cap.height = maxf(h * 0.92, cap.radius * 2.0 + 0.05)
	col.shape = cap
	col.position = Vector3(0.0, cap.height * 0.5, 0.0)
	add_child(col)


## Health straight off the row, and NO contact hitbox.
##
## Contract §2: absolute, never through `Prog`. `Prog.health_mult` and
## `damage_bonus` exist to curve the generated roster against the floor it spawned
## on; a boss is authored for one floor, so putting the curve on top would make
## the arithmetic in the row's own comment a lie.
##
## The missing hitbox is deliberate too. Everything this thing does to you is an
## authored beat with a tell in front of it; a permanently-open claw would be a
## fourth attack with no wind-up, which is precisely the thing GDD pillar 3
## forbids. `Enemy._on_died` is guarded for a null `_hitbox`.
func _build_combat() -> void:
	health = HealthComponent.new()
	health.name = "Health"
	health.max_quarters = maxi(int(_row.get("health", 48)), 1)
	# The same monster i-frames `Enemy` takes, and for the same reason: the light
	# chain has to land all three of its steps on a boss too. What makes a boss
	# hard is the authored beats and forty-odd quarters of health, never a hidden
	# rule that quietly deletes two thirds of the player's damage.
	health.iframe_time = K.ENEMY_IFRAME_TIME
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


## A no-op, and the emptiness IS the override.
##
## `Enemy` re-runs the floor's curve every time `level` is written now (card #22),
## which is right for a generated body and would be a disaster here: contract §2
## authors a boss's health ABSOLUTE for the one floor it stands on, so a single
## stray `boss.level = 3` would otherwise rewrite the Bellwake's 96 quarters as
## `_row["health"] * Prog.health_mult(3)` and make the swing arithmetic in the
## row's own comment a lie. Nothing writes it today. This is what keeps that from
## being a thing anyone has to remember.
##
## Virtual dispatch is real for methods -- it is only STATIC calls that bind to
## the base class at parse time (CLAUDE.md §3), and the setter reaches this
## through `self`.
func _apply_level_curve() -> void:
	pass


## The authored tint, painted into per-surface OVERRIDES before `HitFlash.bind`.
##
## See deviation 1 in the header: the contract says tint before binding, and the
## reason is that `bind()` records whatever it finds as the baseline `restore()`
## returns to -- tint afterwards and the boss goes white on the player's first
## blow and stays a stock grey golem for the rest of the fight. What it does NOT
## want is what `mi.get_active_material()` hands you: that is the GLB's shared
## material, and writing to it tints every instance of the mesh in the process
## (`HitFlash`'s header is about exactly this). So the duplication happens here,
## and `bind()` duplicates the already-tinted override on top. Same order, same
## baseline, nothing shared is written.
func _style_model() -> void:
	var tint: Dictionary = _row.get("tint", {})
	if tint.is_empty() or _model == null:
		return
	var albedo: Color = tint["albedo"]
	var mix := float(tint["albedo_mix"])
	var emission: Color = tint["emission"]
	var energy := float(tint["energy"])
	for mi in Enemy._meshes(_model):
		for surface in mi.mesh.get_surface_count():
			var src := mi.get_active_material(surface) as BaseMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as BaseMaterial3D
			m.resource_local_to_scene = true
			m.albedo_color = m.albedo_color.lerp(albedo, mix)
			m.emission_enabled = true
			m.emission = emission
			m.emission_energy_multiplier = energy
			mi.set_surface_override_material(surface, m)


# --- Waking -------------------------------------------------------------------

func is_awake() -> bool:
	return state != State.IDLE and state != State.DEAD


## Start the fight. Called by `BossArena` when the room seals.
##
## `Bus.boss_engaged` is emitted HERE and nothing else about the music happens,
## per contract §8: `Music` already listens to this signal and owns the only
## `AudioStreamPlayer` a track may live in (`docs/CONTRACT.md` §8). A boss that
## started its own track would be a second soundtrack fighting the crossfade.
##
## # NEEDS: a `Music.prefer(path)` a boss can hand `BossDb`'s `music` field to
## before this emit. There are four boss tracks and four bosses and the pairing
## is authored, but `Music.POOLS[Mood.BOSS]` currently draws one at random, so
## the Warden can get the Riven Knight's cue. `Music` is orchestrator-owned.
func wake() -> void:
	if state != State.IDLE:
		return
	state = State.CHASE
	_cooldown = WAKE_DELAY
	Bus.boss_engaged.emit(self)


## Make the NEXT pick come out `beat_id`. For directors only -- a fight has to
## photograph each of its three tells, and `pick_beat` is weighted-random by
## design so no amount of positioning can guarantee one. It deliberately does not
## touch the weights, the repeat penalty or the range gate: `pick_beat` is still
## the only implementation of the choice rule in play (contract §6).
func force_beat(beat_id: StringName) -> void:
	_forced = beat_id


func current_beat() -> StringName:
	return _beat.get("id", &"")


## True while the fight is holding its promise open. Rooted, hitboxes shut, no
## new tell -- the window every beat buys, without exception (contract §4).
func is_punishable() -> bool:
	return state == State.RECOVER and _punishing


# --- The beat -----------------------------------------------------------------

func _tick_idle() -> void:
	_stop()
	_play(&"idle", true)


## Everything between the end of one beat's punish and the start of the next
## tell. The ONE window a beat gives the boss to move (contract §4), and
## `_cooldown` -- decremented by `Enemy._physics_process` -- is what measures it.
## A beat whose `cooldown` equals its `punish` therefore spends no time here at
## all, which is what "pure openings with no repositioning" means in the table.
func _tick_chase(delta: float) -> void:
	if _player == null:
		_stop()
		_play(&"idle", true)
		return
	_face_player(delta, ROAM_TRACK_DEG)
	var dist := _distance()
	if dist > ROAM_RING:
		_steer(K.flat(_to_player()), float(_def["speed"]))
		_play(&"walk_fwd", true, 0.9)
	else:
		_steer(Vector3.ZERO, 0.0)
		_play(&"idle", true)
	if _cooldown <= 0.0:
		_begin_beat()


## Pick, then hold still and telegraph. Contract §4's TELL, and nothing is
## damaging during it.
func _begin_beat() -> void:
	var id := _choose()
	if id == &"":
		return
	_beat = BossDb.beat(boss_id, id)
	if _beat.is_empty():
		return
	_last_id = id
	state = State.WINDUP
	_tell_total = maxf(float(_beat["tell"]["time"]), 0.001)
	_timer = _tell_total
	_kill_recoil()
	_show_tell_marker()
	_play(&"attack_1")
	# Once, on the first frame. Sfx owns which sound (docs/CONTRACT.md §8).
	Bus.request_sfx.emit(_beat["tell"]["sfx"], global_position)
	beat_started.emit(id)


## `BossDb.pick_beat`, plus the one thing `pick_beat` cannot see.
##
## Contract §6 and §5: the choice rule lives in the table and is not re-derived
## here. The only judgement this function makes is the summon cap, which is world
## state rather than design -- when `cap` of a beat's summons are already alive
## the pick is thrown away and re-rolled with `last_id` set to the refused beat,
## so `REPEAT_WEIGHT` makes the second roll something else with near-certainty.
func _choose() -> StringName:
	if _forced != &"":
		var forced := _forced
		_forced = &""
		return forced
	var dist := 0.0 if _player == null else _distance()
	var refused := _last_id
	for _attempt in 3:
		var id := BossDb.pick_beat(boss_id, _rng, refused, dist)
		if id == &"":
			return &""
		var b := BossDb.beat(boss_id, id)
		if b["shape"] == BossDb.SHAPE_SUMMON and _summons_alive() >= int(b["cap"]):
			refused = id
			continue
		return id
	# Three refusals in a row means every eligible beat is a capped summon.
	# Throwing the turn away would be a boss standing still, which contract §6
	# rules out explicitly, so it takes the beat and `_shape_summon` clamps the
	# count to whatever room is left (usually none). The tell and the punish
	# still happen: the player gets a free window out of it, which is the right
	# way for a boss to be over-committed.
	return refused


func _tick_windup(delta: float) -> void:
	_stop()
	_timer -= delta
	_face_player(delta, TELL_TRACK_DEG)

	var tell: Dictionary = _beat["tell"]
	# 0 at the start of the commit, 1 at the moment it lands.
	var t := clampf(1.0 - _timer / _tell_total, 0.0, 1.0)
	# Eased for the POSE only. A linear rear-back reads as a slow lean and the
	# player needs the spike; the glow stays linear because contract §4 writes it
	# as `t * tell.energy` and because a light that ramps evenly is a clock.
	_hold_pose(tell["pose"], t * t)
	# Driven every frame off this timer, never tweened: a tween here survives its
	# own interruption and leaves the body lit (`Enemy._tick_windup` says the same
	# at length, and the guard at the top of `Enemy._physics_process` is what
	# takes it down again when the state changes).
	_flash.glow(tell["color"], t * float(tell["energy"]))
	_glowing = true
	_grow_marker(t)

	if _timer <= 0.0:
		_commit()


## The instant the tell expires. Contract §4's COMMIT, in its order.
func _commit() -> void:
	_glowing = false
	_flash.restore()
	_clear_marker()
	_pose_reset()
	state = State.STRIKE
	_timer = _commit_seconds(_beat)
	Bus.request_sfx.emit(_beat["sfx"], global_position)
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)
	_commit_pose()
	_deliver_shape(_beat)
	beat_committed.emit(_beat["id"])


## How long the body stays in the commit. Instant for everything the boss
## resolves once; the charge's own travel time for the one that moves.
func _commit_seconds(b: Dictionary) -> float:
	if b["shape"] == BossDb.SHAPE_CHARGE:
		return float(b["reach"]) / maxf(float(b["speed"]), 0.1) + 0.05
	return COMMIT_TIME


func _tick_strike(delta: float) -> void:
	_timer -= delta
	if _charging:
		_advance_charge(delta)
	else:
		_stop()
	if _timer <= 0.0:
		_end_charge()
		state = State.RECOVER
		_timer = float(_beat["recover"])
		_punishing = false


## RECOVER and PUNISH, in that order, in one state: both are "rooted, hitboxes
## shut, no new tell", and the only thing that separates them is which promise is
## being kept.
##
## `_cooldown` is armed at the moment the punish OPENS, not at the moment it
## closes, because contract §4 measures both from the same instant and asserts
## `cooldown >= punish`. So the leftover after the window is exactly
## `cooldown - punish` -- the reposition time -- and a beat with `cooldown ==
## punish` flows straight from the closing window into the next tell.
func _tick_recover(delta: float) -> void:
	_stop()
	_timer -= delta
	if not _punishing:
		if _timer <= 0.0:
			_punishing = true
			_measured_punish = 0.0
			_timer = float(_beat["punish"])
			_cooldown = float(_beat["cooldown"])
			punish_opened.emit(_beat["id"], float(_beat["punish"]))
		return
	# Measured rather than assumed. The window is the promise; a director that
	# checks the authored number has checked the table, not the fight.
	_measured_punish += delta
	if _timer <= 0.0:
		_punishing = false
		punish_closed.emit(_beat["id"], _measured_punish)
		state = State.CHASE


# --- The five shapes ----------------------------------------------------------
# Contract §5. Twelve beats, five shapes, each implemented exactly once. A beat
# carries only the keys its shape needs, so nothing below reads a key off a beat
# of another shape.

func _deliver_shape(b: Dictionary) -> void:
	match b["shape"]:
		BossDb.SHAPE_ARC:
			_shape_arc(b)
		BossDb.SHAPE_SLAM:
			_shape_slam(b)
		BossDb.SHAPE_CHARGE:
			_shape_charge(b)
		BossDb.SHAPE_ZONE:
			_shape_zone(b)
		BossDb.SHAPE_SUMMON:
			_shape_summon(b)


## A cone in front of the boss, `reach` long, `arc_deg` either side of `-basis.z`.
## Resolved ONCE, here, on the frame of the commit -- not an area left open for a
## while, which would hit anyone who walked into the space afterwards.
##
## `-basis.z` and not `+basis.z`: that is the facing contract every other system
## in the project reads an actor through (`docs/CONTRACT.md` §2.5). The art-space
## 180 lives on the model node, put there by `Enemy._build_model`.
func _shape_arc(b: Dictionary) -> void:
	var reach := float(b["reach"])
	var half := deg_to_rad(float(b["arc_deg"]))
	var fwd := K.flat(-global_transform.basis.z)
	# The same call `_show_tell_marker` made, so the flash after the blow and the
	# warning before it are one shape drawn twice and cannot drift apart.
	_flash_marker(_fan_marker(reach, half, b["tell"]["color"]))
	for body in _victims():
		var to := K.plane(body.global_position - global_position)
		var d := to.length()
		if d > reach or d < 0.001:
			continue
		if absf(to.normalized().signed_angle_to(fwd, Vector3.UP)) > half:
			continue
		_land(body, b)


## A ring centred on the boss: hurts between `safe_inner` and `radius`.
## `safe_inner == 0` is a solid disc.
##
## The donut is the Warden's whole teaching value and it is one comparison: the
## answer to the biggest, loudest attack in the fight is to walk TOWARD it.
func _shape_slam(b: Dictionary) -> void:
	var outer := float(b["radius"])
	var inner := float(b["safe_inner"])
	_flash_marker(_ring_marker(inner, outer, b["tell"]["color"]))
	for body in _victims():
		var d := K.plane(body.global_position - global_position).length()
		if d <= outer and d >= inner:
			_land(body, b)


## Lock the heading and go. Resolved per frame during `STRIKE`, once per body.
func _shape_charge(b: Dictionary) -> void:
	_charging = true
	_charge_dir = K.flat(-global_transform.basis.z)
	_charge_left = float(b["reach"])
	_charge_speed = float(b["speed"])
	_charge_hit.clear()


func _advance_charge(delta: float) -> void:
	if _charge_dir == Vector3.ZERO:
		_end_charge()
		return
	velocity.x = _charge_dir.x * _charge_speed
	velocity.z = _charge_dir.z * _charge_speed
	_charge_left -= _charge_speed * delta
	var radius := float(_beat["radius"])
	for body in _victims():
		var id := body.get_instance_id()
		if _charge_hit.has(id):
			continue
		if K.plane(body.global_position - global_position).length() > radius:
			continue
		_charge_hit.append(id)
		_land(body, _beat)
	# Stops on a wall, and ends the commit with it -- a boss that kept grinding
	# into masonry for the rest of its travel time would be spending the player's
	# punish window on a shove.
	if _charge_left <= 0.0 or is_on_wall():
		_timer = 0.0


func _end_charge() -> void:
	if not _charging:
		return
	_charging = false
	_charge_dir = Vector3.ZERO
	_stop()


## `count` discs marked on the floor at commit -- the first under the hero, the
## rest scattered inside the arena -- detonating `fuse` seconds later.
##
## **The boss is not placed in one and is not hurt by one either.** The first
## disc goes under the HERO and never under the boss, which is the placement half
## of `BossDb`'s executor contract §5; the damage half of that row used to say the
## boss "is not protected from them" and this file said so twice, and neither was
## ever true -- `_victims()` has only ever returned the player. The code is the
## side that was kept, and the contract now says what it does. Three reasons, in
## the order they decided it:
##
##  1. The boss cannot leave a disc that lands on it. It is ROOTED through the
##     whole of `RECOVER` and the punish window, which is most of a zone's fuse,
##     so a scattered disc landing on it is not a hazard it answers -- it is a
##     coin flip. A hazard the actor has no move against is not gameplay.
##  2. Contract §2: a boss's health is ABSOLUTE and authored for one floor. A
##     second damage source on that health nobody tuned makes the swing counts in
##     every row's comment arithmetic about a number that is no longer true.
##  3. It buys nothing. Measured against the scatter, a disc lands on the boss on
##     the order of once a fight for three quarters out of seventy-two -- so the
##     rule costs a random hitstop, a camera kick and a health bar that moves when
##     the player did nothing, and returns about two percent of a fight.
##
## If it is ever wanted, it is `_victims()` growing an `include_self` argument
## that only `_burst` passes -- and emphatically not the boss joining `_victims()`
## outright, which would put it inside its own `slam` at range zero on every
## beat that has one.
func _shape_zone(b: Dictionary) -> void:
	var radius := float(b["radius"])
	var count := maxi(int(b["count"]), 1)
	var ring := maxf(arena_radius() - radius, 1.0)
	for i in count:
		var at := _arena_center
		if i == 0 and _player != null:
			at = _player.global_position
		else:
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * ring
			at = _arena_center + Vector3(cos(a) * r, 0.0, sin(a) * r)
		at.y = global_position.y
		var mark := _ring_marker(0.0, radius, b["tell"]["color"])
		get_parent().add_child(mark)
		mark.global_position = at + Vector3(0.0, MARK_Y, 0.0)
		_zones.append({
			"node": mark, "at": at, "radius": radius,
			"fuse": float(b["fuse"]), "beat": b,
		})


## Burns every disc's fuse. Called from `_physics_process` BEFORE the base class,
## so a disc placed by a boss that has since died still bursts -- the pool was
## already on the floor and the player was already avoiding it.
func _tick_zones(delta: float) -> void:
	var i := _zones.size() - 1
	while i >= 0:
		var z: Dictionary = _zones[i]
		z["fuse"] = float(z["fuse"]) - delta
		var node := z["node"] as Node3D
		if float(z["fuse"]) <= 0.0:
			_burst(z)
			if is_instance_valid(node):
				node.queue_free()
			_zones.remove_at(i)
		elif is_instance_valid(node):
			# Grows to full over the fuse, so "about to" and "now" are two
			# pictures rather than one that blinks.
			var b: Dictionary = z["beat"]
			var t := clampf(1.0 - float(z["fuse"]) / maxf(float(b["fuse"]), 0.001),
				0.0, 1.0)
			node.scale = Vector3(0.55 + 0.45 * t, 1.0, 0.55 + 0.45 * t)
		i -= 1


func _burst(z: Dictionary) -> void:
	var b: Dictionary = z["beat"]
	var at: Vector3 = z["at"]
	var radius := float(z["radius"])
	Bus.request_sfx.emit(b["sfx"], at)
	for body in _victims():
		if K.plane(body.global_position - at).length() <= radius:
			_land(body, b, at)


## `count` ordinary `Enemy`s of `kind` at `radius`. Deals no damage.
##
## `kind` is always a key of `Enemy.DEFS` and `BossDb.validate()` enforces it,
## because `Enemy._ready` swaps an unknown kind for skeleton's STATS while
## keeping the requested MODEL -- a boss that summons a troll-shaped six-quarter
## skeleton is a fight nobody can tune.
##
## **The level is an ARGUMENT to `spawn` and not a write afterwards.** It used to
## be the write, one line below the call, under a comment claiming the adds were
## curved by the boss's band -- and they were not: `spawn` calls `add_child`,
## `add_child` runs `_ready`, and `_ready` had already latched health and damage
## off the `Prog.FIRST` default by the time the write landed. The Bellwake's
## choristers came out at 6 quarters instead of 9 and the Riven Knight's wraiths
## at 20 instead of 35, with a perfectly correct `level` sitting on both, on
## floors 3 and 4. Nothing on screen said so -- the bodies looked right and simply
## hit for less, which is the one place `docs/GDD.md` §7's "difficulty comes from
## depth" was quietly false. Card #22; `boss_cistern.gd` section O is the check.
func _shape_summon(b: Dictionary) -> void:
	var room := int(b["cap"]) - _summons_alive()
	var n := mini(int(b["count"]), maxi(room, 0))
	var radius := float(b["radius"])
	# The floor the BOSS is authored for, so an add is curved by the same `Prog`
	# band as the room it appeared in rather than by `Run.level` -- which is not
	# the same number the moment anything (a director, a vault) fights a boss on a
	# floor other than its own.
	var floor_n := int(_row.get("floor", 1))
	for i in n:
		var a := TAU * (float(i) + _rng.randf()) / float(maxi(n, 1))
		var at := global_position + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		var e := Enemy.spawn(get_parent() as Node3D, b["kind"], at, _rng.randi(),
			floor_n)
		_summons.append(e)


func _summons_alive() -> int:
	var alive := 0
	var i := _summons.size() - 1
	while i >= 0:
		var e := _summons[i]
		if not is_instance_valid(e):
			_summons.remove_at(i)
		elif (e as Enemy).state == State.DEAD:
			_summons.remove_at(i)
		else:
			alive += 1
		i -= 1
	return alive


# --- Landing a blow -----------------------------------------------------------

## Everything a beat can hurt: the player, and only the player.
##
## This docstring used to add "plus -- for a zone -- the boss itself, which
## contract §5 says is not protected from its own pools", and the function under
## it has never done that. The contract row was the side that moved
## (`boss_db.gd` §5's `zone` row, and `_shape_zone` above carries the argument):
## a rooted boss cannot answer a disc that lands on it, and its health is
## authored absolute with no second damage source in it.
##
## "Contract §5" throughout this file means `BossDb`'s EXECUTOR contract, the
## numbered header in `boss_db.gd` -- not `docs/CONTRACT.md` §5, which is the
## group list and says nothing about who a beat may hurt.
func _victims() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(&"player"):
		var body := n as Node3D
		if body != null and is_instance_valid(body):
			out.append(body)
	return out


## One blow, down the ONE damage path.
##
## `DamageArea._deliver` and not a hand-rolled `take_hit` / `HealthComponent`
## fork: `docs/CONTRACT.md` §8 says there is exactly one deliverer and two victim
## entry points, and re-deciding here which of the two applies would be the
## second damage path the contract exists to forbid. What this file owns is the
## GEOMETRY -- a cone, a donut, a lane, a disc -- none of which is a shape an
## `Area3D` has, which is why the query is resolved here rather than by opening a
## hitbox.
func _land(body: Node3D, b: Dictionary, from: Vector3 = Vector3.INF) -> void:
	var origin := global_position if from == Vector3.INF else from
	# **Mass and commitment, the two numbers that decide what the player's BODY
	# does about this** (card #130, `Hit.tier_odds`). Mass is the authored body
	# height in the same units the roster uses. Commitment is this beat's damage
	# over the biggest damage in this boss's own moveset -- so the heaviest
	# telegraphed beat is 1.0 and usually floors you, and the jab, at three
	# quarters of it, mostly does not. That fraction is the boss's OWN scale on
	# purpose: it is what lets a small boss's committed beat read as committed
	# without having to pretend to be the size of a large one.
	var hit := Hit.make(int(b["damage"]), origin, &"contact",
		float(b["knockback"]), float(b["stun"]), StringName(title()),
		_height() / K.LAUNCH_MASS_REF, _commitment(b))
	DamageArea._deliver(body, hit)


## How big `b` is on this boss's OWN scale, 0..1, which is the second half of
## what decides whether a beat floors the player (`Hit.tier_odds`).
##
## **Measured on `Hit.severity` and not on damage alone**, which is what it was
## first and what `tools/directors/hurt_table.gd` caught: `riven_knight` deals 6
## on both of its beats and `bellwake` deals 5 on both, so a damage-only ratio
## made every beat of those two bosses its own heaviest and both of them floored
## the player 85% of the time with everything they had -- including a light-shove
## pool. Knockback is the designer's own statement of how hard a beat hauls you
## about, and it is authored across the twelve beats where damage is not.
##
## **The range is 0.6 to 1.0, not 0 to 1.** A boss's lightest beat is still a
## boss hitting you, and `tier_odds` squares this before it is used -- a raw 0.3
## would come out at 0.09 and price a boss's jab under a goblin's.
##
## Cached: `_land` runs per victim per beat and the moveset cannot change inside
## a fight.
func _commitment(b: Dictionary) -> float:
	if _top_sev <= 0.0:
		for beat in BossDb.beats(boss_id):
			_top_sev = maxf(_top_sev, Hit.severity_of(
				int(beat["damage"]), float(beat["knockback"])))
		_top_sev = maxf(_top_sev, 0.01)
	var rel := Hit.severity_of(int(b["damage"]), float(b["knockback"])) / _top_sev
	return 0.6 + 0.4 * clampf(rel, 0.0, 1.0)


# --- Poses --------------------------------------------------------------------

## The five poses, each implemented once, on the MODEL node.
##
## `e` runs 0 at the start of the tell to 1 at the commit. Every pose starts by
## restoring the fitted rest -- the height fit and the art-space 180 both live in
## that transform, and a pose that wrote absolute values would delete them.
##
## These are transforms on the whole model and not bone poses, and that is not
## laziness: the nine monster GLBs ship near-empty clip sets (the goblin's is
## 0.03 s) and share one animation library that has no boss content in it, so
## there is nothing to key. A gross silhouette change is what reads at 10 m
## anyway, which is the bar `BossDb`'s pose table sets.
func _hold_pose(pose: StringName, e: float) -> void:
	if _model == null:
		return
	var h := _height()
	_model.rotation = _model_rest
	_model.scale = _fit_scale
	_model.position = _fit_pos
	match pose:
		BossDb.POSE_REAR:
			_model.rotation.x = _model_rest.x - deg_to_rad(REAR_DEG) * e
			_model.position.y = _fit_pos.y + h * REAR_LIFT * e
		BossDb.POSE_CROUCH:
			_model.scale.y = _fit_scale.y * (1.0 - CROUCH_DROP * e)
		BossDb.POSE_TILT:
			_model.rotation.z = _model_rest.z + deg_to_rad(TILT_DEG) * e
		BossDb.POSE_RISE:
			_model.scale.y = _fit_scale.y * (1.0 + RISE_STRETCH * e)
			_model.position.y = _fit_pos.y + h * RISE_LIFT * e
		BossDb.POSE_SPREAD:
			_model.scale.x = _fit_scale.x * (1.0 + SPREAD_WIDE * e)
			_model.scale.z = _fit_scale.z * (1.0 + SPREAD_WIDE * e)


func _pose_reset() -> void:
	if _model == null:
		return
	_model.rotation = _model_rest
	_model.scale = _fit_scale
	_model.position = _fit_pos


## The commit itself, made visible: the body whips through the blow and settles.
## `Enemy._lunge_pose` in a bigger size, and it reuses the same `_recoil` handle
## so a beat landing on top of a flinch cannot leave two tweens fighting over one
## rotation.
func _commit_pose() -> void:
	if _model == null:
		return
	_kill_recoil()
	_model.rotation.x = _model_rest.x + deg_to_rad(REAR_DEG * COMMIT_WHIP)
	_recoil = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_recoil.tween_property(_model, ^"rotation:x", _model_rest.x, COMMIT_SETTLE)


# --- Ground markers -----------------------------------------------------------
# The crudest thing that reads: flat, unshaded primitives on the floor in the
# beat's own authored colour. They exist to answer ONE question -- where is the
# damage going to be -- and they are drawn during the tell so that the answer
# arrives before the blow does. No shader, no particle, no material tuning.

func _show_tell_marker() -> void:
	_clear_marker()
	var b := _beat
	var col: Color = b["tell"]["color"]
	match b["shape"]:
		BossDb.SHAPE_SLAM:
			_marker = _ring_marker(float(b["safe_inner"]), float(b["radius"]), col)
		BossDb.SHAPE_ARC:
			_marker = _fan_marker(float(b["reach"]),
				deg_to_rad(float(b["arc_deg"])), col)
		BossDb.SHAPE_CHARGE:
			_marker = _lane_marker(float(b["reach"]), float(b["radius"]) * 2.0, col)
		_:
			# A zone draws its discs at COMMIT, where the table puts them, and a
			# summon has nothing to draw: the tell IS the pose.
			return
	# Parented to the BODY, so a marker for a beat aimed in front of the boss
	# turns with it while it tracks. A marker left in world space would promise
	# a lane the boss has since walked off.
	add_child(_marker)
	_marker.position = Vector3(0.0, MARK_Y, 0.0)
	_marker.scale = Vector3(0.001, 1.0, 0.001)


func _grow_marker(t: float) -> void:
	if _marker == null or not is_instance_valid(_marker):
		return
	var s := maxf(t, 0.001)
	_marker.scale = Vector3(s, 1.0, s)


func _clear_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


## Drop a marker in world space for a moment, so the frame after a commit still
## shows where the blow reached.
func _flash_marker(node: Node3D) -> void:
	get_parent().add_child(node)
	node.global_position = global_position + Vector3(0.0, MARK_Y, 0.0)
	node.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
	var tw := node.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(node.queue_free)


## An annulus between `inner` and `outer`, or a solid disc when `inner` is 0.
## Built from boxes on a circle rather than a torus, because a torus at these
## radii is a four-metre-thick tube standing in the arena rather than a mark on
## the floor.
func _ring_marker(inner: float, outer: float, col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Mark"
	var mat := _mark_mat(col)
	if inner <= 0.01:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = outer
		cyl.bottom_radius = outer
		cyl.height = 0.04
		mi.mesh = cyl
		mi.material_override = mat
		root.add_child(mi)
		return root
	var mid := (inner + outer) * 0.5
	var band := outer - inner
	# 1.35x the chord, for the reason locked_door.gd's `_arc` uses the same
	# figure: neighbouring boxes are rotated relative to each other and a chord
	# cut to its exact length leaves daylight at every joint.
	var chord := TAU * mid / float(MARK_SEGMENTS) * 1.35
	for i in MARK_SEGMENTS:
		var a := TAU * float(i) / float(MARK_SEGMENTS)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(chord, 0.04, band)
		mi.mesh = box
		mi.material_override = mat
		mi.position = Vector3(cos(a) * mid, 0.0, sin(a) * mid)
		# `-a - PI/2`, and the quarter turn is the whole point. The box is
		# authored WIDE across the chord and DEEP across the band, so its local X
		# has to end up tangential; a bare `-a` leaves X pointing radially
		# outward, which is what this line said first. The mark that came out was
		# a starfish -- twenty 4.1 m spokes laid across the circle -- and it drew
		# the danger as a thin 3.5-4.8 m hoop when the slam actually reaches from
		# 2.1 m to 6.2 m. A player standing at 5.5 m read clear floor and took
		# four quarters, which is the exact failure the marks exist to prevent.
		#
		# Godot's Y rotation puts local X at `(cos t, 0, -sin t)`, so tangential
		# `(-sin a, 0, cos a)` needs `t = -a - PI/2`. Render it and look; this is
		# not a thing to derive twice.
		mi.rotation.y = -a - PI * 0.5
		root.add_child(mi)
	return root


## The swept cone: a filled circular sector of radius `reach`, opening `half`
## radians either side of `-Z`. It is `_shape_arc`'s own damage test drawn as a
## picture -- same apex, same radius, same half-angle -- and not the smallest box
## that test fits inside.
##
## A box is what stood here, `reach * 2 * sin(half)` wide, and it was wrong at
## BOTH ends of the range (board card 21). At `slag_backhand`'s 95 degrees the
## `sin` clamped at 89.8 and the mark was an 8.4 m slab over 4.2 m of reach --
## while the damage was a 190 degree cone reaching round the boss's shoulders
## into ground the box never covered. At `gate_shard`'s 22 degrees the same line
## drew a 6.7 m wall for a 44 degree needle. The telegraph is a contract
## (`docs/GDD.md` §4.1): a mark that frightens the player off safe floor AND says
## nothing about lethal floor teaches him something false in both directions.
##
## FILLED, and not an outline or a fan of hairlines. The mark answers one
## question from a chase camera at speed -- is the ground I am standing on about
## to be hit -- and a shape that is geometrically right but invisible in motion is
## a worse warning than the wrong box was. `_ring_marker` fills for the same
## reason whenever there is no safe middle to leave open.
##
## The shape changed and the MATERIAL did not: no emission, no additive blend.
## `docs/STYLEGUIDE.md` §7.5 bans the first, and `CLAUDE.md` §3 records that the
## second is an opaque slab at every opacity over near-black.
##
## Safe under `_grow_marker`, which scales the root uniformly in X and Z: that
## scales the radius and leaves the angle alone, so a half-grown mark is an
## honest picture of the cone's WIDTH from the first frame of the tell and only
## its reach arrives late.
func _fan_marker(reach: float, half: float, col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Fan"
	# `PI` is the whole disc; nothing in the table is near it, but a row that went
	# past it would wrap the sector back over itself rather than widen it.
	var span := clampf(half, 0.01, PI)
	# One triangle per ~6 degrees of the SWEPT angle rather than a fixed count:
	# 32 across `slag_backhand`'s 190 degrees keeps the outer edge a curve, and 8
	# across `gate_shard`'s 44 is enough for a needle that would otherwise read as
	# a polygon.
	var segs := maxi(int(ceil(span * 2.0 / deg_to_rad(6.0))), 4)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in segs:
		var a0 := -span + 2.0 * span * float(i) / float(segs)
		var a1 := -span + 2.0 * span * float(i + 1) / float(segs)
		# Forward is `-basis.z` (`docs/CONTRACT.md` §2.5), so an offset of `a` off
		# the heading is `(0,0,-1)` turned about +Y: `(-sin a, 0, -cos a)`. This is
		# the direction `_shape_arc`'s `signed_angle_to` measures against, written
		# the other way round.
		verts.append(Vector3.ZERO)
		verts.append(Vector3(-sin(a0), 0.0, -cos(a0)) * reach)
		verts.append(Vector3(-sin(a1), 0.0, -cos(a1)) * reach)
		for _n in 3:
			norms.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := _mark_mat(col)
	# Double-sided. The sector is one sheet with no back to hide, and which way a
	# hand-wound triangle faces the camera is exactly the kind of thing CLAUDE.md
	# §4 says not to derive twice -- culling it the wrong way is an invisible
	# telegraph, which is the failure this whole function exists to end.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	root.add_child(mi)
	return root


## A flat box running `length` forward of the boss along `-Z`, `width` across.
## The CHARGE's shape, and only the charge's: a charge really does sweep a lane
## `radius` wide down its own heading. An `arc` draws `_fan_marker`.
func _lane_marker(length: float, width: float, col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Lane"
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.04, length)
	mi.mesh = box
	mi.material_override = _mark_mat(col)
	mi.position = Vector3(0.0, 0.0, -length * 0.5)
	root.add_child(mi)
	return root


## Unshaded, so the mark is the same brightness under a sconce and in the dark --
## a warning that dims where the room is dim is a warning you miss where you most
## need it.
func _mark_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# --- Damage, the chain, and death ---------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_zones(delta)
	super(delta)


## Poise. A blow lands, and the beat carries on.
##
## `Enemy._on_damaged` throws the body into `HURT`, pushes the cooldown and
## reels -- correct for a skeleton, and it would delete this fight. The window
## every beat promises (contract §4) only exists if the beat gets to finish, and
## a boss staggered out of its own recovery is a boss with nothing to punish. It
## would also make the telegraph a lie: read the tell, hit first, and the attack
## you read never arrives.
##
## Everything the player receives from a blow is still here, in the same order --
## the world stops, the body goes white, the camera kicks, it makes a noise -- so
## hitting it feels identical. Only the STATE is untouched.
func _on_damaged(hit: Hit) -> void:
	if state == State.DEAD:
		return
	# Scaled by the blow like every other body's (`Enemy._on_damaged`, and
	# `K.SHAKE_TAP` for the argument). This asked for 0.52 trauma on every hit
	# too, so chipping away at a boss with the light chain -- which is most of
	# what a boss fight IS -- held the camera at maximum trauma for the whole
	# fight and left the beats nothing to escalate to.
	#
	# The IMPACT scales; the STATE still does not. That is poise, and it is the
	# whole point of this override.
	var weight := blow_weight(hit.knockback)
	Bus.request_hitstop.emit(int(roundf(
		lerpf(float(K.HITSTOP_LIGHT), float(K.HITSTOP_HEAVY), weight))))
	Bus.request_shake.emit(lerpf(K.SHAKE_TAP, K.SHAKE_HIT, weight),
		lerpf(0.12, 0.2, weight))
	# The mark at the spot. A boss gets the scuff and never the star: the star is
	# the crit, the crit is the launch, and `_can_launch` refuses it one.
	ImpactVfx.spawn(get_tree().current_scene, _impact_point(hit.from), weight)
	# Cleared before the flash for the reason `Enemy._on_damaged` gives: the white
	# supersedes the wind-up glow, and a flag left set would have the guard in
	# `_physics_process` restore over it next frame. A tell in progress simply
	# writes its glow again on the following frame, which is right -- the blow
	# interrupted nothing.
	_glowing = false
	_flash.hit()
	Bus.hit_landed.emit(self, hit.amount, global_position)
	# THE RECEPTACLE, and it is the one thing that gets past poise from a weapon
	# (`docs/BOSSES.md` §6.2). Deliberately AFTER the impact block rather than
	# instead of it: the blow is still a blow -- the hitstop, the shake, the scuff
	# and `hit_landed` all happen exactly as they would for any other arrow -- and
	# what the branch adds is the state change on top. Routed through `stagger()`
	# and never by writing `state` here, so a receptacle hit and a parry are the
	# same transition and cannot drift apart.
	if _is_receptacle_hit(hit):
		stagger(hit.from, K.PARRY_STAGGER, 0.0)


## An arrow into a charge that is already crossing the floor.
##
## `docs/BOSSES.md` §6.2, exactly: **`State.STRIKE` with `_charging` true**, which
## is the travel and not the tell. The tell is the wrong window and the doc says
## why at length -- a tell that never lands makes the telegraph a lie, and
## `freeze` refuses the hookshot a tell-cut on that same argument (§6.4), so
## granting the bow one would be an exception with a name on it rather than a
## rule. Scoped to the travel it is the parry's own shape: the beat committed,
## the lane is real, and the player is answering something already in the air.
##
## **It is scoped by SHAPE, not by beat id, and that is worth saying out loud.**
## `_charging` is only ever true for a `SHAPE_CHARGE` commit, so this reads as
## "one beat" on floor 2 -- `bellows_charge` is the Slag Ogre's only charge -- and
## it equally answers the Riven Knight's `gate_lunge` and the Bellows-Hand's
## `plate_advance`. That is the rule §6.2 specifies and it is the honest one: a
## body committed to eleven metres of travel is the same receptacle whoever is
## wearing it, and a branch that named `bellows_charge` by id would be a
## per-boss special case for a shape the game implements once.
func _is_receptacle_hit(hit: Hit) -> bool:
	return state == State.STRIKE and _charging \
		and (hit.kind == Hit.ARROW or hit.kind == Hit.ARROW_FIRE)


## The chain does not stop it. Same reason as poise: a hookshot that could cut a
## tell short would let the player delete the beat they were supposed to read,
## and one that could cut a PUNISH short would take the window away from them.
## The barb rings off the plate and buys nothing.
func freeze(_seconds: float = K.HOOK_FREEZE) -> void:
	if state == State.DEAD:
		return
	Bus.request_sfx.emit(&"hit_armor", global_position)


## And neither does a blow throw it. Same argument as poise above, one step
## further: a beat the player can knock the boss out of is a beat they can
## delete, and the arena is authored around a body that stays in it. The corpse
## does not fly either -- `Enemy._on_died` launches every other kill, and a boss
## sliding into the scenery would take its placed relic with it (`_drop_loot`).
func _can_launch() -> bool:
	return false


## **The parry is the one thing that DOES move it, and that is deliberate.**
##
## Poise refuses the hookshot and refuses every blow, on the argument above: a
## beat the player can interrupt is a beat they can delete. A parry is the one
## input in the game that cannot delete a beat, because it can only be thrown
## AFTER the beat has committed — the blow is already in the air by the time
## `HeroCombat.parries` can be true. So this does not shorten a telegraph or skip
## a phase; it takes the swing the boss has already spent and turns it into a
## window, which is exactly what a parry is for and the only reason a player
## would ever risk one against something this big.
##
## What it does NOT do is throw the body. `_can_launch` is still false and this
## does not go near it: a boss that slid across its own arena would take its
## placed relic into the scenery, and the recovery is the reward here, not the
## distance. It is also SHORTER than a mob's — `stagger` is asked for
## `K.PARRY_STAGGER` and this spends two thirds of it, because an opening on a
## set-piece is worth more per second than an opening on a goblin.
func stagger(from: Vector3, seconds: float, _shove: float) -> void:
	if state == State.DEAD or state == State.IDLE:
		return
	_end_charge()
	# Into RECOVER with the punish NOT yet open, which is the fight's own
	# vocabulary rather than a second one bolted on: `_tick_recover` runs the
	# short timer down and then opens the beat's authored punish window and emits
	# `punish_opened` exactly as it would have. A parry therefore does not invent
	# an opening — it brings the one the beat already owed forward.
	state = State.RECOVER
	_punishing = false
	_timer = seconds * 0.66
	var away := K.flat(global_position - from)
	if away != Vector3.ZERO:
		_flinch(away)
	_glowing = false
	_flash.hit()
	Bus.request_sfx.emit(&"hit_armor", global_position)


func _on_died() -> void:
	_clear_marker()
	_end_charge()
	_pose_reset()
	for z in _zones:
		var node := z["node"] as Node3D
		if is_instance_valid(node):
			node.queue_free()
	_zones.clear()
	# Before `super()`, because `Enemy._on_died` awaits a 2.2 s timer partway
	# through: anything that has to be true the moment the boss dies -- the music
	# changing, the arena unsealing, the door opening -- cannot be on the far side
	# of that await.
	Bus.boss_defeated.emit()
	super()


## The authored drop, not a roll.
##
## `Enemy._drop_loot` rolls `ItemDb.ENEMY_DROPS` for ingredients, which is right
## for a body and wrong for the thing at the bottom of the floor. Contract §9:
## grant a miniboss progress token, PLACE `drop.relic`.
##
## A floor boss's permanent item waits in the arena's great chest. Only an
## authored miniboss token -- the Makers' Mark today -- is granted on death.
##
## The relic is a MOTE on the floor and emphatically not a grant. GDD §3 puts a
## relic in the BAG, which means it costs a slot, is charged the extraction fee,
## dies with the bag and comes back to the room it was placed in. Handing it over
## as an owned flag would delete the entire decision the relic exists to create.
func _drop_loot() -> void:
	var drop: Dictionary = _row.get("drop", {})
	var item: StringName = drop.get("item", &"")
	if item != &"" and BossDb.is_miniboss(boss_id):
		Game.grant(item)
	var relic: StringName = drop.get("relic", &"")
	if relic != &"":
		# Through `RelicPickup`, not `LootMote.drop`, and the difference is not
		# cosmetic: `LootMote.drop` stamps every mote with `Heat.multiplier()`,
		# so a relic dropped straight off the corpse banked the run's heat bonus
		# while the deep chest's and the vault's -- which go through
		# `RelicPickup.place` and are forced to `heat_mult = 1.0` -- did not. Three
		# relics on one floor, one of them paying differently, off a code path
		# nobody would think to compare. `place` also refuses to mint a second
		# copy of a relic already in the bag or in the ledger, which is the same
		# guard the other two placements already had.
		#
		# Parented to `current_scene` and not to this body, exactly as
		# `Enemy._drop_loot` is: the corpse sinks into the floor and frees itself,
		# and a drop parented to it would go down with it.
		RelicPickup.place(get_tree().current_scene, relic,
			global_position + Vector3.UP * 1.0, Vector3(0.0, 0.0, 1.2))
