extends RefCounted
## Every blow the player can take, priced through `Hit.tier_odds`.
##
## Card #130 chooses one of three reactions -- flinch, stagger, knocked flat --
## from the attacker's heft and the move's commitment, and a curve fitted on a
## whiteboard is a curve nobody has checked against the roster. This prints the
## whole table so the fit can be read against the rows it was solved for:
##
##   goblin        light 90 / heavy 10 / knockdown  0
##   orc           light 64 / heavy 33 / knockdown  3
##   troll         light 39 / heavy 54 / knockdown  8
##   troll/heavy   light 29 / heavy 36 / knockdown 35
##
## **Those rows ARE the known answer** (CLAUDE.md §2). If they come out at
## anything else, the numbers in `K` have been moved without being re-fitted and
## every other row on the table is a guess.
##
## Three structural checks ride alongside them, and they matter more than the
## percentages because they are the owner's design in a form arithmetic cannot
## drift out of:
##
##   * nothing the hero's own size or smaller may EVER floor him -- goblin,
##     kobold and skeleton must read exactly 0, not "nearly 0";
##   * no ordinary roster body may floor him more often than not;
##   * every boss's heaviest beat MUST usually floor him, or the telegraph the
##     whole fight is built around is not worth reading.
##
## A DIRECTOR and not a `-s` SceneTree script, which is what it was first, and
## the reason is worth keeping: `BossDb` depends on `relic_db` and `story_db`,
## which reference the `Game` and `Run` autoloads, and autoloads are not
## registered for a bare `-s` run (CLAUDE.md §3's `--check-only --script` row is
## the same trap). The compile failed, `for id in BossDb.BOSSES` iterated an
## unusable class, and the twelve boss rows -- the half the whole card is about
## -- SILENTLY printed nothing while the roster half looked perfectly healthy.
##
## Headless is correct here and is not the "never pass --headless" trap: this
## renders nothing and captures nothing, so there is no empty frame to be fooled
## by.
##
##   godot --path . --headless -s tools/shoot.gd -- \
##     --scene=res://scenes/_smoke.tscn \
##     --director=res://tools/directors/hurt_table.gd --frames=0

## The two rows the curves were solved for, as percentages, and the slack allowed
## against them. Two points of a percent -- the constants carry four figures, so
## anything looser would let a real re-fit through.
const ANCHORS := {
	&"goblin": Vector3(90.0, 10.0, 0.0),
	&"orc": Vector3(64.0, 33.0, 3.0),
	&"troll": Vector3(39.0, 54.0, 8.0),
	&"troll/heavy": Vector3(29.0, 36.0, 35.0),
}
const TOL := 2.0
## A boss's heaviest beat has to be the thing that puts you down.
const BOSS_HEAVIEST_MIN_KD := 50.0

var _fails: int = 0


func run(rig) -> void:
	print("%-32s %4s %6s %6s %6s %6s | %5s %5s %5s" % [
		"blow", "dmg", "knock", "mass", "commit", "force",
		"light", "heavy", "knock"])
	print("-".repeat(94))

	for kind in Enemy.DEFS:
		var d: Dictionary = Enemy.DEFS[kind]
		var mass := float(d["height"]) / K.LAUNCH_MASS_REF
		# Spelled again rather than calling `Hit.commitment_of_tell`, for the
		# same reason the boss half below respells `Boss._commitment`: a director
		# that asks the game for the answer prints whatever the game believes.
		var commit: float = K.COMMIT_LIGHT + (1.0 - K.COMMIT_LIGHT) * clampf(
			(float(d["windup"]) - K.COMMIT_TELL_MIN)
			/ (K.COMMIT_TELL_MAX - K.COMMIT_TELL_MIN), 0.0, 1.0)
		var hit := Hit.make(int(d["damage"]), Vector3.ZERO, &"contact",
			K.KNOCKBACK_LIGHT, 0.0, kind, mass, commit)
		hit.odds_knockdown = float(d.get("knockdown", -1.0))
		hit.odds_stagger = float(d.get("stagger", -1.0))
		var got := _row(String(kind), hit)
		if ANCHORS.has(kind):
			_check(rig, String(kind), got, ANCHORS[kind])
		# The second beat, for the kinds that have one. Same row, same body, the
		# heavy's own numbers -- and NOT subject to the two design rules below,
		# which are about a monster's ORDINARY swing. A telegraphed heavy is
		# allowed to floor you; that is what it is for.
		var hv: Dictionary = d.get("heavy", {})
		if not hv.is_empty():
			var hcommit: float = K.COMMIT_LIGHT + (1.0 - K.COMMIT_LIGHT) * clampf(
				(float(hv.get("windup", d["windup"])) - K.COMMIT_TELL_MIN)
				/ (K.COMMIT_TELL_MAX - K.COMMIT_TELL_MIN), 0.0, 1.0)
			var hhit := Hit.make(int(hv.get("damage", d["damage"])), Vector3.ZERO,
				&"contact", float(hv.get("knockback", K.KNOCKBACK_LIGHT)), 0.0,
				kind, mass, hcommit)
			var hgot := _row("%s/heavy" % kind, hhit)
			var hkey := StringName("%s/heavy" % kind)
			if ANCHORS.has(hkey):
				_check(rig, String(hkey), hgot, ANCHORS[hkey])
			if hgot.z <= got.z:
				rig.fail("%s's heavy floors the hero %.1f%% against its ordinary swing's %.1f%% -- a second beat the player answers the same way is not a second beat"
					% [kind, hgot.z, got.z])
				_fails += 1
		# The design, not the fit. A body no heavier than the hero cannot put him
		# on the ground -- if this ever reads 0.4% instead of 0, the floor in
		# `K.KNOCKDOWN_MASS_FLOOR` has stopped being a statement.
		if mass <= K.KNOCKDOWN_MASS_FLOOR and got.z != 0.0:
			rig.fail("%s is no heavier than the hero and still floors him %.1f%% of the time"
				% [kind, got.z])
			_fails += 1
		if got.z > 50.0:
			rig.fail("%s floors the hero %.1f%% of the time -- a roster body's ordinary swing may not be a knockdown more often than not"
				% [kind, got.z])
			_fails += 1

	# The boss half, which is the half that was silently empty. Fail if it is
	# empty again rather than printing a shorter table that still looks fine.
	print("")
	var beats := 0
	for id in BossDb.BOSSES:
		var row: Dictionary = BossDb.BOSSES[id]
		var mass := float(row["height"]) / K.LAUNCH_MASS_REF
		# The same normalisation `Boss._commitment` does, spelled again because a
		# director that asks the game the answer cannot catch the game getting it
		# wrong -- it would print whatever the shipping code believes.
		var top := 0.01
		for b in BossDb.beats(id):
			top = maxf(top, Hit.severity_of(int(b["damage"]), float(b["knockback"])))
		var heaviest_kd := 0.0
		for b in BossDb.beats(id):
			if int(b["damage"]) <= 0:
				continue
			var rel := Hit.severity_of(int(b["damage"]), float(b["knockback"])) / top
			var hit := Hit.make(int(b["damage"]), Vector3.ZERO, &"contact",
				float(b["knockback"]), float(b["stun"]), id, mass,
				0.6 + 0.4 * clampf(rel, 0.0, 1.0))
			var got := _row("%s/%s" % [id, b["id"]], hit)
			heaviest_kd = maxf(heaviest_kd, got.z)
			beats += 1
		if heaviest_kd < BOSS_HEAVIEST_MIN_KD:
			rig.fail("%s's heaviest beat only floors the hero %.1f%% of the time -- a telegraph nobody has to respect"
				% [id, heaviest_kd])
			_fails += 1
	if beats == 0:
		rig.fail("no boss beats priced -- BossDb did not load")
		_fails += 1

	if _fails == 0:
		print("HURT TABLE OK -- %d anchors within %.0f pt, and the design holds"
			% [ANCHORS.size(), TOL])


func _row(label: String, hit: Hit) -> Vector3:
	var o := hit.tier_odds()
	var got := Vector3((1.0 - o.y) * 100.0, (o.y - o.x) * 100.0, o.x * 100.0)
	print("%-32s %4d %6.1f %6.2f %6.2f %6.2f | %4.0f%% %4.0f%% %4.0f%%" % [
		label.substr(0, 32), hit.amount, hit.knockback, hit.mass, hit.commitment,
		hit.force(), got.x, got.y, got.z])
	return got


func _check(rig, label: String, got: Vector3, want: Vector3) -> void:
	if absf(got.x - want.x) <= TOL and absf(got.y - want.y) <= TOL \
			and absf(got.z - want.z) <= TOL:
		return
	rig.fail("%s is %.0f/%.0f/%.0f, authored as %.0f/%.0f/%.0f" % [
		label, got.x, got.y, got.z, want.x, want.y, want.z])
	_fails += 1
