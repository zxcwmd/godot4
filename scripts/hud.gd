extends CanvasLayer
## Responsive vector HUD and menus. All UI strings are Russian.
const INK = Color("050505")
const PANEL = Color("0c0c0c")
const LINE = Color("5a4a10")
const TEXT = Color("ffde00")
const MUTED = Color("8a8010")
const LIME = Color("ffde00")
const CYAN = Color("fff8d0")
const PINK = Color("d01018")
var game
var canvas: Control
var controls: Control
var menu = "hub"
var hovered = -1
var font: Font
var bold: Font
var clock = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	font = ThemeDB.fallback_font
	bold = load("res://assets/Display-Bold.ttf") if ResourceLoader.exists("res://assets/Display-Bold.ttf") else font
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = Vector2(1440, 900)
	add_child(canvas)
	canvas.draw.connect(draw_screen)
	controls = Control.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(controls)

func _process(dt: float) -> void:
	clock += dt
	canvas.scale = get_viewport().get_visible_rect().size / Vector2(1440, 900)
	canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		game.muted = not game.muted
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), game.muted)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause"):
		if menu == "": show_pause()
		elif menu in ["pause", "help", "hub"]: close_menu()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("help") and game.phase != "end":
		if menu == "help": close_menu()
		else: show_help()
		get_viewport().set_input_as_handled()
	if menu == "hub" and event is InputEventKey and event.pressed:
		for i in range(3):
			if event.is_action_pressed("element_"+str(i)):
				select_class(i)
				get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ENTER:
			close_menu()
			get_viewport().set_input_as_handled()
	if menu == "end" and event.is_action_pressed("restart"):
		game.restart()

func clear_controls() -> void:
	for child in controls.get_children():
		child.queue_free()

func open_menu(value: String, pause: bool = true) -> void:
	menu = value
	clear_controls()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = pause

func close_menu() -> void:
	menu = ""
	clear_controls()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game.player.side_mode else Input.MOUSE_MODE_CAPTURED
	game.audio.play_sfx("ui")
	if game.phase == "hub":
		game.notify("WASD — ДВИЖЕНИЕ / ИДИ ВПЕРЁД И ПРЫГАЙ В ЯМУ", LIME, 5)

func select_class(index: int) -> void:
	game.player.set_class(index)
	game.audio.play_sfx("ui", 1+index*0.15)

func show_hub() -> void:
	open_menu("hub", false)
	for i in range(3):
		var button = make_button(Rect2(48+i*451, 446, 438, 258), "", func(): select_class(i), false, true)
		button.mouse_entered.connect(func(): hovered = i)
		button.mouse_exited.connect(func(): hovered = -1)
	make_button(Rect2(1058, 755, 334, 66), "В ХАБ    →", close_menu, true)
	make_button(Rect2(48, 762, 230, 52), "КАК ИГРАТЬ   ↗", show_help)

func show_pause() -> void:
	open_menu("pause")
	make_button(Rect2(80, 330, 420, 62), "ПРОДОЛЖИТЬ    →", close_menu, true)
	make_button(Rect2(80, 407, 420, 58), "УПРАВЛЕНИЕ / СИНТЕЗ", show_help)
	make_button(Rect2(80, 480, 420, 58), "НОВЫЙ ЦИКЛ", func(): game.restart())
	make_button(Rect2(80, 733, 420, 54), "ВЫЙТИ ИЗ ИГРЫ", func(): get_tree().quit())
	var music = HSlider.new()
	music.position = Vector2(260, 577)
	music.size = Vector2(240, 30)
	music.min_value = -35
	music.max_value = 0
	music.value = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	music.value_changed.connect(func(value): AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), value))
	controls.add_child(music)
	var sensitivity = HSlider.new()
	sensitivity.position = Vector2(260, 624)
	sensitivity.size = Vector2(240, 30)
	sensitivity.min_value = 0.0007
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = game.player.sensitivity
	sensitivity.value_changed.connect(func(value): game.player.sensitivity = value)
	controls.add_child(sensitivity)
	var check = CheckButton.new()
	check.position = Vector2(72, 672)
	check.text = "Меньше тряски и вспышек"
	check.button_pressed = game.player.reduced_motion
	check.add_theme_font_size_override("font_size", 19)
	check.toggled.connect(func(value): game.player.reduced_motion = value)
	controls.add_child(check)

func show_help() -> void:
	open_menu("help")
	make_button(Rect2(1060, 793, 330, 60), "НАЗАД    →", func():
		if game.phase == "hub": show_hub()
		else: close_menu(), true)

func show_end() -> void:
	open_menu("end")
	make_button(Rect2(510, 655, 420, 68), "ЕЩЁ ОДИН ЦИКЛ    →", func(): game.restart(), true)
	make_button(Rect2(560, 742, 320, 54), "ВЫЙТИ", func(): get_tree().quit())

func make_button(rect: Rect2, text: String, callback: Callable, accent: bool = false, transparent: bool = false) -> Button:
	var button = Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", bold)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK if accent else TEXT)
	button.add_theme_color_override("font_hover_color", INK if accent else LIME)
	button.add_theme_color_override("font_pressed_color", INK if accent else LIME)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0) if transparent else (LIME if accent else PANEL)
		style.border_color = Color(0, 0, 0, 0) if transparent else (LIME if state != "normal" else LINE)
		style.set_border_width_all(0 if transparent else 1)
		if state == "hover" and accent: style.bg_color = Color("fff38a")
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	controls.add_child(button)
	return button

func text(at: Vector2, value: String, size: int = 20, color: Color = TEXT, strong: bool = false) -> void:
	canvas.draw_string(bold if strong else font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(y: float, value: String, size: int = 20, color: Color = TEXT, strong: bool = false) -> void:
	var f = bold if strong else font
	var width = f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(Vector2((1440-width)/2, y), value, size, color, strong)

func line(a: Vector2, b: Vector2, color: Color = LINE, width: float = 1.0) -> void:
	canvas.draw_line(a, b, color, width, true)

func panel(rect: Rect2, color: Color = PANEL, edge: Color = LINE) -> void:
	canvas.draw_rect(rect, color)
	canvas.draw_rect(rect, edge, false, 1)

func pal_accent() -> Color:
	if game and is_instance_valid(game.world) and game.world.pal.has("accent"):
		return game.world.pal.accent
	return LIME

func pal_glow() -> Color:
	if game and is_instance_valid(game.world) and game.world.pal.has("glow"):
		return game.world.pal.glow
	return CYAN

func frost() -> void:
	canvas.draw_rect(Rect2(0, 0, 1440, 24), Color(0, 0, 0, 0.5))
	canvas.draw_rect(Rect2(0, 876, 1440, 24), Color(0, 0, 0, 0.5))
	canvas.draw_rect(Rect2(0, 0, 18, 900), Color(0, 0, 0, 0.4))
	canvas.draw_rect(Rect2(1422, 0, 18, 900), Color(0, 0, 0, 0.4))
	for i in range(5):
		var y = 70 + i * 160 + sin(clock * 1.1 + i) * 12
		canvas.draw_rect(Rect2(0, y, 1440, 1), Color(pal_accent(), 0.08))

func draw_transition() -> void:
	if game.trans_t < 0:
		return
	var t = game.trans_t
	var cover = 1.0
	if t < 0.45:
		cover = t / 0.45
	elif t > 0.55:
		cover = 1.0 - (t - 0.55) / 0.45
	var a = pal_accent()
	var g = pal_glow()
	var c = Vector2(720, 450)
	for i in range(10):
		var w = 1440.0 * clampf(cover * 1.15 - i * 0.05, 0, 1)
		var y = i * 90.0
		if i % 2 == 0:
			canvas.draw_rect(Rect2(0, y, w, 70), Color(a, 0.28 + cover * 0.3))
		else:
			canvas.draw_rect(Rect2(1440 - w, y, w, 70), Color(g, 0.22 + cover * 0.3))
	var iris = absf(t - 0.5) * 2.0
	var r = 24 + iris * 780
	for k in range(3):
		canvas.draw_arc(c, r + k * 16, 0, TAU, 56, Color(a, 0.5 * (1.0 - iris)), 5 - k, true)
	if t > 0.36 and t < 0.64:
		var flash = maxf(0, 1.0 - absf(t - 0.5) * 7.0)
		canvas.draw_rect(Rect2(0, 0, 1440, 900), Color(1, 0.9, 0.1, flash * 0.45))
		centered(430, "2D" if game.trans_to_side else "3D", 96, Color(INK, flash), true)
		centered(510, game.SECTOR_NAMES[game.sector], 22, Color(INK, flash))
	for i in range(8):
		var ang = i * TAU / 8.0 + t * 3.0
		var p = c + Vector2(cos(ang), sin(ang)) * (60 + cover * 240)
		canvas.draw_circle(p, 5 + cover * 8, Color(g, 0.5 * cover))

func draw_screen() -> void:
	if menu == "hub": draw_hub(); frost(); draw_transition(); return
	if menu == "pause": draw_pause(); frost(); return
	if menu == "help": draw_help(); frost(); return
	if menu == "end": draw_end(); frost(); return
	draw_game()
	frost()
	draw_transition()

func background() -> void:
	canvas.draw_rect(Rect2(0, 0, 1440, 900), Color(0, 0, 0, 0.94))
	canvas.draw_rect(Rect2(32, 32, 1376, 836), LIME, false, 2)
	canvas.draw_rect(Rect2(40, 40, 1360, 820), LINE, false, 1)
	line(Vector2(48, 75), Vector2(1392, 75), LIME, 2)
	line(Vector2(48, 849), Vector2(1392, 849), LIME, 2)
	text(Vector2(48, 52), "ZB // TERMINAL", 17, LIME, true)
	text(Vector2(1088, 52), "КРОВЬ — ТОПЛИВО.", 14, MUTED)
	text(Vector2(48, 878), "ZERO BEAT   /   HELL IS FULL", 13, MUTED)
	text(Vector2(1165, 878), "GODOT 4  /  186 BPM", 13, MUTED)

func draw_hub() -> void:
	background()
	text(Vector2(48, 124), "СКОРОСТЬ — ТВОЙ ЕДИНСТВЕННЫЙ ВЫХОД", 17, MUTED)
	text(Vector2(42, 224), "НУЛЕВОЙ", 101, TEXT, true)
	text(Vector2(42, 324), "ТАКТ", 101, LIME, true)
	canvas.draw_rect(Rect2(49, 347, 43, 4), LIME)
	text(Vector2(111, 357), "УБИВАЙ. НЕ СТОЙ. СОРВИ ПЕЧАТИ.", 18, TEXT)
	text(Vector2(48, 393), "Три печати. Босс в четырёх слоях. 22 секунды на выход.", 19, MUTED)
	var c = Vector2(1140, 252)
	for i in range(4):
		canvas.draw_arc(c, 44+i*28, 0, TAU, 48, LIME if i==1 else LINE, 3 if i==1 else 1, false)
	canvas.draw_rect(Rect2(c.x-8, c.y-70, 16, 140), LIME)
	canvas.draw_rect(Rect2(c.x-70, c.y-8, 140, 16), LIME)
	canvas.draw_circle(c, 22, PINK)
	canvas.draw_circle(c, 10, INK)
	text(Vector2(1270, 404), "[ 186.00 ]", 15, LIME)
	text(Vector2(48, 429), "01  /  ВЫБЕРИ КЛАСС", 15, MUTED, true)
	for i in range(3): draw_class_card(i)
	text(Vector2(50, 741), "02  /  ПРЫГНИ В ЯМУ", 16, LIME, true)
	text(Vector2(335, 789), "1 / 2 / 3 — выбор    •    Enter — в хаб", 17, MUTED)
	text(Vector2(50, 835), "Убийства лечат. Смена оружия растит рейтинг. Остановка убивает.", 16, MUTED)

func draw_class_card(index: int) -> void:
	var x = 48+index*451
	var selected = game.player.class_id == index
	var colors = [LIME, CYAN, PINK]
	var accent = colors[index]
	panel(Rect2(x, 446, 438, 258), Color("1a1400") if selected else PANEL, accent if selected else (MUTED if hovered == index else LINE))
	if selected: canvas.draw_rect(Rect2(x, 446, 438, 3), accent)
	text(Vector2(x+22, 480), "0"+str(index+1)+"  /  "+["БЛИЖНИЙ БОЙ", "ДАЛЬНИЙ БОЙ", "СИНТЕЗ СТИХИЙ"][index], 14, accent)
	text(Vector2(x+22, 530), ["КЛИНОК", "БАЛЛИСТ", "АРКАНИСТ"][index], 32, TEXT, true)
	# Class insignias.
	var c = Vector2(x+377, 515)
	if index == 0:
		line(c+Vector2(-22,20), c+Vector2(20,-24), accent, 4)
		line(c+Vector2(-17,-2), c+Vector2(0,15), accent, 3)
	elif index == 1:
		canvas.draw_arc(c, 20, 0, TAU, 40, accent, 2, true)
		line(c+Vector2(-30,0), c+Vector2(30,0), accent, 2)
		line(c+Vector2(0,-30), c+Vector2(0,30), accent, 2)
	else:
		for i in range(3):
			var at = c+Vector2(cos(i*TAU/3-PI/2), sin(i*TAU/3-PI/2))*22
			canvas.draw_circle(at, 7, [Color("ff7a45"), Color("4ad4ff"), Color("7dffc3")][i])
	line(Vector2(x+22, 550), Vector2(x+416, 550))
	var details = [
		["Катана · серпы · рапира", "Руки-бензопилы · коса", "БЛИЖЕ К ЦЕЛИ. ВЫШЕ ТЕМП."],
		["Револьвер · диски · рельс · дробовик", "Арбалет · гвоздомёт · гарпун · кадило", "ВОСЕМЬ СТВОЛОВ. НИ ОДНОГО ПАТРОНА."],
		["Огонь + лёд + молния", "10 уникальных обрядов", "КАЖДАЯ ТРОИЦА — СВОЙ РИТУАЛ."]
	]
	text(Vector2(x+22, 582), details[index][0], 18, TEXT)
	text(Vector2(x+22, 611), details[index][1], 18, TEXT)
	text(Vector2(x+22, 649), details[index][2], 13, MUTED)
	text(Vector2(x+22, 681), "●  ВЫБРАНО" if selected else "○  ВЫБРАТЬ КЛАСС", 14, accent if selected else MUTED, true)

func draw_game() -> void:
	var p = game.player
	var hub = game.phase == "hub"
	panel(Rect2(28, 25, 350, 91), Color(0, 0, 0, 0.88), pal_accent())
	canvas.draw_rect(Rect2(28, 25, 4, 91), pal_accent())
	text(Vector2(47, 52), "ZB / "+("ПРЕДКАМЕРА" if hub else game.SECTOR_NAMES[game.sector]), 17, pal_accent(), true)
	text(Vector2(47, 82), "ПРЫГНИ В ЯМУ" if hub else ("БЕГИ К ВЫХОДУ →" if game.phase=="escape" else ("УБЕЙ БОССА" if game.sector>=6 else "СОРВИ ТРИ ПЕЧАТИ")), 20, TEXT, true)
	text(Vector2(47, 104), "1 / 2 / 3 — класс • E — терминал" if hub else "ПЕЧАТИ  %d / 3   ·   ЦЕЛИ В БЛОКЕ  %02d" % [game.seals, game.block_enemies(mini(2, game.sector/2))], 13, MUTED)
	# Mission progress — a single continuous timeline.
	line(Vector2(426, 43), Vector2(990, 43), LINE, 3)
	var progress = clampf(p.global_position.x/540, 0, 1)
	line(Vector2(426, 43), Vector2(426+564*progress, 43), pal_accent(), 3)
	for i in range(3):
		var x = 426+564*(122+i*130)/540.0
		canvas.draw_circle(Vector2(x,43), 5, LIME if game.collected[i] else MUTED)
	text(Vector2(426, 68), ("2D / БОКОВАЯ ПРОЕКЦИЯ" if p.side_mode else "3D / ПЕРВОЕ ЛИЦО"), 13, pal_glow())
	text(Vector2(886, 68), "%02d:%02d" % [int(game.elapsed)/60, int(game.elapsed)%60], 14, MUTED)
	text(Vector2(1190, 47), "%07d" % game.score, 30, TEXT, true)
	text(Vector2(1230, 69), "СЧЁТ / ЦИКЛ", 13, MUTED)
	# Rhythm bars reflect the fallback tempo, not analysis of an imported track.
	for i in range(22):
		var h = 3 + absf(sin(clock*7+i*1.8))*12 + game.audio.beat()*5
		canvas.draw_rect(Rect2(1215+i*8, 104-h, 4, h), MUTED if game.muted else pal_accent())
	if game.combo > 0:
		text(Vector2(1270, 211), game.style_rank(), 58, pal_accent(), true)
		text(Vector2(1230, 241), "НЕ СБАВЛЯЙ ТЕМП", 13, TEXT)
		canvas.draw_rect(Rect2(1230, 254, 168, 3), LINE)
		canvas.draw_rect(Rect2(1230, 254, 168*clampf(game.combo_time/5,0,1), 3), pal_accent())
		text(Vector2(1280, 283), "ЦЕПЬ ×%02d" % game.combo, 16, MUTED)
	# Sparse radial streaks communicate velocity without obscuring targets.
	if p.dash_time > 0 and not p.reduced_motion:
		for i in range(14):
			var direction = Vector2.RIGHT.rotated(i*TAU/14+0.14)
			line(Vector2(720,450)+direction*350, Vector2(720,450)+direction*650, Color(CYAN,0.35), 1.5)
	# Target reticle, screen-space in 2D, center in FPS.
	var center = get_viewport().get_mouse_position()/canvas.scale if p.side_mode else Vector2(720,450)
	var cross_color = TEXT if game.hit_marker <= 0 else PINK
	for i in range(4):
		var dir = Vector2.RIGHT.rotated(i*PI/2)
		line(center+dir*7, center+dir*14, cross_color, 2)
	canvas.draw_circle(center, 1.5, LIME)
	if game.hit_marker > 0:
		for i in range(4):
			var dir = Vector2.RIGHT.rotated(PI/4+i*PI/2)
			line(center+dir*17, center+dir*24, PINK, 2)
	# Off-screen target guidance helps avoid leaving an enemy behind at a seal.
	if not hub:
		var nearest = null
		var nearest_distance = INF
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var d = p.global_position.distance_to(enemy.global_position)
			if not enemy.dead and d < nearest_distance:
				nearest = enemy; nearest_distance = d
		if nearest != null:
			var cam = game.side_camera if p.side_mode else p.camera
			var point = nearest.global_position+Vector3.UP*2.2
			if not cam.is_position_behind(point):
				var uv = cam.unproject_position(point)/canvas.scale
				if uv.x > 25 and uv.x < 1415 and uv.y > 120 and uv.y < 740:
					canvas.draw_rect(Rect2(uv.x-18, uv.y-4, 36, 3), LINE)
					canvas.draw_rect(Rect2(uv.x-18, uv.y-4, 36*nearest.hp/nearest.max_hp, 3), PINK)
				else: centered(743, ("← ЦЕЛЬ ПОЗАДИ" if nearest.global_position.x < p.global_position.x else "ЦЕЛЬ ВПЕРЕДИ →")+" / %d М"%nearest_distance, 13, PINK)
			else: centered(743, "← ЦЕЛЬ ПОЗАДИ / %d М"%nearest_distance, 13, PINK)
	if game.notice_time > 0:
		panel(Rect2(360, 140, 720, 42), Color(0,0,0,0.88), Color(game.notice_color,0.5))
		centered(167, game.notice, 15, game.notice_color, true)
	# Vital statistics.
	panel(Rect2(28, 764, 353, 105), Color(0,0,0,0.9))
	text(Vector2(46, 789), "ЦЕЛОСТНОСТЬ", 13, MUTED)
	text(Vector2(45, 840), "%03d"%p.hp, 43, PINK if p.hp<30 else TEXT, true)
	text(Vector2(148, 837), "/ 100", 16, MUTED)
	for i in range(10):
		canvas.draw_rect(Rect2(48+i*31, 852, 27, 4), (PINK if p.hp<30 else LIME) if p.hp>=i*10+1 else LINE)
	text(Vector2(233, 790), "ЭНЕРГИЯ", 13, CYAN)
	text(Vector2(260, 827), "%03d"%p.energy, 27, CYAN, true)
	canvas.draw_rect(Rect2(228, 839, 125, 3), LINE)
	canvas.draw_rect(Rect2(228, 839, 125*p.energy/100, 3), CYAN)
	panel(Rect2(997, 782, 415, 87), Color(0,0,0,0.9))
	text(Vector2(1014, 806), ["01 / КЛИНОК", "02 / БАЛЛИСТ", "03 / АРКАНИСТ"][p.class_id], 13, LIME)
	text(Vector2(1014, 835), p.weapon_name(), 19, TEXT, true)
	text(Vector2(1014, 856), "1 / 2 / 3 — стихии  ·  F — синтез" if p.class_id==2 else "Q / E / колесо — сменить оружие", 13, MUTED)
	if p.class_id==2:
		for i in range(3):
			var c = Vector2(664+i*56, 797)
			canvas.draw_circle(c, 18, Color(p.element_color(p.elements[i]),0.16))
			canvas.draw_arc(c, 18, 0, TAU, 28, p.element_color(p.elements[i]), 1.5, true)
			text(c+Vector2(-5,6), str(p.elements[i]+1), 18, p.element_color(p.elements[i]), true)
		centered(836, "F / СИНТЕЗ    •    ПКМ / ЭФИР", 12, MUTED)
	else:
		centered(811, "SHIFT  /  РЫВОК", 15, LIME if p.dash_cooldown<=0 else MUTED, true)
		canvas.draw_rect(Rect2(650, 826, 140, 3), LINE)
		canvas.draw_rect(Rect2(650, 826, 140*(1-p.dash_cooldown/0.85), 3), LIME)
	centered(887, "WASD / ДВИЖЕНИЕ     ПРОБЕЛ / ДВОЙНОЙ ПРЫЖОК     ЛКМ / АТАКА     ПКМ / ОСОБАЯ     TAB / ПОМОЩЬ     ESC / ПАУЗА", 12, MUTED)
	if is_instance_valid(game.boss) and not game.boss.dead:
		centered(207, "Б О С С", 17, PINK, true)
		canvas.draw_rect(Rect2(460, 221, 520, 5), LINE)
		canvas.draw_rect(Rect2(460, 221, 520*game.boss.hp/game.boss.max_hp, 5), PINK)
	if game.phase == "escape":
		centered(271, "ОБНУЛЕНИЕ ЧЕРЕЗ %.1f"%game.escape_left, 32, PINK, true)
	if game.damage_flash > 0:
		var a = game.damage_flash*(0.25 if p.reduced_motion else 0.55)
		canvas.draw_rect(Rect2(0,0,1440,900), Color(0.8,0.04,0.15,a), false, 18)
	if game.transition_flash > 0 and not p.reduced_motion:
		canvas.draw_rect(Rect2(0,0,1440,900), Color(pal_accent(), game.transition_flash*0.22))
		for i in range(8):
			canvas.draw_rect(Rect2(0, posmod(int(clock*1800)+i*127,900), 1440, 2), Color(pal_glow(), game.transition_flash*0.7))

func draw_pause() -> void:
	background()
	text(Vector2(80, 185), "ПАУЗА", 72, TEXT, true)
	text(Vector2(83, 231), "АД ПОДОЖДЁТ.", 20, LIME)
	text(Vector2(80, 598), "МУЗЫКА", 17, MUTED)
	text(Vector2(80, 646), "МЫШЬ", 17, MUTED)
	text(Vector2(695, 210), "НЕ ДАВАЙ РИТМУ УМЕРЕТЬ", 27, TEXT, true)
	var tips = [
		["01", "УБИВАЙ, ЧТОБЫ ЖИТЬ", "+7 здоровья и +6 энергии за каждую цель."],
		["02", "МЕНЯЙ ПОДХОД", "Новое оружие растит комбо быстрее."],
		["03", "РЫВОК — ТВОЯ БРОНЯ", "Короткая неуязвимость. Откат меньше секунды."],
		["04", "ВТОРОЕ ИЗМЕРЕНИЕ", "В 2D двигайся A / D и целься курсором."],
		["05", "СЛУШАЙ СВОЙ ТРЕК", "assets/music/breakcore.ogg  •  M — без музыки"]
	]
	for i in range(tips.size()):
		var y = 300+i*96
		text(Vector2(695,y), tips[i][0], 24, LIME, true)
		text(Vector2(754,y), tips[i][1], 19, TEXT, true)
		text(Vector2(754,y+29), tips[i][2], 17, MUTED)
		line(Vector2(695,y+49),Vector2(1350,y+49))

func draw_help() -> void:
	background()
	text(Vector2(48, 151), "ПРОТОКОЛ ВЫЖИВАНИЯ", 46, TEXT, true)
	text(Vector2(50, 191), "Хаб → яма → Жадность/Кишка вразброс → 3 печати → босс → выход.", 20, LIME)
	line(Vector2(720,235),Vector2(720,754))
	text(Vector2(48, 252), "УПРАВЛЕНИЕ", 22, TEXT, true)
	var rows = [
		["W A S D", "Движение / A и D в 2D"], ["МЫШЬ", "Обзор в 3D / прицел в 2D"],
		["ПРОБЕЛ ×2", "Двойной прыжок / через ударные волны"], ["SHIFT", "Рывок + короткая неуязвимость"],
		["ЛКМ / ПКМ", "Атака / усиленная атака за энергию"], ["Q / E / КОЛЕСО", "Смена оружия мечника и стрелка"],
		["1 / 2 / 3", "В хабе — класс. У мага — стихии."], ["F", "Собрать заклинание из трёх сфер"],
		["ПКМ / МАГ", "Эфирный разряд восполняет энергию"], ["ESC / TAB / M", "Пауза / справочник / музыка"]
	]
	for i in range(rows.size()):
		text(Vector2(48, 297+i*41), rows[i][0], 15, LIME, true)
		text(Vector2(260, 297+i*41), rows[i][1], 16, MUTED)
	text(Vector2(48, 748), "Печать открывается, когда зачищены оба сектора блока.", 17, TEXT)
	text(Vector2(766, 252), "АРКАНИСТ / ТАБЛИЦА СИНТЕЗА", 22, TEXT, true)
	text(Vector2(766, 287), "1 — ОГОНЬ    2 — ЛЁД    3 — МОЛНИЯ", 15, CYAN)
	var recipes = [
		["111", "Столпы пепла", "колонны огня под врагами"], ["112", "Дыхание урны", "конус пламени впереди"],
		["113", "Комета плоти", "рывок-метеорит с взрывом"], ["122", "Кряж костей", "шипы изо льда по линии"],
		["123", "Триптих", "огонь, лёд и молния в одну цель"], ["133", "Цепь молний", "скачки между врагами"],
		["222", "Часовня льда", "нова, сбивает снаряды, лечит"], ["223", "Небопогребение", "врагов поднимает и бьёт оземь"],
		["233", "Орбита бури", "три сферы бьют вокруг тебя"], ["333", "Шаг грома", "телепорт по лучу с уроном"]
	]
	for i in range(recipes.size()):
		var y = 330+i*37
		text(Vector2(766, y), recipes[i][0], 17, LIME, true)
		text(Vector2(830, y), recipes[i][1], 16, TEXT)
		text(Vector2(1130, y), recipes[i][2], 14, MUTED)
	text(Vector2(766, 734), "Нажми три цифры, затем F. Порядок сфер не важен.", 17, TEXT)
	text(Vector2(766, 759), "ЛКМ — сотворить. Выбранное заклинание сохраняется.", 16, MUTED)

func draw_end() -> void:
	background()
	centered(213, "СЛОЙ СОРВАН" if game.won else "МАШИНА РАЗРУШЕНА", 18, LIME if game.won else PINK)
	centered(326, "ЦИКЛ РАЗОРВАН" if game.won else "ТАКТ ОБОРВАН", 69, TEXT, true)
	centered(379, "Слой сорван. Ты ещё машина." if game.won else "Машина сломана. Ещё один цикл.", 21, MUTED)
	line(Vector2(270, 424),Vector2(1170,424))
	var values = ["%07d"%game.score, str(game.kills), "%02d:%02d"%[int(game.elapsed)/60,int(game.elapsed)%60], str(game.seals)+" / 3"]
	var labels = ["СЧЁТ", "УНИЧТОЖЕНО", "ВРЕМЯ", "ПЕЧАТИ"]
	for i in range(4):
		var x = 290+i*235
		text(Vector2(x, 479), labels[i], 13, MUTED)
		text(Vector2(x, 532), values[i], 36, LIME, true)
	line(Vector2(270, 564),Vector2(1170,564))
	centered(603, "ЛИЧНЫЙ РЕКОРД / %07d"%game.best_score, 16, MUTED)
