extends RefCounted
## The five valleys: each builds in its own world beside the shared one, has a depot and more
## places to deliver to than the one before (3, 4, 4, 5, 5) on flat ground at the ends of its
## roads, nothing standing on a road or floating over the ground, no tree or rock on ice, a car
## slid into any of its ditches stays there, and every road drivable both ways in 4x4 by the test
## autopilot.

const SCENE := preload("res://scenes/main.tscn")


func test_five_valleys_in_order(t: TCase) -> void:
	var all := Valley.all()
	t.eq(all.size(), 5, "valleys")
	t.eq(all[0].id, "khutir", "the first")
	t.eq(all[0].price, 0, "the first is free")
	var ids := {}
	for i in all.size():
		var v := all[i]
		t.ok(not ids.has(v.id), "two valleys are %s" % v.id)
		ids[v.id] = true
		t.ok(v.title != "" and v.blurb != "", "%s has no title or blurb" % v.id)
		if i > 0:
			t.ok(v.price > all[i - 1].price, "%s costs no more than %s" % [v.id, all[i - 1].id])
			t.ok(v.pay > all[i - 1].pay, "%s pays no more than %s" % [v.id, all[i - 1].id])
	t.eq([all[1].price, all[2].price, all[3].price, all[4].price], [1500, 2500, 4000, 6000], "prices")


func test_every_valley_builds(t: TCase) -> void:
	var places := [3, 4, 4, 5, 5]
	var all := Valley.all()
	for vi in all.size():
		var v := all[vi]
		var vp := _world(v, t)
		var world = vp.get_child(0)
		await t.ticks(90)
		var terrain: Terrain = world.terrain
		t.ok(world.locations.has("depot"), "%s has no depot" % v.id)
		var deliveries := 0
		for loc in world.locations.values():
			var p: Vector2 = loc.pos
			var h0 := terrain.get_height(p.x, p.y)
			var h1 := terrain.get_height(p.x + 4.0, p.y + 4.0)
			t.ok(absf(h1 - h0) < 1.0, "%s: %s is not flat (%.1f vs %.1f)" % [v.id, loc.name, h0, h1])
			t.ok(loc.get("offroad", false) or terrain.road_distance(p) < 1.0, "%s: no road to %s" % [v.id, loc.name])
			if loc.has("cargo"):
				deliveries += 1
		t.eq(deliveries, places[vi], "%s: places to deliver to" % v.id)
		var contacts := 0
		for w in world.vehicle.wheels:
			contacts += 1 if w.contact else 0
		t.eq(contacts, 4, "%s: the truck's wheels on the ground at the start" % v.id)
		t.ok(world.vehicle.global_transform.basis.y.y > 0.9, "%s: the truck starts tilted" % v.id)
		_nothing_on_the_roads(t, v, world)
		_no_piece_by_the_roads(t, v, world)
		_nothing_floats(t, v, world)
		for p in world.builder.anchor_points:  # every tree and rock
			if terrain.sample(p).ice > 0.0:
				t.fail("%s: a tree or rock on the ice at %s" % [v.id, Vector2(p.x, p.z).snapped(Vector2.ONE)])
				break
		await _cars_stay_in_their_ditches(t, v, world)
		vp.free()


func test_every_road_drives_both_ways(t: TCase) -> void:
	var notes := PackedStringArray()
	for v in Valley.all():
		var vp := _world(v, t)
		var world = vp.get_child(0)
		await t.ticks(10)
		var truck: Vehicle = world.vehicle
		truck.awd = true
		var slowest := 0.0
		for r in v.roads.size():
			for back in [false, true]:
				var road: PackedVector2Array = v.roads[r].duplicate()
				if back:
					road.reverse()
				var secs := await _drive(t, world, road)
				slowest = maxf(slowest, secs)
				t.ok(secs > 0.0, "%s: road %d %s does not get through" % [v.id, r, "back" if back else "out"])
		notes.append("%s %.0f s" % [v.id, slowest])
		vp.free()
	t.note = "slowest road: " + ", ".join(notes)


## The seconds the autopilot takes from one end of road to the other, or 0 when it gets stuck.
func _drive(t: TCase, world, road: PackedVector2Array) -> float:
	var truck: Vehicle = world.vehicle
	var a := road[0]
	var dir := road[1] - a
	truck.teleport(Vector3(a.x, world.terrain.get_height(a.x, a.y) + 1.2, a.y), atan2(-dir.x, -dir.y))
	await t.ticks(60)
	truck.fuel = Vehicle.FUEL_CAPACITY
	truck.drive_along(road.slice(1), 9.0)
	var end := road[road.size() - 1]
	var last := truck.global_position
	var still := 0
	for tick in 60 * 90:
		await t.tree.physics_frame
		if Vector2(truck.global_position.x, truck.global_position.z).distance_to(end) < 6.0:
			truck.autodrive = false
			return tick / 60.0
		if tick % 120 == 119:
			still = still + 1 if truck.global_position.distance_to(last) < 1.0 else 0
			last = truck.global_position
			if still >= 4:
				break
	truck.autodrive = false
	return 0.0


## No house, tree, rock or post stands where the truck drives: a box the truck's size slid along
## every road every 2 m touches only the ground.
func _nothing_on_the_roads(t: TCase, v: Valley, world) -> void:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.4, 2.2)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.exclude = [world.terrain.get_child(world.terrain.get_child_count() - 1).get_rid(), world.vehicle.get_rid()]
	var hits := 0
	for r in v.roads.size():
		var road: PackedVector2Array = v.roads[r]
		for i in road.size() - 1:
			var n := ceili(road[i].distance_to(road[i + 1]) / 2.0)
			for k in n:
				var p := road[i].lerp(road[i + 1], float(k) / n)
				q.transform = Transform3D(Basis(), Vector3(p.x, world.terrain.get_height(p.x, p.y) + 1.4, p.y))
				var found := space.intersect_shape(q, 1)
				if not found.is_empty() and hits < 5:
					hits += 1
					t.fail("%s: road %d blocked at %s by %s" % [v.id, r, p.snapped(Vector2.ONE), found[0].collider.get_parent().name])


## Nor does anything a place is built of, collider or not (fences, animals, barrels, logs...): seen
## from above, no mesh comes within the road's half width and 1 m of a road's centre line, except
## in the places' flats, the yards the roads drive into.
func _no_piece_by_the_roads(t: TCase, v: Valley, world) -> void:
	var clear := Terrain.ROAD_HALF_WIDTH + 1.0
	var line := PackedVector2Array()  # the centre lines every metre, out of the yards
	var which := PackedInt32Array()
	for r in v.roads.size():
		var road: PackedVector2Array = v.roads[r]
		for i in road.size() - 1:
			var n := ceili(road[i].distance_to(road[i + 1]))
			for k in n + 1:
				var p := road[i].lerp(road[i + 1], float(k) / n)
				var yard := false
				for loc in v.locations.values():
					yard = yard or p.distance_to(loc.pos) < float(loc.radius)
				if not yard:
					line.append(p)
					which.append(r)
	var hits := 0
	for m in world.builder.find_children("*", "MeshInstance3D", true, false):
		var hull := _footprint(m)
		var mid := Vector2.ZERO
		for c in hull:
			mid += c / hull.size()
		var reach := 0.0
		for c in hull:
			reach = maxf(reach, c.distance_to(mid))
		var near := INF
		var nearest := -1
		for j in line.size():
			var p := line[j]
			if p.distance_to(mid) > reach + clear:
				continue
			var d := 0.0 if Geometry2D.is_point_in_polygon(p, hull) else INF
			for e in hull.size() - 1:
				d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, hull[e], hull[e + 1])))
			if d < near:
				near = d
				nearest = which[j]
		if near < clear:
			if hits < 5:
				t.fail("%s: a piece of %s at %s stands %.1f m from road %d's centre line" % [v.id, _place_of(v, mid), mid.snapped(Vector2.ONE), near, nearest])
			hits += 1


## Nor does anything float: an upright piece that reaches the ground under one of its corners (it
## stands on the ground, not on another piece) is no more than 0.15 m above it under any of them.
func _nothing_floats(t: TCase, v: Valley, world) -> void:
	var terrain: Terrain = world.terrain
	var hits := 0
	for m in world.builder.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = m.global_transform
		if xf.basis.y.normalized().y < 0.9:
			continue  # lying down: a log, a barrel
		var box: AABB = m.mesh.get_aabb()
		var low := INF
		var high := -INF
		for i in 4:
			var c := xf * (box.position + box.size * Vector3(i & 1, 0, (i >> 1) & 1))
			var gap := c.y - terrain.get_height(c.x, c.z)
			low = minf(low, gap)
			high = maxf(high, gap)
		if low <= 0.15 and high > 0.15:
			if hits < 5:
				t.fail("%s: a piece of %s at %s floats %.2f m over the ground" % [v.id, _place_of(v, Vector2(xf.origin.x, xf.origin.z)), Vector2(xf.origin.x, xf.origin.z).snapped(Vector2.ONE), high])
			hits += 1


## A mesh's box as it stands, seen from above: a convex polygon, closed.
func _footprint(m: MeshInstance3D) -> PackedVector2Array:
	var box := m.mesh.get_aabb()
	var corners := PackedVector2Array()
	for i in 8:
		var c := m.global_transform * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
		corners.append(Vector2(c.x, c.z))
	return Geometry2D.convex_hull(corners)


## The name of the place nearest p.
func _place_of(v: Valley, p: Vector2) -> String:
	var best := ""
	var near := INF
	for loc in v.locations.values():
		if p.distance_to(loc.pos) < near:
			near = p.distance_to(loc.pos)
			best = loc.name
	return best


## Valley v in a world of its own, so its ground and buildings do not meet the shared one's.
func _world(v: Valley, t: TCase) -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(480, 270)
	var world = SCENE.instantiate()
	world.valley = v
	vp.add_child(world)
	t.tree.root.add_child(vp)
	return vp


## A car in each ditch at once: it settles where it slid in, on its wheels, off the road, so a
## stuck car job is neither done by itself nor lost on its roof.
func _cars_stay_in_their_ditches(t: TCase, v: Valley, world: Node) -> void:
	var terrain: Terrain = world.terrain
	var cars: Array[StuckCar] = []
	for d in v.ditches:
		var car := StuckCar.new()
		world.add_child(car)
		car.slide_into(d, terrain)
		cars.append(car)
	await t.ticks(180)
	for i in cars.size():
		var car := cars[i]
		var at: Vector2 = v.ditches[i].at
		var moved := Vector2(car.global_position.x, car.global_position.z).distance_to(at)
		t.ok(moved < 1.5 and car.upright() and not car.on_road(terrain),
			"%s: the car in ditch %d moved %.1f m, up %.2f, on the road %s" % [v.id, i, moved, car.global_transform.basis.y.y, car.on_road(terrain)])
		car.free()
