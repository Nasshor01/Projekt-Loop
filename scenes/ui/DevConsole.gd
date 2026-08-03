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
	# Remake catalog (36) is the live set. Legacy CZ .tres under common/rare/... still exist
	# on disk and inflate the count if we scan the whole tree.
	all_artifacts.clear()
	var remake_list = _recursive_load("res://data/artifacts/catalog/")
	for artifact in remake_list:
		var key = artifact.resource_path.get_file().get_basename()
		all_artifacts[key] = artifact
	var remake_count: int = all_artifacts.size()

	var legacy_list = _recursive_load("res://data/artifacts/")
	var legacy_only: int = 0
	for artifact in legacy_list:
		var key = artifact.resource_path.get_file().get_basename()
		if all_artifacts.has(key):
			continue
		# Keep legacy discoverable under list_artifacts, but remake keys win.
		all_artifacts[key] = artifact
		legacy_only += 1

	log_message("Načteno %d artefaktů (remake catalog: %d, legacy: %d)" % [
		all_artifacts.size(), remake_count, legacy_only
	])

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
			# Skip behaviors/ (scripts only) and nested re-scan of catalog when scanning root
			if dir_name == "behaviors":
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

		"add_apple":
			_cmd_add_artifact(["forbidden_apple"])

		"test_artifacts":
			_cmd_test_artifacts()
		
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
		
		"reset_skill_points":
			_cmd_reset_skill_points()
		
		"add_card":
			_cmd_add_card(args)
		
		"add_cards":
			_cmd_add_cards(args)
		
		"add_card_all_paladin":
			_cmd_add_cards(["paladin"])
		
		"add_card_all_everyone":
			_cmd_add_cards(["everyone"])
		
		"list_cards":
			_cmd_list_cards()
		
		"sfx":
			_cmd_sfx(args)
		
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


func _cmd_test_artifacts() -> void:
	"""Načte všechny behavior skripty a vypíše parse/load chyby."""
	if not has_node("/root/ArtifactManager"):
		log_error("ArtifactManager není dostupný")
		return
	var report: Dictionary = ArtifactManager.validate_all_behavior_scripts()
	var ok: Array = report.get("ok", [])
	var failed: Array = report.get("failed", [])
	log_message("🧪 Behavior scripts OK: %d" % ok.size())
	for name in ok:
		log_message("  ✅ %s" % name)
	if failed.is_empty():
		log_success("Všechny behavior skripty se načetly.")
	else:
		log_error("Behavior scripts FAILED: %d" % failed.size())
		for name in failed:
			log_error("  ❌ %s" % name)
	# Also verify catalog .tres resolve
	var catalog_ok := 0
	var catalog_fail := 0
	for key in all_artifacts.keys():
		var art: ArtifactsData = all_artifacts[key]
		if art and art.behavior_script:
			var inst = art.behavior_script.new()
			if inst is ArtifactBehavior:
				catalog_ok += 1
			else:
				catalog_fail += 1
				log_error("  ❌ catalog %s behavior invalid" % key)
	log_message("📦 Catalog with behavior: %d ok, %d fail" % [catalog_ok, catalog_fail])
	log_success("🔄 Artefakty znovu načteny!")

func _cmd_reset_skill_points():
	if not has_node("/root/SaveManager"):
		log_error("SaveManager není dostupný!")
		return
	
	var save_manager = get_node("/root/SaveManager")
	var meta = save_manager.meta_progress
	
	if not meta:
		log_error("Meta progress není načten!")
		return
	
	var old_skill_points = meta.skill_points
	var hero_id: String = SaveManager.resolve_hero_id()
	var level: int = meta.get_hero_level(hero_id)
	
	# Zavoláme funkci pro přepočet skill points
	save_manager.recalculate_skill_points()
	
	log_success("🔄 Skill points resetovány!")
	log_message("  Hero: %s Level: %d" % [hero_id, level])
	log_message("  Staré skill points: %d" % old_skill_points)
	log_message("  Nové skill points: %d" % meta.skill_points)
	log_message("  Alokované skilly byly resetovány")

func _cmd_add_card(args: Array):
	if args.is_empty():
		log_error("Použití: add_card <card_id>")
		return
	
	var battle_scene = _find_battle_scene()
	if battle_scene and battle_scene.has_method("add_card_to_hand"):
		if battle_scene.add_card_to_hand(args[0]):
			log_success("✅ Karta '%s' přidána do ruky." % args[0])
		else:
			log_error("❌ Karta '%s' nebyla nalezena nebo se nepodařilo přidat." % args[0])
	else:
		log_error("Tento příkaz lze použít pouze v bitvě!")

func _cmd_add_cards(args: Array):
	"""add_cards paladin | add_card_all_paladin — dump folder cards into hand (battle only)."""
	if args.is_empty():
		log_error("Použití: add_cards <paladin|everyone|trapper>")
		log_message("Alias: add_card_all_paladin / add_card_all_everyone")
		return
	var folder := str(args[0]).to_lower().strip_edges()
	if folder.begins_with("all_"):
		folder = folder.substr(4)
	var path := "res://data/cards/%s/" % folder
	if not DirAccess.dir_exists_absolute(path):
		log_error("Složka neexistuje: %s" % path)
		return
	var battle_scene = _find_battle_scene()
	if battle_scene == null or not battle_scene.has_method("add_card_resource_to_hand"):
		log_error("Tento příkaz lze použít pouze v bitvě!")
		return
	var cards := _load_cards_from_folder(path)
	if cards.is_empty():
		log_error("Žádné karty ve složce %s" % path)
		return
	var added := 0
	for card in cards:
		if battle_scene.add_card_resource_to_hand(card):
			added += 1
	log_success("✅ Přidáno %d / %d karet z '%s' do ruky." % [added, cards.size(), folder])

func _load_cards_from_folder(path: String) -> Array[CardData]:
	var out: Array[CardData] = []
	var seen: Dictionary = {}
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res = load(path.path_join(file_name))
			if res is CardData:
				var card: CardData = res
				var key := card.card_id if not card.card_id.is_empty() else file_name
				if not seen.has(key):
					seen[key] = true
					out.append(card)
		file_name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a: CardData, b: CardData): return a.card_id < b.card_id)
	return out

func _find_battle_scene():
	return get_tree().get_first_node_in_group("battle_scene")

func _cmd_list_cards():
	var pool = load("res://data/cards/reward_card_pool.tres") as CardPool
	if not is_instance_valid(pool) or pool.cards.is_empty():
		log_message("📋 Seznam karet (IDs): (pool neexistuje nebo je prázdný)")
		return
	log_message("📋 Seznam karet (IDs) z reward pool (%d):" % pool.cards.size())
	var ids: Array[String] = []
	for c in pool.cards:
		if is_instance_valid(c) and c is CardData:
			ids.append(c.card_id)
	ids.sort()
	for card_id in ids:
		log_message("  - %s" % card_id)

func _cmd_help():
	log_message("📖 Dostupné příkazy:")
	log_message("  add_artifact <název> - Přidá artefakt")
	log_message("  add_apple - Přidá Forbidden Apple")
	log_message("  test_artifacts - Načte všechny behavior skripty (parse check)")
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
	log_message("  reset_skill_points - Resetuje skill points podle levelu")
	log_message("  add_card <card_id> - Přidá kartu do ruky (pouze v bitvě)")
	log_message("  add_cards <paladin|everyone|trapper> - Přidá všechny karty ze složky do ruky")
	log_message("  add_card_all_paladin - Alias pro add_cards paladin")
	log_message("  add_card_all_everyone - Alias pro add_cards everyone")
	log_message("  list_cards - Zobrazí dostupné card_id z reward poolu")
	log_message("  sfx [ui_click|card_play|hit_deal|hit_take|coins|shuffle|all] - Test SFX")
	log_message("  help - Zobrazí tento seznam")

func _cmd_sfx(args: Array):
	if not has_node("/root/AudioManager"):
		log_error("AudioManager není dostupný")
		return
	var which := "all"
	if args.size() > 0:
		which = str(args[0]).to_lower()
	match which:
		"ui_click", "click":
			AudioManager.play_ui_click()
		"card_play", "card":
			AudioManager.play_card_play()
		"hit_deal", "deal", "hit":
			AudioManager.play_hit_deal()
		"hit_take", "take", "hurt":
			AudioManager.play_hit_take()
		"coins", "gold":
			AudioManager.play_coins()
		"shuffle":
			AudioManager.play_card_shuffle()
		"all":
			AudioManager.play_ui_click()
			await get_tree().create_timer(0.25).timeout
			AudioManager.play_card_play()
			await get_tree().create_timer(0.25).timeout
			AudioManager.play_hit_deal()
			await get_tree().create_timer(0.25).timeout
			AudioManager.play_hit_take()
			await get_tree().create_timer(0.25).timeout
			AudioManager.play_coins()
			await get_tree().create_timer(0.35).timeout
			AudioManager.play_card_shuffle()
		_:
			log_error("Neznámý SFX. Použití: sfx [ui_click|card_play|hit_deal|hit_take|coins|shuffle|all]")
			return
	log_success("SFX: %s" % which)

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
