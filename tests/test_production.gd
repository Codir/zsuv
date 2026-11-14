extends RefCounted
## Production (docs/plan.md §5, §6, §12): a sawmill with fuel makes a load of timber every 2
## minutes, fells the tree nearest it each time, stops when full, out of fuel or felled out, and
## keeps going with the truck far away; a quarry makes gravel; a concrete plant turns gravel
## brought to it into concrete in a mixer under its chute; a fuel station fills a tank from its
## stock and runs dry; the tow loses the load; and a building's stock and timer are saved.

const B := preload("res://tests/test_building.gd")


func test_a_sawmill_makes_timber_while_it_has_fuel_and_trees(t: TCase) -> void:
	var infra: Infra = t.world.infra
	B._clear(infra)
	var mill := _built(t, infra, "sawmill", Vector2(-40.0, -40.0))
	if mill == null:
		return
	var trees := mill.trees_left
	infra._sync_felled()
	var before := infra.felled.duplicate()  # the trees its site took
	t.ok(trees >= 12, "only %d trees by the sawmill" % trees)
	infra.advance(130.0)
	t.eq(mill.stock.get("timber", 0.0), 0.0, "timber made with no fuel")
	t.eq(mill.status, "No fuel", "with no fuel")
	t.eq(mill.deliver("fuel", 100.0), 100.0, "fuel taken in")
	infra.advance(119.0)
	t.eq(mill.stock.get("timber", 0.0), 0.0, "timber made before 2 minutes")
	infra.advance(2.0)
	t.eq(mill.stock.get("timber", 0.0), 1.0, "timber after 2 minutes")
	t.eq(mill.fuel, 40.0, "fuel after a load, the next one started")
	t.eq(mill.trees_left, trees - 1, "trees left after a load")
	var new: Array = infra.felled.keys().filter(func(i: int) -> bool: return not before.has(i))
	t.eq(new.size(), 1, "trees felled for a load")
	if new.size() == 1:
		var nearest := INF
		for i in infra.trees.size():
			if not infra.felled.has(i):
				nearest = minf(nearest, infra.trees[i].distance_to(mill.at))
		var gone: Vector2 = infra.trees[new[0]]
		t.ok(gone.distance_to(mill.at) <= nearest, "the tree felled is not the nearest")
		t.ok(t.world.land.earthworks.felled.has(gone), "the tree felled still stands in the world")
	infra.advance(600.0)
	t.eq(mill.stock.get("timber", 0.0), 3.0, "a full sawmill's timber")
	t.eq(mill.status, "Full", "when full")
	t.eq(mill.fuel, 10.0, "fuel when full")
	t.ok(mill.line().begins_with("Sawmill: timber 3/3, 10 L,") and mill.line().ends_with("trees left, Full"), "its line: " + mill.line())
	mill.give("timber", 1.0)
	infra.advance(200.0)
	t.eq(mill.stock.get("timber", 0.0), 2.0, "timber made on 10 L")
	t.eq(mill.status, "No fuel", "out of fuel")
	# Felled out: every tree in reach gone.
	mill.deliver("fuel", 100.0)
	for i in infra.trees.size():
		if infra.trees[i].distance_to(mill.at) <= BuildingSpec.TREE_REACH:
			infra.felled[i] = true
	infra._fell(mill)
	infra.advance(200.0)
	t.eq(mill.trees_left, 0, "trees left")
	t.eq(mill.status, "Felled out", "with no trees")
	t.eq(mill.stock.get("timber", 0.0), 2.0, "timber made with no trees")
	B._clear(infra)


func test_production_goes_on_with_the_truck_far_away(t: TCase) -> void:
	var infra: Infra = t.world.infra
	B._clear(infra)
	var mill := _built(t, infra, "sawmill", Vector2(-40.0, -40.0))
	if mill == null:
		return
	mill.deliver("fuel", 100.0)
	await t.place(Vector2(90.0, 90.0), 0.0, 10)
	t.ok(t.world.vehicle.global_position.distance_to(mill.global_position) > 150.0, "the truck is near")
	infra.advance(119.0)
	await t.ticks(90)  # 1.5 s of game time, the truck far off
	t.eq(mill.stock.get("timber", 0.0), 1.0, "timber made with the truck far away")
	B._clear(infra)


func test_a_quarry_makes_gravel(t: TCase) -> void:
	var infra: Infra = t.world.infra
	B._clear(infra)
	infra.deposits.append({"pos": Vector2.ZERO, "radius": 1000.0})
	var at := B.spot(infra, "quarry", Vector2(40.0, 40.0))
	infra.deposits.clear()
	infra.deposits.append({"pos": at, "radius": 12.0})
	var quarry := _built(t, infra, "quarry", at)
	infra.deposits.clear()
	if quarry == null:
		return
	quarry.deliver("fuel", 50.0)
	infra.advance(91.0)
	t.eq(quarry.stock.get("gravel", 0.0), 1.0, "gravel after 90 s")
	t.eq(quarry.fuel, 10.0, "fuel after a load, the next one started")
	B._clear(infra)


func test_a_concrete_plant_pours_into_a_mixer(t: TCase) -> void:
	var infra: Infra = t.world.infra
	B._clear(infra)
	var plant := _built(t, infra, "plant", Vector2(40.0, 40.0))
	if plant == null:
		return
	t.world.set_truck(TruckSpec.mixer())
	await t.ticks(2)
	var v: Vehicle = t.world.vehicle
	await t.place(B._front(plant), plant.yaw + PI * 0.5, 60)
	infra.interact()
	t.eq(infra.yard.size(), 0, "concrete to load with no gravel in the plant")
	t.eq(plant.deliver("gravel", 6.0), 4.0, "gravel the plant takes")
	plant.deliver("fuel", 100.0)
	infra.interact()
	t.eq(infra.yard.map(func(i: Dictionary) -> String: return i.res), ["concrete"], "what the mixer loads")
	infra.load_item(0)
	t.eq(Loads.amount(v, "concrete"), 1.0, "concrete in the mixer")
	t.eq(plant.stock.get("gravel", 0.0), 3.0, "gravel left")
	t.eq(plant.fuel, 90.0, "fuel left")
	infra.interact()  # the list shuts
	infra.interact()
	t.eq(infra.yard.size(), 0, "a full mixer offered more concrete")
	t.world.set_truck(TruckSpec.pickup())
	await t.ticks(2)
	B._clear(infra)


func test_a_fuel_station_fills_a_tank_and_runs_dry(t: TCase) -> void:
	var infra: Infra = t.world.infra
	var v: Vehicle = t.world.vehicle
	B._clear(infra)
	var station := _built(t, infra, "fuel_station", Vector2(-40.0, -40.0))
	if station == null:
		return
	var got: Array[String] = []
	var on_message := func(text: String) -> void: got.append(text)
	infra.message.connect(on_message)
	await t.place(B._front(station), station.yaw + PI * 0.5, 60)
	v.fuel = 0.0
	infra.interact()
	t.eq(got.back() if not got.is_empty() else "", "Dry: bring fuel", "an empty station")
	t.eq(v.fuel, 0.0, "fuel from an empty station")
	Loads.put(v, "fuel", 400.0)
	infra.interact()
	t.eq(station.fuel, 400.0, "the barrels into the station")
	infra.interact()
	t.eq(v.fuel, v.spec.fuel_capacity, "the tank from the station")
	t.eq(station.fuel, 400.0 - v.spec.fuel_capacity, "the station after filling a tank")
	t.eq(got.back(), "Tank is full", "message")
	station.fuel = 5.0
	v.fuel = 0.0
	infra.yard = []  # the list E opened, shut
	infra.interact()
	t.eq(v.fuel, 5.0, "what a nearly dry station gives")
	t.eq(station.fuel, 0.0, "the station run dry")
	infra.yard = []
	infra.interact()
	t.eq(got.back(), "Dry: bring fuel", "a station run dry")
	v.fuel = v.spec.fuel_capacity
	infra.message.disconnect(on_message)
	B._clear(infra)


func test_the_tow_loses_the_load(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	Loads.put(v, "parts", 1.0)
	t.ok(v.has_cargo, "no crates on the bed")
	c.recover()
	await t.ticks(5)
	t.eq(Loads.amount(v, "parts"), 0.0, "the load after the tow")
	t.ok(not v.has_cargo, "the crates are still on the bed")


func test_buildings_are_saved_with_their_stock_and_timers(t: TCase) -> void:
	var infra: Infra = t.world.infra
	B._clear(infra)
	var mill := _built(t, infra, "sawmill", Vector2(-40.0, -40.0))
	if mill == null:
		return
	mill.deliver("fuel", 100.0)
	infra.advance(150.0)
	var site := infra.place("fuel_station", B.spot(infra, "fuel_station", Vector2(40.0, -40.0)), 0.0)
	if not t.ok(site != null, "nowhere for a fuel station"):
		B._clear(infra)
		return
	site.yaw = 0.5  # turned, as saved
	site.deliver("parts", 1.0)
	infra.railhead.stock["timber"] = 3.0
	infra._save()
	var path := "user://test_production.cfg"
	var p: Profile = t.world.profile
	var keep := p.path
	p.path = path
	p.save()
	p.path = keep
	var q := Profile.open(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var loaded := Infra.new()
	t.world.add_child(loaded)
	loaded.setup(t.world.vehicle, t.world.land, q, null, t.world.locations, t.world.builder.tree_points)
	var placed := loaded.sites.filter(func(x: Site) -> bool: return x != loaded.village)
	t.eq(placed.size(), 2, "sites loaded")
	if placed.size() == 2:
		var m: Site = placed[0]
		var s: Site = placed[1]
		t.ok(m.built and m.spec.id == "sawmill" and m.at == mill.at, "the sawmill")
		t.eq(m.stock, mill.stock, "the sawmill's stock")
		t.eq(m.fuel, mill.fuel, "the sawmill's fuel")
		t.ok(absf(m.timer - mill.timer) < 0.01 and m.timer > 0.0, "the sawmill's timer %.1f, saved %.1f" % [m.timer, mill.timer])
		t.eq(m.trees_left, mill.trees_left, "the trees left")
		t.ok(not s.built and s.spec.id == "fuel_station" and is_equal_approx(s.yaw, 0.5), "the site")
		t.eq(s.needs_left(), {"concrete": 1.0}, "the site's needs")
	t.eq(loaded.railhead.stock.get("timber", 0.0), 3.0, "the railhead's timber")
	infra._sync_felled()
	t.eq(loaded.felled.size(), infra.felled.size(), "the trees felled")
	loaded.land = null  # it saves nothing on its way out
	loaded.free()
	B._clear(infra)


## A building of kind standing near near: placed on the first spot it can go and built.
func _built(t: TCase, infra: Infra, kind: String, near: Vector2) -> Site:
	var at := B.spot(infra, kind, near)
	var site := infra.place(kind, at, 0.0) if at.x < INF else null
	if not t.ok(site != null, "nowhere to put a %s" % kind):
		return null
	for res in site.spec.needs:
		site.deliver(res, float(site.spec.needs[res]))
	t.ok(site.built, "the %s is not built" % kind)
	return site
