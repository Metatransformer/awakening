class_name CivilInstruments
extends Control
## The two civil instruments that share the HUD's top-right edge: a heading strip
## and the day's sun/moon track. The clock owns time, SkyCycle owns its authored
## boundaries, and the player's -basis.z owns facing; this node only presents them.

const WIDTH := 224.0
const HEIGHT := 96.0
const MAP_GAP := 8.0
const COMPASS_H := 48.0
const SPAN_DEGREES := 150.0
const REDRAW_HZ := 30.0
const MINUTE_TWEEN_SECONDS := 1.28

const CARDINALS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const MARKS: Array[Dictionary] = [
	{&"bearing": 0.0, &"label": "N"},
	{&"bearing": 45.0, &"label": "NE"},
	{&"bearing": 90.0, &"label": "E"},
	{&"bearing": 135.0, &"label": "SE"},
	{&"bearing": 180.0, &"label": "S"},
	{&"bearing": 225.0, &"label": "SW"},
	{&"bearing": 270.0, &"label": "W"},
	{&"bearing": 315.0, &"label": "NW"},
]

var _player: Node3D = null
var _heading_degrees: float = 0.0
var _redraw_accumulator: float = 0.0
var _motion_time: float = 0.0
var _underground: bool = false
var _display_absolute_minutes: float = -1.0
var _target_absolute_minutes: float = -1.0
var _clock_tween: Tween = null


func _ready() -> void:
	name = "CivilInstruments"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	get_viewport().size_changed.connect(_seat)
	Clock.minute_changed.connect(_on_minute_changed)
	_display_absolute_minutes = float(Clock.day - 1) * 1440.0 + Clock.hour * 60.0
	_target_absolute_minutes = _display_absolute_minutes
	_underground = Run != null and Run.in_dungeon
	_seat()
	_find_player()
	set_process(true)


func _exit_tree() -> void:
	if _clock_tween != null and _clock_tween.is_valid():
		_clock_tween.kill()


func _process(delta: float) -> void:
	_motion_time += delta
	var now_underground: bool = Run != null and Run.in_dungeon
	if now_underground != _underground:
		_underground = now_underground
		_seat()
	if (_player == null or not is_instance_valid(_player)
			or not _player.is_inside_tree()):
		_find_player()
	_redraw_accumulator += delta
	if _redraw_accumulator >= 1.0 / REDRAW_HZ:
		_redraw_accumulator = fmod(_redraw_accumulator, 1.0 / REDRAW_HZ)
		_update_heading()
		queue_redraw()


func _seat() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return
	var width := Pal.px(WIDTH, viewport_size.y)
	var height := Pal.px(HEIGHT, viewport_size.y)
	var right := -(1.0 - Pal.MINIMAP_RIGHT) * viewport_size.x
	var top := Pal.MINIMAP_TOP * viewport_size.y
	if _underground:
		top += Pal.px(Pal.MINIMAP_SIZE + MAP_GAP, viewport_size.y)
	offset_left = right - width
	offset_right = right
	offset_top = top
	offset_bottom = top + height
	queue_redraw()


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_update_heading()


func _update_heading() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var forward := -_player.global_transform.basis.z
	var flat := Vector2(forward.x, forward.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	_heading_degrees = fposmod(rad_to_deg(atan2(flat.x, -flat.y)), 360.0)


func _on_minute_changed(day: int, hour: int, minute: int) -> void:
	var target := float(day - 1) * 1440.0 + float(hour * 60 + minute)
	if _display_absolute_minutes < 0.0:
		_set_display_absolute_minutes(target)
		_target_absolute_minutes = target
		return
	if _clock_tween != null and _clock_tween.is_valid():
		_clock_tween.kill()
	_clock_tween = null
	_target_absolute_minutes = target
	var distance := target - _display_absolute_minutes
	# A restore may move civil time backwards. That is setup, not a journey around
	# the dial, so it snaps. Midnight does not: day is part of the absolute value,
	# hence 23:59 -> 00:00 remains a positive one-minute target.
	if distance <= 0.0:
		_set_display_absolute_minutes(target)
		return
	var duration := MINUTE_TWEEN_SECONDS
	if distance > 1.5:
		duration = clampf(0.65 + log(1.0 + distance) * 0.12, 0.8, 1.5)
	_clock_tween = create_tween()
	_clock_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_clock_tween.set_ignore_time_scale(true)
	_clock_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_clock_tween.tween_method(_set_display_absolute_minutes,
		_display_absolute_minutes, target, duration)


func _set_display_absolute_minutes(value: float) -> void:
	_display_absolute_minutes = value
	queue_redraw()


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(Pal.VOID, 0.84))
	draw_rect(Rect2(Vector2.ZERO, size), Pal.ASH, false, _px(1.0))
	_draw_compass()
	_draw_day_track()


func _draw_compass() -> void:
	var centre_x := size.x * 0.5
	var inset := _px(8.0)
	var strip_width := size.x - inset * 2.0
	var pixels_per_degree := strip_width / SPAN_DEGREES
	var label_scale := CanvasText.scale_for(10.0, get_viewport_rect().size.y)
	var bearing_scale := CanvasText.scale_for(14.0, get_viewport_rect().size.y)
	var first_tick := int(floor((_heading_degrees - SPAN_DEGREES * 0.5) / 15.0)) * 15
	var last_tick := int(ceil((_heading_degrees + SPAN_DEGREES * 0.5) / 15.0)) * 15
	for tick: int in range(first_tick, last_tick + 1, 15):
		var difference := _signed_difference(float(tick), _heading_degrees)
		var x := centre_x + difference * pixels_per_degree
		var cardinal_tick := tick % 45 == 0
		var tick_top := _px(19.0 if cardinal_tick else 22.0)
		draw_line(Vector2(x, tick_top), Vector2(x, _px(28.0)),
			Color(Pal.MOTH, 0.72), _px(1.0))
	for mark: Dictionary in MARKS:
		var difference := _signed_difference(float(mark[&"bearing"]), _heading_degrees)
		if absf(difference) > SPAN_DEGREES * 0.5 + 6.0:
			continue
		var label := String(mark[&"label"])
		var tint := Pal.BONE if label.length() == 1 else Pal.MOTH
		CanvasText.draw_centred(self, label,
			Vector2(centre_x + difference * pixels_per_degree, _px(5.0)),
			label_scale, tint)
	# Fixed pointer: the strip moves beneath this, never the other way around.
	draw_line(Vector2(centre_x, _px(3.0)), Vector2(centre_x, _px(28.0)),
		Pal.BONE, _px(1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(centre_x, _px(8.0)),
		Vector2(centre_x - _px(4.0), _px(1.0)),
		Vector2(centre_x + _px(4.0), _px(1.0)),
	]), Pal.BONE)
	CanvasText.draw_centred(self, "%s  %03d°" % [cardinal_label(),
		int(round(_heading_degrees)) % 360],
		Vector2(centre_x, _px(32.0)), bearing_scale, Pal.BONE)
	draw_line(Vector2(_px(6.0), _px(COMPASS_H)),
		Vector2(size.x - _px(6.0), _px(COMPASS_H)), Color(Pal.ASH, 0.8), _px(1.0))


func _draw_day_track() -> void:
	var absolute_minutes := maxf(_display_absolute_minutes, 0.0)
	var day := int(floor(absolute_minutes / 1440.0)) + 1
	var minute_of_day := fposmod(absolute_minutes, 1440.0)
	var hour := minute_of_day / 60.0
	var text_scale := CanvasText.scale_for(14.0, get_viewport_rect().size.y)
	CanvasText.draw_centred(self, "DAY %d  •  %s" % [day, SkyCycle.hour_string(hour)],
		Vector2(size.x * 0.5, _px(54.0)), text_scale, Pal.MOTH)
	var left := _px(10.0)
	var right := size.x - _px(10.0)
	var track_y := _px(82.0)
	var track_width := right - left
	draw_line(Vector2(left, track_y), Vector2(right, track_y),
		Color(Pal.MOTH, 0.8), _px(1.0))
	var sunrise := SkyCycle.sunrise_hour()
	var sunset := SkyCycle.sunset_hour()
	var dawn_x := left + track_width * sunrise / 24.0
	var dusk_x := left + track_width * sunset / 24.0
	draw_line(Vector2(dawn_x, track_y - _px(4.0)),
		Vector2(dawn_x, track_y + _px(4.0)), Pal.RUST, _px(1.0))
	draw_line(Vector2(dusk_x, track_y - _px(4.0)),
		Vector2(dusk_x, track_y + _px(4.0)), Pal.RUST, _px(1.0))
	draw_line(Vector2(dawn_x, track_y), Vector2(dusk_x, track_y),
		Color(Pal.BONE, 0.76), _px(2.0))
	var marker := Vector2(left + track_width * hour / 24.0,
		track_y + sin(_motion_time * TAU * 0.65) * _px(1.5))
	var pulse := 1.0 + sin(_motion_time * TAU * 0.9) * 0.08
	if SkyCycle.is_daylight(hour):
		_draw_sun(marker, pulse)
	else:
		_draw_moon(marker, pulse)


func _draw_sun(at: Vector2, pulse: float) -> void:
	var radius := _px(3.5) * pulse
	draw_circle(at, radius, Pal.BONE)
	for ray: int in 8:
		var direction := Vector2.from_angle(TAU * float(ray) / 8.0)
		draw_line(at + direction * (radius + _px(1.0)),
			at + direction * (radius + _px(3.0)), Pal.BONE, _px(1.0))


func _draw_moon(at: Vector2, pulse: float) -> void:
	var radius := _px(4.0) * pulse
	draw_circle(at, radius, Pal.MOTH)
	draw_circle(at + Vector2(_px(2.0), -_px(1.0)), radius * 0.76,
		Color(Pal.VOID, 0.96))


func _px(reference_pixels: float) -> float:
	return Pal.px(reference_pixels, get_viewport_rect().size.y)


func _signed_difference(target: float, current: float) -> float:
	return wrapf(target - current, -180.0, 180.0)


func bearing_degrees() -> float:
	return _heading_degrees


func cardinal_label() -> String:
	return CARDINALS[int(round(_heading_degrees / 45.0)) % CARDINALS.size()]


func displayed_absolute_minutes() -> float:
	return _display_absolute_minutes


func target_absolute_minutes() -> float:
	return _target_absolute_minutes


func instrument_rect() -> Rect2:
	return Rect2(position, size)


func layout_mode() -> StringName:
	return &"dungeon" if _underground else &"surface"
