extends RefCounted
## Card #62 — **is a frame of a frozen scene reproducible?** Three directors
## subtract one capture from another and call what is left "ink"
## (`world_labels.gd`, `echo_plates.gd`), and `enemy_bars.gd` classifies colour
## inside a single frame; every one of them is worth exactly what the answer to
## this question is worth.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/frame_repro.gd \
##     --out=/tmp/repro/x.png --size=1280x720
##
## Optional: `--gap=15` (extra frame count between the two captures of a pair).
##
## ## The measurement
##
## The world is frozen with `Engine.time_scale = 0` — the same freeze the three
## directors use — and then photographed twice. Whatever differs between those
## two PNGs is, by definition, something that is not on the game clock.
##
## Four conditions, each under `Settings.internal_render` off and on, which is
## what makes the answer separable rather than merely alarming:
##
##  * **quiet** — flames held still AND `volumetric_fog_enabled = false`.
##  * **fog** — flames still, the dungeon's air back. Godot's volumetric fog is
##    temporally reprojected with a per-frame jitter, so this is the one that
##    says whether the ENGINE is deterministic here, with nothing of the game's
##    own moving.
##  * **fog_notemporal** — the same air with
##    `volumetric_fog_temporal_reprojection_enabled = false`. The pair `fog` /
##    `fog_notemporal` is what turns "the fog does it" into a named mechanism
##    with a one-line remedy a director can apply.
##  * **live** — the room exactly as the game ships it. `KitTorch._process`
##    swings `light_energy` off `Time.get_ticks_msec()`, a WALL clock the freeze
##    does not stop (card #45).
##  * **dark** — every sconce hidden. The card's "with torches in frame and with
##    none", and a control on `live`.
##  * **running** — `live` with the world NOT frozen, which is the control on the
##    fix rather than on the bug: a fire that is reproducible because it stopped
##    burning is not a fix. The heat map for this one has torch pools in it.
##
## and every count is split **HUD versus world**, because the card's three
## consequences differ precisely there. The split is not a guessed rectangle: the
## pose is photographed once more with `Hud.visible = false` **in the quiet
## condition**, and the pixels that move when the overlay goes away ARE the
## pixels the overlay paints. Taking that mask anywhere else was the first
## version of this file and it was worthless — with the fog jittering, `A` and
## `bare` differ over 86% of the frame and the "HUD" mask is just the noise.
##
## A rectangle around the health bar would have been wrong differently: it counts
## the gaps between the ticks as HUD, and a damage number out over the room as
## world.

## Extra frames between the two captures of a pair, beyond the one frame
## `capture()` itself costs. 0 is "consecutive frames", the strictest form of the
## question; the longer gap is there because a slow drift (a 0.5 Hz breath, an
## ember loop) shows nothing over one frame.
const GAPS: Array[int] = [0, 15, 60]

## Frames discarded after `internal_render` is flipped. Turning §4.5 on rebuilds
## a render target and re-registers a camera; the frames during that are a
## photograph of the rebuild.
const SETTLE := 30

## Frames discarded after any change to the WORLD (flames, fog) before the freeze.
## Hiding 41 lights is a large lighting change and the renderer takes it over
## several frames — SSAO, the glow chain and the fog volume all reconverge. The
## first version of this file waited 4 and measured its own transient: "torches
## hidden" came out NOISIER than torches live, which is nonsense, and it was the
## settle and not the scene.
const SETTLE_WORLD := 90

## Frames given to the floor before anything is measured. The dungeon generates
## its layout in `_ready` and the hero's clip library retargets on load.
const BUILD := 60

## `echo_plates.gd` and `world_labels.gd` both call a difference real at
## `absf(a - b) > 0.02` in 0..1 colour. That is 5.1 in the 0..255 bytes this file
## reads, so the `>=ink` column is directly comparable with what those two would
## have counted as ink.
const INK := 5

## Diff amplification in the heat map. A 16% swing on dim masonry is a delta of 2
## or 3 out of 255 and is invisible in a straight subtraction image.
const HEAT_GAIN := 12

var _out := ""
var _rows: Array[String] = []
var _torches: Array[Node] = []
var _lively: Array[float] = []
var _env: Environment = null
var _fog_was := false


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/repro/x.png").get_base_dir()
	var gaps: Array[int] = GAPS.duplicate()
	var gap := int(rig.arg("gap", "0"))
	if not gaps.has(gap):
		gaps.append(gap)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var vp: Viewport = rig.root
	print("REPRO window=%dx%d internal=%v hud=%s"
		% [int(vp.get_visible_rect().size.x), int(vp.get_visible_rect().size.y),
			Settings._screen.internal_size(), str(Hud.visible)])

	await rig.wait_frames(BUILD)
	_torches = _every(rig.scene(), func(n: Node) -> bool: return n is KitTorch)
	# The authored flicker per sconce, not a constant: `BossArena.douse` and the
	# Bellwake's turn both leave torches at a fraction of nominal, and a "live"
	# restore that wrote `KitStyle.FIRE_FLICKER` over them would be lighting fires
	# this director had put out.
	for t in _torches:
		_lively.append(float(t.get(&"flicker")))
	var we := _every(rig.scene(), func(n: Node) -> bool: return n is WorldEnvironment)
	if not we.is_empty():
		_env = (we[0] as WorldEnvironment).environment
		_fog_was = _env.volumetric_fog_enabled
	print("REPRO %d torch(es); volumetric fog %s"
		% [_torches.size(), "on" if _fog_was else "off"])

	var was: bool = Settings.internal_render
	for internal: bool in [false, true]:
		Settings.set_internal_render(internal)
		await rig.wait_frames(SETTLE)
		# quiet FIRST and not by accident: its pair is where the HUD mask comes
		# from, and the mask is only honest in a world that is otherwise still.
		var mask := {}
		for mode: String in ["quiet", "fog_notemporal", "fog", "live", "dark",
				"running"]:
			_apply(mode)
			await rig.wait_frames(SETTLE_WORLD)
			mask = await _pair(rig, internal, mode, gaps, mask)
	_apply("live")
	Settings.set_internal_render(was)
	await rig.wait_frames(4)

	print("")
	print("REPRO %-28s %8s %8s %8s %8s %5s"
		% ["pipeline / world / gap", "diff_px", "hud_px", "world_px", ">=ink", "maxd"])
	for r: String in _rows:
		print(r)
	print("")
	print("REPRO done -> %s" % _out)


# --- One condition ------------------------------------------------------------

## Freeze, photograph twice at each gap, and (on the first condition of a
## pipeline) photograph once more with the HUD away so the counts can be split.
## Hands the mask back so the later conditions reuse it.
func _pair(rig, internal: bool, mode: String, gaps: Array[int],
		mask: Dictionary) -> Dictionary:
	var tag := "%s/%s" % ["480x270" if internal else "native", mode]
	var stem := "%s_%s" % ["ir" if internal else "nat", mode]
	var prev := Engine.time_scale
	# `running` is the one condition that deliberately does NOT stop the world.
	Engine.time_scale = prev if mode == "running" else 0.0
	await rig.wait_frames(4)

	var a_path := "%s/%s_a.png" % [_out, stem]
	var a: Image = await _shoot(rig, a_path)
	if a == null:
		print("REPRO FAIL %s: could not re-read %s" % [tag, a_path])
		Engine.time_scale = prev
		return mask

	if mask.is_empty():
		var hud_was: bool = Hud.visible
		Hud.visible = false
		await rig.wait_frames(2)
		var bare_path := "%s/%s_nohud.png" % [_out, stem]
		var bare: Image = await _shoot(rig, bare_path)
		Hud.visible = hud_was
		await rig.wait_frames(2)
		mask = _mask(a, bare)
		DirAccess.remove_absolute(bare_path)
		print("REPRO %s -- the overlay paints %d px (%.1f%% of the frame)"
			% [tag, int(mask["px"]),
				100.0 * float(mask["px"]) / float(a.get_width() * a.get_height())])

	for g: int in gaps:
		if g > 0:
			await rig.wait_frames(g)
		var b_path := "%s/%s_b%d.png" % [_out, stem, g]
		var b: Image = await _shoot(rig, b_path)
		if b == null or b.get_size() != a.get_size():
			print("REPRO FAIL %s gap %d: sizes differ" % [tag, g])
			continue
		var d := _diff(a, b, mask["bits"])
		_rows.append("REPRO %-28s %8d %8d %8d %8d %5d"
			% ["%s g=%d" % [tag, g], d["px"], d["hud"], d["world"], d["ink"],
				d["maxd"]])
		print(("REPRO %s g=%d -- %d px of %d differ (%.2f%%): %d of the overlay's "
			+ "%d, %d in the world; %d at or over ink (%d/255); worst delta %d; "
			+ "world bbox %s")
			% [tag, g, d["px"], d["total"],
				100.0 * float(d["px"]) / float(d["total"]),
				d["hud"], int(mask["px"]), d["world"], d["ink"], INK, d["maxd"],
				str(d["bbox"])])
		(d["heat"] as Image).save_png("%s/%s_heat_g%d.png" % [_out, stem, g])
		# Only the first gap's B frame is worth keeping; the rest are
		# near-identical PNGs nobody opens.
		if g != gaps[0]:
			DirAccess.remove_absolute(b_path)
	Engine.time_scale = prev
	await rig.wait_frames(2)
	return mask


func _shoot(rig, path: String) -> Image:
	await rig.capture(path)
	var img := Image.load_from_file(path)
	if img != null and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img


# --- Pixels -------------------------------------------------------------------

## Which pixels does the overlay paint? Every byte where the HUD-on frame differs
## at all from the HUD-off one.
##
## It undercounts by exactly the pixels where the HUD happens to paint the colour
## already underneath it, and that is harmless here: such a pixel cannot be a HUD
## pixel that VARIES, which is the only thing the mask is used to decide.
func _mask(a: Image, bare: Image) -> Dictionary:
	var ra := a.get_data()
	var n := ra.size() / 3
	var bits := PackedByteArray()
	bits.resize(n)
	if bare == null or bare.get_size() != a.get_size():
		return {"bits": bits, "px": 0}
	var rb := bare.get_data()
	var px := 0
	var i := 0
	while i < n:
		var j := i * 3
		if ra[j] != rb[j] or ra[j + 1] != rb[j + 1] or ra[j + 2] != rb[j + 2]:
			bits[i] = 1
			px += 1
		i += 1
	return {"bits": bits, "px": px}


## Count where two frames differ, split by the mask, with a heat map.
##
## Through `get_data()` and not `get_pixel()`: this is 921k pixels a frame and
## a dozen frames a run, and `room_range.gd` already paid for that lesson.
func _diff(a: Image, b: Image, bits: PackedByteArray) -> Dictionary:
	var w := a.get_width()
	var h := a.get_height()
	var ra := a.get_data()
	var rb := b.get_data()
	var n := w * h
	var heat := PackedByteArray()
	heat.resize(n * 3)
	var px := 0
	var hud := 0
	var world := 0
	var ink := 0
	var maxd := 0
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	var i := 0
	while i < n:
		var j := i * 3
		var d0 := absi(int(ra[j]) - int(rb[j]))
		var d1 := absi(int(ra[j + 1]) - int(rb[j + 1]))
		var d2 := absi(int(ra[j + 2]) - int(rb[j + 2]))
		var d := maxi(d0, maxi(d1, d2))
		if d > 0:
			px += 1
			if d > maxd:
				maxd = d
			if d >= INK:
				ink += 1
			var v := mini(255, d * HEAT_GAIN)
			if bits[i] == 1:
				# Overlay variance in red, world variance in white: the two
				# answers this card separates should not need a legend.
				hud += 1
				heat[j] = v
			else:
				world += 1
				heat[j] = v
				heat[j + 1] = v
				heat[j + 2] = v
				var x := i % w
				var y := i / w
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
		i += 1
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, heat)
	var bbox := Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1) if x1 >= 0 else Rect2i()
	return {"px": px, "hud": hud, "world": world, "ink": ink, "maxd": maxd,
		"total": n, "bbox": bbox, "heat": img}


# --- Fixture ------------------------------------------------------------------

func _apply(mode: String) -> void:
	var still := mode != "live" and mode != "running"
	var shown := mode != "dark"
	for i in _torches.size():
		var torch := _torches[i] as Node3D
		torch.visible = shown
		torch.set(&"flicker", 0.0 if still else _lively[i])
		if still:
			# The setter runs `_apply_light`, which is the only thing that puts
			# the nominal energy back after `_process` has spent the last N
			# frames multiplying it.
			torch.set(&"light_energy", torch.get(&"light_energy"))
	if _env != null:
		_env.volumetric_fog_enabled = _fog_was and mode != "quiet"
		_env.volumetric_fog_temporal_reprojection_enabled = mode != "fog_notemporal"


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
