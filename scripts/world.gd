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

func make_palette(side: bool, sector: int) -> Dictionary:
	var block := clampi(int(sector) >> 1, 0, 4)
	if side:
		# Terminal hell — black void, gold stamp, blood cutout. Another game.
		var acc = [Color("ff2a1a"), Color("ffde00"), Color("ffffff"), Color("ff2a1a"), Color("ffde00")][block]
		var glo = [Color("ffde00"), Color("ff2a1a"), Color("ffde00"), Color("ffffff"), Color("ff2a1a")][block]
		return {
			"dark": Color("000000"), "floor": Color("0a0a0a"), "wall": Color("050505"),
			"metal": Color("ffde00"), "accent": acc, "glow": glo, "bone": Color("f4f0e4"),
			"fog": Color("000000"), "bg": Color("000000"), "sun": Color("ffde00"),
			"ambient": Color("3a1008"), "glass": Color(1.0, 0.15, 0.1, 0.35)
		}
	# Marble palace — cream stone, gold veins, blood on the floor.
	var acc2 = [Color("ffde00"), Color("d01018"), Color("ffde00"), Color("ffffff"), Color("d01018")][block]
	var glo2 = [Color("d01018"), Color("ffde00"), Color("d01018"), Color("ffde00"), Color("ff2a1a")][block]
	return {
		"dark": Color("12100e"), "floor": Color("d8d2c4"), "wall": Color("ece6d8"),
		"metal": Color("e0b000"), "accent": acc2, "glow": glo2, "bone": Color("f7f2e8"),
		"fog": Color("6a5040"), "bg": Color("1a1410"), "sun": Color("ffe8a0"),
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
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = pal.fog
	env.fog_density = 0.012
	env.fog_light_energy = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_color = pal.sun
	sun.light_energy = 1.35
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

func card(at: Vector3, size: Vector3, role: String = "bone") -> void:
	box(self, at, size, role, 0.0 if role != "accent" else 0.8)

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

func build_hub() -> void:
	box(self, Vector3(-36, -0.5, 0), Vector3(44, 1, 20), "dark", 0, true)
	box(self, Vector3(-58, 6, 0), Vector3(1, 12, 20), "dark", 0, true)
	for z in [-10, 10]:
		box(self, Vector3(-29, 5, z), Vector3(58, 10, 0.7), "wall", 0, true)
		box(self, Vector3(-29, 0.04, z * 0.9), Vector3(56, 0.08, 0.2), "metal")
	# Sparse giant columns, not a picket fence.
	for x in [-52, -36, -20]:
		column(Vector3(x, 0, -7.4), 9)
		column(Vector3(x, 0, 7.4), 9)
		banner(Vector3(x + 4, 3.5, -9.4), 5)
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
	box(self, Vector3(center, -0.6, 0), Vector3(65, 1.2, 20), "floor", 0, true)
	if side:
		_build_2d(index, start, center)
	else:
		_build_3d(index, start, center)
	if index > 0:
		column(Vector3(start, 0, -8), 9)
		column(Vector3(start, 0, 8), 9)
		box(self, Vector3(start, 9.2, 0), Vector3(1.2, 0.35, 16), "metal")
		var signage = Forge.label(self, Vector3(start - 0.2, 6.8, 0), "LAYER / 2D" if side else "LAYER / 3D", 50, col("accent"))
		signage.rotation.y = -PI / 2
		tag_label(signage, "accent")
	if index in [7, 8]:
		var g = box(self, Vector3(start, 6, 0), Vector3(0.4, 12, 20), "accent", 1, true)
		boss_gates.append(g)
	if index == 0:
		box(self, Vector3(0, 4, 0), Vector3(0.5, 8, 20), "dark", 0, true)

func _build_3d(index: int, start: float, center: float) -> void:
	# Marble hall: checker plates, few fat columns, blood, gold ribs. Not a pipe of posts.
	for z in [-10, 10]:
		box(self, Vector3(center, 7, z), Vector3(65, 14, 0.7), "wall", 0, true)
		box(self, Vector3(center, 1.6, z * 0.96), Vector3(65, 0.12, 0.18), "metal")
		box(self, Vector3(center, 10.5, z * 0.96), Vector3(65, 0.1, 0.14), "glow", 0.4)
	# Throat then chamber: inner jaws at the entrance only.
	box(self, Vector3(start + 6, 3.5, 6.2), Vector3(12, 7, 1.2), "dark", 0, true)
	box(self, Vector3(start + 6, 3.5, -6.2), Vector3(12, 7, 1.2), "dark", 0, true)
	for i in range(4):
		var x = start + 14 + i * 14
		var light = i % 2 == 0
		box(self, Vector3(x, 0.04, 0), Vector3(12, 0.05, 12), "bone" if light else "dark")
		if i == 1 or i == 3:
			column(Vector3(x, 0, -7.2), 11)
			column(Vector3(x, 0, 7.2), 11)
			banner(Vector3(x + 3, 4, -9.5), 6)
		if i == 0 or i == 2:
			blood(Vector3(x + 2, 0.07, 3 - i), Vector3(4.5, 0.05, 1.8))
			prism(self, Vector3(x - 3, 0.4, 7.2), Vector3(1.4, 1.1, 2.2), "glow", 0.5)
	lamp(Vector3(center, 8.5, 0), "glow", 2.4, 22)
	# Gold ceiling rib, one, not a grid.
	box(self, Vector3(center, 12.4, 0), Vector3(40, 0.2, 0.35), "metal")
	box(self, Vector3(center, 12.4, 0), Vector3(0.35, 0.2, 16), "metal")

func _build_2d(index: int, start: float, center: float) -> void:
	# Paper theater: black void, flat cards, stamps. No colonnade.
	box(self, Vector3(center, 6, -10), Vector3(65, 12, 0.5), "dark", 0, true)
	for i in range(5):
		var x = start + 8 + i * 12
		var w = 9.0 if i % 2 == 0 else 6.0
		var h = 9.0 if i % 2 == 0 else 12.0
		card(Vector3(x, h * 0.45, -9.55), Vector3(w, h, 0.08), "bone" if i % 2 == 0 else "dark")
		box(self, Vector3(x, 0.5, -9.4), Vector3(w * 0.4, 0.12, 0.06), "accent", 1)
	blood(Vector3(center, 0.06, 0), Vector3(50, 0.04, 0.9))
	for offset in [18.0, 40.0]:
		# Stage flats, thin in Z — cardboard, not rooms.
		card(Vector3(start + offset, 2.2, 0), Vector3(0.18, 4.4, 5.5), "metal")
		prism(self, Vector3(start + offset, 4.6, 0), Vector3(0.4, 1.2, 2.4), "accent", 0.9)
	var titles = ["", "01 / КУЛИСА", "", "02 / РЕЗНЯ", "", "03 / ПЛОСКОСТЬ", "", "ПОГОНЯ"]
	var huge = Forge.label(self, Vector3(center, 6.4, -9.3), titles[index] if index < titles.size() else "АД", 140, col("accent"))
	huge.modulate.a = 0.85
	tag_label(huge, "accent")
	lamp(Vector3(center, 6, -6), "accent", 1.6, 18)

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
	column(Vector3(x + 6, 0, -8.5), 9)
	column(Vector3(x + 6, 0, 8.5), 9)

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
