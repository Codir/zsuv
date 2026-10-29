extends RefCounted
## The valleys screen and what it keeps: the profile saves and loads, valleys open in order for
## money, the screen buys and drives in, Esc in a valley comes back to the screen.

const TEST_PATH := "user://test_profile.cfg"


func test_the_profile_saves_and_loads(t: TCase) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var p := Profile.open(TEST_PATH)
	t.eq(p.money, 0, "a new profile's money")
	t.ok(p.owns("khutir") and not p.owns("steppe"), "a new profile owns the khutir valley only")
	p.money = 2000
	t.ok(p.buy(Valley.steppe()), "cannot buy the steppe for $2000")
	p.set_sky("steppe", Weather.Kind.NIGHT)
	p.records["steppe:elevator:timed"] = {"time": 42.5, "medal": 1}
	p.last = "steppe"
	p.save()
	var q := Profile.open(TEST_PATH)
	t.eq(q.money, 500, "money after buying")
	t.ok(q.owns("steppe"), "the steppe is not kept")
	t.eq(q.sky("steppe"), Weather.Kind.NIGHT, "the steppe's sky")
	t.eq(q.sky("khutir"), Weather.Kind.OWN, "the khutir valley's sky")
	t.eq(q.records.get("steppe:elevator:timed", {}).get("time", 0.0), 42.5, "a record")
	t.eq(q.last, "steppe", "the last valley")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_valleys_open_in_order_for_money(t: TCase) -> void:
	var p := Profile.new()
	var all := Valley.all()
	t.eq(p.cannot_buy(all[0]), "owned", "the khutir valley")
	t.eq(p.cannot_buy(all[1]), "$1500 more to earn", "the steppe with no money")
	t.ok(p.cannot_buy(all[2]).begins_with("open The Steppe"), "Zakarpattia before the steppe: " + p.cannot_buy(all[2]))
	t.ok(not p.buy(all[1]), "bought the steppe with no money")
	p.money = 1600
	t.ok(p.buy(all[1]), "cannot buy the steppe for $1600")
	t.eq(p.money, 100, "money left")
	t.eq(p.cannot_buy(all[2]), "$2400 more to earn", "Zakarpattia next")


func test_the_screen_buys_and_drives_in(t: TCase) -> void:
	var s := StartScreen.new()
	s.profile = Profile.new()
	t.tree.root.add_child(s)
	var entered := []
	s.drive.connect(func(v: Valley, kind: Weather.Kind) -> void: entered.append([v.id, kind]))
	t.eq(s.valley().id, "khutir", "the screen opens on")
	s.step(1)
	t.eq(s.valley().id, "steppe", "D: the next valley")
	await s.go()
	t.ok(s.message.begins_with("Not yet"), "bought with no money: " + s.message)
	s.profile.money = 1500
	await s.go()
	t.ok(s.profile.owns("steppe"), "the screen does not buy the steppe for $1500")
	s.step_sky(1)
	t.eq(s.profile.sky("steppe"), Weather.Kind.SUN, "W/S: the next sky")
	await s.go()
	t.eq(entered, [["steppe", Weather.Kind.SUN]], "drove into")
	s.step(-2)
	t.eq(s.valley().id, "carpathians", "A from the first: the last valley")
	s.free()


func test_esc_leaves_the_valley_for_the_screen(t: TCase) -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	t.tree.root.add_child(vp)
	var game = load("res://scripts/game.gd").new()
	game.profile_path = TEST_PATH
	vp.add_child(game)
	t.ok(game.screen != null and game.world == null, "the game does not open on the valleys")
	game.enter(Valley.khutir(), Weather.Kind.NIGHT)
	await t.ticks(5)
	t.ok(game.screen == null and game.world != null, "no valley after driving in")
	t.ok(game.world.weather.night, "the sky picked is not the one in play")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	game.world._unhandled_input(esc)
	await t.ticks(2)
	t.ok(game.screen != null and game.world == null, "Esc does not leave the valley for the screen")
	vp.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
