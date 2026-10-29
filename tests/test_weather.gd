extends RefCounted
## Every valley has its own sky, and four more to switch to: sun, overcast, snow or rain by its
## season, night. The sky in play changes when it is switched.


func test_every_valley_has_every_sky(t: TCase) -> void:
	for v in Valley.all():
		t.ok(v.own != null and v.own.name != "", "%s has no sky of its own" % v.id)
		t.ok(Weather.make(Weather.Kind.OWN, v) == v.own, "%s: OWN is not its own sky" % v.id)
		var sun := Weather.make(Weather.Kind.SUN, v)
		var night := Weather.make(Weather.Kind.NIGHT, v)
		var fall := Weather.make(Weather.Kind.FALL, v)
		t.ok(night.sky.get_luminance() < sun.sky.get_luminance() * 0.3, "%s: night is not dark" % v.id)
		t.ok(night.night and not sun.night, "%s: night is not night" % v.id)
		t.eq(sun.fall, "none", "%s: what falls in the sun" % v.id)
		t.eq(fall.fall, "snow" if v.season == "winter" else "rain", "%s (%s): what falls" % [v.id, v.season])
		t.ok(fall.fall_amount > 0, "%s: nothing falls" % v.id)
		for k in Weather.Kind.values():
			t.ok(Weather.label(k, v) != "", "%s: kind %d has no name" % [v.id, k])


func test_the_sky_switches_in_play(t: TCase) -> void:
	var world = t.world
	var own: Weather = world.weather
	world.apply_weather(Weather.make(Weather.Kind.NIGHT, world.valley))
	await t.ticks(2)
	t.eq(world._env.background_color, Weather.make(Weather.Kind.NIGHT, world.valley).sky, "night sky")
	t.ok(world._fall == null, "something falls on a clear night")
	world.apply_weather(Weather.make(Weather.Kind.FALL, world.valley))
	await t.ticks(2)
	t.ok(world._fall != null and world._fall.amount > 0, "nothing falls in snow or rain")
	world.apply_weather(own)
	await t.ticks(2)
	t.ok(absf(world._env.fog_density - own.fog_density) < 0.0001, "fog %.4f, its own %.4f" % [world._env.fog_density, own.fog_density])
	t.ok(world._fall != null, "its own snowfall is gone")
