extends Control

const Arsenal = preload("res://scripts/arsenal.gd")
const RiftWorld = preload("res://scripts/world.gd")

var game: Node3D
var font: Font = ThemeDB.fallback_font
var ui: Control
var ink := Color("e8eff5")
var muted := Color("8293a9")
var dark := Color("0b1220")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	build_menu()

func _process(_dt: float) -> void:
	ui.scale = get_viewport_rect().size / Vector2(1440, 900)

func text(at: Vector2, content: String, size: int = 18, color: Color = Color("e8eff5")) -> void:
	draw_string(font, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color = Color(0.035, 0.055, 0.09, 0.94), border: Color = Color("253044")) -> void:
	draw_rect(rect, color)
	draw_rect(rect, border, false, 1)

func line(a: Vector2, b: Vector2, color: Color = Color("253044"), width: float = 1.0) -> void:
	draw_line(a, b, color, width, true)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, get_viewport_rect().size / Vector2(1440, 900))
	if game.state == "MENU":
		draw_hub()
		return
	draw_game()
	if game.state in ["PAUSE", "UPGRADE", "HELP", "OVER"]:
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.015, 0.025, 0.048, 0.94))
		match game.state:
			"PAUSE": draw_pause()
			"UPGRADE": draw_upgrades()
			"HELP": draw_help()
			"OVER": draw_over()

func draw_hub() -> void:
	# Asymmetric editorial layout leaves the animated 3D hub visible on the right.
	draw_rect(Rect2(0, 0, 650, 410), Color(0.02, 0.035, 0.06, 0.9))
	draw_rect(Rect2(0, 405, 1440, 495), Color(0.02, 0.035, 0.06, 0.97))
	line(Vector2(48, 57), Vector2(1392, 57))
	text(Vector2(48, 37), "R//R     НЕЙРОАРЕНА", 17, Arsenal.LIME)
	text(Vector2(1090, 37), "СИГНАЛ АКТИВЕН     •     200 BPM", 14, Arsenal.CYAN)
	text(Vector2(64, 96), "БЕСКОНЕЧНЫЙ ЗАБЕГ  /  ОДНА ЖИЗНЬ", 14, muted)
	text(Vector2(54, 202), "RIFT//", 112, ink)
	text(Vector2(54, 310), "RUSH", 128, Arsenal.LIME)
	draw_rect(Rect2(433, 236, 145, 34), Arsenal.ORANGE)
	text(Vector2(446, 260), "NO SIGNAL LOST", 13, dark)
	text(Vector2(65, 355), "ПАДАЙ ГЛУБЖЕ. ДВИГАЙСЯ БЫСТРЕЕ.", 18, ink)
	text(Vector2(65, 381), "3D <> 2D  /  BREAKBEATS  /  SURVIVE", 14, muted)
	panel(Rect2(1110, 95, 265, 86), Color(0.025, 0.045, 0.07, 0.9))
	text(Vector2(1130, 123), "ЛИЧНЫЙ РЕКОРД", 13, muted)
	text(Vector2(1130, 163), game.clock(game.best), 34, Arsenal.CYAN)
	text(Vector2(970, 370), "//  ХАБ / ВЫБЕРИ СВОЙ СИГНАЛ", 14, Arsenal.CYAN)
	text(Vector2(64, 444), "01", 16, Arsenal.LIME)
	text(Vector2(100, 444), "ВЫБЕРИ КЛАСС", 16, ink)
	text(Vector2(1110, 444), "ТВОЙ СТИЛЬ. ТВОЙ ХАОС.", 13, muted)
	for i in 3:
		var x = 64 + i * 445
		var c = Arsenal.CLASSES[i]
		var active = game.class_index == i
		panel(Rect2(x, 465, 422, 136), Color("111e2b") if active else Color("0d1522"), c.color if active else Color("253044"))
		draw_rect(Rect2(x, 465, 4, 136), c.color if active else Color("253044"))
		text(Vector2(x + 22, 490), c.tag, 12, c.color)
		text(Vector2(x + 22, 525), c.name, 28, ink if active else muted)
		var desc = c.desc.split("\n")
		text(Vector2(x + 22, 555), desc[0], 15, muted)
		text(Vector2(x + 22, 578), desc[1], 14, muted)
		draw_circle(Vector2(x + 388, 486), 5, c.color, active, -1.0 if active else 1.5, true)
	text(Vector2(64, 640), "02", 16, Arsenal.LIME)
	text(Vector2(100, 640), "СТАРТОВОЕ ОРУЖИЕ", 16, ink)
	text(Vector2(64, 739), Arsenal.WEAPONS[game.selected_weapon].desc, 17, muted)
	line(Vector2(64, 786), Vector2(978, 786))
	text(Vector2(64, 819), "WASD  движение      МЫШЬ  прицел / атака      SHIFT  рывок      SPACE  прыжок", 15, ink)
	text(Vector2(64, 849), "TAB  улучшения      F1  справка      M  музыка      ESC  пауза", 14, muted)
	text(Vector2(1090, 867), "ENTER / ПРЫЖОК В НЕИЗВЕСТНОСТЬ", 11, muted)

func draw_game() -> void:
	var p = game.player
	panel(Rect2(30, 26, 365, 84))
	draw_rect(Rect2(30, 26, 4, 84), Arsenal.LIME)
	text(Vector2(50, 51), "R//R   •   " + ("FLATLINE / 2D" if game.top_down else "PERSPECTIVE / 3D"), 13, Arsenal.LIME)
	text(Vector2(50, 88), "%02d" % (game.sector + 1), 30, ink)
	text(Vector2(102, 85), RiftWorld.ROOM_NAMES[game.sector], 14, muted)
	panel(Rect2(610, 26, 220, 87))
	text(Vector2(656, 51), "ВРЕМЯ В ЖИВЫХ", 12, muted)
	text(Vector2(649, 94), game.clock(game.elapsed), 39, ink)
	panel(Rect2(1138, 26, 270, 84))
	text(Vector2(1158, 53), "УБИЙСТВА", 12, muted)
	text(Vector2(1158, 89), "%03d" % game.kills, 32, Arsenal.ORANGE)
	text(Vector2(1260, 53), "УРОВЕНЬ", 12, muted)
	text(Vector2(1278, 89), "%02d" % game.level, 32, ink)
	if game.combo > 1:
		text(Vector2(55, 172), "%02d ×" % game.combo, 42, Arsenal.ORANGE)
		text(Vector2(57, 199), "НЕ СБАВЛЯЙ ТЕМП", 12, muted)
		draw_rect(Rect2(57, 210, 150 * clampf(game.combo_timer / 4, 0, 1), 3), Arsenal.ORANGE)
	# Crosshair remains diegetic: centered in FPS, follows mouse in overhead mode.
	var cross = Vector2(720, 450)
	if game.top_down:
		cross = get_viewport().get_mouse_position() / (get_viewport_rect().size / Vector2(1440, 900))
	if game.top_down:
		# Keep the player readable even when a heavy enemy overlaps their model.
		var screen_scale = get_viewport_rect().size / Vector2(1440, 900)
		var marker = game.top_camera.unproject_position(p.global_position + Vector3.UP) / screen_scale
		draw_circle(marker, 18, Arsenal.CYAN, false, 2.0, true)
		var aim_2d = Vector2(p.aim.x, p.aim.z).normalized()
		line(marker + aim_2d * 20, marker + aim_2d * 31, Arsenal.LIME, 3)
	var active_camera: Camera3D = game.top_camera if game.top_down else p.camera
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.health >= enemy.max_health:
			continue
		var head: Vector3 = enemy.global_position + Vector3.UP * 2.7
		if active_camera.is_position_behind(head):
			continue
		var screen = active_camera.unproject_position(head) / (get_viewport_rect().size / Vector2(1440, 900))
		if screen.x > 0 and screen.x < 1440 and screen.y > 0 and screen.y < 900:
			draw_rect(Rect2(screen - Vector2(19, 14), Vector2(38, 4)), dark)
			draw_rect(Rect2(screen - Vector2(19, 14), Vector2(38 * maxf(0, enemy.health / enemy.max_health), 4)), enemy.color)
	var col = Arsenal.ORANGE if game.hit_marker > 0 else Color(0.8, 0.98, 1.0, 0.8)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		line(cross + dir * 6, cross + dir * 13, col, 2)
	if game.hit_marker > 0:
		for dir in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			line(cross + dir * 14, cross + dir * 20, Arsenal.ORANGE, 2)
	panel(Rect2(30, 754, 370, 111))
	text(Vector2(50, 783), "ЖИЗНЕННЫЙ СИГНАЛ", 12, muted)
	text(Vector2(50, 825), "%03d" % ceili(p.health), 38, Arsenal.LIME if p.health > 30 else Arsenal.ORANGE)
	text(Vector2(137, 823), "/ %d" % p.max_health, 18, muted)
	draw_rect(Rect2(50, 843, 330, 5), Color("253044"))
	draw_rect(Rect2(50, 843, 330 * p.health / p.max_health, 5), Arsenal.LIME if p.health > 30 else Arsenal.ORANGE)
	text(Vector2(243, 782), "SHIFT / РЫВОК", 12, Arsenal.CYAN)
	draw_rect(Rect2(244, 801, 132, 7), Color("253044"))
	draw_rect(Rect2(244, 801, 132 * (1 - p.dash_cooldown / 1.1), 7), Arsenal.CYAN)
	text(Vector2(264, 833), "ГОТОВ" if p.dash_cooldown <= 0 else "%.1f с" % p.dash_cooldown, 14, muted)
	panel(Rect2(1040, 754, 368, 111))
	text(Vector2(1060, 781), "АКТИВНОЕ ОРУЖИЕ  /  ∞", 12, muted)
	text(Vector2(1060, 813), Arsenal.WEAPONS[p.weapon].name, 20, Arsenal.CLASSES[game.class_index].color)
	text(Vector2(1060, 842), "КОЛЕСО / 1–9   •   АРСЕНАЛ: %02d" % p.inventory.size(), 13, muted)
	text(Vector2(530, 851), "TAB  УЛУЧШЕНИЯ   •   F1  СПРАВКА", 14, muted)
	if game.points > 0:
		panel(Rect2(542, 777, 355, 45), Color("253c28"), Arsenal.LIME)
		text(Vector2(564, 806), "+%d  ОЧКИ УЛУЧШЕНИЯ  [TAB]" % game.points, 16, Arsenal.LIME)
	draw_rect(Rect2(30, 884, 1378, 3), Color("253044"))
	draw_rect(Rect2(30, 884, 1378.0 * game.xp / game.xp_goal, 3), Arsenal.VIOLET)
	if game.class_index == 2:
		panel(Rect2(450, 660, 540, 76))
		text(Vector2(470, 689), "Q  ОГОНЬ     E  ЛЁД     R  МОЛНИЯ", 13, muted)
		text(Vector2(470, 719), (p.elements if not p.elements.is_empty() else "— — —") + "  > F", 20, Arsenal.VIOLET)
		text(Vector2(632, 717), Arsenal.SPELLS[p.spell].name, 15, ink)
	if game.notice_time > 0:
		var width = font.get_string_size(game.notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 50
		panel(Rect2(720 - width / 2, 140, width, 46), Color(0.02, 0.035, 0.06, 0.94), game.notice_color.darkened(0.6))
		text(Vector2(745 - width / 2, 169), game.notice, 19, game.notice_color)
	# A tiny route map is also a navigation hint: the arena is not a straight hallway.
	if game.elapsed < 14 or game.top_down:
		draw_map(Vector2(1252, 160))
	if game.state == "DROP":
		text(Vector2(462, 385), "ВНИЗ ПО КРОЛИЧЬЕЙ НОРЕ", 29, Arsenal.LIME)
		text(Vector2(586, 425), "СИГНАЛ СКОРО ВОССТАНОВИТСЯ", 12, ink)
	if game.hurt_flash > 0:
		var c = Color(1, 0.12, 0.05, game.hurt_flash * 0.7)
		draw_rect(Rect2(0, 0, 1440, 900), c, false, 16)
	if game.transition > 0 and not game.reduced_fx:
		for i in 7:
			var y = fmod(game.real_time * 380 + i * 149, 900)
			draw_rect(Rect2(0, y, 1440, 2), Color(0.4, 0.9, 1.0, game.transition * 0.22))

func draw_map(origin: Vector2) -> void:
	panel(Rect2(origin - Vector2(12, 16), Vector2(168, 206)), Color(0.025, 0.04, 0.07, 0.8))
	text(origin + Vector2(0, 0), "КАРТА СИГНАЛА", 11, muted)
	for i in game.centers.size():
		var c: Vector3 = game.centers[i]
		var p = origin + Vector2(c.x * 1.25 + 65, c.z * 1.1 + 163)
		if i > 0:
			var prev: Vector3 = game.centers[i - 1]
			line(p, origin + Vector2(prev.x * 1.25 + 65, prev.z * 1.1 + 163), Color("475269"), 2)
		draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Arsenal.LIME if i == game.sector else (Arsenal.VIOLET if i % 2 else Arsenal.CYAN).darkened(0.6))

func heading(kicker: String, title: String, subtitle: String) -> void:
	text(Vector2(120, 116), kicker, 15, Arsenal.LIME)
	text(Vector2(115, 191), title, 58, ink)
	text(Vector2(120, 235), subtitle, 18, muted)
	line(Vector2(120, 265), Vector2(1320, 265))

func draw_pause() -> void:
	heading("R//R  /  СИГНАЛ ПРИОСТАНОВЛЕН", "ПЕРЕДЫШКА.", "Время и враги замерли. Твой забег ждёт.")
	text(Vector2(122, 335), "Время  " + game.clock(game.elapsed) + "     /     Убийства  " + str(game.kills), 26, Arsenal.CYAN)
	text(Vector2(122, 695), "M  музыка: " + ("ВЫКЛ" if game.sound.muted else "ВКЛ"), 18, muted)
	text(Vector2(122, 731), "F3  частицы и тряска: " + ("СНИЖЕНЫ" if game.reduced_fx else "ПОЛНЫЕ"), 18, muted)

func draw_upgrades() -> void:
	heading("R//R  /  ПЕРЕПРОШИВКА", "СТАНЬ ОПАСНЕЕ.", "Доступно очков: %d   /   Каждое улучшение стоит 1 очко. Время остановлено." % game.points)
	var descriptions = [
		["01 / ЖИВУЧЕСТЬ", "+25 к максимуму HP, лечение +45"],
		["02 / РАЗРУШЕНИЕ", "+18% базового урона"],
		["03 / СВЕРХЧАСТОТА", "+15% скорости атак"],
		["04 / УСКОРЕНИЕ", "+1.3 к скорости бега, максимум 20"],
		["05 / ВОЗДУШНЫЙ ШАГ", "Дополнительный прыжок в воздухе"],
		["06 / УДАРНАЯ ВОЛНА", "Рывок наносит урон и замедляет"],
		["07 / БРОНЯ", "−10% входящего урона, максимум 60%"],
		["08 / ВАМПИРИЗМ", "Каждое убийство лечит на 4 HP"]
	]
	for i in 8:
		var x = 120 + (i % 2) * 614
		var y = 290 + (i / 2) * 108
		panel(Rect2(x, y, 590, 94), Color("101d2c"))
		text(Vector2(x + 22, y + 32), descriptions[i][0], 19, Arsenal.CYAN)
		text(Vector2(x + 22, y + 61), descriptions[i][1], 16, muted)
		if upgrade_owned(i):
			text(Vector2(x + 467, y + 58), "АКТИВНО", 12, Arsenal.LIME)
	text(Vector2(120, 760), "HP %d   /   УРОН ×%.2f   /   АТАКА ×%.2f   /   БЕГ %.1f   /   БРОНЯ %d%%" % [game.player.max_health, game.player.damage_mult, game.player.haste, game.player.speed, game.player.armor * 100], 16, muted)

func draw_help() -> void:
	heading("R//R  /  ПРОТОКОЛ ВЫЖИВАНИЯ", "ДВИЖЕНИЕ — ЖИЗНЬ.", "Один уровень. Девять секторов. Бесконечная угроза. Иди по салатовым стрелкам.")
	var tips = ["WASD / стрелки — бег    •    SPACE — прыжок    •    SHIFT — рывок с неуязвимостью", "Мышь — обзор в 3D / прицел в 2D    •    ЛКМ — атака (можно удерживать)", "Колесо / 1–9 — оружие    •    TAB — прокачка    •    M — музыка    •    ESC — пауза", "Новый сектор: смена 3D <> 2D, +1 очко и +25 HP. Каждые 12 убийств — оружие.", "Опыт за убийства даёт уровни и очки. Зелёные осколки лечат. Дольше живёшь — сильнее враги."]
	for i in tips.size():
		text(Vector2(120, 307 + i * 36), tips[i], 17, ink if i < 3 else muted)
	text(Vector2(120, 521), "АРКАНИСТ / Q огонь + E лёд + R молния > F призвать > ЛКМ применить", 19, Arsenal.VIOLET)
	var i := 0
	for key in Arsenal.SPELLS:
		text(Vector2(120 + (i % 2) * 614, 559 + (i / 2) * 32), key + "  /  " + Arsenal.SPELLS[key].name, 16, muted)
		i += 1
	text(Vector2(120, 741), "Порядок стихий не важен. Последние три нажатия задают комбинацию. Заклинания без маны.", 16, Arsenal.CYAN)

func draw_over() -> void:
	heading("R//R  /  СОЕДИНЕНИЕ ПОТЕРЯНО", "СИГНАЛ ОБОРВАН.", "Ещё один прыжок. Ещё одна попытка стать быстрее.")
	text(Vector2(113, 415), game.clock(game.elapsed), 122, Arsenal.ORANGE)
	text(Vector2(121, 455), "ВРЕМЯ В ЖИВЫХ", 16, muted)
	for i in 3:
		var x = 120 + i * 408
		panel(Rect2(x, 508, 385, 120))
		text(Vector2(x + 25, 542), ["УБИЙСТВА", "ЛУЧШЕЕ КОМБО", "ЛИЧНЫЙ РЕКОРД"][i], 15, muted)
		text(Vector2(x + 25, 598), [str(game.kills), str(game.best_combo) + " ×", game.clock(game.best)][i], 42, Arsenal.CYAN)

func upgrade_owned(id: int) -> bool:
	return (id == 4 and game.player.extra_jump) or (id == 5 and game.player.nova) or (id == 7 and game.player.lifesteal) or (id == 6 and game.player.armor >= 0.599) or (id == 3 and game.player.speed >= 20)

func build_menu() -> void:
	if ui == null:
		return
	for node in ui.get_children():
		ui.remove_child(node)
		node.queue_free()
	match game.state:
		"MENU":
			for i in 3:
				var index = i
				button(Rect2(64 + i * 445, 465, 422, 136), "", func():
					game.class_index = index
					game.selected_weapon = Arsenal.CLASSES[index].weapons[0]
					game.sound.play("ui")
					build_menu(), Arsenal.CLASSES[i].color, true)
			var weapons = Arsenal.CLASSES[game.class_index].weapons
			var width = minf(254, 1312.0 / weapons.size() - 10)
			for i in weapons.size():
				var id: String = weapons[i]
				button(Rect2(64 + i * (width + 10), 661, width, 49), Arsenal.WEAPONS[id].name, func():
					game.selected_weapon = id
					game.sound.play("ui")
					build_menu(), Arsenal.CLASSES[game.class_index].color, false, id == game.selected_weapon, 15)
			button(Rect2(1028, 777, 349, 64), "НАЧАТЬ ЗАБЕГ   >>", game.start_run, Arsenal.LIME, false, true, 21)
		"PAUSE":
			button(Rect2(120, 395, 520, 65), "ПРОДОЛЖИТЬ  /  ESC", game.resume_run, Arsenal.LIME, false, true)
			button(Rect2(120, 482, 520, 60), "ПРОТОКОЛ / СПРАВКА", func():
				game.state = "HELP"
				build_menu(), Arsenal.CYAN)
			button(Rect2(120, 565, 520, 60), "ЗАВЕРШИТЬ ЗАБЕГ / В ХАБ", game.return_to_hub, Arsenal.ORANGE)
		"UPGRADE":
			for i in 8:
				var id = i
				var b = button(Rect2(120 + (i % 2) * 614, 290 + (i / 2) * 108, 590, 94), "", func(): game.upgrade(id), Arsenal.CYAN, true)
				b.disabled = game.points <= 0 or upgrade_owned(i)
			button(Rect2(930, 794, 390, 60), "В БОЙ  /  TAB", game.resume_run, Arsenal.LIME, false, true)
		"HELP":
			button(Rect2(930, 794, 390, 60), "ПОНЯТНО / В БОЙ", game.resume_run, Arsenal.LIME, false, true)
		"OVER":
			button(Rect2(120, 714, 580, 75), "ЕЩЁ ОДИН ЗАБЕГ   >>", game.start_run, Arsenal.LIME, false, true, 22)
			button(Rect2(732, 714, 580, 75), "СМЕНИТЬ КЛАСС / В ХАБ", game.return_to_hub, Arsenal.CYAN, false, false, 20)

func button(rect: Rect2, title: String, callback: Callable, accent: Color, transparent: bool = false, active: bool = false, font_size: int = 18) -> Button:
	var b = Button.new()
	b.position = rect.position
	b.size = rect.size
	b.text = title
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", dark if active else ink)
	b.add_theme_color_override("font_hover_color", dark)
	b.add_theme_color_override("font_pressed_color", dark)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = accent if active else Color("142131")
		style.border_color = accent if active else Color("34425a")
		style.set_border_width_all(1)
		if transparent:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
		if state_name in ["hover", "pressed"]:
			style.bg_color = Color(accent, 0.09) if transparent else accent
			style.border_color = accent
		b.add_theme_stylebox_override(state_name, style)
	b.pressed.connect(callback)
	ui.add_child(b)
	return b
