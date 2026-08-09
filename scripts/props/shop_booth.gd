class_name ShopBooth
extends Node3D
## The place a shopkeeper works, as opposed to the menu they open.
##
## Every counter in this town used to be a person standing on bare flagstones,
## and the difference between the smith and the alchemist was the word floating
## over their head. A forge is a hearth, an anvil, a quench barrel and a rack of
## finished steel; an apothecary is a bench, a cauldron and a wall of bottles.
## Those things say which shop this is from across the yard, before the sign is
## readable and without anybody opening a screen.
##
## **This is dressing, not a system.** A booth has no script logic beyond a
## banked fire that breathes: no interaction, no state, nothing saved. The
## counter is still `Npc` + `TradeScreen` and a row in `Npc.COUNTERS`
## (docs/METAGAME.md §6.6), exactly as before. Adding a booth to a fourth
## shopkeeper is a row in `PARTS` here and a line in `Town._build_people`.
##
## Counts are unchanged against docs/SCOPE.md §1: one town scene, three
## counters, no new screens. These are props in the courtyard that already
## exists.

## Which shop. One per counter, and `Town` picks by role.
enum Kind { STALL, FORGE, ALCHEMY }

## **The booth's +Z is the customer's side.**
##
## Same convention as `Npc`, which turns a shopkeeper with
## `rotation.y = atan2(to.x, to.z)` and so points the body's +Z at the player.
## Keeping booth and keeper on one convention means `Town` gives them the same
## yaw and the keeper ends up behind their own counter instead of in front of
## it. Everything in `PARTS` is authored in that space: negative Z is the
## working side, where the fire and the stock live.
@export var kind: Kind = Kind.STALL

## How far behind the counter the shopkeeper stands. Far enough back that the
## counter reads as between you and them, close enough that they are still
## inside their own booth rather than loitering near it.
##
## `Npc` reads this to place its booth: the booth goes `KEEPER_BACK` forward
## along the keeper's +Z, which puts the keeper exactly here in booth space.
## One number, so the two can never drift apart.
const KEEPER_BACK := 0.95

const DIR := "res://assets/props/booth/"

## Every booth, as a list of rows. A prop is a file, a place, and a turn.
##
## A table rather than three build functions, for the reason `Npc.COUNTERS`
## gives: a fourth shop should be data, and an arrangement you can read top to
## bottom is one you can rearrange without re-reading any code. Positions come
## off `tools/directors/booth_props.gd`, which measures every one of these in
## metres -- they are transcribed, not guessed.
##
##   * `at`    -- metres, booth space. +Z is the customer side (see `kind`).
##   * `yaw`   -- degrees.
##   * `tint`  -- optional albedo multiply, for the pack's white glassware.
##   * `glow`  -- whether a tinted thing also catches light. Defaults TRUE,
##     because almost everything tinted here is a bottle; the book stack is the
##     one row that opts out.
##
## `static var`, not `const`: the rows hold Colors and the parser will not take
## a const Dictionary indexed for typed values (CLAUDE.md §3).
static var PARTS := {
	# --- The pawnbroker's stall ------------------------------------------
	# A canopied market stall, because the pawnbroker is the one counter that
	# is pure commerce -- no craft behind it, just a table and what is on it.
	Kind.STALL: [
		{"f": "Stall_Empty.gltf", "at": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
		# On the counter. The stall's table top measures 0.95.
		{"f": "Coin_Pile.gltf", "at": Vector3(-0.45, 0.95, 0.05), "yaw": 20.0},
		{"f": "Chalice.gltf", "at": Vector3(0.30, 0.95, 0.10), "yaw": 0.0},
		{"f": "Pouch_Large.gltf", "at": Vector3(0.62, 0.95, -0.05), "yaw": -35.0},
		# Behind it: what has not been sold yet.
		{"f": "Chest_Wood.gltf", "at": Vector3(-0.95, 0.0, -1.15), "yaw": 12.0},
		{"f": "Crate_Wooden.gltf", "at": Vector3(0.95, 0.0, -1.30), "yaw": -18.0},
	],
	# --- The forge --------------------------------------------------------
	# The hearth sits BEHIND the smith, not beside him: it is the light source
	# for the whole booth, so it has to be the thing he is standing in front of.
	Kind.FORGE: [
		{"f": "Workbench.gltf", "at": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
		# -3.05 and not a metre nearer. The hearth was at -2.30 first, which put
		# its front lip a hand's width behind the smith's heels: from the
		# customer's side he was not standing in front of a fire, he was standing
		# IN one. A metre of clear floor between a person and an open forge is
		# what makes the forge read as hot.
		{"f": "forge_pit.glb", "at": Vector3(-0.20, 0.0, -3.05), "yaw": 0.0},
		{"f": "stump.glb", "at": Vector3(1.35, 0.0, -1.05), "yaw": 0.0},
		{"f": "anvil.glb", "at": Vector3(1.35, 0.50, -1.05), "yaw": 90.0},
		{"f": "hammer01.glb", "at": Vector3(1.30, 0.82, -1.05), "yaw": 24.0},
		{"f": "tongs01.glb", "at": Vector3(0.55, 0.89, -0.05), "yaw": 70.0},
		{"f": "Barrel.gltf", "at": Vector3(-1.55, 0.0, -1.05), "yaw": 0.0},
		{"f": "Bucket_Metal.gltf", "at": Vector3(-1.05, 0.0, -1.55), "yaw": 0.0},
		{"f": "WeaponStand.gltf", "at": Vector3(2.15, 0.0, -3.10), "yaw": -28.0},
		# Right out at the edge. The treadle grindstone is the tallest thing in
		# the booth after the smith -- its wheel clears a metre -- so anywhere
		# nearer than this and it stands between the customer and the keeper.
		{"f": "grindstone.glb", "at": Vector3(-2.95, 0.0, -2.55), "yaw": 50.0},
	],
	# --- The apothecary ---------------------------------------------------
	Kind.ALCHEMY: [
		{"f": "Workbench.gltf", "at": Vector3(0.0, 0.0, 0.0), "yaw": 0.0},
		# The bench top measures 0.89, so everything on it sits at exactly that.
		{"f": "Potion_2.gltf", "at": Vector3(-0.70, 0.89, 0.02), "yaw": 0.0,
			"tint": Color(0.45, 0.95, 0.62)},
		{"f": "Potion_4.gltf", "at": Vector3(-0.45, 0.89, -0.10), "yaw": 30.0,
			"tint": Color(0.95, 0.72, 0.35)},
		{"f": "Potion_1.gltf", "at": Vector3(0.72, 0.89, 0.04), "yaw": -15.0,
			"tint": Color(0.72, 0.55, 0.95)},
		{"f": "SmallBottles_1.gltf", "at": Vector3(0.40, 0.89, -0.12), "yaw": 8.0,
			"tint": Color(0.55, 0.90, 0.80)},
		# Tinted, because the pack's books ship in bright white paper and a stack
		# of them next to a cauldron read as a pile of clean laundry.
		{"f": "Book_Stack_1.gltf", "at": Vector3(-1.05, 0.89, -0.14), "yaw": -12.0,
			"tint": Color(0.58, 0.44, 0.36), "glow": false},
		{"f": "CandleStick.gltf", "at": Vector3(0.95, 0.89, -0.16), "yaw": 0.0},
		# The still, working away behind her.
		{"f": "Cauldron.gltf", "at": Vector3(-1.15, 0.0, -1.55), "yaw": 0.0},
		{"f": "Crate_Wooden.gltf", "at": Vector3(0.90, 0.0, -1.90), "yaw": 8.0},
		# Standing ON the crate -- 0.90 is the crate's measured lid, not a guess.
		{"f": "Shelf_Small_Bottles.gltf", "at": Vector3(0.85, 0.90, -1.85), "yaw": 0.0},
	],
}

## The fire each booth is lit by, and where it sits. The stall has none -- it is
## lit by the keeper's own lantern, which `Npc` already carries, and a second
## light there would flatten the one bit of shape the stall canopy casts.
##
## Colours are deliberately NOT `Pal.GOLD` (currency only) and never `Pal.CYAN`
## (reserved for the way down, STYLEGUIDE §2). A cyan glow on the alchemist's
## cauldron would quietly compete with the gate.
## The alchemist's pot is deliberately the DIMMER of the two, at less than half
## the forge's reach. It is the same green as her lamp used to be, and with both
## of them running the whole west half of the yard went green -- including the
## flagstones in front of the gate, three metres from the one cyan thing in the
## game that is supposed to own that end of the spectrum. She keeps the green;
## her lamp went warm (`Town._build_people`), and the pot stopped shouting.
static var FIRES := {
	Kind.FORGE: {
		# 0.55, not the 0.72 that filled the basin lip to lip. A disc the exact
		# size of the pit reads as a plate of orange paint sitting in a stone
		# ring; leaving a hand's width of dark hearth around it is what makes it
		# a bed of coals down inside something.
		"at": Vector3(-0.20, 0.26, -3.05), "radius": 0.55,
		"color": Color(1.0, 0.38, 0.12), "energy": 5.2, "range": 8.5,
	},
	Kind.ALCHEMY: {
		"at": Vector3(-1.15, 0.62, -1.55), "radius": 0.30,
		"color": Color(0.42, 0.95, 0.62), "energy": 1.4, "range": 4.2,
	},
}

var _fire: OmniLight3D
var _coals: StandardMaterial3D
var _age: float = 0.0
## Seeded from the booth's own position so two booths never breathe in lockstep.
var _phase: float = 0.0


func _ready() -> void:
	_build_props()
	_build_fire()
	_build_collision()


func _process(delta: float) -> void:
	if _fire == null:
		return
	_age += delta
	# Two waves at unrelated speeds, so the fire never settles into a pulse you
	# can count. Same trick the kit torches use, and for the same reason: a
	# regular throb reads as a machine, not a fire.
	var f := FIRES[kind] as Dictionary
	var base := float(f["energy"])
	var beat := sin(_age * 2.7 + _phase) * 0.12 + sin(_age * 6.1 + _phase * 1.7) * 0.06
	_fire.light_energy = base * (1.0 + beat)
	if _coals != null:
		_coals.emission_energy_multiplier = 2.4 * (1.0 + beat * 1.6)


# --- Construction -----------------------------------------------------------

func _build_props() -> void:
	var rows: Array = PARTS.get(kind, [])
	for r in rows:
		var row: Dictionary = r
		var path: String = DIR + String(row["f"])
		if not ResourceLoader.exists(path):
			push_error("shop_booth: no prop at %s" % path)
			continue
		var n := (load(path) as PackedScene).instantiate() as Node3D
		n.position = row["at"]
		n.rotation.y = deg_to_rad(float(row.get("yaw", 0.0)))
		add_child(n)
		if row.has("tint"):
			_tint(n, row["tint"], bool(row.get("glow", true)))


## Multiply a prop's albedo. The pack's glassware ships white so that whoever
## uses it can decide what is in the bottle; an apothecary's bench with four
## identical clear bottles on it says nothing at all.
func _tint(n: Node, c: Color, glow: bool) -> void:
	for mi in _meshes(n):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var dup := (m.duplicate() if m != null else StandardMaterial3D.new()) as StandardMaterial3D
			if dup == null:
				continue
			dup.albedo_color = c
			# Bottles are the one thing here allowed to catch the light.
			if glow:
				dup.emission_enabled = true
				dup.emission = c
				dup.emission_energy_multiplier = 0.35
			mi.set_surface_override_material(s, dup)


## The banked fire: a disc of coals and the light it throws.
##
## The coals are a flat emissive disc rather than a particle effect or an
## additive quad. STYLEGUIDE §4 and the table in CLAUDE.md §3 both say the same
## thing about the alternative -- alpha does not attenuate an ADD blend, so an
## additive glow over near-black stone renders as an opaque slab at every
## opacity. Shape carries this, not blending.
func _build_fire() -> void:
	if not FIRES.has(kind):
		return
	var f: Dictionary = FIRES[kind]
	var at: Vector3 = f["at"]
	var col: Color = f["color"]

	_coals = StandardMaterial3D.new()
	_coals.albedo_color = col
	_coals.emission_enabled = true
	_coals.emission = col
	_coals.emission_energy_multiplier = 2.4
	_coals.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = float(f["radius"])
	dm.bottom_radius = float(f["radius"]) * 0.82
	dm.height = 0.09
	dm.radial_segments = 10   # faceted; the kit's silhouettes are all N64-era
	disc.mesh = dm
	disc.material_override = _coals
	disc.position = at
	add_child(disc)

	_fire = OmniLight3D.new()
	_fire.light_color = col
	_fire.light_energy = float(f["energy"])
	_fire.omni_range = float(f["range"])
	# >1 curves the falloff so the pool has an edge instead of washing the whole
	# yard -- the same number KitStyle settled on for the torches.
	_fire.omni_attenuation = 1.35
	_fire.shadow_enabled = false
	_fire.position = at + Vector3(0.0, 0.35, 0.0)
	add_child(_fire)

	_phase = float(int(absf(position.x) * 7.0 + absf(position.z) * 13.0) % 628) * 0.01


## One box across the counter, and nothing else.
##
## Only the counter is solid. Boxing every barrel and crate would turn the back
## of each booth into a maze of invisible corners for a player who has no reason
## to walk back there, and the yard is eight seconds wide -- there is no room to
## spend on collision the player only discovers by getting stuck in it.
##
## The counter must not push the player out of talking range: `Npc` uses a 2.3 m
## trigger, the keeper stands 0.95 m behind the booth origin, and this stops the
## player about 1.1 m in front of it. That is ~2.05 m apart, which leaves the
## prompt comfortably inside its radius.
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 1.0, 0.9)
	cs.shape = box
	cs.position = Vector3(0.0, 0.5, -0.1)
	body.add_child(cs)
	add_child(body)


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append(mi)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
