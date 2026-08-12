# Mechanics inventory

This is the complete working ledger of committed player-facing mechanics in
**The Lower Worlds: Awakening**, audited against the design canon and build on
2026-08-11. Update it whenever a mechanic is added, removed, materially changed
or changes status.

A mechanic belongs here when it is a player action, rule, resource, constraint,
state transition or feedback rule with gameplay consequences. An input binding,
animation, UI shortcut, implementation helper, enemy/item variant or room
prefab is not a separate mechanic unless it changes what the player can decide
or what the game does in response.

## Status and traceability

- **Playable** — present in the current build.
- **Partial** — some of the canonical behaviour exists, but the full mechanic
  or content coverage does not.
- **Designed** — committed to the bounded prologue, but not fully implemented.
- **Contradicted** — sources disagree; resolve the owner before extending it.

**Now** distinguishes `Test` (may be observed or minimally changed for the
active proof), `Maintain` (already present; do not expand it to evade the proof)
and `Frozen` (not authorised during Core Loop Proof).

MDA targets refer to [`MDA.md`](MDA.md): **Risk**, **Mastery**, **Growth**,
**Homecoming** and **Curiosity**. Every mechanic names the player dynamic it is
supposed to create and the experience it is supposed to serve. That is its MDA
trace; tiny rules do not each need a separate three-heading essay.

## Control, movement and combat

| ID | Mechanic / rule | Status | Now | MDA target | Intended dynamic → aesthetic | Owner / evidence |
|---|---|---|---|---|---|---|
| MOVE-01 | Camera-relative analog movement; stick magnitude sets speed | Playable | Test | Mastery | Read and control space → embodied competence | [`GDD.md` §4, §9](GDD.md); implementation directors |
| MOVE-02 | Hold to run; running and combat actions spend stamina | Playable | Test | Risk, Mastery | Spend mobility to close, extend or escape → tension and agency | [`GDD.md` §9](GDD.md); [`CONTRACT.md` §4](CONTRACT.md) |
| MOVE-03 | Committed dodge roll with invulnerability; sharp reversal uses a distinct turn | Playable | Test | Mastery | Predict and commit to evasion → readable competence | [`GDD.md` §4](GDD.md); combat directors |
| MOVE-04 | Jump; an unarmed airborne sword input becomes an air slam | Playable | Maintain | Mastery | Turn traversal commitment into an attack choice → agency | [`GDD.md` §9](GDD.md) |
| MOVE-05 | Lock-on frames one threat; the same trigger raises the shield | Playable | Test | Mastery | Keep danger readable while choosing defence/offence → competence | [`GDD.md` §9](GDD.md); targeting directors |
| MOVE-06 | Context input talks/uses normally and parries while guarding | Playable | Test | Mastery, Homecoming | Reuse one input without ambiguous action → fluency and trust | [`GDD.md` §9](GDD.md); input contract |
| COMBAT-01 | Three-hit light chain has committed wind-up, hit and recovery frames | Playable | Test | Mastery | Decide whether to continue a sequence → earned competence | [`CONTRACT.md` “The sword”](CONTRACT.md) |
| COMBAT-02 | Held heavy charge releases a stronger swing; movement can turn it into a lunge | Playable | Test | Mastery | Trade time/exposure for reach and force → nerve | [`CONTRACT.md` “The sword”](CONTRACT.md) |
| COMBAT-03 | Spin and slam spend scarce stamina/magic for area control | Playable | Maintain | Mastery, Growth | Budget a burst answer against groups → agency | [`GDD.md` §9](GDD.md); combat directors |
| COMBAT-04 | Shield blocks only inside an upgradeable facing arc | Playable | Test | Mastery | Face and read an attack instead of receiving passive defence → competence | [`GDD.md` §4.1](GDD.md); [`METAGAME.md` §6.5](METAGAME.md) |
| COMBAT-05 | Timed parry drops guard; a hit staggers and opens one riposte | Playable | Test | Mastery | Risk a punishable read to seize initiative → nerve/mastery | [`BESTIARY.md` §3.6](BESTIARY.md); parry/dodge director |
| COMBAT-06 | Perfect dodge through a real hit slows time and opens a flurry | Playable | Test | Mastery | Convert reactive defence into a counterattack → recovery/mastery | [`BESTIARY.md` §3.6](BESTIARY.md); parry/dodge director |
| COMBAT-07 | Quarter-heart health, damage, invulnerability, healing and death share one path | Playable | Test | Risk, Mastery | Read remaining exposure and consequence → tension/trust | [`CONTRACT.md` “Damage”](CONTRACT.md) |
| COMBAT-08 | Enemy baseline is see, close, wind-up, commit, recover; wind-ups keep a reaction floor at depth | Playable | Test | Mastery | Learn a transferable grammar instead of guessing → fair mastery | [`BESTIARY.md` §0–1](BESTIARY.md); enemy directors |
| COMBAT-09 | Packs spread, circle, leash and return home; disengagement remains possible | Playable | Test | Risk, Mastery | Choose engagement, escape or extraction → agency/tension | [`METAGAME.md` §7](METAGAME.md) |
| COMBAT-10 | Hit weight jointly controls impact, hit-stop, shake and launch; bosses resist launch | Playable | Maintain | Mastery | Read force and mass from reaction → satisfying competence | [`BESTIARY.md` §3.5](BESTIARY.md); launch director |
| COMBAT-11 | Heat chains kills, decays on a shrinking window and steps down on damage/timeout | Playable | Test | Risk, Mastery | Chase tempo or preserve safety → tense greed/mastery | [`METAGAME.md` §4.5](METAGAME.md); Heat director |
| COMBAT-12 | Kills refund chase stamina; Heat pulls motes and stamps a cooling value premium onto loot | Playable | Test | Risk | Extend a chain and sweep before value cools → tense greed | [`METAGAME.md` §4.5](METAGAME.md); Heat director |
| DIFF-01 | Optional Mercy starts at 5% resistance, rises with saved deaths and caps at 30% without changing spawns, telegraphs or rewards | Playable | Maintain | Mastery | Let a repeatedly stuck player survive more mistakes without declaring a mode or invalidating success → resilience/accessibility | [`GDD.md` §7.1](GDD.md); settings/save directors |
| ENEMY-01 | Thrower telegraphs a projectile the shield can return | Designed | Frozen | Mastery, Curiosity | Recognise the shield as an active answer → discovery/mastery | [`BESTIARY.md` §3](BESTIARY.md) |
| ENEMY-02 | Guard has plated front; Burst/timed arrow is fast, circling is slow | Designed | Frozen | Mastery, Curiosity | Match tool or position to visible defence → discovery/mastery | [`BESTIARY.md` §3](BESTIARY.md) |
| ENEMY-03 | Perched enemy makes range matter; bow or hookshot answers it | Designed | Frozen | Mastery, Curiosity | Solve an unwanted gap with a chosen tool → agency/mastery | [`BESTIARY.md` §3](BESTIARY.md) |
| ENEMY-04 | Thief steals the richest eligible exposed stack and flees; killing it returns the stack | Playable | Maintain | Risk, Mastery | Chase to recover value or accept loss → tense greed | [`BESTIARY.md` §3](BESTIARY.md); thief director |
| BOSS-01 | Bosses use authored multi-beat fight shapes; parry can cut a committed beat into recovery | Partial | Frozen | Mastery, Curiosity | Learn a fight-level rule and earn a verb → mastery/anticipation | [`BOSSES.md`](BOSSES.md); boss test arena |
| BOSS-02 | Defeated bosses remain dead and permanently open depth progression | Partial | Frozen | Homecoming, Curiosity | Turn mastery into lasting access → achievement/anticipation | [`GDD.md` §5.1](GDD.md) |
| BOSS-03 | A floor boss earns a persistent great chest; opening it grants the deterministic boss verb through one shared item-get ceremony while the relic remains separate bag loot | Playable | Test | Growth, Curiosity, Homecoming | See victory become a memorable new capability without confusing it with artifact turn-in → achievement/discovery | [`GDD.md` §5.1–5.2](GDD.md); [`ITEMS.md` §0–1](ITEMS.md); boss director |

## Tools, loadout and supplies

| ID | Mechanic / rule | Status | Now | MDA target | Intended dynamic → aesthetic | Owner / evidence |
|---|---|---|---|---|---|---|
| KIT-01 | Hand and carry rings cycle owned armaments, bottles and rations; loadout swap preserves two sets | Playable | Test | Mastery, Growth | Reach a prepared answer quickly → fluency/agency | [`GDD.md` §9](GDD.md); [`CONTRACT.md` §4.1](CONTRACT.md) |
| KIT-02 | Eight-slot hold-and-release kit wheel equips owned weapons/carry items without adding capacity | Playable | Maintain | Mastery, Growth | Curate and recall a field kit → preparation/fluency | [`CONTRACT.md` §4.2](CONTRACT.md); built sequencing debt |
| KIT-03 | Bow consumes capped arrows and provides the ranged answer to eyes/distant bodies | Playable | Maintain | Mastery, Curiosity | Plan shots and recognise range opportunities → competence/discovery | [`ITEMS.md` §1.2](ITEMS.md) |
| KIT-04 | Arrows come from stores, floor bundles/urns or fletching bag ingredients | Playable | Maintain | Risk, Growth | Buy, craft or conserve ammunition → preparation/tension | [`METAGAME.md` §4.6](METAGAME.md) |
| KIT-05 | Hookshot crosses a gap or briefly controls a target; rings receive aim preference | Playable | Maintain | Mastery, Curiosity | Reinterpret distance as solvable → agency/discovery | [`ITEMS.md` §1.3](ITEMS.md) |
| KIT-06 | Burst spends charges on a fused area blast that breaks burstable structures/guards | Playable | Maintain | Mastery, Growth, Curiosity | Spend a scarce destructive answer to change room/fight → agency | [`ITEMS.md` §1.4](ITEMS.md); M5 sequencing debt |
| KIT-07 | Sustain spends a charge to preserve one Heat break | Playable | Maintain | Risk, Growth | Buy one more tempo extension → tense greed | [`ITEMS.md` §1.5](ITEMS.md) |
| KIT-08 | Ballast burns the cheapest exposed stack for temporary soak | Playable | Maintain | Risk, Growth | Sacrifice profit to survive carrying it → tense greed/agency | [`ITEMS.md` §1.6](ITEMS.md) |
| KIT-09 | Far Lantern has no field verb; it is a pure final progression key | Designed | Frozen | Homecoming, Curiosity | Finish the prologue while opening the larger promise → anticipation | [`ITEMS.md` §1.7](ITEMS.md) |
| KIT-10 | Bottles cap carried draught uses; draughts heal or grant timed run effects | Playable | Maintain | Risk, Growth | Prepare finite safety and choose when to spend it → security/tension | [`METAGAME.md` §6.6](METAGAME.md) |
| KIT-11 | Hardtack/beer restore over a vulnerable seated channel that interruption wastes | Playable | Maintain | Risk, Growth | Secure a room before accepting slow recovery → relief/preparation | [`METAGAME.md` §6.4](METAGAME.md); ration director |

## Run, inventory and extraction

| ID | Mechanic / rule | Status | Now | MDA target | Intended dynamic → aesthetic | Owner / evidence |
|---|---|---|---|---|---|---|
| RUN-01 | Run begins with an empty finite bag; stacks consume slots and full bags visibly refuse pickup | Playable | Test | Risk | Compare value per slot and deliberately leave loot → tense greed/trust | [`METAGAME.md` §3](METAGAME.md) |
| RUN-02 | Three bag slots form a secure document case; pickup fills it first and players may repack | Playable | Test | Risk | Choose what survives before danger resolves → ownership/tension | [`GDD.md` §3.1](GDD.md); case director |
| RUN-03 | Relics/Echoes cannot enter the case; thieves/Ballast cannot reach it | Playable | Test | Risk | Make the strongest risk objects unsafe while case rules stay predictable → trust | [`GDD.md` §3.1](GDD.md) |
| RUN-04 | Ingredients sell, components bank to benches and relics change home; the three are not convertible | Playable | Test | Risk, Growth, Homecoming | Carry distinct rewards toward distinct future goals → anticipation | [`GDD.md` §3](GDD.md); [`METAGAME.md` §2–4](METAGAME.md) |
| RUN-05 | A sounding stone offers three unheld Echoes; the chosen Echo costs a slot, grants run-only power, sells for zero and vanishes on home/death | Playable | Maintain | Risk, Curiosity | Choose temporary possibility at the price of haul capacity → curiosity/tension | [`PUZZLES.md` §6, §9](PUZZLES.md); puzzle-loop director |
| RUN-06 | Unique relics occupy the bag, are lost on death and return to their authored room | Partial | Frozen | Risk, Homecoming, Curiosity | Risk a world-changing object without corrupting the save → tension | [`GDD.md` §3](GDD.md); [`ITEMS.md` §2](ITEMS.md) |
| RUN-07 | Permanent Escape Rope requires a menu hold then an interruptible world channel; blocking preserves it | Playable | Test | Risk, Mastery | Create safety before committing to leave → tension/relief | [`METAGAME.md` §5](METAGAME.md); MVP director |
| RUN-08 | Extraction costs max(15, 25% of bag value), capped at current gold, and always remains possible | Playable | Test | Risk | Price a rich exit without trapping a poor player → tense greed | [`METAGAME.md` §5](METAGAME.md) |
| RUN-09 | Extraction banks the whole haul and heals to full | Playable | Test | Risk, Homecoming | Convert chosen risk into permanence and relief → homecoming | [`METAGAME.md` §5](METAGAME.md) |
| RUN-10 | Death banks only the case, loses exposed carry, preserves metagame progress and restores health | Playable | Test | Risk, Homecoming | Suffer legible setback without erasing prior growth → tension/resilience | [`METAGAME.md` §5](METAGAME.md) |
| RUN-11 | One run-end receipt reports extracted/lost/cased stacks, values, floor, kills and killer | Playable | Test | Risk, Homecoming | Attribute the outcome to specific choices → ownership/closure | [`METAGAME.md` §5](METAGAME.md) |
| RUN-12 | Run state is never saved; persistent state autosaves at scene transitions | Playable | Maintain | Risk, Homecoming | Prevent reload from undoing risk while protecting permanence → trust | [`METAGAME.md` §5](METAGAME.md) |
| RUN-13 | Descending preserves health, bag and rising fee; it banks/heals nothing | Playable | Test | Risk, Curiosity | Choose deeper possibility at peak exposure → tense greed/curiosity | [`METAGAME.md` §7.1](METAGAME.md) |
| RUN-14 | Depth raises rooms, packs, elites, rewards, health/damage and tempo pressure through one curve | Playable | Maintain | Risk, Mastery, Curiosity | Self-select risk while rewards remain competitive → anticipation | [`METAGAME.md` §7.1](METAGAME.md) |

### Echo rule bends

These are item-specific mechanics because each changes an existing rule and
therefore changes player decisions. All are playable systems; expanding their
placements or content remains outside the active proof.

| ID | Mechanic / rule | Status | Now | MDA target | Intended dynamic → aesthetic | Owner / evidence |
|---|---|---|---|---|---|---|
| ECHO-01 | Held Note keeps every Heat tier at Warm's timer | Playable | Maintain | Risk | Maintain high tempo with a longer leash → empowered greed | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-02 | Answering Strike makes a successful block advance Heat like a kill | Playable | Maintain | Risk, Mastery | Use defence to preserve offence → mastery/flow | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-03 | Slow Fade prevents Heat-stamped motes cooling before pickup | Playable | Maintain | Risk | Spend the chain on fighting rather than immediate cleanup → freedom/tension | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-04 | Second Wind makes a kill refill the whole stamina bar | Playable | Maintain | Mastery | Chain movement and attacks aggressively after a kill → momentum | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-05 | Blazing Tithe makes kills at Blazing drop a second mote | Playable | Maintain | Risk | Stay at maximum tempo for quantity as well as value → greed/exhilaration | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-06 | Unbroken Rope prevents a landed hit breaking extraction | Playable | Maintain | Risk | Push further knowing the exit channel is reliable → daring/relief | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-07 | Cold Ledger taxes base bag value rather than Heat premium | Playable | Maintain | Risk | Chase tempo without making the extra value dearer to extract → empowered greed | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-08 | Deep Pocket doubles common-ingredient stack size | Playable | Maintain | Risk | Revalue common pickups and capacity → planning/abundance | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-09 | Quiet Room holds the first enemy encountered in each room | Playable | Maintain | Risk, Mastery | Open each room on the player's terms → confidence | [`PUZZLES.md` §6.1](PUZZLES.md); `Run` room trigger |
| ECHO-10 | Returning Shaft recovers arrows from enemies they kill | Playable | Maintain | Growth, Mastery | Use ranged answers at depth without the normal budget → freedom/mastery | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-11 | Full Cup preserves a bottle drunk while Heat is Blazing | Playable | Maintain | Risk, Growth | Convert risky tempo into retained preparation → exhilaration | [`PUZZLES.md` §6.1](PUZZLES.md); `EchoDb` |
| ECHO-12 | Long Chord makes every other held Echo stop costing a slot | Playable | Maintain | Risk, Curiosity | Reward prior commitment to Echoes and radically reprice capacity → discovery/payoff | [`PUZZLES.md` §6.1](PUZZLES.md); `Run.slots_used` |

## Dungeon structure, puzzles and discovery

| ID | Mechanic / rule | Status | Now | MDA target | Intended dynamic → aesthetic | Owner / evidence |
|---|---|---|---|---|---|---|
| WORLD-01 | Seeded room graph combines procedural fill with authored boss/gate, shortcut, vault and deep-chest anchors | Playable | Maintain | Risk, Curiosity | Learn stable promises inside variable routes → curiosity/place-memory | [`GDD.md` §5.1](GDD.md); dungeon directors |
| WORLD-02 | Gate-room puzzle opens a cycle that shortens the walk home | Playable | Test | Risk, Curiosity | Convert understanding into reduced extraction distance → mastery/relief | [`PUZZLES.md` §4–5](PUZZLES.md); M4 slice |
| WORLD-03 | Shortcuts need this floor's boss verb; vaults need the next; critical path asks only owned verbs | Partial | Frozen | Risk, Curiosity | Revisit old space with new capability without hard-locking progress → anticipation | [`PUZZLES.md` §1, §5](PUZZLES.md) |
| WORLD-04 | Small key is collected and spent at its matching locked door | Playable | Maintain | Curiosity | Search a bounded space and convert discovery into access → curiosity | [`PUZZLES.md` §2](PUZZLES.md); atom director |
| WORLD-05 | Urn breaks under a hit and reveals a bounded supply drop | Playable | Maintain | Growth, Curiosity | Test readable containers for resources → discovery/preparation | [`PUZZLES.md` §2](PUZZLES.md) |
| WORLD-06 | Pressure plate stays solved while a hero/block/weighted body holds it | Playable | Maintain | Curiosity | Reason about weight and placement → discovery/mastery | [`PUZZLES.md` §2](PUZZLES.md) |
| WORLD-07 | Push block requires an initial hold, then grid-steps while pressure is maintained | Playable | Maintain | Mastery, Curiosity | Commit to spatial manipulation without repeated friction → competence | [`PUZZLES.md` §2](PUZZLES.md); push-grip director |
| WORLD-08 | Eye switch accepts an arrow hit | Playable | Maintain | Mastery, Curiosity | Recognise and execute a ranged verb → mastery/discovery | [`PUZZLES.md` §2](PUZZLES.md) |
| WORLD-09 | Cracked pillar/floor responds to Burst and changes supported geometry | Playable | Maintain | Growth, Curiosity | Spend destruction to reveal a route → agency/discovery | [`PUZZLES.md` §2](PUZZLES.md) |
| WORLD-10 | Hook ring accepts the hookshot to cross or pull | Playable | Maintain | Mastery, Curiosity | Read reach relationships and change position → discovery | [`PUZZLES.md` §2](PUZZLES.md) |
| WORLD-11 | Sun socket receives a shield-reflected beam | Playable | Maintain | Mastery, Curiosity | Aim defence as an environmental tool → discovery/mastery | [`PUZZLES.md` §2](PUZZLES.md) |
| WORLD-12 | Lantern toggles lit/dark on hit and can transform a shot passing through it | Playable | Maintain | Mastery, Curiosity | Treat light as reversible state/routing material → curiosity | [`PUZZLES.md` §2–3](PUZZLES.md) |
| WORLD-13 | Puzzle gates adopt matching atoms, report remaining work and reset run-scoped solutions on a new run | Playable | Maintain | Curiosity | Form and verify a room-level plan → trust/discovery | [`PUZZLES.md` §2](PUZZLES.md) |
| WORLD-14 | Nest, sequence, cycle, couple, chain, convert and room-scale reconfigure compose existing atoms | Playable | Maintain | Curiosity | Read relationships rather than isolated locks → curiosity/mastery | [`PUZZLES.md` §3–5](PUZZLES.md); puzzle directors |
| WORLD-15 | Time and displace combinators, plus floor-scale reconfiguration, extend that grammar | Designed | Frozen | Curiosity | Add timing, cross-room memory and world-state reasoning → discovery | [`PUZZLES.md` §3.3, §10](PUZZLES.md) |
| WORLD-16 | Optional treasure branch combines a harder puzzle/miniboss with a richer chest | Partial | Frozen | Risk, Mastery, Curiosity | Self-select extra danger for a memorable reward → greed/curiosity | [`PUZZLES.md` §5.3, §7](PUZZLES.md) |
| WORLD-17 | Chests open once and draw richer bounded loot; authored deep chests hold unique relics | Playable | Maintain | Risk, Curiosity | Seek visible reward containers and weigh their contents against capacity → anticipation/greed | [`METAGAME.md` §7](METAGAME.md); chest/dungeon directors |
| WORLD-18 | One map is drawn as minimap and pause map; rooms/annexes reveal only when entered and markers update when used | Playable | Maintain | Risk, Curiosity | Build place-memory and plan routes without revealing unvisited answers → orientation/discovery | [`CONTRACT.md` “The map”](CONTRACT.md); map directors |
| WORLD-19 | Seeded ambient pots occupy blank walls; coins bank directly while gems enter the at-risk bag and supplies use their existing lanes | Playable | Test | Risk, Growth, Curiosity | Break a readable side-room container and distinguish safe money from exposed merchandise → discovery/greed | [`METAGAME.md` §2](METAGAME.md); [`PUZZLES.md` §0](PUZZLES.md); ambient-pots director |

## Economy, growth, home and story

| ID | Mechanic / rule | Status | Now | MDA target | Intended dynamic → aesthetic | Owner / evidence |
|---|---|---|---|---|---|---|
| HOME-01 | Quartermaster buys ingredients singly or all at once; components cannot be sold | Playable | Test | Growth, Homecoming | Convert a chosen haul into spendable progress → satisfying return | [`METAGAME.md` §6](METAGAME.md) |
| HOME-02 | Stores sell arrows, charges, rations, four bag slots and three heart containers under caps/gates | Playable | Test | Risk, Growth | Choose supplies or permanent capacity/safety → preparation | [`METAGAME.md` §6](METAGAME.md); stores director |
| HOME-03 | Forge ladders spend gold plus components to improve sword, shield, bow, hookshot and armour | Playable | Test | Growth, Homecoming | Set a material goal and feel the bought difference → growth/anticipation | [`METAGAME.md` §6.5](METAGAME.md) |
| HOME-04 | Four armour pieces commit to mutually exclusive heavy/light paths | Playable | Maintain | Growth | Build a play style with opportunity cost → agency | [`GDD.md` §6.6](GDD.md) |
| HOME-05 | Four jewellery slots buy blanks, choose one of two paths, climb with components and can be recut without refund | Playable | Maintain | Growth | Make durable but revisable build commitments → ownership | [`METAGAME.md` §6.7](METAGAME.md) |
| HOME-06 | Five displayed stats aggregate all upgrade sources under shared caps | Playable | Maintain | Mastery, Growth | Understand what growth changes without hidden arithmetic → trust | [`METAGAME.md` §6.7](METAGAME.md) |
| HOME-07 | Alchemist sells bottle capacity and brews three draughts for gold plus components | Playable | Maintain | Risk, Growth | Turn found materials into a finite next-run plan → preparation | [`METAGAME.md` §6.6](METAGAME.md) |
| HOME-08 | Material-spending/destructive transactions use a visible hold; ordinary purchases use a tap | Playable | Maintain | Growth, Homecoming | Commit deliberately and trust the counter → ownership | [`METAGAME.md` §6](METAGAME.md); hold contract |
| HOME-09 | NPCs arrive permanently at progress gates; Aldric introduces each arrival once | Playable | Test | Homecoming, Curiosity | Notice the expedition growing because of play → attachment/anticipation | [`METAGAME.md` §6](METAGAME.md); roster director |
| HOME-10 | NPCs offer ordered once-only beats and repeatable topics gated by progress, without quests/branches | Playable | Maintain | Homecoming, Curiosity | Seek context as the world opens without a quest log → curiosity | [`LORE_AND_STORY.md`](LORE_AND_STORY.md); story directors |
| HOME-11 | Relics are donated/read rather than sold; broken relics require a home-side transaction before consequence | Partial | Frozen | Growth, Homecoming, Curiosity | Turn a risky unique find into visible change through a person/place → attachment | [`GDD.md` §6.2–6.4](GDD.md); [`ITEMS.md` §2](ITEMS.md) |
| HOME-12 | Footlocker transfers ingredients into a finite persistent stash unavailable underground; two Elder ranks expand it 24 → 36 | Playable | Test | Risk, Growth, Homecoming | Preserve more future recipes by paying for bounded home capacity without deleting bag pressure → security/planning | [`METAGAME.md` §6.8](METAGAME.md) |
| HOME-13 | Bed advances to dawn, refills stamina, heals one heart per purchased Elder rank and autosaves; refused during runs | Playable | Test | Homecoming, Growth | Spend on a better home, then deliberately close a day and wake recovered → safety/ownership | [`METAGAME.md` §6.8](METAGAME.md) |
| HOME-14 | Maker's mark and boss/gold milestones gate arrivals/story but are not usable items or quests | Playable | Maintain | Homecoming, Curiosity | Make achievements change who is present and what is known → consequence | [`METAGAME.md` §6](METAGAME.md) |
| HOME-15 | Two endings resolve the four-floor prologue; Far Lantern opens the Long Descent afterwards | Designed | Frozen | Homecoming, Curiosity | Complete a bounded promise while pointing toward Valenfeld → closure/anticipation | [`GDD.md` §8](GDD.md) |
| HOME-16 | One persistent 32-minute civil day drives 05:00 dawn, 20:00 sunset and readable HUD time across every scene | Playable | Test | Homecoming, Risk | Plan remaining errands/expedition time against a legible closing day → rhythm/tension | issue #114; [`METAGAME.md` §6](METAGAME.md) |
| HOME-17 | Services open 07:00–20:00 (06:00 after Early Reveille); staffed NPCs physically move between work nooks and assigned bunks | Playable | Test | Homecoming, Growth | Treat keepers as inhabitants and plan service use instead of assuming permanent menus → attachment/planning | issue #114; [`METAGAME.md` §6](METAGAME.md) |
| HOME-18 | Dawn returns the player to their bunk; a missed underground dawn settles by death-loss rather than free extraction | Playable | Test | Risk, Homecoming | Respect the overnight boundary without finding a dominant wait-to-bank strategy → tension/closure | issue #114; `game_flow.gd` |
| HOME-19 | Surface weather is deterministic per day and only multiplies sky, fog, light, wind and local rain | Playable | Maintain | Homecoming, Curiosity | Let repeated returns differ in mood while navigation/rules remain trustworthy → place attachment | issue #114; `surface_weather.gd` |

### Relic consequences

The repair/donation transaction is `HOME-11`; these rows list each unique rule
it can switch on. The effects are implemented, but future-floor acquisition and
the full homecoming arc remain frozen and human-unproven.

| ID | Mechanic / rule | Status | Now | MDA target | Intended dynamic → aesthetic | Owner / evidence |
|---|---|---|---|---|---|---|
| RELIC-01 | Tally-Ledger unlocks forge rung 2 across every ladder | Playable | Maintain | Growth, Homecoming | Bring a unique find home to widen all near-term upgrade goals → anticipation | [`GDD.md` §6.2](GDD.md); `RelicDb.forge_rungs_known` |
| RELIC-02 | Anvil-Plate unlocks forge rung 3 across every ladder | Playable | Maintain | Growth, Homecoming | Turn boss victory into the forge's final capability tier → achievement | [`GDD.md` §6.2](GDD.md); `RelicDb.forge_rungs_known` |
| RELIC-03 | Still-Head unlocks the Ironhide Draught recipe | Playable | Maintain | Growth, Homecoming | Convert discovery into a new preparation option → anticipation | [`GDD.md` §6.2](GDD.md); `RelicDb` recipe gate |
| RELIC-04 | Cinder-Retort unlocks the Emberblood Draught recipe | Playable | Maintain | Growth, Homecoming | Convert discovery into an aggressive preparation option → anticipation | [`GDD.md` §6.2](GDD.md); `RelicDb` recipe gate |
| RELIC-05 | Glass-Kiln Core raises bottle capacity to four | Playable | Maintain | Growth, Homecoming | Make a unique home change enlarge the next-run safety stock → progression | [`GDD.md` §6.2](GDD.md); `RelicDb.bottle_cap` |
| RELIC-06 | Sustain-Verse teaches the Sustain working | Playable | Maintain | Risk, Growth, Curiosity | Translate found lore into a new tempo decision → discovery/agency | [`GDD.md` §6.2](GDD.md); `RelicDb.WORKING_RELICS` |
| RELIC-07 | Ballast-Verse teaches the Ballast working | Playable | Maintain | Risk, Growth, Curiosity | Translate found lore into a new sacrifice decision → discovery/agency | [`GDD.md` §6.2](GDD.md); `RelicDb.WORKING_RELICS` |
| RELIC-08 | Sounding-Rod makes the deep chest hum on arrival | Playable | Maintain | Curiosity, Homecoming | Let a donated object change how future floors are searched → attachment/discovery | [`GDD.md` §6.2](GDD.md); `RelicDb.chest_hums` |
| RELIC-09 | Warp-Stone lets a new run start at any permanently opened shortcut | Playable | Maintain | Risk, Homecoming, Curiosity | Convert prior route mastery into chosen starting depth → ownership/anticipation | [`GDD.md` §6.2](GDD.md); `RelicDb.garrison_shortcuts` |
| RELIC-10 | Rope-Drum reduces the extraction rate from 25% to 20% | Playable | Maintain | Risk, Homecoming | Make home change soften—but not remove—the exit price → earned relief | [`GDD.md` §6.2](GDD.md); `RelicDb.extract_rate` |
| RELIC-11 | Pillar-Shard lights the square and raises vendor prices by 10% | Playable | Maintain | Growth, Homecoming | See the market change and gain value from the same haul → prosperity/attachment | [`GDD.md` §6.2](GDD.md); `RelicDb.vendor_price_mult` |
| RELIC-12 | Riven Chord resolves the final relic state after Long Descent floor 10 | Partial | Frozen | Homecoming, Curiosity | Complete the long collection promise → closure/world curiosity | [`GDD.md` §6.2, §8](GDD.md) |

## Boundary and audit notes

- This ledger uses *mechanic* in MDA's broad sense. [`PUZZLES.md` §2](PUZZLES.md)
  uses the word more narrowly for the composed puzzle, while
  [`SCOPE.md`](SCOPE.md) owns its own budget count. Those counts do not change
  because this ledger names an atom's player-facing rule.
- Caller, gaze, riser and ledworthy enemy behaviours and the three phase-two
  puzzle atoms are documented candidates, not committed game mechanics. They
  stay outside the ledger until a scope decision admits them.
- Four-floor bosses, placements, relic consequences and Echo content may exist
  in data or test scenes without being complete, authorised production content.
- Open code/document defects remain listed in [`ITEMS.md` §8](ITEMS.md). Shared
  world-canon collisions remain in [`CANON_BRIDGE.md`](CANON_BRIDGE.md).
- Automated directors prove implementation seams, not player dynamics or
  aesthetics. The active human evidence lives in
  [`design-tests/CORE_LOOP_PROOF.md`](design-tests/CORE_LOOP_PROOF.md).

## Adding or changing a mechanic

Before implementation, add or amend its row with an MDA target, intended
dynamic, intended aesthetic, canonical owner and smallest evidence plan. A
mechanic with no intended dynamic/aesthetic is an **orphan mechanic** and a cut
candidate. A desired dynamic with no mechanic is a design gap. An intended
aesthetic with no observed dynamic is an unproven claim.

This ledger does not authorise work. [`NOW.md`](NOW.md) does.
