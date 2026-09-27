class_name RiftProjectile
extends Node3D

const Arsenal = preload("res://scripts/arsenal.gd")
const RiftEnemy = preload("res://scripts/enemy.gd")

var game: Node3D
var direction := Vector3.FORWARD
var speed := 25.0
var damage := 20.0
var color := Arsenal.ORANGE
var hostile := false
var disc := false
var radius := 0.0
var slow := 0.0
var age := 0.0
var trail_timer := 0.0
var hits: Array[int] = []
var visual: MeshInstance3D

func _ready() -> void:
	visual = game.visual_box(self, Vector3.ZERO, Vector3(0.7, 0.08, 0.7) if disc else Vector3.ONE * (0.3 if hostile else 0.22), color)

func _physics_process(dt: float) -> void:
	if game.state != "RUN":
		return
	age += dt
	if age > 4.0:
		queue_free()
		return
	if disc and age > 0.65:
		direction = (game.player.global_position + Vector3.UP * 1.2 - global_position).normalized()
		if global_position.distance_to(game.player.global_position + Vector3.UP * 1.2) < 1.0:
			queue_free()
			return
	visual.rotate_y(dt * 18)
	var previous = global_position
	var next = previous + direction * speed * dt
	var query = PhysicsRayQueryParameters3D.create(previous, next, 1 | (2 if hostile else 4))
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result.position
		var collider = result.collider
		if hostile:
			if collider == game.player:
				game.player.hurt(damage)
			detonate()
			return
		elif collider is RiftEnemy:
			if not hits.has(collider.get_instance_id()):
				hits.append(collider.get_instance_id())
				collider.take_damage(damage, direction * 3)
				collider.slowed = slow
			if not disc:
				detonate()
				return
		elif disc and age < 0.65:
			age = 0.66
		else:
			detonate()
			return
	global_position = next
	trail_timer -= dt
	if trail_timer <= 0:
		game.fx.beam(previous, next, color, 0.045, 0.14)
		trail_timer = 0.04

func detonate() -> void:
	game.fx.burst(global_position, color, 9, 5)
	if radius > 0 and not hostile:
		game.area_damage(global_position, radius, damage * 0.65, color, slow)
	queue_free()
