extends RefCounted
## Proves the score actually plays, and changes when the game does.
##
## Music is the one system a screenshot cannot verify, so this asserts on the
## real thing: that an AudioStreamPlayer on the Music bus is `playing`, that it
## holds a stream from the right pool, that the bus is audible, and that the
## mood flips when a fight starts and settles back when it ends.
##
## It forces `Settings.music_volume` up front. The persisted settings.cfg on
## this machine had `music=0.0` -- written there by critic_menu.gd, which drags
## the slider to zero as a test and saves it to the REAL config. A music test
## that silently passes because the bus is muted is worth nothing.
##
## Run:
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/music_beats.gd \
##     --out=/tmp/music/x.png --warmup=90

var _fails := 0
var _parked: Node3D = null
var _home := Vector3.ZERO


func run(rig) -> void:
	Settings.set_volume(&"Music", 0.8)

	var bus := AudioServer.get_bus_index("Music")
	_ck("A0 a Music bus exists", bus != -1)
	_ck("A1 the Music bus is not muted", not AudioServer.is_bus_mute(bus))

	# --- Ambient: something should be playing, unprompted ---------------------
	# Which mood is correct depends on the room this was pointed at, so read it
	# from the scene rather than hardcoding one and calling the other a failure.
	var scene: Node = rig.current_scene
	var in_town: bool = scene != null and scene.scene_file_path.contains("town")
	var want_calm := "CALM" if in_town else "DELVE"

	await rig.wait_seconds(2.5)

	# A scene with no hero is lookdev or a tool harness. Those stay silent, the
	# same rule the HUD follows -- a monster turntable should not open with the
	# dungeon theme over it.
	if rig.get_first_node_in_group(&"player") == null:
		_ck("B* a heroless scene stays silent (got %s)"
			% _short(Music.current_track()), Music.current_track() == "")
		_ck("B*b and reports SILENT (got %s)" % Music.mood_name(),
			Music.mood_name() == "SILENT")
		if _fails == 0:
			print("MUSIC OK — silent scene, as intended")
		else:
			print("MUSIC FAIL — %d check(s) failed" % _fails)
		return

	_ck("B0 a track is playing unprompted (%s)" % _short(Music.current_track()),
		Music.current_track() != "")
	_ck("B1 the quiet mood matches the room: want %s, got %s"
		% [want_calm, Music.mood_name()], Music.mood_name() == want_calm)
	_ck("B2 the active player is audible, not parked at -60 dB (%.1f dB)"
		% _active_db(), _active_db() > -30.0)

	# --- A fight takes over ---------------------------------------------------
	# Drive a real enemy into CHASE rather than poking the music directly: the
	# thing under test is that the poll notices the roster, not that a setter
	# works.
	var faked := _force_a_chase(rig)
	if faked:
		await rig.wait_seconds(1.5)
		_ck("C0 an engaged enemy switched the score to FIGHT (got %s)"
			% Music.mood_name(), Music.mood_name() == "FIGHT")
		_ck("C1 the fight track came from the combat pool (%s)"
			% _short(Music.current_track()),
			Music.current_track().contains("combat_"))

		# --- and lets go once the fight is over -------------------------------
		_stand_down(rig)
		await rig.wait_seconds(1.0)
		_ck("D0 the fight cue lingers instead of snapping back (still %s)"
			% Music.mood_name(), Music.mood_name() == "FIGHT")
		await rig.wait_seconds(5.0)
		_ck("D1 it settled back to %s once the linger ran out (got %s)"
			% [want_calm, Music.mood_name()], Music.mood_name() == want_calm)
	else:
		print("  --   no enemies in this scene; skipped the fight beats")

	# --- The pause menu must not kill the music -------------------------------
	Menu.open()
	await rig.wait_seconds(1.0)
	_ck("E0 the score keeps playing while paused", Music.current_track() != "")
	Menu.close()

	if _fails == 0:
		print("MUSIC OK — all checks passed")
	else:
		print("MUSIC FAIL — %d check(s) failed" % _fails)


## Start a REAL fight rather than writing `state = CHASE` directly. Aggro is
## `distance <= detect` re-evaluated every tick, so a poked state is back to
## IDLE before the music poll ever sees it -- the first version of this director
## did exactly that and reported the feature broken when it was not. Walking an
## enemy onto the hero makes the roster choose CHASE on its own, which is the
## thing actually under test.
func _force_a_chase(rig) -> bool:
	# Annotated, not inferred: `rig` is untyped, so this call returns Variant and
	# `:=` cannot infer an Array from it (CLAUDE.md §3).
	var es: Array = rig.get_nodes_in_group(&"enemy")
	var hero: Node3D = rig.get_first_node_in_group(&"player")
	if es.is_empty() or hero == null:
		return false
	for e in es:
		if e is Node3D and &"state" in e:
			_parked = e
			_home = e.global_position
			e.global_position = hero.global_position + Vector3(1.5, 0.0, 0.0)
			return true
	return false


## Put it back where it came from and let it lose interest on its own.
func _stand_down(_rig) -> void:
	if _parked != null and is_instance_valid(_parked):
		_parked.global_position = _home


func _active_db() -> float:
	for n in Music.get_children():
		if n is AudioStreamPlayer and n.playing:
			return n.volume_db
	return -999.0


func _short(p: String) -> String:
	return p.get_file() if p != "" else "<silent>"


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("MUSIC FAIL %s" % label)
