class_name Bag
extends RefCounted
## The dungeon bag: a fixed number of stacking slots (docs/METAGAME.md §7).
##
## Slot order is meaningful. Slots `0 .. K.BELT_SLOTS-1` are the **belt pouch**,
## which survives death; everything after it is lost. That is why this is a
## positional array and not a Dictionary of counts — where a thing sits is a
## decision the player makes, so the data structure has to be able to hold it.
##
## A slot is `[id: StringName, count: int]`, or `[&"", 0]` when empty.

signal changed

var slots: Array = []


func _init(size: int = K.BAG_SLOTS) -> void:
	slots.resize(size)
	for i in slots.size():
		slots[i] = [&"", 0]


func size() -> int:
	return slots.size()


func is_belt(index: int) -> bool:
	return index >= 0 and index < K.BELT_SLOTS


func id_at(index: int) -> StringName:
	if index < 0 or index >= slots.size():
		return &""
	return slots[index][0]


func count_at(index: int) -> int:
	if index < 0 or index >= slots.size():
		return 0
	return slots[index][1]


func is_empty_at(index: int) -> bool:
	return count_at(index) <= 0


func is_full() -> bool:
	for i in slots.size():
		if is_empty_at(i):
			return false
	return true


## Total of one ingredient across every slot.
func count(id: StringName) -> int:
	var total := 0
	for s in slots:
		if s[0] == id:
			total += s[1]
	return total


func total_items() -> int:
	var total := 0
	for s in slots:
		total += s[1]
	return total


## What the vendor would pay for everything currently held.
func total_value() -> int:
	var v := 0
	for s in slots:
		if s[1] > 0:
			v += LootDB.sell_value(s[0]) * s[1]
	return v


## Add up to `n` of `id`. Returns how many did NOT fit — callers must handle a
## full bag, because "the bag is full and this is better than what I'm holding"
## is the decision the whole design exists to produce.
func add(id: StringName, n: int = 1) -> int:
	var item := LootDB.get_item(id)
	if item == null or n <= 0:
		return n
	var remaining := n

	# Top up existing stacks before opening a new slot, so a haul packs tight.
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i][0] == id and slots[i][1] < item.max_stack:
			var space: int = item.max_stack - slots[i][1]
			var take: int = mini(space, remaining)
			slots[i][1] += take
			remaining -= take

	for i in slots.size():
		if remaining <= 0:
			break
		if is_empty_at(i):
			var take: int = mini(item.max_stack, remaining)
			slots[i] = [id, take]
			remaining -= take

	if remaining < n:
		changed.emit()
	return remaining


## Remove up to `n`. Returns how many were actually removed.
func remove(id: StringName, n: int = 1) -> int:
	var remaining := n
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i][0] == id and slots[i][1] > 0:
			var take: int = mini(slots[i][1], remaining)
			slots[i][1] -= take
			remaining -= take
			if slots[i][1] <= 0:
				slots[i] = [&"", 0]
	var removed := n - remaining
	if removed > 0:
		changed.emit()
	return removed


## Drop one whole stack on the floor of the bag's owner. Returns [id, count].
func take_slot(index: int) -> Array:
	if index < 0 or index >= slots.size() or is_empty_at(index):
		return [&"", 0]
	var out: Array = slots[index].duplicate()
	slots[index] = [&"", 0]
	changed.emit()
	return out


## Swap two slots. This is how a player moves a good find into the belt, which
## is the one inventory interaction that carries real stakes.
func swap(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= slots.size() or b >= slots.size():
		return
	var t: Array = slots[a]
	slots[a] = slots[b]
	slots[b] = t
	changed.emit()


## Everything in the bag as id -> count, then empty it. Used on extraction, when
## the whole haul moves to the town stash.
func drain() -> Dictionary:
	var out: Dictionary = {}
	for i in slots.size():
		if slots[i][1] > 0:
			out[slots[i][0]] = int(out.get(slots[i][0], 0)) + slots[i][1]
		slots[i] = [&"", 0]
	changed.emit()
	return out


## Death. The belt survives; everything past it is gone. Returns what was lost
## as id -> count, so the death screen can say exactly what it cost.
func drop_all_but_belt() -> Dictionary:
	var lost: Dictionary = {}
	for i in range(K.BELT_SLOTS, slots.size()):
		if slots[i][1] > 0:
			lost[slots[i][0]] = int(lost.get(slots[i][0], 0)) + slots[i][1]
		slots[i] = [&"", 0]
	changed.emit()
	return lost


func clear() -> void:
	for i in slots.size():
		slots[i] = [&"", 0]
	changed.emit()


## Serialised form for Saves — ids and counts only, never resource paths.
func to_data() -> Array:
	var out: Array = []
	for s in slots:
		out.append([String(s[0]), s[1]])
	return out


func from_data(data: Array) -> void:
	for i in slots.size():
		if i < data.size():
			slots[i] = [StringName(data[i][0]), int(data[i][1])]
		else:
			slots[i] = [&"", 0]
	changed.emit()
