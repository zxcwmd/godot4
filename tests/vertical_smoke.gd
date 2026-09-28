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
	check(not ("challenge" in game) and not ("side_view" in game), "Perspective-break event fully removed")
	check(not FileAccess.file_exists("res://scripts/perspective_event.gd"), "No leftover event script")
	print("RIFT VERTICAL TESTS: ", checks, " checks / ", "FAILED" if failed else "ALL PASSED")
	game.queue_free()
	await frames(5)
	quit(1 if failed else 0)
