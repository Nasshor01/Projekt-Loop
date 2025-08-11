# Soubor: scripts/autoload/SaveManager.gd (UPRAVENÁ VERZE)
extends Node

signal meta_progress_changed

const SAVE_PATH = "user://meta_progress.res"
var meta_progress: MetaProgress

func _ready():
	load_meta_progress()

func get_xp_for_next_level() -> int:
	return meta_progress.player_level * 100

func _check_for_level_up():
	var xp_needed = get_xp_for_next_level()
	while meta_progress.total_xp >= xp_needed:
		meta_progress.total_xp -= xp_needed
		meta_progress.player_level += 1
		meta_progress.skill_points += 1
		print("GRATULACE! Hráč postoupil na level %d." % meta_progress.player_level)
		xp_needed = get_xp_for_next_level()

func save_meta_progress():
	var error = ResourceSaver.save(meta_progress, SAVE_PATH)
	if error != OK:
		DebugLogger.log_error("Failed to save meta progress! Error: %d" % error, "SAVE")
		printerr("Chyba při ukládání meta-progrese! Kód chyby: ", error)
	else:
		DebugLogger.log_save_load("save_meta_progress", true, "Level: %d, XP: %d" % [meta_progress.player_level, meta_progress.total_xp])
		print("Meta-progrese úspěšně uložena.")
	emit_signal("meta_progress_changed")

func load_meta_progress():
	if ResourceLoader.exists(SAVE_PATH):
		meta_progress = ResourceLoader.load(SAVE_PATH)
		print("Meta-progrese načtena.")
	else:
		meta_progress = MetaProgress.new()
		print("Žádná uložená data nenalezena, vytvářím nová.")
	emit_signal("meta_progress_changed")

func add_xp(amount: int):
	meta_progress.total_xp += amount
	print("Hráč získal %d XP. Celkem: %d" % [amount, meta_progress.total_xp])
	_check_for_level_up()
	save_meta_progress()
