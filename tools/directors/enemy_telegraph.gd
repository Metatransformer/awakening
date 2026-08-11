extends RefCounted
## Board card 90: **a monster's wind-up has a noise, and it arrives before the
## blow rather than with it.**
##
## `Enemy._tick_windup` has carried a real visual tell since it was written — the
## body rears `WINDUP_LEAN_DEG` and glows `Pal.RUST`, both eased so the spike
## lands late, both driven from the timer that governs the commit. What it had no
## audio half of: the only sound the fight made was `swing`, emitted on the same
## frame as `_hitbox.activate()`. That is not a warning, it is an impact — by the
## time you hear it the blow is live and `K.PARRY_WINDOW` is already draining,
## and a player looking at any of the other three monsters in the room got
## nothing at all.
##
## THE CLAIM IS AN ORDER, so what this measures is an order. Every
## `Bus.request_sfx` in the run is recorded with the monster's `state` at the
## moment it was emitted, and the beat asserts:
##
##   1. `attack_prepare` is emitted while the monster is in WINDUP.
##   2. `swing` / `swing_heavy` is emitted after it, at the commit.
##   3. There is real time between them — at least half the kind's wind-up. Two
##      sounds a tenth of a second apart are one sound with an echo, and a
##      telegraph you cannot act on is not a telegraph.
##
## **The null case is beat zero and it is not decoration.** For the first stretch
## of the run the hero stands out of reach and the monster is walking, and the
## recorder must show NO `attack_prepare` at all. Without it "the cue fired" is
## unfalsifiable — a recorder wired to the wrong signal, or a sound emitted every
## frame from CHASE, would pass check 1 exactly as loudly. CLAUDE.md §2: an
## instrument that has only ever been pointed at the case it expects to find has
## not been tested.
##
## The ORC, because its wind-up is the longest in the roster at 0.62 s and the
## comment on `Prog.WINDUP_FLOOR` says the telegraph is the one number with a
## hard floor. If the two events are not separable on the orc they are separable
## nowhere.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/enemy_telegraph.gd \
##     --out=/tmp/tele/x.png --warmup=60

## The cue under test, and the two commit sounds it has to come before.
const PREPARE := &"attack_prepare"
const COMMIT: Array[StringName] = [&"swing", &"swing_heavy"]

## How far out of reach the hero stands for the null case. The orc's `reach` is
## 2.0 m and its `detect` is 11.0, so this is "seen, walking, nowhere near able
## to swing" — which is the state that must be silent.
const NULL_GAP := 9.0

var _fails: int = 0
## id -> the monster's state when it was emitted, in order.
var _heard: Array = []
var _foe: Node3D = null


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/tele/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = Vector3(0.0, 0.05, 5.0)
	await rig.wait_frames(10)

	# Recorded from before the monster exists, so the null case covers the whole
	# of its walk in as well as the frames before it spawned.
	Bus.request_sfx.connect(_heard_one)

	_foe = Enemy.new()
	_foe.kind = &"orc"
	_foe.drop_seed = 77
	scene.add_child(_foe)
	# Out of reach and inside detect: it will see the hero and walk, which is the
	# behaviour the null case is about.
	_foe.global_position = Vector3(0.0, 0.05, 5.0 - NULL_GAP)
	Bus.camera_recenter.emit()

	await _the_silence(rig)
	await _the_tell(rig, out)

	Bus.request_sfx.disconnect(_heard_one)
	if _fails == 0:
		print("TELEGRAPH OK")
	else:
		print("TELEGRAPH %d FAILED" % _fails)


func _fail(msg: String) -> void:
	_fails += 1
	print("TELEGRAPH FAIL ", msg)


## Every sound the game asks for, with the monster's state at the time.
##
## The STATE and not just the id, because "a prepare cue was emitted" and "a
## prepare cue was emitted during a wind-up" are different claims and only the
## second one is the card.
func _heard_one(id: StringName, _at: Vector3) -> void:
	var state := -1
	if _foe != null and is_instance_valid(_foe):
		state = int(_foe.state)
	_heard.append({"id": id, "state": state, "ms": Time.get_ticks_msec()})


## Beat zero: out of reach, walking, and SILENT of the cue.
##
## THE RECORDER IS CALIBRATED FIRST, and the first cut of this beat did not do
## that — it printed "0 sounds so far, none of them the cue" and passed, which a
## recorder connected to nothing at all would have printed word for word. A null
## case that cannot tell absence from deafness is not a null case (CLAUDE.md §2).
## So a sound with a known answer is put through it: `pickup`, which is nothing
## to do with combat and cannot be confused with what the beat is looking for.
## Now "no prepare cue" is a reading and not a shrug.
func _the_silence(rig) -> void:
	Bus.request_sfx.emit(&"pickup", _foe.global_position)
	await rig.wait_frames(2)
	var live := false
	for row in _heard:
		if row["id"] == &"pickup":
			live = true
	if not live:
		_fail("the recorder did not hear a sound emitted directly into it —"
				+ " every silence this beat reports would be its own deafness")
		return

	# Long enough to cross most of NULL_GAP at the orc's own speed without
	# arriving — the point is a monster that is awake and moving, not a monster
	# that has not noticed yet.
	for i in 70:
		await rig.wait_frames(1)
		if _foe.state == Enemy.State.WINDUP:
			break
	var early := 0
	for row in _heard:
		if row["id"] == PREPARE:
			early += 1
	if early > 0:
		_fail("%d prepare cues before the monster was ever in reach — the recorder"
				% early + " is hearing something other than a wind-up")
	else:
		print("TELEGRAPH silence: recorder live, %d sounds heard, none the cue"
				% _heard.size())


## The tell itself: the cue, then the commit, with time between them.
func _the_tell(rig, out: String) -> void:
	# Walk the hero into reach by moving the MONSTER, not the hero: the hero is
	# where the camera is framed on, and a beat that shuffles him spends its
	# frames on the camera settling.
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	_foe.global_position = hero.global_position - Vector3(0.0, 0.0, 1.6)

	var windup: float = float(Enemy.DEFS[&"orc"]["windup"])
	var saw := false
	var shots := 0
	for i in 300:
		await rig.wait_frames(1)
		if _foe.state == Enemy.State.WINDUP and not saw:
			saw = true
			# One frame in, and again late. The lean is eased so most of it is in
			# the last third — a single frame at the start of a wind-up
			# photographs a monster standing still, which is the mistake
			# monster_feel's first pass made and its comment records.
			await rig.capture(out.path_join("tele_0_windup_early.png"))
			shots += 1
		if saw and shots == 1 and _foe.state == Enemy.State.STRIKE:
			await rig.capture(out.path_join("tele_1_strike.png"))
			shots += 1
			break
	if not saw:
		_fail("the orc never wound up in 300 frames")
		return

	var prep := -1
	var commit := -1
	for i in _heard.size():
		var row: Dictionary = _heard[i]
		if prep < 0 and row["id"] == PREPARE:
			prep = i
		elif prep >= 0 and commit < 0 and COMMIT.has(row["id"]):
			commit = i

	if prep < 0:
		_fail("the orc wound up and asked for no prepare cue")
		return
	var p: Dictionary = _heard[prep]
	if int(p["state"]) != int(Enemy.State.WINDUP):
		_fail("the prepare cue was emitted in state %d, not WINDUP" % p["state"])
	if commit < 0:
		_fail("the prepare cue fired and no commit sound ever followed it")
		return
	var c: Dictionary = _heard[commit]
	var gap := float(int(c["ms"]) - int(p["ms"])) / 1000.0
	# Half the authored wind-up. Not the whole of it: `Prog.windup_scale`
	# compresses the commit with depth on purpose, and this beat is asserting the
	# two are SEPARABLE, not re-asserting the tuning.
	if gap < windup * 0.5:
		_fail("cue and commit are %.3f s apart against a %.2f s wind-up — one"
				% [gap, windup] + " sound with an echo, not a telegraph")
	else:
		print("TELEGRAPH order: %s (WINDUP) -> %s, %.3f s apart, wind-up %.2f s" % [
			p["id"], c["id"], gap, windup])
