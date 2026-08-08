class_name MenuSavesPanel
extends Control
## The three-slot save/load screen, drawn entirely from `Saves.peek(slot)`.
##
## Two modes share one screen. In SAVE mode every slot is usable and a used slot
## asks before it is overwritten. In LOAD mode an empty slot is `disabled` AND
## `FOCUS_NONE`, so neither a mouse nor a stick can reach it — loading nothing is
## impossible, not merely unwise.
##
## `Saves.load_slot()` deliberately does not change scenes (docs/CONTRACT.md §8),
## so this panel restores the state and hands the destination upward.

signal back_requested
signal notice(text: String, is_error: bool)
signal saved_to(slot: int)
## Emitted after Saves.load_slot() has restored Game. `dest` is the
## {scene, room, pos, yaw} dictionary the caller must transition to.
signal load_requested(slot: int, dest: Dictionary)

enum Mode { SAVE, LOAD }

const FRAME_SIZE := Vector2(1060, 604)
const ERASE_WIDTH := 150

var mode: Mode = Mode.SAVE
var confirm: MenuConfirm = null

var _title: Label
var _hint: Label
var _list: VBoxContainer
var _back: Button
var _slots: Array[MenuSlotRow] = []
var _erasers: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func bind_confirm(c: MenuConfirm) -> void:
	confirm = c


func _build() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.theme_type_variation = &"MenuFrame"
	frame.custom_minimum_size = FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.theme_type_variation = &"MenuStack"
	frame.add_child(col)

	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	col.add_child(header)
	_title = Label.new()
	_title.theme_type_variation = &"MenuTitle"
	_title.text = "SAVE GAME"
	header.add_child(_title)

	var body := MarginContainer.new()
	body.theme_type_variation = &"MenuBodyPad"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_list = VBoxContainer.new()
	_list.theme_type_variation = &"MenuList"
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_list)

	for i in Saves.SLOTS:
		var row := HBoxContainer.new()
		_list.add_child(row)

		var card := MenuSlotRow.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		card.setup(i)
		var slot_index := i
		card.pressed.connect(func() -> void: _on_slot_pressed(slot_index))
		_slots.append(card)

		var erase := Button.new()
		erase.text = "Erase"
		erase.theme_type_variation = &"MenuDanger"
		erase.custom_minimum_size = Vector2(ERASE_WIDTH, MenuSlotRow.CARD_HEIGHT)
		erase.pressed.connect(func() -> void: _on_erase_pressed(slot_index))
		row.add_child(erase)
		_erasers.append(erase)

	var footer := PanelContainer.new()
	footer.theme_type_variation = &"MenuFooter"
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	_hint = Label.new()
	_hint.theme_type_variation = &"MenuHint"
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frow.add_child(_hint)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(spacer)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 160
	_back.pressed.connect(func() -> void: back_requested.emit())
	frow.add_child(_back)


# --- Mode / refresh ---------------------------------------------------------

func open_mode(m: Mode) -> void:
	mode = m
	refresh_all()


## Re-peek every slot and re-derive what is reachable. Called on every open, so
## a save made a moment ago shows up without the menu being rebuilt.
func refresh_all() -> void:
	_title.text = "SAVE GAME" if mode == Mode.SAVE else "LOAD GAME"
	_hint.text = ("↑↓ / D-pad Select    → Erase    Enter / A Save    Esc / B Back"
		if mode == Mode.SAVE
		else "↑↓ / D-pad Select    → Erase    Enter / A Load    Esc / B Back")
	for i in _slots.size():
		var card := _slots[i]
		card.refresh()
		var usable := mode == Mode.SAVE or not card.is_empty
		card.disabled = not usable
		# Disabled alone would still accept a grab_focus(); FOCUS_NONE is what
		# makes the row genuinely unreachable by stick, arrow keys and Tab.
		card.focus_mode = Control.FOCUS_ALL if usable else Control.FOCUS_NONE
		var e := _erasers[i]
		e.disabled = card.is_empty
		e.focus_mode = Control.FOCUS_NONE if card.is_empty else Control.FOCUS_ALL
	_wire_focus()


func _wire_focus() -> void:
	var n := _slots.size()
	for i in n:
		var card := _slots[i]
		var erase := _erasers[i]
		var up: Control = _slots[i - 1] if i > 0 else _back
		var down: Control = _slots[i + 1] if i < n - 1 else _back
		card.focus_neighbor_top = card.get_path_to(up)
		card.focus_neighbor_bottom = card.get_path_to(down)
		card.focus_previous = card.get_path_to(up)
		card.focus_next = card.get_path_to(down)
		card.focus_neighbor_left = ^"."

		var eup: Control = _erasers[i - 1] if i > 0 else _back
		var edown: Control = _erasers[i + 1] if i < n - 1 else _back
		erase.focus_neighbor_top = erase.get_path_to(eup)
		erase.focus_neighbor_bottom = erase.get_path_to(edown)
		erase.focus_neighbor_right = ^"."
		MenuUtil.link_right(card, erase)
		erase.focus_neighbor_left = erase.get_path_to(card)

	if n > 0:
		_back.focus_neighbor_top = _back.get_path_to(_slots[n - 1])
		_back.focus_neighbor_bottom = _back.get_path_to(_slots[0])
		_back.focus_previous = _back.get_path_to(_slots[n - 1])
		_back.focus_next = _back.get_path_to(_slots[0])
	_back.focus_neighbor_left = ^"."
	_back.focus_neighbor_right = ^"."


func focus_first() -> void:
	var list: Array = []
	list.append_array(_slots)
	list.append(_back)
	var c := MenuUtil.first_focusable(list)
	if c:
		c.grab_focus()


# --- Actions ----------------------------------------------------------------

func _on_slot_pressed(slot: int) -> void:
	var card := _slots[slot]
	if mode == Mode.LOAD:
		# Belt and braces: the row is already disabled + unfocusable when empty.
		if card.is_empty:
			notice.emit("Slot %d is empty — there is nothing to load." % (slot + 1), true)
			return
		var dest := Saves.load_slot(slot)
		if dest.is_empty():
			notice.emit("Slot %d could not be read." % (slot + 1), true)
			return
		load_requested.emit(slot, dest)
		return

	if not card.is_empty:
		var ok: bool = await _ask(
			"Overwrite Slot %d?" % (slot + 1),
			"Slot %d already holds a save from %s. It will be replaced." % [
				slot + 1, String(card.header.get("stamp", "an earlier session"))],
			"Overwrite", "Cancel", true, card)
		if not ok:
			return
	_do_save(slot)


func _do_save(slot: int) -> void:
	if Saves.save(slot):
		_slots[slot].refresh()
		refresh_all()
		notice.emit("Saved to slot %d." % (slot + 1), false)
		saved_to.emit(slot)
	else:
		notice.emit("Could not write slot %d." % (slot + 1), true)


func _on_erase_pressed(slot: int) -> void:
	if _slots[slot].is_empty:
		return
	var ok: bool = await _ask(
		"Erase Slot %d?" % (slot + 1),
		"This deletes the save permanently. It cannot be undone.",
		"Erase", "Keep", true, _erasers[slot])
	if not ok:
		return
	Saves.erase(slot)
	refresh_all()
	focus_first()
	notice.emit("Slot %d erased." % (slot + 1), false)


func _ask(title: String, body: String, ok_text: String, cancel_text: String,
		danger: bool, ret: Control) -> bool:
	if confirm == null:
		return true
	confirm.ask(title, body, ok_text, cancel_text, danger, ret)
	return await confirm.resolved
