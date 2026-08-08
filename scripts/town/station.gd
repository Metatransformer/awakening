class_name Station
extends StaticBody3D
## An interactable fixture in town — the vendor's counter, the smith's forge, or
## the gate down. Walk up, press `interact`, something opens.
##
## These are counters and machines rather than NPC characters on purpose: the
## project has no townsfolk models, and a hooded warrior rig standing in for a
## shopkeeper reads worse than an honest market stall. The stall IS the vendor.

signal activated(kind: StringName)

enum Kind { VENDOR, SMITH, GATE }

@export var kind: Kind = Kind.VENDOR
@export var prompt: String = "Talk  [E]"
## Radius the prompt appears within.
@export var reach: float = 2.6

var _near: bool = false


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"station")
	collision_layer = K.L_WORLD

	var area := Area3D.new()
	area.collision_layer = K.L_INTERACT
	area.collision_mask = K.L_PLAYER
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	col.shape = sphere
	col.position = Vector3(0, 1.0, 0)
	area.add_child(col)
	add_child(area)

	area.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group(&"player"):
			_near = true
			Bus.request_message.emit(prompt))
	area.body_exited.connect(func(b: Node3D) -> void:
		if b.is_in_group(&"player"):
			_near = false
			Bus.request_message.emit(""))


func _unhandled_input(event: InputEvent) -> void:
	if not _near:
		return
	if event.is_action_pressed(&"interact"):
		Bus.request_message.emit("")
		activated.emit(_kind_name())
		get_viewport().set_input_as_handled()


func _kind_name() -> StringName:
	match kind:
		Kind.VENDOR: return &"vendor"
		Kind.SMITH: return &"smith"
		_: return &"gate"


## Let the UI suppress the prompt while a panel is open.
func set_prompt_active(on: bool) -> void:
	if _near and on:
		Bus.request_message.emit(prompt)
	elif not on:
		Bus.request_message.emit("")
