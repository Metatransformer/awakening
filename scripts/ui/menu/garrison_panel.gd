class_name MenuGarrisonPanel
extends Control
## Read-only view of the garrison's authoritative clock, hearth, provisions,
## morale, duty, roster, relic, and improvement state. Nothing here mutates it.

signal back_requested

const ROSTER: Array[Dictionary] = [
	{"id": &"elder", "role": "Lanternkeeper / commander"},
	{"id": &"quartermaster", "role": "Quartermaster"},
	{"id": &"smith", "role": "Smith"},
	{"id": &"alchemist", "role": "Alchemist"},
	{"id": &"jewelcrafter", "role": "Jewelcrafter"},
	{"id": &"builder", "role": "Builder / mechanisms"},
]

var _hrow: HBoxContainer
var _band_slot: VBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.garrison_changed.connect(refresh)
	refresh()


## Where PauseMenu inserts the shared focusable page strip.
func tab_host() -> HBoxContainer:
	return _hrow


## The strip's down-link and this page's only body focus target.
func tab_row() -> Array:
	return [_back] if _back != null else []


func focus_first() -> void:
	if _back != null:
		_back.grab_focus()


func refresh() -> void:
	_rebuild_band()
	if _body == null:
		return
	UITheme.clear_children(_body)
	_build_provisions_and_morale()
	_build_hearth_status()
	_build_duty_status()
	_build_garrison_defence()
	_build_roster()
	_build_relic_effects()
	_build_improvements()
	if _scroll != null:
		_scroll.scroll_vertical = 0


func _build() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	UITheme.style_panel(frame, UITheme.FRAME_FACE_SOLID, true)
	frame.custom_minimum_size = MenuUtil.FRAME_SIZE
	center.add_child(frame)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override(&"separation", 0)
	frame.add_child(col)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 14, 6, 14, 0))
	col.add_child(header)
	_hrow = HBoxContainer.new()
	header.add_child(_hrow)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hrow.add_child(gap)

	_band_slot = VBoxContainer.new()
	_band_slot.add_theme_constant_override(&"separation", 0)
	col.add_child(_band_slot)

	_scroll = ScrollContainer.new()
	_scroll.name = "StatusScroll"
	_scroll.focus_mode = Control.FOCUS_NONE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)

	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		inset.add_theme_constant_override("margin_" + side, 20)
	for side: String in ["top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 12)
	_scroll.add_child(inset)

	_body = VBoxContainer.new()
	_body.name = "StatusBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 8)
	inset.add_child(_body)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",
		UITheme.hud_box(UITheme.GRAY_1, 20, 10, 20, 10))
	col.add_child(footer)
	var frow := HBoxContainer.new()
	footer.add_child(frow)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(spacer)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "Back"
	_back.custom_minimum_size.x = 160
	_back.focus_mode = Control.FOCUS_ALL
	_back.pressed.connect(_on_back_pressed)
	frow.add_child(_back)
	MenuUtil.chain([_back], true)


func _on_back_pressed() -> void:
	back_requested.emit()


func _rebuild_band() -> void:
	if _band_slot == null:
		return
	UITheme.clear_children(_band_slot)
	var transition: Dictionary = Clock.next_garrison_transition()
	var next_day: int = int(transition.get("day", Clock.day))
	var next_hour: float = float(transition.get("hour", 0.0))
	var next_value := "%s  %s" % [
		_phase_label(StringName(transition.get("phase", &""))),
		_clock_text(next_hour),
	]
	if next_day != Clock.day:
		next_value = "Day %d  %s" % [next_day, next_value]
	UiKit.stat_band(_band_slot, [
		{"label": "Day", "value": str(Clock.day)},
		{"label": "Time", "value": _clock_text(Clock.hour)},
		{"label": "Schedule", "value": _phase_label(Clock.garrison_phase())},
		{"label": "Next", "value": next_value},
	])


func _build_hearth_status() -> void:
	UITheme.section_rule(_body, "HEARTH & TRADE")
	_fact("Hearth stock", "%d / %d bundles" % [Game.firewood_stock, Game.FIREWOOD_CAP])
	_fact("Carried Firewood cargo", "%d bundles" % _carried_firewood())
	_fact("Next unresolved bonfire",
		"Can be fueled" if Game.firewood_stock > 0 else "No stored bundle")
	_fact("Garrison Warmth", "Active" if Game.warmth_active else "Inactive",
		UITheme.SUCCESS if Game.warmth_active else null)
	_fact("Ordinary Trade buy", "×0.90  (10% less)" if Game.warmth_active else "×1.00")
	_fact("Ordinary Trade sell", "×%.2f%s" % [Game.warmth_sell_mult(),
		"  (10% more)" if Game.warmth_active else ""])


func _build_provisions_and_morale() -> void:
	UITheme.section_rule(_body, "PROVISIONS & MORALE")
	_fact("Fish reserve", "%d / %d meals" % [Game.fish_stock, Game.FISH_CAP])
	_fact("Carried Food cargo", "%d fish" % _carried_food())
	_fact("Today's remaining yield",
		"%d Fish" % Game.fishing_remaining_today(Clock.day))
	_fact("Next supper", _next_supper_status())
	_fact("Fed", "Active" if Game.fed_active else "Inactive",
		UITheme.SUCCESS if Game.fed_active else null)
	var well_fed_status := "Not prepared"
	var well_fed_tone: Variant = null
	if Game.well_fed_trip:
		well_fed_status = "Active this descent · +15 temporary maximum stamina"
		well_fed_tone = UITheme.SUCCESS
	elif Game.well_fed_ready:
		well_fed_status = "Ready for next descent · +15 temporary maximum stamina"
		well_fed_tone = UITheme.SUCCESS
	_fact("Well Fed", well_fed_status, well_fed_tone)

	var arrived: Array[StringName] = []
	var total_causes := 0
	for slot: Dictionary in ROSTER:
		var who: StringName = slot["id"]
		if not _arrived(who):
			continue
		arrived.append(who)
		total_causes += Game.morale_causes(who, Clock.day).size()
	var overall := "No residents arrived"
	if not arrived.is_empty():
		var average_causes := float(total_causes) / float(arrived.size())
		var labels: Array[String] = ["Low", "Uneasy", "Steady", "High"]
		overall = labels[clampi(roundi(average_causes), 0, labels.size() - 1)]
	_fact("Overall morale", overall)

	for who: StringName in arrived:
		var person: Dictionary = DialogueDb.PEOPLE.get(who, {})
		var display_name: String = String(
			person.get("name", String(who).capitalize()))
		var causes: PackedStringArray = Game.morale_causes(who, Clock.day)
		var cause_text: String = ", ".join(causes) \
			if not causes.is_empty() else "No active causes"
		_fact(display_name, "%s · %s" % [Game.morale_label(who, Clock.day), cause_text])


func _next_supper_status() -> String:
	var next_day: int = Clock.day + 1 if Game.last_supper_day >= Clock.day else Clock.day
	var reserve_status := "Fish reserved" if Game.fish_stock > 0 else "No Fish reserved"
	return "Day %d at 20:00 · %s" % [next_day, reserve_status]


func _build_duty_status() -> void:
	UITheme.section_rule(_body, "KEEP THE HEARTH")
	var assigned: bool = Game.flag(StoryDb.told_flag(&"elder", &"timber_duty"))
	var owns_axe: bool = Game.has(ShopDb.WOODSMAN_AXE_ID)
	var completed: bool = Game.timber_completed_day == Clock.day
	var availability: String
	if not assigned:
		availability = "Unavailable · duty not assigned"
	elif not owns_axe:
		availability = "Unavailable · axe not owned"
	elif completed:
		availability = "Completed today"
	elif Clock.garrison_phase() != WorldClock.GARRISON_DAYTIME:
		availability = "Closed · %s" % _phase_label(Clock.garrison_phase())
	else:
		availability = "Available now"
	_fact("Outskirts grove", availability)
	_fact("Today's chop", "Complete" if completed else "Not complete")
	_fact("Current step", _duty_step(assigned, owns_axe, completed))


func _duty_step(assigned: bool, owns_axe: bool, completed: bool) -> String:
	if not assigned:
		return "Not assigned"
	if not owns_axe:
		return "Craft the Woodsman's Axe at Brannoc's forge."
	if not Game.tool_usable(ToolDb.WOODSMAN_AXE_ID):
		return "Reforge the broken Woodsman's Axe at Brannoc's forge."
	if _carried_firewood() > 0 or _carried_food() > 0:
		return "Deposit carried cargo at the south-gate supply box."
	if completed:
		return "Return tomorrow for the next bundle."
	return "Fell today's tree in the outskirts grove."


func _carried_firewood() -> int:
	return int(Run.bag.get(SupplyCargoDb.FIREWOOD_ID, 0))


func _carried_food() -> int:
	var total := 0
	for fish_id: StringName in SupplyCargoDb.FISH_IDS:
		total += int(Run.bag.get(fish_id, 0)) * SupplyCargoDb.food_units(fish_id)
	return total


func _build_garrison_defence() -> void:
	UITheme.section_rule(_body, "GARRISON DEFENCE")
	var phase := Game.raid_phase()
	if phase == GarrisonRaidState.PHASE_DORMANT:
		_fact("Raid", "No raid is scheduled.")
	else:
		match phase:
			GarrisonRaidState.PHASE_ARMED:
				_fact("Raid", "Scheduled · Day %d at 23:00" % Game.raid_scheduled_day())
			GarrisonRaidState.PHASE_WARNED:
				_fact("Raid", "Warning issued · Day %d at 23:00" % Game.raid_scheduled_day())
			GarrisonRaidState.PHASE_ACTIVE:
				_fact("Raid", "Under attack")
			GarrisonRaidState.PHASE_WON:
				_fact("Resolution", "Garrison secure", UITheme.SUCCESS)
			GarrisonRaidState.PHASE_LOST:
				_fact("Resolution", "Garrison lost", UITheme.DANGER)
		var status := Game.raid_status()
		_fact("Garrison integrity", "%d / %d" % [
			Game.raid_integrity(), GarrisonRaidState.INTEGRITY_MAX])
		_fact("Living raiders", str(int(status.get("living_raiders", 0))))
	_fact("West Gate Bolt-Thrower", "Built" if Game.raid_defense_built() else "Not built")
	_fact("Tally-Ledger", "Stolen" if Game.raid_ledger_stolen() else "Secure",
		UITheme.DANGER if Game.raid_ledger_stolen() else null)


func _build_roster() -> void:
	UITheme.section_rule(_body, "GARRISON ROSTER")
	var working: bool = Clock.garrison_phase() == WorldClock.GARRISON_DAYTIME \
		and Clock.services_available()
	for slot: Dictionary in ROSTER:
		var who: StringName = slot["id"]
		var role: String = slot["role"]
		if not _arrived(who):
			_fact(role, "Undiscovered")
			continue
		var person: Dictionary = DialogueDb.PEOPLE.get(who, {})
		var name_of: String = String(person.get("name", ""))
		var activity: String
		var location: String
		if working:
			activity = "Working"
			location = "%s station" % role
		elif Clock.garrison_phase() == WorldClock.GARRISON_BONFIRE:
			activity = "Bonfire"
			location = "Central hearth"
		else:
			activity = "Sleeping"
			location = "Elder quarters" if who == &"elder" else "Barracks"
		_fact(role, "%s · %s · %s · Services %s" % [
			name_of, activity, location, "Open" if working else "Closed"])


func _arrived(who: StringName) -> bool:
	if who == &"elder" or who == &"quartermaster":
		return true
	if who == &"builder" and Game.flag(
			RelicDb.flag_donated(RelicDb.TALLY_LEDGER_ID)):
		return true
	if Game.flag(StoryDb.intro_flag(who)):
		return true
	# Card #115 separates an earned arrival from a person physically in the yard:
	# at most one unlocked-but-unintroduced keeper is present on a homecoming. If
	# the live garrison has built that arriving body, show it without latching any
	# flag; otherwise the read-only page must not turn an unlock into a roster row.
	var garrison := get_tree().current_scene as Garrison
	if garrison == null:
		return false
	match who:
		&"smith": return garrison.smith != null
		&"alchemist": return garrison.alchemist != null
		&"jewelcrafter": return garrison.jeweller != null
		&"builder": return garrison.builder != null
	return false


func _build_relic_effects() -> void:
	UITheme.section_rule(_body, "DONATED RELIC EFFECTS")
	var found := false
	for row: Dictionary in RelicDb.all():
		var id: StringName = row["id"]
		if not RelicDb.donated(id):
			continue
		_fact(String(row["name"]), String(row["detail"]))
		found = true
	if not found:
		_empty("No donated relic effects yet.")


func _build_improvements() -> void:
	UITheme.section_rule(_body, "ELDER IMPROVEMENTS")
	var found := false
	for id: StringName in ElderUpgradeDb.UPGRADE_IDS:
		var summary: Dictionary = ElderUpgradeDb.summary(id)
		var owned: int = int(summary.get("owned", 0))
		if owned <= 0:
			continue
		_fact("%s · Rank %d / %d" % [summary.get("label", String(id)), owned,
			int(summary.get("limit", owned))], String(summary.get("effect", "")))
		found = true
	if not found:
		_empty("No Elder improvements owned yet.")


func _fact(label_text: String, value_text: String, tone: Variant = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	_body.add_child(row)
	var label := Label.new()
	label.custom_minimum_size.x = 260
	label.text = label_text
	UITheme.apply_text_style(label, UITheme.TYPE_LABEL_MD, UITheme.TEXT_DIM)
	row.add_child(label)
	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.text = value_text
	UITheme.apply_text_style(value, UITheme.TYPE_PARAGRAPH_2,
		tone if tone is Color else UITheme.TEXT)
	row.add_child(value)


func _empty(text: String) -> void:
	var label := Label.new()
	label.text = text
	UITheme.apply_text_style(label, UITheme.TYPE_PARAGRAPH_2, UITheme.TEXT_DIM)
	_body.add_child(label)


func _phase_label(phase: StringName) -> String:
	match phase:
		WorldClock.GARRISON_DAYTIME:
			return "Daytime"
		WorldClock.GARRISON_BONFIRE:
			return "Bonfire Time"
		WorldClock.GARRISON_BEDTIME:
			return "Bedtime"
		_:
			return "Unknown"


func _clock_text(at_hour: float) -> String:
	var total_minutes: int = int(floor(fposmod(at_hour, 24.0) * 60.0 + 0.0001))
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]
