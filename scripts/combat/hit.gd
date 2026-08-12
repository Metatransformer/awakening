class_name Hit
extends RefCounted
## One blow. docs/CONTRACT.md §8 — there is exactly one damage path and this is
## the thing that travels down it.
##
## Amounts are in QUARTER hearts, like the source material: K.HEART == 4 is one
## heart, and a basic slash is deliberately not a whole one.

## The two kinds a bow can deliver, spelled once.
##
## **`ARROW_FIRE` is the whole of combinator 8** (`docs/PUZZLES.md` §3.1,
## priced in §8.1): an arrow that crossed a lit lantern arrives as something
## else, and the lock on the far side only accepts the something else. It is one
## `StringName` because that is all it is allowed to be -- the moment convert
## needs a prop of its own it has stopped being a combinator.
##
## Spelled HERE rather than on `Arrow` because `kind` is this class's field and
## because the atoms that discriminate on it (`EyeSwitch`) should not have to
## know which projectile script exists. A typo'd StringName is a puzzle that
## builds, generates and silently never solves -- `PuzzleAtoms`' own note.
const ARROW := &"arrow"
const ARROW_FIRE := &"arrow_fire"

## Quarter-hearts of damage. K.QUARTER == 1.
var amount: int = K.QUARTER
## World position the blow came FROM, which is what knockback is measured against.
var from: Vector3 = Vector3.ZERO
## Metres/sec pushed away from `from`.
var knockback: float = 0.0
## Seconds the victim is stunned.
var stun: float = 0.0
## &"sword" &"arrow" &"arrow_fire" &"bomb" &"contact" &"fire"
var kind: StringName = &"sword"
## Who threw it, ready to print: "SKELETON", "ELITE WRAITH".
##
## A NAME and not a node reference, because the only thing that reads it is the
## run-ending screen, and by the time that screen draws the thing that killed you
## is being freed along with the floor it stood on. A `Node3D` here would be a
## field that is valid for one frame and dangling for the one that matters.
##
## Empty means nobody claimed it. The screen says so ("THE DARK") rather than
## inventing an attacker.
var source: StringName = &""

## How heavy the thing that threw this is, in `K.LAUNCH_MASS_REF` units -- so a
## 1.25 m goblin is 0.74, the reference skeleton is 1.0 and a 3 m boss is 1.76.
##
## The same body height the launch already scales off (`Enemy._mass_scale`),
## because a second measure of mass is a second thing to keep in step. It is here
## rather than looked up off the attacker for the reason `source` is a name and
## not a node: by the time a run-ending blow is being read the thing that threw it
## may already have been freed with the floor it stood on.
##
## 1.0 by default, so nothing that has not been taught about mass changes
## behaviour by existing.
var mass: float = 1.0
## How big a swing this is FOR THE THING THAT THREW IT, 0..1. A boss's telegraphed
## heaviest beat is 1.0; its jab is low. Its own scale, not the game's, which is
## what lets a small enemy's committed lunge read as committed without pretending
## to be a boss.
##
## 0.5 by default -- "an ordinary attack" -- so an attacker that never sets it is
## treated as neither a jab nor a haymaker.
var commitment: float = 0.5

## Authored overrides for the two odds, as fractions. **Negative means "derive"**,
## which is the default and what almost everything should stay on -- the curves in
## `tier_odds` exist so a new monster is priced by having a height, not by
## somebody remembering to fill two more columns.
##
## They are here for the exceptions the curves cannot know about: a small body
## that hits like a truck, a large one whose whole design is that it cannot floor
## you. Set BOTH or neither; one alone falls back to the derivation, because a
## half-authored pair is a number nobody chose.
##
## `odds_stagger` is the HEAVY band's own width, not a cumulative threshold --
## `Enemy.KINDS[&"orc"]` reading `{knockdown = 0.20, stagger = 0.30}` says exactly
## what the design note said, "80-100 knockdown, 50-80 heavy".
var odds_knockdown: float = -1.0
var odds_stagger: float = -1.0


## The three reactions a blow can earn from its victim. LIGHT is a flinch he
## walks out of, HEAVY is a stagger that eats his next press, KNOCKDOWN puts him
## on his back and costs him the time to get up.
enum Tier { LIGHT, HEAVY, KNOCKDOWN }


static func make(amount_q: int, from_pos: Vector3, kind_id: StringName = &"sword",
		knock: float = 0.0, stun_time: float = 0.0,
		source_name: StringName = &"", body_mass: float = 1.0,
		commit: float = 0.5) -> Hit:
	var h := Hit.new()
	h.amount = amount_q
	h.from = from_pos
	h.kind = kind_id
	h.knockback = knock
	h.stun = stun_time
	h.source = source_name
	h.mass = body_mass
	h.commitment = commit
	return h


## How hard this blow lands ON ITS VICTIM, 0..1. Decided ONCE, here.
##
## Every channel of the receiving end reads this and nothing else: how long the
## hit-stop holds, how far the camera is punched, which flinch clip plays, how
## long the stagger lasts, and which grunt is voiced. One number, so a beat
## retuned in `BossDb` moves all five together and none of them can fall out of
## step with the others.
##
## **This is NOT `K.blow_weight`, and the difference is the whole card.**
## That one is knockback alone, which is right for the OUTGOING half: every swing
## in the hero's kit sets knockback deliberately, so it already separates a jab
## from a finisher. On the INCOMING half it separates nothing -- `K`'s own note
## says so ("Enemy contact hitboxes carry KNOCKBACK_LIGHT, so a monster's blow is
## always weight 0"), and the floor 1 boss's arc and its slam differ by one step
## of a two-step scale. Read through it, a goblin's jab and a boss's pool are the
## same event, which is exactly the complaint card #130 was opened for.
##
## So this leads on DAMAGE, which is the thing the incoming blows actually differ
## by (1 quarter for a goblin, 3-6 across the twelve boss beats), and keeps
## knockback as the second term because a shove is a real part of how hard
## something hit you. The floor 1 boss comes out:
##
##   goblin jab       1q, light  ->  0.00     boss arc     3q, light  ->  0.24
##   boss pool        3q, light  ->  0.24     boss slam    4q, heavy  ->  0.76
##   final charge     6q, heavy  ->  1.00
##
## The arc and the pool land on the same number and that is correct rather than a
## failure to discriminate: they ARE the same weight of blow, and what separates
## them is where they came from -- the arc from the boss, the pool from under
## your own feet. That is the camera punch's job (`Feel.punch`), not this one's.
##
## `amount` is pre-armour on purpose. `Game.armour_soak` is a build decision and
## the screen should report the blow that was thrown, not the one that got
## through -- otherwise the same boss beat reads softer every time you upgrade,
## and the player loses the read they spent the fight learning.
func severity() -> float:
	return severity_of(amount, knockback)


## `severity` for a blow that has not been built yet, so an attacker can price
## its own moveset against itself before it throws anything -- `Boss._land` reads
## every beat through this to work out which of its beats is its heaviest.
##
## Static rather than "make a throwaway Hit and ask it": the answer is wanted
## once per boss for a dozen beats, and a constructor per row to read a pure
## function of two numbers is a function pretending to be an object.
static func severity_of(amount_q: int, knock: float) -> float:
	var dmg := clampf(float(amount_q - K.QUARTER) / float(K.HEART + K.QUARTER),
		0.0, 1.0)
	var shove := clampf((knock - K.KNOCKBACK_LIGHT)
		/ (K.KNOCKBACK_HEAVY - K.KNOCKBACK_LIGHT), 0.0, 1.0)
	return clampf(dmg * 0.6 + shove * 0.4, 0.0, 1.0)



## The odds of each of the three reactions, as (knockdown, not-light).
##
## **The whole model, and it is two logistic curves through numbers the designer
## named.** A goblin's swing is 90 / 9 / 1 light / heavy / knockdown; an orc's is
## 50 / 30 / 20. Everything else on the roster is those two rows extrapolated,
## which is what makes this a schema rather than a table nobody can extend: add a
## monster with a height and it is priced, and the two curves are the only thing
## anyone has to agree with.
##
## The input is `mass * commitment^2`:
##
##   * **mass** separates the creatures. A 1.25 m goblin is 0.74 and a 1.95 m orc
##     is 1.15, and that 1.56x is worth 20x in knockdown odds -- which is steep,
##     and is exactly the spread that was asked for.
##   * **commitment SQUARED** separates one creature's moves from each other. A
##     boss's heaviest telegraphed beat is 1.0 and stays where its mass puts it;
##     its jab at 0.75 comes down to 0.56, which is what stops a body large enough
##     to floor you doing it with every twitch. Squared and not linear because a
##     moveset only spans 3/4 to 1 (`commitment` is damage over the monster's own
##     best damage), and a linear read of that is barely a difference at all.
##
## Measured across the roster as it stands -- `tools/_hurt_table.gd` prints it:
##
##   goblin        90 /  9 /  1        orc            50 / 30 / 20
##   skeleton      69 / 24 /  7        wraith         54 / 29 / 17
##   boss f1 arc   53 / 30 / 17        boss f1 slam    2 / 14 / 85
##
## Not-light rather than heavy as the second number, so the two can never sum past
## one and a badly-authored override cannot produce negative odds.
func tier_odds() -> Vector2:
	if odds_knockdown >= 0.0 and odds_stagger >= 0.0:
		var k := clampf(odds_knockdown, 0.0, 1.0)
		return Vector2(k, clampf(k + odds_stagger, 0.0, 1.0))
	var c := clampf(commitment, 0.0, 1.0)
	var x := clampf(mass, 0.1, 4.0) * c * c
	var kd := K.KNOCKDOWN_CEIL / (1.0
		+ exp(-K.KNOCKDOWN_K * (x - K.KNOCKDOWN_MID)))
	var nl := K.STAGGER_CEIL / (1.0 + exp(-K.STAGGER_K * (x - K.STAGGER_MID)))
	return Vector2(kd, maxf(nl, kd))


## Draw one of the three reactions. **Call this ONCE per landed blow and keep the
## answer** -- it rolls, so asking twice is asking two different questions, and
## the bug that ships is a hero playing the knockdown clip while the controller
## runs the flinch's timings.
##
## Rolled and not derived because that is what keeps the tell worth reading. A
## deterministic table is one the player memorises after two fights: this beat
## floors me, that one does not. A roll means the heaviest blow is *usually* a
## knockdown and the read is "do not eat that", which is the read the fight is
## actually about.
func roll_tier(rng: RandomNumberGenerator = null) -> Tier:
	var odds := tier_odds()
	var r := rng.randf() if rng != null else randf()
	if r < odds.x:
		return Tier.KNOCKDOWN
	return Tier.HEAVY if r < odds.y else Tier.LIGHT


## How hard this blow lands ALL IN, 0..1 -- the CONTINUOUS half, which is what
## the camera, the hit-stop and the grunt read.
##
## Separate from `tier_odds` on purpose. The tier is a discrete reaction and it is
## rolled; this is a magnitude and it is not, because a blow that rolled LIGHT
## from something enormous should still shake the screen harder than a jab. Two
## players eating the same boss slam see the same camera and may see different
## reactions, which is right: the roll decides what his BODY did, and the screen
## reports what HIT it.
func force() -> float:
	var m := sqrt(clampf(mass, 0.25, 4.0))
	return clampf(severity() * 0.62 + (m - 0.86) * 0.42
		+ clampf(commitment, 0.0, 1.0) * 0.20, 0.0, 1.0)


## How much of the authored knockback each reaction actually spends.
##
## The number in `BossDb` is the beat's shove and it stays the beat's shove; this
## is the victim's half of it. A knockdown has to TRAVEL -- `ex_knocked_down` is
## authored being hurled backwards, and a man who lies down exactly where he was
## standing reads as a man who fainted. A light flinch spends less than the full
## shove for the opposite reason: it does not take control away, so a full shove
## would slide the player out of position for a hit he is meant to shrug off.
##
## Lives here rather than in `K` because the table is keyed on `Tier`, and `Tier`
## is declared in this file -- putting it in `K` would make the constants file
## depend on this one, which already depends on it.
static func knock_scale(t: Tier) -> float:
	match t:
		Tier.KNOCKDOWN:
			return 1.8
		Tier.HEAVY:
			return 1.0
		_:
			return 0.7
