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
var practice_target := false
var target_recovery := 0.0
var nav_path := PackedVector3Array()
var nav_timer := 0.0

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
	if practice_target:
		health = 1000
		max_health = 1000
		color = Arsenal.CYAN
	visual = Node3D.new()
	add_child(visual)
	game.art.actor(visual, "target" if practice_target else ["scavenger", "robot", "beast"][kind], color)
	var s = 1.25 if kind == 2 else 1.0
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
	visual.rotation.z = sin(flash * 50) * flash * 0.4
	if practice_target:
		target_recovery -= dt
		if target_recovery <= 0:
			health = max_health
		return
	var offset = game.player.global_position - global_position
	var distance = offset.length()
	if distance > 85:
		game.enemies.erase(self)
		queue_free()
		return
	var target: Vector3 = game.enemy_target(global_position)
	if not game.sandbox:
		nav_timer -= dt
		var needs_route = abs(target.y - position.y) > 2.5 or position.y - game.centers[game.nearest_sector(position)].y > 2.5 or not game.clear_line(position + Vector3.UP, target + Vector3.UP)
		if needs_route:
			if nav_timer <= 0 or nav_path.is_empty():
				nav_path = game.world.route(position, target)
				nav_timer = 2.0
				if nav_path.size() > 1:
					var segment = nav_path[1] - nav_path[0]
					var progress = (position - nav_path[0]).dot(segment) / maxf(0.01, segment.length_squared())
					var on_path = nav_path[0] + segment * clampf(progress, 0, 1)
					if progress > 0 and position.distance_to(on_path) < 3:
						nav_path.remove_at(0)
			while nav_path.size() > 1 and position.distance_to(nav_path[0]) < 1.4:
				nav_path.remove_at(0)
			if not nav_path.is_empty():
				target = nav_path[0]
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
	game.art.animate_actor(visual, velocity.length(), age, clampf(1 - cooldown / 0.38, 0, 1))
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
	game.report_hit(self, amount if practice_target else minf(amount, health))
	health -= amount
	target_recovery = 2.0
	knockback += push
	flash = 0.18
	game.hit_marker = 0.13
	game.fx.burst(global_position + Vector3.UP * 1.1, color, 5, 5)
	game.sound.play("hit", -20)
	if practice_target:
		knockback = Vector3.ZERO
		if health <= 0:
			health = max_health
		return
	if health <= 0:
		game.fx.dismantle(visual, push)
		dead = true
		game.fx.burst(global_position + Vector3.UP, color, 18, 10)
		game.enemy_killed(self)
		game.enemies.erase(self)
		queue_free()
