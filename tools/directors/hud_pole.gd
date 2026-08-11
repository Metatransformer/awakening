extends RefCounted
## The vitals pole, in every state it has, in both scenes that draw it.
##
## **This is the beat that would have caught the collision in HUD_PLAN §0** — the
## draught row drawn on top of the magic bar in the garrison and four pixels into
## the heat bar underground, which shipped twice and which `alchemy_loop.gd`
## passed straight through both times because none of its checks can see a
## rectangle.
##
## It has to run in BOTH scenes, and that is not a convenience: heat is
## dungeon-only, so the draught row takes a different slot in each, and the
## collision was a DIFFERENT collision in each. A director that only ran one of
## them would have caught one of the two.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/hud_pole.gd --out=/tmp/pole/x.png --warmup=60
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/hud_pole.gd --out=/tmp/pole/x.png --warmup=60
##
## The scene is not switched from in here on purpose. `Flow` owns
## `change_scene_to_file` (CLAUDE.md §6) and a director that drove a transition
## would be photographing the loading card's timing as much as the pole's layout.
## Two runs, one scene each, one prefix each.


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/pole/x.png").get_base_dir()
	await rig.wait_frames(30)

	var underground: bool = Run != null and Run.in_dungeon
	var tag := "d" if underground else "g"

	# 0 draughts: the state every run starts in and spends most of its life in.
	# Before decision 21 this frame drew NO draught row at all.
	await rig.wait_frames(6)
	await rig.capture(out.path_join("%s_00_dry.png" % tag))

	# 1 draught: one slot lit, one slot empty. The frame that proves the slots are
	# fixed by kind — the lit one must be the SECOND slot, because Emberblood is
	# second in `PotionDb.IDS` order and slots do not pack leftward any more.
	Game.start_draught(&"emberblood_draught", K.DRAUGHT_TIME)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("%s_01_ember.png" % tag))

	# The other one alone, so the pair cannot both be passing by accident.
	Game.draughts.clear()
	Game.start_draught(&"ironhide_draught", K.DRAUGHT_TIME)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("%s_02_hide.png" % tag))

	# 2 draughts: the row full. This is the widest the row ever gets and it is the
	# frame the safe-margin claim is made against.
	Game.start_draught(&"emberblood_draught", K.DRAUGHT_TIME)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("%s_03_both.png" % tag))

	# A draught nearly out: the tiles have to have gone out one at a time, and the
	# last one has to still be lit. `ceil` in `_draw_draughts` is what guarantees
	# the second half of that.
	Game.draughts[&"emberblood_draught"] = K.DRAUGHT_TIME * 0.2
	Game.draughts[&"ironhide_draught"] = K.DRAUGHT_TIME * 0.6
	await rig.wait_frames(4)
	await rig.capture(out.path_join("%s_04_expiring.png" % tag))

	# Magic spent. The bar's zero state is an empty track, and an empty track is
	# the thing that has to still read as an instrument.
	Game.magic = 0
	Bus.magic_changed.emit(Game.magic, Game.max_magic)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("%s_05_magic_spent.png" % tag))
	Game.fill_magic()

	# Low health: the pulse is VITAL <-> VOID now, and the frame this exists to
	# disprove is the one where it borrowed BONE from the stamina bar below it.
	Game.damage(Game.quarters - 2)
	await rig.wait_frames(4)
	await rig.capture(out.path_join("%s_06_low.png" % tag))

	if underground:
		# Each heat tier, because heat's row sits between magic and the draughts
		# and nothing else photographs the pole at Blazing. Driven through
		# `Bus.enemy_died`, which is the signal `Heat` actually listens to —
		# poking `Heat.kills` would set the count without the tier, the window or
		# the announcement, and the frame would be of a state the game cannot
		# reach.
		var hero := rig.get_first_node_in_group(&"player") as Node3D
		var at: Vector3 = hero.global_position if hero != null else Vector3.ZERO
		for target in [3, 7, 13]:
			while Heat.kills < target:
				Bus.enemy_died.emit(hero, at)
			await rig.wait_frames(4)
			await rig.capture(out.path_join("%s_07_heat_t%d.png" % [tag, Heat.tier]))

	print("POLECHECK scene=%s draughts=%d/%d magic=%d/%d q=%d" % [
		tag, Game.draughts.size(), 2, Game.magic, Game.max_magic, Game.quarters])
