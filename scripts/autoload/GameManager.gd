# Soubor: scripts/autoload/GameManager.gd (Kombinace funkčního základu a nové logiky)
extends Node

const PlayerClassData = preload("res://data/classes/Tank.tres")
const PlayerSubclassData = preload("res://data/classes/Paladin.tres")

var main_menu_scene = "res://scenes/ui/MainMenu.tscn"
var character_screen_scene = "res://scenes/CharSelect/CharacterScreen.tscn"
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

func _ready():
	global_ui_instance = global_ui_scene.instantiate()
	add_child(global_ui_instance)
	# ZMĚNA 1: Hra se nespustí rovnou, ale zobrazí hlavní menu.
	_change_scene(main_menu_scene)

func start_new_run(seed = null):
	if seed == null:
		randomize()
		current_seed = randi()
	else:
		current_seed = seed
	
	print("Zahajuji nový běh se seedem: ", current_seed)
	
	has_saved_camera_state = false
	current_map_data = null
	PlayerData.initialize_player(PlayerClassData, PlayerSubclassData)
	PlayerData.start_new_run_state()
	
	_change_scene(map_scene)

func start_battle(encounter: EncounterData):
	print("Zahajuji souboj...")
	current_encounter = encounter
	_change_scene(battle_scene)

func battle_finished(player_won: bool):
	if player_won:
		print("Hráč vyhrál! Přecházím na obrazovku odměn.")
		
		if current_encounter and current_encounter.encounter_type == EncounterData.EncounterType.ELITE:
			last_battle_gold_reward = randi_range(40, 60)
		elif current_encounter and current_encounter.encounter_type == EncounterData.EncounterType.BOSS:
			last_battle_gold_reward = randi_range(90, 110)
		else:
			last_battle_gold_reward = randi_range(15, 25)
			
		print("Hráč získává %d zlata." % last_battle_gold_reward)
		
		_change_scene(reward_scene)
	else:
		# ZMĚNA 2: Když hráč prohraje, spočítáme XP a vrátíme se do hlavního menu
		print("Hráč prohrál!")
		var xp_earned = PlayerData.floors_cleared * 10 
		SaveManager.add_xp(xp_earned)
		_change_scene(main_menu_scene)

func go_to_character_screen():
	_change_scene(character_screen_scene)

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

	if is_instance_valid(current_scene):
		current_scene.queue_free()

	var new_scene_resource = load(scene_path)

	if new_scene_resource:
		current_scene = new_scene_resource.instantiate()

		if is_instance_valid(current_scene):
			if scene_path == reward_scene:
				current_scene.gold_reward = last_battle_gold_reward
			
			if "encounter_data" in current_scene:
				current_scene.encounter_data = current_encounter

			get_tree().get_root().call_deferred("add_child", current_scene)
		else:
			printerr("FATÁLNÍ CHYBA: Selhalo instancování scény: ", scene_path)
	else:
		printerr("FATÁLNÍ CHYBA: Nepodařilo se načíst zdroj scény: ", scene_path)
