extends Node3D
const DARK = Color("111c2a")
const STEEL = Color("263444")
const LIME = Color("d4ff64")
const CYAN = Color("64e3fa")
const PINK = Color("ff608c")
var game
var seals = []
var gates = []
var rotators = []
var accents = [LIME, CYAN, PINK]
var exit_ring: MeshInstance3D
var exit_gate: MeshInstance3D
var exit_sign: Label3D

func build(owner_game) -> void:
	game = owner_game
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080f1b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8aa1be")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("071018")
	env.fog_density = 0.012
	env.fog_light_energy = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 0.7
	environment.environment = env
	add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("bed9ff")
	sun.light_energy = 0.95
	add_child(sun)
	build_hub()
	for sector in range(7):
		build_sector(sector)
	for i in range(3):
		build_seal(i)
	build_exit()

func build_hub() -> void:
	Forge.box(self, Vector3(-36, -0.5, 0), Vector3(44, 1, 20), DARK, 0, true)
	Forge.box(self, Vector3(-58, 6, 0), Vector3(1, 12, 20), DARK, 0, true)
	for z in [-10, 10]:
		Forge.box(self, Vector3(-29, 4, z), Vector3(58, 8, 0.7), DARK, 0, true)
		Forge.box(self, Vector3(-29, 0.05, z*0.88), Vector3(56, 0.04, 0.09), LIME, 1)
		for x in range(-54, 0, 8):
			Forge.box(self, Vector3(x, 4, z), Vector3(0.4, 8, 1.2), STEEL)
			Forge.box(self, Vector3(x, 4, z*0.92), Vector3(0.08, 6, 0.08), CYAN, 1)
	for x in range(-54, -14, 4):
		Forge.box(self, Vector3(x, 0.01, 0), Vector3(0.04, 0.03, 18), STEEL)
	for z in range(-8, 9, 4):
		Forge.box(self, Vector3(-36, 0.01, z), Vector3(42, 0.03, 0.04), STEEL)
	for i in range(3):
		var x = -36 + i * 8
		Forge.box(self, Vector3(x, 0.7, -5), Vector3(3, 1.4, 2), STEEL, 0, true)
		Forge.box(self, Vector3(x, 1.43, -5), Vector3(2.8, 0.06, 1.8), accents[i], 1)
		var core = Forge.orb(self, Vector3(x, 3, -5), 0.55, accents[i])
		rotators.append(core)
		var ring = Forge.ring(self, Vector3(x, 3, -5), 1.2, accents[i])
		ring.rotation_degrees.x = 70
		rotators.append(ring)
		var text = Forge.label(self, Vector3(x, 4.8, -5), ["01 / КЛИНОК", "02 / БАЛЛИСТ", "03 / АРКАНИСТ"][i], 38, accents[i])
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lamp(Vector3(x, 3.4, -5), accents[i], 3.2, 10)
	var signage = Forge.label(self, Vector3(-5, 5, 0), "ВНИЗ — ЗНАЧИТ ВПЕРЁД\n↓   ВХОД В ЦИКЛ   ↓", 58, LIME)
	signage.rotation.y = -PI / 2
	Forge.box(self, Vector3(-14.3, 0.04, 0), Vector3(0.3, 0.08, 20), LIME, 1)
	Forge.box(self, Vector3(0, -6, 0), Vector3(1, 22, 20), DARK, 0, true)
	# Visible shaft so the drop reads as a deliberate entrance, not a missing floor.
	for z in [-10, 10]:
		Forge.box(self, Vector3(-7, -8, z), Vector3(14, 16, 0.6), DARK, 0, true)
		Forge.box(self, Vector3(-7, -8, z * 0.92), Vector3(13, 16, 0.08), CYAN, 1)
	lamp(Vector3(-7, -2, 0), CYAN, 4.5, 16)
	for y in range(-12, 0, 2):
		rotators.append(Forge.ring(self, Vector3(-7, y, 0), 5.0, CYAN if y%4 == 0 else LIME, 0.08))
	for x in [-29, -25, -21, -17]:
		var arrow = Forge.label(self, Vector3(x, 0.04, 0), "»", 80, LIME)
		arrow.rotation_degrees = Vector3(-90, 0, -90)

func build_sector(index: int) -> void:
	var start = index * 65.0
	var center = start + 32.5
	var side = index % 2 == 1
	var color = accents[mini(index / 2, 2)]
	Forge.box(self, Vector3(center, -0.6, 0), Vector3(65, 1.2, 20), DARK, 0, true)
	for z in [-10, 10]:
		if side and z == 10:
			continue # Open the near wall for the side-on camera.
		Forge.box(self, Vector3(center, 6, z), Vector3(65, 12, 0.6), DARK, 0, true)
		Forge.box(self, Vector3(center, 2.1, z*0.96), Vector3(65, 0.045, 0.07), color, 1)
		Forge.box(self, Vector3(center, 8.8, z*0.96), Vector3(65, 0.09, 0.1), color, 1)
		for x in range(int(start)+4, int(start)+65, 10):
			Forge.box(self, Vector3(x, 5.5, z), Vector3(0.7, 11, 1.4), STEEL)
			Forge.box(self, Vector3(x, 5.5, z*0.92), Vector3(0.1, 7.8, 0.06), color, 1)
			Forge.box(self, Vector3(x+4, 5.0, z*0.967), Vector3(4.5, 2.8, 0.08), Color("1b2a3b"))
			for row in range(3):
				Forge.box(self, Vector3(x+4, 4.25+row*0.5, z*0.96), Vector3(3.4, 0.045, 0.04), STEEL, 1)
	for x in range(int(start), int(start)+65, 5):
		Forge.box(self, Vector3(x, 0.018, 0), Vector3(0.04, 0.024, 20), STEEL)
	for z in [-8, -4, 0, 4, 8]:
		Forge.box(self, Vector3(center, 0.02, z), Vector3(65, 0.02, 0.03), STEEL)
	for z in [-8.5, 8.5]:
		Forge.box(self, Vector3(center, 0.04, z), Vector3(64, 0.035, 0.075), color, 1)
	lamp(Vector3(center, 7.5, 0), color, 2.4, 22)
	# Large ribs and overhead light bars establish the single megastructure.
	if not side:
		for x in range(int(start)+5, int(start)+65, 15):
			Forge.box(self, Vector3(x, 11.3, 0), Vector3(0.8, 0.8, 20), STEEL)
			Forge.box(self, Vector3(x, 10.86, 0), Vector3(0.35, 0.05, 13), CYAN, 1)
		for offset in [23, 43]:
			var z = -5 if offset == 23 else 5
			Forge.box(self, Vector3(start+offset, 1, z), Vector3(3, 2, 3), STEEL, 0, true)
			Forge.box(self, Vector3(start+offset, 2.05, z), Vector3(3, 0.08, 3), color, 1)
	else:
		# Low obstacles can be vaulted; enemies have jump assistance.
		for offset in [19, 38]:
			Forge.box(self, Vector3(start+offset, 0.65, 0), Vector3(2.6, 1.3, 5), STEEL, 0, true)
			Forge.box(self, Vector3(start+offset, 1.32, 0), Vector3(2.6, 0.04, 5), color, 1)
		var huge = Forge.label(self, Vector3(center, 6.2, -9.6), ["", "01 / СДВИГ", "", "02 / РАЗРЫВ", "", "03 / ПЕРЕГРУЗ"][index], 130, color)
		huge.modulate.a = 0.7
	# Mode boundary — tall rectangular neon gateway, not a loading screen.
	if index > 0:
		for z in [-8, 8]:
			Forge.box(self, Vector3(start, 4, z), Vector3(0.3, 8, 0.3), color, 1)
		Forge.box(self, Vector3(start, 8, 0), Vector3(0.3, 0.3, 16), color, 1)
		var signage = Forge.label(self, Vector3(start-0.2, 6.6, 0), "СДВИГ / 2D" if side else "ВОЗВРАТ / 3D", 54, color)
		signage.rotation.y = -PI/2
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
	var ring = Forge.ring(node, Vector3.ZERO, 1.55, color)
	ring.rotation.x = PI/2
	rotators.append(ring)
	var label = Forge.label(node, Vector3(0, 2.6, 0), "ПЕЧАТЬ / 0" + str(index+1), 38, color)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	seals.append(node)
	lamp(Vector3(x, 3.2, 0), color, 5.0, 14)
	var gate = Forge.box(self, Vector3(x+6, 4, 0), Vector3(0.3, 8, 20), Color(color, 0.2), 1, true)
	for z in range(-9, 10, 2):
		Forge.box(gate, Vector3(-0.01, 0, z), Vector3(0.06, 8, 0.045), color, 1)
	gates.append(gate)

func open_seal(index: int) -> void:
	seals[index].hide()
	gates[index].hide()
	for child in gates[index].get_children():
		if child is StaticBody3D:
			child.collision_layer = 0
	game.fx.wave(seals[index].global_position, accents[index], 12)

func build_exit() -> void:
	# The evacuation chute remains part of this same scene.
	Forge.box(self, Vector3(497.5, -0.6, 0), Vector3(85, 1.2, 20), DARK, 0, true)
	Forge.box(self, Vector3(540, 5, 0), Vector3(1, 10, 20), DARK, 0, true)
	for z in [-10, 10]:
		Forge.box(self, Vector3(497.5, 5, z), Vector3(85, 10, 0.6), DARK, 0, true)
		Forge.box(self, Vector3(497, 1, z*0.96), Vector3(84, 0.06, 0.09), PINK, 1)
		Forge.box(self, Vector3(497, 7, z*0.96), Vector3(84, 0.1, 0.09), LIME, 1)
	for x in range(459, 538, 9):
		for z in [-7, 7]:
			Forge.box(self, Vector3(x, 4, z), Vector3(0.4, 8, 0.4), STEEL)
			Forge.box(self, Vector3(x, 0.035, z), Vector3(7.5, 0.04, 0.2), LIME, 1)
		Forge.box(self, Vector3(x, 8, 0), Vector3(0.4, 0.4, 14), STEEL)
		Forge.box(self, Vector3(x, 7.76, 0), Vector3(0.15, 0.04, 13), LIME, 1)
	for x in [473, 493, 513]:
		Forge.box(self, Vector3(x, 0.65, 0), Vector3(1.5, 1.3, 20), STEEL, 0, true)
		Forge.box(self, Vector3(x, 1.32, 0), Vector3(1.5, 0.04, 20), PINK, 1)
	exit_gate = Forge.box(self, Vector3(453, 4, 0), Vector3(0.3, 8, 20), Color(PINK, 0.25), 1, true)
	exit_sign = Forge.label(self, Vector3(452, 6, 0), "СЕРДЦЕ УДЕРЖИВАЕТ ВЫХОД", 36, PINK)
	exit_sign.rotation.y = -PI/2
	exit_ring = Forge.ring(self, Vector3(537, 3, 0), 2.7, LIME, 0.16)
	exit_ring.rotation.z = PI/2
	var signage = Forge.label(self, Vector3(539, 7.4, 0), "РАЗОРВИ ЦИКЛ", 72, LIME)
	signage.rotation.y = -PI/2
	for z in [-7, 7]:
		Forge.box(self, Vector3(421, 0.1, z), Vector3(56, 0.2, 0.2), PINK, 1)

func unlock_exit() -> void:
	exit_gate.hide()
	exit_sign.hide()
	for child in exit_gate.get_children():
		if child is StaticBody3D: child.collision_layer = 0
	lamp(Vector3(530, 4, 0), LIME, 6.0, 18)

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
