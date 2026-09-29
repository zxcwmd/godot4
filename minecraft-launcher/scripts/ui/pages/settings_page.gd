class_name SettingsPage
extends LauncherPage
## Настройки: аккаунт, Java, память, оформление, автоматизация и «умные» задачи.

var _account_name: LineEdit
var _account_status: Label
var _java_box: VBoxContainer
var _ram_slider: SleekSlider
var _ram_label: Label
var _accent_select: Select
var _bg_slider: SleekSlider
var _motion_toggle: ToggleSwitch
var _bot_host: LineEdit
var _bot_port: LineEdit
var _bot_name: LineEdit
var _concurrency_slider: SleekSlider
var _concurrency_label: Label
var _smart_box: VBoxContainer

func _ready() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.add_child(_build_account())
	content.add_child(_build_java())
	content.add_child(_build_memory())
	content.add_child(_build_look())
	content.add_child(_build_automation())
	content.add_child(_build_smart())
	content.add_child(_build_about())
	add_child(Kit.scroll(Kit.margin(content, 22, 26, 24, 26)))
	refresh()

func _panel(title: String) -> Dictionary:
	var panel := Kit.glass(20)
	var margin := MarginContainer.new()
	for pair in [["margin_top", 16], ["margin_right", 18], ["margin_bottom", 16], ["margin_left", 18]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(Kit.section(title))
	margin.add_child(box)
	panel.add_child(margin)
	return {"panel": panel, "box": box}

# ------------------------------------------------------------------- аккаунт -
func _build_account() -> Control:
	var parts := _panel("Аккаунт")
	var box: VBoxContainer = parts["box"]
	_account_name = LineEdit.new()
	_account_name.text = String(Store.account.get("name", "Player"))
	_account_name.custom_minimum_size = Vector2(240, 40)
	_account_name.text_changed.connect(func(text):
		Store.account["name"] = text
		Store.account["type"] = "offline"
		Store.account["uuid"] = ""
		Store.account["token"] = ""
		Store.save_account()
		_refresh_account_status()
	)
	box.add_child(Kit.setting_row("Имя игрока", "Для оффлайн-режима (свои миры и локальные серверы)", _account_name))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var login := AccentButton.make("Войти через Microsoft", "accent", "user")
	login.custom_minimum_size = Vector2(220, 42)
	login.pressed.connect(_ms_login)
	row.add_child(login)
	_account_status = Kit.muted("", 12)
	_account_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_account_status.custom_minimum_size = Vector2(420, 0)
	_account_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_account_status)
	box.add_child(row)
	_refresh_account_status()
	return parts["panel"]

func _refresh_account_status() -> void:
	if _account_status == null:
		return
	if String(Store.account.get("type", "offline")) == "msa":
		_account_status.text = "Вход выполнен: %s (лицензия)" % String(Store.account.get("name", ""))
		_account_status.add_theme_color_override("font_color", Constants.C_OK)
	else:
		_account_status.text = "Оффлайн-режим: игра работает без проверки лицензии. Для официальных серверов нужен вход через Microsoft."
		_account_status.add_theme_color_override("font_color", Constants.C_TEXT_MUTED)

func _ms_login() -> void:
	Notify.push("Вход через Microsoft", "Откроется браузер — подтвердите код", "info")
	var result = await Auth.login_microsoft()
	if bool(result.get("ok", false)):
		Notify.push("Вход выполнен", "Аккаунт: %s" % String(result.get("name", "")), "ok")
		_account_name.text = String(Store.account.get("name", ""))
		_refresh_account_status()
	else:
		Notify.push("Не удалось войти", String(result.get("error", "")), "error")

# ---------------------------------------------------------------------- Java -
func _build_java() -> Control:
	var parts := _panel("Среда выполнения Java")
	var box: VBoxContainer = parts["box"]
	_java_box = VBoxContainer.new()
	_java_box.add_theme_constant_override("separation", 8)
	_java_box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_java_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var rescan := AccentButton.make("Найти заново", "ghost", "refresh")
	rescan.custom_minimum_size = Vector2(150, 40)
	rescan.corner = 12.0
	rescan.pressed.connect(func():
		Java.detect()
		refresh()
	)
	row.add_child(rescan)
	var install := AccentButton.make("Установить Java 21", "accent", "download")
	install.custom_minimum_size = Vector2(200, 40)
	install.pressed.connect(_install_java)
	row.add_child(install)
	box.add_child(row)
	refresh_java()
	return parts["panel"]

func refresh_java() -> void:
	if _java_box == null:
		return
	for child in _java_box.get_children():
		child.queue_free()
	if Java.detected.is_empty():
		Java.detect()
	if Java.detected.is_empty():
		var label := Kit.muted("Java не найдена. Нажмите «Установить Java 21» — лаунчер скачает Temurin JRE автоматически.", 12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_java_box.add_child(label)
		return
	for info in Java.detected:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card := Kit.card(12)
		var inner := MarginContainer.new()
		for pair in [["margin_top", 8], ["margin_right", 12], ["margin_bottom", 8], ["margin_left", 12]]:
			inner.add_theme_constant_override(pair[0], pair[1])
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph := IconGlyph.new()
		glyph.icon = "coffee"
		glyph.glyph_color = Constants.C_OK
		glyph.custom_minimum_size = Vector2(16, 16)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(glyph)
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", 0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(Kit.label(String(info.get("name", "Java")), 13, Color(1, 1, 1)))
		texts.add_child(Kit.label(String(info.get("path", "")), 10, Constants.C_TEXT_DIM))
		line.add_child(texts)
		var use := AccentButton.make("Использовать", "ghost", "check")
		use.custom_minimum_size = Vector2(140, 34)
		use.corner = 11.0
		var path := String(info.get("path", ""))
		use.pressed.connect(func():
			Store.set_setting("java_path", path)
			Notify.push("Java выбрана", String(info.get("name", "")), "ok")
		)
		line.add_child(use)
		inner.add_child(line)
		card.add_child(inner)
		row.add_child(card)
		_java_box.add_child(row)

func _install_java() -> void:
	Notify.push("Устанавливаю Java 21", "Скачиваю Eclipse Temurin JRE", "info")
	var result = await Java.install(21)
	if bool(result.get("ok", false)):
		Notify.push("Java 21 установлена", String(result.get("path", "")), "ok")
		Store.set_setting("java_path", String(result.get("path", "")))
		refresh_java()
	else:
		Notify.push("Не удалось установить Java", String(result.get("error", "")), "error")

# -------------------------------------------------------------------- память -
func _build_memory() -> Control:
	var parts := _panel("Память и производительность")
	var box: VBoxContainer = parts["box"]
	var ram_row := VBoxContainer.new()
	ram_row.add_theme_constant_override("separation", 4)
	ram_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ram_slider = SleekSlider.new()
	var system := float(Store.system_ram_mb())
	_ram_slider.set_range(1024.0, maxf(2048.0, system), 512.0)
	_ram_slider.value = float(int(Store.setting("ram_mb", 4096)))
	_ram_slider.value_changed.connect(func(v):
		_ram_label.text = "%d МБ" % int(v)
		Store.set_setting("ram_mb", int(v))
	)
	ram_row.add_child(_ram_slider)
	_ram_label = Kit.label("%d МБ" % int(_ram_slider.value), 12, Constants.C_TEXT_MUTED)
	ram_row.add_child(_ram_label)
	box.add_child(Kit.setting_row("Выделено лаунчеру по умолчанию", "Системная память: %d МБ · рекомендуется %d МБ" % [int(system), Store.recommended_ram_mb()], ram_row))
	return parts["panel"]

# ---------------------------------------------------------------- оформление -
func _build_look() -> Control:
	var parts := _panel("Оформление")
	var box: VBoxContainer = parts["box"]
	_accent_select = Select.make(_accent_options(), 0, false)
	_accent_select.custom_minimum_size = Vector2(220, 40)
	_accent_select.selected.connect(func(_i, _v): _apply_accent())
	var current_key := String(Store.setting("accent", "aurora"))
	for i in range(_accent_select.options.size()):
		if String((_accent_select.options[i] as Dictionary).get("value", "")) == current_key:
			_accent_select.select_index(i, false)
			break
	box.add_child(Kit.setting_row("Акцентный цвет", "Цвет кнопок, подсветки и фона", _accent_select))

	var bg_row := VBoxContainer.new()
	bg_row.add_theme_constant_override("separation", 4)
	bg_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bg_slider = SleekSlider.new()
	_bg_slider.set_range(0.0, 1.6, 0.05)
	_bg_slider.value = float(Store.setting("bg_intensity", 1.0))
	_bg_slider.value_changed.connect(func(v): Store.set_setting("bg_intensity", v))
	bg_row.add_child(_bg_slider)
	var bg_label := Kit.label("Яркость фоновой анимации", 12, Constants.C_TEXT_MUTED)
	bg_row.add_child(bg_label)
	box.add_child(Kit.setting_row("Фон", "Аврора, звёзды и виньетка", bg_row))

	_motion_toggle = ToggleSwitch.new()
	_motion_toggle.pressed = bool(Store.setting("reduce_motion", false))
	_motion_toggle.toggled.connect(func(v): Store.set_setting("reduce_motion", v))
	box.add_child(Kit.setting_row("Меньше анимаций", "Отключает плавные переходы и замедляет фон", _motion_toggle))
	return parts["panel"]

func _accent_options() -> Array:
	var out: Array = []
	for key in Constants.accents().keys():
		var entry: Dictionary = Constants.accents()[key]
		out.append({"value": key, "label": String(entry.get("name", key))})
	return out

func _apply_accent() -> void:
	var key := String(_accent_select.selected_value())
	Store.set_setting("accent", key)
	var colors := Constants.accent_colors(key)
	Bus.accent_changed.emit(colors["a"], colors["b"])

# ------------------------------------------------------------- автоматизация -
func _build_automation() -> Control:
	var parts := _panel("Автоматизация (боты)")
	var box: VBoxContainer = parts["box"]
	_bot_host = LineEdit.new()
	_bot_host.text = String(Store.setting("bot_host", "127.0.0.1"))
	_bot_host.custom_minimum_size = Vector2(200, 40)
	_bot_host.text_changed.connect(func(text): Store.set_setting("bot_host", text))
	box.add_child(Kit.setting_row("Адрес сервера", "Куда подключать ботов по умолчанию", _bot_host))

	_bot_port = LineEdit.new()
	_bot_port.text = str(int(Store.setting("bot_port", 25565)))
	_bot_port.custom_minimum_size = Vector2(120, 40)
	_bot_port.text_changed.connect(func(text):
		if text.is_valid_int():
			Store.set_setting("bot_port", int(text))
	)
	box.add_child(Kit.setting_row("Порт", "25565 — стандартный порт Java Edition", _bot_port))

	_bot_name = LineEdit.new()
	_bot_name.text = String(Store.setting("bot_username", "AuroraBot"))
	_bot_name.custom_minimum_size = Vector2(200, 40)
	_bot_name.text_changed.connect(func(text): Store.set_setting("bot_username", text))
	box.add_child(Kit.setting_row("Ник бота", "Имя, под которым бот заходит на сервер", _bot_name))

	var conc_row := VBoxContainer.new()
	conc_row.add_theme_constant_override("separation", 4)
	conc_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_concurrency_slider = SleekSlider.new()
	_concurrency_slider.set_range(1.0, 6.0, 1.0)
	_concurrency_slider.value = float(int(Store.setting("max_concurrent_tasks", 2)))
	_concurrency_slider.value_changed.connect(func(v):
		_concurrency_label.text = "%d одновременно" % int(v)
		Store.set_setting("max_concurrent_tasks", int(v))
	)
	conc_row.add_child(_concurrency_slider)
	_concurrency_label = Kit.label("%d одновременно" % int(_concurrency_slider.value), 12, Constants.C_TEXT_MUTED)
	conc_row.add_child(_concurrency_label)
	box.add_child(Kit.setting_row("Одновременные боты", "Больше — быстрее, но выше нагрузка", conc_row))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var open_bots := AccentButton.make("Пульт автоматизации", "ghost", "robot")
	open_bots.custom_minimum_size = Vector2(200, 40)
	open_bots.corner = 12.0
	open_bots.pressed.connect(func(): Bus.nav_requested.emit("automation"))
	row.add_child(open_bots)
	var open_dir := AccentButton.make("Каталог ботов", "ghost", "folder")
	open_dir.custom_minimum_size = Vector2(170, 40)
	open_dir.corner = 12.0
	open_dir.pressed.connect(func(): Proc.open_in_file_manager(Store.automation_dir()))
	row.add_child(open_dir)
	box.add_child(row)
	return parts["panel"]

# ------------------------------------------------------------- умные задачи --
func _build_smart() -> Control:
	var parts := _panel("Умные задачи лаунчера")
	var box: VBoxContainer = parts["box"]
	_smart_box = box
	box.add_child(Kit.setting_row("Авто-бэкап сохранений", "Копирует saves/ перед каждым запуском", _toggle("auto_backup")))
	box.add_child(Kit.setting_row("Авто-обновление модов", "Проверять новые версии на Modrinth", _toggle("auto_update_mods")))
	box.add_child(Kit.setting_row("Авто-установка Java", "Скачивать нужную версию Java при первом запуске", _toggle("auto_install_java")))
	box.add_child(Kit.setting_row("Авто-установка загрузчика", "Ставить Fabric/Forge/NeoForge самому", _toggle("auto_install_loader")))
	return parts["panel"]

func _toggle(key: String) -> ToggleSwitch:
	var toggle := ToggleSwitch.new()
	toggle.pressed = bool(Store.setting(key, true))
	toggle.toggled.connect(func(v): Store.set_setting(key, v))
	return toggle

# ------------------------------------------------------------------ о чём ---
func _build_about() -> Control:
	var parts := _panel("О программе")
	var box: VBoxContainer = parts["box"]
	box.add_child(Kit.setting_row("Версия", Constants.APP_NAME + " " + Constants.APP_VERSION, Kit.muted("Godot " + Engine.get_version_info().get("string", "4.x"), 12)))
	box.add_child(Kit.setting_row("Данные", "Сборки, моды и боты хранятся здесь", null))
	var open_button := AccentButton.make("Открыть папку данных", "ghost", "folder")
	open_button.custom_minimum_size = Vector2(200, 38)
	open_button.corner = 12.0
	open_button.pressed.connect(func(): Proc.open_in_file_manager(Store.data_dir()))
	box.add_child(open_button)
	var note := Kit.muted("Автоматизация действий в игре допустима только там, где это разрешено правилами сервера или в одиночной игре. За нарушение правил сервера ответственность несёт пользователь.", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	return parts["panel"]

func refresh() -> void:
	refresh_java()
