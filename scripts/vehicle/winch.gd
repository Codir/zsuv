class_name Winch
extends Node3D
## The winch (docs/plan.md §8): F starts aiming, and a crosshair follows the mouse; a ray from the
## camera through the cursor finds what is under it. A tree (1 m up its trunk), a rock, a building
## or a body (a truck, a trailer, a car: hooked where the cursor is on it) can be hooked if the
## cable reaches and no ground is in between; left click hooks it, F again hooks what the winch
## picks itself (the nearest tree or rock ahead, or a stuck car), Esc stops aiming. Hooked, the
## cable takes up its own slack (a ratchet), Shift reels it in, F lets go. A body is pulled as the
## truck is, the pull on both. Winch.aim(origin, dir) does what the cursor does.

const MAX_FORCE := 32000.0
const STIFFNESS := 60000.0
const DAMPING := 6000.0
const REEL_SPEED := 1.4
const MIN_LENGTH := 2.0
const CAR_MIN_LENGTH := 0.6  # a body comes right up to the bumper
const MIN_REACH := 1.5  # nothing closer than this to the winch is hooked
const AIM_REACH := 300.0  # how far the aiming ray looks
const SEGMENTS := 10
const HOOKABLE := Color(1.0, 0.85, 0.2)
const REFUSED := Color(0.95, 0.2, 0.12)
const NOTHING := "Nothing to hook: a tree, a rock or a truck"

signal said(text: String)  # why a click hooked nothing

var vehicle: Vehicle
var mount := Vector3(0.0, 0.25, -2.4)  # on the truck's front, in its frame (TruckSpec.winch_mount)
var max_length := 20.0  # the cable (TruckSpec.winch_length)
var pull := 1.0  # times MAX_FORCE (the long winch upgrade)
var anchors := PackedVector3Array()  # the trees' and rocks' hook points, for the winch's own pick
var bodies: Array[RigidBody3D] = []  # bodies it may pick itself (a stuck car), before any anchor
var attached := false
var anchor := Vector3.ZERO
var anchor_body: RigidBody3D  # the body hooked, or null for a tree, a rock or a building
var anchor_local := Vector3.ZERO  # the hook on anchor_body, in its frame
var length := 0.0
var tension := 0.0
var reeling := false
var candidate := -1
var auto_reel := false  # for tests
var aiming := false
var aimed := {}  # what the last aim found: {ok, point, body, local, what, reason}; empty: none

var _segments: Array[MeshInstance3D] = []
var _marker: MeshInstance3D  # the winch's own pick, bobbing
var _aim_ok: MeshInstance3D  # where the aim is: yellow it hooks, red it cannot
var _aim_no: MeshInstance3D


func _ready() -> void:
	for i in SEGMENTS:
		var seg := Psx.box(self, Vector3(0.08, 0.08, 1.0), Vector3.ZERO, Color(0.12, 0.12, 0.12))
		seg.top_level = true
		seg.visible = false
		_segments.append(seg)
	_marker = _ball(HOOKABLE, 0.35)
	_aim_ok = _ball(HOOKABLE, 0.3)
	_aim_no = _ball(REFUSED, 0.3)
	Psx.box(self, Vector3(0.5, 0.3, 0.25), mount + Vector3(0.0, 0.0, 0.1), Color(0.3, 0.3, 0.32))


func _ball(colour: Color, size: float) -> MeshInstance3D:
	var b := Psx.box(self, Vector3.ONE * size, Vector3.ZERO, colour, 2.5)
	b.top_level = true
	b.visible = false
	return b


func mount_position() -> Vector3:
	return vehicle.global_transform * mount


## F: lets go when hooked; aiming, hooks what the winch picks itself; else starts aiming.
func press() -> void:
	if attached:
		detach()
	elif aiming:
		cancel_aim()
		toggle()
	else:
		aiming = true
		aimed = {}
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)


## Stops aiming, hooking nothing.
func cancel_aim() -> void:
	if aiming:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	aiming = false
	aimed = {}


## Khutir Road's F: lets go, or hooks what the winch picks itself (the stuck car, else the
## nearest tree or rock ahead).
func toggle() -> void:
	if attached:
		detach()
	elif candidate >= 0:
		if candidate >= anchors.size():
			var b := bodies[candidate - anchors.size()]
			hook_body(b, b.global_transform.affine_inverse() * _body_hook(b))
		else:
			hook_point(anchors[candidate])


## Hooks a fixed point: a tree, a rock, a building.
func hook_point(p: Vector3) -> void:
	detach()
	anchor = p
	length = mount_position().distance_to(p)
	attached = true


## Hooks body at local, a point in its frame; a truck hooked wakes and lets its brakes go.
func hook_body(body: RigidBody3D, local: Vector3) -> void:
	detach()
	anchor_body = body
	anchor_local = local
	anchor = body.global_transform * local
	length = mount_position().distance_to(anchor)
	attached = true
	var v := body as Vehicle
	if v:
		v.set_frozen(false)
		v.hooked_by = self
	var t := body as Trailer
	if t:
		t.freeze = false


func detach() -> void:
	var v := anchor_body as Vehicle
	if v and is_instance_valid(v) and v.hooked_by == self:
		v.hooked_by = null
	attached = false
	anchor_body = null
	tension = 0.0


## Aims along the ray from origin in dir, as the cursor does: what is there and whether it can be
## hooked, as aimed is ({ok, point, body, local, what, reason}).
func aim(origin: Vector3, dir: Vector3) -> Dictionary:
	aimed = {"ok": false, "point": Vector3.INF, "body": null, "local": Vector3.ZERO, "what": "", "reason": NOTHING}
	var space := vehicle.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir.normalized() * AIM_REACH)
	var mine: Array[RID] = [vehicle.get_rid()]
	if vehicle.trailer:
		mine.append(vehicle.trailer.get_rid())
	q.exclude = mine
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return aimed
	var col: Object = hit.collider
	var point: Vector3 = hit.position
	aimed.point = point
	if _is_ground(col):
		return aimed
	if col is RigidBody3D:
		var body := col as RigidBody3D
		aimed.body = body
		aimed.local = body.global_transform.affine_inverse() * point
		aimed.what = "the trailer" if body is Trailer else ("the truck" if body is Vehicle else "the car")
	elif col is CollisionObject3D:
		var co := col as CollisionObject3D
		var shape: Node = co.shape_owner_get_owner(co.shape_find_owner(int(hit.shape)))
		if shape and shape.has_meta("anchor"):  # a tree or a rock (WorldBuilder)
			point = shape.get_meta("anchor")
			aimed.what = shape.get_meta("what", "the tree")
		else:
			aimed.what = "the building"
		aimed.point = point
	else:
		return aimed
	var d := mount_position().distance_to(point)
	if d > max_length:
		aimed.reason = "Too far: %d m, the cable is %d" % [roundi(d), roundi(max_length)]
	elif d < MIN_REACH:
		aimed.reason = "Too close"
	elif _ground_between(mount_position(), point):
		aimed.reason = "The ground is in the way"
	else:
		aimed.ok = true
		aimed.reason = ""
	return aimed


## Hooks what was aimed at, if it can be: true when it did; else says why.
func hook_aimed() -> bool:
	if aimed.is_empty() or not aimed.ok:
		said.emit(aimed.get("reason", NOTHING))
		return false
	if aimed.body:
		hook_body(aimed.body, aimed.local)
	else:
		hook_point(aimed.point)
	cancel_aim()
	return true


## The ray from the camera through the mouse cursor (the 480x270 stretch maps it).
func _aim_at_mouse() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var m := get_viewport().get_mouse_position()
	aim(cam.project_ray_origin(m), cam.project_ray_normal(m))


func _is_ground(col: Object) -> bool:
	return vehicle.land != null and vehicle.land.is_ground(col)


## Whether the ground stands between a and b (a little short of b: a tree's foot is in it).
func _ground_between(a: Vector3, b: Vector3) -> bool:
	if vehicle.land == null:
		return false
	var to := b - a
	var end := a + to * maxf(1.0 - 0.6 / maxf(to.length(), 0.001), 0.0)
	var q := PhysicsRayQueryParameters3D.create(a, end)
	var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(q)
	while not hit.is_empty() and not _is_ground(hit.collider):
		var ex: Array[RID] = q.exclude
		ex.append((hit.collider as CollisionObject3D).get_rid())
		q.exclude = ex
		hit = vehicle.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty()


func candidate_point() -> Vector3:
	if candidate < anchors.size():
		return anchors[candidate]
	var k := candidate - anchors.size()
	return _body_hook(bodies[k]) if k < bodies.size() and is_instance_valid(bodies[k]) else mount_position()


## Where a body the winch picks itself is hooked: its towing eye if it has one.
func _body_hook(b: RigidBody3D) -> Vector3:
	return b.hook_point() if b.has_method("hook_point") else b.global_position


## Lets go of body if it is hooked or the next to be, as it drives off.
func forget(body: RigidBody3D) -> void:
	if anchor_body == body:
		detach()
	bodies.erase(body)
	candidate = -1


func prompt() -> String:
	if attached:
		return "[Shift] reel in  [F] unhook"
	if aiming:
		if aimed.is_empty():
			return "Aim with the mouse  [F] nearest  [Esc] cancel"
		if aimed.ok:
			return "[Click] Hook %s (%d m)  [Esc] cancel" % [aimed.what, roundi(mount_position().distance_to(aimed.point))]
		return "%s  [F] nearest  [Esc] cancel" % aimed.reason
	if candidate >= 0:
		var what := "the car" if candidate >= anchors.size() else "anchor"
		return "[F] Winch to %s (%d m)" % [what, roundi(mount_position().distance_to(candidate_point()))]
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not aiming or not vehicle.driven:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_aim_at_mouse()
		hook_aimed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		cancel_aim()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not attached:
		candidate = _find_candidate()
		reeling = false
		return
	if anchor_body and not is_instance_valid(anchor_body):
		detach()
		return
	if anchor_body:
		anchor = anchor_body.global_transform * anchor_local
	var m := mount_position()
	var to := anchor - m
	var d := to.length()
	reeling = (auto_reel or (vehicle.driven and Input.is_action_pressed("winch_reel"))) and vehicle.fuel > 0.0
	if reeling:
		length = maxf(length - REEL_SPEED * delta, CAR_MIN_LENGTH if anchor_body else MIN_LENGTH)
		vehicle.fuel = maxf(vehicle.fuel - 0.15 * delta, 0.0)
	length = minf(length, d)  # ratchet: slack is taken up by itself
	var stretch := d - length
	tension = 0.0
	if stretch > 0.0 and d > 0.01:
		var dir := to / d
		var v_away := -vehicle.point_velocity(m).dot(dir)
		if anchor_body:
			var c := anchor_body.global_transform * anchor_body.center_of_mass
			v_away += (anchor_body.linear_velocity + anchor_body.angular_velocity.cross(anchor - c)).dot(dir)
		tension = clampf(STIFFNESS * stretch + DAMPING * v_away, 0.0, MAX_FORCE * pull)
		vehicle.apply_force(dir * tension, m - vehicle.global_position)
		if anchor_body:
			anchor_body.apply_force(-dir * tension, anchor - anchor_body.global_position)


func _process(_delta: float) -> void:
	if aiming and vehicle.driven and DisplayServer.get_name() != "headless":
		_aim_at_mouse()
	var bob := Vector3(0.0, 0.3 + sin(Time.get_ticks_msec() / 200.0) * 0.1, 0.0)
	_marker.visible = not attached and not aiming and candidate >= 0
	if _marker.visible:
		_marker.global_position = candidate_point() + bob
	var aim_shown: bool = aiming and not aimed.is_empty() and aimed.point != Vector3.INF
	_aim_ok.visible = aim_shown and aimed.ok
	_aim_no.visible = aim_shown and not aimed.ok
	if aim_shown:
		(_aim_ok if aimed.ok else _aim_no).global_position = aimed.point

	for seg in _segments:
		seg.visible = attached or aim_shown
	if not attached:
		if aim_shown:  # a dashed line from the winch to the point
			_draw_line(mount_position(), aimed.point, 0.0, 0.5)
		return
	var m := mount_position()
	var d := m.distance_to(anchor)
	var sag := clampf(1.0 - tension / 4000.0, 0.0, 1.0) * 0.05 * d
	_draw_line(m, anchor, sag, 1.0)


## The cable's segments from a to b, sagging by sag in the middle; each drawn over share of its
## length (under 1: dashed).
func _draw_line(a: Vector3, b: Vector3, sag: float, share: float) -> void:
	var prev := a
	for i in SEGMENTS:
		var t := float(i + 1) / SEGMENTS
		var p := a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		var dir := p - prev
		if dir.length() > 0.001 and absf(dir.normalized().y) < 0.99:
			var basis := Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3(1.0, 1.0, dir.length() * share))
			_segments[i].global_transform = Transform3D(basis, prev + dir * share * 0.5 if share < 1.0 else (prev + p) * 0.5)
		prev = p


func _find_candidate() -> int:
	var m := mount_position()
	var fwd := -vehicle.global_transform.basis.z
	var best := -1
	var best_score := INF
	var reach := max_length
	for i in anchors.size():
		var to := anchors[i] - m
		var d := to.length()
		if d > reach or d < MIN_REACH:
			continue
		var score := d - to.normalized().dot(fwd) * 6.0
		if score < best_score:
			best_score = score
			best = i
	for k in bodies.size():  # a stuck car before any tree: it is what the winch is for here
		if not is_instance_valid(bodies[k]):
			continue
		var to := _body_hook(bodies[k]) - m
		var d := to.length()
		if d > reach or d < MIN_REACH:
			continue
		var score := d - to.normalized().dot(fwd) * 6.0 - 8.0
		if score < best_score:
			best_score = score
			best = anchors.size() + k
	return best
