extends Node3D
## A valley in play: builds its world, the truck, the camera, the HUD and the contracts.

const POST_SHADER := preload("res://shaders/post_dither.gdshader")

signal leave  # Esc: back to the valleys (scripts/game.gd)

var valley: Valley  # set before the scene enters the tree; the khutir valley if not
var profile: Profile  # the same; a profile in memory if not
var terrain: Terrain
var vehicle: Vehicle
var camera_rig: CameraRig
var contracts: Contracts
var hud: Hud
var map_screen: MapScreen
var builder: WorldBuilder
var locations: Dictionary
var roads: Array[PackedVector2Array] = []
var weather: Weather  # set before the scene enters the tree; the valley's own if not
var _env: Environment
var _sun: DirectionalLight3D
var _parked: Array[Vector3] = []  # the middles of the spots the trailers were parked on
var _fall: CPUParticles3D


func _ready() -> void:
	_setup_input()
	if valley == null:
		valley = Valley.khutir()
	apply_weather(weather if weather else valley.own)
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

	if profile == null:
		profile = Profile.new()
	var spawn := _spawn()
	var spawn_yaw := valley.spawn_yaw
	vehicle = _truck(TruckSpec.find(profile.truck))

	camera_rig = CameraRig.new()
	camera_rig.target = vehicle
	camera_rig.terrain = terrain
	add_child(camera_rig)
	camera_rig.snap_to_target()

	contracts = Contracts.new()
	contracts.spawn_pos = spawn
	contracts.spawn_yaw = spawn_yaw
	add_child(contracts)
	contracts.profile = profile
	_park_trailers()
	contracts.setup(vehicle, terrain, locations)
	contracts.truck_wanted.connect(set_truck)
	contracts.rigs_changed.connect(_park_trailers)

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


## Where the truck starts: beside the depot, facing the first road out.
func _spawn() -> Vector3:
	return Vector3(valley.spawn.x, terrain.get_height(valley.spawn.x, valley.spawn.y) + 1.5, valley.spawn.y)


## A truck of spec at the spawn, in the world (the pickup when spec is null).
func _truck(spec: TruckSpec) -> Vehicle:
	var v := Vehicle.new()
	v.name = "Truck"
	v.spec = spec if spec else TruckSpec.pickup()
	v.terrain = terrain
	v.position = _spawn()
	v.rotation.y = valley.spawn_yaw
	add_child(v)
	v.winch.anchors = builder.anchor_points
	return v


## The garage put spec at the depot: the truck in play is replaced by it, at the spawn.
func set_truck(spec: TruckSpec) -> void:
	var old := vehicle
	old.unhitch()
	remove_child(old)
	old.queue_free()
	vehicle = _truck(spec)
	camera_rig.target = vehicle
	camera_rig.snap_to_target()
	hud.vehicle = vehicle
	map_screen.vehicle = vehicle
	contracts.set_vehicle(vehicle)


## The player's trailers wait beside the truck's spawn, facing the way it faces; one bought here
## joins them.
func _park_trailers() -> void:
	for spec in TrailerSpec.all():
		if not profile.has_rig(spec.id) or contracts._trailer(spec.id) != null:
			continue
		var t := Trailer.new()
		t.name = "Trailer_%s" % spec.id
		t.spec = spec
		t.terrain = terrain
		add_child(t)
		var p := _parking(spec)
		t.stand_on(Vector2(p.x, p.z), valley.spawn_yaw)
		contracts.trailers.append(t)


## A spot for a trailer of spec beside the depot: on level ground with nothing standing on it, clear
## of the truck's spawn and of the trailers parked already, the nearest of a few rows to either side.
func _parking(spec: TrailerSpec) -> Vector3:
	var turn := Basis(Vector3.UP, valley.spawn_yaw)
	var lo := Vector3(-1.5, 0.0, spec.coupler.z)
	var hi := Vector3(1.5, 2.5, spec.coupler.z)
	for b in spec.shapes:
		lo = lo.min(b.pos - b.size * 0.5)
		hi = hi.max(b.pos + b.size * 0.5)
	var box := BoxShape3D.new()
	box.size = hi - lo + Vector3(1.0, 0.0, 1.0)
	var space := get_world_3d().direct_space_state
	for row in [0.0, 6.0, -6.0, 12.0, -12.0]:
		for step in range(1, 8):
			for side in [1.0, -1.0]:
				var p := _spawn() + turn * Vector3(side * 4.5 * step, 0.0, row)
				p.y = terrain.get_height(p.x, p.z)
				var middle := p + turn * ((lo + hi) * 0.5)
				var heights := PackedFloat32Array()
				for c in [Vector3(lo.x, 0.0, lo.z), Vector3(hi.x, 0.0, lo.z), Vector3(lo.x, 0.0, hi.z), Vector3(hi.x, 0.0, hi.z)]:
					var corner: Vector3 = p + turn * c
					heights.append(terrain.get_height(corner.x, corner.z))
				var level := heights[heights.size() - 1]
				var spread := 0.0
				for h in heights:
					spread = maxf(spread, absf(h - level))
				if spread > 0.6 or middle.distance_to(_spawn()) < 6.0:
					continue
				var free := true
				for taken in _parked:
					free = free and middle.distance_to(taken) > 6.0
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = box
				q.transform = Transform3D(turn, middle + Vector3(0.0, box.size.y * 0.5 + 0.4, 0.0))
				for hit in space.intersect_shape(q, 4):
					free = free and hit.collider.get_parent() == terrain
				if free:
					_parked.append(middle)
					return p
	return _spawn() + turn * Vector3(9.0, 0.0, 0.0)


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
	if _fall:
		_fall.global_position = cam.global_position - cam.global_transform.basis.z * 10.0 + Vector3(0.0, 8.0, 0.0)


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
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		if map_screen.visible:
			_toggle_map()
		elif leave.get_connections().is_empty():
			get_tree().quit()
		else:
			leave.emit()


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
		"hitch": [KEY_C],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key  # physical keys: works with any keyboard layout
			InputMap.action_add_event(action, ev)


## The sky, the light, the fog and what falls from it; called again to change the weather.
func apply_weather(w: Weather) -> void:
	weather = w
	if _env == null:
		_env = Environment.new()
		_env.background_mode = Environment.BG_COLOR
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.fog_enabled = true
		var we := WorldEnvironment.new()
		we.environment = _env
		add_child(we)
		_sun = DirectionalLight3D.new()
		add_child(_sun)
	_env.background_color = w.sky
	_env.ambient_light_color = w.ambient
	_env.ambient_light_energy = w.ambient_energy
	_env.fog_light_color = w.fog
	_env.fog_density = w.fog_density
	_sun.rotation_degrees = w.sun_angle
	_sun.light_color = w.sun
	_sun.light_energy = w.sun_energy
	_setup_fall(w)


## Snow drifting down around the camera, or rain streaking through, or nothing.
func _setup_fall(w: Weather) -> void:
	if _fall:
		_fall.queue_free()
		_fall = null
	if w.fall == "none":
		return
	_fall = CPUParticles3D.new()
	_fall.amount = w.fall_amount
	_fall.local_coords = false
	_fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fall.emission_box_extents = Vector3(30.0, 2.0, 30.0)
	_fall.spread = 10.0
	var quad := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if w.fall == "rain":
		_fall.lifetime = 1.4
		_fall.preprocess = 1.4
		_fall.direction = Vector3(w.wind * 0.3, -1.0, 0.0)
		_fall.initial_velocity_min = 12.0
		_fall.initial_velocity_max = 15.0
		_fall.gravity = Vector3(w.wind, -9.0, 0.0)
		quad.size = Vector2(0.02, 0.6)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.72, 0.78, 0.88, 0.55)
	else:
		_fall.lifetime = 5.0
		_fall.preprocess = 5.0
		_fall.direction = Vector3(w.wind, -1.0, 0.0)
		_fall.initial_velocity_min = 1.5
		_fall.initial_velocity_max = 2.5
		_fall.gravity = Vector3(w.wind * 1.5, -0.6, 0.0)
		quad.size = Vector2(0.07, 0.07)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(0.95, 0.97, 1.0)
	quad.material = m
	_fall.mesh = quad
	add_child(_fall)


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
