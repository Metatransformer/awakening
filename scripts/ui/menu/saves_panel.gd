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
## so this panel restores the state and hands the destination upward: out through
## `PauseMenu.load_requested` and into `Flow.resume`, which is what actually
## travels. **`Flow.continue_game` is the wrong end to hand it to** -- the slot is
## already spent by the time this emits, and that one starts by reading it again.

signal back_requested
signal notice(text: String, is_error: bool)
signal saved_to(slot: int)
## Emitted after Saves.load_slot() has restored Game. `dest` is the
## {scene, room, pos, yaw} dictionary the caller must transition to.
signal load_requested(slot: int, dest: Dictionary)

enum Mode { SAVE, LOAD }

const ERASE_WIDTH := 150

var mode: Mode = Mode.SAVE
var confirm: MenuConfirm = null

var _header_slot: VBoxContainer
var _hint: Label
var _list: VBoxContainer
var _back: Button
var _slots: Array[MenuSlotRow] = []
var _erasers: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No `theme` of its own: `PauseMenu` puts `UITheme.theme()` on Root and every
	# panel inherits it. This used to override a `menu_theme.tres` that Root
	# carried while the screens converted one at a time; they all have, so the
	# per-panel override went with the .tres.
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
	# `edge_to_edge`: the plate header and the footer reach the frame's edge and
	# the body owns its inset.
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	frame.add_child(col)

	# The title is the one thing on this screen that changes with the mode, so
	# the header is rebuilt rather than written into: a `PlateHeader` composes
	# its kicker, emblem and title together and there is no half of it worth
	# reaching back into.
	_header_slot = VBoxContainer.new()
	_header_slot.add_theme_constant_override("separation", 0)
	col.add_child(_header_slot)
	_rebuild_header()

	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_list)

	for i in Saves.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
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
		UITheme.style_pill_button(erase)
		# The one destructive control in the menu, so it is the one control that
		# wears DANGER. It is not a red BOX -- a filled red slab beside three
		# quiet cards is louder than the thing it deletes; red TEXT on the same
		# plate as everything else is the kit's way of saying the same thing.
		for state in ["font_color", "font_hover_color", "font_focus_color",
				"font_pressed_color"]:
			erase.add_theme_color_override(state, UITheme.DANGER)
		erase.custom_minimum_size = Vector2(ERASE_WIDTH, MenuSlotRow.CARD_HEIGHT)
		erase.pressed.connect(func() -> void: _on_erase_pressed(slot_index))
		row.add_child(erase)
		_erasers.append(erase)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	_hint = Label.new()
	UITheme.apply_text_style(_hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
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
	_rebuild_header()
	_hint.text = ("↑↓ / D-pad Select    → Erase    E / A Save    Esc / B Back"
		if mode == Mode.SAVE
		else "↑↓ / D-pad Select    → Erase    E / A Load    Esc / B Back")
	for i in _slots.size():
		var card := _slots[i]
		card.refresh()
		var usable := mode == Mode.SAVE or not card.is_empty
		card.disabled = not usable
		# Disabled alone would still accept a grab_focus(); FOCUS_NONE is what
		# makes the row genuinely unreachable by stick, arrow keys and Tab.
		card.focus_mode = Control.FOCUS_ALL if usable else Control.FOCUS_NONE
		# ...and it says why, at full contrast through the dimmed card. See
		# `MenuSlotRow.refuse` and the refusal law it cites.
		card.refuse("" if usable else "Nothing here to load.")
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


## The plate header for the mode we are in. Rebuilt rather than edited: see the
## note where `_header_slot` is created.
func _rebuild_header() -> void:
	if _header_slot == null:
		return
	for child in _header_slot.get_children():
		child.queue_free()
		_header_slot.remove_child(child)
	var saving := mode == Mode.SAVE
	UiKit.plate_header(_header_slot, {
		"kicker": "Three slots  ·  on this machine",
		"title": "Save Game" if saving else "Load Game",
		"emblem": UiKit.action_icon("save"),
	})
