class_name EnemyRagdoll
extends RefCounted
## Runtime physical-bone rig shared by every ordinary monster.
##
## The monster GLBs all expose the same humanoid bone names, but they arrive at
## very different source scales. PhysicalBone3D cannot safely simulate under
## that scaled render hierarchy, so physics runs on an unscaled proxy skeleton
## with metre-sized rests and copies its pose back onto the visual skeleton.

const BONE_CHAINS: Array[Array] = [
	[&"Hips", &"Spine02"],
	[&"Spine02", &"Spine01"],
	[&"Spine01", &"Spine"],
	[&"Spine", &"neck"],
	[&"neck", &"Head"],
	[&"Head", &"head_end"],
	[&"LeftShoulder", &"LeftArm"],
	[&"LeftArm", &"LeftForeArm"],
	[&"LeftForeArm", &"LeftHand"],
	[&"RightShoulder", &"RightArm"],
	[&"RightArm", &"RightForeArm"],
	[&"RightForeArm", &"RightHand"],
	[&"LeftUpLeg", &"LeftLeg"],
	[&"LeftLeg", &"LeftFoot"],
	[&"LeftFoot", &"LeftToeBase"],
	[&"RightUpLeg", &"RightLeg"],
	[&"RightLeg", &"RightFoot"],
	[&"RightFoot", &"RightToeBase"],
]

const HINGE_BONES: Array[StringName] = [
	&"LeftForeArm", &"RightForeArm", &"LeftLeg", &"RightLeg",
]
const ROOT_BONE := &"Hips"
const MIN_BONES := 14

var _visual_skeleton: Skeleton3D = null
var _skeleton: Skeleton3D = null
var _simulator: PhysicalBoneSimulator3D = null
var _bodies: Array[PhysicalBone3D] = []
var _active: bool = false
var _recovering: bool = false
var _recovery: Tween = null
var _carrier_position: Vector3 = Vector3.ZERO
var _fit_scale: float = 1.0
var _blend_weight: float = 1.0


## Builds the inactive rig. Returns false rather than leaving a partial physics
## tree behind when an imported model no longer matches the shared skeleton.
func setup(model: Node3D, actor: PhysicsBody3D, fit_scale: float,
		world_layer: int) -> bool:
	if model == null or actor == null or fit_scale <= 0.0:
		return false
	_visual_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _visual_skeleton == null:
		return false
	_fit_scale = fit_scale

	# The imported model root is uniformly fitted from centimetre-ish source
	# units. A RigidBody below that transform acquires invalid scale, so mirror the
	# bone tree beside the model and bake the fit only into rest translations.
	_skeleton = Skeleton3D.new()
	_skeleton.name = "EnemyRagdollProxy"
	actor.add_child(_skeleton)
	var proxy_global := _visual_skeleton.global_transform
	proxy_global.basis = proxy_global.basis.orthonormalized()
	_skeleton.global_transform = proxy_global
	for bone_id: int in range(_visual_skeleton.get_bone_count()):
		_skeleton.add_bone(_visual_skeleton.get_bone_name(bone_id))
		_skeleton.set_bone_parent(bone_id, _visual_skeleton.get_bone_parent(bone_id))
		var rest := _visual_skeleton.get_bone_rest(bone_id)
		rest.origin *= _fit_scale
		_skeleton.set_bone_rest(bone_id, rest)

	_simulator = PhysicalBoneSimulator3D.new()
	_simulator.name = "EnemyRagdoll"
	_skeleton.add_child(_simulator)

	for chain: Array in BONE_CHAINS:
		var bone_name := chain[0] as StringName
		var child_name := chain[1] as StringName
		var body := _make_body(bone_name, child_name, world_layer)
		if body != null:
			_bodies.append(body)

	if _bodies.size() < MIN_BONES:
		_clear_partial_rig()
		return false

	# The CharacterBody owns the launch arc. Its articulated children may strike
	# the room, but never the carrier or one another -- self-collision turns a
	# compact humanoid rig into an exploding pile on its first simulation frame.
	_simulator.physical_bones_add_collision_exception(actor.get_rid())
	for i: int in range(_bodies.size()):
		for j: int in range(i + 1, _bodies.size()):
			_bodies[i].add_collision_exception_with(_bodies[j])

	for body: PhysicalBone3D in _bodies:
		if body.get_bone_id() < 0:
			_clear_partial_rig()
			return false
	return true


func _make_body(bone_name: StringName, child_name: StringName,
		world_layer: int) -> PhysicalBone3D:
	var bone_id := _skeleton.find_bone(bone_name)
	var child_id := _skeleton.find_bone(child_name)
	if bone_id < 0 or child_id < 0 or _skeleton.get_bone_parent(child_id) != bone_id:
		return null

	# This is Godot 4.7's own Skeleton3D editor construction, reproduced at
	# runtime so all nine generated monster instances receive the same rig.
	var child_rest := _skeleton.get_bone_rest(child_id)
	var half_height := child_rest.origin.length() * 0.5
	if half_height <= 0.00001:
		return null
	var direction := child_rest.origin.normalized()
	var up := Vector3.UP
	# Imported bone lengths are centimetre-scale before fitting, so testing the
	# raw cross product makes "parallel" depend on source units. Compare unit
	# directions instead, then keep a second fallback for a forward-pointing bone.
	if absf(up.dot(direction)) > 0.999:
		up = Vector3.FORWARD
	if absf(up.dot(direction)) > 0.999:
		up = Vector3.RIGHT
	var body_basis := Basis.looking_at(child_rest.origin, up)
	var body_offset := Transform3D(body_basis,
		body_basis * Vector3(0.0, 0.0, -half_height))
	var joint_offset := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, half_height))

	var body := PhysicalBone3D.new()
	body.name = "Physical Bone %s" % bone_name
	body.body_offset = body_offset
	body.joint_offset = joint_offset
	body.mass = 0.75
	body.friction = 0.85
	body.bounce = 0.08
	body.linear_damp = 0.35
	body.angular_damp = 1.2
	body.gravity_scale = 0.0
	body.collision_layer = 0
	body.collision_mask = world_layer
	_simulator.add_child(body)
	body.set(&"bone_name", bone_name)
	if bone_name != ROOT_BONE:
		body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE \
			if bone_name in HINGE_BONES else PhysicalBone3D.JOINT_TYPE_CONE

	var capsule := CapsuleShape3D.new()
	capsule.height = half_height * 2.0
	capsule.radius = half_height * 0.2
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = capsule
	# CapsuleShape3D points along Y; the editor rotates it onto the bone's -Z.
	shape.basis = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0),
		Vector3(0.0, 1.0, 0.0))
	body.add_child(shape)
	return body


func _clear_partial_rig() -> void:
	_bodies.clear()
	if _visual_skeleton != null:
		_visual_skeleton.clear_bones_global_pose_override()
	if _skeleton != null:
		_skeleton.queue_free()
	_simulator = null
	_skeleton = null
	_visual_skeleton = null


func is_ready() -> bool:
	return _simulator != null and _bodies.size() >= MIN_BONES


func is_active() -> bool:
	return _active


func is_recovering() -> bool:
	return _recovering


func physical_bone_count() -> int:
	return _bodies.size()


## Hands translation to the existing CharacterBody arc while the physical bones
## own articulation. This preserves the launch players already like and avoids
## two independent gravity/bounce solvers drifting the mesh away from its actor.
func start(carrier_position: Vector3, carrier_velocity: Vector3,
		spin_axis: Vector3, spin_speed: float) -> bool:
	if not is_ready():
		return false
	if _recovery != null and _recovery.is_valid():
		_recovery.kill()
	_recovery = null
	_recovering = false
	_blend_weight = 1.0
	# Enter physics from the exact animation pose on the impact frame. Positions
	# are baked into proxy metres; rotations are already scale-independent.
	for bone_id: int in range(_visual_skeleton.get_bone_count()):
		var pose := _visual_skeleton.get_bone_global_pose_no_override(bone_id)
		pose.origin *= _fit_scale
		_skeleton.set_bone_global_pose(bone_id, pose)
	_skeleton.force_update_all_bone_transforms()
	_simulator.physical_bones_start_simulation()
	_active = true
	_carrier_position = carrier_position
	var axis := spin_axis.normalized() if not spin_axis.is_zero_approx() else Vector3.RIGHT
	for i: int in range(_bodies.size()):
		var body := _bodies[i]
		var bone_name := String(body.get(&"bone_name"))
		var limb_kick := Vector3.ZERO
		if "Shoulder" in bone_name or "Arm" in bone_name:
			limb_kick += Vector3.UP * 1.15
		elif "Leg" in bone_name or "Foot" in bone_name:
			limb_kick -= Vector3.UP * 0.35
		if bone_name.begins_with("Left"):
			limb_kick -= axis * 0.45
		elif bone_name.begins_with("Right"):
			limb_kick += axis * 0.45
		body.linear_velocity = carrier_velocity + limb_kick
		# Deterministic differences let the joints break up the old rigid
		# somersault without making repeatable launch tests depend on random state.
		var variation := 0.45 + float(i % 5) * 0.24
		var cross_axis := axis.cross(Vector3.UP).normalized()
		body.angular_velocity = axis * spin_speed * variation \
			+ cross_axis * spin_speed * (float((i % 3) - 1) * 0.28)
	_apply_visual_pose()
	return true


## Called after the carrier moves. PhysicalBone3D owns rotations and contacts;
## the driven hips keep the jointed rig in the CharacterBody's frame.
func drive(carrier_position: Vector3, delta: float) -> void:
	if not _active or delta <= 0.0:
		return
	var carrier_velocity := (carrier_position - _carrier_position) / delta
	_carrier_position = carrier_position
	# Drive only the hips. Giving every segment the exact same velocity on every
	# frame mathematically forbids the relative motion a ragdoll needs; the joints
	# carry the limbs along while leaving them free to lag, fold and hit the room.
	if not _bodies.is_empty():
		_bodies[0].linear_velocity = carrier_velocity
	# Rigid-body transforms already contain the preceding Jolt step here. The
	# visual copy is intentionally immediate so teardown never leaves a queued
	# callback retaining a freed enemy rig.
	_apply_visual_pose()


func _apply_visual_pose() -> void:
	if not is_instance_valid(_visual_skeleton) or not is_instance_valid(_skeleton):
		return
	var to_proxy := _skeleton.global_transform.affine_inverse()
	for body: PhysicalBone3D in _bodies:
		var bone_id := body.get_bone_id()
		if bone_id < 0:
			continue
		# PhysicalBoneSimulator3D is a modifier: its result is prepared for the
		# renderer and is not returned by `Skeleton3D.get_bone_global_pose()` here.
		# Reconstruct the same bone pose directly from the simulated rigid body.
		var pose := to_proxy * body.global_transform * body.body_offset.affine_inverse()
		pose.origin /= _fit_scale
		_visual_skeleton.set_bone_global_pose_override(
			bone_id, pose, _blend_weight, true)


## Reveal the playing get-up pose underneath the simulator, then stop physics.
func recover(host: Node, duration: float = 0.32) -> void:
	if not _active or _recovering or host == null:
		return
	_recovering = true
	_recovery = host.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_recovery.tween_property(self, ^"_blend_weight", 0.0, duration)
	_recovery.tween_callback(_finish_recovery)


func _finish_recovery() -> void:
	if is_instance_valid(_simulator):
		_simulator.physical_bones_stop_simulation()
	if is_instance_valid(_visual_skeleton):
		_visual_skeleton.clear_bones_global_pose_override()
	_blend_weight = 1.0
	_active = false
	_recovering = false
	_recovery = null


## Immediate reset for freeze/despawn paths which cannot wait for a blend.
func stop() -> void:
	if _recovery != null and _recovery.is_valid():
		_recovery.kill()
	_recovery = null
	if is_instance_valid(_simulator):
		_simulator.physical_bones_stop_simulation()
	if is_instance_valid(_visual_skeleton):
		_visual_skeleton.clear_bones_global_pose_override()
	_blend_weight = 1.0
	_active = false
	_recovering = false


## Freeze the last simulated pose in skeleton space before the corpse's authored
## sink tween. Stopping without clearing the overrides makes the whole pose ride
## its CharacterBody downward; live world contacts would pin it to the floor and
## make the actor sink invisibly out from under its own mesh.
func settle_for_cleanup() -> void:
	if not _active:
		return
	_apply_visual_pose()
	if is_instance_valid(_simulator):
		_simulator.physical_bones_stop_simulation()
	_active = false
	_recovering = false
