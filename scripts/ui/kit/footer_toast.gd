class_name FooterToast
extends RefCounted
## An outcome message, pinned to the panel FOOTER.
##
##     ┌─┬──────────────────────────────────────────┐
##     │▌│ Sold Deep Amber ×2 — 220 ◇.              │
##     └─┴──────────────────────────────────────────┘
##      ▲ 3px semantic edge: SUCCESS / DANGER / WARNING
##
## Never place a status label ABOVE the content it reports on. A result message
## between the summary and the action list shoves every row down, and the thing
## you just clicked moves out from under your cursor. Layout must not depend on
## whether something has happened yet.
##
## The toast is a plain node, not a timer-driven animation: the panel decides
## when to replace or clear it. A panel that wants a fade owns that with its own
## Tween — the kit does not impose one, because a message that vanishes before it
## is read is worse than one that lingers.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

const EDGE_PX := 3


static func build(parent: Node, text: String, tone: Color = UITheme.SUCCESS) -> Control:
	if text.strip_edges().is_empty():
		push_warning("[FooterToast] reason=empty toast text; toast omitted")
		return null

	var toast := PanelContainer.new()
	toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override("panel", _box(tone))

	var line := Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text_style(line, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT)
	toast.add_child(line)
	# The line, for a panel that has to read back or rewrite what was said. The
	# pause menu's notice bar does both, and a caller digging for `get_child(0)`
	# is a caller that breaks the next time this component grows a second child.
	toast.set_meta(&"toast_label", line)

	if parent != null:
		parent.add_child(toast)
	return toast


static func _box(tone: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.42)
	box.border_width_left = EDGE_PX
	box.border_color = tone
	box.corner_radius_top_right = UITheme.RADIUS
	box.corner_radius_bottom_right = UITheme.RADIUS
	box.content_margin_left = 13
	box.content_margin_right = 13
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box
