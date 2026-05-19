extends SceneTree

# Smoke test for the WeaponDict autoload. Covers:
#  - bundled-dict load
#  - archetype resolution for known nouns
#  - default-by-shape fallback for unknown nouns
#  - adjective stat-mult + stat-add stacking
#  - empty-input fallback
#  - tag merging via adjectives

func _initialize() -> void:
	var failures: Array[String] = []

	# Dictionary loaded at autoload _ready time. Sanity check: counts > 0.
	_expect(WeaponDict.noun_count() > 0,
		"core.json loaded — at least one noun", failures)
	_expect(WeaponDict.adjective_count() > 0,
		"core.json loaded — at least one adjective", failures)

	# Known noun → expected archetype.
	_expect(WeaponDict.archetype_for_noun("crowbar") == "melee_reach",
		"crowbar maps to melee_reach", failures)
	_expect(WeaponDict.archetype_for_noun("pistol") == "ranged_precision",
		"pistol maps to ranged_precision", failures)
	_expect(WeaponDict.archetype_for_noun("shotgun") == "ranged_spread",
		"shotgun maps to ranged_spread", failures)
	_expect(WeaponDict.archetype_for_noun("microwave") == "aoe",
		"microwave maps to aoe", failures)
	_expect(WeaponDict.archetype_for_noun("umbrella") == "utility",
		"umbrella maps to utility", failures)

	# Unknown noun — default-by-shape rule.
	var sh1: String = WeaponDict.archetype_for_noun("axe")  # 3 chars
	_expect(sh1 == "melee_short",
		"unknown 3-char word falls back to melee_short (got %s)" % sh1, failures)
	var sh2: String = WeaponDict.archetype_for_noun("bzzrt")  # 5 chars
	_expect(sh2 == "melee_reach",
		"unknown 5-char word falls back to melee_reach (got %s)" % sh2, failures)
	var sh3: String = WeaponDict.archetype_for_noun("metallrgy")  # 9 chars
	_expect(sh3 == "ranged_precision",
		"unknown 9-char word falls back to ranged_precision (got %s)" % sh3, failures)
	var sh4: String = WeaponDict.archetype_for_noun("indecipherable")  # 14 chars
	_expect(sh4 == "aoe",
		"unknown 14-char word falls back to aoe (got %s)" % sh4, failures)
	# Vowel-heavy → utility override.
	var sh5: String = WeaponDict.archetype_for_noun("aieiou")
	_expect(sh5 == "utility",
		"vowel-heavy word falls to utility (got %s)" % sh5, failures)

	# Resolve "rusty crowbar" — adjective applies a multiplier.
	var rusty: Dictionary = WeaponDict.resolve("rusty crowbar")
	_expect(rusty.get("archetype", "") == "melee_reach",
		"resolve('rusty crowbar').archetype is melee_reach", failures)
	_expect(rusty.get("noun", "") == "crowbar",
		"resolve('rusty crowbar').noun is crowbar", failures)
	_expect(Array(rusty.get("adjectives", [])) == ["rusty"],
		"resolve('rusty crowbar').adjectives is ['rusty']", failures)
	# core.json: melee_reach base damage is 22; rusty multiplies damage 0.8 → 17.6.
	var rusty_dmg: float = float(rusty.get("stats", {}).get("damage", 0.0))
	_expect(abs(rusty_dmg - 17.6) < 0.01,
		"rusty crowbar damage = 22 * 0.8 = 17.6 (got %.2f)" % rusty_dmg, failures)

	# Multi-adjective stacking — heavy + sharp on a pistol.
	var multi: Dictionary = WeaponDict.resolve("heavy sharp pistol")
	# pistol base damage 18; sharp ×1.25 = 22.5; heavy doesn't touch damage. So 22.5.
	var multi_dmg: float = float(multi.get("stats", {}).get("damage", 0.0))
	_expect(abs(multi_dmg - 22.5) < 0.01,
		"heavy sharp pistol damage = 18 * 1.25 = 22.5 (got %.2f)" % multi_dmg, failures)
	# heavy ×1.25 on fire_cooldown. pistol base 0.35 → 0.4375.
	var multi_cd: float = float(multi.get("stats", {}).get("fire_cooldown", 0.0))
	_expect(abs(multi_cd - 0.4375) < 0.001,
		"heavy sharp pistol fire_cooldown = 0.35 * 1.25 = 0.4375 (got %.4f)" % multi_cd, failures)

	# Tags merge: lightning adds "chain"; fire adds "dot".
	var elec: Dictionary = WeaponDict.resolve("lightning fan")
	_expect(elec.get("tags", []).has("chain"),
		"lightning fan has 'chain' tag", failures)
	var burny: Dictionary = WeaponDict.resolve("fire book")
	_expect(burny.get("tags", []).has("dot"),
		"fire book has 'dot' tag", failures)

	# Empty input → fist fallback.
	var blank: Dictionary = WeaponDict.resolve("")
	_expect(blank.get("noun", "") == "fist",
		"empty input resolves to 'fist'", failures)

	# Attack pattern dispatch is filled in for every archetype.
	var patterns := {}
	for noun in ["knife", "crowbar", "pistol", "shotgun", "microwave", "umbrella"]:
		var r: Dictionary = WeaponDict.resolve(noun)
		patterns[String(r.get("archetype", ""))] = String(r.get("attack_pattern", ""))
	for arch in ["melee_short", "melee_reach", "ranged_precision", "ranged_spread", "aoe", "utility"]:
		_expect(patterns.has(arch) and patterns[arch] != "",
			"attack_pattern populated for archetype %s" % arch, failures)

	if failures.is_empty():
		print("[test_weapon_dict] All assertions passed.")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)

func _expect(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append("FAIL: " + message)
