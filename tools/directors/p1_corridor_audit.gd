extends RefCounted
## P1 — the numeric half of the corridor proof. Runs headless (no captures).
##
## Drives the same path as p1_corridor.gd — north through the 2.4 m doorway, down
## the 4 m corridor to the end wall, then a hard reversal and back out — and
## twice a second prints where the hero actually is, where the camera ended up,
## and the one question a contact sheet cannot answer: is the camera's eye INSIDE
## geometry? A camera that has clipped through a wall is a camera whose eye is in
## solid, and that is a yes/no test, not a matter of taste.
##
## `near` is also checked, because an eye 4 cm from a wall renders the far side
## just as badly as an eye 4 cm past it.
##
##   godot --headless --path . -s tools/shoot.gd -- \
##       --scene=res://scenes/rooms/playtest.tscn \
##       --director=res://tools/directors/p1_corridor_audit.gd --warmup=20

func run(rig) -> void:
	var hero: Node3D = rig.get_first_node_in_group(&"player")
	var cam: Camera3D = rig.root.get_camera_3d()
	var space := hero.get_world_3d().direct_space_state

	var probe := SphereShape3D.new()
	probe.radius = 0.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = K.L_WORLD

	var inside := 0
	var too_near := 0
	var boom_min := 1e9
	var samples := 0

	await rig.wait_seconds(0.4)
	Input.action_press(&"move_up", 1.0)
	await _leg(rig, hero, cam, space, q, "N", 75)
	Input.action_release(&"move_up")
	await rig.wait_seconds(0.3)
	Input.action_press(&"move_down", 1.0)
	await _leg(rig, hero, cam, space, q, "S", 60)
	Input.action_release(&"move_down")

	print("CAM_AUDIT eye_in_solid=%d near_clip_risk=%d boom_min=%.2f samples=%d"
			% [_inside, _near, _boom_min, _samples])


var _inside := 0
var _near := 0
var _boom_min := 1e9
var _samples := 0


func _leg(rig, hero: Node3D, cam: Camera3D, space: PhysicsDirectSpaceState3D,
		q: PhysicsShapeQueryParameters3D, tag: String, steps: int) -> void:
	for i in steps:
		await rig.wait_seconds(0.1)
		_samples += 1
		q.transform = Transform3D(Basis(), cam.global_position)
		var solid := space.intersect_shape(q, 1).size() > 0
		if solid:
			_inside += 1
		# Nearest surface to the eye in the six axis directions.
		var nearest := 99.0
		for d in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
				Vector3.UP, Vector3.DOWN]:
			var rq := PhysicsRayQueryParameters3D.create(
					cam.global_position, cam.global_position + d * 1.0)
			rq.collision_mask = K.L_WORLD
			var h := space.intersect_ray(rq)
			if not h.is_empty():
				nearest = minf(nearest, cam.global_position.distance_to(h.position))
		if nearest < 0.12:
			_near += 1
		var eye := hero.global_position + Vector3.UP * K.HERO_EYE_Y
		var boom := cam.global_position.distance_to(eye)
		_boom_min = minf(_boom_min, boom)
		if i % 10 == 0:
			print("%s%02d hero=(%6.2f,%7.2f) face=%6.1f wall=%s | cam=(%6.2f,%5.2f,%7.2f) yaw=%6.1f swing=%5.1f lift=%4.1f boom=%4.2f nearest=%5.2f solid=%s"
					% [tag, i, hero.global_position.x, hero.global_position.z,
						rad_to_deg(hero.get(&"facing_yaw")), hero.is_on_wall(),
						cam.global_position.x, cam.global_position.y,
						cam.global_position.z, rad_to_deg(cam.get(&"_yaw")),
						cam.get(&"_swing_bias_deg"), cam.get(&"_lift_bias_deg"),
						boom, nearest, solid])
