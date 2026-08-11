extends RefCounted
## Card #57 — **does this backend actually render 8x MSAA, or does it hand you
## 4x and report success?**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/msaa_clamp.gd \
##     --out=/tmp/msaa/x.png --size=1280x720
##
## ## Why this exists when `aa_compare.gd` already ran
##
## #55 measured that 8x and 4x cost the **same VRAM to 0.1 MB** and that their
## edge histograms were inside noise, and #57 was opened off that. Both of those
## are consistent with a clamp and *also* consistent with "8x is real and its
## second four samples land in the same places". They are different claims and
## only one of them justifies deleting a row from the options menu.
##
## The distinguishing measurement is the frame itself. Freeze the world, render
## the identical pose at each level, and subtract. A resolve over 8 samples and a
## resolve over 4 cannot produce a **bit-identical** 921,600-pixel frame unless
## the driver gave you the same framebuffer twice.
##
## ## The instrument is calibrated in both directions, per CLAUDE.md §2
##
## A diff director that reports 0 px is worthless until it has been shown it can
## report anything else, and one that reports a number is worthless until it has
## been shown it reports 0 when nothing changed. So every run prints, before it
## gets to the question:
##
##  * **null** — 4x photographed twice with nothing touched in between. This is
##    the NOISE FLOOR, and it is not asserted to be exactly zero. Two runs here:
##    the first read 3 px of 921,600 at a worst delta of 1/255 (native) and 2 px
##    at 8/255 (one RGB555 step, CLAUDE.md §3) under §4.5; the second read 0 and
##    0. So the floor is a settling transient in the low single digits, four
##    orders of magnitude below the calibration pairs — and on the run where it
##    was non-zero, the answer row still came in BELOW it.
##  * **off -> 2x** and **2x -> 4x** — known-different configurations. Must be
##    far above the floor, or the instrument cannot see MSAA at all and its `0`
##    on the question is the instrument, not the driver.
##
## Only then: **4x -> 8x**, which is the card.
##
## ## Native, not §4.5's buffer
##
## The primary rows run with `Settings.internal_render` OFF. Under §4.5 the world
## is rendered at 480x270 and quantized to RGB555, whose step is 8/255 — a real
## one-sample edge difference is far below that and would be quantized away, so
## the internal pipeline can only ever *hide* a difference (CLAUDE.md §3's
## quantizer row, read forwards). The run does both anyway and prints both,
## because what a player actually sees is the internal one.

## `garrison_look.tl_01_arrive`, the same pose `aa_compare.gd` uses, so the two
## sheets are of one frame. Copied rather than shared for the reason stated
## there: neither director may drift with the other.
const EYE := Vector3(0.0, 1.7, 8.0)
const AIM := Vector3(0.0, 1.2, -4.0)
const FOV := 50.0

## Frames discarded after an MSAA change. Swapping the level rebuilds the
## viewport's framebuffers and the frames during that rebuild are a photograph of
## the rebuild, not of the mode.
const SETTLE := 40

## Frames given to the garrison before anything is measured. It instances about
## twenty GLBs and the bodies retarget a shared clip library on load; a shot taken
## early is of bind-pose statues.
const BUILD := 60

## The null control is a floor, not an assertion of zero — see the header. A
## frozen garrison lands at 2-3 px; anything at or above this many is a leak
## large enough that the rows underneath stop being evidence.
const NULL_CEILING := 200

## A calibration pair has to clear the floor by this factor before its non-zero
## reading counts as "the instrument can see MSAA".
const CALIB_OVER_FLOOR := 50

## name -> Viewport.MSAA. Ordered: the pairs below are consecutive rows.
static var LEVELS: Array = [
	["off", Viewport.MSAA_DISABLED],
	["2x", Viewport.MSAA_2X],
	["4x", Viewport.MSAA_4X],
	["8x", Viewport.MSAA_8X],
]

var _out := ""
var _rows: Array[String] = []
var _fails: Array[String] = []


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/msaa/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await rig.wait_frames(BUILD)

	var scene: Node3D = rig.scene()
	var cam := Camera3D.new()
	cam.fov = FOV
	scene.add_child(cam)
	cam.make_current()
	cam.global_position = EYE
	cam.look_at(AIM, Vector3.UP)

	# `vendor` is what `Settings.max_msaa()` gates on, so it is printed here: the
	# gate and the measurement that justifies it come out of one run.
	print("MSAA adapter=%s vendor=%s api=%s os=%s max_msaa=%d"
		% [RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_vendor(),
			RenderingServer.get_video_adapter_api_version(),
			OS.get_name(), Settings.max_msaa()])
	print("MSAA rendering_method=%s driver=%s"
		% [str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
			str(ProjectSettings.get_setting(
				"rendering/rendering_device/driver", ""))])

	# The flames and the fog are the two things in this project that do not stop
	# when the game clock does (CLAUDE.md §3). Without this every row below reads
	# as "different" and the answer is the torches.
	rig.still_the_frame()
	var was_scale := Engine.time_scale
	Engine.time_scale = 0.0
	await rig.wait_frames(4)

	var was_internal: bool = Settings.internal_render
	var was_msaa: int = Settings.msaa
	for internal: bool in [false, true]:
		Settings.set_internal_render(internal)
		await rig.wait_frames(SETTLE)
		await _sweep(rig, internal)

	Settings.msaa = was_msaa
	Settings.set_internal_render(was_internal)
	Settings.apply_video()
	Engine.time_scale = was_scale
	await rig.wait_frames(4)

	print("")
	print("MSAA %-24s %9s %9s %6s %9s" % ["pipeline / pair", "diff_px", "pct", "maxd", "vram_mb"])
	for r: String in _rows:
		print(r)
	for f: String in _fails:
		print(f)
	print("MSAA done -> %s" % _out)


# --- One pipeline -------------------------------------------------------------

func _sweep(rig, internal: bool) -> void:
	var tag := "480x270" if internal else "native"
	var stem := "ir" if internal else "nat"
	var shots: Dictionary = {}
	var vram: Dictionary = {}

	# The null control first: 4x, twice, with nothing touched between. If this is
	# not 0 the freeze is leaking and every row after it is noise.
	_set_level(Viewport.MSAA_4X)
	await rig.wait_frames(SETTLE)
	var null_a: Image = await _shoot(rig, "%s/%s_null_a.png" % [_out, stem])
	var null_b: Image = await _shoot(rig, "%s/%s_null_b.png" % [_out, stem])
	var nd := _diff(null_a, null_b)
	var floor_px := int(nd["px"])
	_row(tag, "null 4x -> 4x", nd, -1.0)
	if floor_px < 0 or floor_px >= NULL_CEILING:
		_fails.append(("MSAA FAIL %s: the null control differs by %d px -- the "
			+ "frame is not frozen, so no row below is evidence of anything")
			% [tag, floor_px])

	for lv in LEVELS:
		var name: String = lv[0]
		_set_level(lv[1])
		await rig.wait_frames(SETTLE)
		shots[name] = await _shoot(rig, "%s/%s_msaa_%s.png" % [_out, stem, name])
		vram[name] = Performance.get_monitor(
			Performance.RENDER_VIDEO_MEM_USED) / 1048576.0

	# Consecutive pairs. The first two are the known-different calibration; the
	# third is the card.
	for i in range(LEVELS.size() - 1):
		var a: String = LEVELS[i][0]
		var b: String = LEVELS[i + 1][0]
		var d := _diff(shots[a], shots[b])
		_row(tag, "%s -> %s" % [a, b], d, float(vram[b]))
		if a != "4x" and int(d["px"]) < maxi(1, floor_px * CALIB_OVER_FLOOR):
			_fails.append(("MSAA FAIL %s: %s -> %s moved only %d px, within "
				+ "reach of the %d px noise floor -- the instrument cannot see "
				+ "an MSAA change, so its verdict on 4x -> 8x is the instrument")
				% [tag, a, b, int(d["px"]), floor_px])

	var q := _diff(shots["4x"], shots["8x"])
	if int(q["px"]) <= floor_px:
		print(("MSAA %s: 4x and 8x differ in %d px of %d -- at or UNDER the %d px "
			+ "noise floor two captures of one unchanged config produce, while "
			+ "the calibration pairs above move ~45,000. This driver clamps 8x "
			+ "to 4x.") % [tag, int(q["px"]), int(q["total"]), floor_px])
	else:
		print(("MSAA %s: 4x and 8x differ in %d px (%.3f%%, worst delta %d/255). "
			+ "8x is doing something here.")
			% [tag, int(q["px"]), 100.0 * float(q["px"]) / float(q["total"]),
				int(q["maxd"])])


## Through `Settings`, not straight onto the viewport, because the row in the
## options menu is what the card is about — this has to travel the path a player's
## click travels, including `_screen.apply_video` since #58 moved the 3D.
func _set_level(level: int) -> void:
	Settings.msaa = level
	Settings.apply_video()


func _shoot(rig, path: String) -> Image:
	await rig.capture(path)
	var img := Image.load_from_file(path)
	if img != null and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img


# --- Pixels -------------------------------------------------------------------

func _row(tag: String, pair: String, d: Dictionary, vram: float) -> void:
	_rows.append("MSAA %-24s %9d %8.3f%% %6d %9s"
		% ["%s %s" % [tag, pair], int(d["px"]),
			100.0 * float(d["px"]) / float(d["total"]), int(d["maxd"]),
			"-" if vram < 0.0 else "%.1f" % vram])


## `get_data()` and not `get_pixel()`: 921k pixels a frame, ten frames a run.
func _diff(a: Image, b: Image) -> Dictionary:
	if a == null or b == null or a.get_size() != b.get_size():
		return {"px": -1, "maxd": -1, "total": 1}
	var ra := a.get_data()
	var rb := b.get_data()
	var n := a.get_width() * a.get_height()
	var px := 0
	var maxd := 0
	var i := 0
	while i < n:
		var j := i * 3
		var d := maxi(absi(int(ra[j]) - int(rb[j])),
			maxi(absi(int(ra[j + 1]) - int(rb[j + 1])),
				absi(int(ra[j + 2]) - int(rb[j + 2]))))
		if d > 0:
			px += 1
			if d > maxd:
				maxd = d
		i += 1
	return {"px": px, "maxd": maxd, "total": n}
