class_name SleepClockCard
extends Control
## Paused-time civil clock shown while Flow owns the black sleep transition.

signal finished

const PRESENTATION_SECONDS: float = 2.4
const CLOCK_RADIUS_PX: float = 82.0
const TITLE_PX: float = 28.0
const TIME_PX: float = 22.0
const DETAIL_PX: float = 15.0

var from_absolute_hour: float = 0.0
var to_absolute_hour: float = 0.0
var presentation_progress: float = 0.0:
	set(value):
		presentation_progress = clampf(value, 0.0, 1.0)
		_redraw()

var _ink: Control = null
var _tween: Tween = null
var _finished_emitted: bool = false


static func open(layer: CanvasLayer, from_hour: float,
		to_hour: float) -> SleepClockCard:
	var card := SleepClockCard.new()
	card.from_absolute_hour = from_hour
	card.to_absolute_hour = to_hour
	layer.add_child(card)
	return card


func _ready() -> void:
	name = "SleepClockCard"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_fit()
	get_viewport().size_changed.connect(_fit)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(Pal.VOID, 0.985)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_ink = Control.new()
	_ink.name = "Ink"
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.focus_mode = Control.FOCUS_NONE
	_ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ink.draw.connect(_draw_ink)
	add_child(_ink)

	_start_presentation()


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		_tween.kill()
	_finish_once()


func current_absolute_hour() -> float:
	return lerpf(from_absolute_hour, to_absolute_hour, presentation_progress)


func _start_presentation() -> void:
	if _finished_emitted:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	presentation_progress = 0.0
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "presentation_progress", 1.0,
		PRESENTATION_SECONDS)
	_tween.finished.connect(_finish_once)


func _finish_once() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	finished.emit()


## A Control parented directly to a CanvasLayer has no Control parent resolving
## its anchors, so this card follows the viewport explicitly.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_redraw()


func _redraw() -> void:
	if _ink != null:
		_ink.queue_redraw()


func _draw_ink() -> void:
	var screen_size: Vector2 = size
	if screen_size.x < 1.0 or screen_size.y < 1.0:
		return
	var fade_in: float = clampf(presentation_progress / 0.10, 0.0, 1.0)
	var fade_out: float = clampf((1.0 - presentation_progress) / 0.08, 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)
	var centre := Vector2(screen_size.x * 0.5, screen_size.y * 0.46)
	var radius: float = Pal.px(CLOCK_RADIUS_PX, screen_size.y)

	_draw_field(screen_size, alpha)
	_draw_clock(centre, radius, current_absolute_hour(), alpha)

	var title_scale: float = CanvasText.scale_for(TITLE_PX, screen_size.y)
	CanvasText.draw_centred(_ink, "SLEEPING",
		Vector2(screen_size.x * 0.5, screen_size.y * 0.145),
		title_scale, Color(Pal.BONE, alpha))

	var detail_scale: float = CanvasText.scale_for(DETAIL_PX, screen_size.y)
	var route: String = "%s  →  %s" % [
		_format_day_time(from_absolute_hour),
		_format_day_time(to_absolute_hour),
	]
	CanvasText.draw_centred(_ink, route,
		Vector2(screen_size.x * 0.5, screen_size.y * 0.225),
		detail_scale, Color(Pal.MOTH, alpha))

	var time_scale: float = CanvasText.scale_for(TIME_PX, screen_size.y)
	CanvasText.draw_centred(_ink, _format_day_time(current_absolute_hour()),
		Vector2(screen_size.x * 0.5, screen_size.y * 0.735),
		time_scale, Color(Pal.BONE, alpha))
	CanvasText.draw_centred(_ink,
		"TARGET  %s" % _format_day_time(to_absolute_hour),
		Vector2(screen_size.x * 0.5, screen_size.y * 0.805),
		detail_scale, Color(Pal.MOTH, alpha))


func _draw_field(screen_size: Vector2, alpha: float) -> void:
	var left: float = screen_size.x * 0.23
	var right: float = screen_size.x * 0.77
	var top: float = screen_size.y * 0.105
	var bottom: float = screen_size.y * 0.865
	var point: float = screen_size.x * 0.026
	_ink.draw_colored_polygon(PackedVector2Array([
		Vector2(left + point, top), Vector2(right - point, top),
		Vector2(right, (top + bottom) * 0.5),
		Vector2(right - point, bottom), Vector2(left + point, bottom),
		Vector2(left, (top + bottom) * 0.5),
	]), Color(Pal.MIDNIGHT, alpha * 0.86))
	_ink.draw_line(Vector2(left + point, top), Vector2(right - point, top),
		Color(Pal.ASH, alpha * 0.72), Pal.px(1.0, screen_size.y), true)
	_ink.draw_line(Vector2(left + point, bottom),
		Vector2(right - point, bottom), Color(Pal.ASH, alpha * 0.52),
		Pal.px(1.0, screen_size.y), true)


func _draw_clock(centre: Vector2, radius: float, absolute_hour: float,
		alpha: float) -> void:
	var line_width: float = Pal.px(1.0, size.y)
	_ink.draw_circle(centre, radius, Color(Pal.VOID, alpha * 0.92))
	_ink.draw_arc(centre, radius, 0.0, TAU, 64, Color(Pal.BONE, alpha * 0.86),
		line_width * 2.0, true)
	_ink.draw_arc(centre, radius * 0.90, 0.0, TAU, 64,
		Color(Pal.ASH, alpha * 0.76), line_width, true)

	for i in 12:
		var angle: float = TAU * float(i) / 12.0 - PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		var inner: float = radius * (0.79 if i % 3 == 0 else 0.84)
		var tick_width: float = line_width * (2.0 if i % 3 == 0 else 1.0)
		_ink.draw_line(centre + direction * inner,
			centre + direction * radius * 0.91,
			Color(Pal.MOTH, alpha), tick_width, true)

	var civil_hour: float = fposmod(absolute_hour, 24.0)
	var minute_angle: float = fposmod(civil_hour, 1.0) * TAU - PI * 0.5
	var hour_angle: float = fposmod(civil_hour, 12.0) / 12.0 * TAU - PI * 0.5
	var hour_direction := Vector2(cos(hour_angle), sin(hour_angle))
	var minute_direction := Vector2(cos(minute_angle), sin(minute_angle))
	_ink.draw_line(centre, centre + hour_direction * radius * 0.50,
		Color(Pal.BONE, alpha), line_width * 4.0, true)
	_ink.draw_line(centre, centre + minute_direction * radius * 0.72,
		Color(Pal.RUST, alpha), line_width * 2.0, true)
	_ink.draw_circle(centre, line_width * 4.0, Color(Pal.BONE, alpha))


func _format_day_time(absolute_hour: float) -> String:
	var safe_hour: float = maxf(0.0, absolute_hour)
	var campaign_day: int = int(floor(safe_hour / 24.0)) + 1
	var minute_of_day: int = int(floor(fposmod(safe_hour, 24.0) * 60.0
		+ 0.0001)) % 1440
	return "DAY %d  %02d:%02d" % [
		campaign_day, minute_of_day / 60, minute_of_day % 60]
