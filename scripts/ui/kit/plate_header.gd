class_name PlateHeader
extends RefCounted
## A panel that is ABOUT a thing opens with that thing's face.
##
##     ┌───────────────────────────────────────────┐
##     │▌                                          │  ← archetype art, full-bleed
##     │▌        (art)                             │
##     │▌                              ░░░░░░░░░░░ │  ← gradient hand-off to the fill
##     │▌ [glyph]  RARE · INGREDIENT               │  ← kicker, gold, uppercase
##     │▌          Deep Amber                      │  ← title, display face
##     └───────────────────────────────────────────┘
##      ▲ optional semantic edge (rarity, danger, allegiance)
##
## ART IS KEYED BY ARCHETYPE, NEVER PER INSTANCE. `kind + biome` for a place,
## `rarity + slot` for an item. A dozen images cover a game; one image per
## instance is how an art budget dies.
##
## The art is OPTIONAL and degrades to the panel fill. A header with no image is
## still a PlateHeader — it still carries the emblem, the kicker and the type
## hierarchy, just quieter. That is what lets a panel adopt the component before
## its art exists.
##
## AN ARTLESS HEADER IS AS TALL AS ITS TEXT, not as tall as the missing picture.
## HEIGHT is the letterbox the ART needs; reserving it with no art produces a
## page header, a tall band of nothing, and only then the name. So a caller never
## passes a magic `height` to get a compact header — if you find one that does,
## it is a workaround for that bug and can go.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const KitIconScript := preload("res://scripts/ui/kit/kit_icon.gd")

const HEIGHT := 208
const EMBLEM_PX := 52
const EDGE_PX := 4


static func build(parent: Node, config: Dictionary) -> Control:
	var title_text := String(config.get("title", ""))
	if title_text.is_empty():
		push_error("[PlateHeader] reason=a plate header requires a title; header omitted")
		return null

	var band := Control.new()
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art := KitIconScript.resolve(config.get("art"))
	# 0 means "measure the text" — resolved at the bottom, once content exists.
	var height := int(config.get("height", HEIGHT if art != null else 0))
	band.custom_minimum_size = Vector2(0, maxi(height, 0))
	if art != null:
		var plate := TextureRect.new()
		plate.texture = art
		plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# COVER, not fit: the band is a wide letterbox and the plates are not, so
		# fitting would pillarbox them against the fill and read as a broken image.
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(plate)
		band.add_child(_scrim(config))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_bottom", 16)
	if art == null:
		# With a picture above it the title only needs air below. With nothing
		# above it, the text IS the band and needs air on both sides of itself.
		pad.add_theme_constant_override("margin_top", 16)
	band.add_child(pad)

	# Identity sits on the DARK end of the gradient, bottom-left, so the art can
	# be busy top-right without ever fighting the name.
	var anchor := VBoxContainer.new()
	anchor.alignment = BoxContainer.ALIGNMENT_END
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(anchor)

	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	line.add_theme_constant_override("separation", 13)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(line)

	var emblem := KitIconScript.resolve(config.get("emblem"))
	if emblem != null:
		var crest := KitIconScript.rect(emblem, EMBLEM_PX)
		crest.size_flags_vertical = Control.SIZE_SHRINK_END
		line.add_child(crest)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_END
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 1)
	line.add_child(text)

	# Built whenever the caller PASSED a kicker, even an empty one. A panel whose
	# kicker depends on state it does not have yet — a counter that cannot know it
	# forges until its board has been read — needs somewhere to write the answer
	# later, and a Label conjured on the second call would land under the title.
	if config.has("kicker"):
		var kicker := Label.new()
		kicker.text = String(config["kicker"]).to_upper()
		kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.apply_text_style(kicker, UITheme.TYPE_CAPTION, UITheme.ACCENT)
		if art != null:
			_outline(kicker, 4)
		text.add_child(kicker)
		band.set_meta(&"plate_kicker", kicker)

	var title := Label.new()
	title.text = title_text
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(title, UITheme.TYPE_TITLE, UITheme.TEXT)
	if art != null:
		_outline(title, 6)
	text.add_child(title)

	var edge: Variant = config.get("edge")
	if edge != null and not edge is Color:
		push_error("[PlateHeader] title='%s' edge=%s reason=edge must be a Color; band drawn without it"
			% [title_text, edge])
	if edge is Color:
		var strip := ColorRect.new()
		strip.color = edge as Color
		strip.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		strip.offset_right = EDGE_PX
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(strip)

	if parent != null:
		parent.add_child(band)
	if height <= 0:
		# The pad is anchored full-rect, so the band cannot infer a height from
		# it — ask the content what it needs. Measured after the reparent, so the
		# labels already have their theme fonts.
		band.custom_minimum_size.y = ceilf(pad.get_combined_minimum_size().y)
	return band


## Rewrite the kicker of a header already on screen.
##
## The header is otherwise built once, because it is the panel's IDENTITY and an
## identity that flickers is not one. The kicker is the exception: it carries the
## state qualifier — "RARE · INGREDIENT", "FORGE" — and the panel sometimes cannot
## know that until it has read the thing it is about.
##
## Does nothing if the header was built without a `kicker` key. Adding one after
## the fact would put it under the title instead of over it.
static func set_kicker(header: Control, text: String) -> void:
	if header == null or not header.has_meta(&"plate_kicker"):
		return
	var label := header.get_meta(&"plate_kicker") as Label
	if label != null:
		label.text = text.to_upper()


## Hand the art off to the panel fill, so there is no seam where the image stops.
##
## Two passes, because one is not enough: a bottom-up dark ramp so the title
## always lands on something calm, and a left wash so the emblem does too.
## Without the second pass, a plate whose subject sits left — half of them do —
## puts the crest on top of a lit wall.
static func _scrim(config: Dictionary) -> Control:
	var stack := Control.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill: Color = config.get("fill", UITheme.BG_DARK)
	var down := TextureRect.new()
	down.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	down.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	down.stretch_mode = TextureRect.STRETCH_SCALE
	down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	down.texture = _ramp([
		Color(fill.r, fill.g, fill.b, 1.0),
		Color(0, 0, 0, 0.55),
		Color(0, 0, 0, 0.10),
	], Vector2(0.5, 1.0), Vector2(0.5, 0.0))
	stack.add_child(down)

	var across := TextureRect.new()
	across.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	across.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	across.stretch_mode = TextureRect.STRETCH_SCALE
	across.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.texture = _ramp([
		Color(0, 0, 0, 0.45),
		Color(0, 0, 0, 0.0),
	], Vector2(0.0, 0.5), Vector2(0.6, 0.5))
	stack.add_child(across)
	return stack


static func _ramp(colors: Array, from: Vector2, to: Vector2) -> GradientTexture2D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var ramp := PackedColorArray()
	for index in colors.size():
		offsets.append(float(index) / maxf(1.0, float(colors.size() - 1)))
		ramp.append(colors[index])
	gradient.offsets = offsets
	gradient.colors = ramp
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 64
	tex.height = 64
	return tex


## Type over an image needs its own floor. The scrim handles the average case;
## the outline handles the bright pixel that happens to sit behind the "H".
static func _outline(label: Label, size: int) -> void:
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.85))
