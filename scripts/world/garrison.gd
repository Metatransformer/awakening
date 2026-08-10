class_name Garrison
extends Node3D
## The hub. **A garrison, not a town** -- the Highbridge people's walled camp
## over the mouth of the mine. Four people, a yard, and a hole in the ground.
##
## Two mistakes are recorded here because the fix for each broke the other, and
## the current build is the shape that satisfies both:
##
##   1. **It was a stone courtyard at night**, built from the dungeon kit, so it
##      photographed as one more interior -- same masonry, same dark, same
##      torches. The strongest contrast this game gets for free is that the
##      surface is outside and the Lower Worlds are not, and the courtyard threw
##      it away.
##   2. **Then it was an open yard behind a waist-high fence**, which fixed that
##      and cost something else: you could see straight out over the rail at a
##      placeholder plain that runs flat to the horizon in every direction. An
##      empty world visible past the only safe place in the game is worse than no
##      world at all.
##
## So: curtain walls high enough that the horizon never clears them, and DAYLIGHT
## AND SKY AND GRASS INSIDE them. Sky overhead is what keeps a walled yard reading
## as a fort rather than as a room whose ceiling failed to load. Those are the two
## halves; do not remove either one thinking it is decoration.
##
## Deliberately TINY -- about eight seconds of walking, corner to corner. The
## garrison is not content; it is the place where the number in your bag turns
## into a number you keep, and every extra metre of it is a tax on the loop.
## Moonlighter earns its town by making you run a shop in it. This one does not,
## so it does not get to be big.
##
## It is also the only warm, lit, safe place in the game, which is what makes the
## gate's cold mouth mean something.

const KIT_FLOOR := preload("res://scenes/kit/floor_slab.tscn")
const KIT_WALL := preload("res://scenes/kit/wall_segment.tscn")
const KIT_PILLAR := preload("res://scenes/kit/pillar.tscn")
const MAT_GRASS := preload("res://assets/materials/mat_grass.tres")
## The kit's own stone, at a daylight albedo.
##
## Not a second look -- the SAME texture and normal map as `mat_wall.tres`, with
## albedo lifted 0.46 -> 0.82. The dungeon's 0.46 is tuned against a torch at
## `KitStyle.FIRE_ENERGY` 9.5 sitting two metres away; under one directional sun
## at 1.35 the identical number renders the curtain as a black band across the top
## of the frame. Same masonry, two lighting regimes, two albedos. If the dungeon
## ever changes stone, change it in both.
const MAT_WALL_SUNLIT := preload("res://assets/materials/mat_wall_sunlit.tres")
const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")

## Clear width left between the two shaft-head rails, so the arch is walkable.
const RAIL_GAP := 5.0

## Set the first time a save sees the courtyard. See `_open_the_game`.
const INTRO_FLAG := &"reported_for_duty"

## Where the curtain stands. Unchanged through both rebuilds, because every NPC
## position in `_build_people` and the whole prop ring in `_build_relic_props`
## are tuned against these numbers and against the arrival camera.
@export var yard: Vector2 = Vector2(26.0, 22.0)
## The grass runs well past the walls, so the garrison sits IN a landscape
## rather than on a slab with a void around it. Placeholder ground, on purpose
## -- SCOPE §3's gate is a played hour, not a look. Nothing inside the yard can
## see any of it now; it is for the lookdev and rampart-height cameras, and for
## the day somebody cuts a gate in the north wall.
@export var ground: Vector2 = Vector2(300.0, 300.0)
## **Tall enough that you cannot see out, and that is the requirement, not a
## style.** The game camera sits around 3 m and pitches about thirty degrees
## down; anything past roughly 4 m already puts the skyline behind masonry, and 6
## gives margin for the pitch-up. Drop this and the empty placeholder plain comes
## back into frame over the parapet.
@export var wall_height: float = 6.0

var vendor: Npc
var smith: Npc
var alchemist: Npc
var keeper: Npc
var jeweller: Npc
var elder: Npc
var gate: Npc
## The hero's billet, in the south-west corner. Public so a director can walk to
## it without knowing where the corner is.
var house: House
## The twelve dark props, in `RelicDb` catalogue order. Public so a director can
## photograph one corner before and after, which is the only way anybody can
## check the claim this system exists to make.
var lights: Array[GarrisonLight] = []


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
	_build_house()
	_build_people()
	_build_relic_props()
	_open_the_game()


## The first thirty seconds of a new game: a voice in the dark, then the yard,
## then the man who sent for you.
##
## **Once per save, not once per boot.** The gate is `Game.flags`, which is
## persisted (`Saves`) and cleared by `Game.reset()`, so it is the flag set every
## other one-way thing in the game uses -- a loaded save comes back to a garrison
## that does not re-introduce itself, and a new game gets the opening even if the
## player has launched the game a hundred times. It is also why this sits behind
## a flag at all rather than behind "is this the first scene of the process":
## `Flow` brings you back through here after every single run.
##
## The order is the whole of it, and each beat is doing a job the next one needs:
##
##   1. **The narration plays over black.** Before the yard, because the yard
##      answers the question the narration is asking -- you arrive at the
##      garrison having been told what the Sunken Cut is, not while looking at it.
##   2. **The veil lifts on the courtyard**, with the elder centre-frame.
##   3. **"I've been expecting you."** After the fade rather than under it,
##      because it is addressed to a man who has just walked through the gate,
##      and a line delivered to a black screen is a line nobody is in the room
##      for. It is also the tutorial: the first voice you hear in the world comes
##      from the one person in it who is standing in the open, which is a cheaper
##      way of saying "go and talk to him" than a prompt would be.
##
## Nothing here waits on a signal. `Voice.say` returns the length of what it
## started -- 0.0 if the file is missing -- so the worst a broken import can do is
## skip the opening, rather than hold the veil down forever.
func _open_the_game() -> void:
	if Game.flag(INTRO_FLAG):
		return
	Game.set_flag(INTRO_FLAG)

	var narration := Voice.say(&"narrator", &"opening")
	# A beat of silence on the black after the last word, so the fade is a
	# response to the narration rather than an interruption of it.
	await Flow.open_on_black(narration + 0.6)
	# And a beat with the yard visible before he speaks, for the same reason in
	# the other direction: the player needs a moment to see where they are
	# standing before somebody starts talking to them.
	await get_tree().create_timer(0.5).timeout
	Voice.say(&"elder", &"arrival")


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
	we.name = "GarrisonEnv"
	we.environment = env
	add_child(we)

	# **The one number that sets the look, and it is the PITCH.** The dome's whole
	# palette blends off the sun's elevation: overhead is azure noon, on the horizon
	# is the golden hour, below is night.
	#
	# Not noon, and that is a design choice rather than a taste one. Twelve dark
	# props coming alight one at a time is the entire payoff of the relic system
	# and one of the three questions `docs/SCOPE.md` §4.1 makes the gate answer
	# -- "did the garrison changing register, or did you have to be told?" A
	# lamp does not register at midday. A lower sun keeps ambient down far
	# enough that a warm point light still reads, and rakes long shadows across
	# the yard, which is the cheapest "this is outdoors" signal there is.
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
	# The curtain. A `KitWall` runs along local X with its finished face down local
	# +Z, which is the frame the fence borrowed, so these four lines have survived
	# both boundaries unchanged. Different seeds, or opposite sides get an identical
	# block field and the eye catches the mirror.
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
		w.material = MAT_WALL_SUNLIT
		w.position = s["at"]
		w.rotation.y = float(s["yaw"])
		add_child(w)

	# Corner towers -- pillars run a third taller than the curtain, so the yard has
	# four hard verticals at its corners instead of a continuous band of masonry.
	# That is most of what separates a fort from a room with no ceiling.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := KIT_PILLAR.instantiate()
			p.height = wall_height * 1.32
			p.material = MAT_WALL_SUNLIT
			p.position = Vector3(hx * sx, 0.0, hz * sz)
			add_child(p)

	# A rail round the shaft head, either side of the arch. Two runs of the same
	# fence the boundary used to be -- a working mine has something stopping people
	# walking into it in the dark, and it is the one thing in the yard that says the
	# hole is a hole before you are standing on it.
	for sx in [-1.0, 1.0]:
		var rail := Fence.new()
		rail.length = 5.0
		rail.rng_seed = 540 + int(sx)
		rail.position = Vector3((RAIL_GAP * 0.5 + 2.5) * sx, 0.0, -yard.y * 0.40 + 1.4)
		add_child(rail)


## The hero's quarters, tucked into the south-west corner.
##
## **The corner is the whole of the placement argument, and it is arithmetic
## rather than taste.** Everything else in the yard is spoken for: the gate and
## the shaft head are due north, the vendor and the smith flank them, the
## alchemist stands on the west side inside the arrival frame that `_build_people`
## says must not be broken, and the Lanternkeeper has the south-east with her
## facing tuned so that turning away from her shows eight relic props. The
## south-west is the one quadrant no existing tuning reads.
##
## It also has to miss the relic ring, which is the constraint that actually
## fixes the size. `_build_relic_props` puts twelve lamps on an ellipse of
## (11.0, 9.0) at quarter-step offsets; the two either side of this corner land
## at (-10.16, 3.44) and (-6.70, 7.14). A 5.2 m room whose outer corner is the
## yard's clears the first by 2.2 m in z and the second by 0.9 m in x. **Grow the
## room and you move a lamp**, and the ring's whole argument (§ the note on
## `_build_relic_props`) is that it is evenly spaced.
##
## Deliberately NOT lit by a `GarrisonLight`. The twelve are a set that comes on
## one at a time and means something; a thirteenth warm light that was on from
## the first frame would be the one prop in the yard whose state says nothing.
func _build_house() -> void:
	house = House.new()
	# Its own two walls go on -X and +Z, so the corner it wants is the corner of
	# the yard, inset by half the room plus enough to clear the curtain's block
	# relief (KitStyle.RELIEF, 0.17 proud of the placement plane).
	var hx := yard.x * 0.5
	var hz := yard.y * 0.5
	var half := house.room * 0.5
	house.position = Vector3(-hx + half.x + 0.2, 0.0, hz - half.y - 0.2)
	add_child(house)


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

	# The jewelcrafter, hard against the WEST wall and side-on to the yard.
	#
	# Her place in the loop is what fixes her position, not the free floor: her
	# whole offer is "spend back what the plate cost you" (GDD §6.6), so she has
	# to come AFTER the smith. The smith is at the north end; the walk from him
	# to the gate runs down this wall. Standing her beside the forge would let a
	# player answer the heavy-or-light trade before they had felt it.
	#
	# Two constraints pin the exact metre, and both have already caught someone:
	#
	#  * **Inside the arrival frame.** z = +1.1 is forward of the arrival spot
	#    (z ≈ +4.8) rather than behind it, so she is on screen on the one frame
	#    every returning player sees. That is the note over the alchemist, and
	#    the first cut of this row put her at z = +6.6 -- behind the camera.
	#  * **Out of the relic ring.** `_build_relic_props` puts twelve lamp posts
	#    on an ellipse of (11, 9); the two nearest this wall land at (-10.16,
	#    3.44) and (-10.91, -1.17). This is the gap between them.
	#
	# Yaw 90° faces her +Z down +X, into the yard, which also means `_counter`
	# steps her BACK toward the wall rather than out into the walk.
	jeweller = _counter(Npc.Role.JEWELLER,
		Vector3(-yard.x * 0.396, 0.0, yard.y * 0.05), 90.0, Color(0.80, 0.62, 0.94))

	# The elder, in the open middle of the yard, facing the arrival.
	#
	# **This is the one position in this function that is about the FIRST frame
	# rather than about the loop.** The hero spawns at (0, 0, +4) with the camera
	# behind him at (0, 1.7, +8); everybody else in here is against a wall or in a
	# corner, so the middle is the only place that is unambiguously *in front of
	# you* when the opening's veil lifts. You are reporting for duty and the person
	# you report to should not have to be found.
	#
	# **It was dead centre first, at (0, 0, +0.4), and the capture is why it is
	# not** -- `v_01_arrival` from `tools/directors/voices.gd`, which is the only
	# thing in the build that would ever have shown it. Two failures, both
	# invisible from the code:
	#
	#  * **The hero stood in front of him.** The arrival camera, the hero and the
	#    yard's centre line are all x = 0, so the one figure the frame exists to
	#    introduce was directly behind the one figure that is always drawn.
	#  * **He was standing IN THE GATE.** The mouth is a 2.5 m cyan quad at
	#    x = 0, and it is the only cold thing in a warm courtyard on purpose
	#    (`Npc._build_gate`). A person silhouetted against it stops reading as a
	#    person and starts reading as something in the doorway, and takes the
	#    gate's signposting down with him.
	#
	# So: two metres right of the centre line, which clears both the hero and the
	# arch (posts at x = ±1.55), and two metres nearer the spawn, which makes him
	# the largest figure in the arrival frame. Still open ground, still nobody's
	# counter, and still off the walk from the spawn to the gate -- that runs
	# straight down x = 0 and he is deliberately not standing in it.
	#
	# Yaw 0 leaves his +Z (the side a keeper is addressed from, see `ShopBooth`)
	# pointing down +Z at the arrival spot. He has no booth, so the only thing
	# that actually places is his lamp post.
	elder = _stand(Npc.Role.ELDER, Vector3(2.0, 0.0, 1.8), 0.0,
		Color(1.00, 0.92, 0.72))

	gate = Npc.new()
	gate.role = Npc.Role.GATE
	gate.position = Vector3(0.0, 0.0, -yard.y * 0.40)
	add_child(gate)


## The twelve dark things, and the reason the garrison is worth coming home to.
##
## `docs/GDD.md` §3 names the failure this is built against by name: Moonlighter's
## town, identical on hour forty and hour one, so that late runs were payroll.
## Gold and components change the character sheet; a relic changes *the place you
## come home to*, and this ring is the entire mechanism.
##
## **A RING, not a scatter, and that is the load-bearing choice.** The gate
## question in `docs/SCOPE.md` §4.1 is "did the garrison changing register, or
## did you have to be told?" -- so the test a placement has to pass is *at least
## one of these is in frame from wherever the player is standing when a lamp
## comes on*, and a ring around the perimeter is the only arrangement that
## passes it from every position in the yard. Props tucked into the corners they
## thematically belong to (the mill by the mill, the kiln by the glasshouse)
## would read better in a screenshot of the finished garrison and fail the only
## test that matters, because eleven of the twelve would be behind you.
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
		var light := GarrisonLight.new()
		light.prop = props[i]
		light.position = Vector3(cos(a) * rx, 0.0, sin(a) * rz)
		add_child(light)
		lights.append(light)


## The prop `RelicDb` calls `prop`, or null. For a director that wants to
## photograph one corner twice.
func light_of(prop: StringName) -> GarrisonLight:
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


## Somebody standing in the open, placed where they are standing.
##
## The difference from `_counter` is one line and it is the whole point of having
## two functions: a keeper's coordinate is where their COUNTER goes and the
## person steps back behind it, so passing the elder through `_counter` would
## quietly put him 0.95 m behind the spot this file says he is on -- and the spot
## is the entire argument for his placement.
func _stand(role: Npc.Role, at: Vector3, yaw_deg: float, lamp: Color) -> Npc:
	var n := Npc.new()
	n.role = role
	n.lamp_color = lamp
	n.rotation.y = deg_to_rad(yaw_deg)
	n.position = at
	add_child(n)
	return n
