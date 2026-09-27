extends Node3D
## Short-lived pooled-by-lifetime meshes. Always capped by the caller.
var pieces = []

func burst(at: Vector3, color: Color, count: int = 10, power: float = 6.0) -> void:
	count = mini(count, 160 - pieces.size())
	for i in range(count):
		var mesh = Forge.box(self, at, Vector3.ONE * randf_range(0.04, 0.16), color, 1.0)
		pieces.append({"node": mesh, "velocity": Vector3(randf_range(-1, 1), randf_range(0.1, 1.4), randf_range(-1, 1)) * power, "life": randf_range(0.2, 0.65), "max": 0.65, "type": 0})

func beam(a: Vector3, b: Vector3, color: Color, width: float = 0.045, life: float = 0.13) -> void:
	if pieces.size() > 170 or a.distance_to(b) < 0.01:
		return
	var mesh = Forge.box(self, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), color, 1.0)
	var axis = Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	if a.distance_to(b) > 0.01:
		mesh.look_at(b, axis)
	pieces.append({"node": mesh, "velocity": Vector3.ZERO, "life": life, "max": life, "type": 1})

func wave(at: Vector3, color: Color, radius: float = 6.0) -> void:
	if pieces.size() > 170:
		return
	var mesh = Forge.ring(self, at, 1.0, color, 0.05)
	pieces.append({"node": mesh, "velocity": Vector3.ONE * radius, "life": 0.4, "max": 0.4, "type": 2})

func _process(dt: float) -> void:
	for i in range(pieces.size() - 1, -1, -1):
		var p = pieces[i]
		p.life -= dt
		if p.life <= 0:
			p.node.queue_free()
			pieces.remove_at(i)
			continue
		if p.type == 0:
			p.node.position += p.velocity * dt
			p.velocity.y -= dt * 14
			p.node.rotate_x(dt * 8)
			p.node.scale = Vector3.ONE * maxf(0.03, p.life / p.max)
		elif p.type == 1:
			p.node.scale.x = p.life / p.max
			p.node.scale.y = p.life / p.max
		else:
			p.node.scale = Vector3.ONE * (1.0 + (1.0 - p.life / p.max) * p.velocity.x)
