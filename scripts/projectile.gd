extends Node3D
var game
var velocity = Vector3.ZERO
var damage = 10.0
var life = 5.0
var friendly = false
var tint = Color("ff608c")
var blast = 0.0
var status = ""
var source_name = ""
var style = "orb"
var ricochets = 0
var visited = []
var ignored_bodies: Array[RID] = []
var spin: MeshInstance3D
var visual: MeshInstance3D

func _ready() -> void:
	add_to_group("projectiles")
	visual = Forge.orb(self, Vector3.ZERO, 0.14 if not friendly else 0.2, tint)
	spin = Forge.ring(self, Vector3.ZERO, 0.42 if style == "disc" else 0.3, tint, 0.06 if style == "disc" else 0.025)
	spin.rotation.x = PI / 2
	if style == "disc":
		visual.scale = Vector3(1.6, 0.15, 1.6)

func _physics_process(dt: float) -> void:
	if game.phase not in ["run", "escape"]:
		queue_free()
		return
	spin.rotate_x(dt * 10)
	spin.rotate_y(dt * 12)
	life -= dt
	if life <= 0:
		queue_free()
		return
	var next = global_position + velocity * dt
	var query = PhysicsRayQueryParameters3D.create(global_position, next, 5 if friendly else 3)
	query.exclude = ignored_bodies
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + hit.normal * 0.025
		if friendly:
			if blast > 0:
				game.explode(global_position, blast, damage, tint, status, source_name)
			elif hit.collider.has_method("take_damage"):
				hit.collider.take_damage(damage, velocity.normalized() * 7, status, source_name)
				if style == "disc" and ricochets > 0:
					visited.append(hit.collider)
					ignored_bodies.append(hit.collider.get_rid())
					var next_target = game.closest_enemy(global_position, 16, visited)
					if next_target != null:
						ricochets -= 1
						var direction = (next_target.global_position+Vector3.UP-global_position).normalized()
						velocity = direction * 42
						global_position += direction * 0.4
						game.fx.burst(global_position, tint, 5, 4)
						return
		else:
			if hit.collider == game.player:
				game.player.hurt(damage)
		game.fx.burst(global_position, tint, 6, 3)
		queue_free()
	else:
		global_position = next
