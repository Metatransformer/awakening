extends RefCounted
## Every component of the UI kit, on one screen, in every state that has a
## different look — so a change to `UITheme` or `UiKit` is judged by looking at
## it rather than by reading the diff.
##
## This is the kit's own gate. The screens have their own directors; this one
## exists so a regression in the SHARED layer is caught once here instead of
## being rediscovered five times downstream.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/kit_lookdev.gd --out=/tmp/kit/x.png

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const UiKitScript := preload("res://scripts/ui/kit/ui_kit.gd")
const KitIconScript := preload("res://scripts/ui/kit/kit_icon.gd")


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/kit/x.png").get_base_dir()
	await rig.wait_frames(20)

	UITheme.prewarm()

	var layer := CanvasLayer.new()
	layer.layer = 120   # above the HUD (50) and the pause menu (100)
	rig.root.add_child(layer)

	var scrim := UITheme.modal_scrim(func() -> void: pass)
	layer.add_child(scrim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_top = 40
	panel.offset_right = -120
	panel.offset_bottom = -40
	# edge_to_edge: a composed column owns its own spacing, so the header band
	# and the stat band must reach the frame edge rather than sit inside the
	# window's 22px margin.
	UITheme.style_panel(panel, UITheme.FRAME_FACE_SOLID, true)
	layer.add_child(panel)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)

	UiKitScript.plate_header(col, {
		"kicker": "Rare · Ingredient",
		"title": "Deep Amber",
		"emblem": UiKitScript.action_icon("jewel"),
		"edge": UiKitScript.rarity_edge(2),
	})

	UiKitScript.stat_band(col, [
		{"value": "308", "label": "Bag"},
		{"value": "4 / 12", "label": "Slots"},
		{"value": "1450", "label": "Purse", "tone": UITheme.SUCCESS},
		{"value": "77", "label": "Fee", "tone": UITheme.WARNING},
		{"value": "+96", "label": "Heat", "tone": UITheme.DANGER},
	])

	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("margin_left", 0)
	body.add_theme_constant_override("margin_top", 14)
	col.add_child(body)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	body.add_child(rows)

	# One primary, several ordinary rows with live meta, one submenu, and a
	# refusal — the four states a verb list actually ships in.
	UiKitScript.verb_row(rows, {
		"label": "Sell everything", "meta": "316 ◇", "primary": true,
		"icon": UiKitScript.action_icon("coin"), "on_press": func() -> void: pass,
	})
	UiKitScript.verb_row(rows, {
		"label": "Fletch arrows", "meta": "2 Bone Shard",
		"icon": UiKitScript.action_icon("fletch"), "on_press": func() -> void: pass,
	})
	UiKitScript.verb_row(rows, {
		"label": "The workbench", "meta": "3 components", "submenu": true,
		"icon": UiKitScript.action_icon("crafting"), "on_press": func() -> void: pass,
	})
	UiKitScript.verb_row(rows, {
		"label": "Escape rope", "meta": "77 ◇",
		"icon": UiKitScript.action_icon("rope"), "on_press": func() -> void: pass,
	})
	# The refusal law: still on screen, still readable, saying WHY.
	UiKitScript.verb_row(rows, {
		"label": "Reforge the Kite Shield", "refused": "no forge in the garrison",
		"icon": UiKitScript.action_icon("forge"),
	})

	UITheme.section_rule(rows, "The way out")

	var toast_slot := VBoxContainer.new()
	toast_slot.add_theme_constant_override("separation", 6)
	col.add_child(toast_slot)
	UiKitScript.footer_toast(toast_slot, "Sold Deep Amber ×2 — 220 ◇.", UITheme.SUCCESS)
	UiKitScript.footer_toast(toast_slot, "You cannot afford to leave.", UITheme.DANGER)

	await rig.wait_frames(12)
	await rig.capture(out.path_join("k_00_column.png"))

	# The focus ring is half the kit and it only exists under a real focus, so
	# photograph it rather than trusting that the stylebox is installed.
	UITheme.focus_first(rows)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("k_01_focus.png"))

	# Step the focus down one so the hover/armed edge is visible on a row that
	# is NOT the primary — the primary's display face can mask a missing edge.
	var focused: Control = rig.root.gui_get_focus_owner()
	if focused != null:
		focused.find_next_valid_focus().grab_focus()
	await rig.wait_frames(6)
	await rig.capture(out.path_join("k_02_focus_second.png"))

	# The whole glyph family on one sheet. Generated line art is only as good as
	# it looks at the size it is drawn, and 30 icons is more than anyone will
	# check one row at a time — so the sheet is the gate.
	for c in panel.get_children():
		c.queue_free()
	await rig.wait_frames(2)
	await _icon_sheet(rig, panel)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("k_03_icons.png"))

	print("KIT LOOKDEV OK -> %s" % out)


func _icon_sheet(rig, panel: Panel) -> void:
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_right", 26)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	pad.add_child(col)

	var title := Label.new()
	title.text = "Action glyphs"
	UITheme.apply_text_style(title, UITheme.TYPE_H1)
	col.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)

	var dir := DirAccess.open("res://assets/icons/actions")
	if dir == null:
		push_error("[kit_lookdev] the action-glyph family is missing; run tools/gen_icons/build_action_icons.py")
		return
	var names: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".svg"):
			names.append(f.trim_suffix(".svg"))
	names.sort()

	for n in names:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		# Drawn at BOTH sizes the kit uses: 19px is the verb row, 42px is the
		# plate-header emblem. A glyph that survives one and not the other is
		# a glyph that is about to look wrong in exactly one place.
		var pair := HBoxContainer.new()
		pair.alignment = BoxContainer.ALIGNMENT_CENTER
		pair.add_theme_constant_override("separation", 8)
		var tex := UiKitScript.resolve_icon(UiKitScript.action_icon(n))
		pair.add_child(KitIconScript.rect(tex, 42))
		pair.add_child(KitIconScript.rect(tex, 19))
		cell.add_child(pair)
		var cap := Label.new()
		cap.text = n
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_text_style(cap, UITheme.TYPE_CAPTION)
		cell.add_child(cap)
		grid.add_child(cell)
