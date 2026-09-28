class_name RiftWorld
extends Node3D
const Arsenal = preload("res://scripts/arsenal.gd")
const ROOM_HALF = 25.0
const FLOOR_HEIGHT = 6.0
const ROOM_NAMES = ["НИЖНИЙ АТРИУМ", "ЗАЛ ПЕРЕЛОМА", "ЛИТЕЙНЫЙ СОБОР", "КОНТУР РАЗРЫВА", "АРХИВ ПЛОТИ", "РЕАКТОРНЫЙ НЕФ", "ЗАБЫТЫЙ АРСЕНАЛ", "ПОСЛЕДНИЙ СИНАПС", "ВЕРХНЕЕ ЯДРО"]
var game: Node3D
var floor_material: Material
var room_roots: Array[Node3D] = []
var room_meshes: Array[Array] = []
var navigation = AStar3D.new()
var floor_nodes: Dictionary = {}
var next_nav_id := 0
var lights: Array[Light3D] = []
var sun: DirectionalLight3D
var visibility_key := ""

func build() -> void:
	floor_material = game.art.material("floor", Color("8a8270"))
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("182631")
	sky_material.sky_horizon_color = Color("736856")
	sky_material.ground_bottom_color = Color("16191c")
	sky_material.ground_horizon_color = Color("736856")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9b5bb")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("363e40")
	environment.fog_density = 0.0025
	env.environment = environment
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -28, 0)
	sun.light_color = Color("ffe0a5")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 105
	add_child(sun)
	for i in game.centers.size():
		build_room(i)
		if i > 0:
			build_corridor(game.centers[i - 1], game.centers[i], i)
			var a: int = floor_nodes[Vector2i(i - 1, 0)][4]
			var b: int = floor_nodes[Vector2i(i, 0)][4]
			navigation.connect_points(a, b)
	build_hub()
	var rng = RandomNumberGenerator.new()
	rng.seed = 922104
	for i in 45:
		var x = rng.randf_range(-190, 190)
		var z = rng.randf_range(-310, 55)
		if x > -108 and x < 108 and z > -260 and z < 28:
			continue
		var h = rng.randf_range(22, 90)
		game.art.cylinder(self, Vector3(x, h / 2 - 22, z), rng.randf_range(3, 6), h, Color("343b38"), 2.5)

func nav_point(pos: Vector3) -> int:
	var id = next_nav_id
	next_nav_id += 1
	navigation.add_point(id, pos)
	return id

func build_room(index: int) -> void:
	var center: Vector3 = game.centers[index]
	var accent = Color("dca95d") if index % 2 == 0 else Color("9ddab4")
	var root = Node3D.new()
	root.name = "Sector%02d" % (index + 1)
	add_child(root)
	room_roots.append(root)
	var base = solid(center + Vector3(0, -0.6, 0), Vector3(50, 1.2, 50), Color("7c7866"), root)
	base.get_child(0).material_override = floor_material
	var openings: Array[Vector3] = []
	for neighbor in [index - 1, index + 1]:
		if neighbor >= 0 and neighbor < game.centers.size():
			var d: Vector3 = game.centers[neighbor] - center
			d.y = 0
			openings.append(d.normalized())
	for side in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var horizontal = abs(side.z) > 0.5
		var tangent = Vector3.RIGHT if horizontal else Vector3.BACK
		for segment in ([-1, 1] if openings.has(side) else [0]):
			var length = 19.0 if segment != 0 else 50.0
			var p = center + side * ROOM_HALF + tangent * segment * 15.5
			solid(p + Vector3.UP * 2, Vector3(length, 4, 0.7) if horizontal else Vector3(0.7, 4, length), Color("777462"), root)
			game.art.box(root, p + Vector3.UP * 4.08, Vector3(length, 0.13, 0.85) if horizontal else Vector3(0.85, 0.13, length), accent, "metal", true)
		for j in [-23, -12, 0, 12, 23]:
			if j == 0 and openings.has(side):
				continue
			var p = center + side * 24.5 + tangent * j
			solid(p + Vector3.UP * 12, Vector3(1.2, 24, 1.2), Color("6b695d"), root)
			game.art.box(root, p + Vector3.UP * 22, Vector3(1.7, 0.8, 1.7), Color("8d8670"))
		game.art.box(root, center + side * 24.5 + Vector3.UP * 23, Vector3(50, 1.2, 1.5) if horizontal else Vector3(1.5, 1.2, 50), Color("645d4f"))
		if openings.has(side):
			for s in [-1, 1]:
				var p = center + side * 24.7 + tangent * s * 6
				solid(p + Vector3.UP * 3.2, Vector3(0.7, 6.4, 0.7), Color("5b635b"), root)
			game.art.box(root, center + side * 24.7 + Vector3.UP * 6.5, Vector3(12.7, 0.6, 0.8) if horizontal else Vector3(0.8, 0.6, 12.7), Color("c6a954"), "hazard")
	# Four accessible storeys around an open atrium. Alternating stairwells
	# are cut out of the receiving deck: no invisible ceiling across a ramp.
	for floor_index in 4:
		var y = floor_index * FLOOR_HEIGHT
		var ids: Array[int] = []
		for corner in [Vector3(-20, y, -20), Vector3(20, y, -20), Vector3(20, y, 20), Vector3(-20, y, 20)]:
			ids.append(nav_point(center + corner))
		var center_id = nav_point(center + Vector3(0, y, 0)) if floor_index == 0 else -1
		if floor_index == 0:
			ids.append(center_id)
			for id in ids.slice(0, 4):
				navigation.connect_points(id, center_id)
		for edge in 4:
			if floor_index > 0 and ((floor_index % 2 == 1 and edge == 3) or (floor_index % 2 == 0 and edge == 1)):
				continue
			navigation.connect_points(ids[edge], ids[(edge + 1) % 4])
		floor_nodes[Vector2i(index, floor_index)] = ids
		if floor_index == 0:
			continue
		for z in [-20, 20]:
			deck(root, center + Vector3(0, y - 0.25, z), Vector3(50, 0.5, 10), y)
			for x in [-10, 10]:
				rail(root, center + Vector3(x, y, z - sign(z) * 5), Vector3(20, 1, 0.1), accent)
		var x = 20.0 if floor_index % 2 else -20.0
		deck(root, center + Vector3(x, y - 0.25, 0), Vector3(10, 0.5, 30), y)
		rail(root, center + Vector3(x - sign(x) * 5, y, 0), Vector3(0.1, 1, 28), accent)
		var ramp_x = -20.0 if floor_index % 2 else 20.0
		var start_z = 15.0 if floor_index % 2 else -15.0
		var a = center + Vector3(ramp_x, y - 6, start_z)
		var b = center + Vector3(ramp_x, y, -start_z)
		build_ramp(root, a, b, 5, accent)
		var ai = nav_point(a)
		var bi = nav_point(b)
		navigation.connect_points(ai, bi)
		var lower: Array = floor_nodes[Vector2i(index, floor_index - 1)]
		var corner = 3 if floor_index % 2 else 1
		navigation.connect_points(lower[corner], ai)
		navigation.connect_points(ids[0 if floor_index % 2 else 2], bi)
		wall_label(root, center + Vector3(0, y + 2.2, -24), "DECK %02d  /  %s" % [floor_index, ROOM_NAMES[index]], accent, 42)
	# Cantilever observation bridge at deck two: a real alternate combat position.
	deck(root, center + Vector3(-8, 11.75, 7), Vector3(24, 0.5, 4), 12)
	var bridge_node = nav_point(center + Vector3(2, 12, 7))
	var bridge_start = nav_point(center + Vector3(-20, 12, 7))
	navigation.connect_points(bridge_start, bridge_node)
	navigation.connect_points(bridge_start, floor_nodes[Vector2i(index, 2)][3])
	for z in [5, 9]:
		rail(root, center + Vector3(-8, 12, z), Vector3(24, 1, 0.1), accent)
	# Dense, original props, out of the main corridors and staircase route.
	for x in [-11, 11]:
		for z in [-7, 7]:
			var p = center + Vector3(x, 0, z)
			solid(p + Vector3.UP * 0.75, Vector3(2.2, 1.5, 2.2), Color("575a4a"), root)
			game.art.crate(root, p, 2.2)
			game.art.cylinder(root, p + Vector3(2.2, 0.8, 0), 0.5, 1.6, Color("705844"))
	for s in [-1, 1]:
		game.art.rod(root, center + Vector3(s * 22.5, 2, -22), center + Vector3(s * 22.5, 20, -22), 0.38, Color("82593c"))
		game.art.cylinder(root, center + Vector3(s * 9, 0.7, -22), 1.1, 1.4, Color("414e4a"), 0.85)
		var console = game.art.box(root, center + Vector3(s * 9, 1.5, -22), Vector3(1.6, 0.5, 1.2), Color("4f5d53"))
		console.rotation.x = -0.25
		game.art.box(console, Vector3(0, 0.26, 0), Vector3(1.1, 0.03, 0.65), accent, "metal", true)
		var lamp = OmniLight3D.new()
		lamp.position = center + Vector3(s * 18, 9, -16)
		lamp.light_color = Color("ffc58a") if s == 1 else Color("a0dac1")
		lamp.light_energy = 3
		lamp.omni_range = 30
		root.add_child(lamp)
		lights.append(lamp)
	floor_label(root, center + Vector3(0, 0.06, 10), "%02d / %s" % [index + 1, ROOM_NAMES[index]], accent)
	floor_label(root, center + Vector3(-20, 0.07, 17), "UP / 4 DECKS", accent, 45)
	if index < game.centers.size() - 1:
		var direction: Vector3 = game.centers[index + 1] - center
		direction.y = 0
		direction = direction.normalized()
		var right = direction.cross(Vector3.UP)
		for j in 3:
			var tip = center + direction * (17 + j * 1.7) + Vector3.UP * 0.07
			permanent_line(tip, tip - direction + right, Arsenal.LIME, root)
			permanent_line(tip, tip - direction - right, Arsenal.LIME, root)
	var meshes: Array = root.find_children("*", "GeometryInstance3D", true, false)
	room_meshes.append(meshes)

func deck(root: Node3D, pos: Vector3, size: Vector3, _height: float) -> void:
	var b = solid(pos, size, Color("777e70"), root)
	b.get_child(0).material_override = floor_material

func rail(root: Node3D, pos: Vector3, size: Vector3, accent: Color) -> void:
	# Waist-high physical rails leave deliberate two-meter openings at landings.
	var beam_size = Vector3(size.x, 0.1, size.z)
	game.art.box(root, pos + Vector3.UP, beam_size, accent, "metal", true)
	var horizontal = size.x > size.z
	for s in [-0.5, 0, 0.5]:
		game.art.rod(root, pos + Vector3(size.x * s if horizontal else 0, 0, size.z * s if not horizontal else 0), pos + Vector3(size.x * s if horizontal else 0, 1, size.z * s if not horizontal else 0), 0.045, Color("505e55"))
	# No invisible fence collider: players can jump/drop off these catwalks.

func build_ramp(root: Node3D, a: Vector3, b: Vector3, width: float, accent: Color) -> void:
	var ramp = Node3D.new()
	root.add_child(ramp)
	ramp.position = (a + b) / 2
	ramp.look_at(b)
	var length = a.distance_to(b)
	var floor_body = solid(Vector3(0, -0.2, 0), Vector3(width, 0.4, length), Color("847c68"), ramp)
	floor_body.get_child(0).material_override = floor_material
	for side in [-1, 1]:
		game.art.box(ramp, Vector3(side * (width / 2 - 0.12), 0.05, 0), Vector3(0.12, 0.06, length), accent, "metal", true)
	# One draw call per flight rather than dozens of separate tread meshes.
	var mesh = BoxMesh.new()
	mesh.size = Vector3(width - 0.4, 0.02, 0.065)
	var batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = int(length / 0.7)
	for i in batch.instance_count:
		batch.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, 0.014, -length / 2 + i * 0.7)))
	var treads = MultiMeshInstance3D.new()
	treads.multimesh = batch
	treads.material_override = game.art.material("metal", Color("3a4036"))
	ramp.add_child(treads)

func build_corridor(a: Vector3, b: Vector3, _index: int) -> void:
	var flat = b - a
	flat.y = 0
	var direction = flat.normalized()
	var start = a + direction * ROOM_HALF
	var finish = b - direction * ROOM_HALF
	build_ramp(self, start, finish, 12, Color("b8c291"))
	for side in [-1, 1]:
		var p = (start + finish) / 2 + direction.cross(Vector3.UP) * side * 6.2
		solid(p + Vector3.UP * 0.7, Vector3(0.4, 1.4, 26) if abs(direction.z) > 0 else Vector3(26, 1.4, 0.4), Color("666554"))

func update_visibility() -> void:
	var deck_index = clampi(int(floor((game.player.position.y - game.centers[game.sector].y + 0.3) / 6)), 0, 3)
	var key = str(game.top_down) + str(game.sector) + str(deck_index) + str(game.sandbox)
	if key == visibility_key:
		return
	visibility_key = key
	for i in room_meshes.size():
		for mesh in room_meshes[i]:
			if not is_instance_valid(mesh):
				continue
			var pos: Vector3 = mesh.global_position - game.centers[i]
			mesh.visible = true
			if game.top_down and i == game.sector and not game.sandbox:
				mesh.visible = pos.y < deck_index * 6 + 3.8
	sun.shadow_enabled = not game.reduced_fx
	for lamp in lights:
		lamp.shadow_enabled = not game.reduced_fx and lamp.position.distance_to(game.player.position) < 45

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	# Attach to the nearest WALKABLE EDGE, not the nearest corner. Corner-only
	# attachment cuts across the atrium when a bridge endpoint is closer.
	var a = nearest_edge(from)
	var b = nearest_edge(to)
	var start = next_nav_id
	var finish = next_nav_id + 1
	navigation.add_point(start, a.point)
	navigation.add_point(finish, b.point)
	for id in [a.a, a.b]:
		navigation.connect_points(start, id)
	for id in [b.a, b.b]:
		navigation.connect_points(finish, id)
	if a.a == b.a and a.b == b.b:
		navigation.connect_points(start, finish)
	var path = navigation.get_point_path(start, finish)
	navigation.remove_point(start)
	navigation.remove_point(finish)
	path.append(to)
	return path

func nearest_edge(pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var score := INF
	var weight = Vector3(1, 5, 1)
	for id in navigation.get_point_ids():
		var a = navigation.get_point_position(id)
		for other in navigation.get_point_connections(id):
			if other <= id:
				continue
			var b = navigation.get_point_position(other)
			var segment = (b - a) * weight
			var t = clampf(((pos - a) * weight).dot(segment) / maxf(0.001, segment.length_squared()), 0, 1)
			var point = a.lerp(b, t)
			var d = ((pos - point) * weight).length_squared()
			if d < score:
				score = d
				best = {"a": id, "b": other, "point": point}
	return best

func nearest_nav(pos: Vector3) -> int:
	var nearest := 0
	var score := INF
	for id in navigation.get_point_ids():
		var p = navigation.get_point_position(id)
		var d = Vector2(pos.x - p.x, pos.z - p.z).length_squared() + pow((pos.y - p.y) * 5, 2)
		if d < score:
			score = d
			nearest = id
	return nearest

func wall_label(root: Node3D, pos: Vector3, text: String, color: Color, size: int = 64) -> void:
	var n = Label3D.new()
	n.text = text
	n.position = pos
	n.font_size = size
	n.pixel_size = 0.024
	n.modulate = color
	n.outline_size = 4
	root.add_child(n)

func floor_label(root: Node3D, pos: Vector3, text: String, color: Color, size: int = 64) -> void:
	wall_label(root, pos, text, color, size)
	root.get_child(root.get_child_count() - 1).rotation_degrees.x = -90

func build_hub() -> void:
	for side in [-1, 1]:
		solid(Vector3(side * 7, 29.5, 0), Vector3(8, 1, 22), Color("686c5b"))
		solid(Vector3(0, 29.5, side * 7), Vector3(6, 1, 8), Color("686c5b"))
		game.art.box(self, Vector3(side * 3.05, 30.06, 0), Vector3(0.14, 0.12, 6), Color("c4ad65"), "hazard")
		game.art.box(self, Vector3(0, 30.06, side * 3.05), Vector3(6, 0.12, 0.14), Color("c4ad65"), "hazard")
	for i in 3:
		var pos = Vector3((i - 1) * 6, 30, -7)
		game.art.cylinder(self, pos + Vector3.UP * 0.3, 1.5, 0.6, Color("686d5e"), 1.3)
		var statue = Node3D.new()
		add_child(statue)
		statue.position = pos + Vector3.UP * 0.6
		statue.scale = Vector3.ONE * 1.5
		game.art.actor(statue, "player", Arsenal.CLASSES[i].color)
		wall_label(self, pos + Vector3(0, 4.5, 0), Arsenal.CLASSES[i].tag, Arsenal.CLASSES[i].color, 38)
		game.art.crate(self, pos + Vector3(1.6, 0, -1.8), 1.1)
	wall_label(self, Vector3(0, 37, -10), "RIFT // TRANSIT AUTHORITY", Color("dcca93"), 50)

func permanent_line(a: Vector3, b: Vector3, color: Color, parent: Node3D = self) -> void:
	var mesh = game.art.box(parent, (a + b) / 2, Vector3(0.13, 0.055, a.distance_to(b)), color, "metal", true)
	mesh.look_at(b)

func solid(pos: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> StaticBody3D:
	var body = StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	game.art.box(body, Vector3.ZERO, size, color, "stone" if size.y > 2 else "metal")
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.collision_layer = 1
	return body
