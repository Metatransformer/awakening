extends RefCounted
## Card #66 — **does the volumetric fog's one-RGB555-step jitter READ on screen?**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/fog_crawl.gd \
##     --out=/tmp/fog/x.png --size=1280x720
##
## Optional: `--conds=ship_still,ship_walk` (default: all six, in the order
## below), `--frames=16`.
##
## ## What this is for, and why it is not a differ
##
## Card #62 found — with a differ — that Godot's volumetric fog is temporally
## reprojected with a per-frame jitter that never converges, and that §4.5's
## RGB555 buffer (step 8/255) quantizes that sub-LSB wobble onto the far side of
## a colour step: 2,468 px of 921,600 move by up to 9 on a still camera in a
## stopped room. **A differ cannot say whether a person sees that**, which is
## the whole of card #66, so this file's real output is not its table. It is a
## SEQUENCE of consecutive 1280x720 frames, at 1:1, that somebody looks at.
##
## `tools/fog_crawl.py` turns each sequence into the things an eye can judge:
## the per-pixel temporal range unamplified and amplified, and a magnified
## flipbook of the hottest window so consecutive frames can be compared without
## a microscope. The numbers this file prints are the cheap corroboration, not
## the finding.
##
## ## The six conditions, and why each one is here
##
##  * **ship_still** — the game exactly as it ships (§4.5 on, reprojection on),
##    world frozen, flames held. The ONLY thing that can move is the fog. This
##    is the sequence the card is about.
##  * **noreproj_still** — the same with
##    `volumetric_fog_temporal_reprojection_enabled = false`. The control that
##    turns "something moves" into "the fog moves": #62 measured this pair at
##    2,584 px against 0.
##  * **native_still** — `internal_render` off, reprojection on. The same engine
##    jitter without the quantizer, where it is 1/255 and nothing sees it. It is
##    what the artefact would look like if §4.5 were the thing at fault, and it
##    is not.
##  * **play_still** — the world running, flames live, hero idle. What a player
##    standing in the room actually sees, fog jitter among everything else that
##    legitimately moves. If the crawl is invisible HERE it is invisible.
##  * **ship_walk** / **noreproj_walk** — the hero holding forward. A crawl you
##    only see standing still matters less than one that survives motion, and
##    the pair says how much of a walking frame's churn the fog is responsible
##    for. (Expect: almost none — a moving camera re-quantizes the whole buffer
##    every frame — but "expect" is not "looked".)
##
## The world is frozen with `Engine.time_scale = 0` for the three `_still`
## isolations for the same reason `frame_repro.gd` does it: a condition that
## leaves the hero's idle breathing in cannot attribute anything to the air.
## `play_still` is the control on that freeze.

## Frames per condition. Enough to see a period if the jitter has one; short
## enough that six conditions fit inside one `timeout 400`.
const FRAMES := 16

## One RGB555 step, in the 0..255 bytes a PNG hands back. §4.5's quantizer moves
## in these and nothing smaller, so a delta below this cannot be the artefact.
const STEP := 8

## Frames given to the floor before anything is measured. The dungeon generates
## its layout in `_ready` and the hero's clip library retargets on load.
const BUILD := 90

## Frames discarded after `internal_render` is flipped. Turning §4.5 on rebuilds
## a render target and re-registers a camera; the frames during that are a
## photograph of the rebuild, not of the pipeline.
const SETTLE := 40

## Frames discarded after any change to the world or the fog. The volumetric
## buffer is itself an accumulator — switch reprojection and it takes a dozen
## frames to reach whatever it is going to sit at. `frame_repro.gd` learned this
## the expensive way and its comment is worth reading.
const SETTLE_WORLD := 60

## Diff amplification for the printed heat map. A one-step wobble on dim
## masonry is invisible in a straight subtraction image.
const HEAT_GAIN := 12

const ORDER: Array[String] = ["ship_still", "noreproj_still", "native_still",
	"play_still", "ship_walk", "noreproj_walk"]

## name -> [internal_render, temporal_reprojection, world_live, walking]
const SPEC: Dictionary = {
	"ship_still": [true, true, false, false],
	"noreproj_still": [true, false, false, false],
	"native_still": [false, true, false, false],
	"play_still": [true, true, true, false],
	"ship_walk": [true, true, true, true],
	"noreproj_walk": [true, false, true, true],
}

var _out := ""
var _frames := FRAMES
var _rows: Array[String] = []
var _torches: Array[Node] = []
var _lively: Array[float] = []
var _env: Environment = null
var _hero: Node3D = null
var _home := Transform3D.IDENTITY


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/fog/x.png").get_base_dir()
	_frames = maxi(4, int(rig.arg("frames", str(FRAMES))))
	DirAccess.make_dir_recursive_absolute(_out)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var want: Array[String] = ORDER.duplicate()
	# Annotated, not inferred: `rig` is untyped (every director takes it that
	# way), so `arg()` hands back a Variant and `:=` cannot infer a String from
	# it. CLAUDE.md §3's "Cannot infer the type of X" row, one level out.
	var picked: String = rig.arg("conds", "")
	if picked != "":
		want.clear()
		for c: String in picked.split(",", false):
			if SPEC.has(c.strip_edges()):
				want.append(c.strip_edges())
			else:
				print("FOG FAIL unknown condition '%s'" % c)

	var vp: Viewport = rig.root
	print("FOG window=%dx%d internal_buffer=%v frames=%d"
		% [int(vp.get_visible_rect().size.x), int(vp.get_visible_rect().size.y),
			Settings._screen.internal_size(), _frames])

	await rig.wait_frames(BUILD)
	_torches = _every(rig.scene(), func(n: Node) -> bool: return n is KitTorch)
	# The authored flicker per sconce, not a constant — `BossArena.douse` and the
	# Bellwake's turn both leave torches at a fraction of nominal, and restoring
	# `KitStyle.FIRE_FLICKER` over them would be lighting fires this director put
	# out. Straight from `frame_repro.gd`, same reason.
	for t in _torches:
		_lively.append(float(t.get(&"flicker")))
	var we := _every(rig.scene(), func(n: Node) -> bool: return n is WorldEnvironment)
	if not we.is_empty():
		_env = (we[0] as WorldEnvironment).environment
	if _env == null or not _env.volumetric_fog_enabled:
		print("FOG FAIL -- no WorldEnvironment with volumetric fog in this scene; "
			+ "there is nothing here to look at")
		return
	print("FOG %d sconce(s); volumetric fog density %.4f, length %.0f m"
		% [_torches.size(), _env.volumetric_fog_density, _env.volumetric_fog_length])

	# Every condition starts from the same spot. Without this the two walking
	# conditions photograph two different corridors — the hero from `ship_walk`
	# is eight metres further on when `noreproj_walk` begins — and the pair that
	# exists to price the remedy is comparing rooms instead of renderers.
	var heroes := _every(rig.scene(), func(n: Node) -> bool: return n is Hero)
	if not heroes.is_empty():
		_hero = heroes[0] as Node3D
		_home = _hero.global_transform

	var was: bool = Settings.internal_render
	for name: String in want:
		await _shoot_condition(rig, name)

	# Put the process back the way it found it, in case a later beat is ever
	# appended to this file.
	Settings.set_internal_render(was)
	_apply_world(true, true)
	Engine.time_scale = 1.0
	await rig.wait_frames(4)

	print("")
	print("FOG %-16s %8s %8s %8s %6s" % ["condition", "diff_px", ">=step", "2step", "maxd"])
	for r: String in _rows:
		print(r)
	print("")
	print("FOG frames -> %s   (now run tools/fog_crawl.py %s)" % [_out, _out])


# --- One condition ------------------------------------------------------------

func _shoot_condition(rig, name: String) -> void:
	var spec: Array = SPEC[name]
	var internal: bool = spec[0]
	var reproj: bool = spec[1]
	var live: bool = spec[2]
	var walking: bool = spec[3]

	var dir := "%s/%s" % [_out, name]
	DirAccess.make_dir_recursive_absolute(dir)

	Engine.time_scale = 1.0
	if _hero != null:
		_hero.global_transform = _home
	Settings.set_internal_render(internal)
	await rig.wait_frames(SETTLE)
	_apply_world(live, reproj)
	await rig.wait_frames(SETTLE_WORLD)
	if not live:
		Engine.time_scale = 0.0
		await rig.wait_frames(4)

	if walking:
		# Fire and forget ON PURPOSE. `hold` is a coroutine that presses now and
		# releases after N process frames; awaiting it here would finish the walk
		# before the first capture and photograph a hero standing still. Both it
		# and `capture` advance one rendered frame at a time, so the release
		# lands after the last frame is in the bag.
		rig.hold(["move_up"], _frames + 12)
		await rig.wait_frames(6)

	var paths := PackedStringArray()
	for i in _frames:
		var p := "%s/f%02d.png" % [dir, i]
		await rig.capture(p)
		paths.append(p)

	Engine.time_scale = 1.0
	await rig.wait_frames(2)
	_report(name, paths)


## The cheap corroboration: consecutive frames 0 and 1, counted the way #62
## counted its pair. The real answer is the sequence on disk and `fog_crawl.py`.
func _report(name: String, paths: PackedStringArray) -> void:
	if paths.size() < 2:
		print("FOG FAIL %s -- fewer than two frames" % name)
		return
	var a := _load(paths[0])
	var b := _load(paths[1])
	if a == null or b == null or a.get_size() != b.get_size():
		print("FOG FAIL %s -- could not re-read the pair" % name)
		return
	var w := a.get_width()
	var h := a.get_height()
	var ra := a.get_data()
	var rb := b.get_data()
	var n := w * h
	var heat := PackedByteArray()
	heat.resize(n * 3)
	var px := 0
	var step := 0
	var two := 0
	var maxd := 0
	var i := 0
	while i < n:
		var j := i * 3
		var d := maxi(absi(int(ra[j]) - int(rb[j])),
			maxi(absi(int(ra[j + 1]) - int(rb[j + 1])),
				absi(int(ra[j + 2]) - int(rb[j + 2]))))
		if d > 0:
			px += 1
			maxd = maxi(maxd, d)
			if d >= STEP:
				step += 1
			if d >= STEP * 2:
				two += 1
			var v := mini(255, d * HEAT_GAIN)
			heat[j] = v
			heat[j + 1] = v
			heat[j + 2] = v
		i += 1
	Image.create_from_data(w, h, false, Image.FORMAT_RGB8, heat).save_png(
		"%s/%s/adjacent_heat.png" % [_out, name])
	_rows.append("FOG %-16s %8d %8d %8d %6d" % [name, px, step, two, maxd])
	print("FOG %s -- frames 0/1 differ on %d px of %d (%.2f%%); %d at or over one "
		% [name, px, n, 100.0 * float(px) / float(n), step]
		+ "RGB555 step, %d over two; worst delta %d/255" % [two, maxd])


# --- Fixture ------------------------------------------------------------------

func _apply_world(live: bool, reproj: bool) -> void:
	for i in _torches.size():
		var torch := _torches[i] as Node3D
		torch.set(&"flicker", _lively[i] if live else 0.0)
		if not live:
			# The setter runs `_apply_light`, which is the only thing that puts
			# the nominal energy back after `_process` has spent the last N
			# frames multiplying it.
			torch.set(&"light_energy", torch.get(&"light_energy"))
	if _env != null:
		_env.volumetric_fog_temporal_reprojection_enabled = reproj


func _load(path: String) -> Image:
	var img := Image.load_from_file(path)
	if img != null and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img


func _every(root: Node, test: Callable) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if test.call(n):
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out
