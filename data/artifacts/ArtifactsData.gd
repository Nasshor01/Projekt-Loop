# Soubor: data/artifacts/ArtifactsData.gd (VYLEPŠENÁ VERZE)
@tool
class_name ArtifactsData
extends Resource

## Základní informace
@export var artifact_name: String = "Neznámý artefakt"
@export_multiline var description: String = "Dělá něco tajemného."
@export var texture: Texture2D

## NOVÉ: Typ artefaktu pro organizaci
enum ArtifactType {
	COMMON,      # Běžné artefakty
	UNCOMMON,    # Neobvyklé artefakty  
	RARE,        # Vzácné artefakty
	LEGENDARY,   # Legendární artefakty
	CURSED,      # Prokleté artefakty (negativní)
	BOSS,        # Boss artefakty (velmi mocné)
	EVENT        # Event artefakty (ze speciálních událostí)
}
@export var artifact_type: ArtifactType = ArtifactType.COMMON

## NOVÉ: Kdy se efekt spouští
enum TriggerType {
	PASSIVE,              # Permanentní efekt
	START_OF_COMBAT,      # Na začátku souboje
	START_OF_TURN,        # Na začátku každého tahu
	END_OF_TURN,          # Na konci každého tahu
	ON_CARD_PLAYED,       # Při zahrání karty
	ON_DAMAGE_TAKEN,      # Při obdržení poškození
	ON_DAMAGE_DEALT,      # Při způsobení poškození
	ON_BLOCK_GAINED,      # Při získání bloku
	ON_HEAL,              # Při léčení
	ON_ENEMY_DEATH,       # Při zabití nepřítele
	ON_HEALTH_LOW,        # Když je zdraví nízké (25% a méně)
	ON_ENERGY_SPENT,      # Při utracení energie
	ON_DRAW_CARDS,        # Při dobírání karet
	CONDITIONAL           # Podmíněný efekt (custom logika)
}
@export var trigger_type: TriggerType = TriggerType.PASSIVE

## NOVÉ: Typ efektu
enum EffectType {
	# Statistiky
	MODIFY_MAX_HP,           # Změní max HP (+/-)
	MODIFY_MAX_ENERGY,       # Změní max energii (+/-)
	MODIFY_CARD_DAMAGE,      # Změní poškození karet (+/-)
	MODIFY_BLOCK_GAIN,       # Změní gain bloku (+/-)
	MODIFY_HEAL_AMOUNT,      # Změní amount léčení (+/-)
	
	# Bojové efekty
	GAIN_BLOCK,              # Získá blok
	GAIN_ENERGY,             # Získá energii
	DEAL_DAMAGE,             # Způsobí poškození
	HEAL_HP,                 # Vyléčí HP
	DRAW_CARDS,              # Dobere karty
	
	# Speciální efekty
	THORNS_DAMAGE,           # Vrací poškození
	CRITICAL_CHANCE,         # Zvýší šanci na kritický zásah
	EXTRA_TURN_DRAW,         # Extra dobírání každý tah
	RETAIN_ENERGY,           # Ponechá energii mezi tahy
	DUPLICATE_CARD,          # Duplikuje zahranou kartu
	
	# Negativní efekty
	CURSE_DRAW,              # Přidá curse do balíčku
	REDUCE_HAND_SIZE,        # Sníží velikost ruky
	ENERGY_LOSS,             # Ztratí energii každý tah
	FRAIL_EFFECT,            # Sníží efektivnost bloku
	VULNERABLE_EFFECT,       # Zvýší přijaté poškození
	
	# Pokročilé efekty
	TRANSFORM_CARDS,         # Změní karty v balíčku
	COPY_LAST_PLAYED,        # Zkopíruje poslední zahranou kartu
	RANDOM_CARD_COST,        # Randomizuje náklady karet
	CHAIN_LIGHTNING,         # Řetězový lightning efekt
	RESURRECT_ONCE,          # Jednorazové oživení
	
	# Meta efekty
	ARTIFACT_SYNERGY,        # Interakce s jinými artefakty
	SCALING_EFFECT,          # Efekt se zvyšuje s časem
	CONDITIONAL_TRIGGER      # Podmíněný efekt
}
@export var effect_type: EffectType = EffectType.MODIFY_MAX_HP

## Hodnoty efektu
@export var primary_value: int = 0      # Hlavní hodnota
@export var secondary_value: int = 0    # Vedlejší hodnota (pro složitější efekty)
@export var percentage_based: bool = false  # Je efekt procentuální?

@export_group("Podmínky a Vlastnosti")
## Použití a limity
@export var uses_per_combat: int = -1   # Počet použití za souboj (-1 = neomezeně)
@export var current_uses: int = 0       # Aktuální počet použití v tomto souboji

## Stohování (Stacking)
@export var is_stackable: bool = false   # Je tento artefakt stohovatelný?
@export var max_stacks: int = 1          # Maximální počet stacků (pokud je stohovatelný)
@export var current_stacks: int = 1      # Aktuální počet stacků

## Synergie
@export var synergy_set_id: String = ""  # ID sady pro synergii (např. "GolemPart", "Magnetic")

## Podmíněné efekty
@export_group("Podmínky spuštění") # Tímto oddělíme další sekci v inspektoru
@export var condition_type: String = "" # Typ podmínky (např. "health_below", "energy_above")
@export var condition_value: int = 0    # Hodnota podmínky

## Textové efekty pro speciální případy
@export var custom_effect_id: String = ""  # Pro custom efekty
@export var effect_description: String = "" # Detailní popis mechaniky

## NOVÉ: Funkce pro práci s artefaktem
func can_trigger() -> bool:
	"""Zkontroluje, jestli se může artefakt aktivovat"""
	if uses_per_combat > 0 and current_uses >= uses_per_combat:
		return false
	return true

func use_artifact():
	"""Označí artefakt jako použitý"""
	if uses_per_combat > 0:
		current_uses += 1

func reset_for_new_combat():
	"""Resetuje artefakt pro nový souboj"""
	current_uses = 0
	
	# OPRAVA: Srdce draka (START_OF_TURN) se neresetuje každý tah!
	# Counter se resetuje jen při skutečně novém souboji
	# Necháme prázdné - Srdce draka si drží counter po celý souboj

func add_stack():
	"""Přidá stack artefaktu, pokud je to možné"""
	if current_stacks < max_stacks:
		current_stacks += 1
		return true
	return false

func get_effective_value() -> int:
	"""Vrátí efektivní hodnotu s ohledem na stacky a procenta"""
	var base_value = primary_value * current_stacks
	
	# NOVÉ: Pokud je percentage_based, počítej z max HP
	if percentage_based and PlayerData:
		return (PlayerData.max_hp * base_value) / 100.0
	
	return base_value

# A stejně i pro secondary_value:
func get_effective_secondary_value() -> int:
	"""Vrátí efektivní vedlejší hodnotu s ohledem na stacky a procenta"""
	var base_value = secondary_value * current_stacks
	
	if percentage_based and PlayerData:
		return (PlayerData.max_hp * base_value) / 100.0
	
	return base_value

func check_condition(context: Dictionary = {}) -> bool:
	"""Zkontroluje, jestli je splněna podmínka pro aktivaci"""
	if condition_type.is_empty():
		return true
		
	match condition_type:
		"health_below":
			var current_hp = context.get("current_hp", 0)
			var max_hp = context.get("max_hp", 1)
			return (current_hp * 100 / max_hp) <= condition_value
		"health_above":
			var current_hp = context.get("current_hp", 0)
			var max_hp = context.get("max_hp", 1)
			return (current_hp * 100 / max_hp) >= condition_value
		"energy_below":
			var current_energy = context.get("current_energy", 0)
			return current_energy <= condition_value
		"energy_above":
			var current_energy = context.get("current_energy", 0)
			return current_energy >= condition_value
		"cards_in_hand":
			var hand_size = context.get("hand_size", 0)
			return hand_size >= condition_value
		"enemies_alive":
			var enemy_count = context.get("enemy_count", 0)
			return enemy_count >= condition_value
		# === PŘIDEJ TYTO DVĚ NOVÉ CASE VĚTVE: ===
		"turn_number":
			var current_turn = context.get("current_turn", 0)
			var turn_number = context.get("turn_number", 0)  # Fallback
			var turn = max(current_turn, turn_number)
			# Aktivuj každý N-tý tah (3., 6., 9., ...)
			return turn > 0 and (turn % condition_value) == 0
		"critical_hit":
			var was_critical = context.get("critical_hit", false)
			return was_critical
			
		"start_of_combat":
			var is_first_turn = context.get("is_first_turn", false)
			return is_first_turn
		# === KONEC NOVÝCH CASE VĚTVÍ ===
		_:
			return true

func get_formatted_description() -> String:
	"""Vrátí popis s aktuálními hodnotami"""
	var desc = description
	
	# Nahradíme placeholdery skutečnými hodnotami
	desc = desc.replace("{value}", str(get_effective_value()))
	desc = desc.replace("{value2}", str(get_effective_secondary_value()))
	desc = desc.replace("{stacks}", str(current_stacks))
	
	if max_stacks > 1:
		desc += " [Stacks: %d/%d]" % [current_stacks, max_stacks]
	
	if uses_per_combat > 0:
		var remaining = uses_per_combat - current_uses
		desc += " [Použití: %d/%d]" % [remaining, uses_per_combat]
		
	return desc

func get_rarity_color() -> Color:
	"""Vrátí barvu podle vzácnosti artefaktu"""
	match artifact_type:
		ArtifactType.COMMON: return Color.WHITE
		ArtifactType.UNCOMMON: return Color.LIME_GREEN  
		ArtifactType.RARE: return Color.DODGER_BLUE
		ArtifactType.LEGENDARY: return Color.ORANGE
		ArtifactType.CURSED: return Color.PURPLE
		ArtifactType.BOSS: return Color.CRIMSON
		ArtifactType.EVENT: return Color.GOLD
		_: return Color.WHITE

func is_negative() -> bool:
	"""Vrátí true, pokud je artefakt negativní"""
	return artifact_type == ArtifactType.CURSED or primary_value < 0
