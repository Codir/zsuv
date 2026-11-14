extends RefCounted
## A car in a ditch: every valley digs one beside each road with room around it, clear of the
## road (on a bend too); the board's job puts a car in it; the winch hooks the car, the truck holds
## while it pulls, and the car back on the road pays, but not one that got there by itself.


func test_every_road_has_a_ditch_with_room(t: TCase) -> void:
	for v in Valley.all():
		# The roads to the biomes' borders (docs/plan.md §3) are short and new: no stuck cars there.
		var own := v.roads.filter(func(r: PackedVector2Array) -> bool: return maxf(maxf(absf(r[0].x), absf(r[0].y)), maxf(absf(r[r.size() - 1].x), absf(r[r.size() - 1].y))) < 127.0).size()
		t.ok(v.ditches.size() >= own - 1, "%s: %d ditches for %d roads" % [v.id, v.ditches.size(), own])
		for d in v.ditches:
			t.ok(absf((d.pos as Vector2).distance_to(d.at) - 7.0) < 0.01, "%s: a ditch off its road" % v.id)
		for ft in v.features:
			if ft.type != "ditch":
				continue
			for k in 11:
				var q: Vector2 = ft.pos + (ft.dir as Vector2) * Valley.DITCH_LENGTH * (k / 10.0 - 0.5)
				var near := INF
				for road in v.roads:
					for i in road.size() - 1:
						near = minf(near, q.distance_to(Geometry2D.get_closest_point_to_segment(q, road[i], road[i + 1])))
				t.ok(near > Terrain.ROAD_HALF_WIDTH + Valley.DITCH_WIDTH - 0.2, "%s: the ditch at %s cuts into a road" % [v.id, ft.pos])
	var close := 0
	for d in t.world.valley.ditches:
		for p in t.world.builder.tree_points:
			if p.distance_to(d.at) < 8.0:
				close += 1
	t.eq(close, 0, "trees by the khutir valley's ditches")


func test_a_car_on_the_road_by_itself_is_not_paid(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	c.call("_end_job")
	c.money = 0
	var o := c.offer_stuck(1)
	c.take(o)
	var car: StuckCar = c._car
	var p: Vector2 = o.ditch.pos
	car.global_transform = Transform3D(Basis(), Vector3(p.x, t.world.land.home.get_height(p.x, p.y) + 0.8, p.y))
	await t.ticks(120)
	t.ok(car.on_road(t.world.land), "the car is not on the road")
	t.ok(not c.job.is_empty() and c.money == 0, "paid for a car the winch never had")
	c.call("_end_job")


func test_the_winch_pulls_the_car_back_onto_the_road(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	c.call("_end_job")
	c.money = 0
	var o := c.offer_stuck(0)
	t.eq(o.reward, 300, "a stuck car pays in the khutir valley")
	c.take(o)
	var car: StuckCar = c._car
	if not t.ok(car != null, "no car in the ditch"):
		return
	await t.ticks(90)
	t.ok(not car.on_road(t.world.land), "the car starts on the road")
	t.ok(c.objective_text().begins_with("STUCK CAR"), "objective: " + c.objective_text())
	# Stand on the far side of the road, facing the ditch.
	var d: Dictionary = o.ditch
	var side: Vector2 = ((d.at as Vector2) - d.pos).normalized()
	await t.place(d.pos - side * 2.5, atan2(-side.x, -side.y))
	t.ok(v.winch.candidate >= v.winch.anchors.size(), "the winch offers no car: " + v.winch.prompt())
	t.ok(v.winch.prompt().begins_with("[F] Winch to the car"), "prompt: " + v.winch.prompt())
	var start := v.global_position
	v.winch.toggle()
	t.ok(v.winch.anchor_body == car, "the winch is not on the car")
	v.winch.auto_reel = true
	var secs := 0.0
	for i in 60 * 20:
		await t.tree.physics_frame
		if c.job.is_empty():
			secs = i / 60.0
			break
	v.winch.auto_reel = false
	t.note = "out in %.1f s, the truck moved %.1f m" % [secs, v.global_position.distance_to(start)]
	t.ok(secs > 0.0, "the car is not back on the road after 20 s")
	t.eq(c.money, 300, "paid")
	t.ok(v.global_position.distance_to(start) < 2.0, "the car dragged the truck %.1f m" % v.global_position.distance_to(start))
	t.ok(not v.winch.attached, "still hooked to the car")
	await t.ticks(200)
	t.ok(not is_instance_valid(car), "the car does not drive off")
