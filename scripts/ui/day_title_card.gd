class_name DayTitleCard
extends Control
## The civil-day announcement shown at nightfall and dawn. Flow owns when one
## exists; this node owns only the three-second picture and its finished edge.

signal finished

const PRESENTATION_SECONDS: float = 3.0
const REVEAL_SECONDS: float = 0.65
const EXIT_SECONDS: float = 0.65
const EXIT_AT: float = PRESENTATION_SECONDS - EXIT_SECONDS

const HORIZON_Y: float = 0.350
const TITLE_Y: float = 0.485
const RULE_Y: float = 0.570
const DAY_Y: float = 0.600
const TITLE_PX: float = 34.0
const DAY_PX: float = 17.0
const RULE_HALF: float = 0.105
const MOTIF_RADIUS_PX: float = 29.0

var title: String = ""
var day_line: String = ""
var cue: StringName = &""

var visual_mode: StringName = &"night"
var reveal_progress: float = 0.0:
	set(value):
		reveal_progress = clampf(value, 0.0, 1.0)
		_redraw()
var motif_progress: float = 0.0:
	set(value):
		motif_progress = clampf(value, 0.0, 1.0)
		_redraw()
var title_progress: float = 0.0:
	set(value):
		title_progress = clampf(value, 0.0, 1.0)
		_redraw()
var rule_progress: float = 0.0:
	set(value):
		rule_progress = clampf(value, 0.0, 1.0)
		_redraw()
var day_progress: float = 0.0:
	set(value):
		day_progress = clampf(value, 0.0, 1.0)
		_redraw()
var exit_progress: float = 0.0:
	set(value):
		exit_progress = clampf(value, 0.0, 1.0)
		_redraw()

var _ink: Control = null
var _tween: Tween = null
var _finished_emitted: bool = false


## Add a configured card to Flow's existing presentation layer. The caller
## owns the returned node and frees it after `finished`.
static func open(layer: CanvasLayer, title_text: String, day: int,
		cue_id: StringName) -> DayTitleCard:
	var card := DayTitleCard.new()
	card.title = title_text
	card.day_line = "Day %d" % day
	card.cue = cue_id
	layer.add_child(card)
	return card


func _ready() -> void:
	name = "DayTitleCard"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visual_mode = &"dawn" if cue == &"dawn_birds" \
			or title.to_lower().contains("sun") else &"night"
	_fit()
	get_viewport().size_changed.connect(_fit)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(Pal.VOID, 0.97)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _start_presentation() -> void:
	if _finished_emitted:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()

	modulate.a = 1.0
	reveal_progress = 0.0
	motif_progress = 0.0
	title_progress = 0.0
	rule_progress = 0.0
	day_progress = 0.0
	exit_progress = 0.0

	_tween = create_tween().set_ignore_time_scale(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "reveal_progress", 1.0, REVEAL_SECONDS)
	_tween.tween_property(self, "motif_progress", 1.0, 0.85).set_delay(0.12)
	_tween.tween_property(self, "title_progress", 1.0, 0.38).set_delay(0.44)
	_tween.tween_property(self, "rule_progress", 1.0, 0.34).set_delay(0.68)
	_tween.tween_property(self, "day_progress", 1.0, 0.34).set_delay(0.86)
	_tween.tween_property(self, "exit_progress", 1.0, EXIT_SECONDS) \
		.set_delay(EXIT_AT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, EXIT_SECONDS) \
		.set_delay(EXIT_AT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_finish_once)


func _finish_once() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	finished.emit()


## A Control parented directly to a CanvasLayer has no Control parent whose
## anchors can resolve, so it follows the viewport explicitly.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_redraw()


func _redraw() -> void:
	if _ink != null:
		_ink.queue_redraw()


func _draw_ink() -> void:
	var screen_size := size
	if screen_size.x < 1.0 or screen_size.y < 1.0:
		return

	var centre_x := screen_size.x * 0.5
	var field_half := screen_size.x * 0.46 * reveal_progress
	if field_half > 1.0:
		var field_top := screen_size.y * 0.175
		var field_bottom := screen_size.y * 0.735
		var point := minf(screen_size.x * 0.032, field_half * 0.28)
		_ink.draw_colored_polygon(PackedVector2Array([
			Vector2(centre_x - field_half + point, field_top),
			Vector2(centre_x + field_half - point, field_top),
			Vector2(centre_x + field_half, (field_top + field_bottom) * 0.5),
			Vector2(centre_x + field_half - point, field_bottom),
			Vector2(centre_x - field_half + point, field_bottom),
			Vector2(centre_x - field_half, (field_top + field_bottom) * 0.5),
		]), _field_color())

	var exit_lift := screen_size.y * 0.018 * exit_progress
	var horizon_y := screen_size.y * HORIZON_Y - exit_lift
	var horizon_half := screen_size.x * 0.205 * reveal_progress
	_ink.draw_line(Vector2(centre_x - horizon_half, horizon_y),
		Vector2(centre_x + horizon_half, horizon_y), Color(Pal.ASH, 0.78),
		Pal.px(1.0, screen_size.y), true)
	_draw_time_motif(screen_size, Vector2(centre_x, horizon_y), exit_lift)

	var title_scale := CanvasText.scale_for(TITLE_PX, screen_size.y)
	CanvasText.draw_centred(_ink, title,
		Vector2(centre_x, screen_size.y * TITLE_Y
			+ screen_size.y * 0.016 * (1.0 - title_progress) - exit_lift),
		title_scale, Color(Pal.BONE, title_progress))

	var rule_half_width := screen_size.x * RULE_HALF * rule_progress
	_ink.draw_rect(Rect2(
		centre_x - rule_half_width,
		screen_size.y * RULE_Y - exit_lift,
		rule_half_width * 2.0,
		Pal.px(1.0, screen_size.y)), Color(Pal.ASH, 0.72))

	var day_scale := CanvasText.scale_for(DAY_PX, screen_size.y)
	CanvasText.draw_centred(_ink, day_line,
		Vector2(centre_x, screen_size.y * DAY_Y
			+ screen_size.y * 0.010 * (1.0 - day_progress) - exit_lift),
		day_scale, Color(Pal.MOTH, day_progress))


func _field_color() -> Color:
	if visual_mode == &"dawn":
		return Pal.MIDNIGHT.lerp(Pal.ASH, 0.18)
	return Pal.MIDNIGHT


func _draw_time_motif(screen_size: Vector2, horizon: Vector2,
		exit_lift: float) -> void:
	if motif_progress <= 0.0:
		return
	var radius := Pal.px(MOTIF_RADIUS_PX, screen_size.y)
	var rise: float = Tween.interpolate_value(0.0, 1.0, motif_progress, 1.0,
		Tween.TRANS_SINE, Tween.EASE_OUT)
	var motif_y := lerpf(horizon.y + radius * 0.72,
		horizon.y - radius * 1.18, rise) - exit_lift * 0.25
	var centre := Vector2(horizon.x, motif_y)
	var motif_alpha := clampf(motif_progress * 1.5, 0.0, 1.0)
	var motif_color := Color(Pal.BONE, motif_alpha)

	if visual_mode == &"dawn":
		_ink.draw_circle(centre, radius, motif_color)
		var ray_alpha := clampf((motif_progress - 0.58) / 0.42, 0.0, 1.0)
		for i in 8:
			var angle := TAU * float(i) / 8.0
			var direction := Vector2(cos(angle), sin(angle))
			_ink.draw_line(centre + direction * radius * 1.28,
				centre + direction * radius * 1.62,
				Color(Pal.MOTH, ray_alpha * 0.72),
				Pal.px(1.0, screen_size.y), true)
	else:
		_ink.draw_circle(centre, radius, motif_color)
		_ink.draw_circle(centre + Vector2(radius * 0.38, -radius * 0.10),
			radius * 0.91, _field_color())
