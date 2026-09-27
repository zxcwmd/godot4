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
var tint = Color("ff608c")
var body: Node3D
var core: MeshInstance3D
var warning: MeshInstance3D
var charge = 0.0
var boss_cycle = 0
var flash = 0.0

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
	body = Node3D.new()
	add_child(body)
	match kind:
		0:
			hp = 65; speed = 6.8; tint = Color("ff608c")
		1:
			hp = 85; speed = 3.6; tint = Color("ffc16b")
		2:
			hp = 170; speed = 3.0; tint = Color("c789ff")
		3:
			hp = 2300; speed = 1.8; tint = Color("ff4968")
	max_hp = hp
	if kind == 3:
		core = Forge.orb(body, Vector3(0, 2.5, 0), 1.25, tint)
		for i in range(3):
			var ring = Forge.ring(body, Vector3(0, 2.5, 0), 2.1+i*0.2, tint, 0.1)
			ring.rotation = Vector3(i*0.9, 0, i*0.7)
		for x in [-1.9, 1.9]:
			Forge.box(body, Vector3(x, 2.3, 0), Vector3(0.6, 2.8, 0.8), Color("3b2339"))
	else:
		var size = 1.35 if kind == 2 else 1.0
		Forge.box(body, Vector3(0, 1.05, 0) * size, Vector3(0.85, 0.85, 0.5) * size, Color("354459"))
		Forge.box(body, Vector3(0, 1.65, 0) * size, Vector3(0.6, 0.4, 0.5) * size, Color("1b2431"))
		core = Forge.box(body, Vector3(0, 1.68, 0.27) * size, Vector3(0.52, 0.12, 0.06) * size, tint, 1)
		for x in [-0.52, 0.52]:
			Forge.box(body, Vector3(x, 0.98, 0) * size, Vector3(0.2, 0.9, 0.28) * size, tint)
			Forge.box(body, Vector3(x*0.5, 0.35, 0) * size, Vector3(0.25, 0.7, 0.32) * size, Color("2b394d"))
		if kind == 1:
			Forge.box(body, Vector3(0.55, 1.1, 0.55), Vector3(0.32, 0.32, 1.1), Color("ffc16b"), 1)
	warning = Forge.ring(self, Vector3(0, 0.08, 0), 1.0, tint, 0.04)
	warning.visible = false

func _physics_process(dt: float) -> void:
	if dead or game.phase not in ["run", "escape"]:
		return
	age += dt
	attack_timer -= dt
	frozen = maxf(0, frozen-dt)
	flash = maxf(0, flash-dt)
	core.material_override = Forge.mat(Color.WHITE if flash > 0 else (Color("71eaff") if frozen > 0 else tint), 1)
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
	if sector % 2 == 1: dir.z = 0
	if dir.length_squared() > 0.01:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), dt * 9)
	var movement = dir * speed * (0.25 if frozen > 0 else 1.0)
	if kind == 1:
		if distance < 8: movement *= -0.5
		elif distance < 16: movement *= 0.15
	if kind == 3:
		movement *= 0.3
		for child in body.get_children():
			if child is MeshInstance3D and child.mesh is TorusMesh:
				child.rotate_x(dt*0.8)
				child.rotate_z(dt*0.6)
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
	velocity.x = movement.x + stagger.x
	velocity.z = movement.z + stagger.z
	velocity.y -= 24 * dt
	stagger = stagger.move_toward(Vector3.ZERO, dt*20)
	if is_on_wall() and is_on_floor(): velocity.y = 8.5
	move_and_slide()
	if sector % 2 == 1:
		global_position.z = move_toward(global_position.z, 0, dt*10)
	global_position.x = clampf(global_position.x, sector*65+2, sector*65+62)
	global_position.z = clampf(global_position.z, -8.6, 8.6)
	if attack_timer <= 0 and frozen <= 0 and charge <= 0:
		if kind == 0 and distance < 2.0:
			game.player.hurt(10); attack_timer = 0.9
		elif kind == 1 and distance < 28:
			shoot(to_player, 15); attack_timer = 1.7
		elif kind == 2 and distance < 5:
			charge = 0.9; attack_timer = 3.2
		elif kind == 3:
			boss_cycle += 1
			attack_timer = 1.7 if hp > max_hp*0.5 else 1.15
			if boss_cycle % 3 == 0:
				charge = 0.9
				game.notify("УДАРНАЯ ВОЛНА — ПРЫГАЙ", tint, 1.0)
			else:
				var origin = global_position + Vector3.UP*2.3
				var aim = (game.player.global_position + Vector3.UP - origin).normalized()
				for angle in [-0.22, 0.0, 0.22]:
					game.spawn_projectile(origin, aim.rotated(Vector3.UP, angle)*18, 14, false, tint)
				if hp < max_hp*0.5 and boss_cycle%4 == 0:
					game.spawn_enemy(global_position + Vector3(-5, 1, 3), 0, 6)

func shoot(_direction: Vector3, projectile_speed: float) -> void:
	var origin = global_position + Vector3.UP*1.3
	var aim = (game.player.global_position + Vector3.UP*0.9 - origin).normalized()
	var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, game.player.global_position+Vector3.UP, 1))
	if hit.is_empty():
		game.spawn_projectile(origin, aim*projectile_speed, 12, false, tint)

func take_damage(amount: float, push: Vector3 = Vector3.ZERO, status: String = "", weapon: String = "") -> void:
	if dead: return
	hp -= amount
	flash = 0.09
	stagger += push * (0.2 if kind == 3 else 1.0)
	if status == "freeze": frozen = 2.5 if kind < 3 else 0.65
	if status == "burn": burn = 3.0
	game.hit_marker = 0.14
	game.fx.burst(global_position+Vector3.UP, tint, 5, 4)
	game.audio.play_sfx("hit")
	if hp <= 0:
		dead = true
		collision_layer = 0
		game.enemy_killed(self, weapon)
		queue_free()
