class_name FishingHole
extends Interactable
## A bounded fishing interaction and every piece of presentation belonging to it.
## Campaign authority remains on `Game`; this node owns the tactile attempt,
## pond landmark, and a small third-person overlay.

const MAT_PATH := preload("res://assets/materials/mat_floor.tres")
const MAT_STONE := preload("res://assets/materials/mat_wall_sunlit.tres")
const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const MAT_IRON := preload("res://assets/materials/mat_iron.tres")
const FEEDBACK_DRAW := preload("res://scripts/ui/fishing_feedback_draw.gd")

const ATTEMPT_MINUTES: float = 10.0
const CAST_CHARGE_TIME: float = 1.1
const WAIT_TIME: float = 1.25
const RESULT_TIME: float = 1.8
const REEL_SFX_GAP: float = 0.72
const STRAIN_SFX_GAP: float = 0.58

enum State { IDLE, CASTING, WAITING, BITE, HOOKED, RESULT }

@export_range(1, 4) var spot_level: int = 1

## Composite exteriors may own a larger pond and banks. In that case this node
## still supplies the dock, fishing gear, fish, ripples, and full interaction.
@export var build_pool_visuals: bool = true

var _state: State = State.IDLE
var _state_elapsed: float = 0.0
var _cast_charge: float = 0.0
var _tension_value: float = 0.0
var _line_value: float = 1.0
var _run_direction: int = -1
var _run_elapsed: float = 0.0
var _run_index: int = 0
var _result_success: bool = false
var _failure_result: StringName = &""
var _current_fish_id: StringName = &""
var _caught_fish_id: StringName = &""
var _forced_next_fish_id: StringName = &""
var _current_tuning: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _actual_steering: int = 0
var _reeling: bool = false
var _reel_sfx_armed: bool = false
var _last_reel_sfx_msec: int = -1000000
var _last_strain_sfx_msec: int = -1000000
var _mode_active: bool = false
var _clock_was_running: bool = true
var _attempt_spent: bool = false

## Release-gated edges are deliberate. The interact press that Prompt used to
## open this mode is still down when our first `_process` runs, and polling it as
## a fresh edge would skip the cast's held-input beat.
var _interact_armed: bool = false
var _interact_was_down: bool = false
var _cancel_armed: bool = false
var _cancel_was_down: bool = false

var _water: MeshInstance3D
var _near_fish: Node3D
var _deep_fish: Node3D
var _splash: Node3D
var _ripple_root: Node3D
var _ripple_rings: Array[MeshInstance3D] = []
var _ripple_materials: Array[StandardMaterial3D] = []
var _rack_rods: Array[Node3D] = []
var _creel_meals: Array[Node3D] = []

var _overlay: CanvasLayer
var _overlay_root: Control
var _feedback: FishingFeedbackDraw
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
	_rng.randomize()
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
	if cancel_pressed:
		_cancel_armed = false
		cancel()
		_update_input_history(interact_down, cancel_down)
		return

	_state_elapsed += delta
	match _state:
		State.CASTING:
			_tick_casting(delta, interact_down, interact_released)
		State.WAITING:
			if _state_elapsed >= WAIT_TIME:
				_transition(State.BITE)
		State.BITE:
			if _state_elapsed >= current_hook_window():
				_finish_failure("THE BITE SLIPPED AWAY.", &"escaped")
			elif interact_pressed:
				_interact_armed = false
				_transition(State.HOOKED)
		State.HOOKED:
			_tick_hooked(delta, interact_down, left_down, right_down)
		State.RESULT:
			if _state_elapsed >= RESULT_TIME:
				_transition(State.IDLE)
		State.IDLE:
			pass

	_animate_fish()
	_refresh_overlay()
	_update_input_history(interact_down, cancel_down)


func activate(_by: Node3D) -> void:
	if _mode_active:
		return
	_start_mode()


## Director seam: enter through the same gates as ordinary activation. The
## retired target argument remains so older probes parse while difficulty is
## now rolled statistically from this spot's level.
func begin_for_test(_legacy_target: StringName = &"") -> bool:
	if _mode_active:
		return false
	return _start_mode()


func state_name() -> StringName:
	match _state:
		State.IDLE:
			return &"idle"
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


func tension() -> float:
	return _tension_value


func line_progress() -> float:
	return _line_value


func feedback_mode_name() -> StringName:
	return _feedback.mode if _feedback != null else &"idle"


func fish_run_direction() -> int:
	return _run_direction if _state == State.HOOKED else 0


func desired_steer_direction() -> int:
	return -_run_direction if _state == State.HOOKED else 0


func actual_steering() -> int:
	return _actual_steering if _state == State.HOOKED else 0


func current_fish_id() -> StringName:
	return _current_fish_id


func caught_fish_id() -> StringName:
	return _caught_fish_id


func current_fish_tier() -> int:
	return SupplyCargoDb.tier_of(_current_fish_id)


func current_hook_window() -> float:
	return float(_current_tuning.get("hook_window", 0.0))


func reaction_fraction() -> float:
	if _state != State.BITE:
		return 0.0
	var window := current_hook_window()
	return clampf(1.0 - _state_elapsed / window, 0.0, 1.0) if window > 0.0 else 0.0


func feedback_reaction_name() -> StringName:
	return _feedback.reaction_name() if _feedback != null else &"neutral"


func feedback_visual_text() -> String:
	return _feedback.visual_text() if _feedback != null else ""


## The forced row is consumed by the next released cast. Invalid catalogue IDs
## are rejected so a proof cannot manufacture tuning or inventory state.
func debug_force_next_fish(id: StringName) -> bool:
	if not SupplyCargoDb.is_fish(id):
		return false
	_forced_next_fish_id = id
	return true


## Only waiting may be advanced by this probe. It cannot manufacture a cast or
## hook and therefore cannot bypass the transaction-bearing outcome states.
func debug_force_bite() -> void:
	if _state == State.WAITING:
		_transition(State.BITE)


## Deterministic proof still lands through Game's real all-or-nothing record and
## the same ten-minute outcome transaction as live play.
func debug_land_catch() -> void:
	if _state == State.HOOKED:
		_land_catch()


## Deterministic failure proof still uses the real attempt outcome: ten civil
## minutes, no banked Fish, RESULT, and ordinary delayed cleanup.
func debug_fail_attempt() -> void:
	if _state == State.BITE:
		_finish_failure("THE BITE SLIPPED AWAY.", &"escaped")
	elif _state == State.HOOKED:
		_finish_failure("THE LINE SNAPPED.", &"snapped")


func cancel() -> void:
	if _state != State.IDLE:
		_transition(State.IDLE)


func _start_mode() -> bool:
	if not Game.tool_known(ToolDb.FISHING_ROD_ID):
		Bus.request_message.emit("BRANNOC FORGES THE FISHING ROD.")
		return false
	if not Game.tool_usable(ToolDb.FISHING_ROD_ID):
		Bus.request_message.emit(
			"THE FISHING ROD IS BROKEN. BRANNOC MUST REFORGE IT.")
		return false
	if Game.fishing_remaining_today(Clock.day) <= 0:
		Bus.request_message.emit("TODAY'S WATER IS SPENT.")
		return false
	if not _any_fish_room():
		Bus.request_message.emit("BAG FULL — MAKE ROOM FOR A FISH.")
		return false

	_attempt_spent = false
	_mode_active = true
	_clock_was_running = Clock.running
	# The world clock normally advances in real time. Holding it here is what
	# makes a cancelled attempt cost zero and a resolved one cost exactly ten
	# civil minutes rather than ten plus however long the player deliberated.
	Clock.running = false
	Prompt.block(self)
	_disarm_input()
	_overlay.visible = true
	_transition(State.CASTING)
	return true


func _transition(next: State) -> void:
	if _state == next:
		return
	_state = next
	_state_elapsed = 0.0
	match next:
		State.IDLE:
			_exit_mode()
		State.CASTING:
			_cast_charge = 0.0
			_tension_value = 0.0
			_line_value = 1.0
			_result_success = false
			_failure_result = &""
			_current_fish_id = &""
			_caught_fish_id = &""
			_current_tuning = {}
		State.WAITING:
			_set_selected_fish_visible(true)
			Bus.request_sfx.emit(&"fishing_cast", _selected_fish_world_position())
		State.BITE:
			_set_selected_fish_visible(true)
			Bus.request_sfx.emit(&"fishing_bite", _selected_fish_world_position())
		State.HOOKED:
			Bus.request_sfx.emit(&"fishing_hook", _selected_fish_world_position())
			_tension_value = float(_current_tuning.get("initial_tension", 0.0))
			_line_value = 1.0
			_run_index = 0
			_run_direction = -1
			_run_elapsed = 0.0
			_actual_steering = 0
			_reeling = false
			_reel_sfx_armed = false
			_last_reel_sfx_msec = -1000000
			_last_strain_sfx_msec = -1000000
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
	_result_success = false
	_failure_result = &""
	_actual_steering = 0
	_reeling = false
	_cast_charge = 0.0
	_tension_value = 0.0
	_line_value = 1.0
	_splash.visible = false
	_ripple_root.visible = false
	_near_fish.visible = true
	_deep_fish.visible = true
	_disarm_input()


func _tick_casting(delta: float, interact_down: bool,
		interact_released: bool) -> void:
	if interact_down:
		_cast_charge = minf(1.0, _cast_charge + delta / CAST_CHARGE_TIME)
	if interact_released:
		_current_fish_id = _roll_fish_for_cast()
		_current_tuning = SupplyCargoDb.tuning(_current_fish_id)
		_transition(State.WAITING)
		if _current_fish_id == &"":
			# Bag state may change while the opening press is held. The empty cast
			# still resolves its ten minutes, but no daily catch is recorded.
			_finish_failure("BAG FULL.", &"escaped")


func _tick_hooked(delta: float, reeling: bool, left_down: bool,
		right_down: bool) -> void:
	var run_time := maxf(float(_current_tuning.get("run_interval", 0.0)), 0.001)
	_run_elapsed += delta
	if _run_elapsed >= run_time:
		_run_elapsed = fmod(_run_elapsed, run_time)
		_run_index += 1
		_run_direction = -1 if _run_index % 2 == 0 else 1

	var steer: int = (1 if right_down else 0) - (1 if left_down else 0)
	_actual_steering = steer
	_reeling = reeling
	_tick_reel_sfx(reeling, steer)
	var correcting: bool = steer == -_run_direction
	var following: bool = steer == _run_direction
	if not reeling:
		_tension_value -= delta * float(_current_tuning.get("tension_recovery", 0.0))
		_line_value += delta * float(_current_tuning.get("no_reel_escape_rate", 0.0))
	elif correcting:
		_tension_value -= delta * float(_current_tuning.get("tension_recovery", 0.0))
		_line_value -= delta * float(_current_tuning.get("correct_reel_rate", 0.0))
	elif following:
		_tension_value += delta * float(_current_tuning.get("wrong_tension_gain", 0.0))
	else:
		_tension_value += delta * float(_current_tuning.get("neutral_tension_gain", 0.0))

	_tension_value = clampf(_tension_value, 0.0, 1.0)
	_line_value = clampf(_line_value, 0.0, 1.0)
	if _tension_value >= 1.0:
		_finish_failure("THE LINE SNAPPED.", &"snapped")
	elif _line_value <= 0.0:
		_land_catch()


func _tick_reel_sfx(reeling: bool, steer: int) -> void:
	if not reeling:
		_reel_sfx_armed = true
		return
	if not _reel_sfx_armed:
		return
	var now: int = Time.get_ticks_msec()
	if steer == 0:
		if now - _last_reel_sfx_msec >= int(REEL_SFX_GAP * 1000.0):
			_last_reel_sfx_msec = now
			Bus.request_sfx.emit(&"fishing_reel", _selected_fish_world_position())
	elif now - _last_strain_sfx_msec >= int(STRAIN_SFX_GAP * 1000.0):
		_last_strain_sfx_msec = now
		Bus.request_sfx.emit(&"fishing_strain", _selected_fish_world_position())


func _land_catch() -> void:
	var landed_id := _current_fish_id
	var caught := Game.record_fish_catch(landed_id, Clock.day)
	Clock.advance_hours(ATTEMPT_MINUTES / 60.0)
	if caught:
		_result_success = true
		_caught_fish_id = landed_id
		_failure_result = &""
		Bus.request_sfx.emit(&"fishing_catch", _selected_fish_world_position())
	else:
		_result_success = false
		_caught_fish_id = &""
		_failure_result = &"escaped"
		Bus.request_sfx.emit(&"fishing_fail", _selected_fish_world_position())
	_spend_attempt_use()
	_transition(State.RESULT)


func _finish_failure(_text: String, result: StringName) -> void:
	Clock.advance_hours(ATTEMPT_MINUTES / 60.0)
	_result_success = false
	_caught_fish_id = &""
	_failure_result = result
	_spend_attempt_use()
	Bus.request_sfx.emit(&"fishing_fail", _selected_fish_world_position())
	_transition(State.RESULT)


func _selected_fish_world_position() -> Vector3:
	var fish := _active_fish_node()
	return fish.global_position if fish != null else global_position


func _active_fish_node() -> Node3D:
	return _deep_fish if current_fish_tier() >= 3 else _near_fish


func _spend_attempt_use() -> String:
	if not _attempt_spent:
		_attempt_spent = true
		Game.spend_tool_use(ToolDb.FISHING_ROD_ID)
	var remaining: int = Game.tool_durability(ToolDb.FISHING_ROD_ID)
	if remaining <= 0:
		return " · ROD BROKEN — BRANNOC MUST REFORGE IT"
	return " · ROD %d / %d" % [remaining,
		Game.tool_max_durability(ToolDb.FISHING_ROD_ID)]


func _any_fish_room() -> bool:
	for fish_id: StringName in SupplyCargoDb.FISH_IDS:
		if Run.room_for(fish_id) > 0:
			return true
	return false


func _roll_fish_for_cast() -> StringName:
	var rolled := SupplyCargoDb.roll_fish(spot_level, _rng)
	if _forced_next_fish_id != &"":
		rolled = _forced_next_fish_id
	_forced_next_fish_id = &""
	if rolled != &"" and Run.room_for(rolled) > 0:
		return rolled

	var fitting: Array[StringName] = []
	for fish_id: StringName in SupplyCargoDb.FISH_IDS:
		if Run.room_for(fish_id) > 0:
			fitting.append(fish_id)
	if fitting.is_empty():
		return &""

	# Filter once and roll once. Rejection sampling would bias deterministic
	# proofs through an unbounded number of RNG draws as the bag fills.
	var authored := SupplyCargoDb.tier_weights_for_spot(spot_level)
	var total := 0.0
	for i: int in SupplyCargoDb.FISH_IDS.size():
		if fitting.has(SupplyCargoDb.FISH_IDS[i]):
			total += maxf(float(authored[i]), 0.0)
	if total <= 0.0:
		return fitting.front()
	var pick := _rng.randf_range(0.0, total)
	for i: int in SupplyCargoDb.FISH_IDS.size():
		var fish_id: StringName = SupplyCargoDb.FISH_IDS[i]
		if not fitting.has(fish_id):
			continue
		pick -= maxf(float(authored[i]), 0.0)
		if pick <= 0.0:
			return fish_id
	return fitting.back()


func _disarm_input() -> void:
	_interact_armed = false
	_cancel_armed = false
	_interact_was_down = Input.is_action_pressed(&"interact")
	_cancel_was_down = Input.is_action_pressed(&"ui_cancel") \
		or Input.is_action_pressed(&"pause")


func _update_input_history(interact_down: bool, cancel_down: bool) -> void:
	_interact_was_down = interact_down
	_cancel_was_down = cancel_down


func _animate_fish() -> void:
	var selected := _active_fish_node()
	if _current_fish_id == &"" or selected == null:
		_splash.visible = false
		_ripple_root.visible = false
		_water.position.y = 0.30 + sin(Time.get_ticks_msec() * 0.0018) * 0.012
		return
	var base := Vector3(0.62, 0.03, -2.82) if selected == _deep_fish \
		else Vector3(-0.62, 0.08, -1.72)
	var travel: float = sin(_state_elapsed * (3.8 if _state == State.HOOKED else 2.2))
	if _state == State.HOOKED:
		travel = float(_run_direction) * 0.78 + sin(_state_elapsed * 7.0) * 0.18
	selected.position = base + Vector3(travel, sin(_state_elapsed * 5.0) * 0.05, 0.0)
	selected.rotation.y = -float(_run_direction) * 0.24 if _state == State.HOOKED \
		else sin(_state_elapsed * 2.2) * 0.18

	var cue_visible: bool = _state == State.WAITING or _state == State.BITE \
		or _state == State.HOOKED
	# The droplets punctuate the bite; the reused ring family carries the quieter
	# waiting and hooked language without turning the pond into particle noise.
	_splash.visible = _state == State.BITE
	if _splash.visible:
		_splash.position = selected.position + Vector3(0.0, 0.12, 0.0)
		var pulse: float = 0.92 + sin(_state_elapsed * 14.0) * 0.22
		_splash.scale = Vector3.ONE * pulse
	_animate_ripples(selected.position, cue_visible)
	_water.position.y = 0.30 + sin(Time.get_ticks_msec() * 0.0018) * 0.012


func _animate_ripples(fish_position: Vector3, cue_visible: bool) -> void:
	_ripple_root.visible = cue_visible
	if not cue_visible:
		return
	_ripple_root.position = fish_position + Vector3(0.0, 0.27, 0.0)
	var speed: float = 0.72
	var reach: float = 0.72
	var alpha: float = 0.24
	var color: Color = Pal.BONE
	if _state == State.BITE:
		speed = 2.8
		reach = 1.45
		alpha = 0.92
		color = Pal.CYAN
	elif _state == State.HOOKED:
		speed = 1.65
		reach = 0.92
		alpha = 0.46
		color = Pal.GOLD
	for i: int in _ripple_rings.size():
		var phase: float = fmod(_state_elapsed * speed + float(i) / 3.0, 1.0)
		var radius: float = 0.42 + phase * reach
		var ring := _ripple_rings[i]
		if _state == State.HOOKED:
			ring.scale = Vector3(radius * 1.35, 1.0, radius * 0.68)
		else:
			ring.scale = Vector3(radius, 1.0, radius)
		var ring_alpha: float = alpha * (1.0 - phase)
		var material := _ripple_materials[i]
		material.albedo_color = Color(color, ring_alpha)
		material.emission = Color(color, ring_alpha)


func _set_selected_fish_visible(value: bool) -> void:
	var fish := _active_fish_node()
	if fish != null:
		fish.visible = value


func _repaint_creel() -> void:
	for i: int in _creel_meals.size():
		_creel_meals[i].visible = i < Game.fish_stock
	var rods_visible: bool = Game.tool_usable(ToolDb.FISHING_ROD_ID)
	for rod: Node3D in _rack_rods:
		rod.visible = rods_visible
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

	var frame := Control.new()
	frame.name = &"Frame"
	_overlay_root.add_child(frame)
	frame.anchor_left = 0.5
	frame.anchor_top = 0.62
	frame.anchor_right = 0.5
	frame.anchor_bottom = 0.62
	frame.offset_left = -230.0
	frame.offset_top = -104.0
	frame.offset_right = 230.0
	frame.offset_bottom = 150.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pad := MarginContainer.new()
	frame.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	for side: String in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 4)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	pad.add_child(stack)

	_feedback = FEEDBACK_DRAW.new() as FishingFeedbackDraw
	_feedback.name = &"FeedbackDraw"
	_feedback.custom_minimum_size = Vector2(436.0, 176.0)
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_feedback)

	_cast_row = _gauge_row(stack, &"CastRow", "CAST", Pal.CYAN)
	_cast_gauge = _cast_row.get_node("Gauge") as ProgressBar
	_tension_row = _gauge_row(stack, &"TensionRow", "TENSION", Pal.VITAL)
	_tension_gauge = _tension_row.get_node("Gauge") as ProgressBar
	_line_row = _gauge_row(stack, &"LineRow", "LAND", Pal.MOSS)
	_line_gauge = _line_row.get_node("Gauge") as ProgressBar


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
	gauge.custom_minimum_size = Vector2(240.0, 9.0)
	gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_set_row_visible(_cast_row, _state == State.CASTING)
	_set_row_visible(_tension_row, _state == State.HOOKED)
	_set_row_visible(_line_row, _state == State.HOOKED)
	_cast_gauge.value = _cast_charge
	_tension_gauge.value = _tension_value
	# The remaining line falls toward zero in play; invert it so the landing bar
	# visibly fills toward the promised catch.
	_line_gauge.value = 1.0 - _line_value
	_feedback.fish_run_direction = fish_run_direction()
	_feedback.desired_steer_direction = desired_steer_direction()
	_feedback.actual_steering = actual_steering()
	_feedback.reeling = _reeling
	_feedback.tension = _tension_value
	_feedback.landing_progress = 1.0 - _line_value
	_feedback.reaction_fraction = reaction_fraction()
	_feedback.caught_name = SupplyCargoDb.name_of(_caught_fish_id)
	_feedback.caught_tier = SupplyCargoDb.tier_of(_caught_fish_id)
	var caught_def := ItemDb.get_def(_caught_fish_id)
	_feedback.caught_tint = caught_def.tint if caught_def != null else Pal.GOLD
	_feedback.failure_result = _failure_result
	_feedback.animation_phase = _state_elapsed
	_feedback.rod_durability = Game.tool_durability(ToolDb.FISHING_ROD_ID)
	_feedback.rod_max_durability = Game.tool_max_durability(ToolDb.FISHING_ROD_ID)
	match _state:
		State.CASTING:
			_feedback.mode = FishingFeedbackDraw.MODE_CASTING
		State.WAITING:
			_feedback.mode = FishingFeedbackDraw.MODE_WAITING
		State.BITE:
			_feedback.mode = FishingFeedbackDraw.MODE_BITE
		State.HOOKED:
			_feedback.mode = FishingFeedbackDraw.MODE_HOOKED
		State.RESULT:
			_feedback.mode = FishingFeedbackDraw.MODE_RESULT_SUCCESS if _result_success \
				else FishingFeedbackDraw.MODE_RESULT_FAILURE
		State.IDLE:
			pass
	_feedback.queue_redraw()


func _set_row_visible(row: Control, value: bool) -> void:
	# Visibility changes affect the VBox only at state boundaries; draw animation
	# itself is queue_redraw-only and never asks the container to lay out again.
	if row.visible != value:
		row.visible = value


# --- Landmark ---------------------------------------------------------------

func _build_landmark() -> void:
	if not build_pool_visuals:
		_water = MeshInstance3D.new()
		_water.name = &"WaterDriver"
		_water.visible = false
		add_child(_water)
		_build_dock()
		_build_rod_rack()
		_build_creel()
		_build_fish()
		_build_ripples()
		return
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
	_build_ripples()


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
		_rack_rods.append(_cylinder(rack, &"Rod", MAT_WOOD, 0.035, 2.15,
			Transform3D(rod_basis, Vector3(x, 1.28, -0.10)), false, 7))
		_rack_rods.append(_cylinder(rack, &"IronGrip", MAT_IRON, 0.055, 0.42,
			Transform3D(rod_basis, Vector3(x, 0.36, 0.10)), false, 7))


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


func _build_ripples() -> void:
	_ripple_root = Node3D.new()
	_ripple_root.name = &"FishingRipples"
	_ripple_root.visible = false
	add_child(_ripple_root)
	for i: int in 3:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(Pal.BONE, 0.0)
		material.emission_enabled = true
		material.emission = Color(Pal.BONE, 0.0)
		material.emission_energy_multiplier = 1.25
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ripple_materials.append(material)

		var ring := MeshInstance3D.new()
		ring.name = StringName("Ripple%d" % (i + 1))
		var torus := TorusMesh.new()
		torus.inner_radius = 0.41
		torus.outer_radius = 0.48
		torus.rings = 16
		torus.ring_segments = 4
		ring.mesh = torus
		ring.material_override = material
		_ripple_root.add_child(ring)
		_ripple_rings.append(ring)


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
