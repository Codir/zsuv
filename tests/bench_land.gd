extends SceneTree
## `godot --headless --fixed-fps 60 --path . -s res://tests/bench_land.gd`: what the land costs the
## CPU, as the game builds it (around the steppe): building the map from the bake, a frame while
## driving, a frame while digging, opening the paper map. Headless, so the GPU's share is not in it:
## the triangles and the textures uploaded are counted instead. Natively; a browser runs GDScript
## some 5-10 times slower (docs/plan.md §3).

var _frames: Array[float] = []
var _last := 0


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var t0 := Time.get_ticks_usec()
	var world = load("res://scenes/main.tscn").instantiate()
	world.valley = Valley.steppe()
	world.profile = Profile.new()
	root.add_child(world)
	var built := (Time.get_ticks_usec() - t0) / 1000.0
	await process_frame
	var land: Land = world.land
	print("world built in %.0f ms (the land from the bake: %s)" % [built, land.baked])
	var t1 := Time.get_ticks_usec()
	var probe := Land.new()
	probe.build(Valley.steppe())
	print("  the land alone from the bake: %.0f ms %s" % [(Time.get_ticks_usec() - t1) / 1000.0, probe.timings])
	probe.free()
	print("  meshes: %d, triangles in the land's meshes: %d" % _triangles(land))

	# Driving: the steppe's first road, the fog uncovering, the sky checked.
	var v: Vehicle = world.vehicle
	v.drive_along(world.roads[0].slice(1))
	await _measure("driving", 600)
	v.autodrive = false

	# Digging: a bite every tick for 2 s (the loader takes one every 0.4 s), with the map closed.
	var p := Vector2(30.0, 40.0)
	var ew := land.earthworks
	_frames.clear()
	for i in 120:
		var a := Time.get_ticks_usec()
		ew.bite(p + Vector2(i % 6, i / 20), Vector2(1, 0))
		await physics_frame
		_frames.append((Time.get_ticks_usec() - a) / 1000.0)
	_report("digging, a bite a tick", _frames)

	# The paper map, opened the first time and drawn a frame.
	var t2 := Time.get_ticks_usec()
	world._toggle_map()
	await process_frame
	print("  the map opens in %.0f ms" % ((Time.get_ticks_usec() - t2) / 1000.0))
	_frames.clear()
	for i in 60:
		var a := Time.get_ticks_usec()
		ew.bite(p + Vector2(10 + i % 6, i / 20), Vector2(1, 0))
		await process_frame
		_frames.append((Time.get_ticks_usec() - a) / 1000.0)
	_report("digging with the map open", _frames)
	world._toggle_map()
	world.free()
	quit()


func _measure(what: String, n: int) -> void:
	_frames.clear()
	_last = Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		_frames.append((now - _last) / 1000.0)
		_last = now
	_report(what, _frames)


func _report(what: String, f: Array[float]) -> void:
	var s := f.duplicate()
	s.sort()
	var sum := 0.0
	for x in s:
		sum += x
	print("  %s: a frame %.2f ms on average, %.2f at the 95th, %.2f at the worst" % [what, sum / s.size(), s[int(s.size() * 0.95)], s[s.size() - 1]])


func _triangles(land: Land) -> Array:
	var meshes := 0
	var tris := 0
	for t in land.tiles:
		for c in t.get_children():
			var mi := c as MeshInstance3D
			if mi and mi.mesh is PlaneMesh:
				meshes += 1
				var pm := mi.mesh as PlaneMesh
				tris += (pm.subdivide_width + 1) * (pm.subdivide_depth + 1) * 2
	return [meshes, tris]
