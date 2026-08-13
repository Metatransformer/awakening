class_name FishingFeedbackDraw
extends Control
## Draw-only vocabulary for the fishing interaction. Gameplay owns every value;
## this control only turns the current snapshot into bounded, readable shapes.

const MODE_CASTING: StringName = &"casting"
const MODE_WAITING: StringName = &"waiting"
const MODE_BITE: StringName = &"bite"
const MODE_HOOKED: StringName = &"hooked"
const MODE_RESULT_SUCCESS: StringName = &"result_success"
const MODE_RESULT_FAILURE: StringName = &"result_failure"

var mode: StringName = MODE_CASTING
var fish_run_direction: int = 0
var desired_steer_direction: int = 0
var actual_steering: int = 0
var reeling: bool = false
var tension: float = 0.0
var landing_progress: float = 0.0
var reaction_fraction: float = 0.0
var caught_name: String = ""
var caught_tier: int = 0
var caught_tint: Color = Pal.GOLD
var failure_result: StringName = &""
var animation_phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func reaction_name() -> StringName:
	if mode != MODE_HOOKED or actual_steering == 0:
		return &"neutral"
	return &"correct" if actual_steering == desired_steer_direction else &"wrong"


## Text painted by this component, exposed so the visual proof can reject the
## old prose even though CanvasItem draw strings are not Label nodes.
func visual_text() -> String:
	match mode:
		MODE_CASTING:
			return "CAST"
		MODE_HOOKED:
			return "L R TENSION LAND"
		MODE_RESULT_SUCCESS:
			var pips := ""
			for _i: int in caught_tier:
				pips += " •"
			return caught_name.to_upper() + pips
	return ""


func _draw() -> void:
	var centre := size * Vector2(0.5, 0.46)
	match mode:
		MODE_CASTING:
			_draw_casting(centre)
		MODE_WAITING:
			_draw_waiting(centre, false)
		MODE_BITE:
			_draw_waiting(centre, true)
		MODE_HOOKED:
			_draw_hooked(centre)
		MODE_RESULT_SUCCESS:
			_draw_success(centre)
		MODE_RESULT_FAILURE:
			_draw_failure(centre)


func _draw_casting(centre: Vector2) -> void:
	var sway: float = sin(animation_phase * 4.5) * 12.0
	draw_line(centre + Vector2(-52.0, 42.0), centre + Vector2(-8.0, -38.0),
		Pal.BONE, 4.0, true)
	draw_line(centre + Vector2(-8.0, -38.0), centre + Vector2(62.0 + sway, 10.0),
		Color(Pal.CYAN, 0.78), 2.0, true)
	draw_circle(centre + Vector2(62.0 + sway, 10.0), 5.0, Pal.GOLD)
	CanvasText.draw_centred(self, "CAST", centre + Vector2(0.0, 48.0),
		0.78, UITheme.ACCENT)


func _draw_waiting(centre: Vector2, is_bite: bool) -> void:
	var speed: float = 4.8 if is_bite else 1.5
	var urgency := clampf(reaction_fraction, 0.0, 1.0)
	var spread: float = lerpf(14.0, 54.0, urgency) if is_bite else 38.0
	var phase: float = fmod(animation_phase * speed, 1.0)
	for i: int in 3:
		var ring_phase: float = fmod(phase + float(i) / 3.0, 1.0)
		var radius: float = 10.0 + ring_phase * spread
		var alpha: float = (1.0 - ring_phase) * (0.95 if is_bite else 0.48)
		var width: float = 5.0 if is_bite else 2.5
		draw_arc(centre, radius, 0.12, PI - 0.12, 22,
			Color(Pal.CYAN if is_bite else Pal.BONE, alpha), width, true)
		draw_arc(centre, radius, PI + 0.12, TAU - 0.12, 22,
			Color(Pal.CYAN if is_bite else Pal.BONE, alpha), width, true)
	var fish_scale: float = 28.0 if is_bite else 18.0
	_draw_fish(centre + Vector2(sin(animation_phase * speed) * 10.0, 7.0),
		fish_scale, -1, Color(Pal.BONE, 0.78 if is_bite else 0.42))
	if is_bite:
		# The cue contracts from the exact hook window rather than an unrelated
		# loop, so its remaining size is the remaining reaction time.
		draw_arc(centre, 16.0 + urgency * 46.0, 0.0, TAU, 28,
			Color(Pal.GOLD, 0.42 + urgency * 0.48), 4.0, true)
		_draw_hook(centre + Vector2(0.0, -61.0), 0.84 + urgency * 0.24)


func _draw_hooked(centre: Vector2) -> void:
	var reaction: StringName = reaction_name()
	var color: Color = Pal.GOLD
	if reaction == &"correct":
		color = Pal.CYAN
	elif reaction == &"wrong":
		color = Pal.VITAL
	var direction: int = desired_steer_direction if desired_steer_direction != 0 else 1
	var pulse: float = 1.0 + sin(animation_phase * 8.0) * (0.07 if reeling else 0.035)
	_draw_arrow(centre + Vector2(0.0, -8.0), direction, color, pulse)
	_draw_key(centre + Vector2(-104.0, 39.0), "L", direction < 0, color)
	_draw_key(centre + Vector2(104.0, 39.0), "R", direction > 0, color)
	var run_at := centre + Vector2(float(fish_run_direction) * 82.0, -52.0)
	_draw_fish(run_at, 16.0, fish_run_direction, Color(Pal.BONE, 0.58))


func _draw_success(centre: Vector2) -> void:
	var reveal: float = clampf(animation_phase / 0.34, 0.0, 1.0)
	var pop: float = 0.55 + sin(reveal * PI) * 0.55 + reveal * 0.45
	for i: int in 2:
		draw_arc(centre, 42.0 + float(i) * 14.0 + reveal * 10.0, 0.0, TAU, 24,
			Color(Pal.GOLD, (1.0 - reveal) * 0.5), 3.0)
	_draw_fish(centre + Vector2(0.0, -12.0), 38.0 * pop, 1, caught_tint)
	CanvasText.draw_centred(self, caught_name.to_upper(),
		centre + Vector2(0.0, 39.0), 0.82, caught_tint)
	var pip_count := clampi(caught_tier, 1, 4)
	var pip_start := -float(pip_count - 1) * 7.0
	for i: int in pip_count:
		draw_circle(centre + Vector2(pip_start + float(i) * 14.0, 62.0),
			4.5, caught_tint)


func _draw_failure(centre: Vector2) -> void:
	var escape: float = clampf(animation_phase / 0.8, 0.0, 1.0)
	var fish_at := centre + Vector2(42.0 + escape * 58.0, -6.0 - escape * 20.0)
	_draw_fish(fish_at, 24.0, 1, Color(Pal.MOTH, 0.88))
	if failure_result == &"snapped":
		draw_line(centre + Vector2(-72.0, -50.0), centre + Vector2(-12.0, -4.0),
			Pal.BONE, 3.0, true)
		draw_line(centre + Vector2(-4.0, 7.0), centre + Vector2(25.0, 28.0),
			Pal.BONE, 3.0, true)
		draw_colored_polygon(PackedVector2Array([
			centre + Vector2(-13.0, -5.0), centre + Vector2(1.0, -1.0),
			centre + Vector2(-7.0, 8.0), centre + Vector2(7.0, 13.0),
		]), Pal.VITAL)
	else:
		for i: int in 3:
			var x: float = float(i) * 18.0
			draw_line(centre + Vector2(-52.0 + x, 19.0 + float(i % 2) * 7.0),
				centre + Vector2(-39.0 + x, 19.0 + float(i % 2) * 7.0),
				Color(Pal.CYAN, 0.65), 3.0, true)
	_draw_circle_x(centre + Vector2(-48.0, 39.0), 13.0, Pal.VITAL)


func _draw_arrow(at: Vector2, direction: int, color: Color, pulse: float) -> void:
	var d: float = float(direction)
	var length: float = 74.0 * pulse
	var tip := at + Vector2(d * length, 0.0)
	var tail := at - Vector2(d * 55.0, 0.0)
	draw_line(tail, tip - Vector2(d * 13.0, 0.0), Color(Pal.VOID, 0.9), 14.0, true)
	draw_line(tail, tip - Vector2(d * 13.0, 0.0), color, 8.0, true)
	draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-d * 28.0, -23.0),
		tip + Vector2(-d * 28.0, 23.0),
	]), Color(Pal.VOID, 0.9))
	draw_colored_polygon(PackedVector2Array([
		tip - Vector2(d * 3.0, 0.0), tip + Vector2(-d * 25.0, -18.0),
		tip + Vector2(-d * 25.0, 18.0),
	]), color)


func _draw_key(at: Vector2, glyph: String, active: bool, color: Color) -> void:
	var box := Rect2(at - Vector2(18.0, 15.0), Vector2(36.0, 30.0))
	var border: Color = color if active else Color(Pal.MOTH, 0.46)
	draw_rect(box, Color(Pal.VOID, 0.72), true)
	draw_rect(box, border, false, 3.0 if active else 2.0, true)
	CanvasText.draw_centred(self, glyph, at + Vector2(0.0, -9.0), 0.76,
		color if active else Color(Pal.BONE, 0.54))


func _draw_hook(at: Vector2, pulse: float) -> void:
	var color := Pal.GOLD
	draw_arc(at + Vector2(0.0, 8.0), 21.0 * pulse, -0.2, PI * 1.14, 18,
		Color(Pal.VOID, 0.9), 9.0, true)
	draw_arc(at + Vector2(0.0, 8.0), 21.0 * pulse, -0.2, PI * 1.14, 18,
		color, 5.0, true)
	draw_line(at + Vector2(20.0, 3.0), at + Vector2(20.0, -27.0), color, 5.0, true)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(10.0, -28.0), at + Vector2(20.0, -38.0),
		at + Vector2(30.0, -28.0), at + Vector2(20.0, -18.0),
	]), Pal.CYAN)


func _draw_fish(at: Vector2, scale_factor: float, direction: int,
		color: Color) -> void:
	var d: float = float(direction if direction != 0 else 1)
	var points := PackedVector2Array([
		at + Vector2(-d * scale_factor * 0.72, 0.0),
		at + Vector2(-d * scale_factor * 0.35, -scale_factor * 0.42),
		at + Vector2(d * scale_factor * 0.45, -scale_factor * 0.35),
		at + Vector2(d * scale_factor * 0.88, 0.0),
		at + Vector2(d * scale_factor * 0.45, scale_factor * 0.35),
		at + Vector2(-d * scale_factor * 0.35, scale_factor * 0.42),
	])
	draw_colored_polygon(points, color)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-d * scale_factor * 0.65, 0.0),
		at + Vector2(-d * scale_factor * 1.18, -scale_factor * 0.52),
		at + Vector2(-d * scale_factor * 1.08, scale_factor * 0.55),
	]), Color(color, color.a * 0.88))
	draw_circle(at + Vector2(d * scale_factor * 0.53, -scale_factor * 0.09),
		maxf(2.0, scale_factor * 0.08), Pal.VOID)


func _draw_circle_x(at: Vector2, radius: float, color: Color) -> void:
	draw_arc(at, radius, 0.0, TAU, 16, Color(Pal.VOID, 0.9), 8.0, true)
	draw_arc(at, radius, 0.0, TAU, 16, color, 4.0, true)
	var diagonal := Vector2(radius * 0.55, radius * 0.55)
	draw_line(at - diagonal, at + diagonal, color, 4.0, true)
	draw_line(at + Vector2(-diagonal.x, diagonal.y),
		at + Vector2(diagonal.x, -diagonal.y), color, 4.0, true)
