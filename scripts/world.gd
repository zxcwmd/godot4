extends Node3D
const DARK = Forge.SOOT
const STONE = Forge.STONE
const AMBER = Forge.AMBER
const COPPER = Forge.COPPER
const BLOOD = Forge.BLOOD
var game
var seals = []
var gates = []
var rotators = []
var accents = [AMBER, COPPER, BLOOD]
var exit_ring: MeshInstance3D
var exit_gate: MeshInstance3D
var exit_sign: Label3D

func build(owner_game) -> void:
	game = owner_game
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("140c08")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4a070")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("2a180c")
	env.fog_density = 0.016
	env.fog_light_energy = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.8
	environment.environment = env
	add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("e8c888")
	sun.light_energy = 1.05
	add_child(sun)
	build_hub()
	for sector in range(7):
		build_sector(sector)
	for i in range(3):
		build_seal(i)
	build_exit()

func pillar(at: Vector3, height: float = 8.0) -> void:
	Forge.cyl(self, at + Vector3(0, height * 0.5, 0), 0.38, height, STONE)
	Forge.box(self, at + Vector3(0, 0.15, 0), Vector3(1.15, 0.3, 1.15), Forge.BRONZE)
	Forge.box(self, at + Vector3(0, height, 0), Vector3(1.25, 0.28, 1.25), Forge.BRONZE)
	Forge.box(self, at + Vector3(0, height + 0.22, 0), Vector3(0.7, 0.18, 0.7), AMBER, 0.4)

func brazier(at: Vector3, color: Color) -> void:
	Forge.cyl(self, at, 0.32, 0.55, STONE)
	Forge.cyl(self, at + Vector3(0, 0.28, 0), 0.38, 0.12, Forge.BRONZE, 0.0, 0.28)
	var fire = Forge.orb(self, at + Vector3(0, 0.55, 0), 0.26, color, 1.2)
	rotators.append(fire)
	lamp(at + Vector3(0, 0.7, 0), color, 3.4, 11)

func build_hub() -> void:
	Forge.box(self, Vector3(-36, -0.5, 0), Vector3(44, 1, 20), DARK, 0, true)
	Forge.box(self, Vector3(-58, 6, 0), Vector3(1, 12, 20), DARK, 0, true)
	for z in [-10, 10]:
		Forge.box(self, Vector3(-29, 4, z), Vector3(58, 8, 0.7), DARK, 0, true)
		Forge.box(self, Vector3(-29, 0.04, z * 0.88), Vector3(56, 0.05, 0.12), AMBER, 0.6)
		for x in range(-54, 0, 8):
			pillar(Vector3(x, 0, z * 0.82), 7.5)
	for x in range(-54, -14, 6):
		Forge.box(self, Vector3(x, 0.02, 0), Vector3(0.08, 0.03, 16), Forge.BRONZE)
		Forge.box(self, Vector3(x + 3, 0.02, 0), Vector3(2.2, 0.02, 2.2), AMBER, 0.3)
	for i in range(3):
		var x = -36 + i * 8
		Forge.box(self, Vector3(x, 0.7, -5), Vector3(3.2, 1.4, 2.2), STONE, 0, true)
		Forge.box(self, Vector3(x, 1.42, -5), Vector3(2.9, 0.08, 1.9), accents[i], 0.8)
		pillar(Vector3(x - 1.6, 0, -6.4), 3.2)
		pillar(Vector3(x + 1.6, 0, -6.4), 3.2)
		var core = Forge.orb(self, Vector3(x, 3, -5), 0.5, accents[i])
		rotators.append(core)
		var halo = Forge.ring(self, Vector3(x, 3, -5), 1.15, accents[i])
		halo.rotation_degrees.x = 70
		rotators.append(halo)
		var text = Forge.label(self, Vector3(x, 4.8, -5), ["01 / КЛИНОК", "02 / БАЛЛИСТ", "03 / АРКАНИСТ"][i], 38, accents[i])
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lamp(Vector3(x, 3.4, -5), accents[i], 3.0, 10)
	var signage = Forge.label(self, Vector3(-5, 5, 0), "ВНИЗ — ЗНАЧИТ ВПЕРЁД\n↓   ВХОД В УСЫПАЛЬНИЦУ   ↓", 58, AMBER)
	signage.rotation.y = -PI / 2
	Forge.box(self, Vector3(-14.3, 0.04, 0), Vector3(0.3, 0.08, 20), AMBER, 1)
	Forge.box(self, Vector3(0, -6, 0), Vector3(1, 22, 20), DARK, 0, true)
	for z in [-10, 10]:
		Forge.box(self, Vector3(-7, -8, z), Vector3(14, 16, 0.6), DARK, 0, true)
		Forge.box(self, Vector3(-7, -8, z * 0.92), Vector3(13, 16, 0.08), AMBER, 0.7)
	lamp(Vector3(-7, -2, 0), AMBER, 4.2, 16)
	for y in range(-12, 0, 2):
		rotators.append(Forge.ring(self, Vector3(-7, y, 0), 5.0, BLOOD if y % 4 == 0 else AMBER, 0.08))
	for x in [-29, -25, -21, -17]:
		var arrow = Forge.label(self, Vector3(x, 0.04, 0), "»", 80, AMBER)
		arrow.rotation_degrees = Vector3(-90, 0, -90)
	brazier(Vector3(-48, 0.3, 6), AMBER)
	brazier(Vector3(-48, 0.3, -6), BLOOD)

func build_sector(index: int) -> void:
	var start = index * 65.0
	var center = start + 32.5
	var side = index % 2 == 1
	var color = accents[mini(index / 2, 2)]
	Forge.box(self, Vector3(center, -0.6, 0), Vector3(65, 1.2, 20), DARK, 0, true)
	for z in [-10, 10]:
		if side and z == 10:
			continue
		Forge.box(self, Vector3(center, 6, z), Vector3(65, 12, 0.6), DARK, 0, true)
		Forge.box(self, Vector3(center, 2.2, z * 0.96), Vector3(65, 0.08, 0.1), color, 0.6)
		Forge.box(self, Vector3(center, 8.6, z * 0.96), Vector3(65, 0.14, 0.12), color, 0.5)
		for x in range(int(start) + 4, int(start) + 65, 10):
			pillar(Vector3(x, 0, z * 0.78), 8.5)
			Forge.box(self, Vector3(x + 4, 5.0, z * 0.97), Vector3(4.2, 2.6, 0.08), Forge.BRONZE)
			for row in range(3):
				Forge.box(self, Vector3(x + 4, 4.3 + row * 0.45, z * 0.96), Vector3(3.2, 0.05, 0.04), color, 0.4)
	for x in range(int(start), int(start) + 65, 8):
		Forge.box(self, Vector3(x, 0.03, 0), Vector3(1.8, 0.03, 1.8), color, 0.25)
		Forge.box(self, Vector3(x + 4, 0.02, 0), Vector3(0.06, 0.02, 16), Forge.BRONZE)
	lamp(Vector3(center, 7.2, 0), color, 2.2, 20)
	if not side:
		for x in range(int(start) + 5, int(start) + 65, 15):
			Forge.box(self, Vector3(x, 11.0, 0), Vector3(1.4, 0.4, 18), STONE)
			Forge.box(self, Vector3(x, 10.7, 0), Vector3(0.4, 0.08, 12), color, 0.5)
		for offset in [23, 43]:
			var z = -5 if offset == 23 else 5
			brazier(Vector3(start + offset, 0.3, z), color)
	else:
		for offset in [19, 38]:
			Forge.box(self, Vector3(start + offset, 0.65, 0), Vector3(2.6, 1.3, 5), STONE, 0, true)
			Forge.box(self, Vector3(start + offset, 1.32, 0), Vector3(2.6, 0.06, 5), color, 0.7)
		var huge = Forge.label(self, Vector3(center, 6.2, -9.6), ["", "01 / СДВИГ", "", "02 / РАЗРЫВ", "", "03 / ПЕРЕГРУЗ"][index], 130, color)
		huge.modulate.a = 0.55
	if index > 0:
		pillar(Vector3(start, 0, -8), 8)
		pillar(Vector3(start, 0, 8), 8)
		Forge.box(self, Vector3(start, 8.2, 0), Vector3(0.8, 0.4, 16), Forge.BRONZE)
		var signage = Forge.label(self, Vector3(start - 0.2, 6.6, 0), "СДВИГ / 2D" if side else "ВОЗВРАТ / 3D", 54, color)
		signage.rotation.y = -PI / 2
	if index == 0:
		Forge.box(self, Vector3(0, 4, 0), Vector3(0.5, 8, 20), DARK, 0, true)

func build_seal(index: int) -> void:
	var x = 122.0 + index * 130.0
	var color = accents[index]
	var node = Node3D.new()
	add_child(node)
	node.position = Vector3(x, 2.3, 0)
	var core = Forge.box(node, Vector3.ZERO, Vector3(1.1, 1.1, 1.1), color, 1)
	core.rotation_degrees = Vector3(45, 25, 45)
	rotators.append(core)
	var halo = Forge.ring(node, Vector3.ZERO, 1.55, color)
	halo.rotation.x = PI / 2
	rotators.append(halo)
	var caption = Forge.label(node, Vector3(0, 2.6, 0), "ПЕЧАТЬ / 0" + str(index + 1), 38, color)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	seals.append(node)
	lamp(Vector3(x, 3.2, 0), color, 5.0, 14)
	var gate = Forge.box(self, Vector3(x + 6, 4, 0), Vector3(0.35, 8, 20), Color(color, 0.22), 1, true)
	for z in range(-9, 10, 2):
		Forge.box(gate, Vector3(-0.01, 0, z), Vector3(0.08, 8, 0.06), color, 1)
	gates.append(gate)
	pillar(Vector3(x + 6, 0, -8.5), 8)
	pillar(Vector3(x + 6, 0, 8.5), 8)

func open_seal(index: int) -> void:
	seals[index].hide()
	gates[index].hide()
	for child in gates[index].get_children():
		if child is StaticBody3D:
			child.collision_layer = 0
	game.fx.wave(seals[index].global_position, accents[index], 12)

func build_exit() -> void:
	Forge.box(self, Vector3(497.5, -0.6, 0), Vector3(85, 1.2, 20), DARK, 0, true)
	Forge.box(self, Vector3(540, 5, 0), Vector3(1, 10, 20), DARK, 0, true)
	for z in [-10, 10]:
		Forge.box(self, Vector3(497.5, 5, z), Vector3(85, 10, 0.6), DARK, 0, true)
		Forge.box(self, Vector3(497, 1, z * 0.96), Vector3(84, 0.08, 0.1), BLOOD, 0.7)
		Forge.box(self, Vector3(497, 7, z * 0.96), Vector3(84, 0.12, 0.1), AMBER, 0.6)
	for x in range(459, 538, 9):
		pillar(Vector3(x, 0, -7), 7)
		pillar(Vector3(x, 0, 7), 7)
		Forge.box(self, Vector3(x, 8, 0), Vector3(0.5, 0.3, 14), STONE)
		Forge.box(self, Vector3(x, 7.76, 0), Vector3(0.16, 0.05, 12), AMBER, 0.5)
	for x in [473, 493, 513]:
		Forge.box(self, Vector3(x, 0.65, 0), Vector3(1.5, 1.3, 20), STONE, 0, true)
		Forge.box(self, Vector3(x, 1.32, 0), Vector3(1.5, 0.05, 20), BLOOD, 0.8)
	exit_gate = Forge.box(self, Vector3(453, 4, 0), Vector3(0.3, 8, 20), Color(BLOOD, 0.25), 1, true)
	exit_sign = Forge.label(self, Vector3(452, 6, 0), "СЕРДЦЕ УДЕРЖИВАЕТ ВЫХОД", 36, BLOOD)
	exit_sign.rotation.y = -PI / 2
	exit_ring = Forge.ring(self, Vector3(537, 3, 0), 2.7, AMBER, 0.16)
	exit_ring.rotation.z = PI / 2
	var signage = Forge.label(self, Vector3(539, 7.4, 0), "РАЗОРВИ ЦИКЛ", 72, AMBER)
	signage.rotation.y = -PI / 2
	for z in [-7, 7]:
		Forge.box(self, Vector3(421, 0.1, z), Vector3(56, 0.2, 0.2), BLOOD, 1)

func unlock_exit() -> void:
	exit_gate.hide()
	exit_sign.hide()
	for child in exit_gate.get_children():
		if child is StaticBody3D:
			child.collision_layer = 0
	lamp(Vector3(530, 4, 0), AMBER, 6.0, 18)

func lamp(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.6
	add_child(light)
	light.position = at

func _process(dt: float) -> void:
	for node in rotators:
		node.rotate_y(dt * 0.5)
	if is_instance_valid(exit_ring):
		exit_ring.scale = Vector3.ONE * (1 + sin(Time.get_ticks_msec() * 0.003) * 0.04)
