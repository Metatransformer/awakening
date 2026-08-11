extends RefCounted
## Card #58 — **`docs/STYLEGUIDE.md` §4.5, photographed at last.** The same pose,
## rendered native and rendered through the 480 x 270 internal buffer, in one
## process, with the pair composited into a single PNG and a 3x nearest zoom of
## the same crop beside it.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/internal_res.gd \
##     --out=/tmp/ir/x.png --size=1280x720
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/internal_res.gd \
##     --out=/tmp/ir/x.png --size=1280x720 --gate-prefab=eye_row
##
## Optional: `--samples=120` per config (0 skips the timing pass).
##
## **Run it at a true 1280x720 and nowhere else.** §4.5's whole argument is about
## a non-integer 2.67x present; at 1920x1080 it is 4.0x and the shimmer question
## the sharp-bilinear filter exists to answer does not arise. `shoot.gd` sizes the
## real window as of #35, so `--size` is now honest — a frame from before
## 2026-08-11 is a 6880x2756 supersample and is not comparable with anything here.
##
## ## Why both halves are shot inside one process
##
## Same reason `aa_compare.gd` gives: this Mac runs four agents' director windows
## at once, so the absolute frame times are a number about the machine. The
## DIFFERENCE between two rows of one run is the honest part, and the difference
## is the entire question — §4.5 is expected to be a large win and "expected" is
## not a measurement.
##
## The world is **paused** across each pair. Without it the two frames are two
## different moments — a wandering enemy, a swinging torch, a breathing idle —
## and a side-by-side of two different moments cannot be read for resolution.
## `KitTorch` swings its energy off the WALL clock, so pausing is not enough for
## it; the flames are pinned separately, exactly as `room_range.gd` does.

## `garrison_look.tl_01_arrive`, and `aa_compare.gd`'s pose. Copied rather than
## shared for the reason aa_compare gives — but it is the same eye on purpose, so
## §4.8's sheet and this one are photographs of one frame under two decisions.
const EYE := Vector3(0.0, 1.7, 8.0)
const AIM := Vector3(0.0, 1.2, -4.0)
const FOV := 50.0

## Floor 1's layout, shared with `room_range.gd`, `echo_plates.gd` and
## `cistern_floor.gd` so the four directors describe one floor and not four.
const SEED := 20260809

## `echo_plates.gd`'s READ_AT: inside `LockedDoor`'s 2.9 m interact radius, far
## enough back that the leaves and what is behind them share the frame.
const READ_AT := 2.5

## Frames discarded after the pipeline is flipped. Turning §4.5 on rebuilds a
## render target, resizes the shadow atlas and re-registers a camera; the frames
## during that are a measurement of the rebuild.
const SETTLE := 30

## The crop the zoom sheet magnifies, in 1280x720 frame coordinates, and 3x is
## what §3.1b used to re-check type under the 1:1 harness. Upper-middle third:
## §5's HUD is deliberately out of it at the top, the horizon and a silhouette
## are in it, and it is where the over-the-shoulder camera puts the fight.
const ZOOM_RECT := Rect2i(420, 90, 320, 180)
const ZOOM := 3

var out := ""
var _rows: Array[String] = []


func run(rig) -> void:
	out = rig.arg("out", "/tmp/ir/x.png").get_base_dir()
	var samples: int = int(rig.arg("samples", "120"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var vp: Viewport = rig.root
	print("IR window=%dx%d  internal=%v"
		% [int(vp.get_visible_rect().size.x), int(vp.get_visible_rect().size.y),
			Settings._screen.internal_size()])
	if int(vp.get_visible_rect().size.x) != 1280:
		print("IR WARNING not 1280x720 -- the 2.67x present is the thing being "
			+ "judged and this is not it")

	if samples > 0:
		RenderingServer.viewport_set_measure_render_time(rig.root.get_viewport_rid(), true)
		RenderingServer.viewport_set_measure_render_time(Settings._screen.viewport_rid(), true)

	var was: bool = Settings.internal_render
	if rig.scene().name == &"DungeonRun":
		await _dungeon(rig, samples)
	else:
		await _garrison(rig, samples)
	# Put the pipeline back the way the game boots, so anything running after
	# this director in the same process is not quietly photographing the wrong
	# one -- `aa_compare.gd`'s closing note, same hazard.
	Settings.set_internal_render(was)
	if samples > 0:
		RenderingServer.viewport_set_measure_render_time(rig.root.get_viewport_rid(), false)
		RenderingServer.viewport_set_measure_render_time(Settings._screen.viewport_rid(), false)

	print("")
	print("IR %-30s %8s %8s %8s %8s %7s"
		% ["pose / pipeline", "frame_ms", "p95", "cpu_ms", "vram_mb", "draws"])
	for r: String in _rows:
		print(r)
	print("")
	print("IR done -> %s" % out)


# --- The two hosts ------------------------------------------------------------

func _garrison(rig, samples: int) -> void:
	# The booths instance about twenty GLBs and the bodies retarget a shared clip
	# library at load; a shot taken early photographs bind-pose statues.
	await rig.wait_frames(40)
	var cam := Camera3D.new()
	cam.fov = FOV
	rig.scene().add_child(cam)
	cam.make_current()
	cam.global_position = EYE
	cam.look_at(AIM, Vector3.UP)
	_still_the_flames(rig.scene())
	await _pair(rig, "g_arrive", samples)


func _dungeon(rig, samples: int) -> void:
	Game.reset()
	Run.enter(SEED)
	Game.grant(&"bow")
	Run.level = 1

	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	d.seed_override = SEED
	rig.scene().add_child(d)
	await rig.wait_frames(14)

	var hero: Node3D = _hero(rig)
	var cam: Camera3D = _first(rig.scene(), func(n: Node) -> bool: return n is GameCamera) as Camera3D
	if hero == null or cam == null:
		print("IR FAIL no hero or no GameCamera in the scene")
		return
	cam.make_current()
	_still_the_flames(d)
	await rig.wait_frames(20)

	# A. the entrance room, read off the shut shortcut door. Deterministic, and
	# the same frame `room_range.gd` beat A and `echo_plates.gd` photograph -- a
	# dark room with one lit anchor, which is the hardest thing to ask of a
	# 5-bit framebuffer.
	var door: Node3D = d.call(&"anchor_node", &"shortcut_door")
	if door != null:
		hero.velocity = Vector3.ZERO
		hero.global_position = door.global_position \
			+ door.global_transform.basis.z * READ_AT + Vector3(0.0, 0.15, 0.0)
		await _face(rig, hero, door.global_position)
		await _pair(rig, "d_shortcut_door", samples)

	# B. a plain generated room -- masonry, torch pools, and whatever body the
	# seed put in it. This is the frame the treatment has to survive in bulk.
	var plain: Node3D = _plain_room(d)
	if plain != null:
		hero.velocity = Vector3.ZERO
		hero.global_position = plain.global_position + Vector3(0.0, 0.15, 4.0)
		await _face(rig, hero, plain.global_position + Vector3(0, 0, -6))
		await _pair(rig, "d_plain_room", samples)


# --- One pose, both pipelines -------------------------------------------------

func _pair(rig, stem: String, samples: int) -> void:
	# `rig` IS the SceneTree -- `tools/shoot.gd` extends it.
	var tree := rig as SceneTree
	var was_vsync := DisplayServer.window_get_vsync_mode()
	if samples > 0:
		# Vsync pins the frame to the panel (120 Hz here), so with it on both rows
		# report 8.33 ms and the sheet says §4.5 is free. `perf_probe.gd` and
		# `aa_compare.gd` learned this first; it is put back below.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Freeze the world so the two frames are one moment photographed twice.
	tree.paused = true
	await rig.wait_frames(4)

	var native := out.path_join("%s_native.png" % stem)
	var psx := out.path_join("%s_480.png" % stem)

	await _one(rig, stem, "native", false, native, samples)
	await _one(rig, stem, "480x270", true, psx, samples)

	tree.paused = false
	DisplayServer.window_set_vsync_mode(was_vsync as DisplayServer.VSyncMode)

	_compose(native, psx, out.path_join("%s_pair.png" % stem), false)
	_compose(native, psx, out.path_join("%s_zoom.png" % stem), true)


func _one(rig, stem: String, label: String, on: bool, path: String, samples: int) -> void:
	Settings.set_internal_render(on)
	await rig.wait_frames(SETTLE)
	await rig.capture(path)

	var ms := PackedFloat32Array()
	if samples > 0:
		var last := Time.get_ticks_usec()
		for i in samples:
			await rig.wait_frames(1)
			var now := Time.get_ticks_usec()
			ms.append((now - last) / 1000.0)
			last = now
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var draws := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	# **`cpu_ms` is the SUM of two viewports, and it has to be.** With §4.5 on the
	# root draws one textured quad and the SubViewport draws the world, so the
	# root's own number stops meaning "the frame" the instant the pipeline is
	# switched on -- read it alone and §4.5 looks free by a factor of ten.
	# `gpu_ms` reads zero on this Metal driver (#55), which is why the argument
	# below rests on the wall clock and VRAM instead.
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rig.root.get_viewport_rid()) \
		+ RenderingServer.viewport_get_measured_render_time_cpu(Settings._screen.viewport_rid())
	_rows.append("IR %-30s %8.2f %8.2f %8.2f %8.1f %7d"
		% ["%s / %s" % [stem, label], _pct(ms, 0.5), _pct(ms, 0.95), cpu, vram, draws])


# --- The sheets ---------------------------------------------------------------

## Two frames side by side, native on the left. `zoom` magnifies `ZOOM_RECT` by
## `ZOOM` with a nearest resample -- a bilinear one would put back exactly the
## softening the sheet exists to show.
func _compose(left_path: String, right_path: String, dest: String, zoom: bool) -> void:
	var a := Image.load_from_file(left_path)
	var b := Image.load_from_file(right_path)
	if a == null or b == null:
		print("IR FAIL could not re-read %s / %s" % [left_path, right_path])
		return
	if zoom:
		a = _zoom(a)
		b = _zoom(b)
	# `blit_rect` refuses two different formats, and a capture comes back RGBA8
	# on one path and RGB8 on another depending on what wrote the PNG.
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var gap := 8
	var w := a.get_width() + b.get_width() + gap
	var h := maxi(a.get_height(), b.get_height())
	var sheet := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	# VOID `#080810`, §2 -- never `#000000`, even in a contact sheet.
	sheet.fill(Color8(8, 8, 16))
	sheet.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	sheet.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()),
		Vector2i(a.get_width() + gap, 0))
	sheet.save_png(dest)
	print("IR sheet %s  (left native, right 480x270)" % dest)


func _zoom(img: Image) -> Image:
	var crop := img.get_region(ZOOM_RECT)
	crop.resize(ZOOM_RECT.size.x * ZOOM, ZOOM_RECT.size.y * ZOOM,
		Image.INTERPOLATE_NEAREST)
	return crop


# --- Fixture ------------------------------------------------------------------

func _pct(v: PackedFloat32Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	var i := clampi(int(round(q * (s.size() - 1))), 0, s.size() - 1)
	return s[i]


## `room_range.gd`'s note, and its reason: `KitTorch._process` swings
## `light_energy` off `Time.get_ticks_msec()` -- the wall clock -- so neither
## `Engine.time_scale` nor `SceneTree.paused` stills it, and the pair would be two
## different fires.
func _still_the_flames(root: Node) -> void:
	var n := 0
	for t in _all(root):
		if t is KitTorch:
			t.flicker = 0.0
			t.light_energy = t.light_energy
			n += 1
	print("IR held %d flame(s) at nominal energy" % n)


func _face(rig, hero: Node3D, at: Vector3) -> void:
	var to := K.flat(at - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _plain_room(d: Node) -> Node3D:
	var rooms: Dictionary = d.get(&"rooms")
	for cell: Vector2i in rooms:
		var r: Dictionary = rooms[cell]
		if not (r["anchors"] as Dictionary).is_empty():
			continue
		if cell == d.get(&"entrance") or cell == d.get(&"deepest"):
			continue
		return r["node"]
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


func _first(root: Node, pred: Callable) -> Node:
	for n in _all(root):
		if pred.call(n):
			return n
	return null
