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
const KIT_CELL := 32.0
const KIT_GAP := 6.0
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
	Bus.prompt_changed.connect(_on_prompt)
	Bus.run_started.connect(_on_headline_changed)
	Bus.run_ended.connect(_on_headline_changed)
	# Affordability moves when the purse moves or the bag moves, and on nothing
	# else -- those are exactly Run.can_extract()'s two inputs.
	Bus.gold_changed.connect(func(_g: int) -> void: _refresh_extract_available())
	Bus.bag_changed.connect(func(_b: Dictionary, _v: int) -> void: _refresh_extract_available())
	Bus.run_started.connect(func(_s: int) -> void: _refresh_extract_available())
	Bus.run_ended.connect(func(_e: bool, _c: Dictionary, _v: int) -> void:
		_refresh_extract_available())

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
	_draw_lock_on(s)
	_draw_sweep(s)
	_draw_controls(s)


# --- Controls -----------------------------------------------------------------
## A one-line legend, in town only.
##
## Not a tutorial and not a settings screen: the two combat verbs live on the
## mouse and there is nothing on screen that says so, which is exactly how a
## working sword reads as a broken one. Town is where you are safe and idle, so
## it is where the legend belongs; underground the line would be noise, and by
## then you have already used every verb on it.

const KEYS := "WASD MOVE    LMB ATTACK    F HEAVY    RMB GUARD    SPACE DODGE    MMB LOCK-ON    E INTERACT"


func _draw_controls(s: Vector2) -> void:
	if Run == null or Run.in_dungeon:
		return
	var scale := Pal.px(10.0 / PixelFont.H, s.y)
	PixelFont.draw_centred(_canvas, KEYS,
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

## The hands: what he is holding, left then right. Two cells, and both of them
## can be empty -- two-handing the sword is a real choice, not a broken state.
func _draw_hands(s: Vector2) -> void:
	var cell := Pal.px(KIT_CELL, s.y)
	var gap := Pal.px(KIT_GAP, s.y)
	var origin := Pal.KIT_ORIGIN * s
	var combat := _hero_combat()
	var blocking: bool = bool(combat.get(&"blocking")) if combat != null else false

	for i in HANDS.size():
		var hand: StringName = HANDS[i]
		var id: StringName = Game.armament(hand)
		var r := Rect2(origin.x + i * (cell + gap), origin.y, cell, cell)

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
	var cell := Pal.px(Pal.CPAD_CELL, s.y)
	var gap := Pal.px(Pal.CPAD_GAP, s.y)
	var origin := Pal.CPAD_ORIGIN * s
	var mid := origin.x + cell + gap
	var held: StringName = Game.armament(Game.HAND_RIGHT)

	for entry in [
		{"slot": Game.QUICK_UP, "at": Vector2(mid, origin.y)},
		{"slot": Game.QUICK_LEFT, "at": Vector2(origin.x, origin.y + cell + gap)},
		{"slot": Game.QUICK_RIGHT, "at": Vector2(mid + cell + gap, origin.y + cell + gap)},
	]:
		var slot: int = entry["slot"]
		var id: StringName = Game.quick(slot)
		var r := Rect2(entry["at"], Vector2(cell, cell))

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
	# and drawing it as one would invite the player to try.
	var tip := Vector2(mid + cell * 0.5, origin.y + (cell + gap) * 2.0 + Pal.px(3.0, s.y))
	var w := Pal.px(5.0, s.y)
	var h := Pal.px(5.0, s.y)
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

	# Only once the target has taken damage. Never a floating bar over every
	# enemy in the room.
	var hp := _health_of(_lock_target)
	if hp != null and hp.quarters < hp.max_quarters:
		var bw := half.x * 2.0
		var by := c.y + half.y + Pal.px(6.0, s.y)
		_canvas.draw_rect(Rect2(c.x - half.x, by, bw, Pal.px(2.0, s.y)),
			Color(Pal.ASH, 0.7))
		_canvas.draw_rect(Rect2(c.x - half.x, by, bw * hp.fraction(),
			Pal.px(2.0, s.y)), Pal.RUST)


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
