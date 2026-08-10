class_name TitleScreen
extends Control
## The first screen. Three answers to one question: carry on, start over, leave.
##
## It is the project's `run/main_scene` now. Booting straight into the garrison
## meant the game had no way to start a *new* one -- `Game.reset()` existed and
## nothing called it, so the flags that gate the opening (`reported_for_duty`)
## and every relic the save had ever seen came back with the process. The three
## buttons here are the only place those decisions get made.
##
## ## What each button actually does
##
##  * **CONTINUE** -- the newest readable slot, straight back to the scene it was
##    written in. Disabled and unfocusable when all three slots are empty, rather
##    than hidden: a menu whose items move depending on your history is a menu
##    you have to re-read every time you open it.
##  * **NEW GAME** -- `Flow.new_game()`. Clears `Game`, plays the opening, lands
##    in the garrison. It does NOT touch a save file: `Saves.autosave` picks the
##    first empty slot and only overwrites one it already owns, so starting a new
##    game with three full slots costs the player nothing until they choose a
##    slot to save into.
##  * **QUIT** -- `get_tree().quit()`.
##
## ## The art, and where the type sits on it
##
## `title_bg.jpg` is the Vale from the road above it: the city and the bridge in
## the left half, the road and the lit shrine down the right. Both of those are
## things worth looking at, so the type takes the middle -- the name high on the
## sky's dark band, the buttons in the column of hillside below it, on a scrim
## that fades out well before it reaches either edge.
##
## `Flow` owns everything past the press. Nothing here calls
## `change_scene_to_file` (docs/CONTRACT.md §7).

const BG := "res://assets/ui/title/title_bg.jpg"

## The name, split where it wants to break. `Cinzel` is a capitals face and the
## project's display voice (`UITheme.display_font`); the subtitle is the same
## face, smaller and letterspaced, so the two lines read as one inscription.
const TITLE := "THE LOWER WORLDS"
const SUBTITLE := "A W A K E N I N G"

## Baselines as fractions of the frame. The name sits above the middle, in the
## band of cloud, and the buttons hang under it in the empty hillside.
const TITLE_Y := 0.20
const MENU_Y := 0.55
const BUTTON_W := 300.0

var _bg: TextureRect
var _menu: VBoxContainer
var _continue: Button
var _slot: int = -1


func _ready() -> void:
	name = "TitleScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UITheme.prewarm()
	theme = UITheme.theme()
	# The game captures the pointer for camera look. Nothing has yet on the first
	# frame of the process, but `Flow` brings a quit-to-title back through here
	# one day and a menu you cannot click is the failure that follows.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_slot = _newest_slot()
	_build()
	# Focus lands on the thing a returning player wants and a new one does not
	# have. `grab_focus` on the next frame, not this one: the buttons are still
	# being sized by their container and a focus rim drawn against a zero rect
	# flickers on the first frame.
	await get_tree().process_frame
	var first := _continue if _slot >= 0 else _menu.get_child(1)
	(first as Button).grab_focus()


# --- Look -------------------------------------------------------------------

func _build() -> void:
	_bg = TextureRect.new()
	_bg.name = "Plate"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Crop, do not letterbox. See the same note in `Cutscene._build`.
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(BG):
		_bg.texture = load(BG) as Texture2D
	else:
		push_error("TitleScreen: no such image %s" % BG)
	add_child(_bg)

	# A column of shade down the middle, not a wash over everything. The
	# painting's two halves are the reason the type is centred at all; darkening
	# them to make a menu legible would be spending the picture to pay for the
	# menu.
	var scrim := TextureRect.new()
	scrim.name = "Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	var ramp := GradientTexture2D.new()
	ramp.fill = GradientTexture2D.FILL_LINEAR
	ramp.fill_from = Vector2(0.0, 0.0)
	ramp.fill_to = Vector2(1.0, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.30, 0.70, 1.0])
	g.colors = PackedColorArray([
		Color(Pal.VOID, 0.0),
		Color(Pal.VOID, 0.62),
		Color(Pal.VOID, 0.62),
		Color(Pal.VOID, 0.0),
	])
	ramp.gradient = g
	scrim.texture = ramp
	add_child(scrim)

	var col := VBoxContainer.new()
	col.name = "Name"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	col.anchor_top = TITLE_Y
	col.offset_top = 0.0
	col.offset_bottom = 0.0
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(_inscription(TITLE, 54))
	col.add_child(_inscription(SUBTITLE, 24, UITheme.ACCENT))

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_menu.anchor_top = MENU_Y
	_menu.offset_top = 0.0
	_menu.offset_bottom = 0.0
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 14)
	add_child(_menu)

	_continue = _button("CONTINUE", _on_continue)
	_button("NEW GAME", _on_new_game)
	_button("QUIT", _on_quit)

	# Empty slots do not offer themselves. `focus_mode = NONE` as well as
	# `disabled`, or gamepad navigation stops on a row that cannot answer.
	if _slot < 0:
		_continue.disabled = true
		_continue.focus_mode = Control.FOCUS_NONE
		_continue.tooltip_text = "No saved game."


## One line of the name. Cinzel with a heavy outline: the sky behind the top line
## is the brightest part of the frame and a serif face on cloud without one is a
## smear.
func _inscription(text: String, px: int, tint: Color = UITheme.TEXT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text_style(l, UITheme.TYPE_TITLE, tint)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(Pal.VOID, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_shadow_color", Color(Pal.VOID, 0.55))
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	UITheme.style_pill_button(b)
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(BUTTON_W, 0.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	_menu.add_child(b)
	return b


# --- Saves ------------------------------------------------------------------

## The slot CONTINUE goes to: the one written most recently, by the stamp the
## save itself carries. Not `Saves.active_slot`, which is -1 in a process that
## has not loaded anything yet -- which is every process that reaches this
## screen.
##
## The stamp is an ISO-ish string written by `Saves.save`, so it sorts
## lexicographically and does not need parsing. A slot with no stamp (v4, before
## it was written) loses to any slot that has one and wins against nothing,
## which is the right answer for a save whose age is genuinely unknown.
func _newest_slot() -> int:
	var best := -1
	var best_stamp := ""
	for i in Saves.SLOTS:
		var head := Saves.peek(i)
		if bool(head.get("empty", true)):
			continue
		var stamp := String(head.get("stamp", ""))
		if best < 0 or stamp > best_stamp:
			best = i
			best_stamp = stamp
	return best


# --- Actions ----------------------------------------------------------------

func _on_continue() -> void:
	if _slot < 0:
		return
	_lock()
	# `await`: `continue_game` runs the fade before it can know whether the room
	# arrived, so it is a coroutine and the bool comes back at the far end of it.
	if not await Flow.continue_game(_slot):
		# The slot passed `peek` and failed the full read -- corrupt, or written
		# by a version this build cannot read. Give the menu back rather than
		# leaving the player looking at three dead buttons.
		_unlock()
		_continue.disabled = true
		_continue.focus_mode = Control.FOCUS_NONE
		_continue.tooltip_text = "That save could not be read."
		(_menu.get_child(1) as Button).grab_focus()


func _on_new_game() -> void:
	_lock()
	Flow.new_game()


func _on_quit() -> void:
	get_tree().quit()


## Deaden the menu for the transition. `Flow` fades from the frame this press
## lands on, and a second press during that fade is a second `change_scene_to_file`
## -- the exact thing `Flow.busy` exists to refuse. This is the visible half of
## that refusal.
func _lock() -> void:
	for b in _menu.get_children():
		(b as Button).disabled = true
	_menu.modulate.a = 0.4


func _unlock() -> void:
	for b in _menu.get_children():
		(b as Button).disabled = false
	_menu.modulate.a = 1.0
