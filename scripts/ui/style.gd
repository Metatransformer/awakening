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
## Currency, and ONLY currency. Not a torch, not a title, not a highlight.
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
## something you can lose. [tune]
const T1 := 250
const T2 := 1000
const T3 := 3000

# --- Layout, as fractions of the viewport (STYLEGUIDE §5.7) -----------------
const SAFE := Vector2(0.025, 0.031)

## The top of the "you" pole. **It moved up by exactly one bar row (MAGIC_GAP +
## MAGIC_H = 12 px @720) when magic was inserted into the stack.** The pole hangs
## DOWNWARDS from here and the garrison control legend is drawn UPWARDS from
## KEYS_BASELINE, so the two grow towards each other and the only slack in the
## frame is the ~3 px between them. Before magic, the garrison pole ended at
## stamina and just cleared the legend's first line; adding a row without moving
## this printed the blue bar straight through "WASD MOVE".
##
## So: add a row to the pole, subtract its height here and from CLUSTER_BOTTOM.
## The heat bar is exempt from the sum -- it is dungeon-only and the legend is
## garrison-only, which is why the two have never had to clear each other.
const HEALTH_ORIGIN := Vector2(0.031, 0.882)
## Health is a BAR, not a row of cells (styleguide §5.1 specifies cells; this is
## a deliberate override -- see the note on _draw_health). Width is fixed rather
## than growing with max health: a bar that gets longer as you buy containers
## walks across the screen and stops being a shape you recognise peripherally.
const HEALTH_W := 0.268            ## 343 px @1280
const HEALTH_H := 15.0             ## reference px
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
const MAGIC_RATIO := 0.52
const MAGIC_H := 8.0
const MAGIC_GAP := 4.0
## The heat bar, third in the "you" stack and shortest of the three. It belongs
## in this pole rather than the money pole even though it PAYS in money: what it
## reports is a state of the body -- how fast you are killing and how long you
## have -- and you read it with the same glance that asks "can I dodge". What it
## is worth is printed beside it; what it has EARNED is over in the money pole,
## and that separation is deliberate.
const HEAT_RATIO := 0.44
const HEAT_H := 6.0
const HEAT_GAP := 4.0
## The heat premium, right-aligned in the bag column. It sits ABOVE the toast
## line because everything below is spoken for -- slips at 0.845, the total at
## 0.900, the fee at 0.940 -- and because reading down the money pole then goes
## "+96 HOT / what you just picked up / what it all is / what leaving costs",
## which is the order the thoughts actually arrive in.
const PREMIUM_BASELINE := 0.735
## --- The button cluster, bottom-left ----------------------------------------
## The three item buttons in the physical shape of the D-pad they sit on
## (docs/CONTRACT.md §2.5 #6), and — since they are the same KIND of thing — the
## two hands beside them. They are not readouts, they are a control surface: the
## arrangement is what tells you which button draws which item, and that is only
## true if the arrangement matches your thumb.
##
## Every cell here answers "what do I press", so they stay ONE cluster with one
## key cap each; splitting that question across two corners means answering it
## with two glances, which is why the hands are not a separate instrument.
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
## Cells are ~2x the old 32/34, and both sizes collapsed to ONE: at this scale a
## 2 px difference between the hand cell and the button cell stops reading as
## deliberate and starts reading as a bug.
const CELL := 64.0
const CELL_GAP := 12.0
## Gap between the hands pair and the item cell — wider than CELL_GAP so the
## cluster reads as two groups (what he is holding, what he has selected) and not
## as three cells in a row.
const CLUSTER_GAP := 22.0
## Shares HEALTH_ORIGIN's x, so the whole bottom-left pole hangs off ONE left
## edge. Laid out from that edge rightwards and from CLUSTER_BOTTOM upwards, so
## a taller cell or an extra text row grows into the empty middle of the screen
## rather than off an edge — which is what the old right-anchored version was
## protecting against and is still the rule, just about a different corner.
const CLUSTER_LEFT := 0.031
## The baseline the cluster's LAST row (the loadout line) sits on. Clear of
## HEALTH_ORIGIN.y (0.882) by enough that the key caps under the cells never
## touch the health bar's VOID hairline. Moves with it, by the same row height --
## see the note on HEALTH_ORIGIN.
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
## Room under a cell for its key cap.
const KEYCAP_GAP := 4.0
const KEYCAP_SCALE := 2.0
const BAG_RIGHT := 0.969
const BAG_NUM_BASELINE := 0.900
const SLIPS_TOP := 0.795
const SLIPS_BOTTOM := 0.845
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
const RIM_TL := Vector2(0.812, 0.786)
const RIM_BR := Vector2(0.978, 0.914)
const ROOM_NAME_BASELINE := 0.139
## The floor card -- the dungeon's name and the level you are on. Top-left, which
## was the one corner of this HUD with nothing in it: health and stamina are
## bottom-left, the bag and the fee bottom-right, the button cluster top-right.
##
## It shares HEALTH_ORIGIN's x so the left margin is ONE edge and not two. The y
## clears the safe area (0.031) by enough that the two-line card does not touch
## it -- an announcement pinned to the very top of the frame reads as a system
## notification rather than as part of the game.
const FLOOR_ORIGIN := Vector2(0.031, 0.052)
## The control legend, garrison only. Bottom edge, under everything.
const KEYS_BASELINE := 0.962

## Reference height every px measurement in the styleguide was authored against.
const REF_H := 720.0


## Scale a styleguide pixel measurement to the current viewport, landing on a
## whole pixel. A 1.5x scale that does not round leaves soft glyph edges, and
## soft edges are the whole treatment collapsing.
static func px(base: float, screen_h: float) -> float:
	return maxf(1.0, round(base * screen_h / REF_H))


## Colour for a bag total. BONE below T1, GOLD from T1 up -- "you now have
## something to lose" should be a colour change you notice without reading.
static func bag_color(value: int) -> Color:
	return GOLD if value >= T1 else BONE


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
