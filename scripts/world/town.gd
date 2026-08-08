class_name Town
extends Node3D
## The hub. A walled yard, two people, and a hole in the ground.
##
## Deliberately TINY -- about eight seconds of walking, corner to corner. The
## town is not content; it is the place where the number in your bag turns into
## a number you keep, and every extra metre of it is a tax on the loop. Moonlighter
## earns its town by making you run a shop in it. This one does not, so it does
## not get to be big.
##
## It is also the only warm, lit, safe place in the game, which is what makes the
## gate's cold mouth mean something.

const KIT_FLOOR := preload("res://scenes/kit/floor_slab.tscn")
const KIT_WALL := preload("res://scenes/kit/wall_segment.tscn")
const KIT_TORCH := preload("res://scenes/kit/torch.tscn")
const KIT_PILLAR := preload("res://scenes/kit/pillar.tscn")

@export var yard: Vector2 = Vector2(26.0, 22.0)
@export var wall_height: float = 4.2

var vendor: Npc
var smith: Npc
var gate: Npc

var _report: Label3D


func _ready() -> void:
	_build_env()
	_build_yard()
	_build_people()
	# The result of the run you just finished, shown once, in the world, on the
	# spot you arrived. A modal "RUN SUMMARY" popup would stop the loop dead;
	# this is readable while you are already walking to the vendor.
	Bus.run_ended.connect(_show_report)
	_show_last_report()


# --- Look -------------------------------------------------------------------

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Pal.VOID
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.24, 0.34)
	env.ambient_light_energy = 0.55
	# Fog as a draw-distance wall, same treatment as the dungeon (STYLEGUIDE §4).
	# In town it only has to hide the fact that there is nothing past the walls.
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.09, 0.14)
	env.fog_density = 0.022
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.0

	var we := WorldEnvironment.new()
	we.name = "TownEnv"
	we.environment = env
	add_child(we)

	# One cold key from above, so the yard reads as open sky at night rather than
	# as an unlit room. Everything warm in town comes from a torch or a lantern.
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.52, 0.58, 0.80)
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	add_child(moon)


func _build_yard() -> void:
	var ground := KIT_FLOOR.instantiate()
	ground.size = yard
	add_child(ground)

	var hx := yard.x * 0.5
	var hz := yard.y * 0.5
	var sides := [
		{"yaw": 0.0, "at": Vector3(0, 0, -hz), "len": yard.x, "seed": 501},
		{"yaw": PI, "at": Vector3(0, 0, hz), "len": yard.x, "seed": 502},
		{"yaw": PI * 0.5, "at": Vector3(-hx, 0, 0), "len": yard.y, "seed": 503},
		{"yaw": -PI * 0.5, "at": Vector3(hx, 0, 0), "len": yard.y, "seed": 504},
	]
	for s in sides:
		var w := KIT_WALL.instantiate()
		w.length = float(s["len"])
		w.height = wall_height
		w.rng_seed = int(s["seed"])
		w.position = s["at"]
		w.rotation.y = float(s["yaw"])
		add_child(w)

	# Torches only along the two long walls, so the yard has a lit spine and dim
	# corners rather than an even wash.
	var n := 0
	for x in [-hx * 0.55, 0.0, hx * 0.55]:
		for z in [-hz, hz]:
			var t := KIT_TORCH.instantiate()
			t.rng_seed = 520 + n
			t.cast_shadow = n < 3
			t.position = Vector3(x, KitStyle.SCONCE_Y, z)
			t.rotation.y = 0.0 if z < 0.0 else PI
			add_child(t)
			n += 1

	for sx in [-1.0, 1.0]:
		var p := KIT_PILLAR.instantiate()
		p.height = wall_height
		p.position = Vector3(hx * 0.62 * sx, 0.0, -hz * 0.55)
		add_child(p)


func _build_people() -> void:
	vendor = Npc.new()
	vendor.role = Npc.Role.VENDOR
	vendor.robe_color = Color(0.34, 0.20, 0.26)
	vendor.lamp_color = Pal.GOLD
	vendor.position = Vector3(-yard.x * 0.26, 0.0, -yard.y * 0.06)
	add_child(vendor)

	smith = Npc.new()
	smith.role = Npc.Role.SMITH
	smith.robe_color = Color(0.22, 0.26, 0.30)
	smith.lamp_color = Color(0.98, 0.56, 0.24)
	smith.position = Vector3(yard.x * 0.26, 0.0, -yard.y * 0.06)
	add_child(smith)

	gate = Npc.new()
	gate.role = Npc.Role.GATE
	gate.position = Vector3(0.0, 0.0, -yard.y * 0.40)
	add_child(gate)


# --- The run report ---------------------------------------------------------

func _show_last_report() -> void:
	# Arriving in town from a run means run_ended already fired, during the fade,
	# before this scene existed. Flow stashes the last one so the arrival can
	# show it -- otherwise the only run whose result you ever see is one that
	# somehow ended while you were already standing here.
	if Flow.last_result.is_empty():
		return
	_show_report(bool(Flow.last_result["extracted"]),
		Flow.last_result["contents"], int(Flow.last_result["value"]))
	Flow.last_result = {}


func _show_report(extracted: bool, contents: Dictionary, value: int) -> void:
	if _report == null:
		_report = Label3D.new()
		_report.font_size = 56
		_report.pixel_size = 0.0030
		_report.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_report.no_depth_test = true
		_report.outline_size = 18
		_report.position = Vector3(0.0, 2.6, yard.y * 0.30)
		add_child(_report)

	var count := 0
	for id: StringName in contents:
		count += int(contents[id])

	if extracted:
		_report.modulate = Pal.CYAN
		_report.text = "EXTRACTED\n%d ITEMS  %d GOLD" % [count, value]
	else:
		_report.modulate = Pal.RUST
		_report.text = "YOU DIED\nLOST %d ITEMS  %d GOLD" % [count, value]

	_report.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(_report, "modulate:a", 0.0, 1.2)
