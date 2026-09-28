extends Node3D

const Arsenal = preload("res://scripts/arsenal.gd")
const RiftPlayer = preload("res://scripts/player.gd")
const RiftWorld = preload("res://scripts/world.gd")
const RiftFX = preload("res://scripts/fx.gd")
const RiftSound = preload("res://scripts/sound.gd")
const RiftEnemy = preload("res://scripts/enemy.gd")
const RiftProjectile = preload("res://scripts/projectile.gd")
const RiftLab = preload("res://scripts/lab.gd")

var state := "MENU"
var suspended_state := "RUN"
var class_index := 0
var selected_weapon := "katana"
var player: RiftPlayer
var world: RiftWorld
var fx: RiftFX
var sound: RiftSound
var hud: Control
var top_camera: Camera3D
var enemies: Array[RiftEnemy] = []
var projectiles: Node3D
var centers: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 0, -40), Vector3(40, 6, -40), Vector3(40, 6, -80), Vector3(0, 0, -80), Vector3(-40, -6, -80), Vector3(-40, -6, -120), Vector3(0, 0, -120), Vector3(40, 6, -120)]
var sector := 0
var visited: Array[int] = [0]
var top_down := false
var elapsed := 0.0
var real_time := 0.0
var kills := 0
var combo := 0
var combo_timer := 0.0
var best_combo := 0
var level := 1
var xp := 0
var xp_goal := 8
var points := 0
var best := 0.0
var spawn_timer := 1.0
var shake := 0.0
var hurt_flash := 0.0
var hit_marker := 0.0
var transition := 0.0
var notice := ""
var notice_color := Arsenal.LIME
var notice_time := 0.0
var drop_time := 0.0
var material_cache: Dictionary = {}
var pickups: Array[Dictionary] = []
var reduced_fx := false
var run_serial := 0
var sandbox := false
var lab: RiftLab

func _ready() -> void:
	randomize()
	setup_input()
	load_record()
	fx = RiftFX.new()
	add_child(fx)
	sound = RiftSound.new()
	add_child(sound)
	world = RiftWorld.new()
	world.game = self
	add_child(world)
	world.build()
	lab = RiftLab.new()
	lab.game = self
	add_child(lab)
	projectiles = Node3D.new()
	add_child(projectiles)
	player = RiftPlayer.new()
	player.game = self
	add_child(player)
	player.position = Vector3(0, 24, 8)
	top_camera = Camera3D.new()
	top_camera.far = 280
	add_child(top_camera)
	top_camera.position = Vector3(27, 43, 30)
	top_camera.look_at(Vector3(0, 23, -2))
	top_camera.current = true
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = load("res://scripts/hud.gd").new()
	hud.game = self
	canvas.add_child(hud)
	get_tree().auto_accept_quit = true

func setup_input() -> void:
	var actions = {"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "dash": [KEY_SHIFT]}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in actions[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_ESCAPE:
				if state in ["RUN", "DROP"]:
					pause_run()
				elif state in ["PAUSE", "UPGRADE", "HELP", "LAB"]:
					resume_run()
			KEY_TAB:
				if state == "RUN":
					state = "UPGRADE"
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					hud.build_menu()
				elif state == "UPGRADE":
					resume_run()
			KEY_B:
				if sandbox and state == "RUN":
					open_lab()
				elif sandbox and state == "LAB":
					resume_run()
			KEY_V:
				if sandbox and state == "RUN":
					set_perspective(not top_down)
			KEY_M:
				sound.toggle_music()
			KEY_F1:
				if state == "RUN":
					state = "HELP"
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					hud.build_menu()
			KEY_F3:
				reduced_fx = not reduced_fx
				fx.enabled = not reduced_fx
				notify("ЭФФЕКТЫ: " + ("СНИЖЕНЫ" if reduced_fx else "ПОЛНЫЕ"), Arsenal.CYAN)
			KEY_ENTER:
				if state == "MENU":
					start_run()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and state in ["RUN", "DROP"] and not top_down:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(dt: float) -> void:
	real_time += dt
	shake = move_toward(shake, 0, dt * 0.65)
	hurt_flash = move_toward(hurt_flash, 0, dt * 1.5)
	hit_marker = move_toward(hit_marker, 0, dt)
	transition = move_toward(transition, 0, dt)
	notice_time = maxf(0, notice_time - dt)
	if state == "MENU":
		top_camera.position = Vector3(27 + sin(real_time * 0.13) * 3, 42, 31)
		top_camera.look_at(Vector3(0, 23, -2))
		top_camera.h_offset = -10
		top_camera.v_offset = -8
	elif state == "DROP":
		drop_time += dt
		player.pitch = lerpf(player.pitch, -0.8, dt * 2)
		player.pivot.rotation.x = player.pitch
	elif state == "RUN":
		combo_timer -= dt
		if combo_timer <= 0:
			combo = 0
		if sandbox:
			lab.tick(dt)
		else:
			elapsed += dt
			var next_sector = nearest_sector(player.global_position)
			if next_sector != sector:
				var offset: Vector3 = player.global_position - centers[next_sector]
				if abs(offset.x) < 12.5 and abs(offset.z) < 12.5:
					enter_sector(next_sector)
			spawn_timer -= dt
			if spawn_timer <= 0:
				spawn_wave()
				spawn_timer = maxf(0.65, 2.8 - elapsed / 150)
		update_pickups(dt)
	if top_down and state != "MENU":
		top_camera.position = top_camera.position.lerp(player.global_position + Vector3(0, 38, 0.01), minf(1, dt * 12))
		# Exactly overhead orthographic view: WASD stays aligned to the screen.
		top_camera.rotation_degrees = Vector3(-90, 0, 0)
	if state in ["RUN", "DROP"]:
		var s = 0.0 if reduced_fx else shake
		player.camera.h_offset = randf_range(-s, s)
		player.camera.v_offset = randf_range(-s, s)
		player.camera.fov = lerpf(player.camera.fov, 102.0 if player.dash_time > 0 else 92.0, dt * 7)
	hud.queue_redraw()

func start_run() -> void:
	sandbox = false
	lab.visible = false
	fx.clear_all()
	# A run is fully reset without rebuilding the world or reloading a scene.
	run_serial += 1
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in projectiles.get_children():
		p.queue_free()
	for p in pickups:
		p.node.queue_free()
	pickups.clear()
	elapsed = 0
	kills = 0
	combo = 0
	best_combo = 0
	combo_timer = 0
	level = 1
	xp = 0
	xp_goal = 8
	points = 0
	sector = 0
	visited = [0]
	spawn_timer = 1.5
	top_down = false
	player.health = 120 if class_index == 0 else 100
	player.max_health = player.health
	player.speed = 12 if class_index == 1 else 11
	player.damage_mult = 1
	player.haste = 1
	player.armor = 0
	player.extra_jump = false
	player.nova = false
	player.lifesteal = false
	player.dash_cooldown = 0
	player.dash_time = 0
	player.invulnerable = 0
	player.attack_cooldown = 0
	player.recoil = 0
	player.elements = ""
	player.inventory.clear()
	player.equip(selected_weapon)
	player.position = Vector3(0, 25.5, 0)
	player.velocity = Vector3(0, -4, 0)
	player.rotation = Vector3.ZERO
	player.pitch = -0.5
	player.old_floor = false
	player.look_guard = 0.12
	player.camera.current = true
	player.model.visible = false
	player.weapon_model.visible = true
	state = "DROP"
	suspended_state = "DROP"
	drop_time = 0
	hurt_flash = 0
	transition = 0.45
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.build_menu()
	sound.start_music()
	sound.play("portal", -5, 0.6)
	notify("НЕ ОСТАНАВЛИВАЙСЯ.", Arsenal.LIME)

func begin_combat() -> void:
	state = "RUN"
	suspended_state = "RUN"
	player.pitch = 0
	player.pivot.rotation.x = 0
	player.invulnerable = 2
	fx.burst(player.position + Vector3.UP, Arsenal.CYAN, 35, 15)
	notify("01 / ТОЧКА ПАДЕНИЯ   •   ВЫЖИВАЙ", Arsenal.LIME)
	spawn_wave()

func pause_run() -> void:
	suspended_state = state
	state = "PAUSE"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.build_menu()

func resume_run() -> void:
	player.look_guard = 0.12
	state = suspended_state
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if top_down else Input.MOUSE_MODE_CAPTURED
	hud.build_menu()

func return_to_hub() -> void:
	player.cancel_attack()
	sandbox = false
	lab.visible = false
	state = "MENU"
	top_down = false
	top_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	top_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.build_menu()

func enter_sector(index: int) -> void:
	sector = index
	set_perspective(index % 2 == 1)
	sound.play("portal", -9)
	if not visited.has(index):
		visited.append(index)
		points += 1
		player.health = minf(player.max_health, player.health + 25)
		notify("%02d / %s  •  +1 ОЧКО [TAB]" % [index + 1, RiftWorld.ROOM_NAMES[index]], Arsenal.CYAN)
	else:
		notify("%02d / %s" % [index + 1, RiftWorld.ROOM_NAMES[index]], Arsenal.VIOLET if top_down else Arsenal.CYAN)
	player.invulnerable = 1.3
	spawn_wave()

func set_perspective(flat: bool) -> void:
	player.look_guard = 0.12
	top_down = flat
	transition = 0.65
	if top_down:
		top_camera.h_offset = 0
		top_camera.v_offset = 0
		top_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		top_camera.size = 36
		top_camera.position = player.global_position + Vector3(0, 38, 0.01)
		top_camera.rotation_degrees = Vector3(-90, 0, 0)
		top_camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		player.camera.current = true
		player.pitch = 0
		player.pivot.rotation.x = 0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if state == "RUN" else Input.MOUSE_MODE_VISIBLE
	player.model.visible = top_down
	player.weapon_model.visible = not top_down

func start_sandbox() -> void:
	start_run()
	sandbox = true
	lab.build()
	lab.visible = true
	state = "RUN"
	suspended_state = "RUN"
	lab.reset_session()
	player.attack_cooldown = 0.25
	set_perspective(false)
	hud.build_menu()

func open_lab() -> void:
	if not sandbox:
		return
	suspended_state = "RUN"
	state = "LAB"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.build_menu()

func enemy_target(pos: Vector3) -> Vector3:
	if sandbox:
		return lab.navigation_target(pos)
	var room = nearest_sector(pos)
	return player.position if room == sector else centers[room + (1 if sector > room else -1)]

func report_hit(enemy: RiftEnemy, amount: float) -> void:
	fx.damage_number(enemy.position + Vector3.UP * 2.1, amount, enemy.color)
	player.weapon_model.impact()
	player.world_weapon.impact()
	if sandbox:
		lab.record_damage(amount)

func nearest_sector(pos: Vector3) -> int:
	var result := 0
	var distance := INF
	for i in centers.size():
		var d = Vector2(pos.x, pos.z).distance_squared_to(Vector2(centers[i].x, centers[i].z))
		if d < distance:
			distance = d
			result = i
	return result

func spawn_wave() -> void:
	if sandbox:
		return
	var count = 2 + mini(4, int(elapsed / 35))
	for i in count:
		if enemies.size() >= 48:
			return
		var center: Vector3 = centers[sector]
		var pos = center
		for attempt in 10:
			pos = center + Vector3(randf_range(-10, 10), 0.2, randf_range(-10, 10))
			if pos.distance_to(player.position) > 8:
				break
		if pos.distance_to(player.position) < 6:
			continue
		var enemy = RiftEnemy.new()
		enemy.game = self
		enemy.kind = 2 if elapsed > 35 and randf() < 0.18 else (1 if randf() < 0.3 else 0)
		enemy.position = pos
		enemies.append(enemy)
		add_child(enemy)

func enemy_killed(enemy: RiftEnemy) -> void:
	kills += 1
	combo += 1
	combo_timer = 4.0
	best_combo = maxi(best_combo, combo)
	sound.play("kill", -16, minf(1.6, 0.9 + combo * 0.02))
	if (class_index == 0 and enemy.position.distance_to(player.position) < 8) or player.lifesteal:
		player.health = minf(player.max_health, player.health + (4 if player.lifesteal else 2))
	if sandbox:
		return
	xp += 3 if enemy.kind == 2 else 1
	if xp >= xp_goal:
		xp -= xp_goal
		level += 1
		xp_goal = 8 + level * 3
		points += 1
		notify("УРОВЕНЬ %02d  /  +1 ОЧКО УЛУЧШЕНИЯ [TAB]" % level, Arsenal.LIME)
		sound.play("pick", -6)
	if kills % 12 == 0:
		var pool: Array = Arsenal.CLASSES[class_index].weapons.duplicate()
		if kills >= 36:
			pool = Arsenal.WEAPONS.keys()
		pool = pool.filter(func(id): return not player.inventory.has(id))
		if not pool.is_empty() and player.inventory.size() < 9:
			var id: String = pool.pick_random()
			player.inventory.append(id)
			notify("НОВОЕ ОРУЖИЕ: " + Arsenal.WEAPONS[id].name + "  [" + str(player.inventory.size()) + "]", Arsenal.ORANGE)
			sound.play("pick", -7)
	if randf() < 0.22:
		var node = visual_box(self, enemy.position + Vector3.UP * 0.7, Vector3.ONE * 0.45, Arsenal.LIME)
		pickups.append({"node": node, "age": 0.0})

func update_pickups(dt: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p = pickups[i]
		p.age += dt
		p.node.rotate_y(dt * 2)
		var offset: Vector3 = player.position + Vector3.UP * 0.8 - p.node.position
		if offset.length() < 6:
			p.node.position += offset.normalized() * dt * 12
		if offset.length() < 1.1:
			player.health = minf(player.max_health, player.health + 14)
			sound.play("pick", -17, 1.4)
			fx.burst(p.node.position, Arsenal.LIME, 8, 4)
			p.node.queue_free()
			pickups.remove_at(i)
		elif p.age > 20:
			p.node.queue_free()
			pickups.remove_at(i)

func clear_line(a: Vector3, b: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1)).is_empty()

func hitscan(origin: Vector3, direction: Vector3, reach: float, damage: float, pierce: bool, color: Color) -> void:
	var end = origin + direction * reach
	var query = PhysicsRayQueryParameters3D.create(origin, end, 1 | 4)
	var excludes: Array[RID] = []
	for i in (12 if pierce else 1):
		query.exclude = excludes
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			break
		if result.collider is RiftEnemy:
			var e: RiftEnemy = result.collider
			excludes.append(e.get_rid())
			e.take_damage(damage, direction * 5)
			if not pierce:
				end = result.position
		else:
			end = result.position
			break
	fx.beam(origin + Vector3(0, -0.15, 0), end, color, 0.12 if pierce else 0.045)
	fx.burst(end, color, 4, 3)

func area_damage(pos: Vector3, radius: float, damage: float, color: Color, slow: float = 0.0, pull: bool = false) -> void:
	fx.ring(pos, radius, color)
	fx.burst(pos, color, 15, 10)
	for e in enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var target: Vector3 = e.position + Vector3.UP
		if target.distance_to(pos) < radius and clear_line(pos, target):
			e.slowed = maxf(e.slowed, slow)
			var push = (target - pos).normalized() * (12 if pull else 5)
			e.take_damage(damage, -push if pull else push)

func chain_lightning(origin: Vector3, direction: Vector3, damage: float, color: Color, slow: bool) -> void:
	var current = origin
	var hit: Array[RiftEnemy] = []
	for i in 5:
		var closest: RiftEnemy = null
		var distance := 24.0 if i == 0 else 9.0
		for e in enemies:
			if e.dead or hit.has(e):
				continue
			var offset = e.position + Vector3.UP - current
			if i == 0 and offset.normalized().dot(direction) < 0.65:
				continue
			if offset.length() < distance and clear_line(current, e.position + Vector3.UP):
				distance = offset.length()
				closest = e
		if closest == null:
			break
		hit.append(closest)
		var end = closest.position + Vector3.UP
		fx.beam(current, end, color, 0.12, 0.2)
		current = end
		closest.slowed = 1.8 if slow else 0
		closest.take_damage(damage * pow(0.85, i))
	if hit.is_empty():
		fx.beam(origin, origin + direction * 16, color, 0.06, 0.15)

func spawn_projectile(origin: Vector3, direction: Vector3, speed: float, damage: float, color: Color, hostile: bool, disc: bool = false, radius: float = 0.0, slow: float = 0.0) -> void:
	var p = RiftProjectile.new()
	p.game = self
	p.position = origin
	p.direction = direction
	p.speed = speed
	p.damage = damage
	p.color = color
	p.hostile = hostile
	p.disc = disc
	p.radius = radius
	p.slow = slow
	projectiles.add_child(p)

func upgrade(id: int) -> void:
	if points <= 0:
		return
	match id:
		0:
			player.max_health += 25
			player.health = minf(player.max_health, player.health + 45)
		1: player.damage_mult += 0.18
		2: player.haste += 0.15
		3: player.speed = minf(20, player.speed + 1.3)
		4:
			if player.extra_jump:
				return
			player.extra_jump = true
		5:
			if player.nova:
				return
			player.nova = true
		6: player.armor = minf(0.6, player.armor + 0.1)
		7:
			if player.lifesteal:
				return
			player.lifesteal = true
	points -= 1
	sound.play("pick", -8)
	hud.build_menu()

func end_run() -> void:
	player.cancel_attack()
	if sandbox:
		lab.clear_combat()
		player.health = player.max_health
		lab.teleport(lab.zone)
		open_lab()
		notify("ТЕСТ ЗАВЕРШЁН / HP ВОССТАНОВЛЕНЫ", Arsenal.ORANGE)
		return
	state = "OVER"
	if elapsed > best:
		best = elapsed
		var save = ConfigFile.new()
		save.set_value("record", "seconds", best)
		save.save("user://record.cfg")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.build_menu()
	sound.play("portal", -5, 0.45)

func load_record() -> void:
	var save = ConfigFile.new()
	if save.load("user://record.cfg") == OK:
		best = float(save.get_value("record", "seconds", 0.0))

func notify(text: String, color: Color) -> void:
	notice = text
	notice_color = color
	notice_time = 3.7

func visual_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, unshaded: bool = true) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var key = str(color) + str(unshaded)
	if not material_cache.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.68
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.emission_enabled = true
			m.emission = color
		material_cache[key] = m
	mesh.material_override = material_cache[key]
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

static func clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
