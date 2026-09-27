class_name RiftWorld
extends Node3D

const Arsenal = preload("res://scripts/arsenal.gd")

var game: Node3D
var floor_material: ShaderMaterial
const ROOM_NAMES = ["ТОЧКА ПАДЕНИЯ", "ПЛОСКОСТЬ ШУМА", "ВЫСОКОЕ НАПРЯЖЕНИЕ", "КОНТУР РАЗРЫВА", "ОБРАТНЫЙ ИМПУЛЬС", "НИЖНИЙ СЛОЙ", "ЧЁРНЫЙ СИГНАЛ", "ПОСЛЕДНИЙ СИНАПС", "ЯДРО БЕСКОНЕЧНОСТИ"]

func build() -> void:
	floor_material = ShaderMaterial.new()
	floor_material.shader = load("res://shaders/grid.gdshader")
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("070c18")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9bbddd")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color("a5c5e7")
	sun.light_energy = 1.3
	add_child(sun)
	for i in game.centers.size():
		build_room(i)
		if i > 0:
			build_corridor(game.centers[i - 1], game.centers[i], i)
	build_hub()
	# The distant structures are non-colliding silhouettes, never gameplay obstacles.
	var rng = RandomNumberGenerator.new()
	rng.seed = 922104
	for i in 65:
		var x = rng.randf_range(-110, 110)
		var z = rng.randf_range(-180, 55)
		if x > -65 and x < 65 and z > -145 and z < 18:
			continue
		var h = rng.randf_range(15, 70)
		game.visual_box(self, Vector3(x, h / 2 - 28, z), Vector3(rng.randf_range(3, 8), h, rng.randf_range(3, 8)), Color("10192a"), false)
		game.visual_box(self, Vector3(x, h - 28, z), Vector3(0.15, 1.0, 3), Arsenal.VIOLET)

func build_room(index: int) -> void:
	var center: Vector3 = game.centers[index]
	var accent: Color = Arsenal.CYAN if index % 2 == 0 else Arsenal.VIOLET
	var base = solid(center + Vector3(0, -0.6, 0), Vector3(26, 1.2, 26), Color("121b29"))
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
		if openings.has(side):
			for sign_value in [-1, 1]:
				var pos = center + side * 13 + tangent * sign_value * 9.2 + Vector3.UP * 1.7
				solid(pos, Vector3(7.6, 3.4, 0.65) if horizontal else Vector3(0.65, 3.4, 7.6), Color("182537"))
				game.visual_box(self, pos + Vector3.UP * 1.75, Vector3(7.6, 0.065, 0.7) if horizontal else Vector3(0.7, 0.065, 7.6), accent)
			# Gate uprights leave a generous ten-meter opening.
			for sign_value in [-1, 1]:
				var p = center + side * 12.6 + tangent * sign_value * 5.2
				game.visual_box(self, p + Vector3.UP * 2.7, Vector3(0.25, 5.4, 0.25), accent)
		else:
			var pos = center + side * 13 + Vector3.UP * 1.7
			solid(pos, Vector3(26.5, 3.4, 0.65) if horizontal else Vector3(0.65, 3.4, 26.5), Color("182537"))
			game.visual_box(self, pos + Vector3.UP * 1.75, Vector3(26, 0.065, 0.7) if horizontal else Vector3(0.7, 0.065, 26), accent)
			for j in [-8, 0, 8]:
				game.visual_box(self, pos + tangent * j - side * 0.36, Vector3(1.6, 0.08, 0.08) if horizontal else Vector3(0.08, 0.08, 1.6), accent)
	for x in [-9.5, 9.5]:
		for z in [-9.5, 9.5]:
			var pos = center + Vector3(x, 1.4, z)
			solid(pos, Vector3(1.8, 2.8, 1.8), Color("283445"))
			game.visual_box(self, pos + Vector3.UP * 1.45, Vector3(1.9, 0.08, 1.9), accent)
	for j in 4:
		var a = float(j) * PI / 2
		var p = center + Vector3(cos(a), 0.04, sin(a)) * 7
		var decal = game.visual_box(self, p, Vector3(2.3, 0.035, 0.15), accent)
		decal.rotation.y = -a
	var text = Label3D.new()
	text.text = "%02d / %s" % [index + 1, "PERSPECTIVE" if index % 2 == 0 else "FLATLINE"]
	text.font_size = 90
	text.pixel_size = 0.014
	text.modulate = accent
	text.outline_size = 0
	text.no_depth_test = false
	text.position = center + Vector3(0, 0.06, 5)
	text.rotation_degrees.x = -90
	add_child(text)
	# Visible direction chevrons guide a winding, non-linear-height route.
	if index < game.centers.size() - 1:
		var d: Vector3 = (game.centers[index + 1] - center)
		d.y = 0
		d = d.normalized()
		var right = d.cross(Vector3.UP)
		for j in 3:
			var tip = center + d * (7.8 + j * 1.3) + Vector3.UP * 0.075
			permanent_line(tip, tip - d * 0.7 + right * 0.7, Arsenal.LIME)
			permanent_line(tip, tip - d * 0.7 - right * 0.7, Arsenal.LIME)
	# Underside gives each arena an architectural, suspended silhouette.
	game.visual_box(self, center + Vector3(0, -2.5, 0), Vector3(20, 3, 20), Color("0c1422"), false)

func build_corridor(a: Vector3, b: Vector3, index: int) -> void:
	var flat = b - a
	flat.y = 0
	var direction = flat.normalized()
	var start = a + direction * 13.0
	var finish = b - direction * 13.0
	var delta = finish - start
	var midpoint = (start + finish) / 2
	var length = delta.length()
	var ramp = Node3D.new()
	add_child(ramp)
	ramp.position = midpoint
	ramp.look_at(midpoint + delta)
	var body = solid(Vector3(0, -0.3, 0), Vector3(10.5, 0.6, length), Color("1e2b39"), ramp)
	body.get_child(0).material_override = floor_material
	var accent = Arsenal.VIOLET if index % 2 == 1 else Arsenal.CYAN
	for side in [-1, 1]:
		solid(Vector3(side * 5.35, 0.8, 0), Vector3(0.45, 1.6, length), Color("1a283b"), ramp)
		game.visual_box(ramp, Vector3(side * 5.35, 1.65, 0), Vector3(0.14, 0.12, length), accent)
		game.visual_box(ramp, Vector3(side * 4.9, 0.04, 0), Vector3(0.12, 0.07, length), Arsenal.LIME)

func build_hub() -> void:
	for side in [-1, 1]:
		solid(Vector3(side * 7, 23.5, 0), Vector3(8, 1, 22), Color("182639"))
		solid(Vector3(0, 23.5, side * 7), Vector3(6, 1, 8), Color("182639"))
		game.visual_box(self, Vector3(side * 3.05, 24.06, 0), Vector3(0.12, 0.12, 6), Arsenal.LIME)
		game.visual_box(self, Vector3(0, 24.06, side * 3.05), Vector3(6, 0.12, 0.12), Arsenal.LIME)
	for i in 3:
		var pos = Vector3((i - 1) * 6, 24, -7)
		solid(pos + Vector3.UP * 0.4, Vector3(3.5, 0.8, 3.5), Color("2a3549"))
		game.visual_box(self, pos + Vector3.UP * 0.85, Vector3(3.6, 0.08, 3.6), Arsenal.CLASSES[i].color)
		var monolith = game.visual_box(self, pos + Vector3.UP * 3, Vector3(1.3, 3.5, 1.3), Arsenal.CLASSES[i].color)
		monolith.rotation_degrees = Vector3(0, 45, 12)
		var label = Label3D.new()
		label.text = Arsenal.CLASSES[i].tag
		label.position = pos + Vector3(0, 5.7, 0)
		label.font_size = 64
		label.pixel_size = 0.012
		label.modulate = Arsenal.CLASSES[i].color
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	for side in [-1, 1]:
		game.visual_box(self, Vector3(side * 11, 27, -10), Vector3(0.3, 6, 0.3), Arsenal.CYAN)
	game.visual_box(self, Vector3(0, 30, -10), Vector3(22, 0.3, 0.3), Arsenal.CYAN)

func permanent_line(a: Vector3, b: Vector3, color: Color) -> void:
	var mesh = game.visual_box(self, (a + b) / 2, Vector3(0.13, 0.055, a.distance_to(b)), color)
	mesh.look_at(b)

func solid(pos: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> StaticBody3D:
	var body = StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	game.visual_box(body, Vector3.ZERO, size, color, false)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.collision_layer = 1
	return body
