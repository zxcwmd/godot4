class_name LauncherPage
extends Control
## Базовый класс страницы: страницы получают события от ядра через main.gd.

func refresh() -> void:
	pass

func on_log(level: String, text: String) -> void:
	pass

func on_game_state(state: String, pid: int) -> void:
	pass

func on_task_state(task_id: String, state: String) -> void:
	pass

func on_task_progress(task_id: String, ratio: float) -> void:
	pass

func on_task_log(task_id: String, level: String, text: String) -> void:
	pass

func on_versions_ready() -> void:
	pass

func on_instance_changed() -> void:
	pass

func on_download_progress(label: String, ratio: float) -> void:
	pass
