extends RefCounted
## The truck drives: down the road from the depot, burning fuel, leaving ruts.


func test_drives_down_the_road(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	v.fuel = Vehicle.FUEL_CAPACITY
	var start := v.global_position
	var ruts_before := _ruts(t.world.terrain)
	v.drive_along(t.world.roads[0].slice(1))
	var top_speed := 0.0
	var min_up := 1.0
	for i in 600:
		await t.tree.physics_frame
		top_speed = maxf(top_speed, v.forward_speed)
		min_up = minf(min_up, v.global_transform.basis.y.y)
	v.autodrive = false
	var dist := start.distance_to(v.global_position)
	t.note = "%.0f m in 10 s, top %.0f km/h" % [dist, top_speed * 3.6]
	t.ok(dist > 40.0, "covered only %.1f m in 10 s" % dist)
	t.ok(top_speed > 5.0, "top speed %.1f m/s" % top_speed)
	t.ok(min_up > 0.6, "nearly rolled over: up.y %.2f" % min_up)
	t.ok(v.fuel < Vehicle.FUEL_CAPACITY, "no fuel burnt")
	t.ok(_ruts(t.world.terrain) > ruts_before, "the wheels left no ruts")


func test_no_drive_without_fuel(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 0.0)  # flat ground away from the depot
	v.fuel = 0.0
	var start := v.global_position
	v.drive_along(PackedVector2Array([farm + Vector2(0.0, -30.0)]))
	await t.ticks(180)
	v.autodrive = false
	var moved := start.distance_to(v.global_position)
	t.ok(moved < 1.5, "moved %.1f m on an empty tank" % moved)
	t.ok(t.world.contracts.prompt.begins_with("Out of fuel"), "prompt: " + t.world.contracts.prompt)
	v.fuel = Vehicle.FUEL_CAPACITY


## Number of compacted track pixels.
func _ruts(terrain: Terrain) -> int:
	var n := 0
	for b in terrain.track_img.get_data():
		if b > 0:
			n += 1
	return n
