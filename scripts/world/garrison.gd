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

## Where the paved circle sits, and how far out the counters ring it.
##
## **Every shop in the yard is placed off these two numbers**, so the layout is
## one polar coordinate per keeper (`_ring`) instead of five hand-tuned Vector3s
## that only agree with each other by accident. The circle is what the yard was
## missing: five counters against four different walls is a field with furniture
## round the edge, and no amount of tuning any single position fixes that,
## because the problem was never any one of them.
##
## Two metres south of the yard's own centre. The plaza has to sit between the
## arrival and the gate WITHOUT swallowing either -- the hero lands at (0, 0, +4)
## and the paving now stops at +3.8, so he steps onto it rather than onto it.
const PLAZA_AT := Vector3(0.0, 0.0, -2.0)
const PLAZA_R := 5.8
## Counters stand just outside the kerb: 7.0 puts the counter face about a metre
## clear of the paving, which leaves the ring of stone unobstructed all the way
## round. A keeper's own body steps a further `ShopBooth.KEEPER_BACK` out (see
## `_counter`), and the deepest booth -- the forge, whose hearth is 3.05 m behind
## its bench -- then reaches 11 m from the centre. That is the number that fixes
## this at 7.0 and not 8: at 8 the smith's hearth is inside the north wall.
const KIOSK_R := 7.0

## Set the first time a save sees the courtyard. See `_open_the_game`.
const INTRO_FLAG := &"reported_for_duty"

## Where the curtain stands. Unchanged through both rebuilds, because every NPC
## position in `_build_people` and the whole prop ring in `_build_relic_props`
## are tuned against these numbers and against the arrival camera.
@export var yard: Vector2 = Vector2(26.0, 22.0)
## The grass runs well past the walls, so the garrison sits IN a landscape
## rather than on a slab with a void around it. Placeholder ground, on purpose
## -- SCOPE §3's gate is a played hour, not a look. Nothing inside the yard can
## see any of it now -- the gatehouse's own passage is roofed and walled all the
## way through, so even standing under the arch you are looking at masonry and not
## at the plain. It is for the lookdev and rampart-height cameras.
@export var ground: Vector2 = Vector2(300.0, 300.0)
## **Tall enough that you cannot see out, and that is the requirement, not a
## style.** The game camera sits around 3 m and pitches about thirty degrees
## down; anything past roughly 4 m already puts the skyline behind masonry, and 6
## gives margin for the pitch-up. Drop this and the empty placeholder plain comes
## back into frame over the parapet.
@export var wall_height: float = 6.0

## The people. **`smith`, `alchemist` and `jeweller` are null until they arrive**
## (`StoryDb.UNLOCKS`, and see `_build_people`) — a fresh save's yard has Aldric,
## Kessa and the way down in it and nothing else. Anything that reaches for one of
## these has to check; the directors get all five because `tools/shoot.gd` stamps
## the arrival flags.
var vendor: Npc
var smith: Npc
var alchemist: Npc
var keeper: Npc
var jeweller: Npc
var gate: Npc
## The hero's billet, in the south-west corner. Public so a director can walk to
## it without knowing where the corner is.
var house: House
## The paved circle, and the carved figure standing on the middle of it. Public
## so a director can frame the plaza without re-deriving where it is.
var plaza: Plaza
var statue: Statue
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
	_build_plaza()
	_build_house()
	_build_people()
	_build_relic_props()
	_open_the_game()


## The last beat of a new game's opening: the man who sent for you, once the
## picture has gone and you can see where you are standing.
##
## **Once per save, not once per boot.** The gate is `Game.flags`, which is
## persisted (`Saves`) and cleared by `Game.reset()`, so it is the flag set every
## other one-way thing in the game uses -- a loaded save comes back to a garrison
## that does not re-introduce itself, and a new game gets the opening even if the
## player has launched the game a hundred times. It is also why this sits behind
## a flag at all rather than behind "is this the first scene of the process":
## `Flow` brings you back through here after every single run.
##
## ## The narration is not here any more
##
## It used to be: `Voice.say(&"narrator", &"opening")` over `Flow.open_on_black`,
## fifteen seconds of a voice in an empty black rectangle. It moved to
## `Cutscene.OPENING` on 2026-08-10 -- same take, same place in the order, now
## with the road painting behind it and the words written out under it, raised by
## `Flow.new_game` before this scene is ever shown. **Do not re-add it here.**
## Two things saying the opening is two openings, and the one in `Flow` is the
## one with a picture.
##
## What is left is the beat that always belonged to the room rather than to the
## black: **"I've been expecting you."** After the fade rather than under it,
## because it is addressed to a man who has just walked through the gate, and a
## line delivered to a screen the player cannot see past is a line nobody is in
## the room for. It is also the tutorial: the first voice you hear in the WORLD is
## the elder's, and he is the counter that matters least to a first run and most
## to a tenth, which is a cheaper way of saying "go and talk to him" than a prompt
## would be.
##
## **He is the Lanternkeeper.** The elder used to stand alone in the middle of the
## yard so that the veil lifting would find him; they became one person on
## 2026-08-10 (`Npc.COUNTERS`) and this line now comes from behind the relic
## counter on the east side. `Voice.say` is not positional (`Voice`'s header,
## third rule) so the line is unchanged by the move -- but the FRAME is, and
## `v_01_arrival` in `tools/directors/voices.gd` is the thing that says whether
## he is still in it.
##
## ## The timer does NOT run while the cutscene is up
##
## `process_always = false` -- the third argument, and the load-bearing one. This
## `_ready` fires during `change_scene_to_file`, which `Flow.new_game` calls
## *behind* the opening picture with the tree about to be paused for the whole of
## it. A default timer is `process_always = true` and would tick straight through
## that pause, so the elder would greet an empty room a second into the narration
## and be finished long before anyone could see him. Held this way, the clock only
## starts when the world does, which is the frame the picture begins to lift.
func _open_the_game() -> void:
	if Game.flag(INTRO_FLAG):
		# Every OTHER arrival in the yard, which is most of them: home from a run,
		# or a save loaded. Nothing is owed here except the introductions -- see
		# `_do_the_rounds`, and the short wait it starts with.
		_do_the_rounds()
		return
	Game.set_flag(INTRO_FLAG)

	# Long enough to cover `Flow.FADE_IN` and leave a beat of quiet courtyard
	# after it: the player needs a moment to see where they are standing before
	# somebody starts talking to them.
	await get_tree().create_timer(1.4, false).timeout
	# In a box, with his face in it, since the dialogue system landed -- the same
	# box every counter uses, with NO options on it. That is the whole difference
	# between the two shapes: a conversation asks something and waits, and this one
	# does not. He says his line, you press once, and the garrison is yours.
	#
	# It is still a `Voice.say` underneath (`DialogueDb.speak`), so the line, the
	# timing and `voices.gd` B1 are all unchanged -- what is new is that you can
	# see who said it.
	var pages := DialogueDb.speak(&"elder", &"arrival")
	# ...and then he actually says what this place is.
	#
	# The briefing is a `StoryDb` beat like any other and would be waiting for the
	# player's first TALK on its own. It is pulled forward and stapled to the
	# recorded line here because of what it contains: what the outpost is for, who
	# pays for it, what happened to the last cadet, that Kessa buys, that the chest
	# by the bed is the only thing the pack does not eat. A player who wandered to
	# the gate instead of to the old man would be underground without any of it,
	# and this is the one moment in the game where they are standing still,
	# looking at him, with nothing else to do.
	#
	# `on_read` is what makes this not a second copy: the beat is marked told when
	# these pages are turned, so his first greeting afterwards is the NEXT thing he
	# owes. Escape out of it and it is still owed -- see `DialogueBox.open`.
	var beat := StoryDb.pending(&"elder")
	var on_read := Callable()
	if not beat.is_empty():
		pages.append_array(StoryDb.pages_of(beat))
		var beat_id := StringName(beat.get("id", &""))
		on_read = func() -> void: StoryDb.mark_told(&"elder", beat_id)
	var box := DialogueBox.open(self, &"elder", pages, [], on_read)
	# And straight into "this is Kessa, she buys". The briefing ends by telling you
	# to go and see the quartermaster, so the introduction is the next sentence out
	# of the same man's mouth and not a second conversation you have to start.
	if box != null:
		await box.finished
	_do_the_rounds()


## Play whatever introductions are owed, in ladder order.
##
## **This is the "cutscene" half of an unlock.** Beating the sluice keeper puts a
## maker's mark in your pack and the smith in the yard (`StoryDb.UNLOCKS`), but a
## new shopkeeper who simply APPEARS between one run and the next is a change the
## player has to notice on their own -- and the person most likely to miss it is
## the one who came home with three hearts left and walked straight to their bed.
## So the elder introduces them, once, the first time you are back in the yard
## after they arrive.
##
## A loop and not a single call: a good run can take the miniboss and the boss
## together, and two people arriving at once should be two scenes back to back
## rather than one scene and one silent stranger.
##
## Fire-and-forget from `_open_the_game` -- nothing awaits this, and the yard is
## fully built and playable underneath it. `DialogueBox` blocks the hero for the
## length of each box on its own (`Prompt.block`), which is the whole of the
## "cutscene" this needs to be.
func _do_the_rounds() -> void:
	# A beat of quiet first, for the same reason the opening has one: `_ready` runs
	# during `change_scene_to_file`, so with no wait the first line of the scene is
	# typed behind `Flow`'s fade and the pan happens where nobody can see it.
	await get_tree().create_timer(1.2, false).timeout
	var who := StoryDb.pending_introduction()
	while who != &"":
		await Introduction.play(self, who)
		who = StoryDb.pending_introduction()


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
	# **The north side is TWO runs with a hole between them**, and the hole is
	# where the gatehouse stands. That is the difference between a fort with a way
	# out of it and a fort with a monument parked against the inside of one wall:
	# the arch has to be cut through the defences, or the eye reads the curtain as
	# continuous and the gate as furniture.
	#
	# The gap is `Gatehouse.FACE_W` exactly. The towers are wider than the face
	# and so bury the last metre of each run inside themselves, which is what a
	# gatehouse does to the wall it is built into and costs nothing to allow.
	var gap := Gatehouse.FACE_W
	var run := (yard.x - gap) * 0.5
	var run_x := gap * 0.5 + run * 0.5
	var sides := [
		{"yaw": 0.0, "at": Vector3(-run_x, 0, -hz), "len": run, "seed": 501},
		{"yaw": 0.0, "at": Vector3(run_x, 0, -hz), "len": run, "seed": 505},
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
	for sx: float in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := KIT_PILLAR.instantiate()
			p.height = wall_height * 1.32
			p.material = MAT_WALL_SUNLIT
			p.position = Vector3(hx * sx, 0.0, hz * sz)
			add_child(p)

	# The rails, which used to lie ACROSS the yard either side of the shaft head
	# and now run WITH the walk, either side of the approach to the gate.
	#
	# Same fence and the same job -- a working mine keeps people off the mouth of
	# it -- but a rail turned ninety degrees stops being a barrier and becomes an
	# avenue, and the last eight metres before the gatehouse is the one stretch of
	# this yard that wants to be a formal approach rather than open ground.
	#
	# They stop at z = -9.1. The gatehouse's towers come forward to -9.15
	# (`Gatehouse`: 3.7 m deep, centred on the wall line), so this is the fence
	# ending against the tower rather than growing through it.
	for sx: float in [-1.0, 1.0]:
		var rail := Fence.new()
		rail.length = 3.0
		rail.rng_seed = 540 + int(sx)
		rail.position = Vector3(4.2 * sx, 0.0, -7.6)
		rail.rotation.y = PI * 0.5
		add_child(rail)


## The paving, and the thing standing on the middle of it.
##
## Built BEFORE the people, because the people are placed off `PLAZA_AT` and the
## statue has to be in the tree first for the Lanternkeeper's spot to have
## anything behind it.
##
## The statue is set 3.9 m off the plaza's middle, north-east. **Not due north**,
## which was the first cut and which put a 4 m column of stone directly between
## the arrival camera and the gate. Swinging it out to x = +2.8 clears the walk
## to the arch and is the more interesting composition: you arrive looking at a
## figure with a bigger figure over its shoulder, rather than at two things
## stacked.
##
## `STATUE_BEARING` is its OWN number now. It used to be read off `KEEPER_YAW` --
## the monument stood at the Lanternkeeper's back, which was true and tidy right
## up until he left the middle of the plaza to stand in front of the hero. A
## statue that follows a person around is a statue nobody can place; this is a
## monument on a paved circle and the circle is what it belongs to.
func _build_plaza() -> void:
	plaza = Plaza.new()
	plaza.radius = PLAZA_R
	plaza.position = PLAZA_AT
	add_child(plaza)

	statue = Statue.new()
	var out := Vector3(sin(deg_to_rad(STATUE_BEARING)), 0.0, -cos(deg_to_rad(STATUE_BEARING)))
	statue.position = PLAZA_AT + out * 3.9
	# Looking back across the plaza at the people arriving, which is what it was
	# doing before and where the value comes from -- it is the yaw `KEEPER_YAW`
	# used to hand it, written down now that the keeper no longer stands here.
	statue.rotation.y = deg_to_rad(STATUE_YAW)
	add_child(statue)


## The hero's quarters, tucked into the south-west corner.
##
## **The corner is the whole of the placement argument, and it is arithmetic
## rather than taste.** Everything else in the yard is spoken for: the gate and
## the shaft head are due north, the vendor and the smith flank them, the
## alchemist stands on the west side inside the arrival frame that `_build_people`
## says must not be broken, and the Lanternkeeper has the centre line and the
## paving in front of the arrival. The south-west is the one quadrant no existing
## tuning reads.
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


## Where the Lanternkeeper stands, and which way he looks.
##
## **Conversation distance in front of where the hero lands, half a pace off his
## shoulder.** The hero arrives at (0, 0, +4) and the arrival camera sits behind
## him at (0, 1.7, +8) looking up -Z, so this is the frame the player opens their
## eyes into and every number here is measured in it.
##
## The DISTANCE was walked in twice. 6 m -- the plaza's middle, where he used to
## stand behind a stall -- reads as a man who happens to be over there. 2.4 m
## still reads as across-the-room. 1.8 m is close enough that his face is legible
## before the player has touched the stick, and `Npc`'s trigger is 2.3 m, so TALK
## is up on the very first frame. Closer and the hero spawns inside his capsule.
##
## The 0.7 m OFF THE AXIS is the part that is not obvious and is not optional.
## Dead centre is the strongest place in the frame and it is also directly behind
## the player's own character: at x = 0 the hero's shoulders cover the elder's
## chest from the arrival camera, so the first thing you ever see of the person
## speaking to you is a head floating over your own. Stepped to the hero's left he
## clears the silhouette completely and is still 6.9 degrees off the camera's
## axis, which `tools/directors/voices.gd` C1 measures against a 24 degree bound.
## LEFT rather than right because the statue and its plinth fill the right half of
## this shot; put him that side and he is a figure in front of a bigger figure.
##
## He is the person who says "I've been expecting you" over that frame
## (`_open_the_game`), and a man saying it from six metres off to one side, behind
## a stall, is a man the player has to be *told* is talking to them.
##
## The yaw aims his +Z at the spawn point rather than straight down -Z: 21
## degrees is `atan2(0.7, 1.8)`, the angle from where he stands to where the hero
## lands, so the offset above buys its framing without costing the thing it was
## for. `Npc`'s +Z is the side the customer stands on -- every director that
## photographs a keeper derives its camera from it (`garrison_look.gd`) -- and
## the model's own art-space flip is handled inside `Npc`, not here. CLAUDE.md
## §4: measured off a render, not reasoned out of a rest pose.
##
## He is ON the walk to the gate, and that is the price of the centre line, paid
## deliberately. Sidestepping a man who greets you by name is a fair cost; the
## alternative is the thing that was there before, where the first person in the
## game could be walked straight past without ever being looked at.
const KEEPER_AT := Vector3(-0.7, 0.0, 2.2)
const KEEPER_YAW := 21.0

## Where the monument stands on the plaza, and which way it looks. Both used to
## be `KEEPER_YAW`'s job; see `_build_plaza` for why they are their own numbers
## now, and for why the bearing is not due north. The two values are what that
## arrangement produced, kept exactly: x = +2.8, looking back at the arrival.
const STATUE_BEARING := 45.0
const STATUE_YAW := -45.0


## Five counters on one circle, and one carved figure in the middle of it.
##
## **The whole of this function used to be five independent placements**, each
## with a good argument and a comment defending it: the quartermaster and the smith
## against the north wall either side of the arch, the alchemist on the west
## inside the arrival frame, the jewelcrafter hard against the west wall after
## the smith, the Lanternkeeper loose on the east. Every one of those arguments
## was about the LOOP -- who you visit with a full bag, who you visit on the way
## out -- and every one of them was right. What none of them could say was where
## the middle of the garrison was, because there wasn't one.
##
## So the loop arguments are kept and re-expressed as bearings round a plaza,
## which is a thing the old layout could not do and the new one gets for free:
##
##   * **North-east and north-west, flanking the gate: the smith and the
##     quartermaster.** The two counters you go to with a full bag, still nearest
##     the way in, still the first pair a returning player walks between.
##   * **East and west, level with the middle: the jewelcrafter and the
##     alchemist.** The two you visit on the way back OUT, so they sit on the
##     half of the ring you cross walking from the plaza to the arch. The
##     jewelcrafter still comes after the smith along that walk (GDD §6.6 -- her
##     offer only means anything once the plate has cost you something), which
##     was the entire argument for her old spot against the west wall and
##     survives the move intact.
##   * **Off the ring entirely: the Lanternkeeper**, who has no kiosk and stands
##     on the hero's own axis two and a half metres in front of where he lands
##     (`KEEPER_AT`). He was on the plaza's middle with a stall in front of him,
##     which answered the reward question -- his lamp is fifteen metres away, so
##     where you stand when you stop talking to him matters, and from the paving
##     turning away faces the yard in every direction -- and that is still true
##     one plaza-radius nearer. What it could not answer is that he is also the
##     village elder and speaks the opening's third line to a player who has just
##     opened their eyes. A greeting has to come from somebody visibly greeting
##     you, and four counters is already the number of counters this yard has.
##
## ## Three of them are not here yet
##
## **The ring is the layout, not the roster.** `StoryDb.UNLOCKS` says who has
## arrived, and a keeper who has not is simply not built -- no booth, no lamp, no
## sign, no `Npc`. A new save's yard is Aldric, Kessa and the gate; the smith
## comes up the road after the first boss, the alchemist after the second and the
## jewelcrafter after the third (owner's call, 2026-08-10).
##
## The alternative -- five people standing there with three of their counters
## refusing to open -- was rejected because it says the wrong thing twice: it
## makes an outpost that is visibly finished on the first frame, and it turns the
## reward for killing a boss into a shop that stops saying no. A trader walking
## into the yard is a thing the player can SEE happen, and it is the only pacing
## the garrison has.
##
## The three fields stay `null` until then, so anything that reaches for
## `garrison.smith` must check. Directors get all five: `tools/shoot.gd` stamps
## the arrival flags, for the same reason it skips the opening.
func _build_people() -> void:
	# North-east and north-west of the plaza, flanking the approach to the gate.
	smith = _ring(Npc.Role.SMITH, &"smith", 55.0, Color(0.98, 0.56, 0.24))
	vendor = _ring(Npc.Role.VENDOR, &"quartermaster", -55.0, Pal.GOLD)

	# East and west, level with the plaza's middle: the two counters you visit on
	# the way back OUT, so the walk from the plaza to the gate crosses them.
	#
	# The alchemist's lamp is WARM, though every other green thing about her stayed
	# green. It used to match her cauldron, and two green sources put a wash across
	# the west half of the yard that reached the flagstones in front of the gate --
	# the one place in the game that belongs to cyan (STYLEGUIDE §2). The pot, the
	# shelf and the potions say "apothecary" perfectly well on their own; the
	# lamp's job is to be a warm light on a face.
	#
	# 118 rather than 90, on both sides. **The constraint is the ARRIVAL FRAME and
	# it is arithmetic**: the returning camera sits at (0, 1.7, +8) on a 50°
	# vertical fov, which is a little under 40° of half-width at 16:9. At a true
	# east/west bearing these two land 43° off the centre line -- just outside it,
	# which is the same failure the old west-wall placement had and which nothing
	# in the build notices except `m_19_home` from `mvp_loop`. Swinging them 28°
	# north brings both to 35°, comfortably inside. A shop you have to turn around
	# to discover is a shop that does not exist.
	alchemist = _ring(Npc.Role.ALCHEMIST, &"alchemist", -118.0, Color(0.96, 0.80, 0.52))
	jeweller = _ring(Npc.Role.JEWELLER, &"jewelcrafter", 118.0, Color(0.80, 0.62, 0.94))

	# The Lanternkeeper, on the centre line, facing the arrival. See `KEEPER_AT`.
	#
	# **Not `_ring` and not `_counter`**, and that is the whole shape of him: those
	# two exist to put a keeper behind a stall (`at` is where the COUNTER goes and
	# the keeper steps back from it), and he no longer has one -- `Npc.LOOKS` is
	# where that comes off. With no counter there is nothing to step back from, so
	# he is placed where he stands.
	keeper = Npc.new()
	keeper.role = Npc.Role.KEEPER
	keeper.lamp_color = Pal.GOLD
	keeper.position = KEEPER_AT
	keeper.rotation.y = deg_to_rad(KEEPER_YAW)
	add_child(keeper)

	# **He is also the village elder** -- one person, not two, since 2026-08-10
	# (`4fccd0a`), and the merge is what took him off the ring. He carries the
	# opening's third beat: the veil lifts, and "I've been expecting you" has to
	# come from somebody you can see (`_open_the_game`). He stood on the middle of
	# the plaza for that, six metres out with a stall between the two of you, which
	# `tools/directors/voices.gd` C1 already passed -- 0 degrees off the arrival
	# camera's axis, against a 24 degree bound his older spot fifteen metres east
	# missed by three times over. Angle was never the part that was wrong. He is on
	# the same 0 degrees now, at 2.4 m with nothing in front of him, which is the
	# difference between being in the frame and being the subject of it.
	#
	# The old worry about x = 0 -- that a figure on the centre line is silhouetted
	# against the gate's cold mouth -- died with the flat arch. The mouth now lies
	# flat over a wellhead four metres inside a roofed passage (`Gatehouse`), so
	# there is nothing bright at head height on this axis to be a silhouette
	# against.

	# The gatehouse sits ON the wall line, in the gap `_build_yard` leaves for it,
	# rather than 2.2 m inside the yard where the old flat arch stood. It has 3.4 m
	# of passage behind its face and it has to be able to put that passage
	# somewhere the player is never standing -- which is outside the curtain.
	#
	# `Npc`'s trigger is 2.3 m, so it reaches from here to z = -8.7: a metre short
	# of the arch's own threshold. You have to walk INTO the gatehouse to be
	# offered the way down, which is the read wanted and which every director that
	# approaches this node gets for free (they aim at `gate.global_position`).
	gate = Npc.new()
	gate.role = Npc.Role.GATE
	gate.position = Vector3(0.0, 0.0, -yard.y * 0.5)
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


## One shopkeeper, on the plaza's ring, facing in.
##
## `bearing` is degrees clockwise from north -- 0 is the gate, 180 the arrival,
## +90 due east. One number per shop, and the facing falls out of it rather than
## being a second number that can disagree with the first: a kiosk on a circle
## faces the middle of the circle or it is not on the circle.
##
## The yaw is `bearing + 180` because a booth's +Z is the CUSTOMER's side
## (`ShopBooth`), and the customer is the one standing in the plaza.
## `who` is their `StoryDb`/`Voice` id, and it is here rather than derived from
## `role` because the two tables are keyed differently on purpose (`Npc.COUNTERS`
## carries the id as `voice`) and a second mapping between them is a second place
## to get the Lanternkeeper-is-the-elder collapse wrong.
##
## Returns null for somebody who has not arrived yet -- see `_build_people`.
func _ring(role: Npc.Role, who: StringName, bearing: float, lamp: Color) -> Npc:
	if not StoryDb.unlocked(who):
		return null
	var b := deg_to_rad(bearing)
	var at := PLAZA_AT + Vector3(sin(b), 0.0, -cos(b)) * KIOSK_R
	return _counter(role, at, bearing + 180.0, lamp)


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


