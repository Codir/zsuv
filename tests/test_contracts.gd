extends RefCounted
## The jobs: the board at the depot offers three; a plain delivery pays; a timed one pays by its
## medal and keeps its record; a fragile one breaks on hard landings and pays for what is whole;
## a heavy one sits the truck low and drinks; a new job at the depot drops the one in hand; the
## tow costs money.


func test_the_board_offers_three_jobs(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	_clear(c, v)
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	t.ok(c.objective_text().begins_with("AT THE DEPOT"), "objective: " + c.objective_text())
	t.eq(c.prompt, "[E] Job board", "prompt at the depot")
	c.call("_interact")
	await t.ticks(2)
	t.ok(c.board_open, "E does not open the board")
	t.ok(c.prompt.begins_with("[1] [2] [3]"), "prompt on the board: " + c.prompt)
	t.eq(c.offers.size(), 3, "jobs on the board")
	var places := {}
	var kinds := {}
	for o in c.offers:
		places[o.key] = true
		kinds[o.kind] = true
		t.ok(o.reward > 0 and o.route > 50.0, "%s to %s: $%d, %d m" % [o.kind, o.name, o.reward, o.route])
	t.eq(places.size(), 3, "different places")
	t.eq(kinds.size(), 3, "different kinds")
	t.eq(c.board_text().split("\n").size(), 5, "lines on the board")
	var o: Dictionary = c.offers[0] if c.offers[0].kind != "stuck" else c.offers[1]
	c.take(o)
	t.ok(not c.board_open and v.has_cargo, "taking a job does not load it")
	_clear(c, v)


func test_a_new_job_at_the_depot_drops_the_one_in_hand(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	var got: Array[String] = []
	var on_message := func(text: String) -> void: got.append(text)
	c.message.connect(on_message)
	_clear(c, v)
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	c.take(c.offer_stuck(0))
	v.fuel = 20.0
	await t.ticks(2)
	t.eq(c.prompt, "[E] Refuel, job board", "prompt at the depot with a job")
	c.call("_interact")
	t.eq(v.fuel, Vehicle.FUEL_CAPACITY, "E does not refuel")
	t.ok(c.board_open, "E does not open the board with a job in hand")
	t.ok(c.board_text().begins_with("JOB BOARD - DEPOT   (a new job drops pull a car out)"), "board: " + c.board_text())
	var car: StuckCar = c._car
	c.take(c.offer("farm", "heavy"))
	t.ok(c.job.kind == "heavy" and v.has_cargo, "the new job is not loaded")
	t.ok(got.any(func(m: String) -> bool: return m.begins_with("Dropped: pull a car out for the ditch near")), "messages: %s" % [got])
	t.ok(not v.winch.bodies.has(car), "the dropped job's car is still there to winch")
	await t.ticks(200)
	t.ok(not is_instance_valid(car), "the dropped job's car does not drive off")
	c.message.disconnect(on_message)
	_clear(c, v)


func test_out_of_fuel_on_a_stuck_car_job_offers_the_tow(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	_clear(c, v)
	c.take(c.offer_stuck(0))
	await t.place(Vector2(40.0, -82.0), 0.0, 30)
	v.fuel = 0.0
	await t.ticks(2)
	t.ok(c.prompt.begins_with("Out of fuel! [T] Tow"), "prompt: " + c.prompt)
	_clear(c, v)


func test_a_plain_delivery_pays(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	var got: Array[String] = []
	var on_message := func(text: String) -> void: got.append(text)
	c.message.connect(on_message)
	_clear(c, v)
	c.money = 0
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	v.fuel = 10.0
	c.take(c.offer("farm", "plain"))
	t.ok(v.has_cargo, "loaded")
	t.eq(v.fuel, Vehicle.FUEL_CAPACITY, "refuelled")
	t.ok(c.objective_text().begins_with("DELIVER: groceries -> Khutir"), "objective: " + c.objective_text())
	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 0.0)
	t.eq(c.prompt, "[E] Unload", "prompt at the khutir")
	c.call("_interact")
	t.ok(not v.has_cargo and c.job.is_empty(), "unloaded")
	t.eq(c.money, 250, "paid")
	t.ok(got.has("Loaded: groceries. Head for Khutir"), "messages: %s" % [got])
	t.ok(got.has("Delivered to Khutir! +$250"), "messages: %s" % [got])
	t.eq(c.offers.size(), 3, "new jobs on the board")
	c.message.disconnect(on_message)


func test_a_timed_job_pays_by_its_medal_and_keeps_its_record(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	_clear(c, v)
	c.money = 0
	var o := c.offer("farm", "timed")
	# The khutir is 195 m from the depot by road: 30, 22 and 15 km/h.
	t.eq(o.medals, PackedFloat32Array([24.0, 32.0, 47.0]), "medal times")
	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 0.0)
	c.take(o)
	c.clock = 20.0
	t.ok(c.objective_text().begins_with("TIMED 0:20: groceries -> Khutir"), "objective: " + c.objective_text())
	c.call("_interact")
	t.eq(c.money, 380, "gold pays 1.5 times $250")
	t.eq(c.profile.records.get(o.record, {}).get("medal", -1), 0, "the record's medal")
	c.take(o)
	c.clock = 60.0
	c.call("_interact")
	t.eq(c.money, 380 + 150, "no medal pays 0.6 times")
	t.eq(c.profile.records[o.record].time, 20.0, "a slower run is no record")
	c.profile.records.erase(o.record)


func test_a_fragile_load_breaks_on_hard_landings(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	_clear(c, v)
	c.money = 0
	var road: PackedVector2Array = t.world.roads[1]
	var dir := road[1] - road[0]
	await t.place(road[0], atan2(-dir.x, -dir.y))
	c.take(c.offer("farm", "fragile"))
	# Driving the road is no harm.
	v.awd = true
	v.drive_along(road.slice(1), 9.0)
	await t.ticks(600)
	v.autodrive = false
	v.awd = false
	var driven := c.integrity
	t.ok(driven > 0.95, "the road broke the load: %d%%" % roundi(driven * 100.0))
	# A drop of 4 m is.
	var farm: Vector2 = t.world.locations.farm.pos
	v.teleport(Vector3(farm.x, t.world.terrain.get_height(farm.x, farm.y - 4.0) + 5.2, farm.y - 4.0), 0.0)
	await t.ticks(120)
	t.note = "%d%% whole after the road, %d%% after a 4 m drop" % [roundi(driven * 100.0), roundi(c.integrity * 100.0)]
	t.ok(c.integrity < driven - 0.3, "a 4 m drop did not break it: %d%%" % roundi(c.integrity * 100.0))
	t.ok(c.integrity > 0.0, "a 4 m drop broke all of it")
	var whole := c.integrity
	var reward: int = c.job.reward
	c.call("_interact")
	t.eq(c.money, Contracts._round(reward * whole), "pays for what is whole")


func test_a_heavy_load_sits_low_and_drinks(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	_clear(c, v)
	var farm: Vector2 = t.world.locations.farm.pos
	var burnt := {}
	var sag := {}
	for kind in ["plain", "heavy"]:
		await t.place(farm + Vector2(0.0, -4.0), 0.0)
		c.take(c.offer("farm", kind))
		await t.ticks(60)
		sag[kind] = v.wheels[2].compression
		v.freeze = true
		v.awd = true
		var before := v.fuel
		Input.action_press(&"accelerate")
		await t.ticks(120)
		Input.action_release(&"accelerate")
		burnt[kind] = before - v.fuel
		v.freeze = false
		v.awd = false
		_clear(c, v)
	t.eq(Vehicle.BASE_MASS + Vehicle.HEAVY_MASS, 3800.0, "heavy mass")
	t.ok(sag.heavy > sag.plain + 0.03, "the heavy load does not sit lower: %.2f vs %.2f m" % [sag.heavy, sag.plain])
	t.ok(absf(burnt.heavy / burnt.plain - 1.5) < 0.05, "fuel: %.2f vs %.2f L" % [burnt.heavy, burnt.plain])
	t.eq(c.offer("farm", "heavy").reward, 400, "heavy pays 1.6 times $250")


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


func _clear(c: Contracts, v: Vehicle) -> void:
	c.call("_end_job")
	c.board_open = false
