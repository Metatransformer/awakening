class_name Arrow
extends Node3D
## One arrow, in flight. Built and launched by HeroRanged; owns nothing but its
## own trajectory and the one blow it lands.
##
## **It is not an Area3D, and that is the point.** K.ARROW_SPEED is 42 m/s, which
## at 60 Hz is a 0.7 m step per frame — further than a crawler is wide and far
## further than a wall is thick. An Area3D only reports what it OVERLAPS on the
## frame the physics server samples it, so an arrow built that way passes clean
## through a thin enemy roughly as often as it hits one, and the misses look like
## bad aim rather than a bug. So each frame this raycasts the SEGMENT it is about
## to travel and stops at whatever that segment crosses. Nothing can be missed by
## being narrow.
##
## The shaft drops: K.ARROW_GRAVITY is a tenth of the world's, because [oot]
## arrows barely fall across the 8.5 m lock range. Far enough out it is visible,
## which is what makes a long shot a shot rather than a hitscan.

## Quarter-hearts. Half a heart, same as the sword — the bow's advantage is
## reach, not damage, and a bow that also out-damages the blade is the only
## weapon anyone brings. [tune]
const DAMAGE := 2 * K.QUARTER
const KNOCKBACK := K.KNOCKBACK_LIGHT
## Seconds a spent arrow stays stuck in whatever it hit before it disappears.
const LINGER := 2.5
## Seconds before an arrow that never hit anything gives up.
const LIFETIME := 4.0

## The model, and how it has to be turned to agree with the flight.
##
## `assets/weapons/arrow.glb` is a real arrow with a real head, real fletching
## and its own materials — 224 triangles, which is cheaper than the five-sided
## cylinder it replaced was going to be once it grew a nock. It imports lying
## along +Y, and this node flies along -Z (see `_face_travel`), so the model gets
## a quarter turn about X and nothing else in the class has to know.
##
## MEASURED, not derived. Which end of a GLB is the point is not a thing to
## reason out from an axis name — see CLAUDE.md §4 and
## `tools/directors/arrow_bundle_lookdev.gd`, which renders it.
const MODEL_ID := "arrow"
const MODEL_PITCH := -PI * 0.5
## Rendered length, metres. Not used by anything here — the flight is a raycast
## and cares nothing for the mesh — but the bundle and the lookdev both want to
## know how long the thing they are laying out is.
const MODEL_LEN := 0.70

var _velocity: Vector3 = Vector3.ZERO
var _origin: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _stuck: bool = false
## Nodes the shot must not hit: the hero and everything under him. An arrow
## leaving a muzzle that sits inside the hero's own capsule would otherwise
## report a hit on frame one, every time.
var _ignore: Array[RID] = []

var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_build()


## Fire from `from` along `dir`. `shooter` is excluded from the raycast.
func launch(from: Vector3, dir: Vector3, shooter: CollisionObject3D = null) -> void:
	global_position = from
	_origin = from
	_velocity = dir.normalized() * K.ARROW_SPEED
	if shooter != null:
		_ignore = [shooter.get_rid()]
	_query.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	# Bodies AND areas: enemies are bodies, but the props that predate
	# HealthComponent hang their damage surface off an Area3D, and the sword
	# scans both for exactly this reason (hero_combat.gd `_scan`).
	_query.collide_with_bodies = true
	_query.collide_with_areas = true
	_query.exclude = _ignore
	_face_travel()


func _physics_process(delta: float) -> void:
	if _stuck:
		_age += delta
		if _age >= LINGER:
			queue_free()
		return

	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return

	_velocity.y -= K.ARROW_GRAVITY * delta
	var from := global_position
	var to := from + _velocity * delta

	_query.from = from
	_query.to = to
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if hit.is_empty():
		global_position = to
		_face_travel()
		return

	# Land ON the surface, not a hair inside it, so a stuck arrow reads as an
	# arrow in a wall rather than a fletching sticking out of nothing.
	global_position = hit["position"] as Vector3 - _velocity.normalized() * 0.04
	_face_travel()
	_strike(hit["collider"] as Node)


## Damage whatever the head found, if it is the kind of thing that takes damage.
## World geometry is not, and an arrow in a wall is a legitimate outcome — it is
## how you learn the range.
func _strike(collider: Node) -> void:
	_stuck = true
	_age = 0.0
	_velocity = Vector3.ZERO

	var victim := _damageable(collider)
	if victim == null:
		Bus.request_sfx.emit(&"weapon_impact_stab_1", global_position)
		return

	var hit := Hit.make(DAMAGE, _origin, &"arrow", KNOCKBACK)
	var landed = victim.apply_hit(hit)
	# apply_hit returns bool on a HealthComponent and null on the duck-typed
	# props that predate it, so absence of a false is a landed blow. Same rule
	# the sword uses; they must not diverge.
	if landed == false:
		return
	Bus.request_sfx.emit(&"arrow_body_impact", global_position)
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	# An arrow that stayed lodged in a walking enemy would have to be parented to
	# it and dragged around; it is not worth the ownership question, so it goes
	# the moment it connects.
	queue_free()


func _damageable(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method(&"apply_hit"):
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	# The hurtbox is often a child Area3D and the health lives on the body.
	var parent := node.get_parent()
	if parent != null and parent.has_method(&"apply_hit"):
		return parent
	return null


## Point the shaft along travel. The arc is shallow but it is not flat, and an
## arrow that keeps its launch pitch all the way down reads as a dart on rails.
func _face_travel() -> void:
	if _velocity.length_squared() < 0.0001:
		return
	var dir := _velocity.normalized()
	# looking_at cannot build a basis when the direction and up are parallel, and
	# a shot fired straight up off a hookshot pull is reachable.
	var up := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
	global_basis = Basis.looking_at(dir, up)


# --- Construction -----------------------------------------------------------
## The node flies along local -Z, so `looking_at` aims it with no extra
## correction. The MODEL is turned to match, once, here — that is the whole of
## the art-space fix and it lives on the model node, never on this node's basis,
## because `-basis.z is forward` is the contract the flight and the raycast both
## read (CLAUDE.md §4).

func _build() -> void:
	var model := WeaponModels.make(MODEL_ID)
	if model == null:
		return
	model.name = "Model"
	model.rotation.x = MODEL_PITCH
	add_child(model)
