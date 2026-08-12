class_name LootMote
extends Area3D
## One dropped ingredient, lying on the floor waiting to be walked over.
##
## Why a physical pickup rather than crediting the bag the instant an enemy dies:
## the bag is the thing the player is deciding about, and a number that changes
## while you are still swinging teaches nothing. Making you walk back over the
## drop puts a beat between "I won the fight" and "I am richer", which is the
## beat the extraction decision lives in. It also gives a full bag somewhere to
## refuse from -- a mote you cannot pick up stays on the floor and pulses, which
## is a far better "you are full" than a toast.
##
## **And the beat is only a decision if you can see what is on offer.** Card
## #123: a mote wears its name on a `WorldCaption` once you are inside
## `NAME_RANGE`, three at a time, nearest first. The long note above that
## constant is where the *when* is argued; it is the only part of this that is
## not already solved somewhere else in the project.

## Picked up. Carries the id so one handler can serve several motes and still
## know which one went -- the same shape `PuzzleAtom.solved` uses, and for the
## same reason. `SoundingStone` is the reader: three motes over one plinth, and
## taking one has to retire the other two.
signal taken(item_id: StringName)

## Seconds before the mote will answer a pickup. Long enough that the kill's own
## knockback does not sweep the hero through it before he has seen it land.
const ARM_TIME := 0.35
const BOB_SPEED := 2.2
const BOB_HEIGHT := 0.09
const SPIN_SPEED := 1.6
## Magnetism waits out `drop`'s 0.42 s fling tween. Both write global_position,
## and the tween wins, so a mote that started pulling early would visibly stall
## for the overlap and then jerk.
const MAGNET_ARM := 0.45

# --- Why a mote does not light itself ---------------------------------------
# Every drop in the dungeon rendered as the SAME flat #FFFFFF wedge -- a Bone
# Shard and a Silver Wire were one pixel value apart at 255 -- which is the one
# failure this object cannot have, because tint is the whole of "what did I just
# get" (STYLEGUIDE §7.2 bans #FFFFFF outright, §7.5 bans the glow that was
# smearing a halo round it). It read on screen as untextured missing art rather
# than as loot.
#
# The cause was NOT the emission, though the emission made it worse and the
# comment that used to sit on it blamed the FILMIC curve and turned 1.6 into 0.9
# without ever measuring the result. It is the OmniLight below: it sits at
# y 0.30 and the mesh's centre is at y 0.28, so the lamp whose job is to put a
# pool on the FLOOR was also flooding the mote's own 34 cm surface from two
# centimetres away, at an attenuation of ~0.84 of full energy. Albedo, plus that,
# plus emission, plus `env_dungeon.tres`'s 1.06 exposure and 1.22 contrast, and
# every channel clipped. Measured with the emission turned entirely OFF the
# surface still came back (252, 247, 220) -- so no amount of retuning the
# material was ever going to fix it.
#
# So the mesh gets its own visual layer and the lamp is told to skip that layer.
# The pool on the flagstones is untouched -- that is the "look over here", and it
# was always the part doing the work -- and the surface is now lit by the room
# like everything else, which is what makes it the item's colour again.
const ALL_LAYERS := 0xFFFFF
## Visual layer 2, used by nothing else in the project. Other lights keep their
## default all-layers cull mask, so a torch, the fill light and the hero's lamp
## all still reach a mote; only its own does not.
const SELF_BIT := 1 << 1
## Resting emission. Small on purpose: with the self-flood gone this is only
## there so a mote in an unlit corner is a shape and not a silhouette.
##
## Measured on the dungeon floor rather than reasoned about, which is the part
## the 1.6-to-0.9 edit skipped. Six drops side by side, sampled off the render:
## at 0.15 Rot Moss is (182, 199, 82), Ember Gland (255, 160, 43), Deep Amber
## (255, 209, 13), Bone Shard (255, 239, 206) -- six items, six colours, facets
## still shaded. At 0.6 and above all six are (255, 255, 2xx) and identical, and
## at 0.9 they are the flat white slabs this whole note is about. [tune]
const EMIT_BASE := 0.15

# --- Why a mote says what it is, and only while you are standing near it -----
# Card #123, off the owner's playtest: "we should show the name of items when
# they fall on the ground." Without a name the walk back over a drop is a
# REFLEX -- you cannot tell an Iron Scrap from a jewel until it is already in
# the bag -- and the beat this file's header is built around, the one where you
# decide whether the walk is worth it, does not happen at all.
#
# **The three things that make a floating name hard are already solved and none
# of them is solved here.** A `WorldCaption` carries the text (card #61: a
# `Label3D` goes into STYLEGUIDE §4.5's 480x270 buffer with the masonry and
# comes out about 5 px of type against §3.1b's floor of 10). `Hud`'s
# line-of-sight ray is what stops it painting a shut door (cards #26 and #37,
# four labels shipped that way). `Hud._draw_world_captions`' de-collide is what
# keeps two names on one baseline from being drawn through each other (card
# #68). Re-solving any of that here is CLAUDE.md §0 three times over.
#
# **What IS decided here is the WHEN**, and the answer is an attention radius
# with a cap on how many names are up at once.
#
#  * **Not always.** A cleared room holds a dozen-odd motes, and a dozen
#    permanent floating names is the sign-in-the-courtyard §7.10 refuses -- it
#    hides the room it is annotating, which is worse than no names. A canvas
#    caption does not shrink with distance either (`world_caption.gd`), so the
#    far corner would shout exactly as loudly as your own feet.
#  * **`NAME_RANGE`, and not the pickup radius.** The name has to arrive while
#    the walk is still a choice. The collision sphere is 0.75 m; a name that
#    appeared there would appear at the same instant the mote vanished into the
#    bag, which answers the question after it has been asked. 4.5 m is about a
#    second and a half of running -- long enough to read one word and veer off
#    -- and it is exactly the reach the magnet has at a full chain
#    (`K.HEAT_MAGNET`), so at T3 everything already being dragged to you is also
#    named.
#  * **`NAME_MAX`, nearest first.** A killed pack drops several motes inside a
#    metre or two. The HUD's de-collide only stacks `Hud.CAPTION_STACK_MAX`
#    rows before it starts dropping captions itself -- and WHICH ones it drops
#    is decided by projected y, so the FARTHEST names would survive, which is
#    backwards for loot. So the choice is made here instead, on distance from
#    the hero, where it carries meaning: the three nearest motes wear their
#    names and the rest wait. Five in a pile is three names and two blank
#    prisms, and taking one promotes the next.
## Metres from the HERO, not from the camera. Same bargain `WorldCaption.max_range`
## and `Hud.EBAR_RANGE` already make, for the same reason: a caption that cannot
## recede has to leave rather than shrink.
const NAME_RANGE := 4.5
## Metres of fade before `NAME_RANGE`, so a name arrives as you close on it
## rather than switching on.
const NAME_FADE := 1.2
## How many motes may wear a name at once. Matched to `Hud.CAPTION_STACK_MAX` so
## the HUD's de-collide never has to refuse one of these -- every name this
## object puts up has a row to be pushed into.
const NAME_MAX := 3
## Seconds between re-rankings. The answer is "where is the player standing",
## which does not need to be right to the frame, and a floor of motes each
## asking every other one sixty times a second is not a trade worth making.
const NAME_TICK := 0.12
## Metres a rival has to be NEARER by before it takes a name that is already up.
##
## Without it two motes a hand's width apart trade the last row every time the
## hero shifts his weight, and a flickering name is far more distracting than a
## missing one. A name already up is sticky; a name not yet up is not.
const NAME_HYST := 0.35
## Where the caption hangs, in metres off the floor. Clear of the prism at its
## fattest (a stack bulks to 1.5x, so its peak plus the bob reaches ~0.63 m) and
## of the plate the caption wears under §5.7, which at 720p reaches about 0.12 m
## below the anchor at the distance this is read from.
const NAME_Y := 0.80
## Every live mote, so one can rank itself against the others. Nothing else
## reads it.
const NAME_GROUP := &"loot_mote"

var item_id: StringName = &""
## How many of `item_id` this one mote is worth.
##
## 1 for every drop the dungeon rolls, and it stays 1 — a kill drops N motes
## because N things fell off the body, and that is the picture. What needs more
## than one is the **Thief** (docs/BESTIARY.md §3): it takes a whole bag SLOT,
## and a slot is up to a full stack, so the thing it drops when you cut it down
## has to be the slot coming back. Twenty motes bursting out of one goblin would
## read as twenty drops rather than as your pearls, and the player would spend
## the recovery hoovering instead of seeing it.
##
## A short count means a FULL bag refuses the rest and the mote stays on the
## floor holding what would not fit — see `_try_take`, which is the same refusal
## a single mote already had, counted.
var count: int = 1
## What the chain was worth at the instant this came off the corpse. It COOLS on
## the floor over K.HEAT_COOL_TIME back to 1.0, which is the rule that makes
## sweeping-while-fighting the mastery move: the loot goes cold whether or not
## you do, so backing off to be safe is paid for in the only currency the game
## has. See Heat.
var heat_mult: float = 1.0

var _def: ItemDef
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _cap: WorldCaption
## Countdown to the next re-ranking. Starts at zero so a mote is ranked on its
## first processed frame rather than a tick after it lands.
var _name_t: float = 0.0
var _named: bool = false
var _age: float = 0.0
var _refused: float = 0.0
var _taken: bool = false
## Cached for the magnet. Re-fetched whenever it goes invalid, which it does on
## every scene change -- a mote outlives nothing, but the lookup is per-frame
## per-mote and a dungeon floor can hold a lot of them.
var _hero: Node3D = null


## Drop one at `at`, with a short arc so it reads as having come off the corpse.
static func drop(parent: Node, id: StringName, at: Vector3,
		fling: Vector3 = Vector3.ZERO, n: int = 1) -> LootMote:
	var m := LootMote.new()
	m.item_id = id
	m.count = maxi(n, 1)
	# Stamped at the drop, not read at the pickup. The chain that earned this is
	# the chain that was live when the thing died.
	m.heat_mult = Heat.multiplier()
	parent.add_child(m)
	m.global_position = at
	if fling != Vector3.ZERO:
		var land := at + fling
		var tw := m.create_tween()
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(m):
				m.global_position = at.lerp(land, t) + Vector3.UP * sin(t * PI) * 0.55,
			0.0, 1.0, 0.42).set_ease(Tween.EASE_OUT)
	return m


func _ready() -> void:
	_def = ItemDb.get_def(item_id)
	add_to_group(NAME_GROUP)
	collision_layer = 0
	collision_mask = K.L_PLAYER
	monitoring = true

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.75
	cs.shape = sp
	add_child(cs)

	_build()


func _build() -> void:
	var tint: Color = _def.tint if _def != null else Color(0.8, 0.8, 0.8)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = tint
	_mat.emission_enabled = true
	_mat.emission = tint
	_mat.emission_energy_multiplier = EMIT_BASE
	_mat.roughness = 0.85
	# Faceted, never smooth: the whole kit is hard-edged and a smooth-shaded
	# pickup reads as an asset from a different game.
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	_mesh = MeshInstance3D.new()
	var pm := PrismMesh.new()
	# A stack is BIGGER, and only a little: the size says "there is more than one
	# here" without a number floating over it. Capped, because a stolen slot can
	# be twenty bone shards and a prism the size of the goblin that dropped it
	# would read as a chest.
	var bulk := clampf(1.0 + 0.06 * float(count - 1), 1.0, 1.5)
	pm.size = Vector3(0.26, 0.34, 0.26) * bulk
	_mesh.mesh = pm
	_mesh.material_override = _mat
	_mesh.position.y = 0.28
	_mesh.layers = SELF_BIT
	add_child(_mesh)

	# A very short-range light so a drop in an unlit corner is still findable.
	# Rarer drops carry further, which is the only "look over here" the game does.
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 1.1
	_light.omni_range = 1.4 + (0.6 * float(_def.rarity) if _def != null else 0.0)
	_light.omni_attenuation = 1.8
	_light.shadow_enabled = false
	_light.position.y = 0.3
	# EVERYTHING EXCEPT THE MOTE. See SELF_BIT.
	_light.light_cull_mask = ALL_LAYERS & ~SELF_BIT
	add_child(_light)

	# The name. See the long note above `NAME_RANGE`. Almost all of this is
	# properties on a class that already exists: `max_range` / `fade_range` are
	# the attention radius, `occlude` (default true) is the ray that keeps the
	# name off the far side of a wall, and `declutter` (default true) puts it in
	# the HUD's de-collide with every other caption in the room.
	#
	# It does NOT bob with the prism, deliberately. The mote's own motion is
	# what says "loot"; a name riding it reads as loose type that happens to be
	# nearby rather than as a label ON something.
	_cap = WorldCaption.new()
	_cap.text = _caption_text()
	_cap.tint = _caption_tint()
	# 14 px, which is `Hud.TYPE_LADDER`'s middle rung and what a keeper's name
	# wears. The rung below is the ladder's floor -- legal, but §3.1b says there
	# is no margin under it, and three of these stacked at the floor is a row of
	# names nobody reads twice.
	_cap.ref_px = 14.0
	_cap.max_range = NAME_RANGE
	_cap.fade_range = NAME_FADE
	_cap.position.y = NAME_Y
	# Off until `_rank_the_name` says otherwise, which is on the next processed
	# frame. A mote that flashed its name for one frame at the moment it landed
	# and then went quiet would be the worst of both rules.
	_cap.visible = false
	add_child(_cap)


## What the plate says. The count rides the name rather than getting a plate of
## its own -- a stolen slot coming back off a Thief is "PEARL ×12" and not two
## captions arguing about one prism.
func _caption_text() -> String:
	if _def != null:
		return _def.display_name if count <= 1 else \
			"%s ×%d" % [_def.display_name, count]
	# A relic is dropped through this same object (`RelicPickup.place`) and its
	# name lives in `RelicDb`, not the catalogue. Naming the scrap and leaving
	# the one thing on the floor worth crossing the room for anonymous would be
	# the defect this card is about, pointed the other way.
	var relic := RelicDb.by_id(item_id)
	return String(relic["name"]) if not relic.is_empty() else ""


## The ink. `Pal.RARITY`, which is what the pickup toast and the bag rim already
## colour an item name with (`Hud._on_loot`) -- so the word on the floor and the
## word that flies into the corner half a second later are the same colour, and
## a common drop renders in MOTH because it is "something you did not need to
## read".
func _caption_tint() -> Color:
	if _def != null:
		return Pal.rarity_color(int(_def.rarity))
	# Relics are not on the rarity ladder and are rarer than anything on it.
	return Pal.ARCANE if RelicDb.is_relic(item_id) else Pal.MOTH


func _process(delta: float) -> void:
	_age += delta
	if _taken:
		return

	# Hot loot spins faster and burns brighter, and both fade as it cools. The
	# TINT is untouched on purpose: tint is what the thing IS (rarity, and the
	# glow radius the styleguide hangs on it), and recolouring a Bone Shard gold
	# because you were on a streak would make the HUD's one honest "look over
	# here" tell you the wrong thing. Heat changes the ENERGY, not the hue.
	var hot := heat()
	var bob := sin(_age * BOB_SPEED * hot) * BOB_HEIGHT
	_mesh.position.y = 0.28 + bob
	_mesh.rotation.y += SPIN_SPEED * hot * delta
	_light.position.y = 0.3 + bob

	# Before the refusal branch below returns: a mote the bag would not take is
	# still on the floor, and a player being refused is exactly who wants to
	# read what they are being refused.
	_name_t -= delta
	if _name_t <= 0.0:
		_name_t = NAME_TICK
		_rank_the_name()

	if _refused > 0.0:
		# Full bag. Pulse toward RUST rather than vanish -- the mote is still
		# there, and the player needs to know it is still there.
		_refused = maxf(0.0, _refused - delta)
		var p := 0.5 + 0.5 * sin(_age * 14.0)
		_mat.emission = Pal.RUST.lerp(_def.tint if _def != null else Pal.BONE, 1.0 - p)
		# Both ramps are rebased on EMIT_BASE rather than on the old 0.9. They used
		# to top out at 2.9 and 2.5, which was inaudible: the surface was already
		# clipped at rest, so "hot" and "refused" both looked exactly like "there".
		# A refusal that reads has to start from a mote that is NOT white.
		_mat.emission_energy_multiplier = EMIT_BASE + p * 0.55
		return

	if hot > 1.0:
		_mat.emission_energy_multiplier = EMIT_BASE + (hot - 1.0) * 0.45
		_light.light_energy = 1.1 + (hot - 1.0) * 1.4

	if _age < ARM_TIME:
		return
	_magnetise(delta)
	for b in get_overlapping_bodies():
		if b.is_in_group(&"player"):
			_try_take()
			return


## What this is worth right now: the heat it was killed at, decaying to base over
## K.HEAT_COOL_TIME. Also drives the glow, so "that one is still hot" is a thing
## you can see across a room rather than a number you have to remember.
func heat() -> float:
	if heat_mult <= 1.0:
		return 1.0
	# The Slow Fade (`EchoDb.SLOW_FADE`): motes never cool, so a stamped
	# multiplier holds until you sweep it and a chain can be spent on fighting
	# instead of on tidying (`docs/PUZZLES.md` §6.1, row 3). The mote still has to
	# be picked up -- the Echo bends the CLOCK, not the walk.
	if Run.has_echo(EchoDb.SLOW_FADE):
		return heat_mult
	var t: float = clampf(_age / K.HEAT_COOL_TIME, 0.0, 1.0)
	return lerpf(heat_mult, 1.0, t)


## Is this one of the motes wearing its name right now?
##
## Nearest-first, capped at `NAME_MAX`, inside `NAME_RANGE`. The rank is counted
## rather than sorted -- a mote only needs to know whether `NAME_MAX` others beat
## it, so the loop stops the moment it has found that many and never builds a
## list.
##
## Ties are broken on instance id, which matters more than it looks: `drop`
## places several motes from one kill at very nearly one point, and two motes
## that each believe they are the nearer one would both claim the last row.
func _rank_the_name() -> void:
	if _cap == null or _cap.text.is_empty():
		return
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group(&"player") as Node3D
	if _hero == null:
		_show_name(false)
		return
	var mine := global_position.distance_to(_hero.global_position)
	if mine > NAME_RANGE:
		_show_name(false)
		return
	# See `NAME_HYST`. A name already up defends its row; a name not yet up does
	# not get the same benefit, which is what makes this hysteresis and not a
	# thumb on the scale.
	var edge := NAME_HYST if _named else 0.0
	var nearer := 0
	for n in get_tree().get_nodes_in_group(NAME_GROUP):
		var other := n as LootMote
		if other == null or other == self or other._taken or not other._names():
			continue
		var d := other.global_position.distance_to(_hero.global_position)
		if d < mine - edge or (is_equal_approx(d, mine)
				and other.get_instance_id() < get_instance_id()):
			nearer += 1
			if nearer >= NAME_MAX:
				break
	_show_name(nearer < NAME_MAX)


## Does this mote have a name to show at all? A rival with no caption -- a drop
## of something the catalogue has never heard of -- must not hold a row.
func _names() -> bool:
	return _cap != null and not _cap.text.is_empty()


func _show_name(on: bool) -> void:
	_named = on
	if _cap != null:
		_cap.visible = on


## Drag toward the hero while the chain is lit. This is the change that makes a
## chain survivable: without it the loop is kill, halt, hoover, and the window is
## gone before you have picked up what you earned. The pull is a POSITION nudge,
## not a force -- the mote is an Area3D with no body, and the existing overlap
## test then takes it exactly as if you had walked over it.
func _magnetise(delta: float) -> void:
	var reach := Heat.magnet_range()
	if reach <= 0.0 or _age < MAGNET_ARM:
		return
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group(&"player") as Node3D
		if _hero == null:
			return
	var to := _hero.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > reach or d < 0.01:
		return
	global_position += to / d * K.HEAT_MAGNET_SPEED * delta


## Walked over. **A partial pickup leaves the remainder on the floor** rather
## than swallowing it: `Run.collect` answers how many actually fit, and a mote
## carrying a stolen slot into a bag with one cell free would otherwise delete
## the rest of the stack at the moment of recovery — the exact loss the player
## just killed something to undo.
func _try_take() -> void:
	var got := Run.collect(item_id, count, heat())
	if got >= count:
		_taken = true
		taken.emit(item_id)
		_pop()
		return
	if got > 0:
		count -= got
		# The plate has to agree with the prism. A mote that just handed over
		# four of six and went on saying "×6" is the caption lying about the one
		# thing it was added to be honest about.
		if _cap != null:
			_cap.text = _caption_text()
	_refused = 0.9


## Rise and fade. Cheap, but it is the only confirmation the player gets that the
## thing on the floor became the number in the corner.
func _pop() -> void:
	monitoring = false
	# The name goes with the prism, not after it. `_process` returns early once
	# `_taken` is set, so nothing else would ever take this row back -- and a
	# caption left hanging over a rising, shrinking mote is the one moment the
	# player is being told what they got by the HUD toast instead.
	_show_name(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mesh, "position:y", _mesh.position.y + 0.9, 0.26) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_mesh, "scale", Vector3.ONE * 0.1, 0.26).set_ease(Tween.EASE_IN)
	tw.tween_property(_light, "light_energy", 0.0, 0.26)
	tw.chain().tween_callback(queue_free)
