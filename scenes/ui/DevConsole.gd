# Soubor: scripts/ui/DevConsole.gd
extends CanvasLayer

signal command_submitted(command, args)

@onready var output_log: RichTextLabel = $ColorRect/VBoxContainer/OutputLog
@onready var input_line: LineEdit = $ColorRect/VBoxContainer/InputLine

var all_artifacts: Dictionary = {}

func _ready():
	visible = false # Konzole je na začátku skrytá
	input_line.text_submitted.connect(_on_text_submitted)
	_load_all_artifacts()

func _unhandled_input(event: InputEvent):
	# Zobraz/skryj konzoli klávesou pod Esc (vlnovka/stříška)
	if event.is_action_pressed("ui_cancel") and event.is_pressed() and not event.is_echo():
		if Input.is_key_pressed(KEY_SHIFT): # Shift+Esc pro jistotu
			visible = not visible
			if visible:
				input_line.grab_focus()
			else:
				input_line.release_focus()

func _load_all_artifacts():
	# Tato funkce prohledá i podsložky, pro jistotu
	var artifacts_list = _recursive_load("res://data/artifacts/")
	for artifact in artifacts_list:
		# Název souboru bez cesty a koncovky
		var key = artifact.resource_path.get_file().get_basename()
		all_artifacts[key] = artifact

func _recursive_load(path: String) -> Array:
	var resources = []
	var dir = DirAccess.open(path)
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				var res = load(path.path_join(file_name))
				if res is ArtifactsData:
					resources.append(res)
		for dir_name in dir.get_directories():
			if dir_name == "." or dir_name == "..":
				continue
			resources.append_array(_recursive_load(path.path_join(dir_name)))
	return resources

func _on_text_submitted(command_text: String):
	if command_text.is_empty():
		return
	
	log_message("> " + command_text)
	input_line.clear()
	
	# strip_edges() odstraní mezery na začátku/konci
	# false znamená, že více mezer za sebou se bere jako jedna
	var parts = command_text.strip_edges().split(" ", false)
	var command = parts[0].to_lower()
	var args = parts.slice(1)
	
	match command:
		"add_artifact":
			if args.is_empty():
				log_error("Použití: add_artifact <NazevSouboru>")
				return
			var artifact_name = args[0]
			if all_artifacts.has(artifact_name):
				PlayerData.add_artifact(all_artifacts[artifact_name])
				log_success("Artefakt '%s' byl přidán." % artifact_name)
			else:
				log_error("Artefakt '%s' nebyl nalezen." % artifact_name)
		
		"remove_artifact":
			if args.is_empty():
				log_error("Použití: remove_artifact <NazevSouboru>")
				return
			var artifact_name = args[0]
			if all_artifacts.has(artifact_name):
				PlayerData.remove_artifact(all_artifacts[artifact_name])
				log_success("Artefakt '%s' byl odebrán." % artifact_name)
			else:
				log_error("Artefakt '%s' nebyl nalezen." % artifact_name)
		
		"list_artifacts":
			log_message("Dostupné artefakty: " + str(all_artifacts.keys()))
		
		# --- PŘIDANÉ PŘÍKAZY PRO ZLATO ---
		"add_gold":
			if args.is_empty() or not args[0].is_valid_int():
				log_error("Použití: add_gold <množství>")
				return
			var amount = args[0].to_int()
			PlayerData.add_gold(amount)
			log_success("Přidáno %d zlata. Celkem: %d" % [amount, PlayerData.gold])

		"remove_gold":
			if args.is_empty() or not args[0].is_valid_int():
				log_error("Použití: remove_gold <množství>")
				return
			var amount = args[0].to_int()
			PlayerData.spend_gold(amount)
			log_success("Odebráno %d zlata. Celkem: %d" % [amount, PlayerData.gold])
		# ------------------------------------

		_:
			# Pokud příkaz neznáme, předáme ho dál pro případ,
			# že by ho uměla zpracovat scéna, ve které se nacházíme (např. Map.gd)
			emit_signal("command_submitted", command, args)

func log_message(text: String):
	output_log.append_text("\n" + text)

func log_error(text: String):
	output_log.append_text("\n[color=red]Chyba: %s[/color]" % text)

func log_success(text: String):
	output_log.append_text("\n[color=green]%s[/color]" % text)
