class_name RiftPlayer
extends CharacterBody3D

const Arsenal = preload("res://scripts/arsenal.gd")

var game: Node3D
var pivot: Node3D
var camera: Camera3D
var model: Node3D
var weapon_model: Node3D
var health := 100.0
var max_health := 100.0
var speed := 11.0
var damage_mult := 1.0
var haste := 1.0
var armor := 0.0
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_direction := Vector3.ZERO
var invulnerable := 0.0
var attack_cooldown := 0.0
var recoil := 0.0
var step_timer := 0.0
var air_jumps := 1
var extra_jump := false
var nova := false
var lifesteal := false
var pitch := 0.0
var weapon := "katana"
var inventory: Array[String] = []
var elements := ""
var spell := "QQQ"
var aim := Vector3.FORWARD
var old_floor := true

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	floor_snap_length = 0.45
	pivot = Node3D.new()
	pivot.position.y = 1.6
	add_child(pivot)
	camera = Camera3D.new()
	camera.fov = 92
	camera.far = 220
	pivot.add_child(camera)
	weapon_model = Node3D.new()
	weapon_model.scale = Vector3.ONE * 0.65
	camera.add_child(weapon_model)
	model = Node3D.new()
	add_child(model)
	game.visual_box(model, Vector3(0, 0.9, 0), Vector3(0.7, 1.3, 0.55), Arsenal.CYAN)
	game.visual_box(model, Vector3(0, 1.65, -0.08), Vector3(0.48, 0.35, 0.48), Arsenal.LIME)
	game.visual_box(model, Vector3(0, 1.65, -0.33), Vector3(0.5, 0.08, 0.08), Color.WHITE)

func equip(id: String) -> void:
	weapon = id
	if not inventory.has(id):
		inventory.append(id)
	if Arsenal.WEAPONS[id].kind == "magic":
		spell = Arsenal.spell_key(Arsenal.WEAPONS[id].combo)
	for child in weapon_model.get_children():
		weapon_model.remove_child(child)
		child.queue_free()
	var kind = Arsenal.WEAPONS[id].kind
	if kind == "melee":
		if id == "saws":
			for side in [-1, 1]:
				game.visual_box(weapon_model, Vector3(side * 0.5, -0.45, -0.85), Vector3(0.18, 0.22, 1.1), Color("263547"))
				for i in 9:
					game.visual_box(weapon_model, Vector3(side * 0.5, -0.31, -0.4 - i * 0.1), Vector3(0.24, 0.08, 0.05), Arsenal.LIME)
		else:
			var blade = game.visual_box(weapon_model, Vector3(0.5, -0.05, -0.9), Vector3(0.065, 1.7, 0.12), Color("cee8df"))
			blade.rotation.z = -0.32
			game.visual_box(weapon_model, Vector3(0.73, -0.64, -0.9), Vector3(0.4, 0.07, 0.22), Arsenal.LIME)
			if id in ["scythe", "sickles"]:
				game.visual_box(weapon_model, Vector3(0.05, 0.6, -0.9), Vector3(0.95, 0.09, 0.12), Arsenal.LIME)
			if id == "sickles":
				game.visual_box(weapon_model, Vector3(-0.5, -0.1, -0.9), Vector3(0.06, 0.9, 0.12), Arsenal.LIME)
	elif kind == "magic":
		for i in 3:
			var orb = game.visual_box(weapon_model, Vector3((i - 1) * 0.35, -0.4, -0.85), Vector3.ONE * 0.18, [Arsenal.ORANGE, Arsenal.CYAN, Arsenal.VIOLET][i])
			orb.rotation = Vector3(0.5, 0.3, 0.7)
	else:
		game.visual_box(weapon_model, Vector3(0.4, -0.38, -0.6), Vector3(0.24, 0.3, 0.4), Color("344256"))
		game.visual_box(weapon_model, Vector3(0.4, -0.29, -0.96), Vector3(0.16, 0.15, 0.85 if id == "rail" else 0.5), Color("83909e"))
		game.visual_box(weapon_model, Vector3(0.4, -0.21, -0.77), Vector3(0.07, 0.035, 0.34), Arsenal.ORANGE)
		if id == "scatter":
			game.visual_box(weapon_model, Vector3(0.58, -0.29, -0.96), Vector3(0.14, 0.15, 0.5), Color("83909e"))
	game.sound.play("pick")

func _unhandled_input(event: InputEvent) -> void:
	if game.state not in ["RUN", "DROP"]:
		return
	if event is InputEventMouseMotion and not game.top_down and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0023
		pitch = clampf(pitch - event.relative.y * 0.0023, -1.35, 1.35)
		pivot.rotation.x = pitch
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_Q, KEY_E, KEY_R] and game.class_index == 2:
			elements += OS.get_keycode_string(key)
			elements = elements.right(3)
			game.sound.play("ui", -14, 0.8 + elements.length() * 0.25)
			game.fx.burst(global_position + Vector3.UP * 1.5, Arsenal.VIOLET, 4, 2)
		if key == KEY_F and game.class_index == 2:
			if elements.length() == 3:
				spell = Arsenal.spell_key(elements)
				if Arsenal.WEAPONS[weapon].kind != "magic":
					equip("ember")
					spell = Arsenal.spell_key(elements)
				game.notify(Arsenal.SPELLS[spell].name, Arsenal.VIOLET)
				game.sound.play("invoke")
				game.fx.ring(global_position + Vector3.UP * 0.2, 2.5, Arsenal.VIOLET)
			else:
				game.notify("СОБЕРИ 3 СТИХИИ: Q / E / R", Arsenal.VIOLET)
		if key >= KEY_1 and key <= KEY_9:
			var index = key - KEY_1
			if index < inventory.size():
				equip(inventory[index])
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var index = inventory.find(weapon)
		index = wrapi(index + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, inventory.size())
		equip(inventory[index])

func _physics_process(dt: float) -> void:
	if game.state not in ["RUN", "DROP"]:
		return
	dash_cooldown = maxf(0, dash_cooldown - dt)
	attack_cooldown = maxf(0, attack_cooldown - dt)
	invulnerable = maxf(0, invulnerable - dt)
	recoil = lerpf(recoil, 0.0, 13.0 * dt)
	weapon_model.position = Vector3(0.15, -0.25, -0.2) + Vector3(sin(game.elapsed * 11) * velocity.length() * 0.0015, -recoil * 0.2, recoil * 0.25)
	weapon_model.rotation.z = recoil * -0.45
	model.visible = game.top_down
	weapon_model.visible = not game.top_down
	var input = Input.get_vector("left", "right", "forward", "back")
	var direction = Vector3(input.x, 0, input.y)
	if not game.top_down:
		direction = basis * direction
		# In FPS gravity supplies pitch; weapons can still aim vertically.
		aim = -camera.global_basis.z
	else:
		var mouse = get_viewport().get_mouse_position()
		var origin = game.top_camera.project_ray_origin(mouse)
		var ray = game.top_camera.project_ray_normal(mouse)
		var plane = Plane(Vector3.UP, global_position.y + 1.0)
		var target = plane.intersects_ray(origin, ray)
		if target != null:
			aim = (target - global_position - Vector3.UP).normalized()
			model.rotation.y = atan2(-aim.x, -aim.z) - rotation.y
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0:
		dash_direction = direction.normalized() if direction.length() > 0 else Vector3(aim.x, 0, aim.z).normalized()
		dash_time = 0.17
		dash_cooldown = 1.1
		invulnerable = 0.28
		game.sound.play("dash")
		game.shake = 0.12
		game.fx.ring(global_position + Vector3.UP * 0.2, 1.8, Arsenal.CYAN)
		if nova:
			game.area_damage(global_position, 5.5, 35 * damage_mult, Arsenal.CYAN, 1.5)
	if is_on_floor():
		air_jumps = 1 if extra_jump else 0
		if not old_floor:
			game.sound.play("land", -10)
			game.fx.ring(global_position + Vector3.UP * 0.1, 2, Arsenal.CYAN)
			game.shake = 0.12
			if game.state == "DROP":
				game.begin_combat()
	if Input.is_action_just_pressed("jump") and (is_on_floor() or air_jumps > 0) and game.state == "RUN":
		if not is_on_floor():
			air_jumps -= 1
		velocity.y = 9.5
		game.sound.play("jump")
		game.fx.burst(global_position, Arsenal.CYAN, 7, 3)
	old_floor = is_on_floor()
	if dash_time > 0:
		dash_time -= dt
		velocity.x = dash_direction.x * 36
		velocity.z = dash_direction.z * 36
		game.fx.burst(global_position + Vector3.UP * 0.5, Arsenal.CYAN, 1, 1)
	else:
		velocity.x = move_toward(velocity.x, direction.x * speed, dt * 65)
		velocity.z = move_toward(velocity.z, direction.z * speed, dt * 65)
	velocity.y -= 26 * dt
	if game.state == "DROP":
		velocity.y = maxf(velocity.y, -45)
	move_and_slide()
	if global_position.y < -32:
		hurt(25)
		global_position = game.centers[game.sector] + Vector3.UP * 3
		velocity = Vector3.ZERO
	step_timer -= dt
	if direction.length() > 0.2 and is_on_floor() and step_timer <= 0:
		game.sound.play("step", -23)
		game.fx.burst(global_position + Vector3.UP * 0.08, Arsenal.CYAN.darkened(0.4), 2, 1.5)
		step_timer = 0.29
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and attack_cooldown <= 0 and game.state == "RUN":
		attack()

func attack() -> void:
	var data = Arsenal.WEAPONS[weapon]
	attack_cooldown = data.rate / haste
	recoil = 1.0
	game.shake = maxf(game.shake, 0.045)
	var origin = global_position + Vector3.UP * 1.2 if game.top_down else camera.global_position
	var color = Arsenal.CLASSES[game.class_index].color
	match data.kind:
		"melee":
			game.sound.play("slash", -10, 1.5 if weapon == "saws" else 1.0)
			for enemy in game.enemies.duplicate():
				if not is_instance_valid(enemy) or enemy.dead:
					continue
				var offset = enemy.global_position + Vector3.UP - origin
				var flat = Vector3(offset.x, 0, offset.z).normalized()
				var flat_aim = Vector3(aim.x, 0, aim.z).normalized()
				if offset.length() < data.reach and flat.dot(flat_aim) >= data.cone and game.clear_line(origin, enemy.global_position + Vector3.UP):
					enemy.take_damage(data.damage * damage_mult, flat * 7)
					if weapon == "sickles":
						health = minf(max_health, health + 1.2)
			var forward = Vector3(aim.x, 0, aim.z).normalized()
			var side = forward.cross(Vector3.UP)
			for i in 7:
				var a = -1.2 + i * 0.4
				var b = a + 0.4
				game.fx.beam(origin + (forward * cos(a) + side * sin(a)) * 2.6, origin + (forward * cos(b) + side * sin(b)) * 2.6, color, 0.09, 0.12)
		"gun", "rail", "shotgun":
			game.sound.play("shot", -9, 0.65 if data.kind == "rail" else 1.0)
			var pellets = 7 if data.kind == "shotgun" else 1
			for i in pellets:
				var direction = aim
				if pellets > 1:
					direction = (aim + Vector3(randf_range(-0.12, 0.12), randf_range(-0.08, 0.08), randf_range(-0.12, 0.12))).normalized()
				game.hitscan(origin, direction, data.reach, data.damage * damage_mult, data.kind == "rail", Arsenal.ORANGE)
		"disc":
			game.sound.play("slash")
			game.spawn_projectile(origin, aim, 27, data.damage * damage_mult, Arsenal.LIME, false, true)
		"magic":
			var s = Arsenal.SPELLS[spell]
			attack_cooldown = s.rate / haste
			game.sound.play("invoke", -13, 1.25)
			if spell in ["EEE", "EER", "EQR"]:
				game.area_damage(global_position + Vector3.UP, s.radius, s.damage * damage_mult, s.color, 2.5 if spell != "EQR" else 0.7, spell == "EQR")
			elif spell in ["RRR", "ERR"]:
				game.chain_lightning(origin, aim, s.damage * damage_mult, s.color, spell == "ERR")
			elif spell == "QRR":
				game.hitscan(origin, aim, 80, s.damage * damage_mult, true, s.color)
			else:
				game.spawn_projectile(origin, aim, 30, s.damage * damage_mult, s.color, false, false, s.radius, 2.0 if spell == "EEQ" else 0.0)

func hurt(amount: float) -> void:
	if invulnerable > 0 or game.state != "RUN":
		return
	health -= amount * (1.0 - armor)
	invulnerable = 0.3
	game.hurt_flash = 0.6
	game.shake = 0.2
	game.combo = 0
	game.sound.play("hurt", -7)
	if health <= 0:
		health = 0
		game.end_run()
