# ===================================================================
# KeywordManager.gd - Centralized Keyword & Tooltip System v0.2.0
# ===================================================================
# Singleton providing keyword definitions and text parsing for tooltips.
extends Node

## Strict icon paths for shorthand card descriptions. Used by CardData.generate_compact_description().
## "attack" and "holy_damage" are canonical keys for the Base + Bonus Holy UI.
const ICON_MAP: Dictionary = {
	"damage": "res://art/icons/status/attack.png",
	"attack": "res://art/icons/status/attack.png",
	"holy": "res://art/icons/status/holy_damage.png",
	"holy_damage": "res://art/icons/status/holy_damage.png",
	"block": "res://art/icons/status/block.png",
	"heal": "res://art/icons/status/Heal.png",
	"heart": "res://art/icons/status/Heal.png",
	"vulnerable": "res://art/icons/status/Vulnerable.png",
	"regeneration": "res://art/icons/status/Regeneration.png",
	"poison": "res://art/icons/status/Poison.png"
}

## Dictionary of all known keywords. Keys are internal names (e.g. "vulnerable").
## Each entry: title, icon, description (translation keys), color (hex), search_terms (for parsing)
## Icons MUST match ICON_MAP where applicable.
const KEYWORDS: Dictionary = {
	"vulnerable": {
		"title": "keyword.vulnerable.title",
		"icon": "res://art/icons/status/Vulnerable.png",
		"description": "keyword.vulnerable.description",
		"color": "#E74C3C",
		"search_terms": ["vulnerable", "zranitelný", "zranitelnost"]
	},
	"holy": {
		"title": "keyword.holy.title",
		"icon": "res://art/icons/status/holy_damage.png",  # ICON_MAP["holy_damage"]
		"description": "keyword.holy.description",
		"color": "#F1C40F",
		"search_terms": ["holy", "svatého", "svaté", "svatý"]
	},
	"regeneration": {
		"title": "keyword.regeneration.title",
		"icon": "res://art/icons/status/Regeneration.png",
		"description": "keyword.regeneration.description",
		"color": "#2ECC71",
		"search_terms": ["regeneration", "regenerace", "regeneraci"]
	},
	"burning": {
		"title": "keyword.burning.title",
		"icon": "res://art/icons/status/attack.png",  # ICON_MAP["damage"]
		"description": "keyword.burning.description",
		"color": "#E67E22",
		"search_terms": ["burn", "burning", "hoření", "hoří"]
	},
	"chilled": {
		"title": "keyword.chilled.title",
		"icon": "res://art/icons/status/Freeze.png",
		"description": "keyword.chilled.description",
		"color": "#3498DB",
		"search_terms": ["chilled", "prochlazený", "prochlazení"]
	},
	"frozen": {
		"title": "keyword.frozen.title",
		"icon": "res://art/icons/status/Freeze.png",
		"description": "keyword.frozen.description",
		"color": "#5DADE2",
		"search_terms": ["frozen", "zmražený", "zmražení"]
	},
	"aiming": {
		"title": "keyword.aiming.title",
		"icon": "res://art/icons/status/Aim.png",
		"description": "keyword.aiming.description",
		"color": "#9B59B6",
		"search_terms": ["aiming", "míří", "míření"]
	},
	"aura_devotion": {
		"title": "keyword.aura_devotion.title",
		"icon": "res://art/icons/status/block.png",
		"description": "keyword.aura_devotion.description",
		"color": "#F39C12",
		"search_terms": ["aura", "oddanost", "devotion"]
	},
	"consecrated_weapon": {
		"title": "keyword.consecrated_weapon.title",
		"icon": "res://art/icons/status/Attack_Heavy.png",
		"description": "keyword.consecrated_weapon.description",
		"color": "#F1C40F",
		"search_terms": ["consecrated", "požehnan", "blessed", "weapon"]
	},
	"block": {
		"title": "keyword.block.title",
		"icon": "res://art/icons/status/block.png",
		"description": "keyword.block.description",
		"color": "#95A5A6",
		"search_terms": ["block", "blok"]
	},
	"poison": {
		"title": "keyword.poison.title",
		"icon": "res://art/icons/status/Poison.png",
		"description": "keyword.poison.description",
		"color": "#9B59B6",
		"search_terms": ["poison", "jed"]
	},
	"taunted": {
		"title": "keyword.taunted.title",
		"icon": "res://art/icons/status/Aim.png",
		"description": "keyword.taunted.description",
		"color": "#E67E22",
		"search_terms": ["taunt", "taunted", "výzva", "provokace"]
	},
	"exhaust": {
		"title": "keyword.exhaust.title",
		"icon": "res://art/icons/status/attack.png",
		"description": "keyword.exhaust.description",
		"color": "#7F8C8D",
		"search_terms": ["exhaust", "vyčerp"]
	},
	"retain": {
		"title": "keyword.retain.title",
		"icon": "res://art/icons/artifact_fx/retain_badge.png",
		"description": "keyword.retain.description",
		"color": "#7EC8FF",
		"search_terms": ["retain", "ponech"]
	},
	"heal": {
		"title": "keyword.heal.title",
		"icon": "res://art/icons/status/Heal.png",
		"description": "keyword.heal.description",
		"color": "#2ECC71",
		"search_terms": ["heal", "léč", "vyléč", "restores hp", "vyléčí"]
	},
	"usage": {
		"title": "keyword.usage.title",
		"icon": "res://art/icons/status/block.png",
		"description": "keyword.usage.description",
		"color": "#9B59B6",
		"search_terms": ["usage", "použití", "uses", "omezen"]
	}
}


func _ready() -> void:
	pass


## Returns an Array of keyword keys found in the given text.
## Case-insensitive. Searches for matches within the text.
## Order: first occurrence in text, then by KEYWORDS definition order.
func parse_text_for_keywords(text: String) -> Array[String]:
	if text.is_empty():
		return []
	
	var found_keys: Array[String] = []
	var text_lower := text.to_lower()
	var seen := {}
	
	# Sort keyword keys by earliest match position to preserve reading order
	var matches: Array[Dictionary] = []
	for key in KEYWORDS.keys():
		var kw: Dictionary = KEYWORDS[key]
		var terms: Array = kw.get("search_terms", [key])
		var earliest_pos := -1
		for term in terms:
			var pos := text_lower.find(term.to_lower())
			if pos >= 0 and (earliest_pos < 0 or pos < earliest_pos):
				earliest_pos = pos
		if earliest_pos >= 0:
			matches.append({"key": key, "pos": earliest_pos})
	
	# Sort by position, then deduplicate
	matches.sort_custom(func(a, b): return a.pos < b.pos)
	for m in matches:
		var k: String = m.key
		if not seen.has(k):
			seen[k] = true
			found_keys.append(k)
	
	return found_keys


## Returns localized title for a keyword key.
func get_keyword_title(key: String) -> String:
	if not KEYWORDS.has(key):
		return key
	return tr(KEYWORDS[key].get("title", key))


## Returns localized description for a keyword key.
func get_keyword_description(key: String) -> String:
	if not KEYWORDS.has(key):
		return ""
	return tr(KEYWORDS[key].get("description", ""))


## Returns icon path for a keyword key.
func get_keyword_icon_path(key: String) -> String:
	if not KEYWORDS.has(key):
		return ""
	return KEYWORDS[key].get("icon", "")


## Returns hex color for a keyword key.
func get_keyword_color(key: String) -> String:
	if not KEYWORDS.has(key):
		return "#FFFFFF"
	return KEYWORDS[key].get("color", "#FFFFFF")


## Returns full keyword data for a key, or empty dict if not found.
func get_keyword_data(key: String) -> Dictionary:
	return KEYWORDS.get(key, {})


## Returns description for tooltip; for "holy" uses dynamic bonus (base 5 + PlayerData.holy_damage_bonus).
## In editor shows base only; in game shows base + passive skill bonus.
func get_keyword_description_dynamic(key: String, _card_data: CardData = null) -> String:
	if key == "holy":
		var base_bonus := 5  # UnitData.get_holy_damage_bonus vs Undead/Demon
		var total := base_bonus
		if not Engine.is_editor_hint():
			total = base_bonus + PlayerData.holy_damage_bonus
		return TranslationHelper.tr_format("keyword.holy.description_with_bonus", {"value": total})
	return get_keyword_description(key)


## Returns icon path for shorthand card descriptions. Keys: damage, holy, block, heal, vulnerable, regeneration.
static func get_icon_path(key: String) -> String:
	return ICON_MAP.get(key, "")
