class_name Earthworks
extends RefCounted
## Shifting the land (docs/plan.md §4): a bite of the ground taken, a load dumped, the ground
## slumping to a natural slope, on the land's 1 m vertices in the world's metres. Volume is kept:
## each vertex stands for 1 m², so what a bite takes off the heights is in m³ exactly what it
## returns, and a dump raises them by exactly what it places. An edit across a border edits both
## tiles (a vertex on it is in both).

const BITE_DEPTH := 0.15  # m, at most, off a patch BITE (across, along), rounded at its edges
const BITE := Vector2(2.2, 1.0)
const FLOOR := 3.0  # m below the ground as generated, no deeper
const CEILING := 6.0  # m above it, no higher
const OVER_WATER := 0.3  # m: never dug below a river's water and this
const SLUMP := 0.8  # m: a vertex more than this above its neighbour sheds half the excess
const SLUMP_REACH := 4  # vertices either way: the 9x9 m around a bite or a dump
const SLUMP_PASSES := 3
const CLEAR := 1.5  # m: trees and rocks this near a bite or a dump go
const DUMP_RADIUS := 2.0  # m a dump spreads over

var land: Land
var shifted := 0.0  # m³ dug in all, for the HUD and the end card
var keep_out: Array[Dictionary] = []  # more flats not to touch: {pos (world), radius, name} (a built site's)
var felled := PackedVector2Array()  # trees and rocks gone, in the world


func _init(l: Land) -> void:
	land = l


## Why the ground at p (world) cannot be dug or dumped on, or "" when it can.
func why_not(p: Vector2) -> String:
	if not land.on_map(p, 4.0):
		return "The map ends here"
	if land.sample(Vector3(p.x, 0.0, p.y)).ice > 0.3:
		return "Ice: nothing to dig here"
	for t in land.tiles:
		for loc in t.valley.locations.values():
			if p.distance_to(loc.pos + t.origin) < float(loc.radius) + 1.0:
				return "Not in the %s's yard" % String(loc.name).to_lower()
	for k in keep_out:
		if p.distance_to(k.pos) < float(k.radius) + 1.0:
			return "Not on the %s" % k.name
	return ""


## Takes a bite of the ground at p (world), the bucket facing forward: up to depth off a patch
## BITE big, rounded at its edges, no deeper than the floor nor below blade (the bucket's edge: it
## shaves what stands above it). Returns the m³ taken (0 when it may not dig there: why_not says
## why).
func bite(p: Vector2, forward: Vector2, depth := BITE_DEPTH, blade := -INF) -> float:
	if why_not(p) != "":
		return 0.0
	var f := forward.normalized()
	var side := Vector2(-f.y, f.x)
	var taken := 0.0
	var road_gone := false
	for z in range(floori(p.y) - 2, ceili(p.y) + 3):
		for x in range(floori(p.x) - 2, ceili(p.x) + 3):
			var d := Vector2(x, z) - p
			var w := (1.0 - smoothstep(BITE.x * 0.5 - 0.5, BITE.x * 0.5 + 0.5, absf(d.dot(side)))) \
				* (1.0 - smoothstep(BITE.y * 0.5 - 0.25, BITE.y * 0.5 + 0.5, absf(d.dot(f))))
			if w <= 0.0:
				continue
			var h := height(x, z)
			var drop := clampf(minf(depth * w, minf(h - floor_at(x, z), h - blade)), 0.0, depth)
			if drop <= 0.0:
				continue
			set_height(x, z, h - drop)
			taken += drop
			road_gone = road_gone or absf(h - drop - generated(x, z)) > 0.3
	if taken <= 0.0:
		return 0.0
	_paint(p, 1.4, Color(0.0, 0.0, 1.0), Color(1.0, 0.0, 1.0), road_gone)
	_clear(p)
	slump(p)
	shifted += taken
	return taken


## The bucket dragged back at level (back-blading): over a patch BITE big at p, what stands above
## level is shaved into carry (up to most m³ in all) and what lies below is filled from it. Returns
## what is carried on; the volume is kept.
func level(p: Vector2, forward: Vector2, at: float, carry: float, most: float) -> float:
	if why_not(p) != "":
		return carry
	var f := forward.normalized()
	var side := Vector2(-f.y, f.x)
	var pts: Array[Vector2i] = []
	for z in range(floori(p.y) - 2, ceili(p.y) + 3):
		for x in range(floori(p.x) - 2, ceili(p.x) + 3):
			var d := Vector2(x, z) - p
			if absf(d.dot(side)) <= BITE.x * 0.5 and absf(d.dot(f)) <= BITE.y * 0.5 + 0.5:
				pts.append(Vector2i(x, z))
	var moved := 0.0
	for v in pts:  # the humps first
		var h := height(v.x, v.y)
		var cut := clampf(minf(h - at, most - carry), 0.0, BITE_DEPTH)
		if cut > 0.0:
			set_height(v.x, v.y, h - cut)
			carry += cut
			moved += cut
	for v in pts:  # then the hollows
		var h := height(v.x, v.y)
		var fill := clampf(minf(at - h, carry), 0.0, BITE_DEPTH)
		if fill > 0.0:
			set_height(v.x, v.y, h + fill)
			carry -= fill
			moved += fill
	if moved > 0.0:
		_paint(p, 1.4, Color(1.0, 0.0, 0.0), Color(1.0, 0.0, 0.0), false)
		_clear(p)
	return carry


## Dumps volume m³ at p (world), heaped highest in the middle over DUMP_RADIUS m, no higher than
## the ceiling. Returns the m³ placed (what did not fit stays where it came from).
func dump(p: Vector2, volume: float) -> float:
	if volume <= 0.0 or why_not(p) != "":
		return 0.0
	var pts: Array[Vector2i] = []
	var weights := PackedFloat32Array()
	var total := 0.0
	for z in range(floori(p.y - DUMP_RADIUS), ceili(p.y + DUMP_RADIUS) + 1):
		for x in range(floori(p.x - DUMP_RADIUS), ceili(p.x + DUMP_RADIUS) + 1):
			var w := 1.0 - smoothstep(0.4, DUMP_RADIUS, Vector2(x, z).distance_to(p))
			if w > 0.0:
				pts.append(Vector2i(x, z))
				weights.append(w)
				total += w
	var placed := 0.0
	var road_gone := false
	for i in pts.size():
		var v := pts[i]
		var h := height(v.x, v.y)
		var rise := clampf(volume * weights[i] / total, 0.0, maxf(generated(v.x, v.y) + CEILING - h, 0.0))
		if rise > 0.0:
			set_height(v.x, v.y, h + rise)
			placed += rise
			road_gone = road_gone or absf(h + rise - generated(v.x, v.y)) > 0.3
	if placed <= 0.0:
		return 0.0
	_paint(p, DUMP_RADIUS, Color(1.0, 0.0, 0.0), Color(1.0, 1.0, 1.0), road_gone)
	_clear(p)
	slump(p)
	return placed


## The ground within SLUMP_REACH vertices of p relaxes: a vertex more than SLUMP above a
## neighbour sheds half the excess onto it, SLUMP_PASSES times over; what one loses the other
## gains, so the volume is kept.
func slump(p: Vector2) -> void:
	var cx := roundi(p.x)
	var cz := roundi(p.y)
	var r := SLUMP_REACH
	var n := 2 * r + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for z in n:
		for x in n:
			hs[z * n + x] = height(cx - r + x, cz - r + z)
	var before := hs.duplicate()
	for pass_i in SLUMP_PASSES:
		for z in n:
			for x in n:
				for nb: Vector2i in [Vector2i(x + 1, z), Vector2i(x, z + 1)]:
					if nb.x >= n or nb.y >= n:
						continue
					var i := z * n + x
					var j := nb.y * n + nb.x
					var diff := hs[i] - hs[j]
					if absf(diff) <= SLUMP:
						continue
					var move := (absf(diff) - SLUMP) * 0.5 * signf(diff)
					hs[i] -= move
					hs[j] += move
	for z in n:
		for x in n:
			if hs[z * n + x] != before[z * n + x]:
				set_height(cx - r + x, cz - r + z, hs[z * n + x])


## The steepest step between neighbouring vertices within reach of p: what the slump leaves.
func steepest_step(p: Vector2, reach: int) -> float:
	var worst := 0.0
	for z in range(roundi(p.y) - reach, roundi(p.y) + reach):
		for x in range(roundi(p.x) - reach, roundi(p.x) + reach):
			worst = maxf(worst, maxf(absf(height(x, z) - height(x + 1, z)), absf(height(x, z) - height(x, z + 1))))
	return worst


# --- The land's vertices, in the world ----------------------------------------------------------

func height(x: int, z: int) -> float:
	var t := land.tile_at(x, z)
	return t.heights[_index(t, x, z)]


func generated(x: int, z: int) -> float:
	var t := land.tile_at(x, z)
	return t.generated[_index(t, x, z)]


## The lowest the vertex may be dug: FLOOR under the ground as generated, and over a river's water.
func floor_at(x: int, z: int) -> float:
	var lowest := generated(x, z) - FLOOR
	var water := land.water_level(Vector2(x, z), 4.0)  # and not on its bank, where it would flood in
	if water > -INF:
		lowest = maxf(lowest, water + OVER_WATER)
	return lowest


## Sets the vertex in every tile it is in (one on a border is in two, or more at a corner).
func set_height(x: int, z: int, h: float) -> void:
	for t in _tiles_with(x, z):
		var l := Vector2i(x - roundi(t.origin.x) + Terrain.SIZE / 2, z - roundi(t.origin.y) + Terrain.SIZE / 2)
		t.set_vertex(l.x, l.y, h)


func _index(t: Terrain, x: int, z: int) -> int:
	var lx := clampi(x - roundi(t.origin.x) + Terrain.SIZE / 2, 0, Terrain.N - 1)
	var lz := clampi(z - roundi(t.origin.y) + Terrain.SIZE / 2, 0, Terrain.N - 1)
	return lz * Terrain.N + lx


func _tiles_with(x: int, z: int) -> Array[Terrain]:
	var out: Array[Terrain] = []
	for t in land.tiles:
		var lx := x - roundi(t.origin.x) + Terrain.SIZE / 2
		var lz := z - roundi(t.origin.y) + Terrain.SIZE / 2
		if lx >= 0 and lz >= 0 and lx < Terrain.N and lz < Terrain.N:
			out.append(t)
	return out


func _paint(p: Vector2, radius: float, works: Color, mask: Color, clear_road: bool) -> void:
	for t in land.tiles:
		var l := p - t.origin
		if absf(l.x) < Terrain.HALF + radius and absf(l.y) < Terrain.HALF + radius:
			t.paint(l, radius, works, mask, true, clear_road)


func _clear(p: Vector2) -> void:
	for i in land.tiles.size():
		var t := land.tiles[i]
		var l := p - t.origin
		if absf(l.x) < Terrain.HALF + CLEAR and absf(l.y) < Terrain.HALF + CLEAR:
			for q in land.builders[i].clear_near(l, CLEAR):
				felled.append(q + t.origin)


## The tree or rock at p (world) goes, as a bite beside it would take it.
func fell(p: Vector2) -> void:
	for i in land.tiles.size():
		var t := land.tiles[i]
		var l := p - t.origin
		if absf(l.x) <= Terrain.HALF and absf(l.y) <= Terrain.HALF:
			for q in land.builders[i].clear_near(l, 0.05):
				felled.append(q + t.origin)
