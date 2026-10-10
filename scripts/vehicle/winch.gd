class_name Winch
extends Node3D
## Лебідка: чіпляється до найближчого дерева/каменя попереду.
## Трос сам вибирає слабину (храповик), Shift - намотувати.

const RANGE := 16.0
const MAX_FORCE := 32000.0
const STIFFNESS := 60000.0
const DAMPING := 6000.0
const REEL_SPEED := 1.4
const MIN_LENGTH := 2.0
const MOUNT := Vector3(0.0, 0.25, -2.4)
const SEGMENTS := 10

var vehicle: Vehicle
var anchors := PackedVector3Array()
var attached := false
var anchor := Vector3.ZERO
var length := 0.0
var tension := 0.0
var reeling := false
var candidate := -1
var auto_reel := false  # для тестів

var _segments: Array[MeshInstance3D] = []
var _marker: MeshInstance3D


func _ready() -> void:
	for i in SEGMENTS:
		var seg := Psx.box(self, Vector3(0.05, 0.05, 1.0), Vector3.ZERO, Color(0.12, 0.12, 0.12))
		seg.top_level = true
		seg.visible = false
		_segments.append(seg)
	_marker = Psx.box(self, Vector3(0.35, 0.35, 0.35), Vector3.ZERO, Color(1.0, 0.85, 0.2), 2.5)
	_marker.top_level = true
	_marker.visible = false
	Psx.box(self, Vector3(0.5, 0.3, 0.25), MOUNT + Vector3(0.0, 0.0, 0.1), Color(0.3, 0.3, 0.32))


func mount_position() -> Vector3:
	return vehicle.global_transform * MOUNT


func toggle() -> void:
	if attached:
		detach()
	elif candidate >= 0:
		anchor = anchors[candidate]
		length = mount_position().distance_to(anchor)
		attached = true


func detach() -> void:
	attached = false
	tension = 0.0


func prompt() -> String:
	if attached:
		return "[Shift] намотувати  [F] відчепити"
	if candidate >= 0:
		return "[F] Лебідка до опори (%d м)" % roundi(mount_position().distance_to(anchors[candidate]))
	return ""


func _physics_process(delta: float) -> void:
	if not attached:
		candidate = _find_candidate()
		reeling = false
		return
	var m := mount_position()
	var to := anchor - m
	var d := to.length()
	reeling = (auto_reel or Input.is_action_pressed("winch_reel")) and vehicle.fuel > 0.0
	if reeling:
		length = maxf(length - REEL_SPEED * delta, MIN_LENGTH)
		vehicle.fuel = maxf(vehicle.fuel - 0.15 * delta, 0.0)
	length = minf(length, d)  # храповик: слабина вибирається сама
	var stretch := d - length
	tension = 0.0
	if stretch > 0.0 and d > 0.01:
		var dir := to / d
		var v_away := -vehicle.point_velocity(m).dot(dir)
		tension = clampf(STIFFNESS * stretch + DAMPING * v_away, 0.0, MAX_FORCE)
		vehicle.apply_force(dir * tension, m - vehicle.global_position)


func _process(_delta: float) -> void:
	_marker.visible = not attached and candidate >= 0
	if _marker.visible:
		_marker.global_position = anchors[candidate] + Vector3(0.0, 0.3 + sin(Time.get_ticks_msec() / 200.0) * 0.1, 0.0)

	for seg in _segments:
		seg.visible = attached
	if not attached:
		return
	var m := mount_position()
	var d := m.distance_to(anchor)
	var sag := clampf(1.0 - tension / 4000.0, 0.0, 1.0) * 0.05 * d
	var prev := m
	for i in SEGMENTS:
		var t := float(i + 1) / SEGMENTS
		var p := m.lerp(anchor, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		var dir := p - prev
		if dir.length() > 0.001 and absf(dir.normalized().y) < 0.99:
			var b := Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3(1.0, 1.0, dir.length()))
			_segments[i].global_transform = Transform3D(b, (prev + p) * 0.5)
		prev = p


func _find_candidate() -> int:
	var m := mount_position()
	var fwd := -vehicle.global_transform.basis.z
	var best := -1
	var best_score := INF
	for i in anchors.size():
		var to := anchors[i] - m
		var d := to.length()
		if d > RANGE or d < 1.5:
			continue
		var score := d - to.normalized().dot(fwd) * 6.0
		if score < best_score:
			best_score = score
			best = i
	return best
