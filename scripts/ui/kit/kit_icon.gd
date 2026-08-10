class_name KitIcon
extends RefCounted
## Icon resolution for the composites — one rule for the whole kit.
##
## Lives in its own file rather than on `UiKit` because every composite needs it
## and UiKit preloads every composite; putting it there makes the preload graph
## cyclic.
##
## Accepts a live Texture2D, a `res://` path, or nothing. A missing icon is a
## degraded row, never a dead panel — art arriving late must not block a screen.


static func resolve(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D
	var path := String(value) if value != null else ""
	if path.is_empty():
		return null
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	if res == null and path.ends_with(".svg"):
		res = _raw_svg(path)
	if res == null:
		push_warning("[KitIcon] path='%s' reason=icon failed to load; element renders without it"
			% path)
		return null
	if not res is Texture2D:
		push_warning("[KitIcon] path='%s' type=%s reason=icon resource is not a Texture2D"
			% [path, res.get_class()])
		return null
	return res as Texture2D


## A deterministic runtime path for raw SVG source, so a fresh worktree renders a
## generated family before the editor's import cache has caught up.
static func _raw_svg(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var error := image.load_svg_from_string(FileAccess.get_file_as_string(path))
	if error != OK:
		push_warning("[KitIcon] path='%s' error=%s reason=raw SVG failed to decode"
			% [path, error_string(error)])
		return null
	return ImageTexture.create_from_image(image)


## A decorative TextureRect at a fixed square size. Never focusable, never eats a
## click — every composite that shows an icon wants exactly this.
static func rect(texture: Texture2D, px: int, alpha := 1.0) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = Vector2(px, px)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.focus_mode = Control.FOCUS_NONE
	art.modulate.a = alpha
	return art
