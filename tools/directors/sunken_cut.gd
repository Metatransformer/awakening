extends RefCounted
## Does the game tell you where you are?
##
## The dungeon has a name now -- THE SUNKEN CUT -- and two places say it: the
## loading card `Flow` raises on every way into the dungeon, and the HUD's
## top-left floor card, which announces on arrival and then settles into the
## readout you glance at between rooms.
##
## The failures this exists to catch are the ones that photograph as a working
## game right up until they do not:
##
##   * **The orphan card.** It is an OPAQUE full-screen Control on layer 200. If
##     the fade-out callback ever stops freeing it, the game is a black rectangle
##     with a title on it and no input will get you out. Checked after every
##     arrival, by looking for the node.
##   * **The card that never came.** `_go` decides on the card by comparing the
##     path it was handed against DUNGEON. A path that gains a query string, a
##     second dungeon scene, a caller that reaches past Flow -- any of those and
##     the descent goes quietly back to being a fade.
##   * **The stale number.** The card is built once from `Run.level`, so it is
##     only ever right if the run has already moved when `_go` runs. Read off the
##     live card, not off Prog.
##   * **The announcement nobody sees.** The whole point of `floor_arrived` is
##     that `level_changed` fires a fade and a load-hold too early. If the HUD
##     ever goes back to the earlier signal, the card is dim by the time the
##     player can see it -- which is exactly what the two HUD frames per floor
##     are for. Look at them.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/sunken_cut.gd --out=/tmp/cut/x.png

## Frames to wait for a card to appear or an arrival to land. The transition is
## FADE_OUT + LOAD_HOLD + FADE_IN ~= 2.1 s, so this is a generous multiple of it
## rather than a guess at it.
const PATIENCE := 400

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/cut/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	if Prog.NAME != "THE SUNKEN CUT":
		_fail("the dungeon is called '%s'" % Prog.NAME)

	# Booted straight into the dungeon, which is not a transition -- no card, and
	# the HUD's floor card should be sitting at its settled colour. This is the
	# frame that proves the readout survives its own announcement.
	await rig.capture(out.path_join("cut_00_settled_level1.png"))

	# Two descents, because "every time you go down" is the property and one
	# descent cannot tell a working announcement from a one-shot.
	for i in 2:
		await _descend(rig, out, i)

	# The other way in, and the one a real run starts with. Same `_go`, same
	# decision, and a level that has been reset rather than incremented.
	await _go_home_and_back(rig, out)

	if _fails == 0:
		print("SUNKEN OK")


## One trip down: photograph the card, read what it says, then photograph the
## HUD announcing and the HUD settled.
func _descend(rig, out: String, i: int) -> void:
	var before := Run.level
	Flow.descend()

	var card := await _wait_for_card(rig)
	if card == null:
		_fail("no loading card on the way from level %d to %d" % [before, before + 1])
		return
	await rig.capture(out.path_join("cut_%02d_card_level%d.png" % [i * 3 + 1, before + 1]))

	var want := "LEVEL %d" % (before + 1)
	if String(card.title) != Prog.NAME:
		_fail("the card is titled '%s', not '%s'" % [card.title, Prog.NAME])
	if String(card.level_line) != want:
		_fail("the card says '%s' on the way to floor %d -- wanted '%s'"
			% [card.level_line, before + 1, want])

	if not await _wait_for_arrival(rig, before):
		return
	# The announcement, caught while it is still lit. `Flow` emits floor_arrived
	# on the frame the card starts lifting, so a handful of frames later the
	# world is visible and the top-left is still at full brightness.
	await rig.wait_frames(18)
	await rig.capture(out.path_join("cut_%02d_announce_level%d.png"
		% [i * 3 + 2, Run.level]))

	# Past FLOOR_HOLD + FLOOR_SETTLE (3.3 s), so this is the resting card.
	await rig.wait_seconds(3.6)
	await rig.capture(out.path_join("cut_%02d_settled_level%d.png"
		% [i * 3 + 3, Run.level]))


## Garrison and back, which is how a run actually begins.
##
## The way home is a DEATH and then the ending screen's button, not a bare
## `Flow.to_garrison()`. That shortcut looks equivalent and is not: it leaves
## `Run.in_dungeon` true, so the HUD draws the floor card over the garrison
## square and the controls legend never comes back. Nothing in the game reaches
## the garrison that way -- `to_garrison()` has exactly one caller and it fires
## after `die()` or `extract()` has already ended the run -- so a director that
## used it would be photographing a state the game cannot be in and reporting
## its own shortcut as a HUD bug.
func _go_home_and_back(rig, out: String) -> void:
	Run.die()
	# Flow holds on the killing blow, then pauses the world and raises the
	# receipt. Wait for that rather than for a frame count.
	for _i in PATIENCE:
		await rig.wait_frames(1)
		if Flow.ending:
			break
	await rig.wait_frames(60)
	# What the button does, which is the only way to the garrison there is.
	Flow.to_garrison()
	for _i in PATIENCE:
		await rig.wait_frames(1)
		if not Flow.busy:
			break
	# Garrison is not the dungeon and must NOT get a card -- it is the place you
	# already know, and a loading screen for the hub is a loading screen for
	# nothing.
	await rig.wait_frames(30)
	if _card_node() != null:
		_fail("garrison raised a loading card")
	await rig.capture(out.path_join("cut_07_garrison.png"))

	Flow.enter_dungeon()
	var card := await _wait_for_card(rig)
	if card == null:
		_fail("no loading card on the way in from the garrison")
		return
	if String(card.level_line) != "LEVEL 1":
		_fail("walking in from the garrison announced '%s', not LEVEL 1" % card.level_line)
	await rig.capture(out.path_join("cut_08_card_entry.png"))

	for _i in PATIENCE:
		await rig.wait_frames(1)
		if not Flow.busy and Run.in_dungeon:
			break
	await rig.wait_frames(18)
	await rig.capture(out.path_join("cut_09_announce_entry.png"))


# --- Waiting on the transition ----------------------------------------------

## The card, by node rather than by Flow's private field: what this director is
## checking is that a real opaque Control was really put on the screen.
func _card_node() -> Node:
	return Flow.find_child("LoadingCard", true, false)


func _wait_for_card(rig) -> Node:
	for _i in PATIENCE:
		await rig.wait_frames(1)
		var c := _card_node()
		if c != null:
			return c
	return null


## Wait until the new floor is up AND the card has been freed. The second half is
## the whole check -- a card that is still parented after the fade is a black
## screen the player cannot dismiss.
func _wait_for_arrival(rig, before: int) -> bool:
	for _i in PATIENCE:
		await rig.wait_frames(1)
		if not Flow.busy and Run.level > before:
			break
	if Run.level <= before:
		_fail("the stair from level %d never landed" % before)
		return false
	# Past the fade-in, which is when the callback frees it.
	await rig.wait_seconds(Flow.FADE_IN + 0.3)
	if _card_node() != null:
		_fail("the loading card is still on screen on level %d -- the game is"
			% Run.level + " welded shut behind it")
		return false
	return true


func _fail(msg: String) -> void:
	_fails += 1
	print("SUNKEN FAIL %s" % msg)
