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
## is the commit, `State.RECOVER` carries the recovery tail and any authored
## recover-aperture, and `State.CHASE` owns the moving breath between attacks.
## That mapping is worth more than a bespoke machine would
## be, because the pieces around it -- the glow guard in `_physics_process`, the
## gravity, `move_and_slide`, `rotation.y = _facing` -- keep working unchanged.
## The parts that are genuinely different are overridden and named:
##
##   `_resolve_def`   stats come from `BossDb`, not `Enemy.DEFS`
##   `_build_combat`  health is ABSOLUTE (contract §2) and there is no hitbox
##   `_style_model`   the authored tint, applied BEFORE `HitFlash.bind`
##   `apply_hit`      armour, weak-point matching and stagger segment budget
##   `_on_damaged`    feedback for damage that passed the true-stagger gate
##   `freeze`         the authored hookshot weak point, otherwise armour
##   `_drop_loot`     the authored drop, not a roll off `ItemDb`
##
## **Armour and poise.** Outside a true stagger, weapon hits do no health damage.
## A correct authored interaction breaks the visible weak point and roots the
## body in a capped vulnerable window. The public parry `stagger()` remains the
## shorter recovery interruption and does not open health damage by itself.
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

## Fired the instant a tell begins, at commit, and around a recover weak point.
## `punish_closed` carries the window MEASURED in game seconds rather than the
## number the table authored, because the thing worth proving is the one the
## player stood in. See `_measured_punish`.
signal beat_started(beat_id: StringName)
signal beat_committed(beat_id: StringName)
signal punish_opened(beat_id: StringName, seconds: float)
signal punish_closed(beat_id: StringName, measured: float)
signal weakpoint_opened(kind: StringName, beat_id: StringName)
signal staggered(count: int, goal: int, seconds: float)
signal phase_changed(phase: int)

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

## Ground markers. Flat, unshaded, and drawn in the beat's own authored colour.
const MARK_Y := 0.05
const MARK_SEGMENTS := 28
const BOUNDARY_INSET := 1.35
const WEAKPOINT_PULSE_HZ := 2.6

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

## A leap moves the CharacterBody only in X/Z. The fitted model owns the sine
## arc, so base gravity and authored height never write the same vertical value.
var _leaping: bool = false
var _leap_start: Vector3 = Vector3.ZERO
var _leap_target: Vector3 = Vector3.ZERO
var _leap_total: float = 0.0
var _leap_elapsed: float = 0.0

## Live thrown zones: destination marker, projectile flight, then fuse.
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

var _phase: int = 1
var _orbit_sign: float = 1.0
var _wall_latched: bool = false
var _reposition_left: float = 0.0

## Ordinary recovery remains armoured. This flag is the one health-damage gate.
var _weakpoint_open: bool = false
var _weakpoint_beat: StringName = &""
var _vulnerable: bool = false
var _vulnerable_timer: float = 0.0
var _stagger_windows: int = 0
var _segment_damage_done: int = 0
var _weakpoint_marker: MeshInstance3D = null
var _weakpoint_clock: float = 0.0
var _phase_flash: Tween = null
var _phase_two_pending: bool = false


func _ready() -> void:
	super()
	# `docs/CONTRACT.md` §5, and the targeting priority chain reads it: Boss
	# outranks Enemy in the lock-on category test.
	add_to_group(&"boss")
	if _model != null:
		_fit_scale = _model.scale
		_fit_pos = _model.position
	_build_weakpoint_marker()
	_orbit_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	_arena_center = _anchor
	# Asleep until an arena wakes it. A boss that charged the moment the player
	# came through the door would have started its fight off screen.
	state = State.IDLE


# --- What the table says ------------------------------------------------------

## `BossDb`'s row, shaped as the `Enemy.DEFS` dictionary the base class reads.
##
## Health is copied ABSOLUTE and the damage is 0, both per contract §2: a boss is
## authored for exactly one floor and its numbers are already that floor's
## numbers, and every HP it deals comes from a beat rather than from a
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
	var movement: Dictionary = _row.get("movement", {})
	var phase_one: Dictionary = movement.get("phase_1", {})
	return {
		"health": int(_row["health"]),
		"damage": 0,
		"speed": float(phase_one.get("speed", 2.1)),
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
	health.max_health_points = maxi(int(_row.get("health", 48)), 1)
	# The same monster i-frames `Enemy` takes. During true stagger the full light
	# chain can land; armour outside it is explicit actor state, not an iframe.
	health.iframe_time = K.ENEMY_IFRAME_TIME
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


## A no-op, and the emptiness IS the override.
##
## `Enemy` re-runs the floor's curve every time `level` is written now (card #22),
## which is right for a generated body and would be a disaster here: contract §2
## authors a boss's health ABSOLUTE for the one floor it stands on, so a single
## stray `boss.level = 3` would otherwise rewrite the Bellwake's authored 96 HP
## and its four 24 HP segments. Nothing writes it today. This is what keeps that from
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


func _build_weakpoint_marker() -> void:
	var stagger_row: Dictionary = _row.get("stagger", {})
	if stagger_row.is_empty():
		return
	var color: Color = stagger_row.get("color", Pal.BONE)
	_weakpoint_marker = MeshInstance3D.new()
	_weakpoint_marker.name = "WeakPoint"
	var orb := SphereMesh.new()
	var radius := clampf(_height() * 0.045, 0.11, 0.18)
	orb.radius = radius
	orb.height = radius * 2.0
	_weakpoint_marker.mesh = orb
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_weakpoint_marker.material_override = mat
	_weakpoint_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weakpoint_marker.position = _weakpoint_rest_position()
	_weakpoint_marker.visible = false
	add_child(_weakpoint_marker)


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


func current_phase() -> int:
	return _phase


func weakpoint_open() -> bool:
	return _weakpoint_open


func is_weakpoint_open() -> bool:
	return _weakpoint_open


func is_vulnerable() -> bool:
	return _vulnerable


func vulnerable() -> bool:
	return _vulnerable


func stagger_count() -> int:
	return _stagger_windows


func stagger_goal() -> int:
	var authored: Dictionary = _row.get("stagger", {})
	return int(authored.get("goal", 1))


func segment_capacity() -> int:
	if health == null:
		return 0
	return int(ceil(float(health.max_health_points) / float(maxi(stagger_goal(), 1))))


func segment_damage() -> int:
	return _segment_damage_done


## True only while health damage can land. Ordinary recovery is armoured.
func is_punishable() -> bool:
	return _vulnerable


func _movement_row() -> Dictionary:
	var movement: Dictionary = _row.get("movement", {})
	return movement.get("phase_2" if _phase >= 2 else "phase_1", {})


func _reposition_duration() -> float:
	return float(_movement_row().get("reposition", 0.5))


# --- The beat -----------------------------------------------------------------

func _tick_idle() -> void:
	_stop()
	_play(&"idle", true)


## Everything between openings and tells. Row-driven orbit steering keeps the
## body in motion, yields when crowded, closes when far, and pushes hard away
## from the live arena boundary. Every exit arms a mandatory reposition timer.
func _tick_chase(delta: float) -> void:
	if _player == null:
		_stop()
		_play(&"idle", true)
		return
	_reposition_left = maxf(0.0, _reposition_left - delta)
	_face_player(delta, ROAM_TRACK_DEG)
	if is_on_wall() and not _wall_latched:
		_orbit_sign *= -1.0
	_wall_latched = is_on_wall()

	var movement := _movement_row()
	var speed := float(movement.get("speed", _def["speed"]))
	var ring := float(movement.get("orbit_radius", 3.8))
	var strength := float(movement.get("orbit_strength", 1.0))
	# Bomb rows must remain beatable without stored charges. While their thrown
	# zone is live the body presses just inside that zone's edge, making the
	# renewable answer a deliberate bait-and-dodge instead of a random scatter
	# that happens to clip the boss once in twenty casts.
	var stagger_row: Dictionary = _row.get("stagger", {})
	if _weakpoint_open and stagger_row.get("kind", &"") == BossDb.STAGGER_BOMB \
			and stagger_row.get("open", &"") == BossDb.OPEN_ZONES:
		ring = minf(ring, float(_beat.get("radius", ring)) * 0.80)
		strength = maxf(strength, 1.65)
	var radial := K.plane(global_position - _player.global_position)
	var dist := radial.length()
	if dist <= 0.001:
		radial = Vector3.FORWARD.rotated(Vector3.UP, _facing)
		dist = 0.001
	else:
		radial /= dist
	var tangent := Vector3(-radial.z, 0.0, radial.x) * _orbit_sign
	var desired := tangent + radial * ((ring - dist) * strength)
	if dist < ring * 0.72:
		desired += radial * 1.8
	elif dist > ring * 1.45:
		desired -= radial * 1.5

	var from_center := K.plane(global_position - _arena_center)
	var boundary := maxf(arena_radius() - BOUNDARY_INSET, 1.0)
	if from_center.length() > boundary - 1.0:
		var edge_t := clampf(from_center.length() - (boundary - 1.0), 0.0, 2.0)
		desired -= from_center.normalized() * (2.5 + edge_t * 2.0)
	_steer(desired.normalized(), speed)
	_play(&"walk_fwd", true, 0.9 + speed * 0.04)
	# A live thrown-zone aperture is a bait sequence, not permission to layer a
	# second attack over it. Keep orbiting until the last fuse closes or the
	# player breaks the weak point.
	if _cooldown <= 0.0 and _reposition_left <= 0.0 and not _weakpoint_open:
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
	_stop()
	_tell_total = maxf(float(_beat["tell"]["time"]), 0.001)
	_timer = _tell_total
	_kill_recoil()
	_prepare_leap_target()
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
		var id := BossDb.pick_beat(boss_id, _rng, refused, dist, _phase)
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


func _prepare_leap_target() -> void:
	_leap_target = global_position
	if not _beat.has("leap") or _player == null:
		return
	var promised := _player.global_position
	var from_center := K.plane(promised - _arena_center)
	var limit := maxf(arena_radius() - BOUNDARY_INSET, 1.0)
	if from_center.length() > limit:
		promised = _arena_center + from_center.normalized() * limit
	promised.y = global_position.y
	_leap_target = promised


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
	if not _beat.has("leap"):
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
	if b.has("leap"):
		var leap: Dictionary = b["leap"]
		return float(leap["time"]) + 0.05
	return COMMIT_TIME


func _tick_strike(delta: float) -> void:
	_timer -= delta
	if _leaping:
		_advance_leap(delta)
	elif _charging:
		_advance_charge(delta)
	else:
		_stop()
	if _timer <= 0.0:
		_end_charge()
		state = State.RECOVER
		_timer = float(_beat["recover"])
		_punishing = false


## Recovery is rooted. Only the authored `OPEN_RECOVER` beat continues into a
## stationary weak-point aperture; every other beat flows back into orbit as
## soon as its animation tail is paid. That distinction prevents armoured fake
## openings where the boss stands politely while sword blows clang for 0 HP.
##
## `_cooldown` is armed at the moment the punish OPENS, not at the moment it
## closes, because contract §4 measures both from the same instant and asserts
## `cooldown >= punish`. The row's movement block adds a mandatory visible
## reposition after the window even when those two authored timers are equal.
func _tick_recover(delta: float) -> void:
	_stop()
	if _vulnerable:
		_vulnerable_timer -= delta
		_hold_stagger_pose()
		if _vulnerable_timer <= 0.0:
			_finish_true_stagger()
		return
	_timer -= delta
	if not _punishing:
		if _timer <= 0.0:
			var stagger_row: Dictionary = _row.get("stagger", {})
			var is_recover_aperture: bool = stagger_row.get("beat", &"") \
				== _beat.get("id", &"") and stagger_row.get("open", &"") \
				== BossDb.OPEN_RECOVER
			if not is_recover_aperture:
				# Spend the old recovery budget in motion. `cooldown` gates the next
				# tell while `punish` is the minimum visible reposition; both tick in
				# CHASE, so the boss gives breathing room without offering fake HP.
				_cooldown = float(_beat["cooldown"])
				_reposition_left = maxf(_reposition_duration(),
					float(_beat["punish"]))
				state = State.CHASE
				return
			_punishing = true
			_measured_punish = 0.0
			_timer = float(_beat["punish"])
			_cooldown = float(_beat["cooldown"])
			_open_weakpoint(BossDb.OPEN_RECOVER)
			punish_opened.emit(_beat["id"], float(_beat["punish"]))
		return
	# Measured rather than assumed. The window is the promise; a director that
	# checks the authored number has checked the table, not the fight.
	_measured_punish += delta
	if _timer <= 0.0:
		_close_weakpoint_for(BossDb.OPEN_RECOVER)
		_punishing = false
		punish_closed.emit(_beat["id"], _measured_punish)
		_reposition_left = _reposition_duration()
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
	if b.has("leap"):
		var leap: Dictionary = b["leap"]
		_leaping = true
		_leap_start = global_position
		_leap_total = maxf(float(leap["time"]), 0.01)
		_leap_elapsed = 0.0
		return
	_resolve_slam(b)


func _resolve_slam(b: Dictionary) -> void:
	var outer := float(b["radius"])
	var inner := float(b["safe_inner"])
	_flash_marker(_ring_marker(inner, outer, b["tell"]["color"]))
	for body in _victims():
		var d := K.plane(body.global_position - global_position).length()
		if d <= outer and d >= inner:
			_land(body, b)


func _advance_leap(delta: float) -> void:
	if not _leaping:
		return
	_leap_elapsed = minf(_leap_elapsed + delta, _leap_total)
	var flat_delta := K.plane(_leap_target - _leap_start)
	var direction := flat_delta.normalized()
	var speed := flat_delta.length() / _leap_total
	_steer(direction, speed)
	var leap: Dictionary = _beat.get("leap", {})
	var t := clampf(_leap_elapsed / _leap_total, 0.0, 1.0)
	if _model != null:
		_model.position.y = _fit_pos.y + sin(t * PI) * float(leap.get("height", 0.0))
	if _leap_elapsed < _leap_total:
		return
	_leaping = false
	_stop()
	_kill_recoil()
	_pose_reset()
	_clear_marker()
	_resolve_slam(_beat)
	_timer = 0.0


func _cancel_leap() -> void:
	if not _leaping:
		return
	_leaping = false
	_stop()
	_kill_recoil()
	_clear_marker()
	_pose_reset()


## Lock the heading and go. Resolved per frame during `STRIKE`, once per body.
func _shape_charge(b: Dictionary) -> void:
	_charging = true
	_charge_dir = K.flat(-global_transform.basis.z)
	_charge_left = float(b["reach"])
	_charge_speed = float(b["speed"])
	_charge_hit.clear()
	_open_weakpoint(BossDb.OPEN_CHARGE)


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
	_close_weakpoint_for(BossDb.OPEN_CHARGE)


## `count` destinations marked on the floor at commit. A high-contrast projectile
## crosses to each destination on the authored parabola; only landing starts its
## fuse. The discs still hurt the player and nothing else.
##
## The first destination remains under the hero and zone damage still queries
## only `_victims()`. A bomb-authored burst near the open marker is checked as a
## weak-point interaction instead; it never sends its normal damage into health.
func _shape_zone(b: Dictionary) -> void:
	var radius := float(b["radius"])
	var count := maxi(int(b["count"]), 1)
	var ring := maxf(arena_radius() - radius, 1.0)
	var throw: Dictionary = b.get("throw", {})
	var start := global_position + Vector3.UP * (_height() * 0.62) \
		+ K.flat(-global_transform.basis.z) * 0.35
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
		mark.scale = Vector3(0.55, 1.0, 0.55)
		var projectile_color: Color = b["tell"]["color"]
		var projectile := _zone_projectile(projectile_color)
		get_parent().add_child(projectile)
		projectile.global_position = start
		_zones.append({
			"node": mark, "projectile": projectile, "from": start, "at": at,
			"radius": radius, "flight": float(throw.get("flight", 0.01)),
			"flight_elapsed": 0.0, "height": float(throw.get("height", 0.0)),
			"landed": false, "fuse": float(b["fuse"]),
			"fuse_left": float(b["fuse"]), "beat": b,
		})
	_open_weakpoint(BossDb.OPEN_ZONES)


func _zone_projectile(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "ThrownZone"
	var mi := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.16
	orb.height = 0.32
	mi.mesh = orb
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


## Advances flight first, then burns the fuse after landing.
func _tick_zones(delta: float) -> void:
	var i := _zones.size() - 1
	while i >= 0:
		var z: Dictionary = _zones[i]
		var node_ref: Variant = z["node"]
		var projectile_ref: Variant = z["projectile"]
		if not bool(z["landed"]):
			z["flight_elapsed"] = float(z["flight_elapsed"]) + delta
			var flight := maxf(float(z["flight"]), 0.01)
			var travel_t := clampf(float(z["flight_elapsed"]) / flight, 0.0, 1.0)
			if is_instance_valid(projectile_ref):
				var projectile := projectile_ref as Node3D
				var source: Vector3 = z["from"]
				var at: Vector3 = z["at"]
				projectile.global_position = source.lerp(at, travel_t) \
					+ Vector3.UP * sin(travel_t * PI) * float(z["height"])
			if travel_t >= 1.0:
				z["landed"] = true
				if is_instance_valid(projectile_ref):
					(projectile_ref as Node3D).queue_free()
			i -= 1
			continue

		z["fuse_left"] = float(z["fuse_left"]) - delta
		if float(z["fuse_left"]) <= 0.0:
			var breaks_weakpoint := _burst(z)
			if is_instance_valid(node_ref):
				(node_ref as Node3D).queue_free()
			if is_instance_valid(projectile_ref):
				(projectile_ref as Node3D).queue_free()
			var b: Dictionary = z["beat"]
			var burst_beat: StringName = b["id"]
			_zones.remove_at(i)
			if breaks_weakpoint:
				_break_weakpoint()
				return
			if _weakpoint_open and _weakpoint_beat == burst_beat \
					and not _has_live_zone(burst_beat):
				_close_weakpoint()
		elif is_instance_valid(node_ref):
			# Grows to full over the fuse, so "about to" and "now" are two
			# pictures rather than one that blinks.
			var b: Dictionary = z["beat"]
			var t := clampf(1.0 - float(z["fuse_left"]) \
				/ maxf(float(z["fuse"]), 0.001),
				0.0, 1.0)
			(node_ref as Node3D).scale = Vector3(0.55 + 0.45 * t, 1.0,
				0.55 + 0.45 * t)
		i -= 1


func _has_live_zone(beat_id: StringName) -> bool:
	for zone in _zones:
		var b: Dictionary = zone["beat"]
		if b["id"] == beat_id:
			return true
	return false


func _burst(z: Dictionary) -> bool:
	var b: Dictionary = z["beat"]
	var at: Vector3 = z["at"]
	var radius := float(z["radius"])
	Bus.request_sfx.emit(b["sfx"], at)
	for body in _victims():
		if K.plane(body.global_position - at).length() <= radius:
			_land(body, b, at)
	var authored: Dictionary = _row.get("stagger", {})
	return _weakpoint_open and authored.get("kind", &"") == BossDb.STAGGER_BOMB \
		and _weakpoint_beat == b["id"] \
		and K.plane(global_position - at).length() <= radius


## `count` ordinary `Enemy`s of `kind` at `radius`. Deals no damage.
##
## `kind` is always a key of `Enemy.DEFS` and `BossDb.validate()` enforces it,
## because `Enemy._ready` swaps an unknown kind for skeleton's STATS while
## keeping the requested MODEL -- a boss that summons a troll-shaped 6 HP
## skeleton is a fight nobody can tune.
##
## **The level is an ARGUMENT to `spawn` and not a write afterwards.** It used to
## be the write, one line below the call, under a comment claiming the adds were
## curved by the boss's band -- and they were not: `spawn` calls `add_child`,
## `add_child` runs `_ready`, and `_ready` had already latched health and damage
## off the `Prog.FIRST` default by the time the write landed. The Bellwake's
## choristers came out at 6 HP instead of 9 and the Riven Knight's wraiths
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
	if b.has("leap") and b["shape"] == BossDb.SHAPE_SLAM:
		get_parent().add_child(_marker)
		_marker.global_position = _leap_target + Vector3(0.0, MARK_Y, 0.0)
		_marker.scale = Vector3(0.001, 1.0, 0.001)
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
		# 4 HP, which is the exact failure the marks exist to prevent.
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

func _open_weakpoint(exposure: StringName) -> void:
	if _weakpoint_open or _vulnerable or state == State.DEAD:
		return
	var authored: Dictionary = _row.get("stagger", {})
	var beat_id: StringName = _beat.get("id", &"")
	if authored.get("beat", &"") != beat_id or authored.get("open", &"") != exposure:
		return
	_weakpoint_open = true
	_weakpoint_beat = beat_id
	if is_instance_valid(_weakpoint_marker):
		_weakpoint_marker.visible = true
	var kind: StringName = authored.get("kind", &"")
	weakpoint_opened.emit(kind, beat_id)


func _close_weakpoint() -> void:
	_weakpoint_open = false
	_weakpoint_beat = &""
	if is_instance_valid(_weakpoint_marker):
		_weakpoint_marker.visible = _vulnerable


func _close_weakpoint_for(exposure: StringName) -> void:
	if not _weakpoint_open:
		return
	var authored: Dictionary = _row.get("stagger", {})
	if authored.get("open", &"") == exposure:
		_close_weakpoint()


func _hit_matches_weakpoint(kind: StringName) -> bool:
	var authored: Dictionary = _row.get("stagger", {})
	var wanted: StringName = authored.get("kind", &"")
	if wanted == BossDb.STAGGER_ARROW:
		return kind == Hit.ARROW or kind == Hit.ARROW_FIRE
	return kind == wanted


func _break_weakpoint() -> void:
	if not _weakpoint_open:
		return
	var broken_beat := _weakpoint_beat
	_close_weakpoint()
	_end_charge()
	_cancel_leap()
	_clear_marker()
	_cancel_zones_for_beat(broken_beat)
	_enter_true_stagger()


func _enter_true_stagger() -> void:
	if _vulnerable or state == State.DEAD or state == State.IDLE:
		return
	var authored: Dictionary = _row.get("stagger", {})
	_vulnerable = true
	_vulnerable_timer = float(authored.get("window", 2.4))
	_segment_damage_done = 0
	_stagger_windows += 1
	state = State.RECOVER
	_punishing = false
	_timer = 0.0
	_stop()
	_kill_recoil()
	_hold_stagger_pose()
	if _anim != null and _anim.has_animation(&"hurt_heavy"):
		_play(&"hurt_heavy")
	elif _anim != null and _anim.has_animation(&"hurt"):
		_play(&"hurt")
	if is_instance_valid(_weakpoint_marker):
		_weakpoint_marker.position = Vector3(0.0, _height() * 0.28,
			_weakpoint_front_z())
		_weakpoint_marker.visible = true
		_weakpoint_marker.scale = Vector3.ONE * 1.10
	Bus.request_sfx.emit(&"parry_clang", global_position)
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)
	staggered.emit(_stagger_windows, stagger_goal(), _vulnerable_timer)


func _finish_true_stagger() -> void:
	if not _vulnerable:
		return
	_vulnerable = false
	_vulnerable_timer = 0.0
	_pose_reset()
	if is_instance_valid(_weakpoint_marker):
		_weakpoint_marker.visible = false
		_weakpoint_marker.scale = Vector3.ONE
		_weakpoint_marker.position = _weakpoint_rest_position()
	if state != State.DEAD:
		state = State.CHASE
		_cooldown = 0.0
		_reposition_left = _reposition_duration()
	if _phase_two_pending:
		call_deferred("enter_phase_two")


func _hold_stagger_pose() -> void:
	if _model == null:
		return
	_pose_reset()
	_model.scale.y = _fit_scale.y * 0.62
	_model.position.y = _fit_pos.y - _height() * 0.16
	_model.rotation.x = _model_rest.x + deg_to_rad(14.0)


func _cancel_zones_for_beat(beat_id: StringName) -> void:
	var i := _zones.size() - 1
	while i >= 0:
		var zone: Dictionary = _zones[i]
		var b: Dictionary = zone["beat"]
		if b["id"] == beat_id:
			var node_ref: Variant = zone["node"]
			var projectile_ref: Variant = zone["projectile"]
			if is_instance_valid(node_ref):
				(node_ref as Node3D).queue_free()
			if is_instance_valid(projectile_ref):
				(projectile_ref as Node3D).queue_free()
			_zones.remove_at(i)
		i -= 1


func _update_weakpoint_marker(delta: float) -> void:
	if not is_instance_valid(_weakpoint_marker):
		return
	_weakpoint_clock += delta
	if _vulnerable:
		_weakpoint_marker.visible = true
		_weakpoint_marker.position = Vector3(0.0, _height() * 0.28,
			_weakpoint_front_z())
		_weakpoint_marker.scale = Vector3.ONE * 1.10
	elif _weakpoint_open:
		_weakpoint_marker.visible = true
		_weakpoint_marker.position = _weakpoint_rest_position()
		var pulse := 1.0 + sin(_weakpoint_clock * TAU * WEAKPOINT_PULSE_HZ) * 0.18
		_weakpoint_marker.scale = Vector3.ONE * pulse
	else:
		_weakpoint_marker.visible = false
		_weakpoint_marker.scale = Vector3.ONE


func _weakpoint_rest_position() -> Vector3:
	return Vector3(0.0, _height() * 0.58, _weakpoint_front_z())


func _weakpoint_front_z() -> float:
	return -clampf(_height() * 0.32, 0.45, 1.25)


## The actor-owned damage gate. Weapon scanners find this before the health
## child, so every damaging weapon shares one armour and segment-budget rule.
func apply_hit(hit: Hit) -> bool:
	if hit == null or health == null or health.dead or state == State.DEAD \
			or health.is_invulnerable():
		return false
	if _weakpoint_open and _hit_matches_weakpoint(hit.kind):
		_break_weakpoint()
		return false
	if not _vulnerable:
		_armor_feedback(hit)
		return false

	var remaining := maxi(segment_capacity() - _segment_damage_done, 0)
	var stagger_row: Dictionary = _row.get("stagger", {})
	var multiplier := float(stagger_row.get("multiplier", 2.0))
	var scaled := maxi(int(roundf(float(hit.amount) * multiplier)), 0)
	var amount := mini(scaled, mini(remaining, health.health_points))
	if amount <= 0:
		_finish_true_stagger()
		return false
	var copied := Hit.make(amount, hit.from, hit.kind, hit.knockback, hit.stun,
		hit.source, hit.mass, hit.commitment)
	copied.odds_knockdown = hit.odds_knockdown
	copied.odds_stagger = hit.odds_stagger
	if not health.apply_hit(copied):
		return false
	_segment_damage_done += amount
	if _segment_damage_done >= segment_capacity() and state != State.DEAD:
		_finish_true_stagger()
	return true


func _armor_feedback(hit: Hit) -> void:
	Bus.request_sfx.emit(&"hit_armor", global_position)
	ImpactVfx.spawn(get_tree().current_scene, _impact_point(hit.from), 0.12)


func enter_phase_two() -> void:
	if _phase >= 2 or state == State.DEAD:
		return
	# Crossing half health must never amputate the player's earned damage window.
	# Miniboss segment sizes can cross 50% midway through the 2+2+4 sword chain;
	# queue the escalation until that full segment is spent or times out.
	if _vulnerable:
		_phase_two_pending = true
		return
	_phase_two_pending = false
	_phase = 2
	_close_weakpoint()
	_cancel_leap()
	_end_charge()
	_pose_reset()
	if _phase_flash != null and _phase_flash.is_valid():
		_phase_flash.kill()
	var authored: Dictionary = _row.get("stagger", {})
	var color: Color = authored.get("color", Pal.BONE)
	_flash.glow(color, 0.9)
	Bus.request_sfx.emit(&"glint_bell", global_position)
	_phase_flash = create_tween()
	_phase_flash.tween_interval(0.20)
	_phase_flash.tween_callback(Callable(self, "_finish_phase_flash"))
	phase_changed.emit(2)
	Bus.boss_phase_changed.emit(2)


func _finish_phase_flash() -> void:
	_phase_flash = null
	if state != State.DEAD:
		_flash.restore()


func _phase_threshold_fallback() -> void:
	if _phase >= 2 or health == null or health.dead:
		return
	var phase_row: Dictionary = _row.get("phase", {})
	if health.fraction() <= float(phase_row.get("at", 0.50)):
		enter_phase_two()


func _physics_process(delta: float) -> void:
	_tick_zones(delta)
	_update_weakpoint_marker(delta)
	super(delta)


## Feedback for health damage that passed the true-stagger gate.
##
## `Enemy._on_damaged` throws the body into `HURT`, pushes the cooldown and
## reels -- correct for a skeleton, and it would delete this fight. The window
## every beat promises (contract §4) only exists if the beat gets to finish, and
## a boss staggered out of its own recovery is a boss with nothing to punish. It
## would also make the telegraph a lie: read the tell, hit first, and the attack
## you read never arrives.
##
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
	call_deferred("_phase_threshold_fallback")


## The hookshot opens only the authored hookshot aperture. At every other time
## the barb rings off plate and cannot cut a tell or ordinary recovery short.
func freeze(_seconds: float = K.HOOK_FREEZE) -> void:
	if state == State.DEAD:
		return
	var authored: Dictionary = _row.get("stagger", {})
	if _weakpoint_open and authored.get("kind", &"") == BossDb.STAGGER_HOOKSHOT:
		_break_weakpoint()
		return
	Bus.request_sfx.emit(&"hit_armor", global_position)


## And neither does a blow throw it. Same argument as poise above, one step
## further: a beat the player can knock the boss out of is a beat they can
## delete, and the arena is authored around a body that stays in it. The corpse
## does not fly either -- `Enemy._on_died` launches every other kill, and a boss
## sliding into the scenery would take its placed relic with it (`_drop_loot`).
func _can_launch() -> bool:
	return false


## **Parry buys poise time, not health damage.**
##
## A parry can only arrive after the beat committed, so it never deletes a tell.
## It cuts the animation tail to a short recovery and then returns the boss to
## motion. If that exact beat owns a recover weak point, the aperture still
## appears and still requires its floor item; the parry itself never opens HP.
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
	_cancel_leap()
	# Into RECOVER with the aperture not yet open. `_tick_recover` runs the short
	# timer down, then either exposes the beat's authored recover weak point or
	# returns to orbit. Parry never invents a damage window.
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
	_cancel_leap()
	_weakpoint_open = false
	_weakpoint_beat = &""
	_vulnerable = false
	if _phase_flash != null and _phase_flash.is_valid():
		_phase_flash.kill()
	_phase_flash = null
	if is_instance_valid(_weakpoint_marker):
		_weakpoint_marker.visible = false
		_weakpoint_marker.scale = Vector3.ONE
	_pose_reset()
	_dismiss_summons()
	for z in _zones:
		var node_ref: Variant = z["node"]
		var projectile_ref: Variant = z["projectile"]
		if is_instance_valid(node_ref):
			(node_ref as Node3D).queue_free()
		if is_instance_valid(projectile_ref):
			(projectile_ref as Node3D).queue_free()
	_zones.clear()
	# Before `super()`, because `Enemy._on_died` awaits a 2.2 s timer partway
	# through: anything that has to be true the moment the boss dies -- the music
	# changing, the arena unsealing, the door opening -- cannot be on the far side
	# of that await.
	var observation_id: StringName = FieldNotesDb.observation_for_boss(boss_id)
	if observation_id != &"":
		Bus.field_observation_recorded.emit(observation_id)
	Bus.boss_defeated.emit()
	super()


func _dismiss_summons() -> void:
	for summon in _summons:
		if is_instance_valid(summon):
			summon.queue_free()
	_summons.clear()


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
