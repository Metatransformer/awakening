class_name DevCommands
extends RefCounted
## Validated local developer mutations shared by the console and directors.

const ARMAMENT_IDS: Array[StringName] = [
	&"bow", &"burst", &"hookshot", &"far_lantern",
]
const AMMO_IDS: Array[StringName] = [&"arrows", &"charges"]
const KEY_IDS: Array[StringName] = [&"small_key", &"boss_key"]
const WORKING_IDS: Array[StringName] = [&"sustain", &"ballast"]
const WORKING_RELICS := {
	&"sustain": &"sustain_verse",
	&"ballast": &"ballast_verse",
}


static func toggle_god() -> Dictionary:
	Game.dev_god_mode = not Game.dev_god_mode
	if Game.dev_god_mode:
		Game.quarters = Game.max_quarters
		Bus.player_health_changed.emit(Game.quarters, Game.max_quarters)
		Game.stamina = Game.max_stamina
		Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
		Game.fill_magic()
		Game.add_arrows(Game.max_arrows - Game.arrows)
		Game.add_charges(Game.max_charges - Game.charges)
	return _result(true, "God mode %s." % (
		"ON — health and resources refilled" if Game.dev_god_mode else "OFF"))


static func grant(raw_id: StringName) -> Dictionary:
	var id := StringName(String(raw_id).strip_edges().to_lower())
	if id == &"":
		return _result(false, "Usage: /grant <item_id>. Valid ids: %s" % _id_text(grant_ids()))

	if ARMAMENT_IDS.has(id):
		var already_owned := Game.has(id)
		Game.grant(id)
		return _result(true, "%s %s." % [String(id),
			"was already owned" if already_owned else "granted"])
	if id == &"arrows":
		Game.add_arrows(Game.max_arrows - Game.arrows)
		return _result(true, "Arrows filled to %d." % Game.arrows)
	if id == &"charges":
		Game.add_charges(Game.max_charges - Game.charges)
		return _result(true, "Charges filled to %d." % Game.charges)
	if id == &"small_key":
		Game.add_key()
		return _result(true, "Small Key granted (%d held)." % Game.small_keys)
	if id == &"boss_key":
		Game.add_boss_key()
		return _result(true, "Boss Key granted for floor %d." % Run.level)
	if WORKING_IDS.has(id):
		var relic_id: StringName = WORKING_RELICS[id]
		if RelicDb.donated(relic_id):
			return _result(true, "%s was already unlocked." % String(id).capitalize())
		Game.set_flag(RelicDb.flag_donated(relic_id))
		Bus.item_acquired.emit(relic_id)
		return _result(true, "%s working unlocked." % String(id).capitalize())

	if ItemDb.get_def(id) != null:
		if not Run.in_dungeon:
			return _result(false, "%s is a bag item; start a run with /tp dungeon first."
				% String(id))
		if Run.collect(id) <= 0:
			return _result(false, "The run bag has no room for %s." % String(id))
		return _result(true, "%s added to the run bag." % String(id))

	return _result(false, "Unknown grant id '%s'. Valid ids: %s"
		% [String(id), _id_text(grant_ids())])


static func grant_ids() -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ARMAMENT_IDS + AMMO_IDS + KEY_IDS + WORKING_IDS:
		seen[id] = true
	for id: StringName in ItemDb.all():
		seen[id] = true
	var out: Array[StringName] = []
	for id: StringName in seen:
		out.append(id)
	out.sort()
	return out


static func upgrade(raw_id: StringName) -> Dictionary:
	var id := StringName(String(raw_id).strip_edges().to_lower())
	if id == &"":
		return _result(false, "Usage: /upgrade <upgrade_id>. Valid ids: %s"
			% _id_text(upgrade_ids()))
	if not upgrade_ids().has(id):
		return _result(false, "Unknown upgrade id '%s'. Valid ids: %s"
			% [String(id), _id_text(upgrade_ids())])

	if Game.JEWEL_TRACKS.has(id):
		var slot := _jewel_slot(id)
		var blank_id := JewelDb.blank_id(slot)
		if not JewelDb.owns_blank(slot):
			return _result(false, "Upgrade %s first; %s has no blank."
				% [String(blank_id), String(id)])
	if Game.path_closed(id):
		return _result(false, "%s is locked by sibling track %s."
			% [String(id), String(Game.sibling_of(id))])

	var current := int(Game.upgrades.get(id, 0))
	var cap := _upgrade_cap(id)
	if current >= cap:
		return _result(false, "%s is already at its authored cap (%d)."
			% [String(id), cap])

	var next := current + 1
	Game.upgrades[id] = next
	if id == &"bag_slot":
		Game.bag_slots += 1
	if id == &"heart" or id == &"jewel_amulet_vigor" \
			or id == &"jewel_amulet_focus":
		Game.resync_maxima(true)

	if Game.FORGE_TRACKS.has(id) or Game.JEWEL_TRACKS.has(id) \
			or _jewel_blank_ids().has(id):
		Bus.gear_forged.emit(id, next)
	if FieldNotesDb.DOCTRINE_IDS.has(id):
		Bus.doctrine_purchased.emit(id, Game.field_notes)
	Bus.item_acquired.emit(id)
	return _result(true, "%s advanced to rung %d/%d." % [String(id), next, cap])


static func upgrade_ids() -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in Game.FORGE_TRACKS:
		seen[id] = true
	for id: StringName in SupplyDb.UPGRADE_IDS:
		seen[id] = true
	for id: StringName in ElderUpgradeDb.UPGRADE_IDS:
		seen[id] = true
	for id: StringName in Game.JEWEL_TRACKS:
		seen[id] = true
	for id: StringName in _jewel_blank_ids():
		seen[id] = true
	for id: StringName in FieldNotesDb.DOCTRINE_IDS:
		seen[id] = true
	var out: Array[StringName] = []
	for id: StringName in seen:
		out.append(id)
	out.sort()
	return out


static func _jewel_blank_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot: StringName in Game.JEWEL_SLOTS:
		ids.append(JewelDb.blank_id(slot))
	return ids


static func _jewel_slot(track: StringName) -> StringName:
	for slot: StringName in Game.JEWEL_SLOTS:
		if String(track).begins_with("jewel_%s_" % slot):
			return slot
	return &""


static func _upgrade_cap(id: StringName) -> int:
	if Game.FORGE_TRACKS.has(id):
		return int(ShopDb.LIMITS.get(id, K.FORGE_MAX))
	if SupplyDb.UPGRADE_IDS.has(id):
		return int(SupplyDb.LIMITS[id])
	if ElderUpgradeDb.UPGRADE_IDS.has(id):
		return int(ElderUpgradeDb.LIMITS[id])
	if Game.JEWEL_TRACKS.has(id):
		return K.JEWEL_MAX
	if _jewel_blank_ids().has(id):
		return 1
	if FieldNotesDb.DOCTRINE_IDS.has(id):
		return FieldNotesDb.DOCTRINE_RANKS
	return 0


static func _id_text(ids: Array[StringName]) -> String:
	var words: Array[String] = []
	for id: StringName in ids:
		words.append(String(id))
	return ", ".join(words)


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
