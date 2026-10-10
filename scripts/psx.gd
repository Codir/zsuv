class_name Psx
extends RefCounted
## Хелпери для PSX-матеріалів, простих мешів і піксельного шрифту.

const LIT_SHADER := preload("res://shaders/psx_lit.gdshader")

static var _materials := {}
static var _font: SystemFont


static func mat(color: Color, emission := 0.0, noise := 0.1) -> ShaderMaterial:
	var key := "%s_%s_%s" % [color.to_html(), emission, noise]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = LIT_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_strength", emission)
	m.set_shader_parameter("noise_amount", noise)
	_materials[key] = m
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return mesh(parent, bm, pos, color, emission)


static func mesh(parent: Node3D, m: Mesh, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, emission)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cylinder(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	return cm


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return _font
