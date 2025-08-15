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
	# Načte všechny artefakty ze složky a podsložek
	var artifacts_list = _recursive_load("res://data/artifacts/")
	for artifact in artifacts_list:
		# Název souboru bez cesty a koncovky jako klíč
		var key = artifact.resource_path.get_file().get_basename()
		all_artifacts[key] = artifact
	
	log_message("Načteno %d artefaktů" % all_artifacts.size())

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
	
	var parts = command_text.strip_edges().split(" ", false)
	var command = parts[0].to_lower()
	var args = parts.slice(1)
	
	match command:
		"add_artifact":
			_cmd_add_artifact(args)
		
		"remove_artifact":
			_cmd_remove_artifact(args)
		
		"list_artifacts":
			_cmd_list_artifacts(args)
		
		"add_all_artifacts":
			_cmd_add_all_artifacts()
		
		"clear_artifacts":
			_cmd_clear_artifacts()
		
		"artifact_info":
			_cmd_artifact_info(args)
		
		"add_gold":
			_cmd_add_gold(args)
		
		"remove_gold":
			_cmd_remove_gold(args)
		
		"set_hp":
			_cmd_set_hp(args)
		
		"add_energy":
			_cmd_add_energy(args)
		
		"reload_artifacts":
			_cmd_reload_artifacts()
		
		"help":
			_cmd_help()
		
		_:
			emit_signal("command_submitted", command, args)

func _cmd_add_artifact(args: Array):
	if args.is_empty():
		log_error("Použití: add_artifact <název_souboru>")
		_show_artifact_examples()
		return
	
	var artifact_name = args[0]
	if all_artifacts.has(artifact_name):
		var artifact = all_artifacts[artifact_name]
		if PlayerData.add_artifact(artifact):
			log_success("✅ Artefakt '%s' byl přidán!" % artifact.artifact_name)
		else:
			log_error("❌ Artefakt '%s' se nepodařilo přidat (už vlastníš nebo je na max stackech)" % artifact.artifact_name)
	else:
		log_error("Artefakt '%s' nebyl nalezen." % artifact_name)
		_show_artifact_examples()

func _cmd_remove_artifact(args: Array):
	if args.is_empty():
		log_error("Použití: remove_artifact <název_artefaktu>")
		_show_owned_artifacts()
		return
	
	var artifact_name = args[0]
	var found_artifact = PlayerData.find_artifact_by_name(artifact_name)
	
	if found_artifact:
		PlayerData.remove_artifact(found_artifact)
		log_success("✅ Artefakt '%s' byl odebrán!" % artifact_name)
	else:
		log_error("Nevlastníš artefakt '%s'." % artifact_name)
		_show_owned_artifacts()

func _cmd_list_artifacts(args: Array):
	if args.size() > 0 and args[0] == "owned":
		_show_owned_artifacts()
	else:
		log_message("📋 Dostupné artefakty (%d):" % all_artifacts.size())
		var sorted_keys = all_artifacts.keys()
		sorted_keys.sort()
		for key in sorted_keys:
			var artifact = all_artifacts[key]
			log_message("  - %s (%s)" % [key, artifact.artifact_name])

func _cmd_add_all_artifacts():
	log_message("🎁 Přidávám všechny artefakty...")
	var added_count = 0
	var failed_count = 0
	
	for artifact_key in all_artifacts.keys():
		var artifact = all_artifacts[artifact_key]
		if PlayerData.add_artifact(artifact):
			added_count += 1
			log_message("  ✅ %s" % artifact.artifact_name)
		else:
			failed_count += 1
			log_message("  ❌ %s (už vlastníš nebo max stacky)" % artifact.artifact_name)
	
	log_success("🎉 Hotovo! Přidáno: %d, Selhalo: %d" % [added_count, failed_count])

func _cmd_clear_artifacts():
	var count = PlayerData.artifacts.size()
	PlayerData.artifacts.clear()
	PlayerData.emit_signal("artifacts_changed")
	log_success("🗑️ Odstraněno %d artefaktů!" % count)

func _cmd_artifact_info(args: Array):
	if args.is_empty():
		log_error("Použití: artifact_info <název_souboru>")
		return
	
	var artifact_name = args[0]
	if all_artifacts.has(artifact_name):
		var artifact = all_artifacts[artifact_name]
		log_message("📋 Info o artefaktu '%s':" % artifact.artifact_name)
		log_message("  Typ: %s" % ArtifactsData.ArtifactType.keys()[artifact.artifact_type])
		log_message("  Trigger: %s" % ArtifactsData.TriggerType.keys()[artifact.trigger_type])
		log_message("  Efekt: %s" % ArtifactsData.EffectType.keys()[artifact.effect_type])
		log_message("  Hodnota: %d" % artifact.primary_value)
		log_message("  Max stacky: %d" % artifact.max_stacks)
		log_message("  Popis: %s" % artifact.description)
	else:
		log_error("Artefakt '%s' nebyl nalezen." % artifact_name)

func _cmd_add_gold(args: Array):
	if args.is_empty() or not args[0].is_valid_int():
		log_error("Použití: add_gold <množství>")
		return
	var amount = args[0].to_int()
	PlayerData.add_gold(amount)
	log_success("💰 Přidáno %d zlata. Celkem: %d" % [amount, PlayerData.gold])

func _cmd_remove_gold(args: Array):
	if args.is_empty() or not args[0].is_valid_int():
		log_error("Použití: remove_gold <množství>")
		return
	var amount = args[0].to_int()
	if PlayerData.spend_gold(amount):
		log_success("💸 Odebráno %d zlata. Celkem: %d" % [amount, PlayerData.gold])
	else:
		log_error("Nemáš dostatek zlata!")

func _cmd_set_hp(args: Array):
	if args.is_empty() or not args[0].is_valid_int():
		log_error("Použití: set_hp <hodnota>")
		return
	var new_hp = args[0].to_int()
	PlayerData.current_hp = clamp(new_hp, 1, PlayerData.max_hp)
	PlayerData.emit_signal("health_changed", PlayerData.current_hp, PlayerData.max_hp)
	log_success("❤️ HP nastaveno na %d/%d" % [PlayerData.current_hp, PlayerData.max_hp])

func _cmd_add_energy(args: Array):
	if args.is_empty() or not args[0].is_valid_int():
		log_error("Použití: add_energy <množství>")
		return
	var amount = args[0].to_int()
	PlayerData.gain_energy(amount)
	log_success("⚡ Přidáno %d energie. Celkem: %d" % [amount, PlayerData.current_energy])

func _cmd_reload_artifacts():
	all_artifacts.clear()
	_load_all_artifacts()
	log_success("🔄 Artefakty znovu načteny!")

func _cmd_help():
	log_message("📖 Dostupné příkazy:")
	log_message("  add_artifact <název> - Přidá artefakt")
	log_message("  remove_artifact <název> - Odebere artefakt")
	log_message("  list_artifacts [owned] - Zobrazí všechny/vlastněné artefakty")
	log_message("  add_all_artifacts - Přidá všechny artefakty jednou")
	log_message("  clear_artifacts - Odstraní všechny artefakty")
	log_message("  artifact_info <název> - Zobrazí detaily artefaktu")
	log_message("  add_gold <číslo> - Přidá zlato")
	log_message("  remove_gold <číslo> - Odebere zlato")
	log_message("  set_hp <číslo> - Nastaví HP")
	log_message("  add_energy <číslo> - Přidá energii")
	log_message("  reload_artifacts - Znovu načte artefakty")
	log_message("  help - Zobrazí tento seznam")

func _show_artifact_examples():
	log_message("💡 Příklady názvů souborů:")
	var examples = []
	for key in all_artifacts.keys():
		examples.append(key)
		if examples.size() >= 5:
			break
	log_message("  " + " | ".join(examples))

func _show_owned_artifacts():
	if PlayerData.artifacts.is_empty():
		log_message("Nevlastníš žádné artefakty.")
		return
	
	log_message("🎒 Vlastněné artefakty (%d):" % PlayerData.artifacts.size())
	for artifact in PlayerData.artifacts:
		var stack_info = ""
		if artifact.max_stacks > 1:
			stack_info = " [%d/%d]" % [artifact.current_stacks, artifact.max_stacks]
		log_message("  - %s%s" % [artifact.artifact_name, stack_info])

func log_message(text: String):
	output_log.append_text("\n" + text)

func log_error(text: String):
	output_log.append_text("\n[color=red]❌ %s[/color]" % text)

func log_success(text: String):
	output_log.append_text("\n[color=green]%s[/color]" % text)
