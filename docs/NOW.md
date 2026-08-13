# Now

**Stage: Pre-production — Raid Loop, Field Notes, and Boss Dynamism Proof**

## Pending Raid Loop human question

> When warned that the garrison will be raided, does the player make a deliberate
> stay-versus-extract decision, and does one built defense change that decision
> in a way they can explain?

The Fair-Weights Forge / smith quest was superseded by the raid pivot before any
human sessions were run. That supersession does not apply to Field Notes.

Implementation is complete and awaiting the precommitted five cold sessions.
The raid test and its criteria are in
[design-tests/RAID_LOOP_PROOF.md](design-tests/RAID_LOOP_PROOF.md).

## Implemented raid slice awaiting test

Test exactly one implemented vertical slice:

- Trigger it after donation of the Tally-Ledger.
- Add one unvoiced Vyr Builder using the existing generic Vyr body and shared
  service patterns.
- Add one optional West Gate Bolt-Thrower build quest using existing gold and
  components.
- Give one afternoon warning and one urgent 23:00 warning; the urgent warning
  interrupts sleep.
- Let underground players continue or consume one carried Escape Rope. The raid
  provides no summon, teleport, free Rope, or special extraction.
- Run one attack through the main gate: three kobolds and one orc.
- Show authoritative GARRISON integrity in the normal HUD. Only completed
  attacks on the courtyard command standard reduce it; all raiders dead above
  zero wins, while zero with any raider alive is irreversible loss.
- Let the built bolt-thrower hold if the player is absent. Without it, absence
  fails the raid. A present player fights manually.
- On failure, suppress and return the donated Tally-Ledger to its original
  dungeon location. Recovery restores the donation without another repair cost.
- Allow the event to occur once. Do not add recurrence scheduling.

This slice may reuse existing enemies, currencies, UI, dialogue presentation,
services, and garrison spaces. It may add only what the slice requires.

## Owner-authorised implementation alongside the freeze

### PS2 visual-cohesion initiative

The owner authorises an autonomous, system-by-system visual-quality pass across
the shared renderer, Highbridge garrison, the currently implemented dungeon,
and the existing outdoor area. [STYLEGUIDE.md](STYLEGUIDE.md) is the target.
Each area must stay on its own claimed card, use native-resolution before/after
frames, preserve combat/navigation space, and pass independent adversarial
review before landing.

The production visual scene roots are `scenes/rooms/garrison.tscn`—which embeds
the outskirts—and `scenes/rooms/dungeon.tscn`.
`scenes/rooms/garrison_outskirts.tscn` remains only the focused compatibility
and lookdev shell; production proof must also use the combined garrison surface.
Visual cards may change visible meshes, materials, lights, sky, fog, and
collision-free dressing. Room topology, ports, item and NPC placement,
collision shapes, navigation, interactions, schedules, quest state, camera
behavior, and UI are read-only unless a separate gameplay card authorises them.

This authorises lighting, environment, material, dressing, and presentation
changes needed to replace the legacy PSX look with coherent PS2-era stylized
realism. It authorises no new floor, boss, enemy kind, quest, reward, gameplay
system, UI screen, or production-content expansion.

Issue #203 is an active owner override to the frozen boss language. It
authorises refinement and proof of the existing fixed roster—four floor bosses
and four optional floor minibosses—without adding a model, item, attack shape,
fight, or floor. The current runtime implements orbiting/repositioning, authored
charges, leaps and thrown zones, armour and timed item-specific weak points,
true stagger segment caps, two pressure phases at half health, and one arena
turn for each full boss. Exact combat truth is owned by
[BOSSES.md](BOSSES.md).

The runtime slice and its dedicated automated acceptance pass are complete;
the five cold human sessions have not happened. The precommitted mechanical and
human evidence boundary is
[design-tests/BOSS_DYNAMISM_PROOF.md](design-tests/BOSS_DYNAMISM_PROOF.md).
Until that test resolves, issue #203 supports only the claim that the structure
is stronger and mechanically testable; it does not establish fun or boss
distinctness.

Issue #168 is an explicitly owner-authorised, bounded daily-life implementation
slice: one fishing pond and minigame, a three-meal Fish reserve, supper-derived
Fed state, visible derived morale, and a one-descent Well Fed benefit. Its exact
rules are owned by [GARRISON_LIFE.md](GARRISON_LIFE.md), and its future human
question is precommitted in
[design-tests/FISHING_PROVISIONS_PROOF.md](design-tests/FISHING_PROVISIONS_PROOF.md).

This work is accepted sequencing debt alongside the test freeze. It is not raid
evidence, does not change or satisfy the Raid Loop Proof criteria, and does not
become the active human test unless that test resolves or the owner changes this
document again.

Issue #184 is a second explicit owner override alongside the freeze. It
authorises exactly three durable, non-combat utility tools forged and reforged
by Brannoc—the Woodsman's Axe, Pickaxe, and Fishing Rod—plus deterministic,
depletable mining veins in ordinary non-entrance, non-maze dungeon rooms. The
fixed player contract is owned by [ITEMS.md](ITEMS.md), [METAGAME.md](METAGAME.md),
and [CONTRACT.md](CONTRACT.md); its future human question is precommitted in
[design-tests/MINING_TOOLS_PROOF.md](design-tests/MINING_TOOLS_PROOF.md).

This override supersedes only the former exclusions for mining and fishing
gear. It authorises no broader profession, collection, map marker, gate, room,
currency, reward id, combat use, inventory expansion, or additional fishing
location. It changes access and cost around fishing but is not evidence that
the near/deep fishing choice is deep; that hypothesis remains open in
[design-tests/FISHING_PROVISIONS_PROOF.md](design-tests/FISHING_PROVISIONS_PROOF.md).

Issue #197 is a third explicit owner override alongside the freeze. It
authorises shared quest-state infrastructure, one read-only Quests page in the
pause-menu ring, and punctuation-only world guidance: `!` for an available
quest or its current target, and `?` on an NPC with a ready turn-in. It seeds
exactly the already-built **Keep the Hearth** duty and the already-authorised
**West Gate Defence** project; both use their existing actions, costs, spaces,
and residents.

This override adds no third quest, chore, reward economy, voiced line, route,
NPC, location, or combat objective. It is state legibility for existing work,
not raid evidence and not a new human-test hypothesis.

Issue #198 is a fourth explicit owner-authorised bounded override alongside the
freeze. It permits only player pickup and throw of the existing explosive
barrels, plus one shared world-space lob landing marker used by both Burst and a
carried barrel. The barrel is never inventory, persistent gear, or a ring stop;
its existing fuse, impact, chain, and blast rules remain authoritative.

### Enemy tool-ladder prototype

Issue [#200](https://github.com/Metatransformer/awakening/issues/200) is a fifth
explicit owner override alongside the freeze. It authorises exactly four
behavior-bearing variants in tool-acquisition order: floor 1 Knotback/Sword,
floor 2 Lantern Seer/Bow, floor 3 Cinder Automaton/Burst and floor 4
Mirebell/Hookshot. Each is a tool question with a fast named-tool answer and a
slower ordinary-damage answer; none is a hard tool lock.

Implementation and deterministic automated proof are complete. The human
question remains unproven and its criteria are precommitted in
[design-tests/ENEMY_TOOL_LADDER_PROOF.md](design-tests/ENEMY_TOOL_LADDER_PROOF.md).
The variants use only temporary primitive kitbash attachments over existing
animated bipeds, add no `Enemy.DEFS` kind or permanent monster model, and keep
the rotation at seven kinds. At most one may appear in an ordinary room, and
none may be an elite or boss summon. This override adds no item, ammo, currency,
screen, boss beat, autoload, permanent art asset or broader production
authorisation.

Issue #199 is another explicit owner-authorised vertical expansion alongside
the freeze. Its completed slice expands authored floor room totals to
**8 / 11 / 12 / 13** with combat-only additions; guarantees one floor-scoped
Small Key detour-and-gate loop per floor; adds sparse counted Escape Rope,
Hardtack and Small Beer clear rewards; publishes live ordinary/Boss locks and
key counts through the shared minimap/MAP renderer; and makes Escape Rope
counted provision stock bought or found before use.

This is accepted sequencing debt, not Raid Loop evidence. It neither resolves
nor displaces the pending Raid Loop human question, and it authorises no broader
dungeon, floor, enemy, reward, map, provision, or extraction expansion beyond
the fixed [SCOPE.md](SCOPE.md) amendment.

Issue #206 is another explicit owner-authorised experiment alongside the freeze:
one Floor-1 Glint Trial prototype behind `--glint-mvp`. It may replace the normal
gate/puzzle anchors only in that flagged run, put one existing puzzle on an
optional post-guardian side branch beside a valid boss route, persist one solve,
and offer one derived Glimmer for one health, stamina, or magic choice at the
existing garrison statue. Its human question and stop conditions are fixed in
[design-tests/GLINT_TRIAL_MVP.md](design-tests/GLINT_TRIAL_MVP.md).

This override authorises no production rollout, random scheduler, additional
trial, new screen, new autoload, repeatable reward, or key-cycle expansion beyond
#199's implemented floor-scoped contract. Default runs remain evidence for the
current puzzle and Field Notes proofs.

## Authorized Field Notes implementation

> Do players connect filed notes to observed Cistern events, compare finite
> doctrines, notice the chosen effect, and name another observation or doctrine
> as a reason to descend again?

Field Notes are authorised dungeon progression work under
[issue #112](https://github.com/Metatransformer/awakening/issues/112).
Implementation and deterministic proof are complete; its five cold human
sessions remain pending.
The canonical bounded system is [FIELD_NOTES.md](FIELD_NOTES.md); the
precommitted human gate is
[design-tests/FIELD_NOTES_PROOF.md](design-tests/FIELD_NOTES_PROOF.md).

Implement exactly five fixed first-time Cistern observations, all visible in the
bedside book, and three one-rank doctrines at Aldric costing two notes each.
Extraction or death records completion without awarding currency; the receipt
names entries ready to file and directs the player to the book. A yellow marker
identifies ready entries there, A/interact files the selected entry and awards
its authored note value, and filed entries remain readable. Aldric still spends
the resulting five-note finite balance. This authorises no production floors,
additional observations, additional doctrines, repeatable faucet or item.

## Frozen

- Recurring raids or a recurrence scheduler.
- Scouts, watchtowers, guards, staffing, or expansion beyond the bounded
  Warm/Fed/Connected morale state.
- Multiple waves, routes, raid types, or defensive structures.
- Freeform construction or placement.
- Destructible buildings.
- Any explosive-barrel or hanging-lantern expansion beyond #198's player
  pickup/throw and shared Burst/barrel lob marker.
- Signature variants beyond #200's four, more than one per ordinary room,
  elite signatures, or boss-summon signatures.
- Mining expansion beyond #184's one deterministic vein rule, additional ore
  or tool types, fishing gear collections, and profession progression.
- Any currency beyond gold and Field Notes, UI screen beyond #197's one Quests
  page, voiced line, or enemy model.
- Any Glint Trial expansion beyond #206's flagged one-trial prototype and its
  single derived Glimmer.
- Floors, production content, boss/miniboss content beyond issue #203's fixed
  four-plus-four refinement, broad lore, or unrelated polish.

Implementation proves only that each bounded system works. It does not prove
the pending human hypotheses. Expansion remains frozen until the relevant human
tests are resolved and [SCOPE.md](SCOPE.md) is amended.
