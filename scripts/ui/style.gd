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

# --- Bag value tiers --------------------------------------------------------
## The thresholds at which the bag stops being pocket change and starts being
## something you can lose. [tune]
const T1 := 250
const T2 := 1000
const T3 := 3000

# --- Layout, as fractions of the viewport (STYLEGUIDE §5.7) -----------------
const SAFE := Vector2(0.025, 0.031)

const HEALTH_ORIGIN := Vector2(0.031, 0.899)
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
## --- The button cluster, top-right ------------------------------------------
## The three item buttons in the physical shape of the D-pad they sit on
## (docs/CONTRACT.md §2.5 #6), and — since they are the same KIND of thing — the
## two hands beside them. They are not readouts, they are a control surface: the
## arrangement is what tells you which button draws which item, and that is only
## true if the arrangement matches your thumb.
##
## The hands used to live bottom-left above health, on the reasoning that what he
## is holding is a fact about his body. That was true and it was the wrong place
## anyway: every cell here answers "what do I press", and splitting that question
## across two corners means answering it with two glances. Now every cell in the
## cluster carries the key that fires it, which is what makes them one instrument.
##
## Cells are ~2x the old 32/34, and both sizes collapsed to ONE: at this scale a
## 2 px difference between the hand cell and the button cell stops reading as
## deliberate and starts reading as a bug.
const CELL := 64.0
const CELL_GAP := 12.0
## Gap between the hands pair and the D-pad cross — wider than CELL_GAP so the
## cluster reads as two groups, not five cells in a row.
const CLUSTER_GAP := 22.0
## The cluster is laid out from its RIGHT edge (see Hud._cluster_rect), not from
## a left-edge fraction. At the old size a fractional origin was safe; doubled,
## the cross alone is 216 reference px and a 0.886 left edge puts it 82 px off
## the side of a 1280-wide screen. Anchor the thing that must not overflow.
const CLUSTER_RIGHT := 0.969   ## shares BAG_RIGHT's margin — one right edge, not two
const CLUSTER_TOP := 0.044
## Room under a cell for its key cap.
const KEYCAP_GAP := 4.0
const KEYCAP_SCALE := 2.0
const BAG_RIGHT := 0.969
const BAG_NUM_BASELINE := 0.900
const SLIPS_TOP := 0.795
const SLIPS_BOTTOM := 0.845
const TOAST_BASELINE := 0.767
const EXTRACT_BASELINE := 0.940
## Hugs its contents. The styleguide's original 0.740 left edge left a third of
## the box empty at every bag size a player will actually see, and an empty
## frame reads as a panel someone forgot to fill rather than as an instrument.
## 0.812 fits a six-digit total, which is past anything the drop tables produce.
## The rim frames THE BAG -- slips and total -- and stops above the extraction
## line. Enclosing the extract line too meant "EXTRACT 238" started left of the
## rim and crossed it, which reads as a rendering bug rather than a frame.
const RIM_TL := Vector2(0.812, 0.786)
const RIM_BR := Vector2(0.978, 0.914)
const ROOM_NAME_BASELINE := 0.139
## The control legend, town only. Bottom edge, under everything.
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
