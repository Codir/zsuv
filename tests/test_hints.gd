extends RefCounted
## The hints a player needs where they are needed (docs/plan.md §1, §4, §5): where each need is
## had, in the P list and a site's line; in the tractor how to dig, slower when too fast, and to
## tip at the washout; in another truck at the washout, that the tractor fills it; and the old
## sawmill's message once the forest is found.

const B := preload("res://tests/test_building.gd")


func test_where_each_need_is_had(t: TCase) -> void:
	var infra: Infra = t.world.infra
	B._clear(infra)
	t.eq(infra.where("timber"), "the railhead's yard (4)", "timber")
	t.eq(infra.where("parts"), "the railhead", "parts")
	await t.place(Vector2(-40.0, -40.0), 0.0, 30)
	infra._press_p()
	await t.ticks(2)
	t.ok(infra.panel.contains("parts, fuel: the railhead") and infra.panel.contains("timber: the railhead's yard (4)"), "the P list: " + infra.panel)
	infra.mode = Infra.Mode.NONE
	var site := infra.place("fuel_station", B.spot(infra, "fuel_station", Vector2(-40.0, -40.0)), 0.0)
	if t.ok(site != null, "not placed"):
		t.ok(infra.ledger().has("Fuel station site: needs concrete 1 (a concrete plant, in the mixer), parts 1 (the railhead)"), "the ledger: %s" % [infra.ledger()])
	infra.railhead.stock["timber"] = 0.0
	t.eq(infra.where("timber"), "a sawmill", "timber once the railhead's is gone")
	B._clear(infra)


func test_the_tractor_is_told_how_to_dig_and_tip(t: TCase) -> void:
	var infra: Infra = t.world.infra
	B._clear(infra)
	var fill: Site = infra.sites.filter(func(s: Site) -> bool: return s.spec.id == "fill")[0]
	t.world.set_truck(TruckSpec.tractor())
	await t.ticks(2)
	var v: Vehicle = t.world.vehicle
	await t.place(Vector2(-40.0, -40.0), 0.0, 30)
	t.eq(infra.prompt, "Hold B and creep forward to dig into the tipper", "the tractor out on the land")
	Input.action_press("dig")
	v.forward_speed = 3.0  # 11 km/h
	t.eq(infra._dig_hint(), "Slower: under 6 km/h to dig", "digging too fast")
	Input.action_release("dig")
	var a: Vector3 = fill.ends[0]
	await t.place(Vector2(a.x, a.z), 0.0, 30)
	(v.get_node("Loader") as Loader).bucket_soil = 1.2
	await t.ticks(2)
	t.eq(infra.prompt, "Hold V to tip here", "with soil at the washout")
	(v.get_node("Loader") as Loader).bucket_soil = 0.0
	t.world.set_truck(TruckSpec.pickup())
	await t.ticks(2)
	await t.place(Vector2(a.x, a.z), 0.0, 30)
	t.eq(infra.prompt, "The tractor with its tipper fills this: dig earth with B, tip it with V", "the pickup at the washout")
	B._clear(infra)


func test_the_old_sawmill_is_told_once_the_forest_is_found(t: TCase) -> void:
	var infra: Infra = t.world.infra
	var land: Land = t.world.land
	B._clear(infra)
	infra.stats = {}
	var got: Array[String] = []
	var on_message := func(text: String) -> void: got.append(text)
	infra.message.connect(on_message)
	var mill: Site = infra.sites.filter(func(s: Site) -> bool: return s.key == "ruin:khutir:lumber")[0]
	land.fog.reveal(mill.at, 40.0)
	await t.ticks(70)
	t.eq(got.filter(func(m: String) -> bool: return m == "An old sawmill: parts 1 brings it back").size(), 1, "the old sawmill's message: %s" % [got])
	infra.message.disconnect(on_message)
	B._clear(infra)
