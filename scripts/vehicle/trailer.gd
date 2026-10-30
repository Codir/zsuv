class_name Trailer
extends Chassis
## A trailer on raycast wheels (Chassis), built from its TrailerSpec. Unhitched it stands on its
## wheels and, at the front, on its stand, its brakes on; hitched to a truck (Vehicle.trailer,
## Vehicle.hitch), its brakes follow the truck's and its stand is wound up. A load on it adds its
## weight and shows.
## Braked and standing, each wheel and the stand hold the spot they stand on as far as their grip
## lets them (a stiff spring to it): a parked trailer stays put on a slope, where brakes that only
## stop a wheel turning would let it creep away a few centimetres a second.

const GROUP := "trailers"
const STAND_TRAVEL := 0.6
const STAND_GRIP := 0.8  # the stand's foot on the ground, times the ground's grip
const HOLD_RATE := 150.0  # a held wheel's spring to its spot, per kg it carries: about 2 Hz
const HOLD_DAMP := 20.0
const HOLD_SPEED := 0.5  # m/s: hitched, the truck's brakes hold the trailer where it is below this
const MAX_TIP := 25.0 * PI / 180.0  # put behind a truck, as far as it tips over rising ground
const DROOP := 0.2  # how much further a bogie's wheel drops into a dip than its spring lets out
const NO_SPOT := Vector3.INF

var spec: TrailerSpec  # set before it enters the tree; the pickup's trailer if not
var truck: Vehicle  # hitched to; null: standing on its own
var load := ""  # the kind of load on it; "" none
var stand_contact := false  # unhitched, its stand is on the ground
var _loads := {}  # look -> its node: a kind of load ("bulk"), or another look of it ("bulk_peat")
var _stand_gfx: Node3D  # the jockey wheel, the prop or the legs' feet
var _stand_down := Transform3D()  # where they are standing and wound up
var _stand_up := Transform3D()
var _spots: Array[Vector3] = []  # per wheel, then the stand: the spot it holds, NO_SPOT none
var _place_requested := false
var _place := Transform3D()
var _place_velocity := Vector3.ZERO
var _parting: Vehicle  # just unhitched from: the two pass through each other until apart


func _ready() -> void:
	if spec == null:
		spec = TrailerSpec.trailer()
	add_to_group(GROUP)
	mass = spec.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = spec.center_of_mass
	can_sleep = false
	angular_damp = 0.4
	rest_length = spec.rest_length
	spring_k = spec.spring_k
	damping = spec.damping
	anti_roll = spec.anti_roll
	for b in spec.shapes:
		_add_box_shape(b.size, b.pos)
	call("_build_" + spec.body)
	for w in spec.wheels:
		_add_wheel(w.mount, w.radius, w.width, false, false, spec.rim)
	axles = spec.axles
	_spots.resize(wheels.size() + 1)
	_spots.fill(NO_SPOT)


func _exit_tree() -> void:
	if truck:
		truck.unhitch()
	_part()


## A load of kind on it, or none (""); look picks another look of that kind ("long_pipes" for
## "long"), the kind's own if it has no such look.
func set_load(kind: String, look := "") -> void:
	load = kind
	mass = spec.mass + float(spec.cargo_mass.get(kind, 0.0))
	var shown := look if look in _loads else kind
	for k in _loads:
		_loads[k].visible = kind != "" and k == shown


## Where its coupler is now.
func coupler_point() -> Vector3:
	return global_transform * spec.coupler


## Hitched to v's hitch (Vehicle.hitch makes the joint): its brakes follow v's, and the two pass
## through each other while hitched.
func couple(v: Vehicle) -> void:
	_part()
	truck = v
	_spots.fill(NO_SPOT)
	add_collision_exception_with(v)
	v.add_collision_exception_with(self)


## Let go of by its truck (Vehicle.unhitch): on its stand again, passing through the truck until
## the two are apart, so a semi-trailer's deck does not knock the truck it sat on.
func uncouple() -> void:
	_parting = truck
	truck = null
	_spots.fill(NO_SPOT)


## Swings it about its wheels so its coupler comes onto the hitch at at (the drawbar lifted or
## lowered onto it), rolled no more than the joint allows from the truck's basis, moving with the
## hitch at velocity. It moves at the next physics step, before the joint made now is solved: the
## joint finds the two already together, and nothing jerks.
func meet(at: Vector3, basis: Basis, velocity: Vector3) -> void:
	var xf := global_transform
	var axle := _axle()
	var from := xf.basis * (spec.coupler - axle)
	var to := at - xf * axle
	var b := Basis(Quaternion(from.normalized(), to.normalized())) * xf.basis
	var roll := asin(clampf(b.x.dot(basis.y), -1.0, 1.0))
	var most := Vehicle.HITCH_ROLL * 0.5
	if absf(roll) > most:
		b = Basis(b.z, -signf(roll) * (absf(roll) - most)) * b
	b = b.orthonormalized()
	var a := at - b * (spec.coupler - axle)  # the axle slides as far as the drawbar falls short
	place(Transform3D(b, a - b * axle), velocity)


## Where it goes straight behind a truck whose hitch is at hitch (the truck's basis there): its
## coupler on it, lined up with the truck, tipped about the coupler as far as rising ground under
## its wheels asks (up to MAX_TIP).
func behind(hitch: Transform3D) -> Transform3D:
	var xf := Transform3D(hitch.basis, hitch.origin - hitch.basis * spec.coupler)
	if terrain == null:
		return xf
	var lift := 0.0
	for w in wheels:
		var bottom := xf * (w.mount - Vector3(0.0, rest_length + w.radius, 0.0))
		lift = maxf(lift, terrain.get_height(bottom.x, bottom.z) + 0.05 - bottom.y)
	if lift <= 0.0:
		return xf
	var tip := minf(asin(clampf(lift / (_axle().z - spec.coupler.z), 0.0, 1.0)), MAX_TIP)
	var b := Basis(hitch.basis.x, -tip) * hitch.basis
	return Transform3D(b, hitch.origin - b * spec.coupler)


## Whether it would stand at xf without running into anything but the ground and the truck.
func fits(xf: Transform3D, truck_too: Node = null) -> bool:
	var space := get_world_3d().direct_space_state
	var skip := _not_ground()
	if truck_too is CollisionObject3D:
		skip.append(truck_too.get_rid())
	for c in get_children():
		var cs := c as CollisionShape3D
		if cs == null:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cs.shape
		q.transform = xf * cs.transform
		q.exclude = skip
		if not space.intersect_shape(q, 1).is_empty():
			return false
	return true


## What a query for what it meets leaves out: itself, and the ground (met all over).
func _not_ground() -> Array[RID]:
	var out: Array[RID] = [get_rid()]
	if terrain and terrain.body:
		out.append(terrain.body.get_rid())
	return out


## Moves it to xf at the next physics step, moving at velocity, not turning (a teleport, as
## Vehicle.teleport: a rigid body's transform set between steps does not always reach the physics).
func place(xf: Transform3D, velocity := Vector3.ZERO) -> void:
	_place = xf
	_place_velocity = velocity
	_place_requested = true


## Stands it on the ground at at (its origin, on the map) facing yaw, on its wheels and its stand,
## tipped as the ground is there; it settles on its springs. In the tree, with its terrain.
func stand_on(at: Vector2, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var axle := _axle()
	var half := absf(spec.wheels[0].mount.x)
	var o := Vector3(at.x, 0.0, at.y)
	var g_axle := _ground_at(o + turn * Vector3(0.0, 0.0, axle.z))
	var g_stand := _ground_at(o + turn * Vector3(0.0, 0.0, spec.stand.z))
	var g_left := _ground_at(o + turn * Vector3(-half, 0.0, axle.z))
	var g_right := _ground_at(o + turn * Vector3(half, 0.0, axle.z))
	var pitch := atan2(g_stand.y - g_axle.y, axle.z - spec.stand.z)
	var roll := atan2(g_right.y - g_left.y, half * 2.0)
	var b := turn * Basis.from_euler(Vector3(pitch, 0.0, roll))
	# On its wheels as far down as its weight presses their springs: the wheels' share of it, as
	# its centre of mass lies between them and the stand.
	var share := clampf((center_of_mass.z - spec.stand.z) / (axle.z - spec.stand.z), 0.0, 1.0)
	var sink := mass * 9.8 * share / wheels.size() / spring_k
	var foot := Vector3(0.0, axle.y - rest_length - wheels[0].radius + sink, axle.z)
	place(Transform3D(b, g_axle + Vector3(0.0, 0.01, 0.0) - b * foot))


## How far the ground under its wheels lies off the plane stand_on(at, yaw) would set it on, the
## most of any wheel: 0 on even ground.
func unevenness(at: Vector2, yaw: float) -> float:
	var plane := _plane(at, yaw)
	var most := 0.0
	for w in spec.wheels:
		most = maxf(most, absf(_off_plane(at, yaw, plane, w.mount)))
	return most


## Whether a truck can back up to its coupler, standing at (at, yaw): the ground ahead of the
## coupler, as far as length, is no more than 0.15 m above the plane it stands on for the first 3 m
## (where the truck's back goes in under it) and within 0.7 m of it all along.
func reachable(at: Vector2, yaw: float, length: float) -> bool:
	var plane := _plane(at, yaw)
	for i in ceili(length) + 1:
		var z := spec.coupler.z - minf(float(i), length)
		for x in [-1.2, 0.0, 1.2]:
			var off := _off_plane(at, yaw, plane, Vector3(x, 0.0, z))
			if off > (0.15 if i <= 3 else 0.7) or off < -0.7:
				return false
	return true


## The plane stand_on(at, yaw) sets it on, through the ground at its stand and under the middle of
## its axles, rolled as the ground is there: its height under that middle, and how much it rises
## per metre back along it (y) and across it to the right (z).
func _plane(at: Vector2, yaw: float) -> Vector3:
	var turn := Basis(Vector3.UP, yaw)
	var axle := _axle()
	var half := absf(spec.wheels[0].mount.x)
	var o := Vector3(at.x, 0.0, at.y)
	var g_axle := _ground_at(o + turn * Vector3(0.0, 0.0, axle.z)).y
	var g_stand := _ground_at(o + turn * Vector3(0.0, 0.0, spec.stand.z)).y
	var g_left := _ground_at(o + turn * Vector3(-half, 0.0, axle.z)).y
	var g_right := _ground_at(o + turn * Vector3(half, 0.0, axle.z)).y
	return Vector3(g_axle, (g_axle - g_stand) / (axle.z - spec.stand.z), (g_right - g_left) / (half * 2.0))


## How far the ground at m (in its frame, standing at (at, yaw)) lies above plane.
func _off_plane(at: Vector2, yaw: float, plane: Vector3, m: Vector3) -> float:
	var ground := _ground_at(Vector3(at.x, 0.0, at.y) + Basis(Vector3.UP, yaw) * Vector3(m.x, 0.0, m.z)).y
	return ground - (plane.x + (m.z - _axle().z) * plane.y + m.x * plane.z)


func _ground_at(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.get_height(p.x, p.z) if terrain else 0.0, p.z)


## The middle of its wheels' mounts, in its frame.
func _axle() -> Vector3:
	var sum := Vector3.ZERO
	for w in spec.wheels:
		sum += w.mount
	return sum / spec.wheels.size()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _place_requested:
		_place_requested = false
		state.transform = _place
		state.linear_velocity = _place_velocity
		state.angular_velocity = Vector3.ZERO
		_spots.fill(NO_SPOT)


func _physics_process(delta: float) -> void:
	if _place_requested:
		return  # forces from where it stands now would land on it where it is going
	_update_wheels(delta)
	if _parting and not _touching(_parting):
		_part()
	var brake := truck.braking if truck else 1.0
	var held := truck == null or (brake >= 1.0 and linear_velocity.length() < HOLD_SPEED)
	for i in wheels.size():
		var w := wheels[i]
		w.request = 0.0
		w.allowed = w.traction
		if held and w.contact:
			_hold(i, w.point, w.normal, w.load, w.surface.grip)
			w.spin_speed = 0.0
		else:
			_spots[i] = NO_SPOT
			_apply_tire(w, brake, delta)
	if truck == null:
		_stand()
	else:
		stand_contact = false
		_spots[wheels.size()] = NO_SPOT


func _process(delta: float) -> void:
	_animate_wheels(delta)
	if _stand_gfx:
		_stand_gfx.transform = _stand_up if truck else _stand_down


## Springs, dampers and anti-roll as Chassis's, but where it has axles side by side (a bogie: the
## farm trailer's two, the semi-trailer's three) the wheels along each side share one beam, as a
## walking beam does: the side's springs push with the mean of its wheels' compressions, shared
## between the wheels on the ground, and a wheel over a dip drops up to DROOP further into it
## instead of hanging in the air. On even ground it is the same spring on every wheel.
func _update_wheels(delta: float) -> void:
	if axles.size() < 2:
		super(delta)
		return
	var space := get_world_3d().direct_space_state
	var up := global_transform.basis.y
	var prev := PackedFloat32Array()
	for w in wheels:
		prev.append(w.compression)
		_reach(w, space, up)
	for side in 2:
		var comp := 0.0
		var rate := 0.0
		var down := 0
		for a in axles:
			var i := a.x if side == 0 else a.y
			if wheels[i].contact:
				comp += wheels[i].compression
				rate += (wheels[i].compression - prev[i]) / delta
				down += 1
		if down == 0:
			continue
		# A spring a wheel, all on the beam's travel (the mean of the wheels'), shared by those down.
		var spring := spring_k * comp / down + damping * clampf(rate / down, -5.0, 5.0)
		var each := maxf(spring, 0.0) * axles.size() / down
		for a in axles:
			var w := wheels[a.x if side == 0 else a.y]
			if w.contact:
				w.load = each
				apply_force(up * each, w.point - global_position)
	for a in axles:
		_apply_anti_roll(wheels[a.x], wheels[a.y], up)
	for w in wheels:
		w.traction = w.load * w.surface.grip if w.contact else 0.0


## A wheel's ground, as far down as DROOP past where its spring lets out.
func _reach(w: Wheel, space: PhysicsDirectSpaceState3D, up: Vector3) -> void:
	var origin := global_transform * w.mount
	var ray_len := rest_length + w.radius
	var q := PhysicsRayQueryParameters3D.create(origin, origin - up * (ray_len + DROOP))
	q.exclude = _ray_exclude()
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		w.contact = false
		w.compression = -DROOP
		w.dist = ray_len + DROOP
		w.load = 0.0
		return
	w.contact = true
	w.point = hit.position
	w.normal = hit.normal
	w.dist = origin.distance_to(w.point)
	w.compression = ray_len - w.dist
	if terrain:
		w.surface = terrain.sample(w.point)


## What a wheel's ray must not hit: the trailer, and the truck it is hitched to or just left.
func _ray_exclude() -> Array[RID]:
	var out: Array[RID] = [get_rid()]
	if truck:
		out.append(truck.get_rid())
	if is_instance_valid(_parting):
		out.append(_parting.get_rid())
	return out


## Unhitched, the front rests on its stand: a stiff spring down to the ground, holding its spot.
func _stand() -> void:
	var i := wheels.size()
	var up := global_transform.basis.y
	var top := global_transform * (spec.stand + Vector3(0.0, STAND_TRAVEL, 0.0))
	var q := PhysicsRayQueryParameters3D.create(top, top - up * STAND_TRAVEL)
	q.exclude = _ray_exclude()
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	stand_contact = not hit.is_empty()
	if not stand_contact:
		_spots[i] = NO_SPOT
		return
	var p: Vector3 = hit.position
	var compression := STAND_TRAVEL - top.distance_to(p)
	var f := maxf(spec.stand_k * compression - spec.stand_damping * point_velocity(p).dot(up), 0.0)
	apply_force(up * f, p - global_position)
	_hold(i, p, hit.normal, f, (terrain.sample(p).grip if terrain else 1.0) * STAND_GRIP)


## Support i (a wheel, or the stand) at p on ground of normal n, carrying load_n newtons with grip,
## holds the spot it stopped on: a stiff spring along the ground to it, up to what its grip allows;
## past that it slides, the spot dragged along behind it, pulling with all its grip.
func _hold(i: int, p: Vector3, n: Vector3, load_n: float, grip: float) -> void:
	if _spots[i] == NO_SPOT or load_n <= 0.0:
		_spots[i] = p
	var held := load_n / 9.8  # the mass on it
	var off := p - _spots[i]
	off -= n * off.dot(n)
	var f := -(off * HOLD_RATE + point_velocity(p) * HOLD_DAMP) * held
	f -= n * f.dot(n)
	var most := load_n * grip
	if f.length() > most:
		f = f.normalized() * most
		var reach := most / (HOLD_RATE * held)  # how far off its spot the spring alone pulls that hard
		if off.length() > reach:
			_spots[i] = p - off.normalized() * reach
	apply_force(f, p - global_position)


## Whether body is in any of its boxes, or under one as far down as its stand reaches (a truck
## it was let go from, still under a semi-trailer's deck as the deck comes down).
func _touching(body: PhysicsBody3D) -> bool:
	if not is_instance_valid(body):
		return false
	var space := get_world_3d().direct_space_state
	for c in get_children():
		var cs := c as CollisionShape3D
		if cs == null:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cs.shape
		q.transform = cs.global_transform
		var box := cs.shape as BoxShape3D
		if box:
			var reach := maxf(cs.position.y - box.size.y * 0.5 - spec.stand.y, 0.0)
			var down := BoxShape3D.new()
			down.size = box.size + Vector3(0.0, reach, 0.0)
			q.shape = down
			q.transform = cs.global_transform.translated_local(Vector3(0.0, -reach * 0.5, 0.0))
		q.exclude = _not_ground()
		for hit in space.intersect_shape(q, 16):
			if hit.rid == body.get_rid():
				return true
	return false


## Apart from the truck it left: the two collide again.
func _part() -> void:
	if is_instance_valid(_parting):
		remove_collision_exception_with(_parting)
		_parting.remove_collision_exception_with(self)
	_parting = null


## The pickup's trailer: a galvanised box on one axle with mudguards, an A-frame drawbar to the
## ball coupler, a jockey wheel; a double load is crates in the box.
func _build_trailer() -> void:
	var steel := Color(0.6, 0.62, 0.63)
	var rail := Color(0.42, 0.44, 0.47)
	Psx.box(self, Vector3(1.5, 0.06, 2.25), Vector3(0.0, 0.03, -0.125), steel)
	for side in [-1.0, 1.0]:
		Psx.box(self, Vector3(0.04, 0.42, 2.25), Vector3(0.73 * side, 0.27, -0.125), steel)
		Psx.box(self, Vector3(0.07, 0.05, 2.29), Vector3(0.73 * side, 0.48, -0.125), rail)
		Psx.box(self, Vector3(0.08, 0.1, 2.2), Vector3(0.5 * side, -0.05, -0.15), DARK)
		Psx.box(self, Vector3(0.07, 0.06, 0.8), Vector3(0.62 * side, -0.13, 0.0), DARK)  # leaf spring
		Psx.box(self, Vector3(0.28, 0.04, 0.78), Vector3(0.9 * side, 0.15, 0.0), steel)  # mudguard
		Psx.box(self, Vector3(0.28, 0.18, 0.04), Vector3(0.9 * side, 0.06, -0.39), steel)
		Psx.box(self, Vector3(0.28, 0.18, 0.04), Vector3(0.9 * side, 0.06, 0.39), steel)
		Psx.box(self, Vector3(0.18, 0.09, 0.04), Vector3(0.55 * side, 0.02, 1.0), Color(0.9, 0.1, 0.05), 1.5)
		_bar(Vector3(0.5 * side, -0.05, -1.25), Vector3(0.04 * side, 0.08, -2.35), 0.07, DARK)
	for z in [-1.23, 0.98]:  # the front board and the tailgate
		Psx.box(self, Vector3(1.5, 0.42, 0.04), Vector3(0.0, 0.27, z), steel)
		Psx.box(self, Vector3(1.54, 0.05, 0.07), Vector3(0.0, 0.48, z), rail)
	Psx.box(self, Vector3(1.6, 0.06, 0.06), Vector3(0.0, -0.2, 0.0), DARK)  # axle
	Psx.box(self, Vector3(0.4, 0.11, 0.02), Vector3(0.0, 0.0, 1.01), Color(0.92, 0.9, 0.8))  # plate
	Psx.box(self, Vector3(0.13, 0.09, 0.32), Vector3(0.0, 0.11, -2.44), DARK)  # coupler
	Psx.box(self, Vector3(0.17, 0.08, 0.17), Vector3(0.0, 0.18, -2.55), Color(0.3, 0.3, 0.32))
	Psx.box(self, Vector3(0.05, 0.05, 0.14), Vector3(0.0, 0.2, -2.42), Color(0.75, 0.3, 0.1))  # its lever
	# The jockey wheel, wound up under the drawbar while hitched.
	_stand_gfx = Node3D.new()
	add_child(_stand_gfx)
	Psx.box(_stand_gfx, Vector3(0.07, 0.62, 0.07), Vector3(0.0, 0.42, 0.0), Color(0.3, 0.3, 0.32))
	Psx.box(_stand_gfx, Vector3(0.16, 0.05, 0.05), Vector3(0.0, 0.75, 0.0), Color(0.75, 0.3, 0.1))  # handle
	Psx.box(_stand_gfx, Vector3(0.1, 0.12, 0.04), Vector3(0.0, 0.12, 0.0), DARK)  # fork
	var jockey := Psx.mesh(_stand_gfx, Psx.cylinder(0.08, 0.08, 0.06, 8), Vector3(0.0, 0.08, 0.0), DARK)
	jockey.rotation.z = PI * 0.5
	_stand_down = Transform3D(Basis(), spec.stand)
	_stand_up = Transform3D(Basis(), spec.stand + Vector3(0.0, 0.25, 0.0))
	# A double load: crates two by two, one more on top, strapped down.
	var crates := _load("double")
	var wood := Color(0.55, 0.38, 0.2)
	for i in 2:
		for j in 2:
			Psx.box(crates, Vector3(0.66, 0.5, 1.0), Vector3(-0.35 + 0.7 * i, 0.31, -0.65 + 1.05 * j), wood)
	Psx.box(crates, Vector3(0.66, 0.42, 1.0), Vector3(-0.35, 0.77, -0.65), wood.darkened(0.15))
	Psx.box(crates, Vector3(1.46, 0.06, 0.1), Vector3(0.0, 0.58, -0.3), DARK)
	Psx.box(crates, Vector3(1.46, 0.06, 0.1), Vector3(0.0, 0.58, 0.6), DARK)


## The tractor's farm trailer, a 2PTS-4: a blue tipper box with ribbed sides and boards on top,
## on a red frame over two axles side by side, a drawbar to its eye, a prop; a bulk load is a heap
## of grain (or peat), or bales of hay.
func _build_farm() -> void:
	var blue := Color(0.2, 0.36, 0.6)
	var rib := Color(0.14, 0.26, 0.46)
	var board := Color(0.32, 0.47, 0.7)
	var red := Color(0.55, 0.13, 0.1)
	Psx.box(self, Vector3(2.3, 0.1, 4.0), Vector3(0.0, 0.05, 0.0), blue)
	for side in [-1.0, 1.0]:
		Psx.box(self, Vector3(0.05, 0.72, 4.0), Vector3(1.125 * side, 0.46, 0.0), blue)
		Psx.box(self, Vector3(0.05, 0.38, 4.0), Vector3(1.125 * side, 1.01, 0.0), board)
		Psx.box(self, Vector3(0.09, 0.07, 4.04), Vector3(1.16 * side, 0.82, 0.0), rib)
		Psx.box(self, Vector3(0.09, 0.06, 4.04), Vector3(1.16 * side, 1.2, 0.0), rib)
		for z in [-1.6, -0.8, 0.0, 0.8, 1.6]:
			Psx.box(self, Vector3(0.07, 0.72, 0.07), Vector3(1.16 * side, 0.46, z), rib)
		Psx.box(self, Vector3(0.14, 0.24, 4.4), Vector3(0.55 * side, -0.14, -0.2), red)
		Psx.box(self, Vector3(0.1, 0.12, 1.5), Vector3(0.62 * side, -0.62, 0.6), DARK)  # the bogie
		Psx.box(self, Vector3(0.1, 0.4, 0.1), Vector3(0.62 * side, -0.42, 0.6), DARK)
		Psx.box(self, Vector3(0.38, 0.04, 2.3), Vector3(0.82 * side, -0.2, 0.6), DARK)  # mudguard
		Psx.box(self, Vector3(0.22, 0.1, 0.04), Vector3(0.95 * side, 0.12, 2.03), Color(0.9, 0.1, 0.05), 1.5)
		_bar(Vector3(0.55 * side, -0.16, -2.3), Vector3(0.05 * side, -0.43, -3.38), 0.1, red)
	for z in [-1.975, 1.975]:  # the front and the tailgate
		Psx.box(self, Vector3(2.3, 1.1, 0.05), Vector3(0.0, 0.6, z), blue)
		Psx.box(self, Vector3(2.34, 0.07, 0.09), Vector3(0.0, 0.82, z + signf(z) * 0.035), rib)
		Psx.box(self, Vector3(2.34, 0.06, 0.09), Vector3(0.0, 1.2, z + signf(z) * 0.035), rib)
	for z in [-1.9, -0.6, 0.6, 1.9]:
		Psx.box(self, Vector3(1.24, 0.1, 0.1), Vector3(0.0, -0.15, z), red)
	for z in [0.0, 1.2]:
		Psx.box(self, Vector3(1.4, 0.09, 0.09), Vector3(0.0, -0.7, z), DARK)  # axles
	Psx.box(self, Vector3(0.4, 0.12, 0.02), Vector3(0.0, 0.2, 2.01), Color(0.92, 0.9, 0.8))  # plate
	var ram := Psx.mesh(self, Psx.cylinder(0.07, 0.09, 0.7, 6), Vector3(0.0, -0.3, -1.45), Color(0.3, 0.3, 0.32))
	ram.rotation.x = -1.1  # the tipping ram, folded under the front
	# The drawbar eye the tractor's pin drops through.
	Psx.box(self, Vector3(0.12, 0.08, 0.3), Vector3(0.0, -0.44, -3.3), red)
	Psx.mesh(self, Psx.cylinder(0.1, 0.1, 0.06, 8), spec.coupler, Color(0.3, 0.3, 0.32))
	Psx.mesh(self, Psx.cylinder(0.05, 0.05, 0.07, 8), spec.coupler, DARK)
	# The prop, folded up along the drawbar while hitched.
	_stand_gfx = Node3D.new()
	add_child(_stand_gfx)
	var top := Vector3(0.0, -0.33, spec.stand.z)
	Psx.box(_stand_gfx, Vector3(0.08, 0.84, 0.08), Vector3(0.0, -0.42, 0.0), red)
	Psx.box(_stand_gfx, Vector3(0.26, 0.04, 0.26), Vector3(0.0, spec.stand.y - top.y + 0.02, 0.0), DARK)
	_stand_down = Transform3D(Basis(), top)
	_stand_up = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), top)
	_load("bulk").add_child(_heap(Color(0.83, 0.68, 0.32)))
	_load("bulk_peat").add_child(_heap(Color(0.3, 0.2, 0.13)))
	var hay := _load("bulk_hay")
	var straw := Color(0.82, 0.74, 0.42)
	for layer in 3:
		for i in 4:
			for j in 4:
				if layer == 2 and (j == 0 or j == 3):
					continue
				var tint := straw.darkened(0.08 * ((i + j + layer) % 3))
				Psx.box(hay, Vector3(0.5, 0.4, 0.95), Vector3(-0.8 + 0.53 * i, 0.32 + 0.42 * layer, -1.47 + 0.98 * j), tint)


## The semi truck's flatbed: a plank deck on red beams, shallow over the fifth wheel at the front
## and deep behind it, a headboard, three axles under mudguards, landing legs; a long load is logs
## between stakes, or steel pipes.
func _build_semi_trailer() -> void:
	var frame := Color(0.5, 0.13, 0.1)
	var wood := Color(0.45, 0.33, 0.22)
	Psx.box(self, Vector3(2.4, 0.1, 12.0), Vector3(0.0, 0.15, 0.0), wood)
	for side in [-1.0, 1.0]:
		Psx.box(self, Vector3(0.1, 0.24, 12.0), Vector3(1.2 * side, 0.08, 0.0), frame)
		Psx.box(self, Vector3(0.14, 0.12, 2.6), Vector3(0.5 * side, -0.06, -4.7), frame)
		Psx.box(self, Vector3(0.14, 0.42, 9.4), Vector3(0.5 * side, -0.21, 1.3), frame)
		for i in 8:
			Psx.box(self, Vector3(0.13, 0.1, 0.12), Vector3(1.2 * side, 0.05, -5.4 + i * 1.55), DARK)
		Psx.box(self, Vector3(0.62, 0.05, 4.0), Vector3(0.95 * side, -0.12, 3.0), DARK)  # mudguard
		Psx.box(self, Vector3(0.6, 0.55, 0.03), Vector3(0.95 * side, -0.52, 5.0), DARK)  # mud flap
		Psx.box(self, Vector3(0.12, 0.25, 2.9), Vector3(0.62 * side, -0.32, 3.0), DARK)  # the bogie
		Psx.box(self, Vector3(0.3, 0.12, 0.04), Vector3(1.0 * side, -0.1, 6.0), Color(0.9, 0.1, 0.05), 1.5)
		Psx.box(self, Vector3(0.1, 0.1, 0.04), Vector3(1.18 * side, 0.08, 6.0), Color(1.0, 0.55, 0.1), 1.5)
		Psx.box(self, Vector3(0.12, 0.12, 0.12), Vector3(1.18 * side, 0.08, -0.5), Color(1.0, 0.55, 0.1), 1.2)
		Psx.box(self, Vector3(0.1, 0.65, 0.1), Vector3(1.0 * side, -0.5, 5.85), DARK)
		Psx.box(self, Vector3(0.16, 0.8, 0.16), Vector3(0.85 * side, -0.4, spec.stand.z), Color(0.3, 0.3, 0.32))
	for i in 6:
		Psx.box(self, Vector3(0.9, 0.08, 0.1), Vector3(0.0, -0.3, -2.0 + i * 1.5), frame)
	for z in [1.69, 3.0, 4.31]:
		Psx.box(self, Vector3(1.4, 0.1, 0.1), Vector3(0.0, -0.7, z), DARK)  # axles
	Psx.box(self, Vector3(2.4, 0.12, 0.14), Vector3(0.0, -0.8, 5.85), DARK)  # the rear guard
	Psx.box(self, Vector3(0.45, 0.12, 0.02), Vector3(0.0, -0.2, 6.01), Color(0.92, 0.9, 0.8))
	Psx.box(self, Vector3(2.4, 0.9, 0.08), Vector3(0.0, 0.65, -5.92), frame)  # headboard
	for x in [-0.8, 0.0, 0.8]:
		Psx.box(self, Vector3(0.1, 0.9, 0.1), Vector3(x, 0.65, -5.85), DARK)
	# The upper coupler plate and the kingpin under it.
	Psx.box(self, Vector3(1.3, 0.04, 1.8), Vector3(0.0, -0.02, spec.coupler.z), Color(0.3, 0.3, 0.32))
	Psx.mesh(self, Psx.cylinder(0.05, 0.05, 0.12, 8), spec.coupler + Vector3(0.0, -0.06, 0.0), Color(0.6, 0.6, 0.62))
	Psx.box(self, Vector3(1.7, 0.08, 0.08), Vector3(0.0, -0.55, spec.stand.z), Color(0.3, 0.3, 0.32))
	Psx.box(self, Vector3(0.05, 0.05, 0.3), Vector3(1.0, -0.3, spec.stand.z), Color(0.75, 0.3, 0.1))  # crank
	# The legs' inner tubes and feet, wound up while hitched.
	_stand_gfx = Node3D.new()
	add_child(_stand_gfx)
	for side in [-1.0, 1.0]:
		Psx.box(_stand_gfx, Vector3(0.11, 0.5, 0.11), Vector3(0.85 * side, 0.29, 0.0), Color(0.45, 0.45, 0.47))
		Psx.box(_stand_gfx, Vector3(0.32, 0.05, 0.32), Vector3(0.85 * side, 0.025, 0.0), DARK)
	_stand_down = Transform3D(Basis(), spec.stand)
	_stand_up = Transform3D(Basis(), spec.stand + Vector3(0.0, 0.35, 0.0))
	# Logs: nine trunks, four, three and two, between stakes, chained.
	var logs := _load("long")
	var trunk := Psx.cylinder(0.27, 0.27, 10.6, 7)
	var face := Psx.cylinder(0.24, 0.24, 10.66, 7)
	for row in 3:
		for i in 4 - row:
			var p := Vector3((i - (3 - row) * 0.5) * 0.56, 0.47 + row * 0.47, 0.4)
			Psx.mesh(logs, trunk, p, Color(0.42, 0.3, 0.18).darkened(0.1 * ((i + row) % 2))).rotation.x = PI * 0.5
			Psx.mesh(logs, face, p, Color(0.8, 0.66, 0.44)).rotation.x = PI * 0.5
	for z in [-4.2, -1.4, 1.4, 4.2]:
		for side in [-1.0, 1.0]:
			Psx.box(logs, Vector3(0.1, 1.45, 0.1), Vector3(1.17 * side, 0.92, z), DARK)
		Psx.box(logs, Vector3(1.6, 0.04, 0.06), Vector3(0.0, 1.7, z), Color(0.3, 0.3, 0.32))
	# Pipes: five steel pipes, three and two, on chocks, strapped.
	var pipes := _load("long_pipes")
	var tube := Psx.cylinder(0.36, 0.36, 11.0, 10)
	var bore := Psx.cylinder(0.3, 0.3, 11.06, 10)
	for row in 2:
		for i in 3 - row:
			var p := Vector3((i - (2 - row) * 0.5) * 0.74, 0.62 + row * 0.63, 0.3)
			Psx.mesh(pipes, tube, p, Color(0.5, 0.55, 0.6)).rotation.x = PI * 0.5
			Psx.mesh(pipes, bore, p, DARK).rotation.x = PI * 0.5
	for z in [-3.8, 0.3, 4.4]:
		Psx.box(pipes, Vector3(2.3, 0.1, 0.3), Vector3(0.0, 0.25, z), wood.darkened(0.2))
		Psx.box(pipes, Vector3(2.3, 0.04, 0.08), Vector3(0.0, 1.62, z), Color(0.9, 0.55, 0.1))


## A heap of something loose filling the farm trailer's box, mounded over its sides.
func _heap(colour: Color) -> Node3D:
	var heap := Node3D.new()
	Psx.box(heap, Vector3(2.2, 0.95, 3.9), Vector3(0.0, 0.58, 0.0), colour)
	var dome := SphereMesh.new()
	dome.is_hemisphere = true
	dome.radial_segments = 8
	dome.rings = 3
	var top := Psx.mesh(heap, dome, Vector3(0.0, 1.05, 0.0), colour.darkened(0.08))
	top.scale = Vector3(1.05, 0.5, 1.85)
	return heap


## The node of a look of a load, hidden until it is on.
func _load(look: String) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.visible = false
	_loads[look] = n
	return n


## A bar of a frame from a to b, in parent's frame, t thick.
func _bar(a: Vector3, b: Vector3, t: float, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var m := Psx.box(parent, Vector3(t, t, a.distance_to(b)), (a + b) * 0.5, color)
	m.basis = Basis.looking_at(b - a)
	return m
