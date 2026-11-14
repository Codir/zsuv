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

const MAP_VERSION := 1  # moves with any change to what the generator makes (docs/plan.md §3, §11)
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
	for t in tiles:
		add_child(t)
		t.finish()
		_bodies.append(t.body.get_rid())
	for b in borders:
		if b.kind != "land":
			_water_plane(b)
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


## The water's level at p: a river's or a gorge's along its border; -INF where there is none.
func water_level(p: Vector2) -> float:
	for b in borders:
		if b.kind == "land":
			continue
		var d: float = _across(b, p)
		var i: float = _along(b, p)
		if absf(d) < float(b.half) and i >= END and i <= Terrain.SIZE - END:
			return b.water_level
	return -INF


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
