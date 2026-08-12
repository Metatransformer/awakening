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
##    recorded as a binding. A screen reached in ONE press (I, M) has nothing
##    under it and Escape leaves outright — see `_open_onto`.
##  * **It never opens over another screen.** The shop and the stash close on the
##    same Escape, and a menu that opened behind the thing you just closed is a
##    press the player did not make (`Prompt.screen_up`, in `_unhandled_input`).
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
##
## `Flow` connects to this in its own `_ready` and answers it with
## `Flow.resume(dest)` -- NOT `continue_game`, which would read the slot a second
## time. For eight weeks nothing was connected at all and a load from this menu
## restored `Game` and left the player standing where they already were.
signal load_requested(slot: int, dest: Dictionary)
signal saved_to(slot: int)

enum Screen { ROOT, EQUIP, POUCH, MAP, GARRISON, OPTIONS, SAVES }

const NOTICE_TIME := 3.5

## The root frame's width. Wider than the 480 the button stack needed, because a
## verb row carries a meta column on the right and the two have to be able to sit
## on one line — "Pouch ......... 7 / 12 slots" wrapped at 480.
const ROOT_W := 560
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
## **The shoulders are not here any more.** `ui_tab_prev` / `ui_tab_next` paged
## the inspection screens on LB / RB and Q / R; the owner asked for the
## selector to go (playtest 2026-08-12) and card #120 removed it. Paging is the
## TAB STRIP's job now, on the same stick that moves inside a page — see
## `MenuPageTabs`, which had to become focusable in the same change because a
## strip nothing can reach is a strip a controller cannot use.
const PAD_UI_BUTTONS := {
	&"ui_accept": [JOY_BUTTON_A, JOY_BUTTON_X],
	&"ui_cancel": [JOY_BUTTON_B],
}
## The keyboard half of the same set.
##
## **E CONFIRMS.** It is the world's `interact` — the key that talks to the
## vendor, opens the chest, pulls the lever — and a player who has spent the
## whole game pressing E to say yes to things does not stop meaning yes because
## the thing they are saying it to is now a menu row. Pad A is already on both
## `interact` and `ui_accept` for exactly that reason; this is the keyboard half
## of a symmetry that was only half built. Enter and Space still confirm.
##
## It cost E its old job as the paging key, and then paging itself went (card
## #120): Q and R are free again and are deliberately left free rather than
## re-pointed at something else. The arrows walk the tab strip now.
const KEY_UI_BUTTONS := {
	&"ui_accept": [KEY_E],
}

## The screens the tab strip cycles, in ring order, with its labels.
##
## Four, and not six. EQUIP / INVENTORY / MAP / GARRISON are the screens that
## ANSWER a question about the run in progress — what am I holding, what am I
## carrying, where am I, how is home — and paging between them is how a player
## checks all four without going back to a list each time. Options and Save/Load are things you DO, they
## change the game or the disk, and putting them one arrow away from a map read
## mid-corridor is how a player lands on the save screen by accident. They stay
## commands on the root menu.
##
## **The labels were ITEMS and POUCH** until card #120 (owner, 2026-08-12).
## POUCH became INVENTORY because that is what a player calls the bag. ITEMS
## became EQUIP because the label was the only name for this screen that was not
## already EQUIP: the enum entry is `Screen.EQUIP`, the panel is
## `equip_panel.gd`, the class is `MenuEquipPanel` and the root menu's own row
## says "Equipment". One word, in five places, is worth more than the shade of
## meaning "ITEMS" carried. Adding GARRISON does not roll that decision back.
const PAGES := [
	[Screen.EQUIP, "EQUIP"],
	[Screen.POUCH, "INVENTORY"],
	[Screen.MAP, "MAP"],
	[Screen.GARRISON, "GARRISON"],
]
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
@onready var _map: MenuMapPanel = $Root/Screens/MapScreen
@onready var _garrison: MenuGarrisonPanel = $Root/Screens/GarrisonScreen
@onready var _options: MenuOptionsPanel = $Root/Screens/OptionsScreen
@onready var _saves: MenuSavesPanel = $Root/Screens/SavesScreen
@onready var _confirm: MenuConfirm = $Root/Confirm
@onready var _sfx: AudioStreamPlayer = $Root/Sfx

var _is_open := false
var _stack: Array[Dictionary] = []
var _listening: StringName = &""
var _listen_return: Control = null

var _cmd_buttons: Array[Button] = []
## Where `refresh_root` rebuilds. Held rather than looked up by path, because the
## containers between the frame and these two are unnamed layout and a path
## through them is a path that breaks when the layout is adjusted.
var _root_list: VBoxContainer
var _root_band_slot: VBoxContainer
## One `MenuPageTabs` per paged screen. Kept so a page change can light the
## right tab on ALL of them: each screen carries its own copy of the strip, and
## a strip that only updated when its own screen was showing would be wrong the
## moment you paged away and back.
var _page_tabs: Array[MenuPageTabs] = []
## True for the duration of a page change made ON the strip. See `_go_page`.
var _paged_from_tabs := false
var _last_root_button: Button = null
var _listen_layer: Control
var _listen_action_label: Label
var _notice_panel: PanelContainer
var _notice_label: Label
var _notice_timer: Timer


func _ready() -> void:
	_ensure_pad_ui_actions()
	# Before the first panel is built. `prewarm` bakes the procedural plate
	# textures and loads the faces; without it the first menu frame a player ever
	# sees is drawn with fallback styleboxes and then corrects itself.
	UITheme.prewarm()
	# The whole menu renders through the kit, and this is the line that says so.
	# It used to be `menu_theme.tres` on Root in the scene, with each converted
	# panel overriding it on itself; every panel has now converted, so the
	# override moved up to the one place and the .tres is gone. A Theme built by
	# a static function cannot be an `ext_resource`, hence code and not the scene.
	$Root.theme = UITheme.theme()
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
	_map.back_requested.connect(back)
	_garrison.back_requested.connect(back)
	_build_page_tabs()
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
	# cannot click a single thing in here. FREED HERE, PUT BACK NOWHERE: the
	# `closed` signal below is what asks for it, and `GameCamera._settle_pointer`
	# answers. This menu remembering what it found and restoring it is the FIRST
	# of the three times that arrangement has killed mouse look — the camera used
	# to release the cursor on `pause` before this ran, so what it remembered was
	# already "visible".
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.visible = true
	# The band and the meta columns are about THIS moment in the run, so they are
	# rebuilt on open rather than at boot. A menu that is never torn down would
	# otherwise show the bag you had the last time you paused.
	refresh_root()
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
	_open_onto(Screen.POUCH)


## The map button (`map` — M or Tab, or Select on the pad). Same contract as
## `open_pouch`: opens straight onto the screen, and pressing it again closes
## the menu from wherever you had navigated to.
##
## "Where am I and what have I not opened yet" is asked as often as "what am I
## carrying", and it is asked mid-corridor — a map you reach through Escape and
## a list is a map the player consults once and then stops consulting.
func open_map() -> void:
	if _is_open:
		close()
		return
	open()
	_open_onto(Screen.MAP)


## Land on `screen` with NOTHING UNDER IT. The root is not a step you passed
## through on the way here, so Escape must not walk you back onto it.
##
## This was the bug: `open()` seeds the stack with ROOT, so opening the pouch
## with I left [ROOT, POUCH], and Escape — which the player is pressing to LEAVE
## — popped one level and opened the pause menu they never asked for. A button
## that opens a screen owns the way back out of it, and the way out of a screen
## you reached in one press is the world.
##
## Paging (`_go_page`) REPLACES the top of the stack, so this holds across the
## whole EQUIP/INVENTORY/MAP/GARRISON ring: however you walk it, Escape leaves.
##
## Reaching the same screen from the root menu still stacks normally — there the
## root IS where you came from, and backing onto it is what the player means.
func _open_onto(screen: int) -> void:
	_stack.clear()
	_push({"screen": screen})


## One strip per paged screen, all built here.
##
## The panels expose a `tab_host()` and nothing else — no ring constant, no
## `picked` re-emission, no "which tab am I" of their own. That is deliberate:
## the ring, the strips, the highlight and the screen stack are one mechanism,
## and the version of this where each panel owned its strip is the version where
## adding a fourth tab means editing four files and getting one of them wrong.
func _build_page_tabs() -> void:
	_page_tabs.clear()
	for page: Array in PAGES:
		var screen: int = int(page[0])
		var host: HBoxContainer = _panel_for(screen).call(&"tab_host")
		if host == null:
			continue
		var strip := MenuPageTabs.new()
		host.add_child(strip)
		host.move_child(strip, 0)
		strip.setup(PAGES, screen)
		strip.picked.connect(_go_page)
		_page_tabs.append(strip)
		strip.link_body(_tab_row(screen))
	# No `input_device_changed` hook any more. The strip used to carry a live key
	# cap at either end naming the shoulder that paged, and those had to be
	# relabelled when a pad was picked up; there is no button on it now, only the
	# arrows, which are the same arrows on both devices.


func _panel_for(screen: int) -> Control:
	match screen:
		Screen.EQUIP: return _equip
		Screen.POUCH: return _pouch
		Screen.MAP: return _map
		Screen.GARRISON: return _garrison
	return null


func _strip_for(screen: int) -> MenuPageTabs:
	for i in PAGES.size():
		if int(PAGES[i][0]) == screen and i < _page_tabs.size():
			return _page_tabs[i]
	return null


## The panel's top row of focusables, landing target first. This is the half of
## the focus graph the PANEL owns and the strip cannot know — which control ↓ out
## of a tab should land on, and which controls ↑ should leave through.
func _tab_row(screen: int) -> Array:
	var panel := _panel_for(screen)
	if panel == null or not panel.has_method(&"tab_row"):
		return []
	return panel.call(&"tab_row")


## A tab was reached — by stick, by keyboard or by mouse. The one and only way
## the page changes now; `_page(delta)`, which the shoulders called, is gone with
## them (card #120).
##
## It REPLACES the top of the stack rather than pushing onto it. That is the
## whole difference between a tab and a screen: paging EQUIP → INVENTORY → MAP
## → GARRISON and then pressing B should put you back where you were before you
## opened any of them, not walk you back out through screens you were only passing
## through. The stack still records the one entry, so B behaves the same
## whichever tab you happen to be standing on when you press it.
##
## `_paged_from_tabs` is what keeps the cursor on the strip afterwards. Without
## it `_apply_top` calls the new panel's `focus_first()` and drops the player
## into the body on every page change — which would make ← ← ← walk EQUIP,
## INVENTORY, and then whatever the INVENTORY body does with ←. The flag is
## cleared here rather than in `_apply_top` because `focus_home()` re-enters this
## function (the `focus_entered` it causes), and that arrival must find the same
## answer the first one did.
func _go_page(screen: int) -> void:
	if _stack.is_empty() or int(_stack[_stack.size() - 1].get("screen",
			Screen.ROOT)) == screen:
		return
	_stack[_stack.size() - 1] = {"screen": screen}
	_paged_from_tabs = true
	_apply_top()
	_paged_from_tabs = false
	_play(SND_MOVE)


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
	_map.visible = screen == Screen.MAP
	_garrison.visible = screen == Screen.GARRISON
	_options.visible = screen == Screen.OPTIONS
	_saves.visible = screen == Screen.SAVES
	for strip in _page_tabs:
		strip.set_active(screen)

	match screen:
		Screen.ROOT:
			var target: Button = _last_root_button if is_instance_valid(_last_root_button) else null
			if target == null and not _cmd_buttons.is_empty():
				target = _cmd_buttons[0]
			if target:
				target.grab_focus()
		Screen.EQUIP, Screen.POUCH, Screen.MAP, Screen.GARRISON:
			_enter_page(screen)
		Screen.OPTIONS:
			_options.open_tab(top.get("tab", MenuOptionsPanel.Tab.AUDIO))
			_options.focus_first()
		Screen.SAVES:
			_saves.open_mode(top.get("mode", MenuSavesPanel.Mode.SAVE))
			_saves.focus_first()


## Show one of the four paged screens and put the cursor somewhere sensible.
##
## The re-link is not optional and it is not a refresh of the paint. Two of the
## three panels rebuild their top row of focusables inside `refresh()` — the
## bag's cells are `ItemGrid` buttons that come and go with `bag_slots` — so the
## strip's ↓ and the row's ↑ have to be re-pointed at the controls that exist
## NOW. Linked once at build time, the first bag slot bought at the smith would
## have left ↑ walking into a freed Button.
func _enter_page(screen: int) -> void:
	var panel := _panel_for(screen)
	if panel == null:
		return
	panel.call(&"refresh")
	var strip := _strip_for(screen)
	if strip != null:
		strip.link_body(_tab_row(screen))
	# Arrived by paging: stay on the strip, so ← / → keep paging. Arrived from
	# the root menu or from `open_pouch` / `open_map`: the player asked for the
	# PAGE, so the cursor belongs in it.
	if _paged_from_tabs and strip != null:
		strip.focus_home()
	else:
		panel.call(&"focus_first")


# --- Input ------------------------------------------------------------------

## Give the engine's confirm/cancel actions a gamepad, once, idempotently. Safe
## to call from every PauseMenu instance and across scene reloads — an action
## that already carries the button is left alone, so events never pile up.
func _ensure_pad_ui_actions() -> void:
	for action: StringName in PAD_UI_BUTTONS:
		# `ui_accept` / `ui_cancel` exist already and this leaves them alone; the
		# `has_action` guard is what let this function also CREATE the two paging
		# actions the engine does not ship, and it is kept because registering at
		# runtime rather than in project.godot keeps these out of `--import`'s
		# reach — that tool re-serialises the file and has silently eaten
		# hand-written lines from it before (see CLAUDE.md §3).
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button: int in PAD_UI_BUTTONS[action]:
			if _action_has_pad_button(action, button):
				continue
			var e := InputEventJoypadButton.new()
			e.device = -1  # any connected pad, not just joypad 0
			e.button_index = button
			InputMap.action_add_event(action, e)
	for action: StringName in KEY_UI_BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in KEY_UI_BUTTONS[action]:
			if _action_has_key(action, code):
				continue
			var k := InputEventKey.new()
			k.physical_keycode = code
			InputMap.action_add_event(action, k)


func _action_has_key(action: StringName, code: int) -> bool:
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k != null and k.physical_keycode == code:
			return true
	return false


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
	# Nothing opens over a screen that is already up either. The shop, the stash
	# and the run summary all close on `ui_cancel` OR `pause`, and Escape is bound
	# to BOTH — so one Escape at the vendor used to close the shop and open this
	# menu in the same frame, which is the player using a button to leave and
	# being handed something else instead. One press, one response.
	#
	# It is not just Escape: Start does the same thing on a pad, and the fix is
	# the same shape for both. (The old note on `TradeScreen.open`'s CanvasLayer
	# claiming you could pause ON TOP of the shop described a state you could
	# only ever reach by hitting this bug.)
	if not _is_open and Prompt != null and Prompt.screen_up:
		return
	if event.is_action_pressed(&"inventory"):
		open_pouch()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"map"):
		open_map()
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

## The root, on the kit.
##
## It was eight identical full-width buttons stacked in a box, which is the exact
## shape `UiKit`'s header describes as what happens when a screen has paint and
## no composition: no hierarchy for the eye to land on, and a pause menu that
## looks the same whether you are safe in the garrison or four floors down with a
## full bag. It said nothing about the run it was pausing.
##
## Rebuilt as a plate header (WHAT this is), a stat band (WHAT STATE the run is
## in), and verb rows with a META COLUMN — the cost, the count, the consequence.
## `Resume` is the one `primary`. `Inventory` says how full the bag is without
## your opening it. `Quit to Title` says what it will cost you, in the row, before
## the confirm dialog rather than only inside it.
##
## The band is REPAINTED on every open (`refresh_root`), not built once: the menu
## is not torn down between visits, and a stat band showing the bag you had two
## floors ago is worse than no band.
func _build_root_screen() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# PanelContainer, NOT Panel. A bare `Panel` is not a Container: it neither
	# lays its children out nor takes a minimum size from them, so inside a
	# CenterContainer it collapses to nothing and the whole pause menu renders as
	# an empty screen — which is exactly what the first frame of this rebuild
	# looked like, with every navigation assertion still passing.
	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.custom_minimum_size.x = ROOT_W
	# edge_to_edge: the header band and the stat band own their own inset and
	# have to reach the frame's edge, or they read as two cards inside a card.
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	frame.add_child(col)

	UiKit.plate_header(col, {
		"kicker": "The Lower Worlds",
		"title": "Paused",
		"emblem": UiKit.action_icon("relic"),
	})

	_root_band_slot = VBoxContainer.new()
	_root_band_slot.add_theme_constant_override("separation", 0)
	col.add_child(_root_band_slot)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 0)
	pad.add_theme_constant_override("margin_right", 0)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	col.add_child(pad)
	_root_list = VBoxContainer.new()
	_root_list.add_theme_constant_override("separation", 0)
	pad.add_child(_root_list)

	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_left", 18)
	footer.add_theme_constant_override("margin_right", 18)
	footer.add_theme_constant_override("margin_bottom", 12)
	col.add_child(footer)
	var hint := Label.new()
	# B, not Start, because B is the universal back in every other screen in this
	# menu and the root is the one place it was not written down. At the root
	# there is nothing left to back out of, so backing out closes — which is what
	# "Resume" was already describing.
	hint.text = "↑↓ / D-pad Select    E / A Confirm    Esc / B Resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text_style(hint, UITheme.TYPE_CAPTION)
	footer.add_child(hint)

	refresh_root()


## Rebuild the band and the rows from the live run.
##
## The whole list is rebuilt rather than repainted in place, unlike the doll's
## tiles: the ROWS themselves change here (a refusal appears, a meta figure
## moves), and there is nothing on this screen a rebuild can lose — focus is
## re-established by `_apply_top` on every push, and `_last_root_button` is
## restored by NAME below rather than by node identity.
func refresh_root() -> void:
	if _root_list == null:
		return
	# `UiKit.label_of`, NOT `.text`. A VerbRow's own `text` is empty by
	# construction — the label is a child of the composite — so reading `.text`
	# here compared "" against "" and matched the FIRST row every time, which
	# silently turned "put me back where I was" into "put me on Resume".
	var want := UiKit.label_of(_last_root_button)
	UITheme.clear_children(_root_band_slot)
	UITheme.clear_children(_root_list)
	_cmd_buttons.clear()

	var used := Run.slots_used()
	var underground := Run.in_dungeon
	UiKit.stat_band(_root_band_slot, [
		{"value": "%d" % Run.depth if underground else "—", "label": "Depth"},
		{"value": "%d / %d" % [used, Game.bag_slots], "label": "Slots",
			"tone": UITheme.WARNING if used >= Game.bag_slots else null},
		{"value": "%d" % Run.bag_value(), "label": "Bag"},
		{"value": "%d" % Game.gold, "label": "Purse", "tone": UITheme.SUCCESS},
		{"value": "%d" % Run.extract_cost() if underground else "—", "label": "Way out",
			"tone": UITheme.DANGER if underground and Run.extract_cost() > Game.gold else null},
	])

	_command("Resume", "resume", "", close, {"primary": true})
	_command("Equipment", "sword",
		ArmamentDb.slot_name(Game.armament(Game.HAND_RIGHT)),
		func() -> void: _push({"screen": Screen.EQUIP}), {"submenu": true})
	# Second, directly under Equipment, because the two answer adjacent
	# questions -- what am I HOLDING, what am I CARRYING -- and a player who has
	# just checked one usually wants the other.
	# "Inventory" and not "Pouch" — the tab it opens says INVENTORY (card #120)
	# and a command that names a screen has to name the screen it opens.
	_command("Inventory", "bag", "%d / %d slots" % [used, Game.bag_slots],
		func() -> void: _push({"screen": Screen.POUCH}), {"submenu": true})
	_command("Garrison", "relic", "%d / %d hearth" % [
		Game.firewood_stock, Game.FIREWOOD_CAP],
		func() -> void: _push({"screen": Screen.GARRISON}), {"submenu": true})
	_command("Save Game", "save", "", func() -> void:
		_push({"screen": Screen.SAVES, "mode": MenuSavesPanel.Mode.SAVE}),
		{"submenu": true})
	_command("Load Game", "read", "", func() -> void:
		_push({"screen": Screen.SAVES, "mode": MenuSavesPanel.Mode.LOAD}),
		{"submenu": true})
	_command("Options", "options", "", func() -> void:
		_push({"screen": Screen.OPTIONS, "tab": _options.current_tab()}),
		{"submenu": true})
	# The consequence goes in the META COLUMN, in the row, not only behind the
	# confirm dialog. A player who has read "the run is lost" before pressing is
	# a player the dialog is confirming a decision for rather than breaking one to
	# them.
	_command("Quit to Title", "leave",
		"the run is lost" if underground else "", _ask_quit_to_title)
	_command("Quit", "quit", "", _ask_quit)
	MenuUtil.chain(_cmd_buttons, true)

	# Restored by LABEL: `refresh_root` builds new Buttons every time, so the
	# node the player last pressed no longer exists. The text is what the player
	# actually remembers standing on.
	_last_root_button = null
	for b in _cmd_buttons:
		if UiKit.label_of(b) == want:
			_last_root_button = b
			break


## One root verb. `glyph` names a member of the ACTION family; `meta` is the
## right-hand column and is allowed to be empty (a row with nothing to say about
## cost is still a row, it just says nothing).
func _command(label: String, glyph: String, meta: String, action: Callable,
		extra: Dictionary = {}) -> Button:
	var config := {
		"label": label,
		"icon": UiKit.action_icon(glyph),
		"meta": meta,
		"on_press": func() -> void:
			_play(SND_CONFIRM)
			action.call(),
	}
	config.merge(extra, true)
	var b := UiKit.verb_row(_root_list, config)
	if b == null:
		return null
	# The press handler above cannot capture `b` (it does not exist yet), and the
	# last-pressed row has to be recoverable after a rebuild — so the bookkeeping
	# is a second connection rather than a closure over a node.
	b.pressed.connect(func() -> void: _last_root_button = b)
	_cmd_buttons.append(b)
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

	# `hover_card`, the same face `MenuConfirm` wears, and for the same reason:
	# this is the other thing that gets RAISED over a screen rather than being
	# one, and two raised surfaces with two faces is two modal languages.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.hover_card())
	frame.clip_contents = true
	frame.custom_minimum_size.x = 620
	center.add_child(frame)

	var pad := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	frame.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)

	var head := Label.new()
	UITheme.apply_text_style(head, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	head.text = "PRESS A KEY OR BUTTON"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	# The action being rebound is the whole content of this overlay, so it gets
	# the display face — everything else here is instruction.
	_listen_action_label = Label.new()
	UITheme.apply_text_style(_listen_action_label, UITheme.TYPE_H1, UITheme.TEXT)
	_listen_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_listen_action_label)

	var foot := Label.new()
	UITheme.apply_text_style(foot, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
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

## Wide enough for the longest thing the bar says — the rebind conflict, which
## names two actions and a key — without running the full width of the screen.
const NOTICE_W := 660

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

	# The panel is now just the anchor. What goes in it is a `FooterToast`, built
	# fresh per notice — the same component, in the same tones, that the locker
	# and the five counters use to say why a press did nothing. A rejected rebind
	# and a refused purchase are the same event and now look like it.
	_notice_panel.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 4, 4, 4, 4))
	# A width of its own, because the bar is grown from a ZERO-SIZE rect: its size
	# is whatever its child's minimum is, and a `FooterToast`'s line autowraps, so
	# that minimum is ONE CHARACTER. The first frame of this was the whole notice
	# set vertically down the middle of the screen, one letter per row.
	_notice_panel.custom_minimum_size.x = NOTICE_W

	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.wait_time = NOTICE_TIME
	_notice_timer.timeout.connect(_hide_notice)
	_root.add_child(_notice_timer)


## Say why something did not happen. A rejected rebind that silently does
## nothing is the single most common way this screen lies to the player.
func _notice(text: String, is_error: bool) -> void:
	for child in _notice_panel.get_children():
		child.queue_free()
		_notice_panel.remove_child(child)
	var toast := UiKit.footer_toast(_notice_panel, text,
		UITheme.DANGER if is_error else UITheme.SUCCESS)
	# Kept so `tools/directors` and `_menu_director` can read what was said —
	# several of them assert on the WORDS, which is the only way to prove the
	# screen explained itself rather than just flashing.
	_notice_label = toast.get_meta(&"toast_label", null) as Label
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
