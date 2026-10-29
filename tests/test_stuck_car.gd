extends RefCounted
## A car in a ditch: every valley digs one beside each road with room around it; the board's job
## puts a car in it; the winch hooks the car, the truck holds while it pulls, and the car back on
## the road pays.


func test_every_road_has_a_ditch_with_room(t: TCase) -> void:
	for v in Valley.all():
		t.ok(v.ditches.size() >= v.roads.size() - 1, "%s: %d ditches for %d roads" % [v.id, v.ditches.size(), v.roads.size()])
		for d in v.ditches:
			t.ok(absf((d.pos as Vector2).distance_to(d.at) - 7.0) < 0.01, "%s: a ditch off its road" % v.id)
	var close := 0
	for d in t.world.valley.ditches:
		for p in t.world.builder.tree_points:
			if p.distance_to(d.at) < 8.0:
				close += 1
	t.eq(close, 0, "trees by the khutir valley's ditches")


func test_the_winch_pulls_the_car_back_onto_the_road(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	c.job = {}
	c.board_open = false
	v.set_cargo(false)
	c.money = 0
	var o := c.offer_stuck(0)
	t.eq(o.reward, 300, "a stuck car pays in the khutir valley")
	c.take(o)
	var car: StuckCar = c._car
	if not t.ok(car != null, "no car in the ditch"):
		return
	await t.ticks(90)
	t.ok(not car.on_road(t.world.terrain), "the car starts on the road")
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
