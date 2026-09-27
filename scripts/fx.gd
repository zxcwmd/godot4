extends Node3D
## Particle slashes plus short-lived tracer meshes.
var pieces = []

func burst(at: Vector3, color: Color, count: int = 10, power: float = 6.0) -> void:
	count = mini(count, 160 - pieces.size())
	for i in range(count):
		var mesh = Forge.box(self, at, Vector3.ONE * randf_range(0.04, 0.16), color, 1.0)
		pieces.append({"node": mesh, "velocity": Vector3(randf_range(-1, 1), randf_range(0.2, 1.6), randf_range(-1, 1)) * power, "life": randf_range(0.2, 0.6), "max": 0.6, "type": 0})

func beam(a: Vector3, b: Vector3, color: Color, width: float = 0.045, life: float = 0.13) -> void:
	if pieces.size() > 170 or a.distance_to(b) < 0.01:
		return
	var mesh = Forge.box(self, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), color, 1.0)
	var axis = Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	mesh.look_at(b, axis)
	pieces.append({"node": mesh, "velocity": Vector3.ZERO, "life": life, "max": life, "type": 1})

func wave(at: Vector3, color: Color, radius: float = 6.0) -> void:
	if pieces.size() > 170:
		return
	var mesh = Forge.ring(self, at, 1.0, color, 0.05)
	pieces.append({"node": mesh, "velocity": Vector3.ONE * radius, "life": 0.4, "max": 0.4, "type": 2})

func flash(at: Vector3, color: Color, size: float = 0.22) -> void:
	if pieces.size() > 170:
		return
	var mesh = Forge.orb(self, at, size, color, 1.4)
	pieces.append({"node": mesh, "velocity": Vector3.ZERO, "life": 0.08, "max": 0.08, "type": 1})

func column(at: Vector3, color: Color, height: float = 6.0) -> void:
	if pieces.size() > 170:
		return
	var mesh = Forge.cyl(self, at + Vector3(0, height * 0.5, 0), 0.16, height, color, 1.0, 0.03)
	pieces.append({"node": mesh, "velocity": Vector3.ZERO, "life": 0.45, "max": 0.45, "type": 3})

func slash(origin: Vector3, forward: Vector3, color: Color, radius: float = 3.2) -> void:
	if pieces.size() > 150:
		return
	forward = Vector3(forward.x, forward.y * 0.35, forward.z)
	if forward.length() < 0.01:
		forward = Vector3.RIGHT
	forward = forward.normalized()
	var up = Vector3.UP
	if absf(forward.dot(up)) > 0.92:
		up = Vector3.RIGHT
	var right = forward.cross(up).normalized()
	if right.length() < 0.1:
		return
	var pts := PackedVector3Array()
	for i in range(16):
		var a = -1.05 + float(i) * 0.14
		pts.append((forward * cos(a) + right * sin(a)) * radius)
	var dust = _emitter(origin, color, 44, 0.3)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	dust.emission_points = pts
	dust.direction = forward
	dust.spread = 26.0
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 18.0
	dust.gravity = Vector3(0, 4, 0)
	dust.scale_amount_min = 0.04
	dust.scale_amount_max = 0.13
	var petal = BoxMesh.new()
	petal.size = Vector3(0.04, 0.01, 0.22)
	dust.mesh = petal
	dust.restart()
	dust.emitting = true
	pieces.append({"node": dust, "velocity": Vector3.ZERO, "life": 0.42, "max": 0.42, "type": 4})
	var sparks = _emitter(origin + forward * 0.35, color, 20, 0.22)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.16
	sparks.direction = forward
	sparks.spread = 72.0
	sparks.initial_velocity_min = 3.5
	sparks.initial_velocity_max = 10.0
	sparks.gravity = Vector3(0, -3, 0)
	sparks.scale_amount_min = 0.04
	sparks.scale_amount_max = 0.1
	var seed = SphereMesh.new()
	seed.radius = 0.045
	seed.height = 0.09
	seed.radial_segments = 6
	seed.rings = 3
	sparks.mesh = seed
	sparks.restart()
	sparks.emitting = true
	pieces.append({"node": sparks, "velocity": Vector3.ZERO, "life": 0.36, "max": 0.36, "type": 4})

func crescent(origin: Vector3, forward: Vector3, color: Color, radius: float = 3.2) -> void:
	slash(origin, forward, color, radius)

func _emitter(at: Vector3, color: Color, amount: int, life: float) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	add_child(p)
	p.global_position = at
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.94
	p.local_coords = true
	p.color = color
	p.damping_min = 1.4
	p.damping_max = 5.0
	p.material_override = Forge.mat(color, 1.5)
	return p

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
			p.velocity.y -= dt * 12
			p.node.rotate_z(dt * 10)
			p.node.scale = Vector3.ONE * maxf(0.03, p.life / p.max)
		elif p.type == 1:
			p.node.scale.x = p.life / p.max
			p.node.scale.y = p.life / p.max
		elif p.type == 2:
			p.node.scale = Vector3.ONE * (1.0 + (1.0 - p.life / p.max) * p.velocity.x)
		elif p.type == 3:
			p.node.scale.y = maxf(0.05, p.life / p.max)
			p.node.scale.x = 1.15 - p.life / p.max * 0.35
			p.node.scale.z = p.node.scale.x
