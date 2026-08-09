class_name HitFlash
extends RefCounted
## Makes a body react to being hit, and to being about to hit you: the white
## flash on a landed blow, and the warning glow that carries a wind-up.
##
## **The thing that makes this a file instead of four lines.** A GLB is loaded
## once and instanced many times, and every instance SHARES the loaded Mesh's
## materials. The MeshInstance3D nodes are unique, the materials behind them are
## not. So `mi.get_active_material(0).emission_energy_multiplier = 3.0` -- the
## obvious way to write this -- lights up every skeleton in the room, and in a
## dungeon that spawns three of a kind per room the tell you built to make one
## enemy readable makes the room unreadable instead. `bind()` therefore
## duplicates each surface's material into a per-surface OVERRIDE, which is a
## cheap instance-local shell: the textures behind it stay shared.
##
## Tweens here deliberately do NOT ignore time scale. `Feel` freezes the world
## for a few frames on impact, and the flash holding at full white through that
## freeze is the impact frame -- letting it keep fading during the stop would
## throw away the one moment the effect exists for.

## How hot the white goes on a landed blow, and how long it takes to fall off.
const HIT_ENERGY := 2.4
const HIT_SECONDS := 0.17

var _host: Node = null
var _mats: Array[BaseMaterial3D] = []
## material instance id -> {enabled, color, energy}. A wraith may be emissive
## before anything touches it; "off" is not a safe thing to restore to.
var _baselines: Dictionary = {}
var _tween: Tween = null


## Take ownership of every surface under `model`, so this body can flash alone.
## `host` is the Node the tweens hang off -- when it frees, they stop.
func bind(host: Node, model: Node3D) -> void:
	_host = host
	_mats.clear()
	_baselines.clear()
	if model == null:
		return

	# One copy per SOURCE material, not one per surface: a model whose six
	# surfaces all use the same material should still flash as one body, and
	# six duplicates of the same resource is five wasted.
	var owned: Dictionary = {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# A whole-instance override beats every per-surface one, so if the model
		# has it, that is the level to isolate at.
		if mi.material_override is BaseMaterial3D:
			var whole := _own(mi.material_override as BaseMaterial3D, owned)
			mi.material_override = whole
			_remember(whole)
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var local := _own(source, owned)
			mi.set_surface_override_material(surface, local)
			_remember(local)


## Struck. Goes white-hot and falls back to whatever each surface was.
func hit(tint: Color = Color.WHITE) -> void:
	_kill()
	_write(tint, HIT_ENERGY)
	if _host == null or not is_instance_valid(_host):
		return
	_tween = _host.create_tween()
	_tween.tween_method(_energy, HIT_ENERGY, 0.0, HIT_SECONDS)
	_tween.tween_callback(restore)


## Hold a colour at `energy01` of full. This is the wind-up: driven every frame
## from the enemy's state tick rather than tweened, because the ramp has to track
## a wind-up that can be interrupted at any point -- and an interrupted tween
## that has already been killed leaves the body glowing.
func glow(tint: Color, energy01: float) -> void:
	_kill()
	_write(tint, clampf(energy01, 0.0, 1.0) * HIT_ENERGY)


## Put every surface back the way the artist left it.
func restore() -> void:
	for m in _mats:
		if not is_instance_valid(m):
			continue
		var base: Dictionary = _baselines.get(m.get_instance_id(), {})
		if base.is_empty():
			continue
		m.emission = base["color"]
		m.emission_energy_multiplier = float(base["energy"])
		m.emission_enabled = bool(base["enabled"])
	_tween = null


## Stop any in-flight flash and settle. Called when the body dies, so a corpse
## does not freeze at whatever intensity the killing blow left it on.
func clear() -> void:
	_kill()
	restore()


# --- internals --------------------------------------------------------------

func _own(source: BaseMaterial3D, owned: Dictionary) -> BaseMaterial3D:
	var key := source.get_instance_id()
	if owned.has(key):
		return owned[key] as BaseMaterial3D
	var local := source.duplicate() as BaseMaterial3D
	local.resource_local_to_scene = true
	owned[key] = local
	return local


func _remember(m: BaseMaterial3D) -> void:
	if _mats.has(m):
		return
	_mats.append(m)
	_baselines[m.get_instance_id()] = {
		"enabled": m.emission_enabled,
		"color": m.emission,
		"energy": m.emission_energy_multiplier,
	}


func _write(tint: Color, energy: float) -> void:
	for m in _mats:
		if not is_instance_valid(m):
			continue
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = energy


func _energy(e: float) -> void:
	for m in _mats:
		if is_instance_valid(m):
			m.emission_energy_multiplier = e


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
