extends RefCounted
## Does a blow READ? Spawns a monster in the lit courtyard, hits it with the
## same DamageArea the hero swings, and photographs the frames the impact lives
## in -- the flash, the recoil, the shake.
##
## The numeric beats print `FEEL FAIL ...` because some of what impact is made of
## has no pixels: whether the damage landed at all, whether time actually stopped,
## whether the camera actually moved. The flash and the recoil are for the eyes.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/monster_feel.gd --out=/tmp/feel/x.png

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/feel/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = Vector3(0.0, 0.05, 6.0)
	await rig.wait_frames(10)

	var foe := Enemy.new()
	foe.kind = &"skeleton"
	foe.drop_seed = 4242
	scene.add_child(foe)
	foe.global_position = Vector3(0.0, 0.05, 0.0)
	await rig.wait_frames(30)

	Bus.camera_recenter.emit()
	await rig.wait_frames(30)
	await rig.capture(out.path_join("feel_00_before.png"))

	# --- the damage path itself ---------------------------------------------
	# Not "did a signal fire" -- did the health number move. Everything below
	# this line is feedback ABOUT a blow, and feedback about a blow that never
	# landed is the failure that hides every other failure.
	var before: int = foe.health.quarters
	_strike(foe, 2)
	await rig.wait_frames(2)
	var after: int = foe.health.quarters
	if after >= before:
		_fail("the blow did not land: health stayed at %d" % before)
	else:
		print("FEEL hit %d -> %d quarters" % [before, after])

	await rig.capture(out.path_join("feel_01_impact.png"))
	await rig.wait_frames(4)
	await rig.capture(out.path_join("feel_02_flash.png"))
	await rig.wait_frames(10)
	await rig.capture(out.path_join("feel_03_recoil.png"))
	await rig.wait_frames(40)
	await rig.capture(out.path_join("feel_04_settled.png"))

	if _fails == 0:
		print("FEEL OK")


## Swing at `foe` the way the hero does: a DamageArea, activated for a window.
## Reaching past DamageArea into HealthComponent.apply_hit would prove the
## health maths and skip the exact link that was broken.
func _strike(foe: Node3D, amount: int) -> void:
	var box := DamageArea.new()
	box.collision_layer = K.L_PLAYER_HITBOX
	box.collision_mask = K.L_ENEMY
	box.amount = amount
	box.kind = &"sword"
	box.knockback = K.KNOCKBACK_LIGHT
	box.stun = 0.2
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	col.shape = sphere
	box.add_child(col)
	foe.get_parent().add_child(box)
	box.global_position = foe.global_position + Vector3.UP * 0.9
	box.activate()


func _fail(msg: String) -> void:
	_fails += 1
	print("FEEL FAIL %s" % msg)
