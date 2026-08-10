extends RefCounted
## The front door: the title screen, and the opening it starts.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/ui/title/title_screen.tscn \
##     --director=res://tools/directors/title.gd \
##     --out=/tmp/title/x.png --warmup=30
##
## What it claims, in the order it proves them:
##
##   A  The title screen draws: the painting is a real texture, the name is on
##      it, and there are three buttons.
##   B  CONTINUE agrees with the disk. No slot on a fresh `user://` means the row
##      is disabled AND unfocusable, and focus has landed on NEW GAME instead.
##   C  Pressing NEW GAME clears `Game`, raises the cutscene over the garrison,
##      and holds the world stopped while it plays.
##   D  The cutscene says both lines, in order, with the narrator's take under
##      them, and the second line is the one the FIRST line's clip pays for --
##      the split.
##   E  The score changes rooms with the picture: TITLE on the menu, PROLOGUE
##      under the narration, CALM once the courtyard is up.
##   F  It ends in the garrison, on a lifted screen, with the hero in the tree.
##
## Beat E is the one worth the harness. Three tracks that are all the same file
## is exactly the shape a copy-paste in `Music.POOLS` takes, and it is inaudible
## in a screenshot.

const TITLE_SCENE := "res://scenes/ui/title/title_screen.tscn"

## `rig` is `tools/shoot.gd` and arrives untyped, so EVERY value read off it is a
## Variant and every `:=` against one fails to infer. Annotate, do not infer --
## it is the same rule CLAUDE.md §3 gives for indexing an untyped const
## Dictionary, arriving from the other direction.
var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/title/x.png").get_base_dir()

	await _menu(rig)
	await _opening(rig)

	if _fails == 0:
		print("TITLE OK")
	else:
		print("TITLE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("TITLE FAIL %s" % label)


# --- A + B. The menu ---------------------------------------------------------

func _menu(rig) -> void:
	var screen: Node = rig.scene()
	_ck("A the title screen is the scene", screen is TitleScreen)

	var plate := screen.get_node_or_null(^"Plate") as TextureRect
	_ck("A the painting loaded", plate != null and plate.texture != null)

	var menu: Node = screen.get_node_or_null(^"Menu")
	_ck("A three buttons", menu != null and menu.get_child_count() == 3)
	if menu == null:
		return

	var labels: Array[String] = []
	for b in menu.get_children():
		labels.append((b as Button).text)
	_ck("A the three are CONTINUE / NEW GAME / QUIT",
		labels == ["CONTINUE", "NEW GAME", "QUIT"])

	# The harness runs on a scratch `user://` with no saves in it, so this is the
	# cold-boot case: nothing to continue to.
	var any_save := false
	for i in Saves.SLOTS:
		any_save = any_save or Saves.has_save(i)
	var cont := menu.get_child(0) as Button
	_ck("B CONTINUE matches the disk (saves=%s)" % any_save,
		cont.disabled == not any_save)
	if not any_save:
		# Both, not just `disabled`: a disabled row that can still take focus is a
		# row gamepad navigation stops on and cannot leave.
		_ck("B and it is unfocusable", cont.focus_mode == Control.FOCUS_NONE)
		_ck("B focus is on NEW GAME", (menu.get_child(1) as Button).has_focus())

	_ck("E the score is the overture", Music.mood_name() == "TITLE")
	await rig.capture("%s/01_title.png" % out)


# --- C..F. The opening -------------------------------------------------------

func _opening(rig) -> void:
	# Straight at `Flow` rather than at the button, deliberately: `Input.action_press`
	# dispatches no InputEvent (CLAUDE.md §3) so a synthesised click is not a
	# press, and what is under test here is the transition, not the Button class.
	Game.set_flag(&"reported_for_duty")
	Flow.new_game()

	var up: bool = await rig.until(func() -> bool:
		return _cutscene(rig) != null, 6.0)
	_ck("C the cutscene came up", up)
	var cut := _cutscene(rig)
	if cut == null:
		return

	_ck("C a new game cleared the flags",
		not Game.flag(&"reported_for_duty"))

	# It is built BEHIND the picture, so the garrison must already be the scene.
	await rig.until(func() -> bool:
		return _here(rig).contains("garrison"), 6.0)
	_ck("C the garrison is built behind it",
		_here(rig).contains("garrison"))
	# `until`, not a bare read: `Flow.new_game` stops the tree two frames AFTER
	# the scene change, so the check above returns true first and a straight
	# assertion here reports a pause that simply has not happened yet.
	var stopped: bool = await rig.until(func() -> bool: return rig.paused, 3.0)
	_ck("C and it is stopped while the opening plays", stopped)

	var line := cut.get_node_or_null(^"Line") as Label
	_ck("D there is a line on screen", line != null and not line.text.is_empty())
	if line == null:
		return

	var first := line.text
	_ck("D beat 1 is Kael on the road", first.contains("Kael"))
	_ck("D the narrator is saying it", Voice.line() == "opening")
	_ck("E and the score is the prologue", Music.mood_name() == "PROLOGUE")
	await rig.capture("%s/02_opening_1.png" % out)

	# The take is ~15 s over two beats, so the second line is due at ~7.5 s. Wait
	# for the CHANGE rather than for a number: the split is derived from the
	# clip's real length and hard-coding the halfway point here would make this
	# check pass by agreeing with itself.
	var turned: bool = await rig.until(func() -> bool:
		return line.text != first, 14.0)
	_ck("D beat 2 arrived on the same clip", turned)
	# The text is swapped at alpha 0 and faded up, so the frame the change lands
	# on has the new line on it INVISIBLY -- the first capture here photographed
	# an empty subtitle and looked like a dropped beat.
	await rig.until(func() -> bool: return line.modulate.a > 0.98, 2.0)
	_ck("D beat 2 is the posting to Highbridge",
		line.text.contains("Highbridge"))
	_ck("D the same take is still under it", Voice.line() == "opening")
	await rig.capture("%s/03_opening_2.png" % out)

	# Skip rather than sit through the rest: the timing is already proven and a
	# director is a batch job.
	cut.skip()
	var landed: bool = await rig.until(func() -> bool:
		return not rig.paused and rig.get_first_node_in_group(&"player") != null, 8.0)
	_ck("F it ends in the garrison, running, with a hero", landed)

	# Long enough for `Flow.FADE_IN` plus the `queue_free` chained onto it. Asked
	# AFTER the wait rather than the instant the world resumes, which is a frame
	# before the fade has started and reported a picture still at full alpha.
	await rig.wait_seconds(1.2)
	_ck("F the picture is gone", _cutscene(rig) == null)
	_ck("E the town theme took over", Music.mood_name() == "CALM")
	_ck("E and it is the town track, not the overture",
		Music.current_track().contains("town"))
	await rig.capture("%s/04_garrison.png" % out)


## The live cutscene, or null. It lives on `Flow`'s own CanvasLayer, which is a
## child of the Flow autoload rather than of any scene -- so it survives the
## scene change happening underneath it, which is the whole point of it being
## there.
func _here(rig) -> String:
	var s: Node = rig.current_scene
	return s.scene_file_path if s != null else ""


func _cutscene(rig) -> Cutscene:
	for layer in rig.root.get_node(^"Flow").get_children():
		if layer is CanvasLayer:
			for c in (layer as CanvasLayer).get_children():
				if c is Cutscene:
					return c
	return null
