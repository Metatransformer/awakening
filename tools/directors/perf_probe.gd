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
## renderer's own timings for this viewport, in milliseconds. `Performance`'s
## TIME_PROCESS / TIME_PHYSICS_PROCESS are script time only and will happily
## read 0.3 ms on a frame the GPU spent 14 ms on -- which is exactly the reading
## that would send a tuning pass after the wrong half of the engine.
##
## **Median and p95, never mean.** A mean hides the frame that hitches, and the
## hitch is the thing a stranger playing the demo actually feels. p95 is the
## budget; the median is the headroom.


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

	var vp: RID = rig.root.get_viewport_rid()
	var was_vsync: int = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await rig.wait_frames(WARM_DISCARD)

	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	var objs: Array[float] = []

	for i in samples:
		await rig.wait_frames(1)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var tex := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0

	RenderingServer.viewport_set_measure_render_time(vp, false)
	DisplayServer.window_set_vsync_mode(was_vsync)

	await rig.capture(out.path_join("perf_%s.png" % label))

	var size := rig.root.get_visible_rect().size

	# One machine-readable line per run, so a tuning pass can diff two of them
	# without anybody re-reading prose. PERF is the grep handle.
	print("PERF %s  %dx%d  n=%d" % [label, int(size.x), int(size.y), samples])
	_row("gpu_ms", gpu)
	_row("cpu_ms", cpu)
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
	var worst := maxf(_pct(gpu, 0.95), _pct(cpu, 0.95))
	var verdict := "OK" if worst < 16.67 else ("TIGHT" if worst < 20.0 else "OVER")
	print("PERF %s  budget60=%s  worst_p95=%.2fms of 16.67ms  headroom=%.0f%%"
		% [label, verdict, worst, (1.0 - worst / 16.67) * 100.0])


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
