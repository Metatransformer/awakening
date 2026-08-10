class_name UITheme
extends RefCounted
## The TOKEN and STYLEBOX layer for every Control-based screen — the paint.
## `UiKit` (scripts/ui/kit/) is the COMPOSITION layer above it. Panels call
## UiKit; UiKit calls UITheme; nothing calls back down.
##
## Ported from ~/valenfeld's `scripts/ui/UITheme.gd` (its docs/UI.md is the
## design system this repo now shares). What changed on the way in:
##
##  * `Loader.res()` -> plain `load()`; we have no Loader autoload.
##  * The carved-stone / cave-rock / progression-button paths are NOT ported.
##    They depend on valenfeld's TexturePack and on a banked-points economy we
##    do not have. The kit there is explicit that chrome is FLAT GLASS and the
##    bevel path survives only for `parchment()`; we took the flat half.
##  * Zone danger tiers, attribute colours and the codex tooltip hook are theirs,
##    not ours, and are left behind.
##
## ## Two palettes, and why that is not drift
##
## `Pal` (scripts/ui/style.gd) still exists and still wins for two things: the
## HUD's layout fractions, and GAME-SEMANTIC colour — rarity tiers, GOLD as
## currency, VITAL, EXTRACT CYAN. Those are authored against the PSX RGB555 grid
## in docs/STYLEGUIDE.md §2 and they mean something in the fiction.
##
## UITheme owns CHROME and TEXT: what a panel, a row, a tab, a focus ring and a
## label look like. Nothing in here is a rarity or a currency.
##
## The split is: if the colour would change when the loot tables change, it is
## `Pal`. If it would change when the menus get restyled, it is here.

# ---- corner policy -----------------------------------------------------------
## A small rounded corner. NOT 0 (square) and NOT 2 — both of those numbers are
## in older versions of the source style guide and both are wrong.
##
## It applies to the `StyleBoxFlat`-based elements only — scrollbars, progress
## fills, `plate_button_solid`, the strong focus ring. The borderless gradient
## plates below are texture-based and read with effectively hard edges.
const RADIUS := 5

# ---- palette -----------------------------------------------------------------
## Hierarchy comes from the FILL layer alone (GRAY_1..4), never from a border
## hue. That is the single rule that keeps the chrome from growing decoration.

const GRAY_1 := Color(0.045, 0.044, 0.043, 0.97)   ## layer 1 — near-opaque panel fill
const GRAY_2 := Color(0.154, 0.153, 0.151, 0.55)   ## layer 2 — element idle
const GRAY_3 := Color(0.253, 0.251, 0.249, 0.66)   ## layer 2 lit — hover; also THE hairline colour
const GRAY_4 := Color(0.368, 0.365, 0.363, 0.76)   ## layer 3 — selected/pressed

const BG_DARK := GRAY_1
const BG_INSET := Color(0.049, 0.048, 0.047, 0.58)          ## sunken wells (lists, item grids)
const BG_DARKER := Color(0.032, 0.031, 0.030, 0.62)
const BG_LIGHT := GRAY_2
const FRAME_FACE := GRAY_1
const FRAME_FACE_SOLID := Color(0.071, 0.070, 0.069, 0.97)  ## near-opaque — the full menu windows
const FRAME_FACE_OPAQUE := Color(0.130, 0.126, 0.121, 1.0)  ## flat solid — full-screen gates
const PLATE := GRAY_1
const PLATE_HOVER := Color(0.165, 0.163, 0.157, 0.56)
const PLATE_SUNK := GRAY_3
const SELECTED_FILL := Color(0.180, 0.178, 0.174, 0.90)     ## a chosen tile's FILL — flat, darker
const SELECT_GREY := GRAY_4

## Borders are deliberately de-emphasized. **Never gold.** A gold border is the
## single most common way this look collapses into a fantasy-UI asset pack.
const EDGE := Color(0.55, 0.52, 0.48, 0.40)
const EDGE_LIT := Color(0.70, 0.67, 0.62, 0.50)
const EDGE_FAINT := Color(0.55, 0.52, 0.48, 0.30)
const EDGE_BOLD := Color(0.55, 0.52, 0.48, 0.70)
const HUD_EDGE := Color(0.70, 0.67, 0.62, 0.76)

# ---- text --------------------------------------------------------------------
const TEXT := Color(0.902, 0.867, 0.788)        ## body text on dark — vellum
const TEXT_DIM := Color(0.702, 0.659, 0.580)    ## secondary
const ACCENT := Color(0.788, 0.639, 0.361)      ## gold — kickers/headers/key numbers. TEXT ONLY.
const ACCENT_DIM := Color(0.690, 0.553, 0.333)
## THE one interactive/selected accent: hover, pressed, active tab, focus, chosen.
## It is off-white, and it is the same value as TEXT on purpose — "this one" is a
## brightness, not a hue. Gold never plays this role.
const HIGHLIGHT := TEXT
const TOPIC := Color(0.860, 0.710, 0.430)       ## a text-link at rest
const TOPIC_HOVER := Color(0.980, 0.910, 0.760)

# ---- semantic status tier ----------------------------------------------------
## Status TEXT and ticks. Never a fill, never a border. Panels reach for these
## instead of inventing a green/red pair, which is how five screens end up with
## five different reds.
const SUCCESS := Color(0.560, 0.820, 0.620)   ## affordable / owned / safe
const DANGER := Color(0.900, 0.480, 0.430)    ## can't afford / blocked / hazard
const WARNING := Color(0.880, 0.700, 0.360)   ## cost / caution / pending

# ---- reading panes -----------------------------------------------------------
const PARCHMENT := Color(0.912, 0.868, 0.762)
const PARCH_EDGE := Color(0.70, 0.67, 0.62, 0.50)
const INK := Color(0.160, 0.130, 0.100)
const INK_DIM := Color(0.40, 0.33, 0.24)
const KEYLINE := Color(0.035, 0.028, 0.020)

# ---- type scale --------------------------------------------------------------
## Never hand-set `font_size` on a Label. Pick a TYPE_* and pass it to
## `apply_text_style`. A screen with seven sizes reads as accreted, not designed.
const TYPE_TITLE := {"size": 32, "color": ACCENT, "display": true}
const TYPE_SUBTITLE := {"size": 19, "color": ACCENT_DIM, "display": false}
const TYPE_H1 := {"size": 24, "color": ACCENT, "display": true}
const TYPE_H2 := {"size": 19, "color": ACCENT, "display": true}
const TYPE_H3 := {"size": 16, "color": ACCENT_DIM, "display": true}
const TYPE_PARAGRAPH_1 := {"size": 16, "color": TEXT, "display": false}
const TYPE_PARAGRAPH_2 := {"size": 14, "color": TEXT_DIM, "display": false}
const TYPE_CAPTION := {"size": 12, "color": TEXT_DIM, "display": false}
## Tile labels scale with the icon they sit under.
const TYPE_LABEL_SM := {"size": 12, "color": TEXT, "display": false}
const TYPE_LABEL_MD := {"size": 18, "color": TEXT, "display": false}
const TYPE_LABEL_LG := {"size": 18, "color": TEXT, "display": false}
const TYPE_LABEL_XL := {"size": 24, "color": TEXT, "display": false}


## The ONLY place a screen sets a Label's size and colour.
static func apply_text_style(lbl: Label, style: Dictionary, color_override = null) -> void:
	lbl.add_theme_font_size_override("font_size", int(style["size"]))
	var col: Color = color_override if color_override != null else style["color"]
	lbl.add_theme_color_override("font_color", col)
	if bool(style.get("display", false)):
		lbl.add_theme_font_override("font", display_font())


# ---- fonts -------------------------------------------------------------------
## TWO OFL faces, vendored under assets/ui/fonts/, and that is the whole list.
##
##  * Alegreya Sans — everything you READ: body copy, dialogue, buttons, labels.
##  * Cinzel — everything that TITLES: headers, kickers, key numbers.
##
## This replaces a `SystemFont` chain that started at "Trebuchet MS" — the game
## rendered its menus in whatever the player's machine happened to have, which is
## not a design decision, it is the absence of one.
##
## Retired, deliberately, and NOT to be re-added without a reason written here:
## Alegreya (the variable serif) — Cinzel is the display voice now, and two
## serifs in one screen is drift, not hierarchy — and Pixel Operator Bold, whose
## `keycap_font()` had no callers at all. Departure Mono and Jacquard 24
## (docs/STYLEGUIDE.md §3) were never wired.
##
## The HUD is on the same two faces. `CanvasText` (scripts/ui/canvas_text.gd)
## paints `display_font()` onto a CanvasItem for everything drawn rather than
## typeset — the vitals, the legend, the floor card, the world prompts. Until
## 2026-08-10 that class was a 5x7 bitmap of its own, which made the HUD the one
## surface in the build that ignored the shipped pair.
const BODY_TTF := "res://assets/ui/fonts/AlegreyaSans-Regular.ttf"
const DISPLAY_TTF := "res://assets/ui/fonts/Cinzel-SemiBold.ttf"

static var _theme: Theme = null
static var _font: Font = null
static var _display: Font = null
static var _global_done := false


## Load a .ttf SMOOTH (antialiased) — both faces here are curved types, which
## alias into mush if rasterised on the pixel grid.
##
## Only WRITE a property that actually differs. Assigning `antialiasing` on a
## FontFile invalidates its glyph cache and TextServer re-rasterises everything
## on the next draw, which is what makes the first painted rows of a menu flash
## blank glyphs before settling.
static func _smooth_font(path: String, fallback: PackedStringArray) -> Font:
	var ff := load(path) as FontFile
	if ff:
		if ff.antialiasing != TextServer.FONT_ANTIALIASING_GRAY:
			ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		if ff.multichannel_signed_distance_field:
			ff.multichannel_signed_distance_field = false
		if not ff.allow_system_fallback:
			ff.allow_system_fallback = true
		return ff
	# LOUD, not silent: a UI in the wrong font is a bug to fix, not a degrade to
	# live with. This is the path that reads as "the font failed to load".
	push_error("[UITheme] FONT LOAD FAILED for %s — falling back to system %s. Fix the asset/import." % [path, fallback])
	var sys := SystemFont.new()
	sys.font_names = fallback
	sys.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return sys


## Alegreya Sans — the humanist sans every Control uses by default.
static func body_font() -> Font:
	if _font == null:
		_font = _smooth_font(BODY_TTF, PackedStringArray(["Helvetica Neue", "Arial", "sans-serif"]))
	return _font


## Cinzel SemiBold — the inscriptional display face for headers, titles, and the
## one primary row. It is a CAPITALS face: its lowercase is a small-cap, so a
## header reads as carved either way, but do not reach for it below ~14px, where
## the flared serifs close up.
static func display_font() -> Font:
	if _display == null:
		_display = _smooth_font(DISPLAY_TTF, PackedStringArray(["Trajan Pro", "Palatino", "serif"]))
	return _display


## Make the body face the default for EVERY Control without touching each one.
static func ensure_global() -> void:
	if _global_done:
		return
	_global_done = true
	ThemeDB.fallback_font = body_font()
	ThemeDB.fallback_font_size = 18


## Rasterise the smooth pair up front, so the first menu frame is already correct
## instead of flashing blank glyphs while the dynamic-font cache fills. Building
## the fonts is itself the cache-clearing step, so doing it here means the
## one-time clear happens off-screen rather than under an open menu.
static func prewarm() -> void:
	ensure_global()
	var sample := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ·×•.,:'\"-/"
	# 9..30 are the sizes `CanvasText` asks for at 720p and 1080p. Without them the
	# HUD's first painted frame after a scene change rasterises under the player.
	for f in [body_font(), display_font()]:
		for sz in [9, 10, 12, 14, 15, 16, 18, 19, 21, 22, 24, 30, 32]:
			f.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)


# ---- the plate core ----------------------------------------------------------
## Everything routes through `_flat`. One plate: a borderless semi-transparent
## fill, left/right edges alpha-fading to nothing over GRADIENT_BAND px, and a
## 1px hairline along the top and bottom.
const GRADIENT_BAND := 5

static var _gradient_cache := {}


## Build the plate texture pixel by pixel, cached by key, 9-patched by
## `_gradient_border_box` so the fade and hairline stay crisp at any size.
##
## The interior is 7 rows tall, not 1. With a single middle row, linear texture
## filtering blends the two hairline rows across the whole stretched interior and
## paints a vertical dark-to-light gradient down every button and panel.
static func _gradient_border_tex(key: String, fill: Color, band: int,
		line_color: Color = GRAY_3) -> ImageTexture:
	if _gradient_cache.has(key):
		return _gradient_cache[key]
	var w := maxi(band * 2 + 2, 3)
	var h := 9
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var is_line := (y == 0 or y == h - 1)
		for x in w:
			# Distance to the nearest LEFT/RIGHT edge: 0 at the edge (fully
			# transparent), 1 once `band` px inward. Never fades vertically.
			var edge_dist := minf(x + 0.5, float(w) - (x + 0.5))
			var grad := clampf(edge_dist / float(band), 0.0, 1.0) if band > 0 else 1.0
			var c: Color
			if is_line:
				c = Color(line_color.r, line_color.g, line_color.b, line_color.a * grad)
			else:
				c = Color(fill.r, fill.g, fill.b, fill.a * grad)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_gradient_cache[key] = tex
	return tex


## Wrap a plate texture in a 9-patch with the given content margins. The
## top/bottom texture margin is 3 (hairline + 2 flat rows), not 1 — it keeps the
## filtered stretch region clear of the hairline so no gradient bleeds inward.
static func _gradient_border_box(tex: ImageTexture, band: int, m_l: int, m_t: int,
		m_r: int, m_b: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = band
	sb.texture_margin_right = band
	sb.texture_margin_top = 3
	sb.texture_margin_bottom = 3
	sb.content_margin_left = m_l
	sb.content_margin_top = m_t
	sb.content_margin_right = m_r
	sb.content_margin_bottom = m_b
	return sb


## THE plate. `border` is accepted for call-site compatibility and is IGNORED —
## hierarchy comes from the fill, not a border hue — unless `highlight` is true,
## in which case the hairline becomes HIGHLIGHT (armed).
static func _flat(fill: Color, border: Color, m_l: int, m_t: int, m_r: int, m_b: int,
		border_w := GRADIENT_BAND, highlight := false) -> StyleBoxTexture:
	var line_color := HIGHLIGHT if highlight else GRAY_3
	var key := "flat:%s:%d:%s" % [fill, border_w, line_color]
	var tex := _gradient_border_tex(key, fill, border_w, line_color)
	return _gradient_border_box(tex, border_w, m_l, m_t, m_r, m_b)


# ---- soft-edge plates (borderless, centre-out fade) --------------------------
static var _soft_edge_cache := {}

static func _soft_edge_tex(key: String, fill: Color, fade_distance: float = 10.0) -> ImageTexture:
	if _soft_edge_cache.has(key):
		return _soft_edge_cache[key]
	var dim := 64
	var img := Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	var center := dim * 0.5
	for y in dim:
		for x in dim:
			var dx := absf(float(x) - center)
			var dy := absf(float(y) - center)
			# Chebyshev (not euclidean): a RECTANGULAR falloff, so the fade
			# reaches all four edges evenly instead of rounding the corners off.
			var dist := maxf(dx, dy)
			var alpha := 1.0 - clampf(dist / fade_distance, 0.0, 1.0)
			alpha = alpha * alpha * (3.0 - 2.0 * alpha)   # smoothstep
			img.set_pixel(x, y, Color(fill.r, fill.g, fill.b, fill.a * alpha))
	var tex := ImageTexture.create_from_image(img)
	_soft_edge_cache[key] = tex
	return tex


static func _soft_edge_box(tex: ImageTexture, pad_h: int = 20, pad_v: int = 10) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(32)   # centre of the 64px image; the 9-patch stretches the fade
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


# ---- parchment (the ONE surviving non-flat surface) --------------------------
## Reading panes only — books, notes, anything the player READS as paper. If it
## is chrome, it is `_flat`. This is the entire exception list.
const PARCH_DIM := 40
static var _parchment_tex: ImageTexture = null


static func _paper_image(dim: int, with_keyline: bool) -> Image:
	var img := Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.22
	fn.seed = 7
	for y in dim:
		for x in dim:
			# A fibre wobble of about +/- 3.5%: enough to stop the page reading
			# as a flat rectangle, far too little to read as texture.
			var n := fn.get_noise_2d(float(x), float(y)) * 0.035
			var c := Color(
				clampf(PARCHMENT.r + n, 0.0, 1.0),
				clampf(PARCHMENT.g + n, 0.0, 1.0),
				clampf(PARCHMENT.b + n * 1.2, 0.0, 1.0),
				1.0)
			var on_rim := x == 0 or y == 0 or x == dim - 1 or y == dim - 1
			if with_keyline and on_rim:
				c = PARCH_EDGE
			img.set_pixel(x, y, c)
	return img


static func _paper_tex() -> ImageTexture:
	if _parchment_tex == null:
		_parchment_tex = ImageTexture.create_from_image(_paper_image(PARCH_DIM, true))
	return _parchment_tex


## Aged vellum for things you READ. The 1px rim is baked into the texture and
## 9-patched, so the page keeps a crisp edge at any size while the centre tiles.
static func parchment() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _paper_tex()
	sb.set_texture_margin_all(2)
	sb.set_content_margin_all(22)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


# ---- the factories -----------------------------------------------------------

## The menu WINDOW. `slim` is the lightweight variant for a small floated
## backing; `edge_to_edge` zeroes the margins for a composed column whose
## children own their own spacing (see UiKit).
static func frame(fill := FRAME_FACE, slim := false, edge_to_edge := false) -> StyleBoxTexture:
	if edge_to_edge:
		return _flat(fill, EDGE, 0, 0, 0, 0)
	if slim:
		return _flat(fill, EDGE, 16, 7, 16, 7)
	return _flat(fill, EDGE, 22, 22, 22, 22)


## The floating hover-card glass. A hover card sits directly OVER the grid it
## describes, so the standard window transparency reads as bleed-through.
static func hover_card() -> StyleBoxTexture:
	return _flat(FRAME_FACE_SOLID, EDGE, 6, 6, 6, 6)


## A HUD-cluster frame: the same glass, tight padding.
static func hud_frame(pad := 8) -> StyleBoxTexture:
	return _flat(BG_DARK, EDGE, pad, pad, pad, pad)


## HUD-only glass: the kit's hairline, but continued around all four sides so a
## small world-facing readout does not dissolve into a bright scene.
static func hud_box(fill: Color = BG_DARK, m_l := 8, m_t := 8, m_r := 8, m_b := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = HUD_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(RADIUS)
	sb.set_content_margin(SIDE_LEFT, m_l)
	sb.set_content_margin(SIDE_TOP, m_t)
	sb.set_content_margin(SIDE_RIGHT, m_r)
	sb.set_content_margin(SIDE_BOTTOM, m_b)
	sb.anti_aliasing = false
	sb.shadow_color = Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, 0.12)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2.ZERO
	return sb


## The shared button plate. Hover and pressed trade the quiet GRAY_3 hairline for
## the bright HIGHLIGHT — the same accent a selected tab underlines with.
static func plate_button(state := "normal", wide := false) -> StyleBoxTexture:
	var mh := 26 if wide else 20
	match state:
		"hover":
			return _flat(PLATE_HOVER, EDGE_LIT, mh, 10, mh, 10, GRADIENT_BAND, true)
		"pressed":
			return _flat(PLATE_SUNK, ACCENT_DIM, mh, 11, mh, 9, GRADIENT_BAND, true)
		"disabled":
			return _flat(Color(0.090, 0.078, 0.065, 0.50),
				Color(EDGE.r, EDGE.g, EDGE.b, 0.55), mh, 10, mh, 10)
		_:
			return _flat(PLATE, EDGE, mh, 10, mh, 10)


## A SOLID near-opaque plate for a prominent button floated over a live scene.
## Plain StyleBoxFlat, not `_flat`, whose edge fade would thin it back out.
static func plate_button_solid(state := "normal") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(RADIUS)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.set_border_width_all(1)
	match state:
		"hover":
			sb.bg_color = Color(0.20, 0.198, 0.192, 0.96)
			sb.border_color = HIGHLIGHT
		"pressed":
			sb.bg_color = Color(0.28, 0.278, 0.272, 0.98)
			sb.border_color = HIGHLIGHT
		"disabled":
			sb.bg_color = Color(0.10, 0.098, 0.092, 0.80)
			sb.border_color = Color(EDGE.r, EDGE.g, EDGE.b, 0.45)
		_:
			sb.bg_color = Color(0.135, 0.132, 0.126, 0.95)
			sb.border_color = EDGE_BOLD
	return sb


static func soft_edge_button(state := "normal", wide := false) -> StyleBoxTexture:
	var mh := 26 if wide else 20
	match state:
		"hover":
			return _soft_edge_box(_soft_edge_tex("soft_plate_hover", PLATE_HOVER), mh, 10)
		"pressed":
			return _soft_edge_box(_soft_edge_tex("soft_plate_sunk", PLATE_SUNK), mh, 11)
		"disabled":
			return _soft_edge_box(
				_soft_edge_tex("soft_plate_dis", Color(0.090, 0.078, 0.065, 0.50)), mh, 10)
		_:
			return _soft_edge_box(_soft_edge_tex("soft_plate", PLATE), mh, 10)


static func soft_edge_frame() -> StyleBoxTexture:
	return _soft_edge_box(_soft_edge_tex("soft_frame", FRAME_FACE), 22, 22)


## The keyboard / gamepad focus marker. `strong` is the bright 2px all-sides ring
## for full-screen or stick-distance focus, where the default hairline is too
## subtle to track. Off-white, never gold.
static func focus_rim(strong := false) -> StyleBox:
	if strong:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, 0.10)
		sb.set_border_width_all(2)
		sb.border_color = HIGHLIGHT
		sb.set_corner_radius_all(RADIUS)
		sb.anti_aliasing = false
		return sb
	return _flat(Color(0.55, 0.52, 0.48, 0.10), EDGE_LIT, 0, 0, 0, 0)


## A small dark backing for ONE transient line — a toast, a pickup card. Lighter
## than `frame()`: it keeps a line readable over a bright scene, it is not a window.
static func chip() -> StyleBoxTexture:
	return _flat(Color(0.052, 0.044, 0.037, 0.80),
		Color(EDGE.r, EDGE.g, EDGE.b, 0.80), 12, 5, 12, 5)


## A sunken well for a scrolling list or an item grid: darker, more transparent
## glass behind a fainter hairline, so the list reads as a recess.
static func well() -> StyleBoxTexture:
	return _flat(BG_INSET, Color(EDGE.r, EDGE.g, EDGE.b, 0.70), 8, 8, 8, 8)


## A "chosen" toggle: a FLAT darker fill under the HIGHLIGHT hairline. `border_w`
## of 0 turns off the edge fade so the plate is a solid colour rather than a
## gradient band — a fading plate under near-black ink reads as a rendering bug.
static func selected_btn() -> StyleBoxTexture:
	return _flat(SELECTED_FILL, EDGE, 16, 9, 16, 9, 0, true)


## A neutral selected LIST ROW — brightened grey under the lit line.
static func selected_row() -> StyleBoxTexture:
	return _flat(SELECT_GREY, EDGE_LIT, 16, 9, 16, 9)


## A picker card's plate. Without this an unpicked tile is `Color(0,0,0,0)` and
## whatever sits behind the grid shows through the gaps.
static func tile_plate(hover := false) -> StyleBoxTexture:
	return _flat(GRAY_3, EDGE_LIT, 0, 0, 0, 0) if hover else _flat(GRAY_2, EDGE, 0, 0, 0, 0)


## A square action slot — an inventory cell, a hotbar tile. The ARMED slot
## carries the light border, so what is readied reads at a glance.
static func slot_sb(state: String) -> StyleBox:
	const PAD := 3
	match state:
		"hover":
			return hud_box(PLATE_HOVER, PAD, PAD, PAD, PAD)
		"pressed":
			return hud_box(PLATE_SUNK, PAD, PAD, PAD, PAD)
		"selected":
			return hud_box(GRAY_4, PAD, PAD, PAD, PAD)
		_:
			return hud_box(GRAY_1, PAD, PAD, PAD, PAD)


## THE tab voice: no fill, ever. An idle tab is bare text, a hovered tab previews
## a thin HIGHLIGHT underline, the selected tab draws it heavier.
static func tab_box(state := "unselected") -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.anti_aliasing = false
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	if state == "selected":
		sb.border_width_bottom = 3
		sb.border_color = HIGHLIGHT
	elif state == "hovered":
		sb.border_width_bottom = 2
		sb.border_color = Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, 0.55)
	return sb


## A generic progress bar (fill supplied by the caller — a vitals colour comes
## from `Pal`, not from here).
static func bar_styleboxes(fill: Color) -> Array:
	var bg := _flat(Color(0.040, 0.034, 0.028, 0.72), EDGE, 0, 0, 0, 0)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(RADIUS)
	fg.anti_aliasing = false
	return [bg, fg]


## The per-gauge hairline frame. A ProgressBar draws its fill full-height from
## the left edge, so the 1px line has to be its OWN border on a wrapping
## PanelContainer or the fill paints straight over it.
static func bar_frame() -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = Color(0, 0, 0, 0)
	f.border_color = Color(GRAY_1.r, GRAY_1.g, GRAY_1.b, 0.95)
	f.set_border_width_all(1)
	f.set_corner_radius_all(RADIUS)
	f.shadow_color = Color(0.95, 0.94, 0.88, 0.14)
	f.shadow_size = 2
	f.shadow_offset = Vector2.ZERO
	return f


static func tooltip_card() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FRAME_FACE_OPAQUE
	sb.set_content_margin_all(10)
	sb.border_color = EDGE_LIT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(RADIUS)
	return sb


# ---- scrollbars --------------------------------------------------------------
## Plain StyleBoxFlat, NOT `_flat`: the plate fades its left/right edges over
## GRADIENT_BAND px, which on a 22px-wide bar erases the entire nub.
const SCROLLBAR_W := 22

static func scrollbar_track() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.028, 0.026, 0.55)
	sb.border_color = Color(EDGE.r, EDGE.g, EDGE.b, 0.60)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(RADIUS)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	return sb


static func scrollbar_grabber(lit := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.52, 0.49, 0.45, 0.95) if lit else Color(0.40, 0.375, 0.345, 0.85)
	sb.border_color = Color(0.72, 0.69, 0.64, 0.95) if lit else Color(0.58, 0.55, 0.50, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(RADIUS)
	return sb


## THE slider voice: a hairline groove with a filled run and a square stone nub,
## the same chiselled material as the scrollbars. Godot's default HSlider is a
## blue capsule, which is the one colour this palette does not contain.
##
## The nub is drawn with `grabber_area` filled behind it, so the travelled part
## of the run reads as spent — a settings slider is a number you are LOOKING at,
## and a bare groove makes you read the figure beside it to know where you are.
static func slider_track() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.028, 0.026, 0.70)
	sb.border_color = Color(EDGE.r, EDGE.g, EDGE.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


static func slider_fill(lit := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var a := 0.55 if lit else 0.34
	sb.bg_color = Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, a)
	sb.set_corner_radius_all(2)
	sb.anti_aliasing = false
	return sb


## The nub. A Slider's grabber is an ICON, not a StyleBox — the one theme item on
## the class that is a Texture2D — so it is drawn here rather than styled. A
## StyleBox handed to `grabber` is silently ignored and you get the engine's
## default circle, or, worse, whichever ancestor theme still has an icon for it.
##
## It is off-white stone, not gold. Gold in this kit is TEXT that carries a
## value, and the slider's value is already printed in gold at the end of the
## row; a gold nub would be the same fact said twice, in the loudest colour on
## the screen, on the part of the row that is furthest from being a number.
static func slider_grabber_tex(lit := false) -> ImageTexture:
	var key := "slider_grab_lit" if lit else "slider_grab"
	if _gradient_cache.has(key):
		return _gradient_cache[key]
	const W := 9
	const H := 20
	var face := HIGHLIGHT if lit else Color(0.62, 0.59, 0.55)
	var rim := Color(0.86, 0.83, 0.78) if lit else Color(0.72, 0.69, 0.64)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var edge := x == 0 or x == W - 1 or y == 0 or y == H - 1
			img.set_pixel(x, y, rim if edge else face)
	var tex := ImageTexture.create_from_image(img)
	_gradient_cache[key] = tex
	return tex


static func _style_sliders(t: Theme) -> void:
	for cls in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", cls, slider_track())
		t.set_stylebox("grabber_area", cls, slider_fill(false))
		t.set_stylebox("grabber_area_highlight", cls, slider_fill(true))
		t.set_icon("grabber", cls, slider_grabber_tex(false))
		t.set_icon("grabber_highlight", cls, slider_grabber_tex(true))
		t.set_icon("grabber_disabled", cls, slider_grabber_tex(false))
		t.set_constant("center_grabber", cls, 0)
		t.set_constant("grabber_offset", cls, 0)


static func _style_scrollbars(t: Theme) -> void:
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, scrollbar_track())
		t.set_stylebox("grabber", cls, scrollbar_grabber(false))
		t.set_stylebox("grabber_highlight", cls, scrollbar_grabber(true))
		t.set_stylebox("grabber_pressed", cls, scrollbar_grabber(true))


## Apply the scrollbar look to ONE container whose bars are not under the theme.
static func style_scrollbar(container: ScrollContainer) -> void:
	for bar in [container.get_v_scroll_bar(), container.get_h_scroll_bar()]:
		if bar == null:
			continue
		bar.custom_minimum_size = Vector2(SCROLLBAR_W, SCROLLBAR_W)
		bar.add_theme_stylebox_override("scroll", scrollbar_track())
		bar.add_theme_stylebox_override("grabber", scrollbar_grabber(false))
		bar.add_theme_stylebox_override("grabber_highlight", scrollbar_grabber(true))
		bar.add_theme_stylebox_override("grabber_pressed", scrollbar_grabber(true))


static func _style_tabs(t: Theme) -> void:
	var empty := StyleBoxEmpty.new()
	for cls in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", cls, tab_box("selected"))
		t.set_stylebox("tab_hovered", cls, tab_box("hovered"))
		t.set_stylebox("tab_unselected", cls, tab_box("unselected"))
		t.set_stylebox("tab_disabled", cls, tab_box("unselected"))
		t.set_stylebox("tab_focus", cls, focus_rim())
		t.set_stylebox("tabbar_background", cls, empty)
		t.set_color("font_selected_color", cls, HIGHLIGHT)
		t.set_color("font_hovered_color", cls, TEXT)
		t.set_color("font_unselected_color", cls, TEXT_DIM)
		t.set_color("font_disabled_color", cls, Color(0.50, 0.45, 0.37))
		t.set_constant("font_outline_size", cls, 0)
		t.set_font_size("font_size", cls, 15)
	t.set_stylebox("panel", "TabContainer", frame())


## The variation names the SHARED cell components render through, painted in
## Gallery Vellum.
##
## `ItemCell` and `UpgradeLadder` are drawn by every screen that shows more than
## one thing — the bag, the pouch, the vendor's board, the locker, the receipt —
## and they ask for `MenuSlot`, `MenuSlotStat`, `MenuValue`, `MenuHeading` and
## `MenuMuted` by name. Those names used to be defined in `menu_theme.tres`, the
## theme §3.0 of the styleguide replaces. So a screen adopting the kit had
## exactly two options: rebuild the cell, or render the cell as an unstyled
## default Button.
##
## This is the third one. The names stay, the cell's own code does not change,
## and the paint underneath becomes the kit's. That matters beyond convenience:
## the bag and the vendor's board are the same objects seen twice, and a bag cell
## that looked one way in the pouch and another at the counter would break the
## one promise `ItemCell`'s header makes.
##
## `menu_theme.tres` is now deleted, so this is no longer a bridge to somewhere
## — it is the only definition of those five names, and the cells would render
## as default Buttons without it. It stays for exactly as long as the ITEM CELL
## does, which is indefinitely: the item menu is the one screen the owner asked
## us not to touch.
##
## It is still not an invitation. Do not add variation names here to save
## writing a composite — new screens compose with `UiKit` and style their own
## labels through `apply_text_style`. This list only ever shrinks.
static func _style_shared_cells(t: Theme) -> void:
	# The cell plate. Gold borders are out (§ the palette note above): what marks
	# an armed cell here is the same off-white HIGHLIGHT every other armed thing
	# in the kit wears.
	t.set_type_variation("MenuSlot", "Button")
	t.set_stylebox("normal", "MenuSlot", _flat(PLATE, EDGE_FAINT, 7, 5, 7, 5))
	t.set_stylebox("hover", "MenuSlot", _flat(PLATE_HOVER, EDGE_LIT, 7, 5, 7, 5))
	t.set_stylebox("pressed", "MenuSlot", _flat(SELECTED_FILL, EDGE_LIT, 7, 5, 7, 5))
	t.set_stylebox("disabled", "MenuSlot",
		_flat(Color(0, 0, 0, 0.25), EDGE_FAINT, 7, 5, 7, 5))
	t.set_stylebox("focus", "MenuSlot", focus_rim(true))

	# `ItemCell` overrides the SIZE on both of these per shape — a rung's numeral
	# and a stack's name are not the same length — so what the variation carries
	# is the voice, not the scale.
	t.set_type_variation("MenuSlotStat", "Label")
	t.set_color("font_color", "MenuSlotStat", TEXT)
	t.set_font_size("font_size", "MenuSlotStat", TYPE_PARAGRAPH_1["size"])

	# The cell's second line is a NUMBER — a price, a count, a tally. Gold, which
	# is the one thing gold is still for.
	t.set_type_variation("MenuValue", "Label")
	t.set_font("font", "MenuValue", display_font())
	t.set_color("font_color", "MenuValue", ACCENT)
	t.set_font_size("font_size", "MenuValue", TYPE_LABEL_MD["size"])

	t.set_type_variation("MenuHeading", "Label")
	t.set_font("font", "MenuHeading", display_font())
	t.set_color("font_color", "MenuHeading", ACCENT)
	t.set_font_size("font_size", "MenuHeading", TYPE_H2["size"])

	t.set_type_variation("MenuMuted", "Label")
	t.set_color("font_color", "MenuMuted", TEXT_DIM)
	t.set_font_size("font_size", "MenuMuted", TYPE_CAPTION["size"])


# ---- the theme ---------------------------------------------------------------
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 18

	t.set_stylebox("panel", "Panel", frame())
	t.set_stylebox("panel", "PanelContainer", frame())

	t.set_stylebox("normal", "Button", plate_button("normal"))
	t.set_stylebox("hover", "Button", plate_button("hover"))
	t.set_stylebox("pressed", "Button", plate_button("pressed"))
	t.set_stylebox("disabled", "Button", plate_button("disabled"))
	t.set_stylebox("focus", "Button", focus_rim())
	# Button text is NEVER gold — that voice belongs to headers, kickers and key
	# numbers. Only brightness shifts with state, never hue.
	t.set_color("font_color", "Button", TEXT_DIM)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.46, 0.42, 0.36))
	t.set_font_size("font_size", "Button", 16)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_color", "RichTextLabel", TEXT)

	var line := StyleBoxLine.new()
	line.color = EDGE
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	var vline := StyleBoxLine.new()
	vline.color = EDGE
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)

	t.set_stylebox("panel", "TooltipPanel", tooltip_card())
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	_style_scrollbars(t)
	_style_sliders(t)
	_style_tabs(t)
	_style_shared_cells(t)

	_theme = t
	return t


# ---- assembly helpers --------------------------------------------------------

## The one call that turns a bare Panel into a styled menu whose every child
## inherits the look. Pass `edge_to_edge` for a composed UiKit column whose
## header, band, rows and footer must reach the frame edge.
static func style_panel(panel: Control, fill := FRAME_FACE, edge_to_edge := false) -> void:
	panel.theme = theme()
	panel.add_theme_stylebox_override("panel", frame(fill, false, edge_to_edge))
	panel.clip_contents = true


static func style_panel_soft_edge(panel: Control) -> void:
	panel.theme = theme()
	panel.add_theme_stylebox_override("panel", soft_edge_frame())
	panel.clip_contents = true


## A fully opaque background for a full-screen gate. `frame()` always fades its
## left/right edges to transparent regardless of the fill's own alpha, which lets
## a sliver of the world bleed through a gate that is meant to block it.
static func style_panel_opaque(panel: Control) -> void:
	panel.theme = theme()
	var sb := StyleBoxFlat.new()
	sb.bg_color = FRAME_FACE_OPAQUE
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.clip_contents = true


static func style_hud_panel(panel: Control, pad := 8) -> void:
	panel.theme = theme()
	panel.add_theme_stylebox_override("panel", hud_frame(pad))


## Restyle a Button as a prominent square ACTION button (Take, Sell, Close).
static func style_pill_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat(PLATE, EDGE, 26, 10, 26, 10))
	btn.add_theme_stylebox_override("hover", _flat(PLATE_HOVER, EDGE_LIT, 26, 10, 26, 10))
	btn.add_theme_stylebox_override("pressed", _flat(PLATE_SUNK, EDGE_LIT, 26, 11, 26, 9))
	btn.add_theme_stylebox_override("disabled",
		_flat(Color(0, 0, 0, 0.25), Color(EDGE.r, EDGE.g, EDGE.b, 0.6), 26, 10, 26, 10))
	btn.add_theme_stylebox_override("focus", focus_rim())
	btn.add_theme_color_override("font_color", TEXT_DIM)
	btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", TEXT)
	btn.add_theme_color_override("font_focus_color", TEXT)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)


## Restyle a Button as a flat hover-highlight TEXT link.
static func style_text_button(btn: Button, pad := Vector2(12, 6)) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = pad.x
		sb.content_margin_right = pad.x
		sb.content_margin_top = pad.y
		sb.content_margin_bottom = pad.y
		btn.add_theme_stylebox_override(state, sb)
	# Focus is NOT empty. A flat text button still needs a visible cursor under
	# keyboard and gamepad navigation.
	var foc := focus_rim()
	foc.content_margin_left = pad.x
	foc.content_margin_right = pad.x
	foc.content_margin_top = pad.y
	foc.content_margin_bottom = pad.y
	btn.add_theme_stylebox_override("focus", foc)
	btn.add_theme_color_override("font_color", TOPIC)
	btn.add_theme_color_override("font_hover_color", TOPIC_HOVER)
	btn.add_theme_color_override("font_pressed_color", ACCENT)
	btn.add_theme_color_override("font_focus_color", TOPIC_HOVER)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)


## Restyle a Button as a hand-built tab, using the kit's ONE underline voice, so
## a hand-rolled tab strip reads identically to a real TabBar.
static func style_tab_button(btn: Button, active: bool) -> void:
	btn.add_theme_stylebox_override("normal", tab_box("selected" if active else "unselected"))
	btn.add_theme_stylebox_override("hover", tab_box("selected" if active else "hovered"))
	btn.add_theme_stylebox_override("pressed", tab_box("selected"))
	btn.add_theme_stylebox_override("focus", focus_rim())
	btn.add_theme_color_override("font_color", HIGHLIGHT if active else TEXT_DIM)
	btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", HIGHLIGHT)
	btn.add_theme_color_override("font_focus_color", TEXT)


## Restyle a LineEdit. Godot's stock field ships bright rounded chrome that reads
## as a foreign widget on every panel; a bare white LineEdit is a bug.
static func style_line_edit(le: LineEdit) -> void:
	le.add_theme_stylebox_override("normal",
		_flat(BG_INSET, Color(EDGE.r, EDGE.g, EDGE.b, 0.70), 10, 6, 10, 6))
	le.add_theme_stylebox_override("focus",
		_flat(BG_INSET, EDGE, 10, 6, 10, 6, GRADIENT_BAND, true))
	le.add_theme_stylebox_override("read_only",
		_flat(Color(BG_INSET.r, BG_INSET.g, BG_INSET.b, 0.55),
			Color(EDGE.r, EDGE.g, EDGE.b, 0.45), 10, 6, 10, 6))
	le.add_theme_color_override("font_color", TEXT)
	le.add_theme_color_override("font_placeholder_color",
		Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.6))
	le.add_theme_color_override("caret_color", HIGHLIGHT)
	le.add_theme_color_override("selection_color",
		Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, 0.30))
	le.add_theme_color_override("font_selected_color", TEXT)


## A big vellum serif title. Gold is the kicker voice, not the h1.
static func header(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display_font())
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", TEXT)
	parent.add_child(l)
	return l


## A centred `◆ TITLE ◆` divider between two thin rules — the way to break a tall
## panel into bands without another boxed header.
static func section_rule(parent: Node, text: String, size: int = 13) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	var left := ColorRect.new()
	left.color = Color(EDGE.r, EDGE.g, EDGE.b, 0.45)
	left.custom_minimum_size = Vector2(8, 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	var l := Label.new()
	l.text = "◆  %s  ◆" % text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT_DIM)
	row.add_child(l)
	row.add_child(left.duplicate())
	parent.add_child(row)
	return row


# ---- blur / scrim ------------------------------------------------------------
static var _blur_mat: ShaderMaterial = null


## One backdrop-blur material, shared. A canvas shader sampling the mipmapped
## screen texture at a fractional LOD — a cheap gaussian-ish blur plus a dim, no
## extra passes.
static func blur_material() -> ShaderMaterial:
	if _blur_mat:
		return _blur_mat
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod : hint_range(0.0, 4.0) = 2.2;
uniform float dim : hint_range(0.0, 1.0) = 0.30;
void fragment() {
	vec4 s = textureLod(screen_tex, SCREEN_UV, lod);
	COLOR = vec4(s.rgb * (1.0 - dim), 1.0);
}
"""
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = sh
	return _blur_mat


## A click-through blur pane to lay BEHIND a translucent window.
static func blur_backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.material = blur_material()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The click-away dimmer. Add it to the CanvasLayer BEFORE the Panel, so the
## Panel draws on top and absorbs clicks inside its own rect — only margin clicks
## reach the scrim.
static func modal_scrim(on_dismiss: Callable) -> ColorRect:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.material = blur_material()
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			on_dismiss.call())
	return scrim


# ---- icon material -----------------------------------------------------------
static var _desat_mats := {}


## A shared desaturate+contrast material for icon TextureRects, so a borrowed
## icon family sits in the palette instead of shouting over it.
##
## The fragment reads the incoming `COLOR` (texture x modulate), never a bare
## `texture(TEXTURE, UV)`: sampling directly throws the CanvasItem's modulate on
## the floor, so every caller that dims an icon by modulate renders at full
## brightness anyway.
static func desaturate_material(amount: float = 0.35, contrast: float = 1.08) -> ShaderMaterial:
	var key := "%.3f|%.3f" % [amount, contrast]
	if _desat_mats.has(key):
		return _desat_mats[key]
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.75;
uniform float contrast : hint_range(1.0, 2.0) = 1.25;
void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(g), amount);
	c.rgb = clamp((c.rgb - 0.5) * contrast + 0.5, 0.0, 1.0);
	COLOR = c;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("amount", amount)
	mat.set_shader_parameter("contrast", contrast)
	_desat_mats[key] = mat
	return mat


# ---- the model-preview stage -------------------------------------------------
## The backdrop a 3D model preview sits in front of — the character screen's
## portrait niche. A warm spotlight set a touch above centre so it haloes the
## head and torso, falling to deep umber at the rim with a darker ground at the
## foot. Built code-side, cached; the preview SubViewport (transparent_bg)
## composites the figure over it.
const STAGE_GLOW := Color(0.305, 0.258, 0.196)
const STAGE_EDGE := Color(0.082, 0.068, 0.052)
const STAGE_FLOOR := Color(0.045, 0.037, 0.028)
static var _model_stage_tex: ImageTexture = null


static func model_stage_texture() -> ImageTexture:
	if _model_stage_tex:
		return _model_stage_tex
	var w := 96
	var h := 192
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w * 0.5
	var cy := h * 0.34
	for y in h:
		var fy := float(y) / h
		for x in w:
			var dx := (x - cx) / (w * 0.62)
			var dy := (y - cy) / (h * 0.72)
			var spot := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			spot = spot * spot * (3.0 - 2.0 * spot)
			var c := STAGE_EDGE.lerp(STAGE_GLOW, spot)
			if fy > 0.70:
				c = c.lerp(STAGE_FLOOR, clampf((fy - 0.70) / 0.30, 0.0, 1.0) * 0.8)
			var vig := clampf(
				1.0 - (absf((x - cx) / (w * 0.5)) * 0.45 + maxf(0.0, fy - 0.5) * 0.5), 0.45, 1.0)
			img.set_pixel(x, y, Color(c.r * vig, c.g * vig, c.b * vig, 1.0))
	_model_stage_tex = ImageTexture.create_from_image(img)
	return _model_stage_tex


## A ready-to-place backdrop TextureRect. Lay it behind a transparent
## SubViewportContainer; improving the texture updates every preview at once.
static func model_backdrop() -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = model_stage_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# ---- focus / navigation ------------------------------------------------------
## Every panel must be drivable with NO mouse. Godot auto-computes focus
## neighbours from layout, so navigation works the moment SOMETHING holds focus.
## The one thing a panel must do is grab focus on a real control when it opens —
## without an initial focus the ui_* directions are no-ops.

## Focus the first focusable control under `root`, and make any ScrollContainer
## follow focus so a focused row scrolls into view.
static func focus_first(root: Node) -> Control:
	_enable_follow_focus(root)
	var c := _first_focusable(root)
	if c:
		c.grab_focus()
	return c


## Re-grab focus ONLY if nothing inside `root` holds it — safe at the tail of any
## `_refresh()`, because it will not steal focus from a control still in use.
static func refocus_if_lost(root: Control) -> void:
	if not root.is_inside_tree():
		return
	var owner := root.get_viewport().gui_get_focus_owner()
	if owner != null and (owner == root or root.is_ancestor_of(owner)):
		return
	focus_first(root)


## The deferred twin, for after a rebuild. Focusing synchronously right after a
## `queue_free` can land on a row that is about to vanish this frame.
static func focus_first_next_frame(root: Control) -> void:
	if not root.is_inside_tree():
		return
	root.get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(root) and root.is_inside_tree() and root.visible:
			refocus_if_lost(root), CONNECT_ONE_SHOT)


## Empty `parent` for a list that rebuilds each refresh. `queue_free()` alone is
## NOT enough: it only marks the node for deferred deletion, so it stays a real
## child until the next idle frame. If a refresh fires twice before a frame runs,
## each rebuild's freed-but-still-present children pile up UNDER the new ones —
## a runaway that grows node count with every extra call. `remove_child` takes
## effect immediately; pair it with `queue_free()` for safe destruction.
static func clear_children(parent: Node) -> void:
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()


static func _first_focusable(n: Node) -> Control:
	for child in n.get_children():
		var ctl := child as Control
		if ctl != null:
			if not ctl.visible:
				continue
			# Only INTERACTIVE focus. NOT the accessibility-only focus mode
			# Godot 4.7 gives Labels/RichText/ScrollContainers — grab_focus on
			# those warns and no-ops unless a screen reader is on, which leaves
			# the panel unfocused and the pad dead.
			if (ctl.focus_mode == Control.FOCUS_ALL or ctl.focus_mode == Control.FOCUS_CLICK) \
					and not (ctl is Button and (ctl as Button).disabled):
				return ctl
		var deep := _first_focusable(child)
		if deep != null:
			return deep
	return null


static func _enable_follow_focus(n: Node) -> void:
	for child in n.get_children():
		if child is ScrollContainer:
			(child as ScrollContainer).follow_focus = true
		_enable_follow_focus(child)
