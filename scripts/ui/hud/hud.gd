extends CanvasLayer
## Autoload `Hud`. The in-game overlay, built to docs/STYLEGUIDE.md §5.
##
## TWO POLES. Bottom-left is YOU: the health and stamina bars and the kit strip,
## one instrument.
## Bottom-right is THE MONEY: the bag's running value and the way out, one
## instrument. They sit in opposite corners deliberately -- in a panic your eye
## has to travel from "how alive am I" to "how much am I about to lose", and that
## eye movement IS the game's central decision. The top of the screen stays empty
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
## Seconds the "+N HOT" line stays lit after it grows.
const HEAT_BANK_POP := 0.45

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
	&"bow": &"use_item",
	&"hookshot": &"use_item",
}
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
const ROLL_TIME := 0.30            ## the number eases to its new value
const TOAST_HOLD := 1.60
const TOAST_FADE := 0.20
const RIM_FLASH := 0.10

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
var _shown_value: float = 0.0      ## the number actually on screen, mid-roll
var _target_value: int = 0
var _toast: String = ""
var _toast_color: Color = Pal.MOTH
var _toast_t: float = -1.0
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
var _heat_bank_t: float = -1.0
## "(E) OPEN", or "" when there is nothing in reach. Owned by the Prompt autoload.
var _prompt: String = ""


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
	_shown_value = float(_target_value)
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
	Bus.quick_slots_changed.connect(_repaint)
	Bus.heat_changed.connect(_on_heat)
	Bus.heat_tier_changed.connect(_on_heat_tier)
	Bus.heat_banked.connect(_on_heat_banked)
	Bus.extract_refused.connect(_on_refused)
	Bus.homeward_broken.connect(_on_homeward_broken)
	Bus.shield_blocked.connect(_on_blocked)
	Bus.target_acquired.connect(_on_target)
	Bus.target_lost.connect(_on_target_lost)
	Bus.aim_changed.connect(_on_aim)
	Bus.prompt_changed.connect(_on_prompt)
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


## THE number, bottom right. In the dungeon it is what you are carrying, because
## that is what you are deciding about. In town it is what you own, because the
## bag is about to become that and nothing else on the screen says how rich you
## are. Same glyphs, same corner, same colour rules -- one instrument, two jobs.
func _headline() -> int:
	if Run == null:
		return 0
	return Run.bag_value() if Run.in_dungeon else Game.gold


func _on_bag(_bag: Dictionary, _value: int) -> void:
	_target_value = _headline()
	_wake()


func _on_gold(_gold: int) -> void:
	_target_value = _headline()
	_wake()


func _on_headline_changed(_a = null, _b = null, _c = null) -> void:
	_target_value = _headline()
	# Crossing town/dungeon should not roll a 900-gold purse up from a 40-gold
	# bag over a third of a second; that reads as an award, not a context change.
	_shown_value = float(_target_value)
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


func _on_heat_banked(_gold: int) -> void:
	_heat_bank_t = 0.0
	_wake()


func _on_prompt(text: String) -> void:
	_prompt = text
	_repaint()


func _on_refused(_cost: int, _gold: int) -> void:
	_refuse_t = 0.0
	_wake()


## Knocked out of the charm. Said as a toast rather than as a beep, because the
## player pressed a button in a menu and then arrived back in the world still in
## the dungeon -- without a sentence, that reads as the menu having eaten the
## input.
func _on_homeward_broken() -> void:
	_toast = "THE CHARM BREAKS"
	_toast_color = Pal.RUST
	_toast_t = 0.0
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
## The pad is gone (the way out is the Homeward Charm, used from the menu), so
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

	if not is_equal_approx(_shown_value, float(_target_value)):
		# Ease-out toward the new total. The roll is the dopamine; never snap.
		var step: float = maxf(1.0, absf(_target_value - _shown_value)) * (delta / ROLL_TIME)
		_shown_value = move_toward(_shown_value, float(_target_value), step)
		busy = true

	for t in [&"_toast_t", &"_rim_flash_t", &"_sweep_t", &"_refuse_t", &"_block_flash_t",
			&"_heat_break_t", &"_heat_bank_t"]:
		var v: float = get(t)
		if v >= 0.0:
			set(t, v + delta)
			busy = true
	if _toast_t > TOAST_HOLD + TOAST_FADE:
		_toast_t = -1.0
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
	if _heat_bank_t > HEAT_BANK_POP:
		_heat_bank_t = -1.0

	# T3 breathes, so the HUD keeps ticking while the bag is that valuable.
	if Pal.tier(_target_value) >= 3 or _lock_target != null or _extract_hold > 0.0:
		busy = true
	# A live chain is a countdown, and a countdown that only repaints on a signal
	# is a countdown that jumps. This is the one thing on the HUD that genuinely
	# wants a frame-by-frame repaint, and it stops the moment the chain is cold.
	if Heat.kills > 0:
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
	_draw_hands(s)
	_draw_cpad(s)
	_draw_bag(s)
	_draw_extraction(s)
	_draw_toast(s)
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
## actions the player rebinds).
const LEGEND := [
	[&"", "MOVE"],
	[&"", "LOOK"],
	[&"z_target", "LOCK-ON"],
	[&"attack", "SWORD (HOLD=CHARGE)"],
	[&"use_item", "USE/LUNGE"],
	# Two things are named here that a button-masher would never find: the dash,
	# which is a button you already know pressed in a stance you already know, and
	# the fact that the guard LOCKS. On the pad `shield` is the left trigger and
	# it is the whole of OOT's Z — the R3 above is only the standing toggle — so a
	# line that called this button GUARD would be hiding its main use.
	[&"shield", "GUARD/LOCK"],
	[&"context", "DODGE"],
	[&"interact", "INTERACT"],
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
	PixelFont.draw_centred(_canvas, _legend(),
		Vector2(s.x * 0.5, Pal.KEYS_BASELINE * s.y), scale, Pal.ASH)


func _legend() -> String:
	var sticks: Array = LEGEND_STICKS[Settings != null and Settings.using_pad]
	var parts: PackedStringArray = []
	var stick := 0
	for entry: Array in LEGEND:
		var action: StringName = entry[0]
		var verb: String = entry[1]
		if action == &"":
			parts.append("%s %s" % [sticks[stick], verb])
			stick += 1
			continue
		var cap := _hotkey(action)
		if cap.is_empty():
			continue  # nothing bound on this device — say nothing rather than lie
		if action == &"shield":
			verb = "GUARD/LOCK (+%s DASH)" % _hotkey(&"attack")
		parts.append("%s %s" % [cap, verb])
	return "    ".join(parts)


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
func _cross_origin(s: Vector2) -> Vector2:
	var cell := Pal.px(Pal.CELL, s.y)
	var gap := Pal.px(Pal.CELL_GAP, s.y)
	return Vector2(
		Pal.CLUSTER_RIGHT * s.x - (cell * 3.0 + gap * 2.0),
		Pal.CLUSTER_TOP * s.y)


## The hands sit to the LEFT of the cross and centred against its two rows, so
## the pair reads as its own group rather than as a third row of the D-pad.
func _hands_origin(s: Vector2) -> Vector2:
	var cell := Pal.px(Pal.CELL, s.y)
	var gap := Pal.px(Pal.CELL_GAP, s.y)
	var cross := _cross_origin(s)
	var cross_h := cell * 2.0 + gap
	return Vector2(
		cross.x - Pal.px(Pal.CLUSTER_GAP, s.y) - (cell * 2.0 + gap),
		cross.y + (cross_h - cell) * 0.5)


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


## The three item buttons, in the shape of the D-pad: ▲ above, ◄ and ► below it,
## with the ▼ direction marked as the loadout swap. The arrangement is the
## label -- a row of three cells would need three glyphs and the player would
## still have to translate "cell 2" into "up" every time (CONTRACT §2.5 #6).
func _draw_cpad(s: Vector2) -> void:
	var cell := Pal.px(Pal.CELL, s.y)
	var gap := Pal.px(Pal.CELL_GAP, s.y)
	var origin := _cross_origin(s)
	var mid := origin.x + cell + gap
	var held: StringName = Game.armament(Game.HAND_RIGHT)

	for entry in [
		{"slot": Game.QUICK_UP, "at": Vector2(mid, origin.y), "act": &"item_up"},
		{"slot": Game.QUICK_LEFT, "at": Vector2(origin.x, origin.y + cell + gap),
			"act": &"item_left"},
		{"slot": Game.QUICK_RIGHT, "at": Vector2(mid + cell + gap, origin.y + cell + gap),
			"act": &"item_right"},
	]:
		var slot: int = entry["slot"]
		var id: StringName = Game.quick(slot)
		var r := Rect2(entry["at"], Vector2(cell, cell))
		# The key cap goes on whether or not the slot is bound. An empty cell with
		# no cap is a hole; an empty cell with a "1" on it is an invitation.
		_draw_keycap(s, r, _hotkey(entry["act"]))

		_canvas.draw_rect(r, Color(Pal.MIDNIGHT, 0.8))
		# An unbound button is drawn EMPTY and dim rather than skipped. A gap in
		# the cross would break the shape, and the shape is the whole point.
		var drawn := id != &"" and id == held
		_canvas.draw_rect(r, Pal.BONE if drawn else Pal.ASH, false,
			Pal.px(2.0 if drawn else 1.0, s.y))
		_draw_item_glyph(s, r, id, Color.BLACK, false, false)

		if id == &"bow":
			PixelFont.draw_right(_canvas, str(Game.arrows),
				Vector2(r.end.x - Pal.px(3.0, s.y), r.end.y - Pal.px(10.0, s.y)),
				Pal.px(1.0, s.y), Pal.MOTH)

	# ▼ swaps the set. A caret rather than a cell: it is not a bindable button,
	# and drawing it as one would invite the player to try — which is also why it
	# is the one thing in the cluster with no key cap.
	#
	# Cleared past the bottom row's caps, not past the bottom row: the caps hang
	# below the cells they belong to, and the caret's old +3 px put it inside the
	# ◄ and ► lettering the moment the caps arrived.
	var caps_bottom := origin.y + cell * 2.0 + gap + Pal.px(Pal.KEYCAP_GAP, s.y) \
		+ PixelFont.height(Pal.px(Pal.KEYCAP_SCALE, s.y)) + Pal.px(3.0, s.y)
	var tip := Vector2(mid + cell * 0.5, caps_bottom + Pal.px(6.0, s.y))
	var w := Pal.px(9.0, s.y)
	var h := Pal.px(9.0, s.y)
	_canvas.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-w, 0.0), tip + Vector2(w, 0.0), tip + Vector2(0.0, h),
	]), Pal.ASH)


## One item's icon in a cell, or its two letters if the bake is missing. An
## empty hand draws nothing at all -- an "empty" glyph is still a glyph, and the
## cell border already says the slot is there.
func _draw_item_glyph(s: Vector2, r: Rect2, id: StringName,
		invert_to: Color, inverted: bool, dim: bool) -> void:
	if id == &"":
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


func _hero_combat() -> Node:
	var hero := get_tree().get_first_node_in_group(&"player")
	return hero.get(&"combat") if hero != null else null


# --- The bag (§5.3) ---------------------------------------------------------
## The most important object on screen. Four parts: the number, the value
## histogram, the rim, and the extraction line below it.

func _draw_bag(s: Vector2) -> void:
	var right := Pal.BAG_RIGHT * s.x
	var value := int(round(_shown_value))
	var tier := Pal.tier(_target_value)

	_draw_rim(s, tier)

	# The number. Tabular by construction -- PixelFont is monospaced -- so the
	# digits do not shuffle while the total rolls up.
	var scale := Pal.px(32.0 / PixelFont.H, s.y)
	var col := Pal.bag_color(_target_value)
	if tier >= 3:
		# Breathes. At T3 every hit also flickers it, so the game reminds you
		# what is at stake at the exact instant you are hurt.
		var b := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * 0.5)
		col = col.lerp(Pal.BONE, b * 0.35)
		if _ghost_t >= 0.0 and _ghost_t < 0.05:
			col = Pal.GOLD
	var top := Pal.BAG_NUM_BASELINE * s.y - PixelFont.height(scale)
	var diamond := Pal.px(16.0, s.y)
	_draw_diamond(Vector2(right - diamond * 0.5, top + PixelFont.height(scale) * 0.5),
		diamond * 0.5, Pal.GOLD)
	PixelFont.draw_right(_canvas, str(value),
		Vector2(right - diamond - Pal.px(6.0, s.y), top), scale, col)

	_draw_slips(s, right)
	_draw_premium(s, right)


## How much of that total is heat.
##
## The premium is already INSIDE the headline -- Run.bag_value() folds it in, so
## the fee above is charging for it too. This line exists because a number that
## is quietly larger than the drop tables can explain reads as a bug, and because
## it is the only place the game ever says out loud that killing fast was worth
## something. Take it away and heat is a multiplier the player has to infer from
## a vendor screen five minutes later.
func _draw_premium(s: Vector2, right: float) -> void:
	if Run.premium <= 0:
		return
	var scale := Pal.px(14.0 / PixelFont.H, s.y)
	var col: Color = Pal.GOLD
	if _heat_bank_t >= 0.0:
		# Lands BONE and settles to gold, so a pickup mid-fight registers in
		# peripheral vision without anything moving.
		col = Pal.BONE.lerp(Pal.GOLD, clampf(_heat_bank_t / HEAT_BANK_POP, 0.0, 1.0))
	PixelFont.draw_right(_canvas, "+%d HOT" % Run.premium,
		Vector2(right, Pal.PREMIUM_BASELINE * s.y), scale, col)


## A value histogram, not an inventory list. Slip width is that stack's share of
## the bag's worth, so the useful thought -- "most of my money is that one violet
## slip" -- is available at a glance, which no list gives you.
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
		_draw_arc_ring(centre, Pal.px(54.0, s.y), _extract_hold,
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
	if _toast_t < 0.0 or _toast.is_empty():
		return
	var a := 1.0
	if _toast_t > TOAST_HOLD:
		a = 1.0 - (_toast_t - TOAST_HOLD) / TOAST_FADE
	PixelFont.draw_right(_canvas, _toast,
		Vector2(Pal.BAG_RIGHT * s.x, Pal.TOAST_BASELINE * s.y),
		Pal.px(16.0 / PixelFont.H, s.y), Color(_toast_color, clampf(a, 0.0, 1.0)))


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
	_canvas.draw_rect(Rect2(centre.x - w * 0.5 - pad, centre.y - pad,
		w + pad * 2.0, h + pad * 2.0), Color(Pal.VOID, 0.72))
	PixelFont.draw_centred(_canvas, _prompt, centre, scale, Pal.BONE)


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

## The currency glyph. Drawn as a polygon rather than a font character because
## the styleguide bans icon sets and this is the one symbol the HUD repeats.
func _draw_diamond(centre: Vector2, r: float, col: Color) -> void:
	_canvas.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -r), centre + Vector2(r, 0.0),
		centre + Vector2(0.0, r), centre + Vector2(-r, 0.0),
	]), col)


func _draw_arc_ring(centre: Vector2, radius: float, t01: float,
		width: float, col: Color) -> void:
	if t01 <= 0.0:
		return
	_canvas.draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * t01,
		maxi(8, int(48 * t01)), col, width)
