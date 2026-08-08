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
	Bus.prompt_changed.emit("")


func _process(delta: float) -> void:
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	var best := _nearest(hero)

	if best != focus:
		drop_focus()
		focus = best
		if focus != null:
			focus.on_focus(true)
			Bus.prompt_changed.emit("(E) %s" % focus.prompt)

	var down := Input.is_action_pressed(&"interact")
	if not down:
		_armed = true
		if _hold > 0.0:
			_hold = 0.0
			if focus != null:
				focus.on_hold(0.0)

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
		it.on_hold(0.0)
		it.activate(hero)
	else:
		focus.on_hold(clampf(_hold / focus.hold_time, 0.0, 1.0))


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
