extends Node
## The game: the valleys screen, then a valley in play; Esc in a valley comes back to the valleys.
## --valley=<id> goes straight into a valley, and so do --autodrive, --capture=..., --maptest and
## --winchtest (the khutir valley), with a profile kept in memory.

const MAIN := preload("res://scenes/main.tscn")
const DIRECT := ["--autodrive", "--maptest", "--winchtest", "--capture="]

var profile_path := Profile.PATH  # the tests keep theirs apart
var profile: Profile
var screen: StartScreen
var world: Node


func _ready() -> void:
	var direct := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--valley="):
			direct = arg.get_slice("=", 1)
		for d in DIRECT:
			if arg.begins_with(d) and direct == "":
				direct = "khutir"
	if direct != "":
		profile = Profile.new()
		var v := Valley.find(direct)
		enter(v if v else Valley.khutir(), Weather.Kind.OWN)
	else:
		profile = Profile.open(profile_path)
		show_valleys()


func show_valleys() -> void:
	screen = StartScreen.new()
	screen.profile = profile
	add_child(screen)
	screen.drive.connect(enter)


func enter(v: Valley, kind: Weather.Kind) -> void:
	if screen:
		screen.queue_free()
		screen = null
	profile.last = v.id
	profile.save()
	world = MAIN.instantiate()
	world.valley = v
	world.weather = Weather.make(kind, v)
	world.profile = profile
	add_child(world)
	world.leave.connect(_leave)


func _leave() -> void:
	world.queue_free()
	world = null
	show_valleys()
