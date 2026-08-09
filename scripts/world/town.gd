class_name Town
extends Node3D
## The hub. A walled yard, three people, and a hole in the ground.
##
## Deliberately TINY -- about eight seconds of walking, corner to corner. The
## town is not content; it is the place where the number in your bag turns into
## a number you keep, and every extra metre of it is a tax on the loop. Moonlighter
## earns its town by making you run a shop in it. This one does not, so it does
## not get to be big.
##
## It is also the only warm, lit, safe place in the game, which is what makes the
## gate's cold mouth mean something.

const KIT_FLOOR := preload("res://scenes/kit/floor_slab.tscn")
const KIT_WALL := preload("res://scenes/kit/wall_segment.tscn")
const KIT_TORCH := preload("res://scenes/kit/torch.tscn")
const KIT_PILLAR := preload("res://scenes/kit/pillar.tscn")

@export var yard: Vector2 = Vector2(26.0, 22.0)
@export var wall_height: float = 4.2

var vendor: Npc
var smith: Npc
var alchemist: Npc
var gate: Npc


## Deliberately says nothing about the run you just finished.
##
## There used to be a `Label3D` here that read "YOU DIED / LOST N ITEMS" over the
## yard, on the reasoning that a modal summary would stop the loop dead. The
## reasoning was fine and the execution never worked: it was authored at
## (0, 2.6, +6.6) and the arrival camera sits at (0, 1.7, +8) pitched about thirty
## degrees down, so the notice was roughly sixty degrees above the middle of the
## only frame a returning player ever sees. The game had a death notice nobody had
## ever read, in the wrong room — a run ends underground, and it is
## `RunEndScreen` (scripts/ui/run_end/) that says so now, over the floor it ended
## on, before the ride home. Do not re-add a second one here.
func _ready() -> void:
	_build_env()
	_build_yard()
	_build_people()


# --- Look -------------------------------------------------------------------

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Pal.VOID
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.24, 0.34)
	env.ambient_light_energy = 0.55
	# Fog as a draw-distance wall, same treatment as the dungeon (STYLEGUIDE §4).
	# In town it only has to hide the fact that there is nothing past the walls.
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.09, 0.14)
	env.fog_density = 0.022
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.0

	var we := WorldEnvironment.new()
	we.name = "TownEnv"
	we.environment = env
	add_child(we)

	# One cold key from above, so the yard reads as open sky at night rather than
	# as an unlit room. Everything warm in town comes from a torch or a lantern.
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.52, 0.58, 0.80)
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	add_child(moon)


func _build_yard() -> void:
	var ground := KIT_FLOOR.instantiate()
	ground.size = yard
	add_child(ground)

	var hx := yard.x * 0.5
	var hz := yard.y * 0.5
	var sides := [
		{"yaw": 0.0, "at": Vector3(0, 0, -hz), "len": yard.x, "seed": 501},
		{"yaw": PI, "at": Vector3(0, 0, hz), "len": yard.x, "seed": 502},
		{"yaw": PI * 0.5, "at": Vector3(-hx, 0, 0), "len": yard.y, "seed": 503},
		{"yaw": -PI * 0.5, "at": Vector3(hx, 0, 0), "len": yard.y, "seed": 504},
	]
	for s in sides:
		var w := KIT_WALL.instantiate()
		w.length = float(s["len"])
		w.height = wall_height
		w.rng_seed = int(s["seed"])
		w.position = s["at"]
		w.rotation.y = float(s["yaw"])
		add_child(w)

	# Torches only along the two long walls, so the yard has a lit spine and dim
	# corners rather than an even wash.
	var n := 0
	for x in [-hx * 0.55, 0.0, hx * 0.55]:
		for z in [-hz, hz]:
			var t := KIT_TORCH.instantiate()
			t.rng_seed = 520 + n
			t.cast_shadow = n < 3
			t.position = Vector3(x, KitStyle.SCONCE_Y, z)
			t.rotation.y = 0.0 if z < 0.0 else PI
			add_child(t)
			n += 1

	for sx in [-1.0, 1.0]:
		var p := KIT_PILLAR.instantiate()
		p.height = wall_height
		p.position = Vector3(hx * 0.62 * sx, 0.0, -hz * 0.55)
		add_child(p)


func _build_people() -> void:
	# The two counters you visit with a FULL BAG share the far wall either side
	# of the gate, angled in so the north end of the yard reads as a row of
	# shops facing you rather than three strangers standing in a line.
	vendor = _counter(Npc.Role.VENDOR,
		Vector3(-yard.x * 0.26, 0.0, -yard.y * 0.06), 18.0, Pal.GOLD)
	smith = _counter(Npc.Role.SMITH,
		Vector3(yard.x * 0.26, 0.0, -yard.y * 0.06), -18.0, Color(0.98, 0.56, 0.24))

	# West side, ahead of the arrival spot but well short of the far wall.
	#
	# The alchemist is the one you visit on the way back OUT, bench already
	# banked and gold in hand, so she stands nearer the near end of that walk and
	# faces south -- you meet her front-on walking up to the gate.
	#
	# The z was +0.22 of the yard first, which is level with where the hero lands
	# -- and the arrival capture showed the consequence: she was BEHIND the
	# camera on the one frame every returning player sees. A shop you have to
	# turn around to discover is a shop that does not exist. Anything here has to
	# stay inside the arrival frame; the shot that proves it is `m_19_home` from
	# `mvp_loop`, and nothing else in the build will notice if you break it.
	#
	# Her lamp is WARM, though every other green thing about her stayed green.
	# It used to match her cauldron, and two green sources put a wash across the
	# west half of the yard that reached the flagstones in front of the gate --
	# the one place in the game that belongs to cyan (STYLEGUIDE §2). The pot,
	# the shelf and the potions say "apothecary" perfectly well on their own; the
	# lamp's job is to be a warm light on a face.
	alchemist = _counter(Npc.Role.ALCHEMIST,
		Vector3(-yard.x * 0.10, 0.0, yard.y * 0.11), 12.0, Color(0.96, 0.80, 0.52))

	gate = Npc.new()
	gate.role = Npc.Role.GATE
	gate.position = Vector3(0.0, 0.0, -yard.y * 0.40)
	add_child(gate)


## One shopkeeper, standing behind their own booth.
##
## **`at` is where the COUNTER goes, not the keeper.** Every one of these
## positions was tuned when an NPC was a single box -- the alchemist's in
## particular is pinned to what the arrival camera can see, and the comment
## above it is there because nothing else in the build would catch her drifting
## out of frame. Now that each of them has a stall in front of them, placing the
## keeper at the old coordinate would push all three counters a metre further
## into the yard and quietly invalidate that tuning. So the counter inherits the
## old spot and the keeper steps back behind it, along their own facing.
func _counter(role: Npc.Role, at: Vector3, yaw_deg: float, lamp: Color) -> Npc:
	var n := Npc.new()
	n.role = role
	n.lamp_color = lamp
	n.rotation.y = deg_to_rad(yaw_deg)
	n.position = at - n.transform.basis * Vector3(0.0, 0.0, ShopBooth.KEEPER_BACK)
	add_child(n)
	return n
