class_name PressurePlate
extends PuzzleAtom
## Atom 3 of 8 (`docs/PUZZLES.md` §2): the pressure plate. T0 -- a body or a
## block holds it.
##
## **The one atom in the kit that goes backwards.** Step off and it rises, and
## that is why `latching` is a column in `PuzzleAtoms.ATOMS` rather than an
## assumption baked into `PuzzleAtom`. It writes no world flag for the same
## reason: a one-way flag on a two-way prop is a plate that comes back pressed
## with nothing standing on it.
##
## That reversibility is the entire design of the pair. A plate the hero can hold
## is a plate that gates a door the hero cannot then reach, which is the oldest
## nest in the genre (§3, combinator 1) and the reason `PushBlock` exists one
## file over. A plate that latched would make the block pointless.
##
## ## What counts as weight
##
## The player, and anything in group `&"plate_weight"` -- which is `PushBlock`
## and nothing else today. Deliberately NOT enemies: a goblin wandering onto a
## plate would open the gate room's door while the player was still hunting the
## key, and a puzzle that solves itself off the pathfinder is a puzzle nobody
## solved. It is also not a corpse-shoving mechanic the combat design ever asked
## for.

## Metres the cap sinks when it is held.
const TRAVEL := 0.085
const PLATE_R := 1.05
const CAP_H := 0.11
const RIM_H := 0.07
const SINK_TIME := 0.13
## The trigger's height. Low, so a hero jumping over the plate does not trip it
## in mid-air -- but taller than the cap's travel, or a block resting ON the
## sunken plate falls out of its own trigger and the plate oscillates.
const TRIGGER_H := 1.1

var _cap: Node3D
var _lamp: OmniLight3D
var _trigger: Area3D
var _rest_y: float = 0.0
## How many things are standing on it. A count and not a bool: the hero steps
## off a plate a block is also on, and a bool would rise under the block.
var _load: int = 0


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.PRESSURE_PLATE
	_build()
	super()


# --- Weight -------------------------------------------------------------------

func _bearing(body: Node3D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"plate_weight")


func _on_entered(body: Node3D) -> void:
	if not _bearing(body):
		return
	_load += 1
	if _load == 1:
		solve()


func _on_exited(body: Node3D) -> void:
	if not _bearing(body):
		return
	_load = maxi(0, _load - 1)
	if _load == 0:
		unsolve()


## How many bodies are on it. Public because a director has to be able to say
## "the plate reports weight" separately from "the plate reports solved" -- the
## two coming apart is the bug this prop is most likely to have.
func load_count() -> int:
	return _load


# --- Pressed and risen --------------------------------------------------------

func on_solved() -> void:
	_move_cap(_rest_y - TRAVEL, Pal.MOSS, 2.4)
	Bus.request_sfx.emit(&"craft_clang", global_position)


func on_unsolved() -> void:
	_move_cap(_rest_y, Pal.COBALT, 0.55)
	Bus.request_sfx.emit(&"craft_grind", global_position)


func _move_cap(to_y: float, hue: Color, energy: float) -> void:
	if _cap == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cap, "position:y", to_y, SINK_TIME)
	if _lamp != null:
		tw.tween_property(_lamp, "light_color", hue, SINK_TIME)
		tw.tween_property(_lamp, "light_energy", energy, SINK_TIME)
	var mat := _cap.get_meta(&"glow") as StandardMaterial3D
	if mat != null:
		tw.tween_property(mat, "emission", hue, SINK_TIME)
		tw.tween_property(mat, "emission_energy_multiplier", energy * 0.6, SINK_TIME)


# --- Construction -------------------------------------------------------------

func _build() -> void:
	# The seated rim: a ring of stone the cap drops into. Static, and the only
	# collision this prop has -- the CAP must not collide, or the block that is
	# meant to rest on it would be standing on a moving floor and jitter.
	var rim_body := StaticBody3D.new()
	rim_body.name = "Rim"
	rim_body.collision_layer = K.L_WORLD
	rim_body.collision_mask = 0
	# `PushBlock._clear` looks for this group before it refuses a slide: the rim is
	# world geometry, and the one cell a block is most often asked to enter is the
	# one with a plate in it. A group and not a class check, so the block does not
	# have to know what a plate IS.
	rim_body.add_to_group(&"plate_rim")
	add_child(rim_body)
	var rim_mat := _mat(Color(0.30, 0.29, 0.31), 0.97, 0.0)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var at := Vector3(cos(a) * (PLATE_R + 0.10), RIM_H * 0.5, sin(a) * (PLATE_R + 0.10))
		_box(rim_body, rim_mat, Vector3(0.34, RIM_H, 0.22), at, Vector3(0.0, -a, 0.0))
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.34, RIM_H, 0.22)
		cs.shape = bx
		cs.position = at
		cs.rotation.y = -a
		rim_body.add_child(cs)

	_cap = Node3D.new()
	_cap.name = "Cap"
	_rest_y = RIM_H
	_cap.position.y = _rest_y
	add_child(_cap)

	var stone := _mat(Color(0.36, 0.35, 0.38), 0.96, 0.0)
	_cyl(_cap, stone, PLATE_R, CAP_H, Vector3(0.0, CAP_H * 0.5, 0.0), 12)

	# The live channel: a cross cut into the cap that lights when it is held.
	# COBALT cold while it is up, MOSS live while it is down -- the same
	# chilled-hue-warms-when-satisfied language `LockedDoor` uses on its sigil,
	# so a player who has read one door has read every plate.
	var glow := _glow_mat(Pal.COBALT, 0.33)
	_cap.set_meta(&"glow", glow)
	for r: float in [0.0, PI * 0.5]:
		_box(_cap, glow, Vector3(PLATE_R * 1.35, 0.035, 0.13),
			Vector3(0.0, CAP_H + 0.005, 0.0), Vector3(0.0, r, 0.0))

	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Pal.COBALT
	_lamp.light_energy = 0.55
	_lamp.omni_range = 3.2
	_lamp.omni_attenuation = 1.8
	_lamp.shadow_enabled = false
	_lamp.position.y = 0.30
	add_child(_lamp)

	_trigger = Area3D.new()
	_trigger.name = "Trigger"
	_trigger.collision_layer = 0
	# `L_PLAYER | L_WORLD`: the hero is on the player layer and `PushBlock` is a
	# world body, and a mask of one of them is a plate only one of the two can
	# hold. The `_bearing` filter above is what keeps the world layer from
	# meaning "every wall segment in the room".
	_trigger.collision_mask = K.L_PLAYER | K.L_WORLD
	_trigger.monitoring = true
	var cs2 := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = PLATE_R
	cyl.height = TRIGGER_H
	cs2.shape = cyl
	cs2.position.y = TRIGGER_H * 0.5
	_trigger.add_child(cs2)
	add_child(_trigger)
	_trigger.body_entered.connect(_on_entered)
	_trigger.body_exited.connect(_on_exited)
