class_name MenuEquipPanel
extends Control
## The Items screen. Two halves, and the top one is the point:
##
##  * **ITEM BUTTONS** — the three C-buttons, drawn in the shape of the D-pad
##    they live on. This is where you BIND. In play those buttons draw what you
##    put on them and nothing else; there is no cycling out there, because a
##    button you have to watch to use is not a button you can reach for.
##  * **PRIMARY / ALTERNATE** — the two hands, twice over, with the live set
##    marked. Changed here only.
##
## It owns no state. Everything reads `Game` and writes back through
## `bind_quick` / `cycle_armament` / `swap_loadout` (docs/CONTRACT.md §4.1,
## §8 *Armaments*), so there is no path where this screen and the buttons
## disagree about what the hero is holding.

signal back_requested
signal notice(text: String, is_error: bool)
## A slot settled on a new armament — the menu answers with a click.
signal value_settled

const FRAME_SIZE := Vector2(1060, 604)
## No "swap set" shortcut in the hint on purpose: the button that swaps in play
## is D-pad ↓, and inside a menu D-pad ↓ is how focus moves. Rather than teach a
## second, contradictory binding, the swap is a focusable button and the detail
## pane names the in-play one.
const HINT := "↑↓←→ Select    Enter / A Bind    Esc / B Back"

## Sized so the whole screen -- header, three cards, footer -- fits inside 720p
## without the frame running off the bottom. It did, the first time: the cards
## are minimums and a VBox grows past its parent without complaining.
const ICON_PX := 48
const QUICK_ICON_PX := 40
const SLOT_MIN := Vector2(228, 98)
const QUICK_MIN := Vector2(150, 104)

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

## `set_index * 2 + hand_index` -> the button. Flat because the focus wiring
## walks it as a grid and a nested array only makes that harder to read.
var _slots: Array[Button] = []
## Indexed by Game.QUICK_LEFT / QUICK_UP / QUICK_RIGHT, not by screen order.
var _quick_slots: Array[Button] = []
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
	title.text = "ITEMS"
	header.add_child(title)

	var body := MarginContainer.new()
	body.theme_type_variation = &"MenuBodyPad"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var split := HBoxContainer.new()
	split.name = "Split"
	split.add_theme_constant_override("separation", 24)
	body.add_child(split)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	split.add_child(left)

	_build_quick(left)
	_build_sets(left)

	# The right column is where the screen talks back: the detail pane for
	# whatever has focus on the left.
	#
	# The way out USED to sit under it. It moved to the POUCH, which is the screen
	# that now carries every number the decision is made out of -- the bag's
	# worth, the purse, and the fee. This screen is about what is in your HANDS;
	# leaving is about what is in your BAG, and the two questions had no business
	# sharing a frame.
	var right := VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size.x = 360
	right.add_theme_constant_override("separation", 12)
	split.add_child(right)

	_build_detail(right)
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


## The three C-buttons, drawn in the physical shape of the D-pad they sit on:
## ← and → flanking ↑, with the ↓ direction spelled out beneath as the swap.
## docs/CONTRACT.md §2.5 #6 — the arrangement IS the label. A vertical list of
## "Item 1 / Item 2 / Item 3" makes the player translate, every time.
func _build_quick(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Quick"
	card.theme_type_variation = &"MenuSection"
	parent.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	var caption := Label.new()
	caption.theme_type_variation = &"MenuHeading"
	caption.text = "ITEM BUTTONS"
	inner.add_child(caption)

	var cross := HBoxContainer.new()
	cross.alignment = BoxContainer.ALIGNMENT_CENTER
	cross.add_theme_constant_override("separation", 12)
	inner.add_child(cross)

	# Order on screen is ← ↑ →, which is the order they sit on the pad. The
	# slot indices are NOT in that order (LEFT=0, UP=1, RIGHT=2 happens to
	# match, but the mapping is stated rather than assumed).
	_quick_slots.resize(Game.QUICK_SLOTS)
	for entry in [
		{"slot": Game.QUICK_LEFT, "glyph": "◄", "action": &"item_left"},
		{"slot": Game.QUICK_UP, "glyph": "▲", "action": &"item_up"},
		{"slot": Game.QUICK_RIGHT, "glyph": "►", "action": &"item_right"},
	]:
		_quick_slots[entry["slot"]] = _make_quick(cross, entry["slot"],
			entry["glyph"], entry["action"])

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	inner.add_child(foot)
	var swap_note := Label.new()
	swap_note.theme_type_variation = &"MenuHint"
	swap_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swap_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_note.text = "▼  swaps the loadout below"
	foot.add_child(swap_note)
	_swap = Button.new()
	_swap.theme_type_variation = &"MenuRow"
	_swap.text = "Swap Set"
	_swap.focus_mode = Control.FOCUS_ALL
	_swap.custom_minimum_size.x = 190
	_swap.pressed.connect(func() -> void:
		Game.swap_loadout()
		value_settled.emit())
	foot.add_child(_swap)


func _make_quick(parent: Node, slot: int, glyph: String, action: StringName) -> Button:
	var b := Button.new()
	b.name = "Quick_%d" % slot
	b.theme_type_variation = &"MenuSlot"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = QUICK_MIN
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta(&"quick", slot)
	b.set_meta(&"action", action)
	b.set_meta(&"glyph", glyph)
	parent.add_child(b)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 8
	col.offset_bottom = -8

	var cap := Label.new()
	cap.name = "Caption"
	cap.theme_type_variation = &"MenuValue"
	cap.text = glyph
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cap)

	var art := CenterContainer.new()
	art.name = "Art"
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)
	art.add_child(_new_icon(QUICK_ICON_PX))
	var letters := Label.new()
	letters.name = "Letters"
	letters.theme_type_variation = &"MenuMuted"
	letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(letters)

	var value := Label.new()
	value.name = "Value"
	value.theme_type_variation = &"MenuSlotStat"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(value)

	b.pressed.connect(func() -> void: _cycle_bind(b))
	b.focus_entered.connect(func() -> void: _describe_quick(b))
	b.mouse_entered.connect(func() -> void: _describe_quick(b))
	return b


func _build_sets(parent: Node) -> void:
	var stack := VBoxContainer.new()
	stack.name = "Sets"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
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
	col.offset_top = 6
	col.offset_bottom = -6

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

	art.add_child(_new_icon(ICON_PX))

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


func _new_icon(px: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(px, px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# NEAREST. These are 5-bit posterised bakes; a bilinear stretch turns the
	# palette into a gradient and the whole PSX read goes with it.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _build_detail(parent: Node) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.theme_type_variation = &"MenuSection"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	# The bind cross, left to right, wrapping.
	var cross: Array[Button] = [
		_quick_slots[Game.QUICK_LEFT],
		_quick_slots[Game.QUICK_UP],
		_quick_slots[Game.QUICK_RIGHT],
	]
	MenuUtil.chain_row(cross)

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
		# Down out of the cross lands on the hands. The cross has three columns
		# and the hands have two, so ← and ↑ both fall to the left hand and →
		# falls to the right — the nearest slot under the finger, not index 0.
		MenuUtil.link_down(cross[col if col < cols else cols - 1], top)
	MenuUtil.link_down(cross[cross.size() - 1], _slots[cols - 1])
	# Swap Set is the last control on the screen, so it closes the loop back to
	# the top of the cross -- everything here is reachable by pressing one
	# direction repeatedly and nothing is an orphan. The way out used to be this
	# last stop; it lives on the POUCH now, with the numbers it is decided from.
	_swap.focus_neighbor_bottom = _swap.get_path_to(cross[0])
	_swap.focus_next = _swap.get_path_to(cross[0])
	_swap.focus_neighbor_left = ^"."
	_swap.focus_neighbor_right = ^"."


# --- State ------------------------------------------------------------------

## Focus entry point when the screen opens: the ← item button, because binding
## items is what this screen is for and the hands below it rarely change.
func focus_first() -> void:
	if not _quick_slots.is_empty() and _quick_slots[Game.QUICK_LEFT] != null:
		_quick_slots[Game.QUICK_LEFT].grab_focus()


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
	for b in _quick_slots:
		_paint_quick(b)
	var focused := get_viewport().gui_get_focus_owner()
	if _slots.has(focused):
		_describe(focused as Button)
	elif _quick_slots.has(focused):
		_describe_quick(focused as Button)
	else:
		_describe_quick(_quick_slots[Game.QUICK_LEFT])


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


func _paint_quick(b: Button) -> void:
	var slot: int = b.get_meta(&"quick")
	var id := Game.quick(slot)

	var icon := b.get_node("Col/Art/Icon") as TextureRect
	var letters := b.get_node("Col/Art/Letters") as Label
	var value := b.get_node("Col/Value") as Label

	var tex := ArmamentDb.icon(id)
	icon.texture = tex
	icon.visible = tex != null
	letters.visible = tex == null
	# An unbound button says so rather than showing a blank cell. A blank cell
	# reads as a bug; "Unbound" reads as a choice you have not made yet.
	letters.text = "·" if id == &"" else ArmamentDb.letter(id)
	value.text = "Unbound" if id == &"" else ArmamentDb.name_of(id)

	# Marked when it is the thing currently in his right hand, so the screen
	# answers "which button am I holding?" without the player working it out.
	# The mark goes on the GLYPH, not after the name: appending " · drawn" made
	# the longest names overrun the slot and sit on top of their neighbours.
	var live := Game.armament(Game.HAND_RIGHT) == id and id != &""
	var glyph: String = b.get_meta(&"glyph")
	(b.get_node("Col/Caption") as Label).text = "%s ●" % glyph if live else glyph


func _armament(set_index: int, hand: StringName) -> StringName:
	return Game.armament_in(set_index, hand)


func _cycle_bind(b: Button) -> void:
	var slot: int = b.get_meta(&"quick")
	var before := Game.quick(slot)
	Game.cycle_quick_bind(slot)
	if Game.quick(slot) == before:
		notice.emit("You have not found anything to bind there yet.", false)
		return
	refresh()
	_describe_quick(b)
	value_settled.emit()


func _describe_quick(b: Button) -> void:
	if b == null or _detail_name == null:
		return
	var slot: int = b.get_meta(&"quick")
	var action: StringName = b.get_meta(&"action")
	var id := Game.quick(slot)

	_detail_hand.text = "ITEM BUTTON  ·  %s" % MenuUtil.action_title(action)
	_detail_name.text = "Unbound" if id == &"" else ArmamentDb.name_of(id)
	_detail_blurb.text = ("Nothing on this button. Confirm to bind something you have found."
		if id == &"" else ArmamentDb.blurb(id))

	var ammo := ArmamentDb.ammo_of(id)
	_detail_ammo.visible = ammo != &""
	if ammo == &"arrows":
		_detail_ammo.text = "%d arrows" % Game.arrows

	_detail_legend.text = "In play: %s or %s draws it, and puts it away again." % [
		MenuUtil.pad_label(action), MenuUtil.key_label(action)]


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

	# Hands are changed HERE and nowhere else -- the D-pad belongs to the item
	# buttons now. Saying so on the screen is the only place a player finds out.
	_detail_legend.text = "Confirm to change this hand. In play, %s swaps to the other set." % (
		MenuUtil.pad_label(&"item_down"))
