class_name Terrain
extends Node3D
## Procedural 256x256 m terrain: heights + a snow/mud layer that the wheels deform.

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
	var snow := 0.0
	var mud := 0.0


var heights := PackedFloat32Array()
var snow_img: Image  # R - snow, G - mud, B - road
var track_img: Image  # compaction 0..1
var track_tex: ImageTexture
var roads: Array[PackedVector2Array] = []

var _track_dirty := false
var _track_timer := 0.0


func generate(p_roads: Array[PackedVector2Array], flats: Array[Dictionary], puddles: Array[Dictionary], seed_value := 1337) -> void:
	roads = p_roads
	var base := _noise(seed_value, 0.008, 3)
	var detail := _noise(seed_value + 1, 0.05, 2)
	var snow_noise := _noise(seed_value + 2, 0.03, 2)
	var mud_noise := _noise(seed_value + 3, 0.025, 2)

	for f in flats:
		var fp: Vector2 = f.pos
		f.height = base.get_noise_2d(fp.x, fp.y) * 16.0

	heights.resize(N * N)
	snow_img = Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	for z in N:
		for x in N:
			var p := Vector2(x - HALF, z - HALF)
			var b := base.get_noise_2d(p.x, p.y) * 16.0
			var h := b + detail.get_noise_2d(p.x, p.y) * 2.5
			var rd := road_distance(p)
			var road_t := 1.0 - smoothstep(ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 4.0, rd)
			h = lerpf(h, b, road_t)
			# The rim at the map's edge goes on after the flats, so a long ramp off a location
			# near the edge cannot drag the rim down with it.
			var rim := smoothstep(100.0, 126.0, maxf(absf(p.x), absf(p.y))) * 30.0 * (1.0 - road_t)
			var flat_t := 0.0
			for f in flats:
				var r: float = f.radius
				var d := p.distance_to(f.pos)
				# The higher the step down to the ground around, the longer the ramp off the
				# flat, so the roads out of a location stay drivable.
				var ramp := maxf(10.0, absf(b - f.height) * 5.0)
				h = lerpf(h, f.height, 1.0 - smoothstep(r, r + ramp, d))
				rim *= smoothstep(r, r + 10.0, d)
				flat_t = maxf(flat_t, 1.0 - smoothstep(r - 3.0, r, d))
			heights[z * N + x] = h + rim

			var on_road := 1.0 - smoothstep(ROAD_HALF_WIDTH - 0.5, ROAD_HALF_WIDTH + 1.0, rd)
			var snow := clampf(0.55 + snow_noise.get_noise_2d(p.x, p.y) * 0.6, 0.15, 1.0)
			snow *= 1.0 - maxf(on_road * 0.93, flat_t * 0.9)
			var mud := smoothstep(0.3, 0.5, mud_noise.get_noise_2d(p.x, p.y)) * (1.0 - maxf(on_road, flat_t))
			for pd in puddles:
				var pr: float = pd.radius
				mud = maxf(mud, 1.0 - smoothstep(pr * 0.5, pr, p.distance_to(pd.pos)))
			snow_img.set_pixel(x, z, Color(snow, mud, on_road, 1.0))

	_build_visuals()
	_build_collision()


func road_distance(p: Vector2) -> float:
	var best := INF
	for road in roads:
		for i in road.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1])
			best = minf(best, p.distance_squared_to(c))
	return sqrt(best)


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
	s.grip = lerpf(1.0, 0.6, clampf(s.snow / 0.4, 0.0, 1.0))
	s.grip = lerpf(s.grip, 0.4, s.mud)
	s.rolling = 0.015 + s.snow * 0.45 + s.mud * 0.17
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

	var snow_mat := ShaderMaterial.new()
	snow_mat.shader = SNOW_SHADER
	snow_mat.set_shader_parameter("height_tex", height_tex)
	snow_mat.set_shader_parameter("snow_tex", snow_tex)
	snow_mat.set_shader_parameter("track_tex", track_tex)
	snow_mat.set_shader_parameter("track_tex_px", track_tex)
	snow_mat.set_shader_parameter("max_snow", MAX_SNOW)
	snow_mat.set_shader_parameter("max_mud", MAX_MUD)

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
