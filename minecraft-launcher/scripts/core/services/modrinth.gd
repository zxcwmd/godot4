class_name ModrinthService
extends Node
## Каталог модов и модпаков Modrinth: поиск, установка, проверка обновлений.

signal progress(text: String, ratio: float)

func search(query: String, game_version := "", loader := "", project_type := "mod", limit := 24, offset := 0) -> Array:
	var facets: Array = [["project_type:%s" % project_type]]
	if game_version != "":
		facets.append(["versions:%s" % game_version])
	if loader != "":
		facets.append(["categories:%s" % loader])
	var url := "%s/search?query=%s&limit=%d&offset=%d&index=relevance&facets=%s" % [
		Constants.MODRINTH_API, query.uri_encode(), limit, offset, JSON.stringify(facets).uri_encode()
	]
	var r := await Net.get_json(url, {}, 30.0)
	if not bool(r.get("ok", false)) or r["json"] == null:
		Bus.logged.emit("error", "Modrinth: %s" % String(r.get("error", "ошибка поиска")))
		return []
	return r["json"].get("hits", [])

func project(slug: String) -> Dictionary:
	var r := await Net.get_json("%s/project/%s" % [Constants.MODRINTH_API, slug], {}, 30.0)
	if bool(r.get("ok", false)) and r["json"] != null:
		return r["json"]
	return {}

func versions(slug: String, game_version := "", loader := "") -> Array:
	var url := "%s/project/%s/version" % [Constants.MODRINTH_API, slug]
	var sep := "?"
	if game_version != "":
		url += "%sgame_versions=%s" % [sep, JSON.stringify([game_version]).uri_encode()]
		sep = "&"
	if loader != "":
		url += "%sloaders=%s" % [sep, JSON.stringify([loader]).uri_encode()]
	var r := await Net.get_json(url, {}, 30.0)
	if bool(r.get("ok", false)) and r["json"] != null:
		return r["json"]
	return []

func latest_compatible(slug: String, game_version: String, loader: String) -> Dictionary:
	var list := await versions(slug, game_version, loader)
	if list.is_empty():
		return {}
	return list[0]

## Устанавливает мод в экземпляр. version — элемент из versions().
func install_mod(instance: Dictionary, version: Dictionary) -> Dictionary:
	var files: Array = version.get("files", [])
	if files.is_empty():
		return {"ok": false, "error": "У версии нет файлов"}
	var file: Dictionary = files[0]
	var url := String(file.get("url", ""))
	var filename := String(file.get("filename", ""))
	if url == "" or filename == "":
		return {"ok": false, "error": "Некорректное описание файла"}
	var mods_dir := Store.instance_dir(String(instance.get("id", ""))).path_join("mods")
	DirAccess.make_dir_recursive_absolute(mods_dir)
	var dest := mods_dir.path_join(filename)
	Bus.download_progress.emit(filename, 0.0)
	var r := await Net.download_file(url, dest, {}, 600.0, func(ratio):
		Bus.download_progress.emit(filename, ratio)
		progress.emit("Качаю %s" % filename, ratio)
	)
	if not bool(r.get("ok", false)):
		return {"ok": false, "error": String(r.get("error", "не удалось скачать мод"))}

	var mods: Array = instance.get("mods", [])
	var entry := {
		"slug": String(version.get("project_id", "")),
		"version_id": String(version.get("id", "")),
		"version_number": String(version.get("version_number", "")),
		"name": String(version.get("name", filename)),
		"filename": filename,
		"game_versions": version.get("game_versions", []),
		"loaders": version.get("loaders", []),
	}
	var replaced := false
	for i in range(mods.size()):
		if String(mods[i].get("slug", "")) == entry["slug"]:
			mods[i] = entry
			replaced = true
			break
	if not replaced:
		mods.append(entry)
	instance["mods"] = mods
	Store.upsert_instance(instance)
	return {"ok": true, "entry": entry}

func installed_mods(instance: Dictionary) -> Array:
	return instance.get("mods", [])

## Ищет обновления для установленных модов.
func updates_for(instance: Dictionary) -> Array:
	var out: Array = []
	var game_version := String(instance.get("version", ""))
	var loader := String(instance.get("loader", ""))
	for mod in instance.get("mods", []):
		var slug := String(mod.get("slug", ""))
		if slug == "":
			continue
		var latest := await latest_compatible(slug, game_version, loader)
		if latest.is_empty():
			continue
		if String(latest.get("id", "")) == String(mod.get("version_id", "")):
			continue
		out.append({"mod": mod, "latest": latest})
	return out

func update_mod(instance: Dictionary, mod: Dictionary, latest: Dictionary) -> Dictionary:
	var mods_dir := Store.instance_dir(String(instance.get("id", ""))).path_join("mods")
	var old_file := mods_dir.path_join(String(mod.get("filename", "")))
	if FileAccess.file_exists(old_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old_file))
	return await install_mod(instance, latest)

## Устанавливает .mrpack: файлы из индекса + распаковка overrides/.
func install_modpack(game_dir: String, mrpack_path: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(game_dir)
	var zip := ZipArchive.new()
	if not zip.open(mrpack_path):
		return {"ok": false, "error": "Не удалось открыть .mrpack"}
	if not zip.has("modrinth.index.json"):
		zip.close()
		return {"ok": false, "error": "В архиве нет modrinth.index.json"}
	var index = JSON.parse_string(zip.read("modrinth.index.json").get_string_from_utf8())
	zip.close()
	if index == null:
		return {"ok": false, "error": "Битый modrinth.index.json"}
	var data: Dictionary = index
	var files: Array = data.get("files", [])
	var total := files.size()
	var done := 0
	for f in files:
		var entry: Dictionary = f
		var path := String(entry.get("path", ""))
		if path == "":
			continue
		var downloads: Array = entry.get("downloads", [])
		if downloads.is_empty():
			continue
		var dest := game_dir.path_join(path)
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var r := await Net.download_file(String(downloads[0]), dest, {}, 600.0)
		if not bool(r.get("ok", false)):
			Bus.logged.emit("warn", "Модпак: не скачан файл %s" % path)
		done += 1
		progress.emit("Файлы модпака %d/%d" % [done, total], float(done) / float(maxi(total, 1)))

	var zip2 := ZipArchive.new()
	if zip2.open(mrpack_path):
		zip2.extract_all(game_dir, "overrides/", true)
		zip2.close()
	return {"ok": true, "name": String(data.get("name", "Модпак")), "dependencies": data.get("dependencies", {})}
