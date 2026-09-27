extends CharacterBody3D
const WEAPONS = [
	["КАТАНА / ИМПУЛЬС", "ПАРНЫЕ СЕРПЫ", "РАПИРА / ИГЛА", "РУКИ-БЕНЗОПИЛЫ", "КОСА / ЖНЕЦ"],
	["РЕВОЛЬВЕР / ШЕСТЬ", "ДИСКИ / РИКОШЕТ", "РЕЛЬСОТРОН / ПРОБОЙ", "ДРОБОВИК / РАЗЛОМ", "АРБАЛЕТ / КОЛ", "ГВОЗДОМЁТ", "ГАРПУН / КРЮК", "КАДИЛО / ДУГА"],
	["СИНТЕЗ СТИХИЙ"]
]
const SPELLS = {
	"000": ["СТОЛПЫ ПЕПЛА", 90.0, 12.0, "burn", 26.0, 1.05],
	"001": ["ДЫХАНИЕ УРНЫ", 38.0, 7.5, "burn", 22.0, 0.55],
	"002": ["КОМЕТА ПЛОТИ", 130.0, 4.5, "burn", 32.0, 1.15],
	"011": ["КРЯЖ КОСТЕЙ", 70.0, 14.0, "freeze", 20.0, 0.85],
	"012": ["ТРИПТИХ", 55.0, 8.0, "", 30.0, 1.05],
	"022": ["ЦЕПЬ МОЛНИЙ", 48.0, 6.0, "", 24.0, 0.8],
	"111": ["ЧАСОВНЯ ЛЬДА", 40.0, 9.0, "freeze", 24.0, 1.0],
	"112": ["НЕБОПОГРЕБЕНИЕ", 85.0, 11.0, "freeze", 28.0, 1.05],
	"122": ["ОРБИТА БУРИ", 34.0, 8.0, "", 26.0, 0.7],
	"222": ["ШАГ ГРОМА", 160.0, 16.0, "", 30.0, 1.1]
}
var game
var camera: Camera3D
var avatar: Node3D
var viewmodel: Node3D
var side_weapon: Node3D
var hp = 100.0
var energy = 100.0
var class_id = 0
var weapon = 0
var side_mode = false
var yaw = -PI / 2
var pitch = 0.0
var cooldown = 0.0
var dash_cooldown = 0.0
var dash_time = 0.0
var dash_dir = Vector3.ZERO
var invincible = 0.0
var jumps = 0
var coyote = 0.0
var jump_buffer = 0.0
var recoil = 0.0
var walk_clock = 0.0
var elements = [0, 0, 0]
var invoked = "000"
var aim = Vector3.RIGHT
var sensitivity = 0.0024
var reduced_motion = false
var comet = false
var storm_time = 0.0
var storm_tick = 0.0
var storm_orbs: Array = []

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.near = 0.05
	camera.far = 160
	camera.fov = 92
	add_child(camera)
	camera.current = true
	avatar = Puppet.new()
	add_child(avatar)
	avatar.build(Puppet.PLAYER, Forge.CYAN)
	avatar.visible = false
	side_weapon = Node3D.new()
	if avatar.hand:
		avatar.hand.add_child(side_weapon)
	else:
		add_child(side_weapon)
		side_weapon.position.y = 1.05
	side_weapon.visible = false
	viewmodel = Node3D.new()
	camera.add_child(viewmodel)
	build_weapon()

func set_class(value: int) -> void:
	class_id = value
	weapon = 0
	elements = [0, 0, 0]
	invoked = "000"
	build_weapon()

func weapon_name() -> String:
	return SPELLS[invoked][0] if class_id == 2 else WEAPONS[class_id][weapon]

func element_color(value: int) -> Color:
	return [Forge.EMBER, Forge.BONE, Forge.AMBER][value]

func build_weapon() -> void:
	if not is_instance_valid(viewmodel) or not is_instance_valid(side_weapon):
		return
	for child in viewmodel.get_children():
		child.queue_free()
	for child in side_weapon.get_children():
		child.queue_free()
	_view_arms()
	_build_side()
	if class_id == 0:
		match weapon:
			0: _katana()
			1: _sickles()
			2: _rapier()
			3: _saws()
			4: _scythe()
	elif class_id == 1:
		match weapon:
			0: _revolver()
			1: _discs()
			2: _rail()
			3: _shotgun()
			4: _crossbow()
			5: _nailer()
			6: _harpoon()
			7: _censer()
	else:
		_staff()

func _build_side() -> void:
	if class_id == 0:
		match weapon:
			1:
				Forge.box(side_weapon, Vector3(0.7, 0.15, 0.1), Vector3(0.7, 0.08, 0.08), Forge.AMBER, 1)
				Forge.box(side_weapon, Vector3(0.7, -0.15, 0.1), Vector3(0.7, 0.08, 0.08), Forge.AMBER, 1)
			3:
				Forge.box(side_weapon, Vector3(0.85, 0.12, 0.12), Vector3(1.1, 0.22, 0.16), Forge.BRONZE)
				for z in range(6):
					Forge.box(side_weapon, Vector3(0.55 + z * 0.12, 0.24, 0.12), Vector3(0.08, 0.08, 0.18), Forge.BONE)
			4:
				Forge.cyl(side_weapon, Vector3(0.55, 0, 0.1), 0.05, 1.6, Forge.BRONZE)
				Forge.box(side_weapon, Vector3(1.35, -0.28, 0.1), Vector3(0.12, 0.85, 0.08), Forge.AMBER, 1)
			_:
				Forge.cyl(side_weapon, Vector3(0.85, 0, 0.1), 0.035, 1.35, Forge.BONE)
				Forge.cyl(side_weapon, Vector3(0.35, 0, 0.1), 0.07, 0.08, Forge.AMBER, 1)
	elif class_id == 1:
		match weapon:
			1:
				Forge.ring(side_weapon, Vector3(0.7, 0.1, 0.12), 0.28, Forge.AMBER, 0.05)
			4:
				Forge.box(side_weapon, Vector3(0.55, 0, 0.1), Vector3(0.9, 0.16, 0.16), Forge.BRONZE)
				Forge.box(side_weapon, Vector3(0.95, 0.05, 0.1), Vector3(0.08, 0.55, 0.08), Forge.BONE)
			6:
				Forge.cyl(side_weapon, Vector3(0.8, 0, 0.1), 0.05, 1.4, Forge.BONE, 0.0, 0.02)
			7:
				Forge.orb(side_weapon, Vector3(0.75, 0.05, 0.1), 0.22, Forge.EMBER)
			_:
				Forge.cyl(side_weapon, Vector3(0.7, 0, 0.12), 0.07, 0.9, Forge.BRONZE)
				Forge.cyl(side_weapon, Vector3(0.7, 0.12, 0.12), 0.03, 0.7, Forge.AMBER, 1)
	else:
		for i in range(3):
			Forge.orb(side_weapon, Vector3(0.55 + i * 0.28, 0.18 * sin(i * 2.0), 0.1), 0.12, element_color(elements[i]))

func _view_arms() -> void:
	# Visible first-person arms so the player body is not only a floating gun.
	var left = Node3D.new()
	viewmodel.add_child(left)
	left.position = Vector3(-0.28, -0.42, -0.28)
	left.rotation_degrees = Vector3(18, 12, -16)
	Forge.cyl(left, Vector3(0, 0, 0), 0.055, 0.18, Forge.STONE)
	Forge.cyl(left, Vector3(0, -0.16, -0.02), 0.045, 0.28, Forge.BONE)
	Forge.box(left, Vector3(0, -0.32, 0), Vector3(0.1, 0.1, 0.08), Forge.BRONZE)
	for f in range(3):
		Forge.box(left, Vector3((f - 1) * 0.03, -0.4, -0.02), Vector3(0.022, 0.09, 0.024), Forge.BONE)
	var right = Node3D.new()
	viewmodel.add_child(right)
	right.position = Vector3(0.22, -0.48, -0.22)
	right.rotation_degrees = Vector3(22, -8, 12)
	Forge.cyl(right, Vector3(0, 0, 0), 0.05, 0.16, Forge.STONE)
	Forge.cyl(right, Vector3(0.02, -0.12, -0.04), 0.042, 0.2, Forge.BONE)

func _wrap(parent: Node3D, at: Vector3, length: float) -> void:
	for i in range(5):
		Forge.box(parent, at + Vector3(0, -length * 0.4 + i * length * 0.18, 0.04), Vector3(0.07, 0.03, 0.02), Forge.AMBER if i % 2 == 0 else Forge.WAX)

func _katana() -> void:
	var sword = Node3D.new()
	viewmodel.add_child(sword)
	sword.position = Vector3(0.38, -0.46, -0.52)
	sword.rotation_degrees = Vector3(-16, -12, -26)
	Forge.cyl(sword, Vector3(0, -0.02, 0), 0.032, 0.34, Forge.BRONZE)
	_wrap(sword, Vector3.ZERO, 0.3)
	Forge.cyl(sword, Vector3(0, 0.18, 0), 0.09, 0.03, Forge.AMBER, 1)
	Forge.ring(sword, Vector3(0, 0.18, 0), 0.12, Forge.AMBER, 0.015)
	Forge.box(sword, Vector3(0, 0.78, 0), Vector3(0.028, 1.18, 0.055), Forge.IVORY)
	Forge.box(sword, Vector3(-0.018, 0.78, 0), Vector3(0.01, 1.16, 0.06), Forge.AMBER, 1)
	Forge.box(sword, Vector3(0, 1.4, 0.01), Vector3(0.02, 0.12, 0.04), Forge.BONE)
	Forge.orb(sword, Vector3(0, -0.2, 0), 0.045, Forge.AMBER, 0.6)

func _sickles() -> void:
	for x in [-0.42, 0.42]:
		var s = Node3D.new()
		viewmodel.add_child(s)
		s.position = Vector3(x, -0.28, -0.5)
		s.rotation_degrees = Vector3(-8, 18 * sign(x), -10 * sign(x))
		Forge.cyl(s, Vector3.ZERO, 0.025, 0.42, Forge.BRONZE)
		_wrap(s, Vector3.ZERO, 0.3)
		Forge.box(s, Vector3(0.02 * sign(x), 0.22, 0), Vector3(0.34, 0.05, 0.04), Forge.IVORY)
		Forge.box(s, Vector3(0.16 * sign(x), 0.3, 0), Vector3(0.22, 0.045, 0.035), Forge.AMBER, 1)
		Forge.box(s, Vector3(0.26 * sign(x), 0.18, 0), Vector3(0.12, 0.2, 0.03), Forge.IVORY)

func _rapier() -> void:
	var sword = Node3D.new()
	viewmodel.add_child(sword)
	sword.position = Vector3(0.4, -0.5, -0.55)
	sword.rotation_degrees = Vector3(-18, -8, -22)
	Forge.cyl(sword, Vector3(0, 0, 0), 0.022, 0.28, Forge.BRONZE)
	Forge.orb(sword, Vector3(0, -0.16, 0), 0.05, Forge.AMBER, 0.5)
	Forge.cyl(sword, Vector3(0, 0.16, 0), 0.11, 0.04, Forge.AMBER, 0.8)
	Forge.ring(sword, Vector3(0, 0.16, 0), 0.13, Forge.WAX, 0.012)
	Forge.box(sword, Vector3(0.1, 0.16, 0), Vector3(0.18, 0.02, 0.02), Forge.BRONZE)
	Forge.box(sword, Vector3(-0.1, 0.16, 0), Vector3(0.18, 0.02, 0.02), Forge.BRONZE)
	Forge.box(sword, Vector3(0, 0.85, 0), Vector3(0.018, 1.28, 0.018), Forge.IVORY)
	Forge.box(sword, Vector3(-0.012, 0.85, 0), Vector3(0.008, 1.26, 0.02), Forge.AMBER, 1)

func _saws() -> void:
	for x in [-0.44, 0.44]:
		var s = Node3D.new()
		viewmodel.add_child(s)
		s.position = Vector3(x, -0.3, -0.48)
		Forge.cyl(s, Vector3(0, 0, 0.05), 0.11, 0.18, Forge.STONE)
		Forge.box(s, Vector3(0, -0.02, -0.28), Vector3(0.16, 0.12, 0.7), Forge.BRONZE)
		Forge.box(s, Vector3(0, 0.08, -0.28), Vector3(0.05, 0.04, 0.68), Forge.AMBER, 1)
		for z in range(8):
			Forge.box(s, Vector3(0, 0.12, -0.05 - z * 0.08), Vector3(0.14, 0.07, 0.035), Forge.BONE)
		Forge.box(s, Vector3(0, -0.14, 0.02), Vector3(0.08, 0.16, 0.12), Forge.BLOOD)

func _scythe() -> void:
	var sword = Node3D.new()
	viewmodel.add_child(sword)
	sword.position = Vector3(0.36, -0.52, -0.5)
	sword.rotation_degrees = Vector3(-8, -12, 12)
	Forge.cyl(sword, Vector3(0, 0.4, 0), 0.03, 1.35, Forge.BRONZE)
	_wrap(sword, Vector3(0, 0.1, 0), 0.4)
	Forge.ring(sword, Vector3(0, -0.22, 0), 0.1, Forge.AMBER, 0.02)
	Forge.box(sword, Vector3(-0.05, 1.05, 0), Vector3(0.08, 0.12, 0.08), Forge.STONE)
	Forge.box(sword, Vector3(-0.28, 1.12, 0), Vector3(0.55, 0.08, 0.04), Forge.IVORY)
	Forge.box(sword, Vector3(-0.48, 1.0, 0), Vector3(0.28, 0.07, 0.035), Forge.AMBER, 1)
	Forge.box(sword, Vector3(-0.58, 0.86, 0), Vector3(0.16, 0.16, 0.03), Forge.IVORY)

func _grip(at: Vector3) -> void:
	Forge.box(viewmodel, at, Vector3(0.14, 0.28, 0.16), Forge.BRONZE)
	Forge.box(viewmodel, at + Vector3(0, -0.16, 0.02), Vector3(0.12, 0.12, 0.14), Forge.STONE)

func _revolver() -> void:
	_grip(Vector3(0.32, -0.34, -0.42))
	Forge.cyl(viewmodel, Vector3(0.32, -0.2, -0.62), 0.045, 0.55, Forge.BONE)
	var barrel = Forge.cyl(viewmodel, Vector3(0.32, -0.2, -0.62), 0.045, 0.55, Forge.BONE)
	barrel.rotation_degrees.x = 90
	var cyln = Forge.cyl(viewmodel, Vector3(0.32, -0.2, -0.48), 0.09, 0.14, Forge.BRONZE)
	cyln.rotation_degrees.x = 90
	for i in range(6):
		var a = float(i) * TAU / 6.0
		Forge.orb(viewmodel, Vector3(0.32 + cos(a) * 0.055, -0.2 + sin(a) * 0.055, -0.48), 0.018, Forge.AMBER, 0.4)
	Forge.box(viewmodel, Vector3(0.32, -0.08, -0.5), Vector3(0.03, 0.08, 0.08), Forge.AMBER, 1)
	Forge.box(viewmodel, Vector3(0.32, -0.12, -0.38), Vector3(0.04, 0.08, 0.06), Forge.STONE)

func _discs() -> void:
	_grip(Vector3(0.3, -0.36, -0.4))
	Forge.cyl(viewmodel, Vector3(0.3, -0.22, -0.5), 0.08, 0.16, Forge.BRONZE)
	for i in range(3):
		var r = Forge.ring(viewmodel, Vector3(0.3, -0.12 - i * 0.08, -0.72), 0.2 - i * 0.02, Forge.AMBER, 0.035)
		r.rotation.x = PI / 2
	Forge.box(viewmodel, Vector3(0.3, -0.22, -0.58), Vector3(0.18, 0.05, 0.4), Forge.STONE)

func _rail() -> void:
	_grip(Vector3(0.3, -0.36, -0.4))
	var barrel = Forge.cyl(viewmodel, Vector3(0.32, -0.18, -0.78), 0.05, 0.95, Forge.BONE)
	barrel.rotation_degrees.x = 90
	for i in range(5):
		var coil = Forge.ring(viewmodel, Vector3(0.32, -0.18, -0.5 - i * 0.12), 0.09, Forge.AMBER, 0.02)
		coil.rotation.x = PI / 2
	Forge.box(viewmodel, Vector3(0.32, -0.06, -0.55), Vector3(0.06, 0.08, 0.5), Forge.AMBER, 1)
	Forge.orb(viewmodel, Vector3(0.32, -0.3, -0.48), 0.07, Forge.EMBER, 1)

func _shotgun() -> void:
	_grip(Vector3(0.28, -0.36, -0.4))
	for x in [-0.05, 0.05]:
		var b = Forge.cyl(viewmodel, Vector3(0.32 + x, -0.18, -0.72), 0.035, 0.72, Forge.BRONZE)
		b.rotation_degrees.x = 90
	Forge.box(viewmodel, Vector3(0.32, -0.26, -0.52), Vector3(0.18, 0.1, 0.4), Forge.STONE)
	Forge.box(viewmodel, Vector3(0.32, -0.1, -0.5), Vector3(0.04, 0.06, 0.3), Forge.AMBER, 1)
	Forge.box(viewmodel, Vector3(0.22, -0.4, -0.38), Vector3(0.1, 0.22, 0.28), Forge.BRONZE)

func _crossbow() -> void:
	_grip(Vector3(0.3, -0.34, -0.42))
	Forge.box(viewmodel, Vector3(0.32, -0.2, -0.62), Vector3(0.1, 0.1, 0.7), Forge.STONE)
	Forge.box(viewmodel, Vector3(0.32, -0.08, -0.72), Vector3(0.72, 0.05, 0.06), Forge.BRONZE)
	Forge.box(viewmodel, Vector3(0.32, -0.18, -0.72), Vector3(0.04, 0.22, 0.04), Forge.AMBER, 1)
	Forge.cyl(viewmodel, Vector3(0.32, -0.16, -0.78), 0.02, 0.55, Forge.BONE, 0.0, 0.008)
	Forge.box(viewmodel, Vector3(-0.02, -0.08, -0.72), Vector3(0.08, 0.16, 0.05), Forge.BONE)
	Forge.box(viewmodel, Vector3(0.66, -0.08, -0.72), Vector3(0.08, 0.16, 0.05), Forge.BONE)

func _nailer() -> void:
	_grip(Vector3(0.32, -0.34, -0.42))
	Forge.box(viewmodel, Vector3(0.32, -0.18, -0.62), Vector3(0.22, 0.18, 0.5), Forge.STONE)
	for i in range(3):
		for j in range(2):
			var n = Forge.cyl(viewmodel, Vector3(0.24 + j * 0.16, -0.12 - i * 0.06, -0.78), 0.015, 0.28, Forge.BONE)
			n.rotation_degrees.x = 90
	Forge.box(viewmodel, Vector3(0.32, 0.0, -0.55), Vector3(0.16, 0.12, 0.18), Forge.AMBER, 0.6)
	Forge.box(viewmodel, Vector3(0.32, -0.28, -0.58), Vector3(0.14, 0.08, 0.22), Forge.BRONZE)

func _harpoon() -> void:
	_grip(Vector3(0.3, -0.36, -0.4))
	var shaft = Forge.cyl(viewmodel, Vector3(0.32, -0.18, -0.78), 0.04, 1.05, Forge.BRONZE, 0.0, 0.02)
	shaft.rotation_degrees.x = 90
	Forge.box(viewmodel, Vector3(0.32, -0.18, -1.22), Vector3(0.12, 0.04, 0.18), Forge.AMBER, 1)
	Forge.box(viewmodel, Vector3(0.32, -0.1, -1.28), Vector3(0.04, 0.14, 0.08), Forge.BONE)
	Forge.box(viewmodel, Vector3(0.32, -0.26, -0.5), Vector3(0.16, 0.1, 0.28), Forge.STONE)
	Forge.ring(viewmodel, Vector3(0.32, -0.18, -0.55), 0.08, Forge.AMBER, 0.015)

func _censer() -> void:
	_grip(Vector3(0.3, -0.38, -0.4))
	Forge.cyl(viewmodel, Vector3(0.32, -0.12, -0.58), 0.09, 0.18, Forge.BRONZE)
	Forge.orb(viewmodel, Vector3(0.32, -0.02, -0.7), 0.16, Forge.EMBER, 1)
	Forge.cyl(viewmodel, Vector3(0.32, 0.14, -0.7), 0.04, 0.12, Forge.AMBER, 1, 0.02)
	Forge.ring(viewmodel, Vector3(0.32, -0.02, -0.7), 0.2, Forge.WAX, 0.02)
	Forge.box(viewmodel, Vector3(0.32, -0.22, -0.52), Vector3(0.08, 0.08, 0.22), Forge.STONE)

func _staff() -> void:
	Forge.cyl(viewmodel, Vector3(0.34, -0.42, -0.48), 0.035, 0.7, Forge.BRONZE)
	_wrap(viewmodel, Vector3(0.34, -0.42, -0.48), 0.35)
	Forge.orb(viewmodel, Vector3(0.34, -0.08, -0.62), 0.09, Forge.AMBER, 0.8)
	Forge.ring(viewmodel, Vector3(0.34, -0.08, -0.62), 0.14, Forge.WAX, 0.015)
	for i in range(3):
		var at = Vector3(-0.28 + i * 0.3, -0.16 + sin(i * PI / 2) * 0.1, -0.58)
		Forge.orb(viewmodel, at, 0.07, element_color(elements[i]))
		var ring = Forge.ring(viewmodel, at, 0.12, element_color(elements[i]), 0.012)
		ring.rotation.x = PI / 2
	Forge.box(viewmodel, Vector3(-0.38, -0.4, -0.4), Vector3(0.12, 0.22, 0.24), Forge.BONE)
	Forge.box(viewmodel, Vector3(0.38, -0.4, -0.4), Vector3(0.12, 0.22, 0.24), Forge.BONE)

func _unhandled_input(event: InputEvent) -> void:
	if not game.controlling():
		return
	if event is InputEventMouseMotion and not side_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.35, 1.35)
	if event.is_action_pressed("interact") and game.phase == "hub":
		game.hud.show_hub()
		return
	if event.is_action_pressed("next_weapon"):
		switch_weapon(1)
	if event.is_action_pressed("previous_weapon"):
		switch_weapon(-1)
	for i in range(3):
		if event.is_action_pressed("element_" + str(i)):
			if game.phase == "hub":
				set_class(i)
				game.notify(["КЛИНОК", "БАЛЛИСТ", "АРКАНИСТ"][i] + " / КЛАСС ВЫБРАН", element_color(i))
			elif class_id == 2:
				elements.pop_front()
				elements.append(i)
				game.audio.play_sfx("ui", 0.8 + i * 0.2)
				build_weapon()
	if event.is_action_pressed("invoke") and class_id == 2:
		var sorted = elements.duplicate()
		sorted.sort()
		invoked = str(sorted[0]) + str(sorted[1]) + str(sorted[2])
		game.notify(SPELLS[invoked][0], element_color(elements[2]), 1.2)
		game.audio.play_sfx("spell")

func switch_weapon(direction: int) -> void:
	if class_id == 2:
		return
	weapon = posmod(weapon + direction, WEAPONS[class_id].size())
	cooldown = maxf(cooldown, 0.15)
	build_weapon()
	game.audio.play_sfx("ui")

func set_side(value: bool) -> void:
	side_mode = value
	avatar.visible = value
	side_weapon.visible = value
	viewmodel.visible = not value
	if value:
		global_position.z = 0
		game.side_camera.current = true
		if avatar.has_method("animate"):
			avatar.rotation.y = -PI / 2
	else:
		camera.current = true
		yaw = -PI / 2
		pitch = 0
	if game.controlling():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func _physics_process(dt: float) -> void:
	cooldown = maxf(0, cooldown - dt)
	dash_cooldown = maxf(0, dash_cooldown - dt)
	invincible = maxf(0, invincible - dt)
	recoil = move_toward(recoil, 0, dt * 5)
	energy = minf(100, energy + dt * 13)
	_tick_storm(dt)
	if not game.controlling():
		return
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir = Vector3.ZERO
	if side_mode:
		dir.x = input.x
		var mouse = get_viewport().get_mouse_position()
		var ray_origin = game.side_camera.project_ray_origin(mouse)
		var ray_dir = game.side_camera.project_ray_normal(mouse)
		var target = Plane(Vector3.FORWARD, 0).intersects_ray(ray_origin, ray_dir)
		if target != null:
			aim = (target - (global_position + Vector3.UP)).normalized()
			avatar.rotation.y = (-PI / 2) if aim.x > 0 else (PI / 2)
			side_weapon.rotation.x = -atan2(aim.y, absf(aim.x) + 0.001) + recoil * 0.2
	else:
		camera.rotation = Vector3(pitch, yaw, 0)
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
		aim = -camera.global_basis.z
	var speed = 11.0 if class_id != 0 else 12.2
	if side_mode:
		speed *= 1.22
	if Input.is_action_just_pressed("jump") or (side_mode and Input.is_action_just_pressed("move_forward")):
		jump_buffer = 0.15
	jump_buffer -= dt
	if is_on_floor():
		jumps = 0
		coyote = 0.16 if side_mode else 0.12
	else:
		coyote -= dt
	if jump_buffer > 0 and (jumps < 2 or coyote > 0):
		velocity.y = 13.6 if side_mode else 9.5
		if coyote <= 0 and jumps == 0:
			jumps = 1
		jumps += 1
		coyote = 0
		jump_buffer = 0
		if jumps == 2:
			game.fx.wave(global_position, Forge.AMBER, 2)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and not comet:
		dash_dir = dir if dir.length() > 0.1 else Vector3(aim.x, 0, aim.z).normalized()
		if dash_dir.length() < 0.1:
			dash_dir = Vector3.RIGHT
		dash_time = 0.18
		dash_cooldown = 0.85
		invincible = 0.23
		game.audio.play_sfx("dash")
		game.fx.wave(global_position + Vector3.UP * 0.1, Forge.AMBER, 2)
	if dash_time > 0:
		dash_time -= dt
		velocity.x = dash_dir.x * (42 if comet else 34)
		velocity.z = dash_dir.z * (42 if comet else 34)
		velocity.y = maxf(velocity.y, 0)
		if dash_time <= 0 and comet:
			comet = false
			game.explode(global_position + Vector3.UP, 4.8, 130, Forge.EMBER, "burn", "КОМЕТА ПЛОТИ")
			game.fx.column(global_position, Forge.EMBER, 5)
	else:
		velocity.x = move_toward(velocity.x, dir.x * speed, dt * (80 if side_mode else 65))
		velocity.z = move_toward(velocity.z, dir.z * speed, dt * 65)
		velocity.y -= (18.5 if side_mode else 25.0) * dt
	move_and_slide()
	if side_mode:
		global_position.z = 0
	var zlim = 22.0 if game.sector >= 9 else 9.0
	if is_instance_valid(game.world):
		var hw = game.world.half_width(game.sector)
		if hw > 0.0:
			zlim = maxf(1.5, hw - 0.55)
	global_position.z = clampf(global_position.z, -zlim, zlim)
	if game.phase == "hub" and global_position.y < -5:
		game.enter_arena()
	elif global_position.y < -20:
		hurt(25)
		global_position = Vector3(maxf(5, game.sector * 65 + 5), 3, 0)
	if Input.is_action_pressed("attack") and cooldown <= 0:
		attack(false)
	elif Input.is_action_pressed("alt_attack") and cooldown <= 0:
		attack(true)
	walk_clock += dt * Vector2(velocity.x, velocity.z).length()
	if avatar.has_method("animate"):
		avatar.animate(dt, velocity, is_on_floor(), class_id == 0 and Input.is_action_pressed("attack"), 0.0, false, not is_on_floor() or comet)
	if not reduced_motion:
		var fov_target = 104 if dash_time > 0 else 92
		if game.trans_t >= 0:
			fov_target = 92 + sin(clampf(game.trans_t, 0, 1) * PI) * 28
		camera.fov = lerpf(camera.fov, fov_target, dt * 8)
		camera.position = Vector3(randf_range(-1, 1) * game.shake * 0.06, 1.55 + sin(walk_clock * 1.6) * 0.035, 0)
		camera.rotation.z = lerpf(camera.rotation.z, -input.x * 0.025, dt * 8)
		viewmodel.position = Vector3(sin(walk_clock * 0.8) * 0.012, sin(walk_clock * 1.6) * 0.016 - recoil * 0.08, recoil * 0.09)
		viewmodel.rotation.z = recoil * (0.3 if class_id == 0 else 0.03)
	else:
		camera.fov = 92
		camera.position = Vector3(0, 1.55, 0)
		viewmodel.position = Vector3.ZERO
		viewmodel.rotation = Vector3.ZERO

func attack(alternate: bool) -> void:
	if game.phase not in ["run", "escape"]:
		return
	if alternate and class_id != 2 and energy < 25:
		return
	recoil = 1.0
	game.shake = 0.14 if alternate else 0.07
	if alternate and class_id != 2:
		energy -= 25
	if class_id == 0:
		melee(alternate)
	elif class_id == 1:
		ranged(alternate)
	else:
		cast(alternate)

func muzzle() -> Vector3:
	return global_position + Vector3.UP if side_mode else camera.global_position + aim * 0.45

func melee(alt: bool) -> void:
	var ranges = [4.8, 4.2, 7.4, 3.6, 6.0]
	var damage = [52.0, 34.0, 72.0, 16.0, 80.0][weapon]
	cooldown = [0.32, 0.19, 0.45, 0.075, 0.62][weapon]
	var reach = ranges[weapon] * (1.3 if alt else 1.0)
	var arc = -0.5 if weapon == 1 or weapon == 4 else (0.9 if weapon == 2 else 0.15)
	if alt:
		damage *= 1.7
		cooldown *= 1.4
		if weapon == 0:
			dash_dir = Vector3(aim.x, 0, aim.z).normalized()
			dash_time = 0.13
			invincible = 0.2
	var hit_count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var delta = enemy.global_position + Vector3.UP - muzzle()
		var distance = delta.length()
		if distance < reach and (aim.dot(delta.normalized()) > arc or (alt and weapon in [1, 4])):
			if not game.line_clear(muzzle(), enemy.global_position + Vector3.UP):
				continue
			var push = delta.normalized() * (10 if alt else 4)
			if weapon == 4 and alt:
				push *= -2
			enemy.take_damage(damage, push, "", weapon_name())
			hit_count += 1
			game.fx.burst(enemy.global_position + Vector3.UP, Forge.AMBER, 8, 6)
			game.fx.beam(muzzle(), enemy.global_position + Vector3.UP, Forge.AMBER, 0.08)
	if weapon == 3 and hit_count > 0:
		hp = minf(100, hp + 1.8 * hit_count)
	if avatar.has_method("strike"):
		avatar.strike()
	game.fx.slash(muzzle(), aim, Forge.AMBER if weapon != 3 else Forge.EMBER, reach * 0.7)
	game.fx.flash(muzzle() + aim * 0.4, Forge.WAX, 0.1)
	if weapon == 4 or alt:
		game.fx.wave(global_position + Vector3.UP * 0.2, Forge.AMBER, reach)
	game.audio.play_sfx("slash", 1.5 if weapon == 3 else 1)

func ranged(alt: bool) -> void:
	var origin = muzzle()
	var gold = Forge.AMBER
	game.fx.flash(origin + aim * 0.2, gold, 0.16 if weapon != 5 else 0.08)
	match weapon:
		0:
			cooldown = 0.28 if not alt else 0.7
			game.hitscan(origin, aim, 62 if not alt else 135, 85, gold, weapon_name(), false)
			game.fx.burst(origin + aim * 0.3, Forge.WAX, 6, 3)
		1:
			cooldown = 0.38
			game.spawn_projectile(origin, aim * 42, 60 if not alt else 95, true, gold, 0, "", weapon_name(), "disc", 4 if alt else 2)
		2:
			cooldown = 0.9 if not alt else 1.2
			game.hitscan(origin, aim, 155 if not alt else 270, 100, gold, weapon_name(), true)
			game.fx.wave(origin, gold, 1.6)
		3:
			cooldown = 0.65
			for i in range(9 if alt else 6):
				var direction = (aim + Vector3(randf_range(-0.09, 0.09), randf_range(-0.08, 0.08), 0 if side_mode else randf_range(-0.09, 0.09))).normalized()
				game.hitscan(origin, direction, 23, 28, gold, weapon_name(), false)
			if alt:
				velocity -= aim * 12
		4:
			cooldown = 0.55 if not alt else 0.95
			game.spawn_projectile(origin, aim * (48 if not alt else 62), 70 if not alt else 120, true, Forge.BONE, 0, "", weapon_name(), "bolt")
		5:
			cooldown = 0.07 if not alt else 0.22
			var nails = 1 if not alt else 5
			for i in range(nails):
				var spread = Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), 0 if side_mode else randf_range(-0.04, 0.04))
				game.spawn_projectile(origin, (aim + spread).normalized() * 55, 18, true, Forge.BONE, 0, "", weapon_name(), "nail")
		6:
			cooldown = 0.7
			game.spawn_projectile(origin, aim * 36, 80 if not alt else 110, true, Forge.BLOOD, 0, "", weapon_name(), "harpoon")
			if alt:
				dash_dir = Vector3(aim.x, 0, aim.z).normalized()
				dash_time = 0.12
		7:
			cooldown = 0.8 if not alt else 1.15
			var loft = (aim * 20 + Vector3.UP * 9).normalized() * 26
			game.spawn_projectile(origin, loft, 90 if not alt else 70, true, Forge.EMBER, 4.2 if not alt else 3.2, "burn", weapon_name(), "bomb", 0, 22.0)
			if alt:
				var loft2 = (aim * 16 + Vector3.UP * 12 + aim.cross(Vector3.UP) * 0.4).normalized() * 24
				game.spawn_projectile(origin, loft2, 70, true, Forge.EMBER, 3.2, "burn", weapon_name(), "bomb", 0, 22.0)
	game.audio.play_sfx("shot", 0.65 if weapon == 2 else (1.4 if weapon == 5 else 1))

func cast(alt: bool) -> void:
	if alt:
		cooldown = 0.2
		energy = minf(100, energy + 4)
		game.spawn_projectile(muzzle(), aim * 45, 23, true, element_color(elements[2]), 0, "", "ЭФИР")
		game.audio.play_sfx("spell")
		return
	var spell = SPELLS[invoked]
	if energy < spell[4]:
		cooldown = 0.2
		game.notify("НЕТ ЭНЕРГИИ / ПКМ — ЭФИРНЫЙ РАЗРЯД", Forge.WAX, 0.5)
		return
	energy -= spell[4]
	cooldown = spell[5]
	match invoked:
		"000":
			_spell_pillars(spell)
		"001":
			_spell_breath(spell)
		"002":
			_spell_comet()
		"011":
			_spell_spikes(spell)
		"012":
			_spell_triptych(spell)
		"022":
			_spell_chain(spell)
		"111":
			_spell_chapel(spell)
		"112":
			_spell_burial(spell)
		"122":
			_spell_storm()
		"222":
			_spell_thunder(spell)
	game.audio.play_sfx("spell")

func _enemies_in(radius: float, cone: float = -1.0) -> Array:
	var found = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var delta = enemy.global_position + Vector3.UP - muzzle()
		if delta.length() > radius:
			continue
		if cone > -0.5 and aim.dot(delta.normalized()) < cone:
			continue
		if not game.line_clear(muzzle(), enemy.global_position + Vector3.UP):
			continue
		found.append(enemy)
	return found

func _spell_pillars(spell: Array) -> void:
	var targets = _enemies_in(spell[2])
	if targets.is_empty():
		game.spawn_zone(muzzle() + aim * 6, 3.2, 3.0, 18, "burn", Forge.EMBER)
		game.fx.column(muzzle() + aim * 6, Forge.EMBER, 7)
		return
	for enemy in targets:
		enemy.take_damage(spell[1], Vector3.UP * 4, "burn", spell[0])
		game.fx.column(enemy.global_position, Forge.EMBER, 7)
		game.spawn_zone(enemy.global_position, 2.2, 2.8, 14, "burn", Forge.EMBER)

func _spell_breath(spell: Array) -> void:
	game.fx.slash(muzzle(), aim, Forge.EMBER, spell[2] * 0.7)
	for i in range(7):
		var spread = aim.rotated(Vector3.UP if not side_mode else Vector3.FORWARD, (i - 3) * 0.12)
		game.fx.beam(muzzle(), muzzle() + spread * spell[2], Forge.EMBER, 0.09, 0.22)
	for enemy in _enemies_in(spell[2], 0.55):
		enemy.take_damage(spell[1], aim * 6, "burn", spell[0])

func _spell_comet() -> void:
	comet = true
	dash_dir = Vector3(aim.x, 0, aim.z).normalized()
	if dash_dir.length() < 0.1:
		dash_dir = Vector3.RIGHT
	dash_time = 0.28
	invincible = 0.32
	game.fx.column(global_position, Forge.EMBER, 4)

func _spell_spikes(spell: Array) -> void:
	for i in range(8):
		var p = muzzle() + aim * (1.4 + i * 1.7)
		p.y = global_position.y
		game.fx.column(p, Forge.BONE, 2.4 + i * 0.15)
		game.explode(p + Vector3.UP, 1.6, spell[1] * 0.45, Forge.BONE, "freeze", spell[0])

func _spell_triptych(spell: Array) -> void:
	var target = game.hitscan(muzzle(), aim, spell[1], 70, Forge.EMBER, spell[0], false)
	if not is_instance_valid(target):
		target = game.closest_enemy(muzzle(), 14)
	if is_instance_valid(target):
		target.take_damage(spell[1], Vector3.ZERO, "burn", spell[0])
		target.take_damage(spell[1], Vector3.ZERO, "freeze", spell[0])
		target.take_damage(spell[1] * 1.2, -aim * 8, "", spell[0])
		game.fx.beam(muzzle(), target.global_position + Vector3.UP, Forge.EMBER, 0.07, 0.2)
		game.fx.beam(muzzle(), target.global_position + Vector3.UP + Vector3(0, 0.3, 0), Forge.BONE, 0.07, 0.25)
		game.fx.beam(muzzle(), target.global_position + Vector3.UP + Vector3(0, -0.3, 0), Forge.AMBER, 0.07, 0.3)
		target.stagger += (muzzle() + aim * 8 - target.global_position).normalized() * 16

func _spell_chain(spell: Array) -> void:
	var current = game.hitscan(muzzle(), aim, spell[1], 70, Forge.AMBER, spell[0], false)
	var visited = []
	var previous = muzzle()
	if is_instance_valid(current):
		visited.append(current)
		previous = current.global_position + Vector3.UP
	for i in range(5):
		var nxt = game.closest_enemy(previous, 11, visited)
		if nxt == null:
			break
		game.fx.beam(previous, nxt.global_position + Vector3.UP, Forge.AMBER, 0.08, 0.28)
		game.fx.flash(nxt.global_position + Vector3.UP, Forge.WAX, 0.3)
		nxt.take_damage(spell[1] * (1.0 - i * 0.08), Vector3.ZERO, "", spell[0])
		visited.append(nxt)
		previous = nxt.global_position + Vector3.UP

func _spell_chapel(spell: Array) -> void:
	game.explode(global_position + Vector3.UP, spell[2], spell[1], Forge.BONE, "freeze", spell[0])
	game.fx.wave(global_position, Forge.BONE, spell[2])
	hp = minf(100, hp + 10)
	for node in get_tree().get_nodes_in_group("projectiles"):
		if node.friendly:
			continue
		if node.global_position.distance_to(global_position) < spell[2] + 2:
			game.fx.burst(node.global_position, Forge.BONE, 6, 3)
			node.queue_free()

func _spell_burial(spell: Array) -> void:
	for enemy in _enemies_in(spell[2]):
		enemy.lift = 0.65
		enemy.take_damage(spell[1] * 0.35, Vector3.UP * 18, "freeze", spell[0])
		game.fx.beam(enemy.global_position, enemy.global_position + Vector3.UP * 6, Forge.BONE, 0.1, 0.4)
	game.fx.wave(muzzle() + aim * 4, Forge.BONE, 6)

func _spell_storm() -> void:
	storm_time = 6.0
	storm_tick = 0.2
	if storm_orbs.is_empty():
		for i in range(3):
			storm_orbs.append(Forge.orb(self, Vector3(1, 1.2, 0), 0.12, Forge.AMBER))

func _spell_thunder(spell: Array) -> void:
	var dest = muzzle() + aim * spell[2]
	var query = PhysicsRayQueryParameters3D.create(muzzle(), dest, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		dest = hit.position - aim * 0.8
	game.hitscan(muzzle(), aim, spell[1], muzzle().distance_to(dest) + 1.0, Forge.AMBER, spell[0], true)
	game.fx.column(global_position, Forge.AMBER, 5)
	global_position = Vector3(dest.x, maxf(dest.y - 1.0, global_position.y), dest.z if not side_mode else 0.0)
	invincible = 0.22
	game.fx.flash(global_position + Vector3.UP, Forge.WAX, 0.4)
	game.fx.wave(global_position, Forge.AMBER, 3)

func _tick_storm(dt: float) -> void:
	if storm_time <= 0:
		if not storm_orbs.is_empty():
			for orb in storm_orbs:
				if is_instance_valid(orb):
					orb.queue_free()
			storm_orbs.clear()
		return
	storm_time -= dt
	storm_tick -= dt
	for i in range(storm_orbs.size()):
		if not is_instance_valid(storm_orbs[i]):
			continue
		var a = walk_clock * 2.5 + i * TAU / 3.0
		storm_orbs[i].position = Vector3(cos(a) * 1.15, 1.15 + sin(a * 2) * 0.15, sin(a) * 1.15)
	if storm_tick <= 0 and game.phase in ["run", "escape"]:
		storm_tick = 0.45
		var victim = game.closest_enemy(global_position + Vector3.UP, 9)
		if victim != null:
			victim.take_damage(34, Vector3.ZERO, "", "ОРБИТА БУРИ")
			game.fx.beam(global_position + Vector3.UP, victim.global_position + Vector3.UP, Forge.AMBER, 0.06, 0.16)

func hurt(damage: float) -> void:
	if invincible > 0 or game.phase not in ["run", "escape"]:
		return
	hp = maxf(0, hp - damage)
	invincible = 0.28
	game.damage_flash = 0.45
	game.shake = 0.45
	game.combo = maxi(0, game.combo - 3)
	game.audio.play_sfx("hurt")
	if hp <= 0:
		game.finish(false)
