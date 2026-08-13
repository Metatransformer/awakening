class_name Garrison
extends Node3D
## The hub. **A garrison, not a town** -- the Highbridge people's walled camp
## over the mouth of the mine. Six people, a yard, and a hole in the ground.
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

## Where the paved circle sits, and how big it is.
##
## Two metres north of the yard's own centre. The plaza leaves a clear arrival
## threshold inside the south gate, then anchors the route to the north wing.
##
## **The keepers are no longer placed off these.** They used to be, one polar
## coordinate each around this circle; `GarrisonCompound` owns where a role
## belongs now and `_compound_counter` reads its named ports. The circle is still
## the middle of the yard and the statue still stands on it, which is all these
## two numbers are for.
const PLAZA_AT := Vector3(0.0, 0.0, -2.0)
const PLAZA_R := 5.8

## Set the first time a save sees the courtyard. See `_open_the_game`.
const INTRO_FLAG := &"reported_for_duty"

## Where the curtain stands. Unchanged through both rebuilds, because every NPC
## position in `GarrisonCompound` and the whole prop ring in `_build_relic_props`
## are tuned against these numbers and against the arrival camera.
@export var yard: Vector2 = GarrisonCompound.COMPOUND_SIZE
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

## The people. **`smith`, `alchemist` and `jeweller` are null until they have been
## INTRODUCED** (`StoryDb.present`, and see `_build_compound_people`) — a fresh
## save's yard has Aldric, Kessa and the way down in it and nothing else. Anything
## that reaches for one of these has to check; the directors get all five because
## `tools/shoot.gd` stamps the arrival flags AND the `met_` flags.
var vendor: Npc
var smith: Npc
var alchemist: Npc
var keeper: Npc
var jeweller: Npc
var builder: Npc
var gate: SurfaceTransition
## The hero's billet, in the south-west corner. Public so a director can walk to
## it without knowing where the corner is.
var house: BunkBed
var compound: GarrisonCompound
var atmosphere: SurfaceAtmosphere
## The paved circle, and the carved figure standing on the middle of it. Public
## so a director can frame the plaza without re-deriving where it is.
var plaza: Plaza
var statue: Statue
var hearth: GarrisonHearth
var supply_box: SupplyBox
var raid_objective: GarrisonRaidObjective
var bolt_thrower: BoltThrower
var raid_raiders: Array[RaidRaider] = []
## The twelve dark props, in `RelicDb` catalogue order. Public so a director can
## photograph one corner before and after, which is the only way anybody can
## check the claim this system exists to make.
var lights: Array[GarrisonLight] = []

## The one keeper whose introduction this visit owes, or `&""`.
##
## **Read ONCE, in `_ready`, before anybody is built**, and then used by both
## halves of an arrival: `_build_compound_people` puts this person in the yard
## (`StoryDb.present`) and `_do_the_rounds` plays their scene. One field rather
## than two calls to `pending_introduction()` because the two answers must not be
## allowed to differ -- the first call latches nothing, but the introduction that
## plays sets `met_`, so a second call made afterwards would name the NEXT keeper
## and the yard would be introducing somebody who is not standing in it.
var _arriving: StringName = &""
var _owns_raid_simulation := false


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
	if Flow.refuse_boot(self):
		return
	atmosphere = SurfaceAtmosphere.new()
	atmosphere.name = &"SurfaceAtmosphere"
	add_child(atmosphere)
	compound = GarrisonCompound.new()
	compound.name = &"Compound"
	add_child(compound)
	house = compound.player_bunk
	_build_plaza()
	_build_hearth()
	_build_supply_box()
	_build_raid_objective()
	# Before a single body is placed: who this homecoming is FOR. See `_arriving`.
	# It must be read BEFORE `_build_compound_people`, not after -- the scene and
	# the bodies have to name the same person or the elder introduces somebody who
	# is not there.
	_arriving = StoryDb.pending_introduction()
	_build_compound_people()
	_build_relic_props()
	Clock.service_availability_changed.connect(_apply_staffing)
	Clock.garrison_phase_changed.connect(_apply_staffing)
	Game.garrison_changed.connect(_sync_raid)
	Game.garrison_raid_restoring.connect(_discard_raid_mirrors)
	Bus.item_acquired.connect(_on_item_acquired)
	Game.raid_set_live_scene_ownership(true)
	_owns_raid_simulation = true
	_sync_raid()
	_apply_staffing()
	_place_dawn_wake()
	_open_the_game()
	# Join only after the compound and every live landmark the plan may expose
	# exist. The HUD discovers this provider; it does not know garrison geometry.
	add_to_group(&"surface_map")


## The compound supplies structure. This scene adds only landmarks represented
## by live nodes it owns, so absent residents never become phantom map services.
func surface_map_plan() -> Dictionary:
	if compound == null or not is_instance_valid(compound):
		return {}
	var base := compound.surface_map_plan()
	var paths: Array = (base[&"paths"] as Array).duplicate()
	var areas: Array = (base[&"areas"] as Array).duplicate()
	var landmarks: Array[Dictionary] = []
	if gate != null and is_instance_valid(gate):
		landmarks.append(_surface_landmark(gate, &"gate"))
	if hearth != null and is_instance_valid(hearth):
		landmarks.append(_surface_landmark(hearth, &"hearth"))
	if supply_box != null and is_instance_valid(supply_box):
		landmarks.append(_surface_landmark(supply_box, &"landmark"))
	if statue != null and is_instance_valid(statue):
		landmarks.append(_surface_landmark(statue, &"landmark"))
	for npc: Npc in [vendor, smith, alchemist, keeper, jeweller, builder]:
		if npc == null or not is_instance_valid(npc):
			continue
		# Bonfire and sleeping routines can bunch residents into one small area.
		# One service glyph there reads; six overprinted diamonds do not.
		var crowded := false
		for landmark: Dictionary in landmarks:
			if StringName(landmark[&"glyph"]) != &"service":
				continue
			var position: Vector3 = landmark[&"position"]
			if position.distance_squared_to(npc.global_position) < 4.0:
				crowded = true
				break
		if not crowded:
			landmarks.append(_surface_landmark(npc, &"service"))
	paths.make_read_only()
	areas.make_read_only()
	landmarks.make_read_only()
	var plan: Dictionary = {
		&"view_range": float(base[&"view_range"]),
		&"paths": paths,
		&"areas": areas,
		&"landmarks": landmarks,
	}
	plan.make_read_only()
	return plan


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


## Introduce the one person this homecoming is for.
##
## **This is the "cutscene" half of an unlock.** Beating the sluice keeper puts a
## maker's mark in your pack and the smith in the yard (`StoryDb.UNLOCKS`), but a
## new shopkeeper who simply APPEARS between one run and the next is a change the
## player has to notice on their own -- and the person most likely to miss it is
## the one who came home with three hearts left and walked straight to their bed.
## So the elder introduces them, once, the first time you are back in the yard
## after they arrive.
##
## **ONE, and this used to be a loop** (card #115, owner's call). A good descent
## takes the floor 1 miniboss and the floor 1 boss together, so two keepers unlock
## in the same run -- and the answer to that is not eight pages of introductions
## at somebody who came home to sell a bag. It is one arrival now and one held
## back: `_arriving` is the whole of this visit's roster, `_build_compound_people`
## has already put exactly that person in the yard, and the other one walks up the
## road next time. Nothing here recomputes who that is; see `_arriving` for why
## asking twice is a bug and not a refresh.
##
## Fire-and-forget from `_open_the_game` -- nothing awaits this, and the yard is
## fully built and playable underneath it. `DialogueBox` blocks the hero for the
## length of the box on its own (`Prompt.block`), which is the whole of the
## "cutscene" this needs to be.
func _do_the_rounds() -> void:
	if _arriving == &"" or Game.flag(StoryDb.intro_flag(_arriving)):
		return
	# A beat of quiet first, for the same reason the opening has one: `_ready` runs
	# during `change_scene_to_file`, so with no wait the first line of the scene is
	# typed behind `Flow`'s fade and the pan happens where nobody can see it.
	await get_tree().create_timer(1.2, false).timeout
	await Introduction.play(self, _arriving)


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
## Built before the people so the courtyard landmark is already present when the
## roster arrives around it.
##
## The statue is set 3.9 m off the plaza's middle, north-east. **Not due north**,
## which was the first cut and which put a 4 m column of stone directly between
## the arrival camera and the gate. Swinging it out to x = +2.8 clears the walk
## to the arch and is the more interesting composition: you arrive looking at a
## figure with a bigger figure over its shoulder, rather than at two things
## stacked.
##
## `STATUE_BEARING` is its own number now. It used to follow the keeper's yaw --
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
	# Looking back across the plaza at the people arriving.
	statue.rotation.y = deg_to_rad(STATUE_YAW)
	add_child(statue)


## The hero's quarters, tucked into the south-west corner.
##
## **The corner is the whole of the placement argument, and it is arithmetic
## rather than taste.** Everything else in the yard is spoken for: the gate and
## the shaft head are due north, the vendor and the smith flank them, the
## alchemist stands on the west side inside the arrival frame that
## `GarrisonCompound` says must not be broken, and the Lanternkeeper has the centre line and the
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
	house = BunkBed.new()
	house.player_bunk = true
	# Its own two walls go on -X and +Z, so the corner it wants is the corner of
	# the yard, inset by half the room plus enough to clear the curtain's block
	# relief (KitStyle.RELIEF, 0.17 proud of the placement plane).
	var hx := yard.x * 0.5
	var hz := yard.y * 0.5
	var half := house.room * 0.5
	house.position = Vector3(-hx + half.x + 0.2, 0.0, hz - half.y - 0.2)
	add_child(house)


## Where the monument stands on the plaza, and which way it looks. Both used to
## follow the Lanternkeeper; see `_build_plaza` for why they are their own
## numbers now, and for why the bearing is not due north.
const STATUE_BEARING := 45.0
const STATUE_YAW := -45.0


## Build the existing roster into the generated compound's named destinations.
## The four traders occupy separate service nooks instead of one counter line;
## the Lanternkeeper has no stall and waits on the arrival axis to greet Kael.
## The generator owns those spatial decisions while this scene owns who has
## arrived and every gameplay node. `StoryDb.UNLOCKS` still controls the roster,
## so unrecruited traders leave genuinely empty nooks rather than closed shops.
func _build_compound_people() -> void:
	vendor = _compound_counter(Npc.Role.VENDOR, &"quartermaster",
		&"quartermaster_day", Pal.GOLD)
	smith = _compound_counter(Npc.Role.SMITH, &"smith",
		&"smith_day", Color(0.98, 0.56, 0.24))
	alchemist = _compound_counter(Npc.Role.ALCHEMIST, &"alchemist",
		&"alchemist_day", Color(0.96, 0.80, 0.52))
	keeper = _compound_counter(Npc.Role.KEEPER, &"elder",
		&"elder_day", Pal.GOLD, false)
	jeweller = _compound_counter(Npc.Role.JEWELLER, &"jewelcrafter",
		&"jewelcrafter_day", Color(0.80, 0.62, 0.94))

	gate = SurfaceTransition.new()
	gate.name = &"OuterGate"
	gate.destination = SurfaceTransition.Destination.OUTSKIRTS
	gate.radius = 3.0
	add_child(gate)
	gate.global_transform = compound.global_transform * compound.port(&"gate")


func _build_hearth() -> void:
	hearth = GarrisonHearth.new()
	hearth.name = &"GarrisonHearth"
	add_child(hearth)
	hearth.global_transform = compound.global_transform * compound.port(&"hearth")


func _build_supply_box() -> void:
	supply_box = SupplyBox.new()
	supply_box.name = &"SupplyBox"
	# (5, 12) is inside the east gatehouse tower. This clears its west edge and
	# sits under the south gallery, facing the arrival axis without blocking it.
	supply_box.position = Vector3(8.3, 0.05, 11.5)
	supply_box.rotation.y = -PI * 0.5
	add_child(supply_box)


func _build_raid_objective() -> void:
	raid_objective = GarrisonRaidObjective.new()
	raid_objective.name = &"RaidObjective"
	raid_objective.position = Vector3(0.0, 0.05, -6.3)
	add_child(raid_objective)


## One keeper, at their named port -- if they are in the yard on this visit.
##
## **`present` and not `unlocked`** (card #115). Unlocking latches the arrival
## flag the frame the metric is met, so gating the BODY on it put a keeper behind
## a counter before the elder had said who they were: a descent that took the
## floor 1 miniboss and the floor 1 boss brought two of them home at once and only
## one could be introduced. Now a keeper is built once they have been MET, plus
## the one whose scene is about to play (`_arriving`) -- the whole reasoning is on
## `StoryDb.present`, which owns the rule.
##
## `gated` is false for exactly one person: the Lanternkeeper, who sent for you
## and has no arrival to wait for.
func _compound_counter(role: Npc.Role, who: StringName, day_port: StringName,
		lamp: Color, gated: bool = true) -> Npc:
	if gated and not StoryDb.present(who, _arriving):
		return null
	var npc := Npc.new()
	npc.role = role
	npc.lamp_color = lamp
	add_child(npc)
	npc.global_transform = compound.global_transform * compound.port(day_port)
	return npc


func _apply_staffing(_changed: Variant = null) -> void:
	var roster: Array = [
		[vendor, &"quartermaster_day", &"quartermaster_bonfire", &"quartermaster_sleep"],
		[smith, &"smith_day", &"smith_bonfire", &"smith_sleep"],
		[alchemist, &"alchemist_day", &"alchemist_bonfire", &"alchemist_sleep"],
		[keeper, &"elder_day", &"elder_bonfire", &"elder_sleep"],
		[jeweller, &"jewelcrafter_day", &"jewelcrafter_bonfire", &"jewelcrafter_sleep"],
		[builder, &"builder_day", &"builder_bonfire", &"builder_sleep"],
	]
	var phase: StringName = Clock.garrison_phase()
	for row: Array in roster:
		var npc := row[0] as Npc
		if npc == null:
			continue
		var activity: StringName
		var target_port: StringName
		if phase == WorldClock.GARRISON_BONFIRE:
			activity = Npc.ACTIVITY_BONFIRE
			target_port = StringName(row[2])
		elif phase == WorldClock.GARRISON_DAYTIME and Clock.services_available():
			activity = Npc.ACTIVITY_WORKING
			target_port = StringName(row[1])
		else:
			activity = Npc.ACTIVITY_SLEEP
			target_port = StringName(row[3])
		npc.set_activity(activity,
			compound.global_transform * compound.port(target_port))


func _on_item_acquired(id: StringName) -> void:
	if id == RelicDb.TALLY_LEDGER_ID:
		_sync_raid()


func _ensure_builder() -> void:
	if builder != null and is_instance_valid(builder):
		return
	if not Game.flag(RelicDb.flag_donated(RelicDb.TALLY_LEDGER_ID)):
		return
	builder = Npc.new()
	builder.name = &"Builder"
	builder.role = Npc.Role.BUILDER
	builder.lamp_color = Pal.RUST
	add_child(builder)
	builder.global_transform = compound.global_transform * compound.port(&"builder_day")
	_apply_staffing()


## Reconcile the courtyard with Game's saved raid records. This is safe to call
## for every garrison change: stable ids prevent duplicate live bodies.
func _sync_raid() -> void:
	_ensure_builder()
	if Game.raid_defense_built() and not is_instance_valid(bolt_thrower):
		bolt_thrower = BoltThrower.new()
		bolt_thrower.name = &"BoltThrower"
		bolt_thrower.position = Vector3(-8.6, 0.05, 13.4)
		add_child(bolt_thrower)
	for light: GarrisonLight in lights:
		light.sync()

	for i in range(raid_raiders.size() - 1, -1, -1):
		if not is_instance_valid(raid_raiders[i]):
			raid_raiders.remove_at(i)
	var phase := Game.raid_phase()
	if phase != GarrisonRaidState.PHASE_ACTIVE \
			and phase != GarrisonRaidState.PHASE_LOST:
		return
	var records := Game.raid_attacker_records()
	for record: Dictionary in records:
		if not bool(record.get("alive", false)) or int(record.get("hp", 0)) <= 0:
			continue
		var id := StringName(record.get("id", &""))
		if id == &"" or _raid_raider(id) != null:
			continue
		var raider := RaidRaider.new()
		raider.name = StringName("RaidRaider_%s" % String(id))
		raider.configure(record, _raid_route(_raid_lane(id)), raid_objective)
		add_child(raider)
		raid_raiders.append(raider)


func _discard_raid_mirrors() -> void:
	for raider: RaidRaider in raid_raiders:
		if is_instance_valid(raider):
			raider.discard_mirror()
			raider.queue_free()
	raid_raiders.clear()


func _raid_raider(id: StringName) -> RaidRaider:
	for raider: RaidRaider in raid_raiders:
		if is_instance_valid(raider) and raider.raid_id == id:
			return raider
	for node: Node in get_tree().get_nodes_in_group(&"raid_raider"):
		var raider := node as RaidRaider
		if raider != null and raider.raid_id == id:
			if not raid_raiders.has(raider):
				raid_raiders.append(raider)
			return raider
	return null


func _raid_lane(id: StringName) -> int:
	match id:
		&"kobold_1":
			return 0
		&"kobold_2":
			return 1
		&"kobold_3":
			return 2
		_:
			return 3


func _raid_route(lane_index: int) -> Array[Vector3]:
	var lanes: Array[float] = [-2.1, -0.7, 0.7, 2.1]
	var x := lanes[clampi(lane_index, 0, lanes.size() - 1)]
	var local_points: Array[Vector3] = [
		Vector3(x, 0.05, 24.0),
		Vector3(x * 0.90, 0.05, 20.2),
		Vector3(x * 0.55, 0.05, 18.0),
		Vector3(x * 0.20, 0.05, 15.4),
		Vector3(x * 0.14, 0.05, 9.0),
		Vector3(0.0, 0.05, -6.3),
	]
	var world_points: Array[Vector3] = []
	for point: Vector3 in local_points:
		world_points.append(to_global(point))
	return world_points


func _exit_tree() -> void:
	for raider: RaidRaider in raid_raiders:
		if is_instance_valid(raider):
			raider.sync_now()
	if _owns_raid_simulation:
		Game.raid_set_live_scene_ownership(false)
		_owns_raid_simulation = false


func _place_dawn_wake() -> void:
	if not Flow.consume_bunk_wake():
		return
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	if hero != null:
		hero.global_transform = compound.global_transform * compound.port(&"player_bunk")
	Bus.request_message.emit("DAWN. YOU WAKE IN THE BARRACKS.")


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
	# The old tiny yard used the curtain itself as the ring. The generated fort's
	# wings now occupy that perimeter, so the same twelve consequences line the
	# open parade loop where every trip between barracks, gate and services sees
	# at least one.
	var rx := 8.8
	var rz := 7.8
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


func _surface_landmark(node: Node3D, glyph: StringName) -> Dictionary:
	var landmark: Dictionary = {
		&"glyph": glyph,
		&"position": node.global_position,
	}
	landmark.make_read_only()
	return landmark
