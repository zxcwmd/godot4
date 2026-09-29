class_name Net
extends Node
## Тонкая обёртка над HTTPRequest: JSON-запросы и скачивание файлов с прогрессом.

const DEFAULT_TIMEOUT := 30.0
const DOWNLOAD_TIMEOUT := 300.0
const USER_AGENT := "AuroraLauncher/1.0 (+godot4)"

var in_flight := 0

## Возвращает {"ok": bool, "code": int, "json": Variant, "raw": PackedByteArray, "error": String}
func request(url: String, headers: Dictionary = {}, method: int = HTTPClient.MethodGet, body: String = "", timeout: float = DEFAULT_TIMEOUT) -> Dictionary:
	var node := HTTPRequest.new()
	node.timeout = int(timeout)
	add_child(node)
	var packed := PackedStringArray()
	for key in headers:
		packed.append("%s: %s" % [key, headers[key]])
	packed.append("User-Agent: " + USER_AGENT)
	in_flight += 1
	var args: Array = await node.request_completed
	in_flight -= 1
	node.queue_free()

	var out := {"ok": false, "code": int(args[1]), "json": null, "raw": args[3], "error": ""}
	if int(args[0]) != HTTPRequest.RESULT_SUCCESS:
		out["error"] = "Сетевая ошибка (код %d): %s" % [int(args[0]), url]
		return out
	var code := int(args[1])
	if code < 200 or code >= 300:
		out["error"] = "HTTP %d: %s" % [code, url]
		return out
	var raw: PackedByteArray = args[3]
	var text := raw.get_string_from_utf8().strip_edges()
	if text.begins_with("{") or text.begins_with("["):
		var parsed = JSON.parse_string(text)
		if parsed == null:
			out["error"] = "Не удалось разобрать JSON: %s" % url
			return out
		out["json"] = parsed
	out["ok"] = true
	return out

func get_json(url: String, headers: Dictionary = {}, timeout: float = DEFAULT_TIMEOUT) -> Dictionary:
	return await request(url, headers, HTTPClient.MethodGet, "", timeout)

func get_text(url: String, headers: Dictionary = {}, timeout: float = DEFAULT_TIMEOUT) -> String:
	var r := await request(url, headers, HTTPClient.MethodGet, "", timeout)
	if not bool(r.get("ok", false)):
		return ""
	return String(r["raw"].get_string_from_utf8())

## Скачивание файла. on_progress(ratio: float) вызывается по мере загрузки.
func download_file(url: String, dest: String, headers: Dictionary = {}, timeout: float = DOWNLOAD_TIMEOUT, on_progress: Callable = Callable()) -> Dictionary:
	var abs_dest := ProjectSettings.globalize_path(dest)
	var abs_dir := abs_dest.get_base_dir()
	if abs_dir != "":
		DirAccess.make_dir_recursive_absolute(abs_dir)

	var node := HTTPRequest.new()
	node.timeout = int(timeout)
	node.download_file = abs_dest
	add_child(node)
	var packed := PackedStringArray()
	for key in headers:
		packed.append("%s: %s" % [key, headers[key]])
	packed.append("User-Agent: " + USER_AGENT)

	# Лямбды захватывают локальные переменные по значению, поэтому состояние
	# держим в изменяемом контейнере.
	var state := {"done": false, "args": []}
	node.request_completed.connect(func(a, b, c, d):
		state["done"] = true
		state["args"] = [a, b, c, d]
	)
	in_flight += 1
	node.request(url, packed, HTTPClient.MethodGet, "")

	var last_ratio := 0.0
	while not bool(state["done"]):
		var total := node.get_body_size()
		var got := node.get_downloaded_bytes()
		if total > 0 and on_progress.is_valid():
			var ratio: float = clampf(float(got) / float(total), 0.0, 1.0)
			if ratio > last_ratio:
				last_ratio = ratio
				on_progress.call(ratio)
		await get_tree().create_timer(0.08).timeout

	in_flight -= 1
	var args: Array = state["args"]
	node.queue_free()
	var out := {"ok": false, "code": int(args[1]), "raw": PackedByteArray(), "error": "", "path": abs_dest}
	if int(args[0]) != HTTPRequest.RESULT_SUCCESS:
		out["error"] = "Ошибка загрузки (код %d): %s" % [int(args[0]), url]
		return out
	var code := int(args[1])
	if code < 200 or code >= 300:
		out["error"] = "HTTP %d: %s" % [code, url]
		return out
	if on_progress.is_valid():
		on_progress.call(1.0)
	out["ok"] = true
	return out
