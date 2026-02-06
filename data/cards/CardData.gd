# res://data/cards/CardData.gd
class_name CardData
extends Resource

# Enum pro typy karet, jak je máte v plánu
enum CardTag {
	ATTACK,
	SPELL,
	SUMMON,
	BUFF,
	DEBUFF, # Přidáno pro rozlišení od BUFF
	MOVE,
	HEAL,
	POWER,
	UTILITY # Obecná užitková karta
	# Můžete přidat další dle potřeby
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
@export_multiline var card_description: String = "Popis efektu karty." # Víceřádkový text pro editor

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


# Enum pro typy dosahu - PŘESUNUTO SEM z CardEffectData, protože dosah je spíše vlastnost karty jako celku
# než jednotlivého efektu (i když i to by šlo modelovat). Pro zjednodušení zatím takto.
enum EffectRangeType {
	NONE,           # Žádný specifický dosah (např. buff na sebe)
	SELF,           # Jen na sebe
	MELEE,          # Na sousední buňku
	RANGED_FIXED,   # Pevný dosah X buněk
	RANGED_LINE,    # V linii X buněk
	GRID_AOE,       # Oblast na mřížce (definovaná v CardEffectData.AreaOfEffectType)
	FULL_BOARD      # Celé bojiště
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

func generate_compact_description() -> String:
	"""Automaticky vygeneruje stručný popis z efektů karty"""
	var parts: Array[String] = []
	var damage_bonus = get_damage_bonus()
	
	# Seskupíme efekty podle typu
	var damage_effects: Array[Dictionary] = []  # {value, target, is_holy}
	var block_effects: Array[Dictionary] = []  # {value, target}
	var heal_effects: Array[Dictionary] = []  # {value, target}
	var other_effects: Array[String] = []
	
	for effect in effects:
		var effect_value = effect.value
		var target_desc = _get_target_description(effect)
		
		match effect.effect_type:
			CardEffectData.EffectType.DEAL_DAMAGE:
				# Zjistíme, jestli je to svaté poškození
				var is_holy = effect.damage_type == CardEffectData.DamageType.HOLY
				var final_damage = effect_value + damage_bonus
				var conditional_info = null
				
				# Pokud má podmíněný bonus, připravíme informace o něm
				if effect.has_condition and effect.conditional_bonus_value > 0:
					conditional_info = {
						"type": effect.condition_type,
						"value": effect.condition_value,
						"bonus": effect.conditional_bonus_value
					}
				
				damage_effects.append({
					"value": final_damage,
					"base_value": effect_value,
					"target": target_desc,
					"is_holy": is_holy,
					"aoe": effect.area_of_effect_type,
					"conditional": conditional_info
				})
			
			CardEffectData.EffectType.GAIN_BLOCK:
				var block_conditional = null
				if effect.has_condition and effect.conditional_bonus_value > 0:
					block_conditional = {
						"type": effect.condition_type,
						"value": effect.condition_value,
						"bonus": effect.conditional_bonus_value
					}
				# Podpora pro blok z max_hp (používá se v unbreakable_faith)
				var block_value = effect_value
				if effect.string_value == "max_hp":
					block_value = PlayerData.max_hp
				block_effects.append({
					"value": block_value,
					"target": target_desc,
					"conditional": block_conditional
				})
			
			CardEffectData.EffectType.HEAL_UNIT:
				var heal_conditional = null
				# Pro massive_healing: pokud máš <30% HP, léčíš za 30 HP místo 20 HP
				# V kódu se použije conditional_bonus_value místo value, pokud je podmínka splněna
				if effect.has_condition and effect.conditional_bonus_value > 0:
					# Pokud je conditional_bonus_value větší než value, nahrazuje to celou hodnotu
					var replaces = effect.conditional_bonus_value >= effect_value
					heal_conditional = {
						"type": effect.condition_type,
						"value": effect.condition_value,
						"bonus": effect.conditional_bonus_value,
						"replaces": replaces
					}
				heal_effects.append({
					"value": effect_value,
					"target": target_desc,
					"conditional": heal_conditional
				})
			
			CardEffectData.EffectType.HEAL_TO_FULL:
				heal_effects.append({
					"value": -1,  # Speciální hodnota pro "plné zdraví"
					"target": target_desc
				})
			
			CardEffectData.EffectType.DRAW_CARDS:
				var card_text = TranslationHelper.tr_single("card.effect.draw_cards", effect_value)
				if effect_value > 1:
					card_text = card_text.replace("card", "cards")
				other_effects.append(card_text)
			
			CardEffectData.EffectType.GAIN_ENERGY:
				other_effects.append(TranslationHelper.tr_single("card.effect.gain_energy", effect_value))
			
			CardEffectData.EffectType.APPLY_STATUS:
				# Speciální popis pro status efekty
				var status_desc = _get_status_display_description(effect)
				if status_desc != "":
					other_effects.append(status_desc)
				else:
					other_effects.append(_get_status_description(effect))
			
			CardEffectData.EffectType.EXHAUST:
				other_effects.append(tr("card.effect.exhaust"))
	
	# Sestavíme popis - POŠKOZENÍ (prioritně)
	for dmg in damage_effects:
		var dmg_text = str(dmg.value)
		if dmg.is_holy:
			dmg_text += " " + tr("card.effect.holy")
		dmg_text += " " + tr("damage.normal")
		
		# Přidáme podmíněný bonus, pokud existuje
		if dmg.has("conditional") and dmg.conditional != null:
			# Speciální případ: damage_per_block (holy_vengeance)
			if dmg.conditional.get("type", "") == "damage_per_block":
				dmg_text += "\n" + tr("card.condition.per_block")
			else:
				var cond_text = _format_conditional_effect(dmg.conditional, "dmg", dmg.is_holy)
				if cond_text != "":
					dmg_text += "\n" + cond_text
		
		if dmg.aoe == CardEffectData.AreaOfEffectType.ALL_ON_GRID:
			dmg_text = tr("card.effect.to_all") + " " + dmg_text
		elif dmg.target != "":
			dmg_text += " " + dmg.target
		
		parts.append(dmg_text)
	
	# BLOK (prioritně)
	for blk in block_effects:
		var blk_text = TranslationHelper.tr_single("card.effect.gain_block", blk.value)
		
		# Přidáme podmíněný bonus, pokud existuje
		if blk.has("conditional") and blk.conditional != null:
			var cond_text = _format_conditional_effect(blk.conditional, "blok", false)
			if cond_text != "":
				blk_text += "\n" + cond_text
		
		if blk.target != "":
			blk_text += " " + blk.target
		parts.append(blk_text)
	
	# LÉČENÍ (prioritně)
	for heal in heal_effects:
		var heal_text = ""
		if heal.value == -1:
			heal_text = tr("card.effect.full_heal")
		else:
			heal_text = TranslationHelper.tr_single("card.effect.heal", heal.value)
		
		# Pro léčení může podmíněný efekt nahradit celou hodnotu
		if heal.has("conditional") and heal.conditional != null:
			var cond = heal.conditional
			if cond.get("replaces", false):
				# Nahrazuje celou hodnotu (massive_healing) - zobrazíme obě
				var bonus_val = cond.get("bonus", 0)
				var cond_desc = _get_condition_description(cond.get("type", ""), cond.get("value", 0))
				heal_text += "\n%s: %s" % [cond_desc, TranslationHelper.tr_single("card.effect.heal", bonus_val)]
			else:
				# Přidává bonus
				var cond_text = _format_conditional_effect(cond, "HP", false)
				if cond_text != "":
					heal_text += "\n" + cond_text
		
		if heal.target != "":
			heal_text += " " + heal.target
		parts.append(heal_text)
	
	# OSTATNÍ EFEKTY
	for other in other_effects:
		parts.append(other)
	
	# Spojíme části s novými řádky (max 2-3 řádky)
	if parts.is_empty():
		return tr(card_description)  # Fallback na původní popis
	
	return "\n".join(parts)

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
	"""Vrátí popis status efektu"""
	if effect.string_value != "":
		return effect.string_value
	return "Status efekt"

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
