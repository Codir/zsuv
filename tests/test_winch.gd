extends RefCounted
## The winch hooks onto a tree or rock ahead and pulls the truck towards it.


func test_winch_pulls(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var winch := v.winch
	await t.place(Vector2(-40.0, -60.0), 0.0)
	v.set_cargo(true)
	v.fuel = v.spec.fuel_capacity
	if not t.ok(winch.candidate >= 0, "no anchor in range"):
		return
	t.ok(winch.prompt().begins_with("[F] Winch to anchor"), "prompt: " + winch.prompt())
	var anchor := winch.anchors[winch.candidate]
	var d0 := winch.mount_position().distance_to(anchor)
	winch.toggle()
	t.ok(winch.attached, "attached")
	winch.auto_reel = true
	var max_tension := 0.0
	for i in 240:
		await t.tree.physics_frame
		max_tension = maxf(max_tension, winch.tension)
	winch.auto_reel = false
	var d1 := winch.mount_position().distance_to(anchor)
	t.note = "%.1f m -> %.1f m, peak %.0f kN" % [d0, d1, max_tension / 1000.0]
	t.ok(winch.length < d0 - 2.0, "cable reeled in: %.1f of %.1f m" % [winch.length, d0])
	t.ok(max_tension > 1000.0, "cable never pulled: %.0f N" % max_tension)
	t.ok(d1 < d0 - 1.0, "truck not pulled: %.1f -> %.1f m" % [d0, d1])
	winch.toggle()
	t.ok(not winch.attached, "unhooked")
	v.set_cargo(false)
