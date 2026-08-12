class_name DayTitleCard
extends Control
## The civil-day announcement shown at nightfall and dawn. Flow owns when one
## exists; this node owns only the five-second picture and its finished edge.

signal finished

const PRESENTATION_SECONDS: float = 5.0
const FADE_IN_SECONDS: float = 0.65
const FADE_OUT_SECONDS: float = 0.65
const HOLD_SECONDS: float = PRESENTATION_SECONDS - FADE_IN_SECONDS - FADE_OUT_SECONDS

const TITLE_Y: float = 0.420
const RULE_Y: float = 0.505
const DAY_Y: float = 0.535
const TITLE_PX: float = 34.0
const DAY_PX: float = 17.0
const RULE_HALF: float = 0.105

var title: String = ""
var day_line: String = ""
var cue: StringName = &""

var _ink: Control = null
var _tween: Tween = null


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
	modulate.a = 0.0
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

	_tween = create_tween().set_ignore_time_scale(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	_tween.finished.connect(func() -> void: finished.emit())


## A Control parented directly to a CanvasLayer has no Control parent whose
## anchors can resolve, so it follows the viewport explicitly.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _ink != null:
		_ink.queue_redraw()


func _draw_ink() -> void:
	var screen_size := size
	if screen_size.x < 1.0 or screen_size.y < 1.0:
		return

	var title_scale := CanvasText.scale_for(TITLE_PX, screen_size.y)
	CanvasText.draw_centred(_ink, title,
		Vector2(screen_size.x * 0.5, screen_size.y * TITLE_Y),
		title_scale, Pal.BONE)

	var rule_half_width := screen_size.x * RULE_HALF
	_ink.draw_rect(Rect2(
		screen_size.x * 0.5 - rule_half_width,
		screen_size.y * RULE_Y,
		rule_half_width * 2.0,
		Pal.px(1.0, screen_size.y)), Color(Pal.ASH, 0.72))

	var day_scale := CanvasText.scale_for(DAY_PX, screen_size.y)
	CanvasText.draw_centred(_ink, day_line,
		Vector2(screen_size.x * 0.5, screen_size.y * DAY_Y),
		day_scale, Pal.MOTH)
