extends RefCounted
## Assertions 1 and 2 from HUD_PLAN decision 20, as amended by decisions 27 and 35.
##
## **This is the check that can see a rectangle.** HUD_PLAN §11's diagnosis of why
## the draught row shipped drawn on top of the magic bar — twice — is that every
## HUD director asserted on numbers off `Run` and `Game`, not one of which would
## differ if the HUD drew nothing at all. `alchemy_loop.gd` passed for the entire
## life of that collision. So did every other one.
##
## It reads `Hud.layout_rects()`, which is populated during `_draw_hud` **by the
## same code that draws** — never a second table, because a hand-maintained
## description of where things are is the original defect one level up.
##
## Used by `hud_pole.gd` and `hud_lookdev.gd`. A director calls `check(tag)` after
## each capture and adds the return to its own failure count.
##
## ## It fails on the tree it was written against, on purpose
##
## HUD_PLAN §13.12 puts this before the fixes it is meant to catch, so landing it
## green would have meant landing it blind. Three real defects fired on the tree
## it landed against, each owned by a later item in the order of work. Two are
## closed; the list is kept because *which* assertion caught *which* defect is
## the only evidence this file works:
##
##   * ~~`rim` crosses the safe area by 5.8 px on the right~~ — closed by item 5
##     (`7d6659e`). Its right edge was 0.978; decision 4.5 puts it at 0.969.
##   * ~~`legend` crosses the safe area on three sides AND overlaps `pole`, in
##     the garrison only~~ — repaired by decision 28's wrap and §14.1's x
##     separation (item 7), and then closed for good by card #121, which deleted
##     the control legend outright. No element publishes `legend` any more;
##     `hud_pole.gd` asserts that nothing does.
##   * ~~`slips` is not inside `rim`, and ONLY at eight stacks~~ — closed by item
##     6. The stack grew upward from `Pal.SLIPS_BOTTOM` and cleared the rim's top
##     frame at 560.4 vs 563.92. HUD_PLAN §14.5 stated this case "resolves
##     correctly" under decision 27's tree and it did not — see §15.5. It was
##     §13.7's complaint measured: the rim's numbers and the slips' numbers were
##     authored separately and did not fit each other. The fix was to derive the
##     slips from the rim, NOT to widen SLACK, which is the repair §14.5 warns
##     about by name — and `SLIPS_BOTTOM` is deleted, so it cannot come back.
##
## ## Assertion 1 — nothing collides, and nesting is declared rather than exempted
##
## Written flat — "no permanent element overlaps any other" — it fires on the
## first frame, because this HUD is full of deliberate overlap: the ammo numeral
## inside the hand cell, the caps plate under the cells, the slips inside the rim.
## The obvious repair is an allowlist of exempt pairs, which is a second table
## describing the layout. So the layout is a TREE and this is two checks:
##
##   * no two rects with the same parent intersect;
##   * every child is contained by its parent.
##
## Stronger than the flat version, and it needs no exemptions.
##
## ## Assertion 2 — everything is inside the safe area
##
## x ∈ [32, 1248], y ∈ [22, 698], in absolute pixels and with no viewport clause.
## `display/window/stretch/mode` is `canvas_items` and `stretch/aspect` is `keep`,
## so the canvas is 1280 × 720 in every build on every display and letterboxed
## into a 16:9 box — every fraction in the anchor table resolves to exactly one
## set of pixels, forever (§13.4). It is still written against the live canvas
## size below, because a harness may be launched at another `--size` and a check
## that silently passes at the wrong resolution is worse than one that fails.
##
## ## Transients are checked too
##
## Decision 35. Decision 20 sells assertion 1 on three defects — the draught
## collision, caps through the health bar, and the legend running off both edges —
## and decision 8 then makes the legend transient. Exempting transients would
## exempt the evidence. A transient that overlaps a permanent element for ten
## seconds is a bug for ten seconds.
##
## The legend itself is gone (card #121), so the transients left are the floor
## card and the item toast. The rule outlives its example: the next transient
## anyone adds is checked the same way.

## `Rect2.intersects` excludes borders, so a shared edge passes and a 0.4 px
## overlap fails — and fractional layout guarantees 0.4 px cases. Half a pixel of
## slack each side is the tolerance; anything more would have hidden the four-pixel
## overlap the draught row actually had.
const SLACK := 0.5

## The safe area, as fractions. Matches STYLEGUIDE §5's, and note that the money
## pole's own right edge is TIGHTER than this (0.969) by decision 4.5 — this is
## the outer bound nothing may cross, not the edge things are aligned to.
const SAFE_MIN := Vector2(0.025, 0.031)
const SAFE_MAX := Vector2(0.975, 0.969)


## Returns the number of failures, having printed one line per failure.
static func check(tag: String) -> int:
	var layout: Dictionary = Hud.layout_rects()
	if layout.is_empty():
		print("  HUDLAYOUT FAIL %s: layout_rects() is empty — the HUD did not "
			% tag + "draw, or this is not a debug build")
		return 1

	var s: Vector2 = Hud.get_viewport().get_visible_rect().size
	var fails := 0
	var keys: Array = layout.keys()
	keys.sort()

	# Assertion 1a: siblings must not intersect.
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: StringName = keys[i]
			var b: StringName = keys[j]
			if _parent(layout, a) != _parent(layout, b):
				continue
			var ra: Rect2 = _rect(layout, a)
			var rb: Rect2 = _rect(layout, b)
			if ra.grow(-SLACK).intersects(rb.grow(-SLACK)):
				print("  HUDLAYOUT FAIL %s: %s %s overlaps %s %s (both under '%s')"
					% [tag, a, ra, b, rb, _parent(layout, a)])
				fails += 1

	# Assertion 1b: a child must be inside its parent.
	for key: StringName in keys:
		var parent: StringName = _parent(layout, key)
		if parent == &"" or not layout.has(parent):
			continue
		var child: Rect2 = _rect(layout, key)
		if not _rect(layout, parent).grow(SLACK).encloses(child):
			print("  HUDLAYOUT FAIL %s: %s %s is not inside its parent %s %s"
				% [tag, key, child, parent, _rect(layout, parent)])
			fails += 1

	# Assertion 2: inside the safe area.
	var safe := Rect2(SAFE_MIN * s, (SAFE_MAX - SAFE_MIN) * s)
	for key: StringName in keys:
		# Roots are the union of their children, so a root outside the safe area
		# is always ALSO a child outside it — reporting both is one defect twice.
		if _parent(layout, key) == &"" and _has_children(layout, key):
			continue
		var r: Rect2 = _rect(layout, key)
		if not safe.grow(SLACK).encloses(r):
			print("  HUDLAYOUT FAIL %s: %s %s crosses the safe area %s"
				% [tag, key, r, safe])
			fails += 1

	# Assertion 3: every size drawn is on the type ladder.
	#
	# On a HUD-scoped wrapper rather than inside `CanvasText.scale_for` (decision
	# 34): the ladder is a HUD rule, and `scale_for` is also what the loading card
	# sets 32 px type with. An assert in the shared function would fail a shipping
	# screen this plan has no authority over, on the day it landed.
	#
	# It can only see call sites that actually RAN, which is the right scope and
	# is why it lives beside the rectangle checks instead of in a grep: the size a
	# frame drew is the only size that was on screen.
	var offenders: Dictionary = Hud.type_offenders()
	for ref_px: float in offenders:
		print("  HUDLAYOUT FAIL %s: text drawn at %.1f px (%d call%s) is not on "
			% [tag, ref_px, offenders[ref_px], "" if offenders[ref_px] == 1 else "s"]
			+ "the type ladder %s" % [Hud.TYPE_LADDER])
		fails += 1

	if fails == 0:
		print("  ok   HUDLAYOUT %s (%d rects, %d sizes on the ladder)"
			% [tag, layout.size(), Hud.TYPE_LADDER.size()])
	return fails


static func _rect(layout: Dictionary, key: StringName) -> Rect2:
	var e: Dictionary = layout[key]
	return e[&"rect"]


static func _parent(layout: Dictionary, key: StringName) -> StringName:
	var e: Dictionary = layout[key]
	return StringName(e[&"parent"])


static func _has_children(layout: Dictionary, key: StringName) -> bool:
	for k: StringName in layout:
		if _parent(layout, k) == key:
			return true
	return false


# --- Assertion 4: no state is separable by hue alone ------------------------
## HUD_PLAN decision 32. Every pair of rarity rims must differ by more than
## `MIN_LUM_SEP` in luminance **after a deuteranope simulation**, or else differ in
## a channel that is not colour at all.
##
## ## Why this is not measured off a frame, which is what decision 32 asked for
##
## The decision says "render `hud_lookdev`'s states through a deuteranope matrix".
## Two things are wrong with that and both were found trying to write it.
##
## First, a director can only photograph the rarity states it can MANUFACTURE, and
## the rim shows the best thing in the bag: getting all four on camera means four
## bag-stuffing beats and four captures to test a property of four constants. The
## palette check covers all six pairs unconditionally and cannot be defeated by a
## beat that failed to reach the state it claimed.
##
## Second and worse, the rule has an escape hatch -- "or separable by another
## channel" -- and a luminance histogram cannot see a channel. A 2 px frame and a
## 3 px frame in two colours of identical luminance is a PASS under this rule and a
## fail under any measurement of the pixels. Checking the frame would have made the
## thickness ladder invisible to the assertion that exists to require it.
##
## So: the matrix runs over `Pal.RARITY`, and the escape hatch reads
## `Hud.rarity_weight` -- the same function `_draw_rim` draws from. HUD_PLAN §15.15.
##
## ## What it found
##
## Not the pair the code confidently named. `MOSS` against `MOTH` was written up in
## `_draw_rim` as "the textbook deutan collision" and it separates by 30%. The real
## collision is **common against rare** -- `MOTH` khaki against `COBALT` blue, 0.1%
## apart -- which reads to a deuteranope as *I cannot tell junk from treasure*.
## It passes only on the thickness channel, which is exactly what that channel is
## for, and this assertion is what stops anyone deleting it.

## Minimum deuteranope luminance separation, as a fraction of the brighter of the
## two. 15% by decision 32.
const MIN_LUM_SEP := 0.15

## Brettel/Vienot deuteranope simulation. RGB -> LMS, kill the M cone by
## reconstructing it from L and S, LMS -> RGB. Operates on LINEAR light, which is
## the reason `_to_linear` exists below -- running this on sRGB bytes is the
## classic way to get a plausible-looking picture and the wrong numbers.
const LMS := [Vector3(17.8824, 43.5161, 4.11935),
	Vector3(3.45565, 27.1554, 3.86714),
	Vector3(0.0299566, 0.184309, 1.46709)]
const LMS_INV := [Vector3(0.0809445, -0.130504, 0.116721),
	Vector3(-0.0102485, 0.0540194, -0.113615),
	Vector3(-0.000365294, -0.00412163, 0.693513)]


## Returns the number of failures, having printed one line per pair.
##
## Called once per director run rather than per capture: it is a property of the
## palette and the ladder, not of a frame, so photographing it four times would be
## four copies of one answer.
static func check_contrast() -> int:
	var fails := 0
	var names := ["common", "uncommon", "rare", "legendary"]
	for i in Pal.RARITY.size():
		for j in range(i + 1, Pal.RARITY.size()):
			var ya := _deutan_luma(Pal.RARITY[i])
			var yb := _deutan_luma(Pal.RARITY[j])
			var sep: float = absf(ya - yb) / maxf(maxf(ya, yb), 0.0001)
			var wa: Vector2i = Hud.rarity_weight(i)
			var wb: Vector2i = Hud.rarity_weight(j)
			if sep >= MIN_LUM_SEP:
				print("  ok   HUDCONTRAST %s/%s luminance %.1f%%"
					% [names[i], names[j], sep * 100.0])
			elif wa != wb:
				# The escape hatch, and it is REPORTED rather than silent: a pair
				# riding entirely on its second channel is a thing a reviewer
				# should have to read, because deleting the ladder deletes it.
				print("  ok   HUDCONTRAST %s/%s luminance only %.1f%% — carried by "
					% [names[i], names[j], sep * 100.0]
					+ "weight %s vs %s" % [wa, wb])
			else:
				print("  HUDCONTRAST FAIL %s/%s differ by hue ALONE: deuteranope "
					% [names[i], names[j]]
					+ "luminance %.1f%% (need %.0f%%) and both draw weight %s"
						% [sep * 100.0, MIN_LUM_SEP * 100.0, wa])
				fails += 1
	return fails


## Relative luminance of a colour as a deuteranope sees it, in linear light.
static func _deutan_luma(c: Color) -> float:
	var v := Vector3(_to_linear(c.r), _to_linear(c.g), _to_linear(c.b))
	var lms := Vector3(LMS[0].dot(v), LMS[1].dot(v), LMS[2].dot(v))
	# The M cone is gone; a deuteranope's brain reconstructs it from L and S.
	lms.y = 0.494207 * lms.x + 1.24827 * lms.z
	var d := Vector3(LMS_INV[0].dot(lms), LMS_INV[1].dot(lms), LMS_INV[2].dot(lms))
	d = d.clampf(0.0, 1.0)
	return 0.2126 * d.x + 0.7152 * d.y + 0.0722 * d.z


## sRGB byte to linear light. Godot's `Color` is sRGB here because every palette
## entry is authored as a hex string.
static func _to_linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)
