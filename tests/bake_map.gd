extends SceneTree
## `./godot.sh bake`: runs the map's generator and writes what it makes to res://map/ (MapBake),
## which the game loads instead of generating it. test_map.gd fails when the bake is stale.

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var land := Land.new()
	land.build(Valley.steppe(), false)
	var b := land.bake()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://map"))
	var err := ResourceSaver.save(b, MapBake.PATH, ResourceSaver.FLAG_COMPRESS)
	print("baked %d tiles, map version %d, in %d ms: %s" % [b.heights.size(), b.version, Time.get_ticks_msec() - t0,
		"ok" if err == OK else error_string(err)])
	land.free()
	quit(0 if err == OK else 1)
