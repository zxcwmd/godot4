class_name RiftLab
extends Node3D
## Isolated, opt-in sandbox. Never advances survival time or writes records.
const Arsenal = preload("res://scripts/arsenal.gd")
const Enemy = preload("res://scripts/enemy.gd")
const ORIGIN = Vector3(180, 0, 0)
const ZONES = [Vector3(180, 0, -40), Vector3(180, 0, 0), Vector3(220, 0, 0)]
const NAMES = ["ТИР / УРОН", "БОЕВАЯ ПЛОЩАДКА", "ДВИЖЕНИЕ / ПРЫЖКИ"]
var game: Node3D
var god_mode := true
var spawn_count := 5
var zone := 0
var uptime := 0.0
var total_damage := 0.0
var last_hit := 0.0
var hit_count := 0
var damage_window: Array[Dictionary] = []
var dps := 0.0
var built := false

func build() -> void:
	if built:
		return
	built = true
	for i in 3:
		var center: Vector3 = ZONES[i]
		var accent: Color = [Arsenal.CYAN, Arsenal.ORANGE, Arsenal.LIME][i]
		if i != 2:
			floor_box(center + Vector3(0, -0.4, 0), Vector3(26, 0.8, 26))
		else:
			# Real gap down to the catch floor: jumping off is safe, but visible.
			floor_box(center + Vector3(0, -5.4, 0), Vector3(26, 0.8, 26))
			for side in [-1, 1]:
				floor_box(center + Vector3(side * 9, -0.4, 0), Vector3(8, 0.8, 26))
				floor_box(center + Vector3(0, -0.4, side * 11.5), Vector3(10, 0.8, 3))
			for j in 3:
				var h = 0.7 + j * 0.8
				var p = center + Vector3(-3.3 + j * 3.3, h / 2, -3 if j % 2 == 0 else 0)
				floor_box(p, Vector3(2, h, 2))
				game.visual_box(self, p + Vector3.UP * (h / 2 + 0.03), Vector3(2.05, 0.055, 2.05), accent)
			# A separate inclined runway reaches the raised observation platform.
			var ramp = Node3D.new()
			add_child(ramp)
			ramp.position = center + Vector3(0, 1.8, 7)
			ramp.rotation.z = atan2(3.6, 14.0)
			floor_box(Vector3(0, -0.2, 0), Vector3(sqrt(14 * 14 + 3.6 * 3.6), 0.4, 3), ramp)
			floor_box(center + Vector3(9.5, 1.6, 7), Vector3(5, 4, 4))
			game.visual_box(self, center + Vector3(9.5, 3.65, 7), Vector3(5, 0.06, 4), accent)
		for side in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var opening = (i == 0 and side == Vector3.BACK) or (i == 1 and side in [Vector3.FORWARD, Vector3.RIGHT]) or (i == 2 and side == Vector3.LEFT)
			var horizontal = abs(side.z) > 0.5
			var tangent = Vector3.RIGHT if horizontal else Vector3.BACK
			for segment in ([-1, 1] if opening else [0]):
				var length = 8.0 if opening else 26.0
				var pos = center + side * 13 + tangent * segment * 9 + Vector3.UP * 1.5
				game.world.solid(pos, Vector3(length, 3, 0.5) if horizontal else Vector3(0.5, 3, length), Color("182537"), self)
				game.visual_box(self, pos + Vector3.UP * 1.55, Vector3(length, 0.09, 0.55) if horizontal else Vector3(0.55, 0.09, length), accent)
		label(center + Vector3(0, 4.5, -12), "%02d / %s" % [i + 1, NAMES[i]], accent, 66)
		floor_label(center + Vector3(0, 0.05, 9), ["5m    /    12m    /    20m", "MANUAL SPAWN / B", "JUMP • DASH • REPEAT"][i], accent)
	for pair in [[0, 1], [1, 2]]:
		var a: Vector3 = ZONES[pair[0]]
		var b: Vector3 = ZONES[pair[1]]
		var delta = (b - a).normalized()
		floor_box((a + b) / 2 + Vector3(0, -0.4, 0), Vector3(10, 0.8, 14) if abs(delta.z) > 0 else Vector3(14, 0.8, 10))
		for side in [-1, 1]:
			var pos = (a + b) / 2 + delta.cross(Vector3.UP) * side * 5.1 + Vector3.UP * 0.6
			game.world.solid(pos, Vector3(0.3, 1.2, 14) if abs(delta.z) > 0 else Vector3(14, 1.2, 0.3), Color("263447"), self)
			game.visual_box(self, pos + Vector3.UP * 0.65, Vector3(0.3, 0.08, 14) if abs(delta.z) > 0 else Vector3(14, 0.08, 0.3), Arsenal.CYAN)
	game.world.build_side_stage(ZONES[1])
	# Firing line and measured target stands. Three clear lanes.
	for lane in 3:
		var x = (lane - 1) * 6
		var z = [3.0, -4.0, -12.0][lane]
		game.visual_box(self, ZONES[0] + Vector3(x, 0.035, 8), Vector3(3.5, 0.035, 0.16), Arsenal.LIME)
		floor_label(ZONES[0] + Vector3(x, 0.06, z + 1), ["05 M", "12 M", "20 M"][lane], Arsenal.CYAN, 38)

func floor_box(pos: Vector3, size: Vector3, parent: Node3D = self) -> void:
	var body = game.world.solid(pos, size, Color("142337"), parent)
	body.get_child(0).material_override = game.world.floor_material

func label(pos: Vector3, text: String, color: Color, font_size: int) -> void:
	var node = Label3D.new()
	node.text = text
	node.position = pos
	node.font_size = font_size
	node.pixel_size = 0.018
	node.modulate = color
	node.outline_size = 0
	add_child(node)

func floor_label(pos: Vector3, text: String, color: Color, font_size: int = 55) -> void:
	label(pos, text, color, font_size)
	get_child(get_child_count() - 1).rotation_degrees.x = -90

func reset_session() -> void:
	god_mode = true
	spawn_count = 5
	uptime = 0
	reset_stats()
	reset_build()
	reset_targets()
	teleport(0)

func reset_stats() -> void:
	damage_window.clear()
	total_damage = 0
	last_hit = 0
	hit_count = 0
	dps = 0

func reset_build() -> void:
	var p = game.player
	p.max_health = 120 if game.class_index == 0 else 100
	p.health = p.max_health
	p.damage_mult = 1
	p.haste = 1
	p.speed = 12 if game.class_index == 1 else 11
	p.armor = 0
	p.extra_jump = false
	p.nova = false
	p.lifesteal = false
	game.points = 10

func select_weapon(id: String) -> void:
	for p in game.projectiles.get_children():
		if not p.hostile:
			p.queue_free()
	# All weapons are available through the panel, independent of nine hotbar slots.
	if not game.player.inventory.has(id) and game.player.inventory.size() >= 9:
		game.player.inventory.erase(game.player.weapon)
	game.player.equip(id)
	reset_stats()

func reset_targets() -> void:
	for e in game.enemies.duplicate():
		if is_instance_valid(e) and e.practice_target:
			game.enemies.erase(e)
			e.queue_free()
	for i in 3:
		var e = Enemy.new()
		e.game = game
		e.practice_target = true
		e.position = ZONES[0] + Vector3((i - 1) * 6, 0.05, [3, -4, -12][i])
		game.enemies.append(e)
		game.add_child(e)

func clear_combat() -> void:
	for e in game.enemies.duplicate():
		if is_instance_valid(e) and not e.practice_target:
			game.enemies.erase(e)
			e.queue_free()
	for p in game.projectiles.get_children():
		p.queue_free()

func spawn_kind(kind: int) -> void:
	var active = game.enemies.filter(func(e): return is_instance_valid(e) and not e.practice_target).size()
	for i in mini(spawn_count, 30 - active):
		var e = Enemy.new()
		e.game = game
		e.kind = kind
		var angle = (active + i) * 2.4
		e.position = ZONES[1] + Vector3(cos(angle) * 9, 0.1, sin(angle) * 9)
		if game.side_view:
			e.side_member = true
			e.side_origin = e.position
			e.position = game.side_center + Vector3(cos(angle) * 19, 0.1, 0)
		game.enemies.append(e)
		game.add_child(e)
	game.notify("ВРАГИ НА БОЕВОЙ ПЛОЩАДКЕ  /  МАКС. 30", Arsenal.ORANGE)

func teleport(index: int) -> void:
	if game.side_view:
		game.set_side_view(false)
	zone = index
	game.player.position = ZONES[index] + Vector3(0, 0.2, 8) if index != 2 else ZONES[index] + Vector3(-9, 0.2, 0)
	game.player.velocity = Vector3.ZERO
	game.player.dash_time = 0
	game.player.dash_cooldown = 0
	game.player.pitch = 0
	game.player.pivot.rotation.x = 0
	game.player.rotation.y = 0 if index != 2 else -PI / 2
	game.player.invulnerable = 1
	game.player.cancel_attack()
	game.notify(NAMES[index] + "   /   B — ПУЛЬТ", Arsenal.CYAN)

func record_damage(amount: float) -> void:
	last_hit = amount
	total_damage += amount
	hit_count += 1
	damage_window.append({"time": uptime, "damage": amount})

func tick(dt: float) -> void:
	uptime += dt
	zone = nearest_zone(game.player.position)
	while not damage_window.is_empty() and damage_window[0].time < uptime - 5:
		damage_window.pop_front()
	var sum := 0.0
	for entry in damage_window:
		sum += entry.damage
	dps = sum / 5.0
	if game.player.position.y < -3.5:
		teleport(zone)
		game.sound.play("portal", -12)

func nearest_zone(pos: Vector3) -> int:
	var result := 0
	var distance := INF
	for i in 3:
		var d = pos.distance_squared_to(ZONES[i])
		if d < distance:
			distance = d
			result = i
	return result

func navigation_target(pos: Vector3) -> Vector3:
	var here = nearest_zone(pos)
	var there = nearest_zone(game.player.position)
	if here == there:
		return game.player.position
	return ZONES[1] if here != 1 and there != 1 else ZONES[there]

func show_side(enabled: bool) -> void:
	for mesh in find_children("*", "GeometryInstance3D", true, false):
		mesh.visible = not enabled or mesh.global_position.z < ZONES[1].z - 3 or mesh.global_position.y < 0
