extends Node3D
## Bakes HUD slot icons from the REAL item models, so the HUD never ships
## hand-drawn vector glyphs that do not match the thing you are holding.
## This is what OOT did: its C-button icons are rendered item models.
##
## Each icon gets its own SubViewport with a transparent background, an
## orthogonal camera framed to the model's measured extent (WeaponModels.extent),
## and a two-light rig that reads as torchlight so the icon belongs to the scene.
##
## The render is then POSTERISED into the Pal ramp and downsampled to ICON_PX.
## A full-colour 256px render dropped into a 5-bit HUD looks like a sticker; the
## styleguide bans vector icon sets (§7.10) because it wants glyphs that were
## authored in the palette, and this is how a rendered icon earns that. What
## survives quantisation is the silhouette, which is all a 32px cell can show.
##
## Must run WINDOWED. `--headless` uses the dummy renderer and every saved PNG
## comes back empty.
##
##   godot --path . res://tools/scenes/_iconbake.tscn -- --out=res://assets/ui/icons/hud
##
## --out MUST be a directory that holds nothing but bakes. This overwrites every
## <id>.png in it without asking, and pointing it at assets/ui/icons/ destroyed
## the imported hookshot_pistol.png once already. assets/ui/icons/hud/ is that
## directory; icons/ proper is for imported and hand-authored art.

## The kit strip, in Hud.KIT order. Values are the euler the model is spun to
## before framing -- a sword read edge-on is a line, so it gets a Z tilt.
const ICONS := {
	"sword_knightly":  Vector3(0.0, 0.0, 0.62),
	"kite_shield":     Vector3(0.0, 0.0, 0.0),
	"hookshot_pistol": Vector3(0.35, 0.55, 0.0),
	"bow_knightly":    Vector3(0.9, 0.9, 0.4),  # three-quarter: a bow is edge-on from every axis
}

## Rendered at SIZE, shipped at ICON_PX. Rendering large and knocking it down is
## what gives the 32px silhouette clean edges.
const SIZE := 512
const ICON_PX := 32
## Luminance cuts into the Pal ramp. Four levels is what the styleguide's
## dither budget affords, and a 32px glyph cannot carry more.
## id -> [zoom, x offset, y offset], applied AFTER the refit, in units of the
## refit box. A whole sword at 32px is a three-pixel scratch; what makes a sword
## read is the guard and pommel, so the icon crops to them instead of dutifully
## showing the entire blade. This is what hand-authored game icons do and it is
## the only reason a rendered icon can work in a 32px cell at all.
const CROP := {
	"sword_knightly": [2.1, 0.22, -0.26],
	"bow_knightly":   [0.92, 0.0, 0.0],  # the whole arc, or it reads as a stick
}

const RAMP := [Pal.VOID, Pal.ASH, Pal.MOTH, Pal.BONE]
const CUTS := [0.16, 0.38, 0.66]
## Icons read better with a little air; 1.0 would touch the frame edge.
const PAD := 1.22

var _out_dir := "/tmp/icons"


var _frames := 0
var _saved := false
var _fitted := false


func _ready() -> void:
	print("ICONBAKE: _ready")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out_dir)

	print("ICONBAKE: out=", _out_dir)
	for id in ICONS:
		_bake(id, ICONS[id])
	print("ICONBAKE: baked ", ICONS.size(), " viewports")


func _process(_d: float) -> void:
	_frames += 1
	# Frame 4: the first render has landed, so refit each camera to the silhouette
	# the renderer ACTUALLY produced. A model AABB is only a hint — skinned meshes
	# report their bind-pose bounds, which on the hookshot is mostly empty air.
	if _frames == 4 and not _fitted:
		_fitted = true
		_refit()
		return
	if _saved or _frames < 8:
		return
	_saved = true
	_save()
	get_tree().quit()


## Second pass: recentre and rezoom every camera on the rendered alpha bounds.
func _refit() -> void:
	for id in ICONS:
		var vp: SubViewport = get_node_or_null(NodePath("vp_" + id))
		if vp == null:
			continue
		var img := vp.get_texture().get_image()
		var r := img.get_used_rect()
		if r.size.x <= 0 or r.size.y <= 0:
			push_warning("iconbake: %s rendered empty" % id)
			continue
		var cam := vp.get_node("cam") as Camera3D
		var per_px: float = cam.size / float(SIZE)
		var mid := Vector2(r.position) + Vector2(r.size) * 0.5
		cam.h_offset += (mid.x - SIZE * 0.5) * per_px
		cam.v_offset -= (mid.y - SIZE * 0.5) * per_px
		cam.size = maxf(float(r.size.x), float(r.size.y)) * per_px * PAD
		if CROP.has(id):
			var c: Array = CROP[id]
			cam.h_offset += float(c[1]) * cam.size
			cam.v_offset += float(c[2]) * cam.size
			cam.size /= float(c[0])


func _save() -> void:
	for id in ICONS:
		var vp: SubViewport = get_node_or_null(NodePath("vp_" + id))
		if vp == null:
			continue
		var img := vp.get_texture().get_image()
		_posterise(img)
		var path := _out_dir.path_join(id + ".png")
		var err := img.save_png(path)
		print("%-18s %s  %dx%d" % [id, "ok" if err == OK else "FAIL", img.get_width(), img.get_height()])


func _bake(id: String, euler: Vector3) -> void:
	var model := WeaponModels.make(id)
	if model == null:
		push_error("iconbake: %s missing" % id)
		return

	var vp := SubViewport.new()
	vp.name = "vp_" + id
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var pivot := Node3D.new()
	pivot.rotation = euler
	pivot.add_child(model)
	vp.add_child(pivot)

	# Centre the model on the pivot's own origin BEFORE the pivot rotates, so the
	# rotation spins the icon in place instead of swinging it out of frame.
	var aabb := _aabb_of(model)
	model.position = -aabb.get_center()

	# Frame the ROTATED silhouette: an edge-on sword and a face-on shield need
	# very different camera sizes, and the raw AABB knows nothing about `euler`.
	var basis := Basis.from_euler(euler)
	var half := aabb.size * 0.5
	var w := 0.0
	var h := 0.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var c: Vector3 = basis * Vector3(half.x * sx, half.y * sy, half.z * sz)
				w = maxf(w, absf(c.x))
				h = maxf(h, absf(c.y))
	var reach := maxf(maxf(w, h), 0.001)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = reach * 2.0 * PAD
	cam.position = Vector3(0.0, 0.0, aabb.size.length() * 2.0 + 1.0)
	cam.name = "cam"
	cam.near = 0.01
	cam.far = cam.position.z * 3.0
	vp.add_child(cam)

	# Key from upper-left, warm, the way a torch would sit; cool rim from behind
	# so a dark blade still separates from a dark HUD panel.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, -38.0, 0.0)
	key.light_energy = 2.6
	key.light_color = Color(1.0, 0.88, 0.72)
	vp.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(18.0, 152.0, 0.0)
	rim.light_energy = 1.5
	rim.light_color = Color(0.78, 0.90, 1.0)
	vp.add_child(rim)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.36, 0.32)
	e.ambient_light_energy = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	vp.add_child(env)


## Downsample to ICON_PX and snap every surviving pixel onto the Pal ramp.
## Alpha is thresholded, not blended: a half-transparent edge pixel dithers into
## the scene behind it and the silhouette goes soft, which is the one thing a
## 32px glyph cannot afford.
func _posterise(img: Image) -> void:
	img.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
	for y in ICON_PX:
		for x in ICON_PX:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var l := c.get_luminance()
			var step := RAMP.size() - 1
			for i in CUTS.size():
				if l < CUTS[i]:
					step = i
					break
			img.set_pixel(x, y, Color(RAMP[step], 1.0))
	_dilate(img)


## Grow the silhouette by one pixel of VOID.
##
## A sword is three pixels wide at 32px and reads as a scratch. This is the same
## trick as the 1px dark outline the HUD uses everywhere else: it gives a thin
## glyph a body, and it separates the icon from whatever the cell is filled with.
## Without it the only kit icon that survives quantisation is the shield.
func _dilate(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in ICON_PX:
		for x in ICON_PX:
			if src.get_pixel(x, y).a >= 0.5:
				continue
			var touching := false
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= ICON_PX or ny >= ICON_PX:
						continue
					if src.get_pixel(nx, ny).a >= 0.5:
						touching = true
						break
				if touching:
					break
			if touching:
				img.set_pixel(x, y, Color(Pal.VOID, 1.0))


## Union of every MeshInstance3D AABB under `root`, in root-local space.
func _aabb_of(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		var a: AABB = t * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out
