class_name SurfaceWeather
extends Node3D
## One deterministic, deliberately small surface-weather state per clock day.
## Dungeons do not instantiate this node, so they share time without inheriting
## surface fog, clouds, or precipitation.

enum Weather { CLEAR, OVERCAST, RAIN, FOG, STORM }

const WEATHER_SEED: int = 0x41A7C3
const EASE_SECONDS: float = 4.0
const RAIN_HEIGHT: float = 11.0
const RAIN_COUNT: int = 320

var _environment: Environment
var _sun: DirectionalLight3D
var _sky_material: ShaderMaterial
var _rain: GPUParticles3D
var _rain_process: ParticleProcessMaterial

var _day: int = -1
var _weather: Weather = Weather.CLEAR
var _wind_direction: Vector2 = Vector2.RIGHT
var _cloud_offset: Vector2 = Vector2.ZERO
var _night_amount: float = 0.0

var _fog_density: float = 0.0008
var _cloud_cover: float = 0.12
var _sun_multiplier: float = 1.0
var _ambient_multiplier: float = 1.0
var _rain_amount: float = 0.0
var _wind_speed: float = 0.004

var _target_fog_density: float = 0.0008
var _target_cloud_cover: float = 0.12
var _target_sun_multiplier: float = 1.0
var _target_ambient_multiplier: float = 1.0
var _target_rain_amount: float = 0.0
var _target_wind_speed: float = 0.004
var _noise_installed: bool = false


func _init() -> void:
	# Weather eases first; the atmosphere then applies the fresh multipliers to
	# the current celestial sample in the same frame.
	process_priority = -10


func _ready() -> void:
	_build_rain()
	_install_cloud_noise()


func _process(delta: float) -> void:
	var weight: float = 1.0 - exp(-delta / EASE_SECONDS)
	_fog_density = lerpf(_fog_density, _target_fog_density, weight)
	_cloud_cover = lerpf(_cloud_cover, _target_cloud_cover, weight)
	_sun_multiplier = lerpf(_sun_multiplier, _target_sun_multiplier, weight)
	_ambient_multiplier = lerpf(_ambient_multiplier, _target_ambient_multiplier, weight)
	_rain_amount = lerpf(_rain_amount, _target_rain_amount, weight)
	_wind_speed = lerpf(_wind_speed, _target_wind_speed, weight)
	_cloud_offset += _wind_direction * _wind_speed * delta

	if _environment != null:
		_environment.fog_density = _fog_density
	_update_clouds()
	_update_rain()


func configure(environment: Environment, sun_light: DirectionalLight3D, sky_material: ShaderMaterial) -> void:
	_environment = environment
	_sun = sun_light
	_sky_material = sky_material
	if _environment != null:
		_environment.fog_enabled = true
		_environment.fog_density = _fog_density
	_install_cloud_noise()
	_update_clouds()


func set_day(new_day: int) -> void:
	var normalized_day: int = maxi(1, new_day)
	if normalized_day == _day:
		return
	_day = normalized_day
	var rng := RandomNumberGenerator.new()
	rng.seed = WEATHER_SEED + normalized_day * 7919
	var roll: float = rng.randf()
	if roll < 0.45:
		_weather = Weather.CLEAR
	elif roll < 0.70:
		_weather = Weather.OVERCAST
	elif roll < 0.85:
		_weather = Weather.RAIN
	elif roll < 0.95:
		_weather = Weather.FOG
	else:
		_weather = Weather.STORM
	var wind_angle: float = rng.randf_range(0.0, TAU)
	_wind_direction = Vector2(cos(wind_angle), sin(wind_angle))
	_set_targets_for_weather()


func weather_name() -> String:
	match _weather:
		Weather.CLEAR:
			return "Clear"
		Weather.OVERCAST:
			return "Overcast"
		Weather.RAIN:
			return "Rain"
		Weather.FOG:
			return "Fog"
		Weather.STORM:
			return "Storm"
	return "Clear"


## Called after the atmosphere samples the clock so weather remains a bounded
## multiplier rather than becoming a second owner of celestial lighting.
func apply_lighting(base_sun_energy: float, base_ambient_energy: float, night: float, horizon: Color) -> void:
	_night_amount = clampf(night, 0.0, 1.0)
	if _sun != null:
		_sun.light_energy = base_sun_energy * _sun_multiplier
	if _environment != null:
		_environment.ambient_light_energy = base_ambient_energy * _ambient_multiplier
		var weather_gray: Color = Color(0.48, 0.54, 0.62)
		var weather_weight: float = clampf((_fog_density - 0.0008) / 0.0092, 0.0, 0.72)
		_environment.fog_light_color = horizon.lerp(weather_gray, weather_weight)


func _set_targets_for_weather() -> void:
	match _weather:
		Weather.CLEAR:
			_set_targets(0.0008, 0.12, 1.0, 1.0, 0.0, 0.004)
		Weather.OVERCAST:
			_set_targets(0.0022, 0.76, 0.78, 0.88, 0.0, 0.008)
		Weather.RAIN:
			_set_targets(0.0040, 0.90, 0.66, 0.80, 0.62, 0.014)
		Weather.FOG:
			_set_targets(0.0100, 0.62, 0.72, 0.82, 0.0, 0.003)
		Weather.STORM:
			_set_targets(0.0065, 1.0, 0.48, 0.68, 1.0, 0.025)


func _set_targets(fog: float, clouds: float, sun_gloom: float, ambient_gloom: float, rain_strength: float, wind: float) -> void:
	_target_fog_density = fog
	_target_cloud_cover = clouds
	_target_sun_multiplier = sun_gloom
	_target_ambient_multiplier = ambient_gloom
	_target_rain_amount = rain_strength
	_target_wind_speed = wind


func _install_cloud_noise() -> void:
	if _noise_installed or _sky_material == null:
		return
	_sky_material.set_shader_parameter(&"cloud_noise_a", _cloud_noise(0.026, WEATHER_SEED))
	_sky_material.set_shader_parameter(&"cloud_noise_b", _cloud_noise(0.051, WEATHER_SEED + 97))
	_noise_installed = true


func _cloud_noise(frequency: float, noise_seed: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.frequency = frequency
	noise.seed = noise_seed
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture


func _update_clouds() -> void:
	if _sky_material == null:
		return
	var overcast_amount: float = clampf((_cloud_cover - 0.12) / 0.88, 0.0, 1.0)
	var day_color: Color = Color.WHITE.lerp(Color(0.52, 0.57, 0.65), overcast_amount)
	var night_color: Color = Color(0.28, 0.34, 0.48).lerp(Color(0.18, 0.22, 0.31), overcast_amount)
	_sky_material.set_shader_parameter(&"cloud_cover", _cloud_cover)
	_sky_material.set_shader_parameter(&"cloud_color", day_color.lerp(night_color, _night_amount))
	_sky_material.set_shader_parameter(&"cloud_offset", _cloud_offset)
	_sky_material.set_shader_parameter(&"cloud_flash", 0.0)


func _build_rain() -> void:
	if _rain != null:
		return
	var particles := GPUParticles3D.new()
	particles.name = "BoundedRain"
	particles.amount = RAIN_COUNT
	particles.lifetime = 0.9
	particles.preprocess = 0.9
	particles.fixed_fps = 30
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-20.0, -24.0, -20.0), Vector3(40.0, 32.0, 40.0))
	particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var particle_process := ParticleProcessMaterial.new()
	particle_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_process.emission_box_extents = Vector3(16.0, 1.0, 16.0)
	particle_process.direction = Vector3.DOWN
	particle_process.spread = 3.0
	particle_process.initial_velocity_min = 15.0
	particle_process.initial_velocity_max = 21.0
	particle_process.gravity = Vector3(0.0, -24.0, 0.0)
	particle_process.scale_min = 0.75
	particle_process.scale_max = 1.2
	particles.process_material = particle_process
	_rain_process = particle_process

	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.75)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.78, 0.86, 0.98, 0.62)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	quad.material = material
	particles.draw_pass_1 = quad
	particles.emitting = false
	particles.visible = false
	add_child(particles)
	_rain = particles


func _update_rain() -> void:
	if _rain == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var focus: Vector3 = global_position
	if camera != null:
		focus = camera.global_position
	_rain.global_position = focus + Vector3.UP * RAIN_HEIGHT
	_rain.amount_ratio = clampf(_rain_amount, 0.0, 1.0)
	_rain.emitting = _rain_amount > 0.02
	_rain.visible = _rain.emitting
	if _rain_process != null:
		var wind: Vector2 = _wind_direction * (_wind_speed * 360.0)
		_rain_process.gravity = Vector3(wind.x, -24.0, wind.y)
