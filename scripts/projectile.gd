extends Node3D
var game
var velocity = Vector3.ZERO
var damage = 10.0
var life = 5.0
var friendly = false
var tint = Color("9a2a32")
var blast = 0.0
var status = ""
var source_name = ""
var style = "orb"
var ricochets = 0
var visited = []
var ignored_bodies: Array[RID] = []
var gravity = 0.0
var spin: MeshInstance3D
var visual: MeshInstance3D

func _ready() -> void:
	add_to_group("projectiles")
	match style:
		"disc":
			visual = Forge.orb(self, Vector3.ZERO, 0.22, tint)
			visual.scale = Vector3(1.6, 0.14, 1.6)
			spin = Forge.ring(self, Vector3.ZERO, 0.42, tint, 0.06)
			spin.rotation.x = PI / 2
		"bolt", "nail", "harpoon":
			var length = 0.7 if style == "harpoon" else (0.45 if style == "bolt" else 0.22)
			visual = Forge.cyl(self, Vector3.ZERO, 0.035 if style != "nail" else 0.02, length, tint, 0.8, 0.01)
			visual.rotation_degrees.x = 90
			spin = Forge.box(self, Vector3(0, 0, length * 0.2), Vector3(0.12, 0.02, 0.02), Forge.BONE)
		"bomb":
			visual = Forge.orb(self, Vector3.ZERO, 0.18, tint, 1.0)
			spin = Forge.cyl(self, Vector3(0, 0.16, 0), 0.05, 0.12, Forge.BRONZE)
		_:
			visual = Forge.orb(self, Vector3.ZERO, 0.14 if not friendly else 0.2, tint)
			spin = Forge.ring(self, Vector3.ZERO, 0.3, tint, 0.025)
			spin.rotation.x = PI / 2

func _physics_process(dt: float) -> void:
	if game.phase not in ["run", "escape"]:
		queue_free()
		return
	if is_instance_valid(spin):
		spin.rotate_x(dt * 10)
		spin.rotate_y(dt * 12)
	life -= dt
	if life <= 0:
		if blast > 0:
			game.explode(global_position, blast, damage, tint, status, source_name)
		queue_free()
		return
	velocity.y -= gravity * dt
	if velocity.length() > 0.15 and style in ["bolt", "nail", "harpoon", "bomb"]:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.95 else Vector3.RIGHT)
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
				if style == "harpoon":
					var pull = (game.player.global_position - hit.collider.global_position).normalized() * 24
					hit.collider.stagger += pull
					game.fx.beam(game.player.global_position + Vector3.UP, hit.collider.global_position + Vector3.UP, tint, 0.05, 0.25)
				if style == "disc" and ricochets > 0:
					visited.append(hit.collider)
					ignored_bodies.append(hit.collider.get_rid())
					var next_target = game.closest_enemy(global_position, 16, visited)
					if next_target != null:
						ricochets -= 1
						var direction = (next_target.global_position + Vector3.UP - global_position).normalized()
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
