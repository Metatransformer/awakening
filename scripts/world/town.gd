class_name Town
extends Node3D
## The hub. A fenced yard on open grass, four people, and a hole in the ground.
##
## It used to be a walled stone courtyard at night, which was a mistake worth
## writing down: it was built from the dungeon kit, so it rendered as one more
## interior -- the same masonry, the same dark, the same torches. The single
## strongest contrast this game can get for free is that the surface is OUTSIDE
## and the Lower Worlds are not, and the courtyard threw it away. Sky, grass and
## a waist-high fence you can see over cost three props and buy the whole of it.
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
const MAT_GRASS := preload("res://assets/materials/mat_grass.tres")
const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")

## Where the fence stands. Unchanged from the old wall line, because every NPC
## position in `_build_people` and the whole prop ring in `_build_relic_props`
## are tuned against these numbers and against the arrival camera.
@export var yard: Vector2 = Vector2(26.0, 22.0)
## The grass goes well past the fence so the town sits IN a landscape instead of
## on a slab with a void around it. Placeholder ground, on purpose -- SCOPE §3's
## gate is a played hour, not a look.
## Big enough that its straight edge is never on screen. Outdoor fog is thin (see
## `_build_env`), so it cannot be used to hide a horizon the way the dungeon's can
## -- the slab just has to run past the far clip.
@export var ground: Vector2 = Vector2(300.0, 300.0)

var vendor: Npc
var smith: Npc
var alchemist: Npc
var keeper: Npc
var gate: Npc
## The twelve dark props, in `RelicDb` catalogue order. Public so a director can
## photograph one corner before and after, which is the only way anybody can
## check the claim this system exists to make.
var lights: Array[TownLight] = []


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
	_build_relic_props()


# --- Look -------------------------------------------------------------------

## Afternoon, open sky, and unambiguously outdoors. The old build was night under
## dungeon masonry, which is what made the hub read as another room of the shaft.
##
## **The dome is Valenfeld's** (`assets/shaders/sky.gdshader`, ported wholesale).
## Over there it is driven by a world clock that repaints every uniform per hour;
## here it is pinned to ONE moment and nothing animates it. That is the whole
## point of taking it — a hand-authored gradient this project would otherwise
## have to tune from scratch, for the cost of one shader file and a dictionary of
## numbers, with no day/night system attached (`docs/SCOPE.md` §1 freezes the
## mechanic count at one, and a clock is not it).
##
## The shader blends its own day / sunset / night palette off `sun_dir.y`, so the
## sun's ELEVATION below is what picks the look. Everything else here is
## Valenfeld's daytime uniform set as `EnvironmentBuilder.build()` seeds it.
##
## ⚠ Every colour uniform is `source_color`, which means Godot sRGB->linear
## decodes it before the shader sees it. Authored numbers render far darker than
## they read on the page — Valenfeld shipped a "noon looks like night" bug on
## exactly this. Do not "correct" these down.
func _build_env() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter(&"top_color", Color(0.40, 0.55, 0.80))
	sky_mat.set_shader_parameter(&"horizon_color", Color(0.66, 0.76, 0.86))
	sky_mat.set_shader_parameter(&"ground_color", Color(0.24, 0.24, 0.23))
	sky_mat.set_shader_parameter(&"horizon_curve", 0.15)
	sky_mat.set_shader_parameter(&"sun_color", Color(1.0, 0.98, 0.93))
	sky_mat.set_shader_parameter(&"sun_energy", 1.0)
	sky_mat.set_shader_parameter(&"sun_radius", 0.046)
	sky_mat.set_shader_parameter(&"day_sky", Color(0.40, 0.55, 0.80))
	sky_mat.set_shader_parameter(&"day_horizon", Color(0.66, 0.76, 0.86))
	sky_mat.set_shader_parameter(&"sunset_sky", Color(0.40, 0.30, 0.56))
	sky_mat.set_shader_parameter(&"sunset_horizon", Color(1.00, 0.56, 0.32))
	sky_mat.set_shader_parameter(&"sunset_exponent", 1.35)
	sky_mat.set_shader_parameter(&"key_tint", 0.40)
	# Night, stars, nebulae, both moons and the aurora are all in the shader and all
	# switched off. The sun never moves here, so they can never come up -- leaving
	# them at zero is cheaper than deleting them and keeps the file a clean copy of
	# Valenfeld's, so the next port is still a `cp`.
	sky_mat.set_shader_parameter(&"night", 0.0)
	sky_mat.set_shader_parameter(&"star_brightness", 0.0)
	sky_mat.set_shader_parameter(&"nebula_intensity", 0.0)
	sky_mat.set_shader_parameter(&"moon_energy", 0.0)
	sky_mat.set_shader_parameter(&"moon2_energy", 0.0)
	sky_mat.set_shader_parameter(&"aurora_intensity", 0.0)
	sky_mat.set_shader_parameter(&"shooting_star_intensity", 0.0)
	sky_mat.set_shader_parameter(&"planet_energy", 0.0)
	# Two FBM layers the shader parallaxes against each other into billows. Generated,
	# not committed: a NoiseTexture2D is four lines and a 512px PNG is a binary nobody
	# can diff.
	sky_mat.set_shader_parameter(&"cloud_noise_a", _cloud_noise(0.012, 1))
	sky_mat.set_shader_parameter(&"cloud_noise_b", _cloud_noise(0.026, 7))
	sky_mat.set_shader_parameter(&"cloud_cover", 0.14)
	sky_mat.set_shader_parameter(&"cloud_tiling", 0.05)
	sky_mat.set_shader_parameter(&"cloud_depth", 0.35)
	sky_mat.set_shader_parameter(&"cloud_shape_exp", 1.25)

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.64, 0.63, 0.59)
	# Valenfeld's number, and its reasoning holds here: let the warm ambient COLOUR
	# lead and keep the sky's own pale-blue radiance to a quarter of the fill. At
	# full sky contribution every surface takes a blue milk wash and the sun stops
	# reading as sunlight.
	env.ambient_light_sky_contribution = 0.25
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# Aerial haze, not a draw-distance wall. The dungeon's fog is the opposite job
	# and wants ten times this density (STYLEGUIDE §4).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.66, 0.74, 0.82)
	env.fog_density = 0.0013
	env.fog_sun_scatter = 0.06
	env.fog_sky_affect = 0.10
	env.fog_aerial_perspective = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.0

	var we := WorldEnvironment.new()
	we.name = "TownEnv"
	we.environment = env
	add_child(we)

	# **The one number that sets the look, and it is the PITCH.** The dome's whole
	# palette blends off the sun's elevation: overhead is azure noon, on the horizon
	# is the golden hour, below is night.
	#
	# Not noon, and that is a design choice rather than a taste one. Twelve dark
	# props coming alight one at a time is the entire payoff of the relic system and
	# one of the three questions `docs/SCOPE.md` §4.1 makes the gate answer -- "did
	# the town changing register, or did you have to be told?" A lamp does not
	# register at midday. A lower sun keeps ambient down far enough that a warm point
	# light still reads, and rakes long shadows across the yard, which is the
	# cheapest "this is outdoors" signal there is.
	#
	# But not as low as it wants to be, either. The blend is
	# `pow(sin(pitch), sunset_exponent)`, so it collapses fast: at 24 degrees the sky
	# is already 70% of the way into `sunset_sky` and the whole dome renders LILAC.
	# 40 degrees is the balance point -- warm band at the horizon, blue overhead,
	# shadows still long. Move this and the sky changes colour; that is the knob.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-58.0), 0.0)
	add_child(sun)
	# The shader draws the sun DISC itself (a custom sky shader gets none for free),
	# so it has to be told where the light is. `-basis.z` is the direction the light
	# TRAVELS -- CLAUDE.md §4 -- so the direction *toward* the sun is +basis.z.
	sky_mat.set_shader_parameter(&"sun_dir", sun.global_transform.basis.z.normalized())


## One seamless FBM layer for the cloud deck. Ported from Valenfeld's
## `EnvironmentBuilder._cloud_noise`; the shader wants two at different
## frequencies and drifts one against the other.
func _cloud_noise(freq: float, noise_seed: int) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 4
	fn.frequency = freq
	fn.seed = noise_seed
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = fn
	return tex


func _build_yard() -> void:
	# One big grass slab. It is a `KitSlab` and not a bare PlaneMesh so the hero
	# gets the same y = 0 top face and the same L_WORLD collider he stands on
	# everywhere else -- the ground is the one thing in a scene that must not be a
	# special case.
	var turf := KIT_FLOOR.instantiate()
	turf.size = ground
	turf.face_material = MAT_GRASS
	add_child(turf)

	var hx := yard.x * 0.5
	var hz := yard.y * 0.5
	# A fence runs along local X with its face down local +Z -- the same frame the
	# wall segments used, so these four lines did not have to change when the
	# masonry did. Different seeds, or opposite sides lean identically and the eye
	# catches the mirror.
	var sides := [
		{"yaw": 0.0, "at": Vector3(0, 0, -hz), "len": yard.x, "seed": 501},
		{"yaw": PI, "at": Vector3(0, 0, hz), "len": yard.x, "seed": 502},
		{"yaw": PI * 0.5, "at": Vector3(-hx, 0, 0), "len": yard.y, "seed": 503},
		{"yaw": -PI * 0.5, "at": Vector3(hx, 0, 0), "len": yard.y, "seed": 504},
	]
	for s in sides:
		var f := Fence.new()
		f.length = float(s["len"])
		f.rng_seed = int(s["seed"])
		f.position = s["at"]
		f.rotation.y = float(s["yaw"])
		add_child(f)


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

	# The Far Lantern Society's hall, on the east side, south of the smith.
	#
	# Placed so that TURNING AWAY FROM HER FACES THE YARD. She is the only
	# counter whose reward is not on the screen you just closed -- it is a lamp
	# fifteen metres away -- so where the player is standing when they stop
	# talking to her is a design constraint and not a decoration. Her +Z (the
	# customer's side, see `ShopBooth`) points south-west across the open middle
	# of the courtyard, which puts eight of the twelve props in the frame the
	# moment the trade screen comes down.
	#
	# Clear of the smith by five metres and of the east wall by six, and clear of
	# the prop ring by two -- see `_build_relic_props`, which is phase-offset
	# partly to keep out of her lamp post.
	keeper = _counter(Npc.Role.KEEPER,
		Vector3(yard.x * 0.25, 0.0, yard.y * 0.20), -140.0, Pal.GOLD)

	gate = Npc.new()
	gate.role = Npc.Role.GATE
	gate.position = Vector3(0.0, 0.0, -yard.y * 0.40)
	add_child(gate)


## The twelve dark things, and the reason the town is worth coming home to.
##
## `docs/GDD.md` §3 names the failure this is built against by name: Moonlighter's
## town, identical on hour forty and hour one, so that late runs were payroll.
## Gold and components change the character sheet; a relic changes *the place you
## come home to*, and this ring is the entire mechanism.
##
## **A RING, not a scatter, and that is the load-bearing choice.** The gate
## question in `docs/SCOPE.md` §4.1 is "did the town changing register, or did
## you have to be told?" -- so the test a placement has to pass is *at least one
## of these is in frame from wherever the player is standing when a lamp comes
## on*, and a ring around the perimeter is the only arrangement that passes it
## from every position in the yard. Props tucked into the corners they
## thematically belong to (the mill by the mill, the kiln by the glasshouse)
## would read better in a screenshot of the finished town and fail the only test
## that matters, because eleven of the twelve would be behind you.
##
## Order is `RelicDb.props()`, which is catalogue order, so the FIRST relic the
## player can possibly find (the Cistern's deep chest, floor 1) lights the lamp
## nearest the gate -- the thing they walk past on the way back down.
##
## Twelve unshaded boxes on twelve posts. GDD §6.2: "do not spend more than a
## prop on it."
func _build_relic_props() -> void:
	var props := RelicDb.props()
	# Inset from the walls by enough that a lamp is a thing standing IN the yard
	# rather than a light smeared on masonry, and the torches (which live flat
	# against the two long walls) stay a clear metre behind them.
	var rx := yard.x * 0.5 - 2.0
	var rz := yard.y * 0.5 - 2.0
	for i in props.size():
		# Starting a quarter-step past due north, not on it and not on the
		# half-step: due north is the gate's arch, and the half-step puts two of
		# them inside the pillars at z = -0.55 * hz. A quarter-step misses both.
		var a: float = -PI * 0.5 + (float(i) + 0.25) * TAU / float(props.size())
		var light := TownLight.new()
		light.prop = props[i]
		light.position = Vector3(cos(a) * rx, 0.0, sin(a) * rz)
		add_child(light)
		lights.append(light)


## The prop `RelicDb` calls `prop`, or null. For a director that wants to
## photograph one corner twice.
func light_of(prop: StringName) -> TownLight:
	for l in lights:
		if l.prop == prop:
			return l
	return null


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
