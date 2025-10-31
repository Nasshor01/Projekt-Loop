# Soubor: scripts/autoload/GameManager.gd (Kombinace funkčního základu a nové logiky)
extends Node

var main_menu_scene = "res://scenes/ui/MainMenu.tscn"
var character_select_scene = "res://scenes/CharSelect/CharacterSelectScreen.tscn"
var run_prep_scene = "res://scenes/CharSelect/RunPrepScreen.tscn"
var end_of_run_scene = "res://scenes/ui/EndOfRunScreen.tscn"
var map_scene = "res://scenes/map/Map.tscn"
var battle_scene = "res://scenes/battle/BattleScene.tscn"
var reward_scene = "res://scenes/rewards/RewardScene.tscn"
var game_over_scene = "res://scenes/ui/GameOver.tscn"
var treasure_scene = "res://scenes/rewards/TreasureScene.tscn"
var shop_scene = "res://scenes/shop/ShopScene.tscn"
var rest_scene = "res://scenes/camp/RestScene.tscn"
var global_ui_scene = preload("res://scenes/ui/GlobalUI.tscn")
var event_scene = "res://scenes/events/EventScene.tscn"

var current_scene: Node = null
var current_seed: int
var current_encounter: EncounterData
var current_map_data: MapData = null
var has_saved_camera_state: bool = false
var saved_camera_position: Vector2 = Vector2.ZERO
var saved_camera_zoom: Vector2 = Vector2(1.0, 1.0)
var global_ui_instance: CanvasLayer = null
var last_battle_gold_reward: int = 0
var last_run_xp_earned: int = 0
var scene_container: Node = null
var last_run_was_victory: bool = false

var selected_class_data: ClassData = null
var selected_subclass_data: SubclassData = null

const CARD_REWARD_POOL = preload("res://data/cards/reward_card_pool.tres")
const ELITE_ARTIFACT_POOL = preload("res://data/artifacts/pool/elite_reward_pool.tres")
const BOSS_ARTIFACT_POOL = preload("res://data/artifacts/pool/boss_reward_pool.tres")

var last_battle_rewards = {}

func _ready():
	if has_node("/root/DebugLogger"):
		DebugLogger.log_info("=== GAME MANAGER STARTED ===")
	DebugLogger.log_info("=== GAME MANAGER STARTED ===")
	DebugLogger.log_system_info() # Zaloguje system info
	scene_container = Node.new()
	scene_container.name = "SceneContainer"
	add_child(scene_container)
	
	global_ui_instance = global_ui_scene.instantiate()
	add_child(global_ui_instance)
	go_to_main_menu()

func start_new_run(seed = null):
	if seed == null:
		randomize()
		current_seed = randi()
	else:
		current_seed = seed
	
	# NOVÉ DEBUG LOGOVÁNÍ
	DebugLogger.log_info("=== STARTING NEW RUN ===", "GAME_FLOW")
	DebugLogger.log_info("Seed: %d" % current_seed, "GAME_FLOW")
	
	has_saved_camera_state = false
	current_map_data = null
	
	PlayerData.start_new_run_state()
	
	# LOGUJ POČÁTEČNÍ STAV
	DebugLogger.log_full_game_state()
	
	_change_scene(map_scene)

func start_new_game_plus(seed = null):
	if seed == null:
		randomize()
		current_seed = randi()
	else:
		current_seed = seed
	
	print("Zahajuji NOVÝ BĚH+ se seedem: ", current_seed)
	PlayerData.ng_plus_level += 1
	
	has_saved_camera_state = false
	current_map_data = null
	# NEVOLÁME initialize_player, protože postava zůstává
	PlayerData.start_ng_plus_state() # Volá částečný reset
	
	_change_scene(map_scene)
	
func start_battle(encounter: EncounterData):
	DebugLogger.log_info("=== STARTING BATTLE ===", "BATTLE")
	DebugLogger.log_info("Encounter: %s" % encounter.resource_path, "BATTLE")
	DebugLogger.log_info("Encounter type: %s" % str(encounter.encounter_type), "BATTLE")
	
	# Loguj stav před bitvou
	DebugLogger.log_player_stats()
	DebugLogger.log_deck_state()
	
	current_encounter = encounter
	_change_scene(battle_scene)

func battle_finished(player_won: bool, final_hp: int = -1, final_shield: int = -1):
	DebugLogger.log_info("=== BATTLE FINISHED ===", "BATTLE")
	DebugLogger.log_battle_event("battle_result", {
		"won": player_won,
		"floors_cleared": PlayerData.floors_cleared,
		"hp_remaining": PlayerData.current_hp,
	})
	
	DebugLogger.log_player_stats()
	DebugLogger.log_artifacts()
	
	if player_won:
		if final_hp != -1:
			PlayerData.current_hp = final_hp
		if final_shield != -1:
			PlayerData.global_shield = final_shield
			print("GLOBÁLNÍ ŠTÍT uložen, nová hodnota: %d" % PlayerData.global_shield)

		if is_instance_valid(current_encounter) and current_encounter.encounter_type == EncounterData.EncounterType.BOSS:
			last_run_was_victory = true
			last_run_xp_earned = PlayerData.floors_cleared * 15 # Bonus XP for victory
			SaveManager.add_xp(last_run_xp_earned)
			DebugLogger.log_info("XP earned after victory: %d" % last_run_xp_earned, "PROGRESSION")
			_change_scene(end_of_run_scene)
		else:
			_prepare_battle_rewards()
			_change_scene(reward_scene)
	else:
		last_run_was_victory = false
		last_run_xp_earned = PlayerData.floors_cleared * 10
		SaveManager.add_xp(last_run_xp_earned)
		
		DebugLogger.log_info("XP earned: %d" % last_run_xp_earned, "PROGRESSION")
		DebugLogger.log_meta_progress()
		
		_change_scene(end_of_run_scene)

func go_to_main_menu():
	_change_scene(main_menu_scene)

func go_to_character_select():
	_change_scene(character_select_scene)

func go_to_run_prep_screen(p_class: ClassData, p_subclass: SubclassData):
	selected_class_data = p_class
	selected_subclass_data = p_subclass
	
	# Loguj výběr postavy
	DebugLogger.log_info("=== CHARACTER SELECTED ===", "CHAR_SELECT")
	DebugLogger.log_info("Class: %s" % p_class.resource_path, "CHAR_SELECT")
	var subclass_name = "Unknown"
	if "subclass_name" in p_subclass:
		subclass_name = p_subclass.subclass_name
	DebugLogger.log_info("Subclass: %s" % subclass_name, "CHAR_SELECT")
	
	_change_scene(run_prep_scene)

func reward_chosen():
	print("Odměna vybrána, vracím se na mapu.")
	_change_scene(map_scene)

func show_treasure_node():
	print("Hráč vstoupil na pole s pokladem.")
	_change_scene(treasure_scene)

func treasure_collected():
	print("Poklad sebrán, vracím se na mapu.")
	_change_scene(map_scene)

func go_to_shop():
	print("Vstup do obchodu.")
	_change_scene(shop_scene)

func leave_shop():
	print("Odchod z obchodu, návrat na mapu.")
	_change_scene(map_scene)
	
func go_to_rest_scene():
	print("Vstup do scény odpočinku.")
	_change_scene(rest_scene)

func go_to_event_scene():
	print("Vstup do event scény")
	DebugLogger.log_info("Entering event scene", "GAME_FLOW")
	_change_scene(event_scene)

func event_completed():
	print("Event dokončen, návrat na mapu")
	DebugLogger.log_info("Event completed, returning to map", "GAME_FLOW")
	_change_scene(map_scene)

func _change_scene(scene_path: String):
	DebugLogger.log_scene_change(str(current_scene.scene_file_path) if current_scene else "none", scene_path)
	print("DEBUG: Pokouším se změnit scénu na: ", scene_path)

	if is_instance_valid(global_ui_instance):
		if scene_path == map_scene or scene_path == battle_scene:
			global_ui_instance.show()
			if scene_path == map_scene:
				global_ui_instance.show_hp()
			else:
				global_ui_instance.hide_hp()
		else:
			global_ui_instance.hide()

	if is_instance_valid(current_scene):
		current_scene.queue_free()

	var new_scene_resource = load(scene_path)
	if new_scene_resource:
		current_scene = new_scene_resource.instantiate()
		
		# DEBUG: Zkontrolujeme typ scény před přiřazováním vlastností
		print("DEBUG: Načtená scéna - typ: ", current_scene.get_class())
		print("DEBUG: Načtená scéna - název: ", current_scene.name)
		
		if is_instance_valid(current_scene):
			# Nejdřív přidáme do stromu, pak nastavujeme vlastnosti
			scene_container.add_child(current_scene)
			
			# Nastavení vlastností scény
			if scene_path == reward_scene:
				print("DEBUG: Nastavujem reward scene properties...")
				print("DEBUG: gold_reward = ", last_battle_rewards.get("gold", 0))
				print("DEBUG: card_choices count = ", last_battle_rewards.get("cards", []).size())
				print("DEBUG: artifact_rewards count = ", last_battle_rewards.get("artifacts", []).size())
				
				# Zkontrolujeme, že current_scene má tyto vlastnosti
				if "gold_reward" in current_scene:
					current_scene.gold_reward = last_battle_rewards.get("gold", 0)
				else:
					print("VAROVÁNÍ: current_scene nemá vlastnost 'gold_reward'")
				
				if "card_choices" in current_scene:
					current_scene.card_choices = last_battle_rewards.get("cards", [])
				else:
					print("VAROVÁNÍ: current_scene nemá vlastnost 'card_choices'")
				
				if "artifact_rewards" in current_scene:
					current_scene.artifact_rewards = last_battle_rewards.get("artifacts", [])
				else:
					print("VAROVÁNÍ: current_scene nemá vlastnost 'artifact_rewards'")
				
				current_scene.setup_ui()
			
			if scene_path == end_of_run_scene:
				if current_scene.has_method("setup"):
					current_scene.setup(last_run_xp_earned, last_run_was_victory)
				else:
					print("VAROVÁNÍ: EndOfRunScene nemá metodu setup()")
			
			if "encounter_data" in current_scene:
				current_scene.encounter_data = current_encounter
		else:
			printerr("FATÁLNÍ CHYBA: Selhalo instancování scény: ", scene_path)
	else:
		printerr("FATÁLNÍ CHYBA: Nepodařilo se načíst zdroj scény: ", scene_path)

func _prepare_battle_rewards():
	last_battle_rewards.clear()
	var encounter_type = current_encounter.encounter_type if current_encounter else EncounterData.EncounterType.NORMAL

	print("DEBUG: Připravuji odměny pro encounter typu: ", encounter_type)

	# 1. Odměna za zlato
	var gold = 0
	match encounter_type:
		EncounterData.EncounterType.NORMAL:
			gold = randi_range(15, 25)
		EncounterData.EncounterType.ELITE:
			gold = randi_range(40, 60)
		EncounterData.EncounterType.BOSS:
			gold = randi_range(90, 110)
	last_battle_rewards["gold"] = gold

	# 2. Odměna karet (pro všechny typy kromě bosse)
	if encounter_type != EncounterData.EncounterType.BOSS:
		if is_instance_valid(CARD_REWARD_POOL) and CARD_REWARD_POOL.cards != null and not CARD_REWARD_POOL.cards.is_empty():
			var available_cards = CARD_REWARD_POOL.cards.duplicate()
			available_cards.shuffle()
			last_battle_rewards["cards"] = available_cards.slice(0, 3)
		else:
			print("VAROVÁNÍ: CARD_REWARD_POOL je prázdný nebo neexistuje")
			last_battle_rewards["cards"] = []
	else:
		last_battle_rewards["cards"] = []

	# 3. Odměna artefaktů (jen pro elity a bossy)
	var artifact_reward = []
	if encounter_type == EncounterData.EncounterType.ELITE:
		if randf() < 0.40: # 40% šance
			var artifact = _get_random_elite_artifact()
			if artifact:
				artifact_reward.append(artifact)
	
	elif encounter_type == EncounterData.EncounterType.BOSS:
		if is_instance_valid(BOSS_ARTIFACT_POOL) and BOSS_ARTIFACT_POOL.artifacts != null and not BOSS_ARTIFACT_POOL.artifacts.is_empty():
			var available = BOSS_ARTIFACT_POOL.artifacts.filter(func(art): return PlayerData.can_gain_artifact(art))
			available.shuffle()
			var choices_count = min(3, available.size())
			artifact_reward = available.slice(0, choices_count)
		else:
			print("VAROVÁNÍ: BOSS_ARTIFACT_POOL je prázdný nebo neexistuje")
	
	last_battle_rewards["artifacts"] = artifact_reward
	print("DEBUG: Připravené odměny: ", last_battle_rewards)
	
func _get_random_elite_artifact() -> ArtifactsData:
	if not is_instance_valid(ELITE_ARTIFACT_POOL) or ELITE_ARTIFACT_POOL.artifacts == null or ELITE_ARTIFACT_POOL.artifacts.is_empty():
		print("VAROVÁNÍ: ELITE_ARTIFACT_POOL je prázdný nebo neexistuje")
		return null
		
	var available = ELITE_ARTIFACT_POOL.artifacts.filter(func(art): return PlayerData.can_gain_artifact(art))
	if available.is_empty():
		print("DEBUG: Žádné dostupné elite artefakty")
		return null

	var roll = randf()
	var target_rarity = ArtifactsData.ArtifactType.COMMON
	if roll < 0.05: # 5% Rare
		target_rarity = ArtifactsData.ArtifactType.RARE
	elif roll < 0.35: # 30% Uncommon
		target_rarity = ArtifactsData.ArtifactType.UNCOMMON

	var filtered_pool = available.filter(func(art): return art.artifact_type == target_rarity)
	if not filtered_pool.is_empty():
		return filtered_pool.pick_random()
	
	# Fallback, pokud se nenajde daná rarita, zkusíme o stupeň nižší
	if target_rarity == ArtifactsData.ArtifactType.RARE:
		filtered_pool = available.filter(func(art): return art.artifact_type == ArtifactsData.ArtifactType.UNCOMMON)
		if not filtered_pool.is_empty(): 
			return filtered_pool.pick_random()

	# Poslední záchrana, vrátíme jakýkoliv common
	filtered_pool = available.filter(func(art): return art.artifact_type == ArtifactsData.ArtifactType.COMMON)
	if not filtered_pool.is_empty(): 
		return filtered_pool.pick_random()

	print("DEBUG: Nepodařilo se najít žádný vhodný artefakt")
	return null # Pokud v poolu nejsou ani common, nevrátíme nic
