class_name MapScreen
extends CanvasLayer
## The paper map on M (docs/plan.md §3, "Fog"): relief with contour lines, roads, snow and mud,
## forest, drawn for the whole map once and redrawn where the ground is dug; fogged paper is blank
## with a pencil hatch, and the map draws itself as the land's Fog is uncovered. It opens on the
## biome the truck is in, 256 m across MAP_SIZE px; the wheel or Z zooms out to the whole map, where
## each biome found is named. On it: the places found, the target, the truck, the trail behind it,
## and the scout's track, dashed, for the heavy rigs to follow.

const MAP_SIZE := 240.0
const PAPER := Color(0.93, 0.88, 0.76)
const INK := Color(0.22, 0.17, 0.12)
const TRAIL_STEP := 3.0
const TRAIL_MAX := 3000
const TRACK_COLOR := Color(0.15, 0.35, 0.85, 0.9)
const FOG_SHADER := """
shader_type canvas_item;
uniform vec4 paper : source_color;
uniform vec4 ink : source_color;
void fragment() {
	float seen = texture(TEXTURE, UV).r;
	// A pencil hatch on blank paper: thin diagonal strokes every 6 px.
	float stroke = step(5.0, mod(FRAGCOORD.x + FRAGCOORD.y, 6.0));
	vec3 c = mix(paper.rgb, ink.rgb, stroke * 0.18);
	COLOR = vec4(c, 1.0 - smoothstep(0.35, 0.65, seen));
}
"""

var land: Land
var terrain: Terrain  # the home tile (the first map drew only it)
var vehicle: Vehicle
var contracts: Contracts
var locations: Dictionary
var whole := false  # zoomed out to the whole map
var scout_track := PackedVector2Array()  # where the scout has been, kept (docs/plan.md §3)

var _canvas: Control
var _fog_rect: TextureRect
var _over: Control
var _tex: ImageTexture
var _img: Image  # the whole map, 1 px a metre
var _fog_img: Image  # the fog, a pixel a Fog.TEXEL
var _fog_tex: ImageTexture
var _fog_dirty := true
var _view := Rect2()  # the world shown
var _rect := Rect2()  # where on the screen
var _trail := PackedVector2Array()
var _trees := PackedVector2Array()
var _bounds := Rect2()
var _drawn := false


func setup(l: Land, v: Vehicle, c: Contracts, locs: Dictionary, trees: PackedVector2Array) -> void:
	land = l
	terrain = l.home
	vehicle = v
	contracts = c
	locations = locs
	_trees = l.tree_points if not l.tree_points.is_empty() else trees
	layer = 3
	visible = false
	_bounds = l.bounds()
	_img = Image.create_empty(int(_bounds.size.x), int(_bounds.size.y), false, Image.FORMAT_RGBA8)
	_img.fill(PAPER)
	if l.paper.size() == _img.get_data().size():  # drawn at the bake
		_img.set_data(_img.get_width(), _img.get_height(), false, Image.FORMAT_RGBA8, l.paper)
		_drawn = true
	_tex = ImageTexture.create_from_image(_img)
	for t in l.tiles:
		t.ground_changed.connect(_on_ground_changed.bind(t))
	_fog_img = Image.create_empty(int(_bounds.size.x / Fog.TEXEL), int(_bounds.size.y / Fog.TEXEL), false, Image.FORMAT_L8)
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	l.fog.changed.connect(func() -> void: _fog_dirty = true)

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)
	_fog_rect = TextureRect.new()
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_fog_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FOG_SHADER
	m.shader = sh
	m.set_shader_parameter("paper", PAPER)
	m.set_shader_parameter("ink", INK)
	_fog_rect.material = m
	_canvas.add_child(_fog_rect)
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_on_draw_over)
	_canvas.add_child(_over)


func toggle() -> void:
	visible = not visible
	if visible:
		whole = false
		if not _drawn:  # drawn the first time it opens: a second or so, not at every start
			_drawn = true
			for t in land.tiles:
				_render(t, Rect2i(0, 0, Terrain.SIZE, Terrain.SIZE))
			_tex.update(_img)


func zoom() -> void:
	whole = not whole


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_Z:
		zoom()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			whole = mb.button_index == MOUSE_BUTTON_WHEEL_DOWN
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var p := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(p) > TRAIL_STEP:
		_trail.append(p)
		if _trail.size() > TRAIL_MAX:
			_trail.remove_at(0)
	if vehicle.spec.id == "scout" and (scout_track.is_empty() or scout_track[scout_track.size() - 1].distance_to(p) > TRAIL_STEP):
		scout_track.append(p)
	if visible:
		if _fog_dirty:
			_update_fog()
		_canvas.queue_redraw()
		_over.queue_redraw()


func _update_fog() -> void:
	_fog_dirty = false
	for t in land.tiles:
		var m: PackedByteArray = land.fog.masks[t.valley.id]
		var o := Vector2i(((t.origin - Vector2.ONE * Terrain.HALF - _bounds.position) / Fog.TEXEL).round())
		var img := Image.create_from_data(Fog.RES, Fog.RES, false, Image.FORMAT_L8, m)
		_fog_img.blit_rect(img, Rect2i(0, 0, Fog.RES, Fog.RES), o)
	_fog_tex.update(_fog_img)


func _to_map(p: Vector2) -> Vector2:
	return _rect.position + (p - _view.position) / _view.size * _rect.size


func _on_draw() -> void:
	var vp := _canvas.size
	var p := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	if whole:
		var s := minf(MAP_SIZE / _bounds.size.y, (vp.x * 0.55) / _bounds.size.x)
		_view = _bounds
		_rect = Rect2(Vector2(16.0, (vp.y - _bounds.size.y * s) * 0.5), _bounds.size * s)
	else:
		var t := land.tile_at(p.x, p.y)
		_view = Rect2(t.origin - Vector2.ONE * Terrain.HALF, Vector2.ONE * Terrain.SIZE)
		_rect = Rect2(Vector2(16.0, (vp.y - MAP_SIZE) * 0.5), Vector2.ONE * MAP_SIZE)
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.6))
	_canvas.draw_rect(_rect.grow(5.0), PAPER)
	_canvas.draw_texture_rect_region(_tex, _rect, Rect2(_view.position - _bounds.position, _view.size))
	var atlas := AtlasTexture.new()
	atlas.atlas = _fog_tex
	atlas.region = Rect2((_view.position - _bounds.position) / Fog.TEXEL, _view.size / Fog.TEXEL)
	_fog_rect.texture = atlas
	_fog_rect.position = _rect.position
	_fog_rect.size = _rect.size


func _on_draw_over() -> void:
	var font := Psx.font()
	var fog := land.fog
	_over.draw_rect(_rect, INK, false, 1.0)
	# The trail driven so far, and the scout's track, dashed.
	if _trail.size() > 1:
		var pts := PackedVector2Array()
		for q in _trail:
			pts.append(_to_map(q))
		_over.draw_polyline(pts, Color(0.95, 0.45, 0.1, 0.85), 1.0)
	for i in scout_track.size() - 1:
		if i % 2 == 0:
			_over.draw_line(_to_map(scout_track[i]), _to_map(scout_track[i + 1]), TRACK_COLOR, 1.5)
	# The places found, and the barriers and crossings found.
	var target := contracts.current_target() if contracts else {}
	for th in fog.things:
		if not th.found or not _view.has_point(th.pos):
			continue
		var mp := _to_map(th.pos)
		match th.kind:
			"place":
				var is_target: bool = not target.is_empty() and (target.pos as Vector2).distance_to(th.pos) < 0.5
				_over.draw_rect(Rect2(mp - Vector2(3, 3), Vector2(6, 6)), Color(0.9, 0.7, 0.1) if is_target else INK)
				if not whole:
					var label := String(th.name).trim_prefix("the ").capitalize()
					var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
					var at := mp + Vector2(6, 4)
					if at.x + label_w > _rect.end.x:
						at.x = mp.x - 6.0 - label_w
					_text(font, at, label, Color(1.0, 0.95, 0.85))
			"washout", "slide", "crossing":
				_over.draw_line(mp - Vector2(4, 4), mp + Vector2(4, 4), Color(0.8, 0.15, 0.1), 2.0)
				_over.draw_line(mp - Vector2(4, -4), mp + Vector2(4, -4), Color(0.8, 0.15, 0.1), 2.0)
	if whole:
		for th in fog.things:
			if th.kind == "biome" and th.found:
				var name := String(th.name).to_upper()
				var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				_text(font, _to_map(th.pos) - Vector2(w * 0.5, 0.0), name, Color(1.0, 0.85, 0.3))
	if not target.is_empty() and fog.seen(target.pos):
		var tt := Time.get_ticks_msec() / 1000.0
		_over.draw_arc(_to_map(target.pos), 8.0 + sin(tt * 5.0) * 2.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.2), 1.5)

	# The truck: an arrow pointing where it is heading.
	var f := -vehicle.global_transform.basis.z
	var d := Vector2(f.x, f.z).normalized()
	var s := Vector2(-d.y, d.x)
	var vp_map := _to_map(Vector2(vehicle.global_position.x, vehicle.global_position.z))
	var arrow := PackedVector2Array([vp_map + d * 7.0, vp_map - d * 4.0 + s * 4.5, vp_map - d * 1.5, vp_map - d * 4.0 - s * 4.5])
	_over.draw_colored_polygon(arrow, Color(0.95, 0.25, 0.15))
	_over.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.1, 0.05, 0.0), 1.0)

	# Right column: the biome, the objective, the legend.
	var x := _rect.end.x + 18.0
	var y := _rect.position.y + 4.0
	var here := land.valley_at(Vector2(vehicle.global_position.x, vehicle.global_position.z))
	_text(font, Vector2(x, y + 8), "THE WHOLE MAP" if whole else here.biome.to_upper(), Color(1.0, 0.85, 0.3))
	y += 26.0
	if contracts:
		for line in _wrap(contracts.objective_text(), 36):
			_text(font, Vector2(x, y), line, Color(1.0, 1.0, 1.0))
			y += 12.0
	y += 12.0
	var legend := [
		[Color(0.95, 0.25, 0.15), "your truck"],
		[Color(0.95, 0.45, 0.1), "your trail"],
		[TRACK_COLOR, "the scout's track"],
		[Color(0.8, 0.15, 0.1), "a barrier"],
		[Color(0.38, 0.33, 0.28), "road"],
		[Color(0.42, 0.3, 0.2), "mud"],
		[Color(0.2, 0.32, 0.22), "trees"],
	]
	if here.layer != "dust":
		legend.append([here.layer_color, "deep " + here.layer])
	for item in legend:
		_over.draw_rect(Rect2(Vector2(x, y - 7), Vector2(8, 8)), item[0])
		_text(font, Vector2(x + 13, y), item[1], Color(0.9, 0.9, 0.85))
		y += 13.0
	_text(font, Vector2(x, _rect.end.y), "[Z] %s  [M] close" % ("this biome" if whole else "whole map"), Color(0.7, 0.7, 0.65))


func _text(font: Font, pos: Vector2, text: String, color: Color) -> void:
	_over.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.0, 0.0, 0.0, 0.9))
	_over.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _wrap(text: String, width: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		if line.length() + word.length() + 1 > width and line != "":
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return lines


## The whole map drawn, as the bake keeps it (tests/bake_map.gd).
static func draw_paper(l: Land) -> PackedByteArray:
	var m := MapScreen.new()
	m.land = l
	m._trees = l.tree_points
	m._bounds = l.bounds()
	m._img = Image.create_empty(int(m._bounds.size.x), int(m._bounds.size.y), false, Image.FORMAT_RGBA8)
	m._img.fill(PAPER)
	for t in l.tiles:
		m._render(t, Rect2i(0, 0, Terrain.SIZE, Terrain.SIZE))
	var out := m._img.get_data()
	m.free()
	return out


## The ground changed in rect (t's vertices): that part of the map is drawn again.
func _on_ground_changed(rect: Rect2i, t: Terrain) -> void:
	if not _drawn:
		return
	_render(t, rect.grow(1).intersection(Rect2i(0, 0, Terrain.SIZE, Terrain.SIZE)))
	_tex.update(_img)


## Draws rect of tile t (its pixels, a metre each) into the map: shaded relief, contour lines,
## ground cover, the water, its trees.
func _render(t: Terrain, rect: Rect2i) -> void:
	var h := t.heights
	var stride := Terrain.N
	var n := Terrain.SIZE
	var v := t.valley
	var o := Vector2i((t.origin - Vector2.ONE * Terrain.HALF - _bounds.position).round())
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var i := z * stride + x
			var hz := h[i]
			var nw := h[maxi(z - 1, 0) * stride + maxi(x - 1, 0)]
			var se := h[mini(z + 1, n) * stride + mini(x + 1, n)]
			var shade := clampf(0.85 + (nw - se) * 0.08, 0.55, 1.15)
			var c := t.snow_img.get_pixel(x, z)
			var col := Color(0.62, 0.55, 0.45)
			if v.layer != "dust":
				col = col.lerp(v.layer_color, clampf(c.r * 1.6, 0.0, 1.0))
			col = col.lerp(Color(0.42, 0.3, 0.2), c.g)
			col = col.lerp(Color(0.38, 0.33, 0.28), c.b)
			col = col.lerp(v.ice_color, 1.0 - c.a)
			var wp := t.origin + Vector2(x - Terrain.HALF, z - Terrain.HALF)
			if land.water_level(wp) > hz:
				col = Color(0.3, 0.45, 0.6)
			col = Color(col.r * shade, col.g * shade, col.b * shade)
			# A contour line every 3 m.
			var band := floori(hz / 3.0)
			if band != floori(h[i + 1] / 3.0) or band != floori(h[i + stride] / 3.0):
				col = col.lerp(INK, 0.35)
			_img.set_pixel(o.x + x, o.y + z, col * PAPER)
	for p in _trees:
		var q := Vector2i((p - _bounds.position).floor())
		var l := q - o
		if rect.has_point(l) and q.x >= 0 and q.y >= 0 and q.x < _img.get_width() - 1 and q.y < _img.get_height() - 1:
			_img.fill_rect(Rect2i(q, Vector2i(2, 2)), Color(0.2, 0.32, 0.22))
