class_name HoldBar
extends Control
## `HoldGauge.bar` with a node around it, for the screens that are built out of
## Controls instead of drawn by hand.
##
## The HUD and the trade screen own their pixels — they call `HoldGauge.bar`
## straight into their own `_draw`. The pause menu does not: it is Buttons in
## Containers, and a Control draws its own commands BENEATH its children, so a
## bar drawn by the panel over one of its rows renders *behind* that row's
## StyleBox and is never seen. That is not a hypothetical; it is the reason this
## file exists rather than four lines in `pouch_panel._draw`.
##
## So: a leaf Control, parented INSIDE the row it is about, anchored to the
## bottom edge of it. Ignores the mouse and refuses focus, because it is a
## readout on a button that already has both.
##
## The look is not this file's to decide. Everything visible here is
## `HoldGauge` (docs/STYLEGUIDE.md) — one widget, three callers, one rule.

## Reference px, and a fixed number rather than `Pal.px`: the menu lives under
## `canvas_items` stretch at 1280×720, so its local space IS reference space and
## the stretch does the scaling that `Pal.px` does for the HUD's raw pixels.
const H := HoldGauge.BAR_H

## 0..1. Assigning it redraws; the empty track at 0 is a state, not "off"
## (`HoldGauge.bar` — the track is the pre-press tell that this is a hold at
## all). Hide the node to mean "no hold is possible here".
var progress: float = 0.0:
	set(v):
		var next := clampf(v, 0.0, 1.0)
		if is_equal_approx(next, progress):
			return
		progress = next
		queue_redraw()

## The fill colour. CYAN is the way out and nothing else (STYLEGUIDE §1), so the
## caller says which hold this is; BONE is the default for the rest.
var col: Color = Pal.BONE:
	set(v):
		col = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size.y = H


func _draw() -> void:
	HoldGauge.bar(self, Rect2(Vector2.ZERO, size), progress, col)


## Pin this bar along the bottom edge of `row`, full width. Called instead of
## `set_anchors_and_offsets_preset`, because the preset that fills the bottom
## edge does not exist and the four-line version got written wrong once.
func pin_to_bottom_of(row: Control) -> void:
	row.add_child(self)
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -H
	offset_bottom = 0.0
