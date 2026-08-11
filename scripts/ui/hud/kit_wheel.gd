class_name KitWheel
extends Control
## The kit wheel's INPUT half: hold LB, point, release.
##
## It draws nothing. `Hud._draw_wheel` does that, on the HUD's one canvas, for
## the same reason every other cell in this game is drawn there — `_note` puts a
## rectangle in `layout_rects()` where a director can find it, `_draw_item_glyph`
## already knows how to put an armament or a bottle in a cell, and a second
## Control painting its own icons would be the second copy of that rule
## (CLAUDE.md §0). What lives here is the state that only exists while the button
## is down, and the input plumbing that keeps the camera out of it.
##
## Three things it is careful about, each of which cost something to find out:
##
##  1. **The mouse is aimed as a VIRTUAL STICK, not as a cursor.** The pointer is
##     captured during play (`GameCamera._settle_pointer`), so there is no screen
##     position to read — `get_mouse_position()` sits in the middle of the window
##     and never moves. Motion is accumulated into `_aim` instead and clamped to
##     the unit circle, which is the same vector the right stick produces and
##     means the sector maths has one input rather than two.
##  2. **`_input`, not `_unhandled_input`, and it marks the motion handled.**
##     That is what stops the camera swinging while the wheel is up: the lens
##     reads `InputEventMouseMotion` in `_unhandled_input`
##     (`GameCamera._apply_look`), which never runs for an event this node has
##     already consumed. The stick half cannot be solved that way — `cam_*` is
##     POLLED, not evented — so `KitWheel.open` is a static the camera asks
##     about. One flag, one reader.
##  3. **The button is read exactly once, on the edge.** `is_action_just_pressed`
##     in `_process` would be the obvious way and it is the wrong one: a director
##     driving this through `rig.hold` dispatches real `InputEvent`s, and the
##     trap table at CLAUDE.md §3 is about exactly the gap between the two. The
##     press and the release are both events here, so a harness that presses the
##     button the way the engine does gets the same wheel the player does.

## How far the stick or the accumulated mouse has to travel before the wheel
## believes the player meant a direction. Matched to the InputMap's own 0.2
## deadzone plus room for a resting thumb: a wheel that latched a sector at 0.2
## would commit whichever way the stick happened to be leaning when LB went down.
const DEADZONE := 0.42

## Mouse travel, in screen pixels, that equals a full stick deflection.
##
## `screen_relative` and not `relative`, for the reason `GameCamera` spells out
## at length: by `_input` the viewport has already divided motion by the canvas
## stretch, so `relative` is in 1280x720 base units rather than in the units the
## hand moved, and the wheel would need a different flick on every window size.
const MOUSE_SPAN := 140.0

## **Is a wheel up right now.** Static because the one thing outside this node
## that has to know is `GameCamera._apply_look`, which polls the right stick and
## would otherwise spin the lens while the player is pointing at a sector — and a
## camera holding a reference to a HUD child, or an autoload invented to carry
## one boolean, are both more machinery than the fact deserves.
##
## There is exactly one KitWheel (the HUD builds it), so a static is not hiding a
## multiplicity. It is cleared in `_close` and in `_exit_tree`, the second of
## which is not belt-and-braces: a scene change while the button is held would
## otherwise leave the camera permanently deaf to its own stick.
static var open: bool = false

## Which sector the player is pointing at, or -1 for "nothing yet" — the wheel
## opens pointing at nothing on purpose, so letting go without moving is a
## cancel rather than a commit to whatever was under the resting thumb.
var sector: int = -1

## The aim, in the same units for both devices: a unit-ish vector, +Y down, the
## way screen space and `Vector2.angle()` both run.
var _aim: Vector2 = Vector2.ZERO


func _ready() -> void:
	name = "KitWheel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# It never wants a click and must never eat one from the world. The motion it
	# consumes is taken in `_input`, which runs before hit-testing and does not
	# care what this filter says.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The HUD is PROCESS_MODE_ALWAYS so its overlay survives a pause; the wheel
	# must not. A pause menu opening over an open wheel would otherwise leave the
	# button held, the sector live, and the release landing behind the panel.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


func _exit_tree() -> void:
	open = false


## The stick, polled, because `cam_*` is an axis and there is no edge to catch.
## Only while the wheel is up — `set_process` is switched with it.
func _process(_delta: float) -> void:
	var stick := Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")
	if stick.length() >= DEADZONE:
		_point(stick)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"kit_wheel") and not event.is_echo():
		_open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released(&"kit_wheel"):
		_close(true)
		get_viewport().set_input_as_handled()
		return
	if not open:
		return
	if event is InputEventMouseMotion:
		# Accumulated, then clamped — a flick past the rim keeps pointing where it
		# was flicked rather than wrapping, and a small correction still moves the
		# selection. Clamping the SUM rather than each event is what makes the
		# second sentence true.
		var mm := event as InputEventMouseMotion
		_point(_aim + mm.screen_relative / MOUSE_SPAN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		# B / Esc while the wheel is up throws the selection away. The wheel is
		# the one hold in the world with no other way out: letting go is a
		# commit, so without this a player who opened it by accident has to pick
		# something. Closed WITHOUT committing, which is the whole point.
		_close(false)
		get_viewport().set_input_as_handled()


## The aim, from either device, reduced to a sector.
func _point(to: Vector2) -> void:
	if not open:
		return
	_aim = to.limit_length(1.0)
	var was := sector
	sector = sector_of(_aim)
	if sector != was:
		# The tick that tells a thumb it crossed a boundary. It is the only
		# feedback a player pointing at the corner of their eye gets, and it is
		# the same cue `_select_blip` gives the D-pad for the same reason.
		Bus.request_sfx.emit(&"ui_move_selection", _hero_at())
		Hud.wake_wheel()


## Which of `Game.WHEEL_SLOTS` sectors a vector points at, or -1 inside the
## deadzone. Static and public: the director calls it to know what it is aiming
## at without having to re-derive the maths it is supposed to be testing.
##
## **Sector 0 is CENTRED on straight up, not started there**, and that is the one
## line of this file worth reading twice. The obvious formula —
## `fposmod(angle + PI/2, TAU)` — puts up on the BOUNDARY between the last sector
## and the first, so the most natural flick a thumb makes is the one that lands
## exactly on a coin toss. The extra half-sector rotates the whole ring so that
## every cell's centre is a direction the hand can actually mean.
static func sector_of(aim: Vector2) -> int:
	var count := Game.WHEEL_SLOTS
	if aim.length() < DEADZONE:
		return -1
	var clockwise_from_top := fposmod(aim.angle() + PI * 0.5 + PI / float(count), TAU)
	return mini(int(floor(clockwise_from_top / TAU * float(count))), count - 1)


## Where a sector's cell sits, as an offset from the wheel's centre in units of
## the ring radius. The HUD lays the cells out with this and the director reads
## it back, so "the third cell is up-right" is one fact rather than two.
static func direction_of(slot: int) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(slot) / float(Game.WHEEL_SLOTS)
	return Vector2(cos(angle), sin(angle))


func _open() -> void:
	if open:
		return
	# Not while a counter or a conversation owns the input. `Prompt.blocked` is
	# the same gate the hero reads, and the HUD is hidden under a full-screen UI
	# anyway — but the button would still be live, and a wheel committing a
	# weapon swap behind the Lanternkeeper's panel is card #48 wearing a hat.
	if Prompt.blocked:
		return
	open = true
	sector = -1
	_aim = Vector2.ZERO
	set_process(true)
	Hud.wake_wheel()


## `commit` is false for the cancel and true for the release. Either way the
## wheel closes and the camera gets its stick back — an early return that left
## `open` true on a refused commit is how a hold turns into a mode.
func _close(commit: bool) -> void:
	if not open:
		return
	var at := sector
	open = false
	sector = -1
	_aim = Vector2.ZERO
	set_process(false)
	if commit and at >= 0 and Game.wheel_select(at):
		# `wheel_select` answers false for an empty slot, a cold one, and the
		# thing already in the hand. None of the three is a change, so none of
		# them clicks — a confirmation sound for "nothing happened" is how a
		# player learns to stop trusting the sound.
		Bus.request_sfx.emit(&"ui_confirm", _hero_at())
	Hud.wake_wheel()


## `Sfx` is 3D-only and the listener rides the hero, so a UI cue is played at
## him. The same thing `HeroCombat._select_blip` does, and for the same reason.
## Vector3.ZERO when there is no hero, which only happens in a lookdev box.
func _hero_at() -> Vector3:
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	return hero.global_position if hero != null else Vector3.ZERO
