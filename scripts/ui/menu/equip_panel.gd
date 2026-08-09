class_name MenuEquipPanel
extends Control
## The Equipment screen: two loadouts, two hands each, arranged the way Elden
## Ring arranges them — left hand on the left, right hand on the right, the live
## set marked.
##
## It owns no state. Every slot reads `Game.armament()` and writes back through
## `Game.cycle_armament()` / `Game.swap_loadout()` — the same two calls the D-pad
## makes in play (docs/CONTRACT.md §4.1, §8 *Armaments*). That is deliberate: the
## screen is a way to SEE the loadout, not a second system for changing it, so
## there is no path where the menu and the D-pad disagree about what is in the
## hero's hands.
##
## Cycling in place rather than opening a "choose an armament" list, because the
## pool is three deep and a list would be a submenu whose only content is the
## thing already on screen. It also means the screen teaches the button: the
## slot legend says "D-Left", and pressing D-Left in play does exactly this.

signal back_requested
signal notice(text: String, is_error: bool)
## A slot settled on a new armament — the menu answers with a click.
signal value_settled

const FRAME_SIZE := Vector2(1060, 604)
## No "swap set" shortcut in the hint on purpose: the button that swaps in play
## is D-pad ↑, and inside a menu D-pad ↑ is how focus moves. Rather than teach a
## second, contradictory binding, the swap is a focusable button and the detail
## pane names the in-play one.
const HINT := "↑↓←→ Select    Enter / A Cycle    Esc / B Back"

const ICON_PX := 64
const SLOT_MIN := Vector2(228, 150)

## Row order on screen. Index into `Game.loadout`.
##
## Spelled as literals, not as `Game.PRIMARY`: `const` is evaluated at parse
## time and an autoload is a node that does not exist yet, so referencing one
## here is a parse error rather than a value. `_assert_agrees_with_game()`
## checks at runtime that these have not drifted from the definitions on Game.
const SETS: Array[int] = [0, 1]                                  # PRIMARY, ALTERNATE
const SET_NAMES := {0: "PRIMARY", 1: "ALTERNATE"}
## Column order. Left hand first, because that is the side it is on.
const HANDS: Array[StringName] = [&"left", &"right"]
const HAND_NAMES := {&"left": "LEFT HAND", &"right": "RIGHT HAND"}
## Which in-play button cycles this hand. Kept as action ids rather than glyphs
## so a rebind shows up here without anyone editing this file.
const HAND_ACTION := {&"left": &"item_left", &"right": &"item_right"}

## `set_index * 2 + hand_index` -> the button. Flat because the focus wiring
## walks it as a grid and a nested array only makes that harder to read.
var _slots: Array[Button] = []
var _set_frames: Array[PanelContainer] = []
var _set_marks: Array[Label] = []
var _swap: Button
var _back: Button
var _detail_name: Label
var _detail_hand: Label
var _detail_blurb: Label
var _detail_legend: Label
var _detail_ammo: Label


func _ready() -> void:
	_assert_agrees_with_game()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	# The D-pad can change the loadout while this screen is open (it is a pause
	# menu, but nothing stops a director or a rebind from firing), and a save
	# loaded from the Saves screen changes it too. Redraw on the signal rather
	# than trusting that open() is the only way in.
	Bus.loadout_changed.connect(func(_s: int, _r: StringName, _l: StringName) -> void: refresh())
	refresh()


## The literals above have to mean what Game means by them. If somebody
## reorders Game's constants this screen would silently edit the wrong hand,
## which is the kind of bug that only shows up as "the menu lies".
func _assert_agrees_with_game() -> void:
	assert(SETS[0] == Game.PRIMARY and SETS[1] == Game.ALTERNATE,
		"MenuEquipPanel.SETS has drifted from Game.PRIMARY/ALTERNATE")
	assert(HANDS[0] == Game.HAND_LEFT and HANDS[1] == Game.HAND_RIGHT,
		"MenuEquipPanel.HANDS has drifted from Game.HAND_LEFT/HAND_RIGHT")


# --- Chrome -----------------------------------------------------------------

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
	col.name = "Col"
	col.theme_type_variation = &"MenuStack"
	frame.add_child(col)

	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	col.add_child(header)
	var title := Label.new()
	title.theme_type_variation = &"MenuTitle"
	title.text = "EQUIPMENT"
	header.add_child(title)

	var body := MarginContainer.new()
	body.theme_type_variation = &"MenuBodyPad"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var split := HBoxContainer.new()
	split.name = "Split"
	split.add_theme_constant_override("separation", 24)
	body.add_child(split)

	_build_sets(split)
	_build_detail(split)
	_wire_focus()

	var footer := PanelContainer.new()
	footer.theme_type_variation = &"MenuFooter"
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	var hint := Label.new()
	hint.theme_type_variation = &"MenuHint"
	hint.text = HINT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frow.add_child(hint)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(spacer)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 160
	_back.pressed.connect(func() -> void: back_requested.emit())
	frow.add_child(_back)


func _build_sets(parent: Node) -> void:
	var stack := VBoxContainer.new()
	stack.name = "Sets"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 16)
	parent.add_child(stack)

	for si in SETS.size():
		var set_index: int = SETS[si]

		var card := PanelContainer.new()
		card.name = "Set%d" % set_index
		card.theme_type_variation = &"MenuSection"
		stack.add_child(card)
		_set_frames.append(card)

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		card.add_child(inner)

		var caption := HBoxContainer.new()
		inner.add_child(caption)
		var name_label := Label.new()
		name_label.theme_type_variation = &"MenuHeading"
		name_label.text = SET_NAMES[set_index]
		caption.add_child(name_label)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.add_child(gap)
		# The live-set mark. A colour difference alone is not enough — the
		# styleguide's palette is five bits deep and two stone greys apart is
		# not a state anyone reads at a glance.
		var mark := Label.new()
		mark.theme_type_variation = &"MenuValue"
		caption.add_child(mark)
		_set_marks.append(mark)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		inner.add_child(row)
		for hand in HANDS:
			_slots.append(_make_slot(row, set_index, hand))

	var swap_row := HBoxContainer.new()
	stack.add_child(swap_row)
	_swap = Button.new()
	_swap.theme_type_variation = &"MenuCommand"
	_swap.text = "Swap Set"
	_swap.focus_mode = Control.FOCUS_ALL
	_swap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_swap.pressed.connect(func() -> void:
		Game.swap_loadout()
		value_settled.emit())
	swap_row.add_child(_swap)


## One armament cell: icon over name, with the hand it belongs to above it.
## A Button rather than a Panel because it has to take pad focus, and every
## focusable thing in this menu is a Button so the theme's focus box is one
## stylebox rather than four.
func _make_slot(parent: Node, set_index: int, hand: StringName) -> Button:
	var b := Button.new()
	b.name = "Slot_%d_%s" % [set_index, hand]
	b.theme_type_variation = &"MenuSlot"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = SLOT_MIN
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta(&"set_index", set_index)
	b.set_meta(&"hand", hand)
	parent.add_child(b)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_right = -12
	col.offset_top = 10
	col.offset_bottom = -10

	var caption := Label.new()
	caption.name = "Caption"
	caption.theme_type_variation = &"MenuHint"
	caption.text = HAND_NAMES[hand]
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(caption)

	var art := CenterContainer.new()
	art.name = "Art"
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# NEAREST. These are 5-bit posterised bakes; a bilinear stretch turns the
	# palette into a gradient and the whole PSX read goes with it.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(icon)

	var letters := Label.new()
	letters.name = "Letters"
	letters.theme_type_variation = &"MenuValue"
	letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(letters)

	var value := Label.new()
	value.name = "Value"
	value.theme_type_variation = &"MenuSlotStat"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(value)

	b.pressed.connect(func() -> void: _cycle(b))
	b.focus_entered.connect(func() -> void: _describe(b))
	b.mouse_entered.connect(func() -> void: _describe(b))
	return b


func _build_detail(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.theme_type_variation = &"MenuSection"
	card.custom_minimum_size.x = 360
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	_detail_hand = Label.new()
	_detail_hand.theme_type_variation = &"MenuHint"
	col.add_child(_detail_hand)

	_detail_name = Label.new()
	_detail_name.theme_type_variation = &"MenuSlotTitle"
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_name)

	_detail_ammo = Label.new()
	_detail_ammo.theme_type_variation = &"MenuValue"
	col.add_child(_detail_ammo)

	_detail_blurb = Label.new()
	_detail_blurb.theme_type_variation = &"MenuSlotStat"
	_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_detail_blurb)

	_detail_legend = Label.new()
	_detail_legend.theme_type_variation = &"MenuHint"
	_detail_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_legend)


## Grid wiring, done by hand because MenuUtil.chain does columns and this is a
## 2x2 with a button under it. Left/right wraps within a row; up/down walks the
## whole column and lands on Swap Set at the bottom, so there is no orphan.
func _wire_focus() -> void:
	var cols := HANDS.size()
	for i in _slots.size():
		var row := i / cols
		var col := i % cols
		MenuUtil.link_right(_slots[i], _slots[row * cols + (col + 1) % cols])
	for col in cols:
		var top := _slots[col]
		var bottom := _slots[cols + col]
		MenuUtil.link_down(top, bottom)
		MenuUtil.link_down(bottom, _swap)
		# Closing the loop upward puts Swap Set one press above the top row,
		# which is how a pad user gets back without walking the whole grid.
		_swap.focus_neighbor_bottom = _swap.get_path_to(top)
	_swap.focus_neighbor_left = ^"."
	_swap.focus_neighbor_right = ^"."


# --- State ------------------------------------------------------------------

## Focus entry point when the screen opens: the live set's right hand, because
## that is the one that swings and the one a player came here to change.
func focus_first() -> void:
	var live := clampi(Game.loadout_set, 0, SETS.size() - 1)
	var idx := live * HANDS.size() + HANDS.find(Game.HAND_RIGHT)
	if idx >= 0 and idx < _slots.size():
		_slots[idx].grab_focus()


func refresh() -> void:
	if _slots.is_empty():
		return
	for i in _set_frames.size():
		var live: bool = SETS[i] == Game.loadout_set
		_set_marks[i].text = "IN HAND" if live else ""
		# Modulate rather than a second stylebox: the dimmed set must still be
		# legible, since half the point of the screen is comparing the two.
		_set_frames[i].modulate = Color.WHITE if live else Color(1, 1, 1, 0.62)
	for b in _slots:
		_paint(b)
	var focused := get_viewport().gui_get_focus_owner()
	_describe(focused as Button if _slots.has(focused) else _slots[0])


func _paint(b: Button) -> void:
	var set_index: int = b.get_meta(&"set_index")
	var hand: StringName = b.get_meta(&"hand")
	var id: StringName = _armament(set_index, hand)

	var icon := b.get_node("Col/Art/Icon") as TextureRect
	var letters := b.get_node("Col/Art/Letters") as Label
	var value := b.get_node("Col/Value") as Label

	var tex := ArmamentDb.icon(id)
	icon.texture = tex
	icon.visible = tex != null
	letters.visible = tex == null
	letters.text = ArmamentDb.letter(id)

	var text := ArmamentDb.name_of(id)
	var ammo := ArmamentDb.ammo_of(id)
	if ammo == &"arrows" and id == &"arrow":
		text = "%s  ×%d" % [text, Game.arrows]
	value.text = text
	# A hand holding something the player does not own is the state the
	# ownership gate exists to prevent; if one ever appears, say so on the slot
	# rather than drawing it as if it were fine.
	b.disabled = false
	if id != &"" and not Game.armament_owned(id):
		value.text = "%s  (not owned)" % text


func _armament(set_index: int, hand: StringName) -> StringName:
	return Game.armament_in(set_index, hand)


func _cycle(b: Button) -> void:
	var set_index: int = b.get_meta(&"set_index")
	var hand: StringName = b.get_meta(&"hand")
	var before := _armament(set_index, hand)
	Game.cycle_armament(hand, 1, set_index)
	var after := _armament(set_index, hand)

	if after == before:
		notice.emit("Nothing else to put in that hand yet.", false)
		return
	refresh()
	_describe(b)
	value_settled.emit()


func _describe(b: Button) -> void:
	if b == null or _detail_name == null:
		return
	var set_index: int = b.get_meta(&"set_index")
	var hand: StringName = b.get_meta(&"hand")
	var id := _armament(set_index, hand)

	_detail_hand.text = "%s  ·  %s" % [SET_NAMES[set_index], HAND_NAMES[hand]]
	_detail_name.text = ArmamentDb.name_of(id)
	_detail_blurb.text = ArmamentDb.blurb(id)

	var ammo := ArmamentDb.ammo_of(id)
	_detail_ammo.visible = ammo != &""
	if ammo == &"arrows":
		_detail_ammo.text = "%d arrows" % Game.arrows

	var action: StringName = HAND_ACTION[hand]
	_detail_legend.text = "In play: %s or %s cycles this hand.    %s swaps the set." % [
		MenuUtil.pad_label(action), MenuUtil.key_label(action),
		MenuUtil.pad_label(&"item_up")]
