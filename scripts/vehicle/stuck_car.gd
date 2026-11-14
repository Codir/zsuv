class_name StuckCar
extends RigidBody3D
## A car slid into a ditch, its hazard lights blinking, waiting for a winch: a boxy little sedan
## of 1100 kg that slides when pulled, heavy low down so a pull up the bank does not roll it. Its
## towing eye is at the front.

const HOOK := Vector3(0.0, 0.45, -2.1)
const COLOURS := [Color(0.82, 0.76, 0.6), Color(0.55, 0.12, 0.1), Color(0.4, 0.46, 0.52), Color(0.25, 0.4, 0.3)]

var _hazards: Array[MeshInstance3D] = []
var _t := 0.0


func _init(colour := 0) -> void:
	mass = 1100.0
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.3, 0.0)
	angular_damp = 1.0
	can_sleep = false
	var m := PhysicsMaterial.new()
	m.friction = 0.45
	physics_material_override = m
	var body_colour: Color = COLOURS[colour % COLOURS.size()]
	_box_shape(Vector3(1.7, 0.8, 4.0), Vector3(0.0, 0.55, 0.0))
	_box_shape(Vector3(1.5, 0.55, 2.0), Vector3(0.0, 1.2, 0.2))
	Psx.box(self, Vector3(1.7, 0.7, 4.0), Vector3(0.0, 0.6, 0.0), body_colour)
	Psx.box(self, Vector3(1.5, 0.55, 2.0), Vector3(0.0, 1.22, 0.2), body_colour)
	Psx.box(self, Vector3(1.52, 0.4, 1.7), Vector3(0.0, 1.24, 0.2), Color(0.13, 0.17, 0.24))
	for side in [-1.0, 1.0]:
		for z in [-1.3, 1.3]:
			var wheel := Psx.mesh(self, Psx.cylinder(0.32, 0.32, 0.22, 8), Vector3(0.82 * side, 0.3, z), Color(0.12, 0.12, 0.13))
			wheel.rotation.z = PI * 0.5
		Psx.box(self, Vector3(0.3, 0.15, 0.05), Vector3(0.55 * side, 0.7, -2.02), Color(1.0, 0.95, 0.75), 1.5)
		_hazards.append(Psx.box(self, Vector3(0.25, 0.12, 0.05), Vector3(0.6 * side, 0.7, 2.02), Color(1.0, 0.55, 0.1), 2.5))
	Psx.box(self, Vector3(0.12, 0.12, 0.2), HOOK, Color(0.3, 0.3, 0.32))


## In ditch d (a valley's, by road d.pos), nose up towards the road and a little along it, so a
## pull from the road brings it up the bank head first.
func slide_into(d: Dictionary, land: Land) -> void:
	var at: Vector2 = d.at
	var out: Vector2 = ((d.pos as Vector2) - at).normalized()
	var nose: Vector2 = (out * 0.9 + (d.dir as Vector2) * 0.35).normalized()
	global_transform = Transform3D(Basis(Vector3.UP, atan2(-nose.x, -nose.y)) * Basis(Vector3.FORWARD, 0.25),
		Vector3(at.x, land.get_height(at.x, at.y) + 0.7, at.y))


func hook_point() -> Vector3:
	return global_transform * HOOK


## Back on the road: out of the ditch, up by the road's edge at the road's level (a truck in the
## middle of the road reels it in that far), at rest. On its roof counts too.
func on_road(land: Land) -> bool:
	var p := Vector2(global_position.x, global_position.z)
	return land.road_distance(p) < Terrain.ROAD_HALF_WIDTH + 2.5 \
		and land.get_height(p.x, p.y) > land.road_height(p) - 0.6 and linear_velocity.length() < 1.5


func upright() -> bool:
	return global_transform.basis.y.y > 0.7


## Drives off after the given seconds (gone with the valley if that goes first).
func drive_off(after: float) -> void:
	create_tween().tween_callback(queue_free).set_delay(after)


func _process(delta: float) -> void:
	_t += delta
	for h in _hazards:
		h.visible = fmod(_t, 1.0) < 0.5


func _box_shape(size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)
