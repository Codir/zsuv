extends RefCounted
## The truck drives: down the road from the depot, burning fuel, leaving ruts.


func test_drives_down_the_road(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	v.fuel = v.spec.fuel_capacity
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
	t.ok(v.fuel < v.spec.fuel_capacity, "no fuel burnt")
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
	v.fuel = v.spec.fuel_capacity


## A key let go after the game lost the keyboard (in a browser, a click outside the game's frame)
## never reaches it: losing focus lets go of every key, or the truck keeps its throttle on.
func test_losing_focus_lets_go_of_the_keys(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 0.0)
	var held: Array[StringName] = [&"accelerate", &"steer_left", &"handbrake"]
	for what in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		for action in held:
			Input.action_press(action)
		await t.ticks(2)
		t.ok(v.throttle_input > 0.0, "W held does not open the throttle")
		t.tree.root.propagate_notification(what)
		await t.ticks(2)
		for action in held:
			t.ok(not Input.is_action_pressed(action), "%s still held after focus out (%d)" % [action, what])
		t.eq(v.throttle_input, 0.0, "throttle after focus out (%d)" % what)
	for action in held:
		Input.action_release(action)


## Number of compacted track pixels.
func _ruts(terrain: Terrain) -> int:
	var n := 0
	for b in terrain.track_img.get_data():
		if b > 0:
			n += 1
	return n
