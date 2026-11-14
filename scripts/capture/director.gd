class_name Director
extends Node
## Scripted capture for the store page: drives the truck and the camera through the trailer
## scenes and saves every frame of each scene as <out>/<scene>/00000.png, at the game's own
## 480x270. Run at a fixed frame rate, so time and physics are the same on every run:
##   godot --path . --fixed-fps 30 -- --capture=trailer --out=<dir>   (./godot.sh capture)
## tools/make_media.py cuts the trailer from the scenes and picks the screenshots.

const FPS := 30.0

var main: Node3D
var out_dir := ""

var _cam: Callable  # (t: float) -> Transform3D while the director holds the camera
var _t := 0.0  # seconds into the current scene
var _hide_arrow := false
var _log := PackedStringArray()


func _ready() -> void:
	process_priority = 1000  # after the truck, the chase camera and the contracts
	main.hud.set_help(Hud.Help.OFF)
	AudioServer.set_bus_mute(0, true)  # frames come slower than real time: the sound would stutter
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _cam.is_valid():
		main.camera_rig.camera.global_transform = _cam.call(_t)
	if _hide_arrow:
		main.contracts._arrow.visible = false


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(10)
	await _depart_depot()
	await _road_to_khutir()
	await _snow_to_tower()
	await _winch()
	_log.append("done")
	var f := FileAccess.open(out_dir.path_join("done.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	get_tree().quit()


# --- Scenes ------------------------------------------------------------------------------------

func _depart_depot() -> void:
	var v: Vehicle = main.vehicle
	var c: Contracts = main.contracts
	# The truck waits at the pump, lights on, while the camera drifts in over the valley.
	await _place(Vector2(-93.5, -88.0), _yaw_to(Vector2(-93.5, -88.0), Vector2(-96.0, -70.0)))
	v.set_lights(true)
	var depot := _ground(-96.0, -92.0)
	_cinematic(true)
	_cam = _fly(depot + Vector3(42.0, 26.0, 40.0), depot + Vector3(14.0, 7.0, 16.0),
		depot + Vector3(0.0, 2.0, 0.0), depot + Vector3(0.0, 2.0, 0.0), 7.0)
	await _record("01-valley", 7.0)

	# Loading up: the crate drops onto the bed, the depot's lit windows behind.
	_cam = _orbit_truck(7.5, 3.2, deg_to_rad(-55.0), deg_to_rad(-15.0), 5.0)
	await _record("02-depot", 5.0, {1.6: func() -> void: c.take(c.offer("farm", "plain"))})

	# Out of the depot and up the west road towards the khutir.
	main.map_screen._trail.clear()
	var route := PackedVector2Array([Vector2(-97.0, -78.0)])
	route.append_array(main.roads[1].slice(1, -1))
	route.append(Vector2(-73.0, 86.0))  # pull up short of the khutir's house
	v.drive_along(route, 10.0)
	_cam = _follow(Vector3(0.0, 2.6, 8.5), Vector3(0.0, 1.0, -6.0), 3.0)
	await _until(func() -> bool: return _xz(v).y > -72.0, 20.0)
	await _record("03-road", 7.0)


func _road_to_khutir() -> void:
	var v: Vehicle = main.vehicle
	# The puddle across the road at (-88, -15): into it in two-wheel drive, then 4x4 and the lock
	# while the wheels are still in the mud.
	await _until(func() -> bool: return _xz(v).distance_to(Vector2(-88.0, -15.0)) < 30.0, 60.0)
	v.awd = false
	v.diff_lock = false
	_cinematic(false)
	_cam = _follow(Vector3(-3.5, 1.8, -9.0), Vector3(0.0, 0.8, 0.0), 2.5)
	await _record("06-mud", 7.0, {
		0.5: func() -> void: v.awd = true,
		1.0: func() -> void: v.diff_lock = true,
	})
	# The last stretch: ride in behind the truck, the khutir's lit window ahead.
	_cinematic(true)
	await _until(func() -> bool: return _xz(v).distance_to(Vector2(-85.0, 60.0)) < 14.0, 90.0)
	_cam = _follow(Vector3(2.8, 2.4, 7.5), Vector3(0.0, 1.6, -10.0), 2.0)
	await _record("10-khutir", 6.0)
	await _until(func() -> bool: return not v.autodrive or absf(v.forward_speed) < 0.3, 10.0)
	await _frames(10)
	main.contracts.call("_interact")  # deliver, for the money on the dashboard
	await _frames(15)
	main.call("_toggle_map")
	await _record("08-map", 4.0)
	main.call("_toggle_map")

	# The end card: the camera cranes up and away from the khutir at dusk.
	_cinematic(true)
	var house := _ground(-75.0, 95.0)
	var look := house + Vector3(0.0, 2.0, 0.0)
	_cam = _crane(v.global_position + Vector3(-3.0, 1.5, -7.0), v.global_position + Vector3(-9.0, 13.0, -24.0), look, 9.0)
	await _record("11-title", 9.0)


func _snow_to_tower() -> void:
	var v: Vehicle = main.vehicle
	# Off the road, through the drifts, up to the radio tower: low range, all wheels, locked.
	var start := Vector2(54.0, 54.0)
	var route := PackedVector2Array([Vector2(31.0, 31.0), Vector2(27.5, 28.0)])
	await _place(start, _yaw_to(start, route[0]))
	v.set_cargo(true)
	v.awd = true
	v.diff_lock = true
	v.low_range = true
	v.drive_along(route, 4.0)
	_cinematic(true)
	_cam = _follow(Vector3(4.0, 1.0, -1.0), Vector3(0.0, 0.6, 0.0), 6.0)
	await _frames(20)
	await _record("04-snow", 4.5)
	# Down low behind it, over the fresh ruts.
	_cam = _follow(Vector3(0.7, 1.2, 5.5), Vector3(0.0, 0.0, 2.0), 3.0)
	await _record("05-ruts", 4.0)
	# Arriving at the tower, the drone on its pad in the foreground.
	var pad := _ground(22.0, 31.0)
	var eye := _find_view(pad + Vector3(0.0, 0.5, 0.0), Vector2(-1.0, -0.7), 5.5, 1.3)
	_cam = _static_watch_blend(eye, pad + Vector3(0.0, 0.6, 0.0), 0.55)
	await _record("09-tower", 7.0)
	v.low_range = false


func _winch() -> void:
	var v: Vehicle = main.vehicle
	# Nose-first in the drifts below a pine: hook up and reel in.
	var p := Vector2(-81.5, 19.6)
	var tree := Vector2(-75.2, 26.0)
	await _place(p, _yaw_to(p, tree))
	v.set_cargo(true)
	v.awd = false
	v.diff_lock = false
	await _frames(20)
	var anchor := v.winch.anchors[v.winch.candidate] if v.winch.candidate >= 0 else _ground(tree.x, tree.y)
	var mid := (v.global_position + anchor) * 0.5
	var across := Vector2(anchor.x - v.global_position.x, anchor.z - v.global_position.z).normalized().orthogonal()
	var eye := _find_view(mid + Vector3(0.0, 0.6, 0.0), across, 5.5, 1.0)
	_cinematic(true)
	_cam = _static_watch_blend(eye, mid + Vector3(0.0, 0.8, 0.0), 0.5)
	await _record("07-winch", 7.0, {
		1.0: func() -> void: v.winch.toggle(),
		1.6: func() -> void: v.winch.auto_reel = true,
	})
	v.winch.auto_reel = false
	if v.winch.attached:
		v.winch.toggle()


# --- Recording -------------------------------------------------------------------------------

## Saves every frame for `seconds` into <out>/<scene>/; `events` maps a time (s) to a Callable.
func _record(scene: String, seconds: float, events := {}) -> void:
	var dir := out_dir.path_join(scene)
	DirAccess.make_dir_recursive_absolute(dir)
	var n := roundi(seconds * FPS)
	var times := events.keys()
	times.sort()
	_t = 0.0
	for i in n:
		while not times.is_empty() and _t >= times[0]:
			(events[times.pop_front()] as Callable).call()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("%05d.png" % i))
	_log.append("%s %d" % [scene, n])
	print("captured ", scene, " (", n, " frames)")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Waits (not recording) until cond is true, at most `limit` seconds of game time.
func _until(cond: Callable, limit: float) -> void:
	for i in roundi(limit * FPS):
		if cond.call():
			return
		await get_tree().process_frame
	_log.append("timeout waiting at %s" % _xz(main.vehicle))


func _place(p: Vector2, yaw: float) -> void:
	var v: Vehicle = main.vehicle
	v.autodrive = false
	v.teleport(Vector3(p.x, main.land.get_height(p.x, p.y) + 1.2, p.y), yaw)
	await _frames(45)


## Cinematic: no dashboard and no guide arrow over the truck.
func _cinematic(on: bool) -> void:
	main.hud.visible = not on
	_hide_arrow = on


# --- Cameras: each returns a Callable(t) -> Transform3D, called every frame. ------------------
# Moving cameras keep a clear line to what they watch: a hill, trunk or pine crown in between
# pulls them in, the way the game's own chase camera does.

func _fly(p0: Vector3, p1: Vector3, look0: Vector3, look1: Vector3, dur: float) -> Callable:
	return func(t: float) -> Transform3D:
		var k := smoothstep(0.0, 1.0, clampf(t / dur, 0.0, 1.0))
		var look := look0.lerp(look1, k)
		return _looking(_unblock(look, p0.lerp(p1, k)), look)


## Circles the truck's position at the start, from angle a0 to a1 (radians from its heading;
## negative is to its right).
func _orbit_truck(radius: float, height: float, a0: float, a1: float, dur: float) -> Callable:
	var v: Vehicle = main.vehicle
	var center := v.global_position
	var heading := v.global_rotation.y
	return func(t: float) -> Transform3D:
		var a := heading + lerpf(a0, a1, smoothstep(0.0, 1.0, clampf(t / dur, 0.0, 1.0)))
		var look := v.global_position + Vector3(0.0, 0.7, 0.0)
		return _looking(_unblock(look, center + Vector3(-sin(a), 0.0, -cos(a)) * radius + Vector3(0.0, height, 0.0)), look)


## Rides with the truck at `offset` in its heading frame (x right, y up, z behind), looking at
## the truck plus `look` (same frame); `smooth` is how fast it catches up.
func _follow(offset: Vector3, look: Vector3, smooth: float) -> Callable:
	var v: Vehicle = main.vehicle
	var s := {"pos": Vector3.INF, "yaw": v.global_rotation.y}
	return func(_t: float) -> Transform3D:
		var dt := 1.0 / FPS
		s.yaw = lerp_angle(s.yaw, v.global_rotation.y, 1.0 - exp(-dt * smooth))
		var b := Basis(Vector3.UP, s.yaw)
		var want := v.global_position + b * offset
		s.pos = want if s.pos == Vector3.INF else (s.pos as Vector3).lerp(want, 1.0 - exp(-dt * smooth * 2.0))
		var target := v.global_position + Vector3(0.0, 0.8, 0.0)
		return _looking(_unblock(target, s.pos), v.global_position + b * look)


## Stands still at p and turns to keep the truck (plus `look` in its heading frame) in view.
func _static_watch(p: Vector3, look: Vector3) -> Callable:
	var v: Vehicle = main.vehicle
	return func(_t: float) -> Transform3D:
		return _looking(p, v.global_position + Basis(Vector3.UP, v.global_rotation.y) * look)


## Stands still at p, looking between `anchor` (k = 0) and the truck (k = 1).
func _static_watch_blend(p: Vector3, anchor: Vector3, k: float) -> Callable:
	var v: Vehicle = main.vehicle
	var s := {"look": Vector3.INF}
	return func(_t: float) -> Transform3D:
		var want := anchor.lerp(v.global_position + Vector3(0.0, 0.8, 0.0), k)
		s.look = want if s.look == Vector3.INF else (s.look as Vector3).lerp(want, 1.0 - exp(-4.0 / FPS))
		return _looking(p, s.look)


## Rises from p0 to p1 over dur, looking at `look`.
func _crane(p0: Vector3, p1: Vector3, look: Vector3, dur: float) -> Callable:
	return func(t: float) -> Transform3D:
		var k := smoothstep(0.0, 1.0, clampf(t / dur, 0.0, 1.0))
		return _looking(_unblock(look, p0.lerp(p1, k)), look)


## A point `dist` from target, at `height` over the ground, as close to direction `dir` as the
## view allows: turns around the target in 20-degree steps until nothing is in the way.
func _find_view(target: Vector3, dir: Vector2, dist: float, height: float) -> Vector3:
	var base := dir.normalized()
	for i in 18:
		var a := deg_to_rad(20.0) * ceili(i / 2.0) * (1.0 if i % 2 == 0 else -1.0)
		var d := base.rotated(a) * dist
		var p := _surface(target.x + d.x, target.z + d.y) + Vector3(0.0, height, 0.0)
		if _unblock(target, p).distance_to(p) < 0.01:
			return p
	_log.append("no clear view of %s" % target)
	var d0 := base * dist
	return _surface(target.x + d0.x, target.z + d0.y) + Vector3(0.0, height, 0.0)


## The point nearest `cam` on the line from `target` that still sees the target: not under the
## ground, not through a trunk or a building (physics) and not through a pine's crown.
func _unblock(target: Vector3, cam: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(target, cam)
	q.exclude = [main.vehicle.get_rid()]
	var hit: Dictionary = main.vehicle.get_world_3d().direct_space_state.intersect_ray(q)
	var end := cam
	if not hit.is_empty():
		end = (hit.position as Vector3) + (target - cam).normalized() * 0.4
	var steps := ceili(target.distance_to(end) / 0.5)
	var last := target
	for i in range(1, steps + 1):
		var p := target.lerp(end, float(i) / steps)
		if p.y < _surface(p.x, p.z).y + 0.35 or _in_crown(p):
			return last
		last = p
	return end


func _in_crown(p: Vector3) -> bool:
	var trees: PackedVector2Array = main.builder.tree_points
	for tp in trees:
		var d := Vector2(p.x, p.z).distance_to(tp)
		if d > 2.8:
			continue
		var hy: float = p.y - main.land.get_height(tp.x, tp.y)
		var r := 0.5 if hy < 1.4 else 2.7 * (1.0 - (hy - 1.4) / 7.5)
		if hy > 0.0 and d < r:
			return true
	return false


func _looking(p: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(target - p, Vector3.UP), p)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, main.land.get_height(x, z), z)


## The top of the snow (or mud) layer, which stands up to 0.8 m over the ground.
func _surface(x: float, z: float) -> Vector3:
	var s: Terrain.Surface = main.land.sample(Vector3(x, 0.0, z))
	return _ground(x, z) + Vector3(0.0, maxf(s.snow, s.mud * Terrain.MAX_MUD), 0.0)


func _xz(n: Node3D) -> Vector2:
	return Vector2(n.global_position.x, n.global_position.z)


## The yaw that points the truck from `from` towards `to`.
func _yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)
