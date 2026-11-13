extends RefCounted
## The title and what it keeps: the profile saves and loads (a bad file too), the title offers
## Continue only with a save and asks before New game wipes one, a new game starts in the steppe
## and Continue where the save was, Esc in play comes back to the title (a held Esc only once),
## and a key let go outside the window on the title is let go.

const TEST_PATH := "user://test_profile.cfg"


func _wipe() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_the_profile_saves_and_loads(t: TCase) -> void:
	_wipe()
	t.ok(not Profile.exists(TEST_PATH), "a save before any was made")
	var p := Profile.open(TEST_PATH)
	t.eq(p.money, 0, "a new profile's money")
	t.eq(p.last, "steppe", "a new profile starts in")
	p.money = 2000
	p.records["steppe:elevator:timed"] = {"time": 42.5, "medal": 1}
	p.last = "polissia"
	p.save()
	t.ok(Profile.exists(TEST_PATH), "no save after saving")
	var q := Profile.open(TEST_PATH)
	t.eq(q.money, 2000, "money")
	t.eq(q.records.get("steppe:elevator:timed", {}).get("time", 0.0), 42.5, "a record")
	t.eq(q.last, "polissia", "the last valley")
	t.ok(not Profile.exists(""), "a profile in memory has a save")
	_wipe()


func test_a_bad_profile_file_loads_as_defaults(t: TCase) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('[progress]\nmoney=1500.0\nlast="atlantis"\nrigs="6x6"\nrecords={"a": 5, "b": {"medal": 1}}\n')
	f.close()
	var p := Profile.open(TEST_PATH)
	t.ok(p != null, "a bad file gives no profile")
	if p == null:
		return
	t.eq(p.money, 1500, "money as a float")
	t.eq(p.last, "steppe", "a valley that is not there")
	t.eq(p.rigs, PackedStringArray(), "rigs as a string")
	t.eq(p.record("a"), {}, "a record as a number")
	t.eq(p.record("b"), {}, "a record with no time")
	_wipe()


func test_the_title_offers_continue_only_with_a_save(t: TCase) -> void:
	var s := TitleScreen.new()
	t.tree.root.add_child(s)
	var started := []
	s.start.connect(func(fresh: bool) -> void: started.append(fresh))
	t.eq(s.choices()[0], "", "Continue with no save")
	t.eq(s.index, 1, "the line picked with no save")
	s.pick(-1)
	t.eq(s.index, 1, "W picked the missing Continue")
	await s.go()
	t.ok(not s.asking, "New game asked with no save to lose")
	t.eq(started, [true], "New game with no save")
	s.free()


func test_new_game_asks_before_it_wipes_a_save(t: TCase) -> void:
	var s := TitleScreen.new()
	s.can_continue = true
	t.tree.root.add_child(s)
	var started := []
	s.start.connect(func(fresh: bool) -> void: started.append(fresh))
	t.eq(s.choices()[0], "Continue", "the first line with a save")
	t.eq(s.index, 0, "the line picked with a save")
	s.pick(1)
	await s.go()
	t.ok(s.asking, "New game did not ask before wiping the save")
	t.eq(started, [], "started before the answer")
	s.cancel()
	t.ok(not s.asking, "Esc did not take the question away")
	await s.go()
	await s.go()
	t.eq(started, [true], "New game after yes")
	s.free()
	s = TitleScreen.new()
	s.can_continue = true
	t.tree.root.add_child(s)
	s.start.connect(func(fresh: bool) -> void: started.append(fresh))
	await s.go()
	t.eq(started, [true, false], "Continue")
	s.free()


func test_new_game_starts_in_the_steppe_and_continue_where_it_was(t: TCase) -> void:
	_wipe()
	var old := Profile.open(TEST_PATH)
	old.money = 700
	old.last = "polissia"
	old.save()
	var vp := SubViewport.new()
	vp.own_world_3d = true
	t.tree.root.add_child(vp)
	var game = load("res://scripts/game.gd").new()
	game.profile_path = TEST_PATH
	vp.add_child(game)
	t.ok(game.screen != null and game.screen.can_continue, "the title has no Continue with a save")
	game._start(false)
	await t.ticks(3)
	t.eq(game.world.valley.id, "polissia", "Continue went to")
	t.eq(game.profile.money, 700, "Continue's money")
	game._leave()
	await t.ticks(2)
	game._start(true)
	await t.ticks(3)
	t.eq(game.world.valley.id, "steppe", "a new game starts in")
	t.eq(game.profile.money, 0, "a new game's money")
	t.eq(Profile.open(TEST_PATH).money, 0, "the old save is still there after a new game")
	vp.free()
	_wipe()


func test_esc_leaves_the_world_for_the_title(t: TCase) -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	t.tree.root.add_child(vp)
	var game = load("res://scripts/game.gd").new()
	game.profile_path = TEST_PATH
	vp.add_child(game)
	t.ok(game.screen != null and game.world == null, "the game does not open on the title")
	game.enter(Valley.khutir(), Weather.Kind.NIGHT)
	await t.ticks(5)
	t.ok(game.screen == null and game.world != null, "no world after starting")
	t.ok(game.world.weather.night, "the sky asked for is not the one in play")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	esc.echo = true
	game.world._unhandled_input(esc)
	await t.ticks(2)
	t.ok(game.world != null, "a held Esc (its key repeat) leaves the world")
	esc.echo = false
	game.world._unhandled_input(esc)
	await t.ticks(2)
	t.ok(game.screen != null and game.world == null, "Esc does not leave the world for the title")
	# W held on the title and let go outside the window: the world does not drive off.
	Input.action_press(&"accelerate")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.ok(not Input.is_action_pressed(&"accelerate"), "a key let go outside the window stays pressed on the title")
	Input.action_release(&"accelerate")
	vp.free()
	_wipe()
