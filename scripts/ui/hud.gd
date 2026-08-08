class_name Hud
extends CanvasLayer
## Everything the player reads, and the two shop panels.
##
## The HUD runs while the tree is paused (`process_mode = ALWAYS`) because
## opening a shop pauses the world. Pausing rather than overlaying is the honest
## choice for a town panel: the alternative is a hero who can be walked around,
## and attacked by nothing, behind a menu.
##
## Readouts are pushed by Bus signals, never polled. The one exception is the
## panels, which are rebuilt from Game on open — they are modal, so there is no
## window in which they can go stale.

const PAD := 14.0

var _root: Control
var _hearts: HeartsBar
var _gold: Label
var _depth: Label
var _extract_hint: Label
var _bag: BagView
var _stash_line: Label
var _message: Label
var _toast: Label
var _channel: ProgressBar
var _panel: PanelContainer
var _panel_body: VBoxContainer

var _in_dungeon: bool = false
var _msg_timer: float = 0.0
var _toast_timer: float = 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

	Bus.gold_changed.connect(_on_gold)
	Bus.stash_changed.connect(_refresh_stash)
	Bus.bag_changed.connect(_refresh_stash)
	Bus.run_depth_changed.connect(_on_depth)
	Bus.request_message.connect(_on_message)
	Bus.loot_overflowed.connect(_on_overflow)
	Bus.extraction_started.connect(_on_extract_started)
	Bus.extraction_progress.connect(_on_extract_progress)
	Bus.extraction_cancelled.connect(_on_extract_cancelled)

	_on_gold(Game.gold)
	_refresh_stash()


# --- Layout -----------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(PAD, PAD)
	top_left.add_theme_constant_override("separation", 6)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_left)

	_hearts = HeartsBar.new()
	top_left.add_child(_hearts)

	_gold = _label("0 gold", 20, Color(1.0, 0.86, 0.42))
	top_left.add_child(_gold)

	_stash_line = _label("", 14, Color(0.78, 0.80, 0.86))
	top_left.add_child(_stash_line)

	var top_right := VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-260.0 - PAD, PAD)
	top_right.custom_minimum_size = Vector2(260, 0)
	top_right.alignment = BoxContainer.ALIGNMENT_END
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_right)

	_depth = _label("", 18, Color(0.86, 0.88, 0.95))
	_depth.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(_depth)

	_extract_hint = _label("", 14, Color(0.55, 0.82, 1.0))
	_extract_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(_extract_hint)

	_bag = BagView.new()
	_bag.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bag.position = Vector2(-K.BAG_SLOTS * 22.0, -74.0)
	_root.add_child(_bag)

	_channel = ProgressBar.new()
	_channel.set_anchors_preset(Control.PRESET_CENTER)
	_channel.position = Vector2(-160.0, 60.0)
	_channel.custom_minimum_size = Vector2(320, 18)
	_channel.max_value = 1.0
	_channel.show_percentage = false
	_channel.visible = false
	_channel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_channel)

	_message = _label("", 18, Color(0.95, 0.95, 0.98))
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.position = Vector2(-300.0, -128.0)
	_message.custom_minimum_size = Vector2(600, 0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_message)

	_toast = _label("", 22, Color(1.0, 0.94, 0.78))
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.position = Vector2(-320.0, -110.0)
	_toast.custom_minimum_size = Vector2(640, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_toast)

	_build_panel()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-330.0, -240.0)
	_panel.custom_minimum_size = Vector2(660, 0)
	_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.96)
	style.border_color = Color(0.55, 0.45, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)

	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", 8)
	_panel.add_child(_panel_body)
	_root.add_child(_panel)


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Context ----------------------------------------------------------------

## Switch between the town readout and the run readout.
func set_context(in_dungeon: bool) -> void:
	_in_dungeon = in_dungeon
	_bag.visible = in_dungeon
	_channel.visible = false
	close_panel()
	# Pull, rather than wait for a push. A world swap is the one moment a save
	# load or a debug poke could have moved Game out from under the readouts.
	_on_gold(Game.gold)
	_hearts.refresh()
	if in_dungeon:
		_on_depth(Game.rooms_cleared, Game.depth_band())
	else:
		_depth.text = ""
		_extract_hint.text = ""
	_refresh_stash()


func _on_gold(n: int) -> void:
	_gold.text = "%d gold" % n


func _refresh_stash() -> void:
	if _in_dungeon:
		var carried: int = Game.bag.total_value() if Game.bag != null else 0
		_stash_line.text = "carrying %d gold worth" % carried
	else:
		_stash_line.text = "stash: %d items, worth %d gold" % [
			_stash_count(), Game.stash_total_value()]


func _stash_count() -> int:
	var n := 0
	for id in Game.stash:
		n += Game.stash[id]
	return n


func _on_depth(rooms: int, band: int) -> void:
	if not _in_dungeon:
		return
	_depth.text = "depth %d   ·   band %d" % [rooms, band]
	var fee := Game.extract_fee()
	if Game.gold >= fee:
		_extract_hint.text = "hold [↑ item] to extract — %d gold" % fee
	else:
		_extract_hint.text = "extraction costs %d gold (you have %d)" % [fee, Game.gold]


func _on_message(text: String) -> void:
	_message.text = text
	_msg_timer = 3.0 if text != "" else 0.0


func _on_overflow(id: StringName, _count: int) -> void:
	_on_message("Bag full — %s left on the floor." % LootDB.display_name(id))


func _on_extract_started(fee: int) -> void:
	_channel.visible = true
	_channel.value = 0.0
	_on_message("Channelling — %d gold. Hold still." % fee)


func _on_extract_progress(t: float) -> void:
	_channel.value = t


func _on_extract_cancelled(why: StringName) -> void:
	_channel.visible = false
	match why:
		&"moved": _on_message("Extraction broken — you moved.")
		&"hurt": _on_message("Extraction broken — you were hit.")
		_: _on_message("")


func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_message.text = ""
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast.text = ""
	# The fee climbs as you clear rooms, so the readout has to follow it.
	if _in_dungeon and not _panel.visible:
		_on_depth(Game.rooms_cleared, Game.depth_band())


func show_run_summary(reason: StringName, rooms: int) -> void:
	match reason:
		&"died":
			_toast.text = "You died at depth %d. The belt is all that came back." % rooms
		&"extracted":
			_toast.text = "Extracted from depth %d. The haul is in your stash." % rooms
		_:
			_toast.text = "Walked out at depth %d." % rooms
	_toast_timer = 6.0


# --- Panels -----------------------------------------------------------------

func is_panel_open() -> bool:
	return _panel.visible


func open_vendor() -> void:
	_open_panel()
	_heading("Vendor", "Ingredients are worth gold. They are also the only thing the smith takes.")

	if Game.stash.is_empty():
		_panel_body.add_child(_label("Your stash is empty. Go and fill it.", 16,
			Color(0.7, 0.7, 0.74)))
	else:
		for id in _sorted_stash():
			_panel_body.add_child(_stash_row(id))
		_panel_body.add_child(HSeparator.new())
		var total := Game.stash_total_value()
		var sell_all := Button.new()
		sell_all.text = "Sell everything  (%d gold)" % total
		sell_all.pressed.connect(func() -> void:
			var earned := Game.sell_all()
			_on_message("Sold the lot for %d gold." % earned)
			open_vendor())
		_panel_body.add_child(sell_all)

	_panel_footer()


func _sorted_stash() -> Array:
	var ids: Array = Game.stash.keys()
	# Cheapest first, so the tail of the list is the stuff worth thinking about.
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return LootDB.sell_value(a) < LootDB.sell_value(b))
	return ids


func _stash_row(id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var swatch := ColorRect.new()
	swatch.color = LootDB.color_of(id)
	swatch.custom_minimum_size = Vector2(20, 20)
	row.add_child(swatch)

	var have: int = Game.stash[id]
	var unit := LootDB.sell_value(id)

	var name_label := _label("%s  ×%d" % [LootDB.display_name(id), have], 16, Color.WHITE)
	name_label.custom_minimum_size = Vector2(260, 0)
	row.add_child(name_label)

	var price := _label("%d ea  ·  %d total" % [unit, unit * have], 14,
		Color(1.0, 0.86, 0.42))
	price.custom_minimum_size = Vector2(160, 0)
	row.add_child(price)

	var one := Button.new()
	one.text = "Sell 1"
	one.pressed.connect(func() -> void:
		Game.sell(id, 1)
		open_vendor())
	row.add_child(one)

	var all := Button.new()
	all.text = "Sell all"
	all.pressed.connect(func() -> void:
		Game.sell(id, have)
		open_vendor())
	row.add_child(all)

	return row


func open_smith() -> void:
	_open_panel()
	_heading("Blacksmith", "Gold buys the labour. Ingredients buy the steel.")
	_panel_body.add_child(_gear_row(Gear.Track.BLADE))
	_panel_body.add_child(HSeparator.new())
	_panel_body.add_child(_gear_row(Gear.Track.ARMOR))
	_panel_footer()


func _gear_row(track: Gear.Track) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var tier := Game.gear_tier(track)
	var track_name := "Blade" if track == Gear.Track.BLADE else "Armour"
	col.add_child(_label("%s — %s" % [track_name, Gear.name_for(track, tier)], 18,
		Color(0.92, 0.90, 0.84)))

	if tier >= Gear.MAX_TIER:
		col.add_child(_label("Nothing left to forge. This is the best there is.", 14,
			Color(0.62, 0.86, 0.62)))
		return col

	col.add_child(_label("→ %s   (%s)" % [
		Gear.name_for(track, tier + 1), Gear.next_effect(track, tier)], 15,
		Color(0.78, 0.82, 0.90)))

	var price := Gear.next_gold(track, tier)
	var short := Game.craft_shortfall(track)

	var cost := HBoxContainer.new()
	cost.add_theme_constant_override("separation", 14)
	cost.add_child(_cost_chip("%d gold" % price, not short.has(&"gold")))
	for id in Gear.next_materials(track, tier):
		var need: int = Gear.next_materials(track, tier)[id]
		var have: int = Game.stash_count(id)
		cost.add_child(_cost_chip("%s %d/%d" % [LootDB.display_name(id), have, need],
			have >= need))
	col.add_child(cost)

	var forge := Button.new()
	forge.text = "Forge"
	forge.disabled = not short.is_empty()
	forge.pressed.connect(func() -> void:
		if Game.craft(track):
			_on_message("Forged: %s." % Gear.name_for(track, Game.gear_tier(track)))
		open_smith())
	col.add_child(forge)
	return col


func _cost_chip(text: String, met: bool) -> Label:
	return _label(text, 15, Color(0.62, 0.88, 0.62) if met else Color(0.95, 0.48, 0.42))


func _heading(title: String, subtitle: String) -> void:
	_panel_body.add_child(_label(title, 26, Color(1.0, 0.92, 0.72)))
	_panel_body.add_child(_label(subtitle, 14, Color(0.68, 0.68, 0.74)))
	_panel_body.add_child(HSeparator.new())


func _panel_footer() -> void:
	_panel_body.add_child(HSeparator.new())
	_panel_body.add_child(_label("%d gold" % Game.gold, 18, Color(1.0, 0.86, 0.42)))
	var close := Button.new()
	close.text = "Close  [Esc]"
	close.pressed.connect(close_panel)
	_panel_body.add_child(close)


func _open_panel() -> void:
	for c in _panel_body.get_children():
		c.queue_free()
		_panel_body.remove_child(c)
	_panel.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_panel() -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_refresh_stash()


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed(&"ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
