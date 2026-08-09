class_name PauseMenu
extends CanvasLayer
## The pause menu. Drop `res://scenes/ui/menu/pause_menu.tscn` into any scene as
## a child and Escape (or Start) works — it brings its own theme, its own audio,
## and its own pause handling.
##
## Contracts it keeps, because each one is a way this screen normally breaks:
##
##  * **It actually pauses.** `get_tree().paused = true`, and this node's
##    process_mode is ALWAYS, so the menu keeps running while the world stops.
##  * **It gives the mouse back.** The camera captures the pointer for look; the
##    menu releases it on open and restores exactly what it found on close.
##  * **Nothing is mouse-only, and nothing is keyboard-only.** Every control is
##    FOCUS_ALL and wired into a closed focus loop, the first control is focused
##    the moment it opens, and the pad can *confirm* — not just move. Godot binds
##    `ui_accept`/`ui_cancel` to keys alone, so this screen adds A/X = confirm and
##    B = cancel itself (`_ensure_pad_ui_actions`); without that a pad player can
##    open the menu, walk it, and use exactly none of it.
##  * **Escape opens and closes; Cancel backs out one level** — the screen stack
##    pops, it does not jump to root. B is the pad's Escape everywhere, including
##    inside the "press a key" overlay, where it cancels instead of being
##    recorded as a binding.
##  * **It re-reads Settings and Saves on every open**, so values survive being
##    changed, closed and reopened.
##
## It never touches AudioServer, the window or the InputMap directly. Audio,
## video and binds all go through the `Settings` autoload; slots go through
## `Saves` (docs/CONTRACT.md §8).

signal opened
signal closed
## The player chose Quit to Title. If `title_scene` is unset the menu just
## closes and reports it, because P14 does not own scene transitions.
signal quit_to_title_requested
## A slot was loaded: `Game` is already restored, `dest` is the
## {scene, room, pos, yaw} that whoever owns room transitions must honour.
signal load_requested(slot: int, dest: Dictionary)
signal saved_to(slot: int)

enum Screen { ROOT, EQUIP, POUCH, OPTIONS, SAVES }

const NOTICE_TIME := 3.5
## Keys that must never become a binding on their own.
const MODIFIER_KEYS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]

## Godot ships `ui_accept` as Enter/Space and `ui_cancel` as Escape — keyboard
## only. Every Control in the engine confirms on `ui_accept`, so without this the
## whole menu is navigable by D-pad and confirmable by nothing, in a game whose
## contract promises pad and keyboard "equivalently" (docs/CONTRACT.md §0/§4).
##
## These are engine `ui_*` actions, not player-rebindable ones:
## `Settings._capture_defaults()` skips every action starting with "ui_" and
## `Settings.rebindable_actions()` excludes them, so `reset_binds()` cannot drop
## these and the rebind conflict scanner never sees them.
##
## **B is cancel and is never a confirm** — a button that both confirms and backs
## out can do neither reliably. A and X confirm, so a player reaching for the
## neighbouring face button gets an action instead of silence.
const PAD_UI_BUTTONS := {
	&"ui_accept": [JOY_BUTTON_A, JOY_BUTTON_X],
	&"ui_cancel": [JOY_BUTTON_B],
}
## Stick travel required before a joypad axis counts as "the player moved it".
## Below this it is resting drift, which must not cancel a rebind.
const PAD_MOTION_DEADZONE := 0.5

const SND_OPEN := preload("res://audio/sfx/ui_open.ogg")
const SND_CLOSE := preload("res://audio/sfx/ui_close.ogg")
const SND_MOVE := preload("res://audio/sfx/ui_move_selection_1.ogg")
const SND_CLICK := preload("res://audio/sfx/ui_click.ogg")
const SND_CONFIRM := preload("res://audio/sfx/ui_confirm.ogg")

## Optional: a title screen to fall back to. Left empty in the dungeon build.
@export_file("*.tscn") var title_scene: String = ""
## Start visible — used by scenes/ui/menu/_menu_test.tscn.
@export var open_on_ready: bool = false

@onready var _root: Control = $Root
@onready var _screens: Control = $Root/Screens
@onready var _root_screen: Control = $Root/Screens/RootScreen
@onready var _equip: MenuEquipPanel = $Root/Screens/EquipScreen
@onready var _pouch: MenuPouchPanel = $Root/Screens/PouchScreen
@onready var _options: MenuOptionsPanel = $Root/Screens/OptionsScreen
@onready var _saves: MenuSavesPanel = $Root/Screens/SavesScreen
@onready var _confirm: MenuConfirm = $Root/Confirm
@onready var _sfx: AudioStreamPlayer = $Root/Sfx

var _is_open := false
var _stack: Array[Dictionary] = []
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE
var _listening: StringName = &""
var _listen_return: Control = null

var _cmd_buttons: Array[Button] = []
var _last_root_button: Button = null
var _listen_layer: Control
var _listen_action_label: Label
var _notice_panel: PanelContainer
var _notice_label: Label
var _notice_timer: Timer


func _ready() -> void:
	_ensure_pad_ui_actions()
	_build_root_screen()
	_build_listen_overlay()
	_build_notice()

	_saves.bind_confirm(_confirm)
	_equip.back_requested.connect(back)
	_equip.notice.connect(_notice)
	_equip.value_settled.connect(func() -> void: _play(SND_CLICK))
	_pouch.back_requested.connect(back)
	# Using the way out is not backing out one screen: the Escape Rope's
	# channel happens in the world and the player has to be able to watch it, so
	# the whole menu goes away rather than popping to root.
	_pouch.use_requested.connect(close)
	_pouch.notice.connect(_notice)
	_options.back_requested.connect(back)
	_options.rebind_requested.connect(_begin_listening)
	_options.notice.connect(_notice)
	_options.value_settled.connect(func() -> void: _play(SND_CLICK))
	_saves.back_requested.connect(back)
	_saves.notice.connect(_notice)
	_saves.saved_to.connect(func(s: int) -> void: saved_to.emit(s))
	_saves.load_requested.connect(_on_load_requested)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

	_root.visible = false
	if open_on_ready:
		open.call_deferred()


var is_open: bool:
	get:
		return _is_open


# --- Open / close -----------------------------------------------------------

func open() -> void:
	if _is_open:
		return
	_is_open = true
	# The game captures the pointer for camera look; hand it back or the player
	# cannot click a single thing in here.
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.visible = true
	_stack.clear()
	_push({"screen": Screen.ROOT})
	_play(SND_OPEN)
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_cancel_listening()
	_confirm.visible = false
	_hide_notice()
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse as Input.MouseMode
	_play(SND_CLOSE)
	closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


## The pouch button (`inventory` — I, or Select on the pad). Opens the menu
## already ON the pouch, rather than at the root with the pouch one press away.
##
## This is the only screen with its own button, and it earns it: "what am I
## carrying and can I afford to leave" is the question the player asks between
## every room, and it is now the ONLY place the game says how much money is in
## play — the HUD stopped printing a total on purpose (see hud.gd). A question
## asked that often must not cost two presses and a focus move.
##
## Pressed again with the menu up it closes, wherever you had navigated to. A
## button that opens must close, or the player has to find a different button to
## undo what they just did.
func open_pouch() -> void:
	if _is_open:
		close()
		return
	open()
	_push({"screen": Screen.POUCH})


## Back out one level. At the root level that means closing the menu.
func back() -> void:
	if _listening != &"":
		_cancel_listening()
		_play(SND_CLOSE)
		return
	if _confirm.is_asking:
		_confirm.cancel()
		_play(SND_CLOSE)
		return
	if _stack.size() > 1:
		_stack.pop_back()
		_apply_top()
		_play(SND_CLOSE)
		return
	close()


func _push(entry: Dictionary) -> void:
	_stack.append(entry)
	_apply_top()


func _apply_top() -> void:
	if _stack.is_empty():
		return
	var top: Dictionary = _stack[_stack.size() - 1]
	var screen: int = top.get("screen", Screen.ROOT)
	_root_screen.visible = screen == Screen.ROOT
	_equip.visible = screen == Screen.EQUIP
	_pouch.visible = screen == Screen.POUCH
	_options.visible = screen == Screen.OPTIONS
	_saves.visible = screen == Screen.SAVES

	match screen:
		Screen.ROOT:
			var target: Button = _last_root_button if is_instance_valid(_last_root_button) else null
			if target == null and not _cmd_buttons.is_empty():
				target = _cmd_buttons[0]
			if target:
				target.grab_focus()
		Screen.EQUIP:
			_equip.refresh()
			_equip.focus_first()
		Screen.POUCH:
			_pouch.refresh()
			_pouch.focus_first()
		Screen.OPTIONS:
			_options.open_tab(top.get("tab", MenuOptionsPanel.Tab.AUDIO))
			_options.focus_first()
		Screen.SAVES:
			_saves.open_mode(top.get("mode", MenuSavesPanel.Mode.SAVE))
			_saves.focus_first()


# --- Input ------------------------------------------------------------------

## Give the engine's confirm/cancel actions a gamepad, once, idempotently. Safe
## to call from every PauseMenu instance and across scene reloads — an action
## that already carries the button is left alone, so events never pile up.
func _ensure_pad_ui_actions() -> void:
	for action: StringName in PAD_UI_BUTTONS:
		if not InputMap.has_action(action):
			continue
		for button: int in PAD_UI_BUTTONS[action]:
			if _action_has_pad_button(action, button):
				continue
			var e := InputEventJoypadButton.new()
			e.device = -1  # any connected pad, not just joypad 0
			e.button_index = button
			InputMap.action_add_event(action, e)


func _action_has_pad_button(action: StringName, button: int) -> bool:
	for e in InputMap.action_get_events(action):
		var j := e as InputEventJoypadButton
		if j != null and j.button_index == button:
			return true
	return false


func _input(event: InputEvent) -> void:
	# While listening for a new binding this node swallows everything, so no
	# focused button can steal the key the player is trying to assign.
	if _listening == &"":
		return
	var consumed := false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if code == KEY_ESCAPE:
				_cancel_listening()
				_play(SND_CLOSE)
			elif not MODIFIER_KEYS.has(code):
				var clean := InputEventKey.new()
				clean.physical_keycode = code
				_finish_listening(clean)
		consumed = true
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.pressed:
			var clean_m := InputEventMouseButton.new()
			clean_m.button_index = m.button_index
			_finish_listening(clean_m)
		consumed = true
	elif event is InputEventJoypadButton:
		var j := event as InputEventJoypadButton
		if j.pressed:
			# B is the pad's Escape. It has to be checked BEFORE the binding
			# path or "I changed my mind" is silently recorded as a new binding.
			if j.button_index == JOY_BUTTON_B:
				_cancel_listening()
				_play(SND_CLOSE)
			else:
				_refuse_pad_bind()
		consumed = true
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) > PAD_MOTION_DEADZONE:
			_refuse_pad_bind()
		consumed = true
	if consumed:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _listening != &"":
		return
	# Nothing opens during a scene transition. Flow's veil is at layer 200 and its
	# loading card is opaque, so a menu opened here is a menu at layer 100 that
	# nobody can see, holding the focus, over a world it did not pause -- and it
	# clears `get_tree().paused` on the way out from under `Flow._go`, which pauses
	# the world itself for the length of the loading card. The window used to be
	# a third of a second of black; naming the floor made it nearly two.
	if Flow != null and (Flow.busy or Flow.ending) and not _is_open:
		return
	if event.is_action_pressed(&"inventory"):
		open_pouch()
		get_viewport().set_input_as_handled()
		return
	if not _is_open:
		if event.is_action_pressed(&"pause"):
			open()
			get_viewport().set_input_as_handled()
		return
	# Escape is bound to both `pause` and `ui_cancel`; one branch, one response.
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


# --- Root screen ------------------------------------------------------------

func _build_root_screen() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size.x = 480
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.theme_type_variation = &"MenuStack"
	frame.add_child(col)

	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	col.add_child(header)
	var title := Label.new()
	title.theme_type_variation = &"MenuTitle"
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var pad := MarginContainer.new()
	pad.theme_type_variation = &"MenuBodyPad"
	col.add_child(pad)
	var list := VBoxContainer.new()
	list.theme_type_variation = &"MenuCommands"
	pad.add_child(list)

	_cmd_buttons.clear()
	_cmd_buttons.append(_command(list, "Resume", close))
	_cmd_buttons.append(_command(list, "Equipment", func() -> void:
		_push({"screen": Screen.EQUIP})))
	# Second, directly under Equipment, because the two answer adjacent
	# questions -- what am I HOLDING, what am I CARRYING -- and a player who has
	# just checked one usually wants the other.
	_cmd_buttons.append(_command(list, "Pouch", func() -> void:
		_push({"screen": Screen.POUCH})))
	_cmd_buttons.append(_command(list, "Save Game", func() -> void:
		_push({"screen": Screen.SAVES, "mode": MenuSavesPanel.Mode.SAVE})))
	_cmd_buttons.append(_command(list, "Load Game", func() -> void:
		_push({"screen": Screen.SAVES, "mode": MenuSavesPanel.Mode.LOAD})))
	_cmd_buttons.append(_command(list, "Options", func() -> void:
		_push({"screen": Screen.OPTIONS, "tab": _options.current_tab()})))
	_cmd_buttons.append(_command(list, "Quit to Title", _ask_quit_to_title))
	_cmd_buttons.append(_command(list, "Quit", _ask_quit))
	MenuUtil.chain(_cmd_buttons, true)

	var footer := PanelContainer.new()
	footer.theme_type_variation = &"MenuFooter"
	col.add_child(footer)
	var hint := Label.new()
	hint.theme_type_variation = &"MenuHint"
	hint.text = "↑↓ / D-pad Select    Enter / A Confirm    Esc / Start Resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(hint)


func _command(parent: Node, label: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.theme_type_variation = &"MenuCommand"
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	b.pressed.connect(func() -> void:
		_last_root_button = b
		_play(SND_CONFIRM)
		action.call())
	return b


func _ask_quit_to_title() -> void:
	_confirm.ask("Quit to Title?", "Any progress since your last save will be lost.",
		"Quit to Title", "Stay", true, _last_root_button)
	if not await _confirm.resolved:
		return
	close()
	if title_scene != "" and ResourceLoader.exists(title_scene):
		get_tree().change_scene_to_file(title_scene)
	else:
		# P14 does not own scene flow — say so instead of pretending.
		quit_to_title_requested.emit()


func _ask_quit() -> void:
	_confirm.ask("Quit the game?", "Any progress since your last save will be lost.",
		"Quit", "Stay", true, _last_root_button)
	if not await _confirm.resolved:
		return
	get_tree().quit()


func _on_load_requested(slot: int, dest: Dictionary) -> void:
	close()
	load_requested.emit(slot, dest)


# --- Rebinding --------------------------------------------------------------

func _build_listen_overlay() -> void:
	_listen_layer = Control.new()
	_listen_layer.name = "Listening"
	_listen_layer.visible = false
	_listen_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_listen_layer)
	_listen_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_listen_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_listen_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size.x = 620
	center.add_child(frame)

	var pad := MarginContainer.new()
	frame.add_child(pad)
	var col := VBoxContainer.new()
	col.theme_type_variation = &"MenuList"
	pad.add_child(col)

	var head := Label.new()
	head.theme_type_variation = &"MenuHeading"
	head.text = "PRESS A KEY OR BUTTON"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	_listen_action_label = Label.new()
	_listen_action_label.theme_type_variation = &"MenuTitle"
	_listen_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_listen_action_label)

	var foot := Label.new()
	foot.theme_type_variation = &"MenuHint"
	foot.text = "Esc / B cancels"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)


func _begin_listening(action: StringName) -> void:
	_listening = action
	_listen_return = get_viewport().gui_get_focus_owner()
	_listen_action_label.text = MenuUtil.action_title(action)
	_listen_layer.visible = true


## The Controls page tells the player "Gamepad bindings are fixed". This is what
## makes that sentence true: a pad input other than B drops out of listening and
## says why, instead of quietly displacing the pad binding through Settings.
func _refuse_pad_bind() -> void:
	_cancel_listening()
	_play(SND_CLOSE)
	_notice("Gamepad bindings cannot be changed.", true)


func _cancel_listening() -> void:
	if _listening == &"":
		return
	_listening = &""
	_listen_layer.visible = false
	_restore_listen_focus()


func _finish_listening(event: InputEvent) -> void:
	var action := _listening
	_listening = &""
	_listen_layer.visible = false

	# Ask WHO owns the key before rebinding, so a rejection can be explained.
	# Settings.rebind() only tells us false.
	var clash := MenuUtil.conflicting_action(event, action)
	if Settings.rebind(action, event):
		_options.refresh_binds()
		_notice("%s is now “%s”." % [
			MenuUtil.action_title(action), MenuUtil.event_label(event)], false)
		_play(SND_CONFIRM)
	else:
		var owner_name := (MenuUtil.action_title(clash) if clash != &""
			else "another action")
		_notice("“%s” is already bound to %s. %s was left unchanged." % [
			MenuUtil.event_label(event), owner_name,
			MenuUtil.action_title(action)], true)
	_restore_listen_focus()


func _restore_listen_focus() -> void:
	if is_instance_valid(_listen_return) and _listen_return.is_visible_in_tree():
		_listen_return.grab_focus()
	_listen_return = null


# --- Notice bar -------------------------------------------------------------

func _build_notice() -> void:
	_notice_panel = PanelContainer.new()
	_notice_panel.name = "Notice"
	_notice_panel.visible = false
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_notice_panel)
	# Pinned to the bottom edge and grown UP and OUT from a zero-size rect.
	# (A CENTER_BOTTOM preset would park it at y = screen height, off screen.)
	_notice_panel.anchor_left = 0.5
	_notice_panel.anchor_right = 0.5
	_notice_panel.anchor_top = 1.0
	_notice_panel.anchor_bottom = 1.0
	_notice_panel.offset_left = 0.0
	_notice_panel.offset_right = 0.0
	_notice_panel.offset_top = -12.0
	_notice_panel.offset_bottom = -12.0
	_notice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_notice_label = Label.new()
	_notice_label.theme_type_variation = &"MenuError"
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_panel.add_child(_notice_label)

	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.wait_time = NOTICE_TIME
	_notice_timer.timeout.connect(_hide_notice)
	_root.add_child(_notice_timer)


## Say why something did not happen. A rejected rebind that silently does
## nothing is the single most common way this screen lies to the player.
func _notice(text: String, is_error: bool) -> void:
	_notice_label.text = text
	_notice_label.theme_type_variation = &"MenuError" if is_error else &"MenuValue"
	_notice_panel.theme_type_variation = &"MenuNotice" if is_error else &"MenuNoticeOk"
	_notice_panel.visible = true
	_notice_timer.start(NOTICE_TIME)


func _hide_notice() -> void:
	if _notice_panel:
		_notice_panel.visible = false


# --- Audio ------------------------------------------------------------------

func _on_focus_changed(_c: Control) -> void:
	if _is_open:
		_play(SND_MOVE)


## Everything routes to the UI bus, so the Interface slider governs it
## (docs/CONTRACT.md §8) — never straight to Master.
func _play(stream: AudioStream) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()
