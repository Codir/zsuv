extends RefCounted
## The delivery loop: load at the depot, deliver, get paid; the tow costs money.


func test_delivery_loop(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	var got: Array[String] = []
	var on_message := func(text: String) -> void: got.append(text)
	c.message.connect(on_message)
	c.money = 0
	c.set("_job_index", 0)
	v.set_cargo(false)

	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	v.fuel = 10.0
	t.ok(c.objective_text().begins_with("PICK UP AT DEPOT"), "objective: " + c.objective_text())
	t.ok(c.prompt.begins_with("[E] Load"), "prompt at the depot: " + c.prompt)
	c.call("_interact")
	t.ok(v.has_cargo, "loaded")
	t.eq(v.fuel, Vehicle.FUEL_CAPACITY, "refuelled")
	t.ok(c.objective_text().begins_with("DELIVER: groceries -> Khutir"), "objective: " + c.objective_text())

	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 0.0)
	t.eq(c.prompt, "[E] Unload", "prompt at the khutir")
	c.call("_interact")
	t.ok(not v.has_cargo, "unloaded")
	t.eq(c.money, 250, "paid")
	t.ok(c.objective_text().contains("spare parts for Sawmill"), "next job: " + c.objective_text())
	t.ok(got.has("Loaded: groceries. Head for Khutir"), "messages: %s" % [got])
	t.ok(got.has("Delivered to Khutir! +$250"), "messages: %s" % [got])
	c.message.disconnect(on_message)


func test_tow_to_depot(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	await t.place(Vector2(40.0, -82.0), 0.0, 30)
	c.money = 500
	v.fuel = 0.0
	c.recover()
	await t.ticks(60)
	t.eq(c.money, 500 - Contracts.RECOVER_COST, "money after the tow")
	t.ok(v.fuel > Vehicle.FUEL_CAPACITY * 0.45, "half a tank after the tow: %.1f L" % v.fuel)
	t.ok(v.global_position.distance_to(c.spawn_pos) < 3.0, "back at the depot: %s" % v.global_position)
