extends RefCounted
## The ground of every valley: every place level, no road steeper than MAX_GRADE, and beside every
## road no step where its nearest point jumps from one stretch of it to another (the legs of a
## hairpin) or to another road. A step, not a slope: what the road holds the ground to is looked at
## every 1/64 m between neighbouring pixels, and only what changes there faster than anything smooth
## counts. Every tile of the shared world's land; a road's barriers (a gap span, a washout, a slide) are
## test_map.gd's.

const SHELF := Terrain.ROAD_HALF_WIDTH + 4.0  # how far from its centre line a road holds the ground
const MAX_STEP := 0.6  # m
## The steepest metre of any road, as a loaded truck in 2WD still climbs it (the khutir valley's
## road 1 is 0.46 m a metre; a climb off the Polissia ice of 0.62 was not).
const MAX_GRADE := 0.5


func test_no_step_beside_the_roads_and_the_places_level(t: TCase) -> void:
	var notes := PackedStringArray()
	for terrain: Terrain in t.world.land.tiles:
		var v := terrain.valley
		var places: Array = terrain.valley.locations.values()
		for loc in places:
			var spread := _spread(terrain, loc.pos, float(loc.radius) - 2.0)
			t.ok(spread < 0.05, "%s: %s is not level, %.2f m from its lowest to its highest" % [v.id, loc.name, spread])
		var steepest := 0.0
		for r in terrain.roads.size():
			var g := _steepest(terrain, terrain.roads[r])
			t.ok(g.x <= MAX_GRADE, "%s: road %d climbs %.2f m a metre, %.0f m along it" % [v.id, r, g.x, g.y])
			steepest = maxf(steepest, g.x)
		# What the road holds the ground to at each pixel, and how hard; in a place its flat does,
		# and where the roads keep to the ground, its ramp too (10 m at the least), laid after them.
		var held := 0.0 if v.road_smooth > 0.0 else 10.0
		var n := Terrain.N
		var shelf := PackedVector2Array()
		shelf.resize(n * n)
		for z in n:
			for x in n:
				var p := Vector2(x - Terrain.HALF, z - Terrain.HALF)
				var in_place := false
				for loc in places:
					in_place = in_place or p.distance_to(loc.pos) < float(loc.radius) + held
				if not in_place:
					shelf[z * n + x] = _shelf(terrain, p)
		var worst := 0.0
		var worst_at := Vector2.ZERO
		for z in n:
			for x in n:
				var i := z * n + x
				for j in [i + 1 if x < n - 1 else -1, i + n if z < n - 1 else -1]:
					if j < 0 or minf(shelf[i].x, shelf[j].x) * absf(shelf[i].y - shelf[j].y) < 0.3:
						continue
					var a := Vector2(x - Terrain.HALF, z - Terrain.HALF)
					var b := Vector2(j % n - Terrain.HALF, j / n - Terrain.HALF)
					var step := _step(terrain, a, b)
					if step > worst:
						worst = step
						worst_at = (a + b) * 0.5
		var near := terrain._road_closest(worst_at)
		t.ok(worst <= MAX_STEP, "%s: the ground steps %.2f m at %s, %.1f m from road %d" % [v.id, worst, worst_at, near.x, near.road])
		notes.append("%s %.2f (grade %.2f)" % [v.id, worst, steepest])
	t.note = "steepest step: " + ", ".join(notes)


## [road_t, the road's height] at p: how hard the road holds the ground there, and to what.
func _shelf(terrain: Terrain, p: Vector2) -> Vector2:
	var near := terrain._road_near(p)
	if near.x >= SHELF:
		return Vector2.ZERO
	return Vector2(1.0 - smoothstep(Terrain.ROAD_HALF_WIDTH, SHELF, near.x), terrain._road_height(p, near))


## How much the ground steps between a and b, 1 m apart, for the road: its changes over 1/64 m
## steeper than 3 m a metre, summed.
func _step(terrain: Terrain, a: Vector2, b: Vector2) -> float:
	var step := 0.0
	var prev := _shelf(terrain, a)
	for k in range(1, 65):
		var s := _shelf(terrain, a.lerp(b, k / 64.0))
		if absf(s.y - prev.y) > 3.0 / 64.0:
			step += minf(s.x, prev.x) * absf(s.y - prev.y)
		prev = s
	return step


## [the steepest metre of road, how far along it], along its centre line every 0.25 m.
func _steepest(terrain: Terrain, road: PackedVector2Array) -> Vector2:
	var pts := PackedVector2Array()
	for i in road.size() - 1:
		var n := ceili(road[i].distance_to(road[i + 1]) / 0.25)
		for k in n:
			pts.append(road[i].lerp(road[i + 1], float(k) / n))
	pts.append(road[road.size() - 1])
	var worst := Vector2.ZERO
	var along := 0.0
	for k in pts.size() - 4:
		var a := pts[k]
		var b := pts[k + 4]
		if terrain.barrier(a) or terrain.barrier(b):
			along += a.distance_to(pts[k + 1])
			continue
		var g := absf(terrain.get_height(b.x, b.y) - terrain.get_height(a.x, a.y)) / maxf(a.distance_to(b), 0.01)
		if g > worst.x:
			worst = Vector2(g, along)
		along += a.distance_to(pts[k + 1])
	return worst


## From the lowest of the ground to the highest within r of c.
func _spread(terrain: Terrain, c: Vector2, r: float) -> float:
	var lo := INF
	var hi := -INF
	for z in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if Vector2(x, z).distance_to(c) <= r:
				var h := terrain.heights[(z + int(Terrain.HALF)) * Terrain.N + x + int(Terrain.HALF)]
				lo = minf(lo, h)
				hi = maxf(hi, h)
	return hi - lo
