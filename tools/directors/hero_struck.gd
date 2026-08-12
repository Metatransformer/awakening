extends RefCounted
## The RECEIVING half of combat, photographed and measured. Card #130.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/hero_struck.gd \
##     --out=/tmp/struck/x.png --warmup=60
##
## `monster_feel.gd` proves a blow the hero THROWS reads. Nothing proved a blow
## he TAKES, and until this card there was nothing to prove: every hit on the
## player produced the same four-frame stop, the same trauma of 0.80, no flinch,
## no direction and no sound.
##
## Three sections, in the order the card asks for them:
##
##   A  **The three floor-1 beats**, each at the tier it most often rolls, three
##      consecutive frames apiece plus a settle. This is the card's own bar --
##      "take a hit from each floor-1 boss move and tell them apart with the
##      health bar covered" -- so look at these with the hearts IGNORED. The
##      differences that have to carry it are the arc's width, how far the frame
##      lurches, and what his body does.
##   B  **The three tiers off one beat**, forced, so flinch / stagger / knocked
##      flat can be compared with everything else held equal.
##   C  **The camera lurch against known answers**, which is the section that
##      makes A and B mean anything (CLAUDE.md §2). See `_directions`.
##
## **Why the hits are delivered rather than fought for.** `boss_cistern.gd`
## already proves the Warden throws these beats and that they land; what is
## unproven is what the RECEIVING end does with one, and waiting for a boss to
## choose a beat photographs the boss's animation with the hero's reaction
## somewhere behind it. Every blow here is built exactly as `Boss._land` builds
## one -- the same `Hit.make` arguments, the same `_height() / K.LAUNCH_MASS_REF`
## mass and the same `_commitment` normalisation, spelled out so this director
## can catch the shipping code getting it wrong instead of agreeing with it.
##
## **Why the tier is forced.** `Hit.roll_tier` is a ROLL, so an unforced sheet is
## a different sheet every run and two of them cannot be compared. `odds_stagger`
## and `odds_knockdown` are the authoring override the schema already carries
## (`damage_area.gd`, `Enemy.DEFS`), so forcing through them is the same door a
## designer pinning a monster's numbers would use.

const BOSS := &"cistern_warden"

## Long enough for a knockdown to finish getting up (0.70 down + 1.00 rise) and
## for `K.IFRAME_TIME` to lapse, so the next blow is not refused.
const BETWEEN := 2.4

## How far off the hero a staged impact stands. Outside arm's reach, inside the
## room -- the number only sets `Hit.from`, which is a bearing here, not a range.
const REACH := 3.0

## `Camera3D.h_offset` / `v_offset` a lurch has to clear to count as a lurch, in
## units. `monster_feel.gd` measured 37.5 px of image per unit at 1280x720, so
## 0.08 is 3 px -- the same 3 px the HUD calls a visible stroke, and comfortably
## under the 0.28..1.00 strength range `K.HURT_PUNCH_MIN/MAX` asks for.
const LURCH := 0.08

## How far a blow has to haul him, and how far a jab must not. `K.KNOCKBACK_HEAVY`
## through `Hit.knock_scale(KNOCKDOWN)` is 8.0 x 1.8 = 14.4 m/s bled off at
## `decel * 1.4`, so the honest answer is metres; 1.0 is a floor well under it
## that still cannot be reached by a shove that was deleted.
const MIN_KNOCKDOWN_TRAVEL := 1.0
const MAX_LIGHT_TRAVEL := 0.5

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/struck/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero: Node3D = _hero(rig)
	if hero == null:
		rig.fail("no hero in the scene")
		_fails += 1
		return

	# `--only=c` runs one section. The contact sheets take four minutes of GPU and
	# the calibration in C is the part anybody iterating on the lurch is after.
	var only: String = rig.arg("only", "abc")
	if "a" in only:
		await _beats(rig, hero, out)
	if "b" in only:
		await _tiers(rig, hero, out)
	if "c" in only:
		await _directions(rig, hero, out)

	if _fails == 0:
		print("STRUCK OK -- every check passed")


# --- A: the three floor-1 beats ----------------------------------------------

## Each beat the Cistern Warden has, at the tier it rolls most often, from the
## bearing the fight actually delivers it from.
##
## `drown_pool` is the interesting one and it is why the `from` column exists:
## the pool is a disc centred under the player's own feet, so its `Hit.from` has
## no direction in it at all. The HUD draws no arc for it by design
## (`Hud._on_hero_struck` refuses to point at a lie) and `Hero.take_hit` throws
## the shove off his own facing instead. That is a THIRD thing the player can
## tell apart, and it is only visible next to the two that do have a bearing.
func _beats(rig, hero: Node3D, out: String) -> void:
	var cam := rig.root.get_viewport().get_camera_3d() as Camera3D
	if cam == null:
		return
	for beat in BossDb.beats(BOSS):
		if int(beat["damage"]) <= 0:
			continue
		var id := String(beat["id"])
		var hit := _price(beat)
		var odds := hit.tier_odds()
		# The tier this beat lands on more often than any other, so the sheet is
		# a picture of the common case rather than of a tail.
		var tier := Hit.Tier.LIGHT
		if odds.x >= 0.5:
			tier = Hit.Tier.KNOCKDOWN
		elif odds.y - odds.x >= 1.0 - odds.y:
			tier = Hit.Tier.HEAVY
		# The pool comes from under him; everything else comes from the boss,
		# which is in front.
		var from := hero.global_position
		if String(beat["shape"]) != String(BossDb.SHAPE_ZONE):
			from = hero.global_position + K.flat(-cam.global_transform.basis.z) * REACH
		hit.from = from
		_force(hit, tier)
		await _throw(rig, hero, hit, tier, out, "struck_a_%s" % id)
		print("A %-14s force %.2f  tier %s  odds %.0f/%.0f/%.0f" % [
			id, hit.force(), _tier_name(tier),
			(1.0 - odds.y) * 100.0, (odds.y - odds.x) * 100.0, odds.x * 100.0])


# --- B: the three tiers, everything else held equal --------------------------

## One beat, three reactions. The comparison A cannot make, because in A the
## force and the bearing move with the tier.
func _tiers(rig, hero: Node3D, out: String) -> void:
	var cam := rig.root.get_viewport().get_camera_3d() as Camera3D
	if cam == null:
		return
	var beat := BossDb.beat(BOSS, &"cistern_drop")
	var moved := {}
	for tier in [Hit.Tier.LIGHT, Hit.Tier.HEAVY, Hit.Tier.KNOCKDOWN]:
		var hit := _price(beat)
		hit.from = hero.global_position + K.flat(-cam.global_transform.basis.z) * REACH
		_force(hit, tier)
		moved[tier] = await _throw(rig, hero, hit, tier, out,
			"struck_b_%s" % _tier_name(tier))
		print("B %-10s moved %.2f m" % [_tier_name(tier), moved[tier]])

	# **The shove has to SURVIVE, and this is the check that says it did.**
	# `Hero._enter_hurt` ends by zeroing `_speed`, so the first cut of `take_hit`
	# wrote the knockback one line before it was deleted and the hero was knocked
	# flat on the spot he had been standing on -- which reads as fainting rather
	# than as being hit, and which no frame of the sheet above would have
	# caught, because a man on the floor looks like a man on the floor.
	#
	# `MIN_KNOCKDOWN_TRAVEL` and its opposite bound on LIGHT are the pair: a
	# knockdown must haul him somewhere, and a jab must not, or the light hit has
	# quietly taken the stick off the player.
	if float(moved[Hit.Tier.KNOCKDOWN]) < MIN_KNOCKDOWN_TRAVEL:
		rig.fail("B knockdown moved him %.2f m, wanted at least %.2f -- the shove "
			% [moved[Hit.Tier.KNOCKDOWN], MIN_KNOCKDOWN_TRAVEL]
			+ "is being zeroed after it is written")
		_fails += 1
	if float(moved[Hit.Tier.LIGHT]) > MAX_LIGHT_TRAVEL:
		rig.fail("B light moved him %.2f m, wanted under %.2f -- a jab is not "
			% [moved[Hit.Tier.LIGHT], MAX_LIGHT_TRAVEL]
			+ "supposed to take the stick away")
		_fails += 1


# --- C: does the lurch point the right way? ----------------------------------

## **The known-answer calibration, and the only reason to believe any frame
## above.** CLAUDE.md §2: a director that has never been pointed at an answer you
## already have has never been tested, and this one is claiming to see a shove of
## a fraction of a unit in a frame that is also shaking.
##
## Four blows from the four screen quadrants and one control:
##
##   from the LEFT of frame    the view must lurch RIGHT   (h_offset > 0)
##   from the RIGHT of frame   ...LEFT                     (h_offset < 0)
##   from AHEAD of the camera  the view must DIP           (v_offset < 0)
##   from BEHIND the camera    ...LIFT                     (v_offset > 0)
##   no blow at all            neither, within a pixel     (the null case)
##
## Those signs are the DESIGN -- `Feel.punch`'s header states them in prose and
## `Hud._on_hero_struck` shares the ahead-is-up convention -- so they are an
## answer known before the run rather than a restatement of the arithmetic.
##
## **The shake is switched off for the measurement and the punch is not.** That
## is not a convenience: `Feel.punch` documents that it is deliberately outside
## `Settings.camera_shake` because direction is information rather than garnish,
## and this is what checks that claim. With the shake gated off, anything left on
## `h_offset` is the lurch. Trauma is zero-mean noise at up to `MAX_OFFSET` 1.4,
## which is larger than the whole signal -- measuring through it would be reading
## the shake and calling it the punch.
func _directions(rig, hero: Node3D, out: String) -> void:
	var cam := rig.root.get_viewport().get_camera_3d() as Camera3D
	if cam == null:
		return
	var was := Settings.camera_shake
	Settings.camera_shake = 0.0

	var beat := BossDb.beat(BOSS, &"cistern_drop")
	var b := cam.global_transform.basis
	var cases := [
		{"n": "left", "d": -b.x, "axis": "h", "want": 1.0},
		{"n": "right", "d": b.x, "axis": "h", "want": -1.0},
		{"n": "ahead", "d": -b.z, "axis": "v", "want": -1.0},
		{"n": "behind", "d": b.z, "axis": "v", "want": 1.0},
	]
	for c in cases:
		var hit := _price(beat)
		hit.from = hero.global_position + K.flat(c["d"]) * REACH
		# LIGHT so his body stays upright: a knockdown moves the hero, the camera
		# chases him, and the offset would then be measuring the follow.
		_force(hit, Hit.Tier.LIGHT)
		Game.quarters = Game.max_quarters
		hero.take_hit(hit)
		# **TWO frames, and the second one is not slack.** `SceneTree.process_frame`
		# is emitted at the TOP of an idle frame, before any node's `_process` --
		# and `Feel` writes the offsets from `_process`. So a single
		# `wait_frames(1)` reads the camera one frame BEFORE the lurch is applied,
		# and reads exactly 0.000.
		#
		# It read 0.967 anyway for the first case in this loop and 0.000 for the
		# other three, which is the shape of the bug worth remembering: where you
		# resume from decides what "one frame" means. Case one resumed from a
		# `process_frame` await and so spent a whole frame inside `take_hit`'s;
		# cases two to four resumed from `wait_seconds`, whose SceneTree timer
		# fires AFTER node processing, so their one frame was the empty half.
		# An instrument that passes its first row and fails the rest is reporting
		# on its own await points, not on the game (CLAUDE.md §2).
		#
		# Two frames costs ~0.06 of the lurch to decay -- `K.HURT_PUNCH_TIME` is
		# 0.30 s -- which is nothing against a `LURCH` bar of 0.08.
		await rig.wait_frames(2)
		var got: float = cam.h_offset if c["axis"] == "h" else cam.v_offset
		var want: float = c["want"]
		if got * want < LURCH:
			rig.fail("C blow from %s moved %s_offset to %+.3f, wanted %s%.2f"
				% [c["n"], c["axis"], got, "> +" if want > 0.0 else "< -", LURCH])
			_fails += 1
		print("C from %-7s h=%+.3f v=%+.3f  (%s)" % [
			c["n"], cam.h_offset, cam.v_offset, c["axis"]])
		if c["n"] == "left" or c["n"] == "right":
			await rig.capture(out.path_join("struck_c_%s.png" % c["n"]))
		await rig.wait_seconds(BETWEEN)

	# The null. Nothing has been thrown for `BETWEEN` seconds, so both offsets
	# must be home -- an instrument that reads a lurch when there is none would
	# have passed every row above by leaning one way permanently.
	if absf(cam.h_offset) > 0.01 or absf(cam.v_offset) > 0.01:
		rig.fail("C null case: camera resting at h=%+.3f v=%+.3f, not home"
			% [cam.h_offset, cam.v_offset])
		_fails += 1
	print("C null    h=%+.3f v=%+.3f" % [cam.h_offset, cam.v_offset])
	Settings.camera_shake = was


# --- Plumbing ----------------------------------------------------------------

## A blow priced exactly as `Boss._land` prices one.
##
## Spelled out rather than delegated to the boss. A director that asks the game
## for the answer cannot catch the game getting it wrong -- it would print
## whatever the shipping code believes. `hurt_table.gd` carries the same
## duplication for the same reason, and its header says so.
func _price(b: Dictionary) -> Hit:
	var row: Dictionary = BossDb.BOSSES[BOSS]
	var top := 0.01
	for other in BossDb.beats(BOSS):
		top = maxf(top, Hit.severity_of(int(other["damage"]),
			float(other["knockback"])))
	var rel := Hit.severity_of(int(b["damage"]), float(b["knockback"])) / top
	return Hit.make(int(b["damage"]), Vector3.ZERO, &"contact",
		float(b["knockback"]), float(b["stun"]), BOSS,
		float(row["height"]) / K.LAUNCH_MASS_REF,
		0.6 + 0.4 * clampf(rel, 0.0, 1.0))


## Pin a blow to one reaction through the schema's own override pair.
func _force(hit: Hit, tier: Hit.Tier) -> void:
	hit.odds_knockdown = 1.0 if tier == Hit.Tier.KNOCKDOWN else 0.0
	hit.odds_stagger = 1.0 if tier == Hit.Tier.HEAVY else 0.0


## Land `hit` and photograph it: the impact frame and the two after it, which is
## the card's wording, plus two more that the card's wording does not get you.
##
## **All three of the card's frames are inside the hit-stop, and that is not a
## flaw in the sheet -- it is what the player sees.** The stop is 3 to 9 frames
## depending on `Hit.force`, so "the two frames after impact" are frozen ones by
## construction. They are not three copies of one picture: `Feel._tick_shake`
## walks the shake and bleeds the lurch off the WALL clock precisely so a frozen
## frame still moves, and the camera is the only thing moving in them.
##
## What they cannot show is his BODY, because the AnimationTree runs on the game
## clock and the game clock is stopped. So:
##
##   `_react`   45% of the way through this tier's own reaction, in GAME time --
##              `wait_seconds` is scaled, so it waits out the stop first and
##              lands mid-clip whatever the stop was. This is the flinch / the
##              stagger / the fall, and it is the frame that answers the card.
##   `_settle`  0.9 s, by which point the camera is home and a LIGHT is over. A
##              knockdown is still on the floor here, which is the whole point of
##              it -- the reaction outlives the effect.
## Returns how far the blow actually MOVED him, on the flat, by the settle frame.
func _throw(rig, hero: Node3D, hit: Hit, tier: Hit.Tier, out: String,
		stem: String) -> float:
	Game.quarters = Game.max_quarters
	var stood_at := hero.global_position
	hero.take_hit(hit)
	for i in 3:
		await rig.capture(out.path_join("%s_%d.png" % [stem, i]))
	await rig.wait_seconds(_react_time(tier) * 0.45)
	await rig.capture(out.path_join("%s_react.png" % stem))
	await rig.wait_seconds(K.HURT_PUNCH_TIME * 3.0)
	await rig.capture(out.path_join("%s_settle.png" % stem))
	# `K.plane` and NOT `K.flat`, which normalises. This measurement read exactly
	# 1.0000 m for a heavy AND for a knockdown before the fix -- two different
	# blows agreeing to four decimal places is an instrument reporting on itself,
	# and `K.flat`'s own header names this as the trap that has now cost the
	# project four bugs (CLAUDE.md §2: the director is the first suspect).
	var moved := K.plane(hero.global_position - stood_at).length()
	await rig.wait_seconds(BETWEEN)
	return moved


## How long this tier's reaction runs, from `K`.
func _react_time(t: Hit.Tier) -> float:
	match t:
		Hit.Tier.KNOCKDOWN:
			return K.KNOCKDOWN_DOWN_TIME
		Hit.Tier.HEAVY:
			return K.HURT_HEAVY_TIME
		_:
			return K.HURT_LIGHT_TIME


func _tier_name(t: Hit.Tier) -> String:
	match t:
		Hit.Tier.KNOCKDOWN:
			return "knockdown"
		Hit.Tier.HEAVY:
			return "heavy"
		_:
			return "light"


func _hero(rig) -> Node3D:
	var found: Array = rig.get_nodes_in_group(&"player")
	return found[0] as Node3D if not found.is_empty() else null
