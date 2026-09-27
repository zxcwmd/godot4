extends CharacterBody3D
var game
var kind = 0 # 0 rush, 1 gunner, 2 brute, 3 heart
var sector = 0
var hp = 70.0
var max_hp = 70.0
var speed = 5.0
var attack_timer = 1.0
var stagger = Vector3.ZERO
var frozen = 0.0
var burn = 0.0
var burn_timer = 0.0
var age = 0.0
var dead = false
var tint = Color("ff6a4a")
var body: Node3D
var core: MeshInstance3D
var warning: MeshInstance3D
var charge = 0.0
var boss_cycle = 0
var flash = 0.0
var lift = 0.0
var stage = 0
var dash_t = 0.0
var dash_dir = Vector3.ZERO
var laser_t = 0.0
var laser_angle = 0.0
var laser_tick = 0.0
var dual_laser = false

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.45 if kind < 2 else (0.8 if kind == 2 else 1.8)
	capsule.height = 1.8 if kind < 2 else (2.6 if kind == 2 else 4.2)
	var collision = CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = capsule.height / 2
	add_child(collision)
	match kind:
		0:
			hp = 65; speed = 6.8; tint = Forge.BLOOD
		1:
			hp = 85; speed = 3.6; tint = Forge.WAX
		2:
			hp = 170; speed = 3.0; tint = Forge.COPPER
		3:
			hp = 2300; speed = 1.8; tint = Forge.EMBER
	max_hp = hp
	body = Puppet.new()
	add_child(body)
	body.build(kind, tint)
	core = body.core
	warning = Forge.ring(self, Vector3(0, 0.08, 0), 1.0, tint, 0.04)
	warning.visible = false

func _physics_process(dt: float) -> void:
	if dead or game.phase not in ["run", "escape"]:
		return
	age += dt
	attack_timer -= dt
	frozen = maxf(0, frozen-dt)
	flash = maxf(0, flash-dt)
	if is_instance_valid(core):
		core.material_override = Forge.mat(Color.WHITE if flash > 0 else (Forge.BONE if frozen > 0 else tint), 1)
	if lift > 0:
		lift -= dt
		velocity.y = 12
		if lift <= 0:
			take_damage(42, Vector3.DOWN * 16, "", "НЕБОПОГРЕБЕНИЕ")
			if dead:
				return
			game.fx.burst(global_position, Forge.BONE, 12, 7)
	if burn > 0:
		burn -= dt
		burn_timer -= dt
		if burn_timer <= 0:
			burn_timer = 0.4
			take_damage(8, Vector3.ZERO, "", "ГОРЕНИЕ")
			if dead: return
	var to_player = game.player.global_position - global_position
	var distance = to_player.length()
	var dir = Vector3(to_player.x, 0, to_player.z).normalized()
	if _on_plane(): dir.z = 0
	if dir.length_squared() > 0.01:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), dt * 9)
	var movement = dir * speed * (0.25 if frozen > 0 else 1.0)
	if kind == 1:
		if distance < 8: movement *= -0.5
		elif distance < 16: movement *= 0.15
	if kind == 3:
		movement *= 0.3
	if charge > 0:
		charge -= dt
		movement = Vector3.ZERO
		warning.visible = true
		warning.scale = Vector3.ONE * (4.0 if kind == 2 else 9.0) * (1.0-charge/0.9)
		if charge <= 0:
			warning.visible = false
			var radius = 4.3 if kind == 2 else 9.5
			game.fx.wave(global_position + Vector3.UP*0.12, tint, radius)
			if distance < radius and game.player.global_position.y < global_position.y + 1.6:
				game.player.hurt(22 if kind == 2 else 30)
			game.shake = 0.3
	if dash_t > 0:
		dash_t -= dt
		movement = dash_dir * 34.0
		if distance < 2.4:
			game.player.hurt(16)
	if laser_t > 0:
		_tick_laser(dt)
		movement *= 0.15
	velocity.x = movement.x + stagger.x
	velocity.z = movement.z + stagger.z
	if lift > 0:
		velocity.y = 12
	else:
		velocity.y -= 24 * dt
	stagger = stagger.move_toward(Vector3.ZERO, dt*20)
	if is_on_wall() and is_on_floor(): velocity.y = 8.5
	move_and_slide()
	if body.has_method("animate"):
		body.animate(dt, velocity, is_on_floor(), kind == 0 and distance < 2.4, charge, frozen > 0, lift > 0)
	if _on_plane():
		global_position.z = move_toward(global_position.z, 0, dt*10)
	_clamp_home()
	if attack_timer <= 0 and frozen <= 0 and charge <= 0 and dash_t <= 0 and laser_t <= 0:
		if kind == 0 and distance < 2.0:
			game.player.hurt(10); attack_timer = 0.9
			if body.has_method("strike"): body.strike()
		elif kind == 1 and distance < 28:
			shoot(to_player, 15); attack_timer = 1.7
			if body.has_method("strike"): body.strike()
		elif kind == 2 and distance < 5:
			charge = 0.9; attack_timer = 3.2
			if body.has_method("strike"): body.strike()
		elif kind == 3:
			_boss_attack(to_player, dir, distance)

func _on_plane() -> bool:
	return sector % 2 == 1 and sector < 9

func _clamp_home() -> void:
	if kind == 3:
		if stage >= 3:
			global_position.x = clampf(global_position.x, 588, 646)
			global_position.z = clampf(global_position.z, -20, 20)
		else:
			global_position.x = clampf(global_position.x, sector*65.0+2, sector*65.0+62)
			global_position.z = clampf(global_position.z, -8.6, 8.6)
		return
	global_position.x = clampf(global_position.x, sector*65+2, sector*65+62)
	global_position.z = clampf(global_position.z, -8.6, 8.6)

func _boss_attack(to_player: Vector3, dir: Vector3, distance: float) -> void:
	boss_cycle += 1
	attack_timer = 1.65 - stage * 0.18
	if body.has_method("strike"):
		body.strike()
	match stage:
		0:
			if boss_cycle % 3 == 0:
				charge = 0.9
				game.notify("УДАРНАЯ ВОЛНА — ПРЫГАЙ", tint, 1.0)
			else:
				_fan(0.22, 3, 18, 14)
		1:
			if boss_cycle % 2 == 0:
				dash_t = 0.42
				dash_dir = Vector3(signf(dir.x) if absf(dir.x) > 0.1 else 1.0, 0, 0)
				game.notify("РЫВОК ПО ПЛОСКОСТИ — ПРЫГАЙ", tint, 1.0)
			else:
				_rain()
				game.notify("ДОЖДЬ ОСКОЛКОВ", tint, 1.0)
		2:
			if boss_cycle % 4 == 0:
				game.spawn_enemy(global_position + Vector3(-4, 1, 3), 0, sector)
				game.spawn_enemy(global_position + Vector3(-4, 1, -3), 0, sector)
				game.notify("СТРАЖИ ПРИЛИВА", tint, 1.0)
			elif boss_cycle % 2 == 0:
				laser_t = 1.05
				laser_angle = 0.0
				dual_laser = false
				game.notify("ЛУЧ — УКЛОНЯЙСЯ", tint, 1.0)
			else:
				_fan(0.18, 5, 20, 12)
		_:
			var pick = boss_cycle % 4
			if pick == 0:
				charge = 0.75
				game.notify("КОЛЬЦО — ПРЫГАЙ", tint, 1.0)
			elif pick == 1:
				_pillars()
				game.notify("СТОЛПЫ ЯДРА", tint, 1.0)
			elif pick == 2:
				laser_t = 1.25
				laser_angle = 0.4
				dual_laser = true
				game.notify("ДВОЙНОЙ ЛУЧ", tint, 1.0)
			else:
				_fan(0.28, 6, 16, 13)

func _fan(spread: float, count: int, shot_speed: float, dmg: float) -> void:
	var origin = global_position + Vector3.UP*2.3
	var aim = (game.player.global_position + Vector3.UP - origin).normalized()
	var mid = (count - 1) * 0.5
	for i in range(count):
		var ang = (float(i) - mid) * spread
		game.spawn_projectile(origin, aim.rotated(Vector3.UP, ang)*shot_speed, dmg, false, tint)

func _rain() -> void:
	var px = game.player.global_position.x
	for i in range(6):
		var at = Vector3(px + float(i - 2) * 2.4, 9.5, 0)
		game.spawn_projectile(at, Vector3(0, -16, 0), 12, false, tint, 0, "", "", "orb", 0, 22.0)

func _pillars() -> void:
	var base = game.player.global_position
	for off in [Vector3.ZERO, Vector3(5, 0, 4), Vector3(-5, 0, -4)]:
		var p = base + off
		p.y = 0
		game.fx.column(p, tint, 8)
		game.spawn_zone(p, 2.4, 1.6, 22, "", tint)

func _tick_laser(dt: float) -> void:
	laser_t -= dt
	laser_angle += dt * (2.2 if dual_laser else 1.7)
	laser_tick -= dt
	var origin = global_position + Vector3.UP * 2.1
	var dirs = [Vector3(cos(laser_angle), 0, sin(laser_angle))]
	if dual_laser:
		dirs.append(Vector3(cos(laser_angle + PI * 0.5), 0, sin(laser_angle + PI * 0.5)))
	for beam_dir in dirs:
		var tip = origin + beam_dir * 36
		game.fx.beam(origin, tip, tint, 0.14, 0.05)
		if laser_tick <= 0 and _near_segment(game.player.global_position + Vector3.UP, origin, tip, 1.15):
			game.player.hurt(9)
	if laser_tick <= 0:
		laser_tick = 0.16

func _near_segment(point: Vector3, a: Vector3, b: Vector3, radius: float) -> bool:
	var ab = b - a
	var t = clampf((point - a).dot(ab) / maxf(0.001, ab.length_squared()), 0, 1)
	return point.distance_to(a + ab * t) <= radius

func shoot(_direction: Vector3, projectile_speed: float) -> void:
	var origin = global_position + Vector3.UP*1.3
	var aim = (game.player.global_position + Vector3.UP*0.9 - origin).normalized()
	var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, game.player.global_position+Vector3.UP, 1))
	if hit.is_empty():
		game.spawn_projectile(origin, aim*projectile_speed, 12, false, tint)

func _advance_stage() -> void:
	if stage >= 3:
		return
	stage += 1
	sector = 6 + stage
	var dest = [Vector3(423, 0.2, 0), Vector3(488, 0.2, 0), Vector3(552, 0.2, 0), Vector3(617, 0.2, 0)][stage]
	game.fx.burst(global_position + Vector3.UP * 2, tint, 28, 12)
	game.fx.wave(global_position, tint, 10)
	global_position = dest
	game.fx.slash(dest + Vector3.UP * 2, Vector3.RIGHT, tint, 5)
	game.world.open_boss_gate(stage - 1)
	var titles = ["ЯВЛЕНИЕ", "ПОГОНЯ / 2D", "ШТОРМ / 3D", "КВАДРАТ ЯДРА"]
	game.notify("ОНО УХОДИТ — " + titles[stage], tint, 2.4)
	attack_timer = 1.1
	charge = 0.0
	dash_t = 0.0
	laser_t = 0.0

func take_damage(amount: float, push: Vector3 = Vector3.ZERO, status: String = "", weapon: String = "") -> void:
	if dead: return
	hp -= amount
	flash = 0.09
	if body.has_method("flinch_hit"):
		body.flinch_hit()
	stagger += push * (0.2 if kind == 3 else 1.0)
	if status == "freeze": frozen = 2.5 if kind < 3 else 0.65
	if status == "burn": burn = 3.0
	game.hit_marker = 0.14
	game.fx.burst(global_position+Vector3.UP, tint, 5, 4)
	game.audio.play_sfx("hit")
	if kind == 3 and hp > 0:
		var want = 0
		if hp < max_hp * 0.75: want = 1
		if hp < max_hp * 0.50: want = 2
		if hp < max_hp * 0.25: want = 3
		while stage < want:
			_advance_stage()
	if hp <= 0:
		dead = true
		collision_layer = 0
		game.enemy_killed(self, weapon)
		queue_free()
