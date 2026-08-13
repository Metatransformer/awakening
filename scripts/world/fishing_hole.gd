class_name FishingHole
extends Interactable
## A bounded fishing interaction and every piece of presentation belonging to it.
## Campaign authority remains on `Game`; this node owns the tactile attempt,
## pond landmark, and a small third-person overlay.

const MAT_PATH := preload("res://assets/materials/mat_flagstone_sunlit.tres")
const MAT_STONE := preload("res://assets/materials/mat_wall_sunlit.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")

const TARGET_NEAR: StringName = &"near"
const TARGET_DEEP: StringName = &"deep"
const ATTEMPT_MINUTES: float = 10.0
const CAST_CHARGE_TIME: float = 1.1
const WAIT_TIME: float = 1.25
const BITE_WINDOW: float = 0.9
const RESULT_TIME: float = 1.8
const NEAR_RUN_TIME: float = 1.45
const DEEP_RUN_TIME: float = 0.95

enum State { IDLE, CHOOSE, CASTING, WAITING, BITE, HOOKED, RESULT }

var _state: State = State.IDLE
var _target: StringName = TARGET_NEAR
var _state_elapsed: float = 0.0
var _cast_charge: float = 0.0
var _tension_value: float = 0.0
var _line_value: float = 1.0
var _run_direction: int = -1
var _run_elapsed: float = 0.0
var _run_index: int = 0
var _result_text: String = ""
var _mode_active: bool = false
var _clock_was_running: bool = true

## Release-gated edges are deliberate. The interact press that Prompt used to
## open this mode is still down when our first `_process` runs, and polling it as
## a fresh edge would choose and cast in the same press.
var _interact_armed: bool = false
var _interact_was_down: bool = false
var _cancel_armed: bool = false
var _cancel_was_down: bool = false
var _left_was_down: bool = false
var _right_was_down: bool = false

var _water: MeshInstance3D
var _near_fish: Node3D
var _deep_fish: Node3D
var _splash: Node3D
var _creel_meals: Array[Node3D] = []

var _overlay: CanvasLayer
var _overlay_root: Control
var _title_label: Label
var _detail_label: Label
var _status_label: Label
var _controls_label: Label
var _cast_row: VBoxContainer
var _tension_row: VBoxContainer
var _line_row: VBoxContainer
var _cast_gauge: ProgressBar
var _tension_gauge: ProgressBar
var _line_gauge: ProgressBar


func _ready() -> void:
	prompt = "FISH"
	radius = 2.5
	super()
	_build_landmark()
	_build_overlay()
	Game.garrison_changed.connect(_repaint_creel)
	_repaint_creel()


func _exit_tree() -> void:
	if _mode_active:
		Prompt.unblock(self)
		Clock.running = _clock_was_running
		_mode_active = false
	super()


func _process(delta: float) -> void:
	if not _mode_active:
		return

	var interact_down: bool = Input.is_action_pressed(&"interact")
	var cancel_down: bool = Input.is_action_pressed(&"ui_cancel") \
		or Input.is_action_pressed(&"pause")
	var left_down: bool = Input.is_action_pressed(&"move_left")
	var right_down: bool = Input.is_action_pressed(&"move_right")

	if not interact_down:
		_interact_armed = true
	if not cancel_down:
		_cancel_armed = true
	var interact_pressed: bool = interact_down and not _interact_was_down \
		and _interact_armed
	var interact_released: bool = not interact_down and _interact_was_down
	var cancel_pressed: bool = cancel_down and not _cancel_was_down and _cancel_armed
	var left_pressed: bool = left_down and not _left_was_down
	var right_pressed: bool = right_down and not _right_was_down

	if cancel_pressed:
		_cancel_armed = false
		cancel()
		_update_input_history(interact_down, cancel_down, left_down, right_down)
		return

	_state_elapsed += delta
	match _state:
		State.CHOOSE:
			_tick_choose(left_pressed, right_pressed, interact_pressed)
		State.CASTING:
			_tick_casting(delta, interact_down, interact_released)
		State.WAITING:
			if _state_elapsed >= WAIT_TIME:
				_transition(State.BITE)
		State.BITE:
			if interact_pressed:
				_interact_armed = false
				_transition(State.HOOKED)
			elif _state_elapsed >= BITE_WINDOW:
				_finish_failure("THE BITE SLIPPED AWAY.")
		State.HOOKED:
			_tick_hooked(delta, interact_down, left_down, right_down)
		State.RESULT:
			if _state_elapsed >= RESULT_TIME:
				_transition(State.IDLE)
		State.IDLE:
			pass

	_animate_fish()
	_refresh_overlay()
	_update_input_history(interact_down, cancel_down, left_down, right_down)


func activate(_by: Node3D) -> void:
	if _mode_active:
		return
	var first_target: StringName = TARGET_NEAR
	if not Game.can_bank_fish(1, Clock.day):
		first_target = TARGET_DEEP
	_start_mode(first_target)


## Director seam: enter through the same capacity gate as ordinary activation,
## but begin with the authored target already selected.
func begin_for_test(target: StringName) -> bool:
	if _mode_active or not _valid_target(target):
		return false
	return _start_mode(target)


func state_name() -> StringName:
	match _state:
		State.IDLE:
			return &"idle"
		State.CHOOSE:
			return &"choose"
		State.CASTING:
			return &"casting"
		State.WAITING:
			return &"waiting"
		State.BITE:
			return &"bite"
		State.HOOKED:
			return &"hooked"
		State.RESULT:
			return &"result"
	return &"idle"


func target_name() -> StringName:
	return _target


func tension() -> float:
	return _tension_value


func line_progress() -> float:
	return _line_value


## Only waiting may be advanced by this probe. It cannot manufacture a cast or
## hook and therefore cannot bypass the transaction-bearing outcome states.
func debug_force_bite() -> void:
	if _state == State.WAITING:
		_transition(State.BITE)


## Deterministic proof still lands through Game's real all-or-nothing bank and
## the same ten-minute outcome transaction as live play.
func debug_land_catch() -> void:
	if _state == State.HOOKED:
		_land_catch()


func cancel() -> void:
	if _state != State.IDLE:
		_transition(State.IDLE)


func _start_mode(target: StringName) -> bool:
	if Game.fish_space() <= 0:
		Bus.request_message.emit("THE CREEL IS FULL. SUPPER MUST USE THE RESERVE.")
		return false
	if Game.fishing_remaining_today(Clock.day) <= 0:
		Bus.request_message.emit("TODAY'S WATER IS SPENT.")
		return false
	if not Game.can_bank_fish(_yield_for(target), Clock.day):
		Bus.request_message.emit("THAT WATER CANNOT FIT TODAY'S RESERVE.")
		return false

	_target = target
	_mode_active = true
	_clock_was_running = Clock.running
	# The world clock normally advances in real time. Holding it here is what
	# makes a cancelled attempt cost zero and a resolved one cost exactly ten
	# civil minutes rather than ten plus however long the player deliberated.
	Clock.running = false
	Prompt.block(self)
	_disarm_input()
	_overlay.visible = true
	_transition(State.CHOOSE)
	return true


func _transition(next: State) -> void:
	if _state == next:
		return
	_state = next
	_state_elapsed = 0.0
	match next:
		State.IDLE:
			_exit_mode()
		State.CHOOSE:
			_cast_charge = 0.0
			_tension_value = 0.0
			_line_value = 1.0
		State.CASTING:
			_cast_charge = 0.0
		State.WAITING:
			_set_selected_fish_visible(true)
		State.BITE:
			_set_selected_fish_visible(true)
		State.HOOKED:
			_tension_value = 0.22 if _target == TARGET_NEAR else 0.30
			_line_value = 1.0
			_run_index = 0
			_run_direction = -1
			_run_elapsed = 0.0
		State.RESULT:
			pass
	_refresh_overlay()


func _exit_mode() -> void:
	if not _mode_active:
		return
	_mode_active = false
	Prompt.unblock(self)
	Clock.running = _clock_was_running
	_overlay.visible = false
	_result_text = ""
	_cast_charge = 0.0
	_tension_value = 0.0
	_line_value = 1.0
	_splash.visible = false
	_near_fish.visible = true
	_deep_fish.visible = true
	_disarm_input()


func _tick_choose(left_pressed: bool, right_pressed: bool,
		interact_pressed: bool) -> void:
	if left_pressed and Game.can_bank_fish(1, Clock.day):
		_target = TARGET_NEAR
	elif right_pressed and Game.can_bank_fish(2, Clock.day):
		_target = TARGET_DEEP
	if interact_pressed and Game.can_bank_fish(_yield_for(_target), Clock.day):
		_interact_armed = false
		_transition(State.CASTING)


func _tick_casting(delta: float, interact_down: bool,
		interact_released: bool) -> void:
	if interact_down:
		_cast_charge = minf(1.0, _cast_charge + delta / CAST_CHARGE_TIME)
	if interact_released:
		# Charge controls presentation and anticipation; even a short cast reaches
		# the chosen authored water so a fumbled release does not waste the attempt.
		_transition(State.WAITING)


func _tick_hooked(delta: float, reeling: bool, left_down: bool,
		right_down: bool) -> void:
	var run_time: float = NEAR_RUN_TIME if _target == TARGET_NEAR else DEEP_RUN_TIME
	_run_elapsed += delta
	if _run_elapsed >= run_time:
		_run_elapsed = fmod(_run_elapsed, run_time)
		_run_index += 1
		_run_direction = -1 if _run_index % 2 == 0 else 1

	var steer: int = (1 if right_down else 0) - (1 if left_down else 0)
	var correcting: bool = steer == -_run_direction
	var following: bool = steer == _run_direction
	if not reeling:
		_tension_value -= delta * (0.31 if _target == TARGET_NEAR else 0.25)
	elif correcting:
		_tension_value -= delta * (0.24 if _target == TARGET_NEAR else 0.18)
		var reel_rate: float = 0.27 if _target == TARGET_NEAR else 0.17
		_line_value -= delta * reel_rate
	elif following:
		_tension_value += delta * (0.31 if _target == TARGET_NEAR else 0.43)
	else:
		_tension_value += delta * (0.17 if _target == TARGET_NEAR else 0.27)

	_tension_value = clampf(_tension_value, 0.0, 1.0)
	_line_value = clampf(_line_value, 0.0, 1.0)
	if _tension_value >= 1.0:
		_finish_failure("THE LINE SNAPPED.")
	elif _line_value <= 0.0:
		_land_catch()


func _land_catch() -> void:
	var units: int = _yield_for(_target)
	var banked: int = Game.bank_fish(units, Clock.day)
	var reserve_after_bank: int = Game.fish_stock
	Clock.advance_hours(ATTEMPT_MINUTES / 60.0)
	if banked == units:
		_result_text = "LANDED %d FISH · RESERVE %d / %d" \
			% [banked, reserve_after_bank, Game.FISH_CAP]
	else:
		# Capacity is reserved when the mode starts, so this can only describe an
		# external state change. It still resolves as the attempt the player made.
		_result_text = "THE CATCH COULD NOT ENTER THE CREEL."
	_transition(State.RESULT)


func _finish_failure(text: String) -> void:
	Clock.advance_hours(ATTEMPT_MINUTES / 60.0)
	_result_text = text + " · 10 MINUTES PASS"
	_transition(State.RESULT)


func _yield_for(target: StringName) -> int:
	return 2 if target == TARGET_DEEP else 1


func _valid_target(target: StringName) -> bool:
	return target == TARGET_NEAR or target == TARGET_DEEP


func _disarm_input() -> void:
	_interact_armed = false
	_cancel_armed = false
	_interact_was_down = Input.is_action_pressed(&"interact")
	_cancel_was_down = Input.is_action_pressed(&"ui_cancel") \
		or Input.is_action_pressed(&"pause")
	_left_was_down = Input.is_action_pressed(&"move_left")
	_right_was_down = Input.is_action_pressed(&"move_right")


func _update_input_history(interact_down: bool, cancel_down: bool,
		left_down: bool, right_down: bool) -> void:
	_interact_was_down = interact_down
	_cancel_was_down = cancel_down
	_left_was_down = left_down
	_right_was_down = right_down


func _animate_fish() -> void:
	var selected: Node3D = _deep_fish if _target == TARGET_DEEP else _near_fish
	var base: Vector3 = Vector3(0.62, 0.03, -2.82) if _target == TARGET_DEEP \
		else Vector3(-0.62, 0.08, -1.72)
	var travel: float = sin(_state_elapsed * (3.8 if _state == State.HOOKED else 2.2))
	if _state == State.HOOKED:
		travel = float(_run_direction) * 0.78 + sin(_state_elapsed * 7.0) * 0.18
	selected.position = base + Vector3(travel, sin(_state_elapsed * 5.0) * 0.05, 0.0)
	selected.rotation.y = -float(_run_direction) * 0.24 if _state == State.HOOKED \
		else sin(_state_elapsed * 2.2) * 0.18

	var cue_visible: bool = _state == State.WAITING or _state == State.BITE \
		or _state == State.HOOKED
	_splash.visible = cue_visible
	if cue_visible:
		_splash.position = selected.position + Vector3(0.0, 0.12, 0.0)
		var pulse: float = 0.82 + sin(_state_elapsed * 9.0) * 0.18
		_splash.scale = Vector3.ONE * pulse
	_water.position.y = 0.30 + sin(Time.get_ticks_msec() * 0.0018) * 0.012


func _set_selected_fish_visible(value: bool) -> void:
	if _target == TARGET_NEAR:
		_near_fish.visible = value
	else:
		_deep_fish.visible = value


func _repaint_creel() -> void:
	for i: int in _creel_meals.size():
		_creel_meals[i].visible = i < Game.fish_stock
	if _mode_active:
		_refresh_overlay()


# --- Overlay ----------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = &"FishingOverlay"
	_overlay.layer = 60
	_overlay.visible = false
	add_child(_overlay)

	_overlay_root = Control.new()
	_overlay_root.name = &"Root"
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.theme = UITheme.theme()
	_overlay.add_child(_overlay_root)
	_fit_overlay()
	get_viewport().size_changed.connect(_fit_overlay)

	var frame := PanelContainer.new()
	frame.name = &"Frame"
	_overlay_root.add_child(frame)
	frame.anchor_left = 0.22
	frame.anchor_top = 0.67
	frame.anchor_right = 0.78
	frame.anchor_bottom = 0.965
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID)

	var pad := MarginContainer.new()
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	for side: String in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	frame.add_child(pad)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	pad.add_child(stack)

	_title_label = _label(stack, &"Title", "FISHING HOLE", UITheme.TYPE_H2,
		UITheme.ACCENT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label = _label(stack, &"Detail", "", UITheme.TYPE_PARAGRAPH_1,
		UITheme.TEXT)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label = _label(stack, &"Status", "", UITheme.TYPE_PARAGRAPH_2,
		UITheme.TEXT_DIM)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_cast_row = _gauge_row(stack, &"CastRow", "CAST", Pal.CYAN)
	_cast_gauge = _cast_row.get_node("Gauge") as ProgressBar
	_tension_row = _gauge_row(stack, &"TensionRow", "TENSION", Pal.VITAL)
	_tension_gauge = _tension_row.get_node("Gauge") as ProgressBar
	_line_row = _gauge_row(stack, &"LineRow", "LINE TO LAND", Pal.MOSS)
	_line_gauge = _line_row.get_node("Gauge") as ProgressBar

	_controls_label = _label(stack, &"Controls", "", UITheme.TYPE_CAPTION,
		UITheme.TEXT_DIM)
	_controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _fit_overlay() -> void:
	if _overlay_root == null:
		return
	_overlay_root.position = Vector2.ZERO
	_overlay_root.size = get_viewport().get_visible_rect().size


func _label(parent: Node, node_name: StringName, text: String,
		style: Dictionary, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(label, style, color)
	parent.add_child(label)
	return label


func _gauge_row(parent: VBoxContainer, row_name: StringName, caption: String,
		color: Color) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 1)
	parent.add_child(row)
	var cap := _label(row, &"Caption", caption, UITheme.TYPE_CAPTION,
		UITheme.TEXT_DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gauge := ProgressBar.new()
	gauge.name = &"Gauge"
	gauge.custom_minimum_size.y = 10.0
	gauge.max_value = 1.0
	gauge.show_percentage = false
	var boxes: Array = UITheme.bar_styleboxes(color)
	gauge.add_theme_stylebox_override("background", boxes[0] as StyleBox)
	gauge.add_theme_stylebox_override("fill", boxes[1] as StyleBox)
	row.add_child(gauge)
	return row


func _refresh_overlay() -> void:
	if _overlay == null or not _mode_active:
		return
	var reserve: String = "RESERVE %d / %d · TODAY %d LEFT" % [Game.fish_stock,
		Game.FISH_CAP, Game.fishing_remaining_today(Clock.day)]
	_cast_row.visible = _state == State.CASTING
	_tension_row.visible = _state == State.HOOKED
	_line_row.visible = _state == State.HOOKED
	_cast_gauge.value = _cast_charge
	_tension_gauge.value = _tension_value
	# The remaining line falls toward zero in play; invert it so the landing bar
	# visibly fills toward the promised catch.
	_line_gauge.value = 1.0 - _line_value

	match _state:
		State.CHOOSE:
			var near_ready: String = "READY" if Game.can_bank_fish(1, Clock.day) \
				else "UNAVAILABLE"
			var deep_ready: String = "READY" if Game.can_bank_fish(2, Clock.day) \
				else "UNAVAILABLE"
			_title_label.text = "CHOOSE WATER · %s" % _target.to_upper()
			_detail_label.text = ("%s NEAR · 1 FISH · FORGIVING · %s\n"
				+ "%s DEEP · 2 FISH · HARDER / LONGER · %s") % [
				">" if _target == TARGET_NEAR else " ", near_ready,
				">" if _target == TARGET_DEEP else " ", deep_ready]
			_status_label.text = reserve
			_controls_label.text = "MOVE LEFT / RIGHT: TARGET · INTERACT: CAST · CANCEL: LEAVE"
		State.CASTING:
			_title_label.text = "CASTING · %s WATER" % _target.to_upper()
			_detail_label.text = "%d FISH · %s" % [_yield_for(_target),
				"DEEP, STRONG RUNS" if _target == TARGET_DEEP else "NEAR, FORGIVING RUNS"]
			_status_label.text = reserve
			_controls_label.text = "HOLD INTERACT TO CHARGE · RELEASE TO CAST"
		State.WAITING:
			_title_label.text = "LINE SET · WATCH THE WATER"
			_detail_label.text = "%s WATER · THE FISH IS CIRCLING" % _target.to_upper()
			_status_label.text = reserve
			_controls_label.text = "WAIT FOR THE SPLASH · CANCEL: LEAVE"
		State.BITE:
			_title_label.text = "BITE — HOOK NOW"
			_detail_label.text = "THE FLOAT IS UNDER · %.1f SECONDS" \
				% maxf(0.0, BITE_WINDOW - _state_elapsed)
			_status_label.text = reserve
			_controls_label.text = "PRESS INTERACT"
		State.HOOKED:
			var run_word: String = "LEFT" if _run_direction < 0 else "RIGHT"
			var steer_word: String = "RIGHT" if _run_direction < 0 else "LEFT"
			_title_label.text = "FISH RUNS %s · STEER %s" % [run_word, steer_word]
			_detail_label.text = "%s WATER · %d FISH ON THE LINE" % [
				_target.to_upper(), _yield_for(_target)]
			_status_label.text = "TENSION %d%% · LANDED %d%%" % [
				roundi(_tension_value * 100.0), roundi((1.0 - _line_value) * 100.0)]
			_controls_label.text = "HOLD INTERACT TO REEL · STEER AGAINST THE RUN · RELEASE TO EASE"
		State.RESULT:
			_title_label.text = "ATTEMPT COMPLETE"
			_detail_label.text = _result_text
			_status_label.text = "RESERVE %d / %d" % [Game.fish_stock, Game.FISH_CAP]
			_controls_label.text = "CANCEL: CLOSE"
		State.IDLE:
			pass


# --- Landmark ---------------------------------------------------------------

func _build_landmark() -> void:
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.10, 0.42, 0.50, 1.0)
	water_material.metallic = 0.08
	water_material.roughness = 0.18
	# The spring sits beneath a tall cliff and must remain legible in its shadow.
	# A restrained self-lit teal reads as reflected sky without becoming neon.
	water_material.emission_enabled = true
	water_material.emission = Color(0.03, 0.20, 0.23)
	water_material.emission_energy_multiplier = 0.55
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var pool := Node3D.new()
	pool.name = &"SpringFedPool"
	add_child(pool)
	_water = MeshInstance3D.new()
	_water.name = &"Water"
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 1.85
	water_mesh.bottom_radius = 1.75
	water_mesh.height = 0.14
	water_mesh.radial_segments = 18
	_water.mesh = water_mesh
	_water.material_override = water_material
	_water.position = Vector3(0.0, 0.30, -2.25)
	_water.scale = Vector3(1.0, 1.0, 1.15)
	pool.add_child(_water)

	# An irregular primitive rim reads as an excavated spring rather than a blue
	# disc laid on the path. The near gap is the dock's clean approach.
	for i: int in 14:
		var angle: float = float(i) * TAU / 14.0
		if sin(angle) > 0.72:
			continue
		var at := Vector3(cos(angle) * 1.84, 0.22,
			-2.25 + sin(angle) * 2.12)
		_box(pool, StringName("Rim%02d" % i), MAT_STONE,
			Vector3(0.62, 0.38, 0.46),
			Transform3D(Basis(Vector3.UP, -angle), at), false)

	var spring := Node3D.new()
	spring.name = &"SpringHead"
	spring.position = Vector3(0.0, 0.0, -4.05)
	pool.add_child(spring)
	for row: Vector4 in [Vector4(-0.68, 0.23, 0.0, 0.48),
			Vector4(0.0, 0.34, -0.08, 0.66), Vector4(0.70, 0.21, 0.05, 0.45)]:
		_cylinder(spring, &"SpringStone", MAT_STONE, row.w, row.w * 0.85,
			Transform3D(Basis(Vector3.UP, row.x * 0.12),
				Vector3(row.x, row.y, row.z)), false, 7)

	_build_dock()
	_build_rod_rack()
	_build_creel()
	_build_fish()


func _build_dock() -> void:
	var dock := Node3D.new()
	dock.name = &"Dock"
	dock.position.y = 0.22
	add_child(dock)
	_box(dock, &"DockBody", MAT_WOOD, Vector3(1.65, 0.18, 2.25),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.19, -0.72)), true)
	for z: float in [0.30, -0.10, -0.50, -0.90, -1.30, -1.70]:
		_box(dock, &"Plank", MAT_WOOD, Vector3(1.80, 0.08, 0.34),
			Transform3D(Basis.IDENTITY, Vector3(0.0, 0.32, z)), false)
	for x: float in [-0.72, 0.72]:
		for z: float in [-0.10, -1.62]:
			_cylinder(dock, &"Post", MAT_WOOD, 0.12, 1.25,
				Transform3D(Basis.IDENTITY, Vector3(x, 0.20, z)), true, 8)


func _build_rod_rack() -> void:
	var rack := Node3D.new()
	rack.name = &"RodRack"
	rack.position = Vector3(-1.55, 0.0, -0.35)
	add_child(rack)
	for x: float in [-0.38, 0.38]:
		_cylinder(rack, &"RackPost", MAT_WOOD, 0.09, 1.25,
			Transform3D(Basis.IDENTITY, Vector3(x, 0.62, 0.0)), false, 8)
	_box(rack, &"RackBar", MAT_WOOD, Vector3(1.05, 0.10, 0.10),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.82, 0.0)), false)
	for x: float in [-0.24, 0.24]:
		var rod_basis := Basis(Vector3.RIGHT, deg_to_rad(-12.0))
		_cylinder(rack, &"Rod", MAT_WOOD, 0.035, 2.15,
			Transform3D(rod_basis, Vector3(x, 1.28, -0.10)), false, 7)
		_cylinder(rack, &"IronGrip", MAT_IRON, 0.055, 0.42,
			Transform3D(rod_basis, Vector3(x, 0.36, 0.10)), false, 7)


func _build_creel() -> void:
	var creel := Node3D.new()
	creel.name = &"Creel"
	creel.position = Vector3(1.55, 0.0, -0.35)
	add_child(creel)
	_box(creel, &"Basket", MAT_WOOD, Vector3(1.05, 0.58, 0.72),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.31, 0.0)), false)
	_box(creel, &"IronBand", MAT_IRON, Vector3(1.12, 0.08, 0.78),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.38, 0.0)), false)
	for i: int in Game.FISH_CAP:
		var meal := Node3D.new()
		meal.name = StringName("StoredFish%d" % (i + 1))
		meal.position = Vector3(-0.28 + float(i) * 0.28, 0.70, 0.0)
		creel.add_child(meal)
		_creel_meals.append(meal)
		_fish_shape(meal, MAT_IRON, 0.28)


func _build_fish() -> void:
	_near_fish = Node3D.new()
	_near_fish.name = &"NearFish"
	_near_fish.position = Vector3(-0.62, 0.08, -1.72)
	add_child(_near_fish)
	_fish_shape(_near_fish, MAT_IRON, 0.42)

	_deep_fish = Node3D.new()
	_deep_fish.name = &"DeepFish"
	_deep_fish.position = Vector3(0.62, 0.03, -2.82)
	add_child(_deep_fish)
	_fish_shape(_deep_fish, MAT_IRON, 0.56)

	_splash = Node3D.new()
	_splash.name = &"SplashCue"
	_splash.visible = false
	add_child(_splash)
	for i: int in 8:
		var angle: float = float(i) * TAU / 8.0
		_sphere(_splash, &"Drop", MAT_PATH, 0.055,
			Transform3D(Basis.IDENTITY,
				Vector3(cos(angle) * 0.42, 0.0, sin(angle) * 0.42)))


func _fish_shape(parent: Node3D, material: Material, scale_factor: float) -> void:
	var body := MeshInstance3D.new()
	body.name = &"Body"
	var mesh := SphereMesh.new()
	mesh.radius = scale_factor
	mesh.height = scale_factor * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	body.mesh = mesh
	body.scale = Vector3(1.45, 0.48, 0.62)
	body.material_override = material
	parent.add_child(body)
	_box(parent, &"Tail", material,
		Vector3(scale_factor * 0.55, scale_factor * 0.10, scale_factor * 0.55),
		Transform3D(Basis(Vector3.UP, PI * 0.25),
			Vector3(-scale_factor * 1.12, 0.0, 0.0)), false)


func _box(parent: Node3D, node_name: StringName, material: Material,
		size: Vector3, local_transform: Transform3D, solid: bool) -> Node3D:
	var holder: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = K.L_WORLD
		body.collision_mask = 0
		holder = body
	else:
		holder = Node3D.new()
	holder.name = node_name
	holder.transform = local_transform
	parent.add_child(holder)
	var instance := MeshInstance3D.new()
	instance.name = &"Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	holder.add_child(instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		holder.add_child(collision)
	return holder


func _cylinder(parent: Node3D, node_name: StringName, material: Material,
		radius: float, height: float, local_transform: Transform3D, solid: bool,
		sides: int) -> Node3D:
	var holder: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = K.L_WORLD
		body.collision_mask = 0
		holder = body
	else:
		holder = Node3D.new()
	holder.name = node_name
	holder.transform = local_transform
	parent.add_child(holder)
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = material
	holder.add_child(instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		holder.add_child(collision)
	return holder


func _sphere(parent: Node3D, node_name: StringName, material: Material,
		radius: float, local_transform: Transform3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.transform = local_transform
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
