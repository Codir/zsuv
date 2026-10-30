class_name Vehicle
extends Chassis
## A truck on raycast wheels (Chassis), built from its TruckSpec: the engine, the drive train
## (2WD or all wheels, open or locked differentials, low range), the brakes, the fuel, the winch,
## the loads on its bed. An open differential limits both wheels of an axle to the worse grip of
## the two; the lock lets each use its own.

const AUTODRIVE_LOOK := 10.0
const BODY_COLOR := Color(0.9, 0.62, 0.16)
const GLASS := Color(0.13, 0.17, 0.24)
const HITCH_REACH := 1.0  # m from the hitch to a trailer's coupler for C to couple them
const HITCH_SLOW := 1.5  # m/s: C hitches and unhitches only this slow
# The hitch's joint: its X up (the trailer swings behind), its Y back along the truck (roll),
# its Z across (pitch); a joint's X turns furthest.
const HITCH_AXES := Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT)
const HITCH_YAW := 85.0 * PI / 180.0
const HITCH_PITCH := 30.0 * PI / 180.0
const HITCH_ROLL := 10.0 * PI / 180.0


var spec: TruckSpec  # set before the truck enters the tree; the pickup if not
var awd := false
var diff_lock := false
var low_range := false
var has_cargo := false
var cargo := ""  # what is on the bed (a job's kind: plain, timed, fragile, heavy); "" nothing
var fuel := 0.0  # a full tank once in the tree
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

var winch: Winch
var audio: TruckAudio
var trailer: Trailer  # hitched to it; null: none
var braking := 0.0  # how hard its brakes hold this tick, 0..1 (a hitched trailer's follow)
var _reset_requested := false
var teleports := 0  # how many times teleport() has moved the truck: no jolt, a jump
var _reset_transform := Transform3D()
var _loads := {}  # look -> its node on the bed: crates, fragile, heavy
var _lights: Array[SpotLight3D] = []
var _joint := RID()  # the hitch's, while a trailer is hitched


func _ready() -> void:
	if spec == null:
		spec = TruckSpec.pickup()
	mass = spec.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = spec.center_of_mass
	can_sleep = false
	angular_damp = 0.4
	rest_length = spec.rest_length
	spring_k = spec.spring_k
	damping = spec.damping
	anti_roll = spec.anti_roll
	fuel = spec.fuel_capacity
	for b in spec.shapes:
		_add_box_shape(b.size, b.pos)
	call("_build_" + spec.body)
	for l in spec.lights:
		_add_light(l)
	winch = Winch.new()
	winch.vehicle = self
	winch.mount = spec.winch_mount
	add_child(winch)
	for w in spec.wheels:
		_add_wheel(w.mount, w.radius, w.width, w.steer, w.drive2)
	axles = spec.axles
	audio = TruckAudio.new()
	audio.vehicle = self
	add_child(audio)


func set_cargo(on: bool, kind := "plain") -> void:
	has_cargo = on
	cargo = kind if on else ""
	mass = spec.mass + (float(spec.cargo_mass.get(kind, spec.cargo_mass.get("plain", 0.0))) if on else 0.0)
	var look: String = kind if kind in _loads else "crates"
	for k in _loads:
		_loads[k].visible = on and k == look


func set_lights(on: bool) -> void:
	for l in _lights:
		l.visible = on


## Moves the truck to pos facing yaw at the next physics step, standing still; a hitched trailer
## goes with it, straight behind and still hitched.
func teleport(pos: Vector3, yaw: float) -> void:
	winch.detach()
	_reset_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	_reset_requested = true
	if trailer:
		trailer.place(trailer.behind(Transform3D(_reset_transform.basis, _reset_transform * spec.hitch)))


func reset_upright() -> void:
	var p := global_position
	if terrain:
		p.y = terrain.get_height(p.x, p.z) + 2.0
	teleport(p, global_rotation.y)


## Where its hitch is now.
func hitch_point() -> Vector3:
	return global_transform * spec.hitch


## The trailer whose coupler is within reach of the hitch, of a kind this truck tows: the nearest,
## or null (none, or one is hitched already).
func hitch_candidate() -> Trailer:
	if trailer or spec.hitch_kind == "":
		return null
	var at := hitch_point()
	var best: Trailer = null
	var best_d := HITCH_REACH
	for n in get_tree().get_nodes_in_group(Trailer.GROUP):
		var t := n as Trailer
		if t.truck or t.spec.hitch_kind != spec.hitch_kind or not spec.tows.has(t.spec.id) or t.get_world_3d() != get_world_3d():
			continue
		var d := at.distance_to(t.coupler_point())
		if d < best_d:
			best = t
			best_d = d
	return best


## C: hitches the trailer in reach, or unhitches the one hitched; only when slow.
func toggle_hitch() -> void:
	if absf(forward_speed) >= HITCH_SLOW:
		return
	if trailer:
		unhitch()
	else:
		var t := hitch_candidate()
		if t:
			hitch(t)


## Couples t: the trailer swung onto the hitch first, then a joint there, free to turn up to
## HITCH_YAW either way and to pitch HITCH_PITCH, held within HITCH_ROLL; the two pass through each
## other, and their wheels' rays too.
func hitch(t: Trailer) -> void:
	unhitch()
	t.meet(hitch_point(), global_transform.basis, point_velocity(hitch_point()))
	_joint = PhysicsServer3D.joint_create()
	# The joint's pitch and roll are about its first body's axes: a fifth wheel's plate tilts across
	# the truck, a drawbar pitches and rolls with its trailer however far round it has swung.
	var on_truck := Transform3D(HITCH_AXES, spec.hitch)
	var on_trailer := Transform3D(HITCH_AXES, t.spec.coupler)
	if spec.hitch_kind == "fifth":
		PhysicsServer3D.joint_make_generic_6dof(_joint, get_rid(), on_truck, t.get_rid(), on_trailer)
	else:
		PhysicsServer3D.joint_make_generic_6dof(_joint, t.get_rid(), on_trailer, get_rid(), on_truck)
	var turn := {Vector3.AXIS_X: HITCH_YAW, Vector3.AXIS_Y: HITCH_ROLL, Vector3.AXIS_Z: HITCH_PITCH}
	for axis: int in turn:
		PhysicsServer3D.generic_6dof_joint_set_flag(_joint, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT, true)
		PhysicsServer3D.generic_6dof_joint_set_param(_joint, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_param(_joint, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_flag(_joint, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
		PhysicsServer3D.generic_6dof_joint_set_param(_joint, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT, -float(turn[axis]))
		PhysicsServer3D.generic_6dof_joint_set_param(_joint, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT, float(turn[axis]))
	# Not the joint's own "no collisions between its bodies": with Jolt that leaves the two
	# passing through each other for good once the joint is gone. Trailer.couple sees to it.
	trailer = t
	t.couple(self)


## Lets the trailer go: it stands on its stand where it is.
func unhitch() -> void:
	if trailer == null:
		return
	PhysicsServer3D.free_rid(_joint)
	_joint = RID()
	var t := trailer
	trailer = null
	t.uncouple()


## What C does here, for the HUD's bottom line ("" nothing).
func hitch_prompt() -> String:
	if absf(forward_speed) >= HITCH_SLOW:
		return ""
	if trailer:
		return "[C] Unhitch"
	var t := hitch_candidate()
	return "[C] Hitch the %s" % t.spec.title.to_lower() if t else ""


## The HUD's bottom line: what the jobs ask (or else what the winch offers), and beside it what
## the hitch does; a trailer waits at the depot beside the job board.
func prompt_with(jobs: String) -> String:
	var first := jobs if jobs != "" else winch.prompt()
	var c := hitch_prompt()
	return first + ("   " if first != "" and c != "" else "") + c


## What a wheel's ray must not hit: the truck and the trailer hitched to it.
func _ray_exclude() -> Array[RID]:
	return [get_rid(), trailer.get_rid()] if trailer else [get_rid()]


func _exit_tree() -> void:
	unhitch()


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
	elif event.is_action_pressed("hitch"):
		toggle_hitch()
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
	var steer_limit := lerpf(spec.max_steer, 0.25, clampf(absf(forward_speed) / spec.max_speed_high, 0.0, 1.0))
	steer = move_toward(steer, steer_input * steer_limit, spec.steer_speed * delta)

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

	var vmax := spec.max_speed_reverse if drive < 0.0 else (spec.max_speed_low if low_range else spec.max_speed_high)
	var engine := spec.engine_force * (spec.low_mult if low_range else 1.0)
	var total_drive := drive * engine * clampf(1.0 - absf(forward_speed) / vmax, 0.0, 1.0)

	_update_wheels(delta)

	# Split the torque between the wheels.
	var driven := 0
	for w in wheels:
		if awd or w.drive2:
			driven += 1
	for w in wheels:
		w.request = total_drive / driven if (awd or w.drive2) else 0.0
	for axle in axles:
		var a: Wheel = wheels[axle.x]
		var b: Wheel = wheels[axle.y]
		if diff_lock:
			a.allowed = a.traction
			b.allowed = b.traction
		else:
			var m := minf(a.traction, b.traction)
			a.allowed = m
			b.allowed = m

	braking = brake
	for w in wheels:
		_apply_tire(w, brake, delta)

	var burn := 0.04 + absf(drive) * 0.45 * spec.burn * (1.2 if awd else 1.0) * (1.15 if low_range else 1.0) * (1.5 if cargo == "heavy" else 1.0)
	fuel = maxf(fuel - burn * delta, 0.0)


func _process(delta: float) -> void:
	_animate_wheels(delta)


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


## The pickup's look (TruckSpec.body "pickup"): an orange cab and bed, the loads on the bed.
func _build_pickup() -> void:
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


## A headlight at pos, in the body's frame, shining ahead.
func _add_light(pos: Vector3) -> void:
	var l := SpotLight3D.new()
	l.position = pos
	l.rotation.x = -0.08
	l.light_color = Color(1.0, 0.88, 0.65)
	l.light_energy = 4.0
	l.spot_range = 32.0
	l.spot_angle = 38.0
	add_child(l)
	_lights.append(l)
