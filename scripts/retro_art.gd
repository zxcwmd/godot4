class_name RetroArt
extends RefCounted
## Original low-poly meshes and deterministic 64px textures; no external assets.
var materials: Dictionary = {}
var textures: Dictionary = {}

func texture(kind: String) -> Texture2D:
	if textures.has(kind):
		return textures[kind]
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(kind) + 913
	for y in 64:
		for x in 64:
			var value = 0.78 + rng.randf_range(-0.09, 0.09)
			match kind:
				"stone":
					if y % 16 < 2 or (x + (16 if (y / 16) % 2 else 0)) % 32 < 2:
						value = 0.32
					elif y % 16 == 2:
						value = 0.98
				"floor":
					if x % 32 < 2 or y % 32 < 2:
						value = 0.3
					elif (x + y) % 12 < 2 and y % 8 < 4:
						value = 0.93
				"metal":
					if x % 32 < 2 or y % 32 < 2:
						value = 0.35
					if x % 32 in [4, 27] and y % 32 in [4, 27]:
						value = 0.99
					if y % 16 == 7 and x % 32 > 12:
						value *= 0.75
				"cloth": value = 0.6 + float((x + y) % 2) * 0.25 + rng.randf_range(-0.08, 0.08)
				"skin": value = 0.82 + rng.randf_range(-0.06, 0.06)
				"flesh":
					value = 0.65 + sin(x * 0.4 + cos(y * 0.2) * 3) * 0.2 + rng.randf_range(-0.08, 0.08)
				"hazard": value = 0.15 if (x + y) % 24 < 12 else 0.95
			image.set_pixel(x, y, Color(value, value, value))
	textures[kind] = ImageTexture.create_from_image(image)
	return textures[kind]

func material(kind: String, color: Color, glow: bool = false) -> StandardMaterial3D:
	var key = kind + str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color * 1.5
	else:
		m.albedo_texture = texture(kind)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * (0.5 if kind in ["stone", "floor"] else 2.0)
		m.metallic = 0.3 if kind == "metal" else 0
	materials[key] = m
	return m

func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, surface: String = "metal", glow: bool = false) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material(surface, color, glow)
	parent.add_child(n)
	n.position = pos
	return n

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, surface: String = "metal", glow: bool = false) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, pos, color, surface, glow)

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1, surface: String = "metal", sides: int = 8) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh_node(parent, mesh, pos, color, surface)

func orb(parent: Node3D, pos: Vector3, size: Vector3, color: Color, surface: String = "skin", glow: bool = false) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 8
	mesh.rings = 4
	var n = mesh_node(parent, mesh, pos, color, surface, glow)
	n.scale = size
	return n

func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var n = cylinder(parent, (a + b) / 2, radius, a.distance_to(b), color)
	var axis = (b - a).normalized()
	n.quaternion = Quaternion(Vector3.UP, axis)
	return n

func blade(parent: Node3D, pos: Vector3, length: float, width: float, color: Color, curve: float = 0.0) -> MeshInstance3D:
	var outline: Array[Vector2] = [Vector2(-width / 2, 0), Vector2(width / 2, 0), Vector2(width / 2 + curve, -length * 0.8), Vector2(curve, -length), Vector2(-width / 2 + curve, -length * 0.75)]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1, 1]:
		for i in range(1, outline.size() - 1):
			for j in ([0, i, i + 1] if side == 1 else [0, i + 1, i]):
				st.add_vertex(Vector3(outline[j].x, side * 0.015, outline[j].y))
	for i in outline.size():
		var j = (i + 1) % outline.size()
		var a = Vector3(outline[i].x, -0.015, outline[i].y)
		var b = Vector3(outline[j].x, -0.015, outline[j].y)
		for p in [a, b, b + Vector3.UP * 0.03, a, b + Vector3.UP * 0.03, a + Vector3.UP * 0.03]:
			st.add_vertex(p)
	st.generate_normals()
	return mesh_node(parent, st.commit(), pos, color)

func actor(root: Node3D, kind: String, accent: Color) -> void:
	var limbs: Array[Dictionary] = []
	if kind == "target":
		cylinder(root, Vector3(0, 0.1, 0), 0.65, 0.2, Color("625e53"))
		rod(root, Vector3(0, 0.2, 0), Vector3(0, 1.7, 0), 0.10, Color("494a40"))
		box(root, Vector3(0, 1.15, 0), Vector3(0.7, 0.9, 0.20), Color("9c7451"), "cloth")
		orb(root, Vector3(0, 1.78, 0), Vector3(0.4, 0.4, 0.3), Color("b9ad86"))
		for r in [0.26, 0.17, 0.08]:
			var ring = cylinder(root, Vector3(0, 1.25, -0.12), r, 0.018, accent if r != 0.17 else Color("4a3f35"))
			ring.rotation.x = PI / 2
		return
	if kind == "beast":
		orb(root, Vector3(0, 1.15, 0.02), Vector3(1.15, 1.5, 0.8), Color("754c46"), "flesh")
		orb(root, Vector3(0, 1.98, -0.12), Vector3(0.65, 0.65, 0.62), Color("a67e62"), "flesh")
		box(root, Vector3(0, 1.82, -0.43), Vector3(0.43, 0.18, 0.16), Color("352b29"), "flesh")
		for i in 5:
			cylinder(root, Vector3(-0.17 + i * 0.085, 1.82, -0.54), 0.028, 0.14, Color("e0d4ab"), 0.002)
		for side in [-1, 1]:
			var horn = cylinder(root, Vector3(side * 0.35, 2.26, 0), 0.16, 0.58, Color("c8b58a"), 0.005)
			horn.rotation.z = -side * 0.45
			orb(root, Vector3(side * 0.17, 2.02, -0.42), Vector3(0.13, 0.07, 0.04), accent, "metal", true)
			limb(root, limbs, Vector3(side * 0.61, 1.45, 0), Vector3(0.33, 0.95, 0.32), Color("81584a"), "flesh", side, false)
			limb(root, limbs, Vector3(side * 0.31, 0.60, 0), Vector3(0.29, 0.6, 0.35), Color("5b4138"), "flesh", side, true)
			for j in 3:
				rod(root, Vector3(side * (0.54 + j * 0.08), 0.74, -0.12), Vector3(side * (0.54 + j * 0.08), 0.47, -0.36), 0.035, Color("d0c49a"))
	elif kind == "robot":
		cylinder(root, Vector3(0, 1.03, 0), 0.31, 0.75, Color("646e69"), 0.4)
		box(root, Vector3(0, 1.55, -0.02), Vector3(0.62, 0.34, 0.5), Color("7a8174"))
		orb(root, Vector3(0, 1.56, -0.30), Vector3(0.24, 0.22, 0.10), accent, "metal", true)
		for side in [-1, 1]:
			rod(root, Vector3(side * 0.22, 0.8, 0), Vector3(side * 0.38, 0.24, 0), 0.09, Color("bbb7a1"))
			limb(root, limbs, Vector3(side * 0.24, 0.7, 0), Vector3(0.15, 0.65, 0.20), Color("535c58"), "metal", side, true)
			var gun = cylinder(root, Vector3(side * 0.47, 1.04, -0.30), 0.12, 0.65, Color("424742"))
			gun.rotation.x = PI / 2
			box(root, Vector3(side * 0.43, 1.3, 0), Vector3(0.2, 0.1, 0.38), accent, "metal", true)
		rod(root, Vector3(0.25, 1.7, 0), Vector3(0.3, 2.15, 0), 0.025, Color("92977f"))
	else:
		var cloth = Color("4b5550") if kind == "player" else Color("6b4635")
		var skin = Color("b08a69") if kind == "player" else Color("8b8b6c")
		cylinder(root, Vector3(0, 1.1, 0), 0.29, 0.7, cloth, 0.38, "cloth", 6)
		box(root, Vector3(0, 1.15, -0.24), Vector3(0.52, 0.48, 0.12), Color("555956"))
		box(root, Vector3(0, 0.84, -0.24), Vector3(0.58, 0.12, 0.12), Color("363c32"), "cloth")
		orb(root, Vector3(0, 1.69, 0), Vector3(0.4, 0.49, 0.39), skin)
		box(root, Vector3(0, 1.87, 0.02), Vector3(0.41, 0.16, 0.36), Color("34352e"), "cloth")
		box(root, Vector3(0, 1.68, -0.20), Vector3(0.29, 0.075, 0.04), accent, "metal", true)
		box(root, Vector3(0, 1.42, -0.12), Vector3(0.44, 0.13, 0.36), accent.darkened(0.35), "cloth")
		for side in [-1, 1]:
			limb(root, limbs, Vector3(side * 0.4, 1.38, 0), Vector3(0.21, 0.65, 0.23), cloth, "cloth", side, false)
			orb(root, Vector3(side * 0.43, 0.77, -0.04), Vector3(0.18, 0.22, 0.17), skin)
			limb(root, limbs, Vector3(side * 0.18, 0.72, 0), Vector3(0.24, 0.70, 0.26), cloth.darkened(0.2), "cloth", side, true)
			box(root, Vector3(side * 0.18, 0.14, -0.08), Vector3(0.28, 0.25, 0.44), Color("31332c"))
		if kind != "player":
			blade(root, Vector3(0.46, 0.77, -0.1), 0.65, 0.16, Color("929c7d"), 0.08)
	root.set_meta("limbs", limbs)

func limb(root: Node3D, limbs: Array[Dictionary], pos: Vector3, size: Vector3, color: Color, surface: String, sign_value: int, leg: bool) -> void:
	var pivot = Node3D.new()
	root.add_child(pivot)
	pivot.position = pos
	cylinder(pivot, Vector3(0, -size.y / 2, 0), size.x * 0.55, size.y, color, size.x * 0.44, surface, 6)
	limbs.append({"node": pivot, "sign": sign_value, "leg": leg})

func animate_actor(root: Node3D, speed: float, age: float, windup: float = 0) -> void:
	for l in root.get_meta("limbs", []):
		l.node.rotation.x = sin(age * 9) * minf(speed / 8, 1) * 0.55 * l.sign * (1 if l.leg else -1)
		if not l.leg:
			l.node.rotation.x -= windup * 1.2

func crate(parent: Node3D, pos: Vector3, size: float = 1.5) -> void:
	box(parent, pos + Vector3.UP * size / 2, Vector3.ONE * size, Color("5f6755"), "metal")
	for side in [-1, 1]:
		box(parent, pos + Vector3(side * size * 0.39, size / 2, 0), Vector3(size * 0.08, size * 1.04, size * 1.04), Color("8c896a"))
	box(parent, pos + Vector3(0, size * 0.6, -size * 0.51), Vector3(size * 0.55, size * 0.25, 0.02), Color("ccae5f"), "hazard")

func health_pickup(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var root = box(parent, pos, Vector3(0.5, 0.38, 0.32), Color("b6b99d"))
	box(root, Vector3(0, 0, -0.18), Vector3(0.09, 0.25, 0.035), Color("b6ff65"), "metal", true)
	box(root, Vector3(0, 0, -0.18), Vector3(0.27, 0.085, 0.035), Color("b6ff65"), "metal", true)
	return root
