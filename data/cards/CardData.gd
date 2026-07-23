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

# Enum pro vzácnost karet
enum CardRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	BASIC # Pro startovní karty, které se nemají objevovat jako odměny
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
	"""Vrátí lokalizovaný dlouhý popis karty"""
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
	if max_uses_before_removal > 0 and not keys.has("usage"):
		keys.append("usage")
	return keys

# Pomocná funkce pro zjištění, zda karta má určitý tag
func has_tag(tag_to_check: CardTag) -> bool:
	return tags.has(tag_to_check)

func can_be_used_by(player_class: ClassData, player_subclass: SubclassData) -> bool:
	if required_class == null and required_subclass == null:
		return true # Neutrální karta

	if required_subclass != null:
		return player_subclass == required_subclass
	
	if required_class != null:
		# Karta je pro hlavní třídu, pokud hráčova subclassa patří pod tuto hlavní třídu
		# NEBO pokud hráč nemá subclassu a jeho hlavní třída odpovídá.
		if player_subclass != null:
			return player_subclass.parent_class == required_class
		else:
			return player_class == required_class
			
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
const SHORTHAND_ICONS: Dictionary = {
	"damage": "res://art/icons/status/attack.png",
	"attack": "res://art/icons/status/attack.png",
	"holy": "res://art/icons/status/holy_damage.png",
	"holy_damage": "res://art/icons/status/holy_damage.png",
	"block": "res://art/icons/status/block.png",
	"heal": "res://art/icons/status/Heal.png",
	"heart": "res://art/icons/status/Heal.png",
	"vulnerable": "res://art/icons/status/Vulnerable.png",
	"regeneration": "res://art/icons/status/Regeneration.png"
}

const ICON_SIZE: int = 16

func generate_compact_description() -> String:
	"""Shorthand: one effect per line — [Value] [Icon]. Details live in the tooltip."""
	var parts: Array[String] = []
	for effect in effects:
		var line := _format_effect_shorthand(effect)
		if not line.is_empty():
			parts.append(line)
	if parts.is_empty():
		return tr(card_description)
	return "\n".join(parts).strip_edges()

func _img(icon_key: String, size: int = ICON_SIZE) -> String:
	"""Returns BBCode [img] tag for icon from KeywordManager.ICON_MAP (or SHORTHAND_ICONS in editor). NO icon if path missing."""
	var path: String = ""
	if not Engine.is_editor_hint():
		path = KeywordManager.get_icon_path(icon_key)
	if path.is_empty():
		path = SHORTHAND_ICONS.get(icon_key, "")
	if path.is_empty():
		return ""
	return "[img=%dx%d]%s[/img]" % [size, size, path]

func _num(x: int) -> String:
	"""Plain bold number — outline comes from RichTextLabel theme override."""
	return "[b]%d[/b]" % x

func _energy(x: int) -> String:
	"""Energy: [b][color=cyan]X Energy[/color][/b] - NO icon."""
	return "[b][color=cyan]%d %s[/color][/b]" % [x, tr("card.effect.energy")]

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
			return "[b][color=green]" + tr("card.effect.full_heal") + "[/color][/b]"
		
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
			# HOLY: show base value only (effect.value), so display matches .tres; +5/+3 vs Undead/Demon/Spirit in tooltip
			var dmg_val: int
			if effect.damage_type == CardEffectData.DamageType.HOLY:
				dmg_val = effect.value
			else:
				dmg_val = DamageCalculator.get_display_damage(effect.value) if not Engine.is_editor_hint() else effect.value
			var prefix := ""
			if effect.area_of_effect_type == CardEffectData.AreaOfEffectType.ALL_ON_GRID:
				prefix = tr("card.effect.to_all") + " "
			if effect.damage_type == CardEffectData.DamageType.HOLY:
				return prefix + _num(dmg_val) + " " + _img("holy_damage")
			var icon_key := "damage"
			var cond := _get_condition_shorthand(effect, "dmg")
			if cond != "":
				return prefix + _num(dmg_val) + " " + _img(icon_key) + " " + cond
			return prefix + _num(dmg_val) + " " + _img(icon_key)
		
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
			return "[b][color=orange]" + tr("card.effect.exhaust_keyword") + "[/color][/b]"
		
		CardEffectData.EffectType.GAIN_EXTRA_MOVE:
			return "[b]" + tr("card.effect.gain_extra_move") + "[/b]"
		
		CardEffectData.EffectType.MODIFY_INITIATIVE_NEXT_ROUND:
			var sign_str := "+" if effect.value >= 0 else ""
			return "[b][color=yellow]%s%d %s[/color][/b]" % [sign_str, effect.value, tr("card.effect.initiative")]
		
		CardEffectData.EffectType.SUMMON_UNIT:
			return "[b]" + tr("card.effect.summon") + "[/b]"
		
		_:
			return ""

func _format_status_shorthand(effect: CardEffectData) -> String:
	"""APPLY_STATUS: vulnerable/regeneration use icons. Others as keyword or plain."""
	match effect.string_value:
		"vulnerable":
			return _img("vulnerable") + " " + _turns(effect.value)
		"regeneration":
			return _num(effect.value) + " " + _img("regeneration")
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
			return TranslationHelper.tr_format("status.aiming", {"value": effect.value - 100})
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

func get_display_description() -> String:
	"""Vrátí automaticky generovaný stručný popis nebo původní s bonusy"""
	# Použijeme nový automatický generátor
	var compact_desc = generate_compact_description()
	
	# Pokud je nový popis příliš krátký nebo prázdný, použijeme původní
	if compact_desc.length() < 3:
		compact_desc = tr(card_description)
	
	return compact_desc
