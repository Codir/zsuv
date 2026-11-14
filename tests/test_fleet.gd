extends RefCounted
## The trucks out on the map (docs/plan.md §8, §12): a truck left stays where it was with its fuel,
## load and trailer; switching works from the map and by E beside a truck; a truck far off is
## frozen and wakes when near or hooked; the garage fetches one out on the map; the tow takes only
## the truck being driven; a pickup with barrels refuels another truck, and a truck found with an
## empty tank runs once fuelled.

const OPEN := Vector2(-60.0, 40.0)  # khutir: open ground off the roads, west of the depot


func test_a_truck_left_stays_with_its_fuel_load_and_trailer(t: TCase) -> void:
	var w = t.world
	var fleet: Fleet = w.fleet
	var pickup: Vehicle = w.vehicle
	var tractor: Vehicle = await _parked(t, TruckSpec.tractor(), OPEN, 0.0)
	var farm := Trailer.new()
	farm.spec = TrailerSpec.farm()
	farm.terrain = w.terrain
	w.add_child(farm)
	farm.place(farm.behind(Transform3D(tractor.global_transform.basis, tractor.hitch_point())))
	await t.ticks(5)
	tractor.hitch(farm)
	t.eq(farm.hold.put("gravel"), 1.0, "a load of gravel in the farm trailer")
	tractor.fuel = 70.0
	await t.ticks(120)
	var at := tractor.global_position
	# The player drives the pickup off, 150 m away.
	t.ok(fleet.driven == pickup and not tractor.driven, "the tractor is driven")
	await t.place(OPEN + Vector2(150.0, 0.0), 0.0)
	await t.ticks(120)
	t.ok(tractor.global_position.distance_to(at) < 0.3, "the tractor moved %.2f m" % tractor.global_position.distance_to(at))
	t.ok(tractor.freeze and farm.freeze, "far off, the tractor and its trailer are not frozen")
	t.eq(tractor.fuel, 70.0, "its fuel")
	t.ok(tractor.trailer == farm and farm.truck == tractor, "its trailer let go")
	t.eq(tractor.rig_holding("gravel"), 1.0, "its load")
	t.ok(tractor.handbrake and not tractor.audio.running, "its engine on or its handbrake off")
	# Back near it, it wakes.
	await t.place(OPEN + Vector2(0.0, -14.0), 0.0)
	await t.ticks(10)
	t.ok(not tractor.freeze and not farm.freeze, "near it, the tractor is still frozen")
	await t.ticks(60)
	t.ok(tractor.global_position.distance_to(at) < 0.3, "woken, the tractor moved %.2f m" % tractor.global_position.distance_to(at))
	t.note = "far off it stood frozen, its trailer hitched with its gravel"
	await _done(t, [tractor], [farm])


func test_e_steps_across_and_the_map_switches(t: TCase) -> void:
	var w = t.world
	var fleet: Fleet = w.fleet
	var pickup: Vehicle = w.vehicle
	var scout := await _parked(t, TruckSpec.scout(), OPEN, 0.0)
	await t.place(OPEN + Vector2(4.0, 0.0), 0.0)  # side by side, 1.5 m apart
	await t.ticks(30)
	var gap := pickup.gap_to(scout)
	t.ok(gap < Fleet.STEP_ACROSS, "the two stand %.1f m apart" % gap)
	t.eq(fleet.prompt(), "[E] Drive the scout", "what E does")
	t.ok(fleet.interact(), "E does nothing")
	t.ok(w.vehicle == scout and fleet.driven == scout and scout.driven and not pickup.driven, "E did not step across into the scout")
	t.ok(w.camera_rig.target == scout and w.hud.vehicle == scout and w.contracts.vehicle == scout, "the camera, the HUD and the jobs did not follow")
	# Too far apart, E does not step across.
	scout.teleport(Vector3(OPEN.x + 20.0, w.terrain.get_height(OPEN.x + 20.0, OPEN.y) + 1.2, OPEN.y), 0.0)
	await t.ticks(60)
	t.ok(not fleet.interact() and w.vehicle == scout, "E stepped across 15 m")
	# On the map, a click on the pickup's mark drives it.
	w._toggle_map()
	var map: MapScreen = w.map_screen
	map._canvas.queue_redraw()
	await t.tree.process_frame
	var mark: Vector2 = map._to_map(Vector2(pickup.global_position.x, pickup.global_position.z))
	t.ok(map.truck_at(mark + Vector2(2, 1)) == pickup, "the pickup's mark is not on the map")
	t.ok(map.truck_at(mark + Vector2(40, 40)) == null, "a click off the mark finds a truck")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = mark
	map._unhandled_input(click)
	t.ok(w.vehicle == pickup and pickup.driven and not scout.driven, "a click on the map does not drive the pickup")
	t.ok(not map.visible, "the map stays open")
	await _done(t, [scout], [])


func test_a_hooked_truck_wakes_and_parked_trucks_burn_nothing(t: TCase) -> void:
	var w = t.world
	var six := await _parked(t, TruckSpec.six(), OPEN, 0.0)
	six.fuel = 100.0
	six.set_frozen(true)
	await t.place(OPEN + Vector2(0.0, 14.0), 0.0)  # behind it, facing it
	await t.ticks(30)
	t.ok(not six.freeze, "near, it stays frozen")
	six.set_frozen(true)  # as if it were far: the winch wakes it
	var pickup: Vehicle = w.vehicle
	var hook := six.global_transform * Vector3(0.0, 0.0, 3.0)
	pickup.winch.hook_body(six, six.global_transform.affine_inverse() * hook)
	t.ok(not six.freeze and six.hooked_by == pickup.winch, "hooked, it is still frozen")
	await t.ticks(60)
	t.ok(not six.handbrake, "hooked, its handbrake holds")
	pickup.winch.detach()
	await t.ticks(5)
	t.ok(six.hooked_by == null and six.handbrake, "let go, its handbrake is off")
	await t.ticks(300)
	t.eq(six.fuel, 100.0, "parked, it burns fuel")
	await _done(t, [six], [])


func test_the_garage_fetches_a_truck_out_on_the_map(t: TCase) -> void:
	var w = t.world
	var six := await _parked(t, TruckSpec.six(), OPEN, 0.0)
	six.fuel = 33.0
	w.set_truck(TruckSpec.six())
	await t.ticks(60)
	var spawn: Vector3 = w._spawn()
	t.ok(w.vehicle == six, "a second 6x6 came out of the garage")
	t.ok(Vector2(six.global_position.x - spawn.x, six.global_position.z - spawn.z).length() < 1.0, "the 6x6 is not at the depot")
	t.ok(absf(six.fuel - 33.0) < 0.2, "its fuel: %.1f L" % six.fuel)
	t.eq(w.fleet.trucks.size(), 1, "trucks out on the map")
	w.set_truck(TruckSpec.pickup())
	await t.ticks(10)
	t.ok(not is_instance_valid(six) or six.is_queued_for_deletion(), "the 6x6 left at the depot did not go into the garage")


func test_the_tow_takes_only_the_truck_driven(t: TCase) -> void:
	var w = t.world
	var c: Contracts = w.contracts
	var spawn: Vector3 = w._spawn()
	# A tractor left on the spawn, and another out on the map.
	var on_spawn := await _parked(t, TruckSpec.tractor(), Vector2(spawn.x, spawn.z), w.valley.spawn_yaw)
	var out := await _parked(t, TruckSpec.scout(), OPEN, 0.0)
	var pickup: Vehicle = w.vehicle
	await t.place(OPEN + Vector2(10.0, 30.0), 0.0)
	pickup.hold.put("parts")
	var tractor_at := on_spawn.global_position
	var scout_at := out.global_position
	c.recover()
	await t.ticks(90)
	var p := pickup.global_position
	t.ok(Vector2(p.x - spawn.x, p.z - spawn.z).length() < 12.0, "the pickup is not towed to the depot: %.1f m off" % Vector2(p.x - spawn.x, p.z - spawn.z).length())
	t.ok(pickup.gap_to(on_spawn) > 0.0, "the pickup was set down on the tractor")
	t.ok(on_spawn.global_position.distance_to(tractor_at) < 0.5, "the tractor on the spawn moved %.1f m" % on_spawn.global_position.distance_to(tractor_at))
	t.ok(out.global_position.distance_to(scout_at) < 0.3, "the scout out on the map moved %.1f m" % out.global_position.distance_to(scout_at))
	t.ok(pickup.hold.is_empty(), "the tow cost nothing: the parts are still on")
	t.note = "the pickup set down %.1f m from the spawn, beside the tractor" % Vector2(p.x - spawn.x, p.z - spawn.z).length()
	await _done(t, [on_spawn, out], [])


func test_a_pickup_with_barrels_refuels_a_truck_found_dry(t: TCase) -> void:
	var w = t.world
	var fleet: Fleet = w.fleet
	var pickup: Vehicle = w.vehicle
	var six := await _parked(t, TruckSpec.six(), OPEN, 0.0)
	six.fuel = 0.0  # found with an empty tank
	await t.place(OPEN + Vector2(4.5, 0.0), 0.0)
	await t.ticks(30)
	t.ok(fleet.prompt().begins_with("[E] Drive the"), "with no barrels: %s" % fleet.prompt())
	t.eq(pickup.rig_put("fuel"), 400.0, "litres of barrels on the pickup")
	t.ok(pickup.mass > pickup.spec.mass + 300.0, "the barrels weigh nothing")
	t.eq(fleet.prompt(), "[E] Pour fuel into the heavy 6x6", "what E does with barrels")
	# Dry, it does not go.
	fleet.drive_truck(six)
	six.autodrive = false
	await t.ticks(5)
	var start := six.global_position
	six.drive_along(PackedVector2Array([OPEN + Vector2(0.0, -30.0)]), 5.0)
	await t.ticks(120)
	six.autodrive = false
	t.ok(six.global_position.distance_to(start) < 0.5, "dry, it drove %.1f m" % six.global_position.distance_to(start))
	fleet.drive_truck(pickup)
	await t.ticks(30)
	t.ok(fleet.interact(), "E does not pour")
	t.eq(six.fuel, 150.0, "its tank after")
	t.eq(pickup.rig_holding("fuel"), 250.0, "litres left in the barrels")
	t.ok(fleet.interact() and w.vehicle == six, "full, E does not step across into it")
	start = six.global_position
	six.drive_along(PackedVector2Array([OPEN + Vector2(0.0, -30.0)]), 5.0)
	await t.ticks(180)
	six.autodrive = false
	t.ok(six.global_position.distance_to(start) > 2.0, "fuelled, it drove only %.1f m" % six.global_position.distance_to(start))
	# The rest of the barrels into a second dry truck: they run out first.
	var tractor := await _parked(t, TruckSpec.tractor(), OPEN + Vector2(9.0, 0.0), 0.0)
	tractor.fuel = 0.0
	fleet.drive_truck(pickup)
	pickup.hold.take("fuel", 200.0)
	await t.ticks(10)
	t.ok(fleet.pour_target() == tractor or fleet.pour_target() == six, "nothing to pour into")
	fleet.pour(tractor)
	t.eq(tractor.fuel, 50.0, "the tractor's tank from what was left")
	t.ok(pickup.hold.is_empty() and pickup.mass == pickup.spec.mass, "the barrels are not empty")
	await _done(t, [six, tractor], [])


## A truck of spec parked out on the map at p facing yaw, settled; the pickup still driven.
func _parked(t: TCase, spec: TruckSpec, p: Vector2, yaw: float) -> Vehicle:
	var w = t.world
	var v: Vehicle = w.park_truck(spec, Vector3(p.x, w.terrain.get_height(p.x, p.y) + 1.5, p.y), yaw)
	await t.ticks(90)
	return v


## The pickup driven again, and the trucks and trailers the test parked gone.
func _done(t: TCase, trucks: Array, trailers: Array) -> void:
	var w = t.world
	if w.vehicle.spec.id != "pickup":
		w.set_truck(TruckSpec.pickup())
	elif not w.fleet.driven == w.vehicle:
		w.fleet.drive_truck(w.vehicle)
	for v: Vehicle in trucks:
		if is_instance_valid(v) and v != w.vehicle:
			v.unhitch()
			w.fleet.remove(v)
			v.free()
	for tr in trailers:
		if is_instance_valid(tr):
			tr.free()
	w.vehicle.hold.clear()
	await t.ticks(2)
