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
## Every colour comes from Pal and every glyph from PixelFont. Nothing here uses
## the engine's fallback font -- see the anti-slop list.

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
## Which action fires the thing in a cell. Keyed by ITEM, not by which hand or
## which corner, because that is the honest question: two-handing the sword moves
## the sword to the other hand and the button that swings it does not change.
## Rendered through _hotkey(), which reads the LIVE InputMap rather than printing
## a remembered "LMB" — CONTRACT §"The two ways this table has lied" #2:
## user://settings.cfg is replayed over the InputMap at boot and wins, so the
## shipped binding and the player's binding are different questions.
const KIT_ACTION := {
	&"sword": &"attack",
	&"shield": &"shield",
	# Both shoulder buttons fire a drawn item (`_tick_item_trigger`); the cap
	# names RB, the one a player already associates with "use what is in my
	# hand", rather than making the cell ask which trigger they meant.
	&"bow": &"attack",
	&"hookshot": &"attack",
}
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
## Icons baked from the REAL item models by tools/scenes/_iconbake.gd, then
## posterised into the Pal ramp so they read as authored in-palette rather than
## as photographs dropped into a 5-bit HUD. Regenerate with:
##   godot --path . res://tools/scenes/_iconbake.tscn -- --out=<abs>/assets/ui/icons/hud
##
## icons/hud/ is GENERATED and the baker overwrites all of it. Hand-authored or
## imported art belongs in icons/ proper -- do not put anything here you cannot
## afford to lose, and do not point this at icons/ or the next bake eats the
## imported source art (it already did once, to hookshot_pistol.png).
const KIT_ICON := {
	&"sword": "res://assets/ui/icons/hud/sword_knightly.png",
	&"shield": "res://assets/ui/icons/hud/kite_shield.png",
	&"hookshot": "res://assets/ui/icons/hud/hookshot_pistol.png",
	&"bow": "res://assets/ui/icons/hud/bow_knightly.png",
}
## Fallback lettering, used only for an icon that failed to load. A missing
## texture must not leave an empty cell -- an empty cell reads as "you have no
## sword", which is a lie the HUD should never tell.
const KIT_LABEL := {
	&"sword": "SW", &"shield": "SH", &"hookshot": "HK", &"bow": "BW",
	&"arrow": "AR", &"": "",
}

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

# --- Extraction (§5.4) -------------------------------------------------------
const SWEEP_TIME := 0.20
const HOLD_TO_EXTRACT := 1.50

var _canvas: Control
var _icons: Dictionary[StringName, Texture2D] = {}
## Stamina, mirrored from Game so the bar can be redrawn without polling.
var _stamina: float = K.MAX_STAMINA

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
var _rim_flash_t: float = -1.0
var _rim_flash_color: Color = Pal.MOTH
var _sweep_t: float = -1.0
## 0..1 while the player holds the extract button at a node.
var _extract_hold: float = 0.0
var _extract_available: bool = false
var _refuse_t: float = -1.0
var _block_flash_t: float = -1.0
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

	for id: StringName in KIT_ICON:
		var tex := load(String(KIT_ICON[id])) as Texture2D
		if tex == null:
			push_warning("Hud: kit icon missing for '%s' — falling back to lettering" % id)
		else:
			_icons[id] = tex

	Bus.player_health_changed.connect(_on_health)
	Bus.stamina_changed.connect(_on_stamina)
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
	Bus.heat_changed.connect(_on_heat)
	Bus.heat_tier_changed.connect(_on_heat_tier)
	Bus.extract_refused.connect(_on_refused)
	Bus.escape_rope_broken.connect(_on_escape_rope_broken)
	Saves.autosaved.connect(_on_autosaved)
	Bus.shield_blocked.connect(_on_blocked)
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
	Bus.run_started.connect(_on_headline_changed)
	Bus.run_ended.connect(_on_headline_changed)
	# Affordability moves when the purse moves or the bag moves, and on nothing
	# else -- those are exactly Run.can_extract()'s two inputs.
	Bus.gold_changed.connect(func(_g: int) -> void: _refresh_extract_available())
	Bus.bag_changed.connect(func(_b: Dictionary, _v: int) -> void: _refresh_extract_available())
	Bus.run_started.connect(func(_s: int) -> void: _refresh_extract_available())
	Bus.run_ended.connect(func(_e: bool, _c: Dictionary, _v: int) -> void:
		_refresh_extract_available())

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


## What the bag is worth, always -- in town as well, where it is normally zero.
##
## This USED to be a number in the bottom-right corner, and in town it showed the
## purse instead. Both are gone. A running gold total on screen turns every room
## into an accounting screen: the player reads the number, not the room, and the
## extraction decision stops being "is this worth the walk back" and becomes
## "has the number gone up". Money is now something you go and LOOK at -- the
## pouch screen, or a vendor's counter -- which is where a decision about it is
## actually made. What stays out here is only what is at stake: the rim's colour,
## the slips, and the extraction fee beside it.
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


func _on_refused(_cost: int, _gold: int) -> void:
	_refuse_t = 0.0
	_wake()


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


func _on_blocked(_at: Vector3, _normal: Vector3) -> void:
	_block_flash_t = 0.0
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


## "You can leave right now."
##
## This used to mean "you are standing on the rune pad", and the pad called it.
## The pad is gone (the way out is the Escape Rope, used from the menu), so
## availability is no longer about WHERE you are -- it is about whether you can
## afford the fee, which is the only thing that can still stop you. The sweep
## therefore fires the moment leaving becomes possible again, which is a more
## useful moment than the old one: crossing back over the fee line mid-run is a
## fact the player cannot otherwise see coming.
##
## Still public because tools/directors/hud_lookdev.gd forces it on to shoot the
## emphasised state.
func set_extract_available(on: bool) -> void:
	if on == _extract_available:
		return
	_extract_available = on
	if on:
		_sweep_t = 0.0
	_wake()


func _refresh_extract_available() -> void:
	set_extract_available(Run != null and Run.can_extract())


func set_extract_hold(t01: float) -> void:
	_extract_hold = clampf(t01, 0.0, 1.0)
	_repaint()


func _wake() -> void:
	set_process(true)
	_canvas.queue_redraw()


func _on_tree_changed(_n: Node) -> void:
	_refresh_visibility.call_deferred()


## Gameplay scenes have a hero; lookdev boxes and tool scenes do not, and an
## overlay on a weapon rack is just noise in a contact sheet.
func _refresh_visibility() -> void:
	if not is_inside_tree():
		return
	var has_player := get_tree().get_first_node_in_group(&"player") != null
	if visible != has_player:
		visible = has_player

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

	for t in [&"_toast_t", &"_save_t", &"_rim_flash_t", &"_sweep_t", &"_refuse_t",
			&"_block_flash_t", &"_heat_break_t"]:
		var v: float = get(t)
		if v >= 0.0:
			set(t, v + delta)
			busy = true
	if _toast_t > TOAST_HOLD + TOAST_FADE:
		_toast_t = -1.0
	if _save_t > SAVE_HOLD + SAVE_FADE:
		_save_t = -1.0
	if _rim_flash_t > RIM_FLASH:
		_rim_flash_t = -1.0
	if _sweep_t > SWEEP_TIME:
		_sweep_t = -1.0
	if _refuse_t > 1.2:
		_refuse_t = -1.0
	if _block_flash_t > 0.06:
		_block_flash_t = -1.0
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

	_canvas.queue_redraw()
	if not busy:
		set_process(false)


func _draw_hud() -> void:
	var s := _canvas.size
	if s.x < 1.0 or s.y < 1.0:
		return
	_draw_health(s)
	_draw_stamina(s)
	_draw_heat(s)
	_draw_draughts(s)
	_draw_hands(s)
	_draw_cpad(s)
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


# --- Controls -----------------------------------------------------------------
## A one-line legend, in town only.
##
## Not a tutorial and not a settings screen: the two combat verbs live on the
## mouse and there is nothing on screen that says so, which is exactly how a
## working sword reads as a broken one. Town is where you are safe and idle, so
## it is where the legend belongs; underground the line would be noise, and by
## then you have already used every verb on it.

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
	# ← → ↓ ↑ and not ◄ ► ▼ ▲: PixelFont has the four thin arrows and none of the
	# four solid triangles, so the pretty ones came out as MISSING blocks.
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
	var scale := Pal.px(10.0 / PixelFont.H, s.y)
	var lines := _legend()
	# Drawn UPWARDS from the baseline, so adding a row pushes the legend into the
	# empty floor above it rather than off the bottom of the screen.
	var step := PixelFont.height(scale) + Pal.px(5.0, s.y)
	var top := Pal.KEYS_BASELINE * s.y - step * (lines.size() - 1)
	for i in lines.size():
		PixelFont.draw_centred(_canvas, lines[i],
			Vector2(s.x * 0.5, top + step * i), scale, Pal.ASH)


func _legend() -> PackedStringArray:
	var sticks: Array = LEGEND_STICKS[Settings != null and Settings.using_pad]
	var lines: PackedStringArray = []
	var parts: PackedStringArray = []
	var stick := 0
	for entry: Array in LEGEND:
		var action: StringName = entry[0]
		var verb: String = entry[1]
		if action == LEGEND_BREAK:
			lines.append("    ".join(parts))
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
	lines.append("    ".join(parts))
	return lines


## How deep you are, on the line the controls legend uses in town.
##
## The two are exclusive by construction: the legend is the thing you need when
## you are safe and idle, and the floor is the thing you need when you are not.
## Sharing the baseline means neither is ever noise, and the strip at the bottom
## of the screen always says exactly one useful thing.
##
## Drawn dim. It is a number you glance at between rooms to decide whether to go
## on, not a score -- the bag in the corner is the score.
func _draw_floor(s: Vector2) -> void:
	if Run == null or not Run.in_dungeon:
		return
	var scale := Pal.px(10.0 / PixelFont.H, s.y)
	PixelFont.draw_centred(_canvas, Prog.label(Run.level),
		Vector2(s.x * 0.5, Pal.KEYS_BASELINE * s.y), scale, Pal.ASH)


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
	_canvas.draw_rect(rect.grow(Pal.px(1.0, s.y)), Pal.VOID)
	_canvas.draw_rect(rect, Pal.VOID if low else Color(Pal.ASH, 0.6))

	var per := w / float(total)

	# The ghost sits UNDER the fill and extends past it: what you just lost.
	var ghost := _ghost_visible()
	if ghost > 0:
		_canvas.draw_rect(Rect2(origin.x + Game.quarters * per, origin.y,
			ghost * per, h), Pal.RUST)

	var fill: Color = Pal.VITAL.lerp(Pal.BONE, pulse) if low else Pal.VITAL
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
	var top := origin.y + Pal.px(Pal.HEALTH_H, s.y) + Pal.px(Pal.STAMINA_GAP, s.y)
	var w := Pal.HEALTH_W * s.x * Pal.STAMINA_RATIO
	var h := Pal.px(Pal.STAMINA_H, s.y)
	var rect := Rect2(origin.x, top, w, h)

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
## Dungeon only. In town there is nothing to chain and the bar would be a third
## empty meter under a control legend.

func _draw_heat(s: Vector2) -> void:
	if Run == null or not Run.in_dungeon:
		return

	var origin := Pal.HEALTH_ORIGIN * s
	var top := origin.y + Pal.px(Pal.HEALTH_H, s.y) + Pal.px(Pal.STAMINA_GAP, s.y) \
		+ Pal.px(Pal.STAMINA_H, s.y) + Pal.px(Pal.HEAT_GAP, s.y)
	var w := Pal.HEALTH_W * s.x * Pal.HEAT_RATIO
	var h := Pal.px(Pal.HEAT_H, s.y)
	var rect := Rect2(origin.x, top, w, h)

	# The track is drawn even at zero, so the bar is a thing the player has seen
	# before the first time it matters. An instrument that only appears once you
	# are already doing well teaches nobody.
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
	var scale := Pal.px(10.0 / PixelFont.H, s.y)
	# String.num rather than "%.2f": it drops trailing zeros, so the ramp reads
	# X1 / X1.25 / X1.6 / X2.2 instead of a column of dead decimals.
	var label := "x" + String.num(Heat.multiplier(), 2)
	PixelFont.draw_centred(_canvas, label,
		Vector2(origin.x + w + Pal.px(22.0, s.y),
			top + (h - PixelFont.height(scale)) * 0.5),
		scale, col)


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

## Where the two groups sit. Laid out from the cluster's RIGHT edge and not from
## a left-edge fraction, so that doubling the cell size moves the left edge left
## instead of pushing the cross off the screen. The cross is the anchor because
## it is the one whose SHAPE carries meaning: it has to stay a cross, in the
## corner, whatever the hands beside it are doing.
##
## THE CLUSTER IS THREE CELLS NOW, not six, and that is the whole story of this
## change: [left hand][right hand] and one selected item beside them. There were
## four bindable D-pad cells here and the D-pad does not bind anything any more.
##
## Measured from the right edge inwards, so widening a cell moves the left edge
## left instead of pushing the cluster off screen.
##
## THE CARET RULE, which the whole cluster reads by: a caret ABOVE a cell is the
## D-pad direction that cycles that cell. ← → over the right hand, ↓ over the
## item. Nothing else in the cluster draws a triangle, so a triangle always means
## "a direction changes this".
func _cross_origin(s: Vector2) -> Vector2:
	return Vector2(
		Pal.CLUSTER_RIGHT * s.x - Pal.px(Pal.CELL, s.y),
		Pal.CLUSTER_TOP * s.y + _caret_band(s))


## Height reserved above the cells for the carets. Every cell in the cluster is
## pushed down by it whether or not it has one, so the tops stay in a line.
func _caret_band(s: Vector2) -> float:
	return Pal.px(CARET * 2.0 + CARET_GAP, s.y)


## The hands sit to the LEFT of the item and share its top edge.
func _hands_origin(s: Vector2) -> Vector2:
	var cell := Pal.px(Pal.CELL, s.y)
	var gap := Pal.px(Pal.CELL_GAP, s.y)
	var cross := _cross_origin(s)
	return Vector2(
		cross.x - Pal.px(Pal.CLUSTER_GAP, s.y) - (cell * 2.0 + gap), cross.y)


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
## that goes stale — see the note on KIT_ACTION.
func _hotkey(action: StringName) -> String:
	return Glyph.cap(action)


## The key cap: the binding, centred under its cell. Drawn BEFORE the cell so a
## cap never lands on top of the icon it belongs to.
func _draw_keycap(s: Vector2, cell: Rect2, key: String) -> void:
	if key.is_empty():
		return
	var scale := Pal.px(Pal.KEYCAP_SCALE, s.y)
	var top := cell.end.y + Pal.px(Pal.KEYCAP_GAP, s.y)
	var w := PixelFont.width(key, scale)
	var h := PixelFont.height(scale)
	var pad := Pal.px(3.0, s.y)
	# On its own plate, not bare on the scene. The cells have a MIDNIGHT fill and
	# the caps hang BELOW them, so a bare cap sits on whatever the world happens
	# to be — ASH lettering over a torchlit wall is nearly gone. It also earns the
	# metaphor: a key cap should look like a key.
	_canvas.draw_rect(Rect2(
		cell.get_center().x - w * 0.5 - pad, top - pad,
		w + pad * 2.0, h + pad * 2.0), Color(Pal.MIDNIGHT, 0.8))
	PixelFont.draw_centred(_canvas, key,
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
			_draw_caret(s, Vector2(r.position.x, mid), Vector2(-1.0, 0.0))
			_draw_caret(s, Vector2(r.end.x, mid), Vector2(1.0, 0.0))
		_draw_keycap(s, r, _hotkey(KIT_ACTION.get(id, &"")))

		# The shield cell IS the block tell. It was the one thing the old strip
		# did that nothing else does, so it survives the strip.
		var raised := id == &"shield" and blocking
		var fill := Color(Pal.MIDNIGHT, 0.8)
		if raised:
			fill = Pal.BONE
		if id == &"shield" and _block_flash_t >= 0.0:
			fill = Pal.RUST
		_canvas.draw_rect(r, fill)
		_canvas.draw_rect(r, Pal.ASH, false, Pal.px(1.0, s.y))

		_draw_item_glyph(s, r, id, Pal.MIDNIGHT if raised else Color.BLACK,
			raised, id == &"arrow" and Game.arrows <= 0)
		if id == &"arrow":
			PixelFont.draw_right(_canvas, str(Game.arrows),
				Vector2(r.end.x - Pal.px(3.0, s.y), r.end.y - Pal.px(10.0, s.y)),
				Pal.px(1.0, s.y), Pal.MOTH)


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
	_draw_caret(s, Vector2(r.get_center().x, origin.y - Pal.px(CARET_GAP, s.y)),
		Vector2(0.0, 1.0))
	# The cap is X, the button that USES it — not the direction that selects it.
	# A cell caps with the button you press to make it happen, and selecting an
	# item does not make anything happen.
	_draw_keycap(s, r, _hotkey(&"use_item"))

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
		PixelFont.draw_right(_canvas,
			"%d/%d" % [Game.item_selected + 1, Game.bottle_count()],
			Vector2(r.end.x - Pal.px(3.0, s.y), r.end.y - Pal.px(10.0, s.y)),
			Pal.px(1.0, s.y), Pal.MOTH)

	# The loadout, on its own row under the key caps.
	#
	# ON A PLATE, and with an ARROW the font actually has. It was "\u25b2 PRIMARY"
	# in bare ASH for one render: PixelFont has no ▲ (its arrows are ↑ ↓ ← →), so
	# the glyph came out as the MISSING block, and ASH lettering laid straight
	# over a torchlit wall was barely there. Right-aligned to the cluster's edge
	# like everything else in it, so the widest word (ALTERNATE) grows leftwards
	# under the hands rather than off the screen.
	var scale := Pal.px(Pal.KEYCAP_SCALE, s.y)
	var line := "\u2191 PRIMARY" if Game.loadout_set == Game.PRIMARY \
		else "\u2191 ALTERNATE"
	var top := r.end.y + Pal.px(Pal.KEYCAP_GAP, s.y) + PixelFont.height(scale) \
		+ Pal.px(9.0, s.y)
	var w := PixelFont.width(line, scale)
	var pad := Pal.px(3.0, s.y)
	_canvas.draw_rect(Rect2(r.end.x - w - pad, top - pad,
		w + pad * 2.0, PixelFont.height(scale) + pad * 2.0),
		Color(Pal.MIDNIGHT, 0.8))
	PixelFont.draw_right(_canvas, line, Vector2(r.end.x, top), scale, Pal.MOTH)


## One caret, `dir` being the unit direction it points. `tip` is where the point
## lands. Drawn rather than typeset because the HUD's PixelFont has no arrow
## glyphs and a "^" is not a caret.
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
	PixelFont.draw_centred(_canvas, String(KIT_LABEL.get(id, "?")),
		Vector2(r.get_center().x, r.position.y + r.size.y * 0.32),
		Pal.px(2.0, s.y), label_col)


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


## The lasting draughts, as a countdown under the heat bar: a pip in the potion's
## own colour, draining left to right.
##
## It shares the stamina/heat column because it is the same KIND of fact — a
## thing that is true right now and will not be shortly — and because the player
## is already watching that column when they are deciding whether to drink.
## Nothing is drawn when nothing is running: an empty slot for a buff you do not
## have is a permanent reminder of an absence.
##
## The stack arithmetic below is spelled out term by term ON PURPOSE. It was
## written once as a short sum that left `HEALTH_H` out, and the row landed
## exactly ON the stamina bar -- two instruments in one rectangle, the label
## sitting inside the dodge meter. Every check in alchemy_loop.gd passed while
## it did that, because none of them can see a rectangle. Copy the shape of
## `_draw_stamina` / `_draw_heat` rather than deriving a new offset.
func _draw_draughts(s: Vector2) -> void:
	var live: Array[StringName] = []
	for id in PotionDb.IDS:
		if Game.draught_left(id) > 0.0:
			live.append(id)
	if live.is_empty():
		return

	var x := Pal.HEALTH_ORIGIN.x * s.x
	var w := Pal.HEALTH_W * s.x * Pal.HEAT_RATIO
	var h := Pal.px(Pal.HEAT_H, s.y)
	# Slot four, under health -> stamina -> heat, in that order. Heat is dungeon
	# only, so in town its slot is empty and the draughts move UP into it: two
	# rows hanging below an absent bar would collide with the control legend,
	# which owns the bottom of the town screen (see _draw_controls).
	var y := Pal.HEALTH_ORIGIN.y * s.y \
		+ Pal.px(Pal.HEALTH_H + Pal.STAMINA_GAP + Pal.STAMINA_H + Pal.HEAT_GAP, s.y)
	if Run != null and Run.in_dungeon:
		y += Pal.px(Pal.HEAT_H + Pal.HEAT_GAP, s.y)

	for id in live:
		var t01: float = clampf(Game.draught_left(id) / K.DRAUGHT_TIME, 0.0, 1.0)
		var tint := PotionDb.tint_of(id)
		var rect := Rect2(x, y, w, h)
		# Same two-layer construction as the bars above it -- a hairline of VOID
		# around an ASH track -- so the column reads as one instrument family
		# rather than as a loose pip that wandered in.
		_canvas.draw_rect(rect.grow(Pal.px(1.0, s.y)), Pal.VOID)
		_canvas.draw_rect(rect, Color(Pal.ASH, 0.6))
		_canvas.draw_rect(Rect2(x, y, w * t01, h), tint)
		PixelFont.draw_text(_canvas, PotionDb.short_of(id),
			Vector2(x + w + Pal.px(6.0, s.y), y - Pal.px(2.0, s.y)),
			Pal.px(1.0, s.y), tint)
		# Tighter than HEAT_GAP between rows: two draughts plus the gap have to
		# fit above the legend in town, and they are one fact, not two columns.
		y += h + Pal.px(2.0, s.y)


func _hero_combat() -> Node:
	var hero := get_tree().get_first_node_in_group(&"player")
	return hero.get(&"combat") if hero != null else null


# --- The bag (§5.3) ---------------------------------------------------------
## What you are carrying, said WITHOUT a number: the rim's colour and the value
## histogram. The extraction line below it is the only figure left in this corner.
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
		_canvas.draw_rect(Rect2(right - w, y - h, w, h), e["c"])
		y -= h + gap

	if entries.size() > SLIP_MAX:
		PixelFont.draw_right(_canvas, "+%d" % (entries.size() - SLIP_MAX),
			Vector2(right, y - Pal.px(8.0, s.y)), Pal.px(1.0, s.y), Pal.MOTH)


## Coloured by the rarity of the single most valuable thing you carry. Silent,
## permanent, peripheral -- it is how the bag whispers.
func _draw_rim(s: Vector2, tier: int) -> void:
	var tl := Pal.RIM_TL * s
	var br := Pal.RIM_BR * s
	var r := Rect2(tl, br - tl)
	var col := Pal.rarity_color(_best_rarity())
	if _rim_flash_t >= 0.0:
		_canvas.draw_rect(r, Color(_rim_flash_color, 0.25))
		col = _rim_flash_color
	elif tier >= 2:
		# The dithered gold halo. One ring of 50% gold reads as a dither at the
		# distance a player actually sits from the screen.
		_canvas.draw_rect(r.grow(Pal.px(2.0, s.y)), Color(Pal.GOLD, 0.18), false,
			Pal.px(1.0, s.y))
	_canvas.draw_rect(r, col, false, Pal.px(2.0, s.y))


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
## Directly under the bag number, because the decision is a comparison between
## two numbers and they must be adjacent.

func _draw_extraction(s: Vector2) -> void:
	if not Run.in_dungeon:
		return
	var right := Pal.BAG_RIGHT * s.x
	var y := Pal.EXTRACT_BASELINE * s.y
	var cost := Run.extract_cost()
	var afford := Game.gold >= cost

	var scale := Pal.px((16.0 if _extract_available else 12.0) / PixelFont.H, s.y)
	var label_col: Color = Pal.CYAN if _extract_available else Pal.MOTH
	var cost_col: Color = Pal.GOLD if afford else Pal.RUST

	if _refuse_t >= 0.0:
		PixelFont.draw_right(_canvas, "NEED %d" % cost, Vector2(right, y),
			scale, Pal.RUST)
		return

	var cost_s := str(cost)
	PixelFont.draw_right(_canvas, cost_s, Vector2(right, y), scale, cost_col)
	var label_x := right - PixelFont.width(cost_s, scale) - Pal.px(8.0, s.y)
	PixelFont.draw_right(_canvas, "EXTRACT", Vector2(label_x, y), scale, label_col)

	if _extract_available:
		# A square pip, set well clear of the word. A full-height 2px bar six
		# pixels from the E is a capital I in this font, and the line read
		# "IEXTRACT" on every capture until it was a pip instead.
		var pip := Pal.px(6.0, s.y)
		var lx := label_x - PixelFont.width("EXTRACT", scale) - Pal.px(14.0, s.y)
		_canvas.draw_rect(Rect2(lx - pip, y + (PixelFont.height(scale) - pip) * 0.5,
			pip, pip), Pal.CYAN)

	# Holding draws a ring around your own money while the world stays live.
	# The cost is paid out of the thing you are protecting, and the UI says so.
	if _extract_hold > 0.0:
		var centre := Vector2(right - Pal.px(40.0, s.y),
			Pal.BAG_NUM_BASELINE * s.y - Pal.px(16.0, s.y))
		HoldGauge.ring(_canvas, centre, Pal.px(54.0, s.y), _extract_hold,
			Pal.px(3.0, s.y), Pal.CYAN)


## One screen-wide event, then silence. A permanent "you can extract" banner
## nags, and a sound alone is missable in combat.
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
	PixelFont.draw_right(_canvas, _toast,
		Vector2(Pal.BAG_RIGHT * s.x, Pal.TOAST_BASELINE * s.y),
		Pal.px(16.0 / PixelFont.H, s.y), Color(_toast_color, clampf(a, 0.0, 1.0)))


## AUTOSAVING…, bottom right, on the toast's baseline.
##
## The same line, and not a line of its own, because the corner below it is
## already spoken for: the rim frames the bag from 0.786 to 0.914, the
## extraction fee sits at 0.940, and the control legend runs across 0.962 in
## town. There is no free row down there, and a notice that overlapped the fee
## would obscure the one number the player is standing still to read.
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
	PixelFont.draw_right(_canvas, "AUTOSAVING...",
		Vector2(Pal.BAG_RIGHT * s.x, Pal.TOAST_BASELINE * s.y),
		Pal.px(14.0 / PixelFont.H, s.y), Color(Pal.MOTH, clampf(a, 0.0, 1.0)))


## The interact line. Centred and low -- under the action, above the kit strip,
## on the axis the player is already looking down. It is the only thing the HUD
## ever draws in the middle of the screen, which is what makes it impossible to
## miss without needing to be large.
func _draw_prompt(s: Vector2) -> void:
	if _prompt.is_empty():
		return
	var scale := Pal.px(14.0 / PixelFont.H, s.y)
	var w := PixelFont.width(_prompt, scale)
	var h := PixelFont.height(scale)
	var centre := Vector2(s.x * 0.5, s.y * 0.735)
	var pad := Pal.px(7.0, s.y)
	var box := Rect2(centre.x - w * 0.5 - pad, centre.y - pad,
		w + pad * 2.0, h + pad * 2.0)
	_canvas.draw_rect(box, Color(Pal.VOID, 0.72))
	PixelFont.draw_centred(_canvas, _prompt, centre, scale, Pal.BONE)

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
