extends Node
## The game: the title, then the world in play; Esc in play comes back to the title.
## --valley=<id> goes straight into a valley, and so do --autodrive, --capture=..., --maptest and
## --winchtest (the khutir valley), with a profile kept in memory.

const MAIN := preload("res://scenes/main.tscn")
const DIRECT := ["--autodrive", "--maptest", "--winchtest", "--capture="]

var profile_path := Profile.PATH  # the tests keep theirs apart
var profile: Profile
var screen: TitleScreen
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
		show_title()


func show_title() -> void:
	screen = TitleScreen.new()
	screen.can_continue = Profile.exists(profile_path)
	add_child(screen)
	screen.start.connect(_start)


## New game wipes the save and starts in the steppe (docs/plan.md §1); Continue goes back to
## where the save was. Until the biomes are one map, that is the valley it was in.
func _start(fresh: bool) -> void:
	if fresh:
		profile = Profile.new()
		profile.path = profile_path
		profile.truck = "scout"  # a new game starts in the scout (docs/plan.md §7)
	var v := Valley.find(profile.last)
	enter(v if v else Valley.steppe(), Weather.Kind.OWN)


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


## A key let go outside the window or the browser frame never reaches the game; main.gd lets go
## of every key in a valley, and this does on the title, or the truck would drive off
## with nothing pressed in the next valley.
func _notification(what: int) -> void:
	if world == null and (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT):
		for action in InputMap.get_actions():
			if Input.is_action_pressed(action):
				Input.action_release(action)


func _leave() -> void:
	world.queue_free()
	world = null
	show_title()
