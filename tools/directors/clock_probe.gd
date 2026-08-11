extends RefCounted
## **The game clock against the wall clock.** The one director in here with no
## pixels, and it exists because a number in a comment that nobody can re-derive
## is the kind of claim this repo has been burned by.
##
## Godot only lets one rendered frame catch up
## `physics/common/max_physics_steps_per_frame` physics steps (default 8), so
## below ~7.5 fps the simulation falls behind real time and never gets it back.
## That ratio is what makes a director's deadline mean different things on a busy
## machine and an idle one — issue #33 — and `shoot.gd`'s `until` is denominated
## in game seconds because of what this prints.
##
## Measured on this Mac, garrison, load ~10:
##
##   (no throttle)   wall=1.03 s phys=1.03 s (1.00x) fps=28
##   --max-fps=5     wall=1.00 s phys=0.67 s (0.67x) fps=5
##
##   timeout 200 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/clock_probe.gd --out=/tmp/clk/x.png \
##     --warmup=60 --max-fps=5
##
## `phys` is counted off `Engine.get_physics_frames()` rather than off accumulated
## `delta`, because the physics frame IS the tick the world moves on and it is the
## one the clamp starves. `proc` is the accumulated process delta beside it: the
## two agree, which is worth knowing, because it means `hold_seconds` and `until`
## are measuring the same thing in different units.

func run(rig) -> void:
	var step: float = rig.root.get_physics_process_delta_time()
	print("CLOCK step=%.4f s max_physics_steps=%s ceiling=%.1f fps"
		% [step, ProjectSettings.get_setting(
			"physics/common/max_physics_steps_per_frame", 8),
			1.0 / (step * float(ProjectSettings.get_setting(
				"physics/common/max_physics_steps_per_frame", 8)))])
	for slice in 8:
		var w0 := Time.get_ticks_msec()
		var p0 := Engine.get_physics_frames()
		var f0 := Engine.get_frames_drawn()
		var proc := 0.0
		while Time.get_ticks_msec() - w0 < 1000:
			await rig.process_frame
			proc += rig.root.get_process_delta_time()
		var wall := float(Time.get_ticks_msec() - w0) / 1000.0
		var phys := float(Engine.get_physics_frames() - p0) * step
		print("CLOCK wall=%.2f s phys=%.2f s (%.2fx) proc=%.2f s fps=%d"
			% [wall, phys, phys / wall, proc, Engine.get_frames_drawn() - f0])
	print("CLOCK DONE")
