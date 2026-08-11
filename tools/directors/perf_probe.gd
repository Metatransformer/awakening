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
## `idle_step_ms` for that reason and it cannot tell you which half of the
## engine is the bottleneck. `TIME_PHYSICS_PROCESS` is honest.
##
## **Median and p95, never mean.** A mean hides the frame that hitches, and the
## hitch is the thing a stranger playing the demo actually feels. p95 is the
## budget; the median is the headroom.
##
## ---
##
## **TWO THINGS THE FIRST RUNS OF THIS DIRECTOR TAUGHT IT.** Both are here
## because a tuning pass that reads the output without knowing them will tune
## the wrong thing, confidently.
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


const WARM_DISCARD := 30  ## Samples thrown away after vsync is cut; the first
                          ## frames off a mode change are not representative.


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/perf/x.png").get_base_dir()
	var label: String = rig.arg("label", "scene")
	var samples: int = maxi(int(rig.arg("samples", "240")), 60)
	var settle: int = maxi(int(rig.arg("settle", "90")), 0)

	# Let shaders finish compiling and the scene finish waking up. A frame
	# measured while a shader is still compiling is a measurement of the
	# compiler. CLAUDE.md 3's cold-import row is the same trap one layer down.
	await rig.wait_frames(settle)

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

	# `--win=1280x720` makes the OS window ACTUALLY that size, which `--size`
	# does not and cannot.
	#
	# THIS IS THE ONE THAT EXPLAINS EVERYTHING ELSE. `project.godot` has
	# `window/size/mode=2` -- WINDOW_MODE_MAXIMIZED -- so the window comes up
	# filling the display no matter what `shoot.gd` assigns to `root.size`; and
	# `window/stretch/mode="canvas_items"` scales only the 2D, leaving the 3D to
	# render at the window's true backing resolution. On this Mac that measured
	# `win=6880x2756`: nineteen megapixels, twenty times the 1280x720 the whole
	# harness believes it is running at, every frame.
	#
	# So `--size` was never a resolution knob, the flat 640/1280/1920 sweep was
	# three runs of the identical 19 MP frame, and the garrison's 16 ms is the
	# cost of a resolution no demo will ever use. Set this to what the demo
	# window will be before quoting a budget number at anyone.
	#
	# It is also why every proof frame this repo has judged is a ~20x
	# supersampled render downscaled by Lanczos in `shoot.gd`. Aliasing, thin
	# geometry and HUD type all look better in a proof than they will on screen.
	# That is a separate problem and a real one; it is not this director's to
	# fix, and it should not be fixed under a deadline while other sessions are
	# mid-run against the same harness.
	var win_arg: String = rig.arg("win", "")
	if win_arg != "":
		var wh := win_arg.split("x")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		await rig.wait_frames(30)

	var vp: RID = rig.root.get_viewport_rid()
	var was_vsync: int = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await rig.wait_frames(WARM_DISCARD)

	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var wall: Array[float] = []
	var proc: Array[float] = []
	var phys: Array[float] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	var objs: Array[float] = []

	var last_us := Time.get_ticks_usec()

	for i in samples:
		await rig.wait_frames(1)
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
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		# TIME_PROCESS IS NOT SCRIPT TIME. It is named `idle_step_ms` here because
		# the first run that sampled it reported med=17.17 ms on frames whose
		# whole wall clock was 16.25 ms, and a number cannot be a part of a frame
		# it is bigger than. The monitor covers the entire main-loop idle step,
		# and `RenderingServer.draw()` is called from inside that step -- so it
		# carries the draw submission and the block waiting on present along with
		# anything `_process` did. The header above was written believing the
		# engine docs' "script time" gloss; the measurement disagreed, and the
		# measurement wins.
		#
		# So it CANNOT separate a GPU-bound frame from one lost in `_process` --
		# the thing it was added to do. What it is still good for is closing the
		# books: idle_step + physics should account for essentially all of
		# frame_ms, and if it does not, time is going somewhere neither monitor
		# can see. TIME_PHYSICS_PROCESS is genuinely the physics step and is the
		# one honest subdivision on this list.
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
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
	_row("frame_ms", wall)
	_row("gpu_ms", gpu)
	if _pct(gpu, 1.0) == 0.0:
		print("PERF   gpu_ms is UNAVAILABLE on this driver (all-zero, not free)."
			+ " Read frame_ms against cpu_ms instead.")
	_row("cpu_ms", cpu)
	_row("idle_step_ms", proc)
	_row("physics_ms", phys)
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


func _pct(v: Array[float], q: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	var i := clampi(int(round(q * (s.size() - 1))), 0, s.size() - 1)
	return s[i]
