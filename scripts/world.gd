extends Node3D
var game
var seals = []
var gates = []
var boss_gates = []
var rotators = []
var painted = []
var lights = []
var env: Environment
var sun: DirectionalLight3D
var pal = {}
var side_look = false
var pal_sector = 0
var exit_ring: MeshInstance3D
var exit_gate: MeshInstance3D
var exit_sign: Label3D
var accents = [Color("e8302a"), Color("f2c44a"), Color("3a8a48")]

func side_sector(index: int) -> bool:
	return index % 2 == 1 and index < 9

func make_palette(side: bool, sector: int) -> Dictionary:
	var block := clampi(int(sector) >> 1, 0, 4)
	if side:
		var acc = [Color("ff3a2a"), Color("f2c44a"), Color("6ad08a"), Color("ff7a40"), Color("f4ece0")][block]
		var glo = [Color("f2c44a"), Color("ff3a2a"), Color("f2c44a"), Color("6ad08a"), Color("ff3a2a")][block]
		return {
			"dark": Color("05040a"), "floor": Color("0c0814"), "wall": Color("140c1c"),
			"metal": Color("c8b090"), "accent": acc, "glow": glo, "bone": Color("faf4ea"),
			"fog": Color("080610"), "bg": Color("030208"), "sun": Color("ff8060"),
			"ambient": Color("5a2040"), "glass": Color(0.9, 0.2, 0.18, 0.22)
		}
	var acc2 = [Color("e8302a"), Color("3a8a48"), Color("f2c44a"), Color("ff7a40"), Color("e8302a")][block]
	var glo2 = [Color("f2c44a"), Color("e8302a"), Color("6ad08a"), Color("f2c44a"), Color("ff5a28")][block]
	return {
		"dark": Color("0a080c"), "floor": Color("1a1210"), "wall": Color("2a1c16"),
		"metal": Color("8a5a28"), "accent": acc2, "glow": glo2, "bone": Color("f4ece0"),
		"fog": Color("120c14"), "bg": Color("08060c"), "sun": Color("f0a878"),
		"ambient": Color("6a4050"), "glass": Color(0.9, 0.25, 0.2, 0.2)
	}

func dye(node: Node, role: String) -> Node:
	painted.append({"n": node, "r": role})
	return node

func col(role: String) -> Color:
	return pal[role] if pal.has(role) else Color.WHITE

func box(parent: Node3D, at: Vector3, size: Vector3, role: String, glow: float = 0.0, solid: bool = false) -> MeshInstance3D:
	return dye(Forge.box(parent, at, size, col(role), glow, solid), role)

func cyl(parent: Node3D, at: Vector3, radius: float, height: float, role: String, glow: float = 0.0) -> MeshInstance3D:
	return dye(Forge.cyl(parent, at, radius, height, col(role), glow), role)

func orb(parent: Node3D, at: Vector3, radius: float, role: String, glow: float = 1.0) -> MeshInstance3D:
	return dye(Forge.orb(parent, at, radius, col(role), glow), role)

func ring(parent: Node3D, at: Vector3, radius: float, role: String, thickness: float = 0.07) -> MeshInstance3D:
	return dye(Forge.ring(parent, at, radius, col(role), thickness), role)

func tag_label(node: Label3D, role: String) -> Label3D:
	return dye(node, role)

func apply_palette(side: bool, sector: int) -> void:
	side_look = side
	pal_sector = sector
	pal = make_palette(side, sector)
	accents = [pal.accent, pal.glow, pal.bone]
	for p in painted:
		if not is_instance_valid(p.n):
			continue
		var c: Color = pal[p.r] if pal.has(p.r) else pal.accent
		if p.n is Label3D:
			p.n.modulate = c
		elif p.n is OmniLight3D:
			p.n.light_color = c
		elif p.n is MeshInstance3D:
			var glow = 0.0
			if p.r == "accent" or p.r == "glow":
				glow = 1.0
			elif p.r == "glass":
				glow = 0.5
			p.n.material_override = Forge.mat(c, glow)
	if env:
		env.background_color = pal.bg
		env.fog_light_color = pal.fog
		env.ambient_light_color = pal.ambient
	if sun:
		sun.light_color = pal.sun

func build(owner_game) -> void:
	game = owner_game
	pal = make_palette(false, 0)
	var environment = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = pal.bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = pal.ambient
	env.ambient_light_energy = 0.58
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = pal.fog
	env.fog_density = 0.016
	env.fog_light_energy = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.1
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 22, 0)
	sun.light_color = pal.sun
	sun.light_energy = 1.05
	add_child(sun)
	build_hub()
	for sector in range(10):
		build_sector(sector)
	for i in range(3):
		build_seal(i)
	build_exit()
	apply_palette(false, 0)

func post(at: Vector3, height: float = 8.0) -> void:
	box(self, at + Vector3(0, height * 0.5, 0), Vector3(0.42, height, 0.42), "wall")
	box(self, at + Vector3(0, height * 0.5, 0), Vector3(0.18, height, 0.18), "dark")
	box(self, at + Vector3(0, 0.12, 0), Vector3(0.7, 0.24, 0.7), "metal")
	box(self, at + Vector3(0, height, 0), Vector3(0.85, 0.14, 0.85), "metal")
	orb(self, at + Vector3(0, height + 0.28, 0), 0.18, "glow", 1.1)

func lantern(at: Vector3) -> void:
	box(self, at, Vector3(0.08, 1.1, 0.08), "metal")
	var paper = orb(self, at + Vector3(0, 1.15, 0), 0.28, "accent", 1.15)
	rotators.append(paper)
	orb(self, at + Vector3(0, 1.15, 0), 0.12, "glow", 1.4)
	lamp(at + Vector3(0, 1.2, 0), "glow", 3.0, 10)

func arch(at: Vector3, tall: float = 7.0) -> void:
	post(at + Vector3(0, 0, -1.6), tall)
	post(at + Vector3(0, 0, 1.6), tall)
	box(self, at + Vector3(0, tall + 0.15, 0), Vector3(0.4, 0.28, 4.0), "metal")
	box(self, at + Vector3(0, tall * 0.55, 0), Vector3(0.06, tall * 0.7, 2.4), "accent", 0.6)

func blossom(at: Vector3) -> void:
	for i in range(5):
		var a = float(i) * TAU / 5.0
		orb(self, at + Vector3(cos(a) * 0.22, 0.05, sin(a) * 0.22), 0.09, "glow" if i % 2 == 0 else "bone", 0.8)
	orb(self, at, 0.08, "accent", 1.0)

func lamp(at: Vector3, role: String, energy: float, radius: float) -> void:
	var light = OmniLight3D.new()
	light.light_color = col(role)
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.6
	add_child(light)
	light.position = at
	dye(light, role)
	lights.append(light)

func build_hub() -> void:
	box(self, Vector3(-36, -0.5, 0), Vector3(44, 1, 20), "dark", 0, true)
	box(self, Vector3(-58, 6, 0), Vector3(1, 12, 20), "dark", 0, true)
	for z in [-10, 10]:
		box(self, Vector3(-29, 4, z), Vector3(58, 8, 0.7), "wall", 0, true)
		box(self, Vector3(-29, 0.05, z * 0.88), Vector3(56, 0.06, 0.16), "accent", 0.7)
		for x in range(-54, 0, 8):
			post(Vector3(x, 0, z * 0.82), 7.4)
	for x in range(-54, -14, 6):
		box(self, Vector3(x, 0.03, 0), Vector3(0.5, 0.04, 12), "glow", 0.3)
		blossom(Vector3(x + 3, 0.2, 0))
	for i in range(3):
		var x = -36 + i * 8
		box(self, Vector3(x, 0.5, -5), Vector3(2.4, 1.0, 2.4), "metal", 0, true)
		box(self, Vector3(x, 1.05, -5), Vector3(1.7, 0.1, 1.7), "accent", 0.9)
		arch(Vector3(x, 0, -5.2), 3.2)
		var core = orb(self, Vector3(x, 2.6, -5), 0.48, "glow")
		rotators.append(core)
		var halo = ring(self, Vector3(x, 2.6, -5), 0.95, "accent")
		halo.rotation_degrees.x = 80
		rotators.append(halo)
		lantern(Vector3(x, 0.2, -6.8))
		var text = Forge.label(self, Vector3(x, 4.4, -5), ["01 / КЛИНОК", "02 / БАЛЛИСТ", "03 / АРКАНИСТ"][i], 38, col("accent"))
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag_label(text, "accent")
		lamp(Vector3(x, 3.1, -5), "glow", 2.8, 10)
	var signage = Forge.label(self, Vector3(-5, 5, 0), "ВНИЗ — ЗНАЧИТ ВПЕРЁД\n↓   ВХОД В САД   ↓", 58, col("accent"))
	signage.rotation.y = -PI / 2
	tag_label(signage, "accent")
	box(self, Vector3(-14.3, 0.04, 0), Vector3(0.3, 0.1, 20), "accent", 1)
	box(self, Vector3(0, -6, 0), Vector3(1, 22, 20), "dark", 0, true)
	for z in [-10, 10]:
		box(self, Vector3(-7, -8, z), Vector3(14, 16, 0.6), "wall", 0, true)
		box(self, Vector3(-7, -8, z * 0.92), Vector3(13, 16, 0.08), "glass", 0.5)
	lamp(Vector3(-7, -2, 0), "glow", 4.0, 16)
	for y in range(-12, 0, 2):
		rotators.append(ring(self, Vector3(-7, y, 0), 5.0, "accent" if y % 4 == 0 else "glow", 0.08))
	for x in [-29, -25, -21, -17]:
		var arrow = Forge.label(self, Vector3(x, 0.04, 0), "»", 80, col("accent"))
		arrow.rotation_degrees = Vector3(-90, 0, -90)
		tag_label(arrow, "accent")
	lantern(Vector3(-48, 0.2, 6))
	lantern(Vector3(-48, 0.2, -6))

func build_sector(index: int) -> void:
	if index == 9:
		build_arena()
		return
	var start = index * 65.0
	var center = start + 32.5
	var side = side_sector(index)
	box(self, Vector3(center, -0.6, 0), Vector3(65, 1.2, 20), "floor", 0, true)
	for z in [-10, 10]:
		if side and z == 10:
			continue
		box(self, Vector3(center, 6, z), Vector3(65, 12, 0.6), "wall", 0, true)
		box(self, Vector3(center, 2.0, z * 0.96), Vector3(65, 0.08, 0.1), "accent", 0.65)
		box(self, Vector3(center, 8.2, z * 0.96), Vector3(65, 0.08, 0.1), "glass", 0.4)
		for x in range(int(start) + 4, int(start) + 65, 10):
			post(Vector3(x, 0, z * 0.78), 8.2)
			blossom(Vector3(x + 4, 0.18, z * 0.7))
	for x in range(int(start), int(start) + 65, 8):
		box(self, Vector3(x, 0.03, 0), Vector3(1.4, 0.04, 1.4), "accent", 0.28)
		box(self, Vector3(x + 4, 0.02, 0), Vector3(0.45, 0.03, 12), "glow", 0.22)
	lamp(Vector3(center, 7.0, 0), "glow", 2.1, 20)
	if not side:
		for x in range(int(start) + 8, int(start) + 65, 16):
			arch(Vector3(x, 0, 0), 6.5)
		for offset in [23, 43]:
			lantern(Vector3(start + offset, 0.2, -5 if offset == 23 else 5))
	else:
		for offset in [19, 38]:
			box(self, Vector3(start + offset, 0.5, 0), Vector3(2.0, 1.0, 4.4), "metal", 0, true)
			box(self, Vector3(start + offset, 1.05, 0), Vector3(2.0, 0.08, 4.4), "accent", 0.8)
		var titles = ["", "01 / СДВИГ", "", "02 / РАЗРЫВ", "", "03 / ПЕРЕГРУЗ", "", "ПОГОНЯ"]
		var huge = Forge.label(self, Vector3(center, 6.2, -9.6), titles[index] if index < titles.size() else "САД", 130, col("accent"))
		huge.modulate.a = 0.5
		tag_label(huge, "accent")
	if index > 0:
		post(Vector3(start, 0, -8), 8)
		post(Vector3(start, 0, 8), 8)
		box(self, Vector3(start, 8.0, 0), Vector3(0.5, 0.3, 16), "metal")
		var signage = Forge.label(self, Vector3(start - 0.2, 6.5, 0), "СДВИГ / 2D" if side else "ВОЗВРАТ / 3D", 54, col("accent"))
		signage.rotation.y = -PI / 2
		tag_label(signage, "accent")
	if index in [7, 8]:
		var g = box(self, Vector3(start, 6, 0), Vector3(0.4, 12, 20), "accent", 1, true)
		boss_gates.append(g)
	if index == 0:
		box(self, Vector3(0, 4, 0), Vector3(0.5, 8, 20), "dark", 0, true)

func build_arena() -> void:
	var start = 585.0
	var center = Vector3(617.5, 0, 0)
	box(self, center + Vector3(0, -0.6, 0), Vector3(65, 1.2, 48), "floor", 0, true)
	box(self, Vector3(650, 6, -17), Vector3(0.7, 12, 14), "wall", 0, true)
	box(self, Vector3(650, 6, 17), Vector3(0.7, 12, 14), "wall", 0, true)
	for z in [-24, 24]:
		box(self, Vector3(center.x, 6, z), Vector3(65, 12, 0.7), "wall", 0, true)
		box(self, Vector3(center.x, 1.1, z * 0.96), Vector3(60, 0.1, 0.12), "accent", 0.7)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			post(center + Vector3(x * 18, 0, z * 16), 9)
			lantern(center + Vector3(x * 10, 0.2, z * 10))
	for i in range(6):
		var a = float(i) * TAU / 6.0
		blossom(center + Vector3(cos(a) * 8, 0.2, sin(a) * 8))
	var core = ring(self, center + Vector3(0, 0.08, 0), 6.2, "accent", 0.1)
	core.rotation.x = PI / 2
	rotators.append(ring(self, center + Vector3(0, 4.2, 0), 4.0, "glow", 0.08))
	lamp(center + Vector3(0, 9, 0), "glow", 5.0, 24)
	var title = Forge.label(self, center + Vector3(0, 8.2, -22), "КВАДРАТ ЦВЕТКА", 92, col("accent"))
	tag_label(title, "accent")
	var g = box(self, Vector3(start, 6, 0), Vector3(0.45, 12, 48), "accent", 1, true)
	boss_gates.append(g)

func build_seal(index: int) -> void:
	var x = 122.0 + index * 130.0
	var node = Node3D.new()
	add_child(node)
	node.position = Vector3(x, 2.3, 0)
	var core = box(node, Vector3.ZERO, Vector3(1.0, 1.0, 1.0), "glow", 1)
	core.rotation_degrees = Vector3(45, 30, 45)
	rotators.append(core)
	var halo = ring(node, Vector3.ZERO, 1.45, "accent")
	halo.rotation.x = PI / 2
	rotators.append(halo)
	var caption = Forge.label(node, Vector3(0, 2.5, 0), "ПЕЧАТЬ / 0" + str(index + 1), 38, col("accent"))
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag_label(caption, "accent")
	seals.append(node)
	lamp(Vector3(x, 3.2, 0), "glow", 5.0, 14)
	var gate = box(self, Vector3(x + 6, 4, 0), Vector3(0.35, 8, 20), "accent", 1, true)
	for z in range(-9, 10, 2):
		box(gate, Vector3(-0.01, 0, z), Vector3(0.08, 8, 0.06), "glow", 1)
	gates.append(gate)
	post(Vector3(x + 6, 0, -8.5), 8)
	post(Vector3(x + 6, 0, 8.5), 8)

func open_seal(index: int) -> void:
	seals[index].hide()
	gates[index].hide()
	for child in gates[index].get_children():
		if child is StaticBody3D:
			child.collision_layer = 0
	game.fx.wave(seals[index].global_position, pal.accent, 12)

func open_boss_gate(index: int) -> void:
	if index < 0 or index >= boss_gates.size():
		return
	var gate = boss_gates[index]
	if not is_instance_valid(gate) or not gate.visible:
		return
	gate.hide()
	for child in gate.get_children():
		if child is StaticBody3D:
			child.collision_layer = 0
	game.fx.wave(gate.global_position, pal.glow, 8)

func build_exit() -> void:
	box(self, Vector3(672.5, -0.6, 0), Vector3(45, 1.2, 20), "floor", 0, true)
	box(self, Vector3(695, 5, 0), Vector3(1, 10, 20), "dark", 0, true)
	for z in [-10, 10]:
		box(self, Vector3(672.5, 5, z), Vector3(45, 10, 0.6), "wall", 0, true)
		box(self, Vector3(672, 1, z * 0.96), Vector3(44, 0.1, 0.12), "glow", 0.7)
	for x in range(655, 690, 9):
		post(Vector3(x, 0, -7), 7)
		post(Vector3(x, 0, 7), 7)
	exit_gate = box(self, Vector3(652, 4, 0), Vector3(0.35, 8, 20), "glow", 1, true)
	exit_sign = Forge.label(self, Vector3(651, 6, 0), "ЦВЕТОК УДЕРЖИВАЕТ ВЫХОД", 36, col("glow"))
	exit_sign.rotation.y = -PI / 2
	tag_label(exit_sign, "glow")
	exit_ring = ring(self, Vector3(682, 3, 0), 2.7, "accent", 0.16)
	exit_ring.rotation.z = PI / 2
	var signage = Forge.label(self, Vector3(684, 7.4, 0), "РАЗОРВИ САД", 72, col("accent"))
	signage.rotation.y = -PI / 2
	tag_label(signage, "accent")
	lantern(Vector3(668, 0.2, -6))
	lantern(Vector3(668, 0.2, 6))

func unlock_exit() -> void:
	for i in range(boss_gates.size()):
		open_boss_gate(i)
	exit_gate.hide()
	exit_sign.hide()
	for child in exit_gate.get_children():
		if child is StaticBody3D:
			child.collision_layer = 0
	lamp(Vector3(678, 4, 0), "accent", 6.0, 18)

func _process(dt: float) -> void:
	for node in rotators:
		if is_instance_valid(node):
			node.rotate_y(dt * 0.55)
	if is_instance_valid(exit_ring):
		exit_ring.scale = Vector3.ONE * (1 + sin(Time.get_ticks_msec() * 0.003) * 0.04)
