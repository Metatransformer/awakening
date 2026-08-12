extends RefCounted
## The edge-treatment sheet: one garrison pose, photographed under every
## anti-aliasing option this engine offers, and each one priced in the same run.
##
## Card #55. Until 2026-08-11 the harness rendered 6880x2756 and Lanczos-
## downscaled to 1280x720, so every frame this project ever judged carried a ~20x
## supersample nobody chose and nobody paid for. `shoot.gd._size_the_window` made
## captures 1:1, and the edges underneath turned out to be rougher than the whole
## repo believed. `docs/STYLEGUIDE.md` owns what to do about that; this is the
## instrument it has to be decided on.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/aa_compare.gd --out=/tmp/aa/x.png
##
## Optional: --samples=120 (per config; 0 skips the timing pass entirely)
##
## **THE POSE IS `garrison_look`'s `tl_01_arrive` ON PURPOSE.** It is the one
## frame in this project that holds all four things the decision turns on at
## once, so no two of them can be judged against different lighting:
##
##   - the curtain-wall merlons and the gatehouse roofline against a flat sky —
##     hard geometric edges, which is all MSAA can ever touch;
##   - ~~the world-space `LANTERNKEEPER` plate — a Label3D, so it is 3D geometry
##     wearing a glyph atlas, and it aliases like geometry~~ — **gone since card
##     #61.** That plate is a `WorldCaption` drawn on the HUD canvas now, so it
##     belongs to the third bullet rather than the second, and this pose no
##     longer holds a sample of "type rendered as world geometry" at all. The
##     three remaining ones are carved signs (`Statue`, `LockedDoor`, the
##     gatehouse lintel) and none of them is in this frame. Nothing in #55's
##     conclusion turns on it: the plate aliased like geometry and MSAA smoothed
##     it like geometry, which was one more instance of the merlons above, not a
##     separate finding.
##   - the HUD's Cinzel key caps — 2D canvas, which **no** viewport AA mode
##     reaches, MSAA or FXAA or TAA;
##   - the vitals pip row — `draw_rect` on the same canvas, whose steps are meant
##     to be steps (STYLEGUIDE §5.1).
##
## **Why the timing lives here and not in `perf_probe.gd`.** perf_probe's own
## header says the p95 on this machine is frequently other agents' windows rather
## than the game, and it is right. Measuring all the configs back to back inside
## ONE process makes that pollution common-mode: the absolute medians are still
## only as quiet as the Mac was, but the DIFFERENCES between two rows of the same
## run are the honest part, and the difference is the whole question. Two separate
## perf_probe runs minutes apart cannot say that.
##
## Read `frame_ms med`, not p95, and read the deltas, not the absolutes — for the
## same reason perf_probe prints its TAIL NOT ATTRIBUTABLE warning.


## eye / target / fov -- `garrison_look.tl_01_arrive`, copied rather than shared
## because that director photographs five booths and this one must not drift with
## it.
const EYE := Vector3(0.0, 1.7, 8.0)
const AIM := Vector3(0.0, 1.2, -4.0)
const FOV := 50.0

## Frames discarded after each mode change. A viewport that has just had its MSAA
## level swapped rebuilds its framebuffers, and the frames during that rebuild are
## a measurement of the rebuild.
const SETTLE := 40

## name, msaa_3d, screen_space_aa, use_taa, msaa_2d
##
## `msaa_2d` is in the table because it is the only viewport knob that touches the
## canvas at all, and the obvious guess -- "it will fix the HUD type" -- is wrong
## in an instructive way: it antialiases 2D PRIMITIVES (the carets, the reticle
## arms, the damage arc), and a glyph is a textured quad the font rasteriser has
## already antialiased, so type does not move. Photograph it rather than argue.
static var CONFIGS: Array = [
	["00_none",        Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, false, Viewport.MSAA_DISABLED],
	["01_msaa2x",      Viewport.MSAA_2X,       Viewport.SCREEN_SPACE_AA_DISABLED, false, Viewport.MSAA_DISABLED],
	["02_msaa4x",      Viewport.MSAA_4X,       Viewport.SCREEN_SPACE_AA_DISABLED, false, Viewport.MSAA_DISABLED],
	["03_msaa8x",      Viewport.MSAA_8X,       Viewport.SCREEN_SPACE_AA_DISABLED, false, Viewport.MSAA_DISABLED],
	["04_fxaa",        Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA,     false, Viewport.MSAA_DISABLED],
	["05_msaa4x_fxaa", Viewport.MSAA_4X,       Viewport.SCREEN_SPACE_AA_FXAA,     false, Viewport.MSAA_DISABLED],
	["06_taa",         Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, true,  Viewport.MSAA_DISABLED],
	["07_msaa8x_2d4x", Viewport.MSAA_8X,       Viewport.SCREEN_SPACE_AA_DISABLED, false, Viewport.MSAA_4X],
]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/aa/x.png").get_base_dir()
	var samples: int = int(rig.arg("samples", "120"))

	# The booths instance about twenty GLBs and the bodies retarget a shared clip
	# library at load. A shot taken early photographs bind-pose statues, which is
	# a different bug entirely -- `garrison_look` waits 40 frames for this and so
	# does this.
	await rig.wait_frames(40)

	var scene: Node3D = rig.scene()
	var cam := Camera3D.new()
	cam.fov = FOV
	scene.add_child(cam)
	cam.make_current()
	cam.global_position = EYE
	cam.look_at(AIM, Vector3.UP)

	var vp: Viewport = rig.root
	var vp_rid: RID = rig.root.get_viewport_rid()
	var was_vsync: int = DisplayServer.window_get_vsync_mode()

	# Vsync pins the frame to the panel (120 Hz here), so with it on every config
	# reports 8.33 ms and the sheet says all eight are free. perf_probe learned
	# this first; the knob is put back at the end of the run.
	if samples > 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)

	print("AA pose eye=%v aim=%v fov=%.0f  vp=%dx%d"
		% [EYE, AIM, FOV, int(vp.get_visible_rect().size.x),
			int(vp.get_visible_rect().size.y)])

	for cfg in CONFIGS:
		var name: String = cfg[0]
		vp.msaa_3d = cfg[1]
		vp.screen_space_aa = cfg[2]
		vp.use_taa = cfg[3]
		vp.msaa_2d = cfg[4]
		await rig.wait_frames(SETTLE)
		await rig.capture(out.path_join("aa_%s.png" % name))

		var ms := PackedFloat32Array()
		if samples > 0:
			# Read `vram_mb` alongside: 8x MSAA is a memory cost as well as a
			# fill cost, and on a machine where `gpu_ms` reads zero (it does on
			# this Metal driver) VRAM is the only other evidence that the mode
			# actually took effect.
			var last := Time.get_ticks_usec()
			for i in samples:
				await rig.wait_frames(1)
				var now := Time.get_ticks_usec()
				ms.append((now - last) / 1000.0)
				last = now
		var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		var cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
		print("AA %-16s frame_ms med=%6.2f p95=%6.2f  cpu_ms=%5.2f  vram_mb=%7.1f  n=%d"
			% [name, _pct(ms, 0.5), _pct(ms, 0.95), cpu, vram, ms.size()])

	# Put the viewport back the way the game boots, so anything that runs after
	# this director in the same process is not quietly photographing 8x.
	Settings.apply_video()
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.msaa_2d = Viewport.MSAA_DISABLED
	RenderingServer.viewport_set_measure_render_time(vp_rid, false)
	DisplayServer.window_set_vsync_mode(was_vsync as DisplayServer.VSyncMode)
	print("AA done -> %s" % out)


func _pct(v: PackedFloat32Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	var i := clampi(int(round(q * (s.size() - 1))), 0, s.size() - 1)
	return s[i]
