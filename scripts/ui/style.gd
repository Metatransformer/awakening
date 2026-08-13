class_name Pal
extends RefCounted
## The palette and the layout metrics from docs/STYLEGUIDE.md, in one place so
## the HUD, the vendor screen and the shop cannot drift apart.
##
## Every channel byte is a multiple of 8. The PSX framebuffer was 15-bit RGB555
## -- 32 levels per channel -- so a value that is not a multiple of 8 is a colour
## the hardware could not display. Authoring inside the grid means the dither
## never has to move a colour we chose deliberately.
##
## Never `Color.BLACK` and never `Color.WHITE`: pure black and pure white are the
## fastest way to make a dirty palette look like a slide deck. VOID and BONE.

# --- Palette ----------------------------------------------------------------
const VOID := Color("080810")
const MIDNIGHT := Color("181828")
const ASH := Color("484050")
const BONE := Color("d8d0b8")
const MOTH := Color("807868")
const VITAL := Color("e04038")
const RUST := Color("b83818")
## Currency; the only exceptions are the authored Boss Key/Door progression mark
## and temporary overhealth's fixed health-bar end-cap. Not a general highlight.
const GOLD := Color("f8c038")
## The only cool saturated hue. Reserved for the way out.
const CYAN := Color("38d0c8")

const MOSS := Color("68a050")     ## uncommon
const COBALT := Color("5878c8")   ## rare
const ARCANE := Color("b060c0")   ## legendary

## Rarity tier -> colour. Common deliberately renders in the muted-text colour:
## a common drop should look like something you did not need to read.
const RARITY := [MOTH, MOSS, COBALT, ARCANE]

# --- Derived dithers --------------------------------------------------------
## Not new palette entries. STYLEGUIDE §2 allows "a dither of two entries", and
## these are those blends written down once so two systems reaching for the same
## mix cannot land on two different colours. Each channel is still a multiple of
## 8, because a 50/50 of two in-grid bytes is only in-grid if you round it back.

## A monster the hookshot has bitten. COBALT mixed half-and-half with EXTRACT
## CYAN: cyan alone is the hookshot's own hue (STYLEGUIDE §2 gives it "the
## hookshot line"), but on a body it reads as an extraction node with legs, and
## cobalt alone is cold stone rather than ice. Halfway is blue enough to say
## "frozen" and cyan enough to say "the thing in your right hand did that".
const FROST := Color("48a8c8")

# --- Bag value tiers --------------------------------------------------------
## The thresholds at which the bag stops being pocket change and starts being
## something you can lose. **A tier is a floor of the Descent**: each number is
## about where the median bag stands when the player takes a stair. The economy
## owns them -- `docs/METAGAME.md` §3.1 is the design of record and
## `tools/bag_curve.gd` is the measurement it is read off, re-runnable in ten
## seconds with no GPU. [tune]
##
## **T3 was 3000 and no bag could hold it** (card #49, 2026-08-11). The best
## selection of distinct full stacks a 12-slot bag can carry is 2782, so a
## starting bag could not reach it by any route the drop tables supply -- and the
## behaviour it gates (`Hud._draw_slips`' 0.5 Hz breath, and the repaint that
## keeps it moving) shipped dead.
## 2000 sits above the largest floor-2 bag in 400 simulated runs (2177, on a
## maxed save chaining the whole floor) and below the end of a careful floor 3-4,
## which is what makes it a threshold rather than a wall.
const T1 := 250      ## partway through floor 1 -- the median bag at that stair is 351
const T2 := 1000     ## the end of floor 2 -- median 1052
const T3 := 2000     ## the deep half: floor 3 on a bought bag, or floor 4 carried well

# --- Layout, as fractions of the viewport (STYLEGUIDE §5.7) -----------------
const SAFE := Vector2(0.025, 0.031)

## The top of the "you" pole. **It moved up by exactly one bar row (MAGIC_GAP +
## MAGIC_H = 12 px @720) when magic was inserted into the stack.**
##
## It used to say: the pole hangs downwards from here, the garrison control
## legend is drawn upwards from the bottom edge, the two grow towards each other,
## and the ~3 px between them is the only slack in the frame — so adding a row to
## the pole meant subtracting its height here and from CLUSTER_BOTTOM, in
## sympathy, forever. That was true, it was the reason the magic bar once printed
## through "WASD MOVE", and **it is no longer true**: the legend was moved out of
## the pole's column (decision 8, HUD_PLAN §15.12) and then deleted outright
## (card #121), so nothing shares this column any more.
##
## What survives is the reason the number is what it is. Do not read the old rule
## back out of it — the pole may grow downwards now, into an empty strip.
const HEALTH_ORIGIN := Vector2(0.031, 0.882)
## Health is a BAR, not a row of cells (styleguide §5.1 specifies cells; this is
## a deliberate override -- see the note on _draw_health). Width is fixed rather
## than growing with max health: a bar that gets longer as you buy containers
## walks across the screen and stops being a shape you recognise peripherally.
const HEALTH_W := 0.268            ## 343 px @1280
const HEALTH_H := 15.0             ## reference px
## One shared frame language for the four player meters. Health carries the
## deeper face and stronger diagonal; the authored bar rectangles and row
## positions do not move. Even the 6 px Tier 2 meters retain a 4 px live track.
const METER_BEZEL := 1.0
const HEALTH_METER_BEZEL := 2.0
const METER_INSET := 1.0
const HEALTH_METER_INSET := 2.0
const METER_DIAGONAL := 3.0
const HEALTH_METER_DIAGONAL := 6.0
const METER_FRAME_LIGHT_ALPHA := 0.28
const METER_FILL_LIGHT_ALPHA := 0.22
const METER_FILL_SHADOW_ALPHA := 0.32
## Directly below health, sharing its left edge. Deliberately shorter, so the
## two never read as one two-line meter in peripheral vision.
const STAMINA_RATIO := 0.62
const STAMINA_H := 8.0
const STAMINA_GAP := 4.0
## Magic, third in the "you" stack. Narrower than stamina and wider than heat, so
## the pole tapers -- four bars of the same length is a block, and the taper is
## what lets the stack be told apart at the edge of vision without reading any
## of it.
##
## It sits under stamina rather than over it because the two are read in that
## order: "can I dodge" is asked every second and "can I still spin" is asked
## before a fight. Above health was never a candidate -- health is the top of the
## pole and the eye starts there.
##
## **6 tall, not 8, and 6 px of gap above it rather than 4.** That pair is what
## makes the pole read as TWO instruments instead of four (HUD_PLAN decision 24).
## Health 15 and stamina 8 are Tier 1 -- read mid-fight without moving your eyes;
## magic, heat and draughts are Tier 2, glanced between beats. Before this, magic
## and stamina were the same height, the same construction, the same ticks and the
## same left edge, differing only in hue and 35 px of width -- so the only thing
## separating a Tier 1 row from a Tier 2 one was colour, which is exactly the
## channel a colour-blind player does not have. Now proximity groups them and
## uniform weight finishes the job: 15 / 8, a 6 px break, then 6 / 6 / 6.
##
## **It costs zero pixels, and that is checkable.** At 720p magic's top moves
## 666 -> 668 and its bottom stays at 674, so heat (678), the draught row (688)
## and the pole bottom (694) do not move, and the 4 px of safe-margin slack under
## the pole is unchanged. Verified in a rendered frame, not derived here.
const MAGIC_RATIO := 0.52
const MAGIC_H := 6.0
const MAGIC_GAP := 6.0
## The heat bar, third in the "you" stack and shortest of the three. It belongs
## in this pole rather than the money pole even though it PAYS in money: what it
## reports is a state of the body -- how fast you are killing and how long you
## have -- and you read it with the same glance that asks "can I dodge". What it
## is worth is printed beside it; what it has EARNED is over in the money pole,
## and that separation is deliberate.
const HEAT_RATIO := 0.44
const HEAT_H := 6.0
const HEAT_GAP := 4.0
## The draught row -- the LAST row of the pole, and the only one that is not a
## meter. Same width as heat so the pole's taper ends cleanly, same height so the
## three Tier 2 rows are one weight (see MAGIC_H), and its own gap constant so
## that adding a row below it never means editing heat's.
##
## Its geometry is here and its ROW INDEX is `Hud._pole_top(s, 4)`. Do not write
## the stack sum anywhere else: two expressions for one stack is how the row
## landed on the stamina bar once and on the magic bar a second time.
const DRAUGHT_RATIO := 0.44
const DRAUGHT_H := 6.0
const DRAUGHT_GAP := 4.0
## Gap between two draught slots. Wide enough that three slots read as three
## containers rather than as one ticked bar -- the whole point of the row not
## being a meter (HUD_PLAN decision 30).
const DRAUGHT_SLOT_GAP := 4.0
# PREMIUM_BASELINE (0.735) was here, and its comment described a money pole with
# a total at 0.900 and a fee at 0.940 -- two readouts deleted in 2026-08-09. The
# heat premium is drawn beside the heat bar in the VITALS pole now, which is
# where a state of the body belongs. HUD_PLAN decision 14's dead-constant sweep.
## --- The equipment strip, bottom-left --------------------------------------
## One compact cave-rock housing for [left hand][right hand][selected item].
## The paintings identify the equipment; the live bindings are small overlays
## inside the slots rather than a second row of controls outside the housing.
##
## **It sits over health now, not in the top-right corner.** Two reasons, and
## the first is the stronger: the cluster and the vitals stack are the same
## sentence — what I am holding, and what I have left to hold it with — and that
## sentence was being read across the full diagonal of the screen. The second is
## that the top-right corner is the one place a minimap can go (see MINIMAP_*
## below): the top-left is the floor card, and both bottom corners are the
## game's central decision (hud.gd's header). Something had to move and the
## corner that was a control surface is the one that had somewhere else to be.
##
## `CELL` remains the kit wheel's square cell. The equipment strip has its own
## narrow, taller geometry copied from Valenfeld's stance bar.
const CELL := 64.0
const EQUIPMENT_SLOT_W := 60.0
const EQUIPMENT_SLOT_H := 84.0
const EQUIPMENT_HAND_GAP := 10.0
## Wider than the hand gap so held equipment and the selected consumable remain
## two semantic groups inside one housing.
const EQUIPMENT_ITEM_GAP := 18.0
const EQUIPMENT_HOUSING_PAD := 8.0
const EQUIPMENT_CHAMFER := 5.0
## Ordered chips on the housing only. The cadence is deterministic so the rock
## face never crawls between HUD repaints.
const EQUIPMENT_GRAIN_STEP := 13.0
const EQUIPMENT_GRAIN_DARK_ALPHA := 0.42
const EQUIPMENT_GRAIN_LIGHT_ALPHA := 0.16
## Shares HEALTH_ORIGIN's x, so the whole bottom-left pole hangs off ONE left
## edge. Laid out from that edge rightwards and upward from CLUSTER_BOTTOM.
const CLUSTER_LEFT := 0.031
## Bottom edge of the entire rock housing. It clears HEALTH_ORIGIN.y (0.882),
## and every slot plus its in-slot action hint stays inside this bound.
const CLUSTER_BOTTOM := 0.855
## --- The minimap, top-right --------------------------------------------------
## The floor plan, in the corner the button cluster used to have. It is the only
## corner it can be in: top-left is the floor card, bottom-left is the body,
## bottom-right is the bag and the fee.
##
## Square, and sized so the widest floor in the game (the Chord Gate, 10 rooms)
## still puts a room at ~26 px — the size at which a chest glyph is a chest and
## not three gold pixels. Bigger than this and it starts eating the upper-middle
## third of the frame, which is where the over-the-shoulder camera puts the
## fight (see the note at the top of hud.gd).
const MINIMAP_RIGHT := 0.969   ## the same right edge as the bag and the fee
const MINIMAP_TOP := 0.052     ## level with the floor card opposite it
const MINIMAP_SIZE := 148.0    ## reference px, square
## Padding between the minimap's frame and the map fitted inside it. The map is
## fitted to the FULL floor bounds, so a room on the outermost cell puts its
## wall right on this margin — without it the outline and the frame touch and
## read as one thick line.
const MINIMAP_PAD := 8.0
const BAG_RIGHT := 0.969
# BAG_NUM_BASELINE (0.900) and SLIPS_TOP (0.795) were here. The first anchored a
# 32 px gold total that was deleted in 2026-08-09 and then went on positioning
# the extraction ring for a year of commits; the second dates from when the slip
# stack was authored top-down, and the stack grew UPWARD from SLIPS_BOTTOM
# since. Both were dead and both were still load-bearing-looking, which is worse
# than dead. HUD_PLAN decision 14/15.
#
# SLIPS_BOTTOM (0.845) has now gone the same way, and for a sharper reason:
# it was a SECOND opinion about where the inside of the rim is. The rim is
# RIM_TL..RIM_BR, the slips sit on the slot-mark row inside it, and a constant
# that has to be kept in agreement with two others by hand is a bug with a
# schedule. `Hud._draw_slips` derives its floor from the rim rect it is passed.
# HUD_PLAN §15.5.
const TOAST_BASELINE := 0.767
## Hugs its contents. The styleguide's original 0.740 left edge left a third of
## the box empty at every bag size a player will actually see, and an empty
## frame reads as a panel someone forgot to fill rather than as an instrument.
## 0.812 fits a six-digit total, which is past anything the drop tables produce.
##
## The bottom edge stops at 0.914 because it used to have to clear an
## `EXTRACT <charge>` line at 0.940 -- enclosing that too put "EXTRACT 238"
## starting left of the rim and crossing it, which read as a rendering bug. That
## line is gone (`Hud._draw_extraction`) and the bound stayed anyway: the rim
## frames THE BAG, and growing it into the empty strip below would frame nothing.
## The bag rim. Its right edge is `BAG_RIGHT`, and that is not a coincidence to
## be maintained by hand -- HUD_PLAN decision 4.5 gives the money pole ONE right
## edge, shared with the slips, the toast and the minimap, and the rim was the
## only thing in the column that had wandered off it.
##
## It was `0.978`, which put 5.8 px of the largest permanent element in the
## corner outside the safe margin. Decision 14 first said "snap it to the safe
## edge, 0.975" and §9 struck that twice: snapping to the margin was never the
## point, the margin only entered because the rim had drifted past it, and a
## fourth right edge 8 px outboard of the other three is what makes the money
## pole read as ragged. The number is `BAG_RIGHT`.
const RIM_TL := Vector2(0.812, 0.786)
const RIM_BR := Vector2(BAG_RIGHT, 0.914)
# ROOM_NAME_BASELINE (0.139) was here. The room-name card was replaced by the
# top-left floor card, which anchors off its own constants; §5.6 recorded the
# deletion and this did not.
## The floor card -- the dungeon's name and the level you are on. Top-left, which
## was the one corner of this HUD with nothing in it: the equipment and vitals
## are bottom-left, the bag bottom-right, and the minimap top-right.
##
## It shares HEALTH_ORIGIN's x so the left margin is ONE edge and not two. The y
## clears the safe area (0.031) by enough that the two-line card does not touch
## it -- an announcement pinned to the very top of the frame reads as a system
## notification rather than as part of the game.
const FLOOR_ORIGIN := Vector2(0.031, 0.052)

## Reference height every px measurement in the styleguide was authored against.
const REF_H := 720.0


## Scale a styleguide pixel measurement to the current viewport, landing on a
## whole pixel. A 1.5x scale that does not round leaves soft glyph edges, and
## soft edges are the whole treatment collapsing.
static func px(base: float, screen_h: float) -> float:
	return maxf(1.0, round(base * screen_h / REF_H))


# bag_color(value) was here -- BONE below T1, GOLD from T1 up, for a bag TOTAL
# that has not been drawn since 2026-08-09. `tier()` below is the live answer to
# the same question and it has four steps rather than two, which is what the rim
# reads. HUD_PLAN decision 14's dead-constant sweep.


static func tier(value: int) -> int:
	if value >= T3:
		return 3
	if value >= T2:
		return 2
	if value >= T1:
		return 1
	return 0


static func rarity_color(r: int) -> Color:
	return RARITY[clampi(r, 0, RARITY.size() - 1)]
