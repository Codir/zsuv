class_name MapBake
extends Resource
## The map as the generator makes it, baked into res://map/ by `./godot.sh bake` (docs/plan.md §3):
## each tile's heights and ground image after the borders are joined, and the borders. The map is
## the same for every player, so the game loads this in a moment instead of generating it (2-4 s
## natively, 10-20 s in a browser). test_map.gd builds from the generator and checks it matches.

const PATH := "res://map/map.res"

@export var version := 0  # Land.MAP_VERSION it was baked at
@export var heights := {}  # valley id -> PackedFloat32Array (Terrain.N x Terrain.N)
@export var grounds := {}  # valley id -> PackedByteArray: the ground image, RGBA8
@export var borders: Array[Dictionary] = []  # as Land.borders, with ids for its tiles


static func load_current() -> MapBake:
	if not ResourceLoader.exists(PATH):
		return null
	var b := ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_REUSE) as MapBake
	return b if b and b.version == Land.MAP_VERSION else null
