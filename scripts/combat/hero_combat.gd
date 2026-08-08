class_name HeroCombat
extends Node3D
## The hero's sword, shield, and held item — the models, the swing, and the box
## that actually hurts things.
##
## Added as a child of the Hero by hero.gd. It keeps combat out of the movement
## script while still driving the hero's states, because the two genuinely are
## coupled: you cannot steer freely mid-swing, and that commitment is most of
## what makes a swing feel like it weighs something.
##
## Sockets are BoneAttachment3D on the real rig bones. The offsets below were
## found by RENDERING, not by arithmetic: the rig's rest pose is expressed in a
## rotated FBX space, so the bone matrices read as nonsense if you try to reason
## from them. tools/directors/p4_combat.gd is what settled each number.
##
## Note the scale compensation in `_mount`. The Model node is scaled by
## K.HERO_SCALE (1.65) to lift a 1.0-unit rig to adult height, and anything
## parented under a bone inherits that. A 0.92 m sword would otherwise render at
## 1.52 m — a greatsword — which is exactly the kind of error that looks like an
## art problem and is really a transform problem.

@export_group("Loadout")
@export var sword_id: String = "sword_knightly"
@export var shield_id: String = "shield_noble"
@export var bow_id: String = "bow_knightly"
@export var hookshot_id: String = "hookshot_pistol"

@export_group("Sword")
## Quarter-hearts per slash. K.HEART == 4, so this is half a heart.
@export var damage: int = 2 * K.QUARTER
## Seconds the whole swing owns the hero. The clips are 1.4-2.4 s, far too slow
## for OOT, so they are time-scaled onto this.
@export var swing_time: float = 0.46
## The slice of the swing during which the blade can hurt something, as
## fractions of swing_time. Before it is the wind-up, after it is the recovery.
@export var damage_window := Vector2(0.22, 0.62)
## Reach from the hero's centre, metres. The blade is 0.92 m and the arm adds.
@export var reach: float = 1.35
@export var arc_degrees: float = 130.0
@export var knockback: float = K.KNOCKBACK_LIGHT

@export_group("Shield")
## Half-angle of the block cone, degrees. A blow from outside it is not blocked.
@export var block_cone: float = 70.0

@export_group("Audio")
@export var sfx_swing: AudioStream = preload("res://audio/sfx/swing.ogg")
@export var sfx_impact: AudioStream = preload("res://audio/sfx/weapon_impact_sword_1.ogg")
@export var sfx_block: AudioStream = preload("res://audio/sfx/block.ogg")

## True while the swing is inside its damage window.
var swinging: bool = false
var blocking: bool = false

## Which item is in the hero's hands right now, or &"" for sword and shield.
var equipped: StringName = &""

var _hero: Hero
var _skel: Skeleton3D
## The mounted models. Public so a director can sweep their placement.
var sword: Node3D
var shield: Node3D
var bow: Node3D
var hookshot: Node3D
## id -> {"hand": Node3D, "stow": Node3D}. Exactly one of the pair is visible.
var _items: Dictionary = {}
var _hitbox: Area3D
var _swing_t: float = -1.0
var _hit_this_swing: Dictionary = {}
var _swing_player: AudioStreamPlayer3D
var _impact_player: AudioStreamPlayer3D


func _ready() -> void:
	_hero = get_parent() as Hero
	if _hero == null:
		push_error("HeroCombat must be a child of the Hero")
		return
	_skel = _hero.skeleton()
	if _skel == null:
		push_error("HeroCombat: no Skeleton3D on the rig")
		return
	# Sharpening is bought in town and has to survive the scene change, so the
	# permanent part lives on Game and the export is only the base blade.
	damage += Game.sword_bonus
	_mount_loadout()
	_build_hitbox()
	_build_audio()


# --- Loadout ----------------------------------------------------------------

func _mount_loadout() -> void:
	# Right hand holds the sword. Mixamo's hand bone runs along the fingers, so
	# the blade is rolled onto that axis and pitched forward to clear the wrist.
	# Right hand holds the sword. The z=-90 is the roll that stands the blade up
	# out of the fist; without it the blade lies over at 45 degrees and the whole
	# pose reads off-kilter even though the grip is in exactly the right place.
	sword = _mount(sword_id, &"mixamorig_RightHand",
		Vector3(0.0, 0.04, 0.02), Vector3(-96.0, 6.0, -90.0))
	# The shield rides the left forearm, not the hand — that is how it sits in
	# the block clips, and hanging it off the hand makes it swing like a paddle.
	# Its origin is the CENTRE of the disc, so it needs pushing off the arm.
	#
	# TWO axes were wrong, which is why the first fix only half worked.
	#   y=180 decides which face meets the blow. At 0 the hero presents the
	#         wooden inner face and its arm straps to the enemy.
	#   z=-90 decides which way the kite point hangs. At 0 the shield lies on its
	#         side with the point sticking out sideways -- the "off kilter" read.
	#         At +90 it stands up but INVERTED, point at the sky. -90 is the one
	#         that hangs the point at the hero's knee, where it belongs.
	# tools/directors/shield_lookdev.gd renders the roll candidates side by side.
	shield = _mount(shield_id, &"mixamorig_LeftForeArm",
		Vector3(0.10, 0.02, 0.0), Vector3(0.0, 180.0, -90.0))

	# The hookshot and the bow each get TWO mounts: one in the hand for when
	# they are equipped, one stowed on the body for when they are not. Carrying
	# the gear visibly is most of what makes a character read as an adventurer
	# rather than a man who happens to be holding a sword, and it means the item
	# buttons have something to animate between instead of a pop-in.
	_mount_item(&"hookshot", hookshot_id,
		&"mixamorig_RightHand", Vector3(0.0, 0.05, 0.02), Vector3(-96.0, 6.0, 0.0),
		&"mixamorig_Hips", Vector3(-0.16, 0.02, 0.10), Vector3(0.0, 0.0, -90.0))
	_mount_item(&"bow", bow_id,
		&"mixamorig_LeftHand", Vector3(0.0, 0.04, 0.0), Vector3(-96.0, 0.0, 90.0),
		&"mixamorig_Spine2", Vector3(0.0, 0.06, -0.16), Vector3(0.0, 0.0, 28.0))
	hookshot = _items[&"hookshot"]["hand"]
	bow = _items[&"bow"]["hand"]
	_show_equipped()


## Both mounts for one swappable item. Two model instances rather than one that
## gets reparented: reparenting a node out from under a BoneAttachment3D mid-
## frame leaves it at a stale transform for a frame, which reads as the bow
## teleporting through the hero's chest every time you press the button.
func _mount_item(id: StringName, model_id: String,
		hand_bone: StringName, hand_pos: Vector3, hand_rot: Vector3,
		stow_bone: StringName, stow_pos: Vector3, stow_rot: Vector3) -> void:
	_items[id] = {
		"hand": _mount(model_id, hand_bone, hand_pos, hand_rot),
		"stow": _mount(model_id, stow_bone, stow_pos, stow_rot),
	}


## Put `id` in the hero's hands, or pass &"" to go back to sword and shield.
## Pressing the button for what is already held puts it away, which is the
## behaviour every player tries first.
func equip(id: StringName) -> void:
	equipped = &"" if id == equipped else id
	_show_equipped()


func _show_equipped() -> void:
	for id: StringName in _items:
		var pair: Dictionary = _items[id]
		var in_hand := id == equipped
		if pair["hand"] != null:
			(pair["hand"] as Node3D).visible = in_hand
		if pair["stow"] != null:
			(pair["stow"] as Node3D).visible = not in_hand
	# You cannot hold a bow and a sword. The shield stays: it is strapped on.
	if sword != null:
		sword.visible = equipped == &""


## Attach a weapon model to `bone`, undoing the rig's scale so the model keeps
## the true size WeaponModels gave it.
func _mount(id: String, bone: StringName, offset: Vector3, rot_deg: Vector3) -> Node3D:
	var idx := _skel.find_bone(bone)
	if idx < 0:
		push_error("HeroCombat: no bone '%s' on the rig" % bone)
		return null

	var socket := BoneAttachment3D.new()
	socket.name = "Socket_" + String(bone)
	socket.bone_name = String(bone)
	socket.bone_idx = idx
	_skel.add_child(socket)

	var model := WeaponModels.make(id)
	if model == null:
		return null

	var holder := Node3D.new()
	holder.name = id
	holder.position = offset
	holder.rotation_degrees = rot_deg
	# Measure the accumulated scale rather than assuming K.HERO_SCALE: the rig
	# may carry its own import scale on top of the Model node's.
	var world_scale := socket.global_transform.basis.get_scale()
	var s := (world_scale.x + world_scale.y + world_scale.z) / 3.0
	if s > 0.0001:
		holder.scale = Vector3.ONE / s
	holder.add_child(model)
	socket.add_child(holder)
	return holder


# --- Hitbox -----------------------------------------------------------------

func _build_hitbox() -> void:
	_hitbox = Area3D.new()
	_hitbox.name = "SwordHitbox"
	_hitbox.add_to_group(&"hitbox")
	_hitbox.collision_layer = K.L_PLAYER_HITBOX
	# Enemies AND the world's interactables, so a training post registers before
	# a single enemy exists.
	_hitbox.collision_mask = K.L_ENEMY | K.L_INTERACT
	_hitbox.monitoring = false
	_hitbox.monitorable = false

	var shape := CollisionShape3D.new()
	var box := SphereShape3D.new()
	box.radius = reach * 0.62
	shape.shape = box
	# Sat out in front of the hero at chest height: a sphere on the origin would
	# hit things behind him, which is how a clone ends up with a sword that
	# damages what it visibly missed.
	shape.position = Vector3(0.0, 1.0, -reach * 0.55)
	_hitbox.add_child(shape)
	add_child(_hitbox)


func _build_audio() -> void:
	_swing_player = AudioStreamPlayer3D.new()
	_swing_player.stream = sfx_swing
	_swing_player.bus = &"SFX"
	_swing_player.unit_size = 5.0
	add_child(_swing_player)

	_impact_player = AudioStreamPlayer3D.new()
	_impact_player.stream = sfx_impact
	_impact_player.bus = &"SFX"
	_impact_player.unit_size = 6.0
	add_child(_impact_player)


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _hero == null:
		return

	# A shop or a fade owns the buttons while it is up. The swing already in
	# flight still finishes below -- cancelling it would leave the hitbox on.
	var locked := Prompt != null and Prompt.blocked

	# The shield is held, not toggled, and it drops the moment you commit to a
	# swing — you cannot hide behind it and attack out of it.
	var want_block := not locked and Input.is_action_pressed(&"shield") and _swing_t < 0.0
	if want_block != blocking:
		blocking = want_block
		_hero.set_blocking(blocking)

	if not locked:
		if Input.is_action_just_pressed(&"item_left"):
			equip(&"hookshot")
		if Input.is_action_just_pressed(&"item_right"):
			equip(&"bow")
		if Input.is_action_just_pressed(&"attack"):
			_try_swing()

	if _swing_t >= 0.0:
		_advance_swing(delta)


func _try_swing() -> void:
	if _swing_t >= 0.0:
		return
	# The sword is stowed while an item is out, so a swing here would deal
	# damage with an invisible blade.
	if equipped != &"":
		return
	if not _hero.request_attack(swing_time):
		return
	_swing_t = 0.0
	_hit_this_swing.clear()
	_swing_player.pitch_scale = randf_range(0.94, 1.07)
	_swing_player.play()


func _advance_swing(delta: float) -> void:
	_swing_t += delta
	var frac := _swing_t / maxf(swing_time, 0.01)

	var live := frac >= damage_window.x and frac <= damage_window.y
	if live != swinging:
		swinging = live
		_hitbox.monitoring = live
	if live:
		_scan()

	if frac >= 1.0:
		_swing_t = -1.0
		swinging = false
		_hitbox.monitoring = false


## Damage anything overlapping, once per swing, and only if it is actually in
## front of the hero. The sphere is generous on purpose so a near-miss connects;
## the arc test is what stops it becoming an omnidirectional aura.
func _scan() -> void:
	for body in _hitbox.get_overlapping_bodies():
		_maybe_hit(body)
	for area in _hitbox.get_overlapping_areas():
		_maybe_hit(area)


func _maybe_hit(node: Node) -> void:
	if node == null or node == _hero or _hero.is_ancestor_of(node):
		return
	var id := node.get_instance_id()
	if _hit_this_swing.has(id):
		return

	var target := node as Node3D
	if target == null:
		return
	var to := K.flat(target.global_position - _hero.global_position)
	if to != Vector3.ZERO:
		var fwd := -_hero.global_transform.basis.z
		if rad_to_deg(fwd.angle_to(to)) > arc_degrees * 0.5:
			return

	var victim := _damageable(target)
	if victim == null:
		return

	_hit_this_swing[id] = true
	var hit := Hit.make(damage, _hero.global_position, &"sword", knockback)
	var landed = victim.apply_hit(hit)
	# apply_hit returns bool on a HealthComponent and null on the duck-typed
	# props that predate it, so absence of a false is treated as a landed blow.
	if landed == false:
		return

	_impact_player.pitch_scale = randf_range(0.92, 1.08)
	_impact_player.play()
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)


## Find whatever on or under `node` answers the damage contract. Props built
## before HealthComponent existed implement apply_hit directly, and the training
## posts are exactly that case.
func _damageable(node: Node) -> Node:
	if node.has_method(&"apply_hit"):
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null


# --- Queries for other packages ---------------------------------------------

## Would a blow arriving from `from_pos` be stopped by the raised shield?
## The cone is generous but strictly frontal — OOT does not let you block your
## own back, and being punished for turning away is the point of the shield.
func blocks(from_pos: Vector3) -> bool:
	if not blocking or _hero == null:
		return false
	var to := K.flat(from_pos - _hero.global_position)
	if to == Vector3.ZERO:
		return false
	var fwd := -_hero.global_transform.basis.z
	return rad_to_deg(fwd.angle_to(to)) <= block_cone


## Play the clang and tell the world. The blocker calls this so a blocked blow
## reads differently from one that never arrived.
func on_blocked(at: Vector3, normal: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = sfx_block
	p.bus = &"SFX"
	p.unit_size = 6.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	Bus.shield_blocked.emit(at, normal)
