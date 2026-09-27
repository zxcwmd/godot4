class_name RiftFX
extends Node3D

var bits: Array[Dictionary] = []
var material_cache: Dictionary = {}
var mesh_cache: Dictionary = {}
var enabled := true

func mat(color: Color, emission: float = 1.0) -> StandardMaterial3D:
	var key = str(color) + str(emission)
	if material_cache.has(key):
		return material_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color * emission
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_cache[key] = m
	return m

func burst(pos: Vector3, color: Color, count: int = 12, force: float = 8.0) -> void:
	if not enabled:
		return
	for i in mini(count, maxi(0, 450 - bits.size())):
		var node = MeshInstance3D.new()
		if not mesh_cache.has("bit"):
			var mesh = BoxMesh.new()
			mesh.size = Vector3.ONE * 0.12
			mesh_cache["bit"] = mesh
		node.mesh = mesh_cache["bit"]
		node.material_override = mat(color)
		add_child(node)
		node.global_position = pos
		var v = Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized() * randf_range(force * 0.3, force)
		bits.append({"node": node, "velocity": v, "life": randf_range(0.2, 0.55), "max": 0.55, "gravity": true})

func beam(a: Vector3, b: Vector3, color: Color, width: float = 0.06, duration: float = 0.12) -> void:
	if bits.size() > 480 or a.distance_to(b) < 0.02:
		return
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(width, width, a.distance_to(b))
	node.mesh = mesh
	node.material_override = mat(color)
	add_child(node)
	node.global_position = (a + b) * 0.5
	if abs((b - a).normalized().dot(Vector3.UP)) > 0.99:
		node.look_at(b, Vector3.RIGHT)
	else:
		node.look_at(b)
	bits.append({"node": node, "velocity": Vector3.ZERO, "life": duration, "max": duration, "gravity": false})

func ring(pos: Vector3, radius: float, color: Color) -> void:
	for i in 24:
		var a = TAU * i / 24.0
		var b = TAU * (i + 1) / 24.0
		beam(pos + Vector3(cos(a), 0, sin(a)) * radius, pos + Vector3(cos(b), 0, sin(b)) * radius, color, 0.09, 0.22)

func _process(dt: float) -> void:
	for i in range(bits.size() - 1, -1, -1):
		var p = bits[i]
		p.life -= dt
		if p.life <= 0:
			p.node.queue_free()
			bits.remove_at(i)
			continue
		if p.gravity:
			p.velocity.y -= 13.0 * dt
		p.node.position += p.velocity * dt
		p.node.scale = Vector3.ONE * maxf(0.01, p.life / p.max)
