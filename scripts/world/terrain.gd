class_name Terrain
extends Node3D
## Procedural 256x256 m terrain from a Valley: heights + a snow (or dust) and mud layer that the
## wheels deform, ice on frozen lakes.

const SIZE := 256
const HALF := 128.0
const N := SIZE + 1
const TRACK_RES := SIZE * 2 + 1  # 0.5 m per pixel
const CHUNK := 32
const MAX_SNOW := 0.8
const MAX_MUD := 0.4
const ROAD_HALF_WIDTH := 3.5

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

var _track_dirty := false
var _track_timer := 0.0
var _base: FastNoiseLite
var _profiles: Array[Dictionary] = []  # per road: {at: cumulative length at each point, h: heights every PROFILE_STEP}
var _seg_road := PackedInt32Array()  # every segment of every road in order: its road,
var _seg_a := PackedVector2Array()  # its ends,
var _seg_b := PackedVector2Array()
var _seg_along := PackedFloat64Array()  # and the metres along its road where it starts
var _all_segs := PackedInt32Array()
var _grid: Array[PackedInt32Array] = []  # per GRID_CELL square of the map: the segments within NEAR m of it

const PROFILE_STEP := 2.0
const PIN := 14.0  # a smoothed road keeps to the ground this far from its ends: across the place there
const NEAR := 12.0  # the ground looks at the roads this near it: their shelves and where two blend
const GRID_CELL := 4.0
const GRID := int(SIZE / GRID_CELL) + 1  # squares a side, one past the map's far edge
const NO_ROAD := {"x": INF}  # _road_near where no road is that near


func generate(v: Valley) -> void:
	valley = v
	roads = v.roads
	_base = _noise(v.seed, 0.008, 3)
	var detail := _noise(v.seed + 1, 0.05, 2)
	var snow_noise := _noise(v.seed + 2, 0.03, 2)
	var mud_noise := _noise(v.seed + 3, 0.025, 2)

	var flats: Array = v.locations.values()
	for f in flats:
		f.height = base_height(f.pos)
	var lakes: Array[Dictionary] = []
	var ditches: Array[Dictionary] = []
	for ft in v.features:
		match ft.type:
			"lake":
				ft.height = base_height(ft.pos) - float(ft.depth)
				lakes.append(ft)
			"ditch":
				ditches.append(ft)

	_profiles.clear()
	for road in roads:
		_profiles.append(_profile(road, v.road_smooth))
	_index_roads()

	heights.resize(N * N)
	snow_img = Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	for z in N:
		for x in N:
			var p := Vector2(x - HALF, z - HALF)
			var b := base_height(p)
			var h := b + detail.get_noise_2d(p.x, p.y) * v.detail
			# A road is a shelf: as high as the ground at its centre line, level across.
			var near := _road_near(p)
			var rd: float = near.x
			var road_t := 1.0 - smoothstep(ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 4.0, rd)
			# A smoothed road is laid after the ramps off the places, which it was smoothed over.
			var road_last := v.road_smooth > 0.0
			if road_t > 0.0 and not road_last:
				h = lerpf(h, _road_height(p, near), road_t)
			# A lake and its shore go in before the flats, so a place on the shore stays level.
			var ice := 0.0
			for l in lakes:
				var r: float = l.radius
				var d := p.distance_to(l.pos)
				h = lerpf(h, l.height, 1.0 - smoothstep(r * 0.8, r + float(l.get("shore", 8.0)), d))
				if l.get("ice", false):
					ice = maxf(ice, 1.0 - smoothstep(r * 0.82, r * 0.92, d))
			# The rim at the map's edge goes on after the flats, so a long ramp off a location
			# near the edge cannot drag the rim down with it.
			var rim := smoothstep(100.0, 126.0, maxf(absf(p.x), absf(p.y))) * v.rim * (1.0 - road_t)
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
			h += rim
			for dt in ditches:
				if p.distance_to(dt.pos) >= float(dt.length) * 0.5 + float(dt.width):
					continue  # it does not reach this far
				var half: Vector2 = dt.dir * float(dt.length) * 0.5
				var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, dt.pos - half, dt.pos + half))
				h -= float(dt.depth) * _bump(d / float(dt.width))
			heights[z * N + x] = h

			var on_road := 1.0 - smoothstep(ROAD_HALF_WIDTH - 0.5, ROAD_HALF_WIDTH + 1.0, rd)
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

	_build_visuals()
	_build_collision()


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
	if valley.road_smooth > 0.0 and not other.is_empty() and other.x - near.x < 4.0:
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
	var fx := clampf(x + HALF, 0.0, SIZE - 0.001)
	var fz := clampf(z + HALF, 0.0, SIZE - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * N + ix
	return lerpf(lerpf(heights[i], heights[i + 1], tx), lerpf(heights[i + N], heights[i + N + 1], tx), tz)


func sample(pos: Vector3) -> Surface:
	var s := Surface.new()
	var c := snow_img.get_pixel(clampi(roundi(pos.x + HALF), 0, N - 1), clampi(roundi(pos.z + HALF), 0, N - 1))
	var tr := _track_at(pos)
	s.snow = c.r * MAX_SNOW * (1.0 - tr * 0.7)
	s.mud = c.g * (1.0 - tr * 0.2)
	s.ice = 1.0 - c.a
	s.grip = lerpf(1.0, valley.layer_grip, clampf(s.snow / 0.4, 0.0, 1.0))
	s.grip = lerpf(s.grip, 0.4, s.mud)
	s.grip = lerpf(s.grip, 0.15, s.ice)
	s.rolling = 0.015 + s.snow * valley.layer_rolling + s.mud * 0.17
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


func _track_at(pos: Vector3) -> float:
	var ix := clampi(roundi((pos.x + HALF) * 2.0), 0, TRACK_RES - 1)
	var iz := clampi(roundi((pos.z + HALF) * 2.0), 0, TRACK_RES - 1)
	return track_img.get_pixel(ix, iz).r


func _noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


func _build_visuals() -> void:
	var height_tex := ImageTexture.create_from_image(Image.create_from_data(N, N, false, Image.FORMAT_RF, heights.to_byte_array()))
	var snow_tex := ImageTexture.create_from_image(snow_img)
	track_img = Image.create_empty(TRACK_RES, TRACK_RES, false, Image.FORMAT_R8)
	track_tex = ImageTexture.create_from_image(track_img)

	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("height_tex", height_tex)
	ground_mat.set_shader_parameter("snow_tex", snow_tex)
	ground_mat.set_shader_parameter("earth_col", _rgb(valley.earth))
	ground_mat.set_shader_parameter("gravel_col", _rgb(valley.gravel))
	ground_mat.set_shader_parameter("ice_col", _rgb(valley.ice_color))

	var snow_mat := ShaderMaterial.new()
	snow_mat.shader = SNOW_SHADER
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

	var chunks := SIZE / CHUNK
	for cz in chunks:
		for cx in chunks:
			var min_h := INF
			var max_h := -INF
			for z in range(cz * CHUNK, (cz + 1) * CHUNK + 1):
				for x in range(cx * CHUNK, (cx + 1) * CHUNK + 1):
					var h := heights[z * N + x]
					min_h = minf(min_h, h)
					max_h = maxf(max_h, h)
			var aabb := AABB(Vector3(-CHUNK * 0.5, min_h - 1.0, -CHUNK * 0.5), Vector3(CHUNK, max_h - min_h + 2.0, CHUNK))
			var center := Vector3(-HALF + (cx + 0.5) * CHUNK, 0.0, -HALF + (cz + 0.5) * CHUNK)
			_add_chunk(ground_mesh, ground_mat, aabb, center)
			_add_chunk(snow_mesh, snow_mat, aabb, center)


func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _add_chunk(m: Mesh, material: Material, aabb: AABB, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.custom_aabb = aabb
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var body := StaticBody3D.new()
	body.add_child(cs)
	add_child(body)
