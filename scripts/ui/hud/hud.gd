extends CanvasLayer
## Autoload `Hud`. The in-game overlay, built to docs/STYLEGUIDE.md §5.
##
## TWO POLES. Bottom-left is YOU: the health and stamina bars and the kit strip,
## one instrument.
## Bottom-right is WHAT YOU STAND TO LOSE: the bag's rim, its value histogram,
## and the fee to leave. They sit in opposite corners deliberately -- in a panic
## your eye has to travel from "how alive am I" to "how much am I about to
## lose", and that eye movement IS the game's central decision.
##
## Note what is NOT in that corner: a gold total. It was there, 32 px and
## rolling, and it made the corner an accounting screen -- the player read the
## number instead of the room. Money is now something you go and LOOK at, in the
## pouch or over a vendor's counter. The corner still says how much is at stake;
## it no longer says it in figures. The top of the screen stays empty
## except for transient state, because the over-the-shoulder camera puts the
## action in the upper-middle third.
##
## This replaced an Ocarina-replica HUD (hearts, magic meter, N64 C-pad at
## top-right). What survived is the architecture, which was sound:
##   - autoload + a single Control that draws in `_draw`, so the overlay exists
##     whatever scene the launcher picks;
##   - coordinates as FRACTIONS of the viewport, so a resize does not relayout;
##   - repaint on signal, never per frame, EXCEPT while an animation is running;
##   - hidden unless a node in group `player` is in the tree, so lookdev and tool
##     scenes stay clean.
##
## Every colour comes from Pal and every line of text from CanvasText, which sets
## it in the display face the menus use. Nothing here uses the engine's fallback
## font -- see the anti-slop list.

const DRAW_LAYER := 50  ## under the pause menu, which sits at 100
const CivilInstrumentsScript := preload("res://scripts/ui/hud/civil_instruments.gd")

# --- Health -----------------------------------------------------------------
## OVERRIDES STYLEGUIDE §5.1, which specifies a row of discrete quarter cells.
## Changed to a bar on the owner's instruction. The styleguide's argument for
## cells was countability -- "the player needs 'three left', not 'about a fifth'"
## -- and that argument is real, so the countability is kept by other means: a
## 2px VOID tick at every heart boundary and a 1px tick at every quarter, cut
## THROUGH the fill. You can still count what is left; the fill is now
## continuous between the ticks.
##
## What is NOT taken from the bar idiom is easing. Anti-slop §7.4 bans smoothly
## lerped meters, and that ban survives intact: this bar moves instantly on
## damage and drains its ghost in the same 4 discrete steps the cells did.
## "Bar" here means the shape, not the animation.
const TICK_W := 1.0                ## quarter tick
const HEART_TICK_W := 2.0          ## heart boundary tick
## Seconds the health you just lost stays lit in RUST before draining.
const GHOST_HOLD := 0.40
const GHOST_DRAIN := 0.25

# --- Enemy health bars --------------------------------------------------------
## OVERRIDES STYLEGUIDE §5.5, which confined target health to the lock-on bracket
## and ended "Never a floating bar over every enemy." Changed on the owner's
## instruction; §5.5 is amended in the same commit rather than left contradicting
## the code.
##
## What that rule was protecting is still protected, by conditions rather than by
## absence. A bar is drawn only when all of these hold:
##
##  * **The monster is in the fight** -- engaged, or already bleeding. A room you
##    have not woken draws nothing, so darkness stays a material (docs/GDD.md §4,
##    pillar 5) and a bar is never what spoils an ambush.
##  * **Nothing is in the way.** A raycast from the CAMERA, against world geometry
##    only. This element is anchored in the world, so it obeys the world's rules --
##    the same principle the lock brackets quantize for. Without it a floating bar
##    becomes an x-ray that reads monsters through walls, which is the single worst
##    version of this feature.
##  * **It is close enough to read.** Past `EBAR_RANGE` the bar is a smear rather
##    than a readout, and a floor's worth of smears is the icon vomit the
##    styleguide is arguing against.
##
## And it never eases. Anti-slop §7.4 bans smoothly lerped meters; the fill is
## written straight from `fraction()` and rounded to whole pixels, so the only
## thing that moves is the monster.
##
## The locked target is NOT special-cased out. It draws through this same path at
## `EBAR_LOCK_MULT` width, which is how the lock keeps reading as a lock -- one
## code path, one bar per monster, emphasis carried by size. `_draw_lock_on` used
## to draw its own bar under the bracket and that duplicate is gone.
const EBAR_W := 20.0          ## reference px at Pal.REF_H, before the lock multiplier
const EBAR_H := 2.0
const EBAR_BORDER := 1.0
## The locked target's bar, as a multiple of the ordinary one. Sized to sit inside
## the bracket's 52 px span rather than to match it, so the bracket still frames
## the bar instead of the two sharing an edge.
const EBAR_LOCK_MULT := 2.2
## Metres from the hero. Deliberately shorter than the monsters' own detect range
## (11-15 m) is long, because this is a legibility limit and not a stealth one -- a
## monster chasing you from 20 m away is still visibly chasing you.
const EBAR_RANGE := 22.0
## Used when something in the `enemy` group does not implement `head_point()`.
const EBAR_FALLBACK_Y := 2.0

# --- Stamina ----------------------------------------------------------------
## Directly below health. The one fact this bar exists to carry is "can I dodge
## right now", so it turns RUST the moment it drops under one roll -- the answer
## is a colour, not a measurement you have to take.
const STAMINA_TICKS := 3           ## rolls-from-full, drawn as boundaries

# --- Heat --------------------------------------------------------------------
## Seconds the bar burns RUST after the chain steps down. The break has to be
## an EVENT -- a bar that merely gets shorter when you are hit is a bar the
## player learns about three runs later, from the wrong conclusion.
##
## Long against the block flash's 0.06 and the rim's 0.10, and deliberately so:
## those two report that something touched you, this one reports that a
## multiplier you spent nine kills building just went away. It is also the
## shortest flash tools/directors/heat_flow.gd could reliably photograph, which
## is a fair proxy for the shortest one a player will reliably notice.
const HEAT_BREAK_FLASH := 0.35

# --- Hands and item buttons (§5.2) -------------------------------------------
## Cell geometry lives in Pal now (Pal.CELL / CELL_GAP / CLUSTER_*), because the
## hands and the D-pad share one cluster and one right edge — see the note there.
##
## Half-height of a D-pad caret, in reference px. Also its half-width — they are
## drawn as equilateral-ish triangles so ← ↓ → read at a glance in a HUD that is
## 40 px tall in the corner.
##
## The band above the cells is CARET * 2 + CARET_GAP tall and every caret is
## drawn INSIDE it. The first version had them straddling the cell edges — the
## left one hung over the icon's top-left corner and the down one had its body
## behind the cell — which made a 64 px cell look like a rendering fault.
const CARET := 8.0
## The gap between a cell and the caret sitting over it.
const CARET_GAP := 5.0
## The hands, left to right as they are on the body. What is IN them comes from
## Game.armament(); this is no longer a fixed list of everything that exists.
##
## It used to be [sword, shield, hookshot, bow] -- every item, always drawn,
## whether or not the player had found it, with an underline marking which was
## out. That is a picture of the game's item table, not of the hero.
const HANDS := [&"left", &"right"]

# --- Bag (§5.3) --------------------------------------------------------------
const SLIP_H := 4.0
const SLIP_GAP := 2.0
const SLIP_MAX := 8
const SLIP_MAX_W := 0.094          ## fraction of screen
## How tall a CASE slot mark is, in reference px. A hold mark is half of it.
const SLOT_MARK_H := 8.0
## The T3 breath, in Hz. Decision 17 specified it for the 32 px gold total and
## decision 33 moved it here: a 0.5 Hz brightness lerp on a 2 px frame 209 px
## across is invisible, and the rim already has five other claimants. The slips
## are a block, so they breathe as one and you can see it.
const BREATH_HZ := 0.5
const TOAST_HOLD := 1.60
const TOAST_FADE := 0.20
const RIM_FLASH := 0.10
## **Frames, not seconds.** Everything else on this HUD is a duration because
## everything else is a fade or a drain, and those want wall-clock. This one is
## literally "two frames" — decision 17's word — and writing it as 0.034 s made
## it *frame-rate dependent in the wrong direction*: a hit arrives between one
## draw and the next, `_process` adds a whole delta before the next draw, and on
## any machine slower than 30 fps the flicker expired before it was ever painted.
## It was invisible in the harness for exactly that reason and the frame proved
## it (HUD_PLAN §15.11). Counted down in `_process`, so two draws happen at any
## frame rate. Any longer reads as a state rather than as an event.
const DAMAGE_FLICKER_FRAMES := 2

## The damage-direction arc — HUD_PLAN decisions 13, 29 and 36. It replaces
## `Feel`'s full-screen vignette, and the trade is the whole point: a red wash
## says *you were hit*, which the player already knows and which §7.10 bans
## anyway; an arc at a bearing says *from behind you, on the left*, which an
## over-the-shoulder camera cannot otherwise tell them.
##
## **`0.42h`, not §5.6's `0.28h`.** At 0.28 the arc passes through y 158–562 and
## x 438–842 — straight across the middle third that STYLEGUIDE §2 rule 1 keeps
## empty because the camera puts the fight there. That radius was authored for a
## HUD with nothing in the centre; there is a prompt and a hold gauge there now.
## 0.42h puts it near the frame edge, where a directional cue belongs, and it is
## the one radius that also threads between the vitals pole and the bag rim when
## the blow came from directly behind.
const ARC_R := 0.42               ## fraction of screen HEIGHT
const ARC_W := 3.0

## The arc at its two ends, LIGHT to KNOCKDOWN. Card #130: the screen-space half
## of "take a hit from each boss move and tell them apart with the health bar
## covered", and the only screen-space half there is going to be.
##
## **What this is instead of.** The obvious answer is a red vignette scaled by
## the blow, and it is wrong twice over. Decision 13/37 DELETED the full-screen
## wash and spent its budget on this arc (see `_draw_arc`), so re-adding one
## would be re-litigating a settled call; and §4.5's 480x270 RGB555 buffer
## quantizes colour in steps of 8/255, so a subtle wash is either invisible or a
## visible band across the frame with nothing in between. An arc is a 3 px stroke
## against VOID and survives the quantizer intact.
##
## So the arc says WEIGHT the only two ways a stroke can without getting louder:
## how much of the circle it covers, and how long it stays. Width is deliberately
## NOT one of them -- §7.10's restraint is a 3 px HUD, and a 6 px stroke on a boss
## slam is exactly the "cue fighting the fight" decision 13 threw out.
const ARC_SPAN := deg_to_rad(40.0)       ## a goblin's jab
const ARC_SPAN_MAX := deg_to_rad(96.0)   ## a slag ogre's backhand
const ARC_TIME := 0.30
const ARC_TIME_MAX := 0.55

## The autosave notice. Longer than a toast on purpose: it goes up as the world
## fades back in (game_flow.gd `_go`), so the first third of it is spent behind
## a screen that is still dark. 2.2 s leaves about a second and a half of it
## actually readable, which is what a player needs to register a word they were
## not looking for.
const SAVE_HOLD := 2.20
const SAVE_FADE := 0.35

# --- Counter-attack prompt ---------------------------------------------------
## Real-time pop duration. Perfect dodge also slows the tree, so this tween must
## ignore that scale or the acknowledgement arrives after its own reward window.
const FLURRY_POP_TIME := 0.18

# --- The floor card ----------------------------------------------------------
## How long the top-left card stays at announcement brightness after you arrive
## on a floor, and how long it takes to settle back to the resting dim. It does
## not disappear -- "which level am I on" is a question you ask between rooms,
## not once on the way in -- so this is a fade to a colour and not to nothing.
##
## The hold starts on `Bus.floor_arrived`, which is the frame the loading card
## begins lifting, so the name is continuously on screen from the transition to
## the settled HUD. Announcing on `level_changed` instead would start the clock a
## fade and a load-hold too early and the card would already be dim by the time
## the player could see it.
const FLOOR_HOLD := 2.40
const FLOOR_SETTLE := 0.90

# --- Extraction (§5.4) -------------------------------------------------------
const SWEEP_TIME := 0.20
const HOLD_TO_EXTRACT := 1.50

var _canvas: Control
## The kit icons, loaded once at `_ready` and held so a repaint is not a disk
## question. **A cache of `ArmamentDb.ICONS`, not a second list of it** —
## HUD_PLAN decision 10. This file used to spell the four paths out in its own
## `KIT_ICON`, and `ArmamentDb`'s header names that as the drift it exists to
## end. The loop that fills this walks the db's keys, so adding an armament is
## still one row in one table and the HUD needs no edit at all.
##
## Those textures are baked from the REAL item models by
## `tools/scenes/_iconbake.gd`, then posterised into the Pal ramp so they read
## as authored in-palette rather than as photographs dropped into a 5-bit HUD:
##   godot --path . res://tools/scenes/_iconbake.tscn -- --out=<abs>/assets/ui/icons/hud
##
## `icons/hud/` is GENERATED and the baker overwrites all of it. Hand-authored
## or imported art belongs in `icons/` proper -- do not put anything there you
## cannot afford to lose, and do not point the baker at `icons/` or the next
## bake eats the imported source art (it already did once, to
## hookshot_pistol.png).
var _icons: Dictionary[StringName, Texture2D] = {}
## Stamina, mirrored from Game so the bar can be redrawn without polling.
var _stamina: float = K.MAX_STAMINA
## The blue bar, mirrored the same way and off the same kind of signal. Kept as a
## local rather than read live off `Game` in `_draw` for the reason the stamina
## mirror exists: the paint is event-driven, and a value the draw pulls itself is
## a value that can change without anything asking for a repaint.
var _magic: int = K.MAX_MAGIC
var _max_magic: int = K.MAX_MAGIC

# Animation state. The HUD only runs `_process` while one of these is live --
# a HUD that repaints every frame to draw nothing is a HUD that costs a
# millisecond forever.
var _ghost_quarters: int = 0       ## cells lost, still lit in RUST
var _ghost_t: float = -1.0
## What the bag is worth. NOT drawn as a number any more (see `_draw_bag`); it
## survives because the rim's tier, the T3 breathing and the repaint budget are
## all decisions about how much is at stake, and those are still made here.
var _target_value: int = 0
var _toast: String = ""
var _toast_color: Color = Pal.MOTH
var _toast_t: float = -1.0
## The autosave notice's own clock, kept apart from the toast's so that neither
## can silently eat the other. They share a baseline (see `_draw_save`).
var _save_t: float = -1.0
## The floor card's announcement clock. -1 means settled, which is where it
## spends most of a floor.
var _floor_t: float = -1.0
var _rim_flash_t: float = -1.0
## Two frames of GOLD on the rim at the instant you are hurt (decision 17, placed
## by decision 33's ladder). Deliberately shorter than the drop flash: a drop
## landing is news, a hit is a thing you already know — you felt it in the health
## bar, which is Tier 1 and much louder.
##
## A frame COUNT, and the only clock on this HUD that is one. See
## `DAMAGE_FLICKER_FRAMES`.
var _damage_flicker: int = 0

## The live damage arc: -1 when there is none, otherwise seconds since the blow.
##
## **One arc, not three.** Decision 29 allowed up to three concurrent, each on its
## own clock, with a fourth replacing the oldest; decision 36 overturned that and
## it is right to. Three RUST strokes around the frame at the moment the player is
## being hit twice is decision 13's own objection — the cue fighting the fight —
## arriving a third time. A second blow replaces this one and restarts the clock.
var _arc_t: float = -1.0
## Camera-relative yaw of the last blow. 0 is the TOP of the circle, clockwise.
var _arc_bearing: float = 0.0
## `Hit.force` of the blow that drew it, 0..1. Set by `Bus.hero_hurt` and read by
## `_draw_arc`; see `_on_hero_hurt` for why the two signals are not one.
var _arc_force: float = 0.0

var _rim_flash_color: Color = Pal.MOTH
var _sweep_t: float = -1.0
## 0..1 while the player holds the extract button at a node.
var _extract_hold: float = 0.0
## True once the extraction toll has climbed to meet the purse, so the walk home
## will take every coin. See `set_extract_dear`.
var _extract_dear: bool = false
var _block_flash_t: float = -1.0
## Whether the flash on that clock is a PARRY rather than a block. See
## `_on_parried` -- one flag, because the two states are exclusive.
var _parry_flash: bool = false
var _lock_target: Node3D = null
## Whether anything is in the `enemy` group right now. Cached off the tree's own
## add/remove signals rather than polled, so `_process` does not walk a group every
## frame just to decide whether to repaint. See the note in `_process`.
var _enemies_present: bool = false
## Reused rather than built per monster per frame: a room holds up to seven and
## this runs at the frame rate.
var _ebar_ray := PhysicsRayQueryParameters3D.new()
## A bow or a hookshot is out, so the middle of the screen is a sight.
var _aiming: bool = false
var _last_quarters: int = -1
## Heat, mirrored from the signal. The WINDOW is not mirrored -- it drains every
## frame and is read straight off Heat when the bar draws, the same way health
## is read off Game. See the note on Heat._process.
var _heat_tier: int = 0
var _heat_kills: int = 0
var _heat_break_t: float = -1.0
## "(E) OPEN", or "" when there is nothing in reach. Owned by the Prompt autoload.
var _prompt: String = ""
## True exactly while combat's perfect-dodge reward window is available.
var _flurry_prompt: bool = false
var _flurry_scale: float = 1.0
var _flurry_tween: Tween = null
## The focused Interactable's hold, mirrored off `Bus.hold_changed`. `_required`
## is true whenever the thing in reach wants a hold AT ALL, held separately from
## the number so the empty track can be drawn before the player presses anything.
var _hold01: float = 0.0
var _hold_required: bool = false
## The kit wheel's input half; this file draws it. See `_draw_wheel`.
var _wheel: KitWheel = null
var _civil_instruments: CivilInstruments = null
var _clock_text := ""


func _ready() -> void:
	layer = DRAW_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	_canvas = Control.new()
	_canvas.name = "HudCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	# **Nearest, not linear** — STYLEGUIDE §8's `default_texture_filter=0`, taken
	# here on the HUD's own Control rather than as the project-wide setting.
	#
	# Two reasons it lands locally. `project.godot` is orchestrator-owned
	# (CONTRACT §3) and is the file `--import` silently re-serialises, dropping
	# comments and the default bus layout with them (CLAUDE.md §3); and the
	# project key governs ALL canvas textures, which is a claim about screens this
	# card has no authority over. This line is the HUD's half of the same delta and
	# nothing else's.
	#
	# It only touches TEXTURES: the baked item icons. `draw_string` rasterises its
	# own glyphs, so every piece of type on this HUD is byte-identical either way,
	# and 3D materials carry their own filter — no other session's frames move.
	# What it changes is the thing the treatment is about: the icons are baked at
	# HUD resolution by `_iconbake.gd`, so there is no minification to alias, and
	# under linear filtering their deliberate VOID dilation smeared into a halo.
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)

	# One reusable top-right stack. It sits below the canvas in draw order so the
	# kit wheel's full-screen scrim still dims every HUD instrument together.
	_civil_instruments = CivilInstrumentsScript.new()
	_civil_instruments.z_index = -1
	add_child(_civil_instruments)

	# The kit wheel's input half. A child of this layer rather than an autoload of
	# its own, because everything that hides the HUD has to hide the wheel too and
	# `_refresh_visibility` already owns that question -- a hidden CanvasLayer's
	# children get no input, so a wheel that could not be seen also cannot be
	# opened, for free and in one place.
	_wheel = KitWheel.new()
	add_child(_wheel)

	_target_value = _headline()
	_last_quarters = Game.quarters

	for id: StringName in ArmamentDb.ICONS:
		var tex := ArmamentDb.icon(id)
		if tex == null:
			push_warning("Hud: kit icon missing for '%s' — falling back to lettering" % id)
		else:
			_icons[id] = tex

	Bus.player_health_changed.connect(_on_health)
	Bus.hero_struck.connect(_on_hero_struck)
	Bus.hero_hurt.connect(_on_hero_hurt)
	Bus.stamina_changed.connect(_on_stamina)
	Bus.magic_changed.connect(_on_magic)
	Bus.bag_changed.connect(_on_bag)
	Bus.loot_gained.connect(_on_loot)
	Bus.gold_changed.connect(_on_gold)
	Bus.ammo_changed.connect(_repaint)
	Bus.loadout_changed.connect(_repaint)
	Bus.item_selected_changed.connect(_repaint)
	Clock.minute_changed.connect(_on_clock_minute)
	_on_clock_minute(Clock.day, int(Clock.hour), int(fmod(Clock.hour, 1.0) * 60.0))
	# A binding moved — on a pickup, or on the equipment screen's card. The wheel
	# is usually shut when this fires and the repaint is then a no-op; it is
	# connected anyway because the auto-bind CAN land while the wheel is open
	# (a chest opened with LB held), and a cell that filled in silently would be
	# the one moment the wheel is teaching what it is for.
	Bus.wheel_changed.connect(_repaint)
	# A bound bottle's cell draws what is IN it, so filling or draining one moves
	# the HUD without the binding changing. `_wake` rather than `_repaint` for the
	# draught: the bar it starts has to keep draining after this frame.
	Bus.bottles_changed.connect(_repaint)
	Bus.draught_changed.connect(func(_p: StringName, _s: float) -> void: _wake())
	# A meal is the same shape of thing as a draught and wakes the overlay the same
	# way: the gauge in the item cell has to keep filling for twelve seconds after
	# this edge, and `_process` keeps itself alive off `Game.eating()` until it
	# stops. `rations_changed` is a plain `_repaint` because a stack that changed
	# size only moves the numeral in the corner of a wheel glyph, which is a
	# one-frame fact.
	Bus.meal_changed.connect(func(_r: StringName, _s: float) -> void: _wake())
	Bus.rations_changed.connect(func(_stock: Dictionary) -> void: _repaint())
	# A room came out of the fog, or a chest on the plan was opened. The hero
	# ARROW does not need this -- it rides the per-frame repaint below -- but the
	# plan itself only changes on these, so the minimap is not asking `Atlas`
	# anything it has not been told.
	Bus.map_changed.connect(_repaint)
	# A full-screen UI took input, and the overlay stands down for it. See
	# `_refresh_visibility` -- these are a set and not a direct `visible` because
	# that function has the last word on this property.
	Bus.screen_opened.connect(func(id: StringName) -> void: _on_screen(id, true))
	Bus.screen_closed.connect(func(id: StringName) -> void: _on_screen(id, false))
	Bus.heat_changed.connect(_on_heat)
	Bus.heat_tier_changed.connect(_on_heat_tier)
	Bus.escape_rope_broken.connect(_on_escape_rope_broken)
	Saves.autosaved.connect(_on_autosaved)
	Bus.shield_blocked.connect(_on_blocked)
	Bus.parried.connect(_on_parried)
	Bus.perfect_dodge.connect(_on_perfect_dodge)
	Bus.target_acquired.connect(_on_target)
	Bus.target_lost.connect(_on_target_lost)
	Bus.aim_changed.connect(_on_aim)
	Bus.prompt_changed.connect(_on_prompt)
	Bus.hold_changed.connect(_on_hold)
	# Every button this overlay names is named for the device in the player's
	# hands, so picking up a pad repaints all of it: the caps and the prompt
	# (which Prompt re-emits on the same signal).
	Bus.input_device_changed.connect(func(_pad: bool) -> void: _repaint())
	Bus.level_changed.connect(func(_l: int) -> void: _repaint())
	Bus.floor_arrived.connect(_on_floor_arrived)
	Bus.run_started.connect(_on_headline_changed)
	Bus.run_ended.connect(_on_headline_changed)
	# The toll meets the purse when the purse moves or the bag moves, and on
	# nothing else -- those are exactly Run.extract_takes_all()'s two inputs.
	Bus.gold_changed.connect(func(_g: int) -> void: _refresh_extract_dear())
	Bus.bag_changed.connect(func(_b: Dictionary, _v: int) -> void: _refresh_extract_dear())
	Bus.run_started.connect(func(_s: int) -> void: _refresh_extract_dear())
	Bus.run_ended.connect(func(_e: bool, _c: Dictionary, _v: int) -> void:
		_refresh_extract_dear())

	# World geometry only, for the enemy bars' occlusion test. Bodies, not areas:
	# a doorway trigger is not a wall.
	_ebar_ray.collision_mask = K.L_WORLD
	_ebar_ray.collide_with_bodies = true
	_ebar_ray.collide_with_areas = false

	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)
	set_process(false)
	_refresh_visibility()


# --- Signals ----------------------------------------------------------------

func _repaint(_a = null, _b = null, _c = null) -> void:
	_canvas.queue_redraw()


func _on_clock_minute(day: int, hour: int, minute: int) -> void:
	_clock_text = "DAY %d  •  %s" % [day,
		SkyCycle.hour_string(float(hour) + float(minute) / 60.0)]
	_repaint()


func _on_health(quarters: int, _max_q: int) -> void:
	var lost := _last_quarters - quarters
	if lost > 0:
		# The ghost accumulates: two hits inside the hold window should show as
		# one four-cell loss, not restart at two.
		_ghost_quarters += lost
		_ghost_t = 0.0
		# The bag flickers with it, underground only: "here is what you stand to
		# lose" lands at the instant losing it becomes possible, and in the
		# garrison there is nothing at stake to remind anyone of.
		if Run != null and Run.in_dungeon:
			_damage_flicker = DAMAGE_FLICKER_FRAMES + 1
		_wake()
	elif quarters > _last_quarters:
		_ghost_quarters = 0
		_ghost_t = -1.0
	_last_quarters = quarters
	_repaint()


## What the bag is worth, always -- in the garrison as well, where it is
## normally zero.
##
## This USED to be a number in the bottom-right corner, and in the garrison it
## showed the purse instead. Both are gone. A running gold total on screen turns
## every room into an accounting screen: the player reads the number, not the
## room, and the extraction decision stops being "is this worth the walk back"
## and becomes "has the number gone up". Money is now something you go and LOOK
## at -- the pouch screen, or a vendor's counter -- which is where a decision
## about it is actually made. What stays out here is only what is at stake: the
## rim's colour, the slips, and the extraction fee beside it.
func _headline() -> int:
	if Run == null:
		return 0
	return Run.bag_value()


func _on_bag(_bag: Dictionary, _value: int) -> void:
	_target_value = _headline()
	_wake()


func _on_gold(_gold: int) -> void:
	_target_value = _headline()
	_wake()


func _on_headline_changed(_a = null, _b = null, _c = null) -> void:
	_target_value = _headline()
	_wake()


func _on_loot(item_id: StringName, _count: int) -> void:
	var def := ItemDb.get_def(item_id)
	if def == null:
		return
	_toast = def.display_name
	_toast_color = Pal.rarity_color(int(def.rarity))
	_toast_t = 0.0
	_rim_flash_color = _toast_color
	_rim_flash_t = 0.0
	_wake()


func _on_stamina(value: float, _max_s: float) -> void:
	_stamina = value
	_repaint()


func _on_magic(value: int, max_value: int) -> void:
	_magic = value
	_max_magic = max_value
	_repaint()


func _on_heat(kills: int, tier: int, _window01: float) -> void:
	_heat_kills = kills
	_heat_tier = tier
	_wake()


## Only the FALL flashes. A tier gained already announces itself -- the bar
## jumps, the multiplier changes, and the loot on the floor gets brighter -- and
## flashing both directions would make the two events the same event.
func _on_heat_tier(_tier: int, rising: bool) -> void:
	if not rising:
		_heat_break_t = 0.0
	_wake()


func _on_prompt(text: String) -> void:
	_prompt = text
	_repaint()


func _on_perfect_dodge(_position: Vector3) -> void:
	_flurry_prompt = true
	_flurry_scale = 0.72
	if _flurry_tween != null and _flurry_tween.is_valid():
		_flurry_tween.kill()
	_flurry_tween = create_tween()
	_flurry_tween.set_ignore_time_scale(true)
	_flurry_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flurry_tween.tween_property(self, "_flurry_scale", 1.0, FLURRY_POP_TIME)
	_wake()


func _clear_flurry_prompt() -> void:
	_flurry_prompt = false
	_flurry_scale = 1.0
	if _flurry_tween != null and _flurry_tween.is_valid():
		_flurry_tween.kill()
	_flurry_tween = null


## `Prompt` re-emits this every frame of a hold, so a repaint is all this needs
## -- there is no timer here to tick and nothing to keep awake between signals.
func _on_hold(t01: float, required: bool) -> void:
	_hold01 = t01
	_hold_required = required
	_repaint()


## Knocked out of the rope. Said as a toast rather than as a beep, because the
## player pressed a button in a menu and then arrived back in the world still in
## the dungeon -- without a sentence, that reads as the menu having eaten the
## input.
func _on_escape_rope_broken() -> void:
	_toast = "THE ROPE SNAPS"
	_toast_color = Pal.RUST
	_toast_t = 0.0
	_wake()


## The disk was written. `slot` is -1 when the autosave declined -- all three
## slots are full of saves a player made by hand -- and then this says NOTHING,
## which is the entire reason `Bus`-side it is a separate signal carrying a
## slot. A notice that appears whether or not anything was written is a notice
## that teaches the player to ignore it.
func _on_autosaved(slot: int) -> void:
	if slot < 0:
		return
	_save_t = 0.0
	_wake()


## You are standing on a new floor and the loading card is lifting off it. Light
## the top-left card up, and let `_process` walk it back down.
func _on_floor_arrived(_level: int) -> void:
	_floor_t = 0.0
	_wake()


func _on_blocked(_at: Vector3, _normal: Vector3) -> void:
	_block_flash_t = 0.0
	_parry_flash = false
	_wake()


## A parry rides the SAME cell and the same clock as a block, in GOLD instead of
## RUST and held four times as long.
##
## The world already carries the loud half of this cue — the burst, the freeze,
## the body going backwards (`FlourishVfx.parry`). What the HUD adds is the one
## thing the world cannot say: *that was the shield*. A player who catches a blow
## by accident and a player who caught it on purpose see the same fight from the
## outside, and the difference between rust and gold on the cell they were
## holding is where they learn which one they did.
##
## One flag over a second timer, because the two states are exclusive: a parry is
## a block that went further, and there is no frame in which both should draw.
func _on_parried(_at: Vector3, _attacker: Node) -> void:
	_block_flash_t = 0.0
	_parry_flash = true
	_wake()


func _on_target(t: Node3D) -> void:
	_lock_target = t
	_wake()


func _on_target_lost() -> void:
	_lock_target = null
	_repaint()


func _on_aim(active: bool) -> void:
	_aiming = active
	_repaint()


## "Leaving now costs everything you have."
##
## This flag has had three meanings and each one was the most useful fact about
## the way out at the time. It began as "you are standing on the rune pad"; the
## pad went and it became "you can afford the fee". That second one is gone too:
## the fee is capped at the purse (`Run.extract_charge`), so leaving is always
## affordable and a light that was always on would be no light at all.
##
## What is left is the moment worth a screen-wide sweep -- the toll climbing to
## meet your gold. From that moment on every mote you pick up is free to carry
## and the walk home costs your whole purse either way, which is a different game
## from the one you were playing a room ago and the player should be told the
## instant it changes.
##
## It is close to a one-shot per run and deliberately not guaranteed to be one.
## Nothing sells underground, so the purse cannot grow down there and the bag
## almost only gets heavier -- but `Run.consume` exists, and fletching a batch of
## arrows takes real value out of the bag. Burn enough of it and the toll drops
## back under the purse and the sweep can fire a second time when the bag climbs
## again. That is the honest answer and it is also the right one: the fact being
## announced has genuinely changed back and then changed again.
##
## Still public because tools/directors/hud_lookdev.gd forces it on to shoot the
## emphasised state.
func set_extract_dear(on: bool) -> void:
	if on == _extract_dear:
		return
	_extract_dear = on
	if on:
		_sweep_t = 0.0
	_wake()


func _refresh_extract_dear() -> void:
	set_extract_dear(Run != null and Run.extract_takes_all())


func set_extract_hold(t01: float) -> void:
	_extract_hold = clampf(t01, 0.0, 1.0)
	_repaint()


func _wake() -> void:
	set_process(true)
	_canvas.queue_redraw()


## Repaint because the wheel opened, moved a sector, or shut. Public because
## `KitWheel` is the only thing that knows when any of those happened, and it
## draws nothing itself — see that file's header for why the two halves are
## split. A plain repaint and not `_wake`: the wheel has no animation to tick,
## so a frame per input event is exactly the right number of frames.
func wake_wheel() -> void:
	_repaint()


## The wheel's input half, for a director that wants to read `sector` back rather
## than infer which way it thinks it is pointing. Named rather than left to
## `get_node("KitWheel")` so the node's path is this file's business and not
## every harness's.
func wheel() -> KitWheel:
	return _wheel


func _on_tree_changed(_n: Node) -> void:
	_refresh_visibility.call_deferred()


## Which full-screen UIs are up, by the id `Bus.screen_opened` carried. See
## `_refresh_visibility`.
##
## **A set and not a boolean, and it listens to every id and not one of them.**
## This was `_conversing`, filtered to `&"dialogue"`, and card #48 is what that
## filter cost: the Lanternkeeper's counter emits `screen_opened(&"trade")` and
## the HUD ignored it, so a shop modal shipped with the world control legend
## reading out from under its bottom edge -- RMB GUARD, SPC DODGE, D-PAD WEAPON,
## every one of them a button that does nothing while a counter has the input.
## `screen_opened`'s own docstring already said the rule ("a full-screen UI took
## or gave back input"); the HUD just was not applying it.
##
## The set matters because these nest: the stash screen opens over the trade
## screen at the smith's, and a boolean would be cleared by the inner one closing
## while the outer is still up.
var _screens: Dictionary[StringName, bool] = {}


func _on_screen(id: StringName, up: bool) -> void:
	if up:
		_screens[id] = true
	else:
		_screens.erase(id)
	_refresh_visibility()


## Gameplay scenes have a hero; lookdev boxes and tool scenes do not, and an
## overlay on a weapon rack is just noise in a contact sheet.
##
## **And no full-screen UI has the input.** The dialogue box is a strip across
## the bottom of a LIVE courtyard and it lands in the same two corners as the
## bars and the key legend. The first frame of it had "RMB GUARD | LMB DASH"
## reading out from under the panel while a dwarf introduced himself. It also
## says nothing useful there: `Prompt.blocked` has the hero's controls for the
## length of a conversation, so every button on that line is a button that does
## nothing.
##
## **Every one of them, not the dialogue box alone** -- card #48. The argument
## above was written as if the trade screen covered the HUD; it does not. It is a
## panel with a scrim on `CanvasLayer` 60, and the strip below its bottom edge is
## bare, so the whole two-row control legend read out under the Lanternkeeper's
## counter naming buttons the counter had taken. The comment that used to sit
## here said "it does not cover this the way the trade screen does" and that
## clause was the bug, in prose, for as long as the frame existed. Everything
## that emits `screen_opened` is a full-screen UI by that signal's own
## definition, and the HUD stands down for all of them: `trade`, `stash`,
## `run_end`, `dialogue`.
##
## **The legend itself is gone** (card #121) and the rule it was the evidence for
## is not. The bars, the money rim, the extraction fee and the interact prompt all
## still draw in the strip a counter's scrim does not reach, and every one of them
## names state the counter has taken. Do not read the removal as making this
## check historical.
##
## The set is the reason this is here and not a `Hud.visible = false` in each
## screen: this function runs deferred off `node_added`/`node_removed` and forces
## `visible` back to `has_player` -- and a screen's own construction is a tree
## change. Anything setting `visible` from outside is overwritten within a frame.
func _refresh_visibility() -> void:
	if not is_inside_tree():
		return
	var has_player := get_tree().get_first_node_in_group(&"player") != null
	var showing := has_player and _screens.is_empty()
	if visible != showing:
		visible = showing
		# A hidden `CanvasLayer` never calls `_draw_hud`, so nothing clears these
		# and `layout_rects()` would go on reporting the last frame the HUD DID
		# draw -- for as long as a counter is open. That is the instrument lying
		# in the one state card #48 is about, and a director asking "did the HUD
		# draw under the shop" off a stale dictionary would have got a confident
		# yes either way. Empty is what "drew nothing" looks like, and
		# `_hud_layout.check` already treats an empty layout as a failure, which
		# is the correct reading of calling it while a screen is up.
		if not showing:
			_layout.clear()
			_glyphs.clear()

	# Deferred off node_added/node_removed, which is exactly when this answer can
	# change, so the enemy bars get their frame ticker the moment a dungeon builds
	# and lose it on the last corpse. `_wake` and not just a repaint: a bar that
	# painted once and then stopped would sit at the spot the monster left.
	var had := _enemies_present
	_enemies_present = not get_tree().get_nodes_in_group(&"enemy").is_empty()
	if has_player and _enemies_present and not had:
		_wake()

	if has_player:
		_canvas.queue_redraw()


# --- Frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	var busy := false

	if _flurry_prompt:
		var combat := _hero_combat()
		if combat == null or float(combat.get(&"_flurry_t")) <= 0.0:
			_clear_flurry_prompt()
		else:
			busy = true

	if _ghost_t >= 0.0:
		_ghost_t += delta
		if _ghost_t > GHOST_HOLD + GHOST_DRAIN:
			_ghost_t = -1.0
			_ghost_quarters = 0
		else:
			busy = true

	# The damage flicker is a frame count, not a duration, so it is decremented
	# here rather than accumulated below — one draw per tick, guaranteed. It is
	# set to FRAMES + 1 because this runs BEFORE the draw it is meant to colour.
	if _damage_flicker > 0:
		_damage_flicker -= 1
		busy = true

	for t in [&"_toast_t", &"_save_t", &"_floor_t", &"_rim_flash_t", &"_sweep_t",
			&"_block_flash_t", &"_heat_break_t", &"_arc_t"]:
		var v: float = get(t)
		if v >= 0.0:
			set(t, v + delta)
			busy = true
	if _toast_t > TOAST_HOLD + TOAST_FADE:
		_toast_t = -1.0
	if _save_t > SAVE_HOLD + SAVE_FADE:
		_save_t = -1.0
	# Settling, not disappearing: past the fade the card keeps drawing at its
	# resting colour, and -1 is what tells `_draw_floor` it has got there.
	if _floor_t > FLOOR_HOLD + FLOOR_SETTLE:
		_floor_t = -1.0
	if _rim_flash_t > RIM_FLASH:
		_rim_flash_t = -1.0
	if _sweep_t > SWEEP_TIME:
		_sweep_t = -1.0
	if _arc_t > _arc_life():
		_arc_t = -1.0
	# A parry holds four times as long as a block. 0.06 s is right for "that one
	# bounced off" — it is a tick, and it is meant to be. A parry is the rarest
	# thing a player will do all fight and 0.24 s is still under a quarter second.
	if _block_flash_t > (0.24 if _parry_flash else 0.06):
		_block_flash_t = -1.0
		_parry_flash = false
	if _heat_break_t > HEAT_BREAK_FLASH:
		_heat_break_t = -1.0

	# T3 breathes, so the HUD keeps ticking while the bag is that valuable.
	if Pal.tier(_target_value) >= 3 or _lock_target != null or _extract_hold > 0.0:
		busy = true
	# A live chain is a countdown, and a countdown that only repaints on a signal
	# is a countdown that jumps. This is the one thing on the HUD that genuinely
	# wants a frame-by-frame repaint, and it stops the moment the chain is cold.
	if Heat.kills > 0:
		busy = true
	# Same argument as the chain: a draught bar is a countdown, and it drains for
	# 45 s off a single signal. Stops the moment the last one runs out.
	if not Game.draughts.is_empty():
		busy = true
	# And the meal, for the same reason at a twelfth of the length. `meal_changed`
	# fires once a TICK -- four times across twelve seconds -- so a gauge that
	# repainted only on the signal would advance in four visible jumps and read as
	# broken. This is what makes it a fill.
	if Game.eating():
		busy = true
	# The other one, and it is a deliberate widening of this file's "repaint on
	# signal, never per frame" rule. An enemy bar is pinned to a body that walks, so
	# it has to be re-projected every frame it is on screen, and there is no signal
	# for "the goblin moved".
	#
	# Gated on monsters EXISTING, not on a bar having been drawn. That is the whole
	# subtlety: gating on the bar deadlocks, because a sleeping overlay never draws,
	# never sets the flag, and so never wakes when a monster finally notices you.
	# There is no aggro signal to wake it on either. So the honest rule is the wide
	# one -- while anything is alive in here, the overlay ticks -- and the last death
	# on the floor is what puts it back to sleep.
	if _enemies_present:
		busy = true
	# The third, and the last widening this rule gets. The minimap's hero arrow
	# is pinned to a body that walks, exactly like an enemy bar, and there is no
	# "the hero moved" signal to hang it on -- so while there is a floor plan on
	# screen, the overlay ticks. It stops the moment the run ends, because
	# `Atlas` tears the plan down on `run_ended` and this goes false with it.
	if Run != null and Run.in_dungeon and Atlas != null and Atlas.has_floor():
		busy = true

	_canvas.queue_redraw()
	if not busy:
		set_process(false)


# --- The layout, exposed so a director can see a rectangle -------------------
## Key -> `{ rect: Rect2, parent: StringName }`, rebuilt by `_draw_hud` **from the
## same code that draws**. Never a second table: a hand-maintained description of
## where things are is exactly the defect this exists to catch, one level up.
##
## HUD_PLAN §11's diagnosis of why the draught row shipped on top of the magic bar
## twice is that there was *no proof that could see a rectangle* — every director
## checked numbers off `Run` and `Game`, none of which would differ if the HUD drew
## nothing at all. This is the fix, and `tools/directors/hud_pole.gd` is what reads
## it.
##
## **A tree, not a list** (decision 27). The flat version — "no permanent element
## overlaps any other" — fires on the first frame, because this HUD is full of
## *deliberate* overlap: the ammo numeral inside the hand cell, the caps plate
## under the cells, the ghost over the health bar, the slips inside the rim. The
## repair for that is an allowlist of exempt pairs, which is a second table
## describing the layout, which is the original defect in a new place. Declaring a
## parent instead makes the nesting a claim the drawing code itself makes, and
## turns one assertion into two stronger ones: siblings must not intersect, and a
## child must be inside its parent.
##
## Roots (`parent == &""`) are **synthesised as the union of their children** by
## `_seal_layout`, so a group's extent is never authored and cannot drift from
## what it contains.
var _layout: Dictionary = {}

## The world-anchored half of the same idea: see `enemy_bar_rects()` for what it
## holds and why it is a second dictionary rather than four more `_layout` entries.
var _ebars: Dictionary = {}

## The roots, and the order is only for readable failures. A group exists here iff
## something claimed it as a parent this frame — the garrison has no minimap and
## the dungeon has no floor card, and neither absence is a special case.
const LAYOUT_ROOTS: Array[StringName] = [
	&"pole", &"cluster", &"money", &"floor_card", &"minimap", &"prompt",
]


## Record the OUTERMOST rectangle an element paints — hairline, plate and all.
##
## Outermost and not the ink, deliberately (§14.5). `_draw_health` issues four
## rects; health's ink bottom is 650 and stamina's ink top is 654, but health's
## VOID hairline reaches 651 and stamina's starts at 653. Reporting the ink leaves
## 2 px of margin that is not really there, and reporting the hairline is what
## would have caught §0's collision a row earlier than it was caught.
func _note(key: StringName, parent: StringName, r: Rect2) -> void:
	if not OS.is_debug_build():
		return
	_layout[key] = {&"rect": r, &"parent": parent}


## Build each root out of what claimed it. Called once, at the end of the frame.
func _seal_layout() -> void:
	if not OS.is_debug_build():
		return
	for root in LAYOUT_ROOTS:
		var union := Rect2()
		var any := false
		for key: StringName in _layout:
			var e: Dictionary = _layout[key]
			if StringName(e[&"parent"]) != root:
				continue
			var r: Rect2 = e[&"rect"]
			union = r if not any else union.merge(r)
			any = true
		if any:
			_layout[root] = {&"rect": union, &"parent": &""}


## What the HUD drew last frame. Debug builds only — in an export `_note` is a
## single boolean test and this stays empty.
func layout_rects() -> Dictionary:
	return _layout


## Every enemy bar drawn last frame: `enemy instance_id -> Rect2` of the OUTER
## frame, hairline and all, exactly as `_note` records the furniture.
##
## **Why this exists** (cards #51 and #64). These bars are painted straight into
## the canvas, so there is no node to inspect — and `tools/directors/enemy_bars.gd`
## therefore counted them by scanning the whole frame for flat horizontal runs of
## red. That is a threshold over a photograph of a room, and the room won: the
## smith's crate stack is a 12–14 px flat orange run at (866, 350) in the garrison
## and was counted as a monster's bar in three of that director's four cases.
## Worse since §4.5 — the world is quantized to RGB555 and upscaled from 480×270,
## so *flatness*, the property that was separating the overlay from the world, is
## now a property the world has too. The instrument was less trustworthy than the
## thing it measured.
##
## So the HUD publishes what it drew, and a director asserts on **which monsters
## got a bar** instead of on how many red runs a courtyard contains. It is still
## checked photographically — the rect says where to look, and the ink inside it is
## what says the bar exists.
##
## **Deliberately not `_note`**, for the reason `_draw_arc` gives two functions up:
## a bar is anchored to a monster's head, so two monsters near each other put two
## of these on top of one another, and any of them may sit outside the safe area or
## across the minimap. `_hud_layout.check()`'s assertions — siblings do not
## intersect, everything is inside the safe area — are true of furniture and false
## of a world-anchored cue. Entering these there would turn assertion 1 into a table
## of exemptions, which is what decision 27's tree exists to avoid.
func enemy_bar_rects() -> Dictionary:
	return _ebars


# --- The type ladder (HUD_PLAN §3) --------------------------------------------
## Every size the HUD is allowed to set type at, in reference px at 720p.
## HUD_PLAN decision 2, and the argument under it is about a COUNT, not about
## these particular integers: *"a HUD with seven sizes reads as accreted rather
## than designed"*. A fourth entry is an amendment to that document, argued in
## the same breath — not a number added here because one label was awkward.
##
##   10  ammo / charge numeral, bottle count, slips +N, heat multiplier,
##       floor name
##   14  key caps, loadout line, interact prompt, autosave notice, cell lettering
##   16  floor level, item toast
const TYPE_LADDER: Array[float] = [10.0, 14.0, 16.0]

# --- The two plate recipes (HUD_PLAN decision 4.4) ----------------------------
# Two, and there were three. A plate is how text stays legible over something it
# does not control, and which plate you get is decided by ONE question: is this
# attached to a cell, or is it floating over the world?
#
# ATTACHED TO A CELL -- the key caps, the loadout line. MIDNIGHT@80% is the
# cells' own fill, so a cap reads as part of the cluster it hangs off rather than
# as a label that landed near it, and 3 px keeps the run of caps tight enough to
# scan as a row.
const PLATE_CELL := Color(Pal.MIDNIGHT, 0.8)
const PLATE_CELL_PAD := 3.0
# FREE OVER THE WORLD -- the interact prompt, the floor card. These have a lit
# wall or a torchlit floor behind them and nothing else of their own, so they get
# the darker VOID and a wider margin: 6 px is what stops a descender touching the
# brick outside the plate at 720p. The prompt used 7 px and the floor card ran
# its own 62% fade; both are on the recipe now.
const PLATE_WORLD := Color(Pal.VOID, 0.72)
const PLATE_WORLD_PAD := 6.0

# --- The world-caption de-collide (card #68) ----------------------------------
## The hairline left between two captions the pass has pushed apart, in §3.1b
## reference px.
##
## One px, and it is deliberately not more: each caption already carries
## `PLATE_WORLD_PAD` of its own on both sides, so two stacked rows are 12 px
## apart before this constant says anything. What it buys is that the two plates
## do not share an edge and read as one taller slab.
const CAPTION_STACK_GAP := 1.0

## How far a caption may be pushed off its own anchor before it is dropped
## instead, in rows.
##
## A caption is *about* the thing under it, and a name that has been walked four
## rows down the screen to find room is a name pointing at the wrong object —
## worse than no name, because it is confidently wrong. Past this the caption is
## taken off the frame, which is the same bargain `WorldCaption.max_range`
## already makes for a caption too far away to read: not shrunk, not smeared,
## removed. Three is what a cluster of four captions needs and one more than the
## sounding stone (the case card #68 was opened for) can ever ask for.
const CAPTION_STACK_MAX := 3

## Sizes this frame asked for that are not on the ladder, `ref_px -> call count`.
## Cleared per frame with `_layout`, and read by `tools/directors/_hud_layout.gd`
## as assertion 3.
var _type_offenders: Dictionary = {}


## **The one spelling for "text this many pixels tall."** HUD_PLAN decisions 3
## and 34.
##
## The same 14 px used to be written three ways — `_text(14.0)`
## in one function, `_text(14.0)` in another — and
## `Pal.px(1.0, s.y)` meant 7 px in a third. Only one of those spellings says
## what size it is, which is why the ladder was unenforceable and why nobody
## noticed the numeral was the smallest text on the screen and also the one read
## mid-fight.
##
## **Why here and not in `CanvasText.scale_for`** (decision 34): the ladder is a
## HUD rule, not a text-drawing rule. `scale_for` is also called by the loading
## card at 32 px and by the run-end tally, and an assert inside it would fail a
## shipping screen that this document has no authority over. So the check lives
## on a HUD-scoped wrapper and `scale_for` stays unguarded.
##
## It records rather than only shouting. `push_error` goes to stderr, where a
## director does not look; the offenders dictionary is what makes assertion 3 a
## countable failure in the same line as assertions 1 and 2.
func _text(ref_px: float) -> float:
	if OS.is_debug_build() and not TYPE_LADDER.has(ref_px):
		if not _type_offenders.has(ref_px):
			push_error(("Hud: text at %.1f px is not on the type ladder %s "
				+ "— HUD_PLAN decision 2") % [ref_px, TYPE_LADDER])
		_type_offenders[ref_px] = int(_type_offenders.get(ref_px, 0)) + 1
	return CanvasText.scale_for(ref_px, _canvas.size.y)


## Off-ladder sizes drawn in the last frame. Empty is the passing state.
func type_offenders() -> Dictionary:
	return _type_offenders


## Which branch each item cell's glyph took last frame: cell key -> `&"icon"`,
## `&"letters"` or `&"bottle"`. Cleared per frame with `_layout`.
##
## **Not a rect, on purpose.** The obvious way to publish this was a `_note`, and
## it cannot be one: the glyph fills the cell and `ammo_<i>` sits in the cell's
## corner *on top of it*, so two rects under the same `hand_<i>` parent would trip
## `_hud_layout`'s assertion 1a on every frame the quiver is up. Decision 27's tree
## can express "inside", not "over" — see `_draw_item_glyph`. What a director
## actually wants here is not where the glyph is but *which* of the three things
## the cell drew, and that is a name.
var _glyphs: Dictionary[StringName, StringName] = {}


## What each cell drew, from `_draw_item_glyph` itself. Card #54: `arrow` wore
## `ArmamentDb.letter()`'s "AR" because it had no bake, and nothing could say so
## without reading pixels. Debug builds only, like `layout_rects()`.
func glyph_sources() -> Dictionary:
	return _glyphs


func _draw_hud() -> void:
	var s := _canvas.size
	if s.x < 1.0 or s.y < 1.0:
		return
	_layout.clear()
	_ebars.clear()
	_type_offenders.clear()
	_glyphs.clear()
	_draw_health(s)
	_draw_stamina(s)
	_draw_magic(s)
	_draw_heat(s)
	_draw_draughts(s)
	_draw_hands(s)
	_draw_item_cell(s)
	_draw_minimap(s)
	if _civil_instruments != null:
		_note(&"civil_instruments", &"", _civil_instruments.instrument_rect())
	_draw_bag(s)
	_draw_extraction(s)
	_draw_toast(s)
	_draw_save(s)
	if _flurry_prompt:
		_draw_flurry_prompt(s)
	else:
		_draw_prompt(s)
	_draw_crosshair(s)
	_draw_lock_on(s)
	_draw_enemy_bars(s)
	_draw_world_captions(s)
	_draw_sweep(s)
	# Last of the world-facing cues and deliberately NOT `_note`d. It is a stroke
	# on a circle around the whole frame, like `_draw_sweep`'s line — an event
	# painted over everything, not an element with a place in the layout tree.
	# Decision 35 rightly says transients are checked, and it says so about the
	# prompt, which HAS a place. A 302 px arc has no parent it
	# could be a child of and no sibling it could be asked not to touch; entering
	# it would turn assertion 1 into a table of exemptions, which is exactly what
	# decision 27's tree exists to avoid. HUD_PLAN §15.13.
	_draw_arc(s)
	_draw_floor(s)
	# Last, because it is the only thing on this canvas that is MODAL — it dims
	# everything above and expects to be read instead of them, not alongside.
	_draw_wheel(s)
	_seal_layout()


# --- The kit wheel -----------------------------------------------------------
## How far each cell's CENTRE sits from the middle of the screen, in reference
## px. 132 puts the ring's outer edge at 164 px from centre — comfortably inside
## the safe area at 720p, and wide enough that the eight cells do not touch at
## `Pal.CELL`. It is a fraction of screen HEIGHT like everything else here, so it
## stays a ring rather than an ellipse on an ultrawide.
const WHEEL_R := 132.0
## What the world dims to behind it. VOID rather than black, per STYLEGUIDE §7.2,
## and 0.62 rather than the 0.4-ish a lighter overlay would use: this is the one
## overlay in the game the player is meant to LOOK at rather than through, and at
## 0.4 a torchlit dungeon wall reads straight through the empty cells.
const WHEEL_SCRIM := 0.62


## The wheel, while `KitWheel` says the button is down.
##
## **Its rectangles are `_note`d under a parent that is NOT a layout root**, and
## that is deliberate rather than an oversight. `LAYOUT_ROOTS` roots are siblings
## of each other, and `_hud_layout`'s assertion 1a fails any two siblings that
## intersect — a modal ring across the middle of the screen intersects every one
## of them by design. Leaving `wheel` off that list gets exactly the check that
## is worth having and none of the one that is not: the eight cells are compared
## against EACH OTHER (they share a parent, and two overlapping cells would be a
## real defect) and against the safe area, while nothing compares them to the
## health pole they are deliberately sitting on top of. The scrim is not noted at
## all, for the reason `_draw_arc` is not: a full-screen wash is an event painted
## over everything, not an element with a place in the tree.
func _draw_wheel(s: Vector2) -> void:
	if _wheel == null or not KitWheel.open:
		return
	var centre := s * 0.5
	var radius := Pal.px(WHEEL_R, s.y)
	var cell := Pal.px(Pal.CELL, s.y)
	var line := Pal.px(1.0, s.y)

	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(Pal.VOID, WHEEL_SCRIM))
	# The ring the cells sit on. It is what makes eight boxes read as one control
	# with a centre to point away from, rather than as a scattered grid.
	_canvas.draw_arc(centre, radius, 0.0, TAU, 64, Color(Pal.ASH, 0.8), line, true)

	var at := _wheel.sector
	for slot in Game.WHEEL_SLOTS:
		var mid := centre + KitWheel.direction_of(slot) * radius
		var r := Rect2(mid - Vector2(cell, cell) * 0.5, Vector2(cell, cell))
		var id := Game.wheel_at(slot)
		var ready := Game.wheel_ready(slot)
		var picked := slot == at

		_note(&"wheel_%d" % slot, &"wheel", r)
		_canvas.draw_rect(r, Pal.BONE if picked else Color(Pal.MIDNIGHT, 0.92))
		# An EMPTY slot draws a hairline and a filled one draws a full stroke —
		# the same one-versus-two-pixel distinction `_draw_item_cell` uses to say
		# "you have the button but not the draught". A player learns the rule once
		# and it means the same thing in both places.
		var edge := Pal.BONE if ready else Pal.ASH
		_canvas.draw_rect(r, Pal.MIDNIGHT if picked else edge, false,
			Pal.px(2.0 if id != &"" else 1.0, s.y))
		# `inverted` on the picked cell, exactly as the raised shield is: the fill
		# went BONE, so the glyph has to come back the other way or it vanishes
		# into it. Dimmed when the binding is cold — a working you have not read,
		# a bottle that was sold — because that is a slot the release will refuse
		# and the refusal has to be visible BEFORE the thumb lets go.
		_draw_item_glyph(s, r, id, &"wheel_%d" % slot, Pal.MIDNIGHT, picked,
			not ready)

	_draw_wheel_caption(s, centre, radius, at)


## The two lines under the ring: what the thumb is on, and what letting go will
## do with it.
##
## The second line is the whole of the routing, said out loud. EQUIP and SELECT
## are different words because they are different outcomes — one fills the right
## hand, the other moves what X drinks — and a player who has just bound a bottle
## next to a hookshot has no other way to learn that the wheel knows the
## difference. It is also the line that makes an empty sector honest: pointing at
## nothing says CANCEL rather than saying nothing at all.
func _draw_wheel_caption(s: Vector2, centre: Vector2, radius: float, at: int) -> void:
	var id := Game.wheel_at(at) if at >= 0 else &""
	var name_scale := _text(16.0)
	var verb_scale := _text(10.0)
	var top := centre.y + radius + Pal.px(Pal.CELL * 0.5 + 18.0, s.y)

	var label := "— nothing —" if id == &"" else _wheel_label(id)
	var verb := "RELEASE TO CANCEL"
	if id != &"":
		if not Game.wheel_ready(at):
			# A ration that has run out is the one cold slot the player can fix
			# without leaving the yard, so it says WHICH kind of not-yet it is.
			# "NOT YOURS YET" over an empty biscuit stack would be the wheel
			# claiming they never bought any.
			verb = "NONE LEFT" if RationDb.has(id) else "NOT YOURS YET"
		elif Game.bottle_index(id) >= 0 or RationDb.has(id):
			verb = "RELEASE TO SELECT"
		else:
			verb = "RELEASE TO EQUIP"

	var name_h := CanvasText.height(name_scale)
	var verb_h := CanvasText.height(verb_scale)
	var gap := Pal.px(4.0, s.y)
	# One rect for the pair. Reported together because they are one caption: two
	# entries stacked 4 px apart would be two siblings the layout check has to be
	# told are allowed to be that close.
	var w := maxf(CanvasText.width(label, name_scale),
		CanvasText.width(verb, verb_scale))
	_note(&"wheel_caption", &"wheel",
		Rect2(centre.x - w * 0.5, top, w, name_h + gap + verb_h))

	CanvasText.draw_centred(_canvas, label, Vector2(centre.x, top),
		name_scale, Pal.BONE if id != &"" else Pal.MOTH)
	CanvasText.draw_centred(_canvas, verb,
		Vector2(centre.x, top + name_h + gap), verb_scale, Pal.MOTH)


## What a wheel entry is called, asked of whichever table owns the id.
##
## A bottle's name is what is IN it, because that is what the player is reaching
## for — "Ironhide Draught" and not "Bottle 2". An empty one says so, and that
## is a real thing to want: selecting the empty bottle is how you walk to the
## alchemist knowing which glass she will fill.
func _wheel_label(id: StringName) -> String:
	var bottle := Game.bottle_index(id)
	if bottle < 0:
		# Rations included: `ArmamentDb.name_of` answers for one with its stack on
		# the end ("Hardtack x12"), which is exactly what the caption wants — this
		# is the widest text either surface draws, and how many you have left is
		# what decides whether you flick at it.
		return ArmamentDb.name_of(id)
	var potion := Game.bottle(bottle)
	return "Empty Bottle" if potion == &"" else PotionDb.name_of(potion)


## Where you are: the dungeon's name, and how far down it you have got.
##
## Top-left, and it is one card doing two jobs. On arrival it is the ANNOUNCEMENT
## -- lit, taking over from the loading card on the frame that lifts, so the
## descent has a beat that says "level 2" in the world rather than only on a
## screen you were waiting through. Then it settles and becomes the READOUT: the
## thing you glance at between rooms to decide whether to go on. A card that
## vanished after its announcement would make that a question you could not
## answer, and a card that never dimmed would make the arrival mean nothing.
##
## It used to be a dim `FLOOR n` centred on the bottom edge, sharing a baseline
## with the garrison controls legend. That was a perfectly good readout and a
## non-existent announcement: the descent's own moment was drawn in ASH, in the
## strip of screen a player looks at least, three lines under the fight.
##
## Deliberately NOT drawn in GOLD however much a title wants to be -- gold is
## currency and only currency (docs/STYLEGUIDE.md §2).
func _draw_floor(s: Vector2) -> void:
	if Run == null or not Run.in_dungeon:
		return

	# 0 while announcing, 1 once settled. The fade is on the COLOUR, not on a
	# size: a card that animated its scale would re-rasterise the face every frame.
	var settle := 1.0
	if _floor_t >= 0.0:
		settle = 0.0 if _floor_t < FLOOR_HOLD \
			else clampf((_floor_t - FLOOR_HOLD) / FLOOR_SETTLE, 0.0, 1.0)

	var at := Pal.FLOOR_ORIGIN * s
	var nt := _text(10.0)
	var lt := _text(16.0)
	# The FLOOR's name, not the shaft's (GDD §3, and `FloorDb.announced_name` for
	# why `Prog.NAME` is still the right answer over the garrison gate). The plate
	# below is measured from whichever of the two lines is wider, so a long name
	# widens the card rather than overrunning it -- "THE HUSHING CHOIR" is the
	# longest of the four and it is what this was looked at with.
	var name_line := FloorDb.announced_name(Run.level)
	var level_line := Prog.label(Run.level)
	var gap := Pal.px(5.0, s.y)
	var level_y := at.y + CanvasText.height(nt) + gap

	# The plate, and it is not decoration. This card is the only text on the HUD
	# with a LIT WALL behind it -- health and the bag sit over floor and shadow,
	# the button cluster carries its own cells -- and torchlit brick at this end
	# of the palette is brighter than MOTH. The first version had no plate and
	# the settled name was invisible from two metres back.
	#
	# It fades with the text rather than staying put, so the corner does not
	# acquire a permanent box: what is left after the announcement is a whisper
	# of shade under two lines, which is what makes the dim colours legible
	# without making the card a panel.
	var pad := Pal.px(PLATE_WORLD_PAD, s.y)
	var w: float = maxf(CanvasText.width(name_line, nt),
		CanvasText.width(level_line, lt))
	var plate := Rect2(at.x - pad, at.y - pad, w + pad * 2.0,
		level_y + CanvasText.height(lt) + pad * 2.0 - at.y)
	_note(&"floor_card", &"", plate)
	# Starts ON the shared recipe and fades to a whisper, rather than starting at
	# its own 62% -- the announcement is the one moment this card is a plate like
	# any other, and what is left afterwards is shade rather than a panel.
	_canvas.draw_rect(plate, Color(Pal.VOID, lerpf(PLATE_WORLD.a, 0.34, settle)))

	CanvasText.draw_text(_canvas, name_line, at, nt, Pal.BONE.lerp(Pal.MOTH, settle))

	# **Both lines dim** (decision 18). This used to draw the level in permanent
	# BONE, on the argument that it is the half of the card carrying information --
	# the name is a constant you only need told once -- and that a readout you have
	# to squint at is one the player stops consulting.
	#
	# The first half of that is true and is exactly why it dims. A question you ask
	# BETWEEN rooms, with a second to spare, is the definition of Tier 3, and §2
	# rule 3 reserves BONE for a Tier 3 element's announcement and never for its
	# resting state. A permanent BONE line in the top-left corner is a Tier 3
	# element wearing Tier 1's brightness, competing with the fight for the one
	# channel the fight needs.
	#
	# The second half is answered by the plate above rather than by the ink: MOTH
	# over torchlit brick is unreadable and MOTH over shade is not, and making that
	# true is what the plate was added for. It is 16 px type -- the top of the
	# ladder, twice the name's size -- so nothing about this line is a squint.
	CanvasText.draw_text(_canvas, level_line, Vector2(at.x, level_y), lt,
		Pal.BONE.lerp(Pal.MOTH, settle))


# --- Player meters -----------------------------------------------------------
## Health, stamina, magic and heat share this shell so their frame language
## cannot drift. Enemy bars are world markers only 2 px tall; putting this bezel
## on them would erase the distinction between a screen-space instrument and a
## minimal world-space warning.
func _meter_shape(r: Rect2, diagonal: float, left_diagonal: bool = true,
		right_diagonal: bool = true) -> PackedVector2Array:
	var cut := minf(diagonal, r.size.x)
	return PackedVector2Array([
		Vector2(r.position.x + (cut if left_diagonal else 0.0), r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - (cut if right_diagonal else 0.0), r.end.y),
		Vector2(r.position.x, r.end.y),
	])


## A hard one-pixel slice of a meter polygon. Keeping the band on the same
## straight side equations as the body avoids square highlights poking through
## the diagonal ends.
func _meter_band_shape(r: Rect2, diagonal: float, band_size: float, top: bool,
		left_diagonal: bool = true) -> PackedVector2Array:
	var cut := minf(diagonal, r.size.x)
	var band := minf(band_size, r.size.y)
	var y0 := 0.0 if top else r.size.y - band
	var y1 := band if top else r.size.y
	var t0 := y0 / r.size.y
	var t1 := y1 / r.size.y
	var left0 := r.position.x + (cut * (1.0 - t0) if left_diagonal else 0.0)
	var left1 := r.position.x + (cut * (1.0 - t1) if left_diagonal else 0.0)
	return PackedVector2Array([
		Vector2(left0, r.position.y + y0),
		Vector2(r.end.x - cut * t0, r.position.y + y0),
		Vector2(r.end.x - cut * t1, r.position.y + y1),
		Vector2(left1, r.position.y + y1),
	])


## Draw the built bezel and return the recessed rectangle that owns fill and
## ticks. Every layer shares one straight diagonal at each end; none of these
## polygons requests antialiasing, so the silhouette stays a hard pixel stair.
func _draw_player_meter(s: Vector2, key: StringName, rect: Rect2,
		track_color: Color, heavy: bool = false) -> Rect2:
	var bezel := Pal.px(Pal.HEALTH_METER_BEZEL if heavy else Pal.METER_BEZEL, s.y)
	var inset := Pal.px(Pal.HEALTH_METER_INSET if heavy else Pal.METER_INSET, s.y)
	var diagonal := Pal.px(
		Pal.HEALTH_METER_DIAGONAL if heavy else Pal.METER_DIAGONAL, s.y)
	var outer := rect.grow(bezel)
	var track := rect.grow(-inset)

	_note(key, &"pole", outer)
	_canvas.draw_colored_polygon(_meter_shape(outer, diagonal), Pal.VOID)
	_canvas.draw_colored_polygon(_meter_shape(rect, diagonal), Pal.ASH)
	_canvas.draw_colored_polygon(
		_meter_band_shape(rect, diagonal, Pal.px(1.0, s.y), true),
		Color(Pal.BONE, Pal.METER_FRAME_LIGHT_ALPHA))
	_canvas.draw_colored_polygon(
		_meter_band_shape(rect, diagonal, Pal.px(1.0, s.y), false), Pal.MIDNIGHT)
	_canvas.draw_colored_polygon(_meter_shape(track, diagonal), Pal.MIDNIGHT)
	_canvas.draw_colored_polygon(_meter_shape(track, diagonal), track_color)
	return track


## Fill a fraction of the recessed track. Only a segment that reaches the
## left edge starts on the track's diagonal; every visible end is diagonal too.
## A later segment underlaps that end by one diagonal, leaving its left edge flat
## beneath the current fill so a damage ghost can show through as a small wedge.
func _draw_meter_segment(s: Vector2, track: Rect2, from: float, to: float,
		color: Color, heavy: bool = false) -> void:
	var first := clampf(from, 0.0, 1.0)
	var last := clampf(to, first, 1.0)
	if last <= first:
		return
	var diagonal := Pal.px(
		Pal.HEALTH_METER_DIAGONAL if heavy else Pal.METER_DIAGONAL, s.y)
	var left_diagonal := is_zero_approx(first)
	var first_x := track.position.x + track.size.x * first
	if not left_diagonal:
		first_x = maxf(track.position.x, first_x - diagonal)
	var segment := Rect2(first_x, track.position.y,
		track.position.x + track.size.x * last - first_x, track.size.y)
	_canvas.draw_colored_polygon(
		_meter_shape(segment, diagonal, left_diagonal), color)
	_canvas.draw_colored_polygon(
		_meter_band_shape(segment, diagonal, Pal.px(1.0, s.y), true, left_diagonal),
		Color(Pal.BONE, Pal.METER_FILL_LIGHT_ALPHA))
	_canvas.draw_colored_polygon(
		_meter_band_shape(segment, diagonal, Pal.px(1.0, s.y), false, left_diagonal),
		Color(Pal.VOID, Pal.METER_FILL_SHADOW_ALPHA))


# --- Health -----------------------------------------------------------------
## A continuous bar, ticked at every quarter and more heavily at every heart, so
## "three left" is still countable without the fill being chopped into cells.
## See the note on TICK_W for why this departs from styleguide §5.1.

func _draw_health(s: Vector2) -> void:
	var total: int = maxi(Game.max_quarters, 1)
	var origin := Pal.HEALTH_ORIGIN * s
	var w := Pal.HEALTH_W * s.x
	var h := Pal.px(Pal.HEALTH_H, s.y)
	var rect := Rect2(origin.x, origin.y, w, h)

	var low := Game.quarters <= 3
	var pulse := 0.0
	if low:
		pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * 2.0)

	var track := _draw_player_meter(s, &"health", rect,
		Pal.VOID if low else Color(Pal.ASH, 0.6), true)

	var per := track.size.x / float(total)

	# The ghost sits UNDER the fill and extends past it: what you just lost.
	var ghost := _ghost_visible()
	if ghost > 0:
		_draw_meter_segment(s, track, float(Game.quarters) / float(total),
			float(Game.quarters + ghost) / float(total), Pal.RUST, true)

	# VITAL <-> VOID, and it used to be VITAL <-> BONE. Two things were wrong with
	# BONE and both are only visible in a frame: it is EXACTLY the stamina fill's
	# colour in the row 19 px below, so for half of every cycle the most urgent
	# state in the game wore another instrument's hue; and it is BRIGHTER than
	# VITAL, so the bar got lighter as the player got closer to death -- the alarm
	# running backwards. Blinking to the TRACK colour reads as the bar failing,
	# which is the sentence. Still a blink and not an ease, so §7.4 holds.
	#
	# RUST was the other candidate and it is stamina's EXHAUSTED colour, which
	# trades this collision for the same one a row down.
	var fill: Color = Pal.VITAL.lerp(Pal.VOID, pulse) if low else Pal.VITAL
	_draw_meter_segment(s, track, 0.0, float(Game.quarters) / float(total), fill, true)

	# Ticks last, cutting through fill and track alike -- that is what keeps the
	# bar countable. Heart boundaries are heavier than quarters.
	for i in range(1, total):
		var heart := i % K.HEART == 0
		var tw := Pal.px(HEART_TICK_W if heart else TICK_W, s.y)
		var th := track.size.y if heart else track.size.y * 0.45
		_canvas.draw_rect(Rect2(track.position.x + i * per - tw * 0.5,
			track.end.y - th, tw, th), Pal.VOID)


## Quarters still shown as lost. Holds, then drains right-to-left in 4 steps --
## how much you just lost is the information; the new total is secondary.
func _ghost_visible() -> int:
	if _ghost_t < 0.0 or _ghost_quarters <= 0:
		return 0
	if _ghost_t <= GHOST_HOLD:
		return _ghost_quarters
	var f := (_ghost_t - GHOST_HOLD) / GHOST_DRAIN
	var steps: float = 1.0 - floor(f * 4.0) / 4.0
	return int(ceil(_ghost_quarters * steps))


# --- Stamina ----------------------------------------------------------------
## Directly below health, sharing its left edge, deliberately shorter. Same
## instant-transition rule as health: it moves when it moves, it does not ease.

func _draw_stamina(s: Vector2) -> void:
	var origin := Pal.HEALTH_ORIGIN * s
	var top := _pole_top(s, 1)
	var w := Pal.HEALTH_W * s.x * Pal.STAMINA_RATIO
	var h := Pal.px(Pal.STAMINA_H, s.y)
	var rect := Rect2(origin.x, top, w, h)

	var track := _draw_player_meter(s, &"stamina", rect, Color(Pal.ASH, 0.6))

	var frac: float = clampf(_stamina / maxf(Game.max_stamina, 1.0), 0.0, 1.0)
	# The whole point of the bar: RUST means the dodge button does nothing.
	var spent: bool = _stamina < K.STAMINA_ROLL
	_draw_meter_segment(s, track, 0.0, frac, Pal.RUST if spent else Pal.BONE)

	# Boundaries at each roll you can still afford, so the bar reads in DODGES
	# rather than in percent -- the only unit the player spends it in.
	for i in range(1, STAMINA_TICKS + 1):
		var at := K.STAMINA_ROLL * i / maxf(Game.max_stamina, 1.0)
		if at >= 1.0:
			break
		_canvas.draw_rect(Rect2(track.position.x + track.size.x * at
			- Pal.px(1.0, s.y) * 0.5, track.position.y,
			Pal.px(1.0, s.y), track.size.y), Pal.VOID)


## The y each bar in the "you" pole starts at, so the four of them cannot drift.
##
## It used to be spelled out per bar -- health's height plus stamina's gap plus
## stamina's height plus heat's gap, written twice -- and inserting the magic bar
## between stamina and heat meant editing an expression in a function that has
## nothing to do with magic. One walk down the stack instead: add a row here and
## everything below it moves.
##
## **THIS IS THE ONLY EXPRESSION FOR THE STACK, and that is the whole of the fix
## for a defect that shipped twice.** `_draw_draughts` used to keep a second,
## hand-rolled sum of the same walk. The first version of that sum left out
## `HEALTH_H` and the row landed exactly on the stamina bar; it was repaired by
## fixing the sum rather than by deleting it, and when the magic bar was inserted
## HERE the second copy was not updated -- so the draught row went back to being
## drawn on top of the magic bar in the garrison and four pixels into the heat bar
## underground. Every check in `alchemy_loop.gd` passed both times, because none of
## them can see a rectangle.
##
## Rows: 0 health, 1 stamina, 2 magic, 3 heat, 4 draughts. In the garrison heat is
## not drawn, so the draught row asks for row **3** -- its slot -- rather than
## carrying a second arithmetic branch of its own. That is the same defect in
## miniature and it is why the garrison case is a different ARGUMENT here and not
## a different SUM somewhere else.
func _pole_top(s: Vector2, row: int) -> float:
	var y := (Pal.HEALTH_ORIGIN * s).y + Pal.px(Pal.HEALTH_H, s.y)
	if row >= 1:
		y += Pal.px(Pal.STAMINA_GAP, s.y)
	if row >= 2:
		y += Pal.px(Pal.STAMINA_H, s.y) + Pal.px(Pal.MAGIC_GAP, s.y)
	if row >= 3:
		y += Pal.px(Pal.MAGIC_H, s.y) + Pal.px(Pal.HEAT_GAP, s.y)
	if row >= 4:
		y += Pal.px(Pal.HEAT_H, s.y) + Pal.px(Pal.DRAUGHT_GAP, s.y)
	return y


# --- Magic ------------------------------------------------------------------
## Third in the "you" stack, under stamina and over heat. **The cost of the
## charged spin, and the only bar on this HUD that does not come back on its own.**
##
## It is the same instrument as stamina wearing a different colour, deliberately:
## the same left edge, the same ticks, the same "the colour IS the answer" rule.
## What differs is the question. Stamina asks "can I dodge in the next second",
## and its answer changes constantly. This asks "how much of this trip's power is
## left", and its answer only ever goes down until you go home (K.MAGIC_SPIN).
## Two bars that behave that differently must not look identical, which is what
## the blue is for.
##
## COBALT, which is also the rare-loot tier in `Pal.RARITY`. That reuse is
## deliberate and safe: rarity colour appears on item names and loot rims, never
## as a meter in the vitals pole, and COBALT is the only saturated blue the
## palette has that is not CYAN -- and CYAN is reserved for the way out
## (STYLEGUIDE §2), which a magic bar must never be mistaken for.

func _draw_magic(s: Vector2) -> void:
	if _max_magic <= 0:
		return
	var origin := Pal.HEALTH_ORIGIN * s
	var top := _pole_top(s, 2)
	var w := Pal.HEALTH_W * s.x * Pal.MAGIC_RATIO
	var h := Pal.px(Pal.MAGIC_H, s.y)
	var rect := Rect2(origin.x, top, w, h)

	var track := _draw_player_meter(s, &"magic", rect, Color(Pal.ASH, 0.6))

	var frac: float = clampf(float(_magic) / float(maxi(_max_magic, 1)), 0.0, 1.0)
	# The whole point of the bar, and the same sentence the stamina bar's RUST
	# says: dim means the trigger's hold will not light the blade. Drawn in MOTH
	# rather than RUST because this is not a danger -- you have not lost anything,
	# you have simply spent your spins, and the fight is still perfectly winnable
	# with the sword. RUST here would read as "you are about to die".
	var spent: bool = _magic < K.MAGIC_SPIN
	_draw_meter_segment(s, track, 0.0, frac, Pal.MOTH if spent else Pal.COBALT)

	# Boundaries at each spin still in the bar, so it reads in SPINS rather than
	# in percent -- the only unit it is ever spent in. Exactly the argument the
	# stamina bar's roll ticks make, and the reason both bars are ticked and the
	# heat bar is not: here the fill and the ticks measure the same quantity.
	var per := float(K.MAGIC_SPIN) / float(maxi(_max_magic, 1))
	var i := 1
	while per > 0.0 and per * float(i) < 1.0:
		_canvas.draw_rect(Rect2(track.position.x + track.size.x * per * float(i)
			- Pal.px(1.0, s.y) * 0.5, track.position.y,
			Pal.px(1.0, s.y), track.size.y), Pal.VOID)
		i += 1


# --- Heat -------------------------------------------------------------------
## Third in the "you" stack, under stamina. Two facts, one instrument:
##
##   the FILL is time  -- how much of the window is left before you drop a tier
##   the NUMBER is money -- what loot swept right now is worth
##
## They are deliberately adjacent, because the decision the bar exists to
## provoke is a trade between them: the multiplier is only worth chasing for as
## long as the fill lasts, and the fill gets SHORTER the higher the multiplier
## goes. A player who understands nothing else about heat can still read "big
## number, emptying fast" and draw the right conclusion.
##
## Dungeon only. In the garrison there is nothing to chain and the bar would be
## a third empty meter in a corner that has nothing to say.

func _draw_heat(s: Vector2) -> void:
	if Run == null or not Run.in_dungeon:
		return

	var origin := Pal.HEALTH_ORIGIN * s
	var top := _pole_top(s, 3)
	var w := Pal.HEALTH_W * s.x * Pal.HEAT_RATIO
	var h := Pal.px(Pal.HEAT_H, s.y)
	var rect := Rect2(origin.x, top, w, h)

	# The track is drawn even at zero, so the bar is a thing the player has seen
	# before the first time it matters. An instrument that only appears once you
	# are already doing well teaches nobody.
	var track := _draw_player_meter(s, &"heat", rect, Color(Pal.ASH, 0.6))

	var col := _heat_color()
	if Heat.kills > 0:
		_draw_meter_segment(s, track, 0.0, Heat.window01(), col)

	# NO TIER TICKS, deliberately, and this was tried the other way first. The
	# health and stamina bars are both ticked, so ticking this one looked like
	# consistency -- but on those two the fill and the ticks measure the SAME
	# quantity, and here they would not. The fill is time; the tier is not. Four
	# ticked segments under a nearly-full bar read as "4 of 4 tiers" at Warm,
	# which is the exact opposite of true, and the capture at h_01_tier1 showed
	# it doing precisely that. Tier is carried by the colour and by the number
	# beside it; the bar means one thing only.

	# The multiplier, right of the bar. Drawn at every tier including x1.0: the
	# number is the whole point of the meter, and hiding it until tier 1 means
	# the player meets it for the first time in the middle of a fight.
	var scale := _text(10.0)
	# String.num rather than "%.2f": it drops trailing zeros, so the ramp reads
	# X1 / X1.25 / X1.6 / X2.2 instead of a column of dead decimals.
	var label := "x" + String.num(Heat.multiplier(), 2)
	var lw := CanvasText.width(label, scale)
	var lx := origin.x + w + Pal.px(22.0, s.y)
	var ly := top + (h - CanvasText.height(scale)) * 0.5
	_note(&"heat_mult", &"pole",
		Rect2(lx - lw * 0.5, ly, lw, CanvasText.height(scale)))
	CanvasText.draw_centred(_canvas, label, Vector2(lx, ly), scale, col)


## RUST while a break is flashing, then the tier ramp: dim when cold, MOTH at
## Warm, GOLD from Hot up, breathing toward BONE at Blazing. GOLD is the money
## colour everywhere else on this HUD, and heat is money, so the bar arriving at
## gold is the game saying the same thing in the same voice.
func _heat_color() -> Color:
	if _heat_break_t >= 0.0:
		return Pal.RUST
	match _heat_tier:
		0:
			return Pal.MOTH if _heat_kills > 0 else Color(Pal.ASH, 0.8)
		1:
			return Pal.MOTH
		2:
			return Pal.GOLD
		_:
			var b := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * 1.5)
			return Pal.GOLD.lerp(Pal.BONE, b * 0.55)


# --- The hands and the item buttons (§5.2, §5.2b) ---------------------------
## Two instruments, deliberately in opposite corners. The hands sit above health
## because what he is holding is a fact about his BODY. The item buttons sit
## top-right because they are not a readout at all -- they are a picture of the
## D-pad, and a control surface belongs where the thumb is.
##
## The hands cells carry the block tell and the ammo count as well as the
## armament; that state has nowhere else to live.
##
## The glyph is a render of the ACTUAL model, baked and posterised into the Pal
## ramp. Lettering ("SW", "SH") only ever appears if a bake is missing.

## Where the two groups sit. Laid out from the cluster's LEFT edge -- shared with
## health and stamina, so the bottom-left pole hangs off one margin -- and
## UPWARDS from `Pal.CLUSTER_BOTTOM`, so adding a row pushes the cluster into the
## empty middle of the screen instead of down through the health bar.
##
## THE CLUSTER IS THREE CELLS, not six: [left hand][right hand] and one selected
## item beside them. There were four bindable D-pad cells here and the D-pad does
## not bind anything any more.
##
## THE CARET RULE, which the whole cluster reads by: a caret ABOVE a cell is the
## D-pad direction that cycles that cell. ← → over the right hand, ↓ over the
## item. Nothing else in the cluster draws a triangle, so a triangle always means
## "a direction changes this".
##
## The hands come first because that is the order they are on the body, and the
## item cell sits to their right across the wider CLUSTER_GAP.
func _hands_origin(s: Vector2) -> Vector2:
	return Vector2(Pal.CLUSTER_LEFT * s.x, _cluster_top(s))


## The item cell sits to the RIGHT of the hands pair and shares its top edge.
func _cross_origin(s: Vector2) -> Vector2:
	var cell := Pal.px(Pal.CELL, s.y)
	var gap := Pal.px(Pal.CELL_GAP, s.y)
	var hands := _hands_origin(s)
	return Vector2(
		hands.x + cell * 2.0 + gap + Pal.px(Pal.CLUSTER_GAP, s.y), hands.y)


## The top of the CELL ROW, worked back from the bottom of the whole cluster.
##
## Spelled out term by term rather than folded into one constant, for the same
## reason `_draw_draughts` spells its stack out: the rows below the cells are the
## key caps and then the loadout line, and a version of this that forgot one of
## them put the caps THROUGH the health bar. Read it against `_draw_item_cell`, which
## is where those two rows are actually drawn.
func _cluster_top(s: Vector2) -> float:
	var caps := Pal.px(Pal.KEYCAP_GAP, s.y) + CanvasText.height(
		_text(14.0))
	var loadout := Pal.px(9.0, s.y) + CanvasText.height(
		_text(14.0))
	# No allowance for the caret band above the cells, and that is not an
	# oversight. The cluster used to be pinned to the TOP of the screen, where a
	# caret drawn above a cell would have gone off the frame, so the origin had
	# to reserve CARET * 2 + CARET_GAP before anything else was placed. Growing
	# upwards from the bottom, the band extends into empty screen instead.
	return Pal.CLUSTER_BOTTOM * s.y - (caps + loadout) - Pal.px(Pal.CELL, s.y)


## The button that fires `action`, as the player would say it out loud, or "" for
## an action the device they are holding has nothing bound to.
##
## This used to be keyboard-and-mouse only, under a comment claiming a pad player
## "has the arrangement itself". They do not: the cells here are the only thing
## that says which of the four face buttons swings, and a controller in hand next
## to a cap reading LMB is the HUD lying about the game. `Glyph` answers for
## whichever device was touched last (`Settings.using_pad`).
##
## Read from the LIVE InputMap every repaint rather than from a table, because a
## table would be a second copy of the bindings and the second copy is the one
## that goes stale — see the note on `ArmamentDb.action_of`, which answers the
## other half of this question (WHICH action, as opposed to which key).
func _hotkey(action: StringName) -> String:
	return Glyph.cap(action)


## The key cap: the binding, centred under its cell. Drawn BEFORE the cell so a
## cap never lands on top of the icon it belongs to.
func _draw_keycap(s: Vector2, cell: Rect2, key: String, tag := &"") -> void:
	if key.is_empty():
		return
	var scale := _text(14.0)
	var top := cell.end.y + Pal.px(Pal.KEYCAP_GAP, s.y)
	var w := CanvasText.width(key, scale)
	var h := CanvasText.height(scale)
	var pad := Pal.px(PLATE_CELL_PAD, s.y)
	if tag != &"":
		_note(tag, &"cluster", Rect2(cell.get_center().x - w * 0.5 - pad,
			top - pad, w + pad * 2.0, h + pad * 2.0))
	# On its own plate, not bare on the scene. The cells have a MIDNIGHT fill and
	# the caps hang BELOW them, so a bare cap sits on whatever the world happens
	# to be — ASH lettering over a torchlit wall is nearly gone. It also earns the
	# metaphor: a key cap should look like a key.
	_canvas.draw_rect(Rect2(
		cell.get_center().x - w * 0.5 - pad, top - pad,
		w + pad * 2.0, h + pad * 2.0), PLATE_CELL)
	CanvasText.draw_centred(_canvas, key,
		Vector2(cell.get_center().x, top), scale, Pal.BONE)


## The hands: what he is holding, left then right. Two cells, and both of them
## can be empty -- two-handing the sword is a real choice, not a broken state.
func _draw_hands(s: Vector2) -> void:
	var cell := Pal.px(Pal.CELL, s.y)
	var gap := Pal.px(Pal.CELL_GAP, s.y)
	var origin := _hands_origin(s)
	var combat := _hero_combat()
	var blocking: bool = bool(combat.get(&"blocking")) if combat != null else false

	for i in HANDS.size():
		var hand: StringName = HANDS[i]
		var id: StringName = Game.armament(hand)
		var r := Rect2(origin.x + i * (cell + gap), origin.y, cell, cell)
		# ← → OVER THE RIGHT HAND: this is the cell D-pad ← / → step, and it is
		# the only thing on screen that says so. Without it the weapon ring is
		# invisible — a player who has found a bow has no way to learn it is one
		# press away, and the question the old bindable cross answered loudly
		# ("which direction is my bow on?") would come back as a quieter one.
		#
		# Drawn for the right hand ALWAYS, even owning nothing but the sword: a
		# ring of one is still the ring, and a caret that appears the moment you
		# pick up a bow is a control the player has to notice arriving.
		if hand == &"right":
			# Both of them live in the band ABOVE the cell, at its mid-line, so
			# neither triangle touches the icon it is describing.
			var mid := r.position.y - Pal.px(CARET_GAP + CARET, s.y)
			var cw := Pal.px(CARET, s.y)
			# The two carets are one band: they straddle the cell's own left and
			# right edges, so reported separately each would overlap the cell and
			# the other. One rect is the honest extent of the thing.
			_note(&"carets_hand", &"cluster", Rect2(
				r.position.x - cw * 2.0, mid - cw,
				r.size.x + cw * 4.0, cw * 2.0))
			_draw_caret(s, Vector2(r.position.x, mid), Vector2(-1.0, 0.0))
			_draw_caret(s, Vector2(r.end.x, mid), Vector2(1.0, 0.0))
		_draw_keycap(s, r, _hotkey(ArmamentDb.action_of(id)), &"cap_%d" % i)

		# The shield cell IS the block tell. It was the one thing the old strip
		# did that nothing else does, so it survives the strip.
		var raised := id == &"shield" and blocking
		var fill := Color(Pal.MIDNIGHT, 0.8)
		if raised:
			fill = Pal.BONE
		if id == &"shield" and _block_flash_t >= 0.0:
			fill = Pal.GOLD if _parry_flash else Pal.RUST
		_note(&"hand_%d" % i, &"cluster", r)
		_canvas.draw_rect(r, fill)
		_canvas.draw_rect(r, Pal.ASH, false, Pal.px(1.0, s.y))

		# The cell's own COUNT, if it is one. This was `id == &"arrow"` spelled
		# twice, and it is a lookup now because the Burst-Verse put a second
		# count in a hand -- charges are arrows with a different noun
		# (`docs/GDD.md` §6.5) and they belong in the same numeral, in the same
		# corner, dimming the same way when the pouch runs out. A second branch
		# drawing its own numeral is two places for the number to end up, and
		# they would not have stayed in the same one.
		#
		# `_beside`, and the other hand's id is the whole of what it adds: the BOW
		# borrows the quiver's numeral when the arrow cell is not up (#53), so
		# bow-right + shield-left -- the loadout a player actually fights in --
		# stops being the one loadout with no arrow count on screen. The rule and
		# the argument for it are on `ArmamentDb.hand_count_beside`; what matters
		# here is that this stays ONE numeral per row, which is the objection the
		# borrow had to survive and the reason it is asked as a pair.
		var other: StringName = Game.armament(&"right" if hand == &"left" else &"left")
		var counter := ArmamentDb.hand_count_beside(id, other)
		var left := Game.ammo_count(counter)
		# `Pal.VOID`, not `Color.BLACK`. It never reaches a pixel — `inverted` is
		# only true for the raised shield, where the argument is `Pal.MIDNIGHT` —
		# which is exactly what made it worth changing: a trap that is armed and
		# not fired is one an author trips later. `Pal`'s own header states the
		# law ("Never `Color.BLACK` and never `Color.WHITE`"), and the point of a
		# law like that is that `grep -r 'Color.BLACK' scripts/ui` can answer the
		# question. STYLEGUIDE §7.2.
		_draw_item_glyph(s, r, id, &"hand_%d" % i,
			Pal.MIDNIGHT if raised else Pal.VOID,
			raised, counter != &"" and left <= 0)
		if counter != &"":
			# BONE, and it was MOTH. "How many arrows do I have" is asked in the
			# middle of a fight, and MOTH is the colour §2 rule 3 reserves for the
			# things you read when you have STOPPED — the key caps, the loadout
			# line, the floor card. A Tier 2 readout wearing Tier 3's brightness is
			# the hierarchy saying one thing and the palette saying another.
			# 10 px, and it was 7 (decision 19). §2's second rule: the smallest
			# text on the screen must not be the thing you read mid-fight, and
			# "how many arrows do I have" was set three pixels under the key cap
			# that fires them.
			#
			# The corner inset is derived from the drawn height rather than from
			# a constant that happened to equal the old size plus three — that
			# constant is precisely why promoting the size would otherwise have
			# put the digits on the cell's bottom border.
			var nsc := _text(10.0)
			var nw := CanvasText.width(str(left), nsc)
			var nr := Vector2(r.end.x - Pal.px(3.0, s.y),
				r.end.y - Pal.px(3.0, s.y) - CanvasText.height(nsc))
			# Parent is the CELL, not the cluster: the numeral is deliberately
			# inside it, which is precisely the nesting a flat overlap check
			# cannot express (decision 27).
			_note(&"ammo_%d" % i, &"hand_%d" % i,
				Rect2(nr.x - nw, nr.y, nw, CanvasText.height(nsc)))
			CanvasText.draw_right(_canvas, str(left), nr, nsc, Pal.BONE)


## The selected item — ONE cell, the bottle D-pad ↓ has stepped to and X will
## drink. It replaced a four-cell bindable cross, and the cell count is the point
## rather than a side effect: the cross existed so the player could answer "which
## direction is this on", and nothing asks that any more.
##
## The same SIZE as a hand cell, after one render at 46 px against their 64. The
## smaller cell was meant to say "this is not a hand"; what it actually said was
## "this is misaligned" — tops in a line and bottoms ragged, with its key cap
## floating half a row above RMB and LMB. Three cells in a row is what a cluster
## is, and the caret over each one is what says which is which.
##
## The bottle it draws is the SELECTION, not the bottle you own most of. An empty
## bottle is drawn empty rather than skipped — you own it, you are about to fill
## it, and a ring whose length changed every time you drank would be a ring you
## could not count (Game.cycle_item).
##
## The loadout line under it is text and not a cell, because it is the only thing
## in the cluster you cannot look at and see: which of the two sets is live is a
## fact about a screen you are not on. It is named rather than marked for the
## same reason — "↑ PRIMARY" is readable cold, and a filled-vs-hollow pip is a
## convention the player has to be taught.
func _draw_item_cell(s: Vector2) -> void:
	var cell := Pal.px(Pal.CELL, s.y)
	var origin := _cross_origin(s)
	var r := Rect2(origin, Vector2(cell, cell))

	# ↓ over the cell: D-pad ↓ steps it, and the triangle POINTS AT the thing it
	# steps. The caret rule, see `_cross_origin`. It pointed up for one render,
	# which put its body behind the cell and its point out in the wall.
	var cw := Pal.px(CARET, s.y)
	var tip := Vector2(r.get_center().x, origin.y - Pal.px(CARET_GAP, s.y))
	_note(&"caret_item", &"cluster",
		Rect2(tip.x - cw, tip.y - cw * 2.0, cw * 2.0, cw * 2.0))
	_draw_caret(s, tip, Vector2(0.0, 1.0))
	# The cap is X, the button that USES it — not the direction that selects it.
	# A cell caps with the button you press to make it happen, and selecting an
	# item does not make anything happen.
	_draw_keycap(s, r, _hotkey(&"use_item"), &"cap_item")

	_note(&"item_cell", &"cluster", r)
	_canvas.draw_rect(r, Color(Pal.MIDNIGHT, 0.8))
	var potion := Game.selected_potion()
	# A RATION is a full cell, like a full bottle: the thing the border is saying
	# is "there is something here to press X on", and a stack of hardtack is. Only
	# an empty bottle gets the thin ASH rim, because it is the one state where you
	# own the button and have nothing behind it.
	var loaded := potion != &"" or Game.selected_ration() != &""
	_canvas.draw_rect(r, Pal.BONE if loaded else Pal.ASH, false,
		Pal.px(2.0 if loaded else 1.0, s.y))
	# `selected_item()` names the GLASS and `selected_potion()` what is in it.
	# The glyph wants the glass: a bottle with nothing in it still has to draw.
	_draw_item_glyph(s, r, Game.selected_item(), &"item_cell", Pal.VOID, false,
		not loaded)

	# **A meal in progress fills the cell's foot**, and it takes the numeral's turn
	# rather than sharing the corner with it.
	#
	# `HoldGauge.bar` and not a new widget: this is the same fact its docstring was
	# written for — an input that is performed correctly for most of its duration
	# and does nothing if you stop early — and its rule is that such a thing lives
	# INSIDE the box it is about. The ration is the selection (`HeroCombat._tick_dpad`
	# freezes the ring while a meal runs, precisely so that stays true), so the box
	# is this cell and the bar needs no anchor of its own.
	#
	# It is not in the draught row, and that was the first place it was tried. That
	# row is things that are true about the WORLD for a while — a ward, a burning
	# edge — and it is read at a glance while moving. A meal is the opposite: it is
	# true only as long as you are sitting still doing nothing else, and the player
	# reading it is a player with nothing to do but read it. Putting it there would
	# also have made it the fourth slot and narrowed the other three to 35 px.
	#
	# The two are mutually exclusive on purpose. "2/3" answers "are there more
	# stops on this ring", which is a question for a hand hovering over the D-pad;
	# the ring is frozen for the whole twelve seconds, so during a meal it is an
	# answer to a question nobody can act on, occupying the one strip of cell the
	# gauge wants.
	if Game.eating():
		var gline := Pal.px(2.0, s.y)
		var gh := Pal.px(HoldGauge.BAR_H, s.y)
		var gr := Rect2(r.position.x + gline, r.end.y - gline - gh,
			r.size.x - gline * 2.0, gh)
		# Noted so a director can assert the gauge REACHED THE SCREEN rather than
		# that `Game.meal_left` is counting down — those came apart once already,
		# on the arrow counter in #52.
		_note(&"meal_gauge", &"item_cell", gr)
		HoldGauge.bar(_canvas, gr, Game.meal_progress(),
			RationDb.tint_of(Game.meal_id))
	# How many stops the ring has, so the player knows there are more. Only past
	# one — "1" under a single bottle is a count of a thing nobody is counting.
	elif Game.carry_count() > 1:
		# 10 px and inset off its own height, for the reason the ammo numeral is
		# — same corner, same question, same decision 19.
		var csc := _text(10.0)
		CanvasText.draw_right(_canvas,
			"%d/%d" % [Game.item_selected + 1, Game.carry_count()],
			Vector2(r.end.x - Pal.px(3.0, s.y),
				r.end.y - Pal.px(3.0, s.y) - CanvasText.height(csc)),
			csc, Pal.MOTH)

	# The loadout, on its own row under the key caps.
	#
	# ON A PLATE, and with an ARROW the font actually has. It was "\u25b2 PRIMARY"
	# in bare ASH for one render: a solid triangle overpowers the word beside it
	# at cap height in this face, and ASH lettering laid straight
	# over a torchlit wall was barely there. Right-aligned to the cluster's edge
	# like everything else in it, so the widest word (ALTERNATE) grows leftwards
	# under the hands rather than off the screen.
	var scale := _text(14.0)
	var line := "\u2191 PRIMARY" if Game.loadout_set == Game.PRIMARY \
		else "\u2191 ALTERNATE"
	var top := r.end.y + Pal.px(Pal.KEYCAP_GAP, s.y) + CanvasText.height(scale) \
		+ Pal.px(9.0, s.y)
	var w := CanvasText.width(line, scale)
	var pad := Pal.px(PLATE_CELL_PAD, s.y)
	_note(&"loadout", &"cluster", Rect2(r.end.x - w - pad, top - pad,
		w + pad * 2.0, CanvasText.height(scale) + pad * 2.0))
	_canvas.draw_rect(Rect2(r.end.x - w - pad, top - pad,
		w + pad * 2.0, CanvasText.height(scale) + pad * 2.0), PLATE_CELL)
	CanvasText.draw_right(_canvas, line, Vector2(r.end.x, top), scale, Pal.MOTH)


# --- The minimap -------------------------------------------------------------
## Where you are on the floor, top-right, in the corner the button cluster
## vacated (see the note on Pal.CLUSTER_LEFT for why it was the one that moved).
##
## It is the same map as the pause menu's MAP screen, drawn by the same
## `MapDraw.draw_map` into a smaller box. There is exactly one map in this game
## and it is rendered at two sizes -- a corner minimap that drifted from the
## screen you open to read it properly is worse than having only one of them.
##
## **Dungeon only, and only once you have seen a room.** In the garrison there
## is no floor, and an empty frame in the corner of the garrison screen is a
## widget announcing that it has nothing to say. The frame appears with the first
## room you stand in, which is also the frame the player has a reason to look at it.
##
## The plate is opaque VOID rather than the 0.72 the prompt box uses. Everything
## else on this HUD is a mark over the world; this is a document held up in
## front of it, and a floor plan you can see torchlight through is a floor plan
## you have to work to read.
func _draw_minimap(s: Vector2) -> void:
	if Run == null or not Run.in_dungeon or Atlas == null or not Atlas.has_floor():
		return
	# Nothing at all until the first room is out of the fog. On arrival the
	# entrance is already marked seen (`Dungeon._add_room_trigger` seeds it), so
	# this is only ever true in a scene with no player in it -- which is exactly
	# where the rest of this overlay hides too.
	if Atlas.explored_count() <= 0:
		return

	var size := Pal.px(Pal.MINIMAP_SIZE, s.y)
	var frame := Rect2(
		Pal.MINIMAP_RIGHT * s.x - size, Pal.MINIMAP_TOP * s.y, size, size)
	# A root in its own right: it is a document held up in front of the world, not
	# part of either pole.
	_note(&"minimap", &"", frame)
	_canvas.draw_rect(frame, Color(Pal.VOID, 0.88))
	_canvas.draw_rect(frame, Pal.ASH, false, Pal.px(1.0, s.y))

	var pad := Pal.px(Pal.MINIMAP_PAD, s.y)
	# `follow`: the hero sits still in the middle of this one and the floor moves
	# under him. The MAP screen still fits the whole floor -- `MapDraw.FOLLOW_SPAN`
	# carries why the two want opposite things.
	MapDraw.draw_map(_canvas, frame.grow(-pad), s.y,
		get_tree().get_first_node_in_group(&"player") as Node3D, true)


## One caret, `dir` being the unit direction it points. `tip` is where the point
## lands. Drawn rather than typeset: a caret that has to point at a moving
## direction wants a rotation, not a glyph, and a "^" is not a caret.
func _draw_caret(s: Vector2, tip: Vector2, dir: Vector2) -> void:
	var w := Pal.px(CARET, s.y)
	# The back edge is perpendicular to `dir`, so one function draws all four
	# directions and none of them is a special case.
	var back := tip - dir * w * 2.0
	var side := Vector2(-dir.y, dir.x) * w
	_canvas.draw_colored_polygon(PackedVector2Array([
		back + side, back - side, tip,
	]), Pal.ASH)


## One item's icon in a cell, or its two letters if the bake is missing. An
## empty hand draws nothing at all -- an "empty" glyph is still a glyph, and the
## cell border already says the slot is there.
func _draw_item_glyph(s: Vector2, r: Rect2, id: StringName, cell: StringName,
		invert_to: Color, inverted: bool, dim: bool) -> void:
	if id == &"":
		return
	var bottle_at := Game.bottle_index(id)
	if bottle_at >= 0:
		if OS.is_debug_build():
			_glyphs[cell] = &"bottle"
		_draw_bottle_glyph(s, r, Game.bottle(bottle_at))
		return
	if RationDb.has(id):
		if OS.is_debug_build():
			_glyphs[cell] = &"ration"
		_draw_ration_glyph(s, r, id, dim)
		return
	var tex: Texture2D = _icons.get(id)
	if OS.is_debug_build():
		_glyphs[cell] = &"icon" if tex != null else &"letters"
	if tex != null:
		# Inset by 2 reference px so the icon's own VOID dilation never sits
		# on the cell border and reads as a thick frame.
		var inset := Pal.px(2.0, s.y)
		var box := Rect2(r.position + Vector2(inset, inset),
			r.size - Vector2(inset, inset) * 2.0)
		var mod := Color(1, 1, 1, 0.3 if dim else 1.0)
		if inverted:
			mod = Color(invert_to, 1.0)
		_canvas.draw_texture_rect(tex, box, false, mod)
		return
	var label_col: Color = Color(Pal.MOTH, 0.3) if dim else Pal.BONE
	if inverted:
		label_col = invert_to
	# `ArmamentDb.letter()`, not a `KIT_LABEL` of our own -- decision 10. The two
	# tables were NOT byte-for-byte identical and HUD_PLAN §14.7.2 caught it: the
	# empty-hand row was `""` here and is `"—"` in the db. That difference cannot
	# reach the screen, because the `id == &""` early return at the top of this
	# function fires first and an empty hand draws nothing at all -- but it is
	# exactly the kind of quiet disagreement that made two tables worth deleting,
	# so do not remove that early return believing this line is a safe fallback.
	CanvasText.draw_centred(_canvas, ArmamentDb.letter(id),
		Vector2(r.get_center().x, r.position.y + r.size.y * 0.32),
		_text(14.0), label_col)


## A bottle, drawn rather than baked: the glass is the same for all four and the
## only thing that differs is the colour of what is in it, which a texture would
## have to be re-baked four times to say. Neck, shoulder, body — three rects,
## and the fill rises from the bottom of the body so a full one reads as full at
## a glance from across the screen.
##
## An EMPTY bottle draws the outline and nothing inside it. That is the one cell
## state that has to be legible mid-fight: "I have the button but not the
## draught" is a different sentence from "I have no button".
func _draw_bottle_glyph(s: Vector2, r: Rect2, potion: StringName) -> void:
	var line := Pal.px(1.0, s.y)
	var w := r.size.x
	var body := Rect2(r.position.x + w * 0.28, r.position.y + w * 0.38,
		w * 0.44, w * 0.46)
	var neck := Rect2(r.position.x + w * 0.42, r.position.y + w * 0.18,
		w * 0.16, w * 0.20)
	var lip := Rect2(r.position.x + w * 0.38, r.position.y + w * 0.14,
		w * 0.24, w * 0.06)

	if potion != &"":
		var tint := PotionDb.tint_of(potion)
		# Filled to two thirds, not to the brim: a rectangle that touches its own
		# outline reads as a solid block, and the gap is what says "liquid".
		var fill := Rect2(body.position.x + line, body.position.y + body.size.y * 0.34,
			body.size.x - line * 2.0, body.size.y * 0.66 - line)
		_canvas.draw_rect(fill, tint)
		_canvas.draw_rect(neck, Color(tint, 0.55))

	var edge := Pal.BONE if potion != &"" else Pal.ASH
	_canvas.draw_rect(body, edge, false, line)
	_canvas.draw_rect(neck, edge, false, line)
	_canvas.draw_rect(lip, edge)


## A ration, drawn rather than baked, for `_draw_bottle_glyph`'s reason and one
## more: at 320x240 (`docs/STYLEGUIDE.md` §4.5) a baked biscuit and a baked cup
## are the same beige smudge, and the thing that has to survive the downscale is
## WHICH ONE THIS IS. So the two are separated by SILHOUETTE first — food is a
## squat wide block, drink is a tall narrow cup with a handle — and by tint
## second, which is the ordering §4.5 asks for everywhere.
##
## It is also the cell that has to answer "how many". The stack is drawn INSIDE
## the glyph rather than in the corner where the bottle count goes, because on a
## ration the two numbers are different questions: the corner says which stop of
## the ring you are on, and this says how many mouthfuls are left.
func _draw_ration_glyph(s: Vector2, r: Rect2, id: StringName, dim: bool) -> void:
	var line := Pal.px(1.0, s.y)
	var w := r.size.x
	var tint := RationDb.tint_of(id)
	var edge: Color = Color(Pal.MOTH, 0.3) if dim else Pal.BONE
	if dim:
		tint = Color(tint, 0.3)

	if RationDb.kind_of(id) == RationDb.HEALS:
		# The biscuit: wide, flat, and scored across the middle the way hardtack
		# is actually baked. The score line is what stops it reading as a crate.
		var slab := Rect2(r.position.x + w * 0.20, r.position.y + w * 0.34,
			w * 0.60, w * 0.34)
		_canvas.draw_rect(slab, tint)
		_canvas.draw_rect(slab, edge, false, line)
		_canvas.draw_line(Vector2(slab.get_center().x, slab.position.y + line),
			Vector2(slab.get_center().x, slab.end.y - line), edge, line)
	else:
		# The cup: tall, narrow, with a handle on the right. Filled two thirds
		# like the bottle, and for the same reason — a rectangle that touches its
		# own outline reads as a solid block rather than as something with drink
		# in it.
		var cup := Rect2(r.position.x + w * 0.28, r.position.y + w * 0.24,
			w * 0.34, w * 0.48)
		var fill := Rect2(cup.position.x + line,
			cup.position.y + cup.size.y * 0.34,
			cup.size.x - line * 2.0, cup.size.y * 0.66 - line)
		_canvas.draw_rect(fill, tint)
		_canvas.draw_rect(cup, edge, false, line)
		var handle := Rect2(cup.end.x, cup.position.y + cup.size.y * 0.24,
			w * 0.12, cup.size.y * 0.36)
		_canvas.draw_rect(handle, edge, false, line)

	# The stack, bottom-left — the opposite corner from the ring's "2/3", so the
	# two numerals can never be read as one.
	var csc := _text(10.0)
	CanvasText.draw_text(_canvas, "x%d" % Game.ration_count(id),
		Vector2(r.position.x + Pal.px(3.0, s.y),
			r.end.y - Pal.px(3.0, s.y) - CanvasText.height(csc)),
		csc, Pal.MOTH if not dim else Color(Pal.MOTH, 0.3))


## How many tiles a draught slot empties through. Four, because four is the
## largest count §7.4 sanctions where it bans a lerp — the ghost drain uses the
## same number for the same reason — and because a 73 px slot divides into four
## tiles a player can count without counting.
const DRAUGHT_TILES := 4


## The row's slots, left to right. A thing earns a slot by having a CLOCK, and
## `Game.LASTING_IDS` is the list of things that have one — this function is a
## rename of that list and nothing else, which is decision 10's argument applied
## to a smaller table.
##
## **It used to be a filter, and the filter is why #39 happened.** It walked
## `PotionDb.IDS` and kept `id == Game.DRAUGHT_PLATE_ID or id ==
## Game.DRAUGHT_EDGE_ID`, under a docstring — and a HUD_PLAN §15.1 entry — saying
## the row would grow by a slot the day a third lasting effect existed with no
## edit to this file. It could not have. The two names in that condition ARE the
## row's membership list, written here, however respectably they were spelled: a
## third brewed draught would have needed a third clause, and Ballast — which is
## not a potion and is not in `PotionDb.IDS` — could not have got in through it at
## all. See docs/HUD_PLAN.md §15.16.
func _draught_slots() -> Array[StringName]:
	return Game.LASTING_IDS


## The lasting draughts, as a fixed row of slots at the foot of the "you" pole.
##
## It shares the stamina/heat column because it is the same KIND of fact — a
## thing that is true right now and will not be shortly — and because the player
## is already watching that column when they are deciding whether to drink.
##
## ## Three things about this row are decisions and not defaults
##
## **It is drawn when it is empty.** This function used to open
## `if live.is_empty(): return`, so the row was invisible for the whole of every
## run until the first draught was drunk — and a player meets an instrument for
## the first time in the one moment they have no attention to spare for learning
## it. `_draw_heat` already carries the rule that settles this, in these words:
## *"the track is drawn even at zero, so the bar is a thing the player has seen
## before the first time it matters. An instrument that only appears once you are
## already doing well teaches nobody."* That argument was written for heat and
## applied to heat alone. It is the same argument here.
##
## **The slots are fixed by kind and never pack.** Live draughts used to be
## collected into a list and drawn leftmost-first, so a slot's POSITION carried no
## information — the first slot meant Ironhide or Emberblood depending on what
## else happened to be running at the time. Fixing them makes position the
## identity channel and colour the redundant one, which is the right way round,
## because the colours cannot carry it alone: `heart_draught`'s tint is
## `(0.88, 0.25, 0.22)` and `Pal.VITAL` is `(0.878, 0.251, 0.220)`;
## `ironhide_draught`'s is `(0.35, 0.47, 0.78)` and `Pal.COBALT` is
## `(0.345, 0.471, 0.784)`. To the precision the palette is written in, a tinted
## draught bar in this column IS the health bar's colour and the magic bar's
## colour, printed 12 px lower.
##
## **It is not a meter, and that is why it is built out of tiles.** Given the
## previous paragraph, a smoothly draining tinted bar directly under three bars
## reads as a fourth vital draining — under an Ironhide the player watches what
## looks like their magic empty. So a slot carries a MARK, which is identity and a
## shape, and four TILES that go out one at a time, which is time and a count.
## Four discrete steps is exactly what §7.4 permits where it bans a lerp, and a
## row that empties in steps is visibly not one of the bars above it.
##
## ## There are three slots, and none of them is the one the plan asked for
##
## HUD_PLAN decision 21 specifies *"slot 0 heart, slot 1 ironhide, slot 2
## emberblood, in `PotionDb.IDS` order"*. **Heart Draught has no clock.**
## `PotionDb.apply` sends it to `Game.heal()` and never to `Game.start_draught`,
## so `Game.draught_left(&"heart_draught")` is 0.0 for the entire life of the
## game and slot 0 would be a container that can never fill — a worse lie than the
## empty row it was drawn to replace.
##
## So the row is every effect that HAS a clock, and the third one is not a
## draught at all: **the Ballast-Verse** (#39), which soaks three quarters for
## eight seconds and is paid for with a bag stack. Before this it was invisible —
## the player inferred a live ward from the health bar not moving, which says a
## ward is up only after something has already hit you and never says how much is
## left. An eight-second window with that price is exactly the thing a clock is
## for.
##
## The row is `Game.LASTING_IDS` and the geometry divides by it, so the slots
## narrow from 73 px to 47 px at three. That is the cost, it was paid on purpose,
## and the tiles stay 8 px wide — countable, which is the whole requirement. See
## docs/HUD_PLAN.md §15.16 for what joining this row cost and what it did not.
func _draw_draughts(s: Vector2) -> void:
	var slots := _draught_slots()
	if slots.is_empty():
		return

	var x := Pal.HEALTH_ORIGIN.x * s.x
	var w := Pal.HEALTH_W * s.x * Pal.DRAUGHT_RATIO
	var h := Pal.px(Pal.DRAUGHT_H, s.y)
	# Row 4 underground. In the garrison heat is not drawn, so the row asks for
	# row **3** — heat's own slot — and that is an ARGUMENT rather than a second
	# sum. This function used to keep its own hand-rolled walk down the stack; it
	# left out `MAGIC_GAP + MAGIC_H` and drew this row straight through the magic
	# bar in the garrison and four pixels into the heat bar underground. See
	# `_pole_top`, which is now the only expression for the stack.
	var underground: bool = Run != null and Run.in_dungeon
	var y := _pole_top(s, 4 if underground else 3)

	var line := Pal.px(1.0, s.y)
	var gap := Pal.px(Pal.DRAUGHT_SLOT_GAP, s.y)
	var slot_w := (w - gap * float(slots.size() - 1)) / float(slots.size())
	# The whole row, hairlines included. The row and not the slots, because what
	# has to clear the heat bar above and the safe margin below is the row.
	_note(&"draughts", &"pole", Rect2(x, y, w, h).grow(line))

	for i in slots.size():
		var id: StringName = slots[i]
		var rect := Rect2(x + float(i) * (slot_w + gap), y, slot_w, h)
		# **Each slot against its OWN span**, not against a shared `K.DRAUGHT_TIME`.
		# Ballast is 8 s and a draught is 45; fed through one divisor the Ballast
		# slot would open at 8/45 — one tile of four, on a window running at full
		# strength — and be dark two seconds in. See `Game.draught_span`.
		var t01: float = clampf(
			Game.draught_left(id) / maxf(Game.draught_span(id), 0.001), 0.0, 1.0)
		# An unlit slot's mark is ASH, not a dim tint: "you are not running this"
		# and "you are nearly out of this" must not be the same picture.
		var tint: Color = _draught_tint(id) if t01 > 0.0 else Color(Pal.ASH, 0.9)
		# The slot, so a director can ask what the row actually drew rather than
		# what `Game` says is running — and, below, the LIT tiles one key each.
		# Those keys are the clock as it reached the screen: none of them means an
		# empty container, which is the state this row spends most of a run in and
		# the one #39 insisted be proved on its own.
		var slot_key := StringName("draught_%s" % id)
		_note(slot_key, &"draughts", rect.grow(line))

		# The hairline-over-track construction the rest of the pole uses, kept —
		# and it is doing MORE work here than it does up there. An empty ASH track
		# with no VOID hairline, laid over torchlit brick or over the garrison's
		# lit grass, is a smudge rather than a container, and this row has to read
		# in exactly that state for most of every run.
		_canvas.draw_rect(rect.grow(line), Pal.VOID)
		_canvas.draw_rect(rect, Color(Pal.ASH, 0.6))

		# The mark sits on its own VOID chip rather than straight on the track.
		# Drawn without one it is the same colour and about the same size as the
		# tiles beside it, and the first render came out as five blocks in a row
		# with no way to tell which was the label — the chip is what makes it read
		# as the slot's name instead of as the slot's first step.
		var chip := Rect2(rect.position, Vector2(h, h))
		_canvas.draw_rect(chip, Color(Pal.VOID, 0.85))
		_draw_draught_mark(s, chip, id, tint)

		# The tiles. `ceil`, so any time at all leaves at least one tile lit: the
		# last tile is the warning, and a draught that reached zero is a slot with
		# none, which are two different frames.
		var lit := int(ceil(t01 * float(DRAUGHT_TILES)))
		var tgap := Pal.px(2.0, s.y)
		var tx := chip.end.x + Pal.px(3.0, s.y)
		var tw := (rect.end.x - tx - tgap * float(DRAUGHT_TILES - 1)) \
			/ float(DRAUGHT_TILES)
		for t in DRAUGHT_TILES:
			var tile := Rect2(tx + float(t) * (tw + tgap), rect.position.y, tw, h)
			if t < lit:
				_note(StringName("draught_%s_lit_%d" % [id, t]), slot_key, tile)
			# A spent tile is a notch cut INTO the ash track rather than a paler
			# tile drawn on top of it, so the row reads as something emptying
			# instead of as something greying out. LIGHT, at 0.3: the first render
			# used 0.55 and an empty row — which is the row's commonest state and
			# the whole reason it is drawn at all — came out as two black bars
			# under the pole rather than as two empty containers.
			_canvas.draw_rect(tile, tint if t < lit else Color(Pal.VOID, 0.3))


## A slot's lit colour. `PotionDb.tint_of` for the two that come out of a bottle,
## and one line here for the one that does not.
##
## **This function is the honest half of #39.** `_draught_slots` now derives
## membership from `Game.LASTING_IDS` with no per-id knowledge at all, so a fourth
## lasting effect joins the row for free — but it cannot be DRAWN for free, and
## this is where that shows. A slot needs a hue and a mark, both are decisions
## nobody outside this file is qualified to make, and `PotionDb` is the wrong
## place to keep a colour for something that is not in a bottle. HUD_PLAN §15.1's
## claim that the row grows "with no edit to `hud.gd`" was wrong about this even
## before Ballast existed; §15.16 records it.
##
## ARCANE, out of the four saturated hues the palette has: CYAN is reserved for
## the way out and GOLD for money (STYLEGUIDE §2), COBALT is the magic bar
## directly above this row AND Ironhide's own tint two slots to the left, and MOSS
## against Emberblood's orange next door is the one deutan-confusable pair the row
## could still have made. Purple is also the only hue on the pole that is not a
## vital, which is right for the one slot that is not a potion.
func _draught_tint(id: StringName) -> Color:
	return Pal.ARCANE if id == Game.BALLAST_ID else PotionDb.tint_of(id)


## A slot's identity, as a shape. Three are drawn today and the fourth case is the
## fallback, kept because `_draught_slots` will hand this function any id that
## `Game.LASTING_IDS` grows by and a mark that is already there is one fewer thing
## to remember.
##
## Shapes rather than hues, because the hues are already spoken for by the bars
## directly above this row — see the note on `_draw_draughts`. They are chosen for
## separation at SIX PIXELS and not for iconography: a heart outline at 6 px is a
## blob, and the honest reduction of "soak" and "edge" is a solid plate against a
## point. HUD_PLAN decision 30 asks for "a heart outline, a hide chevron, a
## flame"; this is that decision at the size it actually renders, recorded in §15.
func _draw_draught_mark(s: Vector2, box: Rect2, id: StringName, col: Color) -> void:
	# Inset so the mark never touches the slot's own VOID hairline, which would
	# make a 6 px slot read as a solid block with a bite out of it.
	var r := box.grow(-Pal.px(1.0, s.y))
	match id:
		&"ironhide_draught":
			# A plate. Solid, square, nothing sticking out of it — the shape of
			# something that stops arguing with what hits it.
			_canvas.draw_rect(r, col)
		&"emberblood_draught":
			# A point: the flame, and equally the edge it is put on. The only
			# thing in the row with a diagonal in it.
			_canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(r.get_center().x, r.position.y),
				Vector2(r.end.x, r.end.y),
				Vector2(r.position.x, r.end.y),
			]), col)
		&"ballast":
			# A weight, sitting on the floor of the chip. The only mark in the row
			# whose mass is off-centre, which is what separates it from Ironhide's
			# plate at six pixels — a plate fills, this one sinks — and the honest
			# reduction of a working whose whole idea is that you put something
			# heavy on. Half height rather than a third: at 6 px a third is 2 px
			# and 2 px of ARCANE on a VOID chip is a smudge, not a shape.
			_canvas.draw_rect(Rect2(r.position.x, r.get_center().y,
				r.size.x, r.size.y * 0.5), col)
		_:
			# The cross, for a Heart Draught that has been given a clock. Two
			# rects, and the only mark in the row with a hole in its silhouette.
			var t := maxf(Pal.px(2.0, s.y), 1.0)
			_canvas.draw_rect(Rect2(r.get_center().x - t * 0.5, r.position.y,
				t, r.size.y), col)
			_canvas.draw_rect(Rect2(r.position.x, r.get_center().y - t * 0.5,
				r.size.x, t), col)


func _hero_combat() -> Node:
	var hero := get_tree().get_first_node_in_group(&"player")
	return hero.get(&"combat") if hero != null else null


# --- The bag (§5.3) ---------------------------------------------------------
## What you are carrying, said WITHOUT a number: the rim's colour and the value
## histogram. There is no figure left in this corner at all -- the extraction
## line under it went the same way and for the same reason (§5.4).
##
## There used to be a 32 px gold total here, rolling up on every pickup, and it
## was the most-read thing on the screen. That is the problem with it. A player
## watching a running total is doing bookkeeping in the middle of a dungeon, and
## the extraction decision degrades from "is this worth the walk back" into "has
## the number gone up". The information did not go away -- it moved to the pouch
## and the vendor's counter, which is where you go to think about money.
##
## What survives is the part that is about RISK rather than arithmetic: the rim
## says how rare the best thing in the bag is, the slips say whether your money
## is one stack or eight, and neither is a figure you can read while running.
func _draw_bag(s: Vector2) -> void:
	var tl := Pal.RIM_TL * s
	var br := Pal.RIM_BR * s
	var rim := Rect2(tl, br - tl)
	_draw_rim(s, Pal.tier(_target_value))
	_draw_slips(s, rim)


## A value histogram, not an inventory list. Slip width is that stack's share of
## the bag's worth, so the useful thought -- "most of my money is that one violet
## slip" -- is available at a glance, which no list gives you. With the total
## gone this is the only reading of the bag left out here, and it is deliberately
## a shape and not a figure.
func _draw_slips(s: Vector2, rim: Rect2) -> void:
	var total := Run.bag_value()
	if total <= 0:
		return

	var entries: Array = []
	for id: StringName in Run.bag:
		var def := ItemDb.get_def(id)
		if def == null:
			continue
		entries.append({
			"v": def.value * int(Run.bag[id]),
			"c": Pal.rarity_color(int(def.rarity)),
			"r": int(def.rarity),
		})
	entries.sort_custom(func(a, b): return a["v"] > b["v"])

	var h := Pal.px(SLIP_H, s.y)
	var gap := Pal.px(SLIP_GAP, s.y)
	# **Derived from the rim, not authored beside it** — HUD_PLAN §15.5. This was
	# `Pal.SLIPS_BOTTOM`, a constant on the same page of the anchor table as the
	# rim's own and fitting it only by coincidence: the stack grows UPWARD, so its
	# height is a function of how many stacks are in the bag while the rim's top
	# was a constant, and at eight stacks the top slip cleared the rim's top frame
	# by 3.5 px. §14.5 claims the tree resolves this case and it does not.
	#
	# The fix is the move `_pole_top` already makes for the vitals column: one
	# expression owns where a thing sits and nothing else gets an opinion. The
	# floor is the slot-mark row's top, so the slips now sit ON the marks rather
	# than floating in the middle of an empty box.
	# The T3 breath (decision 17, relocated by decision 33). A 0.5 Hz brightness
	# lerp, on the whole stack rather than on the rim's 2 px frame where it was
	# invisible. It is the one Tier 3 element allowed to move, and it moves only
	# at T3 — "you are carrying more than you can afford to lose" is the sentence,
	# and it should not be sayable at any other time.
	var breath := 0.0
	if Pal.tier(_target_value) >= 3:
		breath = 0.10 * (0.5 + 0.5 * sin(
			Time.get_ticks_msec() * 0.001 * TAU * BREATH_HZ))
		# No `_wake()` here. `_process` already holds `busy` while the tier is 3
		# ("T3 breathes, so the HUD keeps ticking"), and calling `queue_redraw`
		# from inside `_draw` to drive an animation is how a paint loop turns into
		# a spin loop that nothing can switch off.
	var frame := Pal.px(3.0, s.y)
	var inner := rim.grow(-(frame + Pal.px(4.0, s.y)))
	var right := inner.end.x
	var max_w: float = minf(SLIP_MAX_W * s.x, inner.size.x)
	var y := inner.end.y - Pal.px(SLOT_MARK_H, s.y) - gap

	# Normalised to the LARGEST stack, not to the bag total. Against the total,
	# eight roughly-even stacks each render as a 14 px stub and the histogram
	# says nothing; against the largest, the top slip is always full width and
	# the rest read as fractions of it -- which is the comparison the player
	# actually makes ("is that one purple slip most of my money?").
	var top_v: float = maxf(1.0, float(entries[0]["v"]))

	for i in mini(entries.size(), SLIP_MAX):
		var e: Dictionary = entries[i]
		var w: float = maxf(Pal.px(3.0, s.y), max_w * (float(e["v"]) / top_v))
		var slip := Rect2(right - w, y - h, w, h)
		_canvas.draw_rect(slip, (e["c"] as Color).lightened(breath))
		# Rarity's second channel, matching the rim's (see `_draw_rim`): 0-3
		# hairline notches cut into the LEFT end, which is the end that moves, so
		# they never sit under the right edge every slip shares. Common gets none
		# — the absence is itself the reading, and it is the commonest case.
		var notches: int = clampi(int(e["r"]), 0, 3)
		for n in notches:
			_canvas.draw_rect(Rect2(slip.position.x + float(n) * Pal.px(2.0, s.y),
				slip.position.y, Pal.px(1.0, s.y), h), Pal.VOID)
		y -= h + gap

	if entries.size() > SLIP_MAX:
		# 10 px, decision 19. "+4" is the only thing on this stack that says how
		# much of the bag you cannot see, so it is not the place for the smallest
		# type on the screen.
		var osc := _text(10.0)
		CanvasText.draw_right(_canvas, "+%d" % (entries.size() - SLIP_MAX),
			Vector2(right, y - Pal.px(8.0, s.y)), osc, Pal.MOTH)
		y -= Pal.px(8.0, s.y) + CanvasText.height(osc)

	# The stack, as one rectangle. Parent is the RIM, and now it genuinely is
	# inside it in every state — the assertion that used to fail at eight stacks
	# is the proof, not the comment.
	_note(&"slips", &"rim", Rect2(right - max_w, y,
		max_w, inner.end.y - Pal.px(SLOT_MARK_H, s.y) - gap - y))


## The rim's NON-HUE channel, as (frame thickness in reference px, ornament).
## Ornament is 0 none, 1 an inner rule, 2 a dithered inner ring.
##
## Exists so that `_draw_rim` and `_hud_layout.check_contrast` read one ladder
## rather than two. Assertion 4's whole job is to catch a rarity pair that is
## separable by hue alone, and a hand-copied table of "what the thicknesses are"
## in the checker would let someone flatten the ladder in the drawing code and
## still pass -- which is decision 27's argument about `layout_rects()`, applied
## to the one property of this widget that is not a rectangle.
static func rarity_weight(rarity: int) -> Vector2i:
	var r := clampi(rarity, 0, 3)
	# thickness: common and uncommon 2 px, rare and legendary 3 px.
	# ornament: uncommon takes the inner rule, legendary the dithered ring.
	return Vector2i(3 if r >= 2 else 2, 1 if r == 1 else (2 if r >= 3 else 0))


## Coloured by the rarity of the single most valuable thing you carry. Silent,
## permanent, peripheral -- it is how the bag whispers.
##
## **And it is not coloured ONLY.** The rim's entire information content used to
## be its hue. This comment used to name `MOSS` against `MOTH` as the hardest pair
## -- mid-green against mid-khaki, the textbook deutan collision -- and decision
## 32's assertion 4 then went and MEASURED all six pairs through a Brettel
## deuteranope simulation. MOSS/MOTH was never the problem. It separates by 30%:
##
##   common vs uncommon    30.1%      uncommon vs rare        30.2%
##   common vs rare       ** 0.1% **  uncommon vs legendary   15.4%
##   common vs legendary   17.4%      rare vs legendary       17.5%
##
## The collision is `MOTH` (`807868`) against `COBALT` (`5878c8`) — khaki against
## blue, one part in a thousand of luminance apart to a deuteranope, which means a
## colour-blind player cannot tell *I am carrying junk* from *I am carrying
## something rare*. That is the single worst thing this corner could get wrong,
## and the comment that was here confidently pointed at the wrong pair.
##
## So rarity is a THICKNESS as well: 2 px common, 2 px with an inner rule
## uncommon, 3 px rare, 3 px with a dithered ring legendary. Four weights, four
## hues, either channel sufficient -- and it is `rarity_weight` below rather than
## a literal here, so the assertion can read the same ladder the drawing does
## instead of describing it a second time.
##
## The vocabulary is not new — the T2 value halo below is the same dither, and
## that is the argument for reusing it rather than inventing a second language for
## the second thing this rectangle has to say.
func _draw_rim(s: Vector2, tier: int) -> void:
	var tl := Pal.RIM_TL * s
	var br := Pal.RIM_BR * s
	var r := Rect2(tl, br - tl)
	var rarity := _best_rarity()
	var col := Pal.rarity_color(rarity)
	# The T2 halo sits 2 px outboard of the frame, so the rim's outermost extent
	# is the grown rect and not `r` — §14.5's "report the ink and you have margin
	# that is not really there".
	_note(&"rim", &"money", r.grow(Pal.px(2.0, s.y)))

	# **The precedence ladder** (decision 33). Six things want this one rectangle:
	# the hold, the drop flash, the damage flicker, the T3 breath, the T2 halo and
	# rarity. At T3, holding to extract, with a legendary in the bag, taking a hit
	# as a drop lands, all six are true at once and nothing used to arbitrate — so
	# the CYAN hold lost, because it is the only one driven by an animation clock
	# rather than by state, and it is the only one that is a live response to a
	# button the player is holding down.
	#
	#   hold > drop flash > damage flicker > T3 breath > T2 halo > rarity
	#
	# The hold suppresses everything below it for its whole duration. It is drawn
	# by `_draw_extraction` onto this same rect, so all this branch does is get
	# out of its way: a halo and a rarity ring under a CYAN sweep are what made
	# the sweep unreadable.
	var holding := Run.in_dungeon and _extract_hold > 0.0
	if holding:
		_canvas.draw_rect(r, col.darkened(0.6), false, Pal.px(2.0, s.y))
		_draw_slot_marks(s, r, col)
		return

	if _rim_flash_t >= 0.0:
		_canvas.draw_rect(r, Color(_rim_flash_color, 0.25))
		col = _rim_flash_color
	elif _damage_flicker > 0:
		# Two frames of GOLD at the instant you are hurt: the game reminding you
		# what is at stake exactly when losing it becomes possible. Below the drop
		# flash because a drop landing is news and a hit is a thing you already
		# know — you felt it in the health bar, which is Tier 1 and louder.
		col = Pal.GOLD
	elif tier >= 2:
		# The dithered gold halo. One ring of 50% gold reads as a dither at the
		# distance a player actually sits from the screen. This one is about
		# VALUE, not rarity — it is outside the frame and gold; the legendary
		# ring below is inside it and the rarity's own colour, so the two can be
		# on screen together and still be two sentences.
		_canvas.draw_rect(r.grow(Pal.px(2.0, s.y)), Color(Pal.GOLD, 0.18), false,
			Pal.px(1.0, s.y))

	var weight := rarity_weight(rarity)
	var thick := Pal.px(float(weight.x), s.y)
	_canvas.draw_rect(r, col, false, thick)
	if rarity == 1:
		# Uncommon: a second, thinner rule inboard of the frame. Deliberately a
		# GAP and a line rather than a fatter frame — 3 px is rare's weight and
		# the two must not converge.
		_canvas.draw_rect(r.grow(-(thick + Pal.px(2.0, s.y))), col, false,
			Pal.px(1.0, s.y))
	elif rarity >= 3:
		_canvas.draw_rect(r.grow(-(thick + Pal.px(2.0, s.y))), Color(col, 0.4),
			false, Pal.px(1.0, s.y))

	_draw_slot_marks(s, r, col)


## How full the bag is, and what the case is saving — one row of marks along the
## rim's bottom inside edge. HUD_PLAN decision 26.
##
## **This is what the empty rim was missing.** A rim with nothing in it is a bare
## rectangle in the corner for the whole first half of a run, and §13.2's rule —
## the same one `_draw_heat` states — is that an instrument which only appears
## once you are already doing well teaches nobody. The marks are there at zero
## stacks, so the histogram above them is explained before the player has one.
##
## The first `Run.CASE_SLOTS` are FULL height and the rest are half: the case is
## the part you keep when you die, so "what does the case save" and "how full am
## I" are the same row read two ways. That difference is a HEIGHT and not a hue,
## which is the same argument the rim's own rarity thickness makes.
##
## Not twelve hard-coded. The case is `Run.CASE_SLOTS` and the hold is
## `Run.hold_slots()`, which the player buys upgrades to — `mvp_loop` reaches 13
## slots on a normal run, so a fixed twelve would have been wrong by the second
## shop visit.
##
## **Deliberately INSIDE the rim, not on its frame**, which is decision 33's
## second reason for putting them here: the frame already has a six-way
## precedence ladder on it, and a seventh claimant would have had to join it.
func _draw_slot_marks(s: Vector2, r: Rect2, col: Color) -> void:
	var case_n: int = Run.CASE_SLOTS
	var hold_n: int = maxi(Run.hold_slots(), 0)
	var total := case_n + hold_n
	if total <= 0:
		return
	var full := Pal.px(SLOT_MARK_H, s.y)
	var pad := Pal.px(4.0, s.y)
	var inner := r.grow(-(Pal.px(3.0, s.y) + pad))
	var gap := Pal.px(2.0, s.y)
	var w := (inner.size.x - gap * float(total - 1)) / float(total)
	if w <= 0.0:
		return
	var used_case: int = Run.case_slots_used()
	var used_hold: int = Run.hold_slots_used()
	var bottom := inner.end.y
	for i in total:
		var is_case := i < case_n
		var h := full if is_case else full * 0.5
		var lit := (i < used_case) if is_case else (i - case_n < used_hold)
		var box := Rect2(inner.position.x + (w + gap) * float(i), bottom - h, w, h)
		# An unused slot is a NOTCH and not nothing. The row has to read as a
		# capacity at a glance, which means the empties have to be visible —
		# otherwise a half-full bag and a small bag look identical.
		_canvas.draw_rect(box, col if lit else Color(Pal.ASH, 0.6))


func _best_rarity() -> int:
	var best := 0
	var best_v := -1
	for id: StringName in Run.bag:
		var def := ItemDb.get_def(id)
		if def != null and def.value > best_v:
			best_v = def.value
			best = int(def.rarity)
	return best


# --- Extraction (§5.4) ------------------------------------------------------
## The hold, and nothing else. **There is no standing readout of the fee out
## here.**
##
## There used to be an `EXTRACT <charge>` line under the bag, RUST once the toll
## had eaten the purse. It is gone for the same reason the 32 px gold total above
## it went (`_draw_bag`, §5.3): a figure pinned to the corner of the screen gets
## read constantly, and a player watching the fee tick is doing bookkeeping in
## the middle of a dungeon instead of playing one. Two numbers in the corner made
## that worse than one, because a pair invites arithmetic.
##
## The fee did not become hidden. The pouch says it in words -- "The rope wants
## 36 and you have 26. It will take all of it." -- the rope's own verb meta
## carries the charge, the pause menu's "Way out" row names it, and the receipt
## says what was actually paid. Every one of those is somewhere the player has
## STOPPED, which is where a money decision belongs.
##
## What is left here is the part that is not a figure at all: the screen-wide
## sweep at the moment leaving starts costing everything (`set_extract_dear` ->
## `_draw_sweep`), and this ring, which is feedback for a button being held right
## now and vanishes with it.
func _draw_extraction(s: Vector2) -> void:
	if not Run.in_dungeon or _extract_hold <= 0.0:
		return
	# **On the rim itself**, not floating over it (decision 15). Holding draws a
	# ring around your own money while the world stays live: the cost is paid out
	# of the thing you are protecting, and the UI says so.
	#
	# This was a 54 px arc centred on `Pal.BAG_NUM_BASELINE` — the anchor of a
	# 32 px gold total deleted in 2026-08-09 — so it was a ring drawn around
	# nothing, positioned by a ghost, and it kept that constant alive for a year
	# of commits. The styleguide's argument for the ring was right and the RIM is
	# already that ring: it frames the bag, it is already 2 px, and its colour is
	# already what says how much is at stake. Redrawing its own frame in CYAN
	# deletes a widget and an anchor instead of moving them.
	var tl := Pal.RIM_TL * s
	var br := Pal.RIM_BR * s
	HoldGauge.frame(_canvas, Rect2(tl, br - tl), _extract_hold,
		Pal.px(3.0, s.y), Pal.CYAN)


## How long the current arc lives. See `ARC_SPAN`.
func _arc_life() -> float:
	return lerpf(ARC_TIME, ARC_TIME_MAX, _arc_force)


## How hard the blow was, banked for the arc that `_on_hero_struck` is about to
## start.
##
## **Two signals and not one, and this one lands first on purpose.** They answer
## different questions -- `hero_hurt` is the blow's WEIGHT and `hero_struck` is
## its BEARING -- and `Hero.take_hit` emits them in that order for exactly this
## reason, with a comment saying so. Nothing else in the tree emits either.
##
## Merging them was considered and is worse: `hero_struck` is also what tells the
## HUD to draw at all, and folding two arguments into it would make every other
## listener carry a force it does not want.
func _on_hero_hurt(force: float, _tier: int, _at: Vector3) -> void:
	_arc_force = clampf(force, 0.0, 1.0)


## Where the blow came from, in camera space, as a bearing with 0 at the top of
## the circle and increasing clockwise.
##
## **The expression is written out because `docs/CONTRACT.md` §2.5 exists.**
## Facing has been derived wrong three times in this repo — the hero rig, the
## weapon socket, and the whole monster roster — so this is not left to whoever
## reads "camera-relative yaw" next:
##
##     local   = cam.basis.inverse() * (from - hero.global_position)
##     bearing = atan2(local.x, -local.z)
##
## `-local.z` because a Node3D's forward is `-basis.z`. A blow from straight
## ahead is 0 and draws at the TOP; one from straight behind is PI and draws at
## the BOTTOM. That is the near-universal convention and it is fine — what is not
## fine is leaving it unwritten, because "behind me" rendered at the bottom of
## the screen reads as "below me" to anyone who has not been told.
func _on_hero_struck(from: Vector3) -> void:
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	var cam := _canvas.get_viewport().get_camera_3d()
	if hero == null or cam == null:
		return
	var local := cam.global_transform.basis.inverse() * (from - hero.global_position)
	# A blow with no direction — a floor spike, a drown, `Hit.from` left at ZERO
	# on a hero standing at the origin. Draw nothing rather than draw "north": an
	# arrow pointing at a lie is worse than no arrow.
	if absf(local.x) < 0.001 and absf(local.z) < 0.001:
		return
	_arc_bearing = atan2(local.x, -local.z)
	_arc_t = 0.0
	_wake()


## The arc itself. 3 px RUST at `ARC_R` about screen centre, 40-96 degrees over
## 300-550 ms depending on what hit him (`ARC_SPAN`).
##
## Godot's `draw_arc` measures from +X and runs clockwise on a screen whose y
## grows downward, so the bearing is turned a quarter-turn to put 0 at the top.
## That single `- PI * 0.5` is the whole of the convention above, and it is here
## rather than in `_on_hero_struck` so the stored bearing stays a bearing.
func _draw_arc(s: Vector2) -> void:
	if _arc_t < 0.0:
		return
	# Fades out over its whole life rather than holding then dropping. It is a
	# 300 ms stroke; a hold would need a fade shorter than three frames to fit,
	# and a cue that vanishes is a cue the player is not sure they saw.
	var a := 1.0 - clampf(_arc_t / _arc_life(), 0.0, 1.0)
	var mid := _arc_bearing - PI * 0.5
	var r := ARC_R * s.y
	var span := lerpf(ARC_SPAN, ARC_SPAN_MAX, _arc_force)
	var from := mid - span * 0.5
	var to := mid + span * 0.5
	# **A VOID underline first.** RUST on a sunlit wall is unmissable and RUST on
	# dark grass is nearly nothing, and the frames say so: the four-bearing beat
	# reads clean at front, left and right and almost vanishes at BEHIND — which
	# is the one bearing this whole feature exists for, because it is the only one
	# the player cannot get any other way. A cue whose legibility depends on what
	# the courtyard is made of is not a cue.
	#
	# The same trick as the slip notches and the world plates, and the cheapest
	# form of it: the RUST stroke stays exactly 3 px, so nothing about §7.10's
	# restraint changes — what changes is that the 3 px is guaranteed to be seen.
	_canvas.draw_arc(s * 0.5, r, from, to, 24, Color(Pal.VOID, a * 0.8),
		Pal.px(ARC_W + 4.0, s.y), true)
	_canvas.draw_arc(s * 0.5, r, from, to, 24, Color(Pal.RUST, a),
		Pal.px(ARC_W, s.y), true)


## One screen-wide event, then silence. A permanent "the way out now costs
## everything" banner nags, and a sound alone is missable in combat.
func _draw_sweep(s: Vector2) -> void:
	if _sweep_t < 0.0:
		return
	var f: float = clampf(_sweep_t / SWEEP_TIME, 0.0, 1.0)
	_canvas.draw_rect(Rect2(0.0, s.y * 0.5, s.x * f, Pal.px(1.0, s.y)), Pal.CYAN)


# --- Toast and lock-on ------------------------------------------------------

func _draw_toast(s: Vector2) -> void:
	if _toast_t < 0.0 or _toast.is_empty() or _save_t >= 0.0:
		return
	var a := 1.0
	if _toast_t > TOAST_HOLD:
		a = 1.0 - (_toast_t - TOAST_HOLD) / TOAST_FADE
	CanvasText.draw_right(_canvas, _toast,
		Vector2(Pal.BAG_RIGHT * s.x, Pal.TOAST_BASELINE * s.y),
		_text(16.0), Color(_toast_color, clampf(a, 0.0, 1.0)))


## AUTOSAVING…, bottom right, on the toast's baseline.
##
## The same line, and not a line of its own, because the corner below it is
## already spoken for: the rim frames the bag from 0.786 to 0.914 and the
## extraction fee sits at 0.940. There is no free row down there, and a notice
## that overlapped the fee would obscure the one number the player is standing
## still to read.
##
## Sharing is safe by construction rather than by luck: an autosave only fires
## inside a `Flow` transition, and nothing drops loot or snaps a rope during a
## fade. `_draw_toast` yields anyway if both are somehow up, because the save is
## the one that reports something irreversible.
##
## MOTH, not CYAN and not GOLD. It is the HUD talking about itself rather than
## about the world, and the two colours that mean "the way out" and "money" are
## exactly the two a player would misread here.
func _draw_save(s: Vector2) -> void:
	if _save_t < 0.0:
		return
	var a := 1.0
	if _save_t > SAVE_HOLD:
		a = 1.0 - (_save_t - SAVE_HOLD) / SAVE_FADE
	CanvasText.draw_right(_canvas, "AUTOSAVING...",
		Vector2(Pal.BAG_RIGHT * s.x, Pal.TOAST_BASELINE * s.y),
		_text(14.0), Color(Pal.MOTH, clampf(a, 0.0, 1.0)))


## The interact line. Centred and low -- under the action, above the kit strip,
## on the axis the player is already looking down. It shares this centre slot
## with the counter-attack prompt, which takes precedence while its reward is available.
func _draw_prompt(s: Vector2) -> void:
	if _prompt.is_empty():
		return
	var scale := _text(14.0)
	var w := CanvasText.width(_prompt, scale)
	var h := CanvasText.height(scale)
	var centre := Vector2(s.x * 0.5, s.y * 0.735)
	var pad := Pal.px(PLATE_WORLD_PAD, s.y)
	var box := Rect2(centre.x - w * 0.5 - pad, centre.y - pad,
		w + pad * 2.0, h + pad * 2.0)
	_canvas.draw_rect(box, PLATE_WORLD)
	CanvasText.draw_centred(_canvas, _prompt, centre, scale, Pal.BONE)

	# The hold gauge, along the bottom edge of the line it belongs to. Inside the
	# box rather than under it: a bar floating below the plate is a second widget
	# the player has to associate with the first, and this is the same statement
	# as "HOLD A TO DESCEND" drawn in the other language. See `HoldGauge`.
	if _hold_required:
		var bar_h := Pal.px(HoldGauge.BAR_H, s.y)
		HoldGauge.bar(_canvas, Rect2(box.position.x, box.end.y - bar_h,
			box.size.x, bar_h), _hold01, Pal.BONE)


## The perfect-dodge counter, in the interact prompt's centre slot. The cap is
## resolved on every draw so device changes and rebinding remain live.
func _draw_flurry_prompt(s: Vector2) -> void:
	var cap := _hotkey(&"attack")
	var cap_scale := _text(14.0)
	var label_scale := _text(16.0)
	var cap_pad := Pal.px(5.0, s.y)
	var outline := maxf(Pal.px(1.0, s.y), 1.0)
	var cap_radius := maxf(Pal.px(14.0, s.y),
		CanvasText.width(cap, cap_scale) * 0.5 + cap_pad)
	var cap_outer := cap_radius + outline
	var label := "COUNTER ATTACK"
	var label_w := CanvasText.width(label, label_scale)
	var label_h := CanvasText.height(label_scale)
	var gap := Pal.px(8.0, s.y)
	var row_h := maxf(cap_outer * 2.0, label_h)
	var row_w := cap_outer * 2.0 + gap + label_w
	var origin := Vector2(s.x * 0.5, s.y * 0.735 + row_h * 0.5)
	var row := Rect2(-row_w * 0.5, -row_h * 0.5, row_w, row_h)
	var plate := row.grow(Pal.px(PLATE_WORLD_PAD, s.y))

	_canvas.draw_set_transform(origin, 0.0, Vector2.ONE * _flurry_scale)
	_canvas.draw_rect(plate, PLATE_WORLD)
	CanvasText.draw_text(_canvas, label,
		Vector2(row.position.x, -label_h * 0.5), label_scale, Pal.BONE)
	var cap_centre := Vector2(row.position.x + label_w + gap + cap_outer, 0.0)
	_canvas.draw_circle(cap_centre, cap_outer, Pal.MIDNIGHT)
	_canvas.draw_circle(cap_centre, cap_radius, Pal.BONE)
	CanvasText.draw_centred(_canvas, cap,
		Vector2(cap_centre.x, -CanvasText.height(cap_scale) * 0.5),
		cap_scale, Pal.MIDNIGHT)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The transformed World plate is the outermost painted area during the pop.
	_note(&"flurry_prompt", &"prompt", Rect2(
		origin + plate.position * _flurry_scale,
		plate.size * _flurry_scale))


## The sight, drawn only while a ranged item is out.
##
## Four ticks around an empty middle, and nothing in the centre. The gap is the
## point: a solid dot or a full cross covers the thing being shot at, and at this
## resolution that is a goblin's head. Everything the player needs — "the shot
## goes HERE" — is carried by the four points converging on a hole.
##
## Screen centre, exactly, because that is the ray `HeroRanged._aim_from` casts.
## A crosshair drawn anywhere else would be a decoration that lies.
##
## Holding a lock turns it RUST and pulls the ticks in. The lock overrides the
## crosshair — the shot goes to the target, not to the middle of the screen — and
## a sight that looked identical either way would be claiming otherwise.
func _draw_crosshair(s: Vector2) -> void:
	if not _aiming:
		return
	var locked := _lock_target != null and is_instance_valid(_lock_target)
	var centre := s * 0.5
	# Quantized to the same 480x270 grid the lock reticle uses, so the two never
	# sit half a pixel apart from each other.
	var grid := s / Vector2(480.0, 270.0)
	centre = (centre / grid).round() * grid

	var gap := Pal.px(5.0 if locked else 7.0, s.y)
	var arm := Pal.px(5.0, s.y)
	var w := Pal.px(1.0, s.y)
	var col := Pal.RUST if locked else Pal.BONE
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var near := centre + dir * gap
		var far := near + dir * arm
		var a := Vector2(minf(near.x, far.x), minf(near.y, far.y))
		var b := Vector2(maxf(near.x, far.x), maxf(near.y, far.y))
		_canvas.draw_rect(Rect2(a, (b - a) + Vector2(w, w)), col)


## What the lock is pointing at, as one of three words. `targetable` is the group
## the targeting system walks, and it is deliberately wider than `enemy` — a
## hookshot anchor and a shopkeeper are both things you can put the reticle on,
## and the bracket has to say which without the player reading anything.
##
## Order matters: a hookable ENEMY exists (a chandelier-hanging wraith is the
## obvious one) and it should read as hostile first, because what it is going to
## do to you outranks what you could do to it.
func _lock_kind(t: Node3D) -> StringName:
	if t == null:
		return &"neutral"
	if t.is_in_group(&"enemy") or t.is_in_group(&"boss"):
		return &"hostile"
	if t.is_in_group(&"hookable"):
		return &"hookable"
	return &"neutral"


## Four corner brackets, not a fairy and not a triangle. Positions quantize to
## the 480x270 internal grid so the reticle jitters in lockstep with the world's
## own vertex snapping -- the UI element that touches the world obeys the world's
## rules, and the corner instruments do not. That is the cohesion detail.
func _draw_lock_on(s: Vector2) -> void:
	if _lock_target == null or not is_instance_valid(_lock_target):
		return
	var cam := _canvas.get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := _lock_target.global_position + Vector3(0.0, 1.4, 0.0)
	if cam.is_position_behind(head):
		return

	var c := cam.unproject_position(_lock_target.global_position + Vector3(0, 0.8, 0))
	var half := Vector2(Pal.px(26.0, s.y), Pal.px(34.0, s.y))
	var grid := s / Vector2(480.0, 270.0)
	c = (c / grid).round() * grid

	# **What KIND of thing is this**, in three channels at once — decisions 16, 22
	# and 31. Colour was the whole answer before, and "can I hook that" being a hue
	# on a bracket mid-fight is the exact failure §13.3 raises: RUST against CYAN
	# is a red/green pair, which is the commonest form of colour blindness there
	# is, and this is the reticle you are looking directly at while fighting.
	#
	#   hostile  RUST  four corners, arms INWARD along the edges   8 px
	#   hookable CYAN  four corners, arms OUTWARD off the corners  12 px
	#   neutral  MOTH  TWO corners (top-left, bottom-right)        5 px
	#
	# Shape, hue and arm length. Any one of the three is sufficient on its own,
	# which is the construction rule decision 31 states — and none of it is a new
	# widget: it is this same loop with a sign, a length and a corner count.
	var kind := _lock_kind(_lock_target)
	var col := Pal.RUST
	var arm := Pal.px(8.0, s.y)
	var outward := false
	# Two corners and not two edges: a diagonal pair still reads as a box, and it
	# is unmistakably LESS than four at a glance, which is the whole message —
	# this is a thing you can talk to, not a thing you are fighting.
	var corners := [Vector2(-1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0),
		Vector2(1.0, -1.0)]
	if kind == &"hookable":
		col = Pal.CYAN
		arm = Pal.px(12.0, s.y)
		# The arms point away from the box rather than lying along it, which is
		# the hookshot's own ring rather than a gunsight. §2 makes CYAN mean the
		# way out, and this is the one shape that means it too.
		outward = true
	elif kind == &"neutral":
		col = Pal.MOTH
		arm = Pal.px(5.0, s.y)
		corners.resize(2)

	# **Every stroke is laid on a VOID keyline first**, 1 px proud on each side.
	#
	# This bracket is drawn over the WORLD, not over a known background, and the
	# HUD already knows what that costs: `_draw_enemy_bars` two functions down
	# frames every bar for exactly this reason, because "2 px of RUST on a lit
	# sandstone wall is nearly the wall". The reticle never got the same
	# treatment and it needed it most — rendered in the garrison, the neutral
	# bracket was INVISIBLE. MOTH (`807868`) is a mid-khaki, the courtyard is lit
	# khaki grass and pine, and of its two 5 px corners exactly one could be found
	# by eye, and only because it happened to fall across a dark step.
	#
	# The keyline is the right repair rather than a longer arm or a brighter hue,
	# because arm length and hue are two of the three channels decision 31 uses to
	# say WHICH KIND of thing this is. Changing either to fix legibility spends a
	# channel that is already carrying meaning. An outline costs none of them.
	#
	# Same argument as §15.13's damage arc, which was invisible over the same
	# grass and was fixed the same way.
	var w := Pal.px(2.0, s.y)
	var key := Pal.px(1.0, s.y)
	for k: Vector2 in corners:
		var sx := k.x
		var sy := k.y
		var corner := c + Vector2(half.x * sx, half.y * sy)
		# Inward: from a right-hand corner the arm runs back to the LEFT. Outward
		# flips exactly that, which is decision 22's "sign flip" and nothing else.
		var hx := (arm if (sx > 0) != outward else 0.0)
		var vy := (arm if (sy > 0) != outward else 0.0)
		var across := Rect2(corner.x - hx, corner.y - w * 0.5, arm, w)
		var down := Rect2(corner.x - w * 0.5, corner.y - vy, w, arm)
		_canvas.draw_rect(across.grow(key), Pal.VOID)
		_canvas.draw_rect(down.grow(key), Pal.VOID)
		_canvas.draw_rect(across, col)
		_canvas.draw_rect(down, col)

	# The bar that used to hang 6 px under this bracket is gone. It is now drawn by
	# `_draw_enemy_bars`, over the target's HEAD, through the same path every other
	# monster's bar takes -- widened by EBAR_LOCK_MULT so the lock still reads as a
	# lock. Two bars on one monster, in two places, from two code paths, is how the
	# locked one stops being the one you are looking at.


## Little bars over the monsters. See the EBAR_* block for what earns one and why
## the conditions are not decoration.
func _draw_enemy_bars(s: Vector2) -> void:
	var cam := _canvas.get_viewport().get_camera_3d()
	if cam == null:
		return
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	if hero == null:
		return

	# Quantized to the same 480x270 grid as the lock brackets, so a bar and the
	# bracket around it jitter together with the world's vertex snapping instead of
	# sliding against each other (docs/STYLEGUIDE.md §5.5).
	var grid := s / Vector2(480.0, 270.0)
	var space := cam.get_world_3d().direct_space_state

	for n in get_tree().get_nodes_in_group(&"enemy"):
		var e := n as Node3D
		if e == null or not is_instance_valid(e):
			continue
		var hp := _health_of(e)
		if hp == null or hp.dead:
			continue
		# Asleep and unhurt earns nothing. `is_engaged` is the monster's own answer
		# about its own states (scripts/actors/enemies/enemy.gd).
		var engaged: bool = e.has_method(&"is_engaged") and e.is_engaged()
		if not engaged and hp.quarters >= hp.max_quarters:
			continue
		if hero.global_position.distance_to(e.global_position) > EBAR_RANGE:
			continue

		var head: Vector3 = e.call(&"head_point") if e.has_method(&"head_point") \
			else e.global_position + Vector3.UP * EBAR_FALLBACK_Y
		# Behind the camera unprojects to a point in front of it -- a bar for a
		# monster at your back, drawn over the wall you are facing.
		if cam.is_position_behind(head):
			continue
		if not _bar_visible(space, cam, head, e):
			continue

		var locked := e == _lock_target
		var w := Pal.px(EBAR_W * (EBAR_LOCK_MULT if locked else 1.0), s.y)
		var h := Pal.px(EBAR_H, s.y)
		var b := Pal.px(EBAR_BORDER, s.y)
		var c := cam.unproject_position(head)
		c = (c / grid).round() * grid
		var x := c.x - w * 0.5

		# A frame, because this bar is drawn over the world rather than over a
		# known background: 2 px of RUST on a lit sandstone wall is nearly the wall,
		# and on VOID an ASH track alone is nearly nothing. BONE for an elite is the
		# only per-kind mark on the HUD, and it is on the one monster whose whole
		# design is "you can see this one coming" (scripts/core/progression.gd).
		var elite: bool = bool(e.get(&"elite")) if &"elite" in e else false
		var frame := Rect2(x - b, c.y - b, w + b * 2.0, h + b * 2.0)
		_canvas.draw_rect(frame, Pal.BONE if elite else Pal.VOID)
		_canvas.draw_rect(Rect2(x, c.y, w, h), Color(Pal.ASH, 0.85))
		# Rounded to whole pixels, and never eased. Anti-slop §7.4.
		var fill := roundf(w * hp.fraction())
		if fill >= 1.0:
			_canvas.draw_rect(Rect2(x, c.y, fill, h), Pal.RUST)
		# Said by the code that drew it, on the frame it drew it — see
		# `enemy_bar_rects()`. Recorded after the draw calls and not before the
		# gates above, so a monster that was skipped for any of the three reasons
		# is absent here as well as absent from the picture.
		_mark_bar(e, frame)


## Record one bar. Debug builds only, like `_note` — in an export this is a single
## boolean test and `enemy_bar_rects()` stays empty.
func _mark_bar(e: Node3D, r: Rect2) -> void:
	if not OS.is_debug_build():
		return
	_ebars[e.get_instance_id()] = r


## Names and readouts anchored to a point in the world and drawn HERE, at native
## resolution, rather than in the world as a billboarded `Label3D`.
##
## **Card #61, and it is `docs/STYLEGUIDE.md` §4.5's one casualty.** The world
## renders into a fixed 480 x 270 buffer now, and a `Label3D` is world geometry
## wearing a glyph atlas -- so `LANTERNKEEPER` over a keeper four metres away
## went through the buffer with the curtain wall and came back as a smear about
## five buffer pixels tall. `E TO TALK`, two inches below it on the same frame,
## stayed crisp, because the HUD never enters the buffer. That contrast is the
## whole argument: this text was always interface, and §4.5 is what made the
## difference visible. `scripts/ui/world_caption.gd` carries the rest of it,
## including which captions deliberately did NOT move -- the carved ones, a
## lintel and a monument and a door tablet, which are physical objects and are
## allowed to be soft at distance the way a real carved sign is.
##
## **The three gates are `_draw_enemy_bars`', deliberately.** In range of the
## hero, in front of the camera, and with nothing in the way. The last one is
## not optional and it is not a nicety: a caption painted through a wall is
## exactly the defect §4.3 spent cards #26 and #37 killing -- a keeper's name
## readable from out on the plain, an Echo's name leaking through the shortcut
## door that had not been opened. Moving the text onto the canvas is not a
## licence to bring that back, so the depth test the world gave for free is
## bought back here with one ray, and `WorldCaption.occlude` is the flag a
## director flips to photograph what it looks like without it.
##
## Everything else -- the words, the size, how far it carries -- belongs to the
## caption and not to this function. A name plate is not one widget with a
## constant block; it is however many the room put in the group.
##
## ## Why this lays the captions out instead of drawing them where they land
##
## **Card #68, and it is card #61's bill arriving.** Text on the canvas does not
## shrink with distance, so the spacing perspective used to do for free is not
## done at all: the sounding stone hangs three names 1.30 m apart on one drum,
## and from the game camera across a 9 m landing THE SECOND WIND was drawn
## through THE RETURNING SHAFT and neither could be read. The lookdev lens three
## metres from the same drum held them apart, which is what says it is spacing
## and not content.
##
## So the captions are gathered, sorted top-down, and any that would overlap one
## already placed is pushed DOWN until it clears -- the direction perspective
## itself picks, because for a row of captions at one height the nearer one
## already projects lower. Nothing else moves: same words, same size, same
## anchor in x, and a caption with nothing near it is drawn exactly where it was
## before this pass existed.
##
## The two answers not taken, because the next reader will think of both:
##
##  * **Shrink with distance.** It un-does card #61 -- the reason a caption is
##    here rather than in the 480x270 buffer is that it was illegible small --
##    and it cannot be done inside §3.1b's ladder, whose floor is 10 px and
##    whose whole point is that there is no rung under it. A name at 9 m would
##    want about 6 px.
##  * **A vertical stagger authored into `SoundingStone`.** It fixes one drum.
##    The defect is not the drum's: any cluster of canvas captions has it, and a
##    fix that has to be re-authored per prop is a fix this repo pays for twice
##    (CLAUDE.md §0).
func _draw_world_captions(s: Vector2) -> void:
	var cam := _canvas.get_viewport().get_camera_3d()
	if cam == null:
		return
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	if hero == null:
		return

	# Same 480x270 grid as the lock brackets and the enemy bars. A caption is
	# anchored to a point in a world that snaps its vertices to that grid; left
	# unquantized it slides half a pixel against the prop it names on every
	# camera move, which reads as the caption being loose rather than the world
	# being crunchy (docs/STYLEGUIDE.md §5.5).
	var grid := s / Vector2(480.0, 270.0)
	var space := cam.get_world_3d().direct_space_state
	var pad := Pal.px(PLATE_WORLD_PAD, s.y)
	var gap := Pal.px(CAPTION_STACK_GAP, s.y)

	# Pass one: who is drawn at all, and where each one would like to be. Nothing
	# reaches the canvas in this loop -- the de-collide below cannot decide where
	# the second caption goes until it knows about the first.
	var want: Array[Dictionary] = []
	var loose: Array[Dictionary] = []
	for n in get_tree().get_nodes_in_group(WorldCaption.GROUP):
		var cap := n as WorldCaption
		if cap == null or not is_instance_valid(cap):
			continue
		# `is_visible_in_tree`, not `visible`: a keeper's sign is raised and
		# dropped by `Prompt` with `cap.visible`, and a caption under a hidden
		# prop must go with the prop.
		if cap.text.is_empty() or not cap.is_visible_in_tree():
			continue
		var at := cap.global_position
		var a := cap.opacity_at(hero.global_position.distance_to(at))
		if a <= 0.004:
			continue
		# Behind the camera unprojects to a point in FRONT of it -- a name for
		# something at your back, drawn over the wall you are facing.
		if cam.is_position_behind(at):
			continue
		if cap.occlude and not _caption_visible(space, cam, cap):
			continue

		var scale := _text(cap.ref_px)
		var w := CanvasText.width(cap.text, scale)
		var h := CanvasText.height(scale)
		var c := cam.unproject_position(at)
		c = (c / grid).round() * grid
		# The anchor is the caption's BASELINE-ish middle: the text is centred on
		# the point and hangs from it, so a caption placed at the height the
		# `Label3D` used to sit at lands where the label used to land.
		var centre := Vector2(c.x, c.y - h * 0.5)
		# The plate's rectangle whether or not this caption wears one: it is the
		# ink's footprint plus the margin §5.7 says text needs, which is what a
		# neighbour has to clear either way.
		var box := Rect2(centre.x - w * 0.5 - pad, centre.y - pad,
			w + pad * 2.0, h + pad * 2.0)
		var e := {"cap": cap, "centre": centre, "box": box, "a": a, "scale": scale}
		if cap.declutter:
			want.append(e)
		else:
			loose.append(e)

	# Pass two: top-down, and stable. Sorting by the projected anchor rather than
	# by distance from the camera is the same order for a row of captions at one
	# height -- the nearer one projects lower -- and it does not swap when the
	# camera crosses the plane the anchors lie in, which a distance sort does.
	# `x` and the instance id break ties, because two captions on one row must not
	# change places between frames: the pass would then hand them each other's
	# rows and the pair would flicker.
	want.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		var a1: Vector2 = p["centre"]
		var b1: Vector2 = q["centre"]
		if not is_equal_approx(a1.y, b1.y):
			return a1.y < b1.y
		if not is_equal_approx(a1.x, b1.x):
			return a1.x < b1.x
		return (p["cap"] as Node).get_instance_id() \
			< (q["cap"] as Node).get_instance_id())

	# Pass three: place, then draw. `loose` captions are appended unplaced -- see
	# `WorldCaption.declutter`: a damage number is already moving and is neither
	# pushed nor pushed against.
	var placed: Array[Rect2] = []
	var draw_list: Array[Dictionary] = []
	for e: Dictionary in want:
		var box: Rect2 = e["box"]
		var limit := (box.size.y + gap) * float(CAPTION_STACK_MAX)
		var drop := 0.0
		# One sweep per already-placed caption is enough to settle: each sweep
		# either clears the box or moves it strictly below the lowest rectangle it
		# hit, and there are only so many of those. The bound is the loop's
		# guarantee of termination, not an estimate.
		for _sweep: int in placed.size() + 1:
			var hit := false
			for p: Rect2 in placed:
				if not p.intersects(box):
					continue
				var d: float = p.end.y + gap - box.position.y
				box.position.y += d
				drop += d
				hit = true
			if not hit:
				break
		if drop > limit:
			# Too crowded to place honestly. See `CAPTION_STACK_MAX`.
			continue
		placed.append(box)
		var centre: Vector2 = e["centre"]
		e["centre"] = Vector2(centre.x, centre.y + drop)
		draw_list.append(e)
	draw_list.append_array(loose)

	for e: Dictionary in draw_list:
		var cap: WorldCaption = e["cap"]
		var centre: Vector2 = e["centre"]
		var scale: float = e["scale"]
		var a: float = e["a"]
		var w: float = CanvasText.width(cap.text, scale)
		var h: float = CanvasText.height(scale)
		if cap.plate:
			_canvas.draw_rect(
				Rect2(centre.x - w * 0.5 - pad, centre.y - pad,
					w + pad * 2.0, h + pad * 2.0),
				Color(Pal.VOID, PLATE_WORLD.a * a))
		CanvasText.draw_centred(_canvas, cap.text, centre, scale,
			Color(cap.tint, cap.tint.a * a))


## Is there world geometry between the camera and this caption?
##
## `K.L_WORLD` only, and the prop the caption hangs off excluded -- a training
## post must not hide its own readout, and `_bar_visible` below documents the
## same rule at length for monsters. The exclusion walks up the ancestors rather
## than testing the caption itself, because a `WorldCaption` is a bare `Node3D`
## with no collider: the body in the way of its own name is always its parent.
func _caption_visible(space: PhysicsDirectSpaceState3D, cam: Camera3D,
		cap: WorldCaption) -> bool:
	_ebar_ray.from = cam.global_position
	_ebar_ray.to = cap.global_position
	var skip: Array[RID] = []
	var owner: Node = cap.get_parent()
	while owner != null:
		if owner is CollisionObject3D:
			skip.append((owner as CollisionObject3D).get_rid())
		owner = owner.get_parent()
	_ebar_ray.exclude = skip
	return space.intersect_ray(_ebar_ray).is_empty()


## Is there world geometry between the camera and this monster's head?
##
## World layer only, and the monster itself excluded. Both matter: including
## `L_ENEMY` would make a monster block its own bar and make a pack hide each
## other's, which is the same bug `Targeting._has_los` documents at length -- a
## thing is never between you and itself.
func _bar_visible(space: PhysicsDirectSpaceState3D, cam: Camera3D,
		head: Vector3, e: Node3D) -> bool:
	_ebar_ray.from = cam.global_position
	_ebar_ray.to = head
	var skip: Array[RID] = []
	if e is CollisionObject3D:
		skip.append((e as CollisionObject3D).get_rid())
	_ebar_ray.exclude = skip
	return space.intersect_ray(_ebar_ray).is_empty()


func _health_of(n: Node) -> HealthComponent:
	for c in n.get_children():
		if c is HealthComponent:
			return c
	return null


# --- Primitives -------------------------------------------------------------
# The arc ring that used to live here is `HoldGauge.ring`. It moved out when the
# interact prompt and the shop counter grew holds of their own: three surfaces
# drawing "keep holding" three ways is three chances for one of them to be the
# one nobody notices.
