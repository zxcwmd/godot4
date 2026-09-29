class_name Bus
extends Node
## Глобальная шина сигналов: связывает ядро и интерфейс без прямых ссылок.

signal logged(level: String, text: String)
signal notified(title: String, body: String, level: String)
signal nav_requested(page: String)

signal instances_changed()
signal current_instance_changed(id: String)
signal java_changed()
signal settings_changed()
signal accent_changed(a: Color, b: Color)

signal download_progress(label: String, ratio: float)
signal game_state_changed(state: String, pid: int)
signal task_state_changed(task_id: String, state: String)
signal task_progress(task_id: String, ratio: float)
signal task_log(task_id: String, level: String, text: String)
signal versions_changed()
signal java_ready()
signal version_preset(version_id: String)
