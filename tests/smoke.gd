extends SceneTree
## Run: godot --headless --path . --script tests/smoke.gd
## Integration test: real scene, physics ramps, all weapons, all spells and run reset.

const Arsenal = preload("res://scripts/arsenal.gd")
const Enemy = preload("res://scripts/enemy.gd")
var game: Node3D
var checks := 0
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func wait_frames(count: int) -> void:
	for i in count:
		await physics_frame

func clear_enemies() -> void:
	for e in game.enemies:
		if is_instance_valid(e):
			e.queue_free()
	game.enemies.clear()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await wait_frames(3)
	check(game.state == "MENU", "Scene starts in hub")
	check(game.centers.size() == 9, "Nine connected sectors")
	check(game.hud.ui.get_child_count() == 10, "Class, weapon and start buttons exist")
	check(Arsenal.SPELLS.size() == 10, "All ten three-element combinations")
	check(Arsenal.spell_key("RQE") == "EQR", "Element order is irrelevant")
	game.start_run()
	check(game.state == "DROP", "Run starts with a real fall")
	await wait_frames(180)
	check(game.state == "RUN", "Fall lands on the arena and begins combat")
	check(game.player.is_on_floor(), "Player has a valid floor")
	clear_enemies()
	game.spawn_timer = 9999
	game.player.invulnerable = 9999
	game.player.global_position = Vector3(0, 0.1, 0)
	game.player.rotation = Vector3.ZERO
	game.player.aim = Vector3.FORWARD
	for weapon in Arsenal.WEAPONS:
		game.player.equip(weapon)
		game.player.attack()
		await wait_frames(2)
		check(game.player.weapon == weapon, "Equip / fire " + weapon)
	game.player.equip("ember")
	for spell in Arsenal.SPELLS:
		game.player.spell = spell
		game.player.attack()
		await wait_frames(2)
		check(game.player.attack_cooldown > 0, "Cast " + spell)
	game.player.equip("katana")
	game.player.attack_cooldown = 0
	var enemy = Enemy.new()
	enemy.game = game
	enemy.position = game.player.position + Vector3(0, 0, -2.5)
	game.enemies.append(enemy)
	game.add_child(enemy)
	await wait_frames(2)
	var hp: float = enemy.health
	game.player.attack()
	await wait_frames(7)
	check(enemy.health < hp, "Melee damages a target through physics visibility")
	enemy.take_damage(10000)
	check(game.kills == 1 and game.xp == 1, "Kill awards experience")
	await wait_frames(2)
	game.points = 10
	for id in 8:
		game.upgrade(id)
	check(game.points == 2, "Eight upgrades consume eight points")
	check(game.player.extra_jump and game.player.nova and game.player.lifesteal, "Abilities activate")
	game.upgrade(4)
	check(game.points == 2, "Duplicate unique ability costs nothing")
	game.pause_run()
	var saved_time: float = game.elapsed
	var saved_position: Vector3 = game.player.position
	await wait_frames(10)
	check(game.elapsed == saved_time and game.player.position == saved_position, "Pause freezes timer and player")
	game.resume_run()
	# Real traversal catches seams, missing collisions, gates and raised ramps.
	game.player.speed = 20
	game.player.position = game.centers[0] + Vector3.UP * 0.2
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	Engine.time_scale = 3.0
	var route: Array[int] = []
	for i in range(1, game.centers.size()):
		route.append(i)
	for i in range(game.centers.size() - 2, -1, -1):
		route.append(i)
	for i in route:
		clear_enemies()
		game.spawn_timer = 9999
		var target: Vector3 = game.centers[i]
		var offset: Vector3 = target - game.player.position
		var action := "forward"
		if abs(offset.x) > abs(offset.z):
			action = "right" if offset.x > 0 else "left"
		else:
			action = "back" if offset.z > 0 else "forward"
		Input.action_press(action)
		var reached := false
		for frame in 200:
			await physics_frame
			if Vector2(game.player.position.x - target.x, game.player.position.z - target.z).length() < 0.9:
				reached = true
				break
		Input.action_release(action)
		game.player.velocity = Vector3.ZERO
		check(reached, "Walk corridor / ramp into sector " + str(i + 1))
		check(game.sector == i, "Sector trigger " + str(i + 1))
		check(game.top_down == (i % 2 == 1), "Perspective alternates in sector " + str(i + 1))
		if not reached:
			print("Traversal stopped at ", game.player.position, "; target ", target)
			break
	Engine.time_scale = 1
	game.start_run()
	check(game.player.inventory.size() == 1, "New run resets inventory")
	check(game.points == 0 and game.kills == 0 and game.elapsed == 0, "New run resets progression")
	check(not game.player.nova and game.player.damage_mult == 1, "New run resets upgrades")
	check(not game.top_down and game.sector == 0, "New run resets camera and sector")
	for c in 3:
		game.class_index = c
		game.selected_weapon = Arsenal.CLASSES[c].weapons[0]
		game.start_run()
		check(game.player.weapon == game.selected_weapon, "Class loadout " + str(c))
	game.return_to_hub()
	check(game.state == "MENU" and game.top_camera.current, "Return to hub")
	print("RIFT TESTS: ", checks, " checks / ", "FAILED" if failed else "ALL PASSED")
	game.queue_free()
	await wait_frames(5)
	quit(1 if failed else 0)
