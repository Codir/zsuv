class_name TruckAudio
extends Node3D
## The truck's sound: the diesel through a gearbox that exists only for the ear, the tyres
## crunching snow and squelching mud, the winch motor. docs/sound.md names the recordings.
## Every player streams (PLAYBACK_TYPE_STREAM): as browser samples, loops restarted 10-80 ms late.

const IDLE := preload("res://sounds/engine_idle.ogg")
const LABOUR := preload("res://sounds/engine_labour.ogg")
const MOTOR := preload("res://sounds/winch.ogg")
const SNOW_HITS := 8
const MUD_HITS := 16

const IDLE_RPM := 800.0  # pitch 1: the recording's idle
const SHIFT_RPM := 1800.0  # at a gear's top speed; above it the next gear takes over
const MAX_RPM := 2000.0
const LAUNCH_RPM := 400.0  # over idle at full throttle with the truck standing: the clutch slips
## The top speed of each gear, m/s: four in high range, two in low range (more revs for the
## speed: the truck sounds like it is working), and reverse.
# Each gear's top speed as a share of the truck's top speed in high and in low range (the pickup:
# 3.5, 7, 11.5 and 18 m/s; 2.5 and 5.5).
const HIGH_GEARS: Array[float] = [3.5 / 18.0, 7.0 / 18.0, 11.5 / 18.0, 1.0]
const LOW_GEARS: Array[float] = [2.5 / 5.5, 1.0]
const DOWNSHIFT := 0.8  # down a gear below this share of the lower gear's top speed
const ENGINE_DB := 0.0
const SNOW_DB := -1.0
const MUD_DB := -3.0
const WINCH_DB := -4.0
const SNOW_STEP := 0.9  # metres a tread rolls per crunch
const MUD_STEP := 1.3
const MIN_TREAD := 0.3  # m/s: slower than this a wheel makes no sound
const MAX_HITS := 12.0  # a second, all four wheels together

var vehicle: Vehicle
var rpm := IDLE_RPM
var gear := 1  # -1 is reverse
var labour := 0.0  # 0..1: how hard the engine works for how little the truck moves
var running := true
var snow_hits := 0
var mud_hits := 0

var idle: AudioStreamPlayer3D
var growl: AudioStreamPlayer3D
var motor: AudioStreamPlayer3D
var snow: AudioStreamPlayer3D
var mud: AudioStreamPlayer3D

var _gain := 1.0
var _motor_gain := 0.0
var _snow_due := 0.0
var _mud_due := 0.0


func _ready() -> void:
	var front := Vector3(0.0, 0.4, -1.7)
	idle = _player(IDLE, &"Engine", front)
	growl = _player(LABOUR, &"Engine", front)
	motor = _player(MOTOR, &"Sfx", vehicle.spec.winch_mount)
	snow = _player(_randomizer("snow", SNOW_HITS), &"Sfx", Vector3.ZERO)
	mud = _player(_randomizer("mud", MUD_HITS), &"Sfx", Vector3.ZERO)
	snow.max_polyphony = 4
	mud.max_polyphony = 4
	_start_engine()


func _physics_process(delta: float) -> void:
	_engine(delta)
	_tyres(delta)
	_winch(delta)


## Revs from the speed in the gear the speed calls for, or from the fastest driven tread when a
## wheel spins; the labouring layer rises with the throttle and with how little the truck moves
## for it. On an empty tank the engine runs down and goes quiet.
func _engine(delta: float) -> void:
	var v := vehicle
	var speed := absf(v.forward_speed)
	var throttle := absf(v.drive)
	var gears: Array[float] = []
	for share in LOW_GEARS if v.low_range else HIGH_GEARS:
		gears.append(share * (v.spec.max_speed_low if v.low_range else v.spec.max_speed_high))
	if v.drive < 0.0 or v.forward_speed < -0.5:
		gear = -1
	else:
		gear = clampi(gear, 1, gears.size())
		while gear < gears.size() and speed > gears[gear - 1]:
			gear += 1
		while gear > 1 and speed < gears[gear - 2] * DOWNSHIFT:
			gear -= 1
	var top := v.spec.max_speed_reverse if gear < 0 else gears[gear - 1]
	var tread := speed
	for w in v.wheels:
		if v.awd or w.drive2:
			tread = maxf(tread, absf(w.spin_speed) * w.radius)
	var target := minf(maxf(IDLE_RPM + throttle * LAUNCH_RPM, tread / top * SHIFT_RPM), MAX_RPM)
	var work := throttle * (0.3 + 0.7 * (1.0 - clampf(speed / top, 0.0, 1.0)))
	running = v.fuel > 0.0
	if not running:
		target = 0.0
		work = 0.0
	rpm = lerpf(rpm, target, 1.0 - exp(-delta * (8.0 if target > rpm else 5.0)))
	labour = lerpf(labour, work, 1.0 - exp(-delta * 6.0))
	_gain = move_toward(_gain, 1.0 if running else 0.0, delta * (2.0 if running else 0.8))
	if _gain <= 0.0:
		if idle.playing:
			idle.stop()
			growl.stop()
		return
	if not idle.playing:
		_start_engine()
	var pitch := clampf(rpm / IDLE_RPM, 0.4, MAX_RPM / IDLE_RPM) * v.spec.engine_pitch
	var g := _gain * lerpf(0.7, 1.0, clampf(maxf(throttle, (rpm - IDLE_RPM) / (SHIFT_RPM - IDLE_RPM)), 0.0, 1.0))
	idle.pitch_scale = pitch
	growl.pitch_scale = pitch
	idle.volume_db = ENGINE_DB + linear_to_db(maxf(g * (1.0 - 0.6 * labour), 0.0001))
	growl.volume_db = ENGINE_DB + linear_to_db(maxf(g * labour, 0.0001))


## Both layers start together, so one loop's bar lines up with the other's.
func _start_engine() -> void:
	idle.play()
	growl.play()


## Each wheel on the ground adds crunches (snow) or squelches (mud) at a rate that follows its
## tread, spin included; they play as loud as the snow is deep or the mud wet.
func _tyres(delta: float) -> void:
	var snow_rate := 0.0
	var mud_rate := 0.0
	var snow_depth := 0.0
	var mud_depth := 0.0
	for w in vehicle.wheels:
		var tread := absf(w.spin_speed) * w.radius
		if not w.contact or tread < MIN_TREAD:
			continue
		var s := w.surface
		if s.mud > 0.1 and s.mud > s.snow:
			mud_rate += tread / MUD_STEP
			mud_depth = maxf(mud_depth, s.mud)
		elif s.snow > 0.05 and _layer_heard():
			snow_rate += tread / SNOW_STEP
			snow_depth = maxf(snow_depth, s.snow)
	_snow_due += minf(snow_rate, MAX_HITS) * delta
	_mud_due += minf(mud_rate, MAX_HITS) * delta
	if _snow_due >= 1.0:
		_snow_due -= 1.0
		snow.volume_db = SNOW_DB + linear_to_db(clampf(snow_depth / 0.4, 0.3, 1.0))
		snow.play()
		snow_hits += 1
	if _mud_due >= 1.0:
		_mud_due -= 1.0
		mud.volume_db = MUD_DB + linear_to_db(clampf(mud_depth, 0.3, 1.0))
		mud.play()
		mud_hits += 1


## Snow crunches under a tyre; a dry road's dust does not.
func _layer_heard() -> bool:
	return vehicle.terrain == null or vehicle.terrain.valley.layer != "dust"


## The motor runs while the winch reels in, lower as the cable takes the strain.
func _winch(delta: float) -> void:
	var w := vehicle.winch
	_motor_gain = move_toward(_motor_gain, 1.0 if w.reeling else 0.0, delta * 6.0)
	if _motor_gain <= 0.0:
		if motor.playing:
			motor.stop()
		return
	if not motor.playing:
		motor.play()
	var strain := clampf(w.tension / Winch.MAX_FORCE, 0.0, 1.0)
	motor.pitch_scale = lerpf(motor.pitch_scale, lerpf(1.1, 0.75, strain), 1.0 - exp(-delta * 4.0))
	motor.volume_db = WINCH_DB + linear_to_db(maxf(_motor_gain, 0.0001))


func _player(stream: AudioStream, bus: StringName, at: Vector3) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = bus
	p.position = at
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	# Panned to where the truck is from the camera, but as loud at 2 m (a tree pulls the camera
	# in) as at 25: the volume is the truck's, not the distance's.
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.attenuation_filter_cutoff_hz = 20500.0
	add_child(p)
	return p


func _randomizer(prefix: String, count: int) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	r.random_pitch = 1.15
	r.random_volume_offset_db = 2.0
	for i in count:
		r.add_stream(-1, load("res://sounds/%s_%02d.ogg" % [prefix, i + 1]))
	return r
