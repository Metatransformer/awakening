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

## What the player asked for. Deliberately coarser than Hero.Swing: WHICH light
## swing a LIGHT becomes — step 1, 2 or 3 — is this script's decision, made from
## the chain state. Buffering an Intent rather than a Swing is what lets a press
## made during step 1 still become step 2 when it is finally honoured.
##
## HEAVY is no longer a button. It is what the attack button's HOLD releases
## into, LUNGE is the use button under a lock, and DASH is the attack button
## pressed from behind a raised shield. They stay Intents because the buffer is
## the thing that makes them feel honest: a charge released during the light
## swing that started it has to come out when that swing ends, not vanish.
enum Intent { LIGHT, HEAVY, LUNGE, DASH }

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
## Seconds the attack button must be HELD before the release becomes a heavy.
## Under it, the release is nothing — the swing the press already started is all
## you get, which is what makes a tap a tap.
##
## 0.42 is deliberately longer than the light swing it overlaps (0.46 is close
## enough that the charge finishes as the swing does): the point is that you can
## start winding up during the swing you just threw, so a charge costs you the
## recovery you were spending anyway rather than a separate standing-still beat.
@export var charge_time: float = 0.42
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

@export_group("Dash")
## The stab out from behind the shield — OOT's R+B. It is not a better light
## swing and it is not a heavy: what it buys is that it CLOSES, and it is the
## only attack in the kit that closes without a lock. Priced between the two.
@export var dash_damage: int = 3 * K.QUARTER
## Longer than a light (0.46) and shorter than a heavy (0.80). The commitment is
## most of the cost, because the drive has already thrown the hero somewhere he
## did not have to be.
@export var dash_swing_time: float = 0.62
## Opens after the drive has ended (see dash_drive_time), so the point lands at
## the END of the lunge. Live earlier and the thrust sweeps through everything it
## travelled past, which is a spin attack wearing a thrust's clip.
@export var dash_damage_window := Vector2(0.34, 0.60)
## A thrust does not launch. Shoving the enemy away is also self-defeating here —
## the whole move was about closing the gap that the knockback would reopen.
@export var dash_knockback: float = K.KNOCKBACK_LIGHT
## Seconds of forward drive, and how fast. 0.20 s at 8.0 m/s is 1.6 m of closing:
## about one enemy's width, which is the gap a guarded player actually stands
## off at. Fast enough to read as an explosion out of the guard rather than a
## walk. [tune]
@export var dash_drive_time: float = 0.20
@export var dash_speed: float = 8.0

@export_group("Shield")
## Half-angle of the block cone, degrees. A blow from outside it is not blocked.
@export var block_cone: float = 70.0

@export_group("Audio")
@export var sfx_swing: AudioStream = preload("res://audio/sfx/swing.ogg")
@export var sfx_impact: AudioStream = preload("res://audio/sfx/weapon_impact_sword_1.ogg")
@export var sfx_block: AudioStream = preload("res://audio/sfx/block.ogg")
## The moment the charge is ready. A hold with no tell is a hold the player
## cannot learn: without this the only way to find `charge_time` is to release
## repeatedly and count. Paired with the blade glow in `_set_charged`.
@export var sfx_charged: AudioStream = preload(
	"res://audio/sfx/weapon_full_charge_voice_male_1.ogg")

## True while the swing is inside its damage window.
var swinging: bool = false
var blocking: bool = false
## True once the attack button has been held past `charge_time`. Public so the
## HUD and a director can both see the wind-up without timing it themselves.
var charged: bool = false

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
## Seconds the attack button has been held, or -1.0 when it is not down. The
## sentinel matters: 0.0 is a legitimate reading on the frame of the press.
var _charge_t: float = -1.0
## The blade's glow while the charge is ready. Built once in _build_charge_glow
## rather than made and freed per charge — a light spawned mid-frame under a
## BoneAttachment3D shows up at the origin for one frame, which reads as a flash
## at the hero's feet.
var _charge_glow: OmniLight3D
var _swing_player: AudioStreamPlayer3D
var _impact_player: AudioStreamPlayer3D
var _charge_player: AudioStreamPlayer3D


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
	damage += Game.sword_bonus()
	# Sharpening is sharpening. A whetstone that only improved the light swing
	# would quietly make the heavy the worse button the more you spent in town.
	heavy_damage += Game.sword_bonus()
	# The shield's ladder widens the arc it covers (K.GUARD_ARC). Read as a
	# DELTA off the export rather than assigned, so the export stays what it
	# says it is -- the bare kite shield -- and a director that hands this node a
	# different base shield still gets the player's forge work on top of it.
	block_cone += Game.guard_arc() - K.GUARD_ARC[0]
	_mount_loadout()
	_build_hitbox()
	_build_audio()
	_build_charge_glow()

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
	# The hookshot's three numbers were all wrong, and each one was wrong in a way
	# only tools/directors/hookshot_grip.gd could show:
	#
	#   z=90  is the roll. At 0 the pistol lay flat on its side in his palm — the
	#         same class of error as the shield's, and the same fix the sword's
	#         z=-90 makes. It rolls the OTHER way to the sword because the mesh
	#         hangs off one side of its own origin: -90 swings the whole body up
	#         above his fist, +90 drops it through the fingers where a grip goes.
	#   x=-66 is the pitch. At -96 the barrel sat 27 degrees off his facing, so
	#         the thing visibly pointed across his body while the chain flew
	#         straight ahead. -66 brings that to under 3.
	#   pos   seats it. Rolling about the barrel moved the body clean out of his
	#         hand, and +0.07 on x with +0.03 on y is what puts it back through
	#         the fist rather than floating beside it.
	_mount_item(&"hookshot", hookshot_id,
		&"mixamorig_RightHand", Vector3(0.07, 0.08, 0.02), Vector3(-66.0, 6.0, 90.0),
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

	_charge_player = AudioStreamPlayer3D.new()
	_charge_player.stream = sfx_charged
	_charge_player.bus = &"SFX"
	_charge_player.unit_size = 6.0
	add_child(_charge_player)


## A cold light on the blade for as long as the charge is held.
##
## The ping says the wind-up became ready; this says it still IS. Half this game
## is a room lit by two sconces with a hero-shaped silhouette in between, and a
## charge state you can only hear is a charge state the player loses track of
## every time they get hit.
##
## Parented to the sword's holder, so it inherits `sword.visible` for free —
## drawing the bow puts the blade away and takes its glow with it.
func _build_charge_glow() -> void:
	if sword == null:
		return
	_charge_glow = OmniLight3D.new()
	_charge_glow.name = "ChargeGlow"
	_charge_glow.light_color = Color(0.66, 0.88, 1.0)
	_charge_glow.light_energy = 2.4
	_charge_glow.omni_range = 1.6
	_charge_glow.shadow_enabled = false
	# 0.6 m up the blade. The holder's origin is the POMMEL and the blade runs
	# along +Y (weapon_models.gd §sword); a light left at the origin lights his
	# fist and the sword reads as unlit.
	_charge_glow.position = Vector3(0.0, 0.6, 0.0)
	_charge_glow.visible = false
	sword.add_child(_charge_glow)


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

	# The shield is held, not toggled, and it drops the moment you commit to
	# anything else — you cannot hide behind it and attack out of it, and you
	# cannot hold a shield up through a dive roll.
	#
	# The roll clause is not cosmetic even though it looks it. `Block` is a
	# BLEND sitting above the roll one-shot in the animation tree, so a guard
	# held at amount 1.0 does not layer over the dive, it REPLACES it — the hero
	# slid backwards across the floor in a standing block pose. It also makes the
	# roll's recovery honestly vulnerable, which is what the recovery is for.
	# The button is still down, so the guard comes straight back up on landing.
	var rolling := _hero.state == Hero.MoveState.ROLL \
		or _hero.state == Hero.MoveState.ROLL_RECOVER
	var want_block := not locked and not rolling \
		and Input.is_action_pressed(&"shield") and _swing_t < 0.0
	if want_block != blocking:
		blocking = want_block
		_hero.set_blocking(blocking)
		# The camera needs to know: guarding pins the hero's facing to the lens
		# (Hero._tick_camera_facing), and autoswing pins the lens to behind the
		# hero. Left running, the two chase each other and a guarded strafe
		# slowly rotates the player 30-odd degrees off what he was watching.
		Bus.guard_changed.emit(blocking)

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
		# The use button: fire what is drawn, or leap at what is locked.
		if Input.is_action_just_pressed(&"use_item"):
			_press(Intent.LUNGE)
		_tick_attack_button(delta)
	else:
		# A shop opening mid-wind-up must not leave the charge armed behind the
		# panel, waiting to come out at whatever is standing there when the
		# player closes it again.
		_release_charge(false)

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


## The attack button. A tap is the light chain; a hold is the wind-up; the
## release is the heavy.
##
## The light swing comes out on the PRESS, never on the release, and that
## ordering is the whole feel of it. A button that waits to see whether you
## meant a tap puts `charge_time` of latency on every ordinary swing — which is
## the most common way a charge attack ruins the light attack it was bolted to.
## OOT does exactly this: B swings, and CONTINUING to hold B after the swing is
## what winds up the spin. So the hold costs the recovery you were spending
## anyway, and a mashed chain never charges anything.
func _tick_attack_button(delta: float) -> void:
	if Input.is_action_just_pressed(&"attack"):
		# Shield up, sword out: the press is the DASH ATTACK, not a light swing.
		# This is OOT's R+B and it is the shield's other half — the guard has
		# always been a way of standing still, and the stab is how you come off
		# it. A guarded player who presses attack is not asking for the ordinary
		# swing he could have thrown from anywhere.
		#
		# No charge is armed on this path, deliberately. The wind-up is a HOLD,
		# and a hold made from behind a shield is a hold whose release would come
		# out as a heavy long after the guard dropped for the dash it already
		# threw. One press, one move.
		if blocking and equipped == &"":
			_press(Intent.DASH)
			return
		_charge_t = 0.0
		_press(Intent.LIGHT)
		return
	if Input.is_action_just_released(&"attack"):
		_release_charge(charged)
		return
	if _charge_t < 0.0:
		return
	# Drawing an item mid-hold drops the wind-up. The press that STARTED this
	# hold already stowed whatever was in his hands and swung (see _begin), so
	# the only way to be here with an item out is a D-pad press made during the
	# hold — and paying that out as a heavy on release would be a swing with an
	# invisible sword, which is the bug the `equipped` gate in _begin exists for.
	if equipped != &"":
		_release_charge(false)
		return
	_charge_t += delta
	if not charged and _charge_t >= charge_time:
		_set_charged(true)


## Let go of the wind-up, swinging it if `fire`. Safe to call on a frame where
## nothing was being held, which is why the shop gate can call it blindly.
func _release_charge(fire: bool) -> void:
	if fire:
		_press(Intent.HEAVY)
	_charge_t = -1.0
	_set_charged(false)


func _set_charged(on: bool) -> void:
	if charged == on:
		return
	charged = on
	if _charge_glow != null:
		_charge_glow.visible = on
	if on and _charge_player != null:
		_charge_player.play()


## An Intent the player has asked for. Mid-swing it is remembered rather
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
	# An item is out. The USE button fires it -- that is what it is for -- and
	# the ATTACK button is the escape hatch: it puts the item away and swings on
	# the same press, so a hookshot you drew by mistake costs you one button you
	# were already reaching for rather than a hunt for which D-pad direction you
	# pressed to draw it.
	#
	# That escape hatch is the whole reason the sword and the item are on
	# different buttons now. Drawing is sticky here -- the item STAYS out and you
	# walk around aiming it, which OOT's momentary C-buttons never let you do --
	# and a sticky mode with no unconditional way out is a trap.
	if equipped != &"":
		if intent == Intent.LIGHT:
			# Stowing is synchronous (Game._announce_loadout -> Bus ->
			# _on_loadout_changed -> equip), so `equipped` is already &"" by the
			# time the swing below asks. If that ever becomes deferred, the swing
			# starts happening with the bow still in his hands.
			Game.stow_item()
			_light_swing(_chain_step)
			return
		if intent == Intent.LUNGE and _hero.ranged != null:
			_hero.ranged.fire(equipped)
		return

	match intent:
		Intent.HEAVY:
			_heavy_swing()
		Intent.DASH:
			_dash_swing()
		Intent.LUNGE:
			# Sword out, use pressed: the leap, if there is something to leap at.
			# Nothing otherwise, deliberately -- this is OOT's A, where the jump
			# attack exists only under Z and the button is silent without it.
			_lunge_swing()
		_:
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


## The stab out of the guard. Unlike the lunge it asks for no target — see
## Hero.request_dash for why the shield has already earned it a direction.
##
## Note that this can arrive from the BUFFER, a swing or two after the shield it
## was pressed behind came down. That is correct and it is how the heavy behaves
## too: the player asked for a dash while guarding, and the answer to a press
## made half a swing early is the move they asked for, late — not a different
## move, and not silence.
func _dash_swing() -> void:
	if not _hero.request_dash(dash_swing_time, dash_drive_time, dash_speed):
		return
	# Ends the chain rather than stepping it, exactly as the heavy does. The dash
	# is how you OPEN on something, so letting it count as step one would make
	# the finisher two taps away from a button you press while standing still.
	_chain_step = 0
	_chain_timer = 0.0
	_commit(dash_swing_time, dash_damage_window, dash_damage, dash_knockback,
		K.HITSTOP_HEAVY, randf_range(0.86, 0.94))


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
## its conditions fail. It has its own button now, so a refusal is silence
## rather than a fallback swing: `attack` is one thumb away and always swings.
func _lunge_swing() -> bool:
	var target := _hero.lock_target()
	if target == null:
		return false

	# Flattened by hand rather than with K.flat, which NORMALISES: a range gate
	# reading distance off K.flat sees every target in the world as exactly 1 m
	# away, which puts them all inside the band and none of them outside it.
	var delta := target.global_position - _hero.global_position
	var to := Vector3(delta.x, 0.0, delta.z)
	var dist := to.length()
	if dist < lunge_min_range or dist > lunge_max_range:
		return false

	# The stick cone and the "only from a standing start" chain gate both went
	# when the lunge stopped sharing the attack button. They existed to tell a
	# leap apart from an ordinary swing pressed with the same thumb, and a hidden
	# rule on a DEDICATED button is just a button that intermittently does
	# nothing -- press X, press A, watch the hero stand there. What stops a
	# mashed chain touring the room is the same thing that always did: the leap
	# costs 0.78 s of unsteerable commitment, and you have to be locked on.

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
