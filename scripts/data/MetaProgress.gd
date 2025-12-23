# Soubor: scripts/data/MetaProgress.gd (NOVÝ SKRIPT)
class_name MetaProgress
extends Resource

@export var total_xp: int = 0
@export var player_level: int = 1
# PŘIDÁNO: Počet bodů, které může hráč utratit ve stromu dovedností
@export var skill_points: int = 0

# NOVÉ: Dictionary pro stackovatelné pasivy
# { "skill_id": allocation_count }
# Místo starého unlocked_skill_ids, které nepodporovalo stackování
@export var allocated_skills: Dictionary = {}

# ZPĚTNÁ KOMPATIBILITA: Pokud máš staré uložené hry s unlocked_skill_ids
func _init():
	# Migrace ze starého systému
	if not allocated_skills.is_empty():
		return  # Už máme nový systém
	
	# Pokud máme starý systém, migrujeme ho
	# (toto se spustí jen při prvním načtení starého save)
