extends Node
## Autoload `Prompt`. Decides which Interactable the player is addressing, and
## owns the interact button so exactly one thing answers it.
##
## Nearest-wins, measured from the hero rather than from the camera: the player's
## mental model of "the thing I am at" is a body-space one, and a camera-space
## rule picks the chest behind the vendor whenever you look past them.
##
## Input is blocked while a full-screen UI is up. Without that, closing the vendor
## screen with the same button that opened it re-opens it on the next frame.
##
## Blocking is DERIVED from a list of live blocker nodes, not a latch. A latch is
## one missed `= false` away from a game where nothing can ever be interacted with
## again, and the miss is always in the error path -- a screen freed by a scene
## change, a node that errored before its cleanup ran. Here a blocker that leaves
## the tree stops blocking whether or not anyone remembered to say so.

var focus: Interactable = null

## True while a screen owns input. Assigning it is the fade's blunt override;
## screens should call `block`/`unblock` instead so their claim expires with them.
var blocked: bool:
	get:
		_prune()
		return _override or not _blockers.is_empty()
	set(v):
		_override = v
		if blocked:
			drop_focus()

## True while a full-screen UI is actually up — the shop, the stash, the run
## summary. NOT true during a fade, which is the whole point of it being separate
## from `blocked`: a transition blocks interaction, but it is not a screen you
## can be standing in, and the two callers who ask this question want the
## difference.
##
##   - `PauseMenu` refuses to OPEN while one of these is up. Escape is bound to
##     both `pause` and `ui_cancel`, and every one of these screens closes on
##     either — so without this the one press that closes the shop also opens
##     the pause menu behind it.
##   - The cursor is handed back for exactly as long as one of these is up.
var screen_up: bool:
	get:
		_prune()
		return not _blockers.is_empty()

var _items: Array[Interactable] = []
var _blockers: Array[Node] = []
var _override: bool = false
var _hold: float = 0.0

## True once the interact button has been seen UP. Nothing activates until then.
##
## Edge-detected on RELEASE rather than on press, which is not the obvious way
## round. `is_action_just_pressed` is true for exactly one frame and is stamped
## with the frame the press arrived in, so a poller can miss the edge outright --
## and a missed edge here is not a dropped tap, it is a hold that can never begin
## however long the button stays down. Watching for the button to come up costs
## one bool and there is no frame to miss.
##
## It also gives the behaviour the gate needs for free: the 0.9 s press that
## opens the gate is still down when the dungeon finishes loading, and the
## entrance pad is the thing you spawn on. Disarming on activate means you have
## to let go before the next world can take the same press.
var _armed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# The line names a button, so it has to be re-said when the button changes
	# under it. Nothing else about the focus moves — the same thing is still in
	# reach, it is just reached with a different thumb.
	Bus.input_device_changed.connect(func(_pad: bool) -> void: _say_prompt())


## Claim input for `by`, for exactly as long as `by` is in the tree.
func block(by: Node) -> void:
	if by != null and not _blockers.has(by):
		_blockers.append(by)
	drop_focus()


func unblock(by: Node) -> void:
	_blockers.erase(by)


func _prune() -> void:
	for i in range(_blockers.size() - 1, -1, -1):
		var b: Node = _blockers[i]
		if not is_instance_valid(b) or not b.is_inside_tree():
			_blockers.remove_at(i)


func register(it: Interactable) -> void:
	if not _items.has(it):
		_items.append(it)


func unregister(it: Interactable) -> void:
	_items.erase(it)
	if focus == it:
		drop_focus()


## THERE WAS AN ARBITRATION HERE AND IT IS GONE. `claims_press` and
## `claims_hold` answered "does the thing in reach own this press, or does the
## dodge?", because for one layout `interact` and `context` were both A/Cross and
## a player at the smith could not be allowed to roll into him. The dodge is B
## now (see the `context` note in project.godot) and the two share nothing on any
## device, so the question has no content left: this node activates what is
## focused off `interact`, `Hero` rolls off `context`, and neither has to ask the
## other anything.
##
## Recorded rather than deleted silently because the layout has moved before and
## could move again — if a future pass puts two verbs back on one button, this
## pair is the shape the answer took, and `Hero._try_start_roll` /
## `Hero._tick_context` were the only callers.


## Let go of whatever is focused, telling it so. Safe to call on nothing.
func drop_focus() -> void:
	if focus == null:
		return
	if is_instance_valid(focus):
		if focus.hold_time > 0.0:
			focus.on_hold(0.0)
		focus.on_focus(false)
	focus = null
	_hold = 0.0
	_armed = false
	Bus.hold_changed.emit(0.0, false)
	Bus.prompt_changed.emit("")


## The one place `_hold` moves, so the prop's own tell (`on_hold`) and the HUD's
## gauge (`Bus.hold_changed`) can never disagree about how far along the player
## is. They are two channels for one number and they are set together or not at
## all: the gate's glow saying 90% while the bar says 40% is worse than either
## alone, because the player believes the diegetic one.
##
## Emitted every frame of a hold rather than on a threshold. This is a bar that
## fills; a bar that updates in steps reads as a stutter, and `Bus` traffic at
## the frame rate for the fraction of a second something is being held is not a
## cost worth optimising against a player who thinks the game is dropping frames.
func _set_hold(t01: float) -> void:
	var required := focus != null and is_instance_valid(focus) and focus.hold_time > 0.0
	if required:
		focus.on_hold(t01)
	Bus.hold_changed.emit(t01 if required else 0.0, required)


func _process(delta: float) -> void:
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	var best := _nearest(hero)
	var down := Input.is_action_pressed(&"interact")

	if best != focus:
		drop_focus()
		focus = best
		if focus != null:
			# **A button that was already down is not a press for something that
			# has only just come into reach.** `drop_focus` cannot say this: it
			# returns early when there was nothing focused to drop, which is
			# exactly this case. The press that DISMISSES a dialogue box is still
			# down on the frame the box frees itself, the block comes off, and the
			# keeper standing behind it becomes reachable again -- so without this
			# the one press both ends the conversation and starts it over. It read
			# as "the box will not go away".
			_armed = not down
			focus.on_focus(true)
			_say_prompt()
			# Empty track up immediately: standing at a hold-gated thing is when
			# the player needs to know it is one, not after a tap did nothing.
			_set_hold(0.0)

	if not down:
		_armed = true
		if _hold > 0.0:
			_hold = 0.0
			_set_hold(0.0)

	if focus == null or not _armed or not down:
		return

	if focus.hold_time <= 0.0:
		_armed = false
		focus.activate(hero)
		return

	# Releasing early snaps the ring back to zero rather than decaying it: a
	# decaying ring says "keep going", and the player did the opposite.
	_hold += delta
	if _hold >= focus.hold_time:
		var it := focus
		_hold = 0.0
		_armed = false
		_set_hold(0.0)
		it.activate(hero)
	else:
		_set_hold(clampf(_hold / focus.hold_time, 0.0, 1.0))


## "E TO TALK", or "Y TO TALK" on a pad. The button is read off the live InputMap
## through `Glyph` rather than written into the string: `interact` moved from A
## to Y when the pad layout changed, and a hardcoded "(E)" was the last thing in
## the game still claiming a keyboard was the only way to open a chest.
##
## "E TO TALK" and not "(E) TALK", because the line is read, not parsed. The
## bracket form is a keycap notation -- it asks the player to know the convention
## before it tells them anything -- while the sentence form is the instruction
## itself, and it costs three characters on the one line the HUD centres.
##
## **"HOLD" IS NOT DECORATION.** An Interactable with `hold_time` does nothing at
## all for a tap, and it does it silently -- there is no refusal, no beep, no
## error. The garrison gate is the only one in the game, and it is also the door
## out of the hub, so the one prompt in the project that had to say how to press
## it was the one prompt that could strand a player. It read "A TO DESCEND", a
## player tapped A at it, and the honest bug report that came back was "A to
## descend doesn't work". Read off `hold_time` rather than written per prop, so
## the next Interactable that grows a hold cannot forget to say so.
func _say_prompt() -> void:
	if focus == null or not is_instance_valid(focus):
		return
	var cap := Glyph.cap(&"interact")
	if cap.is_empty():
		Bus.prompt_changed.emit(focus.prompt)
		return
	var form := "HOLD %s TO %s" if focus.hold_time > 0.0 else "%s TO %s"
	Bus.prompt_changed.emit(form % [cap, focus.prompt])


func _nearest(hero: Node3D) -> Interactable:
	if blocked or hero == null:
		return null
	var best: Interactable = null
	var best_d := INF
	for it in _items:
		if not is_instance_valid(it) or not it.enabled or not it.player_inside:
			continue
		var d := hero.global_position.distance_squared_to(it.global_position)
		if d < best_d:
			best_d = d
			best = it
	return best
