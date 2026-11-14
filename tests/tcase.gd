class_name TCase
extends RefCounted
## One running test: collects failures instead of stopping at the first,
## and carries the world that every test shares.

var name: String
var failures: PackedStringArray = []
var note := ""
var tree: SceneTree
var world  # scenes/main.tscn (scripts/main.gd), built once by run_tests.gd


func _init(n: String, t: SceneTree, w: Node) -> void:
	name = n
	tree = t
	world = w


func ok(cond: bool, msg: String = "") -> bool:
	if not cond:
		failures.append(msg if msg != "" else "expected true")
	return cond


func eq(a, b, msg: String = "") -> bool:
	if a == b:
		return true
	failures.append("%s: got %s, expected %s" % [msg, var_to_str(a), var_to_str(b)])
	return false


func fail(msg: String) -> void:
	failures.append(msg)


## Waits n physics ticks (1/60 s each when the runner is started with --fixed-fps 60).
func ticks(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Puts the truck on the ground at p, facing yaw, and lets it settle.
func place(p: Vector2, yaw: float, settle := 90) -> void:
	var v: Vehicle = world.vehicle
	v.autodrive = false
	v.teleport(Vector3(p.x, world.land.home.get_height(p.x, p.y) + 1.2, p.y), yaw)
	await ticks(settle)
