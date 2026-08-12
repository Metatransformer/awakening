class_name MenuEquipPanel
extends Control
## The Items screen: **PRIMARY / ALTERNATE**, the two hands twice over, with the
## live set marked.
##
## IT USED TO HAVE A SECOND HALF and losing it is the point. An ITEM BUTTONS card
## sat on top of this, four cells in the shape of the D-pad, and it existed to
## let the player decide which direction the bow was on. The D-pad cycles now
## (see the note in project.godot) so there is nothing to bind, and this screen
## is down to the one question it was always best at: what goes in which hand.
##
## In play, D-pad ← / → step the right hand through this same pool and ↑ swaps
## the set — the same `cycle_armament` and `swap_loadout` calls the buttons here
## make. One code path, so the screen and the D-pad cannot disagree about what
## the hero is holding (docs/CONTRACT.md §4.1, §8 *Armaments*).

signal back_requested
signal notice(text: String, is_error: bool)
## A slot settled on a new armament — the menu answers with a click.
signal value_settled

## Sized so the whole screen -- header, cards, footer -- fits inside 720p without
## the frame running off the bottom. It did, the first time: the cards are
## minimums and a VBox grows past its parent without complaining.
const ICON_PX := 48
const SLOT_MIN := Vector2(228, 98)
## The worn-slots column. See `_build_doll`.
const DOLL_W := 284

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
## The header's row, so `PauseMenu` can drop the shared tab strip into it. The
## four paged screens all expose this and none of them builds a strip of its
## own — the ring, the strip and the stack all live in one place.
var _hrow: HBoxContainer

var _slots: Array[Button] = []
## The eight kit-wheel cells, in slot order — index IS the sector. See
## `_build_wheel`.
var _wheel_cells: Array[Button] = []
var _set_frames: Array[PanelContainer] = []
var _set_marks: Array[Label] = []
var _swap: Button
var _back: Button
var _detail_name: Label
var _detail_hand: Label
var _detail_blurb: Label
var _detail_legend: Label
var _detail_ammo: Label
## Stat id -> the right-hand Label on its row. See `_build_stats`.
var _stat_values: Dictionary[StringName, Label] = {}
## Permanent utility tools are inspection-only Labels under the worn column.
var _tools: VBoxContainer
var _tools_empty: Label


func _ready() -> void:
	_assert_agrees_with_game()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No `theme` of its own: `PauseMenu` puts `UITheme.theme()` on Root and every
	# panel inherits it. This used to override a `menu_theme.tres` that Root
	# carried while the screens converted one at a time; they all have, so the
	# per-panel override went with the .tres.
	_build()
	# The D-pad can change the loadout while this screen is open (it is a pause
	# menu, but nothing stops a director or a rebind from firing), and a save
	# loaded from the Saves screen changes it too. Redraw on the signal rather
	# than trusting that open() is the only way in.
	Bus.loadout_changed.connect(func(_s: int, _r: StringName, _l: StringName) -> void: refresh())
	# A bound bottle's cell shows what is IN it, so brewing, drinking or blowing
	# one changes this screen without the binding changing at all.
	Bus.bottles_changed.connect(func(_c: Array) -> void: refresh())
	# And the wheel can change without this screen touching it: picking something
	# up auto-binds it, and a save loaded from the Saves screen replaces all eight.
	Bus.wheel_changed.connect(func(_s: Array) -> void: refresh())
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
	# `edge_to_edge`: the tab strip and the footer reach the frame's edge and the
	# body between them owns its own inset — the same construction the counters
	# and the locker use, so the three pause screens and the five shop screens are
	# one piece of furniture.
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 0)
	frame.add_child(col)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 14, 6, 14, 0))
	col.add_child(header)
	# The shared tab strip goes here and there is no title Label: the lit tab is
	# the title. See `build_tabs` and `MenuPageTabs`.
	_hrow = HBoxContainer.new()
	header.add_child(_hrow)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hrow.add_child(gap)

	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var split := HBoxContainer.new()
	split.name = "Split"
	split.add_theme_constant_override("separation", 24)
	body.add_child(split)

	_build_doll(split)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	split.add_child(left)

	_build_sets(left)
	_build_swap(left)
	_build_wheel(left)

	# The right column is where the screen talks back: the detail pane for
	# whatever has focus on the left.
	#
	# The way out USED to sit under it. It moved to INVENTORY, which is the screen
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
	_build_stats(right)
	_wire_focus()

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(spacer)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size.x = 160
	_back.pressed.connect(func() -> void: back_requested.emit())
	frow.add_child(_back)


## The figure, with all ten worn slots on it.
##
## **The first column of this screen, and read-only.** The two hands are set here
## by pressing a slot; the eight worn slots are not settable anywhere, because
## there is nothing to set -- a piece of plate is a ladder you climbed at the
## smith and a stone is one you climbed at her bench, and neither comes off. What
## the doll is for is the question those two counters cannot answer between them:
## *what am I wearing, all of it, at once.* The smith knows about armour and she
## knows about stones, and until this column existed nowhere in the game put the
## eight on one body.
##
## Nothing here takes focus, so the 2x2-plus-Swap graph `_wire_focus` builds is
## untouched by the column appearing beside it.
func _build_doll(parent: Node) -> void:
	# NOT a card. It was one, and so were the detail pane and the stat block, and
	# three nested boxes inside a boxed frame is the "everything is a panel" read
	# the kit exists to undo — it also cost 44 px of padding a column, which is
	# what pushed this screen past `MenuUtil.FRAME_SIZE` and made the window fill
	# the viewport. A `section_rule` divides a column for free.
	var col := VBoxContainer.new()
	col.name = "Worn"
	# A floor, not a share. The two hand slots beside it are a measured 228 px
	# each (`SLOT_MIN`) and cannot give any of it back, and the detail column is
	# 360; this is what is left of 1220 with the separations taken off.
	col.custom_minimum_size.x = DOLL_W
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)

	UITheme.section_rule(col, "WORN")

	var doll := MenuPaperDoll.new()
	doll.name = "Doll"
	# Before `add_child`, because `_ready` reads it to pick a minimum size.
	doll.full = true
	col.add_child(doll)

	# The legend. Four gold pips on a plate is a quantity with no unit until
	# something says what one pip is, and the two ladders are different lengths
	# -- three rungs of plate against four of a stone (K.FORGE_MAX, K.JEWEL_MAX).
	var legend := Label.new()
	UITheme.apply_text_style(legend, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.text = "Plate at the smith, stones at her bench.  %d rungs of plate, %d of a stone." % [
		K.FORGE_MAX, K.JEWEL_MAX]
	col.add_child(legend)

	UITheme.section_rule(col, "TOOLS")
	_tools = VBoxContainer.new()
	_tools.name = "Tools"
	_tools.add_theme_constant_override(&"separation", 5)
	col.add_child(_tools)
	_tools_empty = Label.new()
	_tools_empty.text = "None yet."
	UITheme.apply_text_style(_tools_empty, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	col.add_child(_tools_empty)


## The button that swaps the live set.
##
## It used to live under the ITEM BUTTONS card, which is gone. It sits under the
## two sets now rather than going with it, because it was never an item-button
## control: it is the second half of "which of these two am I holding", and both
## halves are on screen together here.
##
## The row beside it names the IN-PLAY input, which is D-pad ↑ and is not a thing
## you can press in this menu (↑ moves focus). A screen that only offered its own
## button would leave the pad shortcut undiscoverable.
func _build_swap(parent: Node) -> void:
	# A `VerbRow`, and the in-play input goes in its META column rather than in a
	# note beside it. The note and the button were two controls saying one thing —
	# "this is how you swap" — laid out as though they were unrelated, and the
	# meta column is the component's answer to exactly that.
	_swap = UiKit.verb_row(parent, {
		"label": "Swap Set",
		"icon": UiKit.action_icon("upgrade"),
		"meta": "in play  %s" % MenuUtil.pad_label(&"loadout_swap"),
		"on_press": func() -> void:
			Game.swap_loadout()
			value_settled.emit(),
	})
	_swap.name = "SwapRow"


## The kit wheel's eight bindings, and the only place they can be edited by hand.
##
## **This screen used to have an ITEM BUTTONS card and it was deleted; this is
## not it coming back.** That card was the *only* way an item became reachable,
## so every player had to come here before a new bow meant anything — which is
## the complaint CONTRACT §4.1 records and the reason the bindings went. The
## wheel auto-binds on pickup (`Game.wheel_auto_bind`), so this card is where you
## go to *rearrange* a wheel that already works, or to fill a slot after the
## eighth thing you own found the wheel full. Nobody has to visit it. That is the
## whole difference, and it is the difference the deletion was about.
##
## Laid out as ONE ROW rather than as a ring or a 4x2 grid, with each cell
## captioned by the direction it lives on. A grid is not a wheel either — no
## rectangular arrangement of eight cells maps onto eight compass points — so
## rather than imply a layout that is a lie, the direction is written on the
## cell. `↑→` and not `↗`: the cardinal arrows in these captions are known to
## render in this face and the diagonals are not, and a card whose labels come
## out as boxes is worse than a card with two-character labels.
const WHEEL_DIRS: Array[String] = ["↑", "↑→", "→", "↓→", "↓", "↓←", "←", "↑←"]
const WHEEL_CELL := Vector2(50, 50)


func _build_wheel(parent: Node) -> void:
	var col := VBoxContainer.new()
	col.name = "Wheel"
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)

	UITheme.section_rule(col, "KIT WHEEL")

	var row := HBoxContainer.new()
	row.name = "Cells"
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for slot in Game.WHEEL_SLOTS:
		_wheel_cells.append(_make_wheel_cell(row, slot))

	var hint := Label.new()
	UITheme.apply_text_style(hint, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# It names the button and the RELEASE, because the release is the half a
	# player will not guess: every other hold in this game commits on the way
	# down. New things bind themselves, which is the sentence that stops this card
	# reading as a chore you have to do before playing.
	hint.text = "Hold %s in play, point, and let go. New kit binds itself to a free slot." % (
		MenuUtil.pad_label(&"kit_wheel"))
	col.add_child(hint)


## One wheel slot: the direction over the icon. Smaller than a hand cell and
## deliberately so — there are eight of them and they are a reference, not the
## decision this screen is about.
func _make_wheel_cell(parent: Node, slot: int) -> Button:
	var b := Button.new()
	b.name = "Wheel_%d" % slot
	b.theme_type_variation = &"MenuSlot"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = WHEEL_CELL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta(&"slot", slot)
	parent.add_child(b)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caption := Label.new()
	caption.name = "Dir"
	UITheme.apply_text_style(caption, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	caption.text = WHEEL_DIRS[slot]
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(caption)

	var art := CenterContainer.new()
	art.name = "Art"
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)
	art.add_child(_new_icon(26))

	var letters := Label.new()
	letters.name = "Letters"
	letters.theme_type_variation = &"MenuValue"
	letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(letters)

	b.pressed.connect(func() -> void: _cycle_wheel(b))
	b.focus_entered.connect(func() -> void: _describe_wheel(b))
	b.mouse_entered.connect(func() -> void: _describe_wheel(b))
	return b


## What this slot may be set to, in cycle order: nothing, then everything the
## hero owns that is not already parked somewhere else on the wheel.
##
## The "not already elsewhere" filter is why this cycles rather than calling
## `Game.wheel_bind` with whatever comes next in `wheel_pool()`. `wheel_bind`
## SWAPS when the id is already bound — which is the right answer for a player
## deliberately moving something, and the wrong one for a cycle, where stepping
## past the bow would silently drag it out of the slot it was in and leave the
## bottle it displaced somewhere the player was not looking.
func _wheel_options(slot: int) -> Array[StringName]:
	var out: Array[StringName] = [&""]
	for id in Game.wheel_pool():
		var at := Game.wheel_slot_of(id)
		if at < 0 or at == slot:
			out.append(id)
	return out


func _cycle_wheel(b: Button) -> void:
	var slot: int = b.get_meta(&"slot")
	var options := _wheel_options(slot)
	if options.size() <= 1:
		notice.emit("Nothing to bind yet.", true)
		return
	var next := options[posmod(options.find(Game.wheel_at(slot)) + 1, options.size())]
	if not Game.wheel_bind(slot, next):
		notice.emit("Nothing else to put on that slot yet.", true)
		return
	refresh()
	_describe_wheel(b)
	value_settled.emit()


func _describe_wheel(b: Button) -> void:
	if b == null or _detail_name == null:
		return
	var slot: int = b.get_meta(&"slot")
	var id := Game.wheel_at(slot)
	var bottle := Game.bottle_index(id)

	_detail_hand.text = "KIT WHEEL  ·  %s" % WHEEL_DIRS[slot]
	if id == &"":
		_detail_name.text = "Empty"
		_detail_blurb.text = "Nothing on this direction. Confirm to put something on it."
	elif bottle >= 0:
		var potion := Game.bottle(bottle)
		_detail_name.text = "Empty Bottle" if potion == &"" else PotionDb.name_of(potion)
		# The routing, told to the player at the one moment it is a surprise: they
		# have just put a draught on the same ring as the hookshot, and the wheel
		# has to say that it knows the difference between the two.
		_detail_blurb.text = "Bottle %d. Releasing here selects it — %s drinks what is selected." % [
			bottle + 1, MenuUtil.pad_label(&"use_item")]
	else:
		_detail_name.text = ArmamentDb.name_of(id)
		_detail_blurb.text = "%s Releasing here puts it in the right hand." % ArmamentDb.blurb(id)

	_detail_ammo.visible = false
	_detail_legend.text = "Confirm to change it. In play, hold %s and point." % (
		MenuUtil.pad_label(&"kit_wheel"))


func _paint_wheel(b: Button) -> void:
	var slot: int = b.get_meta(&"slot")
	var id := Game.wheel_at(slot)
	var icon := b.get_node("Col/Art/Icon") as TextureRect
	var letters := b.get_node("Col/Art/Letters") as Label

	# A bottle has no baked icon — the HUD DRAWS its glass, which a TextureRect
	# cannot do — so it wears the two letters the rest of this kit falls back to.
	# `BT` and not the potion's own initials: what is bound is the GLASS, and the
	# cell would otherwise change identity every time the player drank.
	var tex := ArmamentDb.icon(id) if Game.bottle_index(id) < 0 else null
	icon.texture = tex
	icon.visible = tex != null
	letters.visible = tex == null
	letters.text = "" if id == &"" else ("BT" if Game.bottle_index(id) >= 0
		else ArmamentDb.letter(id))
	# Dimmed when the binding is cold, the same rule the HUD's wheel draws: a
	# working you have not read at the counter yet is still worth SEEING here.
	b.modulate = Color.WHITE if Game.wheel_ready(slot) else Color(1, 1, 1, 0.45)


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
		UITheme.style_panel(card, UITheme.BG_INSET)
		stack.add_child(card)
		_set_frames.append(card)

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		card.add_child(inner)

		var caption := HBoxContainer.new()
		inner.add_child(caption)
		var name_label := Label.new()
		UITheme.apply_text_style(name_label, UITheme.TYPE_H2, UITheme.ACCENT)
		name_label.text = SET_NAMES[set_index]
		caption.add_child(name_label)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.add_child(gap)
		# The live-set mark. A colour difference alone is not enough — the
		# styleguide's palette is five bits deep and two stone greys apart is
		# not a state anyone reads at a glance.
		# HIGHLIGHT, not gold. "IN HAND" is a STATE — which of the two sets is
		# live — and the off-white is what this UI uses to mean "this one".
		var mark := Label.new()
		UITheme.apply_text_style(mark, UITheme.TYPE_LABEL_MD, UITheme.HIGHLIGHT)
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
	UITheme.apply_text_style(caption, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
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
	var col := VBoxContainer.new()
	col.name = "Detail"
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	parent.add_child(col)

	# The kicker / title / value stack of a `PlateHeader`, written by hand because
	# this one is REWRITTEN on every focus change — an identity that flickers is
	# not one, so the composite is built once and this pane is not it.
	_detail_hand = Label.new()
	UITheme.apply_text_style(_detail_hand, UITheme.TYPE_CAPTION, UITheme.ACCENT)
	col.add_child(_detail_hand)

	_detail_name = Label.new()
	UITheme.apply_text_style(_detail_name, UITheme.TYPE_H1, UITheme.TEXT)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_name)

	_detail_ammo = Label.new()
	UITheme.apply_text_style(_detail_ammo, UITheme.TYPE_LABEL_MD, UITheme.ACCENT)
	col.add_child(_detail_ammo)

	_detail_blurb = Label.new()
	UITheme.apply_text_style(_detail_blurb, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_detail_blurb)

	_detail_legend = Label.new()
	UITheme.apply_text_style(_detail_legend, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	_detail_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_legend)


## **Five stats, and there is no sixth** (docs/GDD.md §6.6, docs/SCOPE.md §1).
## Damage, speed, max health, stamina, soak. Every one is a number the player can
## feel inside one run; a stat that needs a tooltip explaining why it matters is
## a stat that does not matter, and the moment this card grows a sixth row the
## gear loop has become a character sheet.
##
## **Nothing here is recomputed.** Every value comes back from an accessor on
## `Game` -- the same call the sword, the hero's locomotion, the HUD and the two
## shop counters read -- so a stat block and the game can never disagree about
## what the hero is. The first draft of this summed `K.PLATE_HEAVY_SOAK` itself
## and was wrong within an hour of the jewelcrafter landing, because `Ward` is a
## second faucet on soak and the panel did not know.
##
## Here rather than on the pouch because this is the screen about WHAT YOU ARE:
## the pouch is what you are carrying and what leaving will cost. It sits under
## the detail pane on the right, which is the column that already answers
## "and what does that mean" for whatever has focus.
##
## No art, per STYLEGUIDE §5 -- the menu owns no art. Five labelled rows.
const STATS: Array[StringName] = [
	&"damage", &"speed", &"health", &"stamina", &"soak",
]
const STAT_NAMES := {
	&"damage": "DAMAGE",
	&"speed": "SPEED",
	&"health": "MAX HEALTH",
	&"stamina": "STAMINA",
	&"soak": "SOAK",
}


func _build_stats(parent: Node) -> void:
	var col := VBoxContainer.new()
	col.name = "Stats"
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)

	UITheme.section_rule(col, "THE HERO")

	for id: StringName in STATS:
		var row := HBoxContainer.new()
		row.name = String(id).capitalize()
		col.add_child(row)

		var name_label := Label.new()
		UITheme.apply_text_style(name_label, UITheme.TYPE_PARAGRAPH_1, UITheme.TEXT_DIM)
		name_label.text = String(STAT_NAMES[id])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var value := Label.new()
		UITheme.apply_text_style(value, UITheme.TYPE_LABEL_MD, UITheme.ACCENT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_stat_values[id] = value


## The five numbers, in the units the player feels them in.
##
## Quarter-hearts for the two that are quarter-hearts, because that is what the
## HUD draws and what `Hero.hurt` subtracts. Speed as a percentage of the
## measured `[oot]` run rather than in metres a second: the player has no way to
## know what 4.8 m/s felt like, and 100% is a ceiling they can read as one.
func _refresh_stats() -> void:
	if _stat_values.is_empty():
		return
	_stat_values[&"damage"].text = "+%d %s" % [
		Game.sword_bonus(), _quarters(Game.sword_bonus())]
	_stat_values[&"speed"].text = "%.1f%%" % (Game.speed_mult() * 100.0)
	_stat_values[&"health"].text = "%d hearts" % Game.heart_containers()
	_stat_values[&"stamina"].text = "%d" % int(round(Game.max_stamina))
	# The exact figure beside the one that actually applies, because
	# `armour_soak()` FLOORS and four pieces at 0.4 each is 1.6 -- a player who
	# only saw "1" would read three purchases as having done nothing.
	var exact := Game.armour_soak_exact()
	var applied := Game.armour_soak()
	_stat_values[&"soak"].text = "-%d %s" % [applied, _quarters(applied)] \
		if is_equal_approx(exact, floorf(exact)) \
		else "-%d %s  (%.1f)" % [applied, _quarters(applied), exact]


## "quarter" or "quarters". A one-word helper rather than living with "+1
## quarters", because the stat block is five short lines and a grammar slip on
## one of them is the whole card looking unfinished.
func _quarters(n: int) -> String:
	return "quarter" if n == 1 else "quarters"


## Grid wiring, done by hand because MenuUtil.chain does closed loops and this is
## a 2x2 with a button under it. Left/right wraps within a row; up/down walks the
## whole thing and lands on Swap Set at the bottom, so there is no orphan.
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
	# Swap Set drops into the wheel row, and the wheel row closes the loop back to
	# the top-left hand -- everything here is reachable by pressing one direction
	# repeatedly and nothing is an orphan. The way out used to be this last stop;
	# it lives on INVENTORY now, with the numbers it is decided from.
	_swap.focus_neighbor_left = ^"."
	_swap.focus_neighbor_right = ^"."
	if _wheel_cells.is_empty():
		_swap.focus_neighbor_bottom = _swap.get_path_to(_slots[0])
		_swap.focus_next = _swap.get_path_to(_slots[0])
		return
	# ← / → walk the eight cells and wrap, which is the ONE place on this screen
	# where wrapping is more than a convenience: the row is a ring flattened out,
	# and ↑← sitting next to ↑ is the only thing on screen that says so.
	MenuUtil.chain_row(_wheel_cells)
	for i in _wheel_cells.size():
		var cell := _wheel_cells[i]
		cell.focus_neighbor_top = cell.get_path_to(_swap)
		cell.focus_previous = cell.get_path_to(_swap)
		cell.focus_neighbor_bottom = cell.get_path_to(_slots[0])
		cell.focus_next = cell.get_path_to(_slots[0])
	MenuUtil.link_down(_swap, _wheel_cells[0])


# --- State ------------------------------------------------------------------

## Focus entry point when the screen opens: the primary right hand, because that
## is the one the D-pad cycles in play and so the one a player comes here to set.
func focus_first() -> void:
	if not _slots.is_empty():
		_slots[HANDS.find(Game.HAND_RIGHT)].grab_focus()


## Where the shared tab strip is inserted. See `_hrow`.
func tab_host() -> HBoxContainer:
	return _hrow


## The top row of focusables, landing target first — see `MenuPageTabs` and
## `PauseMenu._tab_row`. The PRIMARY set's two hands, right hand first, because
## the right hand is where `focus_first` opens and so the control a player is
## standing on when they press ↑.
func tab_row() -> Array:
	if _slots.size() < HANDS.size():
		return []
	var out: Array = []
	var right := HANDS.find(Game.HAND_RIGHT)
	for i in HANDS.size():
		out.append(_slots[right if i == 0 else (right + i) % HANDS.size()])
	return out


func refresh() -> void:
	_refresh_tools()
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
	for b in _wheel_cells:
		_paint_wheel(b)
	_refresh_stats()
	# The detail pane follows focus, and focus can be on a wheel cell — a refresh
	# that always re-described a HAND would throw away the wheel's blurb every time
	# a binding changed, which is precisely when the player is reading it.
	var focused := get_viewport().gui_get_focus_owner()
	if _wheel_cells.has(focused):
		_describe_wheel(focused as Button)
	elif _slots.has(focused):
		_describe(focused as Button)
	else:
		_describe(_slots[HANDS.find(Game.HAND_RIGHT)])


## Rebuild the authored permanent-tool manifest without adding anything to the
## hand, wheel, drag, sale, or focus graphs above.
func _refresh_tools() -> void:
	if _tools == null or _tools_empty == null:
		return
	UITheme.clear_children(_tools)
	var any := false
	for definition: Dictionary in ToolDb.all():
		if not bool(definition.get("owned", false)):
			continue
		var row := VBoxContainer.new()
		row.add_theme_constant_override(&"separation", 1)
		_tools.add_child(row)
		var title := Label.new()
		title.text = String(definition.get("display_name", ""))
		UITheme.apply_text_style(title, UITheme.TYPE_LABEL_MD, UITheme.TEXT)
		row.add_child(title)
		var blurb := Label.new()
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.text = String(definition.get("blurb", ""))
		UITheme.apply_text_style(blurb, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
		row.add_child(blurb)
		any = true
	_tools.visible = any
	_tools_empty.visible = not any


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
		# An ERROR. A press that changed nothing is a refusal, and it was flagged
		# `false` back when the notice bar's two tones were gold and gold: nothing
		# on screen was going to contradict it. The bar draws SUCCESS green now, so
		# "nothing happened" arrived looking like "done".
		notice.emit("Nothing else to put in that hand yet.", true)
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

	# The two hands are not symmetrical in play and the legend has to say which
	# one you are looking at. ← / → walk the RIGHT hand through the same pool this
	# cell cycles; the left hand is set here and here only, because the D-pad has
	# no spare direction for it and a shield you can lose mid-fight is a bug.
	if hand == Game.HAND_RIGHT:
		_detail_legend.text = "Confirm to change it. In play, %s / %s step this hand." % [
			MenuUtil.pad_label(&"weapon_prev"), MenuUtil.pad_label(&"weapon_next")]
	else:
		_detail_legend.text = "Confirm to change it. In play, %s swaps the whole set." % (
			MenuUtil.pad_label(&"loadout_swap"))
