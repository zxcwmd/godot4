class_name WeaponRig
extends Node3D
## Procedural keyframed view/world model. Animation never alters aim or movement.
const Arsenal = preload("res://scripts/arsenal.gd")
var game: Node3D
var first_person := true
var weapon := "katana"
var hands: Array[Node3D] = []
var moving_parts: Array[Dictionary] = []
var muzzle: MeshInstance3D
var age := 0.0
var attack_age := 10.0
var attack_length := 0.4
var equip_age := 1.0
var invoke_age := 1.0
var hit_pause := 0.0
var sequence := 0
var sway := Vector2.ZERO
var active := false
var primary: Node3D
const STEEL = Color("b8b9a5")
const BODY = Color("697167")
const RUBBER = Color("303a30")

func configure(id: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	hands.clear()
	moving_parts.clear()
	muzzle = null
	weapon = id
	attack_age = 10
	active = false
	hit_pause = 0
	sequence = 0
	equip_age = 0
	invoke_age = 1
	primary = Node3D.new()
	add_child(primary)
	hands.append(primary)
	var kind: String = Arsenal.WEAPONS[id].kind
	if id in ["sickles", "saws"]:
		var other = Node3D.new()
		add_child(other)
		hands.append(other)
	for i in hands.size():
		var hand = hands[i]
		var forearm = game.art.cylinder(hand, Vector3(0, -0.12, 0.34), 0.115, 0.45, Color("59604c"), 0.1, "cloth", 6)
		forearm.rotation.x = PI / 2
		game.art.orb(hand, Vector3(0, -0.10, 0.09), Vector3(0.20, 0.23, 0.23), Color("b7916c"))
		box(hand, Vector3(0, -0.08, 0.22), Vector3(0.23, 0.12, 0.08), Color("6b715b"))
		for finger in 4:
			game.art.orb(hand, Vector3(-0.067 + finger * 0.045, -0.045, -0.014), Vector3(0.04, 0.105, 0.055), Color("b7916c"))
		match id:
			"katana", "rapier":
				box(hand, Vector3(0, 0, 0.02), Vector3(0.10, 0.10, 0.32), RUBBER)
				for j in 5:
					box(hand, Vector3(0, 0.058, 0.12 - j * 0.055), Vector3(0.105, 0.016, 0.026), Arsenal.LIME)
				var length = 1.65 if id == "rapier" else 1.30
				game.art.blade(hand, Vector3(0, 0, -0.15), length, 0.035 if id == "rapier" else 0.105, STEEL, 0.06 if id == "katana" else 0.0)
				box(hand, Vector3(0.05, 0.004, -0.78), Vector3(0.013, 0.035, 1.27), Arsenal.LIME)
				box(hand, Vector3(0, 0, -0.14), Vector3(0.37, 0.065, 0.07), Arsenal.LIME)
				if id == "rapier":
					cylinder(hand, Vector3(0, 0, -0.10), 0.17, 0.05, STEEL)
			"sickles":
				box(hand, Vector3(0, 0, -0.16), Vector3(0.10, 0.09, 0.55), BODY)
				arc_blade(hand, Vector3(0, 0, -0.56), 0.38, 0.0, PI * 1.05, 8)
			"scythe":
				box(hand, Vector3(0, 0, -0.40), Vector3(0.09, 0.09, 1.85), RUBBER)
				box(hand, Vector3(0, 0.055, -0.60), Vector3(0.04, 0.02, 1.35), Arsenal.VIOLET)
				arc_blade(hand, Vector3(-0.18, 0, -1.29), 0.8, -0.25, 1.65, 10)
			"saws":
				box(hand, Vector3(0, 0, -0.30), Vector3(0.26, 0.23, 0.75), BODY)
				box(hand, Vector3(0, 0.03, -0.60), Vector3(0.17, 0.08, 0.92), STEEL)
				for j in 16:
					var tooth = box(hand, Vector3.ZERO, Vector3(0.07, 0.065, 0.07), Arsenal.LIME)
					moving_parts.append({"node": tooth, "kind": "tooth", "phase": j / 16.0})
			"revolver", "rail", "scatter":
				box(hand, Vector3(0, 0, -0.20), Vector3(0.23, 0.23, 0.5), BODY)
				var grip = box(hand, Vector3(0, -0.22, -0.06), Vector3(0.17, 0.32, 0.15), RUBBER)
				grip.rotation.x = -0.25
				for bolt in [-1, 1]:
					game.art.orb(hand, Vector3(bolt * 0.125, 0.025, -0.12), Vector3(0.035, 0.05, 0.06), STEEL, "metal")
				for slot in 3:
					box(hand, Vector3(0.12, 0.02, -0.25 - slot * 0.065), Vector3(0.012, 0.10, 0.025), RUBBER)
				var length = 1.1 if id == "rail" else 0.66
				cylinder(hand, Vector3(0, 0.055, -0.38 - length / 2), 0.065, length, STEEL)
				if id == "revolver":
					var chamber = cylinder(hand, Vector3(0, 0.055, -0.22), 0.14, 0.22, STEEL)
					moving_parts.append({"node": chamber, "kind": "chamber"})
					for j in 6:
						var a = j * TAU / 6
						box(chamber, Vector3(cos(a) * 0.13, 0, sin(a) * 0.13), Vector3(0.055, 0.2, 0.055), RUBBER)
				elif id == "scatter":
					cylinder(hand, Vector3(0.14, 0.055, -0.71), 0.07, 0.66, STEEL)
					var pump = box(hand, Vector3(0.06, -0.10, -0.60), Vector3(0.30, 0.12, 0.22), Arsenal.ORANGE)
					moving_parts.append({"node": pump, "kind": "pump"})
				else:
					for j in 6:
						cylinder(hand, Vector3(0, 0.055, -0.50 - j * 0.15), 0.11, 0.05, Arsenal.CYAN)
				box(hand, Vector3(0, 0.17, -0.39), Vector3(0.055, 0.04, 0.25), Arsenal.ORANGE)
				muzzle = box(hand, Vector3(0, 0.055, -0.42 - length), Vector3(0.2, 0.2, 0.25), Arsenal.ORANGE)
				muzzle.visible = false
			"discs":
				var disc = cylinder(hand, Vector3(0, 0.06, -0.24), 0.28, 0.05, STEEL)
				disc.rotation = Vector3.ZERO
				moving_parts.append({"node": disc, "kind": "disc"})
				for j in 4:
					var tooth = box(disc, Vector3(0, 0, 0), Vector3(0.62, 0.025, 0.055), Arsenal.LIME)
					tooth.rotation.y = j * PI / 4
			_:
				if kind == "magic":
					for j in 3:
						var orb = game.art.orb(hand, Vector3.ZERO, Vector3.ONE * 0.17, [Arsenal.ORANGE, Arsenal.CYAN, Arsenal.VIOLET][j], "metal", true)
						moving_parts.append({"node": orb, "kind": "orb", "phase": j * TAU / 3})
	for part in find_children("*", "GeometryInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if first_person else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	step(0, 0, Vector2.ZERO, false)

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return game.art.box(parent, pos, size, color, "cloth" if color == RUBBER else "metal", color in [Arsenal.LIME, Arsenal.ORANGE, Arsenal.VIOLET, Arsenal.CYAN])

func cylinder(parent: Node3D, pos: Vector3, radius: float, length: float, color: Color) -> MeshInstance3D:
	var n = box(parent, pos, Vector3.ONE, color)
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	n.mesh = mesh
	n.rotation.x = PI / 2
	return n

func arc_blade(parent: Node3D, center: Vector3, radius: float, start: float, end: float, count: int) -> void:
	for j in count:
		var a = lerpf(start, end, float(j) / count)
		var b = lerpf(start, end, float(j + 1) / count)
		var p = center + Vector3(cos(a), 0, -sin(a)) * radius
		var q = center + Vector3(cos(b), 0, -sin(b)) * radius
		var blade = box(parent, (p + q) / 2, Vector3(lerpf(0.13, 0.025, float(j) / count), 0.025, p.distance_to(q) + 0.03), Arsenal.LIME)
		blade.rotation.y = atan2((q - p).x, (q - p).z)

func strike(duration: float) -> void:
	sequence += 1
	attack_age = 0
	attack_length = maxf(0.07, duration)
	active = true

func impact() -> void:
	if active and Arsenal.WEAPONS[weapon].kind == "melee" and weapon != "saws":
		hit_pause = 0.035

func invoke() -> void:
	invoke_age = 0

func step(dt: float, move_speed: float, mouse_sway: Vector2, reduced_motion: bool) -> void:
	age += dt
	equip_age = minf(1, equip_age + dt * 5)
	invoke_age = minf(1, invoke_age + dt * 2.5)
	if hit_pause > 0:
		hit_pause = maxf(0, hit_pause - dt)
	else:
		attack_age += dt
	active = attack_age < attack_length
	var t = clampf(attack_age / attack_length, 0, 1)
	# Snap into the follow-through in the first 20%, then ease back to rest.
	var sweep = sin(clampf(t / 0.22, 0, 1) * PI / 2) if t < 0.22 else pow(1 - (t - 0.22) / 0.78, 2)
	var kick = exp(-t * 9) if active else 0.0
	if not active:
		sweep = 0
	var kind: String = Arsenal.WEAPONS[weapon].kind
	sway = sway.lerp(mouse_sway.limit_length(20) * 0.0015, minf(1, dt * 14))
	var walk = Vector3(sin(age * 11), abs(cos(age * 11)) - 0.5, 0) * minf(move_speed, 18) * 0.0018
	position = Vector3(0.42, -0.38, -0.65) if first_person else Vector3(0.28, 1.10, -0.22)
	if not reduced_motion:
		position += walk + Vector3(-sway.x, sway.y, 0)
	position.y -= pow(1 - equip_age, 2) * 0.7
	var rest = Vector3(0.65, -0.08, -0.18) if first_person and kind == "melee" else Vector3.ZERO
	if weapon == "rapier":
		rest = Vector3(0.08, -0.14, 0)
	rotation = rest
	var direction = 1.0 if sequence % 2 else -1.0
	match weapon:
		"katana":
			rotation += Vector3(-0.35, direction * 1.2, direction * -1.35) * sweep
			position += Vector3(-0.28 * direction, 0.12, -0.18) * sweep
		"rapier":
			position += Vector3(-0.24, 0.08, -0.65) * sweep
			rotation.x -= sweep * 0.08
		"sickles": rotation += Vector3(-0.3, direction * 0.65, direction * -0.9) * sweep
		"scythe":
			rotation += Vector3(-0.8, -1.7, -1.2) * sweep
			position.x -= sweep * 0.5
		"saws":
			position += Vector3(sin(age * 130) * 0.01, cos(age * 160) * 0.012, -sweep * 0.12)
		"discs":
			rotation += Vector3(0.15, -1.25, 0.8) * sweep
			position += Vector3(-0.35, 0.08, -0.2) * sweep
		_:
			if kind == "magic":
				position.z -= sweep * 0.26
				rotation.z += sin(invoke_age * PI) * 1.1
			else:
				var force = {"revolver": 1.0, "rail": 1.4, "scatter": 1.6}.get(weapon, 1.0)
				rotation.x += kick * 0.35 * force
				rotation.z -= kick * 0.09 * direction
				position.z += kick * 0.16 * force
	for i in hands.size():
		hands[i].position = Vector3(-0.75 if i else 0, 0, 0) if first_person else Vector3(-0.55 if i else 0, 0, 0)
		hands[i].rotation = Vector3.ZERO
		if weapon == "sickles":
			hands[i].rotation.z = sweep * (1.2 if i == sequence % 2 else -0.3)
	if muzzle:
		muzzle.visible = active and attack_age < 0.045
		muzzle.scale = Vector3.ONE * (1 + kick * 0.8)
	for part in moving_parts:
		var n: Node3D = part.node
		match part.kind:
			"tooth":
				var phase = fposmod(part.phase + age * (6 if active else 1.5), 1) * TAU
				n.position = Vector3(cos(phase) * 0.13, 0.035, -0.6 + sin(phase) * 0.48)
			"chamber": n.rotation.y = sequence * TAU / 6 - kick * 0.8
			"pump": n.position.z = -0.6 + sin(t * PI) * 0.22
			"disc":
				n.rotation.y = age * 12
				n.visible = not active or t > 0.55
			"orb":
				var a: float = part.phase + age * 2 + sweep * 2
				var radius = 0.22 + sin(invoke_age * PI) * 0.18
				n.position = Vector3(cos(a) * radius, 0.16 + sin(a) * radius, -0.28 - sweep * 0.3)
				n.rotation = Vector3(age, a, age * 0.7)
				n.scale = Vector3.ONE * (1 + sweep * 0.7)
