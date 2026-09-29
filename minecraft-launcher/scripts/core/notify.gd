class_name Notify
extends Node
## Очередь уведомлений: складывает сообщения и рассылает их в UI.

var queue: Array = []
var history: Array = []

func _ready() -> void:
	Bus.notified.connect(_on_notified)

func _on_notified(title: String, body: String, level: String) -> void:
	var item := {"title": title, "body": body, "level": level, "time": Time.get_unix_time_from_system()}
	queue.append(item)
	history.append(item)
	if history.size() > 50:
		history = history.slice(history.size() - 50)

func push(title: String, body: String = "", level: String = "info") -> void:
	Bus.notified.emit(title, body, level)

func log(level: String, text: String) -> void:
	Bus.logged.emit(level, text)
