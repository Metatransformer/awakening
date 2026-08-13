class_name GlintTrialReward
extends Node3D
## The one-shot presentation attached to the Cistern sun socket. Permanent
## mutation is the gate: a duplicate solve does nothing, including no autosave
## and no cameo.

const GLINT_FAE_SCRIPT := "res://scripts/world/glint_fae.gd"
const CAMEO_HOLD := 10.0
const CAMEO_FADE := 0.45

var _claimed: bool = false
var _cameo: Node3D = null
var _reward_label: WorldCaption = null
var _signpost: WorldCaption = null


func bind(socket: PuzzleAtom) -> void:
	if socket == null or not is_instance_valid(socket):
		return
	if not socket.solved.is_connected(_on_socket_solved):
		socket.solved.connect(_on_socket_solved)
	if socket.is_solved():
		_on_socket_solved.call_deferred(socket)


func claimed() -> bool:
	return _claimed


func cameo_visible() -> bool:
	return is_instance_valid(_cameo) and _cameo.visible


func _on_socket_solved(_atom: PuzzleAtom) -> void:
	if not Game.solve_glint_trial(GlintDb.CISTERN_SUN_GLINT_ID):
		return
	Saves.autosave()
	_claimed = true
	_present()


func _present() -> void:
	var script := load(GLINT_FAE_SCRIPT) as GDScript
	if script == null:
		push_error("glint_trial_reward: cannot load %s" % GLINT_FAE_SCRIPT)
		return
	_cameo = script.new() as Node3D
	if _cameo == null:
		return
	_cameo.name = "GlintCameo"
	_cameo.position.y = 0.58
	_cameo.scale = Vector3.ONE * 0.04
	add_child(_cameo)
	RewardVfx.aura(_cameo, 0.82, Pal.GOLD)

	_reward_label = _caption("GLIMMER +1", Pal.GOLD, 2.18)
	_signpost = _caption("HIGHBRIDGE STATUE", Pal.BONE, 1.82)
	Bus.request_sfx.emit(&"glint_yoohoo", global_position)
	Bus.request_sfx.emit(&"glint_bell", global_position)

	var tween := create_tween()
	tween.tween_property(_cameo, ^"scale", Vector3.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(CAMEO_HOLD)
	tween.tween_property(_cameo, ^"scale", Vector3.ONE * 0.02, CAMEO_FADE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_reward_label, ^"alpha", 0.0, CAMEO_FADE)
	tween.parallel().tween_property(_signpost, ^"alpha", 0.0, CAMEO_FADE)
	tween.tween_callback(_finish_cameo)


func _caption(words: String, hue: Color, height: float) -> WorldCaption:
	var caption := WorldCaption.new()
	caption.text = words
	caption.tint = hue
	caption.ref_px = 14.0
	caption.position.y = height
	caption.max_range = 18.0
	add_child(caption)
	return caption


func _finish_cameo() -> void:
	if is_instance_valid(_cameo):
		_cameo.queue_free()
	if is_instance_valid(_reward_label):
		_reward_label.queue_free()
	if is_instance_valid(_signpost):
		_signpost.queue_free()
	_cameo = null
	_reward_label = null
	_signpost = null
