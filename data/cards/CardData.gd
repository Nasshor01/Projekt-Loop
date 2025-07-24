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
