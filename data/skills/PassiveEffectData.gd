# Soubor: res://data/skills/PassiveEffectData.gd (ROZŠÍŘENÁ VERZE)
class_name PassiveEffectData
extends Resource

# Zde si definujeme VŠECHNY možné pasivní efekty, které ve hře můžeš mít.
enum EffectType {
	# Základní efekty
	ADD_MAX_HP,
	ADD_STARTING_GOLD,
	ADD_MAX_ENERGY,
	GRANT_REVIVE,
	ADD_CARD_DAMAGE,
	ADD_RETAINED_BLOCK,
	
	# Nové efekty pro Paladin strom
	CRITICAL_CHANCE_BONUS,      # Šance na kritický zásah
	HEAL_END_OF_TURN,          # Léčení na konci tahu
	AURA_ENHANCEMENT,          # Vylepšení aury
	AVATAR_STARTING_BLOCK,     # Speciální blok na začátku (2x max HP)
	THORNS_DAMAGE,             # Poškození útočníka při zásahu
	DOUBLE_HEALING,            # Dvojnásobné léčení
	ENERGY_ON_KILL,            # Energie za zabití nepřítele
	BLOCK_ON_CARD_PLAY,        # Blok za hraní karet
	
	# Budoucí efekty pro ostatní postavy
	LIFESTEAL_PERCENTAGE,      # % lifesteal z poškození
	MOVEMENT_BONUS,            # Extra pohyb
	CARD_COST_REDUCTION,       # Snížení ceny karet
	DRAW_EXTRA_CARDS,          # Líznutí extra karet
	STATUS_IMMUNITY,           # Imunita na statusy
	AREA_DAMAGE_BONUS,         # Bonus k AoE útokům
}

## Typ efektu, který si vybereš z menu v editoru.
@export var effect_type: EffectType = EffectType.ADD_MAX_HP

## Hodnota efektu (např. 10 pro HP, 25 pro zlato, 20 pro procenta).
@export var value: int = 0

## Textová hodnota, pokud by byla potřeba (pro statusy, podmínky atd.).
@export var string_value: String = ""

## Druhá číselná hodnota pro složitější efekty.
@export var secondary_value: int = 0

## Je efekt aktivní pouze za určitých podmínek?
@export var conditional: bool = false

## Popis podmínky pro aktivaci efektu.
@export var condition_description: String = ""

# Pomocné funkce pro formátování popisů
func get_formatted_description() -> String:
	match effect_type:
		EffectType.ADD_MAX_HP:
			return "+%d maximálního zdraví" % value
		EffectType.ADD_STARTING_GOLD:
			return "+%d startovního zlata" % value
		EffectType.ADD_MAX_ENERGY:
			return "+%d maximální energie" % value
		EffectType.GRANT_REVIVE:
			return "Možnost oživení" if value > 0 else ""
		EffectType.ADD_CARD_DAMAGE:
			return "+%d poškození všech karet" % value
		EffectType.ADD_RETAINED_BLOCK:
			return "+%d startovního bloku" % value
		EffectType.CRITICAL_CHANCE_BONUS:
			return "+%d%% šance na kritický zásah" % value
		EffectType.HEAL_END_OF_TURN:
			return "Vyléč se za %d HP na konci každého tahu" % value
		EffectType.AURA_ENHANCEMENT:
			return "Vylepšení aury o +%d" % value
		EffectType.AVATAR_STARTING_BLOCK:
			return "Na začátku souboje získej blok rovný %dx tvému max HP" % value
		EffectType.THORNS_DAMAGE:
			return "Vrať %d poškození útočníkům" % value
		EffectType.DOUBLE_HEALING:
			return "Veškeré léčení je o %d%% silnější" % value
		EffectType.ENERGY_ON_KILL:
			return "Získej %d energie za zabití nepřítele" % value
		EffectType.BLOCK_ON_CARD_PLAY:
			return "Získej %d bloku za každou zahrátou kartu" % value
		_:
			return "Speciální efekt"
