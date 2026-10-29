extends RefCounted
## The six valleys: each builds in its own world beside the shared one, has a depot and three
## places to deliver to on flat ground at the ends of its roads, nothing standing on a road, and
## every road drivable both ways in 4x4 by the test autopilot.

const SCENE := preload("res://scenes/main.tscn")


func test_six_valleys_in_order(t: TCase) -> void:
	var all := Valley.all()
	t.eq(all.size(), 6, "valleys")
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
	t.eq([all[1].price, all[2].price, all[3].price, all[4].price, all[5].price], [1500, 2500, 4000, 6000, 8500], "prices")


func test_every_valley_builds(t: TCase) -> void:
	for v in Valley.all():
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
		t.eq(deliveries, 3, "%s: places to deliver to" % v.id)
		var contacts := 0
		for w in world.vehicle.wheels:
			contacts += 1 if w.contact else 0
		t.eq(contacts, 4, "%s: the truck's wheels on the ground at the start" % v.id)
		t.ok(world.vehicle.global_transform.basis.y.y > 0.9, "%s: the truck starts tilted" % v.id)
		_nothing_on_the_roads(t, v, world)
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
