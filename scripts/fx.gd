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

func clear_all() -> void:
	for bit in bits:
		if is_instance_valid(bit.node):
			bit.node.queue_free()
	bits.clear()

func damage_number(pos: Vector3, amount: float, color: Color) -> void:
	if bits.size() >= 450:
		return
	var node = Label3D.new()
	node.text = str(roundi(amount))
	node.font_size = 48
	node.pixel_size = 0.012
	node.modulate = color
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.outline_size = 7
	add_child(node)
	node.position = pos + Vector3(randf_range(-0.25, 0.25), 0, 0)
	bits.append({"node": node, "velocity": Vector3.UP * 1.7, "life": 0.65, "max": 0.65, "gravity": false})

func dismantle(visual: Node3D, push: Vector3) -> void:
	if not enabled:
		return
	for part in visual.get_children():
		if not part is MeshInstance3D or not part.visible or bits.size() >= 450:
			continue
		var chunk = MeshInstance3D.new()
		chunk.mesh = part.mesh
		chunk.material_override = part.material_override
		add_child(chunk)
		chunk.global_transform = part.global_transform
		var velocity = Vector3(randf_range(-5, 5), randf_range(3, 7), randf_range(-5, 5)) + push * 0.4
		bits.append({"node": chunk, "velocity": velocity, "life": 1.15, "max": 1.15, "gravity": true, "spin": Vector3(randf(), randf(), randf()) * 14})

func _process(dt: float) -> void:
	if get_parent().state not in ["RUN", "DROP"]:
		return
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
		if p.has("spin"):
			p.node.rotation += p.spin * dt
		p.node.scale = Vector3.ONE * maxf(0.01, p.life / p.max)
