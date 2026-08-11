class_name WorldCaption
extends Node3D
## A caption **about** something in the world, anchored to a point in the world
## and drawn on the HUD canvas at native resolution.
##
## Card #61. It replaces the billboarded `Label3D` that used to do this job, and
## the reason is `docs/STYLEGUIDE.md` §4.5: the world renders into a fixed
## 480 x 270 buffer now, and a `Label3D` is world geometry wearing a glyph
## atlas, so every one of these captions went through the buffer with the walls
## and came out as a smear. `JEWELCRAFTER` over a keeper four metres away was
## about five buffer pixels of cap height — Cinzel's serifs do not survive that,
## and no amount of outline or font size fixes it without turning the caption
## into a billboard in the courtyard (§7.10, and card #61's option 2).
##
## ## Which captions live here, and which stay in the world
##
## **The tell is `billboard`.** A `Label3D` that turns to face the camera was
## never a physical object — it is interface that had been rendered in the world
## by habit, and §4.5 is what made the difference visible. Those move here:
## the keeper's name, the training post's readout and its damage numbers, the
## Echo plates over a sounding stone.
##
## Text that IS a physical object stays a `Label3D` and stays in the buffer,
## soft at distance, exactly the way a carved sign behaves: the gatehouse
## lintel's `THE SUNKEN CUT` (`scripts/world/npc.gd`), the statue's inscription
## (`scripts/props/statue.gd` — whose own comment already asks to be
## "deliberately unreadable from more than a few metres"), and the locked door's
## tablet (`scripts/props/locked_door.gd`, whose comment says a plate is not the
## HUD and means it). None of the three is billboarded. That is card #61's
## option 3, kept for the three places it is honest.
##
## ## What it costs, and it is not nothing
##
## A caption drawn on the canvas does not shrink as you back away, and it is
## occluded by a single line-of-sight ray rather than per-pixel by the depth
## buffer — a wall's edge can no longer cut a name in half, it can only take the
## whole name away. That is the same deal `Hud._draw_enemy_bars` already makes
## (`docs/STYLEGUIDE.md` §5.7, "World-anchored — these obey the world's rules,
## not the frame's"), and these captions join that table rather than inventing a
## second set of rules. The honest cost is a register change: a name over a
## keeper is now *interface about the world* and not *a thing in the world*.
##
## ## Using it
##
## Build it where you built the `Label3D`, position it the same way, and let the
## HUD find it — it puts itself in the `world_caption` group in `_ready`.
##
## [codeblock]
## var cap := WorldCaption.new()
## cap.text = "LANTERNKEEPER"
## cap.tint = Pal.BONE
## cap.position.y = _head + 0.5
## add_child(cap)
## [/codeblock]
##
## `visible` still gates it, so `cap.visible = on` keeps working for anything
## that raised and dropped a sign. `alpha` and `position` are both plain
## properties, so a `Tween` floats and fades a damage number exactly as it did
## when this was a `Label3D`.

## The group every one of these joins. `Hud._draw_world_captions` is the only
## thing that reads it.
const GROUP := &"world_caption"

## What it says. Uppercased by `CanvasText.draw_*`, like every other HUD string.
@export var text: String = ""

## The ink. `Pal.BONE` for a name, `Pal.CYAN` for an Echo, and so on — the same
## colours the `Label3D`s carried.
@export var tint: Color = Pal.BONE

## Fade, for anything that tweens out. Multiplied into both the ink and the
## plate, so a number fades as one object rather than leaving its plate behind.
@export_range(0.0, 1.0) var alpha: float = 1.0

## Size, in §3.1b's reference px at 720p. **It has to be on `Hud.TYPE_LADDER`**
## (10 / 14 / 16) — `Hud._text` pushes an error for anything else and
## `tools/directors/_hud_layout.gd` reports it. That constraint is the point of
## moving here: a caption on the canvas is HUD type and answers to the HUD's
## ladder, where a `Label3D`'s `font_size` answered to nobody.
@export var ref_px: float = 14.0

## Past this, in metres from the hero, it is not drawn at all.
##
## The same bargain `Hud.EBAR_RANGE` makes: a caption too far away to read is
## not made smaller, it is taken off the screen. 18 m is past the range anything
## in this game is captioned from and inside the yard's own width, so a name
## does not follow you out onto the plain.
@export var max_range: float = 18.0

## Metres of fade-out before `max_range`, so a caption does not pop.
##
## It is the one concession to the thing a `Label3D` did for free. A canvas
## caption cannot recede, but it can leave, and leaving over three metres of
## walking reads as distance rather than as a widget being switched off.
@export var fade_range: float = 3.0

## Is a wall between the camera and this point allowed to hide it?
##
## True is the shipped setting and the analogue of the depth test that
## `docs/STYLEGUIDE.md` §4.3 spent three cards defending. It is exported
## because `tools/directors/world_labels.gd` turns it OFF to photograph the
## defect — the same control frame it used to take by forcing `no_depth_test`
## back on. Do not ship it off; the reason is four cards long and it is in §4.3.
@export var occlude: bool = true

## Draw §5.7's World plate recipe behind the text (VOID@72%, 6 px pad).
##
## On by default and on for damage numbers too, which is a change from the
## outline the `Label3D`s carried. One rule beats a list of exceptions, and a
## plate is what §5.7 says text uses to survive a background it does not
## control — a lit sandstone wall at this end of the palette is brighter than
## MOTH, and a two-digit number in RUST on it is no more readable than a name.
@export var plate: bool = true


func _ready() -> void:
	add_to_group(GROUP)


## Opacity at `dist` metres from the hero, or 0.0 if it should not be drawn.
## Lives here rather than in the HUD so the fade rule is next to the two
## constants that set it.
func opacity_at(dist: float) -> float:
	if dist > max_range:
		return 0.0
	if fade_range <= 0.0:
		return alpha
	var t := clampf((max_range - dist) / fade_range, 0.0, 1.0)
	return alpha * t
