class_name Forge
extends RefCounted
## Shared procedural geometry. No external models or textures are required.

static var materials = {}

static func mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + ":" + str(glow)
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	if glow > 0.0:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = m
	return m

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: float = 0.0, solid: bool = false) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat(color, glow)
	parent.add_child(node)
	node.position = at
	if solid:
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(body)
		body.add_child(collision)
	return node

static func orb(parent: Node3D, at: Vector3, radius: float, color: Color, glow: float = 1.0) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = mat(color, glow)
	parent.add_child(node)
	node.position = at
	return node

static func ring(parent: Node3D, at: Vector3, radius: float, color: Color, thickness: float = 0.07) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 32
	mesh.ring_segments = 6
	node.mesh = mesh
	node.material_override = mat(color, 1.0)
	parent.add_child(node)
	node.position = at
	return node

static func label(parent: Node3D, at: Vector3, text: String, size: int = 64, color: Color = Color.WHITE) -> Label3D:
	var node = Label3D.new()
	node.text = text
	node.font_size = size
	node.pixel_size = 0.009
	node.modulate = color
	node.no_depth_test = false
	node.outline_size = 0
	parent.add_child(node)
	node.position = at
	return node
