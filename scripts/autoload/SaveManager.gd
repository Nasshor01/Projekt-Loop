# Soubor: scripts/autoload/SaveManager.gd (UPRAVENÁ VERZE)
extends Node

const SAVE_PATH = "user://meta_progress.res"
var meta_progress: MetaProgress

func _ready():
	load_meta_progress()

# --- PŘIDANÉ FUNKCE PRO VÝPOČET LEVELU ---
# Jednoduchý vzorec, který určuje, kolik XP je potřeba na další level.
# Můžeš si ho později libovolně ztížit.
func get_xp_for_next_level() -> int:
	return meta_progress.player_level * 100

# Funkce, která zkontroluje, jestli došlo k postupu na další level.
func _check_for_level_up():
	var xp_needed = get_xp_for_next_level()
	# Pokud máme dostatek XP, opakujeme, pro případ více levelů najednou
	while meta_progress.total_xp >= xp_needed:
		# Odečteme XP potřebné pro tento level
		meta_progress.total_xp -= xp_needed
		# Zvýšíme level a přidáme dovednostní bod
		meta_progress.player_level += 1
		meta_progress.skill_points += 1
		print("GRATULACE! Hráč postoupil na level %d." % meta_progress.player_level)
		# Přepočítáme XP potřebné pro NOVÝ, vyšší level
		xp_needed = get_xp_for_next_level()
# ----------------------------------------------

func save_meta_progress():
	var error = ResourceSaver.save(meta_progress, SAVE_PATH)
	if error != OK:
		printerr("Chyba při ukládání meta-progrese! Kód chyby: ", error)
	else:
		print("Meta-progrese úspěšně uložena.")

func load_meta_progress():
	if ResourceLoader.exists(SAVE_PATH):
		meta_progress = ResourceLoader.load(SAVE_PATH)
		print("Meta-progrese načtena.")
	else:
		meta_progress = MetaProgress.new()
		print("Žádná uložená data nenalezena, vytvářím nová.")

# --- UPRAVENÁ FUNKCE PRO PŘIDÁNÍ XP ---
func add_xp(amount: int):
	meta_progress.total_xp += amount
	print("Hráč získal %d XP. Celkem: %d" % [amount, meta_progress.total_xp])
	
	# Po přidání XP vždy zkontrolujeme, jestli to stačilo na nový level
	_check_for_level_up()
	
	save_meta_progress()
