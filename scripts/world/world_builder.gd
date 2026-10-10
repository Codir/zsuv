class_name WorldBuilder
extends Node3D
## Розставляє дерева, камені, будівлі й снігові віхи вздовж доріг.

const TRUNK := Color(0.28, 0.18, 0.12)
const PINE := Color(0.12, 0.24, 0.18)
const PINE_LIGHT := Color(0.16, 0.3, 0.22)
const SNOW := Color(0.88, 0.92, 1.0)
const WARM_LIGHT := Color(1.0, 0.78, 0.45)

var terrain: Terrain
var tree_points := PackedVector2Array()
var anchor_points := PackedVector3Array()  # опори для лебідки
var _rng := RandomNumberGenerator.new()


func build(t: Terrain, locations: Dictionary) -> void:
	terrain = t
	_rng.seed = 4242
	_scatter_trees(locations)
	_scatter_rocks(locations)
	_road_poles()
	_build_depot(locations.depot)
	_build_farm(locations.farm)
	_build_lumber(locations.lumber)
	_build_tower(locations.tower)
	_boundary_walls()


func _is_clear(p: Vector2, locations: Dictionary, margin: float) -> bool:
	if terrain.road_distance(p) < Terrain.ROAD_HALF_WIDTH + margin:
		return false
	for l in locations.values():
		if p.distance_to(l.pos) < float(l.radius) + margin + 4.0:
			return false
	return true


func _scatter_trees(locations: Dictionary) -> void:
	var xforms: Array[Transform3D] = []
	var body := StaticBody3D.new()
	add_child(body)
	var attempts := 0
	while xforms.size() < 500 and attempts < 5000:
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
		body.add_child(cs)
	_multimesh(Psx.cylinder(0.2, 0.28, 2.4, 5), Psx.mat(TRUNK), xforms, Vector3(0.0, 1.2, 0.0))
	_multimesh(Psx.cylinder(0.0, 1.9, 3.6, 6), Psx.mat(PINE), xforms, Vector3(0.0, 3.2, 0.0))
	_multimesh(Psx.cylinder(0.0, 1.4, 2.8, 6), Psx.mat(PINE_LIGHT), xforms, Vector3(0.0, 4.9, 0.0))
	_multimesh(Psx.cylinder(0.0, 0.7, 1.4, 6), Psx.mat(SNOW), xforms, Vector3(0.0, 6.0, 0.0))


func _scatter_rocks(locations: Dictionary) -> void:
	var xforms: Array[Transform3D] = []
	var body := StaticBody3D.new()
	add_child(body)
	var attempts := 0
	while xforms.size() < 60 and attempts < 1000:
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
		body.add_child(cs)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 3
	_multimesh(sphere, Psx.mat(Color(0.38, 0.38, 0.4)), xforms, Vector3.ZERO)


## Помаранчеві снігові віхи вздовж доріг - орієнтир у хуртовину.
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


func _house(pos: Vector3, yaw: float, size: Vector3, wall: Color, roof: Color, lit := true) -> StaticBody3D:
	var root := StaticBody3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	root.add_child(cs)
	Psx.box(root, size, Vector3(0.0, size.y * 0.5, 0.0), wall)
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x + 0.6, size.y * 0.5, size.z + 0.6)
	Psx.mesh(root, prism, Vector3(0.0, size.y * 1.25, 0.0), roof)
	var front := size.z * 0.5 + 0.05
	Psx.box(root, Vector3(1.1, 2.0, 0.1), Vector3(-size.x * 0.25, 1.0, front), Color(0.25, 0.16, 0.1))
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


func _build_depot(loc: Dictionary) -> void:
	var c: Vector2 = loc.pos
	_house(_ground(c.x - 7.0, c.y - 8.0), 0.0, Vector3(10.0, 5.0, 7.0), Color(0.35, 0.42, 0.52), Color(0.6, 0.18, 0.12), false)
	_house(_ground(c.x + 6.0, c.y - 9.0), 0.0, Vector3(5.0, 3.5, 5.0), Color(0.85, 0.7, 0.35), Color(0.3, 0.3, 0.32))
	var pump := _ground(c.x - 2.0, c.y + 7.0)
	Psx.box(self, Vector3(0.8, 1.7, 0.6), pump + Vector3(0.0, 0.85, 0.0), Color(0.8, 0.12, 0.1))
	Psx.box(self, Vector3(0.6, 0.3, 0.62), pump + Vector3(0.0, 1.5, 0.0), Color(0.95, 0.95, 0.9), 1.5)
	Psx.box(self, Vector3(6.0, 0.3, 4.0), pump + Vector3(0.0, 4.2, 0.0), Color(0.85, 0.85, 0.82))
	for side in [-2.6, 2.6]:
		Psx.box(self, Vector3(0.2, 4.2, 0.2), pump + Vector3(side, 2.1, 0.0), Color(0.3, 0.3, 0.32))
	_lamp(_ground(c.x + 3.0, c.y + 2.0))
	_sign(_ground(c.x - 7.0, c.y - 8.0) + Vector3(0.0, 8.5, 0.0), "ДЕПО UAV RANNER")


func _build_farm(loc: Dictionary) -> void:
	var c: Vector2 = loc.pos
	_house(_ground(c.x - 4.0, c.y + 4.0), PI, Vector3(6.0, 3.5, 5.0), Color(0.45, 0.6, 0.7), Color(0.85, 0.88, 0.95))
	_house(_ground(c.x + 7.0, c.y + 3.0), PI, Vector3(7.0, 5.0, 9.0), Color(0.6, 0.15, 0.1), Color(0.85, 0.88, 0.95), false)
	_sign(_ground(c.x, c.y + 4.0) + Vector3(0.0, 7.5, 0.0), "ХУТІР")


func _build_lumber(loc: Dictionary) -> void:
	var c: Vector2 = loc.pos
	_house(_ground(c.x, c.y + 6.0), PI, Vector3(9.0, 4.0, 6.0), Color(0.42, 0.28, 0.16), Color(0.85, 0.88, 0.95))
	var logs := Psx.cylinder(0.35, 0.35, 6.0, 7)
	for row in 3:
		for i in 4 - row:
			var p := _ground(c.x + 7.0, c.y - 4.0) + Vector3(0.0, 0.35 + row * 0.62, -1.1 + i * 0.72 + row * 0.36)
			var m := Psx.mesh(self, logs, p, Color(0.5, 0.33, 0.2))
			m.rotation.z = PI * 0.5
	_sign(_ground(c.x, c.y + 6.0) + Vector3(0.0, 7.5, 0.0), "ЛІСОПИЛКА")


func _build_tower(loc: Dictionary) -> void:
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

	# Маленький дрон на майданчику - натяк на майбутні UAV-механіки.
	var pad := _ground(c.x - 3.0, c.y - 4.0) + Vector3(0.0, 0.4, 0.0)
	Psx.mesh(self, Psx.cylinder(1.6, 1.6, 0.1, 8), pad, Color(0.3, 0.3, 0.32))
	Psx.box(self, Vector3(0.5, 0.18, 0.5), pad + Vector3(0.0, 0.25, 0.0), Color(0.2, 0.22, 0.25))
	for a in 4:
		var dir := Vector3(cos(a * PI * 0.5 + PI * 0.25), 0.0, sin(a * PI * 0.5 + PI * 0.25))
		Psx.box(self, Vector3(0.06, 0.06, 0.06), pad + Vector3(0.0, 0.25, 0.0) + dir * 0.35, Color(0.2, 0.2, 0.2))
		Psx.mesh(self, Psx.cylinder(0.22, 0.22, 0.02, 8), pad + Vector3(0.0, 0.32, 0.0) + dir * 0.5, Color(0.3, 0.9, 0.4), 1.0)
	_sign(base + Vector3(0.0, 23.0, 0.0), "РАДІОВЕЖА")


func _boundary_walls() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	for i in 4:
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 200.0, 260.0) if i < 2 else Vector3(260.0, 200.0, 2.0)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var s := -1.0 if i % 2 == 0 else 1.0
		cs.position = Vector3(s * 127.0, 0.0, 0.0) if i < 2 else Vector3(0.0, 0.0, s * 127.0)
		body.add_child(cs)
