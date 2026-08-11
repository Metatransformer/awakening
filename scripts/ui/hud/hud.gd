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
const TOAST_HOLD := 1.60
const TOAST_FADE := 0.20
const RIM_FLASH := 0.10

## The autosave notice. Longer than a toast on purpose: it goes up as the world
## fades back in (game_flow.gd `_go`), so the first third of it is spent behind
## a screen that is still dark. 2.2 s leaves about a second and a half of it
## actually readable, which is what a player needs to register a word they were
## not looking for.
const SAVE_HOLD := 2.20
const SAVE_FADE := 0.35

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
## The focused Interactable's hold, mirrored off `Bus.hold_changed`. `_required`
## is true whenever the thing in reach wants a hold AT ALL, held separately from
## the number so the empty track can be drawn before the player presses anything.
var _hold01: float = 0.0
var _hold_required: bool = false


func _ready() -> void:
	layer = DRAW_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	_canvas = Control.new()
	_canvas.name = "HudCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)

	_target_value = _headline()
	_last_quarters = Game.quarters

	for id: StringName in ArmamentDb.ICONS:
		var tex := ArmamentDb.icon(id)
		if tex == null:
			push_warning("Hud: kit icon missing for '%s' — falling back to lettering" % id)
		else:
			_icons[id] = tex

	Bus.player_health_changed.connect(_on_health)
	Bus.stamina_changed.connect(_on_stamina)
	Bus.magic_changed.connect(_on_magic)
	Bus.bag_changed.connect(_on_bag)
	Bus.loot_gained.connect(_on_loot)
	Bus.gold_changed.connect(_on_gold)
	Bus.ammo_changed.connect(_repaint)
	Bus.loadout_changed.connect(_repaint)
	Bus.item_selected_changed.connect(_repaint)
	# A bound bottle's cell draws what is IN it, so filling or draining one moves
	# the HUD without the binding changing. `_wake` rather than `_repaint` for the
	# draught: the bar it starts has to keep draining after this frame.
	Bus.bottles_changed.connect(_repaint)
	Bus.draught_changed.connect(func(_p: StringName, _s: float) -> void: _wake())
	# A room came out of the fog, or a chest on the plan was opened. The hero
	# ARROW does not need this -- it rides the per-frame repaint below -- but the
	# plan itself only changes on these, so the minimap is not asking `Atlas`
	# anything it has not been told.
	Bus.map_changed.connect(_repaint)
	# Somebody is talking to you, and the overlay stands down for it. See
	# `_refresh_visibility` -- this is a flag and not a direct `visible` because
	# that function has the last word on this property.
	Bus.screen_opened.connect(func(id: StringName) -> void: _on_conversation(id, true))
	Bus.screen_closed.connect(func(id: StringName) -> void: _on_conversation(id, false))
	Bus.heat_changed.connect(_on_heat)
	Bus.heat_tier_changed.connect(_on_heat_tier)
	Bus.escape_rope_broken.connect(_on_escape_rope_broken)
	Saves.autosaved.connect(_on_autosaved)
	Bus.shield_blocked.connect(_on_blocked)
	Bus.parried.connect(_on_parried)
	Bus.target_acquired.connect(_on_target)
	Bus.target_lost.connect(_on_target_lost)
	Bus.aim_changed.connect(_on_aim)
	Bus.prompt_changed.connect(_on_prompt)
	Bus.hold_changed.connect(_on_hold)
	# Every button this overlay names is named for the device in the player's
	# hands, so picking up a pad repaints all of it: the caps, the legend, and
	# the prompt (which Prompt re-emits on the same signal).
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


func _on_health(quarters: int, _max_q: int) -> void:
	var lost := _last_quarters - quarters
	if lost > 0:
		# The ghost accumulates: two hits inside the hold window should show as
		# one four-cell loss, not restart at two.
		_ghost_quarters += lost
		_ghost_t = 0.0
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


func _on_tree_changed(_n: Node) -> void:
	_refresh_visibility.call_deferred()


## True while a `DialogueBox` is up. See `_refresh_visibility`.
var _conversing: bool = false


func _on_conversation(id: StringName, up: bool) -> void:
	if id != &"dialogue":
		return
	_conversing = up
	_refresh_visibility()


## Gameplay scenes have a hero; lookdev boxes and tool scenes do not, and an
## overlay on a weapon rack is just noise in a contact sheet.
##
## **And nobody is talking to you.** The dialogue box is a strip across the
## bottom of a LIVE courtyard -- it does not cover this the way the trade screen
## does -- and it lands in the same two corners as the bars and the key legend.
## The first frame of it had "RMB GUARD | LMB DASH" reading out from under the
## panel while a dwarf introduced himself. It also says nothing useful there:
## `Prompt.blocked` has the hero's controls for the length of a conversation, so
## every button on that line is a button that does nothing.
##
## The flag is the reason this is here and not a `Hud.visible = false` in the
## box: this function runs deferred off `node_added`/`node_removed` and forces
## `visible` back to `has_player` -- and the box's own construction is a tree
## change. Anything setting `visible` from outside is overwritten within a frame.
func _refresh_visibility() -> void:
	if not is_inside_tree():
		return
	var has_player := get_tree().get_first_node_in_group(&"player") != null
	var showing := has_player and not _conversing
	if visible != showing:
		visible = showing

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

	if _ghost_t >= 0.0:
		_ghost_t += delta
		if _ghost_t > GHOST_HOLD + GHOST_DRAIN:
			_ghost_t = -1.0
			_ghost_quarters = 0
		else:
			busy = true

	for t in [&"_toast_t", &"_save_t", &"_floor_t", &"_rim_flash_t", &"_sweep_t",
			&"_block_flash_t", &"_heat_break_t"]:
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

## The roots, and the order is only for readable failures. A group exists here iff
## something claimed it as a parent this frame — the garrison has no minimap and
## the dungeon has no legend, and neither absence is a special case.
const LAYOUT_ROOTS: Array[StringName] = [
	&"pole", &"cluster", &"money", &"floor_card", &"minimap", &"legend", &"prompt",
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


# --- The type ladder (HUD_PLAN §3) --------------------------------------------
## Every size the HUD is allowed to set type at, in reference px at 720p.
## HUD_PLAN decision 2, and the argument under it is about a COUNT, not about
## these particular integers: *"a HUD with seven sizes reads as accreted rather
## than designed"*. A fourth entry is an amendment to that document, argued in
## the same breath — not a number added here because one label was awkward.
##
##   10  ammo / charge numeral, bottle count, slips +N, heat multiplier,
##       floor name, legend
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


func _draw_hud() -> void:
	var s := _canvas.size
	if s.x < 1.0 or s.y < 1.0:
		return
	_layout.clear()
	_type_offenders.clear()
	_draw_health(s)
	_draw_stamina(s)
	_draw_magic(s)
	_draw_heat(s)
	_draw_draughts(s)
	_draw_hands(s)
	_draw_cpad(s)
	_draw_minimap(s)
	_draw_bag(s)
	_draw_extraction(s)
	_draw_toast(s)
	_draw_save(s)
	_draw_prompt(s)
	_draw_crosshair(s)
	_draw_lock_on(s)
	_draw_enemy_bars(s)
	_draw_sweep(s)
	_draw_controls(s)
	_draw_floor(s)
	_seal_layout()


# --- Controls -----------------------------------------------------------------
## A one-line legend, in the garrison only.
##
## Not a tutorial and not a settings screen: the two combat verbs live on the
## mouse and there is nothing on screen that says so, which is exactly how a
## working sword reads as a broken one. Garrison is where you are safe and idle,
## so it is where the legend belongs; underground the line would be noise, and
## by then you have already used every verb on it.
##
## It has this baseline to itself now. The floor readout used to share it and is
## a top-left card instead (see `_draw_floor`), so nothing has to be exclusive
## with anything down here.

## The verbs, in the order a player meets them, each paired with the action that
## fires it. Built from the LIVE bindings rather than written out, because the
## line has to be true on a pad as well as on a keyboard and there is no way to
## keep two hand-written strings honest — the keyboard one had already outlived
## two rebinds of the sword.
##
## `&""` means the label carries its own button (the sticks, which are not
## actions the player rebinds), and LEGEND_LITERAL means the text IS the whole
## entry -- for the D-pad, whose four directions are one idea and would otherwise
## need four rows naming four caps the player never presses individually.
const LEGEND_LITERAL := &"__literal"
## Everything after this entry goes on a SECOND line.
##
## It is here because the legend outgrew 1280 px. Jump, the item button and the
## three D-pad cycles all landed in one pass, and the single centred line went
## off BOTH edges of the screen -- MOVE was cut in half on the left and LOADOUT
## on the right, which is the one failure a legend cannot have. Two rows, split
## where the verbs change subject: what you do with the sword, then what you do
## with your gear.
const LEGEND_BREAK := &"__break"
## Between two entries on a row. Four spaces and not one: at 10 px in a face with
## this much serif, a single space between "R3 LOCK-ON" and "LMB SWORD" makes the
## row read as one sentence, and the whole value of the legend is that the eye
## can find the verb it came looking for.
const LEGEND_SEP := "    "
## What decision 28 budgets: two authored rows, plus one for the combat row to
## overflow into. `_pack_legend` complains rather than truncating if the entry
## list ever needs a fourth.
const LEGEND_MAX_LINES := 3

const LEGEND := [
	[&"", "MOVE"],
	[&"", "LOOK"],
	[&"z_target", "LOCK-ON"],
	[&"attack", "SWORD"],
	# One row for the trigger, and it has to carry three meanings without becoming
	# a paragraph: the heavy, the charge that a hold turns it into, and the fact
	# that a drawn item takes the button over entirely. Naming the HOLD is the
	# same argument the dodge row below makes — there is no tell for a button you
	# are not holding down, so a player who only taps will never find the spin.
	[&"heavy", "HEAVY (HOLD=SPIN) / ITEM"],
	# Two things are named here that a button-masher would never find: the dash,
	# which is a button you already know pressed in a stance you already know, and
	# the fact that the guard LOCKS. On the pad `shield` is the left trigger and
	# it is the whole of OOT's Z — the R3 above is only the standing toggle — so a
	# line that called this button GUARD would be hiding its main use.
	[&"shield", "GUARD/LOCK"],
	# The hold is named because nothing else can name it. A tap rolls and a hold
	# runs off the same button, and a player who only ever taps it will never
	# discover the run — there is no prompt, no stance and no tell for a button
	# you are not holding down. Same argument as the GUARD/LOCK line above.
	#
	# TAP= is on the row for a related reason and it is not decoration: the two
	# halves are now EXCLUSIVE (Hero.sprint_hold_time), so a player who holds the
	# button expecting the roll that used to come out underneath the run gets
	# nothing, and "HOLD=RUN" alone reads as an addition rather than a choice.
	#
	# The LEAP came off this row when it came off this button. It is the trigger's
	# now, under a lock, and it is not named separately up there either — a legend
	# that lists every branch of a contextual button is a manual, not a legend.
	[&"context", "TAP=DODGE HOLD=RUN"],
	[&"jump", "JUMP"],
	[LEGEND_BREAK, ""],
	[&"interact", "INTERACT"],
	# The item button, named for the thing it does rather than for the ring it
	# reads from: a player looking for "how do I drink this" is not looking for
	# the word SELECT. Which bottle it drinks is on the HUD cell itself.
	[&"use_item", "USE ITEM"],
	# The three cycles, on one line, because they are one idea: the D-pad changes
	# your gear and never uses it. Three rows would make them look unrelated and
	# would be the longest thing in the legend, for the input that needs the
	# least explaining once you have seen the carets in the corner.
	# ← → ↓ ↑ and not ◄ ► ▼ ▲. Neither set is in Cinzel; both arrive from the
	# system fallback, and the thin arrows are the pair that sit on a cap-height
	# line without looming over the words either side of them.
	[LEGEND_LITERAL, "D-PAD  \u2190\u2192 WEAPON  \u2193 ITEM  \u2191 SET"],
	[&"inventory", "POUCH"],
]
## What drives movement and the camera on each device. The sticks are bound as
## four actions apiece and naming any one of them ("STICK L MOVE") would be
## nonsense, so this pair is the one thing on the line that is written out.
const LEGEND_STICKS := {
	false: ["WASD", "MOUSE"],
	true: ["L-STICK", "R-STICK"],
}


func _draw_controls(s: Vector2) -> void:
	if Run == null or Run.in_dungeon:
		return
	# FIT TO THE FRAME, do not trust the authored width. This is the one thing on
	# the HUD whose width is set by its TEXT and not by the layout -- it is every
	# bound control, so a rebind, a device swap or a longer verb makes it longer,
	# and the row is already ~150 characters on a keyboard. Under the old 5x7
	# table every glyph was 6 px and it happened to fit at 720p; under a
	# proportional face it ran off both edges of the screen on the first capture.
	#
	# **It WRAPS. It used to shrink, and shrinking could not work** (decision 28,
	# and HUD_PLAN §15.3 for the measurement). The old line here was
	# `if widest > avail: scale *= avail / widest`, which looks like it must fit
	# by construction and does not: `CanvasText.size_of` clamps the em size at
	# `MIN_SIZE`, so below about 9 px the scale keeps falling, the rendered glyphs
	# stop shrinking with it, and the line comes out WIDER than the width it was
	# asked to fit. That is why the strip was illegible AND still ran off both
	# edges -- it was being punished for being long twice and fixed by neither.
	#
	# 10 px is the bottom of the ladder and there is nothing under it, so a legend
	# that does not fit at 10 px has too many entries on a row, not type that is
	# too big. Decision 8 draws it upward into empty floor, so a third row is free.
	var scale := _text(10.0)
	var avail := s.x * (1.0 - Pal.SAFE.x * 2.0)
	var lines := _pack_legend(_legend_groups(), scale, avail)
	# Drawn UPWARDS from the baseline, so adding a row pushes the legend into the
	# empty floor above it rather than off the bottom of the screen.
	var step := CanvasText.height(scale) + Pal.px(5.0, s.y)
	var top := Pal.KEYS_BASELINE * s.y - step * (lines.size() - 1)
	var widest_drawn := 0.0
	for line in lines:
		widest_drawn = maxf(widest_drawn, CanvasText.width(line, scale))
	# Transient, and reported anyway (decision 35). A transient element that
	# overlaps a permanent one for ten seconds is a bug for ten seconds — and the
	# legend running off both edges is one of the three defects decision 20 sells
	# assertion 1 on, so exempting it would exempt the evidence.
	_note(&"legend", &"", Rect2(s.x * 0.5 - widest_drawn * 0.5, top,
		widest_drawn, step * (lines.size() - 1) + CanvasText.height(scale)))
	for i in lines.size():
		CanvasText.draw_centred(_canvas, lines[i],
			Vector2(s.x * 0.5, top + step * i), scale, Pal.ASH)


## Pack the authored groups into rows no wider than `avail`.
##
## **Between ENTRIES, never inside one** — which is why `_legend_groups` hands
## back a list of entries rather than a joined string, and why this does not use
## `CanvasText.wrap`. That function breaks on spaces, and every entry on this
## line has a space in it ("LMB SWORD"); word wrapping would split a cap from its
## verb and collapse the four-space separators that are the only thing making the
## row read as a list rather than as a sentence.
##
## The authored break (`LEGEND_BREAK`) is still honoured — a group always starts
## a new row. Rows are RESERVED for the groups still to come, so a long combat
## group cannot push POUCH off the legend; the gear group is guaranteed its row.
func _pack_legend(groups: Array, scale: float, avail: float) -> PackedStringArray:
	var out: PackedStringArray = []
	for gi in groups.size():
		var entries: PackedStringArray = groups[gi]
		var rows := _greedy_rows(entries, scale, avail).size()
		# BALANCED, not merely legal. Greedy packing at the full width fills row
		# one to the brim and leaves the remainder alone underneath, and the first
		# render of this did exactly that: the combat group came out as a full
		# 1179 px row followed by "E JUMP" by itself in the middle of the screen,
		# which reads as a mistake rather than as a second row. Once the row count
		# is known, the narrowest width that still fits in that many rows spreads
		# the entries evenly — same rows, same order, no orphan.
		var lo := 0.0
		for e in entries:
			lo = maxf(lo, CanvasText.width(e, scale))
		var hi := avail
		for _i in 12:
			var mid := (lo + hi) * 0.5
			if _greedy_rows(entries, scale, mid).size() <= rows:
				hi = mid
			else:
				lo = mid
		out.append_array(_greedy_rows(entries, scale, hi))
	# Not truncated when it overflows, said out loud instead. Dropping a row would
	# hide a binding the player has no other way to learn, which is worse than a
	# legend one row taller than the plan budgeted for — and a silent drop is how
	# you find out months later that POUCH stopped being on screen.
	if OS.is_debug_build() and out.size() > LEGEND_MAX_LINES:
		push_error(("Hud: the legend packed to %d rows and decision 28 budgets "
			+ "%d — the entry list has outgrown the screen, so cut an entry "
			+ "rather than the type") % [out.size(), LEGEND_MAX_LINES])
	return out


## Entries packed left to right into rows no wider than `w`. The first entry
## always goes on the row it is offered, so an entry wider than `w` overhangs
## rather than vanishing — a binding the player cannot see is worse than a
## binding that is slightly too long.
func _greedy_rows(entries: PackedStringArray, scale: float,
		w: float) -> PackedStringArray:
	var rows: PackedStringArray = []
	var line := ""
	for e in entries:
		var candidate: String = e if line.is_empty() else line + LEGEND_SEP + e
		if line.is_empty() or CanvasText.width(candidate, scale) <= w:
			line = candidate
			continue
		rows.append(line)
		line = e
	if not line.is_empty():
		rows.append(line)
	return rows


## The legend's entries, grouped by authored row. Joined and re-broken to fit by
## `_pack_legend`, which is the only thing that knows how wide the screen is.
func _legend_groups() -> Array[PackedStringArray]:
	var sticks: Array = LEGEND_STICKS[Settings != null and Settings.using_pad]
	var lines: Array[PackedStringArray] = []
	var parts: PackedStringArray = []
	var stick := 0
	for entry: Array in LEGEND:
		var action: StringName = entry[0]
		var verb: String = entry[1]
		if action == LEGEND_BREAK:
			lines.append(parts)
			parts = PackedStringArray()
			continue
		if action == LEGEND_LITERAL:
			parts.append(verb)
			continue
		if action == &"":
			parts.append("%s %s" % [sticks[stick], verb])
			stick += 1
			continue
		var cap := _hotkey(action)
		if cap.is_empty():
			continue  # nothing bound on this device — say nothing rather than lie
		if action == &"shield":
			verb = "GUARD/LOCK (+%s DASH)" % _hotkey(&"attack")
		# The dodge and the interact were ONE button on a pad for a while, and this
		# merge is what kept the legend from printing "A DODGE   A INTERACT" and
		# asking the player to work out which one they got. They are B and A now
		# and neither branch fires — kept because the layout has moved before, and
		# a legend that silently prints a button twice is how you find out it moved
		# back.
		elif action == &"context" and _hotkey(&"interact") == cap:
			verb = "TAP=DODGE/TALK HOLD=RUN"
		elif action == &"interact" and _hotkey(&"context") == cap:
			continue  # already said, on the merged row above
		parts.append("%s %s" % [cap, verb])
	lines.append(parts)
	return lines


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
	var name_line := Prog.NAME
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

	# The level does NOT dim. It is the half of the card that carries the
	# information -- the name is a constant and you only need to be told it once
	# -- and a readout you have to squint at between rooms is one the player
	# stops consulting, which was the exact failure of the old bottom-edge line.
	CanvasText.draw_text(_canvas, level_line, Vector2(at.x, level_y), lt, Pal.BONE)


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

	# 1px VOID hairline OUTSIDE the bar, same containment rule the cells had.
	_note(&"health", &"pole", rect.grow(Pal.px(1.0, s.y)))
	_canvas.draw_rect(rect.grow(Pal.px(1.0, s.y)), Pal.VOID)
	_canvas.draw_rect(rect, Pal.VOID if low else Color(Pal.ASH, 0.6))

	var per := w / float(total)

	# The ghost sits UNDER the fill and extends past it: what you just lost.
	var ghost := _ghost_visible()
	if ghost > 0:
		_canvas.draw_rect(Rect2(origin.x + Game.quarters * per, origin.y,
			ghost * per, h), Pal.RUST)

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
	_canvas.draw_rect(Rect2(origin.x, origin.y, Game.quarters * per, h), fill)

	# Ticks last, cutting through fill and track alike -- that is what keeps the
	# bar countable. Heart boundaries are heavier than quarters.
	for i in range(1, total):
		var heart := i % K.HEART == 0
		var tw := Pal.px(HEART_TICK_W if heart else TICK_W, s.y)
		var th := h if heart else h * 0.45
		_canvas.draw_rect(Rect2(origin.x + i * per - tw * 0.5,
			origin.y + h - th, tw, th), Pal.VOID)


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

	_note(&"stamina", &"pole", rect.grow(Pal.px(1.0, s.y)))
	_canvas.draw_rect(rect.grow(Pal.px(1.0, s.y)), Pal.VOID)
	_canvas.draw_rect(rect, Color(Pal.ASH, 0.6))

	var frac: float = clampf(_stamina / maxf(Game.max_stamina, 1.0), 0.0, 1.0)
	# The whole point of the bar: RUST means the dodge button does nothing.
	var spent: bool = _stamina < K.STAMINA_ROLL
	_canvas.draw_rect(Rect2(origin.x, top, w * frac, h),
		Pal.RUST if spent else Pal.BONE)

	# Boundaries at each roll you can still afford, so the bar reads in DODGES
	# rather than in percent -- the only unit the player spends it in.
	for i in range(1, STAMINA_TICKS + 1):
		var at := K.STAMINA_ROLL * i / maxf(Game.max_stamina, 1.0)
		if at >= 1.0:
			break
		_canvas.draw_rect(Rect2(origin.x + w * at - Pal.px(1.0, s.y) * 0.5, top,
			Pal.px(1.0, s.y), h), Pal.VOID)


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

	_note(&"magic", &"pole", rect.grow(Pal.px(1.0, s.y)))
	_canvas.draw_rect(rect.grow(Pal.px(1.0, s.y)), Pal.VOID)
	_canvas.draw_rect(rect, Color(Pal.ASH, 0.6))

	var frac: float = clampf(float(_magic) / float(maxi(_max_magic, 1)), 0.0, 1.0)
	# The whole point of the bar, and the same sentence the stamina bar's RUST
	# says: dim means the trigger's hold will not light the blade. Drawn in MOTH
	# rather than RUST because this is not a danger -- you have not lost anything,
	# you have simply spent your spins, and the fight is still perfectly winnable
	# with the sword. RUST here would read as "you are about to die".
	var spent: bool = _magic < K.MAGIC_SPIN
	_canvas.draw_rect(Rect2(origin.x, top, w * frac, h),
		Pal.MOTH if spent else Pal.COBALT)

	# Boundaries at each spin still in the bar, so it reads in SPINS rather than
	# in percent -- the only unit it is ever spent in. Exactly the argument the
	# stamina bar's roll ticks make, and the reason both bars are ticked and the
	# heat bar is not: here the fill and the ticks measure the same quantity.
	var per := float(K.MAGIC_SPIN) / float(maxi(_max_magic, 1))
	var i := 1
	while per > 0.0 and per * float(i) < 1.0:
		_canvas.draw_rect(Rect2(origin.x + w * per * float(i) - Pal.px(1.0, s.y) * 0.5,
			top, Pal.px(1.0, s.y), h), Pal.VOID)
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
## a third empty meter under a control legend.

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
	_note(&"heat", &"pole", rect.grow(Pal.px(1.0, s.y)))
	_canvas.draw_rect(rect.grow(Pal.px(1.0, s.y)), Pal.VOID)
	_canvas.draw_rect(rect, Color(Pal.ASH, 0.6))

	var col := _heat_color()
	if Heat.kills > 0:
		_canvas.draw_rect(Rect2(origin.x, top, w * Heat.window01(), h), col)

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
## them put the caps THROUGH the health bar. Read it against `_draw_cpad`, which
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
		var counter := ArmamentDb.hand_count(id)
		var left := Game.ammo_count(counter)
		_draw_item_glyph(s, r, id, Pal.MIDNIGHT if raised else Color.BLACK,
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
func _draw_cpad(s: Vector2) -> void:
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
	_canvas.draw_rect(r, Pal.BONE if potion != &"" else Pal.ASH, false,
		Pal.px(2.0 if potion != &"" else 1.0, s.y))
	# `selected_item()` names the GLASS and `selected_potion()` what is in it.
	# The glyph wants the glass: a bottle with nothing in it still has to draw.
	_draw_item_glyph(s, r, Game.selected_item(), Color.BLACK, false,
		potion == &"")

	# How many bottles there are, so the player knows the ring has more stops.
	# Only past one — "1" under a single bottle is a count of a thing nobody is
	# counting.
	if Game.bottle_count() > 1:
		# 10 px and inset off its own height, for the reason the ammo numeral is
		# — same corner, same question, same decision 19.
		var csc := _text(10.0)
		CanvasText.draw_right(_canvas,
			"%d/%d" % [Game.item_selected + 1, Game.bottle_count()],
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
	MapDraw.draw_map(_canvas, frame.grow(-pad), s.y,
		get_tree().get_first_node_in_group(&"player") as Node3D)


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
func _draw_item_glyph(s: Vector2, r: Rect2, id: StringName,
		invert_to: Color, inverted: bool, dim: bool) -> void:
	if id == &"":
		return
	var bottle_at := Game.bottle_index(id)
	if bottle_at >= 0:
		_draw_bottle_glyph(s, r, Game.bottle(bottle_at))
		return
	var tex: Texture2D = _icons.get(id)
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


## How many tiles a draught slot empties through. Four, because four is the
## largest count §7.4 sanctions where it bans a lerp — the ghost drain uses the
## same number for the same reason — and because a 73 px slot divides into four
## tiles a player can count without counting.
const DRAUGHT_TILES := 4


## The row's slots, left to right, fixed forever. A draught earns a slot by having
## a duration, and `Game` already names the two that do — reading them from there
## rather than listing them here is the whole of decision 10's argument applied to
## a smaller table: a second copy is the one that goes stale.
func _draught_slots() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in PotionDb.IDS:
		if id == Game.DRAUGHT_PLATE_ID or id == Game.DRAUGHT_EDGE_ID:
			out.append(id)
	return out


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
## ## There are two slots, and the plan asked for three
##
## HUD_PLAN decision 21 specifies *"slot 0 heart, slot 1 ironhide, slot 2
## emberblood, in `PotionDb.IDS` order"*. **Heart Draught has no clock.**
## `PotionDb.apply` sends it to `Game.heal()` and never to `Game.start_draught`,
## so `Game.draught_left(&"heart_draught")` is 0.0 for the entire life of the
## game and slot 0 would be a container that can never fill — a worse lie than the
## empty row it was drawn to replace. So the row is every draught that HAS a
## clock, in `PotionDb.IDS` order: two today, three the day a third lasting
## draught is brewed, with no edit to this file. Recorded in docs/HUD_PLAN.md
## §15 rather than diverged from silently.
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
		var t01: float = clampf(Game.draught_left(id) / K.DRAUGHT_TIME, 0.0, 1.0)
		# An unlit slot's mark is ASH, not a dim tint: "you are not running this"
		# and "you are nearly out of this" must not be the same picture.
		var tint: Color = PotionDb.tint_of(id) if t01 > 0.0 else Color(Pal.ASH, 0.9)

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
			# A spent tile is a notch cut INTO the ash track rather than a paler
			# tile drawn on top of it, so the row reads as something emptying
			# instead of as something greying out. LIGHT, at 0.3: the first render
			# used 0.55 and an empty row — which is the row's commonest state and
			# the whole reason it is drawn at all — came out as two black bars
			# under the pole rather than as two empty containers.
			_canvas.draw_rect(tile, tint if t < lit else Color(Pal.VOID, 0.3))


## A draught's identity, as a shape. Two of these are drawn today and the third is
## written because the row grows by a slot the moment a third draught gets a clock
## (see `_draught_slots`) and a mark that arrives with it is one fewer thing to
## remember.
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
	var right := Pal.BAG_RIGHT * s.x
	_draw_rim(s, Pal.tier(_target_value))
	_draw_slips(s, right)


## A value histogram, not an inventory list. Slip width is that stack's share of
## the bag's worth, so the useful thought -- "most of my money is that one violet
## slip" -- is available at a glance, which no list gives you. With the total
## gone this is the only reading of the bag left out here, and it is deliberately
## a shape and not a figure.
func _draw_slips(s: Vector2, right: float) -> void:
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
	var max_w := SLIP_MAX_W * s.x
	var y := Pal.SLIPS_BOTTOM * s.y

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
		_canvas.draw_rect(slip, e["c"])
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

	# The stack, as one rectangle. Parent is the RIM: the slips are deliberately
	# inside it, and §14.5 warns that the first thing a new director reports is
	# the half-pixel overlap between the topmost slip and the rim's top frame — a
	# real geometric fact, and not a bug, once the nesting is declared.
	_note(&"slips", &"rim", Rect2(right - max_w, y,
		max_w, Pal.SLIPS_BOTTOM * s.y - y))


## Coloured by the rarity of the single most valuable thing you carry. Silent,
## permanent, peripheral -- it is how the bag whispers.
##
## **And it is not coloured ONLY.** The rim's entire information content used to
## be its hue, and the pair it has to separate hardest is `MOSS` (`68a050`)
## against `MOTH` (`807868`) — mid-green against mid-khaki at near-identical
## luminance, which is the textbook deutan collision. A colour-blind player could
## not tell *I am carrying something uncommon* from *I am carrying junk*, which is
## the one thing this corner exists to whisper. So rarity is now a THICKNESS as
## well: 2 px common, 2 px with an inner rule uncommon, 3 px rare, 3 px with a
## dithered ring legendary. Four weights, four hues, either channel sufficient.
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
	if _rim_flash_t >= 0.0:
		_canvas.draw_rect(r, Color(_rim_flash_color, 0.25))
		col = _rim_flash_color
	elif tier >= 2:
		# The dithered gold halo. One ring of 50% gold reads as a dither at the
		# distance a player actually sits from the screen. This one is about
		# VALUE, not rarity — it is outside the frame and gold; the legendary
		# ring below is inside it and the rarity's own colour, so the two can be
		# on screen together and still be two sentences.
		_canvas.draw_rect(r.grow(Pal.px(2.0, s.y)), Color(Pal.GOLD, 0.18), false,
			Pal.px(1.0, s.y))

	var thick := Pal.px(3.0 if rarity >= 2 else 2.0, s.y)
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
## already spoken for: the rim frames the bag from 0.786 to 0.914, the
## extraction fee sits at 0.940, and the control legend runs across 0.962 in
## garrison. There is no free row down there, and a notice that overlapped the
## fee would obscure the one number the player is standing still to read.
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
## on the axis the player is already looking down. It is the only thing the HUD
## ever draws in the middle of the screen, which is what makes it impossible to
## miss without needing to be large.
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

	var arm := Pal.px(8.0, s.y)
	var w := Pal.px(2.0, s.y)
	var col := Pal.RUST
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(half.x * sx, half.y * sy)
			_canvas.draw_rect(Rect2(
				corner.x - (arm if sx > 0 else 0.0), corner.y - w * 0.5,
				arm, w), col)
			_canvas.draw_rect(Rect2(
				corner.x - w * 0.5, corner.y - (arm if sy > 0 else 0.0),
				w, arm), col)

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
		_canvas.draw_rect(Rect2(x - b, c.y - b, w + b * 2.0, h + b * 2.0),
			Pal.BONE if elite else Pal.VOID)
		_canvas.draw_rect(Rect2(x, c.y, w, h), Color(Pal.ASH, 0.85))
		# Rounded to whole pixels, and never eased. Anti-slop §7.4.
		var fill := roundf(w * hp.fraction())
		if fill >= 1.0:
			_canvas.draw_rect(Rect2(x, c.y, fill, h), Pal.RUST)


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
