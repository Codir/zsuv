class_name Weather
extends RefCounted
## The sky over a valley: its light, its fog and what falls from it. Every valley has its own
## (OWN); the start screen can switch it to sun, overcast, snow or rain (by the valley's season)
## or night.

enum Kind { OWN, SUN, OVERCAST, FALL, NIGHT }

var name := ""
var sky := Color(0.3, 0.34, 0.43)
var fog := Color(0.38, 0.42, 0.5)
var fog_density := 0.022
var ambient := Color(0.55, 0.6, 0.75)
var ambient_energy := 0.55
var sun := Color(0.85, 0.88, 1.0)
var sun_energy := 0.55
var sun_angle := Vector3(-35.0, 40.0, 0.0)  # degrees
var fall := "snow"  # snow | rain | none
var fall_amount := 900
var wind := 0.2  # sideways drift of what falls, m/s
var night := false  # the truck's headlights matter


## What the start screen calls a kind in valley v: "snow" or "rain" for FALL by its season.
static func label(kind: Kind, v: Valley) -> String:
	match kind:
		Kind.OWN:
			return v.own.name
		Kind.SUN:
			return "sun"
		Kind.OVERCAST:
			return "overcast"
		Kind.FALL:
			return "snow" if v.season == "winter" else "rain"
	return "night"


static func make(kind: Kind, v: Valley) -> Weather:
	if kind == Kind.OWN:
		return v.own
	var w := Weather.new()
	w.name = label(kind, v)
	var winter := v.season == "winter"
	w.fall = "none"
	w.fall_amount = 0
	match kind:
		Kind.SUN:
			w.sky = Color(0.58, 0.72, 0.92) if not winter else Color(0.62, 0.74, 0.9)
			w.fog = Color(0.78, 0.82, 0.88)
			w.fog_density = 0.005
			w.ambient = Color(0.72, 0.74, 0.78)
			w.ambient_energy = 0.7
			w.sun = Color(1.0, 0.94, 0.82)
			w.sun_energy = 1.15
			w.sun_angle = Vector3(-48.0, 35.0, 0.0)
		Kind.OVERCAST:
			w.sky = Color(0.5, 0.52, 0.55)
			w.fog = Color(0.56, 0.58, 0.6)
			w.fog_density = 0.016
			w.ambient = Color(0.62, 0.64, 0.68)
			w.ambient_energy = 0.65
			w.sun = Color(0.85, 0.86, 0.88)
			w.sun_energy = 0.35
			w.sun_angle = Vector3(-60.0, 20.0, 0.0)
		Kind.FALL:
			w.sky = Color(0.4, 0.42, 0.46)
			w.fog = Color(0.46, 0.48, 0.52)
			w.fog_density = 0.028
			w.ambient = Color(0.55, 0.58, 0.64)
			w.ambient_energy = 0.6
			w.sun = Color(0.8, 0.82, 0.86)
			w.sun_energy = 0.3
			w.sun_angle = Vector3(-60.0, 20.0, 0.0)
			w.fall = "snow" if winter else "rain"
			w.fall_amount = 1400
			w.wind = 0.8
		Kind.NIGHT:
			w.sky = Color(0.03, 0.04, 0.08)
			w.fog = Color(0.05, 0.06, 0.1)
			w.fog_density = 0.02
			w.ambient = Color(0.25, 0.3, 0.45)
			w.ambient_energy = 0.3
			w.sun = Color(0.6, 0.68, 0.9)  # the moon
			w.sun_energy = 0.12
			w.sun_angle = Vector3(-40.0, 120.0, 0.0)
			w.night = true
	return w


## The khutir valley's own: a winter dusk with the snow coming down, as the game always was.
static func dusk() -> Weather:
	var w := Weather.new()
	w.name = "winter dusk"
	return w


## a's sky going over into b's, t of the way (a border crossed, docs/plan.md §3): the colours, the
## light and the fog blend; what falls is a's up to halfway and b's after, its amount blending
## from none on the side where nothing falls.
static func mix(a: Weather, b: Weather, t: float) -> Weather:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	var w := Weather.new()
	w.name = a.name if t < 0.5 else b.name
	w.sky = a.sky.lerp(b.sky, t)
	w.fog = a.fog.lerp(b.fog, t)
	w.fog_density = lerpf(a.fog_density, b.fog_density, t)
	w.ambient = a.ambient.lerp(b.ambient, t)
	w.ambient_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
	w.sun = a.sun.lerp(b.sun, t)
	w.sun_energy = lerpf(a.sun_energy, b.sun_energy, t)
	w.sun_angle = a.sun_angle.lerp(b.sun_angle, t)
	var main := a if t < 0.5 else b
	w.fall = main.fall if main.fall != "none" else (b.fall if t < 0.5 else a.fall)
	var amount_a := a.fall_amount if a.fall == w.fall else 0
	var amount_b := b.fall_amount if b.fall == w.fall else 0
	w.fall_amount = roundi(lerpf(amount_a, amount_b, t))
	w.wind = lerpf(a.wind, b.wind, t)
	w.night = a.night if t < 0.5 else b.night
	return w
