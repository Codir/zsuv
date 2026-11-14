extends RefCounted
## Fuel is the frontier (docs/plan.md §6): a pickup's tank goes about 2 km of road, measured
## driving the forest's longest road both ways at the autopilot's pace; the scout goes about as
## far on its small tank; and on a flat, at a road pace, a heavy rig's tank goes no further than
## the pickup's.


## A truck whose pedals and wheel the test holds.
class Held extends Vehicle:
	func _read_input() -> void:
		pass


func test_a_tank_goes_about_two_km_of_road(t: TCase) -> void:
	var w = t.world
	var road: PackedVector2Array = _longest(w.roads)
	var path := road.duplicate()
	var back := road.duplicate()
	back.reverse()
	path.append_array(back.slice(1))
	var reach := {}
	for id in ["pickup", "scout"]:
		var v := Vehicle.new()
		v.spec = TruckSpec.find(id)
		v.land = w.land
		var a: Vector2 = path[0]
		var b: Vector2 = path[1]
		v.position = Vector3(a.x, w.land.get_height(a.x, a.y) + 1.5, a.y)
		v.rotation.y = atan2(-(b - a).x, -(b - a).y)
		w.add_child(v)
		w.vehicle.teleport(Vector3(200.0, w.land.get_height(200.0, 200.0) + 1.5, 200.0), 0.0)
		await t.ticks(90)
		v.awd = true
		var fuel0 := v.fuel
		var metres := 0.0
		var last := v.global_position
		v.drive_along(path.slice(1), 9.0)
		for tick in 60 * 150:
			await t.tree.physics_frame
			metres += Vector2(v.global_position.x - last.x, v.global_position.z - last.z).length()
			last = v.global_position
			if not v.autodrive or v._autodrive_index >= path.size() - 1:
				break
		t.ok(metres > 500.0, "the %s drove only %.0f m of the road" % [id, metres])
		reach[id] = v.spec.fuel_capacity / maxf(fuel0 - v.fuel, 0.001) * metres / 1000.0
		v.free()
	t.ok(reach.pickup > 1.6 and reach.pickup < 2.6, "the pickup's 80 L go %.1f km of road" % reach.pickup)
	t.ok(reach.scout > reach.pickup * 0.9, "the scout's 45 L go only %.1f km" % reach.scout)
	t.note = "a tank on the forest's road in 4x4: the pickup %.1f km, the scout %.1f km" % [reach.pickup, reach.scout]


func test_a_heavy_rigs_tank_goes_no_further_than_the_pickups(t: TCase) -> void:
	var vp := _flat(t)
	var reach := {}
	var ids := ["pickup", "six", "tractor", "semi", "mixer"]
	var trucks := {}
	for i in ids.size():
		var v := Held.new()
		v.spec = TruckSpec.find(ids[i])
		v.position = Vector3(i * 30.0, 1.5, 0.0)
		vp.add_child(v)
		trucks[ids[i]] = v
	await t.ticks(90)
	var fuel0 := {}
	var start := {}
	for id in ids:
		fuel0[id] = trucks[id].fuel
		start[id] = trucks[id].global_position
	for tick in 60 * 40:
		await t.tree.physics_frame
		for id in ids:
			var v: Held = trucks[id]
			var pace := minf(9.0, v.spec.max_speed_high * 0.6)  # a road pace, the tractor's slower
			v.throttle_input = clampf((pace - v.forward_speed) * 0.5, 0.0, 1.0)
	for id in ids:
		var v: Held = trucks[id]
		var km: float = v.global_position.distance_to(start[id]) / 1000.0
		reach[id] = v.spec.fuel_capacity / maxf(fuel0[id] - v.fuel, 0.001) * km
	for id in ["six", "semi", "mixer"]:
		t.ok(reach[id] <= reach.pickup * 1.1 and reach[id] > reach.pickup * 0.4, "the %s's tank goes %.1f km, the pickup's %.1f" % [id, reach[id], reach.pickup])
	var notes := PackedStringArray()
	for id in ids:
		notes.append("%s %.1f km" % [id, reach[id]])
	t.note = "a tank on the flat at a road pace: " + ", ".join(notes)
	vp.free()


func _longest(roads: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_m := 0.0
	for r: PackedVector2Array in roads:
		var m := 0.0
		for i in r.size() - 1:
			m += r[i].distance_to(r[i + 1])
		if m > best_m:
			best = r
			best_m = m
	return best


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
