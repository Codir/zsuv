class_name BuildingSpec
extends RefCounted
## A kind of building the player places with P (docs/plan.md §5): what it needs brought to stand,
## where it may go, what it holds and what it makes. Every number is a first guess.

var id := ""
var title := ""
var needs := {}  # resource -> loads, brought to its site
var size := Vector2(10.0, 8.0)  # its footprint, across and along, m
var tank := 0.0  # litres of fuel it holds; 0: none
var makes := ""  # the resource it makes; "" nothing
var period := 0.0  # seconds a load takes to make
var burns := 0.0  # litres a load made burns
var holds := 0.0  # loads of what it makes it keeps, at most
var takes := {}  # resource -> loads of it that it keeps to make with (a concrete plant's gravel)
var yard := 0.0  # loads of anything it keeps in its yard (an outpost); 0: no yard
var trees := 0  # trees it needs within TREE_REACH
var deposit := false  # it goes only on a gravel deposit
var color := Color(0.7, 0.6, 0.4)

const TREE_REACH := 40.0


static func all() -> Array[BuildingSpec]:
	return [fuel_station(), sawmill(), quarry(), plant(), outpost()]


## The placeable ones and the railhead.
static func find(spec_id: String) -> BuildingSpec:
	for s in all():
		if s.id == spec_id:
			return s
	match spec_id:
		"railhead":
			return railhead()
		"village":
			return village()
	return null


static func fuel_station() -> BuildingSpec:
	var s := BuildingSpec.new()
	s.id = "fuel_station"
	s.title = "Fuel station"
	s.needs = {"concrete": 1, "parts": 1}
	s.size = Vector2(10.0, 8.0)
	s.tank = 2000.0
	s.color = Color(0.85, 0.35, 0.15)
	return s


static func sawmill() -> BuildingSpec:
	var s := BuildingSpec.new()
	s.id = "sawmill"
	s.title = "Sawmill"
	s.needs = {"parts": 2, "timber": 1, "gravel": 1}
	s.size = Vector2(16.0, 12.0)
	s.tank = 300.0
	s.makes = "timber"
	s.period = 120.0
	s.burns = 30.0
	s.holds = 3.0
	s.trees = 12
	s.color = Color(0.55, 0.38, 0.22)
	return s


static func quarry() -> BuildingSpec:
	var s := BuildingSpec.new()
	s.id = "quarry"
	s.title = "Quarry"
	s.needs = {"parts": 1, "timber": 1}
	s.size = Vector2(14.0, 14.0)
	s.tank = 300.0
	s.makes = "gravel"
	s.period = 90.0
	s.burns = 20.0
	s.holds = 3.0
	s.deposit = true
	s.color = Color(0.5, 0.5, 0.48)
	return s


static func plant() -> BuildingSpec:
	var s := BuildingSpec.new()
	s.id = "plant"
	s.title = "Concrete plant"
	s.needs = {"parts": 2, "timber": 2, "gravel": 1}
	s.size = Vector2(12.0, 10.0)
	s.tank = 300.0
	s.makes = "concrete"
	s.burns = 10.0
	s.takes = {"gravel": 4}
	s.color = Color(0.62, 0.62, 0.6)
	return s


static func outpost() -> BuildingSpec:
	var s := BuildingSpec.new()
	s.id = "outpost"
	s.title = "Outpost"
	s.needs = {"parts": 2, "timber": 2, "concrete": 1}
	s.size = Vector2(20.0, 16.0)
	s.tank = 1000.0
	s.yard = 6.0
	s.color = Color(0.35, 0.5, 0.4)
	return s


## The first base, built from the start: fuel and parts that never run out, a concrete plant
## with gravel in it, a garage, and timber in its yard.
static func railhead() -> BuildingSpec:
	var s := BuildingSpec.new()
	s.id = "railhead"
	s.title = "Railhead"
	s.size = Vector2(24.0, 24.0)
	s.makes = "concrete"
	s.takes = {"gravel": 4}
	s.yard = 6.0
	return s


## What it does, said when it stands.
func does() -> String:
	match id:
		"fuel_station":
			return "it holds %d L of fuel: bring fuel with E, fill up with E" % roundi(tank)
		"sawmill":
			return "it makes timber from the trees about it while it has fuel"
		"quarry":
			return "it makes gravel while it has fuel"
		"plant":
			return "bring it gravel, and it pours concrete into a mixer under its chute"
		"outpost":
			return "a base: a garage, a tank and a yard"
	return ""


## The goal (docs/plan.md §1): the upper village, cut off in the mountains, asks for fuel and
## parts. It is found, not placed, and the end card shows when its needs are in.
static func village() -> BuildingSpec:
	var s := BuildingSpec.new()
	s.id = "village"
	s.title = "Upper village"
	s.needs = {"fuel": 800, "parts": 2}
	s.size = Vector2(16.0, 16.0)
	return s


## A road site the land has (Land.site_spots, docs/plan.md §5): staked where it is, not placed. A
## bridge is built from the loads it needs and its deck put up; a fill, a landslide and a gravel road
## are done when the ground along them is (Land.corridor_state), and need nothing brought by E.
static func road_site(spot: Dictionary) -> BuildingSpec:
	var s := BuildingSpec.new()
	s.id = str(spot.kind)
	s.title = {"bridge": "Bridge", "fill": "Fill", "slide": "Landslide", "gravel_road": "Gravel road"}.get(s.id, "Road")
	s.needs = (spot.get("needs", {}) as Dictionary).duplicate() if s.id == "bridge" else {}
	var a: Vector3 = spot.a
	var b: Vector3 = spot.b
	s.size = Vector2(9.0, Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) + 2.0)
	s.color = Color(0.5, 0.36, 0.22)
	return s
