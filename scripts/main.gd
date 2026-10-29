extends Node3D
## A valley in play: builds its world, the truck, the camera, the HUD and the contracts.

const POST_SHADER := preload("res://shaders/post_dither.gdshader")

var valley: Valley  # set before the scene enters the tree; the khutir valley if not
var terrain: Terrain
var vehicle: Vehicle
var camera_rig: CameraRig
var contracts: Contracts
var hud: Hud
var map_screen: MapScreen
var builder: WorldBuilder
var locations: Dictionary
var roads: Array[PackedVector2Array] = []
var _snowfall: CPUParticles3D


func _ready() -> void:
	_setup_input()
	_setup_environment()

	if valley == null:
		valley = Valley.khutir()
	locations = valley.locations
	roads = valley.roads

	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate(valley)

	builder = WorldBuilder.new()
	builder.name = "World"
	add_child(builder)
	builder.build(terrain, valley)

	var spawn := Vector3(valley.spawn.x, terrain.get_height(valley.spawn.x, valley.spawn.y) + 1.5, valley.spawn.y)
	var spawn_yaw := valley.spawn_yaw
	vehicle = Vehicle.new()
	vehicle.name = "Truck"
	vehicle.terrain = terrain
	vehicle.position = spawn
	vehicle.rotation.y = spawn_yaw
	add_child(vehicle)
	vehicle.winch.anchors = builder.anchor_points

	camera_rig = CameraRig.new()
	camera_rig.target = vehicle
	camera_rig.terrain = terrain
	add_child(camera_rig)
	camera_rig.snap_to_target()

	contracts = Contracts.new()
	contracts.spawn_pos = spawn
	contracts.spawn_yaw = spawn_yaw
	add_child(contracts)
	contracts.setup(vehicle, terrain, locations)

	_setup_snowfall()
	_setup_post()
	hud = Hud.new()
	add_child(hud)
	hud.setup(vehicle, contracts)
	map_screen = MapScreen.new()
	add_child(map_screen)
	map_screen.setup(terrain, vehicle, contracts, locations, builder.tree_points)

	if "--autodrive" in OS.get_cmdline_user_args():
		vehicle.drive_along(roads[0].slice(1))
	if "--maptest" in OS.get_cmdline_user_args():
		_toggle_map()
	if "--winchtest" in OS.get_cmdline_user_args():
		_winch_test()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture(arg.get_slice("=", 1))


## Store-page capture (scripts/capture/director.gd): --capture=trailer --out=<dir>.
func _capture(what: String) -> void:
	var director := Director.new()
	director.main = self
	director.out_dir = OS.get_user_data_dir().path_join("capture").path_join(what)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			director.out_dir = arg.get_slice("=", 1)
	add_child(director)


func _process(_delta: float) -> void:
	if vehicle.autodrive and Engine.get_process_frames() % 30 == 0:
		print("autodrive pos %s  speed %.1f" % [vehicle.global_position.snapped(Vector3.ONE * 0.1), vehicle.forward_speed])
	var cam := camera_rig.camera
	_snowfall.global_position = cam.global_position - cam.global_transform.basis.z * 10.0 + Vector3(0.0, 8.0, 0.0)


## The window or the browser tab lost the keyboard: a key let go out there never reaches the game
## (in a browser, after a click outside the game's frame), so every key is let go here, or the
## truck would keep its throttle on with nothing pressed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for action in InputMap.get_actions():
			if Input.is_action_pressed(action):
				Input.action_release(action)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("toggle_map"):
		_toggle_map()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		if map_screen.visible:
			_toggle_map()
		else:
			get_tree().quit()


func _toggle_map() -> void:
	map_screen.toggle()
	hud.visible = not map_screen.visible


func _winch_test() -> void:
	# Park the truck nose-first in deep snow on a slope, hook up and pull.
	var p := Vector2(-40.0, -60.0)
	vehicle.teleport(Vector3(p.x, terrain.get_height(p.x, p.y) + 1.5, p.y), 0.0)
	vehicle.set_cargo(true)
	await get_tree().create_timer(1.5).timeout
	print("winch candidate %d  prompt: %s" % [vehicle.winch.candidate, vehicle.winch.prompt()])
	vehicle.winch.toggle()
	vehicle.winch.auto_reel = true
	for i in 16:
		await get_tree().create_timer(0.5).timeout
		print("winch len %.1f tension %.0f  pos %s  anchor %s" % [vehicle.winch.length, vehicle.winch.tension,
			vehicle.global_position.snapped(Vector3.ONE * 0.1), vehicle.winch.anchor.snapped(Vector3.ONE * 0.1)])


func _setup_input() -> void:
	var map := {
		"accelerate": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"handbrake": [KEY_SPACE],
		"toggle_awd": [KEY_Q],
		"toggle_diff": [KEY_X],
		"toggle_low": [KEY_G],
		"toggle_lights": [KEY_H],
		"reset": [KEY_R],
		"interact": [KEY_E],
		"recover": [KEY_T],
		"toggle_help": [KEY_F1],
		"toggle_map": [KEY_M],
		"winch": [KEY_F],
		"winch_reel": [KEY_SHIFT],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key  # physical keys: works with any keyboard layout
			InputMap.action_add_event(action, ev)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.34, 0.43)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.75)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.38, 0.42, 0.5)
	env.fog_density = 0.022
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	sun.light_color = Color(0.85, 0.88, 1.0)
	sun.light_energy = 0.55
	add_child(sun)


func _setup_snowfall() -> void:
	_snowfall = CPUParticles3D.new()
	_snowfall.amount = 900
	_snowfall.lifetime = 5.0
	_snowfall.preprocess = 5.0
	_snowfall.local_coords = false
	_snowfall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snowfall.emission_box_extents = Vector3(30.0, 2.0, 30.0)
	_snowfall.direction = Vector3(0.2, -1.0, 0.0)
	_snowfall.spread = 10.0
	_snowfall.initial_velocity_min = 1.5
	_snowfall.initial_velocity_max = 2.5
	_snowfall.gravity = Vector3(0.3, -0.6, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.95, 0.97, 1.0)
	quad.material = m
	_snowfall.mesh = quad
	add_child(_snowfall)


func _setup_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	rect.material = m
	layer.add_child(rect)
