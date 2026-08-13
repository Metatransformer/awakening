extends RefCounted
## Four Ocarina-style enemy questions in tool order. This director proves the
## implementation facts and photographs the player-facing shapes; it does not
## claim that a cold player understands them (that belongs to the human test in
## docs/design-tests/ENEMY_TOOL_LADDER_PROOF.md).
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/signature_enemies.gd \
##     --out=/tmp/signature-enemies/x.png --warmup=60

const HERO_PARK := Vector3(0.0, 0.05, 28.0)
const RANK_Z := 2.5
const RANK_X: Array[float] = [-4.8, -1.7, 1.5, 4.8]
const VARIANTS: Array[Dictionary] = [
	{"kind": &"goblin", "behaviour": &"knotback", "name": &"KNOTBACK",
		"tool": &"sword"},
	{"kind": &"kobold", "behaviour": &"lantern_seer", "name": &"LANTERN SEER",
		"tool": &"bow"},
	{"kind": &"knight_iron", "behaviour": &"cinder_automaton",
		"name": &"CINDER AUTOMATON", "tool": &"burst"},
	{"kind": &"troll", "behaviour": &"mirebell", "name": &"MIREBELL",
		"tool": &"hookshot"},
]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/signature-enemies/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = HERO_PARK
	hero.visible = false
	_hide_npcs(scene)

	_manifest(rig)
	var made: Array[Enemy] = await _spawn_rank(scene, rig)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	await _look(rig, cam, Vector3(0.0, 2.4, 12.0),
		Vector3(0.0, 1.25, RANK_Z), 57.0)
	await rig.capture(out.path_join("signature_00_lineup.png"))

	# Hold the staged bodies still while each public damage contract is measured.
	for foe in made:
		foe.set_physics_process(false)

	await _knotback(rig, out, cam, made, hero)
	await _lantern_seer(rig, out, cam, made, hero)
	await _cinder_automaton(rig, out, cam, made, hero)
	await _mirebell(rig, out, cam, made, hero)
	await _ordinary_finishes(rig, scene)
	print("SIGNATURE ENEMIES proof complete")


func _manifest(rig) -> void:
	rig.check(Enemy.DEFS.size() == 7,
		"signature variants grew Enemy.DEFS to %d rows" % Enemy.DEFS.size())
	for i in VARIANTS.size():
		var row: Dictionary = FloorDb.signature(i + 1)
		var want: Dictionary = VARIANTS[i]
		rig.check(StringName(row.get("kind", &"")) == StringName(want["kind"]),
			"floor %d signature body is %s, expected %s" % [i + 1,
				row.get("kind", &""), want["kind"]])
		rig.check(StringName(row.get("behaviour", &""))
			== StringName(want["behaviour"]),
			"floor %d signature behaviour is %s, expected %s" % [i + 1,
				row.get("behaviour", &""), want["behaviour"]])
		var share := float(row.get("share", 0.0))
		rig.check(share > 0.0 and share < 1.0,
			"floor %d signature share %.2f is not a room-level chance" % [i + 1, share])
	rig.check(FloorDb.signature(5).is_empty(),
		"endless mode inherited an authored signature variant")


func _spawn_rank(scene: Node, rig) -> Array[Enemy]:
	var made: Array[Enemy] = []
	for i in VARIANTS.size():
		var row: Dictionary = VARIANTS[i]
		var foe := Enemy.new()
		foe.kind = StringName(row["kind"])
		foe.behaviour = StringName(row["behaviour"])
		foe.drop_seed = 2000 + i
		foe.level = i + 1
		scene.add_child(foe)
		foe.global_position = Vector3(RANK_X[i], 0.05, RANK_Z)
		# Knotback presents its rear knot; the other three present their face/core.
		foe._facing = 0.0 if i == 0 else PI
		foe.rotation.y = foe._facing
		made.append(foe)
	await rig.wait_frames(36)
	for i in made.size():
		var foe: Enemy = made[i]
		var row: Dictionary = VARIANTS[i]
		rig.check(foe.is_signature_enemy(), "%s did not resolve as a signature"
			% row["behaviour"])
		rig.check(foe.signature_name() == StringName(row["name"]),
			"%s reports the wrong player-facing name" % row["behaviour"])
		rig.check(foe.signature_tool() == StringName(row["tool"]),
			"%s reports the wrong tool answer" % row["behaviour"])
		var look := foe.get_node_or_null("SignatureLook")
		rig.check(look != null and _mesh_count(look) >= 4,
			"%s has no readable primitive silhouette" % row["behaviour"])
	return made


func _knotback(rig, out: String, cam: Camera3D, made: Array[Enemy],
		hero: Node3D) -> void:
	var foe := made[0]
	_solo(made, 0)
	var chip := await _land(rig, foe, Hit.make(2, foe.global_position + Vector3.BACK,
		&"sword"))
	rig.check(chip == K.HEALTH_POINT,
		"closed Knotback sword changed %d HP; the slower answer must still chip 1" % chip)
	foe._enter_recover(1.0)
	rig.check(foe.signature_exposure() >= 0.99,
		"Knotback recovery did not expose the rear knot")
	foe._facing = 0.0
	foe.rotation.y = 0.0
	await _portrait(rig, cam, foe)
	await rig.capture(out.path_join("signature_01_knotback_open.png"))
	var punish := await _land(rig, foe, Hit.make(2,
		foe.global_position + Vector3.BACK, &"sword"))
	rig.check(punish > chip,
		"Knotback open sword (%d HP) did not beat closed chip (%d HP)" % [punish, chip])
	hero.global_position = HERO_PARK


func _lantern_seer(rig, out: String, cam: Camera3D, made: Array[Enemy],
		hero: Node3D) -> void:
	var foe := made[1]
	_solo(made, 1)
	var chip := await _land(rig, foe, Hit.make(2, foe.global_position + Vector3.BACK,
		&"sword"))
	rig.check(chip == K.HEALTH_POINT,
		"closed Lantern Seer sword changed %d HP; ordinary damage must still work" % chip)
	hero.global_position = foe.global_position + Vector3(0.0, 0.0, 5.2)
	foe.state = Enemy.State.CHASE
	foe._cooldown = 0.0
	foe.set_physics_process(true)
	var charged: bool = await rig.until(func() -> bool:
		return foe.state == Enemy.State.SEER_WINDUP, 3.0)
	if not rig.check(charged, "Lantern Seer never entered its room-range wind-up"):
		foe.set_physics_process(false)
		return
	await rig.wait_seconds(0.42)
	rig.check(foe.signature_exposure() > 0.0,
		"Lantern Seer eye was not open during its traced charge")
	await _portrait(rig, cam, foe)
	await rig.capture(out.path_join("signature_02_lantern_seer_charge.png"))
	var before := foe.health.health_points
	var landed := foe.apply_hit(Hit.make(2, hero.global_position, Hit.ARROW,
		K.KNOCKBACK_LIGHT, 0.1))
	var punish := before - foe.health.health_points
	rig.check(landed and punish > chip,
		"Lantern Seer open arrow (%d HP) did not beat ordinary chip (%d HP)"
			% [punish, chip])
	rig.check(foe.state == Enemy.State.HURT or foe.state == Enemy.State.LAUNCHED,
		"Lantern Seer arrow did not cancel the charged line")
	foe.set_physics_process(false)
	hero.global_position = HERO_PARK


func _cinder_automaton(rig, out: String, cam: Camera3D, made: Array[Enemy],
		hero: Node3D) -> void:
	var foe := made[2]
	_solo(made, 2)
	var chip := await _land(rig, foe, Hit.make(2, foe.global_position + Vector3.BACK,
		&"sword"))
	rig.check(chip == K.HEALTH_POINT,
		"closed Cinder Automaton changed %d HP; ordinary damage must still work" % chip)
	var burst := await _land(rig, foe, Hit.make(K.BOMB_DAMAGE,
		foe.global_position + Vector3.BACK, &"bomb", K.KNOCKBACK_LIGHT, 0.1))
	rig.check(burst > chip,
		"Cinder Automaton Burst (%d HP) did not beat ordinary chip (%d HP)"
			% [burst, chip])
	rig.check(foe.signature_exposure() >= 3.4,
		"Cinder Automaton Burst did not leave a long vent opening")
	foe._facing = PI
	foe.rotation.y = PI
	await _portrait(rig, cam, foe)
	await rig.capture(out.path_join("signature_03_cinder_automaton_open.png"))
	hero.global_position = HERO_PARK


func _mirebell(rig, out: String, cam: Camera3D, made: Array[Enemy],
		hero: Node3D) -> void:
	var foe := made[3]
	_solo(made, 3)
	var chip := await _land(rig, foe, Hit.make(2, foe.global_position + Vector3.BACK,
		&"sword"))
	rig.check(chip == K.HEALTH_POINT,
		"closed Mirebell changed %d HP; ordinary damage must still work" % chip)
	foe.freeze(K.HOOK_FREEZE)
	rig.check(foe.signature_exposure() >= K.HOOK_FREEZE + 1.1,
		"Mirebell hookshot freeze did not tear open a long core window")
	foe._facing = PI
	foe.rotation.y = PI
	await _portrait(rig, cam, foe)
	await rig.capture(out.path_join("signature_04_mirebell_hooked.png"))
	var punish := await _land(rig, foe, Hit.make(2,
		foe.global_position + Vector3.BACK, &"sword"))
	rig.check(punish > chip,
		"Mirebell hooked-core sword (%d HP) did not beat ordinary chip (%d HP)"
			% [punish, chip])
	hero.global_position = HERO_PARK


## Progress is not enough for the no-hard-lock claim: repeat the closed-shell
## answer through the real HealthComponent until each fresh body actually dies.
func _ordinary_finishes(rig, scene: Node) -> void:
	for i in VARIANTS.size():
		var row: Dictionary = VARIANTS[i]
		var foe := Enemy.new()
		foe.kind = StringName(row["kind"])
		foe.behaviour = StringName(row["behaviour"])
		foe.drop_seed = 2400 + i
		foe.level = i + 1
		scene.add_child(foe)
		foe.global_position = Vector3(-18.0 - float(i) * 2.0, 0.05, -12.0)
		foe.visible = false
		foe.set_physics_process(false)
		var blows := 0
		while not foe.health.dead and blows < 80:
			var landed := foe.apply_hit(Hit.make(2,
				foe.global_position + Vector3.BACK, &"sword"))
			if not landed:
				rig.fail("%s ordinary finish was swallowed outside its i-frame"
					% row["name"])
				break
			blows += 1
			if not foe.health.dead:
				await rig.wait_seconds(K.ENEMY_IFRAME_TIME + 0.02)
		rig.check(foe.health.dead,
			"%s survived %d closed-shell ordinary hits" % [row["name"], blows])
		print("SIGNATURE ordinary finish %-18s %d hits" % [row["name"], blows])


func _land(rig, foe: Enemy, hit: Hit) -> int:
	var before := foe.health.health_points
	var landed := foe.apply_hit(hit)
	var loss := before - foe.health.health_points
	rig.check(landed, "%s refused a valid %s hit" % [foe.signature_name(), hit.kind])
	await rig.wait_seconds(K.ENEMY_IFRAME_TIME + 0.04)
	return loss


func _portrait(rig, cam: Camera3D, foe: Enemy) -> void:
	var at := foe.global_position
	await _look(rig, cam, at + Vector3(0.0, 1.75, 4.2),
		at + Vector3(0.0, minf(1.35, foe._height() * 0.55), 0.0), 43.0)


func _look(rig, cam: Camera3D, eye: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	await rig.wait_frames(8)


func _solo(made: Array[Enemy], index: int) -> void:
	for i in made.size():
		made[i].visible = i == index


func _hide_npcs(scene: Node) -> void:
	for node in scene.find_children("*", "Npc", true, false):
		(node as Node3D).visible = false


func _mesh_count(root: Node) -> int:
	var count := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).mesh != null:
			count += 1
	return count
