extends Node3D
const PlayerScript = preload("res://scripts/player.gd")
const WorldScript = preload("res://scripts/world.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const FXScript = preload("res://scripts/fx.gd")
const AudioScript = preload("res://scripts/audio.gd")
const HUDScript = preload("res://scripts/hud.gd")
const SECTOR_NAMES = ["ЗОЛОТОЙ ЗЕВ", "КАМЕРА МЯСА", "МРАМОРНЫЙ ДВОР", "ГЛОТКА", "ПЛОЩАДЬ", "ЖЕЛУДОК", "ЯВЛЕНИЕ", "ПОГОНЯ", "ШТОРМ", "КЛЕТКА"]
var player
var world
var fx
var audio
var hud
var side_camera: Camera3D
var phase = "hub"
var sector = 0
var seals = 0
var spawned = []
var collected = [false, false, false]
var score = 0
var best_score = 0
var kills = 0
var combo = 0
var combo_time = 0.0
var last_weapon = ""
var elapsed = 0.0
var escape_left = 22.0
var shake = 0.0
var damage_flash = 0.0
var hit_marker = 0.0
var transition_flash = 0.0
var notice = ""
var notice_color = Color("d01018")
var zones = []
var notice_time = 0.0
var boss
var won = false
var save_records = true
var muted = false
var cinematic = true
var trans_t = -1.0
var trans_to_side = false
var trans_committed = false
var trans_dur = 0.85

func _ready() -> void:
	randomize()
	setup_inputs()
	if save_records:
		load_record()
	fx = FXScript.new()
	add_child(fx)
	audio = AudioScript.new()
	add_child(audio)
	world = WorldScript.new()
	add_child(world)
	world.build(self)
	player = PlayerScript.new()
	player.game = self
	add_child(player)
	player.global_position = Vector3(-43, 0.1, 1.5)
	side_camera = Camera3D.new()
	side_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	side_camera.size = 15.5
	side_camera.far = 90
	add_child(side_camera)
	hud = HUDScript.new()
	hud.game = self
	add_child(hud)
	hud.show_hub()

func setup_inputs() -> void:
	if InputMap.has_action("attack"):
		return
	var keys = {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "dash": [KEY_SHIFT], "previous_weapon": [KEY_Q],
		"next_weapon": [KEY_E], "interact": [KEY_E], "invoke": [KEY_F],
		"element_0": [KEY_1], "element_1": [KEY_2], "element_2": [KEY_3],
		"pause": [KEY_ESCAPE], "help": [KEY_TAB], "mute": [KEY_M], "restart": [KEY_R]
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in keys[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for entry in [["attack", MOUSE_BUTTON_LEFT], ["alt_attack", MOUSE_BUTTON_RIGHT], ["next_weapon", MOUSE_BUTTON_WHEEL_DOWN], ["previous_weapon", MOUSE_BUTTON_WHEEL_UP]]:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
		var event = InputEventMouseButton.new()
		event.button_index = entry[1]
		InputMap.action_add_event(entry[0], event)

func controlling() -> bool:
	return is_instance_valid(hud) and hud.menu == "" and phase in ["hub", "run", "escape"] and not get_tree().paused

func _physics_process(dt: float) -> void:
	if not is_instance_valid(player):
		return
	if player.side_mode:
		var zoom = 15.5
		if trans_t >= 0.5 and trans_to_side:
			zoom = lerpf(28.0, 15.5, clampf((trans_t - 0.5) / 0.5, 0, 1))
		side_camera.size = zoom
		var target = Vector3(player.global_position.x + 1.6, player.global_position.y + 3.0, 20)
		side_camera.global_position = side_camera.global_position.lerp(target, minf(1, dt * 10))
		side_camera.look_at(Vector3(player.global_position.x + 1.6, player.global_position.y + 1.2, 0))
	if phase not in ["run", "escape"]:
		return
	elapsed += dt
	combo_time -= dt
	if combo_time <= 0 and combo > 0:
		combo = maxi(0, combo - 1)
		combo_time = 0.7
	var current = clampi(int(player.global_position.x / 65.0), 0, 9)
	if current != sector:
		sector = current
		change_perspective()
	activate_sector(sector)
	_tick_zones(dt)
	for i in range(3):
		if collected[i]:
			continue
		var distance = player.global_position.distance_to(Vector3(122 + i * 130, 0, 0))
		if distance < 4:
			if block_enemies(i) == 0 and spawned.has(i * 2) and spawned.has(i * 2 + 1):
				collect_seal(i)
			elif notice_time < 0.2:
				notify("ПЕЧАТЬ ЗАПЕРТА / УНИЧТОЖЬ ЦЕЛИ В БЛОКЕ", Color("d01018"), 1.0)
	if phase == "escape":
		escape_left -= dt
		if player.global_position.x > 676:
			finish(true)
		elif escape_left <= 0:
			finish(false)

func _process(dt: float) -> void:
	shake = maxf(0, shake - dt * 2.0)
	damage_flash = maxf(0, damage_flash - dt)
	hit_marker = maxf(0, hit_marker - dt)
	transition_flash = maxf(0, transition_flash - dt)
	notice_time = maxf(0, notice_time - dt)
	if trans_t >= 0.0:
		trans_t += dt / trans_dur
		if trans_t >= 0.48 and not trans_committed:
			trans_committed = true
			_commit_perspective(trans_to_side)
		if trans_t >= 1.0:
			trans_t = -1.0

func enter_arena() -> void:
	phase = "run"
	player.global_position = Vector3(6, 1, 0)
	player.velocity = Vector3.ZERO
	player.yaw = -PI / 2
	player.pitch = 0
	player.hp = 100
	player.energy = 100
	player.invincible = 1.5
	player.set_side(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.apply_palette(false, 0)
	transition_flash = 0.5
	shake = 0.5
	activate_sector(0)
	notify("01 / ЗОЛОТОЙ ЗЕВ — НЕ СТОЙ", world.pal.accent, 3)
	audio.play_sfx("seal", 0.7)

func change_perspective() -> void:
	var side = world.side_sector(sector)
	if side == player.side_mode:
		world.apply_palette(side, sector)
		notify(("2D / " if side else "3D / ") + SECTOR_NAMES[sector], world.pal.accent, 2)
		return
	if cinematic and not player.reduced_motion:
		trans_to_side = side
		trans_t = 0.0
		trans_committed = false
		audio.play_sfx("seal", 0.85)
	else:
		_commit_perspective(side)

func _commit_perspective(side: bool) -> void:
	if side:
		side_camera.size = 15.5
		side_camera.global_position = Vector3(player.global_position.x + 1.6, player.global_position.y + 3.0, 20)
		side_camera.look_at(Vector3(player.global_position.x + 1.6, player.global_position.y + 1.2, 0))
	player.set_side(side)
	world.apply_palette(side, sector)
	transition_flash = 0.25
	audio.play_sfx("dash", 0.6)
	notify(("2D / " if side else "3D / ") + SECTOR_NAMES[sector], world.pal.accent, 2)

func activate_sector(index: int) -> void:
	if spawned.has(index):
		return
	spawned.append(index)
	if index == 6:
		boss = spawn_enemy(Vector3(423, 0.2, 0), 3, 6)
		notify("ДОБРОДЕТЕЛЬ / ЯВЛЕНИЕ", Color("d01018"), 3)
		return
	if index >= 7:
		return
	var count = 7 + index
	for i in range(count):
		var x = index * 65 + 16 + (i % 5) * 8
		var z = 0.0
		if index % 2 != 1:
			var hw = world.half_width(index)
			var lane = minf(5.5, maxf(1.2, hw - 1.6))
			z = -lane if i % 2 == 0 else lane
		var kind = 0
		if i % 3 == 1:
			kind = 1
		if i % 5 == 4 and index > 0:
			kind = 2
		spawn_enemy(Vector3(x, 0.2, z), kind, index)

func spawn_enemy(at: Vector3, kind: int, section: int):
	var enemy = EnemyScript.new()
	enemy.game = self
	enemy.kind = kind
	enemy.sector = section
	add_child(enemy)
	enemy.global_position = at
	fx.wave(at, Color("d01018"), 2)
	return enemy

func block_enemies(block: int) -> int:
	var count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.dead and int(enemy.sector / 2) == block:
			count += 1
	return count

func collect_seal(index: int) -> void:
	collected[index] = true
	seals += 1
	score += 1500
	player.hp = 100
	player.energy = 100
	world.open_seal(index)
	transition_flash = 0.3
	notify("ПЕЧАТЬ 0" + str(index + 1) + " РАЗРУШЕНА / ЗДОРОВЬЕ ВОССТАНОВЛЕНО", world.accents[index], 3)
	audio.play_sfx("seal")

func enemy_killed(enemy, weapon_name: String) -> void:
	kills += 1
	combo += 2 if weapon_name != last_weapon else 1
	last_weapon = weapon_name
	combo_time = 5.0
	score += int((300 if enemy.kind == 2 else 100) * (1 + minf(combo, 30) * 0.1))
	player.hp = minf(100, player.hp + 7)
	player.energy = minf(100, player.energy + 6)
	fx.burst(enemy.global_position + Vector3.UP, enemy.tint, 20, 9)
	fx.wave(enemy.global_position, enemy.tint, 3)
	audio.play_sfx("kill")
	if enemy.kind == 3:
		phase = "escape"
		world.unlock_exit()
		escape_left = 22
		score += 8000
		transition_flash = 0.6
		shake = 0.8
		notify("ДОБРОДЕТЕЛЬ ПАЛА / БЕГИ К ВЫХОДУ →", Color("ffde00"), 5)
		audio.play_sfx("seal", 0.65)

func spawn_projectile(at: Vector3, velocity: Vector3, damage: float, friendly: bool, color: Color, blast: float = 0, status: String = "", weapon_name: String = "", style: String = "orb", ricochets: int = 0, gravity: float = 0.0) -> void:
	var node = ProjectileScript.new()
	node.game = self
	node.velocity = velocity
	node.damage = damage
	node.friendly = friendly
	node.tint = color
	node.blast = blast
	node.status = status
	node.source_name = weapon_name
	node.style = style
	node.ricochets = ricochets
	node.gravity = gravity
	add_child(node)
	node.global_position = at

func spawn_zone(at: Vector3, radius: float, life: float, dps: float, status: String, color: Color) -> void:
	zones.append({"pos": at, "radius": radius, "life": life, "dps": dps, "status": status, "color": color, "tick": 0.25})
	fx.wave(at, color, radius)
	fx.column(at, color, 3.5)

func _tick_zones(dt: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var zone = zones[i]
		zone.life -= dt
		zone.tick -= dt
		if zone.tick <= 0:
			zone.tick = 0.4
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.dead:
					continue
				if enemy.global_position.distance_to(zone.pos) <= zone.radius:
					enemy.take_damage(zone.dps, Vector3.ZERO, zone.status, "ПЕПЕЛ")
		if zone.life <= 0:
			zones.remove_at(i)

func line_clear(a: Vector3, b: Vector3) -> bool:
	var query = PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func hitscan(origin: Vector3, direction: Vector3, damage: float, reach: float, color: Color, weapon_name: String, pierce: bool):
	var end = origin + direction * reach
	var query = PhysicsRayQueryParameters3D.create(origin, end, 5)
	var first = null
	for i in range(8 if pierce else 1):
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		end = hit.position
		if hit.collider.has_method("take_damage"):
			var enemy = hit.collider
			if first == null:
				first = enemy
			var headshot = hit.position.y - enemy.global_position.y > 1.45 and enemy.kind < 2
			enemy.take_damage(damage * (1.5 if headshot else 1.0), direction * 5, "", weapon_name)
			if pierce:
				var excluded = query.exclude
				excluded.append(enemy.get_rid())
				query.exclude = excluded
				end = origin + direction * reach
				continue
		else:
			fx.burst(hit.position, color, 4, 3)
			break
	fx.beam(origin, end, color, 0.095 if pierce else 0.035, 0.22 if pierce else 0.1)
	return first

func closest_enemy(at: Vector3, radius: float, excluded: Array = []):
	var nearest = null
	var distance = radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead or enemy in excluded:
			continue
		var d = at.distance_to(enemy.global_position + Vector3.UP)
		if d < distance and line_clear(at, enemy.global_position + Vector3.UP):
			distance = d
			nearest = enemy
	return nearest

func explode(at: Vector3, radius: float, damage: float, color: Color, status: String, weapon_name: String) -> void:
	fx.wave(at, color, radius)
	fx.burst(at, color, 22, 10)
	shake = 0.22
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var delta = enemy.global_position + Vector3.UP - at
		if delta.length() <= radius and line_clear(at, enemy.global_position + Vector3.UP):
			enemy.take_damage(damage, delta.normalized() * 12, status, weapon_name)
			fx.beam(at, enemy.global_position + Vector3.UP, color, 0.06, 0.2)

func notify(text: String, color: Color = Color("d01018"), duration: float = 2.0) -> void:
	notice = text
	notice_color = color
	notice_time = duration

func finish(victory: bool) -> void:
	if phase == "end":
		return
	won = victory
	phase = "end"
	if victory:
		score += int(maxf(0, 900 - elapsed) * 10)
	best_score = maxi(best_score, score)
	if save_records:
		var save = ConfigFile.new()
		save.set_value("record", "score", best_score)
		save.save("user://zero_beat.cfg")
	hud.show_end()

func load_record() -> void:
	var save = ConfigFile.new()
	if save.load("user://zero_beat.cfg") == OK:
		best_score = int(save.get_value("record", "score", 0))

func restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

func style_rank() -> String:
	if combo >= 25:
		return "SSS"
	if combo >= 18:
		return "SS"
	if combo >= 12:
		return "S"
	if combo >= 8:
		return "A"
	if combo >= 4:
		return "B"
	return "C"
