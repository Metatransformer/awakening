extends RefCounted
## Votive Court prototype proof. The legacy filename is kept because the full
## director survey and several historical styleguide notes invoke it by path.
## The old world-caption instrument is gone with the three-mote Echo pedestal.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/echo_plates.gd \
##     --out=/tmp/votive/x.png --warmup=60
##
## It proves the replacement at the real generated reward site: seven distinct
## effigies (six possible responders plus broken Vallen), exactly three lit by a
## seeded offer, direct A/E interaction, six menu cards with three disabled,
## visible full-bag refusal, and one blessing taken while the other gods darken.

const SEED := 20260809

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/votive/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if rig.scene().name != &"DungeonRun":
		print("VOTIVE FAIL wrong host scene (%s)" % rig.scene().name)
		return

	Game.reset()
	Run.enter(SEED)
	var dungeon := await _rebuild(rig)
	if dungeon == null:
		print("VOTIVE FAIL the dungeon did not build")
		return
	var hero := _hero(rig)
	if hero == null:
		print("VOTIVE FAIL no hero")
		return
	_clear_the_floor(dungeon)

	var shrine := _stone_with(dungeon, &"gate")
	_ck("A0 the gate reward is a Votive Court", shrine != null)
	if shrine == null:
		return
	shrine.call(&"offer")
	await rig.wait_frames(12)

	var effigies := _every(shrine, func(node: Node) -> bool:
		return node.is_in_group(&"patron_effigy"))
	var patron_ids: Dictionary = {}
	var answering := 0
	var vallen_dark := false
	for effigy: Node in effigies:
		var patron_id := StringName(effigy.get(&"patron_id"))
		patron_ids[patron_id] = true
		var lamp := effigy.get_node_or_null(^"AnswerLight") as OmniLight3D
		if lamp != null and lamp.visible:
			answering += 1
		if patron_id == &"vallen":
			vallen_dark = bool(effigy.get(&"broken")) and (lamp == null or not lamp.visible)
	_ck("A1 seven distinct prototype effigies stand on it",
		effigies.size() == 7 and patron_ids.size() == 7)
	_ck("A2 exactly three gods answer", answering == 3)
	_ck("A3 broken Vallen never answers", vallen_dark)
	await _stand_in_front(rig, hero, shrine, 5.3, 0.8)
	await rig.capture(out.path_join("v_01_court.png"))

	var interactable := shrine.get_node_or_null(^"Interactable") as Interactable
	_ck("B0 the shrine has one direct interaction", interactable != null)
	if interactable == null:
		return
	await _stand_in_front(rig, hero, shrine, 2.35, 0.65)
	await rig.until(func() -> bool: return Prompt.focus == interactable, 2.0)
	_ck("B1 the shrine owns A/E", Prompt.focus == interactable)
	if Prompt.focus != interactable:
		return
	await rig.tap([&"interact"])
	await rig.until(func() -> bool: return bool(shrine.call(&"menu_open")), 2.0)
	var menu := _blessing_menu(rig.scene())
	_ck("B2 A/E opens the blessing menu", menu != null)
	if menu == null:
		return
	_ck("B3 all six gods remain on the board", int(menu.call(&"card_count")) == 6)
	_ck("B4 three answer and three are silent",
		int(menu.call(&"answering_count")) == 3)
	await rig.until(func() -> bool:
		var owner := menu.get_viewport().gui_get_focus_owner()
		return owner != null and menu.is_ancestor_of(owner), 2.0)
	await rig.capture(out.path_join("v_02_menu.png"))

	# The bag's current brim is the smallest deterministic full-bag fixture. It is
	# restored before the second press even when the refusal itself fails.
	var bag_slots_before := Game.bag_slots
	Game.bag_slots = Run.slots_used()
	await rig.tap([&"ui_accept"])
	await rig.wait_frames(12)
	_ck("C0 a full bag leaves the shrine unspent",
		not bool(shrine.call(&"is_spent")))
	_ck("C1 and keeps the six-god menu open",
		bool(shrine.call(&"menu_open")) and _blessing_menu(rig.scene()) != null)
	await rig.capture(out.path_join("v_03_bag_full.png"))
	Game.bag_slots = bag_slots_before

	await rig.wait_frames(4)
	await rig.tap([&"ui_accept"])
	await rig.until(func() -> bool:
		return bool(shrine.call(&"is_spent")) \
			and not bool(shrine.call(&"menu_open")), 3.0)
	var held := Run.echoes_held()
	_ck("D0 one offered blessing enters the run", held.size() == 1)
	_ck("D1 the menu closes and the shrine is spent",
		bool(shrine.call(&"is_spent")) and not bool(shrine.call(&"menu_open")))
	var lights_left := 0
	for effigy: Node in effigies:
		var lamp := effigy.get_node_or_null(^"AnswerLight") as OmniLight3D
		if lamp != null and lamp.visible:
			lights_left += 1
	_ck("D2 only the chosen god remains lit", lights_left == 1)
	await rig.capture(out.path_join("v_04_chosen.png"))

	if _fails == 0:
		print("VOTIVE ok -- every check passed")
	else:
		print("VOTIVE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("VOTIVE ok %s" % label)
	else:
		_fails += 1
		print("VOTIVE FAIL %s" % label)


func _rebuild(rig) -> Node:
	Run.level = 1
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	if script == null:
		return null
	var dungeon: Node = script.new()
	dungeon.name = "Dungeon"
	dungeon.seed_override = SEED
	scene.add_child(dungeon)
	await rig.wait_frames(12)
	return dungeon


func _clear_the_floor(dungeon: Node) -> void:
	for enemy in _every(dungeon, func(node: Node) -> bool: return node is Enemy):
		enemy.queue_free()


func _stand_in_front(rig, hero: Node3D, at: Node3D, back: float,
		side: float = 0.0) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = at.global_position \
		- at.global_transform.basis.z * back \
		+ at.global_transform.basis.x * side + Vector3(0.0, 0.15, 0.0)
	var toward := K.flat(at.global_position - hero.global_position)
	if toward != Vector3.ZERO:
		hero.facing_yaw = atan2(toward.x, toward.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)


func _stone_with(dungeon: Node, id: StringName) -> Node3D:
	for node in _every(dungeon, func(candidate: Node) -> bool:
		return candidate.is_in_group(&"sounding_stone") \
			and candidate.get(&"stone_id") == id):
		return node
	return null


func _blessing_menu(root: Node) -> Node:
	for node in _every(root, func(candidate: Node) -> bool:
		return candidate.has_method(&"card_count") \
			and candidate.has_method(&"answering_count") \
			and candidate.has_signal(&"blessing_chosen")):
		return node
	return null


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _every(root: Node, pred: Callable) -> Array:
	var found: Array = []
	for node in _all(root):
		if pred.call(node):
			found.append(node)
	return found


func _all(root: Node) -> Array:
	var found: Array = [root]
	for child in root.get_children():
		found.append_array(_all(child))
	return found
