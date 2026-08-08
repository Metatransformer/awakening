extends RefCounted
## Where do the hookshot and the bow sit — stowed on the body, and in the hand?
##
## Four sockets, each of which can be wrong in a way that is obvious in a picture
## and invisible in the numbers: bow-in-left-hand, bow-stowed-on-back,
## hookshot-in-right-hand, hookshot-on-right-hip. The rig's rest pose is in a
## rotated FBX space (docs/CONTRACT.md), so these are found by looking.
##
## Shot from four sides, because a bow on the back is only wrong from behind and
## a hookshot on the hip is only wrong from the side.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/item_lookdev.gd --out=/tmp/il/x.png

const VIEWS := [
	{"name": "front", "eye": Vector3(0.0, 1.15, -2.6)},
	{"name": "back", "eye": Vector3(0.0, 1.15, 2.6)},
	{"name": "left", "eye": Vector3(-2.6, 1.15, 0.0)},
	{"name": "right", "eye": Vector3(2.6, 1.15, 0.0)},
]

const STATES := [&"", &"hookshot", &"bow"]


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/il/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	await rig.wait_frames(24)

	if hero == null:
		push_error("item_lookdev: no Hero")
		return
	var combat = hero.get("combat")
	if combat == null:
		push_error("item_lookdev: no combat node")
		return

	for id in ["hookshot", "bow"]:
		var holder: Node3D = combat.get(id) as Node3D
		if holder == null:
			push_error("item_lookdev: '%s' did not mount" % id)
			continue
		var model := holder.get_child(0) as Node3D
		if model != null:
			print("SIZE %s extent=%.2fm" % [id, WeaponModels.extent(model)])

	var cam := Camera3D.new()
	cam.fov = 46.0
	scene.add_child(cam)
	cam.make_current()

	var key := OmniLight3D.new()
	key.light_energy = 3.4
	key.omni_range = 9.0
	scene.add_child(key)
	key.global_position = hero.global_position + Vector3(-1.6, 2.6, -2.2)

	for state in STATES:
		combat.call(&"equip", state)
		# equip() toggles, so re-assert rather than trusting the toggle.
		combat.set(&"equipped", state)
		combat.call(&"_show_equipped")
		await rig.wait_frames(4)
		for view in VIEWS:
			cam.global_position = hero.global_position + (view["eye"] as Vector3)
			cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
			await rig.wait_frames(2)
			var label: String = String(state) if state != &"" else "stowed"
			await rig.capture(out.path_join("it_%s_%s.png" % [label, view["name"]]))

	key.queue_free()
	cam.queue_free()
	print("ITEMCHECK states=%d views=%d" % [STATES.size(), VIEWS.size()])
