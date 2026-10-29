extends SceneTree
## The valleys screen's pictures: each valley in its own sky, seen from above and behind the
## truck at its depot, looking out along its first road, saved as <out>/<id>.png at 240x135
## (the game's 480x270 halved). Needs a window to render into:
##   godot --path . -s res://scripts/capture/previews.gd -- --out=<dir>   (./godot.sh previews)

const SCENE := preload("res://scenes/main.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := ProjectSettings.globalize_path("res://previews")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	for v in Valley.all():
		var world = SCENE.instantiate()
		world.valley = v
		root.add_child(world)
		world.hud.visible = false
		world.contracts.set_process(false)
		world.contracts._arrow.visible = false
		for m in world.contracts._markers:
			m.visible = false
		world.camera_rig.set_process(false)
		var cam: Camera3D = world.camera_rig.camera
		var dir := (v.roads[0][1] - v.spawn).normalized()
		var terrain: Terrain = world.terrain
		var from := v.spawn - dir * 20.0
		var at := v.spawn + dir * 45.0
		cam.global_position = Vector3(from.x, maxf(terrain.get_height(from.x, from.y), terrain.get_height(v.spawn.x, v.spawn.y)) + 12.0, from.y)
		cam.look_at(Vector3(at.x, terrain.get_height(at.x, at.y) + 2.0, at.y), Vector3.UP)
		for i in 45:
			await process_frame
		var img := root.get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		img.save_png(out.path_join(v.id + ".png"))
		print("previews: ", v.id)
		world.free()
		await process_frame
	quit()
