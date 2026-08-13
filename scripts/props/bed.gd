class_name Bed
extends Interactable
## The cot in the hero's quarters. Hold to sleep.
##
## ## What sleeping actually does, and what it deliberately does not
##
## **It writes the save.** That is the load-bearing one. `Flow._go` autosaves on
## every scene change (game_flow.gd), which covers the four moments a run passes
## through — but it covers nothing you do *between* them, and everything the
## garrison is for happens between them. Sell the bag, forge a rung, brew two
## draughts, quit: all of it was on the disk as of the moment you walked out of
## the dungeon, and none of the last twenty minutes was. The bed is where a
## player says "keep this", in the place and the gesture every game of this
## shape has used to say it.
##
## **Recovery is complete.** Every successful sleep fills real health, while
## each `elder_bed` rung grants 1 temporary HP. The
## clock jump happens behind Flow's existing black veil so every clock listener
## finds morning already true when the world comes back.
##
## The hold is `Prompt`'s, not this file's — see `hold_time` below.

## Long enough to be a decision, short of the gate's 0.9 s.
##
## The gate is guarding against a press you made while walking past it into a
## dungeon run. This is guarding against nothing at all: sleeping is free,
## reversible and thirty seconds from repeatable. It is held only because a
## fade-to-black that fires on a tap while you are walking past the foot of your
## own bed is a jump-scare, and because the gauge is what tells the player the
## fade is coming.
const SLEEP_HOLD := 0.55

const IDLE_MOTE_RATIO: float = 0.38
const FOCUSED_MOTE_RATIO: float = 0.92

var _glow: OmniLight3D = null
var _quilt_material: ShaderMaterial = null
var _motes: GPUParticles3D = null
var _dialogue: DialogueBox = null
var _selected_destination_id: StringName = &""
var _sleep_pending: bool = false


func _ready() -> void:
	prompt = "SLEEP IN YOUR BED"
	radius = 1.5
	hold_time = SLEEP_HOLD
	super()
	_build()


## Refused mid-run rather than merely unreachable.
##
## Nothing can carry this prop underground today — it is built by `House`, which
## is built by `Garrison`. The guard is here anyway because the rule it enforces
## is not "the cot is in the garrison", it is **"you cannot save your way out of
## a run"**, and that rule is `docs/METAGAME.md` §5 and the reason
## `Saves._save_scene` refuses to record a dungeon. A bed placed in a safe room
## on floor three would be the whole extraction decision undone by a prop, and
## the file that stops it should be the file the prop is in.
func activate(_by: Node3D) -> void:
	if Run.in_dungeon or Flow.busy or Flow.ending or _sleep_pending \
			or is_instance_valid(_dialogue):
		return
	activated.emit(_by)
	_sleep_pending = true
	_selected_destination_id = &""
	var choices: Array = [
		{
			"label": "Sleep until nightfall",
			"act": _select_sleep_destination.bind(
				WorldClock.SLEEP_DESTINATION_NIGHTFALL),
		},
		{
			"label": "Sleep until morning",
			"act": _select_sleep_destination.bind(
				WorldClock.SLEEP_DESTINATION_MORNING),
		},
	]
	_dialogue = DialogueBox.open(self, &"",
		PackedStringArray(["How long should I sleep?"]), choices)
	if _dialogue == null:
		_sleep_pending = false
		return
	_dialogue.finished.connect(_on_sleep_dialogue_finished, CONNECT_ONE_SHOT)


func _select_sleep_destination(destination_id: StringName) -> PackedStringArray:
	_selected_destination_id = destination_id
	return PackedStringArray()


## Dialogue has removed its own Prompt blocker before emitting `finished`, so
## Flow can claim the transition without two full-screen owners overlapping.
func _on_sleep_dialogue_finished() -> void:
	_dialogue = null
	if _selected_destination_id == &"":
		_sleep_pending = false
		return
	if Run.in_dungeon or Flow.busy or Flow.ending:
		_selected_destination_id = &""
		_sleep_pending = false
		return
	var destination: Dictionary[StringName, Variant] = \
		Clock.effective_sleep_destination(_selected_destination_id)
	if destination.is_empty():
		_selected_destination_id = &""
		_sleep_pending = false
		return
	var from_absolute_hour: float = Clock.absolute_hours(Clock.day, Clock.hour)
	var to_absolute_hour: float = Clock.absolute_hours(
		int(destination[&"day"]), float(destination[&"hour"]))
	Flow.sleep_transition(_sleep.bind(_selected_destination_id),
		from_absolute_hour, to_absolute_hour)


## Called with the world stopped and the screen black. Everything in here is a
## thing the player should find already true when the lights come up, which is
## why the autosave is inside the dark and not after it: `Saves.save` reads the
## hero's position out of the live tree, and the position it should record is the
## one he is standing in now — beside his own bed — rather than wherever a fade
## found him.
func _sleep(destination_id: StringName) -> void:
	# `sleep_until` emits synchronously. Mark this as deliberate so Flow's dawn
	# curfew handler does not try to start a second transition inside this one.
	Flow.deliberate_rest = true
	var completed: bool = Clock.sleep_until(destination_id)
	Flow.deliberate_rest = false
	_selected_destination_id = &""
	_sleep_pending = false
	if not completed:
		return
	var bed_rank := int(Game.upgrades.get(ElderUpgradeDb.BED_ID, 0))
	Game.heal(Game.max_health_points)
	Game.set_temporary_overhealth(
		bed_rank * ElderUpgradeDb.BED_OVERHEALTH_PER_RANK)
	Game.refund_stamina(Game.max_stamina)
	var slot := -1
	if Saves.autosave():
		slot = Saves.active_slot
	Bus.rested.emit(slot)
	# The HUD already draws `Saves.autosaved` as its own notice, so a rest that
	# wrote a slot has said so. This is for the one that did not — three slots
	# full of hand-made saves means the autosave declines (see `Saves.autosave`),
	# and a bed that faded to black and silently did nothing is a bed the player
	# files as broken.
	if slot < 0:
		Bus.request_message.emit("RESTED. NO SLOT FREE TO SAVE.")


# --- Look --------------------------------------------------------------------
# A frame, a mattress and a blanket, in the garrison's own vocabulary: kit stone
# for the base, `mat_wood` for the frame, and the one warm gold the whole
# garrison is lit in (`GarrisonLight`, `Npc._lamp`). Three boxes.
# `docs/STYLEGUIDE.md` §6 budgets a prop at "the shape, not the material", and
# the shape of a bed is a low rectangle with a pale block at one end.

const MAT_WOOD := preload("res://assets/materials/mat_wood.tres")
const YOUR_BED_SHADER := preload("res://assets/shaders/your_bed.gdshader")

const LEN := 2.05
const WIDE := 0.95
const FRAME_Y := 0.34


func _build() -> void:
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(WIDE, FRAME_Y, LEN)
	frame.mesh = fm
	frame.material_override = MAT_WOOD
	frame.position.y = FRAME_Y * 0.5
	add_child(frame)

	# The mattress, proud of the frame on all four sides so the bed reads as
	# something soft on something hard rather than as one box.
	var pad := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(WIDE - 0.08, 0.16, LEN - 0.10)
	pad.mesh = pm
	pad.material_override = _flat(Color(0.44, 0.36, 0.30))
	pad.position.y = FRAME_Y + 0.08
	add_child(pad)

	# The blanket. The one saturated thing in the room, and it is the RUST the
	# styleguide gives the Highbridge people rather than the gold every lamp in
	# the yard already is — a warm box at lamp colour in a room lit by a lamp
	# disappears into it.
	var quilt := MeshInstance3D.new()
	var qm := BoxMesh.new()
	qm.size = Vector3(WIDE + 0.04, 0.10, LEN * 0.58)
	quilt.mesh = qm
	_quilt_material = ShaderMaterial.new()
	_quilt_material.shader = YOUR_BED_SHADER
	quilt.material_override = _quilt_material
	quilt.position = Vector3(0.0, FRAME_Y + 0.19, LEN * 0.16)
	add_child(quilt)

	# The pillow, at the head (local -Z). It is what tells you which end is which
	# from across the room, and therefore which way the hero is meant to lie.
	var pillow := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(WIDE - 0.22, 0.14, 0.42)
	pillow.mesh = wm
	pillow.material_override = _flat(Pal.BONE)
	pillow.position = Vector3(0.0, FRAME_Y + 0.21, -LEN * 0.36)
	add_child(pillow)

	# A dim warm pool on the bed itself, so the cot is the brightest thing in a
	# room that is otherwise in the shade of its own roof. Range is short and the
	# energy is a fifth of a torch's: this is a hint of where to walk, not a
	# light source, and a second bright omni four metres from the quarters' lamp
	# would flatten the roof shadow that makes the room read as indoors at all.
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.86, 0.66)
	_glow.light_energy = 1.6
	_glow.omni_range = 3.2
	_glow.position = Vector3(0.0, 1.05, 0.0)
	add_child(_glow)

	_motes = _build_motes()
	add_child(_motes)


func on_focus(on: bool) -> void:
	if _quilt_material != null:
		_quilt_material.set_shader_parameter(&"focus", 1.0 if on else 0.0)
	if _motes != null:
		_motes.amount_ratio = FOCUSED_MOTE_RATIO if on else IDLE_MOTE_RATIO


func _build_motes() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = &"BedMotes"
	particles.amount = 10
	particles.amount_ratio = IDLE_MOTE_RATIO
	particles.lifetime = 3.2
	particles.preprocess = 3.2
	particles.one_shot = false
	particles.local_coords = true
	particles.fixed_fps = 30
	particles.position = Vector3(0.0, FRAME_Y + 0.34, -LEN * 0.08)
	particles.visibility_aabb = AABB(
		Vector3(-0.55, -0.18, -0.98), Vector3(1.10, 1.05, 1.96))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.38, 0.04, 0.80)
	process.direction = Vector3.UP
	process.spread = 16.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.18
	process.gravity = Vector3.ZERO
	process.damping_min = 0.05
	process.damping_max = 0.16
	process.scale_min = 0.65
	process.scale_max = 1.2
	process.scale_curve = _mote_scale_curve()
	process.color_ramp = _mote_color_ramp()
	particles.process_material = process
	particles.draw_pass_1 = _mote_billboard()
	particles.emitting = true
	return particles


func _mote_scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.24, 1.0))
	curve.add_point(Vector2(1.0, 0.12))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _mote_color_ramp() -> GradientTexture1D:
	var warm: Color = Pal.RUST.lerp(Pal.GOLD, 0.44)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(warm.r, warm.g, warm.b, 0.0),
		Color(warm.r, warm.g, warm.b, 0.44),
		Color(warm.r, warm.g, warm.b, 0.25),
		Color(warm.r, warm.g, warm.b, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _mote_billboard() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _mote_texture()
	material.disable_receive_shadows = true
	quad.material = material
	return quad


func _mote_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.68),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


## An unshaded material, the way `GarrisonLight` builds its two states: these
## are props at STYLEGUIDE §6's "a prop and a light" budget, and a lit shader on
## a 0.1 m box buys nothing a flat colour does not.
func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m
