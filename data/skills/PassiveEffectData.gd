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
	
	# Card Management efekty
	CARD_UNLOCK,                # Odemknout kartu do poolu odměn (string_value = card_id)
	DRAW_CARD_FIRST_TURN,       # Líznutí karty navíc v prvním kole
	CONDITIONAL_DRAW,           # Líznutí karty za podmínky (string_value = condition)
	HAND_SIZE_BONUS,            # Větší ruka (+X karet)
	
	# Resource Management efekty
	STARTING_RESOURCE,          # Začátek souboje s resource (string_value = resource_type: combo/essence/potions)
	STARTING_TRAP,              # Začátek souboje s pastí (value = počet)
	STARTING_POTIONS,           # Začátek souboje s lektvary (value = počet)
	
	# Combat Bonuses
	TARGET_BONUS_DAMAGE,        # Bonusové poškození proti označenému cíli (%)
	CARD_COST_REDUCTION_TARGET, # Snížení ceny karty proti cíli (value = snížení)
	FIRST_ATTACK_FREE,          # První útok zdarma (value = počet)
	SPELL_BLOCK,                # Blok za sešlání kouzla (value = blok)
	
	# Passive Enhancements
	PASSIVE_ENHANCEMENT,        # Vylepšení pasivní schopnosti (string_value = passive_id, value = bonus)
	PASSIVE_RESONANCE_BONUS,    # Bonus k pasivní rezonanci (%)
	PASSIVE_USE_COUNT,          # Počet použití pasivní schopnosti za kolo (+X)
	PASSIVE_TRIGGER_THRESHOLD,  # Změna prahu aktivace pasivní schopnosti (string_value = passive_id, value = nový threshold)
	
	# Posture System (Fighter)
	POSTURE_BONUS,              # Bonus v určitém postoji (string_value = posture_type, value = bonus %)
	POSTURE_COST_REDUCTION,     # Snížení ceny přepnutí postoje (value = snížení)
	
	# DoT/Status
	POISON_DAMAGE_BONUS,        # Bonus k jedům (+X poškození za kolo)
	
	# Summoning (Nekromant)
	SUMMON_HEALTH_BONUS,        # Bonus HP pro vyvolané jednotky (+X)
	ENEMY_TO_CARD_CONVERSION,   # Převod zabitých nepřátel na karty (%)
	
	# Lifesteal (Vrah Duší)
	OVERHEAL_TO_TEMP_HP,        # Přebytečné léčení → dočasné HP (value = % konverze)
	ALLIED_DAMAGE_LIFESTEAL,    # Lifesteal z poškození spojenců (%)
	
	# Conditional Effects
	CONDITIONAL_BLOCK,          # Blok za podmínky (string_value = condition, value = blok)
	STARTING_TEMP_HP,           # Začátek s dočasným HP (value = HP)
	
	# Support (Ochránce)
	ALLIED_DEFENSE_BONUS,       # Bonus k obraně spojenců (%)
	FORCE_ENEMY_MOVEMENT,       # Donutit nepřátele k pohybu (value = počet použití)
	
	# Elemental (Elementalista)
	FIRST_SPELL_ELEMENT_FREE,   # První kouzlo každého živlu zdarma (value = počet živlů)
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
		
		# Card Management
		EffectType.CARD_UNLOCK:
			return "Odemknout kartu: %s" % string_value if string_value != "" else "Odemknout novou kartu"
		EffectType.DRAW_CARD_FIRST_TURN:
			return "Líznutí %d karty navíc v prvním kole" % value
		EffectType.CONDITIONAL_DRAW:
			var condition_text = string_value if string_value != "" else "za podmínky"
			return "Líznutí karty %s" % condition_text
		EffectType.HAND_SIZE_BONUS:
			return "Větší ruka: +%d karet" % value
		
		# Resource Management
		EffectType.STARTING_RESOURCE:
			var resource_type = string_value if string_value != "" else "resource"
			return "Začátek souboje s %d %s" % [value, resource_type]
		EffectType.STARTING_TRAP:
			return "Začátek souboje s %d pastí" % value
		EffectType.STARTING_POTIONS:
			return "Začátek souboje s %d lektvary" % value
		
		# Combat Bonuses
		EffectType.TARGET_BONUS_DAMAGE:
			return "+%d%% poškození proti označenému cíli" % value
		EffectType.CARD_COST_REDUCTION_TARGET:
			return "Karty proti cíli stojí o %d méně" % value
		EffectType.FIRST_ATTACK_FREE:
			return "První %d útok(y) zdarma" % value
		EffectType.SPELL_BLOCK:
			return "Získej %d bloku za každé sešlání kouzla" % value
		
		# Passive Enhancements
		EffectType.PASSIVE_ENHANCEMENT:
			var passive_name = string_value if string_value != "" else "pasivní schopnost"
			return "Vylepšení %s: +%d" % [passive_name, value]
		EffectType.PASSIVE_RESONANCE_BONUS:
			return "+%d%% k pasivní rezonanci" % value
		EffectType.PASSIVE_USE_COUNT:
			return "Pasivní schopnost lze použít %dx za kolo" % value
		EffectType.PASSIVE_TRIGGER_THRESHOLD:
			var passive_name = string_value if string_value != "" else "pasivní schopnost"
			return "Prah aktivace %s změněn na %d%%" % [passive_name, value]
		
		# Posture System
		EffectType.POSTURE_BONUS:
			var posture = string_value if string_value != "" else "postoji"
			return "+%d%% bonus v %s" % [value, posture]
		EffectType.POSTURE_COST_REDUCTION:
			return "Přepnutí postoje stojí o %d méně" % value
		
		# DoT/Status
		EffectType.POISON_DAMAGE_BONUS:
			return "Jedy způsobují o %d poškození navíc za kolo" % value
		
		# Summoning
		EffectType.SUMMON_HEALTH_BONUS:
			return "Vyvolané jednotky mají +%d maximálního zdraví" % value
		EffectType.ENEMY_TO_CARD_CONVERSION:
			return "%d%% zabitých nepřátel se přidá jako karty" % value
		
		# Lifesteal
		EffectType.LIFESTEAL_PERCENTAGE:
			return "%d%% lifesteal z poškození" % value
		EffectType.OVERHEAL_TO_TEMP_HP:
			return "%d%% přebytečného léčení se převede na dočasné HP" % value
		EffectType.ALLIED_DAMAGE_LIFESTEAL:
			return "%d%% lifesteal z poškození spojenců" % value
		
		# Conditional Effects
		EffectType.CONDITIONAL_BLOCK:
			var condition = string_value if string_value != "" else "za podmínky"
			return "Získej %d bloku %s" % [value, condition]
		EffectType.STARTING_TEMP_HP:
			return "Začátek souboje s %d dočasným HP" % value
		
		# Support
		EffectType.ALLIED_DEFENSE_BONUS:
			return "Spojenci mají +%d%% k obraně" % value
		EffectType.FORCE_ENEMY_MOVEMENT:
			return "Můžeš donutit nepřátele k pohybu (%dx za souboj)" % value
		
		# Elemental
		EffectType.FIRST_SPELL_ELEMENT_FREE:
			return "První kouzlo každého živlu zdarma"
		
		# Legacy efekty
		EffectType.MOVEMENT_BONUS:
			return "+%d extra pohyb" % value
		EffectType.CARD_COST_REDUCTION:
			return "Všechny karty stojí o %d méně" % value
		EffectType.DRAW_EXTRA_CARDS:
			return "Líznutí %d karet navíc" % value
		EffectType.STATUS_IMMUNITY:
			return "Imunita na statusy" if value > 0 else ""
		EffectType.AREA_DAMAGE_BONUS:
			return "+%d%% k AoE útokům" % value
		
		_:
			return "Speciální efekt"
