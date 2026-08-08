class_name Interactable
extends Area3D
## Anything the player can walk up to and press the interact button on.
##
## The node does NOT read input. Arbitration lives in the `Prompt` autoload,
## because "which of the three things I am standing inside do I mean?" is a
## question only something that can see all of them can answer. A chest that
## decides for itself fires at the same instant as the vendor standing behind
## it, and the player gets both.
##
## Subclass and override `activate()`. Override `on_focus()` / `on_hold()` if the
## prop wants to show something while it is the one being addressed.

signal activated(by: Node3D)

## Shown in the HUD as "(E) <prompt>". Uppercased by the font, so write it plain.
@export var prompt: String = "EXAMINE"
## Radius of the auto-built trigger sphere. Ignored if the scene supplies a shape.
@export var radius: float = 1.9
## Seconds the button must be held. 0 fires on press.
@export var hold_time: float = 0.0
@export var enabled: bool = true:
	set(v):
		enabled = v
		if not v and Prompt != null and Prompt.focus == self:
			Prompt.drop_focus()

## True while a node in group `player` overlaps the trigger. Read by Prompt.
var player_inside: bool = false


func _ready() -> void:
	collision_layer = K.L_INTERACT
	collision_mask = K.L_PLAYER
	monitoring = true
	monitorable = true
	if _find_shape() == null:
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = radius
		cs.shape = sp
		add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Prompt.register(self)


func _exit_tree() -> void:
	Prompt.unregister(self)


func _find_shape() -> CollisionShape3D:
	for c in get_children():
		if c is CollisionShape3D:
			return c
	return null


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		player_inside = false


# --- Overridables -----------------------------------------------------------

## Called when this becomes (or stops being) the prop the player is addressing.
func on_focus(_on: bool) -> void:
	pass


## 0..1 while the player holds the button. Only called if `hold_time` > 0.
func on_hold(_t01: float) -> void:
	pass


## The thing actually happening. `by` is the hero.
func activate(by: Node3D) -> void:
	activated.emit(by)
