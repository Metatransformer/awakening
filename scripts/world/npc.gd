class_name Npc
extends Interactable
## The two people in town, and the gate they stand either side of.
##
## They are boxes with a lantern. That is on purpose for the MVP: a stand-in
## character model that is nearly good is worse than an obvious placeholder,
## because it invites you to fix the model instead of the loop. What they DO --
## turn to face you, light up when addressed, open the right screen -- is the
## part that has to be right, and none of it depends on the mesh.

enum Role { VENDOR, SMITH, GATE }

@export var role: Role = Role.VENDOR
@export var robe_color: Color = Color(0.34, 0.20, 0.26)
@export var lamp_color: Color = Pal.GOLD

var _body: Node3D
var _lamp: OmniLight3D
var _lamp_mat: StandardMaterial3D
var _sign: Label3D
var _lit: float = 0.0
var _age: float = 0.0


func _ready() -> void:
	match role:
		# TALK, not SELL/FORGE. The verb on a person should be the thing you do to
		# a person -- what they then open is theirs to decide, and naming it here
		# put the shop's menu on the label before you had met the shopkeeper. The
		# name floating over them (`_sign`) already says which one this is, so
		# "TALK" is not vague: it reads as TALK TO THE PAWNBROKER.
		Role.VENDOR, Role.SMITH:
			prompt = "TALK"
		Role.GATE:
			prompt = "DESCEND"
			hold_time = 0.9
	radius = 2.3
	super()
	_build()


func activate(_by: Node3D) -> void:
	match role:
		Role.VENDOR:
			TradeScreen.open(self, TradeScreen.Mode.SELL, "PAWNBROKER")
		Role.SMITH:
			TradeScreen.open(self, TradeScreen.Mode.BUY, "THE FORGE")
		Role.GATE:
			Flow.enter_dungeon()


func on_focus(on: bool) -> void:
	if role == Role.GATE:
		return
	_sign.visible = on


func on_hold(t01: float) -> void:
	# The gate's descent bar is the gate itself filling with light.
	_lamp.light_energy = 1.4 + t01 * 7.0
	_lamp_mat.emission_energy_multiplier = 0.55 + t01 * 5.0


func _process(delta: float) -> void:
	_age += delta
	var want := 1.0 if Prompt.focus == self else 0.0
	_lit = move_toward(_lit, want, delta * 5.0)

	if role != Role.GATE:
		_lamp.light_energy = 1.1 + _lit * 1.8 + sin(_age * 3.1) * 0.12
		_lamp_mat.emission_energy_multiplier = 1.8 + _lit * 2.2
		# Turns to face you. It is two lines and it is the difference between a
		# shopkeeper and a crate with a menu attached.
		var hero := get_tree().get_first_node_in_group(&"player") as Node3D
		if hero != null:
			var to := K.flat(hero.global_position - global_position)
			if to != Vector3.ZERO:
				var want_yaw := atan2(to.x, to.z)
				_body.rotation.y = lerp_angle(_body.rotation.y, want_yaw, delta * 6.0)
	elif Prompt.focus != self:
		_lamp.light_energy = 1.4 + sin(_age * 1.7) * 0.35
		_lamp_mat.emission_energy_multiplier = 0.55


# --- Construction -----------------------------------------------------------

func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	if role == Role.GATE:
		_build_gate()
	else:
		_build_person()

	_sign = Label3D.new()
	_sign.text = "PAWNBROKER" if role == Role.VENDOR else "SMITH"
	_sign.font_size = 48
	_sign.pixel_size = 0.0022
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = true
	_sign.modulate = Pal.BONE
	_sign.outline_size = 16
	_sign.position.y = 2.25
	_sign.visible = false
	add_child(_sign)


func _build_person() -> void:
	var robe := StandardMaterial3D.new()
	robe.albedo_color = robe_color
	robe.roughness = 0.95
	robe.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.62, 0.48, 0.38)
	skin.roughness = 0.9
	skin.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# A tapered robe: narrow at the shoulders, wide at the hem. PrismMesh already
	# points its apex at +Y, so this is the DEFAULT orientation -- the flip that
	# used to be here stood the vendor on his own point.
	var torso := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.98, 1.26, 0.66)
	tm.left_to_right = 0.5
	torso.mesh = tm
	torso.material_override = robe
	torso.position.y = 0.63
	_body.add_child(torso)

	# A prism's apex is a knife edge, and a person is not. The shoulder block is
	# what turns the wedge back into somebody wearing it.
	var shoulders := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.60, 0.26, 0.46)
	shoulders.mesh = sm
	shoulders.material_override = robe
	shoulders.position.y = 1.30
	_body.add_child(shoulders)

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.30, 0.34, 0.28)
	head.mesh = hm
	head.material_override = skin
	head.position.y = 1.58
	_body.add_child(head)

	var hood := MeshInstance3D.new()
	var hoodm := BoxMesh.new()
	hoodm.size = Vector3(0.38, 0.16, 0.36)
	hood.mesh = hoodm
	hood.material_override = robe
	hood.position.y = 1.78
	_body.add_child(hood)

	# The lantern they hold. It is also the only light on their face, so the
	# focus brightening reads on the character and not just on the ground.
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = lamp_color
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = lamp_color
	_lamp_mat.emission_energy_multiplier = 1.8
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# An arm, or the lantern is a glowing cube hovering beside a stranger.
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.42, 0.09, 0.09)
	arm.mesh = am
	arm.material_override = robe
	arm.position = Vector3(0.24, 1.10, 0.18)
	arm.rotation.z = deg_to_rad(-18.0)
	_body.add_child(arm)

	var lamp_mesh := MeshInstance3D.new()
	var lmm := BoxMesh.new()
	lmm.size = Vector3(0.16, 0.22, 0.16)
	lamp_mesh.mesh = lmm
	lamp_mesh.material_override = _lamp_mat
	lamp_mesh.position = Vector3(0.42, 1.02, 0.22)
	_body.add_child(lamp_mesh)

	_lamp = OmniLight3D.new()
	_lamp.light_color = lamp_color
	_lamp.light_energy = 1.1
	_lamp.omni_range = 5.5
	_lamp.omni_attenuation = 1.4
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.42, 1.02, 0.22)
	_body.add_child(_lamp)

	var counter := StaticBody3D.new()
	counter.collision_layer = K.L_WORLD
	counter.collision_mask = 0
	var cc := CollisionShape3D.new()
	var cshape := CylinderShape3D.new()
	cshape.radius = 0.45
	cshape.height = 1.8
	cc.shape = cshape
	cc.position.y = 0.9
	counter.add_child(cc)
	add_child(counter)


## The way down. A dark arch with a cold mouth: the town is warm and gold, so
## the entrance being the only cold thing in it is the only signposting needed.
func _build_gate() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.20, 0.19, 0.22)
	stone.roughness = 1.0
	stone.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.55, 3.4, 0.65)
		post.mesh = pm
		post.material_override = stone
		post.position = Vector3(1.55 * sx, 1.7, 0.0)
		_body.add_child(post)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(3.8, 0.6, 0.75)
	lintel.mesh = lm
	lintel.material_override = stone
	lintel.position.y = 3.7
	_body.add_child(lintel)

	_lamp_mat = StandardMaterial3D.new()
	# Faint. An additive quad at full strength reads as a lit swimming pool; the
	# gate should read as a hole with something cold behind it.
	_lamp_mat.albedo_color = Color(Pal.CYAN, 0.22)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Pal.CYAN
	_lamp_mat.emission_energy_multiplier = 0.55
	_lamp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lamp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mouth := MeshInstance3D.new()
	var mm := QuadMesh.new()
	mm.size = Vector2(2.5, 3.3)
	mouth.mesh = mm
	mouth.material_override = _lamp_mat
	mouth.position = Vector3(0.0, 1.7, 0.0)
	_body.add_child(mouth)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Pal.CYAN
	_lamp.light_energy = 1.4
	_lamp.omni_range = 6.0
	_lamp.omni_attenuation = 1.3
	_lamp.shadow_enabled = false
	_lamp.position.y = 1.6
	_body.add_child(_lamp)

	var plate := Label3D.new()
	plate.text = "THE LOWER WORLDS"
	plate.font_size = 40
	plate.pixel_size = 0.0028
	plate.modulate = Pal.MOTH
	plate.outline_size = 14
	plate.position.y = 4.25
	_body.add_child(plate)
