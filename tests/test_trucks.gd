extends RefCounted
## The trucks of 0.3.0 beside the pickup (docs/trucks.md): every one builds from its TruckSpec,
## stands on all its wheels with its hitch where its trailer needs it, and drives off down a khutir
## road in 2WD; on a flat their top speeds are their specs' and the semi turns the widest; the 6x6
## with 3.5 t of concrete rings gets through a drift where the pickup in 2WD bogs and climbs the
## steepest pitch of any road; the tractor crawls in low range through a Polissia bog where the
## pickup in 2WD sticks.

const SCENE := preload("res://scenes/main.tscn")
const DRIFT := [Vector2(54.0, 54.0), Vector2(31.0, 31.0)]  # khutir: up a bank of deep snow below the radio tower
const BOG := [Vector2(-2.0, -42.0), Vector2(-28.0, -27.0)]  # Polissia: across the mud of the lake's shore, rising 1.3 m


## A truck whose pedals and wheel the test holds (a Vehicle reads the keys otherwise).
class Held extends Vehicle:
	func _read_input() -> void:
		pass


func test_every_truck_builds_stands_and_drives_off(t: TCase) -> void:
	var terrain: Terrain = t.world.terrain
	var c: Contracts = t.world.contracts
	var spawn := Vector2(c.spawn_pos.x, c.spawn_pos.z)
	var road: PackedVector2Array = t.world.roads[0]
	var notes := PackedStringArray()
	var ids := {}
	for spec in TruckSpec.all():
		t.ok(not ids.has(spec.id), "two trucks are %s" % spec.id)
		ids[spec.id] = true
		_check_wheels(t, spec)
		var v := await _truck(t, spec)
		await _place(t, v, spawn, road[1] - spawn)
		var down := 0
		for w in v.wheels:
			down += 1 if w.contact else 0
		t.eq(down, spec.wheels.size(), "%s: wheels on the ground" % spec.id)
		t.ok(v.global_transform.basis.y.y > 0.97, "%s stands tilted: up.y %.2f" % [spec.id, v.global_transform.basis.y.y])
		t.ok(absf(v.forward_speed) < 0.3, "%s rolls away standing: %.2f m/s" % [spec.id, v.forward_speed])
		var ground := terrain.get_height(v.global_position.x, v.global_position.z)
		t.ok(v.global_position.y > ground + 0.3 and v.global_position.y < ground + 1.5, "%s rides at %.2f over the ground" % [spec.id, v.global_position.y - ground])
		_check_hitch(t, v)
		_check_loads(t, v)
		# 60 m down the road from the depot in 2WD.
		v.awd = false
		v.fuel = spec.fuel_capacity
		var start := v.global_position
		v.drive_along(road.slice(1), 9.0)
		var secs := 0.0
		for tick in 60 * 15:
			await t.tree.physics_frame
			if v.global_position.distance_to(start) > 60.0:
				secs = tick / 60.0
				break
		v.autodrive = false
		t.ok(secs > 0.0, "%s does not cover 60 m of road 0 in 15 s in 2WD (%.0f m)" % [spec.id, v.global_position.distance_to(start)])
		t.ok(v.fuel < spec.fuel_capacity, "%s burns no fuel" % spec.id)
		notes.append("%s %.1f s" % [spec.id, secs])
		_done(t, v)
	t.note = "60 m in 2WD: " + ", ".join(notes)


func test_top_speeds_and_turning_circles_on_a_flat(t: TCase) -> void:
	var vp := _flat(t)
	var specs := TruckSpec.all()
	var trucks: Array[Held] = []
	for i in specs.size():
		var v := Held.new()
		v.spec = specs[i]
		v.position = Vector3(i * 40.0, 1.5, 0.0)
		vp.add_child(v)
		trucks.append(v)
	await t.ticks(60)
	# Flat out straight ahead, in high range, then in low range.
	var tops := {}
	for low in [false, true]:
		for v in trucks:
			v.low_range = low
			v.throttle_input = 1.0
			v.steer_input = 0.0
		var top := PackedFloat32Array()
		top.resize(trucks.size())
		for tick in 60 * (15 if not low else 5):
			await t.tree.physics_frame
			for i in trucks.size():
				top[i] = maxf(top[i], trucks[i].forward_speed)
		for i in trucks.size():
			var s := specs[i]
			var rated := s.max_speed_low if low else s.max_speed_high
			# The air and the tyres take the same share off every truck's rated top speed (the
			# pickup: 13.3 of 18 m/s).
			t.ok(top[i] > rated * 0.7 and top[i] <= rated, "%s: %.1f m/s flat out in %s range, rated %.1f" % [s.id, top[i], "low" if low else "high", rated])
			if not low:
				tops[s.id] = top[i]
		for v in trucks:
			v.throttle_input = 0.0
			v.handbrake = true
		await t.ticks(240)
		for v in trucks:
			v.handbrake = false
	t.ok(tops.tractor < tops.six and tops.six < tops.pickup and tops.pickup < tops.semi,
		"fastest last should be the tractor, the 6x6, the pickup, the semi: %s" % tops)
	# Full lock to the left at a walking pace: the circle the truck drives, its speed over its
	# rate of turn once it has settled into it.
	var speed := PackedFloat32Array()
	var turn := PackedFloat32Array()
	speed.resize(trucks.size())
	turn.resize(trucks.size())
	for tick in 60 * 10:
		await t.tree.physics_frame
		for i in trucks.size():
			var v := trucks[i]
			v.steer_input = 1.0
			v.throttle_input = clampf((2.5 - v.forward_speed) * 0.5, 0.0, 1.0)
			if tick >= 60 * 5:
				speed[i] += v.forward_speed
				turn[i] += absf(v.angular_velocity.y)
	var radius := {}
	for i in trucks.size():
		radius[specs[i].id] = speed[i] / maxf(turn[i], 0.001)
	t.ok(radius.semi > radius.six and radius.semi > radius.pickup * 1.25 and radius.semi > radius.tractor,
		"the semi should turn the widest: %s" % radius)
	var notes := PackedStringArray()
	for s in specs:
		notes.append("%s %.0f km/h, %.1f m" % [s.id, tops[s.id] * 3.6, radius[s.id]])
	t.note = "flat out, and the turning radius: " + ", ".join(notes)
	vp.free()


func test_six_loaded_gets_through_a_drift_where_the_pickup_bogs(t: TCase) -> void:
	var terrain: Terrain = t.world.terrain
	var a: Vector2 = DRIFT[0]
	var b: Vector2 = DRIFT[1]
	var depth := 0.0
	for k in 11:
		var p := a.lerp(b, k / 10.0)
		depth += terrain.sample(Vector3(p.x, 0.0, p.y)).snow / 11.0
	t.ok(depth > 0.4, "the drift is not deep: %.2f m of snow" % depth)
	var ruts := terrain.track_img.duplicate()
	# The pickup in 2WD.
	terrain.track_img.fill(Color.BLACK)
	var pickup: Vehicle = t.world.vehicle
	await _place(t, pickup, a, b - a)
	pickup.awd = false
	var made := await _through(t, pickup, a, b, 10.0)
	t.ok(made < 5.0, "the pickup in 2WD should bog in the drift: it made %.1f m" % made)
	_park(t, pickup)
	# The 6x6 with the concrete rings, all six wheels driven.
	terrain.track_img.fill(Color.BLACK)
	var six := await _truck(t, TruckSpec.six())
	six.set_cargo(true, "heavy")
	await _place(t, six, a, b - a)
	six.awd = true
	var secs := await _secs_through(t, six, b, 18.0)
	t.ok(secs > 0.0, "the 6x6 with 3.5 t in 6x6 does not get through the drift in 18 s: %.1f m short" % _short(six, b))
	t.note = "%.0f m of snow %.2f m deep: the pickup in 2WD %.1f m in 10 s, the 6x6 with the rings %.1f s" % [a.distance_to(b), depth, made, secs]
	_done(t, six)
	terrain.track_img.copy_from(ruts)
	terrain.track_tex.update(terrain.track_img)


func test_six_loaded_climbs_the_steepest_pitch_in_low_range(t: TCase) -> void:
	var terrain: Terrain = t.world.terrain
	# Road 1 every metre, and its steepest metre.
	var pts := _every_metre(t.world.roads[1])
	var steep := 0.0
	var at := 0
	for i in pts.size() - 1:
		var g := absf(terrain.get_height(pts[i + 1].x, pts[i + 1].y) - terrain.get_height(pts[i].x, pts[i].y))
		if g > steep:
			steep = g
			at = i
	t.ok(steep > 0.4, "road 1's steepest metre climbs only %.2f m" % steep)
	var up := 1 if terrain.get_height(pts[at + 1].x, pts[at + 1].y) > terrain.get_height(pts[at].x, pts[at].y) else -1
	# From a standstill at the foot of the pitch (the lowest point of the 25 m below it) to 25 m
	# above it.
	var from := at
	for k in 25:
		var j := clampi(at - k * up, 0, pts.size() - 1)
		if terrain.get_height(pts[j].x, pts[j].y) < terrain.get_height(pts[from].x, pts[from].y):
			from = j
	var to := clampi(at + 25 * up, 0, pts.size() - 1)
	var path := PackedVector2Array()
	var i := from
	while i != to:
		i += up
		path.append(pts[i])
	var rise := terrain.get_height(pts[to].x, pts[to].y) - terrain.get_height(pts[from].x, pts[from].y)
	_park(t, t.world.vehicle)
	var six := await _truck(t, TruckSpec.six())
	six.set_cargo(true, "heavy")
	await _place(t, six, pts[from], path[0] - pts[from])
	six.awd = false
	six.low_range = true
	var secs := await _secs_through(t, six, path[path.size() - 1], 30.0, path)
	t.ok(secs > 0.0, "the 6x6 with 3.5 t in 6x4, low range, does not climb past road 1's steepest metre (%.2f) in 30 s: %.1f m short" % [steep, _short(six, path[path.size() - 1])])
	t.note = "%.2f m a metre at its worst, %.1f m up in %.0f m of road from a standstill: %.1f s" % [steep, rise, path.size(), secs]
	_done(t, six)


func test_tractor_crawls_through_a_polissia_bog_where_the_pickup_sticks(t: TCase) -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(64, 64)
	var world = SCENE.instantiate()
	world.valley = Valley.polissia()
	vp.add_child(world)
	t.tree.root.add_child(vp)
	await t.ticks(10)
	var terrain: Terrain = world.terrain
	var a: Vector2 = BOG[0]
	var b: Vector2 = BOG[1]
	var mud := 0.0
	for k in 11:
		var p := a.lerp(b, k / 10.0)
		mud += terrain.sample(Vector3(p.x, 0.0, p.y)).mud / 11.0
	t.ok(mud > 0.9, "the bog is not muddy: %.2f" % mud)
	var pickup: Vehicle = world.vehicle
	pickup.teleport(Vector3(a.x, terrain.get_height(a.x, a.y) + 1.2, a.y), _yaw(b - a))
	await t.ticks(90)
	pickup.awd = false
	var made := await _through(t, pickup, a, b, 12.0)
	t.ok(made < a.distance_to(b) - 8.0, "the pickup in 2WD should stick in the bog: it made %.1f of %.0f m" % [made, a.distance_to(b)])
	pickup.teleport(Vector3(100.0, terrain.get_height(100.0, -100.0) + 1.5, -100.0), 0.0)
	terrain.track_img.fill(Color.BLACK)
	var tractor := Vehicle.new()
	tractor.spec = TruckSpec.tractor()
	tractor.terrain = terrain
	tractor.position = Vector3(a.x, terrain.get_height(a.x, a.y) + 1.5, a.y)
	tractor.rotation.y = _yaw(b - a)
	world.add_child(tractor)
	await t.ticks(90)
	tractor.awd = false
	tractor.low_range = true
	var secs := await _secs_through(t, tractor, b, 20.0)
	t.ok(secs > 0.0, "the tractor in 2WD, low range, does not crawl through the bog in 20 s: %.1f m short" % _short(tractor, b))
	t.note = "%.0f m of mud: the pickup in 2WD %.1f m in 12 s, the tractor in low range %.1f s" % [a.distance_to(b), made, secs]
	vp.free()


## Wheels in pairs, left and right, front to back; something steers and something drives in 2WD.
func _check_wheels(t: TCase, s: TruckSpec) -> void:
	t.eq(s.wheels.size(), s.axles.size() * 2, "%s: wheels for its axles" % s.id)
	var steers := false
	var drives := false
	var last := -INF
	for a in s.axles:
		var l: Vector3 = s.wheels[a.x].mount
		var r: Vector3 = s.wheels[a.y].mount
		t.ok(l.x < 0.0 and r.x > 0.0 and is_equal_approx(l.z, r.z), "%s: axle %s is not a left and a right wheel" % [s.id, a])
		t.ok(l.z > last, "%s: axle %s is ahead of the one before" % [s.id, a])
		last = l.z
		steers = steers or s.wheels[a.x].steer
		drives = drives or s.wheels[a.x].drive2
	t.ok(steers and drives, "%s: nothing steers or nothing drives in 2WD" % s.id)


## Its hitch where its trailer couples: a towbar or a drawbar pin behind its last axle, as high as
## the pickup's or lower; a fifth wheel over its rear axles, 1.2-1.4 m off the ground.
func _check_hitch(t: TCase, v: Vehicle) -> void:
	var s := v.spec
	var p := v.global_transform * s.hitch
	var over := p.y - (t.world.terrain as Terrain).get_height(p.x, p.z)
	var last: float = s.wheels[s.wheels.size() - 1].mount.z
	var heights := {"ball": Vector2(0.5, 0.9), "pin": Vector2(0.3, 0.7), "fifth": Vector2(1.2, 1.4)}
	t.ok(heights.has(s.hitch_kind), "%s: a hitch of no kind (%s)" % [s.id, s.hitch_kind])
	if not heights.has(s.hitch_kind):
		return
	var h: Vector2 = heights[s.hitch_kind]
	t.ok(over > h.x and over < h.y, "%s: its %s hitch stands %.2f m off the ground" % [s.id, s.hitch_kind, over])
	if s.hitch_kind == "fifth":
		var mid: float = s.wheels[s.axles[s.axles.size() - 2].x].mount.z
		t.ok(s.hitch.z > mid - 0.5 and s.hitch.z < last, "%s: its fifth wheel is not over its rear axles" % s.id)
	else:
		t.ok(s.hitch.z > last + 0.6, "%s: its hitch is not behind its last axle" % s.id)


## Each load it carries weighs what its spec says and shows on it; it carries nothing else.
func _check_loads(t: TCase, v: Vehicle) -> void:
	for kind in ["plain", "timed", "fragile", "heavy", "bulk", "long"]:
		v.set_cargo(true, kind)
		var shown := false
		for k in v._loads:
			shown = shown or v._loads[k].visible
		if v.spec.cargo_mass.has(kind):
			t.eq(v.mass, v.spec.mass + float(v.spec.cargo_mass[kind]), "%s: its mass with a %s load" % [v.spec.id, kind])
			t.ok(shown, "%s: a %s load does not show" % [v.spec.id, kind])
		elif v.spec.cargo_mass.is_empty():
			t.eq(v.mass, v.spec.mass, "%s carries a %s load itself" % [v.spec.id, kind])
			t.ok(not shown, "%s shows a %s load" % [v.spec.id, kind])
	v.set_cargo(false)


## spec's truck in the shared world, the pickup itself for the pickup; the pickup out of the way.
func _truck(t: TCase, spec: TruckSpec) -> Vehicle:
	var pickup: Vehicle = t.world.vehicle
	if spec.id == "pickup":
		return pickup
	_park(t, pickup)
	var v := Vehicle.new()
	v.spec = spec
	v.terrain = t.world.terrain
	v.position = Vector3(110.0, t.world.terrain.get_height(110.0, -110.0) + 3.0, -110.0)
	t.world.add_child(v)
	v.winch.anchors = t.world.builder.anchor_points
	await t.ticks(2)
	return v


func _done(t: TCase, v: Vehicle) -> void:
	v.autodrive = false
	if v != t.world.vehicle:
		v.free()


## The pickup on flat ground away from the depot and the roads the tests drive.
func _park(t: TCase, v: Vehicle) -> void:
	var farm: Vector2 = t.world.locations.farm.pos + Vector2(0.0, -4.0)
	v.autodrive = false
	v.teleport(Vector3(farm.x, t.world.terrain.get_height(farm.x, farm.y) + 1.2, farm.y), 0.0)


func _place(t: TCase, v: Vehicle, p: Vector2, dir: Vector2) -> void:
	v.autodrive = false
	v.teleport(Vector3(p.x, t.world.terrain.get_height(p.x, p.y) + 1.2, p.y), _yaw(dir))
	await t.ticks(90)


## The metres v makes from a towards b in secs at most, by the autopilot at 6 m/s.
func _through(t: TCase, v: Vehicle, a: Vector2, b: Vector2, secs: float) -> float:
	v.fuel = v.spec.fuel_capacity
	v.drive_along(PackedVector2Array([b]), 6.0)
	await t.ticks(int(secs * 60.0))
	v.autodrive = false
	return (Vector2(v.global_position.x, v.global_position.z) - a).dot((b - a).normalized())


## The seconds v takes to within 4 m of b, by the autopilot along path (straight to b if empty),
## or 0 when secs run out.
func _secs_through(t: TCase, v: Vehicle, b: Vector2, secs: float, path := PackedVector2Array()) -> float:
	v.fuel = v.spec.fuel_capacity
	v.drive_along(path if not path.is_empty() else PackedVector2Array([b]), 6.0)
	for tick in int(secs * 60.0):
		await t.tree.physics_frame
		if _short(v, b) < 4.0:
			v.autodrive = false
			return tick / 60.0
	v.autodrive = false
	return 0.0


func _short(v: Vehicle, b: Vector2) -> float:
	return Vector2(v.global_position.x, v.global_position.z).distance_to(b)


func _every_metre(road: PackedVector2Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in road.size() - 1:
		var n := ceili(road[i].distance_to(road[i + 1]))
		for k in n:
			pts.append(road[i].lerp(road[i + 1], float(k) / n))
	pts.append(road[road.size() - 1])
	return pts


## A world of its own with nothing in it but a flat floor 4 km square.
func _flat(t: TCase) -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(64, 64)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 1.0, 4000.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor.add_child(shape)
	vp.add_child(floor)
	t.tree.root.add_child(vp)
	return vp


## The yaw that faces a truck along dir on the XZ plane (it looks down -Z).
func _yaw(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)
