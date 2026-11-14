extends RefCounted
## The valley: terrain, props, the truck standing on four wheels.


func test_terrain_and_props(t: TCase) -> void:
	var terrain: Terrain = t.world.land.home
	t.eq(terrain.heights.size(), Terrain.N * Terrain.N, "height samples")
	t.eq(terrain.roads.size(), 4, "roads: two of its own, to the river and to the swamp")
	t.ok(t.world.builder.tree_points.size() >= 400, "trees: %d" % t.world.builder.tree_points.size())
	t.ok(t.world.builder.anchor_points.size() > t.world.builder.tree_points.size(), "rocks are winch anchors too")
	for key in ["depot", "farm", "lumber", "tower"]:
		t.ok(t.world.locations.has(key), "location " + key)
	# Locations sit on flattened ground.
	for loc in t.world.locations.values():
		var p: Vector2 = loc.pos
		var h0 := terrain.get_height(p.x, p.y)
		var h1 := terrain.get_height(p.x + 4.0, p.y + 4.0)
		t.ok(absf(h1 - h0) < 1.0, "%s is not flat: %.2f vs %.2f" % [loc.name, h0, h1])


func test_truck_stands_on_four_wheels(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw, 120)
	var contacts := 0
	for w in v.wheels:
		if w.contact:
			contacts += 1
	t.eq(contacts, 4, "wheels on the ground")
	t.ok(v.global_transform.basis.y.y > 0.95, "upright: up.y = %.2f" % v.global_transform.basis.y.y)
	t.ok(absf(v.forward_speed) < 0.5, "parked: speed %.2f" % v.forward_speed)
	var ground: float = t.world.land.home.get_height(v.global_position.x, v.global_position.z)
	t.ok(v.global_position.y > ground and v.global_position.y < ground + 2.0,
		"rides at %.2f over ground %.2f" % [v.global_position.y, ground])


func test_snow_and_mud_slow_you_down(t: TCase) -> void:
	var terrain: Terrain = t.world.land.home
	var road := terrain.sample(Vector3(-60.0, 0.0, -102.0))
	# The deepest snow off the roads.
	var deep_p := Vector3.ZERO
	var deep := road
	for z in range(-110, 110, 4):
		for x in range(-110, 110, 4):
			var s := terrain.sample(Vector3(x, 0.0, z))
			if s.snow > deep.snow:
				deep = s
				deep_p = Vector3(x, 0.0, z)
	t.ok(deep.snow > 0.5, "deep snow somewhere: %.2f" % deep.snow)
	t.ok(deep.grip < road.grip, "snow grips less: %.2f vs road %.2f" % [deep.grip, road.grip])
	t.ok(deep.rolling > road.rolling * 5.0, "snow drags more: %.3f vs road %.3f" % [deep.rolling, road.rolling])
	# Packed down by wheels, it is shallower and easier going.
	for i in 6:
		terrain.compact(deep_p, 0.25)
	var packed := terrain.sample(deep_p)
	t.ok(packed.snow < deep.snow * 0.5, "packed snow %.2f vs fresh %.2f" % [packed.snow, deep.snow])
	t.ok(packed.rolling < deep.rolling, "packed snow drags less")
