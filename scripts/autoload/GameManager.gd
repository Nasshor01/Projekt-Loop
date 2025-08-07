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

func _ready():
	# Vytvoříme si prázdný Node, který bude sloužit jako bezpečný kontejner
	# pro všechny naše scény.
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
	
	print("Zahajuji nový běh se seedem: ", current_seed)
	
	has_saved_camera_state = false
	current_map_data = null
	# VOLÁNÍ initialize_player ZDE UŽ NENÍ POTŘEBA! Je zavoláno dříve.
	# Místo toho rovnou resetujeme staty pro nový běh.
	PlayerData.start_new_run_state()
	
	_change_scene(map_scene)

func start_new_game_plus(seed = null):
	if seed == null:
		randomize()
		current_seed = randi()
	else:
		current_seed = seed
	
	print("Zahajuji NOVÝ BĚH+ se seedem: ", current_seed)
	
	has_saved_camera_state = false
	current_map_data = null
	# NEVOLÁME initialize_player, protože postava zůstává
	PlayerData.start_ng_plus_state() # Volá částečný reset
	
	_change_scene(map_scene)
	
func select_character_and_go_to_prep(p_class: ClassData, p_subclass: SubclassData):
	# 1. Nejdříve inicializujeme hráče a tím nastavíme aktivní strom
	PlayerData.initialize_player(p_class, p_subclass)
	# 2. AŽ TEĎ, když je vše připraveno, přejdeme na obrazovku se stromem
	go_to_run_prep_screen()
	
func start_battle(encounter: EncounterData):
	print("Zahajuji souboj...")
	current_encounter = encounter
	_change_scene(battle_scene)

func battle_finished(player_won: bool):
	var is_boss = current_encounter and current_encounter.encounter_type == EncounterData.EncounterType.BOSS
	
	if player_won and not is_boss:
		# Běžné vítězství -> obrazovka odměn
		print("Hráč vyhrál! Přecházím na obrazovku odměn.")
		if current_encounter and current_encounter.encounter_type == EncounterData.EncounterType.ELITE:
			last_battle_gold_reward = randi_range(40, 60)
		else:
			last_battle_gold_reward = randi_range(15, 25)
		_change_scene(reward_scene)
	else:
		last_run_was_victory = player_won # Uložíme si, jestli hráč vyhrál (true) nebo prohrál (false)
		# Prohra NEBO vítězství nad bossem -> konec běhu
		if player_won:
			print("Hráč vyhrál hru!")
		else:
			print("Hráč prohrál!")
		
		# Vypočítáme a uložíme XP
		last_run_xp_earned = PlayerData.floors_cleared * 10
		SaveManager.add_xp(last_run_xp_earned)
		
		# Přesun na obrazovku konce běhu
		_change_scene(end_of_run_scene)

func go_to_main_menu():
	_change_scene(main_menu_scene)

func go_to_character_select():
	_change_scene(character_select_scene)

func go_to_run_prep_screen():
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

func _change_scene(scene_path: String):
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

	# Smažeme starou scénu
	if is_instance_valid(current_scene):
		current_scene.queue_free()

	var new_scene_resource = load(scene_path)

	if new_scene_resource:
		current_scene = new_scene_resource.instantiate()

		if is_instance_valid(current_scene):
			if scene_path == reward_scene:
				current_scene.gold_reward = last_battle_gold_reward
			
			if scene_path == end_of_run_scene:
				current_scene.xp_earned = last_run_xp_earned
			
			if "encounter_data" in current_scene:
				current_scene.encounter_data = current_encounter
			
			if scene_path == end_of_run_scene:
				current_scene.setup(last_run_xp_earned, last_run_was_victory)

			# --- ZDE JE KLÍČOVÁ ZMĚNA ---
			# Místo get_tree().get_root() použijeme náš bezpečný kontejner
			scene_container.add_child(current_scene)
			# ------------------------------
		else:
			printerr("FATÁLNÍ CHYBA: Selhalo instancování scény: ", scene_path)
	else:
		printerr("FATÁLNÍ CHYBA: Nepodařilo se načíst zdroj scény: ", scene_path)
