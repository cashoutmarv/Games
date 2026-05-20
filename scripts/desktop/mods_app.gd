extends CanvasLayer

# mods/ — the community-pack browser. Scans `user://mods/dict/` for JSON
# packs and reports each one's noun/adjective counts. v6 ships read-only;
# packs are auto-loaded by WeaponDict at game start. Players install by
# dropping JSON files into the mods folder on disk.

@onready var _list: VBoxContainer = $Window/V/Scroll/List
@onready var _summary: Label = $Window/V/Summary
@onready var _path_label: Label = $Window/V/PathLabel
@onready var _reload_button: Button = $Window/V/Footer/Reload
@onready var _close_button: Button = $Window/V/Footer/Close

const _MOD_DIR := "user://mods/dict"

func _ready() -> void:
	_close_button.pressed.connect(_on_close)
	_reload_button.pressed.connect(_on_reload)
	_path_label.text = "Drop JSON packs into:\n%s" % ProjectSettings.globalize_path(_MOD_DIR)
	_render()

func _render() -> void:
	for child in _list.get_children():
		child.queue_free()
	_ensure_mod_dir()
	var packs: Array = _scan_packs()
	if packs.is_empty():
		var empty := Label.new()
		empty.text = "(no community packs installed yet)"
		empty.modulate = Color(0.7, 0.75, 0.85, 1)
		_list.add_child(empty)
	for pack in packs:
		_list.add_child(_make_pack_row(pack))
	_summary.text = "Bundled: %d nouns, %d adjectives.   Installed packs: %d." % [
		WeaponDict.noun_count(),
		WeaponDict.adjective_count(),
		packs.size(),
	]

func _ensure_mod_dir() -> void:
	# Make the mods directory exist so the player has a place to drop files.
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_MOD_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_MOD_DIR))

func _scan_packs() -> Array:
	var packs: Array = []
	var d := DirAccess.open(_MOD_DIR)
	if d == null:
		return packs
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		if not d.current_is_dir() and name.ends_with(".json"):
			packs.append(_inspect_pack(_MOD_DIR.path_join(name)))
		name = d.get_next()
	d.list_dir_end()
	return packs

func _inspect_pack(path: String) -> Dictionary:
	var info: Dictionary = {"path": path, "nouns": 0, "adjectives": 0, "ok": false}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return info
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return info
	var d: Dictionary = parsed
	info["nouns"] = int(d.get("nouns", {}).size())
	info["adjectives"] = int(d.get("adjectives", {}).size())
	info["ok"] = true
	return info

func _make_pack_row(pack: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 70)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var name := Label.new()
	name.text = String(pack.get("path", "")).get_file()
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name)
	var stats := Label.new()
	if bool(pack.get("ok", false)):
		stats.text = "%d nouns · %d adj" % [int(pack.nouns), int(pack.adjectives)]
	else:
		stats.text = "malformed"
		stats.modulate = Color(1.0, 0.6, 0.5, 1)
	h.add_child(stats)
	return row

func _on_reload() -> void:
	# Re-run the WeaponDict scan + refresh this view. Lets a player drop
	# a new pack file and see it appear without restarting the game.
	if WeaponDict.has_method("_load_all_dicts"):
		WeaponDict._load_all_dicts()
	_render()

func _on_close() -> void:
	queue_free()
