extends Node3D
## A valley in play: builds its world, the truck, the camera, the HUD and the contracts.

const POST_SHADER := preload("res://shaders/post_dither.gdshader")
const TOW_HOME := 30.0  # m from the spawn: a trailer further off than this the tow brings back

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
var _parked := {}  # trailer -> the spot it was given by the depot: its footprint about the spawn
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
	contracts.towing.connect(_towing)

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
	_clear_spawn()
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
		_park(t)
		contracts.trailers.append(t)


## Stands trailer t on its spot by the depot (it moves at the next physics step).
func _park(t: Trailer) -> void:
	var p := _parking(t)
	t.stand_on(Vector2(p.x, p.z), valley.spawn_yaw)


## The tow (T) is on its way: the truck's trailer is let go, and it and any trailer left out in the
## valley or lying on its side are brought to their spots by the depot; a trailer left standing
## where the truck is to be set down is moved off it.
func _towing() -> void:
	var hitched := vehicle.trailer
	vehicle.unhitch()
	if hitched:
		_park(hitched)
	for t in contracts.trailers:
		if is_instance_valid(t) and t != hitched and (t.global_transform.basis.y.y < 0.7 \
				or Vector2(t.global_position.x - _spawn().x, t.global_position.z - _spawn().z).length() > TOW_HOME):
			_park(t)
	_clear_spawn()


## Moves any trailer standing where a truck is set down at the spawn (a long one left there, say)
## to its spot by the depot.
func _clear_spawn() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 10.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis(Vector3.UP, valley.spawn_yaw), _spawn() + Vector3(0.0, 0.5, 0.0))
	q.exclude = [terrain.body.get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var t := hit.collider as Trailer
		if t and t.truck == null:
			_park(t)


## A spot for trailer t beside the depot, facing the way the truck does there, and t's from now
## on: clear of whatever stands on it (but t), of the trucks' spawn and of the other trailers'
## spots; on level ground off the roads if there is such a spot about, else on fairly level ground
## off them, else anywhere clear. The nearest of a grid of spots to either side of the spawn.
func _parking(t: Trailer) -> Vector3:
	var turn := Basis(Vector3.UP, valley.spawn_yaw)
	var lo := t.spec.extent().position
	var hi := t.spec.extent().end
	var box := BoxShape3D.new()
	box.size = hi - lo + Vector3(1.0, 0.0, 1.0)
	var feet: Array[Vector3] = []  # along its sides and down its middle, every 2 m or less
	var n := ceili((hi.z - lo.z) / 2.0)
	for i in n + 1:
		for x in [lo.x, 0.0, hi.x]:
			feet.append(Vector3(x, 0.0, lerpf(lo.z, hi.z, float(i) / n)))
	var taken: Array[Rect2] = [_spawn_rect()]
	for o in _parked.keys():
		if not is_instance_valid(o):
			_parked.erase(o)
		elif o != t:
			taken.append(_parked[o])
	var spots: Array[Vector2] = []  # about the spawn: across, along
	for row in range(-8, 9):
		for step in range(1, 11):
			for side in [1.0, -1.0]:
				spots.append(Vector2(side * 4.5 * step, row * 3.0))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	var space := get_world_3d().direct_space_state
	# Level and off the roads; fairly level and off them; anywhere clear.
	for limits in [Vector2(0.6, Terrain.ROAD_HALF_WIDTH + 0.5), Vector2(1.2, Terrain.ROAD_HALF_WIDTH), Vector2(INF, -INF)]:
		for s in spots:
			var rect := Rect2(s.x + lo.x - 0.5, s.y + lo.z - 0.5, hi.x - lo.x + 1.0, hi.z - lo.z + 1.0)
			if taken.any(func(r: Rect2) -> bool: return r.intersects(rect)):
				continue
			var p := _spawn() + turn * Vector3(s.x, 0.0, s.y)
			p.y = terrain.get_height(p.x, p.z)
			var low := INF
			var high := -INF
			var off_road := INF
			for f in feet:
				var at: Vector3 = p + turn * f
				var h := terrain.get_height(at.x, at.z)
				low = minf(low, h)
				high = maxf(high, h)
				off_road = minf(off_road, terrain.road_distance(Vector2(at.x, at.z)))
			if high - low > limits.x or off_road <= limits.y:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = Transform3D(turn, p + turn * ((lo + hi) * 0.5) + Vector3(0.0, 0.3, 0.0))
			q.exclude = [t.get_rid(), terrain.body.get_rid()]
			if space.intersect_shape(q, 1).is_empty():
				_parked[t] = rect
				return p
	# Nowhere clear of buildings and trees for 30 m about: the first spot no truck or trailer has.
	for s in spots:
		var rect := Rect2(s.x + lo.x - 0.5, s.y + lo.z - 0.5, hi.x - lo.x + 1.0, hi.z - lo.z + 1.0)
		if not taken.any(func(r: Rect2) -> bool: return r.intersects(rect)):
			_parked[t] = rect
			var p := _spawn() + turn * Vector3(s.x, 0.0, s.y)
			return Vector3(p.x, terrain.get_height(p.x, p.z), p.z)
	return _spawn()


## Where the trucks stand at the spawn, about it (across, along): the largest of them, and 1 m about.
func _spawn_rect() -> Rect2:
	var lo := Vector2(-1.0, -1.0)
	var hi := Vector2(1.0, 1.0)
	for spec in TruckSpec.all():
		for b in spec.shapes:
			lo = lo.min(Vector2(b.pos.x - b.size.x * 0.5, b.pos.z - b.size.z * 0.5))
			hi = hi.max(Vector2(b.pos.x + b.size.x * 0.5, b.pos.z + b.size.z * 0.5))
		for w in spec.wheels:
			lo = lo.min(Vector2(w.mount.x - w.width, w.mount.z - w.radius))
			hi = hi.max(Vector2(w.mount.x + w.width, w.mount.z + w.radius))
	return Rect2(lo - Vector2.ONE, hi - lo + Vector2.ONE * 2.0)


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
