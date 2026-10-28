extends RefCounted
## The controls help: a small hint in a corner by default, the full card and nothing on F1.


func test_the_hint_keeps_to_its_corner(t: TCase) -> void:
	var hud: Hud = t.world.hud
	hud.set_help(Hud.Help.HINT)
	await t.ticks(2)
	var hint := _label(hud, Hud.HINT_TEXT)
	var card := _label(hud, Hud.HELP_TEXT)
	var status := _label_containing(hud, "km/h")
	if not (t.ok(hint != null, "no hint label") and t.ok(card != null, "no help card") and t.ok(status != null, "no dashboard")):
		return
	t.ok(hint.visible and not card.visible, "the hint is not what shows first")
	var screen := hud.get_viewport().get_visible_rect()
	var hint_rect := Rect2(hint.position, hint.get_minimum_size())
	var card_rect := Rect2(card.position, card.get_minimum_size())
	t.note = "hint %dx%d px, the card was %dx%d" % [hint_rect.size.x, hint_rect.size.y, card_rect.size.x, card_rect.size.y]
	t.ok(screen.encloses(hint_rect), "the hint runs off the screen: %s" % hint_rect)
	t.ok(hint_rect.get_area() < card_rect.get_area() * 0.3, "the hint covers %.0f%% of what the card did"
		% (hint_rect.get_area() / card_rect.get_area() * 100.0))
	t.ok(not hint_rect.intersects(Rect2(status.position, status.get_minimum_size())), "the hint overlaps the dashboard")


func test_f1_steps_through_hint_card_and_nothing(t: TCase) -> void:
	var hud: Hud = t.world.hud
	hud.set_help(Hud.Help.HINT)
	var hint := _label(hud, Hud.HINT_TEXT)
	var card := _label(hud, Hud.HELP_TEXT)
	var seen: Array[String] = []
	for i in 4:
		Input.parse_input_event(_f1())
		await t.ticks(2)
		seen.append("hint" if hint.visible else "card" if card.visible else "none")
	t.eq(seen, ["card", "none", "hint", "card"] as Array[String], "after each F1")
	hud.set_help(Hud.Help.HINT)


func _f1() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"toggle_help"
	ev.pressed = true
	return ev


func _label(hud: Hud, text: String) -> Label:
	for l in hud.find_children("*", "Label", true, false):
		if (l as Label).text == text:
			return l
	return null


func _label_containing(hud: Hud, part: String) -> Label:
	for l in hud.find_children("*", "Label", true, false):
		if (l as Label).text.contains(part):
			return l
	return null
