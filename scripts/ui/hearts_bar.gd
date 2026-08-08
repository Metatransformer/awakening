class_name HeartsBar
extends Control
## The quarter-heart health row.
##
## Health is stored in quarters (K.QUARTER / K.HEART), so a heart has five
## states and the bar must be able to draw a fractional one. Rather than ship
## five sprites, the heart is a polygon and the filled part is the polygon
## intersected with a vertical slice — exact at any fraction, and no art needed.

const HEART_SIZE := 22.0
const GAP := 3.0
const PER_ROW := 10

const FILL := Color(0.90, 0.16, 0.20)
const EMPTY := Color(0.12, 0.09, 0.10, 0.85)
const EDGE := Color(0.04, 0.03, 0.04, 0.9)

var quarters: int = K.START_HEARTS * K.HEART
var max_quarters: int = K.START_HEARTS * K.HEART

static var _shape: PackedVector2Array = _make_heart()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Bus.player_health_changed.connect(_on_changed)
	refresh()


## Re-read Game directly. For the moments a push cannot cover — a save load, or
## a world swap that may have happened while nothing was emitting.
func refresh() -> void:
	_on_changed(Game.quarters, Game.max_quarters)


func _on_changed(q: int, max_q: int) -> void:
	quarters = q
	max_quarters = max_q
	var hearts := int(ceil(float(max_quarters) / float(K.HEART)))
	var rows := int(ceil(float(hearts) / float(PER_ROW)))
	custom_minimum_size = Vector2(
		mini(hearts, PER_ROW) * (HEART_SIZE + GAP),
		rows * (HEART_SIZE + GAP))
	queue_redraw()


## A heart on the unit square, y down. Two lobes and a point, traced by hand
## rather than by a formula so the silhouette stays chunky at 22 px.
static func _make_heart() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 14
	# Left lobe: a half-circle from the centre notch round to the left waist.
	for i in steps + 1:
		var a: float = PI + PI * (float(i) / float(steps))
		pts.append(Vector2(0.27, 0.30) + Vector2(cos(a), sin(a)) * 0.27)
	# Right lobe.
	for i in steps + 1:
		var a: float = PI + PI * (float(i) / float(steps))
		pts.append(Vector2(0.73, 0.30) + Vector2(cos(a), sin(a)) * 0.27)
	# Down to the point and back up the left flank.
	pts.append(Vector2(0.94, 0.46))
	pts.append(Vector2(0.50, 0.97))
	pts.append(Vector2(0.06, 0.46))
	return pts


func _draw() -> void:
	var hearts := int(ceil(float(max_quarters) / float(K.HEART)))
	for i in hearts:
		var col := i % PER_ROW
		var row := i / PER_ROW
		var at := Vector2(col * (HEART_SIZE + GAP), row * (HEART_SIZE + GAP))
		var poly := _scaled(at)
		draw_colored_polygon(poly, EMPTY)
		draw_polyline(_closed(poly), EDGE, 1.5, true)

		var filled: int = clampi(quarters - i * K.HEART, 0, K.HEART)
		if filled <= 0:
			continue
		var frac := float(filled) / float(K.HEART)
		if frac >= 1.0:
			draw_colored_polygon(poly, FILL)
			continue
		# Intersect with the left `frac` of the heart's box. Godot returns an
		# array of polygons because an intersection can split; draw them all.
		var slice := PackedVector2Array([
			at, at + Vector2(HEART_SIZE * frac, 0.0),
			at + Vector2(HEART_SIZE * frac, HEART_SIZE), at + Vector2(0.0, HEART_SIZE)])
		for piece in Geometry2D.intersect_polygons(poly, slice):
			if piece.size() >= 3:
				draw_colored_polygon(piece, FILL)


func _scaled(at: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _shape:
		out.append(at + p * HEART_SIZE)
	return out


static func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(poly)
	if out.size() > 0:
		out.append(out[0])
	return out
