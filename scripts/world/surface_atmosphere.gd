class_name SurfaceAtmosphere
extends Node3D
## Reusable composition root for outdoor sky, light, fog, and daily weather.
## It dynamically discovers `/root/Clock`; until that autoload is integrated it
## remains parseable and renders the canonical 08:00 sample.

const SKY_SHADER: Shader = preload("res://assets/shaders/sky.gdshader")
const DEFAULT_HOUR: float = 8.0
const SMOOTH_SECONDS: float = 0.65
const SOLAR_YAW: float = -58.0

var environment_node: WorldEnvironment
var sun: DirectionalLight3D
var weather: SurfaceWeather

var _sky_material: ShaderMaterial
var _clock: Node
var _initialized: bool = false

var _target_top: Color = Color.BLACK
var _target_horizon: Color = Color.BLACK
var _target_sun_color: Color = Color.WHITE
var _target_sun_energy: float = 0.0
var _target_ambient: float = 0.0
var _target_curve: float = 0.15
var _target_night: float = 1.0
var _target_sun_direction: Vector3 = Vector3.UP

var _top: Color = Color.BLACK
var _horizon: Color = Color.BLACK
var _sun_color: Color = Color.WHITE
var _sun_energy: float = 0.0
var _ambient: float = 0.0
var _curve: float = 0.15
var _night: float = 1.0
var _sun_direction: Vector3 = Vector3.UP


func _ready() -> void:
	_build_atmosphere()
	_try_connect_clock()
	refresh()
	_snap_to_target()
	_apply_atmosphere()


func _exit_tree() -> void:
	_disconnect_clock()


func _process(delta: float) -> void:
	if _clock == null or not is_instance_valid(_clock):
		_try_connect_clock()
	refresh()
	var weight: float = 1.0 - exp(-delta / SMOOTH_SECONDS)
	_top = _top.lerp(_target_top, weight)
	_horizon = _horizon.lerp(_target_horizon, weight)
	_sun_color = _sun_color.lerp(_target_sun_color, weight)
	_sun_energy = lerpf(_sun_energy, _target_sun_energy, weight)
	_ambient = lerpf(_ambient, _target_ambient, weight)
	_curve = lerpf(_curve, _target_curve, weight)
	_night = lerpf(_night, _target_night, weight)
	_sun_direction = _sun_direction.slerp(_target_sun_direction, weight).normalized()
	_apply_atmosphere()


func refresh() -> void:
	var clock_hour: float = DEFAULT_HOUR
	var clock_day: int = 1
	if _clock != null and is_instance_valid(_clock):
		clock_hour = float(_clock.get("hour"))
		clock_day = maxi(1, int(_clock.get("day")))
	var sampled: Dictionary = SkyCycle.sample(clock_hour)
	_target_top = Color(sampled["top"])
	_target_horizon = Color(sampled["hor"])
	_target_sun_energy = float(sampled["sun_e"])
	_target_ambient = float(sampled["amb"])
	_target_sun_color = Color(sampled["suncol"])
	_target_curve = float(sampled["curve"])
	_target_night = float(sampled["night"])
	_target_sun_direction = _sun_direction_for_hour(clock_hour)
	if weather != null:
		weather.set_day(clock_day)


func _build_atmosphere() -> void:
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	_sky_material.set_shader_parameter(&"ground_color", Color(0.24, 0.24, 0.23))
	_sky_material.set_shader_parameter(&"day_sky", Color(0.40, 0.55, 0.80))
	_sky_material.set_shader_parameter(&"day_horizon", Color(0.64, 0.74, 0.85))
	_sky_material.set_shader_parameter(&"sunset_sky", Color(0.44, 0.32, 0.54))
	_sky_material.set_shader_parameter(&"sunset_horizon", Color(1.00, 0.55, 0.30))
	_sky_material.set_shader_parameter(&"night_sky", Color(0.02, 0.03, 0.07))
	_sky_material.set_shader_parameter(&"night_horizon", Color(0.05, 0.06, 0.12))
	_sky_material.set_shader_parameter(&"sunset_exponent", 1.25)
	_sky_material.set_shader_parameter(&"night_exponent", 3.0)
	_sky_material.set_shader_parameter(&"key_tint", 0.40)
	_sky_material.set_shader_parameter(&"star_brightness", 0.75)
	_sky_material.set_shader_parameter(&"nebula_intensity", 0.30)
	_sky_material.set_shader_parameter(&"moon_energy", 0.0)
	_sky_material.set_shader_parameter(&"moon2_energy", 0.0)
	_sky_material.set_shader_parameter(&"aurora_intensity", 0.0)
	_sky_material.set_shader_parameter(&"shooting_star_intensity", 0.0)
	_sky_material.set_shader_parameter(&"planet_energy", 0.0)

	var sky_resource := Sky.new()
	sky_resource.sky_material = _sky_material
	sky_resource.radiance_size = Sky.RADIANCE_SIZE_256

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky_resource
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.25
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0008
	environment.fog_sun_scatter = 0.06
	environment.fog_sky_affect = 0.14
	environment.fog_aerial_perspective = 0.24
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 2.0

	environment_node = WorldEnvironment.new()
	environment_node.name = "SurfaceEnvironment"
	environment_node.environment = environment
	add_child(environment_node)

	sun = DirectionalLight3D.new()
	sun.name = "SurfaceSun"
	sun.shadow_enabled = true
	add_child(sun)

	weather = SurfaceWeather.new()
	weather.name = "SurfaceWeather"
	weather.configure(environment, sun, _sky_material)
	add_child(weather)


func _try_connect_clock() -> void:
	var candidate: Node = get_node_or_null("/root/Clock")
	if candidate == null or candidate == _clock:
		return
	_disconnect_clock()
	_clock = candidate
	var minute_callable := Callable(self, "_on_minute_changed")
	var phase_callable := Callable(self, "_on_phase_changed")
	if _clock.has_signal(&"minute_changed") and not _clock.is_connected(&"minute_changed", minute_callable):
		_clock.connect(&"minute_changed", minute_callable)
	if _clock.has_signal(&"phase_changed") and not _clock.is_connected(&"phase_changed", phase_callable):
		_clock.connect(&"phase_changed", phase_callable)
	refresh()


func _disconnect_clock() -> void:
	if _clock == null or not is_instance_valid(_clock):
		_clock = null
		return
	var minute_callable := Callable(self, "_on_minute_changed")
	var phase_callable := Callable(self, "_on_phase_changed")
	if _clock.is_connected(&"minute_changed", minute_callable):
		_clock.disconnect(&"minute_changed", minute_callable)
	if _clock.is_connected(&"phase_changed", phase_callable):
		_clock.disconnect(&"phase_changed", phase_callable)
	_clock = null


func _on_minute_changed(_day: int, _hour: int, _minute: int) -> void:
	refresh()


func _on_phase_changed(_phase: StringName) -> void:
	refresh()


func _snap_to_target() -> void:
	_top = _target_top
	_horizon = _target_horizon
	_sun_color = _target_sun_color
	_sun_energy = _target_sun_energy
	_ambient = _target_ambient
	_curve = _target_curve
	_night = _target_night
	_sun_direction = _target_sun_direction
	_initialized = true


func _apply_atmosphere() -> void:
	if not _initialized or environment_node == null or sun == null:
		return
	var environment: Environment = environment_node.environment
	environment.ambient_light_color = _horizon.lerp(_sun_color, 0.18)
	sun.light_color = _sun_color
	_set_sun_direction(_sun_direction)
	if weather != null:
		weather.apply_lighting(_sun_energy, _ambient, _night, _horizon)
	else:
		sun.light_energy = _sun_energy
		environment.ambient_light_energy = _ambient
		environment.fog_light_color = _horizon
	_sky_material.set_shader_parameter(&"top_color", _top)
	_sky_material.set_shader_parameter(&"horizon_color", _horizon)
	_sky_material.set_shader_parameter(&"horizon_curve", _curve)
	_sky_material.set_shader_parameter(&"night", _night)
	_sky_material.set_shader_parameter(&"sun_dir", _sun_direction)
	_sky_material.set_shader_parameter(&"sun_color", _sun_color)
	_sky_material.set_shader_parameter(&"sun_energy", sun.light_energy)


func _sun_direction_for_hour(clock_hour: float) -> Vector3:
	var normalized_hour: float = fposmod(clock_hour, 24.0)
	var sunrise: float = SkyCycle.sunrise_hour()
	var sunset: float = SkyCycle.sunset_hour()
	var orbit_angle: float
	if normalized_hour >= sunrise and normalized_hour < sunset:
		orbit_angle = inverse_lerp(sunrise, sunset, normalized_hour) * PI
	else:
		var night_hour: float = normalized_hour
		if night_hour < sunrise:
			night_hour += 24.0
		orbit_angle = PI + inverse_lerp(sunset, sunrise + 24.0, night_hour) * PI
	var direction := Vector3(cos(orbit_angle), sin(orbit_angle), 0.0)
	return direction.rotated(Vector3.UP, deg_to_rad(SOLAR_YAW)).normalized()


func _set_sun_direction(direction: Vector3) -> void:
	# DirectionalLight3D emits along -basis.z; the shader needs the opposite,
	# toward-sun vector, so basis.z and `sun_dir` are the same vector.
	var basis_up: Vector3 = Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var light_basis := Basis.looking_at(-direction, basis_up)
	sun.global_transform = Transform3D(light_basis, sun.global_position)
