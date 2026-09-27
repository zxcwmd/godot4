class_name Puppet
extends Node3D
## Articulated character: pivots + meshes, posed every physics frame.

const PLAYER := -1
const RUSH := 0
const GUNNER := 1
const BRUTE := 2
const HEART := 3

var kind := 0
var tint := Color.WHITE
var joints := {}
var extras: Array = []
var core: MeshInstance3D
var hand: Node3D
var clock := 0.0
var gait := 0.0
var attack_t := 0.0
var flinch := 0.0
var rest_hunch := 0.0
var scale_mul := 1.0

func strike() -> void:
	attack_t = 1.0

func flinch_hit() -> void:
	flinch = 1.0

func build(role: int, accent: Color) -> void:
	kind = role
	tint = accent
	scale_mul = 1.35 if role == BRUTE else (0.96 if role == RUSH else 1.0)
	rest_hunch = 0.45 if role == RUSH else (0.12 if role == BRUTE else 0.08)
	if role == HEART:
		_build_heart()
		return
	_build_humanoid(role == PLAYER)

func _pivot(parent: Node3D, id: String, at: Vector3) -> Node3D:
	var node = Node3D.new()
	parent.add_child(node)
	node.position = at
	joints[id] = node
	return node

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	return Forge.box(parent, at, size, color, glow)

func _cyl(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	return Forge.cyl(parent, at, radius, height, color, glow)

func _build_humanoid(is_player: bool) -> void:
	var s = scale_mul
	var plate = Forge.STONE if not is_player else Forge.STONE
	var bone = Forge.BONE
	var metal = Forge.BRONZE
	var cloth = Forge.BLOOD if kind == RUSH else (Forge.BRONZE if kind == BRUTE else Forge.WAX)
	if is_player:
		cloth = Forge.BRONZE
	var hip = _pivot(self, "hip", Vector3(0, 0.92 * s, 0))
	_box(hip, Vector3(0, -0.04, 0), Vector3(0.38 * s, 0.16 * s, 0.24 * s), metal)
	_box(hip, Vector3(0, 0.02, 0.02), Vector3(0.42 * s, 0.06 * s, 0.28 * s), tint, 0.5)
	# Tassets / hanging plates.
	for x in [-1, 1]:
		_box(hip, Vector3(x * 0.16 * s, -0.14 * s, 0.02), Vector3(0.14 * s, 0.22 * s, 0.08 * s), plate)
	var spine = _pivot(hip, "spine", Vector3(0, 0.08 * s, 0.02 * s))
	_cyl(spine, Vector3(0, 0.16 * s, 0), 0.07 * s, 0.28 * s, bone)
	for i in range(4):
		_box(spine, Vector3(0, 0.04 * s + i * 0.07 * s, 0.04), Vector3(0.22 * s - i * 0.01, 0.045 * s, 0.08 * s), plate)
	var chest = _pivot(spine, "chest", Vector3(0, 0.32 * s, 0))
	_box(chest, Vector3(0, 0.08 * s, 0), Vector3(0.48 * s, 0.36 * s, 0.28 * s), plate)
	_box(chest, Vector3(0, 0.1 * s, 0.14 * s), Vector3(0.36 * s, 0.22 * s, 0.06 * s), bone)
	# Ribs.
	for i in range(4):
		_box(chest, Vector3(0, 0.18 * s - i * 0.07 * s, 0.12 * s), Vector3(0.4 * s, 0.025 * s, 0.04 * s), bone)
	_box(chest, Vector3(0, 0.02 * s, 0.15 * s), Vector3(0.12 * s, 0.1 * s, 0.04 * s), tint, 0.8)
	# Pauldrons.
	for x in [-1.0, 1.0]:
		var pad = _box(chest, Vector3(x * 0.28 * s, 0.18 * s, 0), Vector3(0.2 * s, 0.14 * s, 0.24 * s), metal)
		extras.append(pad)
		_box(chest, Vector3(x * 0.32 * s, 0.22 * s, 0), Vector3(0.08 * s, 0.08 * s, 0.08 * s), tint, 0.4)
	# Cape / shroud, three hanging segments.
	var cape = _pivot(chest, "cape", Vector3(0, 0.12 * s, 0.14 * s))
	for i in range(3):
		var seg = _pivot(cape if i == 0 else joints["cape" + str(i - 1)], "cape" + str(i), Vector3(0, -0.02 if i == 0 else -0.22 * s, 0.02))
		_box(seg, Vector3(0, -0.12 * s, 0), Vector3(0.46 * s - i * 0.04, 0.24 * s, 0.05 * s), cloth)
	var neck = _pivot(chest, "neck", Vector3(0, 0.28 * s, 0))
	_cyl(neck, Vector3(0, 0.07 * s, 0), 0.07 * s, 0.14 * s, bone)
	var head = _pivot(neck, "head", Vector3(0, 0.16 * s, 0))
	_cyl(head, Vector3(0, 0.08 * s, 0), 0.16 * s, 0.22 * s, bone)
	_box(head, Vector3(0, 0.04 * s, -0.12 * s), Vector3(0.22 * s, 0.12 * s, 0.1 * s), plate)
	# Mask / eye slits.
	core = _box(head, Vector3(0, 0.08 * s, -0.16 * s), Vector3(0.18 * s, 0.04 * s, 0.03 * s), tint, 1.0)
	_box(head, Vector3(-0.06 * s, 0.08 * s, -0.16 * s), Vector3(0.05 * s, 0.025 * s, 0.04 * s), Color.BLACK)
	_box(head, Vector3(0.06 * s, 0.08 * s, -0.16 * s), Vector3(0.05 * s, 0.025 * s, 0.04 * s), Color.BLACK)
	_box(head, Vector3(0, -0.02 * s, -0.14 * s), Vector3(0.12 * s, 0.04 * s, 0.08 * s), metal)
	# Crest / horns.
	if is_player or kind == BRUTE:
		_box(head, Vector3(0, 0.22 * s, 0.02), Vector3(0.06 * s, 0.16 * s, 0.18 * s), tint, 0.5)
	if kind == RUSH:
		for x in [-1, 1]:
			_box(head, Vector3(x * 0.12 * s, 0.18 * s, 0.02), Vector3(0.05 * s, 0.18 * s, 0.05 * s), tint)
	if kind == GUNNER:
		_cyl(head, Vector3(0, 0.16 * s, 0.08 * s), 0.08 * s, 0.12 * s, metal)
	# Jaw.
	var jaw = _pivot(head, "jaw", Vector3(0, -0.04 * s, -0.04 * s))
	_box(jaw, Vector3(0, -0.04 * s, -0.08 * s), Vector3(0.16 * s, 0.05 * s, 0.12 * s), bone)
	# Arms.
	for side in [-1.0, 1.0]:
		var prefix = "l" if side < 0 else "r"
		var sh = _pivot(chest, prefix + "_sh", Vector3(side * 0.3 * s, 0.16 * s, 0))
		_cyl(sh, Vector3(0, 0, 0), 0.08 * s, 0.1 * s, metal)
		var up = _pivot(sh, prefix + "_up", Vector3(0, 0, 0))
		_cyl(up, Vector3(0, -0.16 * s, 0), 0.07 * s, 0.3 * s, plate)
		_box(up, Vector3(0, -0.16 * s, 0.05 * s), Vector3(0.08 * s, 0.22 * s, 0.04 * s), bone)
		var lo = _pivot(up, prefix + "_lo", Vector3(0, -0.32 * s, 0))
		_cyl(lo, Vector3(0, -0.14 * s, 0), 0.055 * s, 0.26 * s, bone)
		for i in range(3):
			_box(lo, Vector3(0, -0.06 * s - i * 0.06 * s, 0.045 * s), Vector3(0.07 * s, 0.03 * s, 0.02 * s), cloth)
		var hn = _pivot(lo, prefix + "_hand", Vector3(0, -0.28 * s, 0))
		_box(hn, Vector3(0, -0.04 * s, 0), Vector3(0.09 * s, 0.1 * s, 0.08 * s), metal)
		for f in range(3):
			_box(hn, Vector3((f - 1) * 0.028 * s, -0.12 * s, -0.02 * s), Vector3(0.022 * s, 0.1 * s, 0.024 * s), bone)
		if kind == RUSH:
			_box(hn, Vector3(0, -0.16 * s, -0.04 * s), Vector3(0.04 * s, 0.14 * s, 0.03 * s), tint, 0.4)
		if side > 0:
			hand = hn
		if kind == GUNNER and side > 0:
			var gun = _cyl(hn, Vector3(0, -0.04 * s, -0.28 * s), 0.04 * s, 0.5 * s, Forge.WAX, 0.5)
			gun.rotation_degrees.x = 90
	# Legs.
	for side in [-1.0, 1.0]:
		var prefix = "l" if side < 0 else "r"
		var th = _pivot(hip, prefix + "_th", Vector3(side * 0.12 * s, -0.06 * s, 0))
		_cyl(th, Vector3(0, -0.18 * s, 0), 0.08 * s, 0.34 * s, plate)
		_box(th, Vector3(0, -0.18 * s, 0.05 * s), Vector3(0.1 * s, 0.28 * s, 0.05 * s), metal)
		var shn = _pivot(th, prefix + "_shn", Vector3(0, -0.36 * s, 0))
		_cyl(shn, Vector3(0, -0.16 * s, 0), 0.06 * s, 0.3 * s, bone)
		for i in range(4):
			_box(shn, Vector3(0, -0.06 * s - i * 0.06 * s, 0.05 * s), Vector3(0.08 * s, 0.03 * s, 0.02 * s), cloth)
		var ft = _pivot(shn, prefix + "_ft", Vector3(0, -0.32 * s, 0))
		_box(ft, Vector3(0, -0.03 * s, -0.08 * s), Vector3(0.11 * s, 0.07 * s, 0.24 * s), metal)
		_box(ft, Vector3(0, -0.01 * s, -0.16 * s), Vector3(0.08 * s, 0.04 * s, 0.08 * s), tint, 0.3)
	if hand == null:
		hand = _pivot(self, "hand", Vector3(0.35 * s, 1.1 * s, -0.2 * s))

func _build_heart() -> void:
	var root = _pivot(self, "hip", Vector3(0, 1.6, 0))
	core = Forge.orb(root, Vector3(0, 0.8, 0), 1.15, tint, 1.2)
	joints["core"] = core
	for i in range(8):
		var a = float(i) / 8.0 * TAU
		var rib = _box(root, Vector3(cos(a) * 1.35, 0.75, sin(a) * 1.35), Vector3(0.16, 2.2, 0.1), Forge.BONE)
		rib.rotation = Vector3(0.25, -a, 0)
		extras.append(rib)
	for i in range(5):
		var ring = Forge.ring(root, Vector3(0, 0.8, 0), 1.6 + i * 0.18, tint if i % 2 == 0 else Forge.AMBER, 0.07)
		ring.rotation = Vector3(i * 0.5, 0, i * 0.35)
		extras.append(ring)
		joints["ring" + str(i)] = ring
	for i in range(4):
		var t = _pivot(root, "tend" + str(i), Vector3(cos(i * TAU / 4) * 0.8, -0.2, sin(i * TAU / 4) * 0.8))
		_cyl(t, Vector3(0, -0.5, 0), 0.12, 1.1, Forge.BRONZE, 0.0)
		_box(t, Vector3(0, -1.1, 0), Vector3(0.18, 0.3, 0.18), tint, 0.6)
	_cyl(root, Vector3(0, -0.4, 0), 0.7, 1.4, Forge.STONE)
	hand = _pivot(self, "hand", Vector3(1.4, 2.2, 0))

func animate(dt: float, velocity: Vector3, on_floor: bool, attacking: bool, charging: float, frozen: bool, lifted: bool) -> void:
	clock += dt
	attack_t = maxf(0, attack_t - dt * 2.4)
	flinch = maxf(0, flinch - dt * 4.0)
	if attacking and attack_t <= 0.1:
		attack_t = 1.0
	var planar = Vector2(velocity.x, velocity.z).length()
	var frozen_mul = 0.25 if frozen else 1.0
	gait += dt * (0.8 + planar * 0.55) * frozen_mul
	if kind == HEART:
		_anim_heart(dt, charging)
		return
	if not joints.has("hip"):
		return
	var breathe = sin(clock * 2.2) * 0.02
	var bob = absf(sin(gait)) * minf(planar, 8.0) * 0.012
	joints.hip.position.y = 0.92 * scale_mul + breathe + (0.08 if lifted else 0.0) - (0.0 if on_floor else 0.04) + bob
	joints.hip.rotation.z = sin(gait) * minf(planar, 7.0) * 0.012 + flinch * 0.15
	joints.hip.rotation.x = rest_hunch + (0.25 if not on_floor else 0.0)
	if joints.has("spine"):
		joints.spine.rotation.x = rest_hunch * 0.5 + sin(clock * 2.2) * 0.03 - attack_t * 0.15
		joints.spine.rotation.y = sin(gait) * 0.08 * minf(planar, 6.0) * 0.1
	if joints.has("chest"):
		joints.chest.rotation.x = breathe * 2.0 + charging * 0.4
		joints.chest.scale = Vector3.ONE * (1.0 + breathe * 0.4)
	if joints.has("head"):
		joints.head.rotation.x = -rest_hunch * 0.4 + sin(clock * 1.4) * 0.05 + flinch * -0.3
		joints.head.rotation.y = sin(clock * 0.7) * 0.12
	if joints.has("jaw"):
		joints.jaw.rotation.x = absf(sin(clock * (3.0 if kind == RUSH else 1.2))) * 0.12 + attack_t * 0.25
	_leg("l", gait, planar, on_floor, lifted)
	_leg("r", gait + PI, planar, on_floor, lifted)
	_arm("l", gait + PI, planar, false, charging)
	_arm("r", gait, planar, true, charging)
	if joints.has("cape0"):
		for i in range(3):
			var id = "cape" + str(i)
			if joints.has(id):
				joints[id].rotation.x = 0.15 + sin(clock * 2.0 + i) * 0.12 + minf(planar, 8.0) * 0.02
				joints[id].rotation.z = sin(clock * 1.6 + i * 0.7) * 0.06

func _leg(side: String, phase: float, planar: float, on_floor: bool, lifted: bool) -> void:
	if not joints.has(side + "_th"):
		return
	var swing = sin(phase) * minf(planar * 0.08, 0.75)
	if not on_floor or lifted:
		swing = 0.45 if side == "l" else -0.2
	joints[side + "_th"].rotation.x = swing
	var shin = maxf(0.0, -sin(phase)) * minf(planar * 0.1, 0.9)
	if not on_floor:
		shin = 0.7
	joints[side + "_shn"].rotation.x = shin
	if joints.has(side + "_ft"):
		joints[side + "_ft"].rotation.x = -swing * 0.4 - shin * 0.3 + (0.2 if not on_floor else 0.0)

func _arm(side: String, phase: float, planar: float, striking: bool, charging: float) -> void:
	if not joints.has(side + "_sh"):
		return
	var walk = sin(phase) * minf(planar * 0.06, 0.55)
	var strike = 0.0
	var fold = 0.0
	if striking:
		strike = -sin((1.0 - attack_t) * PI) * 1.4
		fold = attack_t * 0.8
	if charging > 0:
		strike = -0.9
		fold = 1.1
	joints[side + "_sh"].rotation.z = (0.12 if side == "r" else -0.12) + flinch * (0.2 if side == "r" else -0.2)
	joints[side + "_up"].rotation.x = walk + strike - 0.15
	joints[side + "_lo"].rotation.x = -absf(walk) * 0.4 - 0.2 + fold
	if joints.has(side + "_hand"):
		joints[side + "_hand"].rotation.x = strike * 0.3

func _anim_heart(dt: float, charging: float) -> void:
	var beat = 1.0 + sin(clock * 3.4) * 0.08 + charging * 0.2
	if joints.has("hip"):
		joints.hip.scale = Vector3.ONE * beat
	if is_instance_valid(core):
		core.scale = Vector3.ONE * (1.0 + sin(clock * 6.8) * 0.12)
	for i in range(5):
		var id = "ring" + str(i)
		if joints.has(id):
			joints[id].rotate_x(dt * (0.4 + i * 0.15))
			joints[id].rotate_y(dt * 0.3)
	for i in range(4):
		var id = "tend" + str(i)
		if joints.has(id):
			joints[id].rotation.x = sin(clock * 2.0 + i) * 0.4
			joints[id].rotation.z = cos(clock * 1.6 + i) * 0.3
