# Soubor: res://data/skills/PassiveEffectData.gd
class_name PassiveEffectData
extends Resource

# Zde si definujeme VŠECHNY možné pasivní efekty, které ve hře můžeš mít.
# Kdykoliv budeš chtít nový, přidáš ho sem a objeví se ti v editoru v menu.
enum EffectType {
	ADD_MAX_HP,
	ADD_STARTING_GOLD,
	ADD_MAX_ENERGY,
	GRANT_REVIVE,
	ADD_CARD_DAMAGE,
	ADD_RETAINED_BLOCK,
	# Můžeš přidávat další...
	# HEAL_AT_START_OF_BATTLE,
	# DRAW_EXTRA_CARD_FIRST_TURN
}

## Typ efektu, který si vybereš z menu v editoru.
@export var effect_type: EffectType = EffectType.ADD_MAX_HP

## Hodnota efektu (např. 10 pro HP, 25 pro zlato).
@export var value: int = 0

## Textová hodnota, pokud by byla potřeba (pro budoucí, složitější efekty).
@export var string_value: String = ""
