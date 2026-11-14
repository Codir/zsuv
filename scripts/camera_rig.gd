class_name CameraRig
extends Node3D
## Chase camera. RMB + mouse orbits, the wheel sets the distance.

var target: Vehicle
var land: Land
var camera: Camera3D
var yaw := 0.0
var pitch := -0.35
var distance := 10.0

var _orbiting := false
var _orbit_cooldown := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.near = 0.1
	camera.far = 200.0
	camera.current = true
	add_child(camera)
	camera.top_level = true


## Straight behind the truck, as far back as its size asks (a new truck, or the first).
func snap_to_target() -> void:
	distance = target.spec.camera_distance
	global_position = target.global_position + Vector3(0.0, target.spec.camera_height, 0.0)
	yaw = target.global_rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(4.0, distance - 1.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(25.0, distance + 1.0)
	elif event is InputEventMouseMotion and _orbiting:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.006
		pitch = clampf(pitch - mm.relative.y * 0.006, -1.3, 0.15)
		_orbit_cooldown = 2.5


func _process(delta: float) -> void:
	if target == null:
		return
	var tpos := target.global_position + Vector3(0.0, target.spec.camera_height, 0.0)
	global_position = global_position.lerp(tpos, 1.0 - exp(-delta * 8.0))
	_orbit_cooldown -= delta
	if not _orbiting and _orbit_cooldown <= 0.0 and target.forward_speed > 1.5:
		yaw = lerp_angle(yaw, target.global_rotation.y, 1.0 - exp(-delta * 1.5))
	# A trailer behind the truck: back by half its length again, so the rig is in view.
	var back := distance + (absf(target.trailer.spec.coupler.z) if target.trailer else 0.0)
	var cam_pos := global_position + Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3(0.0, 0.0, back)
	if land:
		cam_pos.y = maxf(cam_pos.y, land.get_height(cam_pos.x, cam_pos.z) + 1.2)
	# A hill or a tree between the truck and the camera: pull the camera in (not for its trailer).
	var q := PhysicsRayQueryParameters3D.create(global_position, cam_pos)
	q.exclude = [target.get_rid(), target.trailer.get_rid()] if target.trailer else [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		cam_pos = hit.position + (global_position - cam_pos).normalized() * 0.4
	camera.global_position = cam_pos
	camera.look_at(global_position, Vector3.UP)
