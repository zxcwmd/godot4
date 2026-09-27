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
var accents = [Color("ffde00"), Color("d01018"), Color("f2ece0")]

func side_sector(index: int) -> bool:
	return index % 2 == 1 and index < 9

func shape(index: int) -> String:
	# Irregular on purpose: rooms and pipes do not alternate with 3D/2D.
	return ["pipe", "room", "room", "pipe", "mix", "room", "room", "pipe", "room", "room"][clampi(index, 0, 9)]

func half_width(index: int) -> float:
	if index >= 9:
		return 22.0
	var s = shape(index)
	if side_sector(index):
		return 0.0
	return 4.0 if s == "pipe" else (7.0 if s == "mix" else 12.0)

func make_palette(side: bool, sector: int) -> Dictionary:
	var block := clampi(int(sector) >> 1, 0, 4)
	if side:
		# Gluttony — wet meat, teeth, black gut. Another game.
		var acc = [Color("ff4a6a"), Color("ffd0c0"), Color("ff2a1a"), Color("ff8a9a"), Color("ffffff")][block]
		var glo = [Color("ff2a1a"), Color("ff4a6a"), Color("ffd0c0"), Color("ff2a1a"), Color("ff4a6a")][block]
		return {
			"dark": Color("120508"), "floor": Color("4a1418"), "wall": Color("2a0a0e"),
			"metal": Color("e8d8c8"), "accent": acc, "glow": glo, "bone": Color("e8c8b8"),
			"fog": Color("2a0408"), "bg": Color("0a0204"), "sun": Color("ff3040"),
			"ambient": Color("401018"), "glass": Color(0.9, 0.1, 0.15, 0.4)
		}
	# Greed — sun, marble, gold. Not the same space as the gut.
	var acc2 = [Color("ffde00"), Color("e0b000"), Color("fff8d0"), Color("ffde00"), Color("ffffff")][block]
	var glo2 = [Color("d01018"), Color("ffde00"), Color("d01018"), Color("ffde00"), Color("ff2a1a")][block]
	return {
		"dark": Color("1a1410"), "floor": Color("d8d2c4"), "wall": Color("ece6d8"),
		"metal": Color("e0b000"), "accent": acc2, "glow": glo2, "bone": Color("f7f2e8"),
		"fog": Color("c8a070"), "bg": Color("2a2018"), "sun": Color("ffe8a0"),
		"ambient": Color("c0a888"), "glass": Color(0.85, 0.1, 0.1, 0.28)
	}

func dye(node: Node, role: String) -> Node:
	painted.append({"n": node, "r": role})
	return node

func col(role: String) -> Color:
	return pal[role] if pal.has(role) else Color.WHITE

func box(parent: Node3D, at: Vector3, size: Vector3, role: String, glow: float = 0.0, solid: bool = false) -> MeshInstance3D:
	return dye(Forge.box(parent, at, size, col(role), glow, solid), role)

func cyl(parent: Node3D, at: Vector3, radius: float, height: float, role: String, glow: float = 0.0, top: float = -1.0) -> MeshInstance3D:
	return dye(Forge.cyl(parent, at, radius, height, col(role), glow, top), role)

func orb(parent: Node3D, at: Vector3, radius: float, role: String, glow: float = 1.0) -> MeshInstance3D:
	return dye(Forge.orb(parent, at, radius, col(role), glow), role)

func ring(parent: Node3D, at: Vector3, radius: float, role: String, thickness: float = 0.07) -> MeshInstance3D:
	return dye(Forge.ring(parent, at, radius, col(role), thickness), role)

func prism(parent: Node3D, at: Vector3, size: Vector3, role: String, glow: float = 0.0) -> MeshInstance3D:
	return dye(Forge.prism(parent, at, size, col(role), glow), role)

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
		env.fog_density = 0.032 if side else 0.007
		env.ambient_light_energy = 0.35 if side else 0.9
	if sun:
		sun.light_color = pal.sun
		sun.light_energy = 0.15 if side else 1.45

func build(owner_game) -> void:
	game = owner_game
	pal = make_palette(false, 0)
	var environment = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = pal.bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = pal.ambient
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = pal.fog
	env.fog_density = 0.007
	env.fog_light_energy = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_color = pal.sun
	sun.light_energy = 1.45
	add_child(sun)
	build_hub()
	for sector in range(10):
		build_sector(sector)
	for i in range(3):
		build_seal(i)
	build_exit()
	apply_palette(false, 0)

func column(at: Vector3, height: float = 10.0) -> void:
	cyl(self, at + Vector3(0, height * 0.5, 0), 0.55, height, "bone")
	cyl(self, at + Vector3(0, 0.2, 0), 0.85, 0.4, "metal")
	cyl(self, at + Vector3(0, height, 0), 0.9, 0.35, "metal")
	box(self, at + Vector3(0, height + 0.35, 0), Vector3(1.5, 0.18, 1.5), "metal")

func banner(at: Vector3, tall: float = 5.0) -> void:
	box(self, at + Vector3(0, tall, 0), Vector3(0.12, 0.1, 1.6), "metal")
	box(self, at + Vector3(0, tall * 0.5, 0), Vector3(0.04, tall, 1.35), "glow", 0.7)

func blood(at: Vector3, size: Vector3) -> void:
	box(self, at, size, "glow", 0.85)

func lamp(at: Vector3, role: String, energy: float, radius: float) -> void:
	var light = OmniLight3D.new()
	light.light_color = col(role)
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.5
	add_child(light)
	light.position = at
	dye(light, role)
	lights.append(light)

func statue(at: Vector3, h: float = 8.0) -> void:
	cyl(self, at + Vector3(0, h * 0.28, 0), 0.7, h * 0.55, "bone")
	box(self, at + Vector3(0, h * 0.62, 0), Vector3(2.2, h * 0.28, 1.1), "wall")
	orb(self, at + Vector3(0, h * 0.82, 0), 0.55, "bone", 0.0)
	box(self, at + Vector3(0, h * 0.82, -0.5), Vector3(0.7, 0.12, 0.08), "accent", 1)
	cyl(self, at + Vector3(0, h * 0.08, 0), 1.1, 0.2, "metal")

func rib(at: Vector3, span: float = 5.0) -> void:
	var bone = cyl(self, at, 0.12, span, "bone")
	bone.rotation_degrees.z = 70
	var other = cyl(self, at + Vector3(0, 0, 0.4), 0.12, span, "bone")
	other.rotation_degrees.z = -70

func boil(at: Vector3, r: float = 0.7) -> void:
	orb(self, at, r, "glow" if r > 0.8 else "floor", 0.4 if r > 0.8 else 0.0)

func ledge(x: float, y: float, w: float, thick: float = 0.35) -> void:
	box(self, Vector3(x, y, 0), Vector3(w, thick, 3.2), "bone", 0, true)

func build_hub() -> void:
	box(self, Vector3(-36, -0.5, 0), Vector3(44, 1, 20), "dark", 0, true)
	box(self, Vector3(-58, 6, 0), Vector3(1, 12, 20), "dark", 0, true)
	for z in [-10, 10]:
		box(self, Vector3(-29, 5, z), Vector3(58, 10, 0.7), "wall", 0, true)
		box(self, Vector3(-29, 0.04, z * 0.9), Vector3(56, 0.08, 0.2), "metal")
	for x in [-52, -36, -20]:
		column(Vector3(x, 0, -7.4), 9)
		column(Vector3(x, 0, 7.4), 9)
		banner(Vector3(x + 4, 3.5, -9.4), 5)
	statue(Vector3(-44, 0, 6.5), 7)
	for x in range(-50, -16, 8):
		var light_tile = (int(x) / 8) % 2 == 0
		box(self, Vector3(x, 0.03, 0), Vector3(7.6, 0.04, 7.6), "bone" if light_tile else "dark")
	blood(Vector3(-28, 0.06, 2), Vector3(6, 0.04, 1.4))
	blood(Vector3(-40, 0.06, -3), Vector3(3.5, 0.04, 2.2))
	for i in range(3):
		var x = -36 + i * 8
		box(self, Vector3(x, 0.55, -5), Vector3(2.2, 1.1, 2.2), "metal", 0, true)
		box(self, Vector3(x, 1.15, -5), Vector3(1.6, 0.1, 1.6), "accent", 1)
		cyl(self, Vector3(x, 2.4, -5), 0.08, 2.2, "metal")
		var core = orb(self, Vector3(x, 3.5, -5), 0.42, "glow")
		rotators.append(core)
		rotators.append(ring(self, Vector3(x, 3.5, -5), 0.85, "accent"))
		var text = Forge.label(self, Vector3(x, 5.0, -5), ["01 / КЛИНОК", "02 / БАЛЛИСТ", "03 / АРКАНИСТ"][i], 38, col("accent"))
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag_label(text, "accent")
		lamp(Vector3(x, 3.6, -5), "glow", 3.0, 11)
	var signage = Forge.label(self, Vector3(-5, 5.2, 0), "ВНИЗ\n↓  КРОВЬ — ТОПЛИВО  ↓", 56, col("accent"))
	signage.rotation.y = -PI / 2
	tag_label(signage, "accent")
	box(self, Vector3(-14.3, 0.04, 0), Vector3(0.3, 0.1, 20), "accent", 1)
	box(self, Vector3(0, -6, 0), Vector3(1, 22, 20), "dark", 0, true)
	for z in [-10, 10]:
		box(self, Vector3(-7, -8, z), Vector3(14, 16, 0.6), "wall", 0, true)
		box(self, Vector3(-7, -8, z * 0.92), Vector3(13, 16, 0.08), "glow", 0.6)
	lamp(Vector3(-7, -2, 0), "glow", 4.5, 16)
	for y in range(-12, 0, 3):
		rotators.append(ring(self, Vector3(-7, y, 0), 4.6, "accent" if y % 6 == 0 else "glow", 0.1))
	for x in [-29, -21]:
		var arrow = Forge.label(self, Vector3(x, 0.04, 0), "»", 90, col("accent"))
		arrow.rotation_degrees = Vector3(-90, 0, -90)
		tag_label(arrow, "accent")

func build_sector(index: int) -> void:
	if index == 9:
		build_arena()
		return
	var start = index * 65.0
	var center = start + 32.5
	var side = side_sector(index)
	var s = shape(index)
	var zspan = 8.5 if s == "pipe" else (20.0 if s == "mix" else 26.0)
	if side:
		zspan = 8.0
	box(self, Vector3(center, -0.6, 0), Vector3(65, 1.2, zspan), "floor", 0, true)
	if side:
		_build_2d(index, start, center, s)
	else:
		_build_3d(index, start, center, s)
	if index > 0:
		if side:
			boil(Vector3(start, 3.5, -3), 1.4)
			rib(Vector3(start + 1, 4.5, 0), 6)
		else:
			column(Vector3(start, 0, -half_width(index) * 0.85), 9)
			column(Vector3(start, 0, half_width(index) * 0.85), 9)
			box(self, Vector3(start, 9.2, 0), Vector3(1.2, 0.35, minf(16, zspan)), "metal")
		var layer = "КИШКА / 2D" if side else "ЖАДНОСТЬ / 3D"
		var signage = Forge.label(self, Vector3(start - 0.2, 6.8, 0), layer, 46, col("accent"))
		signage.rotation.y = -PI / 2
		tag_label(signage, "accent")
	if index in [7, 8]:
		var g = box(self, Vector3(start, 6, 0), Vector3(0.4, 12, maxf(20, zspan)), "accent", 1, true)
		boss_gates.append(g)
	if index == 0:
		box(self, Vector3(0, 4, 0), Vector3(0.5, 8, 20), "dark", 0, true)

func _build_3d(index: int, start: float, center: float, s: String) -> void:
	var hw = 4.2 if s == "pipe" else (8.0 if s == "mix" else 13.0)
	var ceil_h = 6.2 if s == "pipe" else 13.0
	for zsign in [-1.0, 1.0]:
		box(self, Vector3(center, ceil_h * 0.5, zsign * hw), Vector3(65, ceil_h, 0.7), "wall", 0, true)
		box(self, Vector3(center, 1.4, zsign * (hw - 0.3)), Vector3(65, 0.1, 0.16), "metal")
	if s == "pipe":
		for i in range(6):
			var x = start + 8 + i * 10
			box(self, Vector3(x, ceil_h, 0), Vector3(0.35, 0.25, hw * 2), "metal")
			blood(Vector3(x, 0.07, 0), Vector3(2.2, 0.04, 1.0))
		lamp(Vector3(center, 5.2, 0), "accent", 1.8, 14)
		var mark = Forge.label(self, Vector3(center, 4.6, -hw + 0.4), "ЗЕВ", 72, col("accent"))
		tag_label(mark, "accent")
		return
	if s == "mix":
		# First third is a gold throat, then it dumps you into a plaza.
		box(self, Vector3(start + 10, 3.5, 6.4), Vector3(18, 7, 1.1), "dark", 0, true)
		box(self, Vector3(start + 10, 3.5, -6.4), Vector3(18, 7, 1.1), "dark", 0, true)
		for i in range(3):
			box(self, Vector3(start + 6 + i * 6, 6.2, 0), Vector3(0.3, 0.2, 8), "metal")
		statue(Vector3(center + 8, 0, 0), 9)
		column(Vector3(start + 40, 0, -10), 11)
		column(Vector3(start + 40, 0, 10), 11)
		blood(Vector3(center + 8, 0.07, 0), Vector3(8, 0.05, 8))
		lamp(Vector3(center + 8, 9, 0), "glow", 3.0, 20)
		return
	# Room: open marble court, corners only, one idol.
	for i in range(3):
		var x = start + 16 + i * 16
		var light = i % 2 == 0
		box(self, Vector3(x, 0.04, 0), Vector3(14, 0.05, 14), "bone" if light else "dark")
	column(Vector3(start + 18, 0, -10), 12)
	column(Vector3(start + 18, 0, 10), 12)
	column(Vector3(start + 48, 0, -10), 12)
	column(Vector3(start + 48, 0, 10), 12)
	statue(Vector3(center, 0, -8), 10)
	banner(Vector3(center + 6, 4, -12.4), 7)
	blood(Vector3(center, 0.07, 3), Vector3(6, 0.05, 2.4))
	box(self, Vector3(center, 12.6, 0), Vector3(28, 0.2, 0.35), "metal")
	box(self, Vector3(center, 12.6, 0), Vector3(0.35, 0.2, 18), "metal")
	lamp(Vector3(center, 9.5, 0), "glow", 2.6, 24)
	var title = Forge.label(self, Vector3(center, 8.2, -12), "ДВОР", 88, col("accent"))
	tag_label(title, "accent")

func _build_2d(index: int, start: float, center: float, s: String) -> void:
	# Side-scroller gut: backplane, teeth, platforms. Not a marble hall on its side.
	box(self, Vector3(center, 7, -6), Vector3(65, 14, 0.5), "wall", 0, true)
	for i in range(8):
		boil(Vector3(start + 6 + i * 8, 1.2 + (i % 3) * 0.4, -5.4), 0.5 + (i % 2) * 0.35)
	for i in range(5):
		rib(Vector3(start + 10 + i * 12, 6.5, -2), 5.5)
	# Ceiling teeth.
	for i in range(7):
		prism(self, Vector3(start + 8 + i * 8, 9.4, 0), Vector3(0.8, 1.8, 0.8), "bone")
	if s == "pipe":
		box(self, Vector3(center, 5.4, 0), Vector3(65, 0.4, 4.5), "floor", 0, true)
		for i in range(4):
			ledge(start + 12 + i * 14, 2.2, 6.0)
		blood(Vector3(center, 0.08, 0), Vector3(60, 0.05, 1.2))
		lamp(Vector3(center, 4.2, -3), "glow", 1.4, 14)
		var tight = Forge.label(self, Vector3(center, 7.2, -5.6), "ГЛОТКА", 110, col("accent"))
		tight.modulate.a = 0.8
		tag_label(tight, "accent")
		return
	# Room: stacked platforms, you jump. Spine floor stays so seals/tests don't fall.
	ledge(start + 16, 2.4, 8)
	ledge(start + 30, 4.2, 7)
	ledge(start + 44, 2.8, 9)
	ledge(start + 22, 5.8, 5)
	boil(Vector3(start + 28, 1.4, 1.5), 1.1)
	boil(Vector3(start + 50, 1.6, -1.2), 0.9)
	blood(Vector3(center, 0.08, 0), Vector3(50, 0.05, 1.4))
	lamp(Vector3(center, 6, -4), "accent", 1.8, 16)
	var titles = ["", "КАМЕРА", "", "ГЛОТКА", "", "ЖЕЛУДОК", "", "ПОГОНЯ"]
	var huge = Forge.label(self, Vector3(center, 7.4, -5.6), titles[index] if index < titles.size() else "КИШКА", 120, col("accent"))
	huge.modulate.a = 0.85
	tag_label(huge, "accent")

func build_arena() -> void:
	var start = 585.0
	var center = Vector3(617.5, 0, 0)
	box(self, center + Vector3(0, -0.6, 0), Vector3(65, 1.2, 48), "floor", 0, true)
	box(self, Vector3(650, 6, -17), Vector3(0.7, 12, 14), "wall", 0, true)
	box(self, Vector3(650, 6, 17), Vector3(0.7, 12, 14), "wall", 0, true)
	for z in [-24, 24]:
		box(self, Vector3(center.x, 7, z), Vector3(65, 14, 0.7), "wall", 0, true)
		box(self, Vector3(center.x, 1.2, z * 0.96), Vector3(60, 0.12, 0.16), "metal")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			column(center + Vector3(x * 18, 0, z * 16), 12)
	statue(center + Vector3(0, 0, -18), 11)
	blood(center + Vector3(0, 0.07, 0), Vector3(14, 0.05, 14))
	var core = ring(self, center + Vector3(0, 0.1, 0), 7, "accent", 0.12)
	core.rotation.x = PI / 2
	rotators.append(ring(self, center + Vector3(0, 5, 0), 4.5, "glow", 0.1))
	lamp(center + Vector3(0, 10, 0), "glow", 5.5, 26)
	var title = Forge.label(self, center + Vector3(0, 8.6, -22), "КЛЕТКА", 96, col("accent"))
	tag_label(title, "accent")
	var g = box(self, Vector3(start, 6, 0), Vector3(0.45, 12, 48), "accent", 1, true)
	boss_gates.append(g)

func build_seal(index: int) -> void:
	var x = 122.0 + index * 130.0
	var node = Node3D.new()
	add_child(node)
	node.position = Vector3(x, 2.4, 0)
	var core = box(node, Vector3.ZERO, Vector3(1.05, 1.05, 1.05), "glow", 1)
	core.rotation_degrees = Vector3(45, 35, 45)
	rotators.append(core)
	var halo = ring(node, Vector3.ZERO, 1.5, "accent")
	halo.rotation.x = PI / 2
	rotators.append(halo)
	var caption = Forge.label(node, Vector3(0, 2.6, 0), "ПЕЧАТЬ / 0" + str(index + 1), 38, col("accent"))
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag_label(caption, "accent")
	seals.append(node)
	lamp(Vector3(x, 3.3, 0), "glow", 5.0, 14)
	var gate = box(self, Vector3(x + 6, 4, 0), Vector3(0.35, 8, 20), "accent", 1, true)
	for z in range(-9, 10, 2):
		box(gate, Vector3(-0.01, 0, z), Vector3(0.08, 8, 0.06), "glow", 1)
	gates.append(gate)

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
		box(self, Vector3(672, 1, z * 0.96), Vector3(44, 0.1, 0.14), "metal")
	column(Vector3(668, 0, -7), 8)
	column(Vector3(668, 0, 7), 8)
	column(Vector3(682, 0, -7), 8)
	column(Vector3(682, 0, 7), 8)
	blood(Vector3(670, 0.07, 0), Vector3(18, 0.05, 3))
	exit_gate = box(self, Vector3(652, 4, 0), Vector3(0.35, 8, 20), "glow", 1, true)
	exit_sign = Forge.label(self, Vector3(651, 6, 0), "АД УДЕРЖИВАЕТ ВЫХОД", 36, col("glow"))
	exit_sign.rotation.y = -PI / 2
	tag_label(exit_sign, "glow")
	exit_ring = ring(self, Vector3(682, 3, 0), 2.7, "accent", 0.16)
	exit_ring.rotation.z = PI / 2
	var signage = Forge.label(self, Vector3(684, 7.4, 0), "РАЗОРВИ СЛОЙ", 72, col("accent"))
	signage.rotation.y = -PI / 2
	tag_label(signage, "accent")

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
			node.rotate_y(dt * 0.7)
	if is_instance_valid(exit_ring):
		exit_ring.scale = Vector3.ONE * (1 + sin(Time.get_ticks_msec() * 0.003) * 0.04)
