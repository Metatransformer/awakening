extends Node
## Autoload `Flow`. Owns the three scenes the game actually has and the fades
## between them.
##
## Title, garrison, dungeon. The title screen is the boot scene and the two
## buttons on it are `new_game` and `continue_game` below; everything after that
## is the loop.
##
## Garrison and dungeon are separate scenes rather than one streamed world
## because the transition IS the mechanic: extracting has to feel like arriving
## somewhere, and dying has to feel like waking up somewhere. A seamless walk
## between them would make both of those into a corridor.
##
## Nothing else calls `change_scene_to_file`. If a second caller appears, the
## fade stops being a guarantee and starts being a suggestion.

const GARRISON := "res://scenes/rooms/garrison.tscn"
const OUTSKIRTS := "res://scenes/rooms/garrison_outskirts.tscn"
const DUNGEON := "res://scenes/rooms/dungeon.tscn"
const TITLE := "res://scenes/ui/title/title_screen.tscn"

const FADE_OUT := 0.35
const FADE_IN := 0.45
## Beat between the extract flash / death and the screen going dark, so the
## player sees the thing that happened to them.
const HOLD := 0.45
## How long the loading card holds before the floor fades in.
##
## `change_scene_to_file` is synchronous and a floor of this size builds in well
## under a frame, so this is NOT a progress bar for a load that takes any time --
## it is the read. Fourteen characters at the size the card draws them needs
## roughly a second of settled screen to be read rather than glimpsed, and the
## number under it is the thing the player is actually here for. Under a second
## and the descent stops announcing anything; much over and a stair the player
## takes eight times a run turns into a wait. [tune]
const LOAD_HOLD := 1.30

const NIGHT_TITLE: String = "Night falls"
const DAWN_TITLE: String = "The sun rises"
const NIGHT_CUE: StringName = &"nightfall_owl"
const DAWN_CUE: StringName = &"dawn_birds"

enum ArrivalIntent {
	DEFAULT,
	DOWN_STAIRS,
}


class DayTitleRequest extends RefCounted:
	var title: String
	var day: int
	var cue: StringName
	var natural_dawn: bool

	func _init(title_text: String, campaign_day: int, cue_id: StringName,
			resolve_natural_dawn: bool) -> void:
		title = title_text
		day = campaign_day
		cue = cue_id
		natural_dawn = resolve_natural_dawn

## True while a transition is in flight. Everything that could start another one
## checks this -- a second extract press during the fade would re-enter
## garrison.
var busy: bool = false
## True from the moment a run ends until the ending screen's button is pressed.
##
## A second guard beside `busy` rather than a reuse of it, because the two mean
## opposite things to the one caller that matters: `to_garrison()` refuses while
## a transition is in flight and is exactly what the ending screen's button
## calls. Folding them together would leave the button unable to fire the
## transition it exists to fire.
var ending: bool = false
## Set only while Bed advances the clock behind Flow's own veil. Dawn listeners
## still update the world, but the curfew handler must not start another trip.
var deliberate_rest: bool = false
var _dawn_collapse := false
var _wake_at_bunk := false

var _layer: CanvasLayer
var _veil: ColorRect
## The named loading screen, alive only between the veil going black and the new
## floor fading in. Held as a field rather than a local so a transition that
## starts while one is still up cannot leave an orphan welded over the game --
## the card is opaque, and an opaque orphan on layer 200 is an unrecoverable
## black screen.
var _card: LoadingCard = null
var _day_title_queue: Array[DayTitleRequest] = []
var _day_title_card: DayTitleCard = null
var _presenting_day_title: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_layer = CanvasLayer.new()
	# Above the pause menu (100) and the HUD (50): a fade that something can draw
	# on top of is not a fade.
	_layer.layer = 200
	add_child(_layer)

	_veil = ColorRect.new()
	_veil.color = Color(Pal.VOID, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_veil)

	Bus.player_died.connect(_on_player_died)
	Bus.run_ended.connect(_on_run_ended)
	Clock.dawn_started.connect(_on_dawn_started)
	Clock.bonfire_started.connect(_on_bonfire_started)
	# **The other half of the pause menu's Load Game.** `MenuSavesPanel` restores
	# the slot itself and emits `load_requested(slot, dest)` for somebody else to
	# travel on -- and until now nobody did, so loading a save from the pause menu
	# restored `Game` and left the player standing in the room they were already
	# in. The save applied to the numbers and to nothing on screen.
	#
	# It goes to `resume` and NOT to `continue_game`: the panel has already spent
	# `Saves.load_slot`, and calling the title screen's entry point here would read
	# the slot a second time.
	#
	# The wire is on THIS side rather than the menu calling `Flow` directly, for
	# the reason pause_menu.gd states about its own `quit_to_title_requested`: P14
	# does not own scene transitions. Flow does, and it is the only thing that
	# calls `change_scene_to_file` (see the header). `Menu` is safe to reach for
	# here because Flow is the LAST autoload -- the note above it in
	# `project.godot` is the record of why -- so the menu is already in the tree.
	Menu.load_requested.connect(_on_menu_load_requested)


func _process(_delta: float) -> void:
	_try_present_day_title()


# --- The boot is the title screen, and that is not a setting -----------------

## Called by a scene that is about to build itself and suspects it is the first
## thing this session has ever shown. Returns true if it is, and if so has
## already sent the player to the title screen — the caller must build NOTHING.
##
## **THE GAME ALWAYS STARTS AT THE FRONT DOOR.** Until 2026-08-10 that door was
## the garrison and this function said so; the title screen took the job on the
## same day, and a refused boot goes there now rather than to the courtyard.
## That is the stricter answer, not a looser one: dropping a mistyped launcher
## into the garrison starts a game nobody chose, with whatever flags the process
## happened to have, which is the same complaint this function was written about
## one room further up. The title screen is where CONTINUE and NEW GAME are, so
## it is the only place that can hand out a game somebody actually picked.
##
## `run/main_scene` is supposed to be the whole of that rule and it is not enough,
## because it has drifted to the dungeon three separate times (the note above it
## in `project.godot` is the record). This is the fourth way in, and this time the
## setting was innocent: a positional scene path on the command line,
##
##     godot --path . res://scenes/rooms/dungeon.tscn
##
## beats `main_scene` outright. One launcher typed for one look at a floor and
## the player boots underground — no gate, no descent, no choice, and the first
## time they ever meet the way down is after their first death. A setting can be
## fixed. The habit that keeps pointing at a floor cannot, so the rule is code.
##
## `get_tree().current_scene` is the entire discriminator, and it separates the
## three cases exactly:
##
##   * **Booted** — `main_scene` or a path on the command line. The engine calls
##     `add_current_scene`, which assigns `current_scene` BEFORE adding the node,
##     so a scene asking this during its own `_ready` already finds itself there.
##     Refused.
##   * **The harness** — `tools/shoot.gd` attaches with a plain `root.add_child`,
##     so `current_scene` stays null. Every director that photographs a floor
##     directly is untouched, which is what keeps this from costing the one way
##     anybody actually looks at the dungeon.
##   * **Flow's own transitions** — `new_game` and `_go` set `busy` before
##     `change_scene_to_file`, and the destination's `_ready` runs before they
##     clear it. That is the positive proof that the title, a save load, or an
##     authored gate chose this scene; let it build. `Run.in_dungeon` cannot be
##     the discriminator because a legitimate garrison/outskirts load is not a
##     dungeon run.
##
## An ANCESTOR test and not `==`, because the script asking is usually not the
## scene root: `dungeon.tscn` is a `DungeonRun` holding the env, the hero, the
## camera and a `Dungeon` child, and it is that child that carries the generator.
## Comparing the caller to `current_scene` directly let the very launch this was
## written against straight through.
##
## `--boot-here` opts out, for a human who really does want a floor from a cold
## start without going through the harness. Same bargain the harness's `--intro`
## makes: safe by default, and the one caller that wants the other thing says so.
func refuse_boot(scene: Node) -> bool:
	var booted := get_tree().current_scene
	if booted == null or not (booted == scene or booted.is_ancestor_of(scene)):
		return false
	if busy:
		return false
	if OS.get_cmdline_args().has("--boot-here") \
			or OS.get_cmdline_user_args().has("--boot-here"):
		print("Flow: --boot-here, booting into %s" % booted.scene_file_path)
		return false

	# Loud, because the alternative is a developer watching the garrison appear
	# after they asked for a floor and having no idea why.
	push_warning("Flow: refused to boot into %s -- the game starts at the "
		% booted.scene_file_path
		+ "title screen. Use tools/shoot.gd to look at a room, or --boot-here.")
	print("Flow: %s is not a boot scene; going to the title screen."
		% booted.scene_file_path)

	# Straight there, not `to_garrison()`: that one fades out of a world the
	# player is looking at, and there is no such world yet -- the scene calling
	# this has not drawn a frame and is about to return without building one.
	get_tree().change_scene_to_file.call_deferred(TITLE)
	return true


# --- Starting a game --------------------------------------------------------

## NEW GAME. Throw the character away, play the opening, arrive in the garrison.
##
## The three beats, and the order matters as much as it does in
## `Garrison._open_the_game`:
##
##   1. **`Game.reset()` FIRST**, before anything is loaded or shown. It clears
##      `Game.flags`, which is what re-arms the garrison's own opening
##      (`reported_for_duty`) and every other one-way thing in the game. This is
##      the only caller `reset()` has ever had -- before the title screen existed
##      the game had no way of starting a second one.
##   2. **The cutscene goes up over the black, and the garrison is built behind
##      it.** Not after it: the scene change is free at this size and doing it
##      under the picture means the fade off the last frame of the opening is
##      the fade onto the courtyard, with nothing in between.
##   3. **The world is PAUSED for the whole of the opening**, for the same reason
##      `_go`'s loading hold pauses it: a garrison
##      running behind an opaque picture for twenty seconds is a hero being
##      walked out of it by a gamepad's stick drift (CLAUDE.md §3).
##
## `Saves` is deliberately NOT touched. `active_slot` is already -1 in a process
## that has only ever seen the title screen, and `autosave` claims the first
## EMPTY slot and never picks one to overwrite for you -- so starting a new game
## with three full slots costs the player nothing until they choose one.
func new_game() -> void:
	if busy or ending:
		return
	ending = false
	Game.reset()
	Clock.set_time(1, 8.0)
	busy = true
	Prompt.blocked = true

	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_veil, "color:a", 1.0, FADE_OUT)
	await tw.finished

	var opening := Cutscene.open(_layer, Cutscene.OPENING)
	# The picture is opaque and fills the same rect, in front of the veil. Same
	# handover as the loading card: dropping the veil now is what makes the
	# CUTSCENE the thing the garrison fades in from, rather than fading a world
	# in behind a picture and then dissolving a black layer off it.
	_veil.color.a = 0.0
	# The score belongs to the opening, not to the room being built behind it.
	# Forced rather than derived, because by the time the first line is spoken
	# the current scene IS the garrison and `Music` would otherwise call this
	# the town.
	Music.force(Music.Mood.PROLOGUE)

	get_tree().paused = false
	var err := get_tree().change_scene_to_file(GARRISON)
	if err != OK:
		push_error("Flow: could not load %s (%d)" % [GARRISON, err])
		opening.queue_free()
		Music.release()
		busy = false
		Prompt.blocked = false
		_veil.color.a = 0.0
		return

	# Two frames for the new scene's `_ready` to run, so the picture lifts on a
	# built courtyard rather than on the title screen's last frame.
	await get_tree().process_frame
	await get_tree().process_frame

	get_tree().paused = true
	await opening.finished
	get_tree().paused = false

	Music.release()
	Prompt.blocked = false
	busy = false
	var tin := create_tween().set_ignore_time_scale(true)
	tin.tween_property(opening, "modulate:a", 0.0, FADE_IN)
	tin.tween_callback(opening.queue_free)


## CONTINUE, off the title screen. Restore a slot and go to the room it was
## written in.
##
## Returns false without touching the screen if the slot cannot be read, so the
## title screen can put its menu back rather than fading to a garrison that was
## never restored.
##
## `Saves.load_slot` deliberately does not change scenes (docs/CONTRACT.md §8) --
## it hands back where the hero was, and travelling there is the caller's job
## because only the caller knows when the scene it belongs to exists. That second
## half is `resume` below, and it is a function of its own because the pause menu
## needs it WITHOUT this one's first line.
func continue_game(slot: int) -> bool:
	if busy or ending:
		return false
	var dest := Saves.load_slot(slot)
	if dest.is_empty():
		return false
	return await resume(dest)


## **Travel to an already-restored save.** `dest` is what `Saves.load_slot`
## handed back: `Game` is restored by the time this is called, and all that is
## left is the half that has pixels in it -- the room, and the hero standing in
## the right part of it.
##
## Split out of `continue_game` because a load has TWO doors and only one of them
## may read the slot:
##
##   * the title screen's CONTINUE arrives with nothing restored, so
##     `continue_game` does both halves;
##   * the PAUSE MENU's Load Game arrives with the slot already spent --
##     `MenuSavesPanel._on_slot_pressed` calls `Saves.load_slot` itself and then
##     emits `load_requested(slot, dest)` -- so it needs this half alone.
##
## Pointing the second one at `continue_game` would load the same slot twice: the
## restore is not idempotent in the way that would forgive (`Game.bottle_contents`
## and `Game.upgrades` are cleared and rebuilt, `Saves.loaded` fires twice, and
## every listener that draws off it repaints on a second identical event).
##
## Returns false without touching the screen when there is nothing to travel to
## or a transition is already in flight, so the title screen can put its menu back
## rather than fading to a room that was never restored.
func resume(dest: Dictionary) -> bool:
	if busy or ending or dest.is_empty():
		return false
	ending = false
	var restored_dungeon := bool(dest.get("run_restored", false)) \
		and bool(dest.get("in_dungeon", false)) and Run.in_dungeon
	var path := String(dest.get("scene", GARRISON))
	if restored_dungeon:
		# The snapshot's seed and level are live before the scene is built, so the
		# ordinary Dungeon._ready path regenerates the same floor.
		path = DUNGEON
	else:
		_abandon_run()
		# A dungeon path without a valid run snapshot is not playable. The bounded
		# surface path is, and keeps its authored/saved transform.
		if path != GARRISON and path != OUTSKIRTS:
			path = GARRISON
	# `dest` goes THROUGH `_go` rather than being applied after it -- see the
	# placement inside `_go` for why that ordering is the difference between a
	# save that survives being loaded and one that does not.
	await _go(path, 0.0, dest)
	return true


## Loading a non-dungeon or legacy slot ends whatever run was in flight, and it
## says so out loud. A valid v10 dungeon snapshot bypasses this function entirely.
##
## `reset()` and not `die()`. Dying is a run ENDING: it writes a receipt, counts
## against the mercy that `Game.deaths` buys (GDD §7.1), and brings the document
## case home. This run did not end, it was discarded, and none of that should
## reach the ledger. `Bus.run_ended` is likewise not emitted -- `_on_run_ended` is
## two lines below and would raise the receipt screen over the load.
##
## The three emits are here because `reset()` is deliberately silent (it is also
## `Run._ready`'s initialiser, where there is nobody listening yet), and the HUD
## would otherwise go on drawing the abandoned bag's value and the floor number
## until something else happened to move them.
func _abandon_run() -> void:
	Run.reset()
	Bus.bag_changed.emit(Run.bag, Run.bag_value())
	Bus.level_changed.emit(Run.level)
	Bus.depth_changed.emit(Run.depth)


func _on_menu_load_requested(_slot: int, dest: Dictionary) -> void:
	resume(dest)


## Put the hero back where the save left him, when the destination carries a
## scene-owned transform.
##
## Called from inside `_go` once the new scene's `_ready` has run and placed him
## at the room's default spawn. A destination without `pos` or `yaw` deliberately
## keeps those authored values. Silent when there is no hero in the tree, which
## is the honest answer for a save written in a scene that no longer has one.
func _place_hero(dest: Dictionary) -> void:
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	if hero == null:
		return
	if dest.has("pos"):
		hero.global_position = dest["pos"]
	# The dungeon's default-spawn trigger can fire during the two build frames
	# above. Put the saved room metadata back in the same ordering as the transform
	# so `_go`'s tail autosave cannot replace it with the entrance.
	Saves.current_room = StringName(dest.get("room", Saves.current_room))
	# **No `+ PI` here, and that is not an oversight.** `Saves.save` writes the
	# hero's `global_rotation.y` verbatim, so what comes back is a NODE rotation
	# and not a heading -- round-tripping it is an assignment. The conversion
	# CLAUDE.md §4 is about (`rotation.y = heading + PI`) belongs where a heading
	# is being turned into a facing, and there is no heading in this dictionary.
	if dest.has("yaw"):
		hero.global_rotation.y = float(dest["yaw"])


## Place an ascending hero on the room-facing side of the canonical DOWN stair.
## Dungeon publishes exactly one ordinary-descent stair through this group and
## opts the optional shortcut landing out before either enters the tree.
func _place_hero_at_down_stairs() -> void:
	var stairs := get_tree().get_first_node_in_group(Stairs.ARRIVAL_GROUP) as Stairs
	var hero := get_tree().get_first_node_in_group(&"player") as Hero
	if stairs == null or hero == null:
		push_warning("Flow: ascent arrival could not find the DOWN stair or hero")
		return
	hero.global_position = stairs.arrival_position()
	var heading := stairs.arrival_heading()
	hero.facing_yaw = atan2(heading.x, heading.z)
	hero.global_rotation.y = hero.facing_yaw + PI
	var room := stairs.arrival_room_id()
	if room != &"":
		Saves.current_room = room


# --- Entry points -----------------------------------------------------------

func enter_dungeon(run_seed: int = 0) -> void:
	if busy or ending:
		return
	Run.enter(run_seed)
	_go(DUNGEON, 0.0)


func to_outskirts() -> void:
	if busy or ending:
		return
	_go(OUTSKIRTS, 0.0)


## The ride home. Called by the ending screen's BACK TO THE GARRISON button,
## and by anything else that just wants the hub.
func to_garrison() -> void:
	if busy:
		return
	ending = false
	_go(GARRISON, 0.0)


## The garrison consumes this after its generated compound exists, so every
## automatic dawn arrival uses the player's actual authored bunk port.
func consume_bunk_wake() -> bool:
	var wake := _wake_at_bunk
	_wake_at_bunk = false
	return wake


## Take the stair down. The run CONTINUES: same bag, same health, same fee
## climbing. Only the floor is new.
##
## It reloads the same dungeon scene rather than loading a different one, which
## is what "endless" means here -- there is no floor 8 scene to run out of. The
## layout differs because `Run.descend_floor` moves the level and the generator
## seeds off `Run.floor_seed()`, so a given run seed still replays identically
## all the way down (scripts/world/dungeon.gd).
func descend() -> void:
	if busy or ending or not Run.in_dungeon:
		return
	Run.descend_floor()
	_go(DUNGEON, 0.0)


## Go back one generated floor without settling the run. Floor 1 is the surface
## seam instead: it uses `Run.extract()` itself, preserving the fee, current
## health, banking and receipt path shared with the portable Escape Rope.
func ascend() -> void:
	if busy or ending or not Run.in_dungeon:
		return
	if Run.level <= 1:
		Run.extract()
		return
	Run.ascend_floor()
	_go(DUNGEON, 0.0, {}, ArrivalIntent.DOWN_STAIRS)


## Fade to black, run `during`, fade back — without changing scenes.
##
## The bed's transition, and it is HERE rather than in `Bed` because the veil is
## Flow's and there is exactly one of it. A prop that made its own ColorRect
## would be a second black rectangle on a second CanvasLayer, and the day the two
## overlapped one of them would be the one that never came down. Same reason
## CLAUDE.md §6 gives for `change_scene_to_file` living in one file.
##
## `busy` is held for the whole blink, so nothing can start a scene change
## underneath it — a player who presses the gate through a fade would otherwise
## arrive in the dungeon with the veil half-lifted and a `during` callback still
## queued against the garrison that no longer exists.
##
## The world is PAUSED across the dark. A rest that let the garrison run for a
## second and a half behind an opaque veil is the same bug `_go`'s loading hold
## exists to prevent, one screen smaller.
func blink(during: Callable, dark: float = 0.9) -> void:
	if busy or ending:
		return
	busy = true
	Prompt.blocked = true

	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_veil, "color:a", 1.0, FADE_OUT)
	await tw.finished

	get_tree().paused = true
	await get_tree().create_timer(dark, true, false, true).timeout
	if during.is_valid():
		during.call()
	get_tree().paused = false

	Prompt.blocked = false
	busy = false
	# A sleep can cross dawn while this blink owns Flow. Hand the blocker directly
	# to the queued title card so there is no one-frame input window between the
	# black rest screen and the five-second announcement.
	_try_present_day_title()
	var tin := create_tween().set_ignore_time_scale(true)
	tin.tween_property(_veil, "color:a", 0.0, FADE_IN)


## `open_on_black` USED TO BE HERE, and it is deliberately gone.
##
## It started the scene opaque, held for `dark` seconds and lifted -- the mirror
## of `blink`, for a world the player has not seen yet -- and it had exactly one
## caller: `Garrison._open_the_game`, holding a black rectangle down over fifteen
## seconds of narration. `new_game` above does that job now with the road
## painting in front of the veil instead of nothing, so the black-screen variant
## had no callers left on 2026-08-10 and was deleted rather than kept warm.
##
## Do not reinstate it for "an opening that does not want a picture". The one
## thing it did that `new_game` does not is start opaque on the FIRST frame of a
## scene, and `new_game` does not need that because it fades out of the title
## screen before the garrison exists. Something that genuinely needs a dark hold
## with no scene change has `blink`.


# --- The two things that end a run ------------------------------------------

func _on_player_died() -> void:
	if ending:
		return
	if Run.in_dungeon:
		# Run.die clears the bag and emits run_ended(false), which is what raises
		# the ending screen. Death does not know about scenes.
		Run.die()
	else:
		# Killed somewhere with no run behind it -- garrison, a lookdev scene, a
		# director's test room. There is nothing to lose and nowhere to be sent,
		# so he just gets up.
		#
		# `busy` is deliberately NOT a guard on this branch. It used to guard
		# the whole function, which meant a blow that landed during a fade was
		# dropped entirely: the run had already ended and healed him to full,
		# monsters kept swinging for the ~1 s the fade takes, and a second
		# lethal hit hit this early return. He arrived in the garrison on zero
		# hearts -- and then could not die again, because Hero.take_hit refuses
		# at zero, so nothing would ever emit `player_died` to heal him. The
		# ending screen stops the world dead, which closes that window at the
		# source; this makes sure the recovery still works if anything ever
		# opens another one.
		Game.heal(Game.max_quarters)


## A run ended, either way it can end. Stop the world and show the receipt.
##
## It does NOT go to the garrison. Sending the player home on a timer meant the
## run ended in a room they never got to look at, and the summary then had to be
## re-staged in the hub, where it was drawn as a Label3D above the arrival
## camera's frustum and was never once seen (see run_end_screen.gd). The screen
## belongs over the floor the run ended on, and leaving is the player's press.
func _on_run_ended(_extracted: bool, _contents: Dictionary, _value: int) -> void:
	if _dawn_collapse:
		_dawn_collapse = false
		_return_at_dawn.call_deferred()
		return
	if busy or ending:
		return
	ending = true
	_show_ending()


func _on_bonfire_started(day: int) -> void:
	if _civil_titles_allowed():
		_queue_day_title(NIGHT_TITLE, day, NIGHT_CUE, false)


## Dawn is announced first. Only after its complete five-second card does a
## natural overnight outing resolve; deliberate bed rest receives the same card
## without becoming curfew travel.
func _on_dawn_started(day: int) -> void:
	var natural_dawn := not deliberate_rest
	if _civil_titles_allowed():
		_queue_day_title(DAWN_TITLE, day, DAWN_CUE, natural_dawn)
		return
	if natural_dawn:
		_resolve_natural_dawn()


## A stopped Clock is a test/save setup surface, not a live presentation source.
## The title scene is the other hard exclusion: civil time never draws over the
## front door. Directors that exercise this feature explicitly enable Clock.
func _civil_titles_allowed() -> bool:
	if not Clock.running:
		return false
	var scene := get_tree().current_scene
	return scene == null or scene.scene_file_path != TITLE


func _queue_day_title(title_text: String, day: int, cue: StringName,
		resolve_natural_dawn: bool) -> void:
	_day_title_queue.append(DayTitleRequest.new(
		title_text, day, cue, resolve_natural_dawn))
	_try_present_day_title()


## Start at most one card. `_process` retries queued cards after a Flow fade,
## dialogue, menu, or ending gives the world back; no boundary is discarded for
## arriving while another owner has input blocked.
func _try_present_day_title() -> void:
	if _presenting_day_title or _day_title_queue.is_empty():
		return
	if busy or ending or get_tree().paused or Prompt.blocked:
		return
	_present_next_day_title()


func _present_next_day_title() -> void:
	var was_paused := get_tree().paused
	var was_blocked := Prompt.blocked
	var resolve_natural_dawn := false
	_presenting_day_title = true
	busy = true
	Prompt.blocked = true
	get_tree().paused = true

	# A single forward jump (and a full night's sleep) can cross more than one
	# civil boundary synchronously. Drain the FIFO under one uninterrupted pause
	# so neither player input nor another Flow transition can slip between cards.
	while not _day_title_queue.is_empty():
		var request: DayTitleRequest = _day_title_queue.pop_front()
		resolve_natural_dawn = resolve_natural_dawn or request.natural_dawn
		_day_title_card = DayTitleCard.open(
			_layer, request.title, request.day, request.cue)
		Bus.request_global_sfx.emit(request.cue)
		await _day_title_card.finished
		if _day_title_card != null:
			_day_title_card.get_parent().remove_child(_day_title_card)
			_day_title_card.queue_free()
			_day_title_card = null

	get_tree().paused = was_paused
	Prompt.blocked = was_blocked
	busy = false
	_presenting_day_title = false

	if resolve_natural_dawn:
		_resolve_natural_dawn()


## On the surface dawn is a ride to the bunk. Underground it keeps the existing
## death settlement, so waiting for the title card never turns dawn into an
## extraction or preserves the carried bag.
func _resolve_natural_dawn() -> void:
	if busy or ending:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == TITLE:
		return
	if Run.in_dungeon:
		_dawn_collapse = true
		Run.die()
		return
	_return_at_dawn.call_deferred()


func _return_at_dawn() -> void:
	if busy:
		return
	ending = false
	_wake_at_bunk = true
	_go(GARRISON, 0.0)


## Hold on the killing blow, then raise the screen.
##
## The hold is the same beat the fade used to take, and it is here for the same
## reason: the player has to see the thing that happened to them. The pause lands
## AFTER it so the death animation, the hit-stop and the doom sting all get to
## play, and then everything stops -- which is also what makes a second blow during
## this window impossible rather than merely unlikely.
func _show_ending() -> void:
	Prompt.blocked = true
	await get_tree().create_timer(HOLD * 1.4, true, false, true).timeout
	if not ending:
		return
	get_tree().paused = true
	# `Prompt.blocked` stays set the whole way through to `_go`, which clears it on
	# arrival. The screen adds its own blocker on top; that one expires with the
	# node, and this one covers the frames either side of it.
	RunEndScreen.open(self, Run.summary)


# --- Transition -------------------------------------------------------------

## `dest` is a load's `{scene, room}` plus a proven optional `pos` / `yaw`, and
## empty for every other transition. `arrival` is Flow's internal generated-floor
## seam and never changes ordinary save placement.
func _go(path: String, hold: float, dest: Dictionary = {},
		arrival: ArrivalIntent = ArrivalIntent.DEFAULT) -> void:
	busy = true
	Prompt.blocked = true
	if hold > 0.0:
		await get_tree().create_timer(hold, true, false, true).timeout

	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_veil, "color:a", 1.0, FADE_OUT)
	await tw.finished

	# The named card, on the two ways into the dungeon and on nothing else. The
	# garrison is the place you already know; the floor is the one that needs
	# saying.
	#
	# `Run.level` is correct HERE because every floor-changing caller moves the run
	# before it calls this -- entering resets to 1, descent increments, and ascent
	# decrements -- which is also why the card can be built once and never updated.
	var card := path == DUNGEON
	if card:
		_raise_card()
		# The veil has nothing left to cover: the card is opaque and fills the
		# same rect, in front of it. Dropping it now is what makes the CARD the
		# thing the floor fades in from, rather than fading the world in behind a
		# card and then dissolving a second black layer off it.
		_veil.color.a = 0.0

	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Flow: could not load %s (%d)" % [path, err])
		busy = false
		Prompt.blocked = false
		_drop_card()
		_veil.color.a = 0.0
		return

	# One frame for the new scene's _ready to run, so the fade lifts on the
	# built world rather than on the old one's last frame.
	await get_tree().process_frame
	await get_tree().process_frame

	# **A load places the hero HERE, and the position of these three lines is the
	# whole reason `dest` is threaded through this function.**
	#
	# It has to be after the two frames above, because the hero does not exist
	# until the new scene's `_ready` has run. And it has to be before
	# `Saves.autosave()` at the foot of this function, because that reads the
	# hero's position out of the LIVE TREE: run it while he is still standing on
	# the room's default spawn and it writes that spawn straight back over the
	# slot the player just loaded. The save would survive exactly one load and
	# then quietly forget where it was written -- which is a nastier version of
	# the bug this whole change is about, because the numbers would still be
	# right.
	#
	# It is also simply earlier than it used to be: `continue_game` did this after
	# awaiting `_go`, which is one frame into the fade-in.
	if not dest.is_empty():
		_place_hero(dest)
	elif arrival == ArrivalIntent.DOWN_STAIRS:
		_place_hero_at_down_stairs()

	# The read. Deliberately AFTER the scene is built rather than in parallel with
	# building it: the hold is for the player, and a hold that overlapped the work
	# would shrink to nothing the day a floor takes longer to generate.
	#
	# **And the world is STOPPED for it.** `change_scene_to_file` returns a floor
	# that is already running, so without this the hold is a second and a third of
	# live game behind an opaque card: monsters wake, walk to a hero who is
	# standing still because his player is reading a title, and swing. It cost a
	# `mvp_loop` run to find -- he arrived on floor 1, died during the card, and
	# because `_on_run_ended` refuses while `busy` the run ended with no receipt
	# and no way home. A loading screen the game plays on is not a loading screen.
	#
	# `process_always` on the timer is what lets this un-pause itself: Flow is
	# PROCESS_MODE_ALWAYS and so is the card.
	if card:
		get_tree().paused = true
		await get_tree().create_timer(LOAD_HOLD, true, false, true).timeout
		get_tree().paused = false

	Prompt.blocked = false
	busy = false
	var tin := create_tween().set_ignore_time_scale(true)
	if _card != null:
		tin.tween_property(_card, "modulate:a", 0.0, FADE_IN)
		tin.tween_callback(_drop_card)
		# The HUD's floor card takes over from this one on the same frame, so the
		# name never leaves the screen in the middle of the handover. `level`
		# rather than a bare ping because a listener that has to ask Run which
		# floor it is could be told a different answer on a late frame.
		Bus.floor_arrived.emit(Run.level)
	else:
		tin.tween_property(_veil, "color:a", 0.0, FADE_IN)

	# The autosave, and it is EVERY transition rather than a flag per caller.
	# Entering, changing floors, loading, extracting and dying are all moments the
	# player would be furious to replay. A rule with no exceptions also cannot be
	# forgotten by the next caller.
	#
	# Here at the END, not before the fade, for two reasons. `Saves.save` reads
	# the hero's position out of the live tree, and during the fade that hero is
	# the one in the scene being left. And the notice this raises is drawn by the
	# HUD -- announcing it to a screen that is still black is announcing it to
	# nobody, so it goes up on the same frame the world comes back.
	Saves.autosave()


# --- The loading card -------------------------------------------------------

## Free whatever is up and put a fresh card over the black. Added to `_layer`
## after `_veil`, which is what puts it in FRONT of the veil -- siblings draw in
## tree order.
## The card names the FLOOR, not the shaft. `Prog.NAME` was what it said until
## GDD §3's "the day the Cistern and the Foundry become real places" arrived --
## four floors that all announced themselves as THE SUNKEN CUT. `Run.level` is
## already the new floor by the time this runs (Flow sets it before the fade), so
## the card is the arrival and not the departure.
func _raise_card() -> void:
	_drop_card()
	_card = LoadingCard.open(_layer, FloorDb.announced_name(Run.level),
		Prog.label(Run.level))


func _drop_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
