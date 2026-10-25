extends RefCounted
## The game is in English: no Cyrillic left in any script, shader or on screen.

const DIRS := ["res://scripts", "res://shaders", "res://scenes"]


func test_sources_are_english(t: TCase) -> void:
	var files := PackedStringArray()
	for d in DIRS:
		_collect(d, files)
	t.ok(files.size() > 10, "found only %d source files" % files.size())
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if _has_cyrillic(lines[i]):
				t.fail("%s:%d  %s" % [path, i + 1, lines[i].strip_edges()])


func test_screen_text_is_english(t: TCase) -> void:
	await t.ticks(2)
	var texts := PackedStringArray()
	for l in t.world.hud.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	for l in t.world.builder.find_children("*", "Label3D", true, false):
		texts.append((l as Label3D).text)
	texts.append(t.world.contracts.objective_text())
	texts.append(t.world.vehicle.winch.prompt())
	t.ok(texts.size() > 6, "found only %d texts" % texts.size())
	for s in texts:
		if _has_cyrillic(s):
			t.fail("on screen: " + s)


func _collect(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "gdshader", "gdshaderinc", "tscn"]:
			out.append(dir + "/" + f)
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + sub, out)


func _has_cyrillic(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x0400 and c <= 0x052F:
			return true
	return false
