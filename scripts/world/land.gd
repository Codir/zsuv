class_name Land
extends Node3D
## The map (docs/plan.md §3): the biomes, each a Terrain of 256 m (a tile) at its cell of one
## grid, joined at their borders, with Terrain's API in the world's metres. It finds the tile under
## a point and hands it the point in that tile's own.
##
## The world's origin is the middle of the biome the land was built around (home): the game
## builds it around the steppe, a test around the biome it is in, so a biome's own coordinates are
## the world's when it is home.
##
## Where two biomes meet, both ease their ground onto one border profile in a BAND along it, so
## they meet exactly: the average of both grounds there, smoothed over 2 x SMOOTH m; at a gate (a
## road ending on the border, its neighbour's going on from the same point) the road's level, flat
## for 2 x GATE_FLAT m. A river or a gorge needs no profile: both tiles carve their half of its bed
## from their own ground, down to one level along it, and the water's level runs along it.

const MAP_VERSION := 6  # moves with any change to what the generator makes (docs/plan.md §3, §11)
const BAND := 24.0
const SMOOTH := 20.0
const GATE_FLAT := 8.0
const GATE_EASE := 12.0
const END := 16.0  # m at each end of a river or a gorge where its bed rises to the ground
const SKY_BLEND := 30.0  # m either side of a border where the skies blend (60 m in all)
const WATER_COLOR := Color(0.18, 0.3, 0.36)
const SIDES := {"west": Vector2i(-1, 0), "east": Vector2i(1, 0), "north": Vector2i(0, -1), "south": Vector2i(0, 1)}
const OPPOSITE := {"west": "east", "east": "west", "north": "south", "south": "north"}

var home: Terrain
var baked := false  # built from the bake (MapBake), not the generator
var earthworks: Earthworks  # digging and dumping on it (docs/plan.md §4)
var timings := {}  # ms build took: ground (the bake or the generator), finish (meshes, collision), world (trees, houses)
var _t0 := 0
var fog: Fog  # what has been seen of it (docs/plan.md §3)
var paper := PackedByteArray()  # the paper map as the bake drew it (MapScreen), or empty
var tiles: Array[Terrain] = []
var builders: Array[WorldBuilder] = []  # per tile, in its order
var borders: Array[Dictionary] = []  # {a, b (west or north of the two, then the other), side (a's), kind, profile, ...}
var anchor_points := PackedVector3Array()  # every tree and rock, for the winch, in the world
var tree_points := PackedVector2Array()  # every tree, in the world
var _by_cell := {}  # Vector2i -> Terrain
var _home_cell := Vector2i.ZERO
var _bodies: Array[RID] = []


## Builds the map around home (a biome of Valley.all(), by id; this one's places are the ones in
## play): every tile's ground (from the bake when there is a current one and use_bake, else
## from the generator), the borders, then what is seen, driven on and stands on it.
func build(home_valley: Valley, use_bake := true) -> void:
	_t0 = Time.get_ticks_msec()
	_home_cell = home_valley.cell
	earthworks = Earthworks.new(self)
	var valleys := {}
	for v0 in Valley.all():
		var v: Valley = home_valley if v0.id == home_valley.id else v0
		valleys[v.cell] = v
		var t := Terrain.new()
		t.name = "Tile_" + v.id
		var at := Vector2((v.cell - _home_cell) * Terrain.SIZE)
		t.position = Vector3(at.x, 0.0, at.y)
		t.origin = at
		_by_cell[v.cell] = t
		tiles.append(t)
		if v == home_valley:
			home = t
	var from_bake := MapBake.load_current() if use_bake else null
	for t in tiles:
		var v: Valley = valleys[_cell_of(t)]
		var edges := {}
		for side in SIDES:
			edges[side] = not _by_cell.has(_cell_of(t) + SIDES[side])
		if from_bake:
			t.outer = edges
			t.prepare(v)
			t.heights = (from_bake.heights[v.id] as PackedFloat32Array).duplicate()
			t.snow_img = Image.create_from_data(Terrain.N, Terrain.N, false, Image.FORMAT_RGBA8, from_bake.grounds[v.id])
		else:
			t.shape(v, edges)
	baked = from_bake != null
	if from_bake:
		paper = from_bake.paper
	if from_bake:
		for b in from_bake.borders:
			var border := b.duplicate()
			border.a = _tile(b.a_id)
			border.b = _tile(b.b_id)
			borders.append(border)
	else:
		_join()
	for border in borders:
		_keep_clear(border.a, border.side, border)
		_keep_clear(border.b, OPPOSITE[border.side], border)
	timings.ground = Time.get_ticks_msec() - _t0
	for t in tiles:
		add_child(t)
		t.finish()
		_bodies.append(t.body.get_rid())
	timings.finish = Time.get_ticks_msec() - _t0 - timings.ground
	for b in borders:
		if b.kind != "land":
			_water_plane(b)
	for t in tiles:
		for ft in t.valley.features:
			if ft.type == "lake" and ft.has("water"):
				var disc := Psx.cylinder(float(ft.radius) + float(ft.get("shore", 8.0)) * 0.5, float(ft.radius) + float(ft.get("shore", 8.0)) * 0.5, 0.02, 16)
				var at: Vector2 = (ft.pos as Vector2) + t.origin
				Psx.mesh(self, disc, Vector3(at.x, float(ft.height) + float(ft.water), at.y), WATER_COLOR).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for t in tiles:
		var wb := WorldBuilder.new()
		wb.name = "World_" + t.valley.id
		wb.position = t.position
		add_child(wb)
		wb.build(t, t.valley)
		builders.append(wb)
		for p in wb.anchor_points:
			anchor_points.append(p + t.position)
		for p in wb.tree_points:
			tree_points.append(p + t.origin)
	timings.world = Time.get_ticks_msec() - _t0 - timings.ground - timings.finish
	fog = Fog.new(self)


func _cell_of(t: Terrain) -> Vector2i:
	return _home_cell + Vector2i(roundi(t.origin.x / Terrain.SIZE), roundi(t.origin.y / Terrain.SIZE))


func _tile(id: String) -> Terrain:
	for t in tiles:
		if t.valley.id == id:
			return t
	return null


## The map as built, for the bake (tests/bake_map.gd).
func bake() -> MapBake:
	var b := MapBake.new()
	b.version = MAP_VERSION
	for t in tiles:
		b.heights[t.valley.id] = t.heights.duplicate()
		b.grounds[t.valley.id] = t.snow_img.get_data()
	for border in borders:
		var d := border.duplicate()
		d.a_id = (border.a as Terrain).valley.id
		d.b_id = (border.b as Terrain).valley.id
		d.erase("a")
		d.erase("b")
		b.borders.append(d)
	return b


# --- Terrain's API, in the world's metres ------------------------------------------------------

## The tile under the world's (x, z), or the nearest one off the map.
func tile_at(x: float, z: float) -> Terrain:
	var c := _home_cell + Vector2i(floori((x + Terrain.HALF) / Terrain.SIZE), floori((z + Terrain.HALF) / Terrain.SIZE))
	var t: Terrain = _by_cell.get(c)
	if t:
		return t
	var best: Terrain = home
	var best_d := INF
	for o in tiles:
		var d := Vector2(maxf(absf(x - o.origin.x) - Terrain.HALF, 0.0), maxf(absf(z - o.origin.y) - Terrain.HALF, 0.0)).length()
		if d < best_d:
			best_d = d
			best = o
	return best


func valley_at(p: Vector2) -> Valley:
	return tile_at(p.x, p.y).valley


func get_height(x: float, z: float) -> float:
	var t := tile_at(x, z)
	return t.get_height(x - t.origin.x, z - t.origin.y)


func sample(pos: Vector3) -> Terrain.Surface:
	var t := tile_at(pos.x, pos.z)
	return t.sample(pos - t.position)


func compact(pos: Vector3, amount: float) -> void:
	var t := tile_at(pos.x, pos.z)
	t.compact(pos - t.position, amount)


## Metres to the nearest road of the tile under p.
func road_distance(p: Vector2) -> float:
	var t := tile_at(p.x, p.y)
	return t.road_distance(p - t.origin)


## The ground on the centre line of the nearest road of the tile under p, at its point nearest p.
func road_height(p: Vector2) -> float:
	var t := tile_at(p.x, p.y)
	return t.road_height(p - t.origin)


## The bodies of the ground, for the rays and queries that leave the ground out.
func bodies() -> Array[RID]:
	return _bodies.duplicate()


## Whether collider is the ground (a tile's body), not a building or a deck on it.
func is_ground(collider: Object) -> bool:
	var b := collider as CollisionObject3D
	return b != null and b.get_rid() in _bodies


## Every road of the map in the world's metres.
func all_roads() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for t in tiles:
		for r in t.roads:
			var w := PackedVector2Array()
			for p in r:
				w.append(p + t.origin)
			out.append(w)
	return out


## Whether p is on the map, margin m in from its outer edges.
func on_map(p: Vector2, margin := 0.0) -> bool:
	var c := _home_cell + Vector2i(floori((p.x + Terrain.HALF) / Terrain.SIZE), floori((p.y + Terrain.HALF) / Terrain.SIZE))
	var t: Terrain = _by_cell.get(c)
	if t == null:
		return false
	var l := p - t.origin
	for side in SIDES:
		if t.outer[side]:
			var toward: float = l.dot(Vector2(SIDES[side]))
			if toward > Terrain.HALF - margin:
				return false
	return true


## The water's level at p: a river's or a gorge's along its border (or margin m off it); -INF where
## there is none.
func water_level(p: Vector2, margin := 0.0) -> float:
	for b in borders:
		if b.kind == "land":
			continue
		var d: float = _across(b, p)
		var i: float = _along(b, p)
		if absf(d) < float(b.half) + margin and i >= END and i <= Terrain.SIZE - END:
			return b.water_level
	for t in tiles:  # ponds and the swamp's deep water: lakes without ice
		for ft in t.valley.features:
			if ft.type == "lake" and ft.has("water") and p.distance_to((ft.pos as Vector2) + t.origin) < float(ft.radius) + float(ft.get("shore", 8.0)) * 0.5 + margin:
				var level := float(ft.height) + float(ft.water)
				if get_height(p.x, p.y) < level + margin:
					return level
	return -INF


## The water's current at p (m/s on the map's plane): a river or a gorge flows along its border,
## from its west or north end, fastest in the middle and slack at the banks (docs/plan.md §8);
## none where there is no water. Its speed is the border's "current" (a river 2 m/s, a gorge
## 2.5, if the valley does not say).
func water_current(p: Vector2) -> Vector2:
	for b in borders:
		if b.kind == "land":
			continue
		var d: float = _across(b, p)
		var i: float = _along(b, p)
		if absf(d) < float(b.half) and i >= END and i <= Terrain.SIZE - END:
			var speed: float = b.get("current", 2.5 if b.kind == "gorge" else 2.0)
			var way := Vector2(0.0, 1.0) if b.side == "east" else Vector2(1.0, 0.0)
			return way * speed * (1.0 - pow(absf(d) / float(b.half), 2.0))
	return Vector2.ZERO


## The rectangle of the map, in the world's metres.
func bounds() -> Rect2:
	var r := Rect2(home.origin - Vector2.ONE * Terrain.HALF, Vector2.ONE * Terrain.SIZE)
	for t in tiles:
		r = r.merge(Rect2(t.origin - Vector2.ONE * Terrain.HALF, Vector2.ONE * Terrain.SIZE))
	return r


## The sky at p: the biome's own, blended with its neighbour's over SKY_BLEND m either side of a
## border.
func weather_at(p: Vector2) -> Weather:
	var t := tile_at(p.x, p.y)
	var w: Weather = t.valley.own
	var l := p - t.origin
	for side in SIDES:
		var n: Terrain = _by_cell.get(_cell_of(t) + SIDES[side])
		if n == null:
			continue
		var d: float = Terrain.HALF - l.dot(Vector2(SIDES[side]))
		if d < SKY_BLEND:
			w = Weather.mix(w, n.valley.own, 0.5 * (1.0 - d / SKY_BLEND))
	return w


# --- The borders --------------------------------------------------------------------------------

## Finds every border, makes its profile, eases both tiles onto it, then makes every point the
## tiles share one height.
func _join() -> void:
	borders.clear()
	for a in tiles:
		for side in ["east", "south"]:
			var b: Terrain = _by_cell.get(_cell_of(a) + SIDES[side])
			if b == null:
				continue
			var spec: Dictionary = a.valley.borders.get(side, b.valley.borders.get(OPPOSITE[side], {}))
			var border := {"a": a, "b": b, "side": side, "kind": spec.get("kind", "land"),
				"depth": float(spec.get("depth", 0.0)), "half": float(spec.get("half", 0.0)), "water": float(spec.get("water", 0.0))}
			_profile(border)
			borders.append(border)
	# Rivers and gorges last: near a corner their bed is carved through the other border's band.
	for wet in [false, true]:
		for border in borders:
			if (border.kind != "land") == wet:
				_ease(border.a, border.side, border)
				_ease(border.b, OPPOSITE[border.side], border)
	_weld()


## The height of t's vertex on side, i along it (west to east, north to south), inset vertices in.
static func _edge(t: Terrain, side: String, i: int, inset := 0) -> int:
	match side:
		"west":
			return i * Terrain.N + inset
		"east":
			return i * Terrain.N + Terrain.N - 1 - inset
		"north":
			return inset * Terrain.N + i
	return (Terrain.N - 1 - inset) * Terrain.N + i


## The border's profile: the average of both grounds along it smoothed, and at each gate the road's
## level; a river's or a gorge's water level, and the gates whose roads do not meet.
func _profile(border: Dictionary) -> void:
	var a: Terrain = border.a
	var b: Terrain = border.b
	var other: String = OPPOSITE[border.side]
	var raw := PackedFloat32Array()
	var lowest := INF  # the lower bank anywhere along it
	for i in Terrain.N:
		var ha := a.heights[_edge(a, border.side, i)]
		var hb := b.heights[_edge(b, other, i)]
		raw.append(0.5 * (ha + hb))
		lowest = minf(lowest, minf(ha, hb))
	var w := int(SMOOTH)
	var prof := PackedFloat32Array()
	prof.resize(Terrain.N)
	for i in Terrain.N:
		var sum := 0.0
		var n := 0
		for j in range(maxi(i - w, 0), mini(i + w, Terrain.N - 1) + 1):
			sum += raw[j]
			n += 1
		prof[i] = sum / n
	var gates := _gates(a, border.side)
	var theirs := _gates(b, other)
	border.unmatched = []
	for g in gates:
		if not theirs.any(func(o: float) -> bool: return absf(o - g) < 0.5):
			border.unmatched.append(g)
	for g in theirs:
		if not gates.any(func(o: float) -> bool: return absf(o - g) < 0.5):
			border.unmatched.append(g)
	border.gates = gates
	for g in gates:
		var level := raw[clampi(roundi(g), 0, Terrain.N - 1)]
		for i in Terrain.N:
			prof[i] = lerpf(prof[i], level, 1.0 - smoothstep(GATE_FLAT, GATE_FLAT + GATE_EASE, absf(i - g)))
	border.profile = prof
	if border.kind != "land":
		border.bed = lowest - border.depth
		border.water_level = border.bed + border.water


## Where t's roads end on its side: their points along it (0..256, as _edge counts).
static func _gates(t: Terrain, side: String) -> Array[float]:
	var out: Array[float] = []
	for road in t.roads:
		for p in [road[0], road[road.size() - 1]]:
			var on := false
			var along := 0.0
			match side:
				"west":
					on = absf(p.x + Terrain.HALF) < 0.5
					along = p.y
				"east":
					on = absf(p.x - Terrain.HALF) < 0.5
					along = p.y
				"north":
					on = absf(p.y + Terrain.HALF) < 0.5
					along = p.x
				"south":
					on = absf(p.y - Terrain.HALF) < 0.5
					along = p.x
			if on:
				out.append(along + Terrain.HALF)
	return out


## Eases t's ground onto the border's profile in the BAND along its side (a place's flat kept
## level), and carves its half of a river's or a gorge's bed.
func _ease(t: Terrain, side: String, border: Dictionary) -> void:
	var prof: PackedFloat32Array = border.profile
	var wet: bool = border.kind != "land"
	var half: float = border.half
	var flats: Array = t.valley.locations.values()
	for i in Terrain.N:
		for d in (ceili(half) if wet else int(BAND)) + 1:
			var k := _edge(t, side, i, d)
			var p := Vector2(k % Terrain.N - Terrain.HALF, k / Terrain.N - Terrain.HALF)
			var keep := 0.0
			for f in flats:
				var r: float = f.radius
				keep = maxf(keep, 1.0 - smoothstep(r, r + 10.0, p.distance_to(f.pos)))
			var h := t.heights[k]
			if wet and d < half:
				# Its bed eases up to the ground over its last END metres, where the map or another
				# border goes on.
				var bank := lerpf(1.0, smoothstep(half * 0.4, half, d), smoothstep(0.0, END, minf(i, Terrain.N - 1 - i)))
				h = border.bed + (h - border.bed) * bank  # its own ground on its own bank
				var c := t.snow_img.get_pixel(k % Terrain.N, k / Terrain.N)
				t.snow_img.set_pixel(k % Terrain.N, k / Terrain.N, Color(c.r * bank, maxf(c.g * bank, 0.6 * (1.0 - bank)), 0.0, c.a))
			elif not wet:
				h = lerpf(h, prof[i], (1.0 - smoothstep(0.0, BAND, d)) * (1.0 - keep))
			t.heights[k] = h


## Nothing grows or stands in a river's or a gorge's bed and on its banks, on t's side of it.
func _keep_clear(t: Terrain, side: String, border: Dictionary) -> void:
	var half: float = border.half
	if border.kind != "land":
		var r := Rect2()
		match side:
			"west":
				r = Rect2(-Terrain.HALF, -Terrain.HALF, half + 3.0, Terrain.SIZE)
			"east":
				r = Rect2(Terrain.HALF - half - 3.0, -Terrain.HALF, half + 3.0, Terrain.SIZE)
			"north":
				r = Rect2(-Terrain.HALF, -Terrain.HALF, Terrain.SIZE, half + 3.0)
			"south":
				r = Rect2(-Terrain.HALF, Terrain.HALF - half - 3.0, Terrain.SIZE, half + 3.0)
		t.keep_clear.append(r)


## Every point two or more tiles share (on their edges) gets one height, their average.
func _weld() -> void:
	var sums := {}
	for t in tiles:
		for side in SIDES:
			if t.outer[side]:
				continue
			for i in Terrain.N:
				var k := _edge(t, side, i)
				var key := Vector2i(roundi(t.origin.x) + k % Terrain.N, roundi(t.origin.y) + k / Terrain.N)
				var s: Vector2 = sums.get(key, Vector2.ZERO)
				sums[key] = s + Vector2(t.heights[k], 1.0)
	for t in tiles:
		for side in SIDES:
			if t.outer[side]:
				continue
			for i in Terrain.N:
				var k := _edge(t, side, i)
				var s: Vector2 = sums[Vector2i(roundi(t.origin.x) + k % Terrain.N, roundi(t.origin.y) + k / Terrain.N)]
				t.heights[k] = s.x / s.y


## Metres from the border's line to p, toward b's side.
func _across(border: Dictionary, p: Vector2) -> float:
	var a: Terrain = border.a
	if border.side == "east":
		return p.x - (a.origin.x + Terrain.HALF)
	return p.y - (a.origin.y + Terrain.HALF)


## Metres along the border to p from its west or north end.
func _along(border: Dictionary, p: Vector2) -> float:
	var a: Terrain = border.a
	if border.side == "east":
		return p.y - (a.origin.y - Terrain.HALF)
	return p.x - (a.origin.x - Terrain.HALF)


## A flat plane of water at the border's level along it.
func _water_plane(border: Dictionary) -> void:
	var a: Terrain = border.a
	var plane := PlaneMesh.new()
	var half: float = border.half
	var at := Vector3.ZERO
	if border.side == "east":
		plane.size = Vector2(half * 2.0, Terrain.SIZE)
		at = Vector3(a.origin.x + Terrain.HALF, border.water_level, a.origin.y)
	else:
		plane.size = Vector2(Terrain.SIZE, half * 2.0)
		at = Vector3(a.origin.x, border.water_level, a.origin.y + Terrain.HALF)
	var m := Psx.mesh(self, plane, at, WATER_COLOR)
	m.name = "Water_%s_%s" % [a.valley.id, (border.b as Terrain).valley.id]
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Every earthwork undone: the ground as the map made it (a save lays its own over it).
func reset_ground() -> void:
	for t in tiles:
		t.reset_ground()
	earthworks.shifted = 0.0
	earthworks.felled = PackedVector2Array()


## The earthworks as a save keeps them (docs/plan.md §11): the map's version, every chunk an
## earthwork touched (Terrain.save_chunk), the trees and rocks gone, the m³ shifted.
func save_earthworks() -> Dictionary:
	var chunks := {}
	for t in tiles:
		for c in t.edited:
			chunks["%s:%d:%d" % [t.valley.id, c.x, c.y]] = t.save_chunk(c)
	return {"map_version": MAP_VERSION, "chunks": chunks, "felled": earthworks.felled, "shifted": earthworks.shifted}


## Lays saved earthworks over the map as made. A save from another version of the map is dropped:
## false, and the ground stays as made (the game says so).
func load_earthworks(d: Dictionary) -> bool:
	reset_ground()
	if int(d.get("map_version", -1)) != MAP_VERSION:
		return false
	var chunks: Dictionary = d.get("chunks", {})
	for key in chunks:
		var parts := String(key).split(":")
		var t := _tile(parts[0]) if parts.size() == 3 else null
		if t:
			t.load_chunk(Vector2i(int(parts[1]), int(parts[2])), chunks[key])
	var felled: PackedVector2Array = d.get("felled", PackedVector2Array())
	for p in felled:
		earthworks.fell(p)
	earthworks.shifted = float(d.get("shifted", 0.0))
	return true


## The crossings whose bridges are gone (docs/plan.md §3, §5): over each river or gorge border, the
## road's two ends at the banks, where a bridge's abutments go, in the world: {a, b (Vector3, on
## the ground at each bank), kind ("river" or "gorge"), over (the gap, m), biomes ([a's, b's])}.
func crossings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in borders:
		if b.kind == "land":
			continue
		var ends: Array[Vector3] = []
		var ids: Array[String] = []
		for t: Terrain in [b.a, b.b]:
			for span in t.valley.gaps:
				var r := int(span.road)
				var road := t.roads[r]
				var total := 0.0
				for i in road.size() - 1:
					total += road[i].distance_to(road[i + 1])
				# The bank end of the span: the end of it away from the border.
				var s := float(span.from) if absf(float(span.to) - total) < absf(float(span.from)) else float(span.to)
				var p: Vector2 = t.along(r, clampf(s, 0.0, total))[0] + t.origin
				if absf(_across(b, p)) < float(b.half) + 16.0:
					ends.append(Vector3(p.x, get_height(p.x, p.y), p.y))
					ids.append(t.valley.id)
		if ends.size() == 2:
			out.append({"a": ends[0], "b": ends[1], "kind": b.kind, "over": Vector2(ends[0].x, ends[0].z).distance_to(Vector2(ends[1].x, ends[1].z)), "biomes": ids})
	return out


# --- The ground side of the sites (docs/plan.md §5): bridges, fills, slides, gravel roads -------

const CORRIDOR := 7.0  # m: a road's corridor, its width
const DRIVABLE_CLIMB := 0.4  # m a metre along its centre line, at most
const DRIVABLE_ACROSS := 0.5  # m across its width, at most
const COVERED := 0.9  # of a gravel road's corridor spread, and it is done
const CLEARED := 0.85  # of a slide above the road's level gone, and it is clear
const GRADE_SMOOTH := 14.0  # m a graded road's profile is averaged over, as a smoothed road's
const GRADE_MOST := 0.22  # the steepest a graded road climbs
const CHURN_MASS := 5000.0  # kg: a rig this heavy with its load churns the mud it spins in (§4)
const CHURN := 0.01  # the mud a spinning wheel adds a tick
const GRAVEL_STRIP := 16.0  # m of half a road a load of gravel covers, crept over in its 12 s

var bridges := {}  # spot id -> the deck built over it (a StaticBody3D), or true
var graded := {}  # spot id -> true
var _spots: Array[Dictionary] = []
var _slide_volume := {}  # spot id -> m3 of the slide over the road's level as made


## Where a road site goes, each found by the fog at pos: {id, kind ("bridge", "fill", "slide",
## "gravel_road"), path (its centre line, world, every 2 m), a, b (its ends, on the ground), needs
## ({resource: loads}: a bridge concrete 2 and timber 3, a gravel road its gravel, the rest none),
## width, pos, biome}. A bridge spans a crossing from bank to bank; a fill crosses a washout, a
## slide a landslide, a gravel road a bog's stretch of road.
func site_spots() -> Array[Dictionary]:
	if not _spots.is_empty():
		return _spots
	for c in crossings():
		var path := PackedVector2Array()
		var a := Vector2(c.a.x, c.a.z)
		var b := Vector2(c.b.x, c.b.z)
		var n := maxi(ceili(a.distance_to(b) / 2.0), 1)
		for k in n + 1:
			path.append(a.lerp(b, float(k) / n))
		var s := _spot("bridge:" + String(c.kind), "bridge", path, c.biomes[0])
		s.needs = {"concrete": 2, "timber": 3}
		s.a = c.a
		s.b = c.b
		_spots.append(s)
	for t in tiles:
		for i in t.valley.features.size():
			var ft: Dictionary = t.valley.features[i]
			if ft.type in ["washout", "slide"]:
				var reach := float(ft.width) + 5.0
				var kind := "fill" if ft.type == "washout" else "slide"
				var s := _spot("%s:%s%d" % [kind, t.valley.id, i], kind, _road_path(t, int(ft.road), float(ft.s) - reach, float(ft.s) + reach), t.valley.id)
				_spots.append(s)
				if kind == "slide":
					_slide_volume[s.id] = _above(s, true)
		for i in t.valley.bogs.size():
			var bg: Dictionary = t.valley.bogs[i]
			var g := _spot("gravel_road:%s%d" % [t.valley.id, i], "gravel_road", _road_path(t, int(bg.road), float(bg.from), float(bg.to)), t.valley.id)
			# Loads of gravel to cover it: a load spreads a strip GRAVEL_STRIP m long, half a road wide.
			g.needs = {"gravel": ceili((float(bg.to) - float(bg.from)) * 2.0 / GRAVEL_STRIP)}
			_spots.append(g)
	return _spots


## The bridge over spot id stands (its site built the deck, or build_deck did): the map and the
## tests know the crossing is open.
func bridged(id: String, deck: Node3D = null) -> void:
	bridges[id] = deck if deck else true


func spot(id: String) -> Dictionary:
	for s in site_spots():
		if s.id == id:
			return s
	return {}


func _spot(id: String, kind: String, path: PackedVector2Array, biome: String) -> Dictionary:
	var a := path[0]
	var b := path[path.size() - 1]
	return {"id": id, "kind": kind, "path": path, "width": CORRIDOR, "biome": biome, "pos": path[path.size() / 2], "needs": {},
		"a": Vector3(a.x, get_height(a.x, a.y), a.y), "b": Vector3(b.x, get_height(b.x, b.y), b.y)}


## Road r of tile t from s0 to s1 metres along it, in the world, every 2 m.
func _road_path(t: Terrain, r: int, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := s0
	while s < s1:
		out.append((t.along(r, s)[0] as Vector2) + t.origin)
		s += 2.0
	out.append((t.along(r, s1)[0] as Vector2) + t.origin)
	return out


## How a road site's corridor stands now: {drivable, why ("" or where it is not), covered (the
## share spread with gravel), cleared (the share of a slide dug away; 1 for the rest)}.
## Drivable: along its centre line no metre climbs more than DRIVABLE_CLIMB, and across its width
## it is level to DRIVABLE_ACROSS.
func corridor_state(s: Dictionary) -> Dictionary:
	var path: PackedVector2Array = s.path
	var why := ""
	var along := 0.0
	var prev := INF
	var prev_at := Vector2.ZERO
	for i in path.size():
		var p := path[i]
		var dir := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x) * (float(s.width) * 0.5 - 0.5)
		var h := get_height(p.x, p.y)
		if i > 0:
			along += p.distance_to(prev_at)
			if absf(h - prev) / maxf(p.distance_to(prev_at), 0.01) > DRIVABLE_CLIMB:
				why = "Too steep %d m along: dig or fill there first" % roundi(along)
				break
		var l := get_height(p.x - side.x, p.y - side.y)
		var r := get_height(p.x + side.x, p.y + side.y)
		if maxf(maxf(l, r), h) - minf(minf(l, r), h) > DRIVABLE_ACROSS:
			why = "Not level across %d m along: dig or fill there first" % roundi(along)
			break
		prev = h
		prev_at = p
	var cleared := 1.0
	if s.kind == "slide" and float(_slide_volume.get(s.id, 0.0)) > 0.0:
		cleared = clampf(1.0 - _above(s, false) / float(_slide_volume[s.id]), 0.0, 1.0)
	return {"drivable": why == "", "why": why, "covered": _covered(s), "cleared": cleared}


## m3 over the corridor's straight level from end to end: as made, or now.
func _above(s: Dictionary, made: bool) -> float:
	var path: PackedVector2Array = s.path
	var a := path[0]
	var b := path[path.size() - 1]
	var ha := earthworks.generated(roundi(a.x), roundi(a.y)) if made else get_height(a.x, a.y)
	var hb := earthworks.generated(roundi(b.x), roundi(b.y)) if made else get_height(b.x, b.y)
	var sum := 0.0
	for v in _corridor_vertices(s):
		var t := clampf((Vector2(v) - a).dot(b - a) / maxf(a.distance_squared_to(b), 0.01), 0.0, 1.0)
		var h := earthworks.generated(v.x, v.y) if made else earthworks.height(v.x, v.y)
		sum += maxf(h - lerpf(ha, hb, t), 0.0)
	return sum


## The share of the corridor spread with gravel.
func _covered(s: Dictionary) -> float:
	var vs := _corridor_vertices(s)
	if vs.is_empty():
		return 0.0
	var n := 0
	for v in vs:
		var t := tile_at(v.x, v.y)
		var c := t._works_at(Vector3(v.x - t.origin.x, 0.0, v.y - t.origin.y))
		n += 1 if c.g > 0.5 else 0
	return float(n) / vs.size()


## The vertices within the corridor (width) of the path.
func _corridor_vertices(s: Dictionary) -> Array[Vector2i]:
	var path: PackedVector2Array = s.path
	var half := float(s.width) * 0.5
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for p in path:
		lo = lo.min(p)
		hi = hi.max(p)
	var out: Array[Vector2i] = []
	for z in range(floori(lo.y - half), ceili(hi.y + half) + 1):
		for x in range(floori(lo.x - half), ceili(hi.x + half) + 1):
			if _to_path(path, Vector2(x, z)).x <= half:
				out.append(Vector2i(x, z))
	return out


## [distance from q to path, metres along it to its nearest point].
static func _to_path(path: PackedVector2Array, q: Vector2) -> Vector2:
	var best := Vector2(INF, 0.0)
	var along := 0.0
	for i in path.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(q, path[i], path[i + 1])
		var d := q.distance_to(c)
		if d < best.x:
			best = Vector2(d, along + path[i].distance_to(c))
		along += path[i].distance_to(path[i + 1])
	return best


## A road site done: its corridor graded (docs/plan.md §5). Its profile is smoothed as a smoothed
## road's is (GRADE_SMOOTH m, GRADE_MOST at most), level across, its edges eased into the ground
## beside; it is marked as road, its mud and soft layer go, and it does not churn (works G).
func grade(s: Dictionary) -> void:
	var path: PackedVector2Array = s.path
	var raw := PackedFloat32Array()
	var steps := PackedFloat32Array()  # metres along at each point
	for i in path.size():
		raw.append(get_height(path[i].x, path[i].y))
		steps.append(0.0 if i == 0 else steps[i - 1] + path[i].distance_to(path[i - 1]))
	var total := steps[steps.size() - 1]
	var prof := PackedFloat32Array()
	prof.resize(path.size())
	for i in path.size():
		var sum := 0.0
		var n := 0
		for j in path.size():
			if absf(steps[j] - steps[i]) <= GRADE_SMOOTH * 0.5:
				sum += raw[j]
				n += 1
		var end_t := smoothstep(0.0, 4.0, minf(steps[i], total - steps[i]))  # its ends stay where the road goes on
		prof[i] = lerpf(raw[i], sum / n, end_t)
	for k in 4:
		for i in range(1, prof.size()):
			var most := GRADE_MOST * (steps[i] - steps[i - 1])
			prof[i] = clampf(prof[i], prof[i - 1] - most, prof[i - 1] + most)
		for i in range(prof.size() - 2, -1, -1):
			var most := GRADE_MOST * (steps[i + 1] - steps[i])
			prof[i] = clampf(prof[i], prof[i + 1] - most, prof[i + 1] + most)
	var half := float(s.width) * 0.5
	var edge := s.duplicate()
	edge.width = float(s.width) + 4.0
	for v in _corridor_vertices(edge):
		var q := _to_path(path, Vector2(v))
		var k := 0
		while k < steps.size() - 2 and steps[k + 1] < q.y:
			k += 1
		var level := lerpf(prof[k], prof[k + 1], clampf((q.y - steps[k]) / maxf(steps[k + 1] - steps[k], 0.01), 0.0, 1.0))
		var w := 1.0 - smoothstep(half, half + 2.0, q.x)
		earthworks.set_height(v.x, v.y, lerpf(earthworks.height(v.x, v.y), level, w))
	for i in path.size():
		for t in tiles:
			var l := path[i] - t.origin
			if absf(l.x) < Terrain.HALF + half and absf(l.y) < Terrain.HALF + half:
				t.paint(l, half, Color(0.0, 1.0, 0.0), Color(1.0, 1.0, 1.0), true, false)
				t.mark_road(l, half)
	graded[s.id] = true
	earthworks.changed.emit()


## A deck over a bridge site, from bank to bank at their heights (docs/plan.md §5): a StaticBody3D
## of boxes, a deck and its rails, on two piers, with a road's grip (it is not the ground). The
## bridge's site puts it up when it stands; a test may too.
func build_deck(s: Dictionary) -> StaticBody3D:
	var a: Vector3 = s.a
	var b: Vector3 = s.b
	# From the road to the road: 4 m onto each bank, its ends just under the ground there, so a
	# wheel rolls off the road onto it without a step.
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	a -= dir * 4.0
	b += dir * 4.0
	a.y = get_height(a.x, a.z) - 0.05
	b.y = get_height(b.x, b.z) - 0.05
	var body := StaticBody3D.new()
	body.name = "Deck_" + String(s.id).replace(":", "_")
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := Vector2(flat.length(), b.y - a.y).length()
	var deck := Vector3(float(s.width) - 1.0, 0.4, length)
	body.position = (a + b) * 0.5
	body.basis = Basis(Vector3.UP, atan2(-flat.x, -flat.z)) * Basis(Vector3.RIGHT, atan2(b.y - a.y, flat.length()))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = deck
	cs.shape = box
	cs.position = Vector3(0.0, -0.2, 0.0)
	body.add_child(cs)
	Psx.box(body, deck, cs.position, Color(0.45, 0.36, 0.26))
	for side in [-1.0, 1.0]:
		var rail := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(0.2, 0.9, length)
		rail.shape = rb
		rail.position = Vector3(side * deck.x * 0.5, 0.45, 0.0)
		body.add_child(rail)
		Psx.box(body, rb.size, rail.position, Color(0.6, 0.58, 0.55))
	for k: float in [-0.25, 0.25]:
		var top: Vector3 = body.position + (b - a) * k
		var depth := maxf(top.y - get_height(top.x, top.z) + 0.5, 1.0)
		Psx.box(body, Vector3(1.2, depth, 1.2), Vector3(0.0, -0.4 - depth * 0.5, -flat.length() * k), Color(0.55, 0.55, 0.52))
	add_child(body)
	bridges[s.id] = body
	return body


## The gravel deposits a quarry may stand on, in the world: {pos, radius, biome}.
func deposits() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in tiles:
		for loc in t.valley.locations.values():
			if loc.kind == "gravel":
				out.append({"pos": (loc.pos as Vector2) + t.origin, "radius": float(loc.radius), "biome": t.valley.id})
	return out


## The shortest way by road from a to b (world): every road of the map, joined where a point of
## one is within a metre of a point of another (their ends at a place, a junction, a gate on a
## border). [the points (world), its length in m]; [[], INF] when no road goes there.
func route(a: Vector2, b: Vector2) -> Array:
	var pts := PackedVector2Array()
	var edges := {}  # point index -> [[index, metres], ...]
	for road in all_roads():
		var prev := -1
		for p in road:
			var i := -1
			for j in pts.size():
				if pts[j].distance_to(p) < 1.0:
					i = j
					break
			if i < 0:
				i = pts.size()
				pts.append(p)
				edges[i] = []
			if prev >= 0 and prev != i:
				var d := pts[prev].distance_to(pts[i])
				edges[prev].append([i, d])
				edges[i].append([prev, d])
			prev = i
	var start := -1
	var goal := -1
	for j in pts.size():
		if start < 0 or pts[j].distance_to(a) < pts[start].distance_to(a):
			start = j
		if goal < 0 or pts[j].distance_to(b) < pts[goal].distance_to(b):
			goal = j
	var dist := {start: 0.0}
	var from := {}
	var open := [start]
	while not open.is_empty():
		var best := 0
		for k in open.size():
			if dist[open[k]] < dist[open[best]]:
				best = k
		var i: int = open.pop_at(best)
		if i == goal:
			var out := PackedVector2Array([pts[i]])
			while from.has(i):
				i = from[i]
				out.insert(0, pts[i])
			return [out, dist[goal]]
		for e in edges[i]:
			var nd: float = dist[i] + e[1]
			if not dist.has(e[0]) or nd < dist[e[0]]:
				dist[e[0]] = nd
				from[e[0]] = i
				open.append(e[0])
	return [PackedVector2Array(), INF]


## The road sites (site_spots) along a route's points, in the order it meets them.
func sites_along(points: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := {}
	for s in site_spots():
		var q := _to_path(points, s.pos)
		if q.x < CORRIDOR:
			at[s.id] = q.y
			out.append(s)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return at[x.id] < at[y.id])
	return out


## The mud at pos (world) deepens by amount, up to 1: a heavy rig's wheel spinning in it. Gravel
## spread does not churn.
func churn(pos: Vector3, amount: float) -> void:
	var t := tile_at(pos.x, pos.z)
	t.churn(pos - t.position, amount)
