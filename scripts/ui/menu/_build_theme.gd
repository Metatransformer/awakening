extends SceneTree
## Dev-only generator for the menu's Theme resource and its two slider-grabber
## textures. The menu styles itself from ONE Theme (see docs/CONTRACT.md §10 and
## the P14 brief) — nothing in scripts/ui/menu/** may reach for
## add_theme_*_override to paint a control by hand.
##
## Run it twice the first time, with an import in between, because the theme has
## to `load()` the PNGs this script writes:
##
##   godot --path . --headless -s scripts/ui/menu/_build_theme.gd
##   godot --path . --headless --import
##   godot --path . --headless -s scripts/ui/menu/_build_theme.gd
##
## Palette: dark quarried stone, warm gold leaf, parchment text — the colours of
## a torch-lit dungeon, matching refs/screens/ rather than Godot's default grey.

const OUT_THEME := "res://scenes/ui/menu/menu_theme.tres"
const OUT_GRAB := "res://scenes/ui/menu/slider_grabber.png"
const OUT_GRAB_HL := "res://scenes/ui/menu/slider_grabber_hl.png"

# --- Palette ----------------------------------------------------------------
const VOID := Color("07060500")          # fully transparent
const STONE_0 := Color("0b0907")         # deepest recess
const STONE_1 := Color("17130e")         # frame body
const STONE_2 := Color("221c14")         # row body
const STONE_3 := Color("342a1c")         # row hover
const STONE_4 := Color("463823")         # row pressed
const GOLD := Color("c8992f")
const GOLD_BRIGHT := Color("f6d271")
const GOLD_DIM := Color("6f5a26")
const PARCH := Color("ece0c2")
const MUTED := Color("9c8f74")
const DANGER := Color("d9603f")
const INK := Color("00000000")

static var FONT_NAMES := PackedStringArray([
	"Trebuchet MS", "Verdana", "Tahoma", "DejaVu Sans",
	"Liberation Sans", "Noto Sans", "Arial", "Helvetica", "sans-serif",
])


func _initialize() -> void:
	_write_grabbers()
	var t := Theme.new()
	_build(t)
	var err := ResourceSaver.save(t, OUT_THEME)
	if err != OK:
		push_error("theme save failed: %d" % err)
		quit(1)
		return
	print("THEME_OK %s" % OUT_THEME)
	quit(0)


# --- Slider grabber ---------------------------------------------------------

func _write_grabbers() -> void:
	_diamond(GOLD_BRIGHT, STONE_0).save_png(ProjectSettings.globalize_path(OUT_GRAB))
	_diamond(Color("fff0c0"), GOLD).save_png(ProjectSettings.globalize_path(OUT_GRAB_HL))


## A small gold lozenge with a dark rim — reads as a gem, not a UI puck.
func _diamond(fill: Color, rim: Color) -> Image:
	const N := 22
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (N - 1) * 0.5
	for y in N:
		for x in N:
			var d := absf(x - c) + absf(y - c)
			if d <= 7.5:
				img.set_pixel(x, y, fill)
			elif d <= 10.0:
				img.set_pixel(x, y, rim)
	return img


# --- Style helpers ----------------------------------------------------------

static func _flat(bg: Color, border_w: int, border_c: Color, radius: int,
		mx: float = 0.0, my: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border_w)
	s.border_color = border_c
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s


static func _empty(mx: float = 0.0, my: float = 0.0) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s


func _font(embolden: float) -> Font:
	var f := SystemFont.new()
	f.font_names = FONT_NAMES
	f.font_weight = 700
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	if is_zero_approx(embolden):
		return f
	# SystemFont has no embolden of its own; FontVariation fattens the strokes so
	# headings read as carved rather than typeset.
	var v := FontVariation.new()
	v.base_font = f
	v.variation_embolden = embolden
	return v


# --- The theme --------------------------------------------------------------

func _build(t: Theme) -> void:
	var body := _font(0.0)
	var heavy := _font(0.45)
	t.default_font = body
	t.default_font_size = 20
	t.default_base_scale = 1.0

	_labels(t, heavy)
	_buttons(t, heavy)
	_panels(t)
	_sliders(t)
	_scroll(t)


func _labels(t: Theme, heavy: Font) -> void:
	t.set_color("font_color", "Label", PARCH)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_color("font_shadow_color", "Label", INK)
	t.set_constant("outline_size", "Label", 3)
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 0)
	t.set_constant("line_spacing", "Label", 4)

	_label_var(t, "MenuTitle", heavy, 38, GOLD_BRIGHT, 8)
	_label_var(t, "MenuHeading", heavy, 24, GOLD, 5)
	_label_var(t, "MenuValue", heavy, 21, GOLD_BRIGHT, 4)
	_label_var(t, "MenuKey", heavy, 20, PARCH, 4)
	_label_var(t, "MenuMuted", null, 17, MUTED, 3)
	_label_var(t, "MenuHint", null, 16, MUTED, 3)
	_label_var(t, "MenuError", heavy, 20, DANGER, 5)
	_label_var(t, "MenuSlotTitle", heavy, 24, GOLD_BRIGHT, 5)
	_label_var(t, "MenuSlotStat", null, 18, PARCH, 3)


func _label_var(t: Theme, name: String, f: Font, size: int, col: Color, outline: int) -> void:
	t.set_type_variation(name, "Label")
	if f:
		t.set_font("font", name, f)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, col)
	t.set_color("font_outline_color", name, Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", name, outline)


func _buttons(t: Theme, heavy: Font) -> void:
	# Base Button: a slab of stone with a hairline gold rim that lights up.
	var normal := _flat(STONE_2, 1, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.55), 4, 18, 11)
	var hover := _flat(STONE_3, 1, GOLD_DIM, 4, 18, 11)
	var pressed := _flat(STONE_4, 1, GOLD, 4, 18, 11)
	var disabled := _flat(Color(STONE_1.r, STONE_1.g, STONE_1.b, 0.6), 1, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.25), 4, 18, 11)
	# Focus draws OVER the state box, so it is a rim + a wash, never opaque.
	var focus := _flat(Color(GOLD.r, GOLD.g, GOLD.b, 0.13), 2, GOLD_BRIGHT, 4, 18, 11)
	focus.set_expand_margin_all(2.0)
	focus.border_width_left = 6

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", PARCH)
	t.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", GOLD_BRIGHT)
	t.set_color("font_disabled_color", "Button", Color(MUTED.r, MUTED.g, MUTED.b, 0.45))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Button", 4)
	t.set_font("font", "Button", heavy)
	t.set_font_size("font_size", "Button", 21)

	# The six root-menu commands: taller, centred, more air.
	t.set_type_variation("MenuCommand", "Button")
	t.set_font_size("font_size", "MenuCommand", 25)
	t.set_stylebox("normal", "MenuCommand", _flat(STONE_2, 1, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.5), 4, 20, 14))
	t.set_stylebox("hover", "MenuCommand", _flat(STONE_3, 1, GOLD_DIM, 4, 20, 14))
	t.set_stylebox("pressed", "MenuCommand", _flat(STONE_4, 1, GOLD, 4, 20, 14))
	t.set_stylebox("disabled", "MenuCommand", _flat(Color(STONE_1.r, STONE_1.g, STONE_1.b, 0.6), 1, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.25), 4, 20, 14))
	var cmd_focus := _flat(Color(GOLD.r, GOLD.g, GOLD.b, 0.15), 2, GOLD_BRIGHT, 4, 20, 14)
	cmd_focus.set_expand_margin_all(2.0)
	cmd_focus.border_width_left = 8
	t.set_stylebox("focus", "MenuCommand", cmd_focus)

	# An options/settings row: wide, left-aligned, low contrast until focused.
	t.set_type_variation("MenuRow", "Button")
	t.set_font_size("font_size", "MenuRow", 20)
	t.set_stylebox("normal", "MenuRow", _flat(Color(STONE_2.r, STONE_2.g, STONE_2.b, 0.75), 0, INK, 3, 16, 9))
	t.set_stylebox("hover", "MenuRow", _flat(STONE_3, 0, INK, 3, 16, 9))
	t.set_stylebox("pressed", "MenuRow", _flat(STONE_4, 0, INK, 3, 16, 9))
	t.set_stylebox("disabled", "MenuRow", _flat(Color(STONE_1.r, STONE_1.g, STONE_1.b, 0.5), 0, INK, 3, 16, 9))
	var row_focus := _flat(Color(GOLD.r, GOLD.g, GOLD.b, 0.16), 2, GOLD_BRIGHT, 3, 16, 9)
	row_focus.border_width_left = 7
	row_focus.set_expand_margin_all(2.0)
	t.set_stylebox("focus", "MenuRow", row_focus)

	# A save slot: a big card, framed even when idle so empty slots read.
	t.set_type_variation("MenuSlot", "Button")
	t.set_stylebox("normal", "MenuSlot", _flat(Color(STONE_2.r, STONE_2.g, STONE_2.b, 0.9), 1, GOLD_DIM, 5, 18, 14))
	t.set_stylebox("hover", "MenuSlot", _flat(STONE_3, 1, GOLD, 5, 18, 14))
	t.set_stylebox("pressed", "MenuSlot", _flat(STONE_4, 1, GOLD_BRIGHT, 5, 18, 14))
	t.set_stylebox("disabled", "MenuSlot", _flat(Color(STONE_1.r, STONE_1.g, STONE_1.b, 0.55), 1, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.3), 5, 18, 14))
	var slot_focus := _flat(Color(GOLD.r, GOLD.g, GOLD.b, 0.14), 3, GOLD_BRIGHT, 5, 18, 14)
	slot_focus.set_expand_margin_all(2.0)
	t.set_stylebox("focus", "MenuSlot", slot_focus)

	# Options tab, inactive: no slab at all, just a label with an underline slot.
	t.set_type_variation("MenuTab", "Button")
	t.set_font_size("font_size", "MenuTab", 22)
	var tab_n := _flat(INK, 0, INK, 0, 22, 10)
	tab_n.border_width_bottom = 3
	tab_n.border_color = Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.35)
	t.set_stylebox("normal", "MenuTab", tab_n)
	var tab_h := _flat(Color(GOLD.r, GOLD.g, GOLD.b, 0.08), 0, INK, 0, 22, 10)
	tab_h.border_width_bottom = 3
	tab_h.border_color = GOLD_DIM
	t.set_stylebox("hover", "MenuTab", tab_h)
	t.set_stylebox("pressed", "MenuTab", tab_h)
	t.set_stylebox("disabled", "MenuTab", tab_n)
	var tab_f := _flat(Color(GOLD.r, GOLD.g, GOLD.b, 0.16), 2, GOLD_BRIGHT, 3, 22, 10)
	tab_f.set_expand_margin_all(2.0)
	t.set_stylebox("focus", "MenuTab", tab_f)
	t.set_color("font_color", "MenuTab", MUTED)
	t.set_color("font_hover_color", "MenuTab", GOLD_BRIGHT)
	t.set_color("font_focus_color", "MenuTab", GOLD_BRIGHT)

	# Options tab, active: gold underline and gold text, focused or not.
	t.set_type_variation("MenuTabActive", "Button")
	t.set_font_size("font_size", "MenuTabActive", 22)
	var taba := _flat(Color(GOLD.r, GOLD.g, GOLD.b, 0.12), 0, INK, 0, 22, 10)
	taba.border_width_bottom = 3
	taba.border_color = GOLD_BRIGHT
	t.set_stylebox("normal", "MenuTabActive", taba)
	t.set_stylebox("hover", "MenuTabActive", taba)
	t.set_stylebox("pressed", "MenuTabActive", taba)
	t.set_stylebox("disabled", "MenuTabActive", taba)
	t.set_stylebox("focus", "MenuTabActive", tab_f)
	t.set_color("font_color", "MenuTabActive", GOLD_BRIGHT)
	t.set_color("font_hover_color", "MenuTabActive", Color.WHITE)
	t.set_color("font_focus_color", "MenuTabActive", Color.WHITE)

	# Erase / quit: same slab, but the text warns you.
	t.set_type_variation("MenuDanger", "Button")
	t.set_color("font_color", "MenuDanger", DANGER)
	t.set_color("font_hover_color", "MenuDanger", Color("ff8a67"))
	t.set_color("font_focus_color", "MenuDanger", Color("ff8a67"))


func _panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", _flat(STONE_1, 1, GOLD_DIM, 4, 0, 0))
	t.set_stylebox("panel", "Panel", _flat(STONE_1, 1, GOLD_DIM, 4, 0, 0))

	# The outer window: near-opaque so the paused world reads as backdrop only.
	t.set_type_variation("MenuFrame", "PanelContainer")
	var frame := _flat(Color(STONE_1.r, STONE_1.g, STONE_1.b, 0.97), 3, GOLD, 6, 3, 3)
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 18
	t.set_stylebox("panel", "MenuFrame", frame)

	t.set_type_variation("MenuHeader", "PanelContainer")
	var head := _flat(Color(STONE_2.r, STONE_2.g, STONE_2.b, 0.95), 0, INK, 0, 24, 12)
	head.border_width_bottom = 2
	head.border_color = GOLD
	t.set_stylebox("panel", "MenuHeader", head)

	t.set_type_variation("MenuFooter", "PanelContainer")
	var foot := _flat(Color(STONE_0.r, STONE_0.g, STONE_0.b, 0.8), 0, INK, 0, 24, 10)
	foot.border_width_top = 1
	foot.border_color = GOLD_DIM
	t.set_stylebox("panel", "MenuFooter", foot)

	t.set_type_variation("MenuNotice", "PanelContainer")
	var note := _flat(Color("2a1712ee"), 2, DANGER, 4, 26, 14)
	note.shadow_color = Color(0, 0, 0, 0.6)
	note.shadow_size = 12
	t.set_stylebox("panel", "MenuNotice", note)

	t.set_type_variation("MenuNoticeOk", "PanelContainer")
	var note_ok := _flat(Color("1d2113ee"), 2, GOLD, 4, 26, 14)
	note_ok.shadow_color = Color(0, 0, 0, 0.6)
	note_ok.shadow_size = 12
	t.set_stylebox("panel", "MenuNoticeOk", note_ok)

	t.set_type_variation("MenuSection", "PanelContainer")
	t.set_stylebox("panel", "MenuSection", _flat(Color(0, 0, 0, 0.25), 0, INK, 3, 8, 8))

	# Spacing lives in the theme too, so no screen ever reaches for
	# add_theme_constant_override just to get its gaps right.
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("margin_left", "MarginContainer", 22)
	t.set_constant("margin_right", "MarginContainer", 22)
	t.set_constant("margin_top", "MarginContainer", 16)
	t.set_constant("margin_bottom", "MarginContainer", 16)

	_vbox_var(t, "MenuStack", 0)      # header / body / footer, flush
	_vbox_var(t, "MenuList", 8)       # a column of option rows
	_vbox_var(t, "MenuCommands", 10)  # the six root commands
	_vbox_var(t, "MenuStatCol", 2)    # caption over value on a save card

	_hbox_var(t, "MenuTabBar", 4)
	_hbox_var(t, "MenuStatRow", 34)

	_margin_var(t, "MenuTabPad", 18, 18, 14, 0)
	_margin_var(t, "MenuBodyPad", 22, 22, 16, 16)


static func _vbox_var(t: Theme, name: String, sep: int) -> void:
	t.set_type_variation(name, "VBoxContainer")
	t.set_constant("separation", name, sep)


static func _hbox_var(t: Theme, name: String, sep: int) -> void:
	t.set_type_variation(name, "HBoxContainer")
	t.set_constant("separation", name, sep)


static func _margin_var(t: Theme, name: String, l: int, r: int, tp: int, b: int) -> void:
	t.set_type_variation(name, "MarginContainer")
	t.set_constant("margin_left", name, l)
	t.set_constant("margin_right", name, r)
	t.set_constant("margin_top", name, tp)
	t.set_constant("margin_bottom", name, b)


func _sliders(t: Theme) -> void:
	var track := _flat(STONE_0, 1, GOLD_DIM, 5, 0, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _flat(GOLD, 0, INK, 5, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(GOLD_BRIGHT, 0, INK, 5, 0, 0))
	t.set_constant("center_grabber", "HSlider", 0)
	t.set_constant("grabber_offset", "HSlider", 0)

	# Icons only exist after the PNGs above have been imported. First run of this
	# script writes them; the second run picks them up.
	if ResourceLoader.exists(OUT_GRAB):
		var g: Texture2D = load(OUT_GRAB)
		var gh: Texture2D = load(OUT_GRAB_HL) if ResourceLoader.exists(OUT_GRAB_HL) else g
		t.set_icon("grabber", "HSlider", g)
		t.set_icon("grabber_highlight", "HSlider", gh)
		t.set_icon("grabber_disabled", "HSlider", g)
	else:
		push_warning("grabber PNGs not imported yet — rerun after `--headless --import`")


func _scroll(t: Theme) -> void:
	t.set_stylebox("panel", "ScrollContainer", _empty())
	# A StyleBoxFlat's minimum size IS its content margins, so these numbers are
	# what give the bar any width at all — at 0 the scrollbar is invisible and a
	# scrolling list looks like a list that has been cut off.
	t.set_stylebox("scroll", "VScrollBar", _flat(Color(0, 0, 0, 0.5), 0, INK, 5, 5, 0))
	t.set_stylebox("scroll_focus", "VScrollBar", _flat(Color(0, 0, 0, 0.5), 0, INK, 5, 5, 0))
	t.set_stylebox("grabber", "VScrollBar", _flat(GOLD_DIM, 0, INK, 5, 5, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", _flat(GOLD, 0, INK, 5, 5, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", _flat(GOLD_BRIGHT, 0, INK, 5, 5, 0))
