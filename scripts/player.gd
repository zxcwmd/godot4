extends CharacterBody3D
const WEAPONS = [
	["КАТАНА / ИМПУЛЬС", "ПАРНЫЕ СЕРПЫ", "РАПИРА / ИГЛА", "РУКИ-БЕНЗОПИЛЫ", "КОСА / ЖНЕЦ"],
	["РЕВОЛЬВЕР / ШЕСТЬ", "ДИСКИ / РИКОШЕТ", "РЕЛЬСОТРОН / ПРОБОЙ", "ДРОБОВИК / РАЗЛОМ"],
	["СИНТЕЗ СТИХИЙ"]
]
const SPELLS = {
	"000": ["СОЛНЕЧНЫЙ РАЗРЫВ", 100.0, 5.5, "burn", 26.0, 1.0],
	"001": ["ОБЖИГАЮЩИЙ ТУМАН", 65.0, 7.0, "burn", 22.0, 0.8],
	"002": ["МЕТЕОРНЫЙ ИМПУЛЬС", 145.0, 4.5, "burn", 32.0, 1.1],
	"011": ["ЛЕДЯНОЙ ШИП", 115.0, 3.0, "freeze", 20.0, 0.7],
	"012": ["ХАОС / СХЛОПЫВАНИЕ", 95.0, 8.0, "freeze", 30.0, 1.1],
	"022": ["ЦЕПНАЯ МОЛНИЯ", 110.0, 6.0, "", 24.0, 0.8],
	"111": ["АБСОЛЮТНЫЙ НОЛЬ", 55.0, 9.0, "freeze", 24.0, 0.9],
	"112": ["ГРАВИТАЦИОННЫЙ СНЕГ", 80.0, 7.0, "freeze", 24.0, 0.9],
	"122": ["ЭЛЕКТРОШТОРМ", 120.0, 6.0, "", 28.0, 1.0],
	"222": ["ГРОМОВОЙ КОПЬЕБРОС", 180.0, 2.5, "", 30.0, 1.1]
}
var game
var camera: Camera3D
var avatar: Node3D
var viewmodel: Node3D
var side_weapon: Node3D
var legs = []
var hp = 100.0
var energy = 100.0
var class_id = 0
var weapon = 0
var side_mode = false
var yaw = -PI/2
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
	avatar = Node3D.new()
	add_child(avatar)
	Forge.box(avatar, Vector3(0, 0.95, 0), Vector3(0.65, 0.8, 0.42), Color("d5eadc"))
	Forge.box(avatar, Vector3(0, 1.57, 0), Vector3(0.5, 0.44, 0.48), Color("263647"))
	Forge.box(avatar, Vector3(0.25, 1.59, 0.01), Vector3(0.07, 0.17, 0.5), Color("d4ff64"), 1)
	for x in [-0.19, 0.19]:
		legs.append(Forge.box(avatar, Vector3(x, 0.31, 0), Vector3(0.23, 0.62, 0.28), Color("415268")))
	Forge.box(avatar, Vector3(-0.44, 0.93, 0), Vector3(0.18, 0.84, 0.3), Color("d4ff64"))
	Forge.box(avatar, Vector3(0.44, 0.93, 0), Vector3(0.18, 0.84, 0.3), Color("d4ff64"))
	avatar.visible = false
	side_weapon = Node3D.new()
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

func build_weapon() -> void:
	if not is_instance_valid(viewmodel) or not is_instance_valid(side_weapon): return
	for child in viewmodel.get_children():
		child.queue_free()
	for child in side_weapon.get_children():
		child.queue_free()
	if class_id == 0:
		Forge.box(side_weapon, Vector3(0.9, 0, 0.12), Vector3(1.3, 0.09 if weapon != 3 else 0.22, 0.13), Color("d4ff64"), 1)
		if weapon == 4:
			Forge.box(side_weapon, Vector3(1.6, -0.25, 0.12), Vector3(0.13, 0.7, 0.1), Color("d4ff64"), 1)
	elif class_id == 1:
		Forge.box(side_weapon, Vector3(0.65, 0, 0.16), Vector3(0.95, 0.22, 0.26), Color("b8cfdf"))
		Forge.box(side_weapon, Vector3(0.7, 0.14, 0.16), Vector3(0.85, 0.04, 0.08), Color("64e3fa"), 1)
	else:
		for i in range(3):
			Forge.orb(side_weapon, Vector3(0.6+i*0.3, 0.2*sin(i*2), 0.1), 0.12, element_color(elements[i]))
	var dark = Color("253346")
	var white = Color("afc5ce")
	var lime = Color("d4ff64")
	# Viewmodel geometry is deliberately chunky, with luminous edges.
	if class_id == 0:
		if weapon == 3:
			for x in [-0.42, 0.42]:
				Forge.box(viewmodel, Vector3(x, -0.32, -0.5), Vector3(0.2, 0.22, 0.55), dark)
				Forge.box(viewmodel, Vector3(x, -0.24, -0.85), Vector3(0.11, 0.16, 0.6), lime, 1)
				for z in range(6):
					Forge.box(viewmodel, Vector3(x, -0.13, -0.61-z*0.09), Vector3(0.14, 0.08, 0.04), white)
		elif weapon == 1:
			for x in [-0.4, 0.4]:
				Forge.box(viewmodel, Vector3(x, -0.28, -0.5), Vector3(0.06, 0.46, 0.07), dark)
				Forge.box(viewmodel, Vector3(x*0.8, -0.03, -0.53), Vector3(0.32, 0.055, 0.075), lime, 1)
		else:
			var sword = Node3D.new()
			viewmodel.add_child(sword)
			sword.position = Vector3(0.39, -0.48, -0.55)
			sword.rotation_degrees = Vector3(-14, -10, -24 if weapon != 4 else 9)
			Forge.box(sword, Vector3.ZERO, Vector3(0.075, 0.38, 0.08), dark)
			Forge.box(sword, Vector3(0, 0.2, 0), Vector3(0.29, 0.035, 0.14), lime, 1)
			Forge.box(sword, Vector3(0, 0.78, 0), Vector3(0.032 if weapon == 2 else 0.09, 1.15, 0.035), white)
			Forge.box(sword, Vector3(-0.05, 0.78, 0), Vector3(0.018, 1.15, 0.04), lime, 1)
			if weapon == 4:
				Forge.box(sword, Vector3(-0.25, 1.32, 0), Vector3(0.65, 0.13, 0.045), lime, 1)
	elif class_id == 1:
		Forge.box(viewmodel, Vector3(0.32, -0.33, -0.45), Vector3(0.15, 0.32, 0.18), dark)
		Forge.box(viewmodel, Vector3(0.32, -0.2, -0.65), Vector3(0.24, 0.2, 0.7 if weapon == 2 else 0.46), white)
		Forge.box(viewmodel, Vector3(0.32, -0.08, -0.69), Vector3(0.05, 0.04, 0.52), Color("64e3fa"), 1)
		Forge.box(viewmodel, Vector3(0.32, -0.2, -0.94), Vector3(0.13, 0.13, 0.1), dark)
		if weapon == 1:
			Forge.ring(viewmodel, Vector3(0.32, -0.15, -0.75), 0.24, Color("64e3fa"), 0.055)
		if weapon == 3:
			Forge.box(viewmodel, Vector3(0.46, -0.2, -0.65), Vector3(0.13, 0.14, 0.7), dark)
	else:
		for i in range(3):
			var at = Vector3(-0.34+i*0.34, -0.2+sin(i*PI/2)*0.12, -0.62)
			Forge.orb(viewmodel, at, 0.075, element_color(elements[i]))
			var ring = Forge.ring(viewmodel, at, 0.13, element_color(elements[i]), 0.012)
			ring.rotation.x = PI/2
		Forge.box(viewmodel, Vector3(-0.38, -0.4, -0.4), Vector3(0.13, 0.23, 0.26), white)
		Forge.box(viewmodel, Vector3(0.38, -0.4, -0.4), Vector3(0.13, 0.23, 0.26), white)

func element_color(value: int) -> Color:
	return [Color("ff9869"), Color("65e2ff"), Color("c58dff")][value]

func _unhandled_input(event: InputEvent) -> void:
	if not game.controlling(): return
	if event is InputEventMouseMotion and not side_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch-event.relative.y*sensitivity, -1.35, 1.35)
	if event.is_action_pressed("interact") and game.phase == "hub":
		game.hud.show_hub()
		return
	if event.is_action_pressed("next_weapon"): switch_weapon(1)
	if event.is_action_pressed("previous_weapon"): switch_weapon(-1)
	for i in range(3):
		if event.is_action_pressed("element_" + str(i)):
			if game.phase == "hub":
				set_class(i)
				game.notify(["КЛИНОК", "БАЛЛИСТ", "АРКАНИСТ"][i] + " / КЛАСС ВЫБРАН", element_color(i))
			elif class_id == 2:
				elements.pop_front()
				elements.append(i)
				game.audio.play_sfx("ui", 0.8+i*0.2)
				build_weapon()
	if event.is_action_pressed("invoke") and class_id == 2:
		var sorted = elements.duplicate()
		sorted.sort()
		invoked = str(sorted[0])+str(sorted[1])+str(sorted[2])
		game.notify(SPELLS[invoked][0], element_color(elements[2]), 1.2)
		game.audio.play_sfx("spell")

func switch_weapon(direction: int) -> void:
	if class_id == 2: return
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
	else:
		camera.current = true
		yaw = -PI/2
		pitch = 0
	if game.controlling():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func _physics_process(dt: float) -> void:
	cooldown = maxf(0, cooldown-dt)
	dash_cooldown = maxf(0, dash_cooldown-dt)
	invincible = maxf(0, invincible-dt)
	recoil = move_toward(recoil, 0, dt*5)
	energy = minf(100, energy+dt*13)
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
			aim = (target - (global_position+Vector3.UP)).normalized()
			avatar.rotation.y = 0 if aim.x > 0 else PI
			side_weapon.rotation.z = atan2(aim.y, aim.x) + recoil * 0.25
	else:
		camera.rotation = Vector3(pitch, yaw, 0)
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
		aim = -camera.global_basis.z
	var speed = 11.0 if class_id != 0 else 12.2
	if Input.is_action_just_pressed("jump") or (side_mode and Input.is_action_just_pressed("move_forward")):
		jump_buffer = 0.15
	jump_buffer -= dt
	if is_on_floor():
		jumps = 0
		coyote = 0.12
	else:
		coyote -= dt
	if jump_buffer > 0 and (jumps < 2 or coyote > 0):
		velocity.y = 9.5
		if coyote <= 0 and jumps == 0: jumps = 1
		jumps += 1
		coyote = 0
		jump_buffer = 0
		if jumps == 2: game.fx.wave(global_position, Color("64e3fa"), 2)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0:
		dash_dir = dir if dir.length() > 0.1 else Vector3(aim.x, 0, aim.z).normalized()
		if dash_dir.length() < 0.1: dash_dir = Vector3.RIGHT
		dash_time = 0.18
		dash_cooldown = 0.85
		invincible = 0.23
		game.audio.play_sfx("dash")
		game.fx.wave(global_position+Vector3.UP*0.1, Color("64e3fa"), 2)
	if dash_time > 0:
		dash_time -= dt
		velocity.x = dash_dir.x * 34
		velocity.z = dash_dir.z * 34
		velocity.y = maxf(velocity.y, 0)
	else:
		velocity.x = move_toward(velocity.x, dir.x*speed, dt*65)
		velocity.z = move_toward(velocity.z, dir.z*speed, dt*65)
		velocity.y -= 25*dt
	move_and_slide()
	if side_mode: global_position.z = 0
	global_position.z = clampf(global_position.z, -9, 9)
	if game.phase == "hub" and global_position.y < -5:
		game.enter_arena()
	elif global_position.y < -20:
		hurt(25)
		global_position = Vector3(maxf(5, game.sector*65+5), 3, 0)
	if Input.is_action_pressed("attack") and cooldown <= 0:
		attack(false)
	elif Input.is_action_pressed("alt_attack") and cooldown <= 0:
		attack(true)
	walk_clock += dt * Vector2(velocity.x, velocity.z).length()
	for i in range(legs.size()):
		legs[i].rotation.z = sin(walk_clock*1.5+i*PI)*0.5 if velocity.length() > 1 else 0.0
	if not reduced_motion:
		camera.fov = lerpf(camera.fov, 104 if dash_time > 0 else 92, dt*8)
		camera.position = Vector3(randf_range(-1, 1)*game.shake*0.06, 1.55+sin(walk_clock*1.6)*0.035, 0)
		camera.rotation.z = lerpf(camera.rotation.z, -input.x*0.025, dt*8)
		viewmodel.position = Vector3(sin(walk_clock*0.8)*0.012, sin(walk_clock*1.6)*0.016-recoil*0.08, recoil*0.09)
		viewmodel.rotation.z = recoil * (0.3 if class_id == 0 else 0.03)
	else:
		camera.fov = 92
		camera.position = Vector3(0, 1.55, 0)
		viewmodel.position = Vector3.ZERO
		viewmodel.rotation = Vector3.ZERO

func attack(alternate: bool) -> void:
	if game.phase not in ["run", "escape"]: return
	if alternate and class_id != 2 and energy < 25: return
	recoil = 1.0
	game.shake = 0.14 if alternate else 0.07
	if alternate and class_id != 2: energy -= 25
	if class_id == 0:
		melee(alternate)
	elif class_id == 1:
		ranged(alternate)
	else:
		cast(alternate)

func muzzle() -> Vector3:
	return global_position + Vector3.UP if side_mode else camera.global_position + aim*0.45

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
		if enemy.dead: continue
		var delta = enemy.global_position+Vector3.UP - muzzle()
		var distance = delta.length()
		if distance < reach and (aim.dot(delta.normalized()) > arc or (alt and weapon in [1, 4])):
			if not game.line_clear(muzzle(), enemy.global_position+Vector3.UP): continue
			var push = delta.normalized() * (10 if alt else 4)
			if weapon == 4 and alt: push *= -2
			enemy.take_damage(damage, push, "", weapon_name())
			hit_count += 1
			game.fx.beam(muzzle(), enemy.global_position+Vector3.UP, Color("d4ff64"), 0.08)
	if weapon == 3 and hit_count > 0: hp = minf(100, hp+1.8*hit_count)
	if weapon == 4 or alt: game.fx.wave(global_position+Vector3.UP*0.2, Color("d4ff64"), reach)
	else:
		var right = aim.cross(Vector3.UP).normalized()
		game.fx.beam(muzzle()+aim*2-right, muzzle()+aim*2+right, Color("d4ff64"), 0.08)
	game.audio.play_sfx("slash", 1.5 if weapon == 3 else 1)

func ranged(alt: bool) -> void:
	var origin = muzzle()
	var color = Color("64e3fa")
	match weapon:
		0:
			cooldown = 0.28 if not alt else 0.7
			game.hitscan(origin, aim, 62 if not alt else 135, 85, color, weapon_name(), false)
		1:
			cooldown = 0.38
			game.spawn_projectile(origin, aim*42, 60 if not alt else 95, true, color, 0, "", weapon_name(), "disc", 4 if alt else 2)
		2:
			cooldown = 0.9 if not alt else 1.2
			game.hitscan(origin, aim, 155 if not alt else 270, 100, color, weapon_name(), true)
		3:
			cooldown = 0.65
			for i in range(9 if alt else 6):
				var direction = (aim+Vector3(randf_range(-0.09, 0.09), randf_range(-0.08, 0.08), 0 if side_mode else randf_range(-0.09, 0.09))).normalized()
				game.hitscan(origin, direction, 23, 28, color, weapon_name(), false)
			if alt: velocity -= aim*12
	game.audio.play_sfx("shot", 0.65 if weapon == 2 else 1)

func cast(alt: bool) -> void:
	if alt:
		cooldown = 0.2
		energy = minf(100, energy+4)
		game.spawn_projectile(muzzle(), aim*45, 23, true, element_color(elements[2]), 0, "", "ЭФИР")
	else:
		var spell = SPELLS[invoked]
		if energy < spell[4]:
			cooldown = 0.2
			game.notify("НЕТ ЭНЕРГИИ / ПКМ — ЭФИРНЫЙ РАЗРЯД", Color("ffc16b"), 0.5)
			return
		energy -= spell[4]
		cooldown = spell[5]
		var color = element_color(int(invoked[2]))
		if invoked == "111":
			game.explode(global_position+Vector3.UP, spell[2], spell[1], color, spell[3], spell[0])
		elif invoked == "222":
			game.hitscan(muzzle(), aim, spell[1], 100, color, spell[0], true)
		elif invoked == "022":
			var first = game.hitscan(muzzle(), aim, spell[1], 75, color, spell[0], false)
			if is_instance_valid(first):
				game.explode(first.global_position+Vector3.UP, spell[2], spell[1]*0.7, color, "", spell[0])
		else:
			game.spawn_projectile(muzzle(), aim*38, spell[1], true, color, spell[2], spell[3], spell[0])
		if invoked in ["012", "112"]:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				var delta = muzzle()+aim*10 - enemy.global_position
				if delta.length() < 12: enemy.stagger += delta.normalized()*14
	game.audio.play_sfx("spell")

func hurt(damage: float) -> void:
	if invincible > 0 or game.phase not in ["run", "escape"]: return
	hp = maxf(0, hp-damage)
	invincible = 0.28
	game.damage_flash = 0.45
	game.shake = 0.45
	game.combo = maxi(0, game.combo-3)
	game.audio.play_sfx("hurt")
	if hp <= 0: game.finish(false)
