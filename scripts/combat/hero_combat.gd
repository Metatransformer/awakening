class_name HeroCombat
extends Node3D
## The hero's sword, shield, and held item — the models, the swing, and the box
## that actually hurts things.
##
## Added as a child of the Hero by hero.gd. It keeps combat out of the movement
## script while still driving the hero's states, because the two genuinely are
## coupled: you cannot steer freely mid-swing, and that commitment is most of
## what makes a swing feel like it weighs something.
##
## Sockets are BoneAttachment3D on the real rig bones. The offsets below were
## found by RENDERING, not by arithmetic: the rig's rest pose is expressed in a
## rotated FBX space, so the bone matrices read as nonsense if you try to reason
## from them. tools/directors/p4_combat.gd is what settled each number.
##
## Note the scale compensation in `_mount`. The Model node is scaled by
## K.HERO_SCALE (1.65) to lift a 1.0-unit rig to adult height, and anything
## parented under a bone inherits that. A 0.92 m sword would otherwise render at
## 1.52 m — a greatsword — which is exactly the kind of error that looks like an
## art problem and is really a transform problem.

## What the player asked for. Deliberately coarser than Hero.Swing: the player
## presses one of two buttons, and WHICH light swing that becomes — step 1, 2, 3
## or the lunge — is this script's decision, made from the chain state and the
## lock. Buffering an Intent rather than a Swing is what lets a press made during
## step 1 still become step 2 when it is finally honoured.
enum Intent { LIGHT, HEAVY }

## Pitch multiplier per chain step. Two rises, three drops — the chain should
## sound like it is going somewhere, and the finisher is the heaviest thing in
## it. Cheapest honest way to make three swings read as one sentence.
const _CHAIN_PITCH: Array[float] = [1.0, 1.08, 0.86]

@export_group("Loadout")
@export var sword_id: String = "sword_knightly"
@export var shield_id: String = "shield_noble"
@export var bow_id: String = "bow_knightly"
@export var hookshot_id: String = "hookshot_pistol"

@export_group("Sword")
## Quarter-hearts per slash. K.HEART == 4, so this is half a heart.
@export var damage: int = 2 * K.QUARTER
## Seconds the whole swing owns the hero. The clips are 1.4-2.4 s, far too slow
## for OOT, so they are time-scaled onto this.
@export var swing_time: float = 0.46
## The slice of the swing during which the blade can hurt something, as
## fractions of swing_time. Before it is the wind-up, after it is the recovery.
@export var damage_window := Vector2(0.22, 0.62)
## Reach from the hero's centre, metres. The blade is 0.92 m and the arm adds.
@export var reach: float = 1.35
@export var arc_degrees: float = 130.0
@export var knockback: float = K.KNOCKBACK_LIGHT

@export_group("Heavy")
## Over a full heart, against the light swing's half. The heavy is worth the
## commitment or nobody presses it twice.
@export var heavy_damage: int = 5 * K.QUARTER
## Nearly twice the light swing. This number IS the cost — the whole trade is
## that you are unsteerable and unable to guard for this long. [tune]
@export var heavy_swing_time: float = 0.80
## Lives later in the swing than the light one and stays live for less of it:
## the extra time is spent in the wind-up, where the tell is, not in the blade.
@export var heavy_damage_window := Vector2(0.46, 0.74)
@export var heavy_knockback: float = K.KNOCKBACK_HEAVY

@export_group("Combo")
## Seconds after a swing ends during which another press continues the chain
## instead of starting a new one. Short enough that you cannot wander off and
## come back to a finisher; long enough that the chain is not a rhythm test.
@export var chain_window: float = 0.34
## Fraction of the current swing after which a press is REMEMBERED rather than
## dropped. Before it, an input is the player mashing; after it, they have seen
## the swing and are asking for the next one. This buffer is the whole difference
## between a chain that obeys you and one that eats inputs made a frame early.
@export var chain_buffer_from: float = 0.35
## Multipliers on swing_time for steps 2 and 3. Two is faster than one — a chain
## should accelerate — and three is much slower, because it is the one that
## hurts AND because its clip is a 2.4 s leaping overhead: at step two's pace the
## whole slam would go past in a third of a second and read as a twitch.
@export var chain_time_scale := Vector2(0.92, 1.65)
## Extra quarter-hearts on the finisher, and the shove it delivers. The payoff
## for landing three in a row instead of backing off after one.
@export var chain_finisher_bonus: int = 2 * K.QUARTER
@export var chain_finisher_knockback: float = K.KNOCKBACK_HEAVY

@export_group("Lunge")
## Between the light swing and the heavy. It is not the biggest blow in the kit;
## what it buys is the distance, and paying twice for that would make Z-targeting
## strictly better than standing your ground.
@export var lunge_damage: int = 4 * K.QUARTER
@export var lunge_swing_time: float = 0.78
## Opens after the drive ends (see lunge_drive_time), so the blade lands at the
## end of the leap rather than sweeping everything along the way.
@export var lunge_damage_window := Vector2(0.46, 0.72)
@export var lunge_knockback: float = K.KNOCKBACK_HEAVY
## Seconds of forward drive. See Hero.request_lunge for what it becomes.
@export var lunge_drive_time: float = 0.24
## Upward metres/sec at the leap. Deliberately small — the CLIP already leaps
## (ss_attack_01 lifts the mesh clean out of frame), so this only has to stop
## the body sliding along the floor under an airborne pose. Adding a real jump
## on top of a baked one gets you a hero who exits the top of the screen.
@export var lunge_hop: float = 1.8
## The band of distances the leap is offered at. Past the far edge it is a long
## unpunishable approach; inside the near edge there is no gap to close and it
## reads as the hero hopping on the spot.
@export var lunge_min_range: float = 1.9
@export var lunge_max_range: float = 6.0
## Half-angle, degrees, between the stick and the target. The lunge is the
## attack you press while asking to GO there; pressing attack while strafing is
## still a standing swing.
@export var lunge_stick_cone: float = 60.0

@export_group("Shield")
## Half-angle of the block cone, degrees. A blow from outside it is not blocked.
@export var block_cone: float = 70.0

@export_group("Audio")
@export var sfx_swing: AudioStream = preload("res://audio/sfx/swing.ogg")
@export var sfx_impact: AudioStream = preload("res://audio/sfx/weapon_impact_sword_1.ogg")
@export var sfx_block: AudioStream = preload("res://audio/sfx/block.ogg")

## True while the swing is inside its damage window.
var swinging: bool = false
var blocking: bool = false

## Which item is in the hero's hands right now, or &"" for sword and shield.
var equipped: StringName = &""

var _hero: Hero
var _skel: Skeleton3D
## The mounted models. Public so a director can sweep their placement.
var sword: Node3D
var shield: Node3D
var bow: Node3D
var hookshot: Node3D
## id -> {"hand": Node3D, "stow": Node3D}. Exactly one of the pair is visible.
var _items: Dictionary = {}
var _hitbox: Area3D
var _swing_t: float = -1.0
## The numbers of the swing currently in flight, captured when it starts. A
## swing has to finish on the terms it began on — reading the exports live would
## mean a heavy that landed while `equipped` changed could pay out light damage.
var _swing_dur: float = 0.0
var _swing_window := Vector2.ZERO
var _swing_damage: int = 0
var _swing_knock: float = 0.0
var _swing_hitstop: int = K.HITSTOP_LIGHT
## Which light comes next: 0, 1, 2. Reset when `_chain_timer` runs out.
var _chain_step: int = 0
var _chain_timer: float = 0.0
## An Intent pressed mid-swing and owed to the player, or -1.
var _buffer: int = -1
var _hit_this_swing: Dictionary = {}
var _swing_player: AudioStreamPlayer3D
var _impact_player: AudioStreamPlayer3D


func _ready() -> void:
	_hero = get_parent() as Hero
	if _hero == null:
		push_error("HeroCombat must be a child of the Hero")
		return
	_skel = _hero.skeleton()
	if _skel == null:
		push_error("HeroCombat: no Skeleton3D on the rig")
		return
	# Sharpening is bought in town and has to survive the scene change, so the
	# permanent part lives on Game and the export is only the base blade.
	damage += Game.sword_bonus
	# Sharpening is sharpening. A whetstone that only improved the light swing
	# would quietly make the heavy the worse button the more you spent in town.
	heavy_damage += Game.sword_bonus
	_mount_loadout()
	_build_hitbox()
	_build_audio()

	Bus.loadout_changed.connect(_on_loadout_changed)
	# Finding a bow has to put it on his back the same moment the chest opens,
	# not the next time a hand changes. See the ownership gate in _show_equipped.
	Bus.item_acquired.connect(func(_id: StringName) -> void: _show_equipped())
	# Adopt whatever Game already holds. A hero spawned into a fresh dungeon
	# after an extraction must come up wearing the set the player left with,
	# and waiting for the next button press to sync would arm him wrongly for
	# the first room.
	_on_loadout_changed(Game.loadout_set,
		Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_LEFT))


# --- Loadout ----------------------------------------------------------------

func _mount_loadout() -> void:
	# Right hand holds the sword. Mixamo's hand bone runs along the fingers, so
	# the blade is rolled onto that axis and pitched forward to clear the wrist.
	# Right hand holds the sword. The z=-90 is the roll that stands the blade up
	# out of the fist; without it the blade lies over at 45 degrees and the whole
	# pose reads off-kilter even though the grip is in exactly the right place.
	sword = _mount(sword_id, &"mixamorig_RightHand",
		Vector3(0.0, 0.04, 0.02), Vector3(-96.0, 6.0, -90.0))
	# The shield rides the left forearm, not the hand — that is how it sits in
	# the block clips, and hanging it off the hand makes it swing like a paddle.
	# Its origin is the CENTRE of the disc, so it needs pushing off the arm.
	#
	# TWO axes were wrong, which is why the first fix only half worked.
	#   y=180 decides which face meets the blow. At 0 the hero presents the
	#         wooden inner face and its arm straps to the enemy.
	#   z=-90 decides which way the kite point hangs. At 0 the shield lies on its
	#         side with the point sticking out sideways -- the "off kilter" read.
	#         At +90 it stands up but INVERTED, point at the sky. -90 is the one
	#         that hangs the point at the hero's knee, where it belongs.
	# tools/directors/shield_lookdev.gd renders the roll candidates side by side.
	shield = _mount(shield_id, &"mixamorig_LeftForeArm",
		Vector3(0.10, 0.02, 0.0), Vector3(0.0, 180.0, -90.0))

	# The hookshot and the bow each get TWO mounts: one in the hand for when
	# they are equipped, one stowed on the body for when they are not. Carrying
	# the gear visibly is most of what makes a character read as an adventurer
	# rather than a man who happens to be holding a sword, and it means the item
	# buttons have something to animate between instead of a pop-in.
	_mount_item(&"hookshot", hookshot_id,
		&"mixamorig_RightHand", Vector3(0.0, 0.05, 0.02), Vector3(-96.0, 6.0, 0.0),
		&"mixamorig_Hips", Vector3(-0.16, 0.02, 0.10), Vector3(0.0, 0.0, -90.0))
	_mount_item(&"bow", bow_id,
		&"mixamorig_LeftHand", Vector3(0.0, 0.04, 0.0), Vector3(-96.0, 0.0, 90.0),
		&"mixamorig_Spine2", Vector3(0.0, 0.06, -0.16), Vector3(0.0, 0.0, 28.0))
	hookshot = _items[&"hookshot"]["hand"]
	bow = _items[&"bow"]["hand"]
	_show_equipped()


## Both mounts for one swappable item. Two model instances rather than one that
## gets reparented: reparenting a node out from under a BoneAttachment3D mid-
## frame leaves it at a stale transform for a frame, which reads as the bow
## teleporting through the hero's chest every time you press the button.
func _mount_item(id: StringName, model_id: String,
		hand_bone: StringName, hand_pos: Vector3, hand_rot: Vector3,
		stow_bone: StringName, stow_pos: Vector3, stow_rot: Vector3) -> void:
	_items[id] = {
		"hand": _mount(model_id, hand_bone, hand_pos, hand_rot),
		"stow": _mount(model_id, stow_bone, stow_pos, stow_rot),
	}


## Put `id` in the hero's RIGHT hand, or pass &"" for the empty hand.
##
## Kept as the low-level "show this model" call. The armament decision lives on
## Game so it survives the scene change that extracting causes; this only makes
## the rig agree with it.
func equip(id: StringName) -> void:
	equipped = id
	_show_equipped()


## Mirror Game's live loadout onto the rig.
func _on_loadout_changed(_set_index: int, right: StringName, left: StringName) -> void:
	# A set may name gear the player has not found: the alternate set defaults
	# to bow and arrows on a brand new game, which is the point -- the slot is
	# reserved, the bow is not owned yet. Falling back to the sword means dpad-up
	# on an unfilled set leaves you armed rather than holding an invisible bow
	# that also refuses to swing (see the `equipped != &""` gate in _try_swing).
	# The equipment screen is where "(not owned)" gets said out loud.
	var held := right if Game.armament_owned(right) else &"sword"
	var off := left if Game.armament_owned(left) else &""
	# The right hand is the one that swings, so it drives `equipped` -- which is
	# what _try_swing and the HUD both read. &"sword" IS the empty-item state
	# here for historical reasons: `equipped == &""` has always meant "sword and
	# shield", and every caller of it predates the loadout.
	equip(&"" if held == &"sword" else held)
	_show_left(off)


func _show_equipped() -> void:
	for id: StringName in _items:
		var pair: Dictionary = _items[id]
		var in_hand := id == equipped
		if pair["hand"] != null:
			(pair["hand"] as Node3D).visible = in_hand
		if pair["stow"] != null:
			# Stowed, but only if he actually has one. Both mounts are built at
			# _ready because BoneAttachment3D is not something to be creating
			# mid-run, so without this gate the hero starts the game wearing a
			# bow and a hookshot he has never found -- and the ownership check
			# in Game.cycle_armament then refuses to equip the bow the player
			# can plainly see on his own back.
			(pair["stow"] as Node3D).visible = not in_hand and Game.has(id)
	# You cannot hold a bow and a sword.
	if sword != null:
		sword.visible = equipped == &""


## The left hand. Only the shield has a model, so anything else empties the arm
## rather than mounting a placeholder -- an untextured cube on the forearm reads
## as a bug, and "arrows" is a count on the HUD, not a thing you hold up.
func _show_left(left: StringName) -> void:
	if shield != null:
		# The bow is mounted on the LEFT hand (that is where a bow is held) while
		# the shield rides the left forearm, so drawing the bow out of the primary
		# set used to leave both on the same arm -- a kite shield growing out of a
		# bowstring. You cannot draw a bow with a shield strapped to the hand that
		# holds it, so the shield comes off for as long as the bow is out.
		shield.visible = left == &"shield" and equipped != &"bow"


## Attach a weapon model to `bone`, undoing the rig's scale so the model keeps
## the true size WeaponModels gave it.
func _mount(id: String, bone: StringName, offset: Vector3, rot_deg: Vector3) -> Node3D:
	var idx := _skel.find_bone(bone)
	if idx < 0:
		push_error("HeroCombat: no bone '%s' on the rig" % bone)
		return null

	var socket := BoneAttachment3D.new()
	socket.name = "Socket_" + String(bone)
	socket.bone_name = String(bone)
	socket.bone_idx = idx
	_skel.add_child(socket)

	var model := WeaponModels.make(id)
	if model == null:
		return null

	var holder := Node3D.new()
	holder.name = id
	holder.position = offset
	holder.rotation_degrees = rot_deg
	# Measure the accumulated scale rather than assuming K.HERO_SCALE: the rig
	# may carry its own import scale on top of the Model node's.
	var world_scale := socket.global_transform.basis.get_scale()
	var s := (world_scale.x + world_scale.y + world_scale.z) / 3.0
	if s > 0.0001:
		holder.scale = Vector3.ONE / s
	holder.add_child(model)
	socket.add_child(holder)
	return holder


# --- Hitbox -----------------------------------------------------------------

func _build_hitbox() -> void:
	_hitbox = Area3D.new()
	_hitbox.name = "SwordHitbox"
	_hitbox.add_to_group(&"hitbox")
	_hitbox.collision_layer = K.L_PLAYER_HITBOX
	# Enemies AND the world's interactables, so a training post registers before
	# a single enemy exists.
	_hitbox.collision_mask = K.L_ENEMY | K.L_INTERACT
	_hitbox.monitoring = false
	_hitbox.monitorable = false

	var shape := CollisionShape3D.new()
	var box := SphereShape3D.new()
	box.radius = reach * 0.62
	shape.shape = box
	# Sat out in front of the hero at chest height: a sphere on the origin would
	# hit things behind him, which is how a clone ends up with a sword that
	# damages what it visibly missed.
	shape.position = Vector3(0.0, 1.0, -reach * 0.55)
	_hitbox.add_child(shape)
	add_child(_hitbox)


func _build_audio() -> void:
	_swing_player = AudioStreamPlayer3D.new()
	_swing_player.stream = sfx_swing
	_swing_player.bus = &"SFX"
	_swing_player.unit_size = 5.0
	add_child(_swing_player)

	_impact_player = AudioStreamPlayer3D.new()
	_impact_player.stream = sfx_impact
	_impact_player.bus = &"SFX"
	_impact_player.unit_size = 6.0
	add_child(_impact_player)


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _hero == null:
		return

	# A shop or a fade owns the buttons while it is up. The swing already in
	# flight still finishes below -- cancelling it would leave the hitbox on.
	#
	# The charm's channel locks the same buttons: swapping your loadout halfway
	# out of the dungeon is not a thing that should typecheck. The SHIELD is the
	# exception and is handled below -- guarding through the channel is the one
	# defence he has left while rooted.
	var locked := Prompt != null and Prompt.blocked
	var leaving := _hero.charm != null and _hero.charm.active()

	# The shield is held, not toggled, and it drops the moment you commit to a
	# swing — you cannot hide behind it and attack out of it.
	var want_block := not locked and Input.is_action_pressed(&"shield") and _swing_t < 0.0
	if want_block != blocking:
		blocking = want_block
		_hero.set_blocking(blocking)

	if not locked and not leaving:
		# The D-pad is the C-pad. ←, ↑ and → each draw whatever the player bound
		# to them (and put it away on a second press); ↓ swaps the whole set.
		#
		# Binding lives in the menu and nowhere else: a button that CYCLES is a
		# button you have to watch to use, and the point of a bound item is that
		# you can reach for it without looking. Game owns what is bound and what
		# is in which hand; this only presses the buttons.
		if Input.is_action_just_pressed(&"item_left"):
			Game.use_quick(Game.QUICK_LEFT)
		if Input.is_action_just_pressed(&"item_up"):
			Game.use_quick(Game.QUICK_UP)
		if Input.is_action_just_pressed(&"item_right"):
			Game.use_quick(Game.QUICK_RIGHT)
		if Input.is_action_just_pressed(&"item_down"):
			Game.swap_loadout()
		# Heavy first: if a frame somehow carries both edges, the button that
		# costs more to press is the one the player meant.
		if Input.is_action_just_pressed(&"heavy_attack"):
			_press(Intent.HEAVY)
		elif Input.is_action_just_pressed(&"attack"):
			_press(Intent.LIGHT)

	# The chain window is the gap BETWEEN swings, so it only runs while nothing is
	# swinging. Ticking it through the swing was the first version, and it made
	# the chain silently impossible: the window (0.34 s) is shorter than the swing
	# it was started by (0.46 s), so `_chain_step` reset before the swing that set
	# it had even finished and every press came out as step one.
	#
	# Ticked outside the `locked` gate on purpose: a shop that opens mid-chain
	# should let the chain lapse, not freeze the player one press from a finisher.
	if _swing_t < 0.0 and _chain_timer > 0.0:
		_chain_timer = maxf(_chain_timer - delta, 0.0)
		if _chain_timer == 0.0:
			_chain_step = 0

	# Pay out a press made during the recovery — but only on a frame AFTER the
	# swing ended, never on the boundary frame itself. The hero clears
	# MoveState.ATTACK in his own _physics_process, and the swing clock runs one
	# frame ahead of his: this node is his CHILD, so on the frame a swing starts
	# the hero has already ticked and the swing has not. Firing the buffer at the
	# end of _advance_swing therefore asked a hero who was still mid-attack, he
	# refused, and the press vanished — the chain could not reach step two at all.
	#
	# Consumed before _begin runs, so a swing that gets refused for a real reason
	# does not leave the press owed forever.
	if _swing_t < 0.0 and _buffer >= 0:
		var queued := _buffer
		_buffer = -1
		_begin(queued)

	if _swing_t >= 0.0:
		_advance_swing(delta)


## A press of one of the two attack buttons. Mid-swing it is remembered rather
## than dropped — but only in the back half of the swing, because a press on the
## first frame is the player mashing, not the player asking for the next step.
func _press(intent: int) -> void:
	if _swing_t >= 0.0:
		if _swing_t / maxf(_swing_dur, 0.01) >= chain_buffer_from:
			_buffer = intent
		return
	_begin(intent)


## Turn an Intent into an actual swing. Everything that decides WHICH swing —
## the lock, the chain position, whether an item is in the hand — lives here, so
## the buffered path and the live path cannot drift apart.
func _begin(intent: int) -> void:
	# The sword is stowed while an item is out, so a swing here would deal damage
	# with an invisible blade. What the attack button does instead is USE the
	# item -- the bow shoots, the hookshot fires. That is what the button means
	# in the source material, and for a long time this line simply ate the press,
	# which made every bound item a thing you could draw and then not use.
	#
	# The heavy button is deliberately not a second way to shoot: there is no
	# heavy arrow, and mapping it to the same shot would make the two buttons
	# lie about being different.
	if equipped != &"":
		if intent == Intent.LIGHT and _hero.ranged != null:
			_hero.ranged.fire(equipped)
		return

	if intent == Intent.HEAVY:
		_heavy_swing()
		return
	# The lunge gets first refusal on a light press: it is the same button, and
	# what distinguishes it is the lock plus a stick pushed at what you locked.
	if _lunge_swing():
		return
	_light_swing(_chain_step)


func _heavy_swing() -> void:
	if not _hero.request_attack(heavy_swing_time, Hero.Swing.HEAVY):
		return
	# A heavy ENDS the chain rather than counting as a step in it. It is the
	# other button; letting it slot into the light chain would make the finisher
	# something you reach by pressing whatever, which is not a combo.
	_chain_step = 0
	_chain_timer = 0.0
	# Pitched down, the cheapest honest way to make the swings sound like
	# different amounts of effort.
	_commit(heavy_swing_time, heavy_damage_window, heavy_damage, heavy_knockback,
		K.HITSTOP_HEAVY, randf_range(0.68, 0.78))


func _light_swing(step: int) -> void:
	var variant := Hero.Swing.LIGHT1
	var dur := swing_time
	var dmg := damage
	var knock := knockback
	var hitstop := K.HITSTOP_LIGHT
	match step:
		1:
			variant = Hero.Swing.LIGHT2
			dur = swing_time * chain_time_scale.x
		2:
			variant = Hero.Swing.LIGHT3
			dur = swing_time * chain_time_scale.y
			dmg += chain_finisher_bonus
			knock = chain_finisher_knockback
			hitstop = K.HITSTOP_HEAVY
	# Only commit the swing's numbers once the hero has agreed to swing — he
	# refuses while rolling or turning, and a half-armed swing left behind by a
	# refusal would pay out on whatever landed next.
	if not _hero.request_attack(dur, variant):
		return
	# Wraps back to 0 after the finisher: the chain is a loop, not a staircase
	# you fall off the end of.
	_chain_step = (step + 1) % 3
	_chain_timer = chain_window
	_commit(dur, damage_window, dmg, knock, hitstop,
		randf_range(0.94, 1.07) * _CHAIN_PITCH[step])


## The Z-targeted leap. Returns false — having done nothing — the moment any of
## its conditions fail, so the caller falls straight through to a normal swing.
func _lunge_swing() -> bool:
	var target := _hero.lock_target()
	if target == null:
		return false
	# Only from a standing start. Ending a chain with a leap would let a mashed
	# combo travel the whole room, which is the opposite of what committing to a
	# chain is meant to cost.
	if _chain_step != 0:
		return false

	# Flattened by hand rather than with K.flat, which NORMALISES: a range gate
	# reading distance off K.flat sees every target in the world as exactly 1 m
	# away, which puts them all inside the band and none of them outside it.
	var delta := target.global_position - _hero.global_position
	var to := Vector3(delta.x, 0.0, delta.z)
	var dist := to.length()
	if dist < lunge_min_range or dist > lunge_max_range:
		return false

	var wish := _hero.wish_dir()
	if wish.length() < 0.5 or rad_to_deg(wish.angle_to(to)) > lunge_stick_cone:
		return false

	if not _hero.request_lunge(lunge_swing_time, lunge_drive_time, lunge_hop):
		return false
	_chain_timer = 0.0
	_commit(lunge_swing_time, lunge_damage_window, lunge_damage, lunge_knockback,
		K.HITSTOP_HEAVY, randf_range(0.80, 0.88))
	return true


## Arm the swing the hero has just agreed to. Called only after a successful
## request_*, so the numbers in flight always describe a swing that is happening.
func _commit(dur: float, window: Vector2, dmg: int, knock: float,
		hitstop: int, pitch: float) -> void:
	_swing_dur = dur
	_swing_window = window
	_swing_damage = dmg
	_swing_knock = knock
	_swing_hitstop = hitstop
	_swing_t = 0.0
	_hit_this_swing.clear()
	_swing_player.pitch_scale = pitch
	_swing_player.play()


func _advance_swing(delta: float) -> void:
	_swing_t += delta
	var frac := _swing_t / maxf(_swing_dur, 0.01)

	var live := frac >= _swing_window.x and frac <= _swing_window.y
	if live != swinging:
		swinging = live
		_hitbox.monitoring = live
	if live:
		_scan()

	if frac >= 1.0:
		_swing_t = -1.0
		swinging = false
		_hitbox.monitoring = false


## Damage anything overlapping, once per swing, and only if it is actually in
## front of the hero. The sphere is generous on purpose so a near-miss connects;
## the arc test is what stops it becoming an omnidirectional aura.
func _scan() -> void:
	for body in _hitbox.get_overlapping_bodies():
		_maybe_hit(body)
	for area in _hitbox.get_overlapping_areas():
		_maybe_hit(area)


func _maybe_hit(node: Node) -> void:
	if node == null or node == _hero or _hero.is_ancestor_of(node):
		return
	var id := node.get_instance_id()
	if _hit_this_swing.has(id):
		return

	var target := node as Node3D
	if target == null:
		return
	var to := K.flat(target.global_position - _hero.global_position)
	if to != Vector3.ZERO:
		var fwd := -_hero.global_transform.basis.z
		if rad_to_deg(fwd.angle_to(to)) > arc_degrees * 0.5:
			return

	var victim := _damageable(target)
	if victim == null:
		return

	_hit_this_swing[id] = true
	var hit := Hit.make(_swing_damage, _hero.global_position, &"sword", _swing_knock)
	var landed = victim.apply_hit(hit)
	# apply_hit returns bool on a HealthComponent and null on the duck-typed
	# props that predate it, so absence of a false is treated as a landed blow.
	if landed == false:
		return

	_impact_player.pitch_scale = randf_range(0.92, 1.08)
	_impact_player.play()
	Bus.request_hitstop.emit(_swing_hitstop)


## Find whatever on or under `node` answers the damage contract. Props built
## before HealthComponent existed implement apply_hit directly, and the training
## posts are exactly that case.
func _damageable(node: Node) -> Node:
	if node.has_method(&"apply_hit"):
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null


# --- Queries for other packages ---------------------------------------------

## Would a blow arriving from `from_pos` be stopped by the raised shield?
## The cone is generous but strictly frontal — OOT does not let you block your
## own back, and being punished for turning away is the point of the shield.
func blocks(from_pos: Vector3) -> bool:
	if not blocking or _hero == null:
		return false
	var to := K.flat(from_pos - _hero.global_position)
	if to == Vector3.ZERO:
		return false
	var fwd := -_hero.global_transform.basis.z
	return rad_to_deg(fwd.angle_to(to)) <= block_cone


## Play the clang and tell the world. The blocker calls this so a blocked blow
## reads differently from one that never arrived.
func on_blocked(at: Vector3, normal: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = sfx_block
	p.bus = &"SFX"
	p.unit_size = 6.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	Bus.shield_blocked.emit(at, normal)
