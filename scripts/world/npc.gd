class_name Npc
extends Interactable
## The three people in the garrison, and the gate they stand around.
##
## They were boxes with a lantern, on purpose, for as long as the loop was the
## thing being built: a stand-in character model that is nearly good is worse
## than an obvious placeholder, because it invites you to fix the model instead
## of the game. The loop works, so they are people now -- standing behind a
## `ShopBooth` full of their own trade, and built two different ways:
##
##   * Four are **authored bodies** (`NpcBody`) -- a dwarf smith, a warrior at the
##     pawnbroker's stall, a hooded Lanternkeeper and the jewelcrafter, each
##     modelled as a whole dressed figure. They do not go near the suit system.
##   * Two are **built** (`RaceBody`) -- the alchemist and the elder, cast from one
##     of the Vale's three peoples and dressed by `SuitSeater`.
##
## **What they DO did not change, either time, and that is the point.** Turn to
## face you, light up when addressed, open the right screen: all of it still lives
## here, none of it ever depended on the mesh, and both mesh swaps touched
## `_build_person` and nothing else.

## KEEPER and JEWELLER are appended rather than slotted in beside the other
## counters: the values are what an `@export var role` serialises, and
## re-ordering this enum would silently turn every placed alchemist into a gate.
enum Role { VENDOR, SMITH, GATE, ALCHEMIST, KEEPER, JEWELLER, ELDER }

## Everything that differs between the people in this garrison, on one row each.
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
##   * `counter`-- present only for those who stand behind one. `db` null means
##     SELL (the screen reads the bag, not a catalogue).
##   * `voice`  -- their key in `Voice.LINES`, or absent for the ones nobody has
##     recorded. `activate` says their `hello` and the screen says the other two;
##     a speaker with no take for a cue is silent and that is not an error, so
##     the Lanternkeeper simply has no row here and no branch anywhere.
##
## The GATE has no counter, so `activate` has exactly one branch: open a counter,
## or do the role's own thing.
##
## `static var`, not `const`: a catalogue is a script reference and an enum from
## another class, and neither is a constant expression to the parser. Static, so
## the table is still built once for the whole game rather than per shopkeeper.
static var COUNTERS := {
	Role.VENDOR: {
		"sign": "PAWNBROKER", "prompt": "TALK", "hold": 0.0, "voice": &"pawnbroker",
		"counter": {"title": "PAWNBROKER", "mode": TradeScreen.Mode.SELL, "db": null},
	},
	Role.SMITH: {
		"sign": "SMITH", "prompt": "TALK", "hold": 0.0, "voice": &"smith",
		"counter": {"title": "THE FORGE", "mode": TradeScreen.Mode.BUY, "db": ShopDb},
	},
	Role.ALCHEMIST: {
		"sign": "ALCHEMIST", "prompt": "TALK", "hold": 0.0, "voice": &"alchemist",
		"counter": {"title": "THE ALCHEMIST", "mode": TradeScreen.Mode.BUY, "db": AlchemyDb},
	},
	# The fourth counter. She cost exactly this row and a `Catalogue` subclass --
	# no screen, no branch in `activate`, no new mode -- which is the acceptance
	# criterion for the whole relic system and not a nice outcome.
	#
	# She was "the last one there will be" until 2026-08-09, when GDD §6.6 added
	# the jewelcrafter below and docs/SCOPE.md §1 moved garrison NPCs from 4 to
	# 5 as an owner's amendment. The claim was not wrong about the COST -- the
	# fifth counter cost the same row and the same subclass -- which is exactly
	# why the ceiling now lives in SCOPE §1 rather than in a comment here.
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
	# The fifth counter, and the last one there will be (docs/SCOPE.md §1:
	# garrison NPCs **5**, "There is no sixth"). Same bill as the
	# Lanternkeeper's, paid again: one row, one `Catalogue`.
	#
	# `hold` is 0 like the other four. `JewelDb.crafts()` answers true for every
	# rung and false for the four blanks, so the gauge lands on the commits that
	# eat stones and the blanks stay a tap -- which is the rule `Catalogue.crafts`
	# exists to state once.
	Role.JEWELLER: {
		"sign": "JEWELCRAFTER", "prompt": "TALK", "hold": 0.0, "voice": &"jewelcrafter",
		"counter": {
			"title": "THE SETTING BENCH", "mode": TradeScreen.Mode.BUY, "db": JewelDb,
		},
	},
	# The sixth person, and the only one who is not selling you anything.
	#
	# **A row with a `voice` and no `counter` is the whole of him**, which is the
	# claim `COUNTERS` has been making since it was written and had never once
	# been tested by a person who does not trade: `activate` opens a counter if
	# there is one, and if there is not, the greeting it already said IS the
	# interaction. No dialogue tree (`docs/SCOPE.md` §1 still says **0**, and a
	# recorded line is not a tree), no screen, no branch.
	#
	# He is why the garrison has somebody to report to. `docs/GDD.md` §1 used to
	# say the hub gets to be small because there is "nobody to talk to who is not
	# selling something"; the elder is the amendment to that sentence and he is
	# deliberately the *smallest* one available -- two takes on a greeting, and
	# a third line the opening spends once (`Voice.LINES` &"elder"/&"arrival").
	Role.ELDER: {
		"sign": "VILLAGE ELDER", "prompt": "TALK", "hold": 0.0, "voice": &"elder",
	},
	# 0.9 s, and the only hold in the world. It is the door OUT of the hub and
	# the one press in the game that ends the safe part of the session, so it is
	# the one press that should be impossible to make by accident on the way past.
	#
	# `# NEEDS:` the Warp-Stone Fragment's unlock,
	# `RelicDb.garrison_shortcuts()`, bites HERE -- "start a run at any shortcut
	# you have opened" (GDD §6.2 #9). It cannot be adopted yet and faking it
	# would be worse than leaving it: the gate would have to open a run at floor
	# N, and `Run.enter()` hard-sets `level = 1` with a comment explaining why,
	# so the change is one argument in `scripts/autoload/run_state.gd`. There is
	# also nothing to offer until the shortcut doors exist on a real floor
	# (SCOPE M4/M6). When both land, this row reads
	# `RelicDb.garrison_shortcuts()` and `activate` picks the deepest floor
	# whose `LockedDoor.flag_id()` is set -- still no new screen.
	Role.GATE: {"sign": "", "prompt": "DESCEND", "hold": 0.9},
}

## Who each shopkeeper IS -- their body, their clothes, and how they stand.
##
## Separate from `COUNTERS` because the two tables answer different questions and
## get edited for different reasons: `COUNTERS` is what a counter DOES, this is
## what a person looks like. A palette pass should not have to read past the
## trade modes to find the colours.
##
## **There are two kinds of row here, and a row is one or the other.**
##
##  * **`model`** -- an AUTHORED person (`NpcBody.PEOPLE`). They were modelled as a
##    whole figure, dressed, with their buckles and their beard painted into one
##    atlas: the smith's apron, the Lanternkeeper's jewelled mail, the
##    jewelcrafter's gown. There is no bare body under them and no normalised UV
##    layout, so **`suit` and `tint` are meaningless on these rows and must not be
##    added.** Putting the clothing system anywhere near them seats a garment onto
##    a rig it was never fitted to and produces a person wearing another person.
##  * **`race`** -- a base from the Valenfeld pack, dressed by the suit system
##    (`RaceBody.wear`). Two rows are left: the alchemist and the elder. That is
##    not a leftover to be finished off. A `RaceBody` is what you reach for when a
##    person has to be BUILT out of a race, a suit and a colour -- which is still
##    how the Vale's three peoples are cast -- and it is the only one of the two
##    that can put somebody new in the yard without commissioning a model.
##
## The casting is not at random on either side. Each body keeps the counter it
## would keep, which is why the garrison reads as a place with history in it
## rather than six vendors in different hats: a dwarf at the forge, an old man in
## relic-jewelled mail at the Far Lantern, a woman wearing her own trade at the
## setting bench, a scarred road-warrior fencing goods at the stall, and the two
## races the pack still casts -- **Vyr** at the apothecary, a head over any settler
## and born, they say, seeing the flaw in the drawing (which is the job), and a
## **Reshi** elder, settler height, eye to eye with you.
##
## Heights are load-bearing and come off `NpcBody.PEOPLE` / `RaceBody.RACES`. The
## hero is 1.65 m, and the row steps -- smith 1.44, jewelcrafter 1.63, elder 1.65,
## pawnbroker 1.72, keeper 1.74, alchemist 1.82 -- so the smith reads a clear head
## short of you and the alchemist a clear head tall, before either says a word.
##
##   * `model`  -- an authored body, dressed as it ships. Excludes `race`.
##   * `race`   -- a base to build and dress. Excludes `model`.
##   * `suit`   -- `race` rows only: which authored suit to dress them in
##     (`SuitSeater.SETS`). Not a fabric name: a suit is a whole dressed person,
##     so this picks the entire outfit including boots, gloves and hood.
##   * `tint`   -- `race` rows only, and it MULTIPLIES the weave, so it runs much
##     lighter than a flat robe colour would. The first pass fed in the box
##     placeholders' robe colours directly and produced silhouettes in black.
##   * `idle`   -- their resting loop, so the garrison is not six people breathing
##     in time. All from the standing family; see `RaceBody.CLIPS`, which is the
##     same four clips either kind of body plays.
##   * `booth`  -- the shop they stand in. **Absent means none**, and the elder is
##     the one row that leaves it out: a counter is what a person who sells
##     things stands behind, so the person who sells nothing stands in the open.
static var LOOKS := {
	# The dwarf: leather apron, one pauldron, a hammer on the belt and a bare
	# forearm, at 1.44 m and half again as wide as anyone else in the yard. He is
	# roughly the height of the Stoneborn he replaced, deliberately -- the forge
	# wants the SHORT silhouette, and the fire two metres behind him is what the
	# tinting of the old placeholder was fighting to survive.
	Role.SMITH: {
		"model": "smith", "idle": &"idle3", "booth": ShopBooth.Kind.FORGE,
	},
	Role.VENDOR: {
		"model": "pawnbroker", "idle": &"idle", "booth": ShopBooth.Kind.STALL,
	},
	Role.ALCHEMIST: {
		"race": "vyr", "suit": "cloth", "idle": &"idle4",
		"tint": Color(0.56, 0.88, 0.68), "booth": ShopBooth.Kind.ALCHEMY,
	},
	# Hooded, white-bearded, and wearing a mail coat set with a dozen coloured
	# stones -- which is the whole of the Far Lantern's pitch worn on a body. He
	# is the tallest of the four authored people and the only one you cannot see
	# the face of from across the yard, so the strange counter reads as the
	# strange one before the sign is legible. (He replaced a Reshi woman built out
	# of suit and tint, and the tint was doing this job on its own.)
	#
	# A STALL, and that is the end of dressing him. The hall is not a booth kind
	# and it does not need to be: the twelve lamps outside are what says this
	# counter is different, and a bespoke booth would be spending on the wrong
	# half of GDD §6.2's budget.
	Role.KEEPER: {
		"model": "lanternkeeper", "idle": &"idle9", "booth": ShopBooth.Kind.STALL,
	},
	# Black and gold, an emerald the size of a thumb at her throat, gold at both
	# wrists. She is the one person in the garrison wearing her own stock, which
	# says what the setting bench sells without a word of it -- and it is why she
	# needs no tint: the violet the old Stoneborn row used was standing in for
	# exactly this and cost a `cut_gemstone` cross-reference to explain.
	#
	# `idle4` is shared with the alchemist, and that is fine for the reason the
	# old row gave and which still holds: `RaceBody.CLIPS` is four and there are
	# six people, so somebody repeats, and you repeat the clip nobody who LOOKS
	# like you is using. The alchemist is a 1.82 m Vyr at the far side of the yard.
	Role.JEWELLER: {
		"model": "jewelcrafter", "idle": &"idle4", "booth": ShopBooth.Kind.STALL,
	},
	# The elder, and every field here is doing the same job: making the one person
	# in the yard who wants nothing from you legible as that from across it.
	#
	#  * **Reshi**, the settler height (1.65 m) -- eye to eye with the hero, which
	#    the Stoneborn and the Vyr are deliberately not. You are being spoken to,
	#    not sold to or looked down at.
	#  * **Leather in warm russet, and it was authored in CLOTH first.** Cloth is
	#    the obvious call -- a robe is what an elder wears, and undyed homespun is
	#    the absence of a trade colour, which is what he is. It rendered as a
	#    charcoal-blue hooded figure of exactly the hero's value, standing next to
	#    the hero, in the one frame the whole placement exists to compose. Only the
	#    capture could say so (`v_02_from_the_spawn` in `tools/directors/voices.gd`).
	#
	#    **`tint` MULTIPLIES, and every atlas in the pack is dark**, with
	#    `SuitSeater.TINT_PULL` softening the colour halfway to white before it
	#    even lands -- so a pale tint is very nearly no tint, and there is no
	#    number here that makes cloth read light. **Pick saturation, never
	#    brightness; to change VALUE, change the suit.** Leather is the lightest
	#    atlas a non-combatant can plausibly wear, and in russet he reads warm and
	#    a full stop lighter than the hero at fifteen metres, which is the distance
	#    he is first seen from. (Mail was tried and works even better on legibility
	#    and reads as a soldier, which he is not.)
	#
	#    The smith is also in leather, also warm. He is a 1.41 m Stoneborn behind a
	#    forge at the far north-east; this is a 1.65 m Reshi alone in the middle of
	#    the grass. Different height, different people, twelve metres apart, and
	#    the tint is a stop deeper.
	#  * **`idle4`.** `RaceBody.CLIPS` is four and there are six people, so
	#    somebody repeats -- and the rule the jewelcrafter's row set is *repeat the
	#    one nobody who looks like you is using*. `idle3` is the smith's and he is
	#    the other man in leather; `idle9` is the Lanternkeeper's and she is the
	#    other Reshi; `idle` is the pawnbroker's, also Reshi. `idle4` belongs to a
	#    Vyr and a Stoneborn, neither of whom he could be mistaken for.
	#  * **No booth.** See the field list above.
	Role.ELDER: {
		"race": "reshi", "suit": "leather", "idle": &"idle4",
		"tint": Color(1.00, 0.82, 0.44),
	},
}

@export var role: Role = Role.VENDOR
@export var lamp_color: Color = Pal.GOLD

var _body: Node3D
## Whoever is standing here -- a `RaceBody` or an `NpcBody`, see `LOOKS`. Held as
## a `Node3D` because nothing outside `_build_person` asks it anything.
var _person: Node3D
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
## here gets a nameless prop you can walk up to, not a crash mid-garrison.
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
	var row := _row()
	# They speak first, before the screen, because that is the order it happens
	# in: you say hello to somebody and then look at what they have. Silent for
	# the gate, which is masonry, and for the Lanternkeeper, who has no takes --
	# `Voice.say` answers 0.0 and nothing happens, so neither needs a branch.
	#
	# For the elder this call IS the interaction. He has no counter, so the
	# function ends two lines down having done exactly what talking to him does.
	var who := StringName(row.get("voice", &""))
	if who != &"":
		Voice.say(who, &"hello")

	# One screen, pointed. See `Catalogue` for why there is not a second one.
	var counter: Dictionary = row.get("counter", {})
	if not counter.is_empty():
		TradeScreen.open(self, int(counter["mode"]), str(counter["title"]),
			counter["db"] as GDScript, who)
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
	#
	# Absent for the elder. `Garrison._stand` is the other half of that: a keeper
	# is placed by where their COUNTER goes and steps back behind it, and somebody
	# with no counter has to be placed where they are standing.
	if look.has("booth"):
		var booth := ShopBooth.new()
		booth.kind = look["booth"]
		booth.position.z = ShopBooth.KEEPER_BACK
		add_child(booth)

	# The person. Two kinds, and the row says which -- see `LOOKS`. An authored
	# body arrives dressed and is left alone; a race base is built, then dressed by
	# the suit system. Both answer `height` and `play`, so nothing below this cares
	# which one turned up.
	var idle: StringName = look.get("idle", &"idle")
	if look.has("model"):
		var authored := NpcBody.make(str(look["model"]))
		if authored != null:
			_person = authored
			_body.add_child(authored)
			authored.play(idle)
			_head = authored.height
	else:
		var built := RaceBody.make(str(look.get("race", "reshi")))
		if built != null:
			_person = built
			_body.add_child(built)
			built.wear(str(look.get("suit", "cloth")), look.get("tint", Color.WHITE))
			built.play(idle)
			_head = built.height

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


## The way down. A dark arch with a cold mouth: the garrison is warm and gold,
## so the entrance being the only cold thing in it is the only signposting
## needed.
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
	# "The Lower Worlds" is everything under the garrison (docs/GDD.md); THE
	# SUNKEN CUT is the one dungeon there is a way down into, and a sign over a
	# door should say where the door goes. It reads off `Prog.NAME` so the gate,
	# the loading card and the HUD cannot end up calling it three different
	# things.
	plate.text = Prog.NAME
	plate.font_size = 40
	plate.pixel_size = 0.0028
	plate.modulate = Pal.MOTH
	plate.outline_size = 14
	plate.position.y = 4.25
	_body.add_child(plate)
