class_name SlotTile
extends RefCounted
## One worn slot, beside the doll.
##
##     ┌─┬──────────────┐        ┌──────────────┬─┐
##     │▌│ [◈]  CHEST   │        │  AMULET  [◈] │▌│
##     │▌│      HEAVY   │        │  WIND        │▌│
##     │▌│      ■■□     │        │     ■□□□     │▌│
##     └─┴──────────────┘        └──────────────┴─┘
##      mirror = false            mirror = true
##
## The tile replaces the leader-line plate the drawn paper doll used. Wires from
## a plate to a spot on a stick figure were the old doll's best idea and they do
## not survive the figure becoming a 3D render: a line ending on a shoulder that
## moves with an idle animation reads as a line that missed.
##
## What replaces the wire is ORDER. The armour column runs down the body — chest,
## arms, legs, boots — and the jewel column runs in `Game.JEWEL_SLOTS` order, so
## the position in the stack still says where on the body the thing goes.
##
## MIRROR IS NOT DECORATION. The right column reads inward, toward the figure, so
## the two stacks frame the doll instead of both pointing away from it. The
## semantic edge goes on the outside of each column for the same reason.
##
## An empty slot draws AT FULL STRUCTURE with a dash in the value. Hiding it, or
## drawing it as a bare box, is the refusal-law mistake in another costume: "what
## have I not started yet" is the question this column is for, and it can only be
## answered if the unstarted ones are on screen.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const KitIconScript := preload("res://scripts/ui/kit/kit_icon.gd")

const HEIGHT := 52
const ICON_PX := 22
const EDGE_PX := 3
## Rung pips. Small enough that four plus their gaps sit under the value without
## widening the tile — the ladder is a shape to glance at, not a thing to count.
const PIP := 6.0
const PIP_GAP := 3.0
## Nothing in the value column, drawn rather than left blank. A tile with an
## empty line in it reads as a tile that failed to load.
const UNSET := "—"


## `config` keys — all optional except `caption`:
##   caption   : String            the slot's name, uppercased
##   value     : String            what is in it; defaults to UNSET
##   icon      : Texture2D|String  a 22px glyph
##   pips      : Vector2i          (filled, total) rung ladder; omit for none
##   edge      : Color             semantic strip; omit for none
##   mirror    : bool              lay the tile out right-to-left
##   on_press  : Callable          makes the tile focusable and pressable
static func build(parent: Node, config: Dictionary) -> Button:
	var caption := String(config.get("caption", ""))
	if caption.is_empty():
		push_error("[SlotTile] reason=a slot tile requires a caption; tile omitted")
		return null

	var value := String(config.get("value", ""))
	var live := not value.is_empty()
	var mirror := bool(config.get("mirror", false))
	var press: Variant = config.get("on_press")

	var tile := Button.new()
	tile.custom_minimum_size.y = HEIGHT
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Never `flat = true`: it drops the styleboxes, and the tile's whole state
	# vocabulary — lit vs unstarted, hovered, focused — is in them.
	tile.focus_mode = Control.FOCUS_ALL if press is Callable else Control.FOCUS_NONE
	tile.mouse_filter = Control.MOUSE_FILTER_STOP if press is Callable \
		else Control.MOUSE_FILTER_IGNORE
	tile.toggle_mode = false
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		tile.add_theme_stylebox_override(state, _box(state, live, mirror, config.get("edge")))
	# The Button's own label is empty; everything visible is the row below it, so
	# the three columns can be laid out rather than crammed into one string.
	tile.text = ""

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 9 if not mirror else 7)
	pad.add_theme_constant_override("margin_right", 7 if not mirror else 9)
	pad.add_theme_constant_override("margin_top", 5)
	pad.add_theme_constant_override("margin_bottom", 5)
	tile.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)

	# Built even when there is no icon yet, and hidden instead of omitted: the
	# slot a tile marks does not change, but what is IN it does, and a tile whose
	# icon appears later must not shove its own text sideways when it arrives.
	var icon := KitIconScript.resolve(config.get("icon"))
	var crest := KitIconScript.rect(icon, ICON_PX, 0.95 if live else 0.5)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crest.visible = icon != null

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
	var name_lbl := Label.new()
	name_lbl.text = caption.to_upper()
	name_lbl.horizontal_alignment = align
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(name_lbl, UITheme.TYPE_CAPTION, UITheme.TEXT_DIM)
	text.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = value if live else UNSET
	value_lbl.horizontal_alignment = align
	value_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(value_lbl, UITheme.TYPE_LABEL_SM,
		UITheme.TEXT if live else UITheme.GRAY_4)
	text.add_child(value_lbl)

	var pips: Variant = config.get("pips")
	var ladder: Control = null
	if pips is Vector2i and (pips as Vector2i).y > 0:
		var rungs := _Pips.new()
		ladder = rungs
		rungs.filled = (pips as Vector2i).x
		rungs.total = (pips as Vector2i).y
		rungs.mirror = mirror
		# Colours are handed in rather than read from the theme: an inner class
		# does not share the outer script's `const UITheme` preload, and the two
		# ways round that are a second preload or this.
		rungs.on_color = Pal.GOLD
		rungs.off_color = UITheme.GRAY_3
		rungs.custom_minimum_size.y = PIP + 4.0
		rungs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(rungs)

	# Mirroring is a child-order swap, not an RTL flag: the icon has to be on the
	# outside edge in both columns and RTL would move the text but not it.
	if mirror:
		row.add_child(text)
		row.add_child(crest)
	else:
		row.add_child(crest)
		row.add_child(text)

	# The handles `repaint` needs. Meta rather than node paths, so a change to the
	# layout above cannot silently turn a repaint into a no-op.
	tile.set_meta(&"slot_value", value_lbl)
	tile.set_meta(&"slot_crest", crest)
	tile.set_meta(&"slot_pips", ladder)
	tile.set_meta(&"slot_mirror", mirror)
	tile.set_meta(&"slot_edge", config.get("edge"))

	if press is Callable:
		tile.pressed.connect(press as Callable)
	if parent != null:
		parent.add_child(tile)
	return tile


## Update a built tile in place. Only the keys present in `config` change.
##
## In place and not rebuild-the-column, for two reasons that both bit the screen
## this component replaced: rebuilding drops focus (the equipment screen's graph
## has to survive a repaint that happens while you are standing on a row), and it
## reflows, so a tile you were reading jumps a few pixels every time a signal
## fires.
##
## Accepted keys: `value`, `icon`, `pips`, `edge`. A tile with no value is drawn
## as unstarted — dash, dimmed icon, sunk fill — never removed.
static func repaint(tile: Variant, config: Dictionary) -> void:
	var button := tile as Button
	if button == null:
		return
	# Every lookup here goes through `has_meta` first. `set_meta(k, null)` ERASES
	# the key rather than storing a null, and `get_meta(k, null)` still pushes an
	# error when the key is missing — a nil default reads as "no default" to the
	# engine. So a tile built with no icon, no pips or no edge would spam the log
	# on every repaint, which is how a real error gets lost in the noise.
	var mirror := bool(button.get_meta(&"slot_mirror", false))
	var value_lbl := button.get_meta(&"slot_value") as Label if button.has_meta(&"slot_value") \
		else null
	var live := value_lbl != null and value_lbl.text != UNSET

	if config.has("value"):
		var value := String(config["value"])
		live = not value.is_empty()
		if value_lbl != null:
			value_lbl.text = value if live else UNSET
			UITheme.apply_text_style(value_lbl, UITheme.TYPE_LABEL_SM,
				UITheme.TEXT if live else UITheme.GRAY_4)

	if config.has("icon") and button.has_meta(&"slot_crest"):
		var crest := button.get_meta(&"slot_crest") as TextureRect
		if crest != null:
			crest.texture = KitIconScript.resolve(config["icon"])
			crest.visible = crest.texture != null
			crest.modulate.a = 0.95 if live else 0.5

	if config.has("pips") and button.has_meta(&"slot_pips"):
		var ladder := button.get_meta(&"slot_pips") as Control
		var want: Variant = config["pips"]
		if ladder != null and want is Vector2i:
			ladder.set(&"filled", (want as Vector2i).x)
			ladder.set(&"total", (want as Vector2i).y)
			ladder.queue_redraw()

	# The edge STICKS unless this call names a new one. A repaint that only
	# changed the value would otherwise strip the semantic strip off the tile,
	# which is the kind of loss that shows up two screens later as "the potion
	# colour stopped working".
	var edge: Variant = null
	if config.has("edge"):
		edge = config["edge"]
	elif button.has_meta(&"slot_edge"):
		edge = button.get_meta(&"slot_edge")
	button.set_meta(&"slot_edge", edge)

	# Always re-stamped, not only when `edge` is passed: `live` may have flipped
	# above, and the idle fill is what carries it.
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _box(state, live, mirror, edge))


## The plate. Same flat-glass vocabulary as VerbRow: a hairline all round, a
## semantic strip on the outer edge, and a lift on hover/focus. An unstarted slot
## is drawn at a lower fill rather than a different shape, so the column stays
## one column.
static func _box(state: String, live: bool, mirror: bool, edge: Variant) -> StyleBoxFlat:
	var armed := state == "hover" or state == "focus" or state == "pressed"
	var box := StyleBoxFlat.new()
	# ONE idle fill for started and unstarted alike. `PLATE_SUNK` was tried here
	# and is backwards: it is a LIGHTER grey than `PLATE`, so over a dark card the
	# four slots you have not begun were the four that glowed. What carries the
	# state is the text and the icon going dim — a column of eight has to stay one
	# column, or the eye reads two groups that mean nothing.
	box.bg_color = UITheme.PLATE_HOVER if armed else UITheme.PLATE
	box.set_border_width_all(1)
	box.border_color = UITheme.HIGHLIGHT if armed else UITheme.GRAY_3
	box.set_corner_radius_all(UITheme.RADIUS)
	if edge is Color:
		var side := SIDE_RIGHT if mirror else SIDE_LEFT
		box.set_border_width(side, EDGE_PX)
		# One border colour per StyleBoxFlat, so a lit semantic edge and a lit
		# hairline cannot both be drawn. The edge wins when the slot is idle and
		# the focus ring wins when it is armed — focus has to be unmissable, and
		# the rarity/allegiance colour is still readable underneath as fill.
		if not armed:
			box.border_color = edge as Color
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


## The rung ladder: filled squares for what you own, hollow for what is left.
## A shape rather than "2 / 3", because eight of these read as one picture and
## eight fractions read as eight sums.
##
## Gold for the filled pip is the one place chrome carries it, and it is not a
## break of the theme's gold-is-text law: a bought rung IS a numeral, drawn as a
## square so the count is read at a glance instead of summed.
class _Pips extends Control:
	var filled: int = 0
	var total: int = 0
	var mirror: bool = false
	var on_color: Color = Color.WHITE
	var off_color: Color = Color(1, 1, 1, 0.4)

	func _draw() -> void:
		if total <= 0:
			return
		var span := float(total) * SlotTile.PIP + float(total - 1) * SlotTile.PIP_GAP
		var x: float = size.x - span if mirror else 0.0
		var y := (size.y - SlotTile.PIP) * 0.5
		for i in total:
			var at := Rect2(Vector2(x + float(i) * (SlotTile.PIP + SlotTile.PIP_GAP), y),
				Vector2(SlotTile.PIP, SlotTile.PIP))
			if i < filled:
				draw_rect(at, on_color)
			else:
				draw_rect(at, off_color, false, 1.0)
