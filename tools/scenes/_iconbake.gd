extends Node3D
## Bakes HUD slot icons from the REAL item models, so the HUD never ships
## hand-drawn vector glyphs that do not match the thing you are holding.
## This is what OOT did: its C-button icons are rendered item models.
##
## Each icon gets its own SubViewport with a transparent background, an
## orthogonal camera framed to the model's measured extent (WeaponModels.extent),
## and a two-light rig that reads as torchlight so the icon belongs to the scene.
##
## Must run WINDOWED. `--headless` uses the dummy renderer and every saved PNG
## comes back empty.
##
##   godot --path . res://tools/scenes/_iconbake.tscn -- --out=/abs/dir

const ICONS := {
	"hookshot_pistol": Vector3(0.35, 0.55, 0.0),
	"sword_knightly":  Vector3(0.0, 0.0, 0.62),
	"sword_crude":     Vector3(0.0, 0.0, 0.62),
	"shield_knightly": Vector3(0.0, 0.0, 0.0),
	"shield_noble":    Vector3(0.0, 0.0, 0.0),
	"kite_shield":     Vector3(0.0, 0.0, 0.0),
}

const SIZE := 512
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


func _save() -> void:
	for id in ICONS:
		var vp: SubViewport = get_node_or_null(NodePath("vp_" + id))
		if vp == null:
			continue
		var img := vp.get_texture().get_image()
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
