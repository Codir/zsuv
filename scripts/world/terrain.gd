class_name Terrain
extends Node3D
## Procedural 256x256 m terrain from a Valley: heights + a snow (or sand) and mud layer that the
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
	var snow := 0.0  # the soft layer's depth, m: snow, or sand (valley.layer)
	var mud := 0.0
	var ice := 0.0


var valley: Valley
var heights := PackedFloat32Array()
var snow_img: Image  # R - snow or sand, G - mud, B - road, A - 1 - ice
var track_img: Image  # compaction 0..1
var track_tex: ImageTexture
var roads: Array[PackedVector2Array] = []

var _track_dirty := false
var _track_timer := 0.0
var _base: FastNoiseLite
var _profiles: Array[Dictionary] = []  # per road: {at: cumulative length at each point, h: heights every PROFILE_STEP}

const PROFILE_STEP := 2.0


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
	var sea := {}
	for ft in v.features:
		match ft.type:
			"lake":
				ft.height = base_height(ft.pos) - float(ft.depth)
				lakes.append(ft)
			"ditch":
				ditches.append(ft)
			"sea":
				sea = ft

	_profiles.clear()
	for road in roads:
		_profiles.append(_profile(road, v.road_smooth))

	heights.resize(N * N)
	snow_img = Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	for z in N:
		for x in N:
			var p := Vector2(x - HALF, z - HALF)
			var b := base_height(p)
			var h := b + detail.get_noise_2d(p.x, p.y) * v.detail
			# A road is a shelf: as high as the ground at its centre line, level across.
			var near := _road_closest(p)
			var rd: float = near.x
			var road_t := 1.0 - smoothstep(ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 4.0, rd)
			# A smoothed road is laid after the ramps off the places, which it was smoothed over.
			var road_last := v.road_smooth > 0.0
			if road_t > 0.0 and not road_last:
				h = lerpf(h, _road_height(near), road_t)
			# The rim at the map's edge goes on after the flats, so a long ramp off a location
			# near the edge cannot drag the rim down with it. No rim on the sea's side.
			var rim := _rim(p, sea) * 30.0 * (1.0 - road_t)
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
			if road_t > 0.0 and road_last:
				h = lerpf(h, _road_height(near), road_t)
				for f in flats:  # a place stays level where the road arrives in it
					h = lerpf(h, f.height, 1.0 - smoothstep(f.radius - 3.0, f.radius, p.distance_to(f.pos)))
			var ice := 0.0
			for l in lakes:
				var r: float = l.radius
				var d := p.distance_to(l.pos)
				h = lerpf(h, l.height, 1.0 - smoothstep(r * 0.8, r + float(l.get("shore", 8.0)), d))
				if l.get("ice", false):
					ice = maxf(ice, 1.0 - smoothstep(r * 0.82, r * 0.92, d))
			h += rim
			for dt in ditches:
				var half: Vector2 = dt.dir * float(dt.length) * 0.5
				var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, dt.pos - half, dt.pos + half))
				h -= float(dt.depth) * _bump(d / float(dt.width))
			if not sea.is_empty():
				h = lerpf(h, float(sea.level) - 4.0, smoothstep(0.0, 30.0, _past_coast(p, sea)))
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
	return h


## 1 at 0, easing to 0 at 1 and beyond.
func _bump(t: float) -> float:
	return 0.5 + 0.5 * cos(PI * clampf(t, 0.0, 1.0))


func _rim(p: Vector2, sea: Dictionary) -> float:
	var r := 0.0
	for axis in 2:
		for sgn in [-1.0, 1.0]:
			if not sea.is_empty() and _side(sea.side) == Vector2(axis, sgn):
				continue
			r = maxf(r, smoothstep(100.0, 126.0, p[axis] * sgn))
	return r


## How far past the coast p is, towards the sea's side of the map (negative: inland).
func _past_coast(p: Vector2, sea: Dictionary) -> float:
	var s := _side(sea.side)
	return p[int(s.x)] * s.y - float(sea.coast)


## A side of the map as (axis, sign): x is 0, z is 1.
func _side(side: String) -> Vector2:
	match side:
		"west":
			return Vector2(0, -1)
		"east":
			return Vector2(0, 1)
		"north":
			return Vector2(1, -1)
	return Vector2(1, 1)  # south


## The nearest road to p: {x: distance, at: its nearest point, road: index, s: metres along it}.
func _road_closest(p: Vector2) -> Dictionary:
	var best := INF
	var out := {"x": INF, "at": p, "road": -1, "s": 0.0}
	for r in roads.size():
		var road := roads[r]
		var along := 0.0
		for i in road.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1])
			var d := p.distance_squared_to(c)
			if d < best:
				best = d
				out = {"x": 0.0, "at": c, "road": r, "s": along + road[i].distance_to(c)}
			along += road[i].distance_to(road[i + 1])
	out.x = sqrt(best)
	return out


func road_distance(p: Vector2) -> float:
	return _road_closest(p).x


## How high the road is at its nearest point: the ground there, or its smoothed profile.
func _road_height(near: Dictionary) -> float:
	var prof: Dictionary = _profiles[near.road]
	if prof.is_empty():
		return base_height(near.at)
	var hs: PackedFloat32Array = prof.h
	var k := clampf(float(near.s) / PROFILE_STEP, 0.0, hs.size() - 1.001)
	var i := int(k)
	return lerpf(hs[i], hs[i + 1], k - i)


## A road's heights every PROFILE_STEP metres, averaged over smooth metres either way so it cuts
## through bumps and fills hollows, but the ground's own height at both ends, where it meets a
## place or another road. Empty when smooth is 0: the road keeps to the ground.
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
		var end_t := smoothstep(0.0, smooth, minf(k * PROFILE_STEP, total - k * PROFILE_STEP))
		hs[k] = lerpf(raw[k], sum / n, end_t)
	# No steeper than the valley's grade, both ways: the road cuts into the slope above it and
	# is filled below, as a hairpin turning up a mountainside has to be.
	var rise := valley.road_grade * PROFILE_STEP
	if rise > 0.0:
		for round in 4:  # the ends stay where the places are
			for k in range(1, hs.size() - 1):
				hs[k] = clampf(hs[k], hs[k - 1] - rise, hs[k - 1] + rise)
			for k in range(hs.size() - 2, 0, -1):
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
