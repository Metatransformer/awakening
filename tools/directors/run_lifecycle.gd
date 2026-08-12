extends RefCounted
## Fresh run seeds and extraction health persistence, through the Run API.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/run_lifecycle.gd \
##     --out=/tmp/run_lifecycle/x.png --warmup=60

const EXPLICIT_SEED := 424242
const QUEUED_SEED := 515151


func run(rig) -> void:
	var run_before: Dictionary = Run.snapshot()
	var seed_next_before: int = Run.seed_next
	var summary_before: Dictionary = Run.summary.duplicate(true)
	var last_attacker_before: StringName = Run.last_attacker
	var flags_before: Dictionary[StringName, bool] = Game.flags.duplicate()
	var quarters_before: int = Game.quarters
	var gold_before: int = Game.gold
	var flow_busy_before: bool = Flow.busy

	Run.seed_next = 0
	Run.enter(0)
	var first_seed: int = Run.seed_used
	Game.heal(Game.max_quarters)
	Game.damage(K.HEART)
	var damaged_quarters: int = Game.quarters
	rig.check(first_seed > 0, "the first fresh run receives a nonzero seed")
	rig.check(damaged_quarters > 0 and damaged_quarters < Game.max_quarters,
		"the extraction fixture carries live damage")
	# Extraction normally opens the receipt and pauses the tree synchronously.
	# Flow's own transition guard suppresses only that presentation here; the
	# public Run.extract settlement and every other run-ended listener still run.
	Flow.busy = true
	rig.check(Run.extract(), "the first run extracts successfully")
	Flow.busy = flow_busy_before
	rig.check(Game.quarters == damaged_quarters,
		"ordinary extraction preserves damaged health")

	Run.enter(0)
	var second_seed: int = Run.seed_used
	rig.check(second_seed > 0, "the second fresh run receives a nonzero seed")
	rig.check(second_seed != first_seed,
		"consecutive unpinned runs receive distinct seeds")

	Run.enter(EXPLICIT_SEED)
	rig.check(Run.seed_used == EXPLICIT_SEED,
		"an explicit nonzero seed remains exact")
	Run.seed_next = QUEUED_SEED
	Run.enter(0)
	rig.check(Run.seed_used == QUEUED_SEED and Run.seed_next == 0,
		"Run.seed_next remains exact and is consumed once")

	Run.restore(run_before)
	Run.seed_next = seed_next_before
	Run.summary = summary_before
	Run.last_attacker = last_attacker_before
	Flow.busy = flow_busy_before
	Game.flags.clear()
	Game.flags.merge(flags_before)
	Game.quarters = quarters_before
	Game.gold = gold_before
	Bus.player_health_changed.emit(Game.quarters, Game.max_quarters)
	Bus.gold_changed.emit(Game.gold)
