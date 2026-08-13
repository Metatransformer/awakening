extends Node
## Autoload `Heat`. Momentum: how fast you are killing, and what that is worth.
##
## The game already prices greed in SPACE -- how deep you go, what the fee costs
## to bank it. It never priced greed in TIME. Nothing punished standing still, so
## the optimal line was pull one enemy, kill it, stop, hoover the drops, breathe,
## repeat, forever. This is the second axis: a chain that pays you for not
## stopping, and takes the pay back if you do.
##
##   kill             -> the chain grows, the window refreshes, stamina returns
##   the window ends  -> you drop a tier
##   a blow LANDS     -> you drop a tier
##   a blow you BLOCK -> nothing, because blocking costs no health
##
## That last rule is not special-cased anywhere. Heat watches
## `Bus.player_health_changed`, and a blocked blow never changes health, so the
## shield being the tempo tool falls out of the wiring rather than out of an if.
## It is the same rule the Escape Rope already channels under
## (docs/METAGAME.md §5), which is why it should feel familiar rather than new.
##
## HEAT IS WORTH MONEY, NEVER POWER. It does not raise damage, reach, or speed.
## docs/GDD.md §4 pillar 4 -- "permanence is bought, never found" -- is what
## makes a great run a decision instead of an automatic one, and a chain that
## made the hero stronger would quietly delete the smith. What heat does instead
## is stamp value onto the loot you sweep while it is lit (see LootMote), which
## lands in `Run.premium`, folds into `Run.bag_value()`, and therefore raises the
## extraction fee by itself: a hot run costs more to bank, and no fee code had to
## know that heat exists.

## Kills in the current chain. Not a score -- it resets, and it steps DOWN.
var kills: int = 0
## 0..3. Cold, Warm, Hot, Blazing.
var tier: int = 0
## Seconds left before the chain drops a tier.
var window: float = 0.0
## Highest tier reached this run. Nothing reads it yet; the run summary will.
var peak_tier: int = 0

## The Sustain-Verse is cast and waiting to be spent (`docs/GDD.md` §6.5 -- "the
## Heat chain holds through **one** break"). Public because the HUD and the
## director both want to say whether it is up, and because a working you cannot
## see the state of is a charge you will spend twice.
##
## It is ONE break and not a duration, which is the whole shape of the item: a
## timed ward would be a buff you cast before a fight, and this is a thing you
## cast because you can feel the window running out. It survives a scene change
## and dies with the run, like the chain it defends -- `reset()` clears it.
var sustained: bool = false

## Mirrored so a health signal can be read as "he was hurt" rather than "health
## is now N" -- Bus.player_health_changed carries no delta.
##
## Seeded from Game rather than left at a sentinel. Nothing emits
## player_health_changed at spawn, so a sentinel meant the FIRST blow of a
## session was always read as "health went UP from -1" and never broke a chain.
## That is a bug you cannot see by playing: the first hit is free, every hit
## after it works, and the meter looks correct the whole time.
var _last_quarters: int = 0


func _ready() -> void:
	# PROCESS_MODE_PAUSABLE (the default) is right: the chain must not tick down
	# while the pause menu is up. Leaving is decided in that menu, and a player
	# who opens it to read the fee should not come back to a cold bar.
	Bus.enemy_died.connect(_on_enemy_died)
	Bus.player_health_changed.connect(_on_health_changed)
	Bus.shield_blocked.connect(_on_blocked)
	Bus.run_started.connect(func(_s: int) -> void: reset())
	Bus.run_ended.connect(func(_e: bool, _c: Dictionary, _v: int) -> void: reset())
	reset()


func reset() -> void:
	kills = 0
	tier = 0
	window = 0.0
	peak_tier = 0
	sustained = false
	# Both ends of a run restore health, and re-reading it here is what stops the
	# heal that follows a death from being mistaken for a blow on the next run.
	_last_quarters = Game.quarters
	_announce()


# --- Frame ------------------------------------------------------------------

## Only the STEP is announced, never the countdown. A signal every frame would
## drag the HUD out of its repaint-on-signal architecture and into polling; the
## HUD instead keeps itself awake while a chain is live and reads window01()
## when it draws, exactly as it already reads Game.quarters.
func _process(delta: float) -> void:
	if kills <= 0:
		return
	window -= delta
	if window <= 0.0:
		_step_down(false)


# --- What moves it ----------------------------------------------------------

## A body dropped. Grows the chain, refreshes the window, and hands stamina back.
##
## The stamina refund lives here rather than in HeroCombat because it is not a
## property of the swing -- it is the chain paying for its own continuation. At
## 40 against K.STAMINA_ROLL's 34, a kill buys the roll that reaches the next
## enemy, which is the only reason a 2.5 s window is survivable at OOT's swing
## lengths. It is transient, so pillar 4 survives: nothing here outlives the run.
func _on_enemy_died(_enemy: Node3D, _position: Vector3) -> void:
	# Garrison has training posts and no stakes. A chain built on the practice
	# dummies would arrive in the dungeon pre-lit, which is the one thing the
	# depth bands exist to prevent (docs/GDD.md §5).
	if not Run.in_dungeon:
		return

	_advance()


## One step of the chain: grow it, refresh the window, hand stamina back.
##
## Split out of `_on_enemy_died` so the Answering Strike has something to call.
## A blocked blow that duplicated these six lines would be a second definition of
## what a step IS, and the first tuning pass would move one of them.
func _advance() -> void:
	kills += 1
	var next := _tier_for(kills)
	# maxi(next, 1): a cold chain still runs on tier 1's clock, so the first kill
	# expires instead of sitting lit until you happen to find a second one.
	#
	# The Held Note (`EchoDb.HELD_NOTE`) is the one term that is not the table:
	# every tier keeps Warm's leash, so the reward for going fast stops coming
	# with a shorter one (`docs/PUZZLES.md` §6.1, row 1).
	var rung := maxi(next, 1)
	if Run.has_echo(EchoDb.HELD_NOTE):
		rung = 1
	window = K.HEAT_TIER_WINDOW[rung]
	# The Second Wind (row 4) returns the WHOLE bar rather than `K.STAMINA_KILL`.
	# A rule about kills, not about the size of the bar -- `Game.max_stamina` is
	# untouched, so GDD §6.6's five stats stay the smith's.
	Game.refund_stamina(Game.max_stamina if Run.has_echo(EchoDb.SECOND_WIND)
		else K.STAMINA_KILL)

	if next != tier:
		tier = next
		peak_tier = maxi(peak_tier, tier)
		Bus.heat_tier_changed.emit(tier, true)
	_announce()


## The Answering Strike (`EchoDb.ANSWERING_STRIKE`): a blow you BLOCK advances
## the chain by one, as a kill does.
##
## `Bus.shield_blocked` and not a hero flag, for the reason the class note gives
## about `player_health_changed`: a blocked blow never changes health, so the
## shield being the tempo tool already falls out of the wiring, and this is the
## same wiring asked to do slightly more.
func _on_blocked(_position: Vector3, _normal: Vector3) -> void:
	if not Run.in_dungeon or not Run.has_echo(EchoDb.ANSWERING_STRIKE):
		return
	_advance()


## He took a hit that actually cost health. Blocked blows never reach here.
func _on_health_changed(quarters: int, _max_quarters: int) -> void:
	if quarters < _last_quarters and kills > 0:
		_step_down(true)
	_last_quarters = quarters


## Fall one tier -- to the floor of the tier below, not to zero.
##
## Zeroing is the obvious rule and it is wrong twice over: it makes one mistake
## at Blazing cost nine kills, and it makes the meter binary, so the player never
## sees the thing they are about to lose sliding away. Stepping down means the
## bar visibly retreats and there is still something worth defending.
func _step_down(struck: bool) -> void:
	if kills <= 0:
		return
	# The Sustain-Verse eats this one. Both doors into `_step_down` are covered
	# on purpose -- the design says "a break", and to a player the window running
	# out and a spear landing are the same event seen from two sides.
	#
	# The window is REFRESHED rather than left where it was, and that is the half
	# of this that is not obvious: an expiry arrives with `window` at or below
	# zero, so absorbing without refilling it would step down again on the very
	# next frame with the ward already spent. "Holds through one break" means the
	# chain comes out of it live, which means it comes out of it with a clock.
	if sustained:
		sustained = false
		window = K.HEAT_TIER_WINDOW[maxi(tier, 1)]
		# Reported as a tier change that did not change tier, which is exactly
		# what the HUD's flash is for: something happened to the chain and it is
		# still lit. `_announce` alone would repaint the bar with no event in it.
		Bus.heat_tier_changed.emit(tier, true)
		_announce()
		return
	kills = K.HEAT_TIER_KILLS[tier - 1] if tier > 0 else 0
	var next := _tier_for(kills)
	window = K.HEAT_TIER_WINDOW[maxi(next, 1)] if kills > 0 else 0.0
	if next != tier:
		tier = next
		Bus.heat_tier_changed.emit(tier, false)
	elif struck:
		# Struck at tier 0 with a kill or two banked: no tier moved, but the
		# chain still broke and the HUD needs the flash or the hit reads as free.
		Bus.heat_tier_changed.emit(tier, false)
	_announce()


## Cast the Sustain-Verse: the next break is absorbed. `HeroRanged._cast_sustain`
## is the only caller.
##
## **Refused when there is no chain to hold.** A ward armed at zero kills would
## sit there through the whole walk to the next fight and then be spent on the
## first expiry of a chain the player had not decided to defend yet -- a charge
## gone on a decision nobody made. Refusing here rather than at the hero is the
## same argument `spend_ammo` makes: the thing that owns the state owns the no.
##
## Re-casting an armed ward is also refused, and that is not politeness. It would
## be a second charge bought for nothing, because one break is one break however
## many times you say it.
func sustain() -> bool:
	if kills <= 0 or sustained:
		return false
	sustained = true
	_announce()
	return true


# --- Queries ----------------------------------------------------------------

## What the vendor pays for loot swept right now, as a multiplier on base value.
func multiplier() -> float:
	return K.HEAT_TIER_MULT[clampi(tier, 0, K.HEAT_TIERS - 1)]


## The chain is at the top rung -- Blazing.
##
## A function rather than `tier == 3` at the two sites that ask (the Blazing
## Tithe's extra mote and the Full Cup's unspent bottle), because 3 is
## `K.HEAT_TIERS - 1` and a literal is what makes a fifth tier a bug in three
## files instead of one number.
func blazing() -> bool:
	return tier >= K.HEAT_TIERS - 1


## Metres a mote will be dragged from at the current tier. 0 means no magnetism.
func magnet_range() -> float:
	var base_range: float = K.HEAT_MAGNET[clampi(tier, 0, K.HEAT_TIERS - 1)]
	return FieldNotesDb.heat_magnet_range(base_range, tier)


## How much of the current tier's window is left, 0..1.
func window01() -> float:
	if kills <= 0:
		return 0.0
	var full := K.HEAT_TIER_WINDOW[maxi(tier, 1)]
	return clampf(window / maxf(full, 0.01), 0.0, 1.0)


func _tier_for(n: int) -> int:
	var found := 0
	for t in K.HEAT_TIERS:
		if n >= K.HEAT_TIER_KILLS[t]:
			found = t
	return found


func _announce() -> void:
	Bus.heat_changed.emit(kills, tier, window01())
