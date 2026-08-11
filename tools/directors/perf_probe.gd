extends RefCounted
## What a frame actually costs, in the scene you point it at.
##
## Card #20. Nothing in this repo had ever measured a frame, so every rendering
## setting in `project.godot` -- an 8192 directional shadow map, soft shadow
## filter quality 4, MSAA -- was a guess nobody had priced. This is the
## instrument that stops the next tuning pass from being a second guess.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/perf_probe.gd --out=/tmp/perf/x.png \
##     --warmup=90
##
## Optional: --label=garrison  --samples=240  --settle=90
##           --ablate=shadows|lights  --scale3d=0.5  --internal=0
##           --stall=300  (a CONTROL, not a measurement -- see 3 below)
##
## **Do not read FPS off this, and do not add it back.** `project.godot` sets no
## `display/window/vsync` key, so the default is VSYNC_ENABLED and the window is
## pinned to the panel -- 120 Hz on this machine. A vsynced FPS counter reports
## the monitor, not the game, and it reports the same 120 whether a frame took
## 1 ms or 8. This director disables vsync for the length of the measurement and
## then puts it back, and even then it reports TIME, because a frame budget is a
## duration and "fps" is its reciprocal rounded until the interesting part is
## gone.
##
## **The numbers that matter are GPU and CPU render time**, from
## `RenderingServer.viewport_get_measured_render_time_*`. Those are the
## renderer's own timings for this viewport, in milliseconds.
##
## `Performance.TIME_PROCESS` is **not** the "script time only" the engine docs
## imply, and this director learned that the hard way -- see the comment at the
## sample site. It is the whole idle step, draw included, so it reads slightly
## LARGER than the frame rather than a fraction of it. It is printed as
## `idle_peak_ms` for that reason and it cannot tell you which half of the
## engine is the bottleneck. `TIME_PHYSICS_PROCESS` measures the honest thing --
## the physics step and nothing else -- but see #3 below: it is latched exactly
## the same way, so it is not a per-frame reading either.
##
## **Median and p95, never mean.** A mean hides the frame that hitches, and the
## hitch is the thing a stranger playing the demo actually feels. p95 is the
## budget; the median is the headroom.
##
## ---
##
## **THREE THINGS THE FIRST RUNS OF THIS DIRECTOR TAUGHT IT.** All three are
## here because a tuning pass that reads the output without knowing them will
## tune the wrong thing, confidently.
##
## **1. `gpu_ms` does not work on this machine.** It reported
## med = p95 = max = 0.00 across 240 samples on Metal -- the failure the header
## above already describes as "pinned by something", pinned at zero. Zero is
## the reading most likely to be mistaken for a free GPU, so the director now
## says so in words when the whole series is zero. `frame_ms`, added for this,
## is the wall-clock interval between two `process_frame`s and is the only
## series that contains the entire frame. Read it against `cpu_ms`: `cpu_ms` is
## the renderer's CPU half only, so `frame_ms` >> `cpu_ms` means the GPU is the
## wall.
##
## **2. THE MACHINE MUST BE EXCLUSIVELY YOURS OR THE NUMBER IS FICTION.** This
## repo runs several agents at once and each director opens a real window on
## the same GPU. Measured here: with four `godot` processes alive, `frame_ms`
## quantised to multiples of 33.3 ms -- 120 Hz divided four ways -- on BOTH a
## 713-draw-call garrison AND a 9-draw-call lookdev scene. Nine draw calls
## cannot cost 33 ms on an M2 Max; the floor was the other three windows. A
## scene-independent floor is the signature, so if two very different scenes
## report the same median, stop and count processes rather than believing it.
##
##     ps -Ao pid,comm | grep -i godot     # must be empty before you launch
##
## `pgrep -f godot` is NOT good enough for this check -- it matches the shell
## wrappers and this director's own command line, so it never reads zero.
##
## **3. THE TWO `Performance` TIME MONITORS ARE PEAK-PER-SECOND, LATCHED --
## THEY ARE NOT PER-FRAME VALUES AND THEY NEVER WERE.** This is card #50, and it
## is the one defect on this list that produced a specific alarming number that
## a tuning pass would have chased for a day.
##
## The report was `idle_step_ms p95 = max = 371.5 ms` on 240 samples, twice,
## while `frame_ms max` on the same runs was 19.6 and 23.6. A 371 ms step inside
## a 20 ms frame is not possible, so either the frame timer was blind to a
## visible demo hitch or the monitor was lying. **The monitor was lying**, and
## here is the mechanism, measured rather than reasoned:
##
##   * The engine refreshes `TIME_PROCESS` and `TIME_PHYSICS_PROCESS` **once per
##     second**, and what it stores is the **maximum** step seen during that
##     second -- not the last one, not an average. Between refreshes the monitor
##     hands back the identical latched float to every caller.
##   * So sampling it 240 times gets you **two or three real numbers repeated
##     ~100 times each**. Measured: `TIME_PROCESS changed at #0, #100, #172` on
##     a 240-sample run. A median, a p95 and a max over that are statistics of a
##     step function, and `p95 == max` merely means the last window happened to
##     be the worst one -- it does NOT mean "one outlier sample", which is what
##     card #50 opened by assuming.
##   * Worst of all, **window zero carries whatever happened before the
##     measurement started**: engine boot, scene instantiation, shader compiles,
##     the vsync mode change this director itself performs. Measured with
##     `--settle=0 --warmup=0`: `physics_ms p95 = max = 691.11 ms`, latched at
##     sample 0 and held for 56 samples, on a scene whose real physics step is
##     0.90 ms. That is #50's 371 ms, caught in the act.
##
## **`frame_ms` is not blind, and that was proved rather than assumed.**
## `--stall=300` blocks the main thread for 300 ms inside one sampled frame.
## `frame_ms` reported `max = 305.29` **at sample 120, the exact frame it was
## injected into**; `idle_step` reported 305.79 at sample **172** -- 52 samples
## and half a second late -- and then held it to the end of the run, manufacturing
## the `p95 == max` signature to order. Run it yourself before doubting a
## `frame_ms` number: the calibration is one flag.
##
## So this director now reports these two monitors as **`idle_peak_ms` and
## `physics_peak_ms`: one value per one-second window, worst step in that
## window, with the first window dropped** because it is inherited rather than
## measured. That is the same remedy as `shoot.gd`'s warmup, applied to a clock
## that warms up on its own schedule instead of on the frame counter's.
## `frame_ms` remains the only series that is genuinely per-frame, and it is the
## only one a budget may be quoted from.


const WARM_DISCARD := 30  ## Samples thrown away after vsync is cut; the first
                          ## frames off a mode change are not representative.

var _phase: Array[String] = []   ## Worst wall-clock frame of each pre-sample phase.


## Walk n frames, timing each one, and say which was the worst. The sampling loop
## below only watches the frames it samples, so a stall that lands in `settle` or
## in the post-vsync warm-up is invisible to it -- and that is exactly where #50's
## 371 ms turned out to live. Costs one `Time` read per frame.
func _walk(name: String, rig, n: int) -> void:
	var worst := 0.0
	var worst_i := -1
	var t := Time.get_ticks_usec()
	for i in n:
		await rig.wait_frames(1)
		var now := Time.get_ticks_usec()
		var ms := (now - t) / 1000.0
		t = now
		if ms > worst:
			worst = ms
			worst_i = i
	if worst_i >= 0:
		_phase.append("%s worst=%.1fms @frame %d/%d" % [name, worst, worst_i, n])


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/perf/x.png").get_base_dir()
	var label: String = rig.arg("label", "scene")
	var samples: int = maxi(int(rig.arg("samples", "240")), 60)
	var settle: int = maxi(int(rig.arg("settle", "90")), 0)

	# `--stall=300` -- CALIBRATE THE INSTRUMENT AGAINST A STALL IT ALREADY KNOWS
	# THE SIZE OF. Card #50 asked whether `frame_ms` can even see a 371 ms hitch,
	# and no amount of staring at a series that does not contain one can answer
	# that. This blocks the main thread for N ms inside one sampled frame; if
	# `frame_ms max` does not then read ~N at that sample index, the frame timer
	# is blind and every budget quoted off it is worthless. It is a control, not
	# a measurement: a run with `--stall` set is NOT a reading of the game.
	var stall_ms: int = int(rig.arg("stall", "0"))
	var stall_at: int = samples / 2

	# Let shaders finish compiling and the scene finish waking up. A frame
	# measured while a shader is still compiling is a measurement of the
	# compiler. CLAUDE.md 3's cold-import row is the same trap one layer down.
	await _walk("settle", rig, settle)

	# `--ablate=shadows|lights|none`. An ABLATION, not a setting: it turns one
	# thing off at runtime so the difference between two runs names the cost.
	# It exists because the two measurements that come free -- resolution and
	# draw calls -- had already answered as far as they can. The garrison reads
	# the same 16.4 / 16.6 / 16.7 ms at 640x360, 1280x720 and 1920x1080, so
	# NINE TIMES the fill costs 0.3 ms and the frame is not pixel-bound; but a
	# 9-draw-call scene runs at 6.40 ms against the garrison's 16.15, so it is
	# very much scene-bound. Geometry that is resolution-independent and paid
	# per draw call is what a shadow pass is, and this is how you find out
	# without guessing.
	#
	# Ablating is deliberately cruder than tuning: it answers "is this the wall"
	# before anyone argues about which value to pick. Do not leave a run's
	# verdict standing on an ablated frame -- it is not the game.
	var ablate: String = rig.arg("ablate", "none")
	if ablate != "none":
		var n := _ablate(rig.root, ablate)
		print("PERF   ABLATED %s on %d light(s) -- this frame is NOT the game" % [ablate, n])
		await rig.wait_frames(30)

	# `--scale3d=0.5` renders the 3D at half linear resolution and upscales.
	# This is the honest fill-rate lever and `--size` is NOT: a `--size` sweep
	# over 640x360 / 1280x720 / 1920x1080 came back flat at 16.40 / 16.59 /
	# 16.70 ms, which reads as "not pixel-bound" and was very nearly written
	# down as a finding -- except the 1280 and 1920 runs also reported the SAME
	# `vram_mb=1519.5`, and two different framebuffer sizes cannot cost the same
	# video memory. The window was not resizing. A flat line is what a broken
	# knob and a genuinely free axis both look like, so this one reports what it
	# actually got (below) rather than what it was asked for.
	var scale3d := float(rig.arg("scale3d", "0"))
	if scale3d > 0.0:
		rig.root.scaling_3d_scale = scale3d

	# **`--size` IS the resolution knob now, and `--win=` is gone.**
	#
	# THIS IS THE ONE THAT EXPLAINED EVERYTHING ELSE. `project.godot` has
	# `window/size/mode=2` -- WINDOW_MODE_MAXIMIZED -- so the window came up
	# filling the display no matter what `shoot.gd` assigned to `root.size`; and
	# `window/stretch/mode="canvas_items"` scales only the 2D, leaving the 3D to
	# render at the window's true backing resolution. On this Mac that measured
	# `win=6880x2756`: nineteen megapixels, twenty times the 1280x720 the whole
	# harness believed it was running at, every frame. So the flat 640/1280/1920
	# `--size` sweep was three runs of the identical 19 MP frame -- the tell was
	# that 1280 and 1920 also reported the SAME `vram_mb=1519.5`, and two
	# framebuffer sizes cannot cost the same video memory.
	#
	# `shoot.gd._size_the_window` resizes the real window to `--size` for every
	# director now (#35), so this director's local `--win=` had become a second
	# spelling of the same knob. Say `--size=1920x1080` and mean it. Quote a
	# budget number only against the resolution the demo will actually run at,
	# and read `win=` in the PERF line below to confirm you got it.
	if rig.arg("win", "") != "":
		print("PERF NOTE --win= is gone: --size resizes the real window now (#35)")

	# `--internal=0` prices the same scene with STYLEGUIDE §4.5 turned off, so a
	# tuning pass can put a number on the pipeline with the standard instrument
	# instead of trusting `internal_res.gd`'s paired run. Two perf_probe runs
	# minutes apart on this Mac are not a controlled comparison (see the header's
	# second lesson) -- for that, use `internal_res.gd`, which shoots both inside
	# one process.
	if rig.arg("internal", "") != "":
		Settings.set_internal_render(rig.arg("internal", "1") != "0")

	var vp: RID = rig.root.get_viewport_rid()
	# **THE WORLD IS NOT DRAWN BY THE ROOT VIEWPORT ANY MORE** (card #58,
	# STYLEGUIDE §4.5): with `Settings.internal_render` on, the root draws a
	# single textured quad and a 480x270 SubViewport draws the scene. Measure the
	# root alone and `cpu_ms` collapses to ~0.2 ms and the probe reports a free
	# renderer -- which is the exact "pinned at zero" failure the header above
	# already caught once on `gpu_ms`. Both viewports are measured and summed.
	var world_vp: RID = Settings._screen.viewport_rid() if Settings.internal_render else RID()
	var was_vsync: int = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(vp, true)
	if world_vp.is_valid():
		RenderingServer.viewport_set_measure_render_time(world_vp, true)
		print("PERF §4.5 on -- cpu_ms/gpu_ms are root + the %v internal buffer"
			% Settings._screen.internal_size())
	await _walk("warm", rig, WARM_DISCARD)

	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var wall: Array[float] = []
	# NOT per-frame series -- one entry per one-second latch window. See header 3.
	var proc: Array[float] = []
	var phys: Array[float] = []
	var win_at: Array[int] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	var objs: Array[float] = []

	var last_us := Time.get_ticks_usec()

	for i in samples:
		await rig.wait_frames(1)
		if stall_ms > 0 and i == stall_at:
			OS.delay_msec(stall_ms)
		# WALL CLOCK IS THE PRIMARY NUMBER, and it is here because the first run
		# of this director reported gpu_ms med=p95=max=0.00 across all 240
		# samples on Metal. The header already says a series that never varies
		# means the measurement is pinned by something; that one was pinned at
		# zero, which is the reading a tuning pass would have mistaken for a
		# free GPU.
		#
		# With vsync off (above) and no max_fps in project.godot, the interval
		# between two frames IS the cost of a frame -- the whole frame, both
		# halves of the engine, whichever one is the bottleneck. It cannot tell
		# you WHICH half, but cpu_ms next to it does: wall >> cpu means the GPU
		# is the wall. That is the classification a tuning pass needs, and it
		# survives a driver that will not hand over a timestamp.
		var now_us := Time.get_ticks_usec()
		wall.append((now_us - last_us) / 1000.0)
		last_us = now_us
		var g := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var c := RenderingServer.viewport_get_measured_render_time_cpu(vp)
		if world_vp.is_valid():
			g += RenderingServer.viewport_get_measured_render_time_gpu(world_vp)
			c += RenderingServer.viewport_get_measured_render_time_cpu(world_vp)
		gpu.append(g)
		cpu.append(c)
		# TIME_PROCESS IS NOT SCRIPT TIME, AND IT IS NOT THIS FRAME. Two separate
		# defects live in this one monitor and only the first was known before
		# card #50.
		#
		# **What it covers**: the entire main-loop idle step, with
		# `RenderingServer.draw()` called from inside it -- so it carries the draw
		# submission and the block waiting on present along with anything
		# `_process` did. The header was originally written believing the engine
		# docs' "script time" gloss; the measurement disagreed and the measurement
		# won. It therefore CANNOT separate a GPU-bound frame from one lost in
		# `_process`, which is the thing it was added to do.
		#
		# **When it covers it**: not now. It is refreshed once a second with the
		# WORST step of that second (header 3). The observation that used to sit
		# here -- "med=17.17 ms on frames whose whole wall clock was 16.25 ms" --
		# is fully explained by that and was never the paradox it reads as: a
		# per-second peak is *supposed* to exceed a median frame. It also kills
		# the consolation prize this comment used to offer, that idle_step plus
		# physics should account for all of frame_ms. Two peaks do not sum to a
		# frame. There is no honest subdivision of `frame_ms` on this list;
		# TIME_PHYSICS_PROCESS is honest about WHAT it measures and latched
		# exactly the same way about WHEN.
		#
		# ONE APPEND PER LATCH WINDOW, NOT PER FRAME. Appending these every frame
		# is what built card #50's 371 ms: the engine refreshes both monitors once
		# a second with the WORST step of that second and hands back the identical
		# float to every caller in between, so a per-frame array is one real number
		# repeated ~100 times and `p95 == max` is guaranteed the moment the last
		# window is the worst one. Recording the transitions instead makes the
		# sample count honest -- a 240-frame run yields two or three windows, and
		# the printout says so rather than implying 240 measurements.
		var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		# EITHER changing opens a new window: they are refreshed together, but a
		# second whose idle peak happens to repeat to the float would otherwise
		# desync the two arrays and mislabel every window after it.
		if proc.is_empty() or not is_equal_approx(p, proc[-1]) or not is_equal_approx(ph, phys[-1]):
			proc.append(p)
			phys.append(ph)
			win_at.append(i)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	# RENDER_TEXTURE_MEM_USED is not implemented on this build: it hands back -1
	# already widened through a uint64, so it arrives as +1.8e19 and prints as
	# 17592186043439.8 MB -- 17.6 PETABYTES of texture on a Mac. The sentinel is
	# POSITIVE, which is why the first guard here (`>= 0.0`) let it straight
	# through; the test has to be an absurdity ceiling, not a sign check. No
	# consumer GPU has a terabyte of anything, so 1e6 MB is a safe wall.
	var tex_raw := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var tex_mb := tex_raw / 1048576.0
	var tex := tex_mb if tex_mb >= 0.0 and tex_mb < 1.0e6 else NAN
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0

	RenderingServer.viewport_set_measure_render_time(vp, false)
	if world_vp.is_valid():
		RenderingServer.viewport_set_measure_render_time(world_vp, false)
	DisplayServer.window_set_vsync_mode(was_vsync)

	await rig.capture(out.path_join("perf_%s.png" % label))

	# Annotated, not inferred. `rig` is untyped, so `rig.root` is a Variant and
	# every call through it returns one -- `:=` here is a parse error, not a
	# runtime one, so the whole director fails to load and shoot.gd reports
	# "Nonexistent function 'new'" instead of anything about types.
	# CLAUDE.md 3, the untyped-indexing row, one layer along.
	var size: Vector2 = rig.root.get_visible_rect().size

	# One machine-readable line per run, so a tuning pass can diff two of them
	# without anybody re-reading prose. PERF is the grep handle.
	#
	# THREE sizes, because they disagree and the disagreement is the point. The
	# viewport's own rect is what `--size` sets; the OS window is what the
	# compositor actually gave us; and `scaling_3d_scale` decides how many
	# pixels the 3D pass really shades. A run that reports 640x360 while the
	# window is still 1280x720 has not measured a smaller frame, and that is
	# exactly the run whose flat timings almost became a finding here.
	var win: Vector2i = DisplayServer.window_get_size()
	print("PERF %s  vp=%dx%d  win=%dx%d  scale3d=%.2f  n=%d"
		% [label, int(size.x), int(size.y), win.x, win.y,
			rig.root.scaling_3d_scale, samples])
	if stall_ms > 0:
		print("PERF   CALIBRATION: %d ms blocked at sample %d -- this run is NOT the game"
			% [stall_ms, stall_at])
	# WHERE the worst frame landed, not just how big it was. A hitch at sample 0
	# is the scene still waking up; one in the middle of a static run is the game.
	# Card #50 was a whole investigation for want of this one integer.
	for p in _phase:
		print("PERF   PRE-SAMPLE  %s" % p)
	_row("frame_ms", wall)
	print("PERF     frame_ms max was sample %d of %d" % [_argmax(wall), samples])
	_row("gpu_ms", gpu)
	if _pct(gpu, 1.0) == 0.0:
		print("PERF   gpu_ms is UNAVAILABLE on this driver (all-zero, not free)."
			+ " Read frame_ms against cpu_ms instead.")
	_row("cpu_ms", cpu)
	_peak_row("idle_peak_ms", proc, win_at)
	_peak_row("physics_peak_ms", phys, win_at)
	_row("draw_calls", draws)
	_row("primitives", prims)
	_row("objects", objs)
	print("PERF %s  vram_mb=%.1f  texture_mb=%.1f  static_mb=%.1f  nodes=%d"
		% [label, vram, tex, mem, int(nodes)])

	# The budget line. 60 fps is 16.67 ms of wall clock for EVERYTHING, and the
	# GPU and the CPU overlap rather than add -- so the honest test is whichever
	# of the two is worse, at p95, against the frame. Stated as a verdict rather
	# than a number so a run that has gone over says so without anybody doing
	# arithmetic at 3am.
	# frame_ms is the verdict because it is the only series that contains the
	# whole frame. Taking max() of gpu and cpu was the original test and it was
	# wrong twice over: gpu reads 0 here, so the max was silently just cpu, and
	# cpu is only the renderer's own CPU half -- it does not include script,
	# physics, or the wait on the GPU. A budget built on it would have called a
	# 9 ms frame a 1 ms one.
	var worst := _pct(wall, 0.95)
	var verdict := "OK" if worst < 16.67 else ("TIGHT" if worst < 20.0 else "OVER")
	print("PERF %s  budget60=%s  worst_p95=%.2fms of 16.67ms  headroom=%.0f%%"
		% [label, verdict, worst, (1.0 - worst / 16.67) * 100.0])

	# WHETHER THE TAIL IS EVEN YOURS. p95 is the right thing to budget against --
	# the hitch is what a stranger playing the demo feels -- but on this machine
	# it is frequently not the game's. The control that showed it: a 9-draw-call
	# lookdev scene came back med 6.40 / p95 18.18 while the 715-draw-call
	# garrison beside it read med 16.15 / p95 17.51. The medians differ by 2.5x
	# in the direction you would expect and THE p95s CROSS. A tail that is worse
	# on the trivial scene is not made of scene cost; it is other agents' windows
	# and the OS.
	#
	# So a wide spread means "go and get a quiet machine", not "optimise
	# something". Only the median is safely attributable when this fires.
	var med := _pct(wall, 0.5)
	if med > 0.0 and worst / med > 2.0:
		print("PERF %s  TAIL NOT ATTRIBUTABLE: p95 is %.1fx the median."
			% [label, worst / med]
			+ " Budget on med=%.2fms; re-measure on a quiet machine" % med
			+ " before believing the p95.")


## Turn one renderer feature off across the whole live tree and say how many
## nodes it touched. `shadows` leaves the lights lighting and stops them casting;
## `lights` puts the scene in flat ambient. Returns the count so a run that
## ablated nothing says so rather than reporting a null result as a finding --
## an ablation that hit zero lights and "made no difference" is the most
## convincing wrong answer this director could produce.
func _ablate(node: Node, what: String) -> int:
	var n := 0
	for child in node.get_children():
		n += _ablate(child, what)
	if node is Light3D:
		var light := node as Light3D
		match what:
			"shadows":
				light.shadow_enabled = false
			"lights":
				light.visible = false
		n += 1
	return n


## Median, p95 and max for one series. Mean is deliberately absent -- see the
## header. A series that never varies still prints all three, which is itself
## information: it means the measurement is pinned by something.
func _row(name: String, v: Array[float]) -> void:
	print("PERF   %-12s med=%8.2f  p95=%8.2f  max=%8.2f"
		% [name, _pct(v, 0.5), _pct(v, 0.95), _pct(v, 1.0)])


## One row for a **latched peak-per-second** monitor. There is no median and no
## p95 here on purpose: a 240-frame run produces two or three of these, and
## quoting a percentile of three numbers is how card #50's `p95 = max = 371 ms`
## came to look like a finding instead of an artefact.
##
## **Window zero is dropped and printed struck out.** It holds the worst step of
## the second BEFORE the first sample -- engine boot, scene instantiation, shader
## compiles, and this director's own vsync mode change. Measured with
## `--settle=0`: 691.11 ms of "physics" on a scene whose real step is 0.90 ms.
## Every window is still printed with the sample it appeared at, because a reader
## who cannot see the step function will not believe the arithmetic behind it.
func _peak_row(name: String, v: Array[float], at: Array[int]) -> void:
	if v.size() < 2:
		print("PERF   %-14s inherited only -- the run was shorter than one latch"
			% name + " window, so there is no measured value. Raise --samples.")
		return
	var parts := PackedStringArray()
	for i in v.size():
		parts.append("%s#%d=%.2f" % ["INHERITED " if i == 0 else "", at[i], v[i]])
	print("PERF   %-14s worst=%8.2f  over %d one-second window(s)"
		% [name, _pct(v.slice(1), 1.0), v.size() - 1])
	print("PERF     %s" % "  ".join(parts))


func _argmax(v: Array[float]) -> int:
	var best := -1
	for i in v.size():
		if best < 0 or v[i] > v[best]:
			best = i
	return best


func _pct(v: Array[float], q: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	var i := clampi(int(round(q * (s.size() - 1))), 0, s.size() - 1)
	return s[i]
