class_name Vehicle
extends RigidBody3D
## A truck on raycast suspension.
## Snow and mud add rolling resistance and cut grip. An open differential limits
## both wheels of an axle to the worse grip of the two; the lock lets each use its own.

const WHEEL_RADIUS := 0.5
const REST_LENGTH := 0.5
const SPRING_K := 32000.0
const DAMPING := 3800.0
const ANTI_ROLL := 16000.0
const ENGINE_FORCE := 12000.0
const LOW_RANGE_MULT := 1.8
const MAX_SPEED_HIGH := 18.0
const MAX_SPEED_LOW := 5.5
const MAX_SPEED_REVERSE := 5.0
const MAX_STEER := 0.6
const STEER_SPEED := 2.2
const BASE_MASS := 2000.0
const CARGO_MASS := 900.0
const HEAVY_MASS := 1800.0
const FUEL_CAPACITY := 80.0
const SLIP_SPIN := 14.0
const AUTODRIVE_LOOK := 10.0

const BODY_COLOR := Color(0.9, 0.62, 0.16)
const DARK := Color(0.12, 0.12, 0.13)
const GLASS := Color(0.13, 0.17, 0.24)


class Wheel:
	var mount: Vector3
	var front: bool
	var pivot: Node3D
	var spin: Node3D
	var spray: CPUParticles3D
	var contact := false
	var compression := 0.0
	var dist := 0.0
	var load := 0.0
	var point := Vector3.ZERO
	var normal := Vector3.UP
	var surface := Terrain.Surface.new()
	var traction := 0.0
	var allowed := 0.0
	var request := 0.0
	var spin_angle := 0.0
	var spin_speed := 0.0
	var slip := false


var terrain: Terrain
var awd := false
var diff_lock := false
var low_range := false
var has_cargo := false
var cargo := ""  # what is on the bed (a job's kind: plain, timed, fragile, heavy); "" nothing
var fuel := FUEL_CAPACITY
var autodrive := false
var autodrive_path := PackedVector2Array()
var autodrive_speed := 9.0
var _autodrive_index := 0
var _autodrive_from := Vector2.ZERO
var forward_speed := 0.0
var drive := 0.0  # what the engine gives this tick, -1..1: the throttle, none on an empty tank

var throttle_input := 0.0
var steer_input := 0.0
var handbrake := false

var wheels: Array[Wheel] = []
var winch: Winch
var audio: TruckAudio
var _steer := 0.0
var _reset_requested := false
var teleports := 0  # how many times teleport() has moved the truck: no jolt, a jump
var _reset_transform := Transform3D()
var _loads := {}  # look -> its node on the bed: crates, fragile, heavy
var _lights: Array[SpotLight3D] = []


func _ready() -> void:
	mass = BASE_MASS
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.1, 0.0)
	can_sleep = false
	angular_damp = 0.4
	_build_body()
	winch = Winch.new()
	winch.vehicle = self
	add_child(winch)
	for m in [Vector3(-0.95, 0.2, -1.55), Vector3(0.95, 0.2, -1.55), Vector3(-0.95, 0.2, 1.45), Vector3(0.95, 0.2, 1.45)]:
		_add_wheel(m)
	audio = TruckAudio.new()
	audio.vehicle = self
	add_child(audio)


func set_cargo(on: bool, kind := "plain") -> void:
	has_cargo = on
	cargo = kind if on else ""
	mass = BASE_MASS + ((HEAVY_MASS if kind == "heavy" else CARGO_MASS) if on else 0.0)
	var look: String = kind if kind in _loads else "crates"
	for k in _loads:
		_loads[k].visible = on and k == look


func set_lights(on: bool) -> void:
	for l in _lights:
		l.visible = on


func teleport(pos: Vector3, yaw: float) -> void:
	winch.detach()
	_reset_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	_reset_requested = true


func reset_upright() -> void:
	var p := global_position
	if terrain:
		p.y = terrain.get_height(p.x, p.z) + 2.0
	teleport(p, global_rotation.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_awd"):
		awd = not awd
	elif event.is_action_pressed("toggle_diff"):
		diff_lock = not diff_lock
	elif event.is_action_pressed("toggle_low"):
		low_range = not low_range
	elif event.is_action_pressed("toggle_lights"):
		set_lights(not _lights[0].visible)
	elif event.is_action_pressed("winch"):
		winch.toggle()
	elif event.is_action_pressed("reset"):
		reset_upright()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_requested:
		_reset_requested = false
		teleports += 1
		state.transform = _reset_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_read_input()
	var basis := global_transform.basis
	forward_speed = -linear_velocity.dot(basis.z)
	var steer_limit := lerpf(MAX_STEER, 0.25, clampf(absf(forward_speed) / MAX_SPEED_HIGH, 0.0, 1.0))
	_steer = move_toward(_steer, steer_input * steer_limit, STEER_SPEED * delta)

	drive = 0.0
	var brake := 0.0
	if handbrake:
		brake = 1.0
	elif throttle_input > 0.05:
		if forward_speed < -0.8:
			brake = 1.0
		else:
			drive = throttle_input
	elif throttle_input < -0.05:
		if forward_speed > 0.8:
			brake = 1.0
		else:
			drive = throttle_input
	elif absf(forward_speed) < 0.8 and not (winch.reeling and winch.anchor_body == null):
		brake = 1.0  # hold on a slope; let the winch pull the truck, but hold it while it pulls a car
	if fuel <= 0.0:
		drive = 0.0

	var vmax := MAX_SPEED_REVERSE if drive < 0.0 else (MAX_SPEED_LOW if low_range else MAX_SPEED_HIGH)
	var engine := ENGINE_FORCE * (LOW_RANGE_MULT if low_range else 1.0)
	var total_drive := drive * engine * clampf(1.0 - absf(forward_speed) / vmax, 0.0, 1.0)

	var space := get_world_3d().direct_space_state
	for w in wheels:
		_update_suspension(w, space, basis.y, delta)
	_apply_anti_roll(wheels[0], wheels[1], basis.y)
	_apply_anti_roll(wheels[2], wheels[3], basis.y)

	# Split the torque between the wheels.
	var driven := 0
	for w in wheels:
		w.traction = w.load * w.surface.grip if w.contact else 0.0
		if awd or not w.front:
			driven += 1
	for w in wheels:
		w.request = total_drive / driven if (awd or not w.front) else 0.0
	for axle in [[0, 1], [2, 3]]:
		var a: Wheel = wheels[axle[0]]
		var b: Wheel = wheels[axle[1]]
		if diff_lock:
			a.allowed = a.traction
			b.allowed = b.traction
		else:
			var m := minf(a.traction, b.traction)
			a.allowed = m
			b.allowed = m

	for w in wheels:
		_apply_tire(w, brake, delta)

	var burn := 0.04 + absf(drive) * 0.45 * (1.2 if awd else 1.0) * (1.15 if low_range else 1.0) * (1.5 if cargo == "heavy" else 1.0)
	fuel = maxf(fuel - burn * delta, 0.0)


func _process(delta: float) -> void:
	var up := global_transform.basis.y
	for w in wheels:
		w.pivot.position = w.mount + Vector3(0.0, -(w.dist - WHEEL_RADIUS), 0.0)
		if w.front:
			w.pivot.rotation.y = _steer
		w.spin_angle = wrapf(w.spin_angle + w.spin_speed * delta, -PI, PI)
		w.spin.rotation.x = -w.spin_angle
		var spraying := w.contact and w.slip and (w.surface.snow > 0.05 or w.surface.mud > 0.1)
		w.spray.emitting = spraying
		if spraying:
			w.spray.global_position = w.point + up * 0.15
			w.spray.direction = Vector3(0.0, 1.0, 1.2 * signf(w.request))
			w.spray.color = Color(0.3, 0.22, 0.15) if w.surface.mud > w.surface.snow else _layer_spray()


## What flies off a spinning wheel that is not mud: snow, sand or dust, as the valley has it.
func _layer_spray() -> Color:
	return terrain.valley.layer_color.lightened(0.15) if terrain else Color(0.9, 0.93, 1.0)


func _read_input() -> void:
	if autodrive:
		_autodrive_input()
		return
	throttle_input = Input.get_axis("brake", "accelerate")
	steer_input = Input.get_axis("steer_right", "steer_left")
	handbrake = Input.is_action_pressed("handbrake")


## Starts the test autopilot along path (points on the XZ plane) at up to speed m/s.
func drive_along(path: PackedVector2Array, speed := 9.0) -> void:
	autodrive_path = path
	autodrive_speed = speed
	_autodrive_index = 0
	_autodrive_from = Vector2(global_position.x, global_position.z)
	autodrive = true


## Test autopilot (frame captures, the trailer, tests): steers at a point a few metres ahead
## on autodrive_path, slows down for bends and slippery ground, and stops at the last point.
func _autodrive_input() -> void:
	handbrake = false
	var path := autodrive_path
	var pos := Vector2(global_position.x, global_position.z)
	# A waypoint is passed when we are at it, or beyond it along the leg that led to it.
	while _autodrive_index < path.size():
		var wp := path[_autodrive_index]
		var from := path[_autodrive_index - 1] if _autodrive_index > 0 else _autodrive_from
		var passed := pos.distance_to(wp) < 3.0
		if _autodrive_index < path.size() - 1:
			passed = passed or (pos - wp).dot(wp - from) > 0.0
		if not passed:
			break
		_autodrive_index += 1
	if _autodrive_index >= path.size():
		throttle_input = 0.0
		steer_input = 0.0
		return

	var wp := path[_autodrive_index]
	var to_wp := pos.distance_to(wp)
	var last := _autodrive_index == path.size() - 1
	var target := wp
	if to_wp < AUTODRIVE_LOOK and not last:
		var next := path[_autodrive_index + 1]
		target = wp + (next - wp).normalized() * minf(AUTODRIVE_LOOK - to_wp, wp.distance_to(next))
	var fwd := Vector2(-global_transform.basis.z.x, -global_transform.basis.z.z)
	var angle := fwd.angle_to(target - pos)
	steer_input = clampf(-angle * 1.6, -1.0, 1.0)

	var v := autodrive_speed
	if not last:  # ease off before a sharp bend: how far the road turns over the next 15 m
		var from := path[_autodrive_index - 1] if _autodrive_index > 0 else _autodrive_from
		var ahead := wp
		var left := 15.0
		for i in range(_autodrive_index + 1, path.size()):
			var step := path[i - 1].distance_to(path[i])
			ahead = path[i - 1].lerp(path[i], minf(left / maxf(step, 0.001), 1.0))
			left -= step
			if left <= 0.0:
				break
		var bend := absf((wp - from).angle_to(ahead - wp))
		var bend_v := lerpf(autodrive_speed, 4.0, clampf(bend / 1.2, 0.0, 1.0))
		v = lerpf(bend_v, v, clampf((to_wp - 6.0) / 25.0, 0.0, 1.0))
	else:
		v = minf(v, to_wp * 0.4)
	var grip := 0.0
	for w in wheels:
		grip += w.surface.grip
	v *= clampf(grip / wheels.size(), 0.5, 1.0) * clampf(1.0 - absf(angle) * 0.8, 0.35, 1.0)
	var err := v - forward_speed
	throttle_input = -0.6 if err < -1.5 else clampf(err * 0.5, 0.0, 1.0)


func _update_suspension(w: Wheel, space: PhysicsDirectSpaceState3D, up: Vector3, delta: float) -> void:
	var origin := global_transform * w.mount
	var ray_len := REST_LENGTH + WHEEL_RADIUS
	var q := PhysicsRayQueryParameters3D.create(origin, origin - up * ray_len)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var prev := w.compression
	if hit.is_empty():
		w.contact = false
		w.compression = 0.0
		w.dist = ray_len
		w.load = 0.0
		return
	w.contact = true
	w.point = hit.position
	w.normal = hit.normal
	w.dist = origin.distance_to(w.point)
	w.compression = ray_len - w.dist
	if terrain:
		w.surface = terrain.sample(w.point)
	var comp_vel := clampf((w.compression - prev) / delta, -5.0, 5.0)
	w.load = maxf(SPRING_K * w.compression + DAMPING * comp_vel, 0.0)
	apply_force(up * w.load, w.point - global_position)


func _apply_anti_roll(a: Wheel, b: Wheel, up: Vector3) -> void:
	if not (a.contact and b.contact):
		return
	var f := (a.compression - b.compression) * ANTI_ROLL
	apply_force(up * f, global_transform * a.mount - global_position)
	apply_force(-up * f, global_transform * b.mount - global_position)


func _apply_tire(w: Wheel, brake: float, delta: float) -> void:
	w.slip = false
	if not w.contact:
		var free_spin := signf(w.request) * SLIP_SPIN if w.request != 0.0 else 0.0
		w.spin_speed = lerpf(w.spin_speed, free_spin, delta * 3.0)
		return
	var basis := global_transform.basis
	var steer := _steer if w.front else 0.0
	var n := w.normal
	var fwd := (-basis.z).rotated(basis.y, steer)
	var right := basis.x.rotated(basis.y, steer)
	fwd = (fwd - n * fwd.dot(n)).normalized()
	right = (right - n * right.dot(n)).normalized()
	var vel := point_velocity(w.point)
	var v_long := vel.dot(fwd)
	var v_lat := vel.dot(right)
	var wheel_mass := mass * 0.25

	var f_long := 0.0
	if brake > 0.0:
		f_long = -v_long * wheel_mass / delta * brake
	elif w.request != 0.0:
		if absf(w.request) > w.allowed:
			w.slip = true
			f_long = signf(w.request) * w.allowed * 0.85
		else:
			f_long = w.request
	var f_lat := -v_lat * wheel_mass / delta * 0.5

	var tire := Vector2(f_long, f_lat)
	if tire.length() > w.traction:
		tire = tire.normalized() * w.traction
	var roll := w.surface.rolling * w.load * clampf(v_long * 8.0, -1.0, 1.0)
	apply_force(fwd * (tire.x - roll) + right * tire.y, w.point - global_position)

	w.spin_speed = signf(w.request) * SLIP_SPIN if w.slip else v_long / WHEEL_RADIUS
	if terrain and (w.surface.snow > 0.02 or w.surface.mud > 0.05):
		terrain.compact(w.point, 0.08 if w.slip else 0.25)


func point_velocity(p: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(p - global_transform * center_of_mass)


func _build_body() -> void:
	_add_box_shape(Vector3(1.9, 1.0, 4.5), Vector3(0.0, 0.3, 0.0))
	_add_box_shape(Vector3(1.9, 0.5, 1.4), Vector3(0.0, 1.03, -0.5))

	var gfx := Node3D.new()
	add_child(gfx)
	Psx.box(gfx, Vector3(1.5, 0.25, 4.4), Vector3(0.0, -0.05, 0.0), DARK)
	Psx.box(gfx, Vector3(1.8, 0.6, 1.0), Vector3(0.0, 0.4, -1.7), BODY_COLOR)
	Psx.box(gfx, Vector3(1.9, 1.15, 1.4), Vector3(0.0, 0.7, -0.5), BODY_COLOR)
	Psx.box(gfx, Vector3(1.6, 0.5, 0.04), Vector3(0.0, 0.95, -1.21), GLASS)
	for side in [-1.0, 1.0]:
		Psx.box(gfx, Vector3(0.04, 0.45, 1.0), Vector3(0.96 * side, 0.95, -0.5), GLASS)
		Psx.box(gfx, Vector3(0.1, 0.5, 2.0), Vector3(0.9 * side, 0.5, 1.2), BODY_COLOR)
		Psx.box(gfx, Vector3(0.35, 0.2, 0.05), Vector3(0.6 * side, 0.45, -2.22), Color(1.0, 0.95, 0.75), 2.0)
		Psx.box(gfx, Vector3(0.25, 0.15, 0.05), Vector3(0.8 * side, 0.5, 2.22), Color(0.9, 0.1, 0.05), 1.5)
		Psx.box(gfx, Vector3(0.5, 0.12, 1.1), Vector3(0.95 * side, 0.42, -1.55), DARK)
		Psx.box(gfx, Vector3(0.5, 0.12, 1.1), Vector3(0.95 * side, 0.42, 1.45), DARK)
	Psx.box(gfx, Vector3(1.9, 0.15, 2.0), Vector3(0.0, 0.2, 1.2), DARK)
	Psx.box(gfx, Vector3(1.9, 0.5, 0.1), Vector3(0.0, 0.5, 2.15), BODY_COLOR)
	Psx.box(gfx, Vector3(2.0, 0.25, 0.2), Vector3(0.0, 0.15, -2.25), Color(0.4, 0.4, 0.42))
	Psx.box(gfx, Vector3(0.3, 0.12, 0.3), Vector3(0.0, 1.35, -0.5), Color(1.0, 0.5, 0.1), 2.0)

	var crates := Node3D.new()
	Psx.box(crates, Vector3(1.5, 0.9, 1.7), Vector3(0.0, 0.75, 1.2), Color(0.55, 0.38, 0.2))
	Psx.box(crates, Vector3(1.55, 0.08, 0.15), Vector3(0.0, 1.2, 0.8), DARK)
	Psx.box(crates, Vector3(1.55, 0.08, 0.15), Vector3(0.0, 1.2, 1.6), DARK)
	# Fragile: smaller crates, strapped, red and white.
	var fragile := Node3D.new()
	for i in 2:
		var z := 0.75 + i * 0.9
		Psx.box(fragile, Vector3(1.3, 0.7, 0.75), Vector3(0.0, 0.65, z), Color(0.86, 0.84, 0.78))
		Psx.box(fragile, Vector3(1.32, 0.14, 0.77), Vector3(0.0, 0.75, z), Color(0.85, 0.15, 0.1))
	Psx.box(fragile, Vector3(0.06, 0.9, 1.9), Vector3(0.0, 0.6, 1.2), DARK)
	# Heavy: two concrete rings lying on the bed.
	var heavy := Node3D.new()
	for i in 2:
		var ring := Psx.mesh(heavy, Psx.cylinder(0.72, 0.72, 0.8, 10), Vector3(0.0, 1.02, 0.75 + i * 0.9), Color(0.62, 0.62, 0.6))
		ring.rotation.x = PI * 0.5
		Psx.mesh(heavy, Psx.cylinder(0.5, 0.5, 0.82, 10), Vector3(0.0, 1.02, 0.75 + i * 0.9), DARK).rotation.x = PI * 0.5
	_loads = {"crates": crates, "fragile": fragile, "heavy": heavy}
	for k in _loads:
		gfx.add_child(_loads[k])
		_loads[k].visible = false

	for side in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(0.6 * side, 0.45, -2.3)
		l.rotation.x = -0.08
		l.light_color = Color(1.0, 0.88, 0.65)
		l.light_energy = 4.0
		l.spot_range = 32.0
		l.spot_angle = 38.0
		add_child(l)
		_lights.append(l)


func _add_box_shape(size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)


func _add_wheel(mount: Vector3) -> void:
	var w := Wheel.new()
	w.mount = mount
	w.front = mount.z < 0.0
	w.dist = REST_LENGTH + WHEEL_RADIUS
	w.pivot = Node3D.new()
	w.pivot.position = mount
	add_child(w.pivot)
	w.spin = Node3D.new()
	w.pivot.add_child(w.spin)
	var tire := Psx.mesh(w.spin, Psx.cylinder(WHEEL_RADIUS, WHEEL_RADIUS, 0.42, 10), Vector3.ZERO, DARK)
	tire.rotation.z = PI * 0.5
	var rim := Psx.mesh(w.spin, Psx.cylinder(0.28, 0.28, 0.44, 8), Vector3.ZERO, Color(0.55, 0.55, 0.58))
	rim.rotation.z = PI * 0.5
	Psx.box(w.spin, Vector3(0.46, 0.08, 0.2), Vector3(0.0, 0.18, 0.0), Color(0.75, 0.3, 0.1))

	w.spray = CPUParticles3D.new()
	w.spray.emitting = false
	w.spray.amount = 24
	w.spray.lifetime = 0.7
	w.spray.local_coords = false
	w.spray.spread = 25.0
	w.spray.initial_velocity_min = 2.5
	w.spray.initial_velocity_max = 4.5
	w.spray.gravity = Vector3(0.0, -9.8, 0.0)
	w.spray.scale_amount_min = 0.6
	w.spray.scale_amount_max = 1.2
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.12
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	bm.material = m
	w.spray.mesh = bm
	add_child(w.spray)
	wheels.append(w)
