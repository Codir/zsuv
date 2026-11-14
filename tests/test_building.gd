extends RefCounted
## Placing and building (docs/plan.md §5, §12): a footprint is green on level ground and red with
## the right reason on a slope, a road, ice, too near a place or another building, with too few
## trees for a sawmill or off a deposit for a quarry; P opens the list, a number picks, the wheel
## turns, Esc cancels; each load brought to a site counts and it stands when all are in; an empty
## site comes down; and on the steppe a fuel station is built from the railhead's loads.

const SCENE := preload("res://scenes/main.tscn")


func test_the_mouse_ray_meets_the_ground(t: TCase) -> void:
	var terrain: Terrain = t.world.land.home  # the home tile sits at the origin
	var height := func(x: float, z: float) -> float: return terrain.get_height(x, z)
	var hit: Variant = Cursor.ground(Vector3(20.0, 60.0, 30.0), Vector3(0.0, -1.0, 0.0), height)
	if t.ok(hit != null, "a ray straight down misses the ground"):
		t.ok(absf(hit.y - terrain.get_height(20.0, 30.0)) < 0.05, "the ray meets the ground %.2f m off" % (hit.y - terrain.get_height(20.0, 30.0)))
	var slant := Vector3(1.0, -0.3, 0.5).normalized()
	hit = Cursor.ground(Vector3(-60.0, 40.0, -20.0), slant, height)
	if t.ok(hit != null, "a slanting ray misses the ground"):
		t.ok(absf(hit.y - terrain.get_height(hit.x, hit.z)) < 0.05, "a slanting ray stops off the ground")
	t.eq(Cursor.ground(Vector3(0.0, 60.0, 0.0), Vector3.UP, height), null, "a ray at the sky")


func test_green_on_level_ground_red_with_the_reason(t: TCase) -> void:
	var infra: Infra = t.world.infra
	var terrain: Terrain = t.world.land.home  # the home tile sits at the origin
	_clear(infra)
	var level := spot(infra, "fuel_station", Vector2(-40.0, -40.0))
	if not t.ok(level.x < INF, "no level ground for a fuel station"):
		return
	t.eq(infra.check("fuel_station", level, 0.0), "", "on level ground")
	# A slope: the steepest ground a fuel station is otherwise allowed on.
	var slope := Vector2.INF
	for p in _grid(Vector2.ZERO, 110.0, 6.0):
		if infra.check("fuel_station", p, 0.0).begins_with("Not level:"):
			slope = p
			break
	if t.ok(slope.x < INF, "no slope found"):
		t.ok(infra.check("fuel_station", slope, 0.0).ends_with("m. Level it with the bucket"), "on a slope: " + infra.check("fuel_station", slope, 0.0))
	var road: PackedVector2Array = terrain.roads[0]
	var on_road := road[0].lerp(road[1], 0.5)
	t.eq(infra.check("fuel_station", on_road, 0.0), "On a road: build beside it", "on a road")
	var farm: Dictionary = t.world.locations.farm
	t.eq(infra.check("fuel_station", farm.pos + Vector2(farm.radius + 4.0, 0.0), 0.0), "Too near the Khutir", "beside a place")
	t.eq(infra.check("fuel_station", Vector2(130.0, 0.0), 0.0), "Off the map", "off the map")
	var site := infra.place("fuel_station", level, 0.0)
	if t.ok(site != null, "not placed on level ground"):
		t.eq(infra.check("fuel_station", level + Vector2(site.spec.size.x + 3.0, 0.0), 0.0), "Too near the fuel station site", "beside a site")
		t.eq(infra.place("fuel_station", level + Vector2(3.0, 0.0), 0.0), null, "placed on top of a site")
	_clear(infra)
	# A sawmill wants trees, a quarry a deposit.
	var mill := spot(infra, "sawmill", Vector2(-40.0, -40.0))
	if t.ok(mill.x < INF, "nowhere in the forest for a sawmill"):
		var all := infra.trees
		infra.trees = all.slice(0, 0)
		for p in all:
			if p.distance_to(mill) < 30.0 and infra.trees.size() < 5:
				infra.trees.append(p)
		t.eq(infra.check("sawmill", mill, 0.0), "Only %d trees here: a sawmill needs 12 within 40 m" % infra.trees.size(), "with few trees")
		infra.trees = all
	var everywhere := {"pos": Vector2.ZERO, "radius": 1000.0}
	infra.deposits.append(everywhere)
	var q := spot(infra, "quarry", Vector2(40.0, 40.0))
	infra.deposits.clear()
	if t.ok(q.x < INF, "no level ground for a quarry"):
		t.eq(infra.check("quarry", q, 0.0), "No gravel here: a quarry goes on a gravel deposit", "a quarry off a deposit")
		infra.deposits.append({"pos": q, "radius": 12.0})
		t.eq(infra.check("quarry", q, 0.0), "", "a quarry on a deposit")
		infra.deposits.clear()
	_clear(infra)


func test_red_on_the_ice(t: TCase) -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	var world = SCENE.instantiate()
	world.valley = Valley.polissia()
	world.profile = Profile.new()
	vp.add_child(world)
	t.tree.root.add_child(vp)
	await t.ticks(5)
	var lake := Vector2.INF  # on Polissia's frozen lake, off the road across it
	for p in _grid(Vector2(10.0, -12.0), 24.0, 2.0):
		if world.infra.check("fuel_station", p, 0.0) == "On ice":
			lake = p
			break
	t.ok(lake.x < INF, "nowhere on the lake says it is ice")
	vp.free()


func test_p_opens_the_list_the_wheel_turns_esc_cancels(t: TCase) -> void:
	var infra: Infra = t.world.infra
	var c: Contracts = t.world.contracts
	_clear(infra)
	await t.place(Vector2(-40.0, -40.0), 0.0, 60)
	Input.parse_input_event(_action(&"build"))
	await t.ticks(2)
	t.eq(infra.mode, Infra.Mode.PICK, "P does not open the list")
	t.ok(infra.panel.begins_with("BUILD") and infra.panel.contains("FUEL STATION") and infra.panel.contains("concrete 1, parts 1"), "the list: " + infra.panel)
	t.ok(t.world.hud.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.visible and l.text == infra.panel), "the list is not on screen")
	Input.parse_input_event(_key(KEY_1))
	await t.ticks(2)
	t.ok(infra.mode == Infra.Mode.PLACE and infra.picked.id == "fuel_station", "1 does not pick the fuel station")
	t.ok(infra._ghost.visible, "no footprint shown")
	t.ok(infra.prompt == infra.ghost_why or infra.prompt.begins_with("[LMB] Place the fuel station"), "prompt: " + infra.prompt)
	var yaw := infra.ghost_yaw
	Input.parse_input_event(_wheel(MOUSE_BUTTON_WHEEL_UP))
	await t.ticks(2)
	t.ok(is_equal_approx(infra.ghost_yaw, yaw + Infra.TURN), "the wheel does not turn it")
	var truck := Vector2(t.world.vehicle.global_position.x, t.world.vehicle.global_position.z)
	t.ok(infra.ghost_at.distance_to(truck) <= Infra.REACH + 0.01, "the footprint is %.0f m from the truck" % infra.ghost_at.distance_to(truck))
	var green := infra._ghost_mat.albedo_color.g > infra._ghost_mat.albedo_color.r
	t.eq(green, infra.ghost_why == "", "the footprint's colour")
	Input.parse_input_event(_key(KEY_ESCAPE))
	await t.ticks(2)
	t.ok(infra.mode == Infra.Mode.NONE and not infra._ghost.visible, "Esc does not cancel")
	t.ok(t.world.get_tree() != null and is_instance_valid(t.world), "Esc left the world")
	t.ok(not c.garage_open, "the garage opened")
	_clear(infra)


func test_each_load_counts_and_the_site_stands(t: TCase) -> void:
	var infra: Infra = t.world.infra
	var v: Vehicle = t.world.vehicle
	_clear(infra)
	var at := spot(infra, "fuel_station", Vector2(-40.0, -40.0))
	var site := infra.place("fuel_station", at, 0.0)
	if not t.ok(site != null, "not placed"):
		return
	t.ok(infra.take_down(site), "an empty site is not taken down")
	t.ok(not infra.sites.has(site), "the site is still listed")
	site = infra.place("fuel_station", at, 0.0)
	await t.place(_front(site), site.yaw + PI * 0.5, 60)
	t.eq(infra.here(), site, "the truck is not at the site")
	t.ok(infra.prompt.begins_with("[E] Bring: concrete 1, parts 1") and infra.prompt.ends_with("[P] take it down"), "prompt: " + infra.prompt)
	infra.interact()  # nothing on the truck
	t.eq(site.needs_left(), {"concrete": 1.0, "parts": 1.0}, "needs with nothing brought")
	Loads.put(v, "parts", 1.0)
	t.eq(Loads.amount(v, "parts"), 1.0, "parts on the pickup")
	t.eq(Loads.text(v), "PARTS 1", "the dashboard's load")
	infra.interact()
	t.eq(Loads.amount(v, "parts"), 0.0, "the parts are still on the pickup")
	t.eq(site.needs_left(), {"concrete": 1.0}, "needs after the parts")
	t.ok(not site.built, "built with half its needs")
	t.ok(not infra.take_down(site), "a site with parts in it is taken down")
	site.deliver("concrete", 1.0)
	t.ok(site.built, "not built with every need in")
	t.ok(site.find_children("*", "StaticBody3D", true, false).size() > 0, "the building has no body")
	t.ok(not infra.take_down(site), "a building is taken down")
	_clear(infra)


## The milestone for Nov 20: on the steppe, a fuel station placed and built from the railhead's
## parts and its plant's concrete, poured from a mixer (a stand-in on the pickup's body until the
## mixer is in), then filled with the railhead's fuel.
func test_a_fuel_station_on_the_steppe_from_the_railheads_loads(t: TCase) -> void:
	var shared: Vehicle = t.world.vehicle
	shared.autodrive = true  # deaf to the keys
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(480, 270)
	var world = SCENE.instantiate()
	world.valley = Valley.steppe()
	world.profile = Profile.new()
	vp.add_child(world)
	t.tree.root.add_child(vp)
	await t.ticks(30)
	var infra: Infra = world.infra
	var got: Array[String] = []
	infra.message.connect(func(text: String) -> void: got.append(text))
	var depot: Vector2 = world.locations.depot.pos
	var at := spot(infra, "fuel_station", depot, 30.0)
	if not t.ok(at.x < INF, "no level ground near the railhead"):
		vp.free()
		shared.autodrive = false
		return
	var site := infra.place("fuel_station", at, 0.0)
	t.note = "the fuel station %.0f m from the railhead" % at.distance_to(depot)
	# Parts from the railhead on the pickup.
	var v: Vehicle = world.vehicle
	await _stand(t, world, depot)
	t.eq(infra.here(), infra.railhead, "the pickup is not at the railhead")
	v.fuel = 10.0
	infra.interact()
	t.eq(v.fuel, v.spec.fuel_capacity, "the railhead does not fill the tank")
	var items: Array = infra.yard.map(func(i: Dictionary) -> String: return i.res)
	t.eq(items, ["fuel", "parts"], "what the pickup can load at the railhead")
	infra.load_item(items.find("parts"))
	t.eq(Loads.amount(v, "parts"), 1.0, "parts loaded")
	await _stand(t, world, _front(site), site.yaw + PI * 0.5)
	infra.interact()
	t.eq(site.needs_left(), {"concrete": 1.0}, "the site's needs after the parts")
	# Concrete from the railhead's plant, into the mixer under its chute.
	var mixer := TruckSpec.pickup()
	mixer.id = "mixer"
	mixer.title = "Mixer"
	world.set_truck(mixer)
	await t.ticks(2)
	v = world.vehicle
	await _stand(t, world, depot)
	infra.interact()
	items = infra.yard.map(func(i: Dictionary) -> String: return i.res)
	t.eq(items, ["concrete"], "what the mixer can load at the railhead")
	infra.load_item(0)
	t.eq(Loads.amount(v, "concrete"), 1.0, "concrete poured")
	t.eq(infra.railhead.stock.get("gravel", 0.0), 1.0, "the plant's gravel after a load")
	await _stand(t, world, _front(site), site.yaw + PI * 0.5)
	infra.interact()
	t.ok(site.built, "the fuel station does not stand: needs %s" % [site.needs_left()])
	t.ok(got.any(func(m: String) -> bool: return m.begins_with("The fuel station stands")), "no message: %s" % [got])
	# Fuel for it, in the pickup's barrels.
	world.set_truck(TruckSpec.pickup())
	await t.ticks(2)
	v = world.vehicle
	await _stand(t, world, depot)
	infra.interact()
	infra.load_item(0)
	t.eq(Loads.amount(v, "fuel"), 400.0, "the barrels")
	await _stand(t, world, _front(site), site.yaw + PI * 0.5)
	infra.interact()
	t.eq(site.fuel, 400.0, "fuel in the station")
	t.eq(Loads.amount(v, "fuel"), 0.0, "fuel left in the barrels")
	t.eq(world.profile.sites.filter(func(d: Dictionary) -> bool: return d.kind == "fuel_station" and d.built).size(), 1, "the station is not saved")
	vp.free()
	shared.autodrive = false


## Where a truck stands across site's footprint, 1.5 m in from its front (the building is at its back).
static func _front(site: Site) -> Vector2:
	return site.at + Vector2(0.0, -site.spec.size.y * 0.5 + 1.5).rotated(-site.yaw)


## Sets world's truck down at p, stopped.
static func _stand(t: TCase, world: Node, p: Vector2, yaw := 0.0) -> void:
	var v: Vehicle = world.vehicle
	v.autodrive = false
	v.teleport(Vector3(p.x, world.land.get_height(p.x, p.y) + 1.2, p.y), yaw)
	await t.ticks(60)


## The spot nearest near (on a 4 m grid), outside skip metres of it, where a kind can go turned 0;
## INF none.
static func spot(infra: Infra, kind: String, near: Vector2, skip := 0.0) -> Vector2:
	for p in _grid(near, 250.0, 4.0):
		if p.distance_to(near) >= skip and infra.check(kind, p, 0.0) == "":
			return p
	return Vector2.INF


## Points about c out to r, every step, nearest first.
static func _grid(c: Vector2, r: float, step: float) -> PackedVector2Array:
	var pts: Array[Vector2] = []
	var n := int(r / step)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var p := c + Vector2(i, j) * step
			if maxf(absf(p.x), absf(p.y)) < Terrain.HALF - 10.0:
				pts.append(p)
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(c) < b.distance_squared_to(c))
	return PackedVector2Array(pts)


## Takes every site and building in infra away, and the railhead back as it was.
static func _clear(infra: Infra) -> void:
	for s in infra.sites:
		s.queue_free()
	infra.sites.clear()
	infra.felled.clear()
	infra.railhead.stock = Infra.RAILHEAD_STOCK.duplicate()
	infra.mode = Infra.Mode.NONE
	infra.yard = []
	Loads.clear(infra.vehicle)


static func _action(a: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = true
	return ev


static func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	return ev


static func _wheel(b: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = b
	ev.pressed = true
	return ev
