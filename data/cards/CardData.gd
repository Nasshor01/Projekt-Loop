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

func get_display_description() -> String:
	"""Vrátí popis karty s aktuálními hodnotami poškození (včetně bonusů)"""
	var description = card_description
	var damage_bonus = get_damage_bonus()
	
	if damage_bonus == 0:
		return description  # Žádný bonus, vrať původní popis
	
	# OPRAVA BUG 1: Shromáždíme všechny unikátní hodnoty poškození najednou
	# aby se zabránilo problému s více efekty se stejnou hodnotou
	var damage_replacements = {}  # {base_damage: total_damage}
	
	for effect in effects:
		if effect.effect_type == CardEffectData.EffectType.DEAL_DAMAGE:
			var base_damage = effect.value
			var total_damage = base_damage + damage_bonus
			# Použijeme maximum, pokud máme více efektů se stejnou základní hodnotou
			# (i když by to nemělo nastat, je to bezpečnější)
			if not damage_replacements.has(base_damage) or damage_replacements[base_damage] < total_damage:
				damage_replacements[base_damage] = total_damage
	
	# Aplikujeme všechny nahrazení najednou (od největších hodnot k nejmenším,
	# aby se zabránilo problémům s čísly, která jsou částí jiných čísel)
	var sorted_bases = damage_replacements.keys()
	sorted_bases.sort()
	sorted_bases.reverse()  # Od největších k nejmenším
	
	for base_damage in sorted_bases:
		var total_damage = damage_replacements[base_damage]
		var base_str = str(base_damage)
		var total_str = str(total_damage)
		
		# Nahradíme všechny výskyty základní hodnoty celkovou hodnotou
		# Použijeme různé formáty, které se mohou v popisech vyskytovat
		
		# Základní formáty
		description = description.replace(base_str + " poškození", total_str + " poškození")
		description = description.replace(base_str + " poškození.", total_str + " poškození.")
		description = description.replace(base_str + " svatého poškození", total_str + " svatého poškození")
		description = description.replace(base_str + " svatého poškození.", total_str + " svatého poškození.")
		
		# Formáty s "Způsob" / "Způsobí"
		description = description.replace("Způsob " + base_str + " poškození", "Způsob " + total_str + " poškození")
		description = description.replace("Způsobí " + base_str + " poškození", "Způsobí " + total_str + " poškození")
		description = description.replace("Způsob " + base_str + " svatého poškození", "Způsob " + total_str + " svatého poškození")
		description = description.replace("Způsobí " + base_str + " svatého poškození", "Způsobí " + total_str + " svatého poškození")
		
		# Formáty s "všem nepřátelům" / "nepřátelům"
		description = description.replace("všem nepřátelům způsob " + base_str + " poškození", "všem nepřátelům způsob " + total_str + " poškození")
		description = description.replace("všem nepřátelům způsobí " + base_str + " poškození", "všem nepřátelům způsobí " + total_str + " poškození")
		description = description.replace("nepřátelům způsob " + base_str + " poškození", "nepřátelům způsob " + total_str + " poškození")
		description = description.replace("nepřátelům způsobí " + base_str + " poškození", "nepřátelům způsobí " + total_str + " poškození")
		
		# Formáty s "v oblasti" / "ve sloupci" / "v řadě"
		description = description.replace("způsobí " + base_str + " poškození", "způsobí " + total_str + " poškození")
		description = description.replace("způsob " + base_str + " poškození", "způsob " + total_str + " poškození")
	
	return description
