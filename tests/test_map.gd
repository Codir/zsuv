extends RefCounted
## The one map (docs/plan.md §3, §12): its five biomes joined on one grid in the shared world. The
## bake matches the generator and loads in a moment; nothing stands on a road or floats; no border
## steps; every gate and every road open from the start drives both ways in 4x4; every barrier on
## the route stops a truck as built; the water runs along the river; the sky blends at a border.

const LOAD_BUDGET_MS := 4000  # the whole land built from the bake, trees and houses and all, natively


func test_the_bake_matches_the_generator_and_loads_in_a_moment(t: TCase) -> void:
	var bake := MapBake.load_current()
	if not t.ok(bake != null, "no current bake in %s (./godot.sh bake)" % MapBake.PATH):
		return
	t.ok(t.world.land.baked, "the shared world's land was generated, not loaded from the bake")
	var fresh := Land.new()
	fresh.build(Valley.steppe(), false)
	var made := fresh.bake()
	for id in made.heights:
		var a: PackedFloat32Array = made.heights[id]
		var b: PackedFloat32Array = bake.heights.get(id, PackedFloat32Array())
		if not t.eq(b.size(), a.size(), "%s: heights baked" % id):
			continue
		var worst := 0.0
		for i in a.size():
			worst = maxf(worst, absf(a[i] - b[i]))
		t.ok(worst < 0.01, "%s: the bake is stale, %.2f m off the generator (./godot.sh bake)" % [id, worst])
		var ga: PackedByteArray = made.grounds[id]
		var gb: PackedByteArray = bake.grounds.get(id, PackedByteArray())
		var off := 0
		for i in mini(ga.size(), gb.size()):
			off += 1 if absi(ga[i] - gb[i]) > 2 else 0
		t.ok(ga.size() == gb.size() and off == 0, "%s: the baked ground image is stale, %d bytes off" % [id, off])
	t.eq(bake.borders.size(), made.borders.size(), "borders baked")
	var paper := MapScreen.draw_paper(fresh)
	var off_px := 0
	for i in range(0, mini(paper.size(), bake.paper.size()), 4):
		off_px += 1 if absi(paper[i] - bake.paper[i]) > 2 else 0
	t.ok(paper.size() == bake.paper.size() and off_px == 0, "the baked paper map is stale, %d pixels off" % off_px)
	fresh.free()
	var t0 := Time.get_ticks_msec()
	var loaded := Land.new()
	loaded.build(Valley.steppe())
	var ms := Time.get_ticks_msec() - t0
	loaded.free()
	t.ok(ms < LOAD_BUDGET_MS, "the land took %d ms to build from the bake" % ms)
	t.note = "built from the bake in %d ms" % ms


func test_five_biomes_on_one_grid(t: TCase) -> void:
	var land: Land = t.world.land
	t.eq(land.tiles.size(), 5, "tiles")
	t.eq(land.bounds().size, Vector2(512, 768), "the map's size")
	var ids := []
	for v in Valley.all():
		ids.append(v.id)
		t.ok(v.biome != "", "%s has no biome name" % v.id)
	t.eq(ids, ["steppe", "khutir", "polissia", "zakarpattia", "carpathians"], "the biomes in the route's order")
	t.eq(land.borders.size(), 4, "borders")
	for b in land.borders:
		t.ok(b.unmatched.is_empty(), "%s|%s: a road ends on the border with none to meet it at %s" % [b.a.valley.id, b.b.valley.id, b.unmatched])
		t.eq(b.gates.size(), 1, "%s|%s: gates" % [b.a.valley.id, b.b.valley.id])
	# The walls stand only on the map's outer edges: a ray along the ground across each border meets none.
	var space: PhysicsDirectSpaceState3D = t.world.get_world_3d().direct_space_state
	for b in land.borders:
		var a: Terrain = b.a
		var across := Vector3(1, 0, 0) if b.side == "east" else Vector3(0, 0, 1)
		var at := Vector3(a.origin.x, 0.0, a.origin.y) + across * (Terrain.HALF - 3.0)
		at.y = land.get_height(at.x, at.z) + 60.0
		var q := PhysicsRayQueryParameters3D.create(at, at + across * 6.0)
		var hit := space.intersect_ray(q)
		t.ok(hit.is_empty(), "%s|%s: something stands on the border at %s" % [a.valley.id, b.b.valley.id, at])


func test_no_seam_has_a_step(t: TCase) -> void:
	var land: Land = t.world.land
	var worst := 0.0
	var worst_at := Vector2.ZERO
	for b in land.borders:
		var a: Terrain = b.a
		var o: Terrain = b.b
		for i in Terrain.N:
			var s := i - Terrain.HALF
			var p := (Vector2(Terrain.HALF, s) if b.side == "east" else Vector2(s, Terrain.HALF)) + a.origin
			var ha := a.heights[Land._edge(a, b.side, i)]
			var hb := o.heights[Land._edge(o, Land.OPPOSITE[b.side], i)]
			if absf(ha - hb) > 0.001:
				t.fail("%s|%s: the two sides are %.2f m apart at %s" % [a.valley.id, o.valley.id, absf(ha - hb), p])
				break
			# Across it the ground bends no more than it does anywhere: a metre either side, its slope
			# changes little.
			var n := Vector2(1, 0) if b.side == "east" else Vector2(0, 1)
			var kink := absf(land.get_height(p.x + n.x, p.y + n.y) - 2.0 * ha + land.get_height(p.x - n.x, p.y - n.y))
			if b.kind == "land" and kink > worst:
				worst = kink
				worst_at = p
	t.ok(worst < 0.5, "the ground bends %.2f m across a border at %s" % [worst, worst_at])
	t.note = "the sharpest bend across a border %.2f m, at %s" % [worst, worst_at]


func test_nothing_on_the_roads_and_nothing_floats(t: TCase) -> void:
	var world = t.world
	var land: Land = world.land
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.4, 2.2)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.exclude = land.bodies() + [world.vehicle.get_rid()]
	var hits := 0
	for tile in land.tiles:
		for r in tile.roads.size():
			var road: PackedVector2Array = tile.roads[r]
			for i in road.size() - 1:
				var n := ceili(road[i].distance_to(road[i + 1]) / 2.0)
				for k in n:
					var p := road[i].lerp(road[i + 1], float(k) / n) + tile.origin
					q.transform = Transform3D(Basis(), Vector3(p.x, land.get_height(p.x, p.y) + 1.4, p.y))
					var found := space.intersect_shape(q, 1)
					if not found.is_empty() and hits < 5:
						hits += 1
						t.fail("%s: road %d blocked at %s by %s" % [tile.valley.id, r, (p - tile.origin).snapped(Vector2.ONE), found[0].collider.get_parent().name])
	var floats := 0
	for wb in land.builders:
		for m in wb.find_children("*", "MeshInstance3D", true, false):
			var xf: Transform3D = m.global_transform
			if xf.basis.y.normalized().y < 0.9:
				continue
			var aabb: AABB = m.mesh.get_aabb()
			var low := INF
			var high := -INF
			for i in 4:
				var c := xf * (aabb.position + aabb.size * Vector3(i & 1, 0, (i >> 1) & 1))
				var gap := c.y - land.get_height(c.x, c.z)
				low = minf(low, gap)
				high = maxf(high, gap)
			if low <= 0.15 and high > 0.15:
				if floats < 5:
					t.fail("%s: a piece at %s floats %.2f m over the ground" % [wb.valley.id, Vector2(xf.origin.x, xf.origin.z).snapped(Vector2.ONE), high])
				floats += 1
	for p in land.anchor_points:
		if land.water_level(Vector2(p.x, p.z)) > -INF:
			t.fail("a tree or rock in the water at %s" % Vector2(p.x, p.z).snapped(Vector2.ONE))
			break


func test_every_gate_drives_both_ways(t: TCase) -> void:
	var land: Land = t.world.land
	var notes := PackedStringArray()
	for b in land.borders:
		if b.kind != "land":
			continue
		var a: Terrain = b.a
		var o: Terrain = b.b
		var path := _to_gate(a, b.side, 20.0) + _from_gate(o, Land.OPPOSITE[b.side], 20.0)
		for back in [false, true]:
			var way := path.duplicate()
			if back:
				way.reverse()
			var secs := await _drive(t, way)
			t.ok(secs > 0.0, "%s|%s: the gate does not drive %s" % [a.valley.id, o.valley.id, "back" if back else "out"])
			notes.append("%s-%s %.0f s" % [a.valley.id, o.valley.id, secs])
	t.note = ", ".join(notes)


func test_every_open_road_drives_both_ways(t: TCase) -> void:
	var land: Land = t.world.land
	var notes := PackedStringArray()
	for tile in land.tiles:
		var slowest := 0.0
		for r in tile.roads.size():
			if _barred(tile, r):
				continue
			for back in [false, true]:
				var road := PackedVector2Array()
				for p in tile.roads[r]:
					road.append(p + tile.origin)
				if back:
					road.reverse()
				var secs := await _drive(t, road)
				slowest = maxf(slowest, secs)
				t.ok(secs > 0.0, "%s: road %d %s does not get through" % [tile.valley.id, r, "back" if back else "out"])
		notes.append("%s %.0f s" % [tile.valley.id, slowest])
	t.note = "slowest road: " + ", ".join(notes)


func test_every_barrier_stops_a_truck(t: TCase) -> void:
	var land: Land = t.world.land
	var ways := {}  # what -> a path over it
	for b in land.borders:
		if b.kind == "land":
			continue
		var over := _to_gate(b.a, b.side) + _from_gate(b.b, Land.OPPOSITE[b.side])
		ways["the %s from %s" % [b.kind, b.a.valley.id]] = over
		var back := over.duplicate()
		back.reverse()
		ways["the %s from %s" % [b.kind, b.b.valley.id]] = back
	for tile in land.tiles:
		for ft in tile.valley.features:
			match ft.type:
				"washout":  # its road from 30 m before it to 15 m past
					ways["the washout in %s" % tile.valley.id] = _stretch(tile, int(ft.road), float(ft.s) - 30.0, float(ft.s) + 15.0)
				"slide":  # its road from 25 m before it to 25 m past, either way
					var r := int(ft.road)
					var s := float(ft.s)
					ways["the landslide in %s" % tile.valley.id] = _stretch(tile, r, s - 25.0, s + 25.0)
					var back := _stretch(tile, r, s - 25.0, s + 25.0)
					back.reverse()
					ways["the landslide in %s, back" % tile.valley.id] = back
	t.eq(ways.size(), 7, "barriers on the route: the river and the gorge both ways, the washout, the landslide both ways")
	for what in ways:
		var secs := await _drive(t, ways[what], 30)
		t.ok(secs == 0.0, "%s lets the pickup through in %.0f s" % [what, secs])
	t.note = ", ".join(ways.keys())


## Road r of tile from s0 to s1 metres along it, in the world.
func _stretch(tile: Terrain, r: int, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := maxf(s0, 0.0)
	while s < s1:
		out.append(tile.along(r, s)[0] + tile.origin)
		s += 2.0
	out.append(tile.along(r, s1)[0] + tile.origin)
	return out


func test_the_river_runs_along_its_border(t: TCase) -> void:
	var land: Land = t.world.land
	var river: Dictionary = land.borders.filter(func(b: Dictionary) -> bool: return b.kind == "river")[0]
	var a: Terrain = river.a
	var x := a.origin.x + Terrain.HALF
	var level := land.water_level(Vector2(x, a.origin.y))
	t.ok(level > -INF, "no water in the river")
	for z in range(-100, 101, 20):  # clear of the map's corners, where the next border meets it
		var p := Vector2(x, a.origin.y + z)
		t.ok(absf(land.water_level(p) - level) < 0.001, "the river's level is not one level at %s" % p)
		t.ok(land.get_height(p.x, p.y) < level - 0.5, "the river's bed at %s is %.1f, the water %.1f" % [p, land.get_height(p.x, p.y), level])
	t.eq(land.water_level(Vector2(x + 30.0, a.origin.y)), -INF, "water 30 m from the river")


func test_each_crossing_has_its_two_banks_at_the_roads_level(t: TCase) -> void:
	var land: Land = t.world.land
	var cs := land.crossings()
	t.eq(cs.size(), 2, "crossings: the river and the gorge")
	for c in cs:
		t.ok(c.over > 15.0 and c.over < 40.0, "the %s's gap is %.0f m" % [c.kind, c.over])
		t.ok(absf(c.a.y - c.b.y) < 4.0, "the %s's banks are %.1f m apart in height" % [c.kind, absf(c.a.y - c.b.y)])
		var mid: Vector3 = (c.a + c.b) * 0.5
		t.ok(land.get_height(mid.x, mid.z) < minf(c.a.y, c.b.y) - 2.0, "the %s's bed is not under its banks" % c.kind)
		t.ok(land.water_level(Vector2(mid.x, mid.z)) > land.get_height(mid.x, mid.z), "no water under the %s's crossing" % c.kind)
	t.note = ", ".join(cs.map(func(c: Dictionary) -> String: return "%s %.0f m" % [c.kind, c.over]))


func test_the_sites_spots_the_deposits_and_the_swamps_deep_water(t: TCase) -> void:
	var land: Land = t.world.land
	var kinds := {}
	for s in land.site_spots():
		kinds[s.kind] = kinds.get(s.kind, 0) + 1
		t.ok(typeof(s.get("needs")) == TYPE_DICTIONARY, "%s has no needs" % s.id)
		t.ok(not land.corridor_state(s).drivable or s.kind == "gravel_road", "%s is drivable as the flood left it" % s.id)
	t.eq(kinds, {"bridge": 2, "fill": 1, "slide": 1, "gravel_road": 1}, "road sites")
	t.eq(land.spot("bridge:river").needs, {"concrete": 2, "timber": 3}, "the river bridge needs")
	t.ok(int(land.site_spots().filter(func(s: Dictionary) -> bool: return s.kind == "gravel_road")[0].needs.get("gravel", 0)) >= 3, "the bog road needs too little gravel")
	var ds := land.deposits()
	t.eq(ds.size(), 3, "gravel deposits")
	for d in ds:
		t.ok(land.road_distance(d.pos) > float(d.radius), "a deposit on a road at %s" % d.pos)
	# The swamp's deep water: over its road, above a pickup's intake.
	var swamp: Terrain = land.tiles.filter(func(x: Terrain) -> bool: return x.valley.id == "polissia")[0]
	var lake: Dictionary = swamp.valley.features.filter(func(f: Dictionary) -> bool: return f.type == "lake" and f.has("water"))[0]
	var at: Vector2 = (lake.pos as Vector2) + swamp.origin
	var level := land.water_level(at)
	var deep := level - land.get_height(at.x, at.y)
	t.ok(deep > 1.0 and deep < 2.0, "the deep water over the swamp's road is %.2f m" % deep)
	t.ok(land.road_distance(at) < Terrain.ROAD_HALF_WIDTH, "the deep water is not on the road")
	t.eq(land.water_level(at + Vector2(40.0, 0.0)), -INF, "water 40 m from the deep water")
	t.note = "the swamp's deep water %.1f m over its road" % deep


func test_a_bridged_crossing_drives_both_ways_with_a_roads_grip(t: TCase) -> void:
	var land: Land = t.world.land
	var notes := PackedStringArray()
	for b in land.borders:
		if b.kind == "land":
			continue
		var s := land.spot("bridge:" + String(b.kind))
		var deck := land.build_deck(s)
		await t.ticks(2)
		# The road up to one bank, over the deck, and on from the other bank.
		var sa := Vector2(s.a.x, s.a.z)
		var sb := Vector2(s.b.x, s.b.z)
		var over := PackedVector2Array()
		for p in _to_gate(b.a, b.side):
			if p.distance_to(sb) > sa.distance_to(sb) + 1.0:
				over.append(p)
		over.append(sa)
		over.append(sb)
		for p in _from_gate(b.b, Land.OPPOSITE[b.side]):
			if p.distance_to(sa) > sa.distance_to(sb) + 1.0:
				over.append(p)
		for back in [false, true]:
			var way := over.duplicate()
			if back:
				way.reverse()
			var secs := await _drive(t, way, 40)
			t.ok(secs > 0.0, "the %s's bridge does not drive %s" % [b.kind, "back" if back else "over"])
			notes.append("%s %.0f s" % [b.kind, secs])
		# Halfway over, the wheels feel a road, not the riverbed under the deck.
		var mid: Vector3 = (s.a + s.b) * 0.5
		var space: PhysicsDirectSpaceState3D = t.world.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid + Vector3(0, 3, 0), mid - Vector3(0, 6, 0)))
		t.ok(not hit.is_empty() and hit.collider == deck and not land.is_ground(hit.collider), "the %s's deck is not under its middle" % b.kind)
		land.bridges.erase(s.id)
		deck.free()
	t.note = ", ".join(notes)


func test_the_sky_blends_across_a_border(t: TCase) -> void:
	var land: Land = t.world.land
	for b in land.borders:
		var a: Terrain = b.a
		var o: Terrain = b.b
		var n := Vector2(1, 0) if b.side == "east" else Vector2(0, 1)
		var edge := a.origin + n * Terrain.HALF
		var deep_a := land.weather_at(edge - n * 40.0)
		var deep_b := land.weather_at(edge + n * 40.0)
		t.ok(deep_a == a.valley.own and deep_b == o.valley.own, "%s|%s: a biome's own sky 40 m from the border" % [a.valley.id, o.valley.id])
		var mid := land.weather_at(edge + n * 0.01)
		var want := lerpf(a.valley.own.fog_density, o.valley.own.fog_density, 0.5)
		t.ok(absf(mid.fog_density - want) < 0.002, "%s|%s: on the border the fog is %.4f, halfway is %.4f" % [a.valley.id, o.valley.id, mid.fog_density, want])
		var prev := deep_a.sky
		var turns := 0
		for k in range(-40, 41, 5):
			var s := land.weather_at(edge + n * k).sky
			turns += 1 if s.get_luminance() != prev.get_luminance() else 0
			prev = s
		t.ok(turns >= 10, "%s|%s: the sky switches, it does not blend (%d changes)" % [a.valley.id, o.valley.id, turns])


## Whether road r of tile has a barrier on it: a gap span, a washout or a slide.
func _barred(tile: Terrain, r: int) -> bool:
	for g in tile.valley.gaps:
		if int(g.road) == r:
			return true
	for ft in tile.valley.features:
		if ft.type in ["washout", "slide"] and int(ft.road) == r:
			return true
		# Deep water over the road: past it only with a snorkel (§8; test_water drives it).
		if ft.type == "lake" and float(ft.get("water", 0.0)) > 1.0:
			for p in tile.roads[r]:
				if p.distance_to(ft.pos) < float(ft.radius) + float(ft.get("shore", 8.0)) * 0.5:
					return true
	return false


## Tile's road ending on side, in the world, ending at the gate (its last metres).
func _to_gate(tile: Terrain, side: String, metres := 40.0) -> PackedVector2Array:
	var g := _from_gate(tile, side, metres)
	g.reverse()
	return g


## Tile's road starting at the gate on side, in the world (its first metres).
func _from_gate(tile: Terrain, side: String, metres := 40.0) -> PackedVector2Array:
	for road in tile.roads:
		for k in 2:
			var r := road.duplicate()
			if k == 1:
				r.reverse()
			if Land._gates(tile, side).any(func(g: float) -> bool: return r[0].distance_to(_gate_point(side, g)) < 0.6):
				var out := PackedVector2Array([r[0] + tile.origin])
				var left := metres
				for i in r.size() - 1:
					var l := r[i].distance_to(r[i + 1])
					if l >= left:
						out.append(r[i].lerp(r[i + 1], left / l) + tile.origin)
						return out
					out.append(r[i + 1] + tile.origin)
					left -= l
				return out
	return PackedVector2Array()


static func _gate_point(side: String, g: float) -> Vector2:
	match side:
		"west":
			return Vector2(-Terrain.HALF, g - Terrain.HALF)
		"east":
			return Vector2(Terrain.HALF, g - Terrain.HALF)
		"north":
			return Vector2(g - Terrain.HALF, -Terrain.HALF)
	return Vector2(g - Terrain.HALF, Terrain.HALF)


## The seconds the autopilot takes the pickup in 4x4 from one end of path to the other, or 0 when
## it gets stuck (no 1 m in 8 s, or past limit s).
func _drive(t: TCase, path: PackedVector2Array, limit := 90) -> float:
	var truck: Vehicle = t.world.vehicle
	truck.awd = true
	# A fresh truck each run: the barriers' test floods its engine, and each flood costs a quarter.
	truck.condition = 1.0
	truck.flooded = false
	var a := path[0]
	var dir := path[1] - a
	truck.teleport(Vector3(a.x, t.world.land.get_height(a.x, a.y) + 1.2, a.y), atan2(-dir.x, -dir.y))
	await t.ticks(60)
	truck.fuel = truck.spec.fuel_capacity
	truck.drive_along(path.slice(1), 9.0)
	var end := path[path.size() - 1]
	var last := truck.global_position
	var still := 0
	for tick in 60 * limit:
		await t.tree.physics_frame
		if Vector2(truck.global_position.x, truck.global_position.z).distance_to(end) < 6.0:
			truck.autodrive = false
			return tick / 60.0
		if tick % 120 == 119:
			still = still + 1 if truck.global_position.distance_to(last) < 1.0 else 0
			last = truck.global_position
			if still >= 4:
				break
	truck.autodrive = false
	truck.throttle_input = 0.0
	return 0.0
