class_name PerspectiveEvent
extends RefCounted
## A gameplay event, not a UI timer: paused menus never consume the deadline.
var game: Node3D
var remaining := 0.0
var cooldown := 10.0
var successes := 0
var misses := 0
const WINDOW = 2.0
const COOLDOWN = 10.0
const DAMAGE_FRACTION = 0.15

func reset() -> void:
	remaining = 0
	cooldown = COOLDOWN

func tick(dt: float) -> void:
	if game.state != "RUN":
		return
	if not game.top_down:
		reset()
		return
	if remaining > 0:
		remaining = maxf(0, remaining - dt)
		if remaining <= 0:
			misses += 1
			cooldown = COOLDOWN
			game.player.hurt(game.player.max_health * DAMAGE_FRACTION, true)
			game.notify("СБОЙ ПЕРСПЕКТИВЫ / -15% HP", Color("ff7955"))
		return
	cooldown = maxf(0, cooldown - dt)
	if cooldown <= 0 and (game.side_view or game.enemies.any(func(e): return is_instance_valid(e) and not e.dead and not e.practice_target)):
		arm()

func arm() -> bool:
	if not game.top_down or remaining > 0 or cooldown > 0:
		return false
	remaining = WINDOW
	game.sound.play("portal", -9, 1.6)
	return true

func respond() -> bool:
	if game.state != "RUN" or not game.top_down or remaining <= 0:
		return false
	remaining = 0
	cooldown = COOLDOWN
	successes += 1
	game.set_side_view(not game.side_view)
	game.sound.play("portal", -8)
	return true

func preview() -> void:
	# Lab-only button: the timer remains frozen until the control panel is closed.
	if not game.sandbox:
		return
	if not game.top_down:
		game.set_perspective(true)
	cooldown = 0
	arm()
