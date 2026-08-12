extends RefCounted
## Proof director for issue #112, the Society's finite Field Notes economy.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/field_notes.gd \
##     --out=/tmp/field_notes/x.png --size=1280x720 --warmup=60
##
## This runs on the garrison because the two rendered claims are home-loop UI.
## The award claims still go through real run endings: a pending observation is
## not permanent until `Run.extract()` or `Run.die()` builds the debrief.

const SAVE_SLOT: int = 4
const EPSILON: float = 0.001

var out: String = ""
var _fails: int = 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/field_notes/x.png").get_base_dir()
	Saves.erase(SAVE_SLOT)
	await rig.wait_frames(20)

	_definition_and_producers()
	await _debrief_awards(rig)
	await _save_round_trip(rig)
	_doctrine_economy_and_effects()
	await _rendered_ui(rig)

	# Slot 4 is director-owned. Player slots 0..2 are never read or written.
	Saves.erase(SAVE_SLOT)
	_ck("Z0 director save slot 4 was erased", not Saves.has_save(SAVE_SLOT))
	if _fails == 0:
		print("FIELD NOTES OK")
	else:
		print("FIELD NOTES FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("FIELD NOTES FAIL %s" % label)


# --- A. Definition and producer mapping ------------------------------------

func _definition_and_producers() -> void:
	var observations: Array[StringName] = FieldNotesDb.OBSERVATION_IDS
	var doctrines: Array[StringName] = FieldNotesDb.DOCTRINE_IDS
	_ck("A0 exactly five observation ids", observations.size() == 5)
	_ck("A1 exactly three doctrine ids", doctrines.size() == 3)
	_ck("A2 observation ids are unique", _unique_count(observations) == 5)
	_ck("A3 doctrine ids are unique", _unique_count(doctrines) == 3)

	var defined_observations: int = 0
	for id: StringName in observations:
		var row: Dictionary = FieldNotesDb.observation_definition(id)
		if FieldNotesDb.is_observation(id) and row.get("id", &"") == id \
				and not String(row.get("label", "")).is_empty() \
				and int(row.get("notes", 0)) == 1:
			defined_observations += 1
	_ck("A4 every observation has one complete definition (%d/5)"
		% defined_observations, defined_observations == 5)

	var defined_doctrines: int = 0
	for id: StringName in doctrines:
		var row: Dictionary = FieldNotesDb.doctrine_definition(id)
		if FieldNotesDb.is_doctrine(id) and row.get("id", &"") == id \
				and not String(row.get("label", "")).is_empty() \
				and int(row.get("cost", 0)) == 2 \
				and int(row.get("ranks", 0)) == 1:
			defined_doctrines += 1
	_ck("A5 every doctrine has a two-note, one-rank definition (%d/3)"
		% defined_doctrines, defined_doctrines == 3)
	var all_ids: Array[StringName] = observations.duplicate()
	all_ids.append_array(doctrines)
	_ck("A6 all eight ids are globally distinct",
		_unique_count(all_ids) == 8)

	_ck("A7 gate_1 maps to the gate-cycle observation",
		FieldNotesDb.observation_for_puzzle(&"gate_1")
			== FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
	_ck("A8 shortcut_1 maps to the shortcut observation",
		FieldNotesDb.observation_for_puzzle(&"shortcut_1")
			== FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID)
	_ck("A9 the Cistern Warden maps to its defeat observation",
		FieldNotesDb.observation_for_boss(&"cistern_warden")
			== FieldNotesDb.CISTERN_WARDEN_DEFEATED_ID)
	_ck("A10 an unknown puzzle maps to empty",
		FieldNotesDb.observation_for_puzzle(&"not_an_authored_puzzle") == &"")
	_ck("A11 an unknown boss maps to empty",
		FieldNotesDb.observation_for_boss(&"not_an_authored_boss") == &"")
	_ck("A12 an unknown id has no definition",
		FieldNotesDb.definition(&"not_a_field_note").is_empty())


# --- B. Debrief award semantics --------------------------------------------

func _debrief_awards(rig) -> void:
	_reset_state()
	Run.enter(11201)
	Bus.field_observation_recorded.emit(
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
	Bus.field_observation_recorded.emit(
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
	Bus.field_observation_recorded.emit(&"invalid_observation")
	var first_pending: Array[StringName] = [
		FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID,
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID,
	]
	_ck("B0 pending observations are deduplicated and invalid ids are ignored",
		_same_ids(_pending_ids(), first_pending))
	_ck("B1 pending run knowledge has not changed permanent Field Notes",
		Game.field_notes == 0 and Game.awarded_field_observations.is_empty())

	# The relic goes through the actual run bag. `Run.extract()` banks it and is
	# the producer of the ledger-home observation immediately before debrief.
	var took: int = Run.collect(RelicDb.TALLY_LEDGER_ID, 1)
	_ck("B2 the Tally-Ledger entered the real run bag", took == 1
		and int(Run.bag.get(RelicDb.TALLY_LEDGER_ID, 0)) == 1)
	_ck("B3 the real extraction completed", Run.extract())
	var extraction_awards: Array[StringName] = _summary_ids()
	var expected_extraction: Array[StringName] = [
		FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID,
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID,
		FieldNotesDb.FAIR_WEIGHTS_LEDGER_HOME_ID,
	]
	_ck("B4 extraction awarded first descent, gate and brought-home ledger once",
		_same_ids(extraction_awards, expected_extraction))
	_ck("B5 extraction stored only that new award set in Run.summary",
		extraction_awards.size() == 3 and Game.field_notes == 3)
	_ck("B6 debrief cleared run-only pending knowledge",
		Run.pending_field_observations.is_empty())
	await _settle_end(rig)

	_reset_state()
	Run.enter(11202)
	Bus.field_observation_recorded.emit(FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID)
	Run.die()
	var death_awards: Array[StringName] = _summary_ids()
	var expected_death: Array[StringName] = [
		FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID,
		FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID,
	]
	_ck("B7 a fresh real death debrief awards first descent and shortcut",
		_same_ids(death_awards, expected_death))
	_ck("B8 fresh death awarded exactly two permanent notes",
		Game.field_notes == 2 and Game.awarded_field_observations.size() == 2)
	await _settle_end(rig)

	Run.enter(11203)
	Bus.field_observation_recorded.emit(
		FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID)
	Bus.field_observation_recorded.emit(FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID)
	_ck("B9 previously awarded observations never become pending again",
		Run.pending_field_observations.is_empty())
	_ck("B10 a later extraction completes", Run.extract())
	_ck("B11 repeat extraction awards zero notes and an empty receipt list",
		_summary_ids().is_empty() and Game.field_notes == 2)
	await _settle_end(rig)

	Run.enter(11204)
	Bus.field_observation_recorded.emit(FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID)
	Run.die()
	_ck("B12 repeat death awards zero notes and an empty receipt list",
		_summary_ids().is_empty() and Game.field_notes == 2)
	await _settle_end(rig)

	_reset_state()
	Run.enter(11205)
	Bus.field_observation_recorded.emit(
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
	Bus.field_observation_recorded.emit(FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID)
	Bus.field_observation_recorded.emit(FieldNotesDb.CISTERN_WARDEN_DEFEATED_ID)
	var full_ledger_took: int = Run.collect(RelicDb.TALLY_LEDGER_ID, 1)
	_ck("B13 the all-authored fixture carries the real Tally-Ledger",
		full_ledger_took == 1)
	_ck("B14 the all-authored fixture settles through a real extraction",
		Run.extract())
	_ck("B15 every authored observation awarded exactly once",
		_same_ids(_awarded_ids(), FieldNotesDb.OBSERVATION_IDS)
		and _same_ids(_summary_ids(), FieldNotesDb.OBSERVATION_IDS))
	_ck("B16 total authored supply is exactly five and never exceeds five",
		Game.field_notes == 5 and Game.field_notes <= FieldNotesDb.OBSERVATION_IDS.size())
	var overflow_awards: Array[StringName] = \
		Game.award_field_observations(FieldNotesDb.OBSERVATION_IDS)
	_ck("B17 replaying the full authored set cannot exceed the five-note supply",
		overflow_awards.is_empty() and Game.field_notes == 5)
	await _settle_end(rig)


# --- C. Save/load idempotency ----------------------------------------------

func _save_round_trip(rig) -> void:
	Saves.erase(SAVE_SLOT)
	_reset_state()
	var already_awarded: Array[StringName] = [
		FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID,
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID,
		FieldNotesDb.FAIR_WEIGHTS_LEDGER_HOME_ID,
	]
	Game.award_field_observations(already_awarded)
	_ck("C0 save fixture bought Rope Drill through FieldNotesDb.buy()",
		FieldNotesDb.buy(_doctrine_line(FieldNotesDb.ROPE_DRILL_ID)))
	Run.enter(11206)
	Bus.field_observation_recorded.emit(FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID)
	Bus.field_observation_recorded.emit(FieldNotesDb.CISTERN_WARDEN_DEFEATED_ID)
	var saved_pending: Array[StringName] = [
		FieldNotesDb.CISTERN_SHORTCUT_OPENED_ID,
		FieldNotesDb.CISTERN_WARDEN_DEFEATED_ID,
	]
	_ck("C1 fixture has balance 1, three awarded, two pending and Rope rank 1",
		Game.field_notes == 1 and _same_ids(_awarded_ids(), already_awarded)
		and _same_ids(_pending_ids(), saved_pending)
		and FieldNotesDb.doctrine_rank(FieldNotesDb.ROPE_DRILL_ID) == 1)
	_ck("C2 the real Saves API wrote director slot 4", Saves.save(SAVE_SLOT)
		and Saves.has_save(SAVE_SLOT))

	Game.reset()
	Run.reset()
	var destination: Dictionary = Saves.load_slot(SAVE_SLOT)
	_ck("C3 the real Saves API loaded director slot 4", not destination.is_empty())
	_ck("C4 note balance survived save/load", Game.field_notes == 1)
	_ck("C5 awarded observation ids survived save/load",
		_same_ids(_awarded_ids(), already_awarded))
	_ck("C6 pending run ids survived save/load",
		Run.in_dungeon and _same_ids(_pending_ids(), saved_pending))
	_ck("C7 doctrine ranks survived save/load",
		FieldNotesDb.doctrine_rank(FieldNotesDb.ROPE_DRILL_ID) == 1
		and FieldNotesDb.doctrine_rank(FieldNotesDb.MEASURED_BREATH_ID) == 0
		and FieldNotesDb.doctrine_rank(FieldNotesDb.SWEEP_PATTERN_ID) == 0)

	# Replay an id that was already permanent into the loaded debrief. It must
	# neither enter pending nor appear beside the two genuinely new loaded ids.
	Bus.field_observation_recorded.emit(
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
	_ck("C8 replaying an awarded id after load does not enter pending",
		_same_ids(_pending_ids(), saved_pending))
	_ck("C9 the loaded run extracts", Run.extract())
	_ck("C10 the loaded debrief awards only its two unawarded pending ids",
		_same_ids(_summary_ids(), saved_pending))
	_ck("C11 replay did not duplicate balance or the awarded set",
		Game.field_notes == 3 and Game.awarded_field_observations.size() == 5)
	await _settle_end(rig)

	Run.enter(11207)
	Bus.field_observation_recorded.emit(FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
	Run.die()
	_ck("C12 replaying the same awarded debrief remains idempotent",
		_summary_ids().is_empty() and Game.field_notes == 3
		and Game.awarded_field_observations.size() == 5)
	await _settle_end(rig)
	Saves.erase(SAVE_SLOT)
	_ck("C13 slot 4 is erased after the save/load case",
		not Saves.has_save(SAVE_SLOT))


# --- D. Doctrine economy and exact effects ---------------------------------

func _doctrine_economy_and_effects() -> void:
	_reset_state()
	Game.award_field_observations(FieldNotesDb.OBSERVATION_IDS)
	var rope_line: Dictionary = _doctrine_line(FieldNotesDb.ROPE_DRILL_ID)
	var breath_line: Dictionary = _doctrine_line(FieldNotesDb.MEASURED_BREATH_ID)
	var sweep_line: Dictionary = _doctrine_line(FieldNotesDb.SWEEP_PATTERN_ID)
	_ck("D0 the finite authored supply starts at five notes",
		Game.field_notes == 5 and Game.awarded_field_observations.size() == 5)
	_ck("D1 Rope Drill buys through FieldNotesDb.buy()",
		FieldNotesDb.buy(rope_line))
	_ck("D2 Measured Breath buys through FieldNotesDb.buy()",
		FieldNotesDb.buy(breath_line))
	_ck("D3 two different doctrines are rank 1 and leave one note",
		FieldNotesDb.doctrine_rank(FieldNotesDb.ROPE_DRILL_ID) == 1
		and FieldNotesDb.doctrine_rank(FieldNotesDb.MEASURED_BREATH_ID) == 1
		and Game.field_notes == 1)
	_ck("D4 a repeat purchase is refused",
		not FieldNotesDb.buy(rope_line) and Game.field_notes == 1)
	_ck("D5 the third doctrine is refused without overspending",
		not FieldNotesDb.buy(sweep_line)
		and FieldNotesDb.doctrine_rank(FieldNotesDb.SWEEP_PATTERN_ID) == 0
		and Game.field_notes == 1)

	# Each effect gets a clean upgrade store so no other doctrine can make the
	# before/after reading pass accidentally. The economy state is restored below.
	_reset_state()
	var rope: EscapeRope = EscapeRope.new()
	var rope_before: float = rope.channel_time()
	Game.upgrades[FieldNotesDb.ROPE_DRILL_ID] = 1
	var rope_after: float = rope.channel_time()
	rope.free()
	_ck("D6 EscapeRope public channel is exactly 1.2 -> 1.0 seconds",
		_close(rope_before, 1.2) and _close(rope_after, 1.0))

	_reset_state()
	var regen_before: float = Game.stamina_regen()
	Game.upgrades[FieldNotesDb.MEASURED_BREATH_ID] = 1
	var regen_after: float = Game.stamina_regen()
	_ck("D7 Game.stamina_regen is exactly five percent faster",
		regen_before > 0.0 and _close(regen_after, regen_before * 1.05))

	_reset_state()
	Game.upgrades[FieldNotesDb.SWEEP_PATTERN_ID] = 1
	Heat.tier = 0
	var cold_base: float = float(K.HEAT_MAGNET[0])
	var cold_range: float = Heat.magnet_range()
	Heat.tier = FieldNotesDb.WARM_HEAT_TIER
	var warm_base: float = float(K.HEAT_MAGNET[FieldNotesDb.WARM_HEAT_TIER])
	var warm_range: float = Heat.magnet_range()
	_ck("D8 Sweep Pattern leaves magnet range unchanged below Warm",
		_close(cold_range, cold_base))
	_ck("D9 Sweep Pattern adds exactly 0.5 m at Warm and above",
		_close(warm_range, warm_base + 0.5))
	Heat.reset()

	# The legitimate economy cannot own all three at once. Buy each in an
	# isolated two-note case instead, then inspect the same groups() contract the
	# real ladder consumes. That proves every authored row's completed state
	# without inventing an impossible six-note save.
	var funding: Array[StringName] = [
		FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID,
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID,
	]
	var represented_cases: int = 0
	var completed_cases: int = 0
	for purchased_id: StringName in FieldNotesDb.DOCTRINE_IDS:
		_reset_state()
		Game.award_field_observations(funding)
		if not FieldNotesDb.buy(_doctrine_line(purchased_id)):
			continue
		var groups: Array[Dictionary] = FieldNotesDb.groups()
		var tracks: Array = groups[0].get("tracks", []) \
			if groups.size() == 1 else []
		var represented: Array[StringName] = []
		for track: Dictionary in tracks:
			var id: StringName = _doctrine_id_named(
				String(track.get("name", "")))
			if id != &"":
				represented.append(id)
			if id == purchased_id and int(track.get("line", 0)) == -1 \
					and int(track.get("owned", 0)) == 1 \
					and int(track.get("rungs", 0)) == 1:
				completed_cases += 1
		if _same_ids(represented, FieldNotesDb.DOCTRINE_IDS):
			represented_cases += 1
	_ck("D10 all three doctrine tracks remain represented after each purchase",
		represented_cases == 3)
	_ck("D11 each purchased track completes at line=-1 with exactly one rank",
		completed_cases == 3)

	# Put back the state whose economics D1-D5 proved before leaving the case.
	_reset_state()
	Game.award_field_observations(FieldNotesDb.OBSERVATION_IDS)
	FieldNotesDb.buy(_doctrine_line(FieldNotesDb.ROPE_DRILL_ID))
	FieldNotesDb.buy(_doctrine_line(FieldNotesDb.MEASURED_BREATH_ID))
	_ck("D12 the two-of-three economy proof remains intact after effect probes",
		Game.field_notes == 1
		and FieldNotesDb.doctrine_rank(FieldNotesDb.ROPE_DRILL_ID) == 1
		and FieldNotesDb.doctrine_rank(FieldNotesDb.MEASURED_BREATH_ID) == 1
		and FieldNotesDb.doctrine_rank(FieldNotesDb.SWEEP_PATTERN_ID) == 0)


# --- E. Rendered proof at 1280x720 -----------------------------------------

func _rendered_ui(rig) -> void:
	_reset_state()
	Run.enter(11208)
	Bus.field_observation_recorded.emit(
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID)
	_ck("E0 receipt fixture completed a real extraction", Run.extract())
	var summary: Dictionary = Run.summary.duplicate(true)
	var receipt_ids: Array[StringName] = _summary_ids()
	var expected_receipt: Array[StringName] = [
		FieldNotesDb.FIRST_DESCENT_DEBRIEF_ID,
		FieldNotesDb.CISTERN_GATE_CYCLE_SOLVED_ID,
	]
	_ck("E1 receipt fixture has exactly two newly awarded Field Notes",
		_same_ids(receipt_ids, expected_receipt))

	# Flow opens its own receipt after a hold. Wait past that hold, stand it down,
	# free every automatic copy, and only then open the proof copy. Otherwise a
	# later automatic screen can cover the screen whose nodes the checks inspect.
	await _settle_end(rig)
	var receipt: RunEndScreen = RunEndScreen.open(rig.scene(), summary)
	await rig.wait_frames(14)
	var receipt_text: Array[String] = _label_texts(receipt)
	_ck("E2 receipt viewport is exactly 1280x720",
		_viewport_is_720p(receipt))
	_ck("E3 exactly one live RunEndScreen is present",
		_count_run_end_screens(rig.scene()) == 1)
	_ck("E4 receipt frame fits inside the viewport", _frame_fits(receipt))
	var exact_rows: bool = true
	for id: StringName in FieldNotesDb.OBSERVATION_IDS:
		var wanted: int = 1 if expected_receipt.has(id) else 0
		if receipt_text.count(FieldNotesDb.display_text(id)) != wanted:
			exact_rows = false
	_ck("E5 exactly the two awarded observation names are rendered", exact_rows)
	_ck("E6 each rendered observation carries +1 Field Note",
		receipt_text.count("+1 Field Note") == expected_receipt.size())
	_ck("E7 receipt renders the new total",
		receipt_text.has("New total: 2 Field Notes"))
	_ck("E8 a known but unseen Warden observation is absent",
		not receipt_text.has(FieldNotesDb.display_text(
			FieldNotesDb.CISTERN_WARDEN_DEFEATED_ID)))
	await rig.capture(out.path_join("field_notes_00_receipt.png"))
	receipt.get_parent().queue_free()
	await rig.wait_frames(8)
	_ck("E9 receipt closes cleanly", _count_run_end_screens(rig.scene()) == 0)

	_reset_state()
	Game.award_field_observations(FieldNotesDb.OBSERVATION_IDS)
	var board: TradeScreen = TradeScreen.open(rig.scene(),
		TradeScreen.Mode.PROGRESSION, "FIELD NOTES", FieldNotesDb, &"",
		"Field Notes")
	await rig.wait_frames(16)
	var board_text: Array[String] = _label_texts(board)
	var row_ids: Array[StringName] = []
	var correct_costs: int = 0
	for row: Dictionary in board._rows:
		if row.get("kind", &"") != &"buy":
			continue
		var line: Dictionary = row.get("line", {})
		var id: StringName = StringName(line.get("id", &""))
		if FieldNotesDb.is_doctrine(id):
			row_ids.append(id)
		if String(row.get("sub", "")) == "2 Field Notes":
			correct_costs += 1
	_ck("E10 board viewport is exactly 1280x720", _viewport_is_720p(board))
	_ck("E11 exactly one live TradeScreen is present",
		_count_trade_screens(rig.scene()) == 1)
	_ck("E12 TradeScreen frame fits inside the viewport", _frame_fits(board))
	_ck("E13 the real focus-capable board owns keyboard/controller focus",
		board.get_viewport().gui_get_focus_owner() is Button
		and board.is_ancestor_of(board.get_viewport().gui_get_focus_owner()))
	_ck("E14 header, service kicker and balance all say Field Notes",
		board_text.has("Field Notes") and board_text.has("FIELD NOTES")
		and board_text.has("5 Field Notes"))
	_ck("E15 exactly the three authored doctrine tracks are visible",
		_same_ids(row_ids, FieldNotesDb.DOCTRINE_IDS)
		and board._ladder != null and board._ladder.count() == 3)
	_ck("E16 every authored doctrine shows its two-note cost",
		correct_costs == 3)
	var band_cells: Array = board._band_cells()
	var currency_cell: Dictionary = band_cells[0] if not band_cells.is_empty() else {}
	var currency_icon: String = String(currency_cell.get("icon", ""))
	_ck("E17 Field Notes use the read marker, never the gold purse marker",
		currency_icon == UiKit.action_icon("read")
		and currency_icon != UiKit.action_icon("coin")
		and not "\n".join(board_text).contains("◇"))
	await rig.capture(out.path_join("field_notes_01_board.png"))
	board.close()
	await rig.wait_frames(8)
	_ck("E18 progression board closes cleanly",
		_count_trade_screens(rig.scene()) == 0)


# --- Helpers ---------------------------------------------------------------

func _reset_state() -> void:
	Game.reset()
	Run.reset()
	Heat.reset()


func _settle_end(rig) -> void:
	await rig.wait_seconds(1.2)
	Flow.ending = false
	for node: Node in _all(rig.scene()):
		if node is RunEndScreen and is_instance_valid(node.get_parent()):
			node.get_parent().queue_free()
	rig.paused = false
	Prompt.blocked = false
	await rig.wait_frames(8)


func _doctrine_line(id: StringName) -> Dictionary:
	for line: Dictionary in FieldNotesDb.lines():
		if line.get("id", &"") == id:
			return line
	return {}


func _doctrine_id_named(label: String) -> StringName:
	for id: StringName in FieldNotesDb.DOCTRINE_IDS:
		if FieldNotesDb.display_text(id) == label:
			return id
	return &""


func _summary_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var raw: Variant = Run.summary.get("field_notes", [])
	if raw is not Array:
		return ids
	for value: Variant in raw:
		if value is StringName or value is String:
			ids.append(StringName(value))
	return ids


func _pending_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in Run.pending_field_observations:
		ids.append(id)
	return ids


func _awarded_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in Game.awarded_field_observations:
		if bool(Game.awarded_field_observations[id]):
			ids.append(id)
	return ids


func _same_ids(actual: Array[StringName], expected: Array[StringName]) -> bool:
	if actual.size() != expected.size():
		return false
	for id: StringName in actual:
		if not expected.has(id):
			return false
	return true


func _unique_count(ids: Array[StringName]) -> int:
	var unique: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		unique[id] = true
	return unique.size()


func _close(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= EPSILON


func _label_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in _all(root):
		if node is Label:
			texts.append((node as Label).text)
	return texts


func _viewport_is_720p(screen: Control) -> bool:
	return Vector2(screen.get_viewport_rect().size).is_equal_approx(
		Vector2(1280.0, 720.0))


func _frame_fits(screen: Control) -> bool:
	var frame: Control = screen.find_child("Frame", true, false) as Control
	if frame == null:
		return false
	var view: Rect2 = Rect2(Vector2.ZERO, screen.get_viewport_rect().size)
	var rect: Rect2 = frame.get_global_rect()
	return rect.position.x >= view.position.x - 0.5 \
		and rect.position.y >= view.position.y - 0.5 \
		and rect.end.x <= view.end.x + 0.5 \
		and rect.end.y <= view.end.y + 0.5


func _count_run_end_screens(root: Node) -> int:
	var count: int = 0
	for node: Node in _all(root):
		if node is RunEndScreen:
			count += 1
	return count


func _count_trade_screens(root: Node) -> int:
	var count: int = 0
	for node: Node in _all(root):
		if node is TradeScreen:
			count += 1
	return count


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child: Node in root.get_children():
		found.append_array(_all(child))
	return found
