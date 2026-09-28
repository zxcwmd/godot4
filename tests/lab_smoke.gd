extends SceneTree
## godot --headless --path . --script tests/lab_smoke.gd
const Arsenal = preload("res://scripts/arsenal.gd")
var game: Node3D
var checks := 0
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game.player._unhandled_input(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	var record: float = game.best
	game.start_sandbox()
	await frames(30)
	check(game.sandbox and game.state == "RUN", "Sandbox entered directly from hub")
	check(game.lab.built and game.lab.visible, "Separate three-zone level built")
	check(game.player.is_on_floor(), "Firing range has a valid floor")
	check(game.enemies.size() == 3, "Three training targets, no automatic waves")
	check(game.elapsed == 0, "Survival timer does not run")
	check(game.player.global_position.x > 160, "Sandbox physically isolated from main arena")
	var dummy = game.enemies[0]
	dummy.take_damage(75)
	dummy.take_damage(25)
	game.lab.tick(0.016)
	check(is_equal_approx(game.lab.total_damage, 100) and is_equal_approx(game.lab.dps, 20), "Fixed five-second rolling DPS calculation")
	check(game.kills == 0 and game.xp == 0, "Targets award no kills or experience")
	check(dummy.health == 900, "Dummy records damage")
	await frames(130)
	check(dummy.health == 1000, "Dummy recovers after two seconds without hits")
	game.lab.tick(5.1)
	check(game.lab.dps == 0, "DPS window expires")
	for id in Arsenal.WEAPONS:
		game.lab.clear_combat()
		game.lab.select_weapon(id)
		game.player.position = dummy.position + Vector3(0, 0, 2.5)
		game.player.velocity = Vector3.ZERO
		game.player.rotation = Vector3.ZERO
		game.player.pitch = 0
		game.player.pivot.rotation.x = 0
		game.player.weapon_model.step(1, 0, Vector2.ZERO, false)
		var rest: Transform3D = game.player.weapon_model.transform
		game.player.attack()
		game.player.weapon_model.step(0.025, 0, Vector2.ZERO, false)
		check(game.player.weapon_model.active and not game.player.weapon_model.transform.is_equal_approx(rest), "Distinct animated pose: " + id)
		await frames(24)
		check(game.lab.total_damage > 0, "Animated weapon really damages target: " + id)
		check(game.player.camera.rotation == Vector3.ZERO, "Animation does not alter aim: " + id)
	check(game.player.inventory.size() <= 9, "Full arsenal access respects hotbar capacity")
	# Physical keys work independently of text layout, even with a non-mage class.
	game.lab.select_weapon("katana")
	game.class_index = 0
	key(KEY_Q)
	key(KEY_E)
	key(KEY_R)
	key(KEY_F)
	check(game.player.spell == "EQR" and Arsenal.WEAPONS[game.player.weapon].kind == "magic", "Sandbox permits Q/E/R/F magic for any class")
	game.lab.select_weapon("katana")
	game.lab.reset_stats()
	game.player.attack()
	game.pause_run()
	var animation_time: float = game.player.weapon_model.attack_age
	await frames(12)
	check(game.player.weapon_model.attack_age == animation_time and game.lab.total_damage == 0, "Pause freezes animation and pending melee hit")
	game.resume_run()
	await frames(12)
	check(game.lab.total_damage > 0, "Paused melee resumes and hits once")
	game.player.attack()
	game.lab.select_weapon("revolver")
	check(game.player.pending_weapon.is_empty(), "Switching weapons cancels a pending swing")
	game.set_perspective(true)
	await frames(2)
	check(game.top_down and game.player.model.visible and not game.player.weapon_model.visible, "World weapon shown in overhead mode")
	check(game.player.world_weapon.weapon == "revolver", "World model matches equipped weapon")
	game.set_perspective(false)
	check(game.player.camera.current, "Return to first person")
	game.open_lab()
	check(game.state == "LAB" and game.hud.ui.get_child_count() >= 40, "Interactive lab control panel built")
	game.set_perspective(true)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Camera toggle in panel does not capture cursor")
	game.lab.spawn_count = 10
	for i in 5:
		game.lab.spawn_kind(i % 3)
	check(game.enemies.size() == 33, "Manual spawning capped at 30 plus three targets")
	game.lab.clear_combat()
	check(game.enemies.size() == 3, "Clear combat preserves target dummies")
	game.lab.reset_targets()
	check(game.enemies.size() == 3, "Reset targets creates no duplicates")
	game.lab.reset_build()
	game.upgrade(1)
	game.upgrade(4)
	check(game.points == 8 and game.player.extra_jump, "Sandbox upgrades are functional")
	game.lab.reset_build()
	check(game.points == 10 and not game.player.extra_jump and game.player.damage_mult == 1, "Reset build restores base stats and ten points")
	game.resume_run()
	var hp: float = game.player.health
	game.player.invulnerable = 0
	game.player.hurt(10)
	check(game.player.health == hp, "Optional invulnerability blocks damage")
	game.lab.god_mode = false
	game.player.hurt(10)
	check(game.player.health == hp - 10, "Invulnerability can be disabled")
	game.player.invulnerable = 0
	game.player.hurt(99999)
	check(game.state == "LAB" and game.player.health == game.player.max_health, "Sandbox death safely resets and opens panel")
	check(game.best == record and game.elapsed == 0, "Sandbox cannot overwrite survival record")
	game.resume_run()
	game.lab.teleport(2)
	game.player.position = game.lab.ZONES[2] + Vector3(0, -4, 0)
	game.lab.tick(0.02)
	check(game.player.position.y > 0 and game.player.position.x > 200, "Movement pit respawns safely inside movement zone")
	# Physically walk both connecting corridors rather than teleporting between zones.
	game.set_perspective(false)
	game.player.position = game.lab.ZONES[0] + Vector3.UP * 0.1
	game.player.rotation = Vector3.ZERO
	Engine.time_scale = 3
	for i in [1, 2]:
		var target: Vector3 = game.lab.ZONES[i]
		var action = "back" if i == 1 else "right"
		Input.action_press(action)
		var reached := false
		for frame in 160:
			await physics_frame
			# Enter the left landing of the movement zone, before the jump gap.
			if (game.player.position.z > -1 if i == 1 else game.player.position.x > 208):
				reached = true
				break
		Input.action_release(action)
		game.player.velocity = Vector3.ZERO
		check(reached, "Physical corridor traversal to zone " + str(i))
	Engine.time_scale = 1
	var geometry_count: int = game.lab.get_child_count()
	game.return_to_hub()
	game.start_sandbox()
	check(game.lab.get_child_count() == geometry_count, "Repeated sandbox entry does not duplicate geometry")
	check(game.lab.total_damage == 0 and game.lab.god_mode, "Fresh sandbox resets telemetry and safety")
	game.start_run()
	check(not game.sandbox and not game.lab.visible and game.state == "DROP", "Normal run remains isolated")
	check(game.player.inventory.size() == 1 and game.points == 0 and game.enemies.is_empty(), "Sandbox inventory and enemies never leak into survival")
	print("RIFT LAB TESTS: ", checks, " checks / ", "FAILED" if failed else "ALL PASSED")
	game.queue_free()
	await frames(5)
	quit(1 if failed else 0)
