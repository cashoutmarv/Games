extends Node

# Scribblenauts-style weapon dictionary.
#
# Parses player-typed weapon text into a resolved weapon dictionary entry:
#   { archetype, attack_pattern, stats, tags, source_text, noun, adjectives }
#
# Reads bundled dictionaries from res://data/dict/*.json on _ready, then
# merges sideloaded packs from user://mods/dict/*.json. Bundled keys win
# conflicts so packs can extend but not override.

const BUNDLED_DICT_DIR := "res://data/dict"
const USER_MOD_DICT_DIR := "user://mods/dict"

signal dictionary_loaded(noun_count: int, adjective_count: int)

# nouns: { "crowbar": {archetype: "melee_reach", stats: {...}, tags: [...] } }
var _nouns: Dictionary = {}
# adjectives: { "rusty": { stat_mults: {damage: 0.8, crit_chance: +0.1}, tags: ["rust"] } }
var _adjectives: Dictionary = {}

const _DEFAULT_STATS_BY_ARCHETYPE: Dictionary = {
	"melee_short":      {"damage": 14, "fire_cooldown": 0.22, "speed": 720.0, "range": 70.0, "knockback": 30.0, "attack_pattern": "melee_arc"},
	"melee_reach":      {"damage": 22, "fire_cooldown": 0.45, "speed": 540.0, "range": 130.0, "knockback": 70.0, "attack_pattern": "thrust"},
	"ranged_precision": {"damage": 18, "fire_cooldown": 0.35, "speed": 780.0, "range": 900.0, "knockback": 10.0, "attack_pattern": "single_shot"},
	"ranged_spread":    {"damage": 8,  "fire_cooldown": 0.55, "speed": 540.0, "range": 520.0, "knockback": 20.0, "attack_pattern": "cone"},
	"aoe":              {"damage": 12, "fire_cooldown": 0.85, "speed": 360.0, "range": 220.0, "knockback": 80.0, "attack_pattern": "aoe_radial"},
	"utility":          {"damage": 6,  "fire_cooldown": 0.40, "speed": 540.0, "range": 480.0, "knockback": 5.0,  "attack_pattern": "buff_self"},
}

func _ready() -> void:
	_load_all_dicts()

# Public re-scan of bundled + sideloaded dictionaries. Called by the mods
# browser after the player drops a new pack into user://mods/dict/.
func reload_dicts() -> void:
	_load_all_dicts()

func _load_all_dicts() -> void:
	_nouns.clear()
	_adjectives.clear()
	# Sideload first so bundled overrides win (we layer bundled on top).
	_load_dir(USER_MOD_DICT_DIR)
	_load_dir(BUNDLED_DICT_DIR)
	dictionary_loaded.emit(_nouns.size(), _adjectives.size())

func _load_dir(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		if not d.current_is_dir() and name.ends_with(".json"):
			_load_file(dir_path.path_join(name))
		name = d.get_next()
	d.list_dir_end()

func _load_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("WeaponDict: %s is not a JSON object" % path)
		return
	var dict: Dictionary = parsed
	for noun_id in dict.get("nouns", {}).keys():
		_nouns[String(noun_id).to_lower()] = dict["nouns"][noun_id]
	for adj_id in dict.get("adjectives", {}).keys():
		_adjectives[String(adj_id).to_lower()] = dict["adjectives"][adj_id]

# ---- Public API ---------------------------------------------------------

# Resolve a player-typed weapon string into a complete weapon dictionary.
# Always returns a non-empty resolution — unknown nouns fall through to
# the by-shape rule. Empty input falls through to "fist".
func resolve(text: String) -> Dictionary:
	var lowered: String = text.strip_edges().to_lower()
	if lowered == "":
		lowered = "fist"
	# split() returns PackedStringArray; normalize to Array[String] and
	# index by size to avoid PackedArray negative-index quirks on older
	# Godot 4.x point releases.
	var raw: PackedStringArray = lowered.split(" ", false)
	var tokens: Array[String] = []
	for s in raw:
		tokens.append(String(s))
	if tokens.is_empty():
		tokens.append("fist")
	var noun: String = tokens[tokens.size() - 1]
	var adjectives: Array = []
	for i in range(tokens.size() - 1):
		adjectives.append(tokens[i])
	var noun_entry: Dictionary = _nouns.get(noun, {})
	var archetype: String
	var base_tags: Array = []
	if noun_entry.is_empty():
		archetype = _archetype_by_shape(noun)
	else:
		archetype = String(noun_entry.get("archetype", "melee_short"))
		base_tags = noun_entry.get("tags", []).duplicate()
	var stats: Dictionary = _base_stats_for(archetype)
	# Apply per-noun stat overrides if the dictionary entry specifies them.
	for k in noun_entry.get("stats", {}).keys():
		stats[k] = noun_entry["stats"][k]
	# Apply adjective modifiers.
	var tags: Array = base_tags
	for adj in adjectives:
		var adj_entry: Dictionary = _adjectives.get(adj, {})
		if adj_entry.is_empty():
			continue
		for stat_key in adj_entry.get("stat_mults", {}).keys():
			if stats.has(stat_key):
				stats[stat_key] = float(stats[stat_key]) * float(adj_entry["stat_mults"][stat_key])
		for stat_key in adj_entry.get("stat_adds", {}).keys():
			if stats.has(stat_key):
				stats[stat_key] = float(stats[stat_key]) + float(adj_entry["stat_adds"][stat_key])
		for t in adj_entry.get("tags", []):
			if not tags.has(t):
				tags.append(t)
	return {
		"source_text": text,
		"noun": noun,
		"adjectives": adjectives,
		"archetype": archetype,
		"attack_pattern": stats.get("attack_pattern", "single_shot"),
		"stats": stats,
		"tags": tags,
	}

# Public helper exposed for tests + inspection.
func archetype_for_noun(noun: String) -> String:
	var entry: Dictionary = _nouns.get(noun.to_lower(), {})
	if entry.is_empty():
		return _archetype_by_shape(noun)
	return String(entry.get("archetype", "melee_short"))

func noun_count() -> int:
	return _nouns.size()

func adjective_count() -> int:
	return _adjectives.size()

# ---- Private helpers ----------------------------------------------------

func _base_stats_for(archetype: String) -> Dictionary:
	var base: Dictionary = _DEFAULT_STATS_BY_ARCHETYPE.get(archetype, _DEFAULT_STATS_BY_ARCHETYPE["melee_short"])
	return base.duplicate(true)

# Default-by-shape fallback for unknown nouns. Vowel-heavy → utility,
# otherwise by length: short → short melee, medium → reach, longer → ranged.
func _archetype_by_shape(noun: String) -> String:
	var n: String = noun.to_lower()
	var vowels: int = 0
	for c in n:
		if c in "aeiouy":
			vowels += 1
	if n.length() > 0 and float(vowels) / float(n.length()) >= 0.55:
		return "utility"
	if n.length() <= 4:
		return "melee_short"
	if n.length() <= 7:
		return "melee_reach"
	if n.length() <= 10:
		return "ranged_precision"
	return "aoe"
