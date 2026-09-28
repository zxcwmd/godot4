extends SceneTree
const Enemy = preload("res://scripts/enemy.gd")
var game: Node3D
var failed := false
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func clear_enemies() -> void:
	for e in game.enemies:
		if is_instance_valid(e):
			e.queue_free()
	game.enemies.clear()

func walk_to(target: Vector3) -> bool:
	for frame in 180:
		var delta = target - game.player.position
		if Vector2(delta.x, delta.z).length() < 0.85 and abs(delta.y) < 0.8:
			for action in ["left", "right", "forward", "back"]:
				Input.action_release(action)
			game.player.velocity = Vector3.ZERO
			return true
		for action in ["left", "right", "forward", "back"]:
			Input.action_release(action)
		if abs(delta.x) > 0.5:
			Input.action_press("right" if delta.x > 0 else "left")
		if abs(delta.z) > 0.5:
			Input.action_press("back" if delta.z > 0 else "forward")
		await physics_frame
	for action in ["left", "right", "forward", "back"]:
		Input.action_release(action)
	print("Stopped: ", game.player.position, "; target: ", target)
	return false

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	game.start_run()
	game.state = "RUN"
	game.best = 1000000 # Tests must never replace the user's real record.
	game.player.position = Vector3(0, 0.1, 0)
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	game.player.invulnerable = 99999
	game.player.speed = 16
	game.spawn_timer = 99999
	check(game.world.ROOM_HALF == 25 and game.centers[1].z == -76, "Megacomplex footprint and wider corridors")
	check(game.world.floor_nodes.size() == 36, "Four storeys in all nine sectors")
	check(game.world.navigation.get_point_count() > 200, "Connected vertical navigation graph")
	check(game.art.textures.size() >= 5, "Original nearest-filter pixel textures")
	Engine.time_scale = 3
	var path: Array[Vector3] = [Vector3(-20, 0, 20), Vector3(-20, 0, 15), Vector3(-20, 6, -15), Vector3(-20, 6, -20), Vector3(20, 6, -20), Vector3(20, 6, -15), Vector3(20, 12, 15), Vector3(20, 12, 20), Vector3(-20, 12, 20), Vector3(-20, 12, 15), Vector3(-20, 18, -15), Vector3(-20, 18, -20)]
	var all_reached := true
	for p in path:
		var reached = await walk_to(p)
		check(reached, "Climb accessible floor / landing " + str(p))
		if not reached:
			all_reached = false
			break
	if all_reached:
		var e = Enemy.new()
		e.game = game
		e.position = Vector3(-20, 0.1, 20)
		game.enemies.append(e)
		game.add_child(e)
		for i in 900:
			await physics_frame
			if e.position.y > 17.5:
				break
		check(e.position.y > 17.5, "Enemy physically navigates all three stair flights")
		if e.position.y < 17.5:
			print("NPC stuck: ", e.position, " path: ", e.nav_path)
	clear_enemies()
	game.player.position = Vector3(-20, 18.1, -20)
	if all_reached:
		path.reverse()
		for p in path:
			var reached = await walk_to(p)
			check(reached, "Descend floor / landing " + str(p))
			if not reached:
				break
	Engine.time_scale = 1
	game.player.position = game.centers[1] + Vector3.UP * 0.1
	game.enter_sector(1)
	clear_enemies()
	game.spawn_timer = 99999
	game.player.armor = 0.6
	game.player.health = game.player.max_health
	game.player.invulnerable = 9999
	check(not game.challenge.arm(), "C cannot be armed during ten-second cooldown")
	game.challenge.cooldown = 0
	check(game.challenge.arm(), "C event opens a two-second window")
	game.challenge.tick(1.0)
	game.pause_run()
	game.challenge.tick(20)
	check(game.challenge.remaining == 1.0, "Pause does not consume the response window")
	game.resume_run()
	var before: float = game.player.health
	game.challenge.tick(1.1)
	check(is_equal_approx(game.player.health, before - game.player.max_health * 0.15), "Failure removes exactly 15% max HP, bypassing armor and dash immunity")
	check(not game.side_view and game.challenge.cooldown == 10, "Failure keeps camera and starts cooldown")
	check(not game.challenge.respond(), "Pressing C outside a prompt does nothing")
	game.challenge.cooldown = 0
	game.challenge.arm()
	var saved: Vector3 = game.player.position
	check(game.challenge.respond(), "Successful response accepted")
	check(game.side_view and game.top_down and game.challenge.cooldown == 10, "Success enters true side-scroller and cooldown")
	await frames(4)
	var z: float = game.player.position.z
	Input.action_press("forward")
	await frames(8)
	Input.action_release("forward")
	check(is_equal_approx(game.player.position.z, z), "Side mode locks depth; W cannot leave the plane")
	var x: float = game.player.position.x
	Input.action_press("right")
	await frames(12)
	Input.action_release("right")
	check(game.player.position.x > x + 1, "Side mode supports horizontal movement")
	game.player.position = game.side_center + Vector3(18, 0.1, 0)
	game.player.velocity = Vector3.ZERO
	await frames(8)
	Input.action_press("jump")
	await frames(4)
	Input.action_release("jump")
	check(game.player.position.y > game.side_center.y + 0.3, "Side mode uses real jumping and gravity")
	game.spawn_wave()
	check(game.enemies.all(func(e): return e.side_member and is_equal_approx(e.position.z, game.side_plane_z)), "New enemies spawn on the combat plane")
	clear_enemies()
	game.challenge.cooldown = 0
	game.challenge.tick(0.01)
	check(game.challenge.remaining > 0, "Clearing all enemies cannot trap the player in side view")
	game.challenge.respond()
	check(not game.side_view and game.player.position.is_equal_approx(saved), "Return to overhead restores safe original position")
	game.set_perspective(false)
	game.challenge.cooldown = 0
	check(not game.challenge.arm(), "FPS sectors never start the C event")
	game.start_sandbox()
	game.open_lab()
	game.challenge.preview()
	check(game.challenge.remaining == 2 and game.top_down, "Lab can preview the C event")
	game.challenge.tick(5)
	check(game.challenge.remaining == 2, "Lab panel freezes the preview")
	game.resume_run()
	game.challenge.respond()
	check(game.side_view, "Lab enters side mode")
	game.lab.teleport(2)
	check(not game.side_view and game.player.position.x > 200, "Lab teleport exits side mode without restoring the wrong position")
	game.return_to_hub()
	check(not game.side_view and game.challenge.remaining == 0, "Hub clears side mode and pending event")
	print("RIFT VERTICAL TESTS: ", checks, " checks / ", "FAILED" if failed else "ALL PASSED")
	game.queue_free()
	await frames(5)
	quit(1 if failed else 0)
