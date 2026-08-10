class_name Npc
extends Interactable
## The three people in town, and the gate they stand around.
##
## They were boxes with a lantern, on purpose, for as long as the loop was the
## thing being built: a stand-in character model that is nearly good is worse
## than an obvious placeholder, because it invites you to fix the model instead
## of the game. The loop works, so they are people now -- `RaceBody`, one of the
## Vale's three peoples each, standing behind a `ShopBooth` full of their own
## trade.
##
## **What they DO did not change, and that is the point.** Turn to face you,
## light up when addressed, open the right screen: all of it still lives here,
## none of it ever depended on the mesh, and swapping the mesh touched
## `_build_person` and nothing else.

## KEEPER is appended rather than slotted in beside the other three counters:
## the values are what an `@export var role` serialises, and re-ordering this
## enum would silently turn every placed alchemist into a gate.
enum Role { VENDOR, SMITH, GATE, ALCHEMIST, KEEPER }

## Everything that differs between the people in this town, on one row each.
##
## It started as a name table beside a `match` in `_ready` and a second `match`
## in `activate`, which is three places to edit to add a fourth shopkeeper and
## two of them easy to miss. **A new counter is a row here plus a `Catalogue`
## subclass -- never a new screen and never a new branch.** The trade screen, the
## recipe column, the affordability colouring and the hold-to-craft gauge are
## written once and pointed; that is the entire reason `TradeScreen` takes its
## catalogue as an argument.
##
##   * `sign`   -- the name over their head. "" for the gate, which is masonry.
##   * `prompt` -- the verb. TALK, not SELL/FORGE: the verb on a person should be
##     the thing you do to a person, and the sign already says which one this is.
##   * `hold`   -- seconds on the button, 0 to fire on press. See `Prompt`.
##   * `counter`-- present only for the three who stand behind one. `db` null
##     means SELL (the screen reads the bag, not a catalogue).
##
## The GATE has no counter, so `activate` has exactly one branch: open a counter,
## or do the role's own thing.
##
## `static var`, not `const`: a catalogue is a script reference and an enum from
## another class, and neither is a constant expression to the parser. Static, so
## the table is still built once for the whole game rather than per shopkeeper.
static var COUNTERS := {
	Role.VENDOR: {
		"sign": "PAWNBROKER", "prompt": "TALK", "hold": 0.0,
		"counter": {"title": "PAWNBROKER", "mode": TradeScreen.Mode.SELL, "db": null},
	},
	Role.SMITH: {
		"sign": "SMITH", "prompt": "TALK", "hold": 0.0,
		"counter": {"title": "THE FORGE", "mode": TradeScreen.Mode.BUY, "db": ShopDb},
	},
	Role.ALCHEMIST: {
		"sign": "ALCHEMIST", "prompt": "TALK", "hold": 0.0,
		"counter": {"title": "THE ALCHEMIST", "mode": TradeScreen.Mode.BUY, "db": AlchemyDb},
	},
	# The fourth counter, and the last one there will be (docs/GDD.md §6: "the
	# vendor buys, the smith forges, the alchemist brews, the Lanternkeeper
	# records"). She cost exactly this row and a `Catalogue` subclass -- no
	# screen, no branch in `activate`, no new mode -- which is the acceptance
	# criterion for the whole relic system and not a nice outcome.
	#
	# `hold` is 0 like the other three: the HOLD that matters here is on the
	# LINE, not on the greeting. `RelicDb.crafts()` answers true for every row,
	# so `TradeScreen` puts its gauge on the donation itself and the footer reads
	# HOLD ENT TO RECORD.
	Role.KEEPER: {
		"sign": "LANTERNKEEPER", "prompt": "TALK", "hold": 0.0,
		"counter": {
			"title": "THE FAR LANTERN", "mode": TradeScreen.Mode.BUY, "db": RelicDb,
		},
	},
	# 0.9 s, and the only hold in the world. It is the door OUT of the hub and
	# the one press in the game that ends the safe part of the session, so it is
	# the one press that should be impossible to make by accident on the way past.
	#
	# `# NEEDS:` the Warp-Stone Fragment's unlock, `RelicDb.town_shortcuts()`,
	# bites HERE -- "start a run at any shortcut you have opened" (GDD §6.2 #9).
	# It cannot be adopted yet and faking it would be worse than leaving it: the
	# gate would have to open a run at floor N, and `Run.enter()` hard-sets
	# `level = 1` with a comment explaining why, so the change is one argument in
	# `scripts/autoload/run_state.gd`. There is also nothing to offer until the
	# shortcut doors exist on a real floor (SCOPE M4/M6). When both land, this row
	# reads `RelicDb.town_shortcuts()` and `activate` picks the deepest floor
	# whose `LockedDoor.flag_id()` is set -- still no new screen.
	Role.GATE: {"sign": "", "prompt": "DESCEND", "hold": 0.9},
}

## Who each shopkeeper IS -- their people, their clothes, and how they stand.
##
## Separate from `COUNTERS` because the two tables answer different questions and
## get edited for different reasons: `COUNTERS` is what a counter DOES, this is
## what a person looks like. A palette pass should not have to read past the
## trade modes to find the colours.
##
## The races are not cast at random. Each keeps the counter their people would
## keep, which is why the town reads as a place with history in it rather than
## three vendors in different hats:
##
##   * **Stoneborn** at the forge -- short, slab-built, and by their own account
##     the best forges north of the river.
##   * **Reshi** at the pawnbroker's -- caravan blood, the Driftmarket stalls,
##     and a reputation for quiet fences that the shop's SELL mode is built on.
##   * **Vyr** at the apothecary -- a head over any settler and born, they say,
##     seeing the flaw in the drawing. Which is the job.
##
## Heights come with the race (`RaceBody.RACES`) and are load-bearing: the hero
## is 1.65 m, so the smith reads a head short of you and the alchemist a head
## tall, before either of them says a word.
##
##   * `fabric` -- which cloth set to dress them in. See `RaceBody.wear`.
##   * `tint`   -- MULTIPLIES the weave, so these run much lighter than a flat
##     robe colour would. The first pass fed in the box placeholders' robe
##     colours directly and produced three silhouettes in black.
##   * `idle`   -- their resting loop, one each so the town is not three people
##     breathing in time. All from the standing family; see `RaceBody.CLIPS`.
##   * `booth`  -- the shop they stand in.
static var LOOKS := {
	# Tan, not the cold slate the box placeholder wore. The pack's homespun chest
	# piece is a strapped work harness rather than a shirt, and tinted slate over
	# a dark weave it read as black webbing on a bare grey torso. In leather it
	# reads as what it is -- a smith's apron -- and it stops fighting the fire
	# two metres behind him.
	Role.SMITH: {
		"race": "stoneborn", "fabric": "homespun", "idle": &"idle3",
		"tint": Color(0.95, 0.74, 0.52), "booth": ShopBooth.Kind.FORGE,
	},
	Role.VENDOR: {
		"race": "reshi", "fabric": "wool", "idle": &"idle",
		"tint": Color(0.86, 0.52, 0.58), "booth": ShopBooth.Kind.STALL,
	},
	Role.ALCHEMIST: {
		"race": "vyr", "fabric": "silk", "idle": &"idle4",
		"tint": Color(0.56, 0.88, 0.68), "booth": ShopBooth.Kind.ALCHEMY,
	},
	# Reshi, like the pawnbroker, because there are three peoples and four
	# counters -- the Society recruits, it is not a race. The fabric, the idle
	# and the tint all differ from his for one reason and it is not taste: two
	# reshi in wool at the same height, breathing in time, read as the SAME
	# PERSON standing in two places, and a player who cannot tell the
	# Lanternkeeper from the pawnbroker across the yard cannot find the hall.
	# Cool against his rose, so the two ends of the yard are told apart by
	# silhouette colour before either sign is readable.
	#
	# A STALL, and that is the end of dressing her. The hall is not a booth kind
	# and it does not need to be: the twelve lamps outside are what says this
	# counter is different, and a bespoke booth would be spending on the wrong
	# half of GDD §6.2's budget.
	Role.KEEPER: {
		"race": "reshi", "fabric": "homespun", "idle": &"idle9",
		"tint": Color(0.66, 0.76, 0.94), "booth": ShopBooth.Kind.STALL,
	},
}

@export var role: Role = Role.VENDOR
@export var lamp_color: Color = Pal.GOLD

var _body: Node3D
var _person: RaceBody
var _lamp: OmniLight3D
var _lamp_mat: StandardMaterial3D
var _sign: Label3D
var _lit: float = 0.0
var _age: float = 0.0
## Crown height of whoever is standing here, so the name floats over the head it
## belongs to. The three races differ by 40 cm; a fixed 2.25 put the Stoneborn's
## sign most of a metre above him.
var _head: float = 1.75


## The row for this NPC. Never null -- a role added to the enum and forgotten
## here gets a nameless prop you can walk up to, not a crash mid-town.
func _row() -> Dictionary:
	var row: Dictionary = COUNTERS.get(role, {})
	return row


func _ready() -> void:
	var row := _row()
	prompt = str(row.get("prompt", "EXAMINE"))
	hold_time = float(row.get("hold", 0.0))
	radius = 2.3
	super()
	_build()


func activate(_by: Node3D) -> void:
	# One screen, pointed. See `Catalogue` for why there is not a second one.
	var counter: Dictionary = _row().get("counter", {})
	if not counter.is_empty():
		TradeScreen.open(self, int(counter["mode"]), str(counter["title"]),
			counter["db"] as GDScript)
		return
	if role == Role.GATE:
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
				# GLOBAL, because the Npc node itself is now turned to aim its booth
				# at the yard. `atan2(to.x, to.z)` is a world yaw, and writing a world
				# yaw into a local rotation left every keeper facing off by however
				# far their stall was rotated.
				var want_yaw := atan2(to.x, to.z)
				_body.global_rotation.y = lerp_angle(_body.global_rotation.y, want_yaw, delta * 6.0)
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
	_sign.text = str(_row().get("sign", ""))
	_sign.font_size = 48
	_sign.pixel_size = 0.0022
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = true
	_sign.modulate = Pal.BONE
	_sign.outline_size = 16
	_sign.position.y = _head + 0.5
	_sign.visible = false
	add_child(_sign)


## A person, their shop, and the lamp they work by.
##
## Note what hangs off what. `_body` turns to follow you and holds ONLY the
## person; the booth and the lamp are children of the Npc itself and never move.
## That split is the entire trick -- a keeper who tracks you across their own
## stationary counter reads as somebody at work, and the earlier version, where
## everything hung off the turning node, would have swung the forge round the
## yard every time you walked past it.
func _build_person() -> void:
	var look: Dictionary = LOOKS.get(role, {})

	# The shop. Set forward of the keeper along the Npc's own +Z, which is the
	# side `ShopBooth` authors its counter to face -- so aiming an Npc at the
	# yard aims their booth at it too, and nothing has to be placed twice.
	var kind: ShopBooth.Kind = look.get("booth", ShopBooth.Kind.STALL)
	var booth := ShopBooth.new()
	booth.kind = kind
	booth.position.z = ShopBooth.KEEPER_BACK
	add_child(booth)

	# The person.
	_person = RaceBody.make(str(look.get("race", "reshi")))
	if _person != null:
		_body.add_child(_person)
		var tint: Color = look.get("tint", Color.WHITE)
		var idle: StringName = look.get("idle", &"idle")
		_person.wear(str(look.get("fabric", "wool")), tint)
		_person.play(idle)
		_head = _person.height

	# The lamp on its post, at the end of the counter. It used to be a cube in
	# the keeper's fist, which was the right call for a keeper made of cubes; a
	# glowing box clenched by an actual hand would be a worse lie than the boxes
	# were. On a post it is a lamp, and it is still the only light on their face
	# -- which is what makes the focus brightening read on the PERSON and not
	# just as a puddle on the flagstones.
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = lamp_color
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = lamp_color
	_lamp_mat.emission_energy_multiplier = 1.8
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.17)
	iron.roughness = 0.85
	iron.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# CLEAR of the counter's right-hand end, and only just forward of it.
	#
	# 1.18 out and 0.30 forward was the first try, and from any three-quarter
	# angle the post stood squarely in front of the keeper -- the pawnbroker was
	# a lamp with a stall behind it. 1.52 puts it outside both the stall's posts
	# and the workbench's top, so it lights the keeper's face across the counter
	# without ever being between them and you.
	var at := Vector3(1.52, 0.0, ShopBooth.KEEPER_BACK + 0.10)
	const LAMP_Y := 1.96

	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.035
	pm.bottom_radius = 0.055
	pm.height = LAMP_Y
	pm.radial_segments = 6
	post.mesh = pm
	post.material_override = iron
	post.position = at + Vector3(0.0, LAMP_Y * 0.5, 0.0)
	add_child(post)

	var cap := MeshInstance3D.new()
	var cm := PrismMesh.new()
	cm.size = Vector3(0.24, 0.14, 0.24)
	cap.mesh = cm
	cap.material_override = iron
	cap.position = at + Vector3(0.0, LAMP_Y + 0.07, 0.0)
	add_child(cap)

	var lamp_mesh := MeshInstance3D.new()
	var lmm := BoxMesh.new()
	lmm.size = Vector3(0.16, 0.20, 0.16)
	lamp_mesh.mesh = lmm
	lamp_mesh.material_override = _lamp_mat
	lamp_mesh.position = at + Vector3(0.0, LAMP_Y - 0.10, 0.0)
	add_child(lamp_mesh)

	_lamp = OmniLight3D.new()
	_lamp.light_color = lamp_color
	_lamp.light_energy = 1.1
	_lamp.omni_range = 5.5
	_lamp.omni_attenuation = 1.4
	_lamp.shadow_enabled = false
	_lamp.position = at + Vector3(0.0, LAMP_Y - 0.10, 0.0)
	add_child(_lamp)

	# The keeper's own body, so you cannot stand inside them if you come round
	# the side of the stall. The counter's collision belongs to `ShopBooth`.
	var solid := StaticBody3D.new()
	solid.collision_layer = K.L_WORLD
	solid.collision_mask = 0
	var cc := CollisionShape3D.new()
	var cshape := CapsuleShape3D.new()
	cshape.radius = 0.32
	cshape.height = maxf(_head, 0.8)
	cc.shape = cshape
	cc.position.y = _head * 0.5
	solid.add_child(cc)
	add_child(solid)


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
	# The name of the place this gate opens onto, not the name of the setting.
	# "The Lower Worlds" is everything under the town (docs/GDD.md); THE SUNKEN
	# CUT is the one dungeon there is a way down into, and a sign over a door
	# should say where the door goes. It reads off `Prog.NAME` so the gate, the
	# loading card and the HUD cannot end up calling it three different things.
	plate.text = Prog.NAME
	plate.font_size = 40
	plate.pixel_size = 0.0028
	plate.modulate = Pal.MOTH
	plate.outline_size = 14
	plate.position.y = 4.25
	_body.add_child(plate)
