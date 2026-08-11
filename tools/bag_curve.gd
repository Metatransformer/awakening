extends SceneTree
## What a run actually HOLDS, floor by floor. The evidence behind
## `docs/METAGAME.md` §3.1's tier table, re-runnable so a later session can check
## it rather than believe it.
##
##   godot --path . --headless -s tools/bag_curve.gd
##
## `--headless` is correct here and only here: this takes no screenshots, so the
## missing rendering device that silently empties a director's frames (CLAUDE.md
## §2) costs nothing, and three other agents are usually on the GPU.
##
## **Everything is `load()`ed at runtime and nothing is statically typed.** That
## is not sloppiness: a `-s` script is compiled BEFORE the autoloads are
## registered, so naming `Game`, or naming any `class_name` whose file mentions
## one, is a compile error (`shoot.gd`'s note on `preload`, and CLAUDE.md §3's
## `--check-only` row, which turns out to bite here too).
##
## It does NOT build a dungeon. It rebuilds the *counts* a dungeon produces --
## `FloorDb.rooms/pack/roster`, `Dungeon.chest_chance`, `Prog.chest_picks` and
## `Prog.drop_rolls`, `Enemy.DEFS` health -- rolls them through the real
## `ItemDb.roll` tables, and pushes every mote through the real `Run.collect`, so
## the SLOT arithmetic (three case slots first, then the hold; a part-stack costs
## a whole slot in each region) is the shipped one rather than a model of it. If
## the generator's shape changes, the reads at the top of `_floor` are what to
## re-check.
##
## Three readings per floor, because one number would hide the argument:
##
##   SWEPT   what a player who walks over everything is holding. The bag fills
##           with whatever fell first and then refuses the good stuff -- there is
##           no drop verb, so this is a real ceiling for that player and not a
##           strawman.
##   BEST    the best selection of `slots` slots out of everything that fell on
##           floors 1..N. Nobody plays this well; it needs perfect foresight
##           about which motes to step around. So it is an UPPER BOUND on careful
##           play, which is what a threshold argument actually needs.
##   HOT     BEST plus the heat premium a strong chain stamps on body loot.

## Runs per floor. 400 is enough that the BEST median moves by single digits
## between seeds; the tails want the count.
const SEEDS := 400

## `Dungeon.chest_chance`, which is `@export` there rather than const, so this is
## a copy. It is the one number here a scene could override.
const CHEST_CHANCE := 0.55

## What a strong chain is worth on the half of the loot that falls off bodies.
## Heat tier 2 is x1.60 and tier 3 x2.20 (`K.HEAT_TIER_MULT`), motes cool over 6 s
## back toward x1.00 (`K.HEAT_COOL_TIME`), and chest loot is swept between chains
## rather than during one -- so a sustained Hot run banks well under the headline
## multiplier. 1.4 is deliberately generous to the case being argued against.
const HEAT_ON_BODIES := 1.4

var _game: Node
var _run: Node
var _db: GDScript
var _prog: GDScript
var _floors: GDScript
var _pal: GDScript
var _relics: GDScript
var _echoes: GDScript
var _defs: Dictionary
var _start_slots: int
var _max_slots: int


func _initialize() -> void:
	_game = root.get_node_or_null(^"Game")
	_run = root.get_node_or_null(^"Run")
	if _game == null or _run == null:
		push_error("BAGCURVE no /root/Game or /root/Run -- autoloads did not boot")
		quit(1)
		return
	_db = load("res://scripts/items/item_db.gd")
	_prog = load("res://scripts/core/progression.gd")
	_floors = load("res://scripts/world/floor_db.gd")
	_pal = load("res://scripts/ui/style.gd")
	_relics = load("res://scripts/items/relic_db.gd")
	_echoes = load("res://scripts/items/echo_db.gd")
	_defs = load("res://scripts/actors/enemies/enemy.gd").DEFS
	var k: GDScript = load("res://scripts/core/consts.gd")
	_start_slots = k.START_BAG_SLOTS
	# `SupplyDb.LIMITS[&"bag_slot"]` is 4, and that is the whole of the ladder: a
	# bag can never be bigger than this, on any save, ever.
	_max_slots = _start_slots + 4

	print("BAGCURVE seeds=%d  start_slots=%d  max_slots=%d"
		% [SEEDS, _start_slots, _max_slots])
	print("BAGCURVE thresholds T1=%d T2=%d T3=%d" % [_pal.T1, _pal.T2, _pal.T3])
	_ceiling(_start_slots)
	_ceiling(_max_slots)
	_curve(_start_slots, "STARTING BAG (%d)" % _start_slots)
	_curve(_max_slots, "FULLY BOUGHT BAG (%d)" % _max_slots)
	quit()


## The arithmetic card #49 did by hand, done off the catalogue instead. Two
## answers, because they are different claims: MONOCULTURE is every slot holding
## a full stack of the single best item (what the card computed), and
## BEST-DISTINCT is the best distinct stacks -- which is what a bag can actually
## be filled with, because no single item's supply is unlimited.
func _ceiling(slots: int) -> void:
	var rows: Array = []
	for id: StringName in _db.all():
		var d = _db.all()[id]
		if d.value <= 0 or _relics.is_relic(id) or _echoes.is_echo(id):
			continue
		rows.append({"id": id, "slot": d.value * d.stack})
	rows.sort_custom(func(a, b): return int(a["slot"]) > int(b["slot"]))

	var mono := int(rows[0]["slot"]) * slots
	var mixed := 0
	for i in mini(slots, rows.size()):
		mixed += int(rows[i]["slot"])
	print("BAGCURVE ceiling slots=%2d  monoculture=%d (%s)  best-distinct=%d"
		% [slots, mono, rows[0]["id"], mixed])


func _curve(slots: int, title: String) -> void:
	print("\nBAGCURVE --- %s ---" % title)
	# Every seed carries its bag down all four floors, because the stair does
	# (`Run.descend_floor`). Floor 3's number is floors 1 + 2 + 3.
	var swept: Array = [[], [], [], []]
	var best: Array = [[], [], [], []]
	var hot: Array = [[], [], [], []]

	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 90210 + s
		_game.bag_slots = slots
		_run.enter(1000 + s)
		# Everything that has fallen so far this run, for the BEST reading.
		var pool: Dictionary = {}
		var body_pool: Dictionary = {}

		for level in [1, 2, 3, 4]:
			_run.level = level
			var fell := _floor(level, rng)
			for id: StringName in fell["all"]:
				pool[id] = int(pool.get(id, 0)) + int(fell["all"][id])
			for id: StringName in fell["bodies"]:
				body_pool[id] = int(body_pool.get(id, 0)) + int(fell["bodies"][id])
			# SWEPT: hand the motes to the real bag, in the order they fell.
			for id: StringName in fell["order"]:
				_run.collect(id)
			swept[level - 1].append(_run.bag_value())
			var b := _best_bag(pool, slots)
			best[level - 1].append(b["value"])
			hot[level - 1].append(int(b["value"])
				+ _hot_bonus(b["taken"], body_pool, pool))

	for i in 4:
		print("BAGCURVE floor %d  swept med=%4d p90=%4d | best med=%4d p90=%4d | hot med=%4d p90=%4d max=%4d"
			% [i + 1, _med(swept[i]), _pct(swept[i], 0.90),
				_med(best[i]), _pct(best[i], 0.90),
				_med(hot[i]), _pct(hot[i], 0.90), _pct(hot[i], 1.0)])
	for i in 4:
		print("BAGCURVE floor %d  swept[%s]  best[%s]  hot[%s]"
			% [i + 1, _tiers(swept[i]), _tiers(best[i]), _tiers(hot[i])])


## One floor's worth of motes. Returns the multiset that fell (`all`), the half
## of it that fell off bodies (`bodies` -- the half heat can stamp), and the flat
## ordered list a sweeping player walks over (`order`).
func _floor(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var room_count: int = _floors.rooms(level)
	var pack: Vector2i = _floors.pack(level)
	var enemy_table: Dictionary = _db.enemy_drops(level)
	var chest_table: Dictionary = _db.chest_drops(level)
	var elite_chance: float = _prog.elite_chance(level)
	var rolls: int = _prog.drop_rolls(level)

	# `Dungeon._plan` grows a tree by budding, biased 70% toward the frontier --
	# which is what makes the walk long and the distances deep. Distance is the
	# only thing this needs out of it: `FloorDb.roster` is keyed on it.
	var dist: Array[int] = [0]
	var frontier := 0
	for i in room_count - 1:
		var from: int = frontier if rng.randf() < 0.7 \
			else rng.randi_range(0, dist.size() - 1)
		dist.append(dist[from] + 1)
		frontier = dist.size() - 1
	var deepest := 0
	for i in dist.size():
		if dist[i] > dist[deepest]:
			deepest = i

	var all: Dictionary = {}
	var bodies: Dictionary = {}
	var order: Array[StringName] = []

	for i in dist.size():
		if i == 0:
			continue  # the entrance room is deliberately empty
		var count := rng.randi_range(pack.x, pack.y)
		for e in count:
			var kind: StringName = _kind(level, dist[i], rng)
			var health: int = _defs.get(kind, {}).get("health", 6)
			var n := (1 + int(health / 7.0)) * rolls
			if e == 0 and rng.randf() < elite_chance:
				n += 1
			for _d in n:
				var id: StringName = _db.roll(enemy_table, rng)
				order.append(id)
				all[id] = int(all.get(id, 0)) + 1
				bodies[id] = int(bodies.get(id, 0)) + 1
		# The deepest room always has one (the `deep_chest` anchor on an authored
		# floor, the plain branch otherwise); every other room rolls for it.
		if i == deepest or rng.randf() < CHEST_CHANCE:
			for _p in int(_prog.chest_picks(level, i == deepest)):
				var id: StringName = _db.roll(chest_table, rng)
				order.append(id)
				all[id] = int(all.get(id, 0)) + 1
	return {"all": all, "bodies": bodies, "order": order}


func _kind(level: int, room_dist: int, rng: RandomNumberGenerator) -> StringName:
	var pool: Array = _floors.roster(level, room_dist)
	if pool.is_empty():
		return &"skeleton"
	return pool[rng.randi_range(0, pool.size() - 1)]


## The best `slots` slots out of everything that fell. Greedy, and greedy is
## exact here: a slot of an item is worth `value * min(left, stack)`, which is
## non-increasing in the number of slots already given to that item, so taking
## the best available slot each time cannot be beaten.
func _best_bag(pool: Dictionary, slots: int) -> Dictionary:
	var left: Dictionary = pool.duplicate()
	var taken: Dictionary = {}
	var value := 0
	for _s in slots:
		var pick := &""
		var gain := 0
		for id: StringName in left:
			var n: int = left[id]
			if n <= 0:
				continue
			var d = _db.get_def(id)
			if d == null or d.value <= 0:
				continue
			var g: int = d.value * mini(n, d.stack)
			if g > gain:
				gain = g
				pick = id
		if pick == &"":
			break
		var d = _db.get_def(pick)
		var n: int = mini(int(left[pick]), d.stack)
		left[pick] = int(left[pick]) - n
		taken[pick] = int(taken.get(pick, 0)) + n
		value += gain
	return {"value": value, "taken": taken}


## What Heat adds to a bag whose body loot was swept warm. Chest loot is not
## stamped here: you open a chest between chains, not during one.
func _hot_bonus(taken: Dictionary, body_pool: Dictionary, pool: Dictionary) -> int:
	var bonus := 0.0
	for id: StringName in taken:
		var total: int = int(pool.get(id, 0))
		if total <= 0:
			continue
		var body_share := float(int(body_pool.get(id, 0))) / float(total)
		var d = _db.get_def(id)
		bonus += float(d.value) * float(taken[id]) * body_share * (HEAT_ON_BODIES - 1.0)
	return int(round(bonus))


func _tiers(a: Array) -> String:
	var n := [0, 0, 0, 0]
	for v in a:
		n[_pal.tier(int(v))] += 1
	return "T0 %d%% T1 %d%% T2 %d%% T3 %d%%" % [
		100 * n[0] / a.size(), 100 * n[1] / a.size(),
		100 * n[2] / a.size(), 100 * n[3] / a.size()]


func _med(a: Array) -> int:
	return _pct(a, 0.5)


func _pct(a: Array, p: float) -> int:
	var b := a.duplicate()
	b.sort()
	return int(b[clampi(int(floor(p * float(b.size()))), 0, b.size() - 1)])
