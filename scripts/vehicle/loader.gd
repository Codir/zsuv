class_name Loader
extends Node3D
## The tractor's front loader and its tipper (docs/plan.md §4). Held B lowers the bucket, and
## while the tractor creeps (under CREEP) it bites the ground just ahead every BITE_EVERY s, into
## the hitched farm trailer (the tipper) or, without one, into the bucket itself. B tapped with a
## full bucket and no tipper drops its soil just ahead. Held V tips the tipper: its load pours out
## just behind it over POUR s; creeping, it spreads in a strip. Built from boxes like the tractor.

const CREEP := 6.0 / 3.6  # m/s
const BITE_EVERY := 0.4
const LEVEL_EVERY := 0.1
const BUCKET := 1.5  # m³ in the bucket itself
const TIPPER := 10.0  # m³ in the tipper
const POUR := 4.0  # s to tip a full tipper
const POUR_EVERY := 0.2
const GRAVEL_POUR := 12.0  # s a load of gravel takes to spread
const GRAVEL_WIDTH := 3.5  # m: the strip it spreads, half a road
const AHEAD := -3.3  # m along the tractor (its -z ahead) where the bucket bites
const BEHIND := 1.2  # m past the tipper's back where it pours

var vehicle: Vehicle
var land: Land
var bucket_soil := 0.0  # m³ in the bucket
var digging := false  # B held: the bucket down
var tipping := false  # V held
var message := ""  # why it did not dig or tip, for the HUD; "" when nothing to say
var _arms: Node3D
var _bucket_t := 0.0
var _pour_t := 0.0
var _tap := 0.0  # s B has been held, to tell a tap


func _ready() -> void:
	_arms = Node3D.new()
	add_child(_arms)
	var yellow := Color(0.86, 0.7, 0.16)
	for side in [-0.62, 0.62]:
		var arm := Psx.box(_arms, Vector3(0.12, 0.16, 2.4), Vector3(side, 0.3, -2.2), yellow)
		arm.rotation.x = 0.25
	Psx.box(_arms, Vector3(2.2, 0.7, 0.8), Vector3(0.0, -0.05, -3.4), Color(0.25, 0.25, 0.27))
	Psx.box(_arms, Vector3(2.2, 0.08, 0.9), Vector3(0.0, -0.42, -3.3), Color(0.35, 0.35, 0.37))
	_arms.position.y = 0.0


## The tipper hitched: the farm trailer, or null.
func tipper() -> Trailer:
	return vehicle.trailer if vehicle.trailer and vehicle.trailer.spec.id == "farm" else null


## m³ of soil in the tipper t (its hold's).
static func soil_in(t: Trailer) -> float:
	return t.hold.holding("soil") if t else 0.0


## Puts m³ of soil in the tipper t, its weight and its heap with it (its hold).
static func set_soil(t: Trailer, m3: float) -> void:
	t.hold.take("soil")
	if m3 > 0.0001:
		t.hold.put("soil", m3)


## What the HUD shows of it: the load and why it stopped, if it did.
func status() -> String:
	var t := tipper()
	var line := (t.hold.text() if not t.hold.is_empty() else "TIPPER EMPTY") if t else "BUCKET %.1f/%.1f m3" % [bucket_soil, BUCKET]
	return line + ("  " + message if message != "" else "")


func _physics_process(delta: float) -> void:
	if land == null:
		return
	var keys := not vehicle.autodrive
	var dig_held := Input.is_action_pressed("dig") if keys else digging
	var tip_held := Input.is_action_pressed("tip") if keys else tipping
	if keys:
		digging = dig_held
		tipping = tip_held
	# The bucket hangs low while B is held and rises when it is let go.
	_arms.position.y = move_toward(_arms.position.y, -0.55 if digging else 0.25, delta * 2.0)
	if digging:
		_tap += delta
		_bucket_t += delta
		if vehicle.forward_speed < -0.2:
			# Backing with the bucket down drags it at the wheels' level: humps shaved, hollows filled.
			if _bucket_t >= LEVEL_EVERY:
				_bucket_t = 0.0
				_level()
		elif _bucket_t >= BITE_EVERY:
			_bucket_t = 0.0
			_bite()
	else:
		if _tap > 0.0 and _tap < 0.3 and tipper() == null and bucket_soil > 0.0:
			_drop_bucket()
		_tap = 0.0
		_bucket_t = BITE_EVERY  # the first bite comes at once
	if tipping:
		_pour_t += delta
		if _pour_t >= POUR_EVERY:
			_pour_t = 0.0
			_pour()
	else:
		_pour_t = POUR_EVERY


func _bite() -> void:
	if absf(vehicle.forward_speed) > CREEP:
		message = "Too fast to dig"
		return
	var t := tipper()
	var room := t.hold.room("soil") if t else BUCKET - bucket_soil
	if room <= 0.01:
		if t and not t.hold.is_empty() and t.hold.kind != "soil":
			message = "The tipper has %s on: tip it first" % t.hold.kind
		else:
			message = "The tipper is full: tip it with V" if t else "The bucket is full"
		return
	var at := _ground_point(Vector3(0.0, 0.0, AHEAD))
	var why := land.earthworks.why_not(at)
	if why != "":
		message = why
		return
	var fwd := -vehicle.global_transform.basis.z
	# Into a face higher than the wheels the bucket shaves it down to where they stand; on the
	# level it bites a little lower each pass.
	var blade := _blade()
	if blade > -INF and land.get_height(at.x, at.y) > blade + 2.0 * Earthworks.BITE_DEPTH:
		blade += Earthworks.BITE_DEPTH
	var got := land.earthworks.bite(at, Vector2(fwd.x, fwd.z), Earthworks.BITE_DEPTH, blade)
	if got > room:  # a bite never overfills: the rest goes back
		land.earthworks.dump(at, got - room)
		got = room
	message = "" if got > 0.0 else "Nothing more to dig here"
	if t:
		set_soil(t, soil_in(t) + got)
	else:
		bucket_soil += got


func _level() -> void:
	var at := _ground_point(Vector3(0.0, 0.0, AHEAD))
	var fwd := -vehicle.global_transform.basis.z
	var blade := _blade()
	if blade == -INF:
		return
	bucket_soil = land.earthworks.level(at, Vector2(fwd.x, fwd.z), blade + Earthworks.BITE_DEPTH, bucket_soil, BUCKET)
	message = ""


func _drop_bucket() -> void:
	var at := _ground_point(Vector3(0.0, 0.0, AHEAD))
	var placed := land.earthworks.dump(at, bucket_soil)
	bucket_soil -= placed
	message = land.earthworks.why_not(at) if placed <= 0.0 else ""


func _pour() -> void:
	var t := tipper()
	if t == null:
		message = "No tipper hitched"
		return
	var back := t.spec.extent().end.z + BEHIND
	var at3 := t.global_transform * Vector3(0.0, 0.0, back)
	var at := Vector2(at3.x, at3.z)
	if t.hold.kind == "gravel":  # spread in a strip behind it as it creeps: a gravel road
		var why := land.earthworks.spread_gravel(at, GRAVEL_WIDTH * 0.5)
		message = why
		if why == "":
			t.hold.take("gravel", POUR_EVERY / GRAVEL_POUR)
		return
	var left := soil_in(t)
	if left <= 0.0:
		message = "The tipper is empty"
		return
	var placed := land.earthworks.dump(at, minf(left, TIPPER * POUR_EVERY / POUR))
	if placed <= 0.0:
		message = land.earthworks.why_not(at) if land.earthworks.why_not(at) != "" else "No room for more here"
		return
	message = ""
	set_soil(t, left - placed)


## How low the bucket's edge goes: BITE_DEPTH under the ground its front wheels stand on, so it
## digs a little lower each pass and shaves a heap ahead down to where the tractor is.
func _blade() -> float:
	var low := INF
	for w in vehicle.wheels:
		if w.front and w.contact:
			low = minf(low, w.point.y)
	if low == INF:
		return -INF
	return low - Earthworks.BITE_DEPTH


## The point p in the tractor's frame, on the map (x, z).
func _ground_point(p: Vector3) -> Vector2:
	var w := vehicle.global_transform * p
	return Vector2(w.x, w.z)
