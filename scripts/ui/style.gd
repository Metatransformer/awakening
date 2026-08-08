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
const KIT_ORIGIN := Vector2(0.031, 0.826)
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
