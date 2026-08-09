extends Node
## Autoload `Flow`. Owns the two scenes the game actually has and the fade
## between them.
##
## Town and dungeon are separate scenes rather than one streamed world because
## the transition IS the mechanic: extracting has to feel like arriving
## somewhere, and dying has to feel like waking up somewhere. A seamless walk
## between them would make both of those into a corridor.
##
## Nothing else calls `change_scene_to_file`. If a second caller appears, the
## fade stops being a guarantee and starts being a suggestion.

const TOWN := "res://scenes/rooms/town.tscn"
const DUNGEON := "res://scenes/rooms/dungeon.tscn"

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

## True while a transition is in flight. Everything that could start another one
## checks this -- a second extract press during the fade would re-enter town.
var busy: bool = false
## True from the moment a run ends until the ending screen's button is pressed.
##
## A second guard beside `busy` rather than a reuse of it, because the two mean
## opposite things to the one caller that matters: `to_town()` refuses while a
## transition is in flight and is exactly what the ending screen's button calls.
## Folding them together would leave the button unable to fire the transition it
## exists to fire.
var ending: bool = false

var _layer: CanvasLayer
var _veil: ColorRect
## The named loading screen, alive only between the veil going black and the new
## floor fading in. Held as a field rather than a local so a transition that
## starts while one is still up cannot leave an orphan welded over the game --
## the card is opaque, and an opaque orphan on layer 200 is an unrecoverable
## black screen.
var _card: LoadingCard = null


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


# --- Entry points -----------------------------------------------------------

func enter_dungeon(run_seed: int = 0) -> void:
	if busy or ending:
		return
	Run.enter(run_seed)
	_go(DUNGEON, 0.0)


## The ride home. Called by the ending screen's BACK TO TOWN button, and by
## anything else that just wants the hub.
func to_town() -> void:
	if busy:
		return
	ending = false
	_go(TOWN, 0.0)


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


# --- The two things that end a run ------------------------------------------

func _on_player_died() -> void:
	if ending:
		return
	if Run.in_dungeon:
		# Run.die clears the bag and emits run_ended(false), which is what raises
		# the ending screen. Death does not know about scenes.
		Run.die()
	else:
		# Killed somewhere with no run behind it -- town, a lookdev scene, a
		# director's test room. There is nothing to lose and nowhere to be sent, so
		# he just gets up.
		#
		# `busy` is deliberately NOT a guard on this branch. It used to guard the
		# whole function, which meant a blow that landed during a fade was dropped
		# entirely: the run had already ended and healed him to full, monsters kept
		# swinging for the ~1 s the fade takes, and a second lethal hit hit this
		# early return. He arrived in town on zero hearts -- and then could not
		# die again, because Hero.take_hit refuses at zero, so nothing would ever
		# emit `player_died` to heal him. The ending screen stops the world dead,
		# which closes that window at the source; this makes sure the recovery
		# still works if anything ever opens another one.
		Game.heal(Game.max_quarters)


## A run ended, either way it can end. Stop the world and show the receipt.
##
## It does NOT go to town. Sending the player home on a timer meant the run ended
## in a room they never got to look at, and the summary then had to be re-staged in
## the hub, where it was drawn as a Label3D above the arrival camera's frustum and
## was never once seen (see run_end_screen.gd). The screen belongs over the floor
## the run ended on, and leaving is the player's press.
func _on_run_ended(_extracted: bool, _contents: Dictionary, _value: int) -> void:
	if busy or ending:
		return
	ending = true
	_show_ending()


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

func _go(path: String, hold: float) -> void:
	busy = true
	Prompt.blocked = true
	if hold > 0.0:
		await get_tree().create_timer(hold, true, false, true).timeout

	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_veil, "color:a", 1.0, FADE_OUT)
	await tw.finished

	# The named card, on the two ways into the dungeon and on nothing else. Town
	# is the place you already know; the floor is the one that needs saying.
	#
	# `Run.level` is correct HERE because both callers move the run before they
	# call this -- `Run.enter()` resets to 1 and `Run.descend_floor()` increments
	# -- which is also why the card can be built once and never updated.
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
	# There are exactly four ways through this function -- into the dungeon, down
	# a floor, home with the fee paid, home in a box -- and all four are moments
	# the player would be furious to replay. A rule with no exceptions also
	# cannot be forgotten by the fifth caller.
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
func _raise_card() -> void:
	_drop_card()
	_card = LoadingCard.open(_layer, Prog.NAME, Prog.label(Run.level))


func _drop_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
