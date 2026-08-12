class_name SurfaceTransition
extends Interactable
## An explicit threshold between the garrison, its surface approach, and the
## Lower Worlds. Flow remains the only owner of scene changes; this prop only
## names the destination and supplies the deliberate hold at each threshold.

enum Destination {
	GARRISON,
	OUTSKIRTS,
	SUNKEN_CUT,
	BLOCKED,
}

@export var destination: Destination = Destination.BLOCKED

var _obstruction: Node3D
var _obstruction_position := Vector3.ZERO
var _obstruction_rotation := Vector3.ZERO
var _obstruction_scale := Vector3.ONE
var _focused: bool = false
var _feedback: Tween


func _ready() -> void:
	match destination:
		Destination.GARRISON:
			prompt = "RETURN"
			hold_time = 0.6
		Destination.OUTSKIRTS:
			prompt = "DEPART"
			hold_time = 0.6
		Destination.SUNKEN_CUT:
			prompt = "DESCEND"
			hold_time = 0.9
		Destination.BLOCKED:
			prompt = "EXAMINE"
			hold_time = 0.0
	super()


func activate(by: Node3D) -> void:
	# Keep the ordinary Interactable contract even for the dead end. Directors and
	# local scene owners can observe one signal without knowing which threshold it
	# was, while Flow still owns the two real transitions.
	super.activate(by)
	match destination:
		Destination.GARRISON:
			Flow.to_garrison()
		Destination.OUTSKIRTS:
			Flow.to_outskirts()
		Destination.SUNKEN_CUT:
			Flow.enter_dungeon()
		Destination.BLOCKED:
			_animate_obstruction()


func on_focus(on: bool) -> void:
	_focused = on
	if _obstruction == null or _feedback != null and _feedback.is_valid():
		return
	_obstruction.scale = _obstruction_scale * (1.04 if on else 1.0)


## Attach the visual-only part of a blocked route. Its aggregate solid backstop
## remains outside this node, so the feedback can move without moving collision.
func bind_obstruction(obstruction: Node3D) -> void:
	_obstruction = obstruction
	_obstruction_position = obstruction.position
	_obstruction_rotation = obstruction.rotation
	_obstruction_scale = obstruction.scale


func _animate_obstruction() -> void:
	if _obstruction == null:
		return
	if _feedback != null and _feedback.is_valid():
		_feedback.kill()
	_obstruction.position = _obstruction_position
	_obstruction.rotation = _obstruction_rotation
	_obstruction.scale = _obstruction_scale * 1.07
	_feedback = create_tween()
	_feedback.tween_property(_obstruction, ^"position:x",
		_obstruction_position.x + 0.12, 0.055)
	_feedback.tween_property(_obstruction, ^"position:x",
		_obstruction_position.x - 0.08, 0.075)
	_feedback.parallel().tween_property(_obstruction, ^"rotation:z",
		_obstruction_rotation.z + deg_to_rad(2.5), 0.075)
	_feedback.tween_property(_obstruction, ^"position:x",
		_obstruction_position.x, 0.24).set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)
	_feedback.parallel().tween_property(_obstruction, ^"rotation:z",
		_obstruction_rotation.z, 0.18)
	_feedback.tween_callback(_settle_obstruction)


func _settle_obstruction() -> void:
	if _obstruction == null:
		_feedback = null
		return
	_obstruction.position = _obstruction_position
	_obstruction.rotation = _obstruction_rotation
	_obstruction.scale = _obstruction_scale * (1.04 if _focused else 1.0)
	_feedback = null
