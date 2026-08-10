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

## No "swap set" shortcut in the hint on purpose: the button that swaps the set
## in play is D-pad ↑, and inside a menu ↑ is how focus moves. Rather than teach
## a second, contradictory binding, the swap is a focusable button and the detail
## pane names the in-play one.
const HINT := "↑↓←→ Select    E / A Change    Esc / B Back"

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
## three paged screens all expose this and none of them builds a strip of its
## own — the ring, the strip and the stack all live in one place.
var _hrow: HBoxContainer

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
## Stat id -> the right-hand Label on its row. See `_build_stats`.
var _stat_values: Dictionary[StringName, Label] = {}


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
	# A bound bottle's cell shows what is IN it, so brewing, drinking or blowing
	# one changes this screen without the binding changing at all.
	Bus.bottles_changed.connect(func(_c: Array) -> void: refresh())
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
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.theme_type_variation = &"MenuStack"
	frame.add_child(col)

	var header := PanelContainer.new()
	header.theme_type_variation = &"MenuHeader"
	col.add_child(header)
	# The shared tab strip goes here and there is no title Label: the lit tab is
	# the title. See `build_tabs` and `MenuPageTabs`.
	_hrow = HBoxContainer.new()
	header.add_child(_hrow)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hrow.add_child(gap)

	var body := MarginContainer.new()
	body.theme_type_variation = &"MenuBodyPad"
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
	_build_stats(right)
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
	var card := PanelContainer.new()
	card.name = "Worn"
	card.theme_type_variation = &"MenuSection"
	# A floor, not a share. The two hand slots beside it are a measured 228 px
	# each (`SLOT_MIN`) and cannot give any of it back, and the detail column is
	# 360; this is what is left of 1220 with the separations taken off.
	card.custom_minimum_size.x = DOLL_W
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var head := Label.new()
	head.theme_type_variation = &"MenuHeading"
	head.text = "WORN"
	col.add_child(head)

	var doll := MenuPaperDoll.new()
	doll.name = "Doll"
	# Before `add_child`, because `_ready` reads it to pick a minimum size.
	doll.full = true
	col.add_child(doll)

	# The legend. Four gold pips on a plate is a quantity with no unit until
	# something says what one pip is, and the two ladders are different lengths
	# -- three rungs of plate against four of a stone (K.FORGE_MAX, K.JEWEL_MAX).
	var legend := Label.new()
	legend.theme_type_variation = &"MenuHint"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.text = "Plate at the smith, stones at her bench.  %d rungs of plate, %d of a stone." % [
		K.FORGE_MAX, K.JEWEL_MAX]
	col.add_child(legend)


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
	var foot := HBoxContainer.new()
	foot.name = "SwapRow"
	foot.add_theme_constant_override("separation", 12)
	parent.add_child(foot)
	var note := Label.new()
	note.theme_type_variation = &"MenuHint"
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.text = "In play, %s swaps sets" % MenuUtil.pad_label(&"loadout_swap")
	foot.add_child(note)
	_swap = Button.new()
	_swap.theme_type_variation = &"MenuRow"
	_swap.text = "Swap Set"
	_swap.focus_mode = Control.FOCUS_ALL
	_swap.custom_minimum_size.x = 190
	_swap.pressed.connect(func() -> void:
		Game.swap_loadout()
		value_settled.emit())
	foot.add_child(_swap)


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
	var card := PanelContainer.new()
	card.name = "Stats"
	card.theme_type_variation = &"MenuSection"
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var head := Label.new()
	head.theme_type_variation = &"MenuHeading"
	head.text = "THE HERO"
	col.add_child(head)

	for id: StringName in STATS:
		var row := HBoxContainer.new()
		row.name = String(id).capitalize()
		col.add_child(row)

		var name_label := Label.new()
		name_label.theme_type_variation = &"MenuSlotStat"
		name_label.text = String(STAT_NAMES[id])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var value := Label.new()
		value.theme_type_variation = &"MenuValue"
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
	# Swap Set is the last control on the screen, so it closes the loop back to
	# the top-left hand -- everything here is reachable by pressing one direction
	# repeatedly and nothing is an orphan. The way out used to be this last stop;
	# it lives on the POUCH now, with the numbers it is decided from.
	_swap.focus_neighbor_bottom = _swap.get_path_to(_slots[0])
	_swap.focus_next = _swap.get_path_to(_slots[0])
	_swap.focus_neighbor_left = ^"."
	_swap.focus_neighbor_right = ^"."


# --- State ------------------------------------------------------------------

## Focus entry point when the screen opens: the primary right hand, because that
## is the one the D-pad cycles in play and so the one a player comes here to set.
func focus_first() -> void:
	if not _slots.is_empty():
		_slots[HANDS.find(Game.HAND_RIGHT)].grab_focus()


## Where the shared tab strip is inserted. See `_hrow`.
func tab_host() -> HBoxContainer:
	return _hrow


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
	_refresh_stats()
	var focused := get_viewport().gui_get_focus_owner()
	if _slots.has(focused):
		_describe(focused as Button)
	else:
		_describe(_slots[HANDS.find(Game.HAND_RIGHT)])


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
