class_name Catalogue
extends RefCounted
## What a counter sells, and the only thing `TradeScreen` knows about it.
##
## The smith and the alchemist were already the same screen pointed in two
## directions -- `TradeScreen` holds whichever catalogue it was opened with and
## never asks which -- but the CONTRACT for being a catalogue lived in a doc
## comment on `AlchemyDb` saying "the same shape as ShopDb, deliberately and
## exactly. If you add a method here, add it there." That is a rule enforced by
## whoever remembers reading it. This is the same rule enforced by the parser.
##
## **Adding a third counter is a subclass and a table row, not a screen.** The
## screen, the recipe column, the per-token affordability colouring, the refusal
## footer and the hold-to-craft gauge are written once, here-ward of every
## vendor; `Npc.COUNTERS` names who stands behind which catalogue. A fourth
## shopkeeper should cost a `lines()` and nothing else, because the last time
## this project grew a second copy of a system it cost more than either copy
## (CLAUDE.md §0).
##
## Static, not instanced, because a catalogue is a pure function of `Game`: what
## the smith has left is `Game.upgrades`, and an instance would be a second copy
## of state that is already saved somewhere else. The subclass script itself is
## the handle that gets passed around (`TradeScreen.catalogue`).
##
## The defaults below are all refusals. A subclass that forgets `buy()` sells
## nothing rather than giving things away.


## Every line on the counter, in display order. Each is a Dictionary with at
## least `id`, `label`, `cost`, `blurb`, and optionally `parts` (the recipe) and
## `detail` (what the number does, in the unit the player feels).
static func lines() -> Array[Dictionary]:
	return []


## How many of `id` are left, or -1 for unlimited. Drawn as "N LEFT".
static func remaining(_id: StringName) -> int:
	return -1


## Can the player afford this line right now -- gold AND materials.
static func can_buy(_line: Dictionary) -> bool:
	return false


## WHY not, in the player's words ("NEED 2 GRIT"), or "" if it is affordable.
## Asked rather than assumed: once a line can be refused for four different
## reasons, a hardcoded "NOT ENOUGH GOLD" sends the player back down for the
## wrong thing.
static func refusal(_line: Dictionary) -> String:
	return ""


## Take the payment and grant the thing. False if it could not happen.
static func buy(_line: Dictionary) -> bool:
	return false


## True when this line eats MATERIALS and not just coin -- a forge rung, a blown
## bottle, a brew. Concrete here and not overridden anywhere: both catalogues
## carry the recipe under the same `parts` key, and a shop that answered this
## question its own way is a shop where crafting is a hold at one counter and a
## tap at the next.
##
## This is the line `TradeScreen` reads to decide what needs holding. Gold is
## grindable and a wasted purchase is a bad afternoon; a Cold Iron Core is a
## thing you FOUND, it is the pacing gate of the whole metagame
## (docs/METAGAME.md §6.5), and spending one on the wrong ladder because the
## cursor was one row off is the one shop mistake this game cannot give back.
## So the irreversible commits are held and the repeatable ones are tapped --
## the hold is not ceremony, it is the difference between the two.
static func crafts(line: Dictionary) -> bool:
	var parts: Dictionary = line.get("parts", {})
	return not parts.is_empty()


## What this counter calls the act of making something out of materials. FORGE
## at the smith, BREW at the alchemist. Overridden per catalogue because the
## footer says it to the player -- "HOLD ENT TO FORGE" is the smith talking, and
## a shared "CRAFT" would be the UI talking.
##
## **Call this through the catalogue you were handed, never from another static
## in this file.** A static call written bare inside `Catalogue` binds to
## `Catalogue` at parse time -- there is no virtual dispatch to climb back down
## to `ShopDb`. A `verb(line)` helper here that did `craft_verb() if
## crafts(line)` compiled fine, ran fine, and shipped a smith whose counter said
## HOLD ENT TO CRAFT; the frame is what caught it. The overrides are only ever
## reached through the subclass, which is exactly how `TradeScreen` holds it.
static func craft_verb() -> String:
	return "CRAFT"
