class_name WorldBuilder
extends Node3D
## Places a valley's trees, rocks, buildings and the snow marker poles along its roads. One per tile
## of the Land, standing where its tile does: everything here is in the tile's own metres.

const TRUNK := Color(0.28, 0.18, 0.12)
const PINE := Color(0.12, 0.24, 0.18)
const PINE_LIGHT := Color(0.16, 0.3, 0.22)
const SNOW := Color(0.88, 0.92, 1.0)
const WARM_LIGHT := Color(1.0, 0.78, 0.45)

var terrain: Terrain
var valley: Valley
var tree_points := PackedVector2Array()
var anchor_points := PackedVector3Array()  # winch anchors
var props: Array[Dictionary] = []  # every tree and rock: {p (its own metres), kind, shape}; gone: shape null
var _rng := RandomNumberGenerator.new()


func build(t: Terrain, v: Valley) -> void:
	terrain = t
	valley = v
	_rng.seed = 4242 + v.seed - 1337
	_scatter_trees(v.locations)
	_scatter_rocks(v.locations)
	if v.poles:
		_road_poles()
	for loc in v.locations.values():
		call("_build_" + String(loc.kind), loc)
	_boundary_walls()


func _is_clear(p: Vector2, locations: Dictionary, margin: float) -> bool:
	for r in terrain.keep_clear:  # a river's bed and banks
		if r.grow(margin).has_point(p):
			return false
	if terrain.road_distance(p) < Terrain.ROAD_HALF_WIDTH + margin:
		return false
	for l in locations.values():
		if p.distance_to(l.pos) < float(l.radius) + margin + 4.0:
			return false
	for d in valley.ditches:  # room for a stuck car and the truck winching it
		if p.distance_to(d.at) < 8.0 + margin:
			return false
	for ft in valley.features:  # nothing grows on a lake or its ice
		if ft.type == "lake" and p.distance_to(ft.pos) < float(ft.radius) + margin:
			return false
	return true


func _scatter_trees(locations: Dictionary) -> void:
	var xforms: Array[Transform3D] = []
	var body := StaticBody3D.new()
	add_child(body)
	var attempts := 0
	while xforms.size() < valley.tree_count and attempts < valley.tree_count * 10:
		attempts += 1
		var p := Vector2(_rng.randf_range(-118.0, 118.0), _rng.randf_range(-118.0, 118.0))
		if not _is_clear(p, locations, 2.5):
			continue
		var s := _rng.randf_range(0.8, 1.5)
		var y := terrain.get_height(p.x, p.y)
		xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, y - 0.2, p.y)))
		tree_points.append(p)
		anchor_points.append(Vector3(p.x, y + 1.0, p.y))
		var shape := CylinderShape3D.new()
		shape.radius = 0.3 * s
		shape.height = 4.0 * s
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(p.x, y + 2.0 * s, p.y)
		cs.set_meta("anchor", anchor_points[anchor_points.size() - 1])  # the winch hooks it 1 m up its trunk
		body.add_child(cs)
		props.append({"p": p, "kind": "tree", "shape": cs})
	_trees(valley.trees, xforms)


## The valley's trees at xforms: pines under snow, bare pines, spruces heavy with snow, autumn
## poplars, spring broadleaves, or pines among birches.
func _trees(style: String, xforms: Array[Transform3D]) -> void:
	match style:
		"pine_snow":
			_multimesh(Psx.cylinder(0.2, 0.28, 2.4, 5), Psx.mat(TRUNK), xforms, Vector3(0.0, 1.2, 0.0))
			_multimesh(Psx.cylinder(0.0, 1.9, 3.6, 6), Psx.mat(PINE), xforms, Vector3(0.0, 3.2, 0.0))
			_multimesh(Psx.cylinder(0.0, 1.4, 2.8, 6), Psx.mat(PINE_LIGHT), xforms, Vector3(0.0, 4.9, 0.0))
			_multimesh(Psx.cylinder(0.0, 0.7, 1.4, 6), Psx.mat(SNOW), xforms, Vector3(0.0, 6.0, 0.0))
		"pine":
			_multimesh(Psx.cylinder(0.18, 0.26, 3.4, 5), Psx.mat(Color(0.42, 0.26, 0.16)), xforms, Vector3(0.0, 1.7, 0.0))
			_multimesh(Psx.cylinder(0.0, 1.6, 2.8, 6), Psx.mat(Color(0.16, 0.3, 0.16)), xforms, Vector3(0.0, 4.2, 0.0))
			_multimesh(Psx.cylinder(0.0, 1.1, 2.2, 6), Psx.mat(Color(0.2, 0.36, 0.18)), xforms, Vector3(0.0, 5.6, 0.0))
		"spruce_snow":
			_multimesh(Psx.cylinder(0.18, 0.24, 1.6, 5), Psx.mat(TRUNK), xforms, Vector3(0.0, 0.8, 0.0))
			_multimesh(Psx.cylinder(0.0, 1.5, 3.0, 6), Psx.mat(PINE), xforms, Vector3(0.0, 2.6, 0.0))
			_multimesh(Psx.cylinder(0.0, 1.1, 2.6, 6), Psx.mat(SNOW), xforms, Vector3(0.0, 4.3, 0.0))
			_multimesh(Psx.cylinder(0.0, 0.75, 2.2, 6), Psx.mat(PINE_LIGHT), xforms, Vector3(0.0, 5.8, 0.0))
			_multimesh(Psx.cylinder(0.0, 0.4, 1.0, 6), Psx.mat(SNOW), xforms, Vector3(0.0, 7.0, 0.0))
		"poplar":
			var gold: Array[Transform3D] = []
			var rust: Array[Transform3D] = []
			for i in xforms.size():
				(gold if i % 3 else rust).append(xforms[i])
			_multimesh(Psx.cylinder(0.14, 0.2, 2.4, 5), Psx.mat(Color(0.36, 0.3, 0.24)), xforms, Vector3(0.0, 1.2, 0.0))
			_multimesh(Psx.cylinder(0.35, 0.95, 6.5, 6), Psx.mat(Color(0.78, 0.62, 0.2)), gold, Vector3(0.0, 5.4, 0.0))
			_multimesh(Psx.cylinder(0.35, 0.95, 6.5, 6), Psx.mat(Color(0.62, 0.36, 0.14)), rust, Vector3(0.0, 5.4, 0.0))
		"broadleaf":
			var dark: Array[Transform3D] = []
			var light: Array[Transform3D] = []
			for i in xforms.size():
				(dark if i % 2 else light).append(xforms[i])
			var crown := SphereMesh.new()
			crown.radius = 1.9
			crown.height = 3.2
			crown.radial_segments = 7
			crown.rings = 3
			_multimesh(Psx.cylinder(0.18, 0.28, 2.6, 5), Psx.mat(Color(0.32, 0.24, 0.16)), xforms, Vector3(0.0, 1.3, 0.0))
			_multimesh(crown, Psx.mat(Color(0.2, 0.4, 0.16)), dark, Vector3(0.0, 3.9, 0.0))
			_multimesh(crown, Psx.mat(Color(0.34, 0.52, 0.2)), light, Vector3(0.0, 3.9, 0.0))
		"pine_birch":
			var pines: Array[Transform3D] = []
			var birches: Array[Transform3D] = []
			for i in xforms.size():
				(pines if i % 2 else birches).append(xforms[i])
			_trees("pine", pines)
			var crown := SphereMesh.new()
			crown.radius = 1.3
			crown.height = 2.8
			crown.radial_segments = 6
			crown.rings = 3
			_multimesh(Psx.cylinder(0.12, 0.17, 4.2, 5), Psx.mat(Color(0.86, 0.85, 0.8)), birches, Vector3(0.0, 2.1, 0.0))
			_multimesh(crown, Psx.mat(Color(0.5, 0.54, 0.26)), birches, Vector3(0.0, 4.6, 0.0))


func _scatter_rocks(locations: Dictionary) -> void:
	var xforms: Array[Transform3D] = []
	var body := StaticBody3D.new()
	add_child(body)
	var attempts := 0
	while xforms.size() < valley.rock_count and attempts < valley.rock_count * 17:
		attempts += 1
		var p := Vector2(_rng.randf_range(-115.0, 115.0), _rng.randf_range(-115.0, 115.0))
		if not _is_clear(p, locations, 1.5):
			continue
		var s := _rng.randf_range(0.6, 2.0)
		var y := terrain.get_height(p.x, p.y)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 1.3, s * 0.8, s))
		xforms.append(Transform3D(b, Vector3(p.x, y, p.y)))
		anchor_points.append(Vector3(p.x, y + s * 0.5, p.y))
		var shape := SphereShape3D.new()
		shape.radius = s * 0.8
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(p.x, y, p.y)
		cs.set_meta("anchor", anchor_points[anchor_points.size() - 1])
		cs.set_meta("what", "the rock")
		body.add_child(cs)
		props.append({"p": p, "kind": "rock", "shape": cs})
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 3
	_multimesh(sphere, Psx.mat(Color(0.38, 0.38, 0.4)), xforms, Vector3.ZERO)


## Orange snow poles along the roads: something to steer by in a blizzard.
func _road_poles() -> void:
	var xforms: Array[Transform3D] = []
	var offset := Terrain.ROAD_HALF_WIDTH + 1.2
	for road in terrain.roads:
		var carry := 0.0
		for i in road.size() - 1:
			var a := road[i]
			var b := road[i + 1]
			var seg := a.distance_to(b)
			var dir := (b - a) / seg
			var side := Vector2(-dir.y, dir.x)
			var d := carry
			while d < seg:
				var c := a + dir * d
				for k in [-1.0, 1.0]:
					var p: Vector2 = c + side * offset * k
					xforms.append(Transform3D(Basis(), Vector3(p.x, terrain.get_height(p.x, p.y) + 0.9, p.y)))
				d += 14.0
			carry = d - seg
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 1.8, 0.1)
	_multimesh(bm, Psx.mat(Color(1.0, 0.4, 0.1), 0.8), xforms, Vector3.ZERO)


func _multimesh(m: Mesh, material: Material, xforms: Array[Transform3D], offset: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xforms.size()
	var local := Transform3D(Basis(), offset)
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i] * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.get_height(x, z) - 0.3, z)


## How far the ground under a footprint of size at pos, turned by yaw, falls below the ground at
## base: a piece standing at base's height reaches down that much further, so it does not float.
func _fall(base: Vector3, pos: Vector3, yaw: float, size: Vector3) -> float:
	var low := INF
	for i in 3:
		for k in 3:
			var p := pos + Basis(Vector3.UP, yaw) * Vector3((i - 1) * size.x * 0.5, 0.0, (k - 1) * size.z * 0.5)
			low = minf(low, terrain.get_height(p.x, p.z))
	return maxf(0.0, terrain.get_height(base.x, base.z) - low)


func _house(pos: Vector3, yaw: float, size: Vector3, wall: Color, roof: Color, lit := true) -> StaticBody3D:
	var root := StaticBody3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	# The walls reach down to the lowest ground under them; the roof, door and window stay.
	var drop := _fall(pos, pos, yaw, size)
	var walls := Vector3(size.x, size.y + drop, size.z)
	var shape := BoxShape3D.new()
	shape.size = walls
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, (size.y - drop) * 0.5, 0.0)
	root.add_child(cs)
	Psx.box(root, walls, Vector3(0.0, (size.y - drop) * 0.5, 0.0), wall)
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x + 0.6, size.y * 0.5, size.z + 0.6)
	Psx.mesh(root, prism, Vector3(0.0, size.y * 1.25, 0.0), roof)
	var front := size.z * 0.5 + 0.05
	Psx.box(root, Vector3(1.1, 2.0 + drop, 0.1), Vector3(-size.x * 0.25, 1.0 - drop * 0.5, front), Color(0.25, 0.16, 0.1))
	Psx.box(root, Vector3(1.2, 0.9, 0.1), Vector3(size.x * 0.2, size.y * 0.55, front), WARM_LIGHT, 1.5)
	if lit:
		var l := OmniLight3D.new()
		l.position = Vector3(size.x * 0.2, size.y * 0.55, front + 1.5)
		l.light_color = WARM_LIGHT
		l.light_energy = 1.4
		l.omni_range = 9.0
		root.add_child(l)
	return root


func _sign(pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = Psx.font()
	label.font_size = 48
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.8)
	label.outline_size = 8
	label.position = pos
	add_child(label)


func _lamp(pos: Vector3) -> void:
	Psx.box(self, Vector3(0.15, 4.0, 0.15), pos + Vector3(0.0, 2.0, 0.0), Color(0.2, 0.2, 0.22))
	Psx.box(self, Vector3(0.5, 0.2, 0.5), pos + Vector3(0.0, 4.0, 0.0), WARM_LIGHT, 2.5)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.0, 3.8, 0.0)
	l.light_color = WARM_LIGHT
	l.light_energy = 1.6
	l.omni_range = 14.0
	add_child(l)


## The place being built and how far its layout is turned: a layout is drawn with the road out
## of the place along ref, and _at and _yaw turn it to the road the place really has.
var _c := Vector2.ZERO
var _rot := 0.0


class Spinner:
	extends Node3D
	var speed := 1.0

	func _process(delta: float) -> void:
		rotate_object_local(Vector3.FORWARD, speed * delta)


func _frame(loc: Dictionary, ref := Vector2.RIGHT) -> void:
	_c = loc.pos
	_rot = ref.angle_to(_out_dir(loc))


## The way out of loc that leaves its back free for buildings: its one road, or the middle of
## its roads opposite the widest gap between them (or the place's own "out").
func _out_dir(loc: Dictionary) -> Vector2:
	if loc.has("out"):
		return (loc.out as Vector2).normalized()
	var angles := _ways(loc)
	if angles.is_empty():
		return Vector2.RIGHT
	if angles.size() == 1:
		return Vector2.from_angle(angles[0])
	angles.sort()
	var back := 0.0
	var widest := -1.0
	for i in angles.size():
		var a := angles[i]
		var gap := wrapf(angles[(i + 1) % angles.size()] - a, 0.0, TAU)
		if gap > widest:
			widest = gap
			back = a + gap * 0.5
	return -Vector2.from_angle(back)


## The angles of the roads out of loc.
func _ways(loc: Dictionary) -> Array[float]:
	var c: Vector2 = loc.pos
	var angles: Array[float] = []
	for road in terrain.roads:
		if road[0].distance_to(c) < 1.0:
			angles.append((road[1] - c).angle())
		if road[road.size() - 1].distance_to(c) < 1.0:
			angles.append((road[road.size() - 2] - c).angle())
	return angles


## A point of the layout, on the ground.
func _at(x: float, z: float) -> Vector3:
	var p := _c + Vector2(x, z).rotated(_rot)
	return _ground(p.x, p.y)


## A yaw of the layout, turned with it.
func _yaw(y: float) -> float:
	return y - _rot


## A box at offset from base, both turned by yaw; no collision. One that stands on the ground
## (its bottom no higher than the ground at base) reaches down to the lowest ground under it.
func _piece(size: Vector3, base: Vector3, offset: Vector3, yaw: float, color: Color, emission := 0.0) -> MeshInstance3D:
	var at := base + Basis(Vector3.UP, yaw) * offset
	var drop := 0.0
	if at.y - size.y * 0.5 <= terrain.get_height(base.x, base.z) + 0.15:
		drop = _fall(base, at, yaw, size)
	var m := Psx.box(self, size + Vector3(0.0, drop, 0.0), at - Vector3(0.0, drop * 0.5, 0.0), color, emission)
	m.rotation.y = yaw
	return m


## A box the truck runs into, standing on the ground at pos (down to the lowest ground under it).
func _solid(pos: Vector3, yaw: float, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	var drop := _fall(pos, pos, yaw, size)
	var box := Vector3(size.x, size.y + drop, size.z)
	var shape := BoxShape3D.new()
	shape.size = box
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, (size.y - drop) * 0.5, 0.0)
	body.add_child(cs)
	Psx.box(body, box, Vector3(0.0, (size.y - drop) * 0.5, 0.0), color)
	return body


## A round post or tower the truck runs into, down to the lowest ground under it.
func _column(pos: Vector3, radius: float, height: float, color: Color, top := -1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var drop := _fall(pos, pos, 0.0, Vector3(radius * 2.0, height, radius * 2.0))
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height + drop
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, (height - drop) * 0.5, 0.0)
	body.add_child(cs)
	Psx.mesh(body, Psx.cylinder(radius if top < 0.0 else top, radius, height + drop, 8), Vector3(0.0, (height - drop) * 0.5, 0.0), color)
	return body


func _roof(pos: Vector3, yaw: float, size: Vector3, color: Color) -> void:
	var prism := PrismMesh.new()
	prism.size = size
	var m := Psx.mesh(self, prism, pos, color)
	m.rotation.y = yaw


func _build_depot(loc: Dictionary) -> void:
	# Laid out for the khutir valley's road, which leaves its depot a little north of east;
	# another valley's depot is turned to its own first road.
	_frame(loc, Vector2(35, -7).normalized())
	_house(_at(-7.0, -8.0), _yaw(0.0), Vector3(10.0, 5.0, 7.0), Color(0.35, 0.42, 0.52), Color(0.6, 0.18, 0.12), false)
	_house(_at(6.0, -9.0), _yaw(0.0), Vector3(5.0, 3.5, 5.0), Color(0.85, 0.7, 0.35), Color(0.3, 0.3, 0.32))
	var pump := _at(-2.0, 7.0)
	var turn := _yaw(0.0)
	_piece(Vector3(0.8, 1.7, 0.6), pump, Vector3(0.0, 0.85, 0.0), turn, Color(0.8, 0.12, 0.1))
	_piece(Vector3(0.6, 0.3, 0.62), pump, Vector3(0.0, 1.5, 0.0), turn, Color(0.95, 0.95, 0.9), 1.5)
	_piece(Vector3(6.0, 0.3, 4.0), pump, Vector3(0.0, 4.2, 0.0), turn, Color(0.85, 0.85, 0.82))
	for side in [-2.6, 2.6]:
		_piece(Vector3(0.2, 4.2, 0.2), pump, Vector3(side, 2.1, 0.0), turn, Color(0.3, 0.3, 0.32))
	_lamp(_at(3.0, 2.0))
	_sign(_at(-7.0, -8.0) + Vector3(0.0, 8.5, 0.0), loc.name.to_upper())


func _build_khutir(loc: Dictionary) -> void:
	var c: Vector2 = loc.pos
	_house(_ground(c.x - 4.0, c.y + 4.0), PI, Vector3(6.0, 3.5, 5.0), Color(0.45, 0.6, 0.7), Color(0.85, 0.88, 0.95))
	_house(_ground(c.x + 7.0, c.y + 3.0), PI, Vector3(7.0, 5.0, 9.0), Color(0.6, 0.15, 0.1), Color(0.85, 0.88, 0.95), false)
	_sign(_ground(c.x, c.y + 4.0) + Vector3(0.0, 7.5, 0.0), loc.name.to_upper())


func _build_sawmill(loc: Dictionary) -> void:
	# Laid out for the khutir valley's road, which leaves its sawmill to the north; another valley's
	# sawmill is turned to its own roads.
	_frame(loc, Vector2(3, -33).normalized())
	_house(_at(0.0, 6.0), _yaw(PI), Vector3(9.0, 4.0, 6.0), Color(0.42, 0.28, 0.16), Color(0.85, 0.88, 0.95))
	# The log pile beside the road in, or beside the house where a second road leaves past it.
	var pile := _at(7.0, -4.0) if _ways(loc).size() < 2 else _at(8.5, 5.0)
	var logs := Psx.cylinder(0.35, 0.35, 6.0, 7)
	for row in 3:
		for i in 4 - row:
			var p := pile + Basis(Vector3.UP, _yaw(0.0)) * Vector3(0.0, 0.35 + row * 0.62, -1.1 + i * 0.72 + row * 0.36)
			var m := Psx.mesh(self, logs, p, Color(0.5, 0.33, 0.2))
			m.rotation = Vector3(0.0, _yaw(0.0), PI * 0.5)
	_sign(_at(0.0, 6.0) + Vector3(0.0, 7.5, 0.0), loc.name.to_upper())


func _build_radio_tower(loc: Dictionary) -> void:
	var c: Vector2 = loc.pos
	var base := _ground(c.x + 4.0, c.y + 4.0)
	Psx.box(self, Vector3(0.7, 20.0, 0.7), base + Vector3(0.0, 10.0, 0.0), Color(0.6, 0.6, 0.62))
	for i in 6:
		Psx.box(self, Vector3(2.0, 0.12, 0.12), base + Vector3(0.0, 2.0 + i * 3.0, 0.0), Color(0.75, 0.2, 0.15))
	Psx.box(self, Vector3(0.5, 0.5, 0.5), base + Vector3(0.0, 20.3, 0.0), Color(1.0, 0.1, 0.05), 3.0)
	var tower_body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 20.0, 1.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = base + Vector3(0.0, 10.0, 0.0)
	tower_body.add_child(cs)
	add_child(tower_body)
	_house(_ground(c.x - 4.0, c.y + 3.0), PI, Vector3(3.5, 2.6, 3.0), Color(0.55, 0.58, 0.5), Color(0.85, 0.88, 0.95))

	# A small drone on its pad: a hint of the UAV mechanics to come.
	var pad := _ground(c.x - 3.0, c.y - 4.0) + Vector3(0.0, 0.4, 0.0)
	Psx.mesh(self, Psx.cylinder(1.6, 1.6, 0.1, 8), pad, Color(0.3, 0.3, 0.32))
	Psx.box(self, Vector3(0.5, 0.18, 0.5), pad + Vector3(0.0, 0.25, 0.0), Color(0.2, 0.22, 0.25))
	for a in 4:
		var dir := Vector3(cos(a * PI * 0.5 + PI * 0.25), 0.0, sin(a * PI * 0.5 + PI * 0.25))
		Psx.box(self, Vector3(0.06, 0.06, 0.06), pad + Vector3(0.0, 0.25, 0.0) + dir * 0.35, Color(0.2, 0.2, 0.2))
		Psx.mesh(self, Psx.cylinder(0.22, 0.22, 0.02, 8), pad + Vector3(0.0, 0.32, 0.0) + dir * 0.5, Color(0.3, 0.9, 0.4), 1.0)
	_sign(base + Vector3(0.0, 23.0, 0.0), loc.name.to_upper())


func _boundary_walls() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	for i in 4:
		if not terrain.outer[["west", "east", "north", "south"][i]]:
			continue  # another biome goes on past it: no wall
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 200.0, 260.0) if i < 2 else Vector3(260.0, 200.0, 2.0)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var s := -1.0 if i % 2 == 0 else 1.0
		cs.position = Vector3(s * 127.0, 0.0, 0.0) if i < 2 else Vector3(0.0, 0.0, s * 127.0)
		body.add_child(cs)


# --- The new valleys' places: each laid out with its road leaving along +x ----------------------

## A depot in the new valleys: its sheds behind the yard, the roads out in front of it.
func _build_yard(loc: Dictionary) -> void:
	_frame(loc)
	_house(_at(-11.0, -3.0), _yaw(PI * 0.5), Vector3(10.0, 5.0, 7.0), Color(0.35, 0.42, 0.52), Color(0.6, 0.18, 0.12), false)
	_house(_at(-8.0, 9.0), _yaw(PI * 0.5), Vector3(5.0, 3.5, 5.0), Color(0.85, 0.7, 0.35), Color(0.3, 0.3, 0.32))
	var pump := _at(-2.0, -10.0)
	var turn := _yaw(0.0)
	_piece(Vector3(0.8, 1.7, 0.6), pump, Vector3(0.0, 0.85, 0.0), turn, Color(0.8, 0.12, 0.1))
	_piece(Vector3(0.6, 0.3, 0.62), pump, Vector3(0.0, 1.5, 0.0), turn, Color(0.95, 0.95, 0.9), 1.5)
	_piece(Vector3(4.0, 0.3, 3.0), pump, Vector3(0.0, 4.2, 0.0), turn, Color(0.85, 0.85, 0.82))
	for side in [-1.6, 1.6]:
		_piece(Vector3(0.2, 4.2, 0.2), pump, Vector3(side, 2.1, 0.0), turn, Color(0.3, 0.3, 0.32))
	_lamp(_at(-4.0, 3.0))
	_sign(_at(-11.0, -3.0) + Vector3(0.0, 8.5, 0.0), loc.name.to_upper())


func _build_station(loc: Dictionary) -> void:
	_build_yard(loc)
	_frame(loc)
	# A narrow-gauge line behind the yard, and its little green engine. The line runs off the flat,
	# so each rail is laid in pieces over a sleeper each, tilted to the ground under them.
	for i in 15:
		for side in [-0.45, 0.45]:
			var a := _at(-19.0 + i * 2.0, -15.0 + side)
			var b := _at(-17.0 + i * 2.0, -15.0 + side)
			var rail := Psx.box(self, Vector3(a.distance_to(b), 0.12, 0.08), (a + b) * 0.5 + Vector3(0.0, 0.35, 0.0), Color(0.3, 0.3, 0.32))
			rail.rotation = Vector3(0.0, _yaw(0.0), atan2(b.y - a.y, 2.0))
		_piece(Vector3(0.25, 0.1, 1.4), _at(-18.0 + i * 2.0, -15.0), Vector3(0.0, 0.28, 0.0), _yaw(0.0), Color(0.3, 0.22, 0.15))
	var engine := _at(-8.0, -15.0)
	_solid(engine + Vector3(0.0, 0.4, 0.0), _yaw(0.0), Vector3(4.0, 1.4, 1.6), Color(0.15, 0.42, 0.25))
	_piece(Vector3(1.4, 1.2, 1.6), engine, Vector3(-1.3, 2.4, 0.0), _yaw(0.0), Color(0.15, 0.42, 0.25))
	_piece(Vector3(0.3, 0.8, 0.3), engine, Vector3(1.4, 2.2, 0.0), _yaw(0.0), Color(0.12, 0.12, 0.12))


func _build_elevator(loc: Dictionary) -> void:
	_frame(loc)
	for i in 4:
		_column(_at(-9.0, -6.0 + i * 4.2), 2.0, 15.0, Color(0.78, 0.76, 0.7))
		Psx.mesh(self, Psx.cylinder(0.3, 2.0, 1.2, 8), _at(-9.0, -6.0 + i * 4.2) + Vector3(0.0, 15.6, 0.0), Color(0.6, 0.6, 0.58))
	_solid(_at(-9.0, 11.0), _yaw(0.0), Vector3(4.0, 22.0, 4.0), Color(0.72, 0.7, 0.64))
	_piece(Vector3(1.0, 0.8, 9.0), _at(-9.0, 4.0), Vector3(0.0, 17.0, 0.0), _yaw(0.0), Color(0.5, 0.5, 0.52))
	_house(_at(2.0, 10.0), _yaw(PI), Vector3(6.0, 3.0, 4.0), Color(0.68, 0.62, 0.5), Color(0.4, 0.4, 0.42))
	_sign(_at(-9.0, 11.0) + Vector3(0.0, 25.0, 0.0), loc.name.to_upper())


func _build_sheepfold(loc: Dictionary) -> void:
	_frame(loc)
	_house(_at(-8.0, 0.0), _yaw(PI * 0.5), Vector3(16.0, 3.0, 6.0), Color(0.66, 0.6, 0.5), Color(0.45, 0.38, 0.3), false)
	# The pen and its flock beside the house, back from the yard where the roads leave it; the rails
	# run from post to post as the ground rises and falls.
	for z in [-9.0, -15.0]:
		for i in 7:
			_piece(Vector3(0.15, 1.1, 0.15), _at(-10.6 + i * 1.6, z), Vector3(0.0, 0.55, 0.0), _yaw(0.0), Color(0.4, 0.3, 0.2))
			if i > 0:
				var a := _at(-12.2 + i * 1.6, z)
				var b := _at(-10.6 + i * 1.6, z)
				var rail := Psx.box(self, Vector3(a.distance_to(b), 0.1, 0.1), (a + b) * 0.5 + Vector3(0.0, 0.9, 0.0), Color(0.4, 0.3, 0.2))
				rail.rotation = Vector3(0.0, _yaw(0.0), atan2(b.y - a.y, 1.6))
	for i in 9:
		var p := _at(-9.6 + (i % 3) * 3.1 + _rng.randf() * 0.8, -10.4 - (i / 3) * 1.6)
		var yaw := _rng.randf() * TAU
		_piece(Vector3(0.9, 0.55, 0.5), p, Vector3(0.0, 0.7, 0.0), yaw, Color(0.9, 0.88, 0.82))
		_piece(Vector3(0.3, 0.3, 0.3), p, Vector3(0.55, 0.9, 0.0), yaw, Color(0.2, 0.18, 0.16))
	_sign(_at(-8.0, 0.0) + Vector3(0.0, 6.5, 0.0), loc.name.to_upper())


func _build_wind_farm(loc: Dictionary) -> void:
	_frame(loc)
	for t in [Vector2(-10.0, -7.0), Vector2(-6.0, 11.0), Vector2(-18.0, 4.0)]:
		var base := _at(t.x, t.y)
		_column(base, 0.45, 22.0, Color(0.92, 0.92, 0.9), 0.3)
		var head := Node3D.new()
		head.position = base + Vector3(0.0, 22.0, 0.0)
		head.rotation.y = _yaw(PI * 0.5)
		add_child(head)
		Psx.box(head, Vector3(0.9, 0.9, 2.2), Vector3(0.0, 0.0, -0.3), Color(0.9, 0.9, 0.88))
		var hub := Spinner.new()
		hub.speed = 0.8 + _rng.randf() * 0.4
		hub.position = Vector3(0.0, 0.0, 0.9)
		head.add_child(hub)
		for k in 3:
			var blade := Psx.box(hub, Vector3(0.35, 8.0, 0.12), Vector3(0.0, 4.0, 0.0).rotated(Vector3.FORWARD, k * TAU / 3.0), Color(0.95, 0.95, 0.93))
			blade.rotation.z = -k * TAU / 3.0
	_house(_at(-4.0, -1.0), _yaw(PI * 0.5), Vector3(4.0, 2.6, 3.5), Color(0.8, 0.82, 0.84), Color(0.3, 0.32, 0.36))
	_sign(_at(-10.0, -7.0) + Vector3(0.0, 26.0, 0.0), loc.name.to_upper())


func _build_winery(loc: Dictionary) -> void:
	_frame(loc)
	# The hall stands back between the two roads either side of it, its barrels along its side.
	_house(_at(-11.8, 0.0), _yaw(PI * 0.5), Vector3(10.0, 5.5, 7.0), Color(0.9, 0.84, 0.68), Color(0.7, 0.3, 0.18))
	for i in 5:
		var b := Psx.mesh(self, Psx.cylinder(0.55, 0.55, 1.2, 8), _at(-9.6 - i * 1.3, 5.85) + Vector3(0.0, 0.85, 0.0), Color(0.46, 0.3, 0.16))
		b.rotation = Vector3(PI * 0.5, _yaw(PI * 0.5), 0.0)
	# Vine rows on the slope around it, clear of the yard and the hall.
	for row in 8:
		for k in 7:
			var x := -24.0 + k * 3.0
			var z := -26.0 + row * 3.2
			if Vector2(x, z).length() < float(loc.radius) + 4.0 or (x > -17.0 and absf(z) < 5.6):
				continue
			var p := _at(x, z)
			if terrain.road_distance(Vector2(p.x, p.z)) < Terrain.ROAD_HALF_WIDTH + 2.0:
				continue
			# A row runs from end to end tilted to the slope, its post at one end.
			var a := _at(x - 1.3, z)
			var b := _at(x + 1.3, z)
			var vine := Psx.box(self, Vector3(a.distance_to(b), 0.9, 0.5), (a + b) * 0.5 + Vector3(0.0, 0.75, 0.0), Color(0.24, 0.42, 0.14))
			vine.rotation = Vector3(0.0, _yaw(0.0), atan2(b.y - a.y, 2.6))
			_piece(Vector3(0.1, 1.4, 0.1), b, Vector3(0.0, 0.7, 0.0), _yaw(0.0), Color(0.36, 0.28, 0.18))
	_sign(_at(-11.8, 0.0) + Vector3(0.0, 9.5, 0.0), loc.name.to_upper())


func _build_castle(loc: Dictionary) -> void:
	_frame(loc)
	var stone := Color(0.58, 0.55, 0.5)
	var dark := Color(0.44, 0.42, 0.38)
	for z in [-8.0, 8.0]:
		_column(_at(-11.0, z), 2.0, 11.0, stone)
		_roof(_at(-11.0, z) + Vector3(0.0, 12.5, 0.0), _yaw(0.0), Vector3(4.6, 3.0, 4.6), Color(0.5, 0.22, 0.16))
	_solid(_at(-11.0, 0.0), _yaw(0.0), Vector3(2.0, 7.0, 14.0), stone)
	for z in [-8.0, 8.0]:
		_solid(_at(-5.0, z * 1.3), _yaw(0.0), Vector3(10.0, 6.0, 1.6), dark)
	_solid(_at(-16.0, 0.0), _yaw(0.0), Vector3(6.0, 15.0, 6.0), stone)
	_roof(_at(-16.0, 0.0) + Vector3(0.0, 17.0, 0.0), _yaw(0.0), Vector3(6.8, 4.0, 6.8), Color(0.5, 0.22, 0.16))
	_piece(Vector3(0.1, 3.0, 0.1), _at(-16.0, 0.0), Vector3(0.0, 20.5, 0.0), _yaw(0.0), Color(0.3, 0.3, 0.3))
	_piece(Vector3(0.1, 0.9, 1.4), _at(-16.0, 0.0), Vector3(0.0, 21.4, 0.7), _yaw(0.0), Color(0.95, 0.8, 0.15), 1.0)
	_lamp(_at(-4.0, 5.0))
	_sign(_at(-16.0, 0.0) + Vector3(0.0, 24.0, 0.0), loc.name.to_upper())


func _build_wooden_church(loc: Dictionary) -> void:
	_frame(loc)
	var wood := Color(0.34, 0.22, 0.13)
	var c := _at(-10.0, 0.0)
	_solid(c, _yaw(0.0), Vector3(6.0, 5.0, 6.0), wood)
	for tier in 3:
		var w := 5.0 - tier * 1.5
		_roof(c + Vector3(0.0, 6.0 + tier * 2.6, 0.0), _yaw(0.0), Vector3(w + 1.4, 1.6, w + 1.4), Color(0.22, 0.15, 0.1))
		_piece(Vector3(w, 1.2, w), c, Vector3(0.0, 5.6 + tier * 2.6, 0.0), _yaw(0.0), wood)
	_piece(Vector3(0.1, 1.6, 0.1), c, Vector3(0.0, 14.4, 0.0), _yaw(0.0), Color(0.85, 0.75, 0.3), 0.6)
	_piece(Vector3(0.8, 0.1, 0.1), c, Vector3(0.0, 14.7, 0.0), _yaw(0.0), Color(0.85, 0.75, 0.3), 0.6)
	_house(_at(1.0, 10.0), _yaw(PI), Vector3(5.0, 3.0, 4.0), Color(0.86, 0.84, 0.76), Color(0.4, 0.3, 0.22))
	_house(_at(-4.0, -11.0), _yaw(0.0), Vector3(5.0, 3.0, 4.0), Color(0.82, 0.8, 0.72), Color(0.3, 0.3, 0.32))
	_sign(c + Vector3(0.0, 17.0, 0.0), loc.name.to_upper())


func _build_fish_farm(loc: Dictionary) -> void:
	_frame(loc)
	_house(_at(-8.0, 6.0), _yaw(PI * 0.5), Vector3(8.0, 3.2, 5.0), Color(0.5, 0.6, 0.64), Color(0.3, 0.32, 0.34))
	for i in 2:
		_piece(Vector3(5.0, 0.05, 3.5), _at(-8.0, -6.0 - i * 4.5), Vector3(0.0, 0.32, 0.0), _yaw(0.0), Color(0.24, 0.32, 0.36))
	for i in 3:  # boats by the ponds, back from the road that leaves past them
		var p := _at(-4.2 + i * 2.2, -11.0)
		_piece(Vector3(1.2, 0.5, 3.4), p, Vector3(0.0, 0.5, 0.0), _yaw(0.3 * i), Color(0.5, 0.36, 0.22))
	for i in 5:  # a net fence, post to post as the ground rises off the shore
		_piece(Vector3(0.12, 2.0, 0.12), _at(-14.0, -12.0 + i * 3.0), Vector3(0.0, 1.0, 0.0), _yaw(0.0), Color(0.36, 0.3, 0.22))
		if i > 0:
			var a := _at(-14.0, -15.0 + i * 3.0)
			var b := _at(-14.0, -12.0 + i * 3.0)
			var net := Psx.box(self, Vector3(0.04, 1.2, a.distance_to(b)), (a + b) * 0.5 + Vector3(0.0, 1.4, 0.0), Color(0.6, 0.6, 0.55))
			net.rotation = Vector3(-atan2(b.y - a.y, 3.0), _yaw(0.0), 0.0)
	_sign(_at(-8.0, 6.0) + Vector3(0.0, 6.5, 0.0), loc.name.to_upper())


func _build_peat_works(loc: Dictionary) -> void:
	_frame(loc)
	_house(_at(-9.0, 7.0), _yaw(PI * 0.5), Vector3(9.0, 3.5, 6.0), Color(0.46, 0.44, 0.4), Color(0.35, 0.28, 0.24), false)
	_house(_at(-8.0, -8.0), _yaw(PI * 0.5), Vector3(5.0, 3.0, 4.0), Color(0.62, 0.6, 0.5), Color(0.3, 0.3, 0.32))
	for row in 3:
		for i in 4:
			_piece(Vector3(1.6, 0.9 - row * 0.25, 1.0), _at(-16.0 + i * 2.0, -2.0 + row * 1.2), Vector3(0.0, 0.6, 0.0), _yaw(0.0), Color(0.22, 0.15, 0.1))
	# An excavator, parked.
	var ex := _at(-2.0, 11.0)
	_solid(ex, _yaw(0.4), Vector3(3.0, 1.0, 2.6), Color(0.15, 0.15, 0.15))
	_piece(Vector3(2.4, 1.6, 2.2), ex, Vector3(0.0, 1.8, 0.0), _yaw(0.4), Color(0.92, 0.7, 0.12))
	var arm := _piece(Vector3(0.5, 0.5, 4.5), ex, Vector3(0.0, 2.6, 2.4), _yaw(0.4), Color(0.92, 0.7, 0.12))
	arm.rotation.x = -0.5
	_sign(_at(-9.0, 7.0) + Vector3(0.0, 7.0, 0.0), loc.name.to_upper())


func _build_village_church(loc: Dictionary) -> void:
	_frame(loc)
	var c := _at(-11.0, 0.0)
	_solid(c, _yaw(0.0), Vector3(7.0, 6.0, 7.0), Color(0.95, 0.94, 0.9))
	_piece(Vector3(3.0, 3.0, 3.0), c, Vector3(0.0, 7.5, 0.0), _yaw(0.0), Color(0.95, 0.94, 0.9))
	var dome := SphereMesh.new()
	dome.radius = 1.8
	dome.height = 3.0
	dome.radial_segments = 8
	dome.rings = 4
	Psx.mesh(self, dome, c + Vector3(0.0, 9.6, 0.0), Color(0.22, 0.4, 0.68))
	_piece(Vector3(0.1, 1.6, 0.1), c, Vector3(0.0, 11.6, 0.0), _yaw(0.0), Color(0.95, 0.8, 0.3), 0.8)
	_piece(Vector3(0.8, 0.1, 0.1), c, Vector3(0.0, 11.9, 0.0), _yaw(0.0), Color(0.95, 0.8, 0.3), 0.8)
	_house(_at(0.0, 11.0), _yaw(PI), Vector3(6.0, 3.0, 4.5), Color(0.88, 0.84, 0.7), Color(0.5, 0.24, 0.16))
	_house(_at(-2.0, -12.0), _yaw(0.0), Vector3(5.5, 3.0, 4.5), Color(0.8, 0.86, 0.88), Color(0.3, 0.3, 0.34))
	_house(_at(8.0, -12.0), _yaw(0.0), Vector3(5.0, 2.8, 4.0), Color(0.9, 0.88, 0.8), Color(0.42, 0.3, 0.22), false)
	_sign(c + Vector3(0.0, 14.0, 0.0), loc.name.to_upper())


func _build_forestry(loc: Dictionary) -> void:
	_frame(loc)
	_house(_at(-8.0, 5.0), _yaw(PI * 0.5), Vector3(8.0, 3.4, 6.0), Color(0.48, 0.32, 0.18), Color(0.26, 0.34, 0.22))
	# A fire lookout over the pines.
	var t := _at(-9.0, -8.0)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_column(t + Vector3(corner.x * 1.2, 0.0, corner.y * 1.2), 0.12, 12.0, Color(0.4, 0.28, 0.18))
	_piece(Vector3(3.0, 2.0, 3.0), t, Vector3(0.0, 13.0, 0.0), _yaw(0.0), Color(0.48, 0.32, 0.18))
	_roof(t + Vector3(0.0, 14.6, 0.0), _yaw(0.0), Vector3(3.6, 1.2, 3.6), Color(0.26, 0.34, 0.22))
	var logs := Psx.cylinder(0.3, 0.3, 5.0, 7)
	for row in 2:
		for i in 3 - row:
			var m := Psx.mesh(self, logs, _at(-1.0, 10.0) + Vector3(0.0, 0.3 + row * 0.55, 0.0) + Basis(Vector3.UP, _yaw(0.0)) * Vector3(0.0, 0.0, -0.6 + i * 0.62 + row * 0.31), Color(0.55, 0.4, 0.25))
			m.rotation = Vector3(0.0, _yaw(0.0), PI * 0.5)
	_sign(_at(-8.0, 5.0) + Vector3(0.0, 6.5, 0.0), loc.name.to_upper())


func _build_apiary(loc: Dictionary) -> void:
	_frame(loc)
	_house(_at(-7.0, 0.0), _yaw(PI * 0.5), Vector3(4.5, 2.6, 3.5), Color(0.86, 0.8, 0.6), Color(0.4, 0.3, 0.22))
	var colours := [Color(0.95, 0.85, 0.3), Color(0.35, 0.55, 0.8), Color(0.92, 0.92, 0.88), Color(0.5, 0.7, 0.4)]
	for i in 10:
		var p := _at(-12.0 + (i % 5) * 2.4, (-8.0 if i < 5 else 8.0))
		_piece(Vector3(0.9, 0.5, 0.8), p, Vector3(0.0, 0.6, 0.0), _yaw(0.0), Color(0.35, 0.25, 0.15))
		_piece(Vector3(0.8, 0.7, 0.7), p, Vector3(0.0, 1.15, 0.0), _yaw(0.0), colours[i % colours.size()])
		_piece(Vector3(0.95, 0.12, 0.85), p, Vector3(0.0, 1.55, 0.0), _yaw(0.0), Color(0.4, 0.4, 0.42))
	_sign(_at(-7.0, 0.0) + Vector3(0.0, 5.5, 0.0), loc.name.to_upper())


func _build_koliba(loc: Dictionary) -> void:
	_frame(loc)
	var c := _at(-9.0, 0.0)
	_solid(c, _yaw(0.0), Vector3(6.0, 2.2, 7.0), Color(0.4, 0.27, 0.15))
	_roof(c + Vector3(0.0, 4.2, 0.0), _yaw(PI * 0.5), Vector3(8.4, 4.0, 7.4), Color(0.86, 0.9, 0.98))
	_piece(Vector3(0.6, 1.6, 0.6), c, Vector3(1.5, 5.6, 1.5), _yaw(0.0), Color(0.35, 0.32, 0.3))
	_piece(Vector3(1.2, 0.9, 0.1), c, Vector3(3.05, 1.3, 0.0), _yaw(PI * 0.5), WARM_LIGHT, 1.5)
	var l := OmniLight3D.new()
	l.position = c + Vector3(0.0, 1.4, 0.0) + Basis(Vector3.UP, _yaw(0.0)) * Vector3(4.5, 0.0, 0.0)
	l.light_color = WARM_LIGHT
	l.light_energy = 1.4
	l.omni_range = 9.0
	add_child(l)
	for i in 6:
		_piece(Vector3(0.15, 1.1, 0.15), _at(-4.0 + i * 1.6, 9.0), Vector3(0.0, 0.55, 0.0), _yaw(0.0), Color(0.36, 0.26, 0.16))
	_piece(Vector3(8.0, 0.1, 0.1), _at(0.0, 9.0), Vector3(0.0, 0.9, 0.0), _yaw(0.0), Color(0.36, 0.26, 0.16))
	_sign(c + Vector3(0.0, 8.5, 0.0), loc.name.to_upper())


func _build_weather_station(loc: Dictionary) -> void:
	_frame(loc)
	_house(_at(-7.0, 2.0), _yaw(PI * 0.5), Vector3(5.0, 3.0, 4.0), Color(0.9, 0.9, 0.88), Color(0.3, 0.32, 0.36))
	var mast := _at(-9.0, -6.0)
	_column(mast, 0.15, 14.0, Color(0.7, 0.7, 0.72))
	var cups := Spinner.new()
	cups.speed = 6.0
	cups.position = mast + Vector3(0.0, 14.3, 0.0)
	cups.rotation.x = PI * 0.5
	add_child(cups)
	for k in 3:
		Psx.box(cups, Vector3(0.9, 0.08, 0.08), Vector3(0.45, 0.0, 0.0).rotated(Vector3.FORWARD, k * TAU / 3.0), Color(0.2, 0.2, 0.2))
	_piece(Vector3(1.2, 1.0, 0.9), _at(-3.0, -7.0), Vector3(0.0, 1.6, 0.0), _yaw(0.0), Color(0.96, 0.96, 0.95))
	for corner in [Vector2(-0.45, -0.35), Vector2(0.45, -0.35), Vector2(-0.45, 0.35), Vector2(0.45, 0.35)]:
		_piece(Vector3(0.06, 1.1, 0.06), _at(-3.0, -7.0), Vector3(corner.x, 0.55, corner.y), _yaw(0.0), Color(0.9, 0.9, 0.9))
	var dome := SphereMesh.new()
	dome.radius = 1.6
	dome.height = 3.2
	dome.radial_segments = 8
	dome.rings = 4
	Psx.mesh(self, dome, _at(-7.0, 2.0) + Vector3(0.0, 5.4, 0.0), Color(0.94, 0.94, 0.94))
	Psx.box(self, Vector3(0.3, 0.3, 0.3), mast + Vector3(0.0, 14.9, 0.0), Color(1.0, 0.1, 0.05), 3.0)
	_sign(_at(-7.0, 2.0) + Vector3(0.0, 9.0, 0.0), loc.name.to_upper())


func _build_rescue_base(loc: Dictionary) -> void:
	_frame(loc)
	_house(_at(-8.0, 6.0), _yaw(PI * 0.5), Vector3(9.0, 4.0, 6.0), Color(0.78, 0.16, 0.12), Color(0.86, 0.9, 0.98))
	_piece(Vector3(0.1, 2.6, 3.0), _at(-8.0, 6.0), Vector3(3.05, 1.3, 0.0), _yaw(PI * 0.5), Color(0.85, 0.85, 0.82))
	var pad := _at(8.5, 3.0)  # on the flat across the yard from the house, off the road through it
	Psx.mesh(self, Psx.cylinder(3.5, 3.5, 0.12, 12), pad + Vector3(0.0, 0.36, 0.0), Color(0.24, 0.24, 0.26))
	_piece(Vector3(0.4, 0.05, 2.4), pad, Vector3(-0.7, 0.44, 0.0), _yaw(0.0), Color(0.95, 0.95, 0.95), 0.8)
	_piece(Vector3(0.4, 0.05, 2.4), pad, Vector3(0.7, 0.44, 0.0), _yaw(0.0), Color(0.95, 0.95, 0.95), 0.8)
	_piece(Vector3(1.0, 0.05, 0.4), pad, Vector3(0.0, 0.44, 0.0), _yaw(0.0), Color(0.95, 0.95, 0.95), 0.8)
	_column(_at(-14.0, -2.0), 0.08, 8.0, Color(0.7, 0.7, 0.72))
	_piece(Vector3(0.05, 1.0, 1.6), _at(-14.0, -2.0), Vector3(0.0, 7.4, 0.8), _yaw(0.0), Color(0.85, 0.12, 0.1), 0.4)
	_lamp(_at(-5.0, -1.0))  # by the house, off the road through the yard
	_sign(_at(-8.0, 6.0) + Vector3(0.0, 8.0, 0.0), loc.name.to_upper())


func _sea(sea: Dictionary) -> void:
	var water := PlaneMesh.new()
	water.size = Vector2(400.0, 160.0)
	var m := Psx.mesh(self, water, Vector3.ZERO, Color(0.16, 0.34, 0.48))
	var side: String = sea.side
	var far := float(sea.coast) + 75.0
	match side:
		"south":
			m.position = Vector3(0.0, sea.level, far)
		"north":
			m.position = Vector3(0.0, sea.level, -far)
		"east":
			m.position = Vector3(far, sea.level, 0.0)
			m.rotation.y = PI * 0.5
		"west":
			m.position = Vector3(-far, sea.level, 0.0)
			m.rotation.y = PI * 0.5


func _build_kurgan_dig(loc: Dictionary) -> void:
	_frame(loc)
	# The mound behind the dig, a trench cut into its face, strings over the squares.
	var mound := _at(-15.0, 0.0)
	var body := StaticBody3D.new()
	body.position = mound
	add_child(body)
	var shape := CylinderShape3D.new()
	shape.radius = 6.0
	shape.height = 2.4
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, 1.0, 0.0)
	body.add_child(cs)
	var earth := SphereMesh.new()
	earth.radius = 7.0
	earth.height = 4.4
	earth.radial_segments = 10
	earth.rings = 4
	Psx.mesh(body, earth, Vector3(0.0, 0.2, 0.0), Color(0.5, 0.42, 0.26))
	_piece(Vector3(4.0, 0.9, 1.6), mound, Vector3(5.2, 0.8, 0.0), _yaw(0.0), Color(0.34, 0.26, 0.16))
	for i in 4:
		_piece(Vector3(0.04, 0.04, 6.0), mound, Vector3(1.5 + i * 1.3, 1.9, 0.0), _yaw(0.0), Color(0.95, 0.95, 0.9))
	for t in [Vector2(-4.0, 9.0), Vector2(2.0, 10.5)]:
		_roof(_at(t.x, t.y) + Vector3(0.0, 1.0, 0.0), _yaw(0.3), Vector3(2.6, 2.0, 3.2), Color(0.56, 0.54, 0.34))
	var table := _at(-5.0, -8.0)
	_piece(Vector3(2.4, 0.08, 1.0), table, Vector3(0.0, 1.0, 0.0), _yaw(0.0), Color(0.5, 0.36, 0.22))
	for k in [-0.8, 0.0, 0.8]:
		_piece(Vector3(0.6, 0.12, 0.6), table, Vector3(k, 1.1, 0.0), _yaw(0.0), Color(0.6, 0.6, 0.58))
	_column(_at(-8.0, 7.0), 0.06, 4.0, Color(0.7, 0.7, 0.72))
	_piece(Vector3(0.05, 0.8, 1.3), _at(-8.0, 7.0), Vector3(0.0, 3.5, 0.65), _yaw(0.0), Color(0.2, 0.4, 0.85), 0.4)
	_sign(mound + Vector3(0.0, 6.0, 0.0), loc.name.to_upper())


## A mineral spring's pump room: a round pavilion of columns under a copper dome.
func _build_pump_room(loc: Dictionary) -> void:
	_frame(loc)
	var c := _at(-10.0, 0.0)
	Psx.mesh(self, Psx.cylinder(3.4, 3.4, 0.4, 12), c + Vector3(0.0, 0.5, 0.0), Color(0.82, 0.8, 0.74))
	for k in 6:
		var a := k * TAU / 6.0
		_column(c + Vector3(cos(a) * 2.8, 0.3, sin(a) * 2.8), 0.22, 3.4, Color(0.95, 0.94, 0.9))
	Psx.mesh(self, Psx.cylinder(3.3, 3.3, 0.4, 12), c + Vector3(0.0, 3.9, 0.0), Color(0.9, 0.88, 0.82))
	var dome := SphereMesh.new()
	dome.radius = 3.0
	dome.height = 3.0
	dome.radial_segments = 10
	dome.rings = 4
	Psx.mesh(self, dome, c + Vector3(0.0, 4.4, 0.0), Color(0.36, 0.62, 0.54))
	_column(c + Vector3(0.0, 0.3, 0.0), 0.7, 1.0, Color(0.6, 0.6, 0.6))
	Psx.mesh(self, Psx.cylinder(0.6, 0.6, 0.08, 10), c + Vector3(0.0, 1.32, 0.0), Color(0.55, 0.8, 0.92), 0.6)
	for side in [-1.0, 1.0]:
		_piece(Vector3(2.0, 0.45, 0.5), _at(-3.0, 6.0 * side), Vector3(0.0, 0.55, 0.0), _yaw(0.0), Color(0.42, 0.28, 0.16))
	_lamp(_at(-4.0, -3.0))
	_sign(c + Vector3(0.0, 7.5, 0.0), loc.name.to_upper())


## Every tree and rock within radius of p (its own metres) goes (docs/plan.md §4): its meshes
## shrink to nothing, its collision goes. The points of those that went.
func clear_near(p: Vector2, radius: float) -> PackedVector2Array:
	var gone := PackedVector2Array()
	for pr in props:
		if pr.shape != null and (pr.p as Vector2).distance_to(p) < radius:
			(pr.shape as CollisionShape3D).queue_free()
			pr.shape = null
			gone.append(pr.p)
	if gone.is_empty():
		return gone
	for c in get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null:
			continue
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			for q in gone:
				if absf(o.x - q.x) < 0.01 and absf(o.z - q.y) < 0.01:
					mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), o))
	return gone
