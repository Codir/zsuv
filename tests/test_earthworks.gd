extends RefCounted
## Shifting the land (docs/plan.md §4, §12): a bite lowers the ground by what it puts in the
## tipper and a dump raises it by what came out; the floor, the ceiling and the flats hold; a
## wheel's ray meets the new height on the next tick; the slump leaves no step over 0.8 m; a tree
## in the way goes; and the tractor fills the steppe's washout with B and V, and then the pickup
## drives the road to the river.

const SCENE := preload("res://scenes/main.tscn")
const SPOT := Vector2(40.0, 60.0)  # open ground in the khutir valley, off its roads and places


func test_a_bite_and_a_dump_keep_the_volume(t: TCase) -> void:
	var ew: Earthworks = t.world.land.earthworks
	var p := _open(t, SPOT)
	var before := _volume(ew, p, 8)
	var taken := 0.0
	for i in 6:
		taken += ew.bite(p + Vector2(0.0, i * 0.7), Vector2(0, -1))
	var after_bite := _volume(ew, p, 8)
	t.ok(taken > 0.5, "the bites took %.2f m3" % taken)
	t.ok(absf((before - after_bite) - taken) <= taken * 0.02, "the ground fell %.3f m3, the bites took %.3f" % [before - after_bite, taken])
	var placed := ew.dump(p + Vector2(0.5, 1.0), taken)
	var after_dump := _volume(ew, p, 8)
	t.ok(absf((after_dump - after_bite) - placed) <= placed * 0.02, "the ground rose %.3f m3, the dump placed %.3f" % [after_dump - after_bite, placed])
	t.ok(absf(placed - taken) < 0.01, "the dump placed %.3f of %.3f" % [placed, taken])
	t.note = "%.2f m3 dug and put back" % taken
	t.world.land.reset_ground()


func test_the_floor_the_ceiling_and_the_flats_hold(t: TCase) -> void:
	var land: Land = t.world.land
	var ew := land.earthworks
	var p := _open(t, SPOT + Vector2(14.0, 0.0))
	for i in 60:
		ew.bite(p, Vector2(1, 0), 0.5)
	var low := INF
	var deepest := 0.0
	for z in range(-2, 3):
		for x in range(-2, 3):
			var q := Vector2i(roundi(p.x) + x, roundi(p.y) + z)
			deepest = maxf(deepest, ew.generated(q.x, q.y) - ew.height(q.x, q.y))
	t.ok(deepest <= Earthworks.FLOOR + 0.001, "dug %.2f m below the ground as made" % deepest)
	t.ok(deepest > Earthworks.FLOOR - 0.2, "60 bites dug only %.2f m" % deepest)
	var q := _open(t, SPOT + Vector2(28.0, 0.0))
	for i in 40:
		ew.dump(q, 6.0)
	var highest := 0.0
	for z in range(-3, 4):
		for x in range(-3, 4):
			var v := Vector2i(roundi(q.x) + x, roundi(q.y) + z)
			highest = maxf(highest, ew.height(v.x, v.y) - ew.generated(v.x, v.y))
	t.ok(highest <= Earthworks.CEILING + 0.001, "heaped %.2f m above the ground as made" % highest)
	# A place's flat: not a bite of it.
	var depot: Vector2 = t.world.locations.depot.pos
	var flat := land.get_height(depot.x, depot.y)
	t.eq(ew.bite(depot, Vector2(1, 0)), 0.0, "a bite of the depot's yard")
	t.ok(ew.why_not(depot).contains("yard"), "why not: '%s'" % ew.why_not(depot))
	t.eq(land.get_height(depot.x, depot.y), flat, "the depot's yard")
	# The river's water: never dug below it and 0.3 m.
	var river: Dictionary = land.borders.filter(func(b: Dictionary) -> bool: return b.kind == "river")[0]
	var bank := Vector2(-Terrain.HALF + 8.0, 60.0)  # on the river's bank, down to its water
	for i in 40:
		ew.bite(bank, Vector2(-1, 0), 0.5)
	var under := -INF  # the furthest any vertex there was dug under the water and 0.3 m
	for z in range(-2, 3):
		for x in range(-2, 3):
			var v := Vector2i(roundi(bank.x) + x, roundi(bank.y) + z)
			var lowest := minf(ew.generated(v.x, v.y), river.water_level + Earthworks.OVER_WATER)
			under = maxf(under, lowest - ew.height(v.x, v.y))
	t.ok(under <= 0.001, "dug %.2f m under the river's water and 0.3 m" % under)
	land.reset_ground()


func test_a_wheel_ray_meets_the_new_height_on_the_next_tick(t: TCase) -> void:
	var land: Land = t.world.land
	var p := _open(t, SPOT + Vector2(0.0, 18.0))
	var space: PhysicsDirectSpaceState3D = t.world.get_world_3d().direct_space_state
	var from := Vector3(p.x, land.get_height(p.x, p.y) + 20.0, p.y)
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 40, 0))
	var y0: float = space.intersect_ray(q).position.y
	land.earthworks.dump(p, 4.0)
	await t.tree.physics_frame
	var y1: float = space.intersect_ray(q).position.y
	t.ok(y1 > y0 + 0.3, "the ray met %.2f, the ground before %.2f" % [y1, y0])
	t.ok(absf(y1 - land.get_height(p.x, p.y)) < 0.02, "the ray met %.2f, the ground is %.2f" % [y1, land.get_height(p.x, p.y)])
	land.reset_ground()


func test_the_slump_leaves_no_step_over_0_8_m(t: TCase) -> void:
	var ew: Earthworks = t.world.land.earthworks
	var p := _open(t, SPOT + Vector2(-14.0, 18.0))
	for i in 20:
		ew.dump(p, 0.5)  # a tipper pours in fifths of a cubic metre or so
	var heap := ew.height(roundi(p.x), roundi(p.y)) - ew.generated(roundi(p.x), roundi(p.y))
	var step := ew.steepest_step(p, 4)
	t.ok(heap > 1.0, "the heap is only %.2f m" % heap)
	t.ok(step <= Earthworks.SLUMP + 0.05, "a step of %.2f m in the heap" % step)
	t.note = "a heap of %.1f m, its steepest step %.2f m" % [heap, step]
	t.world.land.reset_ground()


func test_a_tree_in_the_way_goes(t: TCase) -> void:
	var land: Land = t.world.land
	var wb: WorldBuilder = t.world.builder
	var tree: Dictionary = {}
	for pr in wb.props:
		if pr.kind == "tree" and pr.shape != null and land.earthworks.why_not(pr.p) == "":
			tree = pr
			break
	var at: Vector2 = tree.p
	var space: PhysicsDirectSpaceState3D = t.world.get_world_3d().direct_space_state
	var trunk := Vector3(at.x, land.get_height(at.x, at.y) + 1.5, at.y)
	var q := PhysicsRayQueryParameters3D.create(trunk + Vector3(3, 0, 0), trunk - Vector3(3, 0, 0))
	t.ok(not space.intersect_ray(q).is_empty(), "no trunk at %s to begin with" % at)
	land.earthworks.bite(at + Vector2(0.8, 0.0), Vector2(-1, 0))
	await t.ticks(2)
	t.ok(tree.shape == null, "the tree at %s still stands" % at)
	q.from = trunk + Vector3(3, -0.3, 0)
	q.to = trunk - Vector3(3, 0.3, 0)
	q.exclude = land.bodies()
	t.ok(space.intersect_ray(q).is_empty(), "something still stands where the tree was")
	t.ok(at in land.earthworks.felled, "the tree is not listed as gone")
	land.reset_ground()


func test_the_tractor_fills_the_washout_and_the_pickup_drives_to_the_river(t: TCase) -> void:
	var shared: Vehicle = t.world.vehicle
	shared.autodrive = true  # deaf to the keys pressed here
	shared.autodrive_path = PackedVector2Array()
	var profile := Profile.new()
	profile.rigs = PackedStringArray(["tractor", "farm"])
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(480, 270)
	var world = SCENE.instantiate()
	world.valley = Valley.steppe()
	world.profile = profile
	vp.add_child(world)
	t.tree.root.add_child(vp)
	await t.ticks(30)
	var land: Land = world.land
	var tile := land.home
	var ft: Dictionary = tile.valley.features.filter(func(f: Dictionary) -> bool: return f.type == "washout")[0]
	var r := int(ft.road)
	var s0 := float(ft.s)
	var road_dir: Vector2 = tile.along(r, s0)[1]
	var across := Vector2(-road_dir.y, road_dir.x)
	# The pickup cannot get through to the river as the flood left it.
	world.set_truck(TruckSpec.pickup())
	await t.ticks(2)
	t.ok(await _drive(t, world, _stretch(tile, r, s0 - 25.0, s0 + 20.0), 25) == 0.0, "the pickup gets over the washout before it is filled")
	# The tractor and its tipper.
	world.set_truck(TruckSpec.tractor())
	await t.ticks(2)
	var tractor: Vehicle = world.vehicle
	tractor.low_range = true
	tractor.awd = true
	var farm: Trailer = world.contracts._trailer("farm")
	var loads := 0
	var passes := 0
	var dug := 0.0
	while loads + passes < 24 and not _drivable(land, tile, r, s0):
		var low := _lowest(land, tile, r, s0)
		if low[0] > 0.3:
			# Dig a lane beside the road short of the washout, creeping along it with B held.
			var lane: Vector2 = tile.along(r, s0 - 22.0)[0] + across * (11.0 + (loads % 5) * 2.6)
			await _set_rig(t, tractor, farm, lane, road_dir)
			await _dig(t, tractor, farm, 40.0, Vector2.INF)
			dug += Loader.soil_in(farm)
			# Back the tipper up to the washout and pour the load into its lowest spots, a third at a time.
			var load := Loader.soil_in(farm)
			for k in 3:
				await _pour_at(t, tractor, farm, _lowest(land, tile, r, s0)[1], road_dir, load * (2 - k) / 3.0)
			loads += 1
		else:
			# Filled: drag the bucket back over the fill, both ways and in three lanes, shaving the
			# humps into the hollows.
			for lane in [-1.8, 0.0, 1.8]:
				for way in [1.0, -1.0]:
					var from: Vector2 = tile.along(r, s0 + 10.0 * way)[0] + across * lane
					var to: Vector2 = tile.along(r, s0 - 10.0 * way)[0] + across * lane
					await _set_rig(t, tractor, farm, from, road_dir * way)
					await _drag(t, tractor, to)
			passes += 1
	t.ok(_drivable(land, tile, r, s0), "after %d loads and %d passes the washout is not drivable: %s" % [loads, passes, _profile_note(land, tile, r, s0)])
	t.ok(land.earthworks.shifted >= dug - 0.1, "the m3 shifted %.1f, dug %.1f" % [land.earthworks.shifted, dug])
	# Then the pickup drives the road to the river.
	world.set_truck(TruckSpec.pickup())
	await t.ticks(2)
	var secs := await _drive(t, world, _stretch(tile, r, 0.0, _length(tile, r) - 24.0), 60)
	t.ok(secs > 0.0, "the pickup does not drive to the river over the fill: %s" % _profile_note(land, tile, r, s0))
	t.note = "%d loads and %d passes levelling, %.0f m3 dug, %.0f m3 shifted; the pickup to the river in %.0f s" % [loads, passes, dug, land.earthworks.shifted, secs]
	vp.free()
	shared.autodrive = false


## Whether the road over the washout drives as a road: along its centre line no metre climbs
## more than 0.4 m, and across it the ground is level to 0.5 m (docs/plan.md §5).
func _drivable(land: Land, tile: Terrain, r: int, s0: float) -> bool:
	var dir: Vector2 = tile.along(r, s0)[1]
	var across := Vector2(-dir.y, dir.x)
	var prev := INF
	for k in range(-8, 9):
		var c: Vector2 = tile.along(r, s0 + k)[0] + tile.origin
		var h := land.get_height(c.x, c.y)
		if prev < INF and absf(h - prev) > 0.4:
			return false
		prev = h
		var l := land.get_height(c.x - across.x * 3.0, c.y - across.y * 3.0)
		var rt := land.get_height(c.x + across.x * 3.0, c.y + across.y * 3.0)
		if absf(l - rt) > 0.5 or absf(l - h) > 0.5 or absf(rt - h) > 0.5:
			return false
	return true


func _profile_note(land: Land, tile: Terrain, r: int, s0: float) -> String:
	var out := PackedStringArray()
	for k in range(-8, 9, 2):
		var c: Vector2 = tile.along(r, s0 + k)[0] + tile.origin
		out.append("%.1f" % land.get_height(c.x, c.y))
	return "heights along it " + " ".join(out)


## Sets the tractor down at p facing dir with the tipper hitched straight behind, and lets it settle.
func _set_rig(t: TCase, tractor: Vehicle, farm: Trailer, p: Vector2, dir: Vector2) -> void:
	_creep(tractor, -1.0)
	if tractor.trailer == null:
		tractor.hitch(farm)
		await t.ticks(2)
	tractor.teleport(Vector3(p.x, tractor.land.get_height(p.x, p.y) + 1.2, p.y), atan2(-dir.x, -dir.y))
	await t.ticks(60)
	t.ok(tractor.trailer == farm, "the tipper came off the tractor at %s" % p)


## Keeps the tractor creeping at about speed m/s (0: stopped, -1: everything let go).
func _creep(tractor: Vehicle, speed: float) -> void:
	if speed < 0.0:
		Input.action_release("accelerate")
		Input.action_release("brake")
		return
	if tractor.forward_speed < speed:
		Input.action_release("brake")
		Input.action_press("accelerate", 0.6)
	else:
		Input.action_release("accelerate")
		Input.action_press("brake", 0.3)


## Road r of tile from s0 to s1 metres along it, in the world.
func _stretch(tile: Terrain, r: int, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := maxf(s0, 0.0)
	while s < s1:
		out.append(tile.along(r, s)[0] + tile.origin)
		s += 2.0
	out.append(tile.along(r, s1)[0] + tile.origin)
	return out


func _length(tile: Terrain, r: int) -> float:
	var total := 0.0
	for i in tile.roads[r].size() - 1:
		total += tile.roads[r][i].distance_to(tile.roads[r][i + 1])
	return total


## The seconds the autopilot takes the truck in play in 4x4 along path, or 0 when it gets stuck.
func _drive(t: TCase, world, path: PackedVector2Array, limit: int) -> float:
	var truck: Vehicle = world.vehicle
	truck.awd = true
	var a := path[0]
	var dir := path[1] - a
	truck.teleport(Vector3(a.x, world.land.get_height(a.x, a.y) + 1.2, a.y), atan2(-dir.x, -dir.y))
	await t.ticks(60)
	truck.fuel = truck.spec.fuel_capacity
	truck.drive_along(path.slice(1), 7.0)
	var end := path[path.size() - 1]
	var last := truck.global_position
	var still := 0
	for tick in 60 * limit:
		await t.tree.physics_frame
		if Vector2(truck.global_position.x, truck.global_position.z).distance_to(end) < 5.0:
			truck.autodrive = false
			return tick / 60.0
		if tick % 120 == 119:
			still = still + 1 if truck.global_position.distance_to(last) < 1.0 else 0
			last = truck.global_position
			if still >= 3:
				break
	truck.autodrive = false
	return 0.0


## The nearest point to p where the ground may be dug and dumped on, on the vertex grid.
func _open(t: TCase, p: Vector2) -> Vector2:
	var ew: Earthworks = t.world.land.earthworks
	for k in 40:
		var q := (p + Vector2(k * 3.0, 0.0)).round()
		if ew.why_not(q) == "" and t.world.land.road_distance(q) > 8.0:
			return q
	return p.round()


## The ground's volume over the (2 reach + 1)² vertices about p, m³ over 0.
func _volume(ew: Earthworks, p: Vector2, reach: int) -> float:
	var v := 0.0
	for z in range(roundi(p.y) - reach, roundi(p.y) + reach + 1):
		for x in range(roundi(p.x) - reach, roundi(p.x) + reach + 1):
			v += ew.height(x, z)
	return v


## [how far the lowest of the spots over the washout is under the road's level there, that spot
## (world)]: the road's level is the line between the ground 9 m either side of the washout.
func _lowest(land: Land, tile: Terrain, r: int, s0: float) -> Array:
	var dir: Vector2 = tile.along(r, s0)[1]
	var across := Vector2(-dir.y, dir.x)
	var a: Vector2 = tile.along(r, s0 - 9.0)[0] + tile.origin
	var b: Vector2 = tile.along(r, s0 + 9.0)[0] + tile.origin
	var ha := land.get_height(a.x, a.y)
	var hb := land.get_height(b.x, b.y)
	var best := [-INF, Vector2.ZERO]
	for k in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		for side in [-2.4, 0.0, 2.4]:
			var p: Vector2 = tile.along(r, s0 + k)[0] + tile.origin + across * side
			var deficit := lerpf(ha, hb, (k + 9.0) / 18.0) - land.get_height(p.x, p.y)
			if deficit > best[0]:
				best = [deficit, p]
	return best


## Creeps the tractor ahead with B held until the tipper is full, secs pass, or it is within 1.5 m
## of to (INF: no end).
func _dig(t: TCase, tractor: Vehicle, farm: Trailer, secs: float, to: Vector2) -> void:
	Input.action_press("dig")
	for tick in int(secs * 60.0):
		if Loader.soil_in(farm) >= Loader.TIPPER - 0.05:
			break
		if to != Vector2.INF and Vector2(tractor.global_position.x, tractor.global_position.z).distance_to(to) < 1.5:
			break
		_creep(tractor, 1.0)
		await t.tree.physics_frame
	Input.action_release("dig")
	_creep(tractor, -1.0)


## Backs the tipper up to pour at spot (world), the tractor facing away along dir, and tips it
## with V until what is left in it is down to keep.
func _pour_at(t: TCase, tractor: Vehicle, farm: Trailer, spot: Vector2, dir: Vector2, keep: float) -> void:
	var back := (tractor.spec.hitch.z - farm.spec.coupler.z) + farm.spec.extent().end.z + Loader.BEHIND
	var load := Loader.soil_in(farm)
	await _set_rig(t, tractor, farm, spot - dir * back, -dir)
	Loader.set_soil(farm, load)
	Input.action_press("tip")
	for tick in 60 * 6:
		if Loader.soil_in(farm) <= keep + 0.01:
			break
		_creep(tractor, -1.0)
		await t.tree.physics_frame
	Input.action_release("tip")


## Backs the tractor with B held (the bucket dragged level) until it is within 1.5 m of to.
func _drag(t: TCase, tractor: Vehicle, to: Vector2) -> void:
	Input.action_press("dig")
	for tick in 60 * 25:
		if Vector2(tractor.global_position.x, tractor.global_position.z).distance_to(to) < 1.5:
			break
		Input.action_release("accelerate")
		if tractor.forward_speed > -0.8:
			Input.action_press("brake", 0.6)
		else:
			Input.action_release("brake")
		await t.tree.physics_frame
	Input.action_release("dig")
	_creep(tractor, -1.0)
