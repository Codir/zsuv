class_name Terrain
extends Node3D
## Procedural 256x256 m terrain from a Valley: heights + a snow (or dust) and mud layer that the
## wheels deform, ice on frozen lakes. One tile of the Land (docs/plan.md §3): its node stands at
## origin, everything here is in the tile's own metres (-128..128), and Land turns the world's
## into them. shape() makes the ground, Land joins the tiles at their borders, finish() builds
## what is seen and what is driven on.

const SIZE := 256
const HALF := 128.0
const N := SIZE + 1
const TRACK_RES := SIZE * 2 + 1  # 0.5 m per pixel
const CHUNK := 32
const CHUNKS := SIZE / CHUNK  # chunks a side
const MAX_SNOW := 0.8
const MAX_MUD := 0.4
const ROAD_HALF_WIDTH := 3.5
const LOOSE := 0.3  # m: how deep loose earth is soft, as snow that deep

signal ground_changed(rect: Rect2i)  # vertices whose heights changed (once a tick at most)

const GROUND_SHADER := preload("res://shaders/terrain_ground.gdshader")
const SNOW_SHADER := preload("res://shaders/terrain_snow.gdshader")


class Surface:
	var grip := 1.0
	var rolling := 0.015
	var snow := 0.0  # the soft layer's depth, m: snow, or dust (valley.layer)
	var mud := 0.0
	var ice := 0.0


var valley: Valley
var heights := PackedFloat32Array()
var snow_img: Image  # R - snow or dust, G - mud, B - road, A - 1 - ice
var track_img: Image  # compaction 0..1
var track_tex: ImageTexture
var roads: Array[PackedVector2Array] = []
var body: StaticBody3D  # its collision: a height map per CHUNK, all under this one body
var origin := Vector2.ZERO  # the tile's middle in the world
var keep_clear: Array[Rect2] = []  # where nothing is to stand (a river's bed and banks), in its own metres
var outer := {"west": true, "east": true, "north": true, "south": true}  # its edges that are the map's
var height_img: Image  # heights as the shaders read them (FORMAT_RF)
var height_tex: ImageTexture
var ground_mat: ShaderMaterial
var snow_mat: ShaderMaterial
var snow_tex: ImageTexture
var _chunk_meshes: Array = []  # per chunk, row by row: [its ground mesh, its snow mesh]
var _chunk_shapes: Array[HeightMapShape3D] = []  # per chunk, row by row

var _track_dirty := false
var _track_timer := 0.0
var _ground_timer := 0.0
var _heights_dirty := false
var _images_dirty := false
var _dirty_chunks: Array[Vector2i] = []
var edited := {}  # Vector2i chunk -> true: every chunk an earthwork touched since the ground was made
var works_img: Image  # 0.5 m a pixel: R loose earth, G gravel spread, B bare earth (docs/plan.md §4)
var works_tex: ImageTexture
var generated := PackedFloat32Array()  # the heights as the map was made, before any earthworks
var _ground_made: Image  # the ground image as the map was made
var _base: FastNoiseLite
var _profiles: Array[Dictionary] = []  # per road: {at: cumulative length at each point, h: heights every PROFILE_STEP}
var _seg_road := PackedInt32Array()  # every segment of every road in order: its road,
var _seg_a := PackedVector2Array()  # its ends,
var _seg_b := PackedVector2Array()
var _seg_along := PackedFloat64Array()  # and the metres along its road where it starts
var _all_segs := PackedInt32Array()
var _grid: Array[PackedInt32Array] = []  # per GRID_CELL square of the map: the segments within NEAR m of it

const PROFILE_STEP := 2.0
const DITCH_BANK := 2.4  # how far past its edge a ditch blends back into the ground
const PIN := 14.0  # a smoothed road keeps to the ground this far from its ends: across the place there
const NEAR := 12.0  # the ground looks at the roads this near it: their shelves and where two blend
const GRID_CELL := 4.0
const GRID := int(SIZE / GRID_CELL) + 1  # squares a side, one past the map's far edge
const NO_ROAD := {"x": INF}  # _road_near where no road is that near


## The ground of v, seen and driven on: a tile on its own, every edge the map's.
func generate(v: Valley) -> void:
	shape(v)
	finish()


## The ground of v (heights and the ground image), before the tile is joined to its neighbours:
## edges is which of its edges are the map's (the rim climbs only there).
func shape(v: Valley, edges := {"west": true, "east": true, "north": true, "south": true}) -> void:
	outer = edges
	prepare(v)
	var detail := _noise(v.seed + 1, 0.05, 2)
	var snow_noise := _noise(v.seed + 2, 0.03, 2)
	var mud_noise := _noise(v.seed + 3, 0.025, 2)
	var flats: Array = v.locations.values()
	var lakes: Array[Dictionary] = []
	var ditches: Array[Dictionary] = []
	var cuts: Array[Dictionary] = []  # washouts and slides, laid after the roads' shelves
	for ft in v.features:
		match ft.type:
			"lake":
				lakes.append(ft)
			"ditch":
				ditches.append(ft)
			"washout", "slide":
				cuts.append(ft)

	heights.resize(N * N)
	snow_img = Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	for z in N:
		for x in N:
			var p := Vector2(x - HALF, z - HALF)
			var b := base_height(p)
			var h := b + detail.get_noise_2d(p.x, p.y) * v.detail
			# A road is a shelf: as high as the ground at its centre line, level across; none over
			# a gap span (a bridge site), where the ground keeps its gorge or riverbed.
			var near := _road_near(p)
			var rd: float = near.x
			var gap := _gap(near)
			var road_t := (1.0 - smoothstep(ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 4.0, rd)) * (1.0 - gap)
			# A smoothed road is laid after the ramps off the places, which it was smoothed over.
			var road_last := v.road_smooth > 0.0
			if road_t > 0.0 and not road_last:
				h = lerpf(h, _road_height(p, near), road_t)
			# A lake and its shore go in before the flats, so a place on the shore stays level.
			var ice := 0.0
			for l in lakes:
				var r: float = l.radius
				var d := p.distance_to(l.pos)
				var shore := 1.0 - smoothstep(r * 0.8, r + float(l.get("shore", 8.0)), d)
				h = lerpf(h, l.height, shore)
				b = lerpf(b, l.height, shore)  # the ground a ramp off a place has to reach
				if l.get("ice", false):
					ice = maxf(ice, 1.0 - smoothstep(r * 0.82, r * 0.92, d))
			# The rim at the map's edge goes on after the flats, so a long ramp off a location
			# near the edge cannot drag the rim down with it. Only on the map's edges: where the
			# tile meets another, the land goes on.
			var rim := smoothstep(100.0, 126.0, _toward_edge(p)) * v.rim * (1.0 - road_t)
			var flat_t := 0.0
			for f in flats:
				var r: float = f.radius
				var d := p.distance_to(f.pos)
				# The higher the step down to the ground around, the longer the ramp off the
				# flat, so the roads out of a location stay drivable.
				var ramp := clampf(absf(b - f.height) * 5.0, 10.0, v.ramp_max)
				h = lerpf(h, f.height, 1.0 - smoothstep(r, r + ramp, d))
				rim *= smoothstep(r, r + 10.0, d)
				flat_t = maxf(flat_t, 1.0 - smoothstep(r - 3.0, r, d))
			for f in flats:  # a place's own flat wins over another place's long ramp
				h = lerpf(h, f.height, 1.0 - smoothstep(f.radius - 3.0, f.radius, p.distance_to(f.pos)))
			if road_t > 0.0 and road_last:
				h = lerpf(h, _road_height(p, near), road_t)
				for f in flats:  # a place stays level where the road arrives in it
					h = lerpf(h, f.height, 1.0 - smoothstep(f.radius - 3.0, f.radius, p.distance_to(f.pos)))
			# What the flood did after the roads were made: washouts cut across them, slides
			# over them.
			var cut := 0.0
			for ft in cuts:
				cut += _cut(ft, p)
			h += rim + cut
			heights[z * N + x] = h

			var on_road := (1.0 - smoothstep(ROAD_HALF_WIDTH - 0.5, ROAD_HALF_WIDTH + 1.0, rd)) * (1.0 - gap)
			on_road *= 1.0 - smoothstep(0.2, 0.4, absf(cut))  # the road is gone where the ground moved
			var snow := clampf(v.layer_base + snow_noise.get_noise_2d(p.x, p.y) * v.layer_noise, v.layer_min, 1.0)
			snow *= 1.0 - maxf(on_road * (1.0 - v.layer_on_road), flat_t * 0.9)
			if v.layer_from > -INF:
				snow *= smoothstep(v.layer_from, v.layer_from + 4.0, h)
			var mud := smoothstep(v.mud_from, v.mud_from + 0.2, mud_noise.get_noise_2d(p.x, p.y)) * (1.0 - maxf(on_road, flat_t))
			if v.mud_below < INF:
				mud *= 1.0 - smoothstep(v.mud_below, v.mud_below + 4.0, h)
			for pd in v.puddles:
				var pr: float = pd.radius
				mud = maxf(mud, 1.0 - smoothstep(pr * 0.5, pr, p.distance_to(pd.pos)))
			snow *= 1.0 - ice
			mud *= 1.0 - ice
			snow_img.set_pixel(x, z, Color(snow, mud, on_road, 1.0 - ice))
	_dig(ditches)


## What the ground needs of v before its heights: the roads' profiles and index, the places' and
## the lakes' levels. A baked tile (Land) loads its heights and does only this.
func prepare(v: Valley) -> void:
	valley = v
	roads = v.roads
	_base = _noise(v.seed, 0.008, 3)
	for f in v.locations.values():
		f.height = base_height(f.pos) - float(f.get("below", 0.0))
	for ft in v.features:
		if ft.type == "lake":
			ft.height = base_height(ft.pos) - float(ft.depth)
	_profiles.clear()
	for road in roads:
		_profiles.append(_profile(road, v.road_smooth))
	_index_roads()


## What is seen and what is driven on, from the heights as they are now.
func finish() -> void:
	_build_visuals()
	_build_collision()


## How far p is toward the nearest of the map's edges among this tile's (as max(|x|, |z|) is for
## a tile on its own); -INF when none of its edges is the map's.
func _toward_edge(p: Vector2) -> float:
	var t := -INF
	if outer.get("west", true):
		t = maxf(t, -p.x)
	if outer.get("east", true):
		t = maxf(t, p.x)
	if outer.get("north", true):
		t = maxf(t, -p.y)
	if outer.get("south", true):
		t = maxf(t, p.y)
	return t


## 1 where the road nearest (near) crosses one of the valley's gap spans (a bridge site), easing
## to 0 over 2 m at its ends; 0 off it or off the roads.
func _gap(near: Dictionary) -> float:
	if near.x == INF or valley.gaps.is_empty():
		return 0.0
	var g := 0.0
	for span in valley.gaps:
		if int(span.road) != int(near.road):
			continue
		var s: float = near.s
		g = maxf(g, smoothstep(float(span.from) - 2.0, float(span.from), s) * (1.0 - smoothstep(float(span.to), float(span.to) + 2.0, s)))
	return g


## The point s metres along road r and the road's way there.
func along(r: int, s: float) -> Array:
	var road := roads[r]
	var left := s
	for i in road.size() - 1:
		var l := road[i].distance_to(road[i + 1])
		if left <= l or i == road.size() - 2:
			var d := (road[i + 1] - road[i]) / l
			return [road[i] + d * clampf(left, 0.0, l), d]
		left -= l
	return [road[road.size() - 1], Vector2.RIGHT]


## Whether p is on one of the roads' barriers as generated: a gap span, or where a washout or a
## slide moved the ground.
func barrier(p: Vector2) -> bool:
	if _gap(_road_near(p)) > 0.0:
		return true
	for ft in valley.features:
		if ft.type in ["washout", "slide"] and absf(_cut(ft, p)) > 0.05:
			return true
	return false


## How much a washout (down) or a slide (up) moves the ground at p.
func _cut(ft: Dictionary, p: Vector2) -> float:
	match ft.type:
		"washout", "slide":
			# A gully (a ridge) across the road: deepest (highest) along a line across it, easing
			# out to its ends.
			var at: Array = along(int(ft.road), float(ft.s))
			var c: Vector2 = at[0]
			var d: Vector2 = at[1]
			var off := p - c
			var across := absf(off.dot(Vector2(-d.y, d.x)))
			var half := float(ft.length) * 0.5
			var size := -float(ft.depth) if ft.type == "washout" else float(ft.height)
			return size * _bump(absf(off.dot(d)) / float(ft.width)) * (1.0 - smoothstep(half - 6.0, half, across))
	return 0.0


## The ground before the roads and the places are cut in: noise, hills, ridges, gullies.
func base_height(p: Vector2) -> float:
	var h := _base.get_noise_2d(p.x, p.y) * valley.relief
	for ft in valley.features:
		match ft.type:
			"hill":
				h += float(ft.height) * _bump(p.distance_to(ft.pos) / float(ft.radius))
			"ridge":
				var c := Geometry2D.get_closest_point_to_segment(p, ft.from, ft.to)
				h += float(ft.height) * _bump(p.distance_to(c) / float(ft.width))
			"gully":
				var best := INF
				var pts: PackedVector2Array = ft.points
				for i in pts.size() - 1:
					best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
				h -= float(ft.depth) * _bump(best / float(ft.width))
	return h


## The ground at p with the places' flats and their ramps cut in, as the terrain has them.
func _ramped(p: Vector2) -> float:
	var b := base_height(p)
	var h := b
	for f in valley.locations.values():
		var ramp := clampf(absf(b - f.height) * 5.0, 10.0, valley.ramp_max)
		h = lerpf(h, f.height, 1.0 - smoothstep(f.radius, f.radius + ramp, p.distance_to(f.pos)))
	for f in valley.locations.values():
		h = lerpf(h, f.height, 1.0 - smoothstep(f.radius - 3.0, f.radius, p.distance_to(f.pos)))
	return h


## 1 at 0, easing to 0 at 1 and beyond.
func _bump(t: float) -> float:
	return 0.5 + 0.5 * cos(PI * clampf(t, 0.0, 1.0))


## The nearest road to p: {x: distance, at: its nearest point, road: index, s: metres along it},
## and the nearest other road the same way under "other" (empty when there is no other).
func _road_closest(p: Vector2) -> Dictionary:
	return _road_scan(p, _all_segs)


## _road_closest, but of the roads within NEAR m of p only (only x, INF, when there is none, and
## other is empty when there is no other that near): it looks only at the segments listed in p's square.
func _road_near(p: Vector2) -> Dictionary:
	var segs := _segs_at(p)
	if segs.is_empty():
		return NO_ROAD
	var near := _road_scan(p, segs)
	if near.x >= NEAR:
		return NO_ROAD
	var other: Dictionary = near.other
	if not other.is_empty() and other.x >= NEAR:
		near.other = {}
	return near


## The segments listed in p's square of the grid, all those within NEAR m of it; off the grid, all.
func _segs_at(p: Vector2) -> PackedInt32Array:
	var gx := floori((p.x + HALF) / GRID_CELL)
	var gz := floori((p.y + HALF) / GRID_CELL)
	return _grid[gz * GRID + gx] if gx >= 0 and gz >= 0 and gx < GRID and gz < GRID else _all_segs


## The nearest road to p over the segments segs (in order, as _seg_road lists them), as _road_closest.
func _road_scan(p: Vector2, segs: PackedInt32Array) -> Dictionary:
	var best := {"x": INF, "at": p, "road": -1, "s": 0.0}
	var other := {}
	var k := 0
	while k < segs.size():
		var r := _seg_road[segs[k]]
		var x := INF
		var at := p
		var s := 0.0
		while k < segs.size() and _seg_road[segs[k]] == r:
			var g := segs[k]
			var c := Geometry2D.get_closest_point_to_segment(p, _seg_a[g], _seg_b[g])
			var d := p.distance_to(c)
			if d < x:
				x = d
				at = c
				s = _seg_along[g] + _seg_a[g].distance_to(c)
			k += 1
		var mine := {"x": x, "at": at, "road": r, "s": s}
		if x < best.x:
			other = best if best.road >= 0 else {}
			best = mine
		elif other.is_empty() or x < other.x:
			other = mine
	best.other = other
	return best


## Lists the roads' segments, and in each square of the grid the ones that come within NEAR m of
## any point in it, so a point of the ground looks at a few segments, not every one.
func _index_roads() -> void:
	_seg_road.clear()
	_seg_a.clear()
	_seg_b.clear()
	_seg_along.clear()
	for r in roads.size():
		var road := roads[r]
		var along := 0.0
		for i in road.size() - 1:
			_seg_road.append(r)
			_seg_a.append(road[i])
			_seg_b.append(road[i + 1])
			_seg_along.append(along)
			along += road[i].distance_to(road[i + 1])
	_all_segs = PackedInt32Array(range(_seg_road.size()))
	var cells: Array[PackedInt32Array] = []
	cells.resize(GRID * GRID)
	var reach := NEAR + GRID_CELL * sqrt(0.5) + 0.5  # from a square's middle, and some to spare
	for g in _seg_road.size():
		var lo := (_seg_a[g].min(_seg_b[g]) + Vector2(HALF - reach, HALF - reach)) / GRID_CELL
		var hi := (_seg_a[g].max(_seg_b[g]) + Vector2(HALF + reach, HALF + reach)) / GRID_CELL
		for gz in range(maxi(floori(lo.y), 0), mini(floori(hi.y), GRID - 1) + 1):
			for gx in range(maxi(floori(lo.x), 0), mini(floori(hi.x), GRID - 1) + 1):
				var centre := Vector2((gx + 0.5) * GRID_CELL - HALF, (gz + 0.5) * GRID_CELL - HALF)
				if centre.distance_to(Geometry2D.get_closest_point_to_segment(centre, _seg_a[g], _seg_b[g])) < reach:
					var cell := cells[gz * GRID + gx]
					cell.append(g)
					cells[gz * GRID + gx] = cell
	_grid = cells


func road_distance(p: Vector2) -> float:
	var near := _road_near(p)
	return near.x if near.x < INF else _road_closest(p).x


## The ground on the road's centre line at its point nearest p, as built.
func road_height(p: Vector2) -> float:
	var at: Vector2 = _road_closest(p).at
	return get_height(at.x, at.y)


## Digs the ditches into the finished ground: each a trench at the level of the road beside it, cut
## into a slope above the road or banked up on one below it, so a car slid in stays in.
func _dig(ditches: Array[Dictionary]) -> void:
	var built := heights.duplicate()
	for dt in ditches:
		var half: Vector2 = dt.dir * float(dt.length) * 0.5
		var w: float = dt.width
		var reach := half.length() + w + DITCH_BANK
		var road := _beside(roads[dt.road], dt.pos, reach + 2.0)
		for z in range(maxi(0, int(dt.pos.y + HALF - reach)), mini(N, int(dt.pos.y + HALF + reach) + 2)):
			for x in range(maxi(0, int(dt.pos.x + HALF - reach)), mini(N, int(dt.pos.x + HALF + reach) + 2)):
				var p := Vector2(x - HALF, z - HALF)
				var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, dt.pos - half, dt.pos + half))
				if d >= w + DITCH_BANK:
					continue
				var c := Vector2.ZERO
				var best := INF
				for i in road.size() - 1:
					var q := Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1])
					if p.distance_to(q) < best:
						best = p.distance_to(q)
						c = q
				var level := _bilinear(built, c.x, c.y) - float(dt.depth) * _bump(d / w)
				heights[z * N + x] = lerpf(heights[z * N + x], level, 1.0 - smoothstep(w, w + DITCH_BANK, d))


## The stretch of road beside p, reach metres along it either way from its point nearest p: a
## ditch's level comes from there, not from another leg of the road nearer its far bank.
static func _beside(road: PackedVector2Array, p: Vector2, reach: float) -> PackedVector2Array:
	var s0 := 0.0
	var best := INF
	var along := 0.0
	for i in road.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1])
		if p.distance_to(q) < best:
			best = p.distance_to(q)
			s0 = along + road[i].distance_to(q)
		along += road[i].distance_to(road[i + 1])
	var out := PackedVector2Array()
	along = 0.0
	for i in road.size() - 1:
		var l := road[i].distance_to(road[i + 1])
		var a := maxf(s0 - reach, along)
		var b := minf(s0 + reach, along + l)
		if a < b:
			if out.is_empty():
				out.append(road[i].lerp(road[i + 1], (a - along) / l))
			out.append(road[i].lerp(road[i + 1], (b - along) / l))
		along += l
	return out


## How high the road is at its nearest point to p: the ground there, or its smoothed profile.
## Where two smoothed roads meet, their profiles blend over the 4 m where both are about as near,
## so a junction has no step in it. Beside a smoothed road, where a stretch of it farther along
## comes about as near (the other leg of a hairpin), the profile is averaged over all of the road
## about as near, every PROFILE_STEP weighed by how near, so where the nearest point jumps from
## one leg to the other the ground does not step.
func _road_height(p: Vector2, near: Dictionary) -> float:
	var h := _profile_height(near)
	var off := smoothstep(ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 1.0, near.x)  # on the road, its own profile
	if off > 0.0 and not _profiles[near.road].is_empty():
		var sum := 0.0
		var weights := 0.0
		var far := 0.0  # how near a stretch more than 4-8 m along the road comes
		for g in _segs_at(p):
			if _seg_road[g] != near.road:
				continue
			var a := _seg_a[g]
			var along := _seg_along[g]
			var length := a.distance_to(_seg_b[g])
			var s := ceilf(along / PROFILE_STEP) * PROFILE_STEP
			while s < along + length:
				var w := 1.0 - smoothstep(0.0, 4.0, p.distance_to(a.lerp(_seg_b[g], (s - along) / length)) - near.x)
				if w > 0.0:
					sum += w * _profile_at(near.road, s)
					weights += w
					far = maxf(far, w * smoothstep(4.0, 8.0, absf(s - float(near.s))))
				s += PROFILE_STEP
		if weights > 0.0:
			h = lerpf(h, sum / weights, off * far)
	var other: Dictionary = near.other
	if not other.is_empty() and other.x - near.x < 4.0:
		h = lerpf(h, _profile_height(other), 0.5 * (1.0 - smoothstep(0.0, 4.0, other.x - near.x)))
	return h


func _profile_height(near: Dictionary) -> float:
	if _profiles[near.road].is_empty():
		return base_height(near.at)
	return _profile_at(near.road, near.s)


## Road r's smoothed profile s metres along it.
func _profile_at(r: int, s: float) -> float:
	var hs: PackedFloat32Array = _profiles[r].h
	var k := clampf(s / PROFILE_STEP, 0.0, hs.size() - 1.001)
	var i := int(k)
	return lerpf(hs[i], hs[i + 1], k - i)


## A road's heights every PROFILE_STEP metres, averaged over smooth metres either way so it cuts
## through bumps and fills hollows, but the ground's own height for PIN metres at both ends, where
## it crosses a place or meets another road. Empty when smooth is 0: the road keeps to the ground.
func _profile(road: PackedVector2Array, smooth: float) -> Dictionary:
	if smooth <= 0.0:
		return {}
	var raw := PackedFloat32Array()
	var total := 0.0
	for i in road.size() - 1:
		total += road[i].distance_to(road[i + 1])
	var seg := 0
	var seg_start := 0.0
	var s := 0.0
	while s <= total + PROFILE_STEP:
		var at := minf(s, total)
		while seg < road.size() - 2 and at > seg_start + road[seg].distance_to(road[seg + 1]):
			seg_start += road[seg].distance_to(road[seg + 1])
			seg += 1
		var t := (at - seg_start) / maxf(road[seg].distance_to(road[seg + 1]), 0.001)
		raw.append(_ramped(road[seg].lerp(road[seg + 1], clampf(t, 0.0, 1.0))))
		s += PROFILE_STEP
	var w := int(smooth / PROFILE_STEP)
	var hs := PackedFloat32Array()
	hs.resize(raw.size())
	for k in raw.size():
		var sum := 0.0
		var n := 0
		for j in range(maxi(k - w, 0), mini(k + w, raw.size() - 1) + 1):
			sum += raw[j]
			n += 1
		var end_t := smoothstep(PIN, PIN + smooth, minf(k * PROFILE_STEP, total - k * PROFILE_STEP))
		hs[k] = lerpf(raw[k], sum / n, end_t)
	# No steeper than the valley's grade, both ways: the road cuts into the slope above it and
	# is filled below, as a hairpin turning up a mountainside has to be.
	# The PIN metres at each end are left as the ground has them, flats and ramps and all.
	var rise := valley.road_grade * PROFILE_STEP
	var pinned := ceili(PIN / PROFILE_STEP)
	# A climb the grade cannot make between the pinned ends gets the grade it needs: a steeper
	# road, never a step.
	var span := hs.size() - 2 * pinned + 1
	if rise > 0.0 and span > 0:
		rise = maxf(rise, absf(hs[hs.size() - pinned] - hs[pinned - 1]) / span * 1.05)
	if rise > 0.0:
		for round in 4:
			for k in range(pinned, hs.size() - pinned):
				hs[k] = clampf(hs[k], hs[k - 1] - rise, hs[k - 1] + rise)
			for k in range(hs.size() - pinned - 1, pinned - 1, -1):
				hs[k] = clampf(hs[k], hs[k + 1] - rise, hs[k + 1] + rise)
	return {"h": hs}


func get_height(x: float, z: float) -> float:
	return _bilinear(heights, x, z)


static func _bilinear(hs: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf(x + HALF, 0.0, SIZE - 0.001)
	var fz := clampf(z + HALF, 0.0, SIZE - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * N + ix
	return lerpf(lerpf(hs[i], hs[i + 1], tx), lerpf(hs[i + N], hs[i + N + 1], tx), tz)


func sample(pos: Vector3) -> Surface:
	var s := Surface.new()
	var c := snow_img.get_pixel(clampi(roundi(pos.x + HALF), 0, N - 1), clampi(roundi(pos.z + HALF), 0, N - 1))
	var tr := _track_at(pos)
	var wk := _works_at(pos)
	s.snow = c.r * MAX_SNOW * (1.0 - tr * 0.7)
	s.mud = c.g * (1.0 - tr * 0.2) * (1.0 - wk.g)  # gravel spread does not churn
	s.ice = 1.0 - c.a
	s.grip = lerpf(1.0, valley.layer_grip, clampf(s.snow / 0.4, 0.0, 1.0))
	s.grip = lerpf(s.grip, 0.4, s.mud)
	s.grip = lerpf(s.grip, 0.15, s.ice)
	s.rolling = 0.015 + s.snow * valley.layer_rolling + s.mud * 0.17
	# Loose earth (dug, dumped or slid) is soft, like snow LOOSE m deep, until wheels pack it.
	var loose := wk.r * LOOSE * (1.0 - tr)
	if loose > 0.0:
		s.snow = maxf(s.snow, loose)
		s.grip = minf(s.grip, lerpf(1.0, 0.55, clampf(loose / 0.3, 0.0, 1.0)))
		s.rolling += loose * 0.45
	# Gravel spread: a road's grip.
	s.grip = lerpf(s.grip, 1.0, wk.g * (1.0 - s.ice))
	s.rolling = lerpf(s.rolling, 0.015, wk.g)
	return s


## A wheel packs down the snow/mud at its contact point.
func compact(pos: Vector3, amount: float) -> void:
	var ix := clampi(roundi((pos.x + HALF) * 2.0), 0, TRACK_RES - 1)
	var iz := clampi(roundi((pos.z + HALF) * 2.0), 0, TRACK_RES - 1)
	var v := track_img.get_pixel(ix, iz).r
	if v >= 1.0:
		return
	track_img.set_pixel(ix, iz, Color(minf(v + amount, 1.0), 0.0, 0.0))
	_track_dirty = true


func _process(delta: float) -> void:
	_track_timer += delta
	if _track_dirty and _track_timer > 0.1:
		track_tex.update(track_img)
		_track_dirty = false
		_track_timer = 0.0
	_ground_timer += delta
	if (_heights_dirty or _images_dirty) and _ground_timer > 0.1:
		_ground_timer = 0.0
		if _heights_dirty:
			height_img.set_data(N, N, false, Image.FORMAT_RF, heights.to_byte_array())
			height_tex.update(height_img)
			_heights_dirty = false
		if _images_dirty:
			snow_tex.update(snow_img)
			works_tex.update(works_img)
			_images_dirty = false


## Before any body moves this tick, the collision of the chunks the ground changed in, so a
## wheel's ray meets the new height on this physics tick.
func _physics_process(_delta: float) -> void:
	flush()


## Rebuilds the collision and the boxes of the chunks changed since the last time.
func flush() -> void:
	if _dirty_chunks.is_empty():
		return
	for c in _dirty_chunks:
		_fill_chunk_shape(c.x, c.y)
		_fit_chunk(c.x, c.y)
	var rect := Rect2i()
	for c in _dirty_chunks:
		var r := Rect2i(c * CHUNK, Vector2i(CHUNK + 1, CHUNK + 1))
		rect = r if rect.size == Vector2i.ZERO else rect.merge(r)
	_dirty_chunks.clear()
	ground_changed.emit(rect)


func _track_at(pos: Vector3) -> float:
	var ix := clampi(roundi((pos.x + HALF) * 2.0), 0, TRACK_RES - 1)
	var iz := clampi(roundi((pos.z + HALF) * 2.0), 0, TRACK_RES - 1)
	return track_img.get_pixel(ix, iz).r


func _works_at(pos: Vector3) -> Color:
	if works_img == null:
		return Color(0, 0, 0, 0)
	return works_img.get_pixel(clampi(roundi((pos.x + HALF) * 2.0), 0, TRACK_RES - 1), clampi(roundi((pos.z + HALF) * 2.0), 0, TRACK_RES - 1))


# --- The ground changed after it was built (docs/plan.md §4) -----------------------------------

## Writes values (row by row) into the heights in rect (vertices: x, z from the tile's north-west
## corner) and marks the chunks it touches: their collision is rebuilt before the next physics
## tick, the shaders' height texture at most 10 times a second.
func set_heights(rect: Rect2i, values: PackedFloat32Array) -> void:
	rect = rect.intersection(Rect2i(0, 0, N, N))
	for z in rect.size.y:
		for x in rect.size.x:
			heights[(rect.position.y + z) * N + rect.position.x + x] = values[z * rect.size.x + x]
	touch(rect)


## The ground as the map made it again: every earthwork undone (a save lays its own over it).
func reset_ground() -> void:
	heights = generated.duplicate()
	snow_img.copy_from(_ground_made)
	works_img.fill(Color(0, 0, 0, 0))
	_paint_slides()
	_images_dirty = true
	touch(Rect2i(0, 0, N, N))
	edited.clear()


## The vertex at (x, z) is h now (its chunk's collision is rebuilt before the next tick).
func set_vertex(x: int, z: int, h: float) -> void:
	heights[z * N + x] = h
	touch(Rect2i(x, z, 1, 1))


## The chunks of rect (vertices) changed: one on a chunk's edge is in both.
func touch(rect: Rect2i) -> void:
	_heights_dirty = true
	var c0 := Vector2i(clampi((rect.position.x - 1) / CHUNK, 0, CHUNKS - 1), clampi((rect.position.y - 1) / CHUNK, 0, CHUNKS - 1))
	var c1 := Vector2i(clampi(rect.end.x / CHUNK, 0, CHUNKS - 1), clampi(rect.end.y / CHUNK, 0, CHUNKS - 1))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if not Vector2i(cx, cz) in _dirty_chunks:
				_dirty_chunks.append(Vector2i(cx, cz))
			edited[Vector2i(cx, cz)] = true


## Paints the works image within radius of local p: each channel (R loose earth, G gravel, B bare
## earth) goes to works' as far as mask's says; clear_layer takes the snow (or dust) and the mud
## off the ground image there, clear_road the road's mark.
func paint(p: Vector2, radius: float, works: Color, mask: Color, clear_layer := false, clear_road := false) -> void:
	var lo := Vector2i(floori((p.x - radius + HALF) * 2.0), floori((p.y - radius + HALF) * 2.0))
	var hi := Vector2i(ceili((p.x + radius + HALF) * 2.0), ceili((p.y + radius + HALF) * 2.0))
	for z in range(maxi(lo.y, 0), mini(hi.y, TRACK_RES - 1) + 1):
		for x in range(maxi(lo.x, 0), mini(hi.x, TRACK_RES - 1) + 1):
			if Vector2(x * 0.5 - HALF, z * 0.5 - HALF).distance_to(p) > radius:
				continue
			var w := works_img.get_pixel(x, z)
			works_img.set_pixel(x, z, Color(lerpf(w.r, works.r, mask.r), lerpf(w.g, works.g, mask.g), lerpf(w.b, works.b, mask.b), 1.0))
	if clear_layer or clear_road:
		for z in range(maxi(floori(p.y - radius + HALF), 0), mini(ceili(p.y + radius + HALF), N - 1) + 1):
			for x in range(maxi(floori(p.x - radius + HALF), 0), mini(ceili(p.x + radius + HALF), N - 1) + 1):
				if Vector2(x - HALF, z - HALF).distance_to(p) > radius:
					continue
				var c := snow_img.get_pixel(x, z)
				snow_img.set_pixel(x, z, Color(0.0 if clear_layer else c.r, 0.0 if clear_layer else c.g, 0.0 if clear_road else c.b, c.a))
	_images_dirty = true


func _noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


func _build_visuals() -> void:
	generated = heights.duplicate()
	_ground_made = snow_img.duplicate()
	works_img = Image.create_empty(TRACK_RES, TRACK_RES, false, Image.FORMAT_RGBA8)
	_paint_slides()
	works_tex = ImageTexture.create_from_image(works_img)
	process_physics_priority = -100  # its collision is up to date before anything moves
	height_img = Image.create_from_data(N, N, false, Image.FORMAT_RF, heights.to_byte_array())
	height_tex = ImageTexture.create_from_image(height_img)
	snow_tex = ImageTexture.create_from_image(snow_img)
	track_img = Image.create_empty(TRACK_RES, TRACK_RES, false, Image.FORMAT_R8)
	track_tex = ImageTexture.create_from_image(track_img)
	var tile_origin := Vector2(position.x, position.z)

	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("tile_origin", tile_origin)
	ground_mat.set_shader_parameter("height_tex", height_tex)
	ground_mat.set_shader_parameter("snow_tex", snow_tex)
	ground_mat.set_shader_parameter("works_tex", works_tex)
	ground_mat.set_shader_parameter("earth_col", _rgb(valley.earth))
	ground_mat.set_shader_parameter("gravel_col", _rgb(valley.gravel))
	ground_mat.set_shader_parameter("ice_col", _rgb(valley.ice_color))

	snow_mat = ShaderMaterial.new()
	snow_mat.shader = SNOW_SHADER
	snow_mat.set_shader_parameter("tile_origin", tile_origin)
	snow_mat.set_shader_parameter("height_tex", height_tex)
	snow_mat.set_shader_parameter("snow_tex", snow_tex)
	snow_mat.set_shader_parameter("track_tex", track_tex)
	snow_mat.set_shader_parameter("track_tex_px", track_tex)
	snow_mat.set_shader_parameter("max_snow", MAX_SNOW)
	snow_mat.set_shader_parameter("max_mud", MAX_MUD)
	snow_mat.set_shader_parameter("layer_col", _rgb(valley.layer_color))
	snow_mat.set_shader_parameter("layer_packed_col", _rgb(valley.layer_packed))
	snow_mat.set_shader_parameter("mud_col", _rgb(valley.mud_color))
	snow_mat.set_shader_parameter("mud_packed_col", _rgb(valley.mud_packed))

	# Ground: 1 m between vertices; snow: 0.5 m, so the ruts show.
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(CHUNK, CHUNK)
	ground_mesh.subdivide_width = CHUNK - 1
	ground_mesh.subdivide_depth = CHUNK - 1
	var snow_mesh := PlaneMesh.new()
	snow_mesh.size = Vector2(CHUNK, CHUNK)
	snow_mesh.subdivide_width = CHUNK * 2 - 1
	snow_mesh.subdivide_depth = CHUNK * 2 - 1

	_chunk_meshes.clear()
	for cz in CHUNKS:
		for cx in CHUNKS:
			var center := Vector3(-HALF + (cx + 0.5) * CHUNK, 0.0, -HALF + (cz + 0.5) * CHUNK)
			var pair := [_add_chunk(ground_mesh, ground_mat, center), _add_chunk(snow_mesh, snow_mat, center)]
			_chunk_meshes.append(pair)
			_fit_chunk(cx, cz)


## The chunk's meshes' boxes, to the heights in it now (or the camera culls what rose out of them).
func _fit_chunk(cx: int, cz: int) -> void:
	var min_h := INF
	var max_h := -INF
	for z in range(cz * CHUNK, (cz + 1) * CHUNK + 1):
		for x in range(cx * CHUNK, (cx + 1) * CHUNK + 1):
			var h := heights[z * N + x]
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)
	var aabb := AABB(Vector3(-CHUNK * 0.5, min_h - 1.0, -CHUNK * 0.5), Vector3(CHUNK, max_h - min_h + 2.0, CHUNK))
	for mi in _chunk_meshes[cz * CHUNKS + cx]:
		(mi as MeshInstance3D).custom_aabb = aabb


func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _add_chunk(m: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## One height map per CHUNK (33x33, the edges shared with the next), all under one body, so an
## edit of the ground rebuilds only the chunks it touched.
func _build_collision() -> void:
	body = StaticBody3D.new()
	add_child(body)
	_chunk_shapes.clear()
	for cz in CHUNKS:
		for cx in CHUNKS:
			var shape := HeightMapShape3D.new()
			shape.map_width = CHUNK + 1
			shape.map_depth = CHUNK + 1
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(-HALF + (cx + 0.5) * CHUNK, 0.0, -HALF + (cz + 0.5) * CHUNK)
			body.add_child(cs)
			_chunk_shapes.append(shape)
			_fill_chunk_shape(cx, cz)


func _fill_chunk_shape(cx: int, cz: int) -> void:
	var data := PackedFloat32Array()
	data.resize((CHUNK + 1) * (CHUNK + 1))
	for z in CHUNK + 1:
		for x in CHUNK + 1:
			data[z * (CHUNK + 1) + x] = heights[(cz * CHUNK + z) * N + cx * CHUNK + x]
	_chunk_shapes[cz * CHUNKS + cx].map_data = data


## A slide is loose earth until it is dug or packed.
func _paint_slides() -> void:
	for ft in valley.features:
		if ft.type == "slide":
			var c: Vector2 = along(int(ft.road), float(ft.s))[0]
			var reach := float(ft.length) * 0.5 + float(ft.width)
			for z in range(maxi(floori((c.y - reach + HALF) * 2.0), 0), mini(ceili((c.y + reach + HALF) * 2.0), TRACK_RES - 1) + 1):
				for x in range(maxi(floori((c.x - reach + HALF) * 2.0), 0), mini(ceili((c.x + reach + HALF) * 2.0), TRACK_RES - 1) + 1):
					if _cut(ft, Vector2(x * 0.5 - HALF, z * 0.5 - HALF)) > 0.2:
						works_img.set_pixel(x, z, Color(1.0, 0.0, 0.0, 1.0))


## Chunk c's earthworks as a save keeps them (docs/plan.md §11): its heights less the generated
## ones at 1 cm in 16 bits, its works image and its ground image, compressed.
func save_chunk(c: Vector2i) -> PackedByteArray:
	var out := PackedByteArray()
	var k := CHUNK + 1
	out.resize(k * k * 2)
	for z in k:
		for x in k:
			var i := (c.y * CHUNK + z) * N + c.x * CHUNK + x
			out.encode_s16((z * k + x) * 2, clampi(roundi((heights[i] - generated[i]) * 100.0), -32768, 32767))
	out.append_array(works_img.get_region(Rect2i(c * CHUNK * 2, Vector2i.ONE * CHUNK * 2)).get_data())
	out.append_array(snow_img.get_region(Rect2i(c * CHUNK, Vector2i.ONE * k)).get_data())
	return out.compress(FileAccess.COMPRESSION_DEFLATE)


## Lays a chunk saved by save_chunk over the ground as made; false when the bytes do not fit.
func load_chunk(c: Vector2i, bytes: PackedByteArray) -> bool:
	var k := CHUNK + 1
	var size := k * k * 2 + (CHUNK * 2) * (CHUNK * 2) * 4 + k * k * 4
	var raw := bytes.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != size or c.x < 0 or c.y < 0 or c.x >= CHUNKS or c.y >= CHUNKS:
		return false
	for z in k:
		for x in k:
			var i := (c.y * CHUNK + z) * N + c.x * CHUNK + x
			heights[i] = generated[i] + raw.decode_s16((z * k + x) * 2) / 100.0
	var at := k * k * 2
	var w := Image.create_from_data(CHUNK * 2, CHUNK * 2, false, Image.FORMAT_RGBA8, raw.slice(at, at + CHUNK * CHUNK * 16))
	works_img.blit_rect(w, Rect2i(Vector2i.ZERO, w.get_size()), c * CHUNK * 2)
	at += CHUNK * CHUNK * 16
	var s := Image.create_from_data(k, k, false, Image.FORMAT_RGBA8, raw.slice(at))
	snow_img.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), c * CHUNK)
	_images_dirty = true
	touch(Rect2i(c * CHUNK, Vector2i.ONE * k))
	return true
