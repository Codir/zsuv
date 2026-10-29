extends RefCounted
## The ground of every valley: every place level, and beside every road no step where its nearest
## point jumps from one stretch of it to another (the legs of a hairpin) or to another road. A step,
## not a slope: what the road holds the ground to is looked at every 1/64 m between neighbouring
## pixels, and only what changes there faster than anything smooth counts. The terrain alone,
## without its world (the shared world's for the khutir valley).

const SHELF := Terrain.ROAD_HALF_WIDTH + 4.0  # how far from its centre line a road holds the ground
const MAX_STEP := 0.6  # m


func test_no_step_beside_the_roads_and_the_places_level(t: TCase) -> void:
	var notes := PackedStringArray()
	for v in Valley.all():
		var terrain: Terrain = t.world.terrain if v.id == t.world.valley.id else Terrain.new()
		if terrain != t.world.terrain:
			terrain.generate(v)
		var places: Array = terrain.valley.locations.values()
		for loc in places:
			var spread := _spread(terrain, loc.pos, float(loc.radius) - 2.0)
			t.ok(spread < 0.05, "%s: %s is not level, %.2f m from its lowest to its highest" % [v.id, loc.name, spread])
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
		notes.append("%s %.2f" % [v.id, worst])
		if terrain != t.world.terrain:
			terrain.free()
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
