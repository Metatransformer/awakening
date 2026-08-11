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
## green would have meant landing it blind. Three real defects fire today, each
## owned by a later item in the order of work — if you are running a director
## tonight and see these, you have not broken anything:
##
##   * `rim` crosses the safe area by 5.8 px on the right. Its right edge is at
##     0.978 and decision 4.5 puts it at 0.969 — HUD_PLAN item 5.
##   * `legend` crosses the safe area on three sides AND overlaps `pole`, in the
##     garrison only. Decision 28's wrap and §14.1's x separation — item 4/7.
##   * `slips` is not inside `rim`, and ONLY at eight stacks: the stack grows
##     upward from `Pal.SLIPS_BOTTOM` and clears the rim's top frame at 560.4 vs
##     563.92. HUD_PLAN §14.5 states this case "resolves correctly" under
##     decision 27's tree and it does not — see §15.5. It is §13.7's complaint
##     measured: the rim's numbers and the slips' numbers are authored
##     separately and do not fit each other. The fix is to derive the slips from
##     the rim (item 6), NOT to widen SLACK, which is the repair §14.5 warns
##     about by name.
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
