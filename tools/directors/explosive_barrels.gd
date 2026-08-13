extends RefCounted
## Card #140 -- reusable explosive barrels and the hanging fire chain.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_atom_test.tscn \
##     --director=res://tools/directors/explosive_barrels.gd \
##     --out=/tmp/explosive_barrels/x.png --warmup=60
##
## The fixture supplies only a lit proving-ground floor, the real hero and the
## camera. This director creates every prop and target itself, at measured
## positions, so each beat has one cause:
##
##   A  A real Arrow reaches a barrel through its child Body and starts a visible
##      fuse before the damaging frame. A sword Hit does the same, and that blast
##      damages both the real hero (`take_hit`) and an enemy-style
##      `HealthComponent` body.
##   B  Three barrels stand just inside neighbour range but with the third beyond
##      the first. One sword Hit produces a real staggered chain; every barrel
##      emits `exploded` exactly once.
##   C  The null control: a sword cannot sever the ceiling lantern. A real Arrow
##      can; the lantern falls under physics, its impact sends a fire Hit through
##      the barrel Body, and that barrel visibly warns before exploding once.
##   D  A real Enemy wearing `behaviour = &"thrower"` discovers an available
##      barrel, walks to it, carries it through a visible wind-up, then releases
##      a live arcing projectile toward the real hero.
##
## Prints `BARREL OK` only after every assertion above has passed.

const FLOOR_Y := 0.02
const OFFSTAGE := Vector3(0.0, 0.0, 40.0)

var _out := "/tmp/explosive_barrels"
var _failed := false
var _counts: Dictionary = {}
var _hero: Node3D
var _camera: Camera3D


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/explosive_barrels/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Game.reset()
	Run.enter(140140)

	if rig.scene().name != &"AtomTest":
		_fail(rig, "wrong host scene (%s)" % rig.scene().name)
		_finish()
		return
	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	if _hero == null:
		_fail(rig, "the fixture has no real hero")
		_finish()
		return
	var gate := rig.scene().get_node_or_null(^"Gate") as Node3D
	if gate != null:
		gate.visible = false
	_camera = _make_camera(rig.scene())

	await _a_direct_hits(rig)
	await _b_three_barrel_chain(rig)
	await _c_hanging_lantern(rig)
	await _d_enemy_thrower(rig)
	_finish()


func _ok(rig, label: String, condition: bool) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_fail(rig, label)


func _fail(rig, label: String) -> void:
	_failed = true
	rig.fail("BARREL %s" % label)


func _finish() -> void:
	if not _failed:
		print("BARREL OK -- every check passed")
	else:
		print("BARREL FAIL -- one or more checks failed")


# --- A. Direct arrow and sword ------------------------------------------------

func _a_direct_hits(rig) -> void:
	_point_camera(Vector3(6.8, 3.8, 6.4), Vector3(-1.5, 0.75, -1.0))
	_park_hero()
	var arrow_barrel := _barrel(rig.scene(), &"ArrowBarrel",
		Vector3(-3.0, FLOOR_Y, -1.0))
	_watch(arrow_barrel, &"arrow")
	await rig.wait_physics_frames(3)

	var arrow := Arrow.new()
	arrow.name = "ProofArrow"
	rig.scene().add_child(arrow)
	var muzzle := Vector3(-3.0, FLOOR_Y + 0.62, 3.0)
	var target := arrow_barrel.global_position + Vector3.UP * 0.56
	arrow.launch(muzzle, target - muzzle)
	var arrow_fused: bool = await rig.until(func() -> bool:
		return is_instance_valid(arrow_barrel) and arrow_barrel.is_fusing(), 1.0)
	_ok(rig, "A0 a real Arrow resolves Body -> apply_hit and lights the fuse",
		arrow_fused)
	_ok(rig, "A1 the direct arrow does not deal an instant surprise blast",
		arrow_fused and _count(&"arrow") == 0)
	await rig.wait_seconds(0.32)
	await rig.capture(_out.path_join("01_arrow_fuse_warning.png"))
	var arrow_blast: bool = await rig.until(func() -> bool:
		return _count(&"arrow") == 1, 2.0)
	_ok(rig, "A2 the arrow-lit barrel explodes once after its warning", arrow_blast)
	await rig.wait_physics_frames(4)
	await rig.capture(_out.path_join("02_arrow_explosion.png"))
	await rig.wait_seconds(0.9)

	# The real hero proves the exceptional `take_hit` branch; this small body is
	# exactly the contract every ordinary enemy exposes to the same query.
	var enemy := _enemy_contract(rig.scene(), Vector3(-1.25, FLOOR_Y, -1.0))
	var hp := enemy.get_node(^"Health") as HealthComponent
	var sword_barrel := _barrel(rig.scene(), &"SwordBarrel",
		Vector3(0.0, FLOOR_Y, -1.0))
	_watch(sword_barrel, &"sword")
	_hero.global_position = Vector3(1.35, FLOOR_Y + 0.03, -1.0)
	_hero.set(&"velocity", Vector3.ZERO)
	_hero.set(&"_invuln", 0.0)
	await rig.wait_physics_frames(4)
	var hero_before := Game.health_points
	var enemy_before := hp.health_points
	sword_barrel.apply_hit(Hit.make(K.HEALTH_POINT,
		sword_barrel.global_position + Vector3.BACK, &"sword"))
	_ok(rig, "A3 a sword Hit starts the same fuse contract",
		sword_barrel.is_fusing() and _count(&"sword") == 0)
	await rig.wait_seconds(0.34)
	await rig.capture(_out.path_join("03_sword_fuse_warning.png"))
	var sword_blast: bool = await rig.until(func() -> bool:
		return _count(&"sword") == 1, 2.0)
	_ok(rig, "A4 the sword-lit barrel explodes exactly once", sword_blast)
	_ok(rig, "A5 its Hit reaches the real hero through take_hit",
		Game.health_points < hero_before)
	_ok(rig, "A6 and reaches an enemy through HealthComponent.apply_hit",
		hp.health_points < enemy_before)
	await rig.wait_physics_frames(4)
	await rig.capture(_out.path_join("04_sword_explosion.png"))
	_park_hero()
	enemy.position = OFFSTAGE
	await rig.wait_seconds(0.9)


# --- B. Three, and only three -------------------------------------------------

func _b_three_barrel_chain(rig) -> void:
	_point_camera(Vector3(7.2, 4.2, 6.5), Vector3(-2.7, 0.72, -1.0))
	var first := _barrel(rig.scene(), &"ChainA", Vector3(-4.25, FLOOR_Y, -1.0))
	var second := _barrel(rig.scene(), &"ChainB", Vector3(-2.7, FLOOR_Y, -1.0))
	var third := _barrel(rig.scene(), &"ChainC", Vector3(-1.15, FLOOR_Y, -1.0))
	_watch(first, &"chain_a")
	_watch(second, &"chain_b")
	_watch(third, &"chain_c")
	await rig.wait_physics_frames(4)
	await rig.capture(_out.path_join("05_three_barrels_intact.png"))

	first.apply_hit(Hit.make(K.HEALTH_POINT, first.global_position + Vector3.BACK,
		&"sword"))
	_ok(rig, "B0 one direct blow lights only the first barrel",
		first.is_fusing() and not second.is_fusing() and not third.is_fusing())
	var first_then_second: bool = await rig.until(func() -> bool:
		return _count(&"chain_a") == 1 and is_instance_valid(second) \
			and second.is_fusing() and _count(&"chain_b") == 0, 2.0)
	_ok(rig, "B1 the first blast starts a shorter visible fuse on its neighbour",
		first_then_second)
	await rig.capture(_out.path_join("06_chain_warning.png"))
	var all_three: bool = await rig.until(func() -> bool:
		return _count(&"chain_a") == 1 and _count(&"chain_b") == 1 \
			and _count(&"chain_c") == 1, 3.0)
	_ok(rig, "B2 the neighbour carries the blast to the out-of-first-range third",
		all_three)
	_ok(rig, "B3 every barrel explodes exactly once",
		_count(&"chain_a") == 1 and _count(&"chain_b") == 1 \
		and _count(&"chain_c") == 1)
	await rig.wait_physics_frames(4)
	await rig.capture(_out.path_join("07_chain_third_explosion.png"))
	await rig.wait_seconds(1.0)


# --- C. Arrow sever, fall, fire ----------------------------------------------

func _c_hanging_lantern(rig) -> void:
	_point_camera(Vector3(6.2, 3.8, 6.4), Vector3(-2.6, 1.75, -1.0))
	var barrel := _barrel(rig.scene(), &"LanternBarrel",
		Vector3(-2.6, FLOOR_Y, -1.0))
	_watch(barrel, &"lantern")
	var lantern := HangingLantern.new()
	lantern.name = "HangingLantern"
	lantern.position = Vector3(-2.6, 4.0, -1.0)
	rig.scene().add_child(lantern)
	await rig.wait_physics_frames(4)

	lantern.apply_hit(Hit.make(K.HEALTH_POINT, lantern.global_position + Vector3.BACK,
		&"sword"))
	_ok(rig, "C0 the control holds: a non-arrow blow does not sever the chain",
		not lantern.has_severed())
	await rig.capture(_out.path_join("08_lantern_hanging_control.png"))

	var shot := Arrow.new()
	shot.name = "LanternArrow"
	rig.scene().add_child(shot)
	var cage := lantern.global_position + Vector3.DOWN * HangingLantern.CHAIN_LENGTH
	var muzzle := cage + Vector3.BACK * 4.0
	shot.launch(muzzle, cage - muzzle)
	var cut: bool = await rig.until(func() -> bool:
		return is_instance_valid(lantern) and lantern.has_severed(), 1.0)
	_ok(rig, "C1 a real Arrow resolves the Body and severs the lantern", cut)
	await rig.wait_physics_frames(8)
	await rig.capture(_out.path_join("09_lantern_falling.png"))

	var fire_landed: bool = await rig.until(func() -> bool:
		return is_instance_valid(lantern) and lantern.has_impacted() \
			and is_instance_valid(barrel) and barrel.is_fusing(), 2.0)
	_ok(rig, "C2 the falling cage impacts the prop and emits a fire Hit",
		fire_landed)
	_ok(rig, "C3 fire still warns before the barrel's damaging frame",
		fire_landed and _count(&"lantern") == 0)
	await rig.capture(_out.path_join("10_lantern_impact_fuse.png"))
	var final_blast: bool = await rig.until(func() -> bool:
		return _count(&"lantern") == 1, 2.0)
	_ok(rig, "C4 the lantern-lit barrel explodes exactly once", final_blast)
	await rig.wait_physics_frames(4)
	await rig.capture(_out.path_join("11_lantern_barrel_explosion.png"))
	await rig.wait_seconds(0.9)


# --- D. Real thrower ---------------------------------------------------------

func _d_enemy_thrower(rig) -> void:
	_point_camera(Vector3(6.8, 4.2, 7.2), Vector3(-0.6, 0.82, -1.0))
	Game.heal(Game.max_health_points)
	_hero.global_position = Vector3(3.0, FLOOR_Y + 0.03, -1.0)
	_hero.set(&"velocity", Vector3.ZERO)
	_hero.set(&"_invuln", 0.0)

	var barrel := _barrel(rig.scene(), &"ThrowerBarrel",
		Vector3(-2.4, FLOOR_Y, -1.0))
	_watch(barrel, &"thrower")
	var thrower := Enemy.new()
	thrower.name = "ProofThrower"
	thrower.kind = &"goblin"
	thrower.drop_seed = 140204
	thrower.level = Prog.FIRST
	thrower.behaviour = &"thrower"
	thrower.position = Vector3(-4.2, FLOOR_Y, -1.0)
	rig.scene().add_child(thrower)
	await rig.wait_physics_frames(3)
	_ok(rig, "D0 the existing Enemy resolved the explicit thrower behaviour",
		thrower.is_thrower())

	var claimed: bool = await rig.until(func() -> bool:
		return is_instance_valid(thrower) and is_instance_valid(barrel) \
			and thrower.state == Enemy.State.THROW_WINDUP \
			and not barrel.is_available(), 2.0)
	_ok(rig, "D1 the thrower walks to and claims an available barrel", claimed)
	await rig.wait_physics_frames(2)
	await rig.capture(_out.path_join("12_thrower_carry.png"))

	# Move during the tell. The release frame, not the pickup frame, owns the aim;
	# this makes the target change visible and proves the arc can be led.
	_hero.global_position = Vector3(3.7, FLOOR_Y + 0.03, -1.8)
	_hero.set(&"velocity", Vector3.ZERO)
	await rig.wait_seconds(0.38)
	_ok(rig, "D2 the claimed barrel remains held through a readable wind-up",
		is_instance_valid(barrel) and not barrel.is_available() \
		and not barrel.is_fusing() and _count(&"thrower") == 0)
	await rig.capture(_out.path_join("13_thrower_windup.png"))

	var left_enemy: bool = await rig.until(func() -> bool:
		return is_instance_valid(thrower) and is_instance_valid(barrel) \
			and not barrel.has_exploded() \
			and K.plane(barrel.global_position - thrower.global_position).length() > 1.4,
		1.2)
	_ok(rig, "D3 throw_from releases a travelling projectile from the enemy",
		left_enemy)
	_ok(rig, "D4 the released barrel is live in flight, not a hitscan blast",
		left_enemy and barrel.is_fusing() and _count(&"thrower") == 0)
	await rig.capture(_out.path_join("14_thrower_flight.png"))

	var exploded_once: bool = await rig.until(func() -> bool:
		return _count(&"thrower") == 1, 2.0)
	_ok(rig, "D5 the thrown barrel reaches its target and explodes exactly once",
		exploded_once and _count(&"thrower") == 1)
	await rig.wait_physics_frames(4)
	await rig.capture(_out.path_join("15_thrower_explosion.png"))
	thrower.queue_free()
	_park_hero()


func _barrel(parent: Node, prop_name: StringName, at: Vector3) -> ExplosiveBarrel:
	var barrel := ExplosiveBarrel.new()
	barrel.name = prop_name
	barrel.position = at
	parent.add_child(barrel)
	return barrel


func _watch(barrel: ExplosiveBarrel, key: StringName) -> void:
	_counts[key] = 0
	barrel.exploded.connect(func(_at: Vector3) -> void:
		_counts[key] = int(_counts.get(key, 0)) + 1)


func _count(key: StringName) -> int:
	return int(_counts.get(key, 0))


func _enemy_contract(parent: Node, at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "EnemyContract"
	body.position = at
	body.collision_layer = K.L_ENEMY
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.30
	shape_node.shape = shape
	shape_node.position.y = 0.65
	body.add_child(shape_node)
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_health_points = 16
	health.iframe_time = 0.0
	body.add_child(health)
	parent.add_child(body)
	return body


func _make_camera(parent: Node) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "BarrelProofCamera"
	camera.fov = 58.0
	parent.add_child(camera)
	camera.make_current()
	return camera


func _point_camera(at: Vector3, target: Vector3) -> void:
	_camera.global_position = at
	_camera.look_at(target, Vector3.UP)


func _park_hero() -> void:
	_hero.global_position = Vector3(0.0, FLOOR_Y + 0.03, 7.0)
	_hero.set(&"velocity", Vector3.ZERO)
