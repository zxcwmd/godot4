extends SceneTree
## Run after importing: godot --headless --path . --script tests/smoke.gd
## This is a real scene/physics integration test, not a second implementation.
var failures = 0
var game

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func action(name: String) -> void:
	var event = InputEventAction.new()
	event.action = name
	event.pressed = true
	game.player._unhandled_input(event)

func settle(frames: int = 3) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame

func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		if not enemy.dead: enemy.take_damage(10000, Vector3.ZERO, "", "SMOKE")
	await process_frame

func run() -> void:
	var scene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	game.save_records = false
	root.add_child(game)
	current_scene = game
	await settle()
	check(game.phase == "hub" and game.hud.menu == "hub", "boot in class-selection hub")
	check(game.world.seals.size() == 3 and game.world.gates.size() == 3, "three seals and real gates")
	check(game.player.WEAPONS[0].size() == 5, "five melee weapons")
	check(game.player.WEAPONS[1].size() == 4, "four ranged weapons")
	check(game.player.SPELLS.size() == 10, "ten unordered elemental combinations")
	for id in range(3):
		game.hud.select_class(id)
		check(game.player.class_id == id, "class selection %d" % id)
	game.hud.close_menu()
	await process_frame
	game.player.global_position = Vector3(-7, -6, 0)
	await settle()
	check(game.phase == "run" and game.spawned.has(0), "fall through hub pit enters arena")
	check(game.player.global_position.x > 0, "arena spawn replaces falling transform")
	game.player.global_position = Vector3(6, 0.05, 0)
	game.player.velocity = Vector3.ZERO
	await settle(5)
	Input.action_press("move_forward")
	await settle(12)
	Input.action_release("move_forward")
	check(game.player.global_position.x > 7.0, "W moves forward along the first-person view")
	Input.action_press("dash")
	await settle(2)
	Input.action_release("dash")
	check(game.player.dash_cooldown > 0 and game.player.invincible > 0, "dash starts cooldown and invulnerability")
	Input.action_press("jump")
	await settle(2)
	Input.action_release("jump")
	await settle(2)
	Input.action_press("jump")
	await settle(2)
	Input.action_release("jump")
	check(game.player.jumps == 2 and game.player.velocity.y > 0, "double jump works while airborne")
	game.player.global_position = Vector3(6, 0.1, 0)
	game.player.velocity = Vector3.ZERO
	game.player.dash_time = 0
	game.player.hp = 100
	game.player.invincible = 0
	game.player.hurt(17)
	check(game.player.hp == 83, "health damage")
	game.player.hurt(17)
	check(game.player.hp == 83, "invulnerability prevents repeated contact damage")
	game.player.hp = 100
	game.player.invincible = 1000
	# Invoke 3,1,2 -> sorted internal code 012. The cast is retained after changing spheres.
	for key in ["element_2", "element_0", "element_1", "invoke"]: action(key)
	check(game.player.invoked == "012", "Invoker-style order-independent synthesis")
	action("element_0")
	check(game.player.invoked == "012", "changing spheres does not change prepared spell")
	# Test every weapon/spell through its actual attack function.
	for id in range(3):
		game.player.set_class(id)
		for weapon in range(game.player.WEAPONS[id].size()):
			game.player.weapon = weapon
			game.player.build_weapon()
			for alt in [false, true]:
				game.player.energy = 100
				game.player.attack(alt)
				check(game.player.cooldown > 0, "attack class %d weapon %d alt=%s" % [id, weapon, alt])
	game.player.set_class(2)
	for code in game.player.SPELLS:
		game.player.invoked = code
		game.player.energy = 100
		game.player.attack(false)
		check(game.player.energy < 100, "spell consumes energy: " + code)
	await settle()
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	await process_frame
	# Straight shot in an unobstructed lane exercises physics queries and kill feedback.
	var victim = game.spawn_enemy(Vector3(12, 0, 0), 0, 0)
	victim.set_physics_process(false)
	await settle()
	var before = game.kills
	game.hitscan(Vector3(8, 1, 0), Vector3.RIGHT, 300, 7, Color.WHITE, "SMOKE", false)
	check(victim.dead and game.kills == before+1, "hitscan kills collision body and increments score")
	await process_frame
	# Every block traverses 3D -> 2D, then unlocks only after both waves die.
	for block in range(3):
		game.player.global_position = Vector3(block*130+7, 1, 0)
		await settle()
		check(not game.player.side_mode, "first-person sector %d" % (block*2))
		await clear_enemies()
		game.player.global_position = Vector3(block*130+70, 1, 0)
		await settle()
		check(game.player.side_mode, "side-on sector %d" % (block*2+1))
		check(absf(game.player.global_position.z) < 0.001, "side movement constrained to plane")
		game.player.global_position = Vector3(122+block*130, 1, 0)
		await settle()
		check(not game.collected[block], "seal remains locked while enemies are alive")
		if block == 0:
			game.player.global_position = Vector3(127, 0, 0)
			Input.action_press("move_right")
			await settle(12)
			Input.action_release("move_right")
			check(game.player.global_position.x < 128, "locked gate physically stops the player")
			game.player.global_position = Vector3(122, 0, 0)
			game.player.velocity = Vector3.ZERO
		await clear_enemies()
		await settle()
		check(game.collected[block], "cleared block awards seal %d" % block)
		check(not game.world.gates[block].visible, "seal gate opens %d" % block)
	check(game.seals == 3, "all three seals collected")
	game.player.global_position = Vector3(397, 1, 0)
	await settle()
	check(is_instance_valid(game.boss) and game.boss.kind == 3, "final boss spawned")
	# Exercise boss warning and bullet fan before ending the encounter.
	game.boss.attack_timer = 0
	await settle()
	game.boss.boss_cycle = 2
	game.boss.attack_timer = 0
	await settle()
	check(game.boss.charge > 0, "boss telegraphs jumpable shockwave")
	game.boss.take_damage(10000, Vector3.ZERO, "", "SMOKE")
	await settle()
	check(game.phase == "escape", "boss death starts timed extraction")
	check(not game.world.exit_gate.visible, "evacuation gate unlocks")
	game.player.global_position = Vector3(535, 0, 0)
	await settle()
	check(game.phase == "end" and game.won, "reaching exit wins the level")
	check(game.hud.menu == "end", "results screen opens")
	game.hud.close_menu()
	game.phase = "run"
	game.player.hp = 10
	game.player.invincible = 0
	game.player.hurt(25)
	check(game.phase == "end" and not game.won, "death has a distinct loss result")
	game.restart()
	await settle(5)
	game = current_scene
	check(is_instance_valid(game) and game.phase == "hub", "restart reloads a fresh playable hub")
	check(InputMap.action_get_events("attack").size() == 1, "restart does not duplicate input bindings")
	paused = false
	game.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	print("SMOKE RESULT: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
