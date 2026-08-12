class_name BlessingMenu
extends CanvasLayer
## The six-presence choice raised over a live votive shrine.
##
## The world remains the top half of this screen: the effigies themselves are
## the portrait plate, so this menu only occupies the lower band and names what
## the lit stone is offering. All six presences stay in the grid. Silence is a
## state the player can learn, not a missing option that changes the board.

signal blessing_chosen(patron_id: StringName, blessing_id: StringName)
signal dismissed

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const UiKit := preload("res://scripts/ui/kit/ui_kit.gd")
const PatronDbScript := preload("res://scripts/items/patron_db.gd")
const EchoDbScript := preload("res://scripts/items/echo_db.gd")

const PANEL_TOP := 0.54
const SCREEN_MARGIN := 14
const CARD_MIN_HEIGHT := 88

var _offers: Dictionary = {}
var _cards: Array[Button] = []
var _answering_buttons: Array[Button] = []
var _toast_slot: VBoxContainer
var _toast: Control
var _last_focus: Button

## A choice is deliberately born disarmed. The same A/E press that asked the
## shrine input used to open this scene must be released before any Button gets
## focus, or one physical press can both open the court and choose its first god.
var _choices_armed := false
var _choice_committed := false
var _opening_frame_passed := false
var _closing := false

@onready var _root: Control = $Root


## Configure before this scene enters the tree. Keys are answering patrons and
## values are the one blessing each offers for this visit.
func setup(offers: Dictionary) -> void:
	_offers.clear()
	for key: Variant in offers:
		var patron_id := StringName(key)
		var blessing_id := StringName(offers[key])
		_offers[patron_id] = blessing_id
	if is_node_ready():
		_build_cards()
		_begin_safe_open()


func card_count() -> int:
	if not _cards.is_empty():
		return _cards.size()
	var patrons: Array[StringName] = PatronDbScript.all()
	return patrons.size()


func answering_count() -> int:
	if not _cards.is_empty():
		return _answering_buttons.size()
	var count := 0
	var patrons: Array[StringName] = PatronDbScript.all()
	for patron_id: StringName in patrons:
		if _offers.has(patron_id):
			count += 1
	return count


## Blessing ids in the pantheon's canonical order, independent of Dictionary
## insertion order.
func offered_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var patrons: Array[StringName] = PatronDbScript.all()
	for patron_id: StringName in patrons:
		if _offers.has(patron_id):
			out.append(StringName(_offers[patron_id]))
	return out


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.prewarm()
	_root.theme = UITheme.theme()
	_build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Prompt.block(self)
	Bus.screen_opened.emit(&"blessing")
	_begin_safe_open()


func _exit_tree() -> void:
	Prompt.unblock(self)
	Bus.screen_closed.emit(&"blessing")


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_dismiss()


func _process(_delta: float) -> void:
	if not _opening_frame_passed:
		_opening_frame_passed = true
		return
	if Input.is_action_pressed(&"ui_accept") or Input.is_action_pressed(&"interact"):
		return
	_choices_armed = true
	set_process(false)
	_restore_focus()


func close() -> void:
	if _closing:
		return
	_closing = true
	queue_free()


func _dismiss() -> void:
	if _closing:
		return
	dismissed.emit()
	close()


## The owner rejected a choice (currently BAG FULL). The court stays open, says
## why in its footer, and hands the cursor back to the same answering presence.
func show_refusal(text: String) -> void:
	if _closing:
		return
	if _toast != null and is_instance_valid(_toast):
		_toast_slot.remove_child(_toast)
		_toast.queue_free()
	_toast = UiKit.footer_toast(_toast_slot, text, UITheme.DANGER)
	_choice_committed = false
	_choices_armed = true
	_set_answering_enabled(true)
	_restore_focus.call_deferred()


# --- Building ----------------------------------------------------------------

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.018, 0.015, 0.013, 0.42)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(scrim)
	# Anchors only resolve after parenting. Re-applying the preset keeps this
	# full-rect even when the scene is instantiated into an unusual viewport.
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var lower := MarginContainer.new()
	lower.name = "LowerBand"
	lower.anchor_left = 0.0
	lower.anchor_top = PANEL_TOP
	lower.anchor_right = 1.0
	lower.anchor_bottom = 1.0
	lower.offset_left = SCREEN_MARGIN
	lower.offset_top = SCREEN_MARGIN
	lower.offset_right = -SCREEN_MARGIN
	lower.offset_bottom = -SCREEN_MARGIN
	for side: String in ["left", "top", "right", "bottom"]:
		lower.add_theme_constant_override("margin_" + side, 0)
	_root.add_child(lower)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	lower.add_child(frame)

	var pad := MarginContainer.new()
	pad.name = "Pad"
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	for side: String in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	frame.add_child(pad)

	var stack := VBoxContainer.new()
	stack.name = "Content"
	stack.add_theme_constant_override("separation", 5)
	pad.add_child(stack)

	var title := Label.new()
	title.name = "Title"
	title.text = "THE VOTIVE COURT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.focus_mode = Control.FOCUS_NONE
	UITheme.apply_text_style(title, UITheme.TYPE_H1, UITheme.TEXT)
	stack.add_child(title)

	var subline := Label.new()
	subline.name = "Subline"
	subline.text = "Three answer. Choose one blessing; it lasts only for this descent."
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subline.focus_mode = Control.FOCUS_NONE
	UITheme.apply_text_style(subline, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	stack.add_child(subline)

	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(grid)

	_toast_slot = VBoxContainer.new()
	_toast_slot.name = "ToastSlot"
	_toast_slot.add_theme_constant_override("separation", 0)
	_toast_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_toast_slot)

	_build_cards()


func _build_cards() -> void:
	var grid := _root.get_node_or_null("LowerBand/Frame/Pad/Content/Cards") as GridContainer
	if grid == null:
		return
	UITheme.clear_children(grid)
	_cards.clear()
	_answering_buttons.clear()
	_last_focus = null
	var patrons: Array[StringName] = PatronDbScript.all()
	for patron_id: StringName in patrons:
		var answering := _offers.has(patron_id)
		var blessing_id := StringName(_offers.get(patron_id, &""))
		var card := _make_card(patron_id, blessing_id, answering)
		grid.add_child(card)
		_cards.append(card)
		if answering:
			_answering_buttons.append(card)
	_wire_answering_focus()


func _make_card(patron_id: StringName, blessing_id: StringName, answering: bool) -> Button:
	var card := Button.new()
	card.name = "Card_%s" % String(patron_id)
	card.text = ""
	card.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.disabled = not answering
	card.focus_mode = Control.FOCUS_ALL if answering else Control.FOCUS_NONE
	card.tooltip_text = PatronDbScript.name_of(patron_id)
	card.set_meta(&"patron_id", patron_id)
	card.set_meta(&"blessing_id", blessing_id)

	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.focus_mode = Control.FOCUS_NONE
	for side: String in ["left", "right"]:
		inset.add_theme_constant_override("margin_" + side, 10)
	for side: String in ["top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 6)
	card.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.focus_mode = Control.FOCUS_NONE
	content.add_theme_constant_override("separation", 1)
	inset.add_child(content)

	var accent := ColorRect.new()
	accent.name = "Accent"
	var patron_color: Color = PatronDbScript.color_of(patron_id)
	accent.color = patron_color if answering else Color(
		patron_color.r, patron_color.g, patron_color.b, 0.30)
	accent.custom_minimum_size = Vector2(0, 3)
	accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.focus_mode = Control.FOCUS_NONE
	content.add_child(accent)

	var god_name := Label.new()
	god_name.name = "GodName"
	god_name.text = PatronDbScript.name_of(patron_id)
	god_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	god_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	god_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	god_name.focus_mode = Control.FOCUS_NONE
	var heading_color := patron_color if answering else Color(
		patron_color.r, patron_color.g, patron_color.b, 0.48)
	UITheme.apply_text_style(god_name, UITheme.TYPE_H3, heading_color)
	content.add_child(god_name)

	var state := Label.new()
	state.name = "State"
	state.text = "ANSWERS" if answering else "SILENT"
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.focus_mode = Control.FOCUS_NONE
	UITheme.apply_text_style(state, UITheme.TYPE_CAPTION,
		UITheme.SUCCESS if answering else UITheme.TEXT_DIM)
	content.add_child(state)

	var blessing := Label.new()
	blessing.name = "BlessingName"
	blessing.text = EchoDbScript.name_of(blessing_id) if answering else "No blessing answers."
	blessing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	blessing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blessing.focus_mode = Control.FOCUS_NONE
	UITheme.apply_text_style(blessing, UITheme.TYPE_PARAGRAPH_1,
		UITheme.TEXT if answering else UITheme.TEXT_DIM)
	content.add_child(blessing)

	if answering:
		var line := Label.new()
		line.name = "BlessingLine"
		line.text = EchoDbScript.line_of(blessing_id)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.focus_mode = Control.FOCUS_NONE
		UITheme.apply_text_style(line, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
		content.add_child(line)
		card.pressed.connect(_on_card_pressed.bind(card, patron_id, blessing_id))
		card.focus_entered.connect(_on_card_focused.bind(card))
	return card


# --- Choice and focus ---------------------------------------------------------

func _begin_safe_open() -> void:
	_choices_armed = false
	_choice_committed = false
	_opening_frame_passed = false
	_clear_shortcuts()
	set_process(true)


func _on_card_pressed(card: Button, patron_id: StringName, blessing_id: StringName) -> void:
	if not _choices_armed or _choice_committed or card.disabled:
		return
	_choice_committed = true
	_choices_armed = false
	_last_focus = card
	_set_answering_enabled(false)
	blessing_chosen.emit(patron_id, blessing_id)


func _on_card_focused(card: Button) -> void:
	if card.disabled:
		return
	_last_focus = card
	# E is the world's `interact` binding rather than a second hard-coded key.
	# Only the focused card owns this Shortcut, so one event cannot press every
	# answering card. A/Cross may also appear here and in ui_accept; the commit
	# guard above makes the two Button paths one choice.
	_clear_shortcuts()
	var shortcut := Shortcut.new()
	shortcut.events = InputMap.action_get_events(&"interact")
	card.shortcut = shortcut
	card.shortcut_in_tooltip = false


func _wire_answering_focus() -> void:
	var count := _answering_buttons.size()
	if count == 0:
		return
	for i: int in count:
		var card := _answering_buttons[i]
		var previous := _answering_buttons[(i - 1 + count) % count]
		var next := _answering_buttons[(i + 1) % count]
		var previous_path := card.get_path_to(previous)
		var next_path := card.get_path_to(next)
		card.focus_neighbor_left = previous_path
		card.focus_neighbor_top = previous_path
		card.focus_previous = previous_path
		card.focus_neighbor_right = next_path
		card.focus_neighbor_bottom = next_path
		card.focus_next = next_path


func _set_answering_enabled(enabled: bool) -> void:
	for card: Button in _answering_buttons:
		card.disabled = not enabled
		card.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	if not enabled:
		_clear_shortcuts()


func _restore_focus() -> void:
	if _closing or not _choices_armed or _answering_buttons.is_empty():
		return
	var target := _last_focus
	if target == null or not is_instance_valid(target) or target.disabled:
		target = _answering_buttons[0]
	target.grab_focus()


func _clear_shortcuts() -> void:
	for card: Button in _answering_buttons:
		card.shortcut = null
