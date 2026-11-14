class_name Director
extends Node
## Scripted capture for the store page: drives the trucks and the camera through Zsuv's scenes
## and saves every frame of each as <out>/<scene>/00000.png, at the game's own 480x270. Run at a
## fixed frame rate, in a window (headless renders nothing) and with no sound, in the world built
## around the steppe, so time and physics are the same on every run:
##   godot --path . --audio-driver Dummy --fixed-fps 30 -- --valley=steppe --capture=trailer --out=<dir>
## (./godot.sh capture). tools/make_media.py cuts the trailer and picks the screenshots, the
## cover and the GIF. Every place is in the steppe's metres; another biome's is its own plus its
## tile's origin.

const FPS := 30.0
const FOREST := Vector2(256.0, 0.0)  # the khutir valley's middle in the steppe's frame
const SWAMP := Vector2(256.0, -256.0)
const PEAKS := Vector2(0.0, -512.0)

var main: Node3D
var out_dir := ""

var _cam: Callable  # (t: float) -> Transform3D while the director holds the camera
var _t := 0.0  # seconds into the current scene
var _log := PackedStringArray()


func _ready() -> void:
	process_priority = 1000  # after the truck and the chase camera
	main.hud.set_help(Hud.Help.OFF)
	AudioServer.set_bus_mute(0, true)  # frames come slower than real time: the sound would stutter
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _cam.is_valid():
		main.camera_rig.camera.global_transform = _cam.call(_t)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	main.profile.add_rigs(PackedStringArray(["tractor", "farm", "six", "trailer"]))
	main.call("_park_trailers")
	await _frames(10)
	await _scout()
	await _washout()
	await _fuel_station()
	await _mixer()
	await _bridge()
	await _forest()
	await _swamp()
	await _village()
	_log.append("done")
	var f := FileAccess.open(out_dir.path_join("done.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	get_tree().quit()


# --- Scenes ------------------------------------------------------------------------------------

## The scout on the wind farm's hill over the steppe, then off down the road with the paper map
## drawing itself.
func _scout() -> void:
	var v := await _truck(TruckSpec.scout())
	var top := Vector2(56.0, 50.0)
	await _place(top, _yaw_to(top, Vector2(20.0, -88.0)))
	v.set_lights(true)
	_cinematic(true)
	var at := v.global_position
	_cam = _fly(at + Vector3(-18.0, 6.0, 16.0), at + Vector3(-6.5, 2.4, 5.0), at + Vector3(0.0, 1.0, 0.0), at + Vector3(-4.0, 0.0, -12.0), 6.0)
	await _record("01-scout-ridge", 6.0)
	# Down the hill and away along the road to the elevator, the map open and filling in.
	main.map_screen._trail.clear()
	v.drive_along(PackedVector2Array([Vector2(44.0, 15.0), Vector2(36.0, -30.0), Vector2(20.0, -88.0)]), 12.0)
	await _frames(30)
	main.call("_toggle_map")
	await _record("02-map-draws", 6.0)
	main.call("_toggle_map")
	v.autodrive = false


## The tractor's bucket bites into the washout's bank, and the tipper pours its load into it.
func _washout() -> void:
	var land: Land = main.land
	var tile := land.home
	var ft: Dictionary = tile.valley.features.filter(func(x: Dictionary) -> bool: return x.type == "washout")[0]
	var r := int(ft.road)
	var s0 := float(ft.s)
	var dir: Vector2 = tile.along(r, s0)[1]
	var tractor := await _truck(TruckSpec.tractor())
	var farm: Trailer = main.contracts._trailer("farm")
	tractor.low_range = true
	tractor.awd = true
	await _rig(tractor, farm, tile.along(r, s0 - 8.0)[0], dir)
	var side := Vector2(-dir.y, dir.x)
	var at := tractor.global_position
	_cinematic(true)
	var eye := _ground(at.x + side.x * 9.0 + dir.x * 2.0, at.z + side.y * 9.0 + dir.y * 2.0) + Vector3(0.0, 3.0, 0.0)
	_cam = _static_watch(eye, Vector3(0.0, 0.0, -2.5))
	Input.action_press("dig")
	await _record("03-bucket-bites", 6.0, {}, func() -> void: _creep(tractor, 0.5))
	Input.action_release("dig")
	_creep(tractor, -1.0)
	# The tipper backed up to the gap, pouring.
	var back := (tractor.spec.hitch.z - farm.spec.coupler.z) + farm.spec.extent().end.z + Loader.BEHIND
	var spot: Vector2 = tile.along(r, s0 + 0.5)[0]
	await _rig(tractor, farm, spot - dir * back, -dir)
	Loader.set_soil(farm, Loader.TIPPER)
	var mid := _ground(spot.x, spot.y)
	eye = _ground(spot.x + side.x * 10.0 - dir.x * 4.0, spot.y + side.y * 10.0 - dir.y * 4.0) + Vector3(0.0, 4.0, 0.0)
	_cam = _static_watch_blend(eye, mid + Vector3(0.0, 0.5, 0.0), 0.35)
	Input.action_press("tip")
	await _record("04-tipper-pours", 6.0)
	Input.action_release("tip")
	tractor.unhitch()


## Placing a fuel station with P by the railhead: its footprint green on level ground.
func _fuel_station() -> void:
	var v := await _truck(TruckSpec.pickup())
	var infra: Infra = main.infra
	# The nearest spot to the railhead where a fuel station may stand, the truck 11 m short of it.
	var site := Vector2(-60.0, -60.0)
	var best := INF
	for z in range(-120, -10, 4):
		for x in range(-120, 0, 4):
			var q := Vector2(x, z)
			var d := q.distance_to(Vector2(-90.0, -85.0))
			if d < best and d > 30.0 and infra.check("fuel_station", q, 0.0) == "" and main.land.road_distance(q + Vector2(0.0, 11.0)) > 4.0:
				best = d
				site = q
	await _place(site + Vector2(0.0, 11.0), 0.0)
	var cam: Camera3D = infra.camera
	infra.camera = null  # the footprint stays where it is put, not under a cursor
	infra.picked = BuildingSpec.fuel_station()
	infra.mode = Infra.Mode.PLACE
	infra.ghost_yaw = 0.0
	infra.ghost_at = site
	_cinematic(false)
	_cam = _orbit_truck(13.0, 6.5, deg_to_rad(150.0), deg_to_rad(120.0), 5.0)
	await _record("05-fuel-station", 5.0)
	infra.mode = Infra.Mode.NONE
	infra.camera = cam


## The mixer out of the railhead with its concrete setting: the countdown on the HUD.
func _mixer() -> void:
	var v := await _truck(TruckSpec.mixer())
	v.rig_put("concrete", 1.0)
	var road: PackedVector2Array = main.roads[0]
	await _place(road[0].lerp(road[1], 0.35), _yaw_to(road[0], road[1]))
	v.drive_along(road.slice(1), 11.0)
	_cinematic(false)
	_cam = _follow(Vector3(-4.5, 2.6, 9.5), Vector3(0.0, 1.2, -8.0), 2.5)
	await _frames(45)
	await _record("06-mixer", 6.0)
	v.autodrive = false
	v.rig_take("concrete")


## A pickup over the river on a bridge, out of the steppe into the forest.
func _bridge() -> void:
	var land: Land = main.land
	var spot := land.spot("bridge:river")
	if not land.bridges.has(spot.id):
		land.build_deck(spot)
	var v := await _truck(TruckSpec.pickup())
	v.set_lights(true)
	var tile := land.home
	var sa := Vector2(spot.a.x, spot.a.z)
	var sb := Vector2(spot.b.x, spot.b.z)
	var way := PackedVector2Array()
	var s := 50.0
	while tile.along(4, s)[0].distance_to(sb) > sa.distance_to(sb) + 1.0:
		way.append(tile.along(4, s)[0])
		s += 4.0
	way.append_array(PackedVector2Array([sa, sb, Vector2(-104.0, -4.0) + FOREST, Vector2(-88.0, -15.0) + FOREST]))
	await _place(way[0], _yaw_to(way[0], way[1]))
	v.awd = true
	v.drive_along(way.slice(1), 8.0)
	var mid: Vector3 = (spot.a + spot.b) * 0.5
	_cinematic(true)
	_cam = _static_watch(mid + Vector3(-3.0, 4.0, 15.0), Vector3(0.0, 0.5, 0.0))
	await _until(func() -> bool: return _xz(v).distance_to(sa) < 14.0, 20.0)
	await _record("07-river-bridge", 7.0)
	v.autodrive = false


## Deep snow under the pines in the forest, then the winch aimed with the mouse at a tree.
func _forest() -> void:
	var v := await _truck(TruckSpec.pickup())
	var start := Vector2(54.0, 54.0) + FOREST
	var route := PackedVector2Array([Vector2(31.0, 31.0) + FOREST, Vector2(27.5, 28.0) + FOREST])
	await _place(start, _yaw_to(start, route[0]))
	v.awd = true
	v.diff_lock = true
	v.low_range = true
	v.drive_along(route, 4.0)
	_cinematic(true)
	_cam = _follow(Vector3(4.0, 1.0, -1.0), Vector3(0.0, 0.6, 0.0), 6.0)
	await _frames(20)
	await _record("08-deep-snow", 5.0)
	v.autodrive = false
	v.low_range = false
	# Nose-first in the drifts below a pine: F, the cursor on the tree, a click, and reel in.
	var p := Vector2(-81.5, 19.6) + FOREST
	var tree := p + Vector2(9.0, 0.0)
	var near := INF
	for pr in main.land.builders[main.land.tiles.find(main.land.tile_at(p.x, p.y))].props:
		var q: Vector2 = (pr.p as Vector2) + main.land.tile_at(p.x, p.y).origin
		var d := q.distance_to(p)
		if pr.kind == "tree" and pr.shape != null and d > 7.0 and d < 14.0 and absf(d - 10.0) < near:
			near = absf(d - 10.0)
			tree = q
	await _place(p, _yaw_to(p, tree))
	v.awd = false
	v.diff_lock = false
	await _frames(20)
	var anchor := v.winch.candidate_point() if v.winch.candidate >= 0 else _nearest_anchor(tree)  # what it would pick: in reach
	# Over the truck's shoulder, the tree ahead of it: the cursor goes onto the tree.
	var back := Vector2(v.global_position.x - anchor.x, v.global_position.z - anchor.z).normalized()
	var eye := _surface(v.global_position.x + back.x * 7.0 - back.y * 2.5, v.global_position.z + back.y * 7.0 + back.x * 2.5) + Vector3(0.0, 2.6, 0.0)
	_cinematic(false)
	_cam = _static_watch_blend(eye, anchor, 0.35)
	var winch: Winch = v.winch
	winch.aiming = true
	v.driven = false  # its aim is the director's here, not the window's cursor's

	await _record("09-winch-aim", 7.0, {
		2.2: func() -> void: winch.hook_aimed(); v.driven = true,
		2.8: func() -> void: winch.auto_reel = true,
	}, func() -> void: if winch.aiming: winch.aim(winch.mount_position(), anchor - Vector3(0.0, 0.15, 0.0) - winch.mount_position()))
	v.driven = true

	winch.auto_reel = false
	if winch.attached:
		winch.toggle()
	winch.cancel_aim()


## The 6x6 with its snorkel through the swamp's deep water, over the road to the forestry.
func _swamp() -> void:
	var v := await _truck(TruckSpec.six())
	v.fit("snorkel")
	var a := Vector2(-66.0, -86.0) + SWAMP
	var route := PackedVector2Array([Vector2(-52.0, -88.0) + SWAMP, Vector2(-22.0, -84.0) + SWAMP, Vector2(-4.0, -80.0) + SWAMP])
	await _place(a, _yaw_to(a, route[0]))
	v.awd = true
	v.low_range = true
	v.drive_along(route, 4.0)
	var lake := Vector2(-37.0, -86.0) + SWAMP
	_cinematic(true)
	var eye := _ground(lake.x - 4.0, lake.y + 10.0) + Vector3(0.0, 2.2, 0.0)
	_cam = _static_watch(eye, Vector3(0.0, 0.6, 0.0))
	await _until(func() -> bool: return _xz(v).distance_to(lake) < 9.0, 20.0)
	await _record("10-swamp-water", 6.0)
	v.autodrive = false
	v.low_range = false


## The upper village at night in the pass, the truck's lights on it: the end of the road.
func _village() -> void:
	var v := await _truck(TruckSpec.pickup())
	var village := Vector2(-12.0, -28.0) + PEAKS
	var at := Vector2(-21.0, -17.0) + PEAKS
	await _place(at, _yaw_to(at, village))
	v.set_lights(true)
	await _frames(30)  # the night's sky in
	_cinematic(true)
	var look := _ground(village.x, village.y) + Vector3(0.0, 3.0, 0.0)
	_cam = _crane(v.global_position + Vector3(4.0, 1.6, 6.0), v.global_position + Vector3(10.0, 12.0, 22.0), look, 9.0)
	await _record("11-upper-village", 9.0)


# --- Recording -------------------------------------------------------------------------------

## Saves every frame for `seconds` into <out>/<scene>/; `events` maps a time (s) to a Callable,
## `each` is called every frame before it is drawn.
func _record(scene: String, seconds: float, events := {}, each := Callable()) -> void:
	var dir := out_dir.path_join(scene)
	DirAccess.make_dir_recursive_absolute(dir)
	var n := roundi(seconds * FPS)
	var times := events.keys()
	times.sort()
	_t = 0.0
	for i in n:
		while not times.is_empty() and _t >= times[0]:
			(events[times.pop_front()] as Callable).call()
		if each.is_valid():
			each.call()
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


## Drives a truck of spec from now on (the one out on the map, or a new one).
func _truck(spec: TruckSpec) -> Vehicle:
	main.vehicle.autodrive = false
	main.vehicle.set_lights(false)
	_cam = Callable()
	main.set_truck(spec)
	await _frames(5)
	var v: Vehicle = main.vehicle
	v.autodrive = false
	return v


func _place(p: Vector2, yaw: float) -> void:
	var v: Vehicle = main.vehicle
	v.autodrive = false
	v.teleport(Vector3(p.x, main.land.get_height(p.x, p.y) + 1.2, p.y), yaw)
	await _frames(45)


## The tractor with its tipper hitched straight behind, set down at p facing dir.
func _rig(tractor: Vehicle, farm: Trailer, p: Vector2, dir: Vector2) -> void:
	_creep(tractor, -1.0)
	if tractor.trailer == null:
		tractor.hitch(farm)
		await _frames(2)
	await _place(p, atan2(-dir.x, -dir.y))


## Keeps the truck creeping at about speed m/s (-1: everything let go).
func _creep(v: Vehicle, speed: float) -> void:
	if speed < 0.0:
		Input.action_release("accelerate")
		Input.action_release("brake")
		return
	if v.forward_speed < speed:
		Input.action_release("brake")
		Input.action_press("accelerate", 0.5)
	else:
		Input.action_release("accelerate")
		Input.action_press("brake", 0.3)


## The mouse over p on the screen, so the winch's aim (which follows the cursor) is on it.
func _point_mouse_at(p: Vector3) -> void:
	var cam := main.camera_rig.camera as Camera3D
	if not cam.is_position_behind(p):
		# The game draws at 480x270 and the window shows it stretched: the cursor is in the window's pixels.
		var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
		Input.warp_mouse(cam.unproject_position(p) * scale)


func _nearest_anchor(p: Vector2) -> Vector3:
	var best := Vector3(p.x, main.land.get_height(p.x, p.y) + 1.0, p.y)
	var near := INF
	for a in main.land.anchor_points:
		var d := Vector2(a.x, a.z).distance_to(p)
		if d < near:
			near = d
			best = a
	return best


## Cinematic: no dashboard.
func _cinematic(on: bool) -> void:
	main.hud.visible = not on


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
	var trees: PackedVector2Array = main.land.tree_points
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
