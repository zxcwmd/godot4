class_name RiftEnemy
extends CharacterBody3D

const Arsenal = preload("res://scripts/arsenal.gd")

var game: Node3D
var kind := 0
var health := 60.0
var max_health := 60.0
var speed := 5.5
var damage := 10.0
var dead := false
var cooldown := 1.0
var slowed := 0.0
var flash := 0.0
var knockback := Vector3.ZERO
var visual: Node3D
var color := Arsenal.ORANGE
var age := 0.0
var room := 0
var warning: MeshInstance3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.6
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.height = 2.2 if kind == 2 else 1.8
	capsule.radius = 0.65 if kind == 2 else 0.45
	shape.shape = capsule
	shape.position.y = capsule.height / 2
	add_child(shape)
	var difficulty = 1.0 + game.elapsed / 180.0
	health = [55.0, 42.0, 165.0][kind] * difficulty
	max_health = health
	speed = [6.0, 3.8, 3.4][kind] + minf(game.elapsed / 90.0, 3.0)
	damage = [10.0, 9.0, 22.0][kind] * (1 + game.elapsed / 420.0)
	color = [Arsenal.ORANGE, Arsenal.VIOLET, Color("ffcf63")][kind]
	visual = Node3D.new()
	add_child(visual)
	var s = 1.4 if kind == 2 else 1.0
	game.visual_box(visual, Vector3(0, 1, 0) * s, Vector3(0.7, 0.85, 0.55) * s, Color("262a3e"))
	game.visual_box(visual, Vector3(0, 1.65, 0) * s, Vector3(0.6, 0.4, 0.55) * s, color)
	game.visual_box(visual, Vector3(0, 1.65, -0.29) * s, Vector3(0.42, 0.07, 0.04) * s, Color.WHITE)
	for side in [-1, 1]:
		game.visual_box(visual, Vector3(side * 0.48, 0.95, 0) * s, Vector3(0.18, 0.7, 0.22) * s, color)
		game.visual_box(visual, Vector3(side * 0.22, 0.25, 0) * s, Vector3(0.19, 0.5, 0.22) * s, Color("47506b"))
	warning = game.visual_box(visual, Vector3(0, 2.15, 0) * s, Vector3(0.22, 0.22, 0.22), Color.WHITE)
	warning.visible = false
	game.fx.ring(global_position + Vector3.UP * 0.15, 1.3, color)

func _physics_process(dt: float) -> void:
	if dead or game.state != "RUN":
		return
	age += dt
	cooldown -= dt
	slowed = maxf(0, slowed - dt)
	flash = maxf(0, flash - dt)
	visual.scale = Vector3.ONE * (1.0 + flash * 0.6)
	var offset = game.player.global_position - global_position
	var distance = offset.length()
	if distance > 85:
		game.enemies.erase(self)
		queue_free()
		return
	var target = game.player.global_position
	room = game.nearest_sector(global_position)
	if room != game.sector:
		target = game.centers[room + (1 if game.sector > room else -1)]
	var direction = target - global_position
	direction.y = 0
	direction = direction.normalized()
	if direction.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 8 * dt)
	var movement = direction * speed * (0.35 if slowed > 0 else 1.0)
	if kind == 1 and distance < 15 and game.clear_line(global_position + Vector3.UP, game.player.global_position + Vector3.UP):
		movement *= -0.25 if distance < 7 else 0.1
	# Cheap separation prevents a whole wave occupying a single point.
	for other in game.enemies:
		if other == self or not is_instance_valid(other):
			continue
		var apart = global_position - other.global_position
		apart.y = 0
		if apart.length_squared() < 1.5 and apart.length_squared() > 0.01:
			movement += apart.normalized() * 2.5
	velocity.x = movement.x + knockback.x
	velocity.z = movement.z + knockback.z
	velocity.y -= 24 * dt
	knockback = knockback.move_toward(Vector3.ZERO, dt * 30)
	move_and_slide()
	visual.position.y = sin(age * 9) * 0.06
	warning.visible = cooldown < 0.38
	if cooldown <= 0:
		if kind == 1 and distance < 28 and game.clear_line(global_position + Vector3.UP * 1.5, game.player.global_position + Vector3.UP):
			var origin = global_position + Vector3.UP * 1.5
			var aim = (game.player.global_position + Vector3.UP + game.player.velocity * 0.15 - origin).normalized()
			game.spawn_projectile(origin, aim, 13, damage, color, true)
			game.sound.play("shot", -25, 0.7)
			cooldown = 1.9
		elif distance < (3.2 if kind == 2 else 2.2):
			if kind == 2:
				game.fx.ring(global_position + Vector3.UP * 0.15, 3.2, color)
			game.player.hurt(damage)
			cooldown = 1.3 if kind == 2 else 0.85
	if global_position.y < -30:
		game.enemies.erase(self)
		queue_free()

func take_damage(amount: float, push: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	health -= amount
	knockback += push
	flash = 0.18
	game.hit_marker = 0.13
	game.fx.burst(global_position + Vector3.UP * 1.1, color, 5, 5)
	game.sound.play("hit", -20)
	if health <= 0:
		dead = true
		game.fx.burst(global_position + Vector3.UP, color, 18, 10)
		game.enemy_killed(self)
		game.enemies.erase(self)
		queue_free()
