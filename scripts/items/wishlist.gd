class_name Wishlist
extends RefCounted
## Live recipe-use queries. The catalogues remain the only source of recipes;
## this class only gives their current `lines()` a stable shared vocabulary.

const FORGE := "forge"
const ALCHEMY := "alchemy"
const JEWEL := "jewel"


## Every current recipe that consumes `item_id`, in deterministic catalogue and
## line order. A use is `{key: StringName, label: String}`.
static func current_uses(item_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_append_uses(out, item_id, FORGE, ShopDb)
	_append_uses(out, item_id, ALCHEMY, AlchemyDb)
	_append_uses(out, item_id, JEWEL, JewelDb)
	return out


static func usage_sentence(item_id: StringName) -> String:
	var uses := current_uses(item_id)
	if uses.is_empty():
		return "Not used in a current recipe - safe to sell."
	if uses.size() == 1:
		return "Used in %s." % String(uses[0]["label"])
	var names := PackedStringArray()
	for use: Dictionary in uses:
		names.append(String(use["label"]))
	return "Used in %d current recipes: %s." % [uses.size(), ", ".join(names)]


static func is_auto_wishlisted(item_id: StringName) -> bool:
	return Settings.auto_wishlist and not current_uses(item_id).is_empty()


static func is_manual_wishlisted(item_id: StringName) -> bool:
	for use: Dictionary in current_uses(item_id):
		if Game.is_wishlist_line_pinned(use["key"]):
			return true
	return false


static func is_wishlisted(item_id: StringName) -> bool:
	return is_auto_wishlisted(item_id) or is_manual_wishlisted(item_id)


static func is_line_pinned(db: GDScript, line: Dictionary) -> bool:
	var key := line_key(db, line)
	return key != &"" and Game.is_wishlist_line_pinned(key)


## Stable catalogue namespace + authored line id. Labels and line indices never
## enter save data.
static func line_key(db: GDScript, line: Dictionary) -> StringName:
	var domain := _domain_for(db)
	var id := StringName(line.get("id", &""))
	if domain.is_empty() or id == &"":
		return &""
	return StringName("%s:%s" % [domain, String(id)])


## The dynamically derived item set a bulk vendor action must keep for wishlist
## reasons. Components and relics are protected by the vendor itself.
static func wishlisted_ids() -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	_append_wishlisted_ids(out, FORGE, ShopDb)
	_append_wishlisted_ids(out, ALCHEMY, AlchemyDb)
	_append_wishlisted_ids(out, JEWEL, JewelDb)
	return out


static func _append_uses(out: Array[Dictionary], item_id: StringName,
		domain: String, db: GDScript) -> void:
	for line: Dictionary in db.lines():
		var parts: Dictionary = line.get("parts", {})
		if parts.is_empty() or not parts.has(item_id):
			continue
		out.append({
			"key": StringName("%s:%s" % [domain, String(line["id"])]),
			"label": String(line.get("label", line["id"])),
		})


static func _append_wishlisted_ids(out: Dictionary[StringName, bool],
		domain: String, db: GDScript) -> void:
	for line: Dictionary in db.lines():
		var parts: Dictionary = line.get("parts", {})
		if parts.is_empty():
			continue
		var key := StringName("%s:%s" % [domain, String(line["id"])])
		if not Settings.auto_wishlist and not Game.is_wishlist_line_pinned(key):
			continue
		for raw_id: Variant in parts:
			out[StringName(raw_id)] = true


static func _domain_for(db: GDScript) -> String:
	if db == ShopDb:
		return FORGE
	if db == AlchemyDb:
		return ALCHEMY
	if db == JewelDb:
		return JEWEL
	return ""
