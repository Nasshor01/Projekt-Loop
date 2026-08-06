# res://data/cards/CardData.gd
class_name CardData
extends Resource

# Enum pro typy karet, jak je máte v plánu. Nové tagy PŘIDÁVEJ NA KONEC (zachová indexy v .tres).
enum CardTag {
	ATTACK,
	SPELL,
	SUMMON,
	BUFF,
	DEBUFF, # Přidáno pro rozlišení od BUFF
	MOVE,
	HEAL,
	POWER,
	UTILITY, # Obecná užitková karta
	ONE_TIME_USE # Jednorázová karta – po použití se natrvalo odstraní z balíčku
}

# Enum pro vzácnost karet.
# Pořadí hodnot NEMĚŇ — .tres ukládají int indexy.
# Platné rarity ve hře: BASIC, COMMON, RARE, EPIC, LEGENDARY (+ Curse frame přes card_id).
# UNCOMMON je deprecated (zrušeno) — ponecháno jen kvůli kompatibilitě starých dat.
enum CardRarity {
	COMMON,
	UNCOMMON, ## DEPRECATED — nepoužívat; mapuje se na COMMON
	RARE,
	EPIC,
	LEGENDARY,
	BASIC # Startovní karty — neobjevují se jako odměny
}

@export var card_id: String = "unique_card_id" # Unikátní identifikátor karty
@export var card_name: String = "Název karty"
@export_multiline var card_description: String = "Popis efektu karty." # Klíč pro tr() nebo text; ve hře se překládá
## Popis jen pro vývojáře – vidět v editoru v .tres, ve hře se nikde nezobrazuje. Můžeš sem psát, co karta přesně dělá.
@export_multiline var editor_description: String = ""

@export var cost: int = 1 # Cena zahrání karty (energie/mana)
@export var range_type: EffectRangeType = EffectRangeType.MELEE # Budeme muset vytvořit enum EffectRangeType
@export var range_value: int = 1 # Např. dosah v buňkách

@export var tags: Array[CardTag] = [] # Tagy karty (může mít více tagů)
@export var rarity: CardRarity = CardRarity.COMMON

# Reference na třídu a subclassu, zatím jako String ID, později můžeme změnit na Resource odkazy
@export var required_class: ClassData = null 
@export var required_subclass: SubclassData = null

@export var artwork: Texture2D # Obrázek karty

# Pole efektů, které karta způsobí
# Použijeme náš dříve vytvořený CardEffectData
@export var effects: Array[CardEffectData] = []
@export var is_upgraded: bool = false
@export var upgraded_version: CardData = null

# Limit použití karty za tah (pro secret debuffy)
@export var max_uses_per_turn: int = -1  # -1 = neomezeně
@export var debuff_on_overuse: Dictionary = {}  # {"damage": 5, "energy_loss": 2, "status": "vulnerable", "status_duration": 2}

## Maximální počet použití karty za celý run; po vyčerpání se karta natrvalo odstraní z balíčku.
## -1 = bez limitu (normální/exhaust), 1 = jednorázová, 2 = 2× použití pak zmizí. Zobrazuje se jako "usage x/x".
@export var max_uses_before_removal: int = -1


# Enum pro typy dosahu - PŘESUNUTO SEM z CardEffectData, protože dosah je spíše vlastnost karty jako celku
# než jednotlivého efektu (i když i to by šlo modelovat). Pro zjednodušení zatím takto.
enum EffectRangeType {
	NONE,           # Žádný specifický dosah (např. buff na sebe)
	SELF,           # Jen na sebe
	MELEE,          # Na sousední buňku
	RANGED_FIXED,   # Pevný dosah X buněk
	RANGED_LINE,    # V linii X buněk
	GRID_AOE,       # Oblast na mřížce (definovaná v CardEffectData.AreaOfEffectType)
	FULL_BOARD,     # Celé bojiště
	PLAYER_CENTERED_AOE  # AOE vycházející z pozice hráče (ROW/COLUMN/SQUARE kolem hráče)
}


func _init(p_id = "", p_name = "Karta", p_desc = "", p_cost = 1, p_artwork = null):
	card_id = p_id
	card_name = p_name
	card_description = p_desc
	cost = p_cost
	artwork = p_artwork
	# Inicializaci efektů a dalších polí zde neprovádíme defaultně,
	# ty se budou nastavovat přímo v editoru nebo specifickým kódem.

# Pomocná funkce pro přidání efektu (může se hodit při generování karet z kódu)
func add_effect(effect: CardEffectData):
	if effect != null:
		effects.append(effect)

func get_localized_name() -> String:
	"""Vrátí lokalizovaný název karty"""
	return tr(card_name)

func get_localized_description() -> String:
	"""Full tooltip description from translations. Holy is a keyword, not rewritten prose."""
	return tr(card_description)

## Vrátí klíče keywordů odvozené z efektů karty (pro tooltip – Holy, Block, Heal, Exhaust, atd.).
## Slouží k zobrazení tagů/ikon v tooltipu i když v textu popisu slovo není.
func get_keywords_from_effects() -> Array[String]:
	var keys: Array[String] = []
	for effect in effects:
		if effect.effect_type == CardEffectData.EffectType.DEAL_DAMAGE and effect.damage_type == CardEffectData.DamageType.HOLY:
			if not keys.has("holy"):
				keys.append("holy")
		if effect.effect_type == CardEffectData.EffectType.GAIN_BLOCK:
			if not keys.has("block"):
				keys.append("block")
		if effect.effect_type == CardEffectData.EffectType.HEAL_UNIT or effect.effect_type == CardEffectData.EffectType.HEAL_TO_FULL:
			if not keys.has("heal"):
				keys.append("heal")
		if effect.effect_type == CardEffectData.EffectType.EXHAUST:
			if not keys.has("exhaust"):
				keys.append("exhaust")
		if effect.effect_type == CardEffectData.EffectType.APPLY_STATUS:
			if effect.string_value == "vulnerable":
				if not keys.has("vulnerable"):
					keys.append("vulnerable")
			elif effect.string_value == "regeneration":
				if not keys.has("regeneration"):
					keys.append("regeneration")
			elif effect.string_value == "aura_devotion" or effect.string_value == "aura_devotion_plus":
				if not keys.has("aura_devotion"):
					keys.append("aura_devotion")
			elif effect.string_value == "consecrated_weapon":
				if not keys.has("consecrated_weapon"):
					keys.append("consecrated_weapon")
			elif effect.string_value == "poison":
				if not keys.has("poison"):
					keys.append("poison")
	if max_uses_before_removal > 0 and not keys.has("usage"):
		keys.append("usage")
	if has_meta("artifact_retain") and bool(get_meta("artifact_retain")) and not keys.has("retain"):
		keys.append("retain")
	return keys

# Pomocná funkce pro zjištění, zda karta má určitý tag
func has_tag(tag_to_check: CardTag) -> bool:
	return tags.has(tag_to_check)

func can_be_used_by(player_class: ClassData, player_subclass: SubclassData) -> bool:
	if required_class == null and required_subclass == null:
		return true # Neutrální karta

	if required_subclass != null:
		if player_subclass == null:
			return false
		if player_subclass == required_subclass:
			return true
		return player_subclass.subclass_id == required_subclass.subclass_id
	
	if required_class != null:
		# Karta je pro hlavní třídu, pokud hráčova subclassa patří pod tuto hlavní třídu
		# NEBO pokud hráč nemá subclassu a jeho hlavní třída odpovídá.
		if player_subclass != null:
			if player_subclass.parent_class == required_class:
				return true
			if player_subclass.parent_class != null and player_subclass.parent_class.class_id == required_class.class_id:
				return true
			return false
		else:
			if player_class == required_class:
				return true
			return player_class != null and player_class.class_id == required_class.class_id
			
	return false # Nemělo by nastat, pokud je logika správná

func get_damage_bonus() -> int:
	"""Vrátí celkový bonus k poškození z pasivních skillů a artefaktů"""
	var bonus = 0
	
	# V editoru nejsou autoload singletony dostupné
	if Engine.is_editor_hint():
		return 0
	
	# V Godot jsou autoload singletony dostupné přímo jako globální proměnné
	# Za běhu jsou vždy dostupné, takže můžeme přistoupit přímo
	
	# Bonus z pasivních skillů (PlayerData je autoload singleton)
	bonus += PlayerData.global_card_damage_bonus
	
	# Bonus z artefaktů (ArtifactManager je autoload singleton)
	var context = {
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp,
		"current_energy": PlayerData.current_energy
	}
	bonus += ArtifactManager.get_card_damage_bonus(context)
	
	return bonus

## Shorthand icon paths. Keep in sync with KeywordManager.ICON_MAP. Fallback when KeywordManager not available (e.g. editor).
const _KeywordManagerScript := preload("res://scripts/autoload/KeywordManager.gd")
const SHORTHAND_ICONS: Dictionary = {
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

const ICON_SIZE: int = 16

## Active BBCode [img] size for the current shorthand pass (set by generate_compact_description).
var _shorthand_icon_px: int = ICON_SIZE

## BBCode accents on LIGHT description panel (dark ink — RTL outline is unreliable).
const BB_ENERGY := "#1a4a8c"
const BB_HEAL := "#1a6a28"
const BB_EXHAUST := "#8a4010"
const BB_INITIATIVE := "#5a3a00"

## Face keyword colors for verbal keywords on white description panel.
const FACE_KEYWORD_COLORS := {
	"holy": {"color": "#8a6810", "words": ["Holy", "Svaté"]},
	"exhaust": {"color": "#8a4010", "words": ["Exhaust", "Vyčerpání"]},
	"retain": {"color": "#1a5080", "words": ["Retain", "Ponechání"]},
	"block": {"color": "#1a4a8c", "words": ["Block", "Blok"]},
	"vulnerable": {"color": "#5a2080", "words": ["Vulnerable", "Zranitelnost"]},
	"poison": {"color": "#1a6a28", "words": ["Poison", "Jed"]},
}

## Face line order when a card has multiple effects.
const FACE_PRIO_DAMAGE := 0
const FACE_PRIO_BLOCK := 1
const FACE_PRIO_HEAL := 2
const FACE_PRIO_KEYWORD_ICON := 3
const FACE_PRIO_VERBAL := 4

func generate_compact_description(icon_px: int = ICON_SIZE) -> String:
	"""Shorthand face: N+icon lines in fixed order. Full STS text stays in tooltip."""
	_shorthand_icon_px = maxi(icon_px, 8)
	var entries: Array = [] # {prio, index, line}
	var has_holy_damage := false
	for i in range(effects.size()):
		var effect: CardEffectData = effects[i]
		if effect != null and effect.effect_type == CardEffectData.EffectType.DEAL_DAMAGE \
				and effect.damage_type == CardEffectData.DamageType.HOLY:
			has_holy_damage = true
		var line := _format_effect_shorthand(effect)
		if line.is_empty():
			continue
		entries.append({
			"prio": _face_line_priority(effect),
			"index": i,
			"line": line,
		})
	# Holy = verbal keyword under damage (not a special holy-damage icon).
	if has_holy_damage:
		entries.append({
			"prio": FACE_PRIO_VERBAL,
			"index": -1, # before Exhaust / other verbal lines
			"line": _format_holy_keyword_line(),
		})
	# Oathbreaker (and similar): permanent Retain stamped as meta on this instance.
	if has_meta("artifact_retain") and bool(get_meta("artifact_retain")):
		entries.append({
			"prio": FACE_PRIO_VERBAL,
			"index": 9999,
			"line": _format_retain_keyword_line(),
		})
	if entries.is_empty():
		return get_localized_description()
	entries.sort_custom(func(a, b):
		if a["prio"] != b["prio"]:
			return a["prio"] < b["prio"]
		return a["index"] < b["index"]
	)
	var lines: Array[String] = []
	for e in entries:
		lines.append(str(e["line"]))
	return "\n".join(lines).strip_edges()

func _format_holy_keyword_line() -> String:
	"""Localized Holy / Svaté keyword title for the face."""
	return "[b][color=%s]%s[/color][/b]" % [FACE_KEYWORD_COLORS["holy"]["color"], tr("keyword.holy.title")]


func _format_retain_keyword_line() -> String:
	"""Localized Retain / Ponechání keyword title for the face."""
	return "[b][color=%s]%s[/color][/b]" % [FACE_KEYWORD_COLORS["retain"]["color"], tr("keyword.retain.title")]

func _face_line_priority(effect: CardEffectData) -> int:
	"""damage → block → heal/regen → keyword icons → verbal (Exhaust…)."""
	if effect == null:
		return FACE_PRIO_VERBAL
	match effect.effect_type:
		CardEffectData.EffectType.DEAL_DAMAGE, \
		CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK, \
		CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK:
			return FACE_PRIO_DAMAGE
		CardEffectData.EffectType.GAIN_BLOCK:
			return FACE_PRIO_BLOCK
		CardEffectData.EffectType.HEAL_UNIT, \
		CardEffectData.EffectType.HEAL_TO_FULL:
			return FACE_PRIO_HEAL
		CardEffectData.EffectType.APPLY_STATUS:
			match effect.string_value:
				"regeneration":
					return FACE_PRIO_HEAL
				"vulnerable", "poison", "consecrated_weapon", "burning", "chilled", "aiming", \
				"aura_devotion", "aura_devotion_plus":
					return FACE_PRIO_KEYWORD_ICON
				_:
					return FACE_PRIO_VERBAL
		CardEffectData.EffectType.PLACE_TERRAIN:
			# Damage-on-enter terrains render as N+damage icon.
			return FACE_PRIO_DAMAGE
		CardEffectData.EffectType.EXHAUST:
			return FACE_PRIO_VERBAL
		_:
			return FACE_PRIO_VERBAL

func _img(icon_key: String, size: int = -1) -> String:
	"""Returns BBCode [img] tag for icon from KeywordManager.ICON_MAP (or SHORTHAND_ICONS in editor). NO icon if path missing.
	Default size follows the current shorthand pass (_shorthand_icon_px), not a fixed 16px."""
	var px := size if size > 0 else _shorthand_icon_px
	var path: String = ""
	if not Engine.is_editor_hint():
		path = _KeywordManagerScript.get_icon_path(icon_key)
	if path.is_empty():
		path = SHORTHAND_ICONS.get(icon_key, "")
	if path.is_empty():
		return ""
	return "[img=%dx%d]%s[/img]" % [px, px, path]

func _num(x: int) -> String:
	"""Face shorthand number — plain text (no [b]) so RichTextLabel keeps push_font size."""
	return str(x)

func _energy(x: int) -> String:
	"""Energy shorthand — light cyan accent (readable on white text + outline)."""
	return "[b][color=%s]%d %s[/color][/b]" % [BB_ENERGY, x, tr("card.effect.energy")]

func _turns(x: int) -> String:
	"""Turns: [b]X turns[/b] - NO icon."""
	return "[b]%d %s[/b]" % [x, tr("card.effect.turns")]

func _format_effect_shorthand(effect: CardEffectData) -> String:
	"""Formats a single effect as shorthand: [Value] [Icon]. NO full sentences."""
	match effect.effect_type:
		CardEffectData.EffectType.HEAL_UNIT:
			var val := effect.value
			var cond := _get_condition_shorthand(effect, "heal")
			if cond != "":
				return _num(val) + " " + _img("heal") + " " + cond
			return _num(val) + " " + _img("heal")
		
		CardEffectData.EffectType.HEAL_TO_FULL:
			return "[b][color=%s]" % BB_HEAL + tr("card.effect.full_heal") + "[/color][/b]"
		
		CardEffectData.EffectType.GAIN_BLOCK:
			var block_val := effect.value
			if effect.string_value == "max_hp" and not Engine.is_editor_hint():
				block_val = PlayerData.max_hp
			elif effect.string_value == "current_hp" and not Engine.is_editor_hint():
				block_val = PlayerData.current_hp
			var cond := _get_condition_shorthand(effect, "block")
			if cond != "":
				return _num(block_val) + " " + _img("block") + " " + cond
			return _num(block_val) + " " + _img("block")
		
		CardEffectData.EffectType.DEAL_DAMAGE:
			# HOLY: base value + normal damage icon; keyword "Holy" is a separate face line.
			# +5 vs Undead/Demon stays in tooltip / combat math.
			var dmg_val: int
			if effect.damage_type == CardEffectData.DamageType.HOLY:
				dmg_val = effect.value
			else:
				dmg_val = DamageCalculator.get_display_damage(effect.value) if not Engine.is_editor_hint() else effect.value
			var prefix := ""
			if effect.area_of_effect_type == CardEffectData.AreaOfEffectType.ALL_ON_GRID:
				prefix = tr("card.effect.to_all") + " "
			var cond := _get_condition_shorthand(effect, "dmg")
			if cond != "":
				return prefix + _num(dmg_val) + " " + _img("damage") + " " + cond
			return prefix + _num(dmg_val) + " " + _img("damage")
		
		CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK:
			return "[b]" + tr("card.effect.deal_damage_from_block") + "[/b]"
		
		CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK:
			return "[b]" + tr("card.effect.deal_double_damage_from_block") + "[/b]"
		
		CardEffectData.EffectType.DRAW_CARDS:
			var t := TranslationHelper.tr_single("card.effect.draw_cards", effect.value)
			t = t.replace("card", "cards") if effect.value > 1 else t
			return "[b]" + t + "[/b]"
		
		CardEffectData.EffectType.GAIN_ENERGY:
			return _energy(effect.value)
		
		CardEffectData.EffectType.APPLY_STATUS:
			return _format_status_shorthand(effect)
		
		CardEffectData.EffectType.EXHAUST:
			return "[b][color=%s]" % BB_EXHAUST + tr("card.effect.exhaust_keyword") + "[/color][/b]"
		
		CardEffectData.EffectType.GAIN_EXTRA_MOVE:
			return "[b]+%d %s[/b]" % [maxi(1, effect.value), tr("card.effect.move_label")]
		
		CardEffectData.EffectType.MODIFY_INITIATIVE_NEXT_ROUND:
			var sign_str := "+" if effect.value >= 0 else ""
			return "[b][color=%s]%s%d %s[/color][/b]" % [BB_INITIATIVE, sign_str, effect.value, tr("card.effect.initiative")]
		
		CardEffectData.EffectType.SUMMON_UNIT:
			return "[b]" + tr("card.effect.summon") + "[/b]"
		
		CardEffectData.EffectType.PLACE_TERRAIN:
			return _format_place_terrain_shorthand(effect)
		
		_:
			return ""

func _format_status_shorthand(effect: CardEffectData) -> String:
	"""APPLY_STATUS: vulnerable/regeneration use icons. Others as keyword or plain."""
	match effect.string_value:
		"vulnerable":
			return _img("vulnerable") + " " + _turns(effect.value)
		"regeneration":
			return _num(effect.value) + " " + _img("regeneration")
		"poison":
			# value = DMG/turn; aoe_param_x = počet kol
			var turns = effect.aoe_param_x if effect.aoe_param_x > 0 else 3
			return _num(effect.value) + " " + _img("poison") + " " + _turns(turns)
		"aura_devotion", "aura_devotion_plus":
			return _num(effect.value) + " " + _img("block")
		"consecrated_weapon":
			return _num(effect.value) + " " + _img("holy")
		"burning", "chilled", "aiming":
			return _num(effect.value) + " " + _img("damage")
		"frozen":
			return "[b]" + tr("status.frozen") + "[/b]"
		"defensive_stance":
			return "[b]" + tr("status.defensive_stance.short") + "[/b]"
		"draw_plus_one":
			return "[b]" + tr("status.draw_plus_one.short") + "[/b]"
		"remove_all_debuffs":
			return "[b]" + tr("status.remove_all_debuffs") + "[/b]"
		_:
			var s := _get_status_display_description(effect)
			if s.is_empty():
				s = _get_status_description(effect)
			return "[b]" + s + "[/b]"


func _format_place_terrain_shorthand(effect: CardEffectData) -> String:
	"""PLACE_TERRAIN: show effect (dmg / Slow), never the terrain display name
	(avoids 'Bear Trap' + 'Spike Trap' double title on the card face)."""
	if effect.string_value.is_empty() or not ResourceLoader.exists(effect.string_value):
		return "[b]" + tr("card.effect.place_terrain") + "[/b]"
	var terrain = load(effect.string_value)
	if terrain == null:
		return "[b]" + tr("card.effect.place_terrain") + "[/b]"
	var effect_type = terrain.effect_type if "effect_type" in terrain else 0
	if effect_type == TerrainData.TerrainEffect.DAMAGE_ON_ENTER:
		var dmg: int = int(terrain.effect_numeric_value) if "effect_numeric_value" in terrain else 0
		if dmg > 0:
			return _num(dmg) + " " + _img("damage")
	if effect_type == TerrainData.TerrainEffect.APPLY_STATUS_ON_ENTER:
		var status_id := str(terrain.effect_string_value) if "effect_string_value" in terrain else ""
		if status_id.to_lower() == "slow":
			return "[b]" + tr("status.slow.short") + "[/b]"
	return "[b]" + tr("card.effect.place_terrain") + "[/b]"


func _get_terrain_display_name(path: String) -> String:
	if path.is_empty() or not ResourceLoader.exists(path):
		return ""
	var terrain = load(path)
	if terrain == null:
		return ""
	if terrain.has_method("get_localized_name"):
		return terrain.get_localized_name()
	if "terrain_name" in terrain:
		return tr(str(terrain.terrain_name))
	return ""

func _get_condition_shorthand(effect: CardEffectData, effect_type: String) -> String:
	"""Compact condition suffix. Returns empty if no condition."""
	if not effect.has_condition or effect.conditional_bonus_value <= 0:
		return ""
	var cond_type := effect.condition_type
	var cond_val := effect.condition_value
	var bonus := effect.conditional_bonus_value
	if cond_type == "damage_per_block":
		return tr("card.condition.per_block")
	var cond_desc := _get_condition_description(cond_type, cond_val)
	var bonus_str := ""
	match effect_type:
		"dmg":
			bonus_str = "+" + _num(bonus)
		"block":
			bonus_str = "+" + _num(bonus) + " " + _img("block")
		"heal":
			bonus_str = "+" + _num(bonus) + " " + _img("heal")
		_:
			bonus_str = "+" + _num(bonus)
	return cond_desc + ": " + bonus_str

func _get_target_description(effect: CardEffectData) -> String:
	"""Vrátí stručný popis cíle efektu"""
	match effect.target_type:
		CardEffectData.TargetType.ALL_ENEMY_UNITS:
			if effect.area_of_effect_type == CardEffectData.AreaOfEffectType.ALL_ON_GRID:
				return ""  # "To all" už je v textu
			return tr("card.target.all")
		CardEffectData.TargetType.ALL_ALLY_UNITS:
			return tr("card.target.allies")
		CardEffectData.TargetType.SELF_UNIT:
			return ""  # Implicitní pro blok/léčení
		_:
			return ""  # Pro SELECTED je cíl jasný z kontextu

func _get_status_description(effect: CardEffectData) -> String:
	"""Localized status label — never return raw string_value IDs on the card face."""
	if effect.string_value.is_empty():
		return tr("status.unknown")
	var key := "status.%s" % effect.string_value
	var localized := tr(key)
	if localized != key:
		return localized
	var short_key := "status.%s.short" % effect.string_value
	var short_localized := tr(short_key)
	if short_localized != short_key:
		return short_localized
	# Last resort: humanize snake_case without leaking the raw id as-is look
	return effect.string_value.replace("_", " ").capitalize()

func _get_status_display_description(effect: CardEffectData) -> String:
	"""Vrátí pěkný popis status efektu pro zobrazení"""
	match effect.string_value:
		"aura_devotion":
			return TranslationHelper.tr_format("status.aura_devotion", {"value": effect.value})
		"aura_devotion_plus":
			return TranslationHelper.tr_format("status.aura_devotion_plus", {"value": effect.value})
		"regeneration":
			return TranslationHelper.tr_format("status.regeneration", {"value": effect.value})
		"consecrated_weapon":
			return TranslationHelper.tr_format("status.consecrated_weapon", {"value": effect.value})
		"vulnerable":
			return TranslationHelper.tr_format("status.vulnerable", {"value": effect.value})
		"burning":
			return TranslationHelper.tr_format("status.burning", {"value": effect.value})
		"chilled":
			return TranslationHelper.tr_format("status.chilled", {"value": effect.value})
		"frozen":
			return tr("status.frozen")
		"aiming":
			# Status value is absolute % of base damage (250 = 250% / 2.5×).
			return TranslationHelper.tr_format("status.aiming", {"value": effect.value})
		"remove_all_debuffs":
			return tr("status.remove_all_debuffs")
		"defensive_stance":
			return tr("status.defensive_stance.short")
		"draw_plus_one":
			return tr("status.draw_plus_one.short")
		_:
			return ""

func _get_condition_description(cond_type: String, cond_value: int) -> String:
	"""Vrátí stručný popis podmínky"""
	match cond_type:
		"target_health_above_percent":
			return TranslationHelper.tr_format("card.condition.target_above_hp", {"value": cond_value})
		"target_health_below_percent":
			return TranslationHelper.tr_format("card.condition.target_below_hp", {"value": cond_value})
		"health_above_percent":
			return TranslationHelper.tr_format("card.condition.if_you_above_hp", {"value": cond_value})
		"health_below_percent":
			return TranslationHelper.tr_format("card.condition.if_you_below_hp", {"value": cond_value})
		"block_above":
			return TranslationHelper.tr_format("card.condition.if_block_above", {"value": cond_value})
		"block_below":
			return TranslationHelper.tr_format("card.condition.if_block_below", {"value": cond_value})
		"target_has_debuff":
			return tr("card.condition.if_has_debuff").trim_suffix(":")
		"took_damage_last_turn":
			return tr("card.condition.took_damage").trim_suffix(":")
		_:
			return tr("card.condition.default")

func _format_conditional_effect(conditional: Dictionary, effect_type: String = "dmg", is_holy: bool = false, replaces: bool = false) -> String:
	"""Formátuje podmíněný efekt do stručného popisu"""
	if conditional == null:
		return ""
	
	var cond_type = conditional.get("type", "")
	var cond_value = conditional.get("value", 0)
	var bonus = conditional.get("bonus", 0)
	
	if bonus <= 0 and not replaces:
		return ""
	
	# Vytvoříme text pro bonus
	var bonus_text = ""
	if effect_type == "dmg":
		if replaces:
			if is_holy:
				bonus_text = TranslationHelper.tr_format("card.effect.holy_dmg", {"value": bonus})
			else:
				bonus_text = TranslationHelper.tr_format("card.effect.dmg", {"value": bonus})
		else:
			if is_holy:
				bonus_text = TranslationHelper.tr_format("card.effect.plus_holy_dmg", {"value": bonus})
			else:
				bonus_text = str(bonus) + " " + tr("damage.normal")
	elif effect_type == "blok":
		if replaces:
			bonus_text = TranslationHelper.tr_format("card.effect.gain_block", {"value": bonus}).trim_prefix("+")
		else:
			bonus_text = TranslationHelper.tr_single("card.effect.gain_block", bonus)
	elif effect_type == "HP":
		if replaces:
			bonus_text = TranslationHelper.tr_single("card.effect.heal", bonus)
		else:
			bonus_text = TranslationHelper.tr_single("card.effect.heal", bonus)
	
	match cond_type:
		"target_health_above_percent":
			return TranslationHelper.tr_format("card.condition.target_above_hp", {"value": cond_value}) + ": " + bonus_text
		"target_health_below_percent":
			return TranslationHelper.tr_format("card.condition.target_below_hp", {"value": cond_value}) + ": " + bonus_text
		"health_above_percent":
			return TranslationHelper.tr_format("card.condition.if_you_above_hp", {"value": cond_value}) + " " + bonus_text
		"health_below_percent":
			return TranslationHelper.tr_format("card.condition.if_you_below_hp", {"value": cond_value}) + " " + bonus_text
		"block_above":
			return TranslationHelper.tr_format("card.condition.if_block_above", {"value": cond_value}) + " " + bonus_text
		"block_below":
			return TranslationHelper.tr_format("card.condition.if_block_below", {"value": cond_value}) + " " + bonus_text
		"target_has_debuff":
			return tr("card.condition.if_has_debuff") + " " + bonus_text
		"damage_per_block":
			return tr("card.condition.per_block")  # Speciální případ - násobitel
		"took_damage_last_turn":
			return tr("card.condition.took_damage") + " " + bonus_text
		_:
			return tr("card.condition.default") + ": " + bonus_text

func get_display_description(icon_size: int = ICON_SIZE) -> String:
	"""Card face = icon shorthand (ordered). Tooltip keeps full localized text."""
	var compact := generate_compact_description(icon_size)
	if compact.length() < 3:
		compact = get_localized_description()
	return _colorize_face_keywords(compact)

func _is_face_keyword_word_char(ch: String) -> bool:
	if ch.is_empty():
		return false
	var c := ch.unicode_at(0)
	# ASCII letter/digit/_ or non-ASCII letter (CS accents).
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c > 127

func _is_whole_face_keyword(text: String, idx: int, word: String) -> bool:
	if idx > 0 and _is_face_keyword_word_char(text.substr(idx - 1, 1)):
		return false
	var end := idx + word.length()
	if end < text.length():
		var next := text.substr(end, 1)
		# Don't colorize filenames (Vulnerable.png) or other identifiers.
		if _is_face_keyword_word_char(next) or next == ".":
			return false
	return true

func _is_inside_face_img_tag(text: String, idx: int) -> bool:
	"""True when idx lies inside an [img=…]…[/img] span (never colorize paths)."""
	var open_idx := text.rfind("[img=", idx)
	if open_idx < 0:
		return false
	var close_idx := text.find("[/img]", open_idx)
	if close_idx < 0:
		close_idx = text.find("[/]", open_idx)
	if close_idx < 0:
		return false
	return idx < close_idx

func _colorize_face_keywords(text: String) -> String:
	"""Wrap Holy / Exhaust / Block / Vulnerable / Poison (EN+CS titles) in [color]."""
	if text.is_empty():
		return text
	var result := text
	# Longer words first (Zranitelnost before shorter collisions).
	var entries: Array = []
	for key in FACE_KEYWORD_COLORS.keys():
		var data: Dictionary = FACE_KEYWORD_COLORS[key]
		var color: String = data["color"]
		for word in data["words"]:
			entries.append({"word": str(word), "color": color})
	entries.sort_custom(func(a, b): return str(a["word"]).length() > str(b["word"]).length())
	for entry in entries:
		var word: String = entry["word"]
		var color: String = entry["color"]
		if word.is_empty() or not result.contains(word):
			continue
		var colored := "[color=%s]%s[/color]" % [color, word]
		var out := ""
		var i := 0
		while i < result.length():
			var idx := result.find(word, i)
			if idx < 0:
				out += result.substr(i)
				break
			if _is_inside_face_img_tag(result, idx) or not _is_whole_face_keyword(result, idx, word):
				out += result.substr(i, idx + word.length() - i)
				i = idx + word.length()
				continue
			# Already inside a color tag for this span?
			var before := result.substr(0, idx)
			if before.ends_with("[color=%s]" % color):
				out += result.substr(i, idx + word.length() - i)
				i = idx + word.length()
				continue
			out += result.substr(i, idx - i)
			out += colored
			i = idx + word.length()
		result = out
	return result
