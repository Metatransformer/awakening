class_name LockedDoor
extends Interactable
## A door that will not open until you own a particular item, and says which one.
##
## This is the gate half of docs/GDD.md §5.3 -- eight of these are the entire
## "the dungeon reshapes itself around what you have proved you can do" system
## (docs/SCOPE.md §1 counts them: 4 shortcuts, 3 vaults, 1 to the Long Descent).
## There is no key, no puzzle and no switch. There is an item id.
##
## **The door is dumb, and that is the design.** It does not call `Flow`, it does
## not know what is on the other side, and it does not move the player. It owns
## exactly three things: the refusal, the opening, and a one-way flag so a floor
## you come back to remembers. `destination` is an opaque tag it hands to whoever
## placed it, via `opened`, and the placer decides what that means -- a shortcut
## warp, a vault room, nothing at all. `Flow` is the only thing in the project
## that changes scenes (CLAUDE.md §6) and a door that did it would be the second.
##
## **The refusal names the item.** Not "LOCKED". GDD pillar 3 is that loss is
## legible, and a refusal is the same promise: a player who reads "NEEDS THE BOW"
## knows what the door is for, knows the bow exists, and knows where they are
## going next. "LOCKED" tells them only that they have wasted a walk.
##
## Built in code like the rest of the kit (see `stairs.gd`, `kit_*.gd`): the
## scene stores parameters, never a few hundred generated triangles.

## Fired the instant the leaves start to swing, NOT when they finish -- the
## placer usually wants to unlock the far side, light a corridor or write its own
## flag while the door is still opening, and half a second of silence after a
## door opens reads as a hitch. `where` is `destination`, verbatim.
signal opened(where: StringName)

## The item id that opens this. `&"bow"`, `&"hookshot"`, and whatever M6 adds.
@export var key_item: StringName = &"bow"
## What the plate over the door says. Empty for no plate -- a shortcut back to a
## room you have already seen does not need naming, a vault does.
@export var label: String = ""
## An opaque tag for whoever placed the door. The door never reads it; it only
## hands it back on `opened`. It IS the flag's identity, though (see `flag_id`),
## so two doors on one floor must not share one.
@export var destination: StringName = &""
## The hole this fills. Defaults to the kit's doorway (K.DOOR_W x K.DOOR_H), so
## a LockedDoor dropped at a `KitDoorway`'s origin fits it without arithmetic.
@export var opening_w: float = K.DOOR_W
@export var opening_h: float = K.DOOR_H

# --- Proportions -------------------------------------------------------------
# All measured against the 1.65 m hero and the 5-degree camera pitch, which is
# what decides whether a detail is on screen at all (docs/CONTRACT.md §1.2).

const LEAF_T := 0.22
## Seam gap. Two leaves that meet exactly co-planar z-fight along the joint.
const SEAM := 0.018
## The sigil sits at 1.58 -- above the hero's eye (K.HERO_EYE_Y 1.32) but well
## inside the frame at playing distance. Put on the lock plate at waist height it
## was behind the hero's own shoulder from the approach the player actually uses.
const MED_Y := 1.58
## Radius of the carved ring around the sigil.
const MED_R := 0.50
## The glyph's unit square is scaled by this, so a rect at x = 1.0 lands here.
const SIGIL_R := 0.30
## Two bars, one high and one low, retracting in opposite directions. One bar
## reads as a latch; two read as SEALED, and they leave the sigil between them
## clear instead of crossing it.
const BAR_HI_Y := 2.46
const BAR_LO_Y := 0.74
const BAR_TRAVEL := 0.60
## Degrees each leaf swings, into the room. Into the room rather than away
## because a door that opens into the passage disappears behind the reveal and
## the player never sees it move -- the open is authored so that it can be
## watched.
##
## 56, not 88 and not 74. This number was set twice by looking at the frame and
## twice it was too big. At 88 the leaves finish edge-on to a camera standing
## square to the door and read as two dark posts. At 74 they are 16 degrees off
## edge-on, which photographed no better: the open frame came back as a clean
## empty hole with two thin green streaks beside it -- the streaks being the only
## part of the leaves still facing the lens, the emissive half-sigils. The door
## had vanished from the shot that is supposed to prove it opened.
##
## 56 leaves roughly half of each leaf's width projected toward the player, so
## the boards, the strapwork and both halves of the mark survive the swing, and
## it still leaves 1.1 m of clear opening for a 0.6 m hero to walk through.
const OPEN_DEG := 56.0
const OPEN_TIME := 0.85

# --- The sigil table ---------------------------------------------------------
## key item -> how the door talks about it and what its mark looks like.
##
## `static var`, not `const`: the values hold `Pal` colours, and a const
## Dictionary holding another class's constants is not a constant expression
## (CLAUDE.md §3). Still built once, still shared.
##
## The colours are the palette's, and the two assignments are not free choices:
##
##  * **Hookshot -> CYAN.** docs/STYLEGUIDE.md §2 reserves EXTRACT CYAN for "the
##    way out" and names exactly two things it belongs to -- extraction nodes and
##    *the hookshot line*. A door wearing the hookshot's own hue is the
##    styleguide's assignment, not a new one.
##  * **Bow -> MOSS.** By elimination, honestly. GOLD is currency and ONLY
##    currency, VITAL and RUST are damage, ARCANE is legendary loot twice a run,
##    CYAN is spoken for above. MOSS is the one saturated hue left, and a yew
##    stave is the one thing in the game it flatters.
##
## Adding floor 3's door is one row here. That is the whole acceptance test.
static var SIGILS := {
	&"bow": {"noun": "THE BOW", "hue": Pal.MOSS, "shape": &"bow"},
	&"hookshot": {"noun": "THE HOOKSHOT", "hue": Pal.CYAN, "shape": &"hook"},
	# The other two keys in the manifest. Floor 1's VAULT is keyed to floor 2's
	# boss item (`FloorDb.vault_key`), so without these rows the first locked
	# door a player meets on the first floor says "NEEDS A KEY" -- a generic
	# refusal on the one door whose whole job is to name a thing worth going
	# deeper for, and a straight miss of GDD pillar 3.
	#
	# Both wear the fallback KEYHOLE on purpose. The WORDS are the gap; authoring
	# a verse and a lantern glyph is art, and art is not this card. `shape` is
	# still spelled out rather than left to `SIGIL_DEFAULT`, because `_sigil`
	# indexes the row directly and a row missing the key is a crash, not a
	# fallback. The hues are pulled apart from each other and from the two above
	# so four doors are still four colours across a dark room -- and neither is
	# `Pal.GOLD`, which STYLEGUIDE §2 reserves for currency.
	&"burst": {"noun": "THE BURST-VERSE", "hue": Pal.RUST, "shape": &"keyhole"},
	&"far_lantern": {"noun": "THE FAR LANTERN", "hue": Pal.ARCANE, "shape": &"keyhole"},
}

## For a key with no row: a plain keyhole in the game's off-white. A door that
## refuses to render is worse than a door that refuses generically.
static var SIGIL_DEFAULT := {"noun": "A KEY", "hue": Pal.BONE, "shape": &"keyhole"}

## How far the sigil's own hue is dragged toward cold stone-blue while it is
## locked. Not zero, and not black: the door has to read as LOCKED from across a
## dark room with no text on it (GDD pillar 5 -- a silhouette you cannot read is
## a bug, and it was one, twice), and the cheapest honest way to say "this hue is
## not live yet" is the hue itself, chilled and dim. Warming it back is then a
## change you can see in a still frame rather than only in motion.
##
## 0.40, down from 0.72. At 0.72 the bow's MOSS arrived on screen as pale blue --
## indistinguishable from the hookshot door six metres behind it, and a straight
## violation of STYLEGUIDE §2's rule that EXTRACT CYAN belongs to the way out and
## the hookshot line and to nothing else. Chilled MOSS has to stay green.
const CHILL := 0.40
const SIGIL_ENERGY_LOCKED := 0.55
const SIGIL_ENERGY_OPEN := 2.2
## The lamp is not a glow around the mark, it is THE DOOR'S LIGHT, and it has to
## be strong enough to model the strapwork -- the first pass ran it at 0.9 and
## every frame came back with a lit sigil floating in a black rectangle, because
## the room's sconces sit in the plane of the wall and rake straight past a door
## recessed into it. A cold pool on warm stone is also the read the brief asks
## for: the locked door is the one COLD thing in a torchlit room, which is
## STYLEGUIDE §1's warm-key/cool-air contrast used the other way up.
const SIGIL_LAMP_LOCKED := 1.5
const SIGIL_LAMP_OPEN := 3.2
## The warm light that comes up in the passage when the door opens. Fire-coloured
## against the sigil's cool: STYLEGUIDE §1 rule 2, warm key against cool air, and
## it is what makes an opened door read as somewhere you can now go.
const PASS_ENERGY := 6.5

var _open: bool = false
var _pivots: Array[Node3D] = []
var _bar_hi: Node3D
var _bar_lo: Node3D
var _blocker: StaticBody3D
var _sigil_mat: StandardMaterial3D
var _sigil_lamp: OmniLight3D
var _pass_lamp: OmniLight3D
var _plate: Label3D
var _tween: Tween


func _ready() -> void:
	# Wide enough that the player is offered the door before they are nose to the
	# planks. Measured like Stairs' was: the leaves are solid, so the closest he
	# can physically stand is about 0.6 m, and a radius that only just reaches
	# there means walking up at an angle finds nothing.
	radius = 2.9
	super()
	_build()
	_refresh_prompt()
	# A floor you come back to remembers. `flags` is one-way and saved, so a door
	# opened last run comes up already open, with no tween and no sound -- the
	# sound is for the moment it happens, and replaying it on every load would
	# turn a landmark into a jingle.
	if Game.flag(flag_id()):
		_pose_open()
	# The gate can be crossed while the player is standing at it -- a boss dies,
	# the bow drops, and the line over the door has to stop lying immediately.
	Bus.item_acquired.connect(_on_item_acquired)


# --- The gate ----------------------------------------------------------------

## Whether the player may pass. One call to THE ownership gate (`Game.has`), and
## deliberately not a cached bool: the item can arrive while the door is on
## screen.
func unlocked() -> bool:
	return Game.has(key_item)


func is_open() -> bool:
	return _open


## The one-way world flag this door writes. Keyed on `destination` because that
## is the thing the placer already had to make unique; falling back to the node
## name keeps an unnamed test door from sharing the fallback with every other one.
func flag_id() -> StringName:
	var tag := String(destination) if destination != &"" else String(name)
	return StringName("door_open_%s" % tag)


## "NEEDS THE BOW". Static so the placer, a HUD toast or a director can ask what
## a door will say without instancing one.
static func refusal_for(key: StringName) -> String:
	return "NEEDS %s" % String(sigil_of(key)["noun"])


static func sigil_of(key: StringName) -> Dictionary:
	return SIGILS.get(key, SIGIL_DEFAULT)


## What THIS door says while it is shut. The instance-level counterpart of
## `refusal_for`, and the single place the two lines below read.
##
## It exists so `PuzzleGate` can say "2 OF 3 EYES STILL SHUT" -- a refusal that
## names the verb and counts the work left, which is the atom kit's half of the
## same promise the class note makes about "LOCKED". A gate whose line came from
## `refusal_for(key_item)` would say "NEEDS THE BOW" at a door the bow does not
## open, which is worse than saying nothing.
func refusal_line() -> String:
	return refusal_for(key_item)


func activate(by: Node3D) -> void:
	if _open:
		return
	if not unlocked():
		_refuse()
		return
	activated.emit(by)
	_swing()


# --- What the player is told -------------------------------------------------

## Locked, the HUD line is the refusal and it carries no keycap. Unlocked, it is
## the verb and `Prompt` puts the button on the front of it as usual.
##
## THIS FIGHTS `Prompt` ON PURPOSE, and the alternative was worse. `Prompt`
## formats every focused prop as "<KEY> TO <prompt>", which is right for a verb
## and nonsense for a refusal -- "E TO NEEDS THE BOW". A locked door has no verb,
## because there is nothing the button does; the line has to be a statement. So
## the door re-emits `Bus.prompt_changed` for itself, one frame-deferred, because
## `Prompt` calls `on_focus()` and THEN `_say_prompt()` in the same tick and an
## immediate emit would simply be overwritten. The deferred call flushes before
## the HUD redraws, so there is no flicker.
##
## `prompt` is still set to the same words, so the one path that skips the
## formatting (no keycap bound for `interact`) says the same thing.
func on_focus(on: bool) -> void:
	if on and not _open and not unlocked():
		_say_refusal.call_deferred()


func _refresh_prompt() -> void:
	prompt = "OPEN" if unlocked() else refusal_line()


func _say_refusal() -> void:
	if Prompt.focus != self or _open or unlocked():
		return
	Bus.prompt_changed.emit(refusal_line())


func _on_item_acquired(id: StringName) -> void:
	if id != key_item or _open:
		return
	_refresh_prompt()
	# The mark stops being dead the moment you own the thing, whether or not you
	# are standing here -- an owned door glimpsed from the far end of a corridor
	# should already be inviting.
	_tint_sigil(1.0)
	if Prompt.focus == self:
		Bus.prompt_changed.emit("%s TO OPEN" % Glyph.cap(&"interact"))


# --- Refusal -----------------------------------------------------------------

## The door says no with its body, not only with a line of text. A jolt against
## the bars and the game's one refusal noise -- `craft_fail` is what `bag_full`
## already uses, and Sfx's own note says the player should learn ONE refusal
## sound rather than three.
##
## It is one of only two refusals left. The rope was the third until 2026-08-09,
## when the fee was capped at the purse: a locked door is a refusal you can act
## on, and an exit you could not afford was not.
func _refuse() -> void:
	Bus.request_sfx.emit(&"craft_fail", global_position)
	_say_refusal()
	if _tween != null and _tween.is_valid():
		return
	# Both legs are parallel tweeners on the SAME property with the return leg
	# delayed past the push, and the return states its `from` explicitly. Left to
	# infer it, a delayed tweener's start value is read at a moment that depends
	# on how the two overlap, and the door settled to a different resting angle
	# depending on frame rate.
	_tween = create_tween().set_parallel(true)
	for p in _pivots:
		var side := signf(p.position.x)
		_tween.tween_property(p, "rotation:y", side * 0.04, 0.06)
		_tween.tween_property(p, "rotation:y", 0.0, 0.26) \
			.from(side * 0.04).set_delay(0.06) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- Opening -----------------------------------------------------------------

## The authored open. One tween, parallel, landing in the same pose `_pose_open`
## snaps to -- so a door opened live and a door restored from a flag are the same
## door afterwards and nothing has to know which happened.
func _swing() -> void:
	if _open:
		return
	_open = true
	Game.set_flag(flag_id())
	# `Bus.request_sfx` rather than `Bus.door_opened`: Sfx maps that signal to
	# this same `door_open` cue at the HERO's position, so emitting both would
	# play the door twice, once of them in the wrong place.
	Bus.request_sfx.emit(&"door_open", global_position)
	opened.emit(destination)

	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	# Nothing left to address. `enabled`'s setter drops Prompt's focus, which
	# clears the HUD line as a side effect -- exactly what should happen.
	enabled = false

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The bars first and fast: the door cannot start moving until it is unbarred,
	# and seeing that order is the difference between a door opening and a door
	# dissolving.
	_tween.tween_property(_bar_hi, "position:y", BAR_HI_Y + BAR_TRAVEL, 0.30)
	_tween.tween_property(_bar_lo, "position:y", BAR_LO_Y - BAR_TRAVEL, 0.30)
	_tween.tween_property(_sigil_mat, "emission_energy_multiplier",
		SIGIL_ENERGY_OPEN, 0.35)
	_tween.tween_property(_sigil_mat, "emission", _hue(), 0.35)
	_tween.tween_property(_sigil_mat, "albedo_color", _hue().darkened(0.55), 0.35)
	_tween.tween_property(_sigil_lamp, "light_color", _hue(), 0.35)
	_tween.tween_property(_sigil_lamp, "light_energy", SIGIL_LAMP_OPEN, 0.35)
	_tween.tween_property(_pass_lamp, "light_energy", PASS_ENERGY, 0.7) \
		.set_delay(0.25)
	for p in _pivots:
		var side := signf(p.position.x)
		_tween.tween_property(p, "rotation:y", side * deg_to_rad(OPEN_DEG),
			OPEN_TIME).set_delay(0.22)
	if _plate != null:
		_tween.tween_property(_plate, "modulate", Pal.BONE, 0.5)


## The finished pose, with no motion and no sound. Called from `_ready` when the
## save already says this door is open.
func _pose_open() -> void:
	_open = true
	enabled = false
	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	_bar_hi.position.y = BAR_HI_Y + BAR_TRAVEL
	_bar_lo.position.y = BAR_LO_Y - BAR_TRAVEL
	for p in _pivots:
		p.rotation.y = signf(p.position.x) * deg_to_rad(OPEN_DEG)
	_tint_sigil(1.0)
	_sigil_lamp.light_energy = SIGIL_LAMP_OPEN
	_pass_lamp.light_energy = PASS_ENERGY
	if _plate != null:
		_plate.modulate = Pal.BONE


## `warm` runs 0 (locked: the hue chilled toward stone-blue and barely lit) to 1
## (open: the item's own colour, live). One function so the tween's end state and
## the restored-from-flag state cannot drift.
func _tint_sigil(warm: float) -> void:
	var col := _hue() if warm >= 1.0 else _chilled()
	_sigil_mat.albedo_color = col.darkened(lerpf(0.82, 0.55, warm))
	_sigil_mat.emission = col
	_sigil_mat.emission_energy_multiplier = lerpf(
		SIGIL_ENERGY_LOCKED, SIGIL_ENERGY_OPEN, warm)
	_sigil_lamp.light_color = col
	_sigil_lamp.light_energy = lerpf(SIGIL_LAMP_LOCKED, SIGIL_LAMP_OPEN, warm)


func _hue() -> Color:
	# Annotated, not returned bare: indexing an untyped Dictionary hands back a
	# Variant and the return type will not infer from one (CLAUDE.md §3).
	var col: Color = sigil_of(key_item)["hue"]
	return col


func _chilled() -> Color:
	return _hue().lerp(Pal.COBALT, CHILL)


# --- Construction ------------------------------------------------------------

func _build() -> void:
	var hw := opening_w * 0.5
	# Lifted from 0.12/0.10 after looking at the frames. STYLEGUIDE §2 puts world
	# surfaces between VOID and ASH, and 0.12 is inside that band -- but the P6
	# kit's own stone renders as bright warm tan under a sconce, and against it a
	# 0.12 door was not "dark", it was a hole in the wall with a sigil in it. Dark
	# enough to be the darkest thing in the frame, light enough to have parts.
	var plank := _mat(Color(0.235, 0.185, 0.150), 0.98, 0.0)
	# Barely metallic on purpose. At metallic 0.42 / roughness 0.55 the lock plate
	# is a flat slab square-on to both the door's lamp and the camera, so it caught
	# the whole specular lobe at once and photographed as one pale lavender
	# rectangle -- brighter than the timber, brighter than the stone, reading as
	# painted plastic. Iron in this kit has to be DARKER than the boards it is
	# strapped to; the sheen belongs on the edges, which a rough near-dielectric
	# still gives at a rake.
	var iron := _mat(Color(0.150, 0.145, 0.172), 0.72, 0.16)
	var stone := _mat(Color(0.230, 0.220, 0.255), 0.97, 0.0)

	# The mark carries its colour in the EMISSION and keeps a near-black albedo.
	# Tinted albedo washed to white: the door's own lamp is 600 mm in front of the
	# mark, so a pale-blue albedo under it plus emission on top clipped, and the
	# chilled MOSS the table asked for photographed as a white crescent. Emission
	# is not lit by anything, so this is the one channel a nearby lamp cannot
	# bleach.
	_sigil_mat = _mat(_hue().darkened(0.82), 0.80, 0.0)
	_sigil_mat.emission_enabled = true
	_sigil_mat.emission = _chilled()
	_sigil_mat.emission_energy_multiplier = SIGIL_ENERGY_LOCKED

	# The void behind the mark. UNSHADED near-black, the trick stairs.gd's pit
	# uses: lit like ordinary timber this plate comes back as dark brown and the
	# recess turns into a sticker. Unshaded, it is a hole with something in it.
	var voidmat := _mat(Pal.VOID, 1.0, 0.0)
	voidmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_build_blocker(hw)
	_build_leaves(hw, plank, iron, voidmat)
	_build_bars(hw, iron)
	_build_lights()
	_build_plate(stone)


## What actually stops the hero. One box, on the world layer, freed when the door
## opens -- rather than a disabled shape, because a shape that is only disabled
## is one bug away from an invisible wall in a door you can see through.
func _build_blocker(hw: float) -> void:
	_blocker = StaticBody3D.new()
	_blocker.name = "Blocker"
	_blocker.collision_layer = K.L_WORLD
	_blocker.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(hw * 2.0, opening_h, LEAF_T + 0.2)
	cs.shape = box
	cs.position = Vector3(0.0, opening_h * 0.5, 0.0)
	_blocker.add_child(cs)
	add_child(_blocker)


## Two leaves. Each is a pivot at its own jamb holding a body node that undoes
## the pivot's offset, so every mesh below is authored in DOOR space (origin at
## the centre of the threshold) and the maths for the ring and the sigil does not
## have to be written twice with opposite signs.
func _build_leaves(hw: float, plank: Material, iron: Material,
		voidmat: Material) -> void:
	var leaf_w := hw - SEAM
	# Typed loop variables: iterating an untyped Array literal yields Variants,
	# and every `:=` derived from one fails to infer (CLAUDE.md §3).
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "PivotR" if side > 0.0 else "PivotL"
		pivot.position = Vector3(side * hw, 0.0, 0.0)
		add_child(pivot)
		_pivots.append(pivot)

		var body := Node3D.new()
		body.name = "Body"
		body.position = Vector3(-side * hw, 0.0, 0.0)
		pivot.add_child(body)

		var cx := side * (hw + SEAM) * 0.5

		# Backing slab, then three proud boards over it. The boards are what make
		# it timber: a single slab at this size is a wall with hinges, and the
		# vertical grain is the only thing on the door running the other way to
		# the bars.
		_box(body, plank, Vector3(leaf_w, opening_h, LEAF_T),
			Vector3(cx, opening_h * 0.5, 0.0))
		var boards := 3
		var board_w := leaf_w / float(boards) - 0.035
		for b in boards:
			var bx := cx + (float(b) - float(boards - 1) * 0.5) * (leaf_w / float(boards))
			_box(body, plank, Vector3(board_w, opening_h - 0.10, 0.05),
				Vector3(bx, opening_h * 0.5, LEAF_T * 0.5 + 0.02))

		# Iron edging: the hinge stile, the meeting stile, and a strap top and
		# bottom. Metallic and smoother than the timber, so the torch finds it --
		# the highlight travelling along a band is what says "iron" at 8 m, which
		# is the range the combat design has to be readable at.
		_box(body, iron, Vector3(0.17, opening_h, LEAF_T + 0.10),
			Vector3(side * (hw - 0.09), opening_h * 0.5, 0.0))
		_box(body, iron, Vector3(0.13, opening_h, LEAF_T + 0.08),
			Vector3(side * (SEAM + 0.065), opening_h * 0.5, 0.0))
		for sy: float in [0.30, opening_h - 0.30]:
			_box(body, iron, Vector3(leaf_w, 0.15, LEAF_T + 0.09),
				Vector3(cx, sy, 0.0))
			for r in 3:
				var rx := cx + (float(r) - 1.0) * (leaf_w * 0.30)
				_box(body, iron, Vector3(0.085, 0.085, 0.075),
					Vector3(rx, sy, LEAF_T * 0.5 + 0.08))

		# Two big hinge irons on the jamb side, because a door this heavy has to
		# look hung. They are also the silhouette cue from the side.
		for hy: float in [0.72, opening_h - 0.72]:
			_box(body, iron, Vector3(leaf_w * 0.62, 0.20, LEAF_T + 0.14),
				Vector3(cx + side * (leaf_w * 0.19), hy, 0.0))

		_build_medallion(body, side, iron, voidmat)


## The lock plate: a stepped iron boss standing PROUD of the boards, a carved
## ring on it, a dark eye inside the ring, and this leaf's half of the mark
## hanging in the eye.
##
## Proud, not sunk, and that was a rewrite. The obvious build puts the mark in a
## recess cut into the door -- except the door is boards and straps, all of which
## stand 25-40 mm off the backing slab, so a "recess" at the slab's own depth is
## behind every one of them and the eye is occluded from any angle but head-on.
## Standing the whole assembly forward of the planking gives the same read -- the
## mark still sits at the bottom of a well, it is just a well built up rather
## than dug down -- and it survives the camera actually orbiting.
##
## Two steps rather than one flat plate, which is kit_doorway.gd's trick for the
## door surround and for the same reason: it is the STEPPING that catches
## torchlight and tells you a thing is bolted on from across a dark room.
##
## The ring is BLOCKS ON A CIRCLE rather than a torus for one reason: it has to
## come apart down the middle, and a carved ring splitting into two halves as the
## door swings is the single detail that says "this was one thing and now it is
## open". A cylinder cannot be halved by geometry it does not know about.
func _build_medallion(body: Node3D, side: float, iron: Material,
		voidmat: Material) -> void:
	var face := LEAF_T * 0.5
	# Lock furniture is BLACKENED iron, and here that is a lighting fix as much as
	# a material one: the plate is the flattest, largest, most square-on surface on
	# the door and it sits a metre from the door's own lamp, so at the strapwork's
	# albedo it came back half again brighter than the timber -- a pale slab with
	# a mark on it. Darkest thing on the door is also the right backing for the one
	# lit thing on the door.
	var lock := _mat(Color(0.105, 0.100, 0.120), 0.86, 0.10)
	# Step one, wider and thinner; step two, the plate the ring sits on. Both were
	# 60 mm bigger and the ring then floated in the middle of a blank rectangle;
	# hugging the ring, with a bolt in each corner, is what makes the plate look
	# fitted to the mark rather than a panel the mark was printed on.
	_box(body, lock, Vector3(0.60, 1.24, 0.06), Vector3(side * 0.30, MED_Y, face + 0.055))
	_box(body, lock, Vector3(0.56, 1.18, 0.12), Vector3(side * 0.28, MED_Y, face + 0.115))
	var boss := face + 0.175
	for by: float in [MED_Y - 0.50, MED_Y + 0.50]:
		_box(body, lock, Vector3(0.09, 0.09, 0.08), Vector3(side * 0.46, by, boss + 0.04))

	# 16 blocks, offset by half a step so none of them lands on the seam.
	for i in 16:
		var a := deg_to_rad(11.25 + float(i) * 22.5)
		var px := cos(a) * MED_R
		if signf(px) != side:
			continue
		_box(body, lock, Vector3(0.155, 0.13, 0.15),
			Vector3(px, MED_Y + sin(a) * MED_R, boss + 0.075), a)

	# The eye: unshaded VOID, the trick stairs.gd's pit uses. The mark then reads
	# as something lit hanging in a hole, which is what an emissive shape over
	# near-black CANNOT do on its own (CLAUDE.md §3 -- alpha does not attenuate
	# ADD, so the answer is the SHAPE around it, not a softer material).
	#
	# Stepped into a half-disc rather than left as one square. A square eye inside
	# a round ring photographed as a black rectangle with a bezel round it -- the
	# corners crowded the ring at the diagonals and the two shapes fought. Five
	# courses of decreasing width per leaf sit inside the ring at every angle, and
	# at this size the steps read as a chamfer rather than as stairs.
	for course: Array in [[0.382, 0.26, 0.0], [0.352, 0.16, 0.20],
			[0.352, 0.16, -0.20], [0.255, 0.14, 0.35], [0.255, 0.14, -0.35]]:
		var ew: float = course[0]
		_box(body, voidmat, Vector3(ew, float(course[1]), 0.02),
			Vector3(side * ew * 0.5, MED_Y + float(course[2]), boss + 0.012))

	var shape: StringName = sigil_of(key_item)["shape"]
	for r in _glyph_rects(shape):
		var gx: float = float(r["x"]) * SIGIL_R
		if signf(gx) != side:
			continue
		# A rect sitting almost ON the seam belongs to neither leaf: it would hang
		# 40 mm over its neighbour and swing away as a stub. Dropped from both,
		# which leaves a hairline gap in the mark exactly where the seam already
		# draws one -- the mark is meant to look cut in half, so the gap is the
		# detail rather than a hole in it.
		if absf(float(r["x"])) < 0.10:
			continue
		# 25 mm behind the ring's lip, so the ring shades it from above and the
		# lamp out front rakes it. Level with the lip it read as a decal.
		_box(body, _sigil_mat,
			Vector3(float(r["w"]) * SIGIL_R, float(r["h"]) * SIGIL_R, 0.055),
			Vector3(gx, MED_Y + float(r["y"]) * SIGIL_R, boss + 0.05),
			float(r["r"]))


## Two bars across both leaves, in their own nodes so they can retract without
## the leaves. The brackets stay put -- a bracket that travelled with the bar
## would be a bracket that had come off the wall.
func _build_bars(hw: float, iron: Material) -> void:
	var z := LEAF_T * 0.5 + 0.20
	for pair in [[BAR_HI_Y, "BarHigh"], [BAR_LO_Y, "BarLow"]]:
		var y: float = pair[0]
		var bar := Node3D.new()
		bar.name = String(pair[1])
		bar.position = Vector3(0.0, y, 0.0)
		add_child(bar)
		_box(bar, iron, Vector3(hw * 2.0 + 0.55, 0.26, 0.22), Vector3(0.0, 0.0, z))
		# Three collars along it, so the bar has length rather than being one
		# extruded rectangle -- at this scale a plain box reads as a UI element.
		for c: float in [-0.62, 0.0, 0.62]:
			_box(bar, iron, Vector3(0.14, 0.34, 0.28),
				Vector3(c * hw, 0.0, z))
		for s: float in [-1.0, 1.0]:
			_box(self, iron, Vector3(0.24, 0.46, 0.38),
				Vector3(s * (hw + 0.20), y, z))
		if y == BAR_HI_Y:
			_bar_hi = bar
		else:
			_bar_lo = bar


func _build_lights() -> void:
	# The sigil's own lamp, close in front of the mark and short-ranged: it is
	# there to rake the ring's blocks and put a coloured pool on the timber, not
	# to light the room. Half the energy the first pass had -- at 6 it washed the
	# whole door to one flat tint and the carving vanished, which is the same
	# mistake stairs.gd's cap made.
	_sigil_lamp = OmniLight3D.new()
	_sigil_lamp.name = "SigilLamp"
	_sigil_lamp.light_color = _chilled()
	_sigil_lamp.light_energy = SIGIL_LAMP_LOCKED
	# Wide and soft rather than close and hot. At range 4.2 / energy 2.7 the lamp
	# put a blown white disc on the lock plate: the plate went brighter than the
	# stone around it, the door read as painted plastic, and the sigil stopped
	# being the coldest thing in the frame because its own backing had gone pale.
	# Pushed out to a metre and spread over seven, the same light models the
	# strapwork without a hot spot anywhere on it.
	_sigil_lamp.omni_range = 7.0
	_sigil_lamp.omni_attenuation = 1.15
	_sigil_lamp.shadow_enabled = false
	_sigil_lamp.position = Vector3(0.0, MED_Y, LEAF_T * 0.5 + 1.00)
	add_child(_sigil_lamp)

	# Behind the door, dark until it opens. Fire-coloured, so what appears in the
	# opening is WARM against the cold mark (STYLEGUIDE §1 rule 2) -- the whole
	# read of an unlocked door is that there is somewhere warm through it.
	_pass_lamp = OmniLight3D.new()
	_pass_lamp.name = "PassageLamp"
	_pass_lamp.light_color = KitStyle.FIRE_COLOR
	_pass_lamp.light_energy = 0.0
	_pass_lamp.omni_range = 9.0
	_pass_lamp.omni_attenuation = 1.3
	_pass_lamp.shadow_enabled = false
	_pass_lamp.position = Vector3(0.0, 1.75, -1.15)
	add_child(_pass_lamp)


## A stone tablet over the lintel with the door's name cut into it. MOTH while
## the door is shut and BONE once it is open, because the plate is the only part
## of the door that is still there to be read afterwards.
##
## Label3D with the engine font, which is the house pattern for a plate in the
## world (npc.gd does the same over the vendor). CanvasText is a canvas renderer
## and there is no 3D path to it; a plate is not the HUD.
func _build_plate(stone: Material) -> void:
	if label.strip_edges().is_empty():
		return
	# Bolted to the FACE of the surround, not tucked under the lintel. The first
	# build put it at the top of the opening and it vanished: a `KitDoorway`'s
	# header moulding steps 0.46 forward off the wall, so anything sitting at the
	# door's own depth is inside it. 0.55 clears the deepest surround in the kit;
	# a placer who builds a heavier one moves the whole prop forward, which is the
	# same knob.
	#
	# The height is 0.20, not the 0.62 the second pass used, and the reason is
	# perspective rather than taste. Being proud of the wall is not free: a plate
	# 0.55 m nearer the lens than the door is also 0.55 m nearer the vanishing
	# point, so from a camera at eye height it climbs the frame roughly twice as
	# fast as its world height suggests. At 0.62 it photographed at the very top
	# of the shot, detached from the doorway, reading as a UI banner painted over
	# the wall instead of a tablet bolted to a lintel. Low and proud looks bolted
	# on; high and proud looks like HUD.
	var y := opening_h + 0.20
	var z := LEAF_T * 0.5 + 0.55
	_box(self, stone, Vector3(opening_w * 0.84, 0.42, 0.13), Vector3(0.0, y, z))
	_plate = Label3D.new()
	_plate.name = "Plate"
	_plate.text = label.to_upper()
	_plate.font_size = 40
	_plate.pixel_size = 0.0022
	_plate.modulate = Pal.MOTH
	_plate.outline_size = 14
	_plate.outline_modulate = Pal.VOID
	_plate.position = Vector3(0.0, y, z + 0.085)
	add_child(_plate)


# --- Glyphs ------------------------------------------------------------------

## A mark, as rectangles in a unit square (x,y in -1..1, y up, `r` radians about
## Z), scaled by SIGIL_R and split between the leaves by the sign of x.
##
## Anything within 0.10 of the seam is dropped by the caller rather than assigned
## to a leaf, so a shape does not have to dodge x = 0 -- but the shapes below are
## still authored to cross it as few times as possible, because every crossing is
## a gap in the finished mark. A mark designed to be cut in half is a mark with
## two halves, which is also why they all read as heraldry.
static func _glyph_rects(shape: StringName) -> Array[Dictionary]:
	match shape:
		&"bow":
			# A stave curving left with its string straight down the right, drawn
			# so the tips of the stave land ON the string: circle centre (0.30, 0)
			# radius 0.72 passes through (0.30, +-0.72), which is the string's own
			# line. Without that the arc and the bar were two unrelated marks and
			# the whole thing photographed as a crescent moon.
			var bow: Array[Dictionary] = _arc(0.30, 0.0, 0.72, 90.0, 270.0, 9, 0.17)
			bow.append({"x": 0.30, "y": 0.0, "w": 0.13, "h": 1.46, "r": 0.0})
			# The grip, at the belly. Small, and the only asymmetry in the mark --
			# it is what stops a bow reading as a bracket.
			bow.append({"x": -0.40, "y": 0.0, "w": 0.20, "h": 0.42, "r": 0.0})
			return bow
		&"hook":
			# A shaft with a hook turning off the bottom of it, which is what the
			# thing on the end of the chain actually looks like.
			var hook: Array[Dictionary] = _arc(-0.10, -0.32, 0.44, 0.0, 240.0, 9, 0.13)
			hook.append({"x": 0.34, "y": 0.28, "w": 0.11, "h": 1.20, "r": 0.0})
			hook.append({"x": 0.34, "y": 0.92, "w": 0.42, "h": 0.13, "r": 0.0})
			return hook
		_:
			# A keyhole. Offset by half a step so no chord sits on the seam.
			var key: Array[Dictionary] = _arc(0.0, 0.26, 0.36, 22.5, 337.5, 8, 0.12)
			key.append({"x": -0.11, "y": -0.34, "w": 0.13, "h": 0.62, "r": 0.0})
			key.append({"x": 0.11, "y": -0.34, "w": 0.13, "h": 0.62, "r": 0.0})
			return key


## Chords of a circle, as rotated rects. `steps` chords between `a0` and `a1`
## degrees, each thick enough to overlap its neighbours so the arc is continuous
## rather than a dotted line.
static func _arc(cx: float, cy: float, r: float, a0: float, a1: float,
		steps: int, thick: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var span := deg_to_rad(a1 - a0)
	var step := span / float(maxi(steps - 1, 1))
	# 1.35x the chord length: neighbouring boxes are rotated relative to each
	# other, so a chord cut to its exact length leaves a wedge of daylight on the
	# outside of every joint.
	var w := absf(2.0 * r * sin(step * 0.5)) * 1.35 + thick * 0.35
	for i in steps:
		var a := deg_to_rad(a0) + step * float(i)
		out.append({
			"x": cx + cos(a) * r,
			"y": cy + sin(a) * r,
			"w": w,
			"h": thick,
			"r": a + PI * 0.5,
		})
	return out


# --- Small builders ----------------------------------------------------------

func _mat(albedo: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	# Everything but the iron is dead matte. The iron keeps its specular on
	# purpose: the moving highlight is the whole reason it reads as metal.
	if is_zero_approx(metal):
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


## One box. Purely decorative -- nothing built here collides, because the only
## thing on this prop that should stop the hero is `_blocker`, and a leaf with
## its own shape would still be standing in the doorway after it swung open if
## anything ever forgot to move it.
func _box(parent: Node, mat: Material, size: Vector3, at: Vector3,
		rot_z: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	if not is_zero_approx(rot_z):
		mi.rotation.z = rot_z
	parent.add_child(mi)
	return mi
