# OOT Dungeon Structure Reference — Forest Temple (primary) + Inside the Deku Tree

**Purpose.** This is the structural target our own dungeon is judged against. It is an explicit
node/edge graph of two real Ocarina of Time dungeons, followed by the design rules extracted from
them. Critics should be able to take our dungeon's room graph, run the same checks listed in
§4 "Acceptance rules", and get a pass/fail.

**Sourcing discipline.** Every claim below is tagged:
- `[decomp]` — from the `zeldaret/oot` decompilation (scene XML / actor C source). Hard fact.
- `[rando]`  — from the OoT Randomizer logic graph (`data/World/*.json`, `LocationList.py`).
  These files are a machine-checked model of vanilla reachability, so edges and gates are reliable.
- `[guide]`  — from walkthroughs (Thonky, Jegged, Link's Hideaway, VG Thought). Reliable for
  contents and ordering; less reliable for exact room identity.
- `UNCERTAIN` — sources disagree or the fact is not publicly enumerable. Do **not** build a
  critic assertion on an `UNCERTAIN` line.

Sources:
- https://github.com/zeldaret/oot — `assets/xml/scenes/dungeons/ydan.xml`, `Bmori1.xml`,
  `ydan_boss.xml`, `moribossroom.xml`; `src/overlays/actors/ovl_Bg_Mori_Elevator/z_bg_mori_elevator.c`;
  `ovl_Bg_Mori_Idomizu/z_bg_mori_idomizu.c`
- https://github.com/OoTRandomizer/OoT-Randomizer — `data/World/Forest Temple.json`,
  `data/World/Deku Tree.json`, `data/Glitched World/Forest Temple.json`, `LocationList.py`
- https://www.thonky.com/ocarina-of-time/forest-temple , https://www.thonky.com/ocarina-of-time/inside-deku-tree
- https://jegged.com/Games/Legend-of-Zelda-Ocarina-of-Time/Walkthrough/17-Forest-Temple.html
- https://www.linkshideaway.com/ocarina-of-time-walkthrough/forest-temple/
- http://www.vgthought.com/article/foresttemple

---

## 1. Headline numbers

| | Inside the Deku Tree (`ydan`) | Forest Temple (`Bmori1`) |
|---|---|---|
| Rooms in scene | **12** (`ydan_room_0`…`_11`) `[decomp]` | **23** (`Bmori1_room_0`…`_22`) `[decomp]` |
| Separate boss scene | `ydan_boss`, **2** rooms `[decomp]` | `moribossroom`, **2** rooms `[decomp]` |
| Small keys | **0** `[rando]` | **5** `[rando]` |
| Small-key locked doors | **0** `[rando]` | **5** `[rando/guide]` |
| Boss Key | **none** — plain barred boss door `[rando]` | **1**, + **1** boss-key door `[guide]` |
| Dungeon item | **Fairy Slingshot** `[rando]` | **Fairy Bow** `[rando]` |
| Chests | 6 `[rando]` | 13 `[rando]` |
| Gold Skulltulas | 4 `[rando]` | 5 `[rando]` |
| Map / Compass | both present | both present |

**The single most important number: 5 keys, 5 locks, zero slack.** The Forest Temple contains
exactly as many small keys as it has small-key doors, and all five locks sit on one linear chain
where every room has exactly two doors (one in, one out). There is no branch on which a key can be
spent wrongly, so the dungeon is softlock-proof by topology, not by a safety check. `[rando, vgthought]`

---

## 2. Forest Temple — node / edge graph

### 2.1 Confirmed room IDs

Only these room numbers are provable from public data. All other node IDs below are descriptive
names and are marked `UNCERTAIN`.

| Room | What it is | Evidence |
|---|---|---|
| **0** | First Room / entry courtyard | `[rando]` Lobby region, `First Room Chest` |
| **2** | Central Chamber (4 torches, elevator shaft) | `[decomp]` `z_bg_mori_elevator.c` tests `curRoom.num == 2`; `[rando]` Center Room pots `(2,0,12–17)` |
| **6** | Stalfos room — **both** the early 2-Stalfos fight **and** the later 3-Stalfos / Fairy Bow fight | `[rando]` `Lower Stalfos Pot 1/2 = (6,0,6/7)` **and** `Upper Stalfos Pot 1–4 = (6,0,8–11)` |
| **7, 8, 9** | Outdoor courtyard + well complex | `[decomp]` `z_bg_mori_idomizu.c` — the well-water actor runs only in `roomNum == 7 \|\| 8 \|\| 9` |
| **13** | Blue Poe (Beth) stairwell room | `[rando]` `Blue Poe Room Pot 1–3 = (13,0,6–8)` |
| **14** | Frozen Eye Switch room | `[rando]` `Frozen Eye Switch Room Pot 1/2 = (14,0,6/7)` |
| **16** | Green Poe (Amy) room | `[rando]` `Green Poe Room Pot 1/2 = (16,0,7/8)` |
| **17** | Basement (rotating room) | `[decomp]` elevator's lower terminus |

### 2.2 Item and key placement

| Item | Location | Chest id `[rando]` |
|---|---|---|
| Small Key #1 | First Room, chest on a tree stump across a gap (Hookshot) | `First Room Chest` |
| Small Key #2 | First Stalfos fight, lower floor of room 6 | `First Stalfos Chest` |
| Small Key #3 | Bottom of the drained well | `Well Chest` |
| Small Key #4 | Joelle (red Poe), after the painting puzzle | `Red Poe Chest` |
| Small Key #5 | Floormaster room off the outdoor upper ledge | `Floormaster Chest` |
| **Dungeon Map** | Small room off the high courtyard balcony, behind a Blue Bubble | `Map Chest` |
| **Compass** | Beth (blue Poe) | `Blue Poe Chest` |
| **Fairy Bow** | Big chest after the 3-Stalfos fight, upper floor of room 6 | `Bow Chest` |
| **Boss Key** | Lower level of the corridor-end room, **after** the corridor is straightened; Wallmaster guard | `Boss Key Chest` |
| Arrows (30) | Block Push Room, behind a fence — gold eye switch | `Eye Switch Chest` |
| Arrows (10) | Falling-ceiling checkerboard room | `Falling Ceiling Room Chest` |
| Arrows (5) | Basement rotating room | `Basement Chest` |
| Recovery Heart | Raised island in the courtyard (Hookshot the chest face) | `Raised Island Courtyard Chest` |

Note the shape: **the four "optional" chests contain only arrows and a heart.** Nothing
progression-relevant is ever off the forced path.

### 2.3 The five locks, in path order `[rando]`

| # | Where | Randomizer gate |
|---|---|---|
| L1 | Central Chamber (room 2), door above the side ledge → Skulltula hall → Block Push Room | `Central Area -> Before Block Puzzle: (Small_Key, 1)` |
| L2 | Top of the Block Push Room, past two Blue Bubbles → Twisted Corridor | `After Block Puzzle -> Twisted Hall: (Small_Key, 2)` |
| L3 | Wallmaster room at the far end of the Twisted Corridor, up the ladder → first Poe stairwell | `Twisted Hall -> Red Poe Room: (Small_Key, 3)` |
| L4 | Top of the stairs in the *second* Poe stairwell → Wallmaster hall | `Blue Poe Room -> Second Twisted Hallway: (Small_Key, 4)` |
| L5 | End of the green-Bubble hall → Frozen Eye Switch room (14) | `Second Twisted Hallway -> Frozen Eye Switch Room: (Small_Key, 5)` |

**Locks L1–L3 are pre-Bow; L4 and L5 are post-Bow, and both of their keys (#4 Joelle, #5
Floormaster) are themselves Bow-gated.** The dungeon item sits at the midpoint of the key chain.

### 2.4 Node/edge list

```
FT0  FIRST ROOM (room 0) — outdoor stone courtyard
     contents: 2 Wolfos; Gold Skulltula #1 above the vines;
               chest = Small Key #1 on a dead tree across a gap
     exits:
       -> SFM Forest Temple Entrance Ledge          [dungeon exit]
       -> FT1 Skulltula Hallway                     [walk]
     gates: Hookshot to reach the vines and the key chest

FT1  SKULLTULA HALLWAY                              [UNCERTAIN id, likely room 1]
     contents: 1 Skulltula
     exits: FT0 <-> FT2

FT2  CENTRAL CHAMBER (room 2) — THE HUB
     trigger: on approach, the four Poe Sisters steal the four coloured flames
              and scatter into the dungeon (opening cutscene)
     contents: 4 unlit torches, 6 pots, fairy pot, Gold Skulltula #2,
               and the ELEVATOR SHAFT in the floor centre
     exits:
       E2a south                 -> FT1 -> FT0
       E2b NW arch               -> FT7 NW Courtyard      [gate: Song of Time — blue Time Block]
       E2c NE door               -> FT9 NE Courtyard      [gate: Bow/Slingshot]
       E2d side door, blue-bubble corridor -> FT5 Stalfos LOWER
       E2e door above ledge+stairs -> [L1] -> FT11 -> FT12 Block Push Room
       E2f ELEVATOR SHAFT        -> FT21 BASEMENT (room 17)
                                   [gate: ALL FOUR Poe flames lit]

FT5  STALFOS ROOM — LOWER FLOOR (room 6, bottom)
     contents: 2 Stalfos (fought one at a time); chest = Small Key #2; 2 pots (1 fairy)
     exits: -> FT2
            <- receives the one-way fall from FT17 above          *** LOOP F4 ***

FT7  NW / WEST COURTYARD (room 8) — open air
     contents: Big Deku Baba, Octorok, Skullwalltulas on a vine wall,
               THE WELL (full of water), 2 recovery hearts on a narrow walkway
     exits:
       -> FT2                                       [back through the Time Block arch]
       -> FT8 High Balconies                        [gate: climb vines, clear Skullwalltulas]
       -> FT9 NE Courtyard                          [gate: Silver/Golden Scale to swim, or Iron Boots]
       <- receives the one-way drop from FT20        *** LOOP F3 ***

FT8  HIGH BALCONIES (courtyard upper ring)
     contents: side room w/ Blue Bubble -> DUNGEON MAP chest;
               a HOOKSHOT TARGET across the gap -> FLOOR SWITCH
     effect:  *** the floor switch DRAINS THE WELL *** (BgMoriIdomizu, rooms 7/8/9) [decomp]
     exits: drop -> FT7, drop -> FT9, ladder -> FT10 Well (only once drained)

FT9  NE / RAISED-ISLAND COURTYARD (room 7)
     contents: raised island, chest (Recovery Heart) taken by Hookshotting the chest's
               front face, Gold Skulltula #3
     exits: -> FT8 (very high vines / Longshot), -> FT7 (swim / Iron Boots),
            <-> FT2 (E2c), <- receives FT19c exit                 *** LOOP F5 ***

FT10 THE WELL (room 9) — enterable only once drained
     contents: ladder down, underground passage, chest = Small Key #3, 2 recovery hearts
     exits: passage end -> vines up -> courtyard -> door near the Deku Baba
            -> FT2 Central Chamber                               *** LOOP F1 ***

FT11 SKULLTULA HALL (behind L1)                     [UNCERTAIN id]
     exits: FT2 <-> FT12

FT12 BLOCK PUSH ROOM — 3 vertical levels           [UNCERTAIN id]
     contents: Blue Bubbles
     puzzle A: a block with ARROWS PAINTED ON THE FLOOR — push it along the arrows,
               then take a side corridor around to reach a DIFFERENT FACE of the same
               block and push from the new angle until it seats
     puzzle B: climb to level 3, push the RED block until it stops; climb down onto
               block A, use it to reach a new face of the red block, push it home, climb up
     side:     a fenced ledge on level 3 with a GOLD EYE SWITCH — visible now,
               openable only with the Bow (`Eye Switch Chest`, Arrows 30)
     exits:
       -> FT13 Blue Bubbles Room (up)
       -> FT20 Outside Upper Ledge via an arch   [normal traffic is FT20 -> FT12;
                                                  reverse needs Hover Boots per [rando]]

FT13 BLUE BUBBLES ROOM + GREY EYE SWITCH           [UNCERTAIN id]
     contents: 2 Blue Bubbles; a hole in the floor;
               *** THE GREY EYE SWITCH *** above the corridor door — shooting it
               TOGGLES the twisted corridor between twisted and straight.
               You shoot it three separate times over the dungeon.
     exits: -> [L2] -> FT14 Twisted Corridor
            -> FT20 Outside Upper Ledge
            <- receives the one-way drop out of the Boss Key room  *** LOOP F2 ***

FT14 TWISTED CORRIDOR (BgMoriHineri)               [UNCERTAIN id]
     The corridor is rotated 90°, so you walk on what should be a wall.
     hazard: Wallmasters — a grab teleports you to the DUNGEON ENTRANCE  *** LOOP F8 ***
     exits: -> FT15

FT15 CORRIDOR-END / WALLMASTER + LADDER ROOM       [UNCERTAIN id]
     WHEN TWISTED:      drop to the bottom, kill the Wallmaster, climb the ladder,
                        [L3] -> FT16
     WHEN STRAIGHTENED: the geometry re-aligns; the lower level now holds the
                        *** BOSS KEY CHEST *** + a Wallmaster + A HOLE IN THE FLOOR
                        -> drop -> FT13                            *** LOOP F2 ***

FT16 POE STAIRWELL ROOM #1 (behind L3)
     "There is nothing to do in this room yet." A tall room with a staircase, POE
     PAINTINGS on the walls, and one coloured torch. Deliberately un-actionable until
     the Bow — a plant-then-pay-off beat.
     exits: down the stairs -> FT17

FT17 STALFOS ROOM — UPPER FLOOR (room 6, top)      *** THE FAIRY BOW FIGHT ***
     contents: 1 Stalfos then 2 more; the first revives if you are slow.
               An open centre — falling drops you to FT5.
               chest = *** FAIRY BOW (+30 arrows) ***; 4 pots
     exits: red-carpet door  -> FT18a Joelle's stairwell
            blue-carpet door -> FT18b Beth's stairwell (room 13)
            hole in the floor -> FT5 -> FT2                        *** LOOP F4 ***

FT18a JOELLE (RED POE) STAIRWELL
     puzzle: shoot each Poe painting with an arrow while the ghost is visible in it;
             if it vanishes, walk away and wait. All hit -> Joelle materialises.
     fight:  block her spin with the shield, then sword or arrow her.
     reward: RED flame flies to a Central Chamber torch; chest = Small Key #4

FT18b BETH (BLUE POE) STAIRWELL (room 13)
     same painting puzzle; BLUE flame lights the second torch; chest = COMPASS; 3 pots

     UNCERTAIN — WHICH ROOM CARRIES WHICH LOCK:
       Thonky: L3 opens into the BLUE room, L4 sits atop the RED room.
       Jegged + [rando] Glitched-World regions: the reverse
         (`Twisted Hall -(key3)-> Red Poe Room -(Stalfos)-> Blue Poe Room -(key4)->
           Second Twisted Hallway`).
       All sources agree: the two Poe rooms are NOT directly connected — they connect
       only THROUGH the Stalfos/Bow room (FT17). Contents are fixed:
       Joelle/red = Small Key, Beth/blue = Compass.

FT19 SECOND TWISTED HALLWAY complex (behind L4)    [UNCERTAIN id]
     part 1: drop to the floor, a Wallmaster hunts you — circle-strafe, kill, climb out
     part 2: a hall with two GREEN BUBBLES, ending at [L5]
     exits: -> [L5] -> FT14b (room 14)
            once twisted: back through -> end room -> jump down the hole -> FT19b

FT14b FROZEN EYE SWITCH ROOM (room 14)
     contents: spinning platforms orbiting a central lava/brazier pillar;
               an ICE-ENCASED EYE SWITCH on the west wall; 2 pots
     puzzle: stand on a rotating platform and line up so the arrow's flight path passes
             THROUGH the flame — the flaming arrow melts the ice
     effect: TWISTS the second hallway (FT19)
     exits: back to FT19

FT19b FALLING CEILING / CHECKERBOARD ROOM          [UNCERTAIN id]
     hazard: the ceiling slams down; survive in the recessed safe tiles.
             Tiles with a shadow hide a Skulltula.
     sequence: safe hole on the left -> floor switch on the right wall (opens the exit)
               -> chest (Arrows 10) from the safe tile to its left -> run for the exit
     exits: -> FT19c

FT19c AMY (GREEN POE) BLOCK-PUZZLE ROOM (room 16)
     puzzle: shoot the Poe painting -> five blocks drop and the camera shows the target
             pattern from above. FOUR green blocks belong; ONE blue block is a decoy.
             Pull the decoy clear and push the four into the pictured arrangement within
             ~60 s, or the blocks reshuffle with the decoy somewhere new.
     fight:  Amy appears; shield-then-shoot.
     reward: GREEN flame lights the third torch; 2 pots
     exits: -> Skulltula hallway -> FT9 NE Courtyard -> FT2      *** LOOP F5 ***

FT20 OUTSIDE UPPER LEDGE                            [UNCERTAIN id]
     contents: the Floormaster room (Small Key #5), a narrow Gold-Skulltula walkway
     exits: -> FT12 Block Push Room (arch)
            -> drop off into FT7 NW Courtyard                     *** LOOP F3 ***

FT2' CENTRAL CHAMBER — MEG (the fourth Poe)
     Walk to the centre with three torches lit. Meg appears and splits into FOUR
     identical copies. The real one does an EXTRA SPIN as the copies form (and reads
     slightly brighter). Lock on, shoot with the Bow, repeat.
     *** THE ELEVATOR RISES. Ride it down. ***
     [decomp] BgMoriElevator exists only in rooms 2 and 17 and refuses to initialise
     elsewhere ("Forest Temple obj elevator room setting is dangerous").

FT21 BASEMENT — ROTATING ROOM (room 17)
     mechanic: BgMoriKaitenkabe — push one of the large wall slabs to ROTATE THE WHOLE
               ROOM about its axis, changing which side passages line up with the exits.
               (Always push the same direction or you lose track of orientation.)
     objective: find and step on THREE floor switches hidden across the rotational
                states to open the gate.
     contents: a Skulltula room with Gold Skulltula #5 and `Basement Chest` (Arrows 5)
     exits: -> FT22

FT22 BOSS CORRIDOR — blue-carpet tunnel
     *** BOSS KEY DOOR *** -> moribossroom (2 rooms)

BOSS PHANTOM GANON (moribossroom)
     Phase 1: six paintings ring the arena; two horses approach, one is a decoy (it turns
              around), the real one is bathed in purple light — shoot it with the Bow.
              Standing on one of the small Triforce sigils on the rim makes his lightning miss.
     Phase 2: he dismounts and fires energy orbs — volley them back with the sword until
              one connects, then melee him while he is down.
     Reward: Heart Container + Forest Medallion.
```

### 2.5 Loops, shortcuts and one-way drops

This is the part that makes the dungeon *cyclic* rather than a tree. Nearly every wing ends by
ejecting you into an earlier room rather than making you walk back.

| ID | Loop | Type |
|---|---|---|
| **F1** | **Well → Central Chamber.** The underground well passage (room 9) ends at a vine climb back into the courtyard, and a door near the Deku Baba puts you straight back in room 2. You never re-walk the balcony/Hookshot route. | Return loop |
| **F2** | **Boss Key room → Blue Bubbles room.** After taking the Boss Key from the straightened corridor's end room you drop through a hole and land back in FT13, on the *entry* side of the twisted corridor. | One-way drop, backwards |
| **F3** | **Outside Upper Ledge → NW Courtyard.** The ledge holding Small Key #5 dumps you into the west courtyard, rejoining the hub network. `[rando]` models `Outside Upper Ledge -> NW Outdoors: True` with a Hover-Boots-only reverse — i.e. intended traffic is outbound. | One-way drop |
| **F4** | **Bow room → first Stalfos room.** The decisive one. `Upper Stalfos Pot 1–4` and `Lower Stalfos Pot 1–2` are **both in room 6** `[decomp/rando]` — the 3-Stalfos/Fairy-Bow arena is the *upper storey of the very room where you fought two Stalfos in the first ten minutes*. Falling through the hole during the Bow fight drops you back to the early game, one door from the hub. Room reuse across the two halves at zero geometry cost. (Room identity is decomp-confirmed; the drop-edge itself is `[guide]` — high confidence, not decomp-proven.) | One-way drop, backwards |
| **F5** | **Amy's wing → NE Courtyard → Central Chamber.** After the green flame, a short Skulltula hallway comes out in the courtyard and back into the hub for Meg. The eastern excursion closes itself. | Return loop |
| **F6** | **The two Poe stairwells are joined through the Stalfos room.** L3 admits you to one; you descend, cross the Bow room, and come up inside the other — where L4 waits. The Bow room is the pivot joint of the back half. | Hub loop |
| **F7** | **The twistable corridors are reversible state, not one-shot.** Shoot the grey eye to *straighten* the corridor and reach the Boss Key; shoot it again to *re-twist* it so you can traverse back and reach L4. The same geometry serves both directions. Repeated with the frozen eye switch and the second hallway. | Toggleable topology |
| **F8** | **Wallmaster = forced full loop.** A grab teleports you to room 0. The punishment for standing still is re-running the whole spine. | Punitive one-way |
| **F9** | **The elevator.** Room 2 ↔ room 17 `[decomp]`. Purely a reward-gate — it only exists once all four flames are lit. | Vertical shortcut |

### 2.6 The back-half unlock

**Opening the big chest after the three-Stalfos fight and getting the Fairy Bow** (upper floor of
room 6). Everything after it is Bow-gated, and the Bow retroactively unlocks things you have
already walked past:

- The **Poe paintings** in both stairwell rooms — the "nothing to do in this room yet" beat from an
  hour earlier pays off (Joelle → Small Key #4, Beth → Compass).
- The **grey eye switch** in FT13 — straightens/re-twists the corridor, the only route to the Boss Key.
- The **gold eye switch** behind the fence in the Block Push Room — a chest you could see but not open.
- The **frozen eye switch** in room 14 — requires shooting an arrow *through a flame*: a
  second-order use of the same item.
- **Amy's** painting, **Meg's** four-copy fight in the hub, and **Phantom Ganon** himself.

### 2.7 Softlock analysis

**Vanilla cannot softlock.** `[rando/vgthought]`
- All five keys are on or immediately adjacent to the forced path; none is optional or
  order-dependent.
- All five locks are on **one linear chain** with no branch, so a key cannot be spent on the
  "wrong" door.
- The four off-path chests contain arrows and a heart only.
- Every one-way drop (F2/F3/F4) and the Wallmaster teleport (F8) costs walking time, never
  progress: each lands you in a room you can walk back out of.
- The Boss Key is on the forced path — you cannot reach L4 without passing through the
  straightened corridor's end room.

---

## 3. Inside the Deku Tree — node / edge graph (the smaller model)

Useful as the *first-dungeon* template: **zero keys, zero locks.** All gating is item- and
skill-based. Confirmed room IDs `[rando]`: **room 0 = the main Lobby**
(`Lower/Upper Lobby Recovery Heart = (0,0,26)/(0,0,27)`); **room 9 = the B2 pre-boss area**
(`Basement Recovery Heart 1–3 = (9,0,7/8/9)`). The other ten IDs are `UNCERTAIN`.

```
N0  LOBBY (room 0) — three vertical levels inside ONE scene room
      contents: Deku Babas, ladder, spiral ramp, MAP chest, a wall of vines with
                3 Skullwalltulas on it, a SPIDERWEB FLOOR at the bottom, 2 hearts
      exits:
        E0a ramp-top door -> N1 Deku Scrub Room (2F)
        E0b vine wall (1F -> 3F)          [gate: kill 3 Skullwalltulas -> needs Slingshot]
        E0c 3F ledge door -> N3 Compass Room
        E0d *** ONE-WAY DROP *** run off a 3F ledge, fall the full height of the tree,
            punch through the spiderweb floor -> N4 Basement B1
        E0e entrance -> KF Outside Deku Tree

N1  DEKU SCRUB ROOM (2F)                                    [UNCERTAIN id]
      contents: 1 Deku Scrub — deflect its nut with the shield (teaches shield use)
      exits: -> N0; -> N2 (door opens when the Scrub is beaten)

N2  SLINGSHOT ROOM (2F, drops to its own 1F)                [UNCERTAIN id]
      contents: falling stone platform, *** SLINGSHOT chest ***, vines to a side chest,
                bushes below, a RAISED LADDER with a green switch-target above the door
      exits: -> N1  [gate: shoot the green target to drop the ladder, drop to the lower
                     floor, climb back out]
      NOTE: the room's own exit is opened from the far side BY THE ITEM YOU JUST TOOK.

N3  COMPASS ROOM (3F, two levels)                           [UNCERTAIN id]
      contents: floor switch raising 3 timed platforms, COMPASS chest, alcove with a
                Gold Skulltula + side chest, Deku Babas, lit + unlit torch, vines back up
      exits: -> N0 3F  [gate: light the unlit torch with a Deku Stick]

N4  BASEMENT B1 — WATER CHAMBER                             [UNCERTAIN id]
      contents: water, Deku Baba platform, vines w/ Gold Skulltula, barred alcove w/
                Gold Skulltula, floor switch that lights a torch and reveals a chest,
                a SPIDERWEB WALL over a door
      exits: E4a web door -> N5   [gate: lit Deku Stick]
             E4b <- receives the one-way drop E0d
             E4c <- receives falls from N10                  *** LOOP L2 ***

N5  B1 DEKU SCRUB ROOM ("2 3 1")                            [UNCERTAIN id]
      contents: a Scrub who tells you the boss-room order "2 3 1"; an eye switch
      exits: -> N6  [gate: shoot the eye switch with the Slingshot]

N6  UNDERWATER-SWITCH / MOVING PLATFORM ROOM                [UNCERTAIN id]
      contents: spiked bar over water, underwater floor switch (dive to lower the water),
                timed moving platform, Skulltula, large pushable block with a floor groove
      exits: -> N7  [gate: lower water, ride platform, push block, climb it to the ledge]

N7  THREE-BABA / TWO-TORCH ROOM                             [UNCERTAIN id]
      contents: 3 RESPAWNING Deku Babas (an infinite Deku Stick farm), 2 unlit torches
      exits: -> N8  [gate: light both torches]

N8  GREAT CIRCULAR WEB ROOM                                 [UNCERTAIN id]
      contents: Skulltula, Deku Baba, lit torch, TWO spiderweb walls; the room centre
                spawns falling enemies — stay on the rim
      exits: E8a web #1 -> N9   [gate: lit Deku Stick]
             E8b web #2 -> crawlspace -> N10  [gate: lit Deku Stick, then crawl]

N9  BASEMENT BACK ROOM                                      [UNCERTAIN id]
      contents: Gold Skulltula #4 behind breakable rocks
      gate: Bombs + Boomerang/Hookshot — a deliberate RETURN-VISIT STUB, unreachable
            on the first playthrough

N10 BASEMENT LEDGE (the shortcut-block room)                [UNCERTAIN id]
      contents: a narrow ledge above the B1 water chamber, a pushable block, a torch,
                SPIDERWEBS ON THE FLOOR
      exits: E10a *** ONE-WAY DROP *** roll into the floor webs with a lit Deku Stick
                  -> fall through -> N11 (room 9)
             E10b falling off the ledge -> N4               *** LOOP L2 ***
             E10c push the block over the ledge -> creates a PERMANENT CLIMB-BACK
                  shortcut from N4 up to N10 (opened from the far side)
             E10d crawlspace back -> N8/N9

N11 B2 PRE-BOSS (room 9)
      contents: water pool with 3 recovery hearts, a slope, THREE Deku Scrubs that must
                be beaten in the order 2-3-1 learned back in N5
      exits: -> ydan_boss (Queen Gohma)

BOSS ydan_boss (2 rooms): Gohma arena + blue-warp antechamber.
      Stun the red eye with the Slingshot, then sword it. Heart Container + Kokiri's Emerald.
```

**Deku Tree loops**

- **L1 — the lobby web drop.** From the 3F ledges you deliberately run off and fall the full height
  of the tree through the spiderweb floor. One-way, and the *only* normal route to B1. The entire
  top half of the dungeon exists to get you high enough to fall.
- **L2 — Basement Ledge ↔ B1.** Falling off N10 dumps you into N4 and forces the long walk back
  through N5→N6→N7→N8. Pushing the block over the ledge converts that punishment into a climbable
  shortcut. `[rando]` models `Deku Tree Basement Ledge -> Deku Tree Basement: True` as one-way.
- **L3 — floor-web drop to B2.** N10 → N11 is one-way.
- **L4 — Slingshot Room ladder.** You shoot down a ladder you cannot otherwise reach. Micro-version
  of the same "open it from the far side" idea.
- **L5 — Back Room stub (N9).** A dead end you *cannot* finish on the first visit.

**Deku Tree back-half unlock: the Fairy Slingshot.** Immediately after taking it you use it to
(a) shoot the ladder that lets you leave the room, (b) clear the Skullwalltulas off the lobby vine
wall — the only way up to 3F, (c) hit the eye switch in N5, and (d) stun Gohma. There is no key
economy at all: one item and one fire source (Deku Sticks) are the entire lock system.

---

## 4. Acceptance rules — what our dungeon must satisfy

These are the falsifiable structural checks extracted from the two graphs above. A critic should be
able to run each against our room graph and return pass/fail.

**Key economy**
1. `keys_found == locked_doors`. Exactly. No spare keys, no spare locks. (Forest Temple: 5 = 5.)
2. Every locked door lies on a **single linear chain**. Formally: contracting all non-locked edges
   must leave a path graph, not a tree with branches. This is what makes key-wasting impossible.
3. Every room on the locked chain has exactly **two** doors — one in, one out.
4. No key is behind an optional branch. Every key is on, or one room off, the forced path.
5. Off-path chests contain **consumables only** — never progression.

**The dungeon item**
6. There is exactly one dungeon item, and it sits at roughly the **midpoint of the key chain**
   (Forest Temple: locks 1–3 before, locks 4–5 after; and *both* remaining keys are item-gated).
7. The item must **retroactively** unlock at least **three** things the player has already walked
   past and could see but not use. (Forest Temple: two rooms of Poe paintings, the grey eye switch,
   the fenced gold eye switch, the frozen eye switch.)
8. At least one use of the item must be **second-order** — the item combined with something else in
   the world, not just "point at target". (Forest Temple: shooting an arrow *through a flame* to melt ice.)
9. Plant the payoff early: at least one room the player enters pre-item where the correct reaction is
   *"there is nothing to do here yet."*

**Cyclic topology (this is the anti-linearity test)**
10. The room graph must contain at least **three independent cycles** — i.e. `edges - nodes + 1 >= 3`.
    A tree is a fail.
11. At least **two one-way drops** that land the player in an *earlier* room, not a later one.
    (Forest Temple has three: F2, F3, F4.)
12. At least **one shortcut opened from the far side** — a block pushed off a ledge, a ladder shot
    down, a door unbarred from behind. The player must never be the one to walk the long way twice.
13. At least **one hub room** re-entered **four or more** times in altered states.
14. **Reuse space, don't add it.** At least one room must serve two different purposes at two
    different points in the dungeon (Forest Temple room 6: tutorial fight downstairs, item fight
    upstairs, connected by a fall). Room *count* is a bad proxy for density.
15. At least **one piece of persistent world state** the player toggles that changes topology
    (well water level; corridor twisted/straight). Bonus if it is **reversible** and the player must
    toggle it back.

**Map / compass / boss key**
16. Map and Compass exist and are **off** the critical path (they are convenience, not progress).
17. The Boss Key is **on** the forced path, behind the dungeon item, and gates exactly one door.
18. The boss lives in a **separate scene** with its own small room count (both OOT dungeons: 2 rooms).

**First-dungeon variant (the Deku Tree profile)**
19. A first dungeon may have **zero keys and zero locks** — gate entirely on the item plus one
    consumable resource (Deku Sticks / fire). If so, rules 1–4 are vacuous but 10–15 still apply:
    the Deku Tree still has five loops.
20. Include at least one **return-visit stub**: a visibly reachable reward that is genuinely
    impossible with the current toolset.
