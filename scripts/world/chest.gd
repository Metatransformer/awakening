class_name Chest
extends Interactable
## A chest. Opens once, spits its contents onto the floor as motes, stays open.
##
## Contents are rolled at OPEN time, not at spawn time, and from `Run.rng` -- so
## a seeded run gives the same chest the same contents, but a chest you never
## opened never consumed a roll. That means adding a chest to a room does not
## reshuffle every other chest on the floor.
##
## Chests are the reason to leave the critical path, so they roll on
## ItemDb.CHEST_DROPS, whose floor is above an ordinary enemy's ceiling.
##
## They also carry the game's arrow supply (`ArrowBundle`), on a roll of their
## own rather than as an entry on the drop table. That separation is deliberate:
## `ItemDb._lift` reweights the table with depth, and arrows must NOT get rarer
## or commoner as you descend. A player five floors down needs the bow to keep
## working at exactly the rate a player on floor one does — supply is not loot,
## and putting it on the loot table would price it like treasure.

## How many things come out. Two is enough to make a chest feel like an event
## without making it the only thing worth doing. [tune]
@export var picks: int = 2
## Chance this chest also holds arrows, on top of its picks. Deliberately not
## certain and deliberately not rare: at 40% the bow is sustainable for a player
## who opens chests, and still dry for one who runs the critical path. [tune]
@export var arrow_chance: float = 0.4
## Marks the chest as already-looted for the rest of the run.
@export var opened: bool = false

var _lid: Node3D
var _glow: OmniLight3D
var _rim: MeshInstance3D


func _ready() -> void:
	prompt = "OPEN"
	radius = 1.7
	super()
	_build()
	if opened:
		_slam_open()


func activate(by: Node3D) -> void:
	if opened:
		return
	opened = true
	enabled = false
	_rim.visible = false

	var tw := create_tween()
	if _lid != null:
		tw.tween_property(_lid, "rotation:x", LID_OPEN, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_glow, "light_energy", 0.0, 0.5)

	# The arrow roll happens FIRST and always, whether or not it lands, so that
	# adding or removing it cannot shift the loot rolls below it on a given seed.
	# A chest's contents have to be a function of the seed alone (see the class
	# doc); an early return would make them a function of the code as well.
	var arrows := Run.rng.randf() < arrow_chance
	var fan := maxi(picks, 1) + (1 if arrows else 0)
	var slot := 0

	for i in maxi(picks, 1):
		var id := ItemDb.roll(ItemDb.chest_drops(Run.level), Run.rng)
		if id == &"":
			continue
		LootMote.drop(get_tree().current_scene, id,
			global_position + Vector3.UP * 0.7, _fan(slot, fan) * 1.15)
		slot += 1

	if arrows:
		ArrowBundle.drop(get_tree().current_scene,
			global_position + Vector3.UP * 0.7, ArrowBundle.CHEST_COUNT,
			_fan(slot, fan) * 1.15)

	Bus.chest_opened.emit(name, &"chest")
	activated.emit(by)


## Where the `i`th of `n` things thrown out of this chest lands. Fanned so two
## drops never stack up and read as one, and taken off the chest's OWN facing
## rather than the world's, so a chest against a wall spills into the room.
func _fan(i: int, n: int) -> Vector3:
	var a := TAU * (float(i) + 0.5) / float(maxi(n, 1)) - PI * 0.5
	return (global_transform.basis * Vector3(sin(a), 0.0, cos(a))).normalized()


# --- Construction -----------------------------------------------------------
# The BOX is authored art; everything hung on it is still built in code. The kit
# generates its walls and pillars because a wall is a parameter, but a chest is a
# thing a person made, and the six-box version of it read as a crate.

## The model. It arrives in five parts — bottom, lid, two handles, a lock — and
## the lid is a sibling node hinged on its own back edge, which is exactly the
## pivot `activate()` wants. That is why this model and not one of the others:
## a single-mesh chest cannot open, and a chest that cannot open is a barrel.
const MODEL := "res://assets/props/treasure_chest.glb"
## Native size is 0.955 x 0.512 x 0.618 m. 1.2 puts it at 1.15 wide and 0.74
## tall, which is docs/CONTRACT.md §2's chest footprint and, more to the point,
## chest-height on a 1.65 m hero.
const MODEL_SCALE := 1.2
## The lid's node name inside the GLB. Named rather than found by index because
## an index is a silent lie the day the model is re-exported.
const LID_NODE := "treasure_chest_lid"
## Where the lid line sits once scaled — the seam of light goes here.
const SEAM_Y := 0.421 * MODEL_SCALE
## How far the lid swings. The hinge is on the chest's -Z edge and the lid runs
## out to +Z, so a negative turn about X stands it up; past 90° it leans back and
## stays there instead of hovering at attention, which is what an opened chest
## does. Unchanged from the box version — the pivot convention is the same.
const LID_OPEN := -104.0 * PI / 180.0

func _build() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	add_child(body)

	# A box, not the mesh's own shape. The collision is what the hero bumps into
	# and what an arrow stops on, and neither wants the handles and the lock
	# resolved to the millimetre — it wants the chest to be chest-shaped.
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.16, 0.86, 0.62)
	col.shape = box
	col.position.y = 0.43
	body.add_child(col)

	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_error("Chest: '%s' failed to load" % MODEL)
		return
	var model := packed.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * MODEL_SCALE
	body.add_child(model)

	# The lid stays where the artist put it and is rotated in place. Re-parenting
	# it under a hand-made pivot would throw away the hinge that is already
	# correct and replace it with one measured off a bounding box.
	_lid = model.get_node_or_null(LID_NODE) as Node3D
	if _lid == null:
		push_error("Chest: no '%s' in %s — the lid cannot open" % [LID_NODE, MODEL])

	# A thin seam of gold light at the lid line. This is the whole "there is
	# something in here" read -- no floating icon, no beam, no exclamation mark.
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Pal.GOLD
	rim_mat.emission_enabled = true
	rim_mat.emission = Pal.GOLD
	rim_mat.emission_energy_multiplier = 2.4
	_rim = MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(1.04, 0.03, 0.56)
	_rim.mesh = rm
	_rim.material_override = rim_mat
	_rim.position.y = SEAM_Y
	add_child(_rim)

	_glow = OmniLight3D.new()
	_glow.light_color = Pal.GOLD
	_glow.light_energy = 1.5
	_glow.omni_range = 2.6
	_glow.omni_attenuation = 1.7
	_glow.shadow_enabled = false
	_glow.position.y = 0.75
	add_child(_glow)


func _slam_open() -> void:
	if _lid != null:
		_lid.rotation.x = LID_OPEN
	_glow.light_energy = 0.0
	_rim.visible = false
	enabled = false
