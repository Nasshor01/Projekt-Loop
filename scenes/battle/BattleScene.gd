extends Node2D

const SHAPE_DEFAULT = [
	"111111111111111", "111111111111111", "111111111111111", "111111111111111", "111111111111111",
	"111111111111111", "111111111111111", "111111111111111", "111111111111111", "111111111111111",
]
const SHAPE_CROSS = [
	"0001111111000", "0001111111000", "1111111111111", "1111111111111", "1111111111111",
	"1111111111111", "0001111111000", "0001111111000",
]
const SHAPE_DIAMOND = [
	"00001110000", "00011111000", "00111111100", "01111111110", "11111111111",
	"01111111110", "00111111100", "00011111000", "00001110000",
]

const UnitScene = preload("res://scenes/battle/Unit.tscn")
const AIController = preload("res://scripts/ai/EnemyAIController.gd")

@export var encounter_data: EncounterData

@onready var player_info_panel = $CanvasLayer/PlayerInfoPanel
@onready var enemy_info_panel = $CanvasLayer/EnemyInfoPanel
@onready var draw_pile_button: TextureButton = $CanvasLayer/DrawPileButton
@onready var discard_pile_button: TextureButton = $CanvasLayer/DiscardPileButton
@onready var card_pile_viewer: PanelContainer = $CanvasLayer/CardPileViewer
@onready var player_hand_ui_instance: Control = $CanvasLayer/PlayerHandUI
@onready var end_turn_button: Button = $CanvasLayer/EndTurnButton
@onready var victory_label: Label = $CanvasLayer/VictoryLabel
@onready var energy_label: Label = $CanvasLayer/EnergyLabel
@onready var win_button: Button = $CanvasLayer/WinButton
@onready var battle_grid_instance: BattleGrid = $BattleGrid
@export var camera_2d: Camera2D
@onready var turn_counter_label: Label = $CanvasLayer/TurnCounterLabel

@export var camera_speed = 1.0
@export var camera_zoom_speed = 0.1
@export var camera_min_zoom = 0.5
@export var camera_max_zoom = 2.0

enum PlayerActionState { IDLE, CARD_SELECTED, UNIT_SELECTED }
var _player_action_state: PlayerActionState = PlayerActionState.IDLE

enum BattleState { SETUP, AWAITING_PLAYER_SPAWN, PLAYER_TURN, ENEMY_TURN, PROCESSING, BATTLE_OVER }
var _current_battle_state: BattleState = BattleState.SETUP


@export var starting_hand_size: int = 5

var _selected_card_ui: Control = null
var _selected_card_data: CardData = null
# =================================================================
#pohyby a ai enemy
var _player_unit_node: Unit = null
var _selected_unit: Unit = null
var _enemy_units: Array[Unit] = []
# =================================================================

var _is_action_processing: bool = false
var _cards_to_draw_queue: int = 0
var _is_drawing_cards: bool = false
var _is_first_turn: bool = true
var _current_turn_number: int = 0
var _is_extra_turn: bool = false

func _ready():
	DebugLogger.log_info("Battle scene loaded", "BATTLE")
	player_info_panel.update_from_player_data()
	_current_battle_state = BattleState.SETUP
	_is_first_turn = true
	victory_label.visible = false
	enemy_info_panel.hide_panel()
	card_pile_viewer.hide()
	
	if has_node("/root/TurnManager"):
		TurnManager.round_started.connect(_on_round_started)
		TurnManager.turn_started.connect(_on_turn_started)
		TurnManager.combat_ended.connect(_on_combat_ended)
	else:
		printerr("CHYBA: TurnManager není dostupný!")

	PlayerData.reset_battle_stats()
	PlayerData.energy_changed.connect(_on_energy_changed)
	player_hand_ui_instance.hand_card_was_clicked.connect(_on_player_hand_card_clicked)
	player_hand_ui_instance.card_hover_started.connect(_on_card_hover_started)
	player_hand_ui_instance.card_hover_ended.connect(_on_card_hover_ended)
	draw_pile_button.pile_clicked.connect(_on_draw_pile_clicked)
	discard_pile_button.pile_clicked.connect(_on_discard_pile_clicked)
	win_button.pressed.connect(_on_win_button_pressed)
	
	player_hand_ui_instance.card_draw_animation_finished.connect(_on_card_draw_animation_finished)
	player_hand_ui_instance.hand_discard_animation_finished.connect(_on_hand_discard_animation_finished)
	
	ArtifactManager.overdose_warning_triggered.connect(_on_overdose_warning)
	
	_setup_camera_boundaries()
	battle_grid_instance.set_camera(camera_2d)
	_generate_grid_from_shape()
	
	start_player_spawn_selection()

func _unhandled_input(event: InputEvent):
	if _is_action_processing: return

	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE or event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		camera_2d.position -= event.relative / camera_2d.zoom * camera_speed

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var new_zoom_value = camera_2d.zoom / (1 + camera_zoom_speed)
			camera_2d.zoom = new_zoom_value.clamp(Vector2(camera_min_zoom, camera_min_zoom), Vector2(camera_max_zoom, camera_max_zoom))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var new_zoom_value = camera_2d.zoom * (1 + camera_zoom_speed)
			camera_2d.zoom = new_zoom_value.clamp(Vector2(camera_min_zoom, camera_min_zoom), Vector2(camera_max_zoom, camera_max_zoom))
	
	# LOGIKA PRO VÝBĚR SPAWNU
	if _current_battle_state == BattleState.AWAITING_PLAYER_SPAWN:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var clicked_cell = battle_grid_instance.get_cell_at_world_position(get_global_mouse_position())
			if battle_grid_instance.is_cell_a_valid_spawn_point(clicked_cell):
				confirm_player_spawn(clicked_cell)
				get_viewport().set_input_as_handled()
		return

	if card_pile_viewer.visible and event.is_action_pressed("ui_cancel"):
		card_pile_viewer.hide()
		return

	if _current_battle_state != BattleState.PLAYER_TURN: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _player_action_state == PlayerActionState.CARD_SELECTED:
			var is_self_targeting_card = false
			if is_instance_valid(_selected_card_data):
				is_self_targeting_card = _selected_card_data.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELF_UNIT)
			if is_self_targeting_card:
				if is_instance_valid(_player_unit_node):
					try_play_card(_selected_card_data, _player_unit_node)
					get_viewport().set_input_as_handled()
				else:
					_reset_player_selection()
					get_viewport().set_input_as_handled()
				return
			
			var clicked_grid_cell = battle_grid_instance.get_cell_at_world_position(get_global_mouse_position())
			var target_node = battle_grid_instance.get_object_on_cell(clicked_grid_cell)
			try_play_card(_selected_card_data, target_node)
			get_viewport().set_input_as_handled()
		elif _player_action_state == PlayerActionState.UNIT_SELECTED:
			var clicked_grid_cell = battle_grid_instance.get_cell_at_world_position(get_global_mouse_position())
			if battle_grid_instance.is_cell_movable(clicked_grid_cell):
				_execute_move(_selected_unit, clicked_grid_cell)
			else:
				_reset_player_selection()
			get_viewport().set_input_as_handled()


# ===== NOVÉ FUNKCE PRO INICIATIVNÍ SYSTÉM =====

func _on_round_started(round_number: int):
	"""Volá se na začátku každého kola"""
	_current_turn_number = round_number
	_update_turn_display()
	print("=== KOLO %d ===" % round_number)

func _on_turn_started(unit: Unit):
	"""Volá se když je na řadě další jednotka"""
	if not is_instance_valid(unit):
		TurnManager.next_turn()
		return
	
	# Zavolej start_turn na jednotce
	var extra_draw = unit.start_turn()
	
	# Rozhodní, zda jde o hráče nebo AI
	if unit.unit_data.faction == UnitData.Faction.PLAYER:
		_start_player_initiative_turn(unit, extra_draw)
	else:
		_start_enemy_initiative_turn(unit)

func _start_player_initiative_turn(player_unit: Unit, extra_draw: int = 0):
	"""Zahájí tah hráče v iniciativním systému"""
	_current_battle_state = BattleState.PROCESSING
	end_turn_button.disabled = true
	
	# Reset adrenaline tracking
	PlayerData.reset_adrenaline_tracking()
	
	if PlayerData.has_adrenaline_addiction:
		_show_floating_notification("💉 Závislost aktivní (limit: 2 Adrenaliny)", Color.PURPLE)
	
	# Reset energie
	PlayerData.reset_energy()
	
	# START_OF_TURN artefakty
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_turn_start()
	
	# Dober karty
	_cards_to_draw_queue = starting_hand_size + extra_draw
	_draw_next_card_in_queue()
	
	# Zobraz AI záměry
	set_enemy_intents()
	battle_grid_instance.show_danger_zone(_enemy_units)

func _start_enemy_initiative_turn(enemy_unit: Unit):
	"""Zahájí tah nepřítele v iniciativním systému"""
	_current_battle_state = BattleState.ENEMY_TURN
	end_turn_button.disabled = true
	
	battle_grid_instance.hide_danger_zone()
	enemy_unit.hide_intent()
	
	await _process_single_enemy_action(enemy_unit)
	
	# Zavolej end_turn na jednotce
	enemy_unit.end_turn()
	
	# Přejdi na další tah
	TurnManager.next_turn()

func _process_single_enemy_action(enemy_unit: Unit):
	"""Zpracuje akci jednoho nepřítele"""
	if not is_instance_valid(enemy_unit):
		return
	
	var player_units_array: Array = [_player_unit_node]
	
	var ai_instance = null
	if is_instance_valid(enemy_unit.unit_data) and is_instance_valid(enemy_unit.unit_data.ai_script):
		ai_instance = enemy_unit.unit_data.ai_script.new()
	else:
		return
	
	# Získáme akci POUZE JEDNOU
	var action = ai_instance.get_next_action(enemy_unit, player_units_array, battle_grid_instance)
	
	match action.type:
		EnemyAIBase.AIAction.ActionType.ATTACK:
			await enemy_unit.attack(action.target_unit, action.damage_multiplier)
		
		EnemyAIBase.AIAction.ActionType.RUSH:
			if enemy_unit.can_move():
				enemy_unit.use_move_action()
				var path = action.move_path
				
				if path.size() > 1:
					var final_target_pos = path[-1]
					
					battle_grid_instance.remove_object_by_instance(enemy_unit)
					battle_grid_instance.place_object_on_cell(enemy_unit, final_target_pos, true)
					
					var target_terrain = battle_grid_instance.get_terrain_on_cell(final_target_pos)
					if is_instance_valid(target_terrain):
						enemy_unit.process_terrain_effects(target_terrain)
					
					await get_tree().create_timer(0.4).timeout
					
					# Útok po RUSH (pokud je cíl platný)
					if is_instance_valid(action.target_unit) and can_attack_target(enemy_unit, action.target_unit, battle_grid_instance):
						await enemy_unit.attack(action.target_unit, action.damage_multiplier)
		
		EnemyAIBase.AIAction.ActionType.MOVE:
			if enemy_unit.can_move():
				enemy_unit.use_move_action()
				var path = action.move_path
				
				if path.size() > 1:
					var move_dist = min(path.size() - 1, enemy_unit.get_current_movement_range())
					var final_target_pos = path[move_dist]
					
					for terrain_check_index in range(1, move_dist + 1):
						var path_cell = path[terrain_check_index]
						var terrain_on_cell = battle_grid_instance.get_terrain_on_cell(path_cell)
						if is_instance_valid(terrain_on_cell) and terrain_on_cell.terrain_name == "Mud":
							final_target_pos = path_cell
							break
					
					battle_grid_instance.remove_object_by_instance(enemy_unit)
					battle_grid_instance.place_object_on_cell(enemy_unit, final_target_pos, true)
					
					var target_terrain = battle_grid_instance.get_terrain_on_cell(final_target_pos)
					if is_instance_valid(target_terrain):
						enemy_unit.process_terrain_effects(target_terrain)
					
					await get_tree().create_timer(0.4).timeout
					
					# !!! ODSTRANĚNO VNOŘENÉ VOLÁNÍ AI !!!
					# var post_move_action = ai_instance.get_next_action(enemy_unit, player_units_array, battle_grid_instance)
					# if post_move_action.type == EnemyAIBase.AIAction.ActionType.ATTACK:
					# 	await enemy_unit.attack(post_move_action.target_unit, post_move_action.damage_multiplier)
		
		EnemyAIBase.AIAction.ActionType.PASS:
			pass
	
	
	# ===== ZDE JE NOVÁ LOGIKA POČÍTÁNÍ FRUSTRACE =====
	# Zkontrolujeme, zda AI má skript Berserkera, než začneme počítat
	if is_instance_valid(enemy_unit.unit_data.ai_script) and "BerserkerAI" in enemy_unit.unit_data.ai_script.resource_path:
		
		# Pokud akce byla útok NEBO rush, resetuj frustraci
		if action.type == EnemyAIBase.AIAction.ActionType.ATTACK or action.type == EnemyAIBase.AIAction.ActionType.RUSH:
			enemy_unit.berserker_frustration = 0
			print("✅ [BattleScene] Frustrace resetována (útok proveden).")
		
		# Pokud to byl pohyb nebo pass (a AI ještě není v rage), zvyšíme frustraci
		# POZNÁMKA: Pokud chcete, aby se frustrace zvyšovala i v RAGE módu (pokud se netrefí),
		# odstraňte podmínku 'and not enemy_unit.is_permanently_enraged'
		elif (action.type == EnemyAIBase.AIAction.ActionType.MOVE or action.type == EnemyAIBase.AIAction.ActionType.PASS):
			enemy_unit.berserker_frustration += 1
			print("⬆️ [BattleScene] Frustrace zvýšena na: %d (bez útoku)." % enemy_unit.berserker_frustration)

func _on_combat_ended(player_won: bool):
	"""Volá se když TurnManager ukončí souboj"""
	_current_battle_state = BattleState.BATTLE_OVER
	
	if player_won:
		end_battle_as_victory()
	else:
		GameManager.battle_finished(false)

# NOVÉ A UPRAVENÉ FUNKCE PRO START HRY
func start_player_spawn_selection():
	_current_battle_state = BattleState.AWAITING_PLAYER_SPAWN
	var spawn_points = battle_grid_instance.get_player_spawn_points(3) # Zobrazí pozice v prvních 3 sloupcích
	battle_grid_instance.show_player_spawn_points(spawn_points)
	end_turn_button.disabled = true

func _start_combat_with_turn_manager(units_to_start: Array[Unit]):
	"""Zahájí souboj s TurnManagerem."""
	if has_node("/root/TurnManager"):
		TurnManager.start_combat(units_to_start)
	else:
		printerr("BattleScene: TurnManager není dostupný pro start_combat!")

func confirm_player_spawn(at_position: Vector2i):
	battle_grid_instance.hide_player_spawn_points()
	
	spawn_player_unit_at(at_position)
	spawn_enemy_units()
	_place_terrain_features()
	
	# NOVÉ: Reset artefaktů na začátku souboje (PŘED prvním tahem)
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_combat_start()

	# ===== OPRAVA ZDE: Definice 'all_units' =====
	# Musíme shromáždit všechny jednotky, abychom je mohli předat TurnManageru
	var all_units: Array[Unit] = []
	if is_instance_valid(_player_unit_node):
		all_units.append(_player_unit_node)
	all_units.append_array(_enemy_units) # Přidá všechny nepřátele
	
	# (Poznámka: Signály 'died' už připojujete ve funkcích
	# spawn_player_unit_at a spawn_enemy_units, což je v pořádku)
	# ==============================================

	# ===== Zahájení souboje přes TurnManager =====
	# Předáme pouze validní jednotky
	var valid_units = all_units.filter(func(u): return is_instance_valid(u)) 
	call_deferred("_start_combat_with_turn_manager", valid_units)
	# ====================================================


func spawn_player_unit_at(grid_pos: Vector2i):
	if PlayerData.selected_subclass and PlayerData.selected_subclass.specific_unit_data:
		_player_unit_node = _spawn_unit(PlayerData.selected_subclass.specific_unit_data, grid_pos)
		if is_instance_valid(_player_unit_node):
			_player_unit_node.unit_selected.connect(_on_unit_selected_on_grid)
			_player_unit_node.stats_changed.connect(_on_unit_stats_changed)
			_player_unit_node.died.connect(_on_unit_died)




func _update_turn_display():
	"""Aktualizuje zobrazení čísla tahu"""
	if is_instance_valid(turn_counter_label):
		turn_counter_label.text = "Tah: %d" % _current_turn_number

func start_extra_turn():
	"""Spustí PLNOHODNOTNÝ extra tah hráče"""
	print("⚡ SPOUŠTÍM EXTRA TAH!")
	_is_extra_turn = false  # Reset flag
	
	# 1. ODHOĎ SOUČASNÉ KARTY (jako konec normálního tahu)
	PlayerData.discard_hand()
	player_hand_ui_instance.clear_hand()  # Vyčisti UI
	_update_pile_counts()
	
	# 2. RESETUJ ENERGII
	PlayerData.reset_energy()
	
	# 3. RESETUJ POHYB JEDNOTKY (KLÍČOVÉ!)
	if is_instance_valid(_player_unit_node):
		_player_unit_node.reset_for_new_turn()  # Toto resetuje pohyb!
	
	# 4. DOBÍREJ NOVÉ KARTY (normální množství)
	_cards_to_draw_queue = starting_hand_size
	_draw_next_card_in_queue()
	
	# 5. NASTAV SPRÁVNÝ STAV
	_current_battle_state = BattleState.PLAYER_TURN
	end_turn_button.disabled = false
	


# Přidejte debug do signálu stats_changed
func _on_unit_stats_changed(unit_node: Node2D):
	if is_instance_valid(unit_node) and unit_node == _player_unit_node:
		player_info_panel.update_stats(unit_node)

func _draw_next_card_in_queue():
	if _is_drawing_cards: return # Zabráníme spuštění, pokud už běží
	if _cards_to_draw_queue <= 0:
		_finish_drawing_hand()
		return

	_is_drawing_cards = true
	var cards_drawn = PlayerData.draw_cards(1)
	
	if cards_drawn > 0:
		var new_card = PlayerData.current_hand.back()
		player_hand_ui_instance.add_card_animated(new_card, draw_pile_button.global_position)
		_update_pile_counts()
	else:
		if not PlayerData.discard_pile.is_empty():
			_reshuffle_and_continue_drawing()
		else:
			_finish_drawing_hand()

func _on_card_draw_animation_finished():
	_cards_to_draw_queue -= 1
	_is_drawing_cards = false
	_draw_next_card_in_queue()

func _reshuffle_and_continue_drawing():
	print("Míchám odhazovací balíček...")
	var tween = create_tween()
	tween.tween_property(discard_pile_button, "modulate", Color.YELLOW, 0.2)
	tween.tween_property(discard_pile_button, "modulate", Color.WHITE, 0.2)
	
	tween.finished.connect(func():
		PlayerData.reshuffle_discard_into_draw_pile()
		_update_pile_counts()
		
		var bounce_tween = create_tween()
		bounce_tween.tween_property(draw_pile_button, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_QUAD)
		bounce_tween.tween_property(draw_pile_button, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE)
		
		bounce_tween.finished.connect(func():
			_is_drawing_cards = false
			_draw_next_card_in_queue()
		)
	)

func _finish_drawing_hand():
	print("Dobírání dokončeno.")
	_is_drawing_cards = false
	player_hand_ui_instance._request_arrange()
	_current_battle_state = BattleState.PLAYER_TURN
	end_turn_button.disabled = false


func _on_hand_discard_animation_finished():
	PlayerData.discard_hand()
	_update_pile_counts()
	
	# ===== UPRAVENO: Přejdi na další tah =====
	var timer = get_tree().create_timer(0.3)
	timer.timeout.connect(func():
		if has_node("/root/TurnManager"):
			TurnManager.next_turn()
	)
	# =========================================

func end_battle_as_victory():
	_current_battle_state = BattleState.BATTLE_OVER
	if is_instance_valid(_player_unit_node):
		# UPOZORNĚNÍ: Přímé nastavování current_hp obejde náš nový signál.
		# Prozatím to necháme, ale do budoucna by bylo lepší mít
		# funkci PlayerData.set_health(), která signál také vyšle.
		PlayerData.current_hp = _player_unit_node.current_health
		PlayerData.global_shield = _player_unit_node.current_block
		print("GLOBÁLNÍ ŠTÍT uložen, nová hodnota: %d" % PlayerData.global_shield)
	GameManager.battle_finished(true)

func _on_win_button_pressed():
	end_battle_as_victory()

func _on_unit_died(unit_node: Node2D):
	"""Zpracuje smrt jednotky"""
	print("=== Jednotka zemřela: %s ===" % unit_node.unit_data.unit_name)
	
	# Zpracuj oživení hráče
	if unit_node == _player_unit_node:
		if PlayerData.has_revive:
			print("!!! BOŽSKÁ OCHRANA AKTIVOVÁNA !!!")
			PlayerData.has_revive = false
			var heal_amount = PlayerData.max_hp / 2
			if unit_node.has_method("heal"):
				unit_node.heal(heal_amount)
			return
	
	# Trigger enemy death artefakty
	if unit_node.unit_data.faction == UnitData.Faction.ENEMY:
		if has_node("/root/ArtifactManager"):
			ArtifactManager.on_enemy_death(unit_node)
	
	# Odeber ze seznamu
	if _enemy_units.has(unit_node):
		_enemy_units.erase(unit_node)
	
	battle_grid_instance.remove_object_by_instance(unit_node)
	
	# Animace zmizení
	var tween = create_tween()
	tween.tween_property(unit_node, "modulate:a", 0.0, 0.5)
	
	# ===== UPRAVENO: Odregistruj až PO animaci =====
	await tween.finished
	
	if has_node("/root/TurnManager"):
		TurnManager.unregister_unit(unit_node)
	
	unit_node.queue_free()


func spawn_enemy_units():
	print("=== DEBUG: SPAWNING ENEMIES ===")
	
	if not encounter_data:
		printerr("BattleScene: Chybí EncounterData!")
		return

	print("Encounter data: %s" % encounter_data.resource_path)
	print("Počet nepřátel: %d" % encounter_data.enemies.size())

	var all_active_cells = battle_grid_instance._active_cells.keys()
	var player_cell = Vector2i.ZERO
	if is_instance_valid(_player_unit_node):
		player_cell = _player_unit_node.grid_position

	var available_spawn_cells: Array[Vector2i] = []
	
	for cell in all_active_cells:
		if cell.x < battle_grid_instance.grid_columns / 2: continue
		if cell == player_cell: continue
			
		var terrain = battle_grid_instance.get_terrain_on_cell(cell)
		var is_walkable = not terrain or terrain.is_walkable
		var is_occupied = battle_grid_instance.get_object_on_cell(cell) != null
		
		if is_walkable and not is_occupied:
			available_spawn_cells.append(cell)

	print("Dostupných spawn pozic: %d" % available_spawn_cells.size())

	for i in range(encounter_data.enemies.size()):
		var enemy_entry = encounter_data.enemies[i]
		print("=== SPAWNING ENEMY %d ===" % (i + 1))
		
		if not enemy_entry or not enemy_entry.unit_data:
			print("CHYBA: Nevalidní enemy entry!")
			continue
			
		print("Enemy data:")
		print("  - unit_name: %s" % enemy_entry.unit_data.unit_name)
		print("  - max_health: %d" % enemy_entry.unit_data.max_health)
		print("  - ai_script: %s" % str(enemy_entry.unit_data.ai_script))
		
		if available_spawn_cells.is_empty():
			printerr("Nedostatek spawn pozic!")
			break
			
		var random_pos = available_spawn_cells.pick_random()
		available_spawn_cells.erase(random_pos)
		print("  - spawn pozice: %s" % str(random_pos))

		var enemy_node = _spawn_unit(enemy_entry.unit_data, random_pos)
		if is_instance_valid(enemy_node):
			print("  ✅ Enemy spawnován!")
			_enemy_units.append(enemy_node)
			enemy_node.died.connect(_on_unit_died)
			enemy_node.stats_changed.connect(_on_unit_stats_changed)
		else:
			print("  ❌ Spawn selhal!")
	
	print("=== SPAWN DOKONČEN ===")
	print("Celkem nepřátel: %d" % _enemy_units.size())

func _on_player_hand_card_clicked(card_ui_node: Control, card_data_resource: CardData):
	if _current_battle_state != BattleState.PLAYER_TURN: return
	if _selected_card_ui == card_ui_node:
		_reset_player_selection()
		return
	if PlayerData.current_energy < card_data_resource.cost:
		print("Nedostatek energie!")
		return

	_reset_player_selection()
	_player_action_state = PlayerActionState.CARD_SELECTED
	_selected_card_ui = card_ui_node
	_selected_card_data = card_data_resource
	player_hand_ui_instance.set_selected_card(card_ui_node)
	_show_valid_targets_for_card(card_data_resource)

func try_play_card(card: CardData, initial_target: Node2D) -> void:
	DebugLogger.log_card_played(card.card_name, initial_target.name if initial_target else "none")
	if _is_action_processing: return
	if not card: return
	if not PlayerData.spend_energy(card.cost):
		print("Nedostatek energie!")
		return

	_is_action_processing = true
	var card_played_successfully = true
	if card_played_successfully:
	# ===== PŘIDÁNO: Označ akci =====
		if is_instance_valid(_player_unit_node):
			_player_unit_node.use_action()
	
	var card_ui_to_remove = _selected_card_ui
	
	# SLEDOVÁNÍ ADRENALIN KARET
	if card.card_id == "adrenaline" or card.card_id == "adrenaline+":
		PlayerData.track_adrenaline_card_played()
		
		# Vizuální feedback podle stavu
		if PlayerData.has_adrenaline_addiction:
			# Má závislost - ukáž kolikátý adrenalin
			_show_adrenaline_counter(PlayerData.adrenaline_cards_this_turn)
		else:
			# Nemá závislost - varuj před získáním
			if PlayerData.adrenaline_cards_this_turn == 3:
				_show_addiction_warning()
	
	for effect_data in card.effects:
		var targets = _get_targets_for_effect(effect_data, initial_target)
		if not targets.is_empty():
			card_played_successfully = true
			for target_unit in targets:
				if is_instance_valid(target_unit):
					_apply_single_effect(effect_data, target_unit)
					
	if card_played_successfully:
		# DŮLEŽITÉ: Trigger artefaktů PO trackování ale PŘED aplikací efektů
		if has_node("/root/ArtifactManager"):
			var artifact_results = ArtifactManager.on_card_played(card)
			for result in artifact_results:
				print("Card play artefakt aktivován: %s" % result.description)
		
		var has_exhaust_effect = card.effects.any(func(e): return e.effect_type == CardEffectData.EffectType.EXHAUST)
		if has_exhaust_effect:
			PlayerData.add_card_to_exhaust_pile(card)
		else:
			PlayerData.add_card_to_discard_pile(card)
		PlayerData.current_hand.erase(card)
		
		if is_instance_valid(card_ui_to_remove):
			card_ui_to_remove.queue_free()
		player_hand_ui_instance._request_arrange()
		_update_pile_counts()
	else:
		print("Karta '%s' nenašla žádný platný cíl." % card.card_name)
		PlayerData.gain_energy(card.cost)

	_is_action_processing = false
	_reset_player_selection()

# NOVÁ FUNKCE - zobrazení počítadla adrenalinů
func _show_adrenaline_counter(count: int):
	"""Zobrazí počítadlo adrenalinů při závislosti"""
	var color = Color.YELLOW
	var text = "Adrenalin %d/2" % count
	
	if count > 2:
		color = Color.RED
		text = "💀 PŘEDÁVKOVÁNÍ! (%d)" % count
	elif count == 2:
		color = Color.ORANGE
		text = "⚠️ Adrenalin %d/2 - LIMIT!" % count
	
	_show_floating_notification(text, color)

# NOVÁ FUNKCE - varování před závislostí
func _show_addiction_warning():
	"""Varování před získáním závislosti"""
	var text = "⚠️ VAROVÁNÍ: Další Adrenalin = ZÁVISLOST!"
	_show_floating_notification(text, Color.ORANGE)

# NOVÁ FUNKCE - pomocná pro notifikace
func _show_floating_notification(text: String, color: Color):
	"""Pomocná funkce pro zobrazení notifikací"""
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	var canvas_layer = $CanvasLayer
	if canvas_layer:
		canvas_layer.add_child(label)
		label.position = Vector2(get_viewport().size.x / 2 - 200, 150)
		
		var tween = create_tween()
		label.modulate.a = 0
		label.scale = Vector2(0.5, 0.5)
		
		# Fade in + scale up
		tween.tween_property(label, "modulate:a", 1.0, 0.2)
		tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
		
		# Hold
		tween.tween_interval(1.5)
		
		# Fade out
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)

func _on_overdose_warning():
	"""Tato funkce se spustí, když ArtifactManager vyšle signál."""
	var text = "⚠️ VAROVÁNÍ: Další Adrenalin způsobí PŘEDÁVKOVÁNÍ!"
	_show_floating_notification(text, Color.ORANGE)

func _on_unit_selected_on_grid(unit_node: Unit):
	if _current_battle_state != BattleState.PLAYER_TURN: return
	if unit_node.unit_data.faction == UnitData.Faction.PLAYER and unit_node.can_move():
		_reset_player_selection()
		_player_action_state = PlayerActionState.UNIT_SELECTED
		_selected_unit = unit_node
		_selected_unit.set_selected_visual(true)
		# Upravené volání, předáváme celou jednotku
		battle_grid_instance.show_movable_range(unit_node)
	else:
		_reset_player_selection()

func _execute_move(unit_to_move: Unit, target_cell: Vector2i):
	unit_to_move.use_move_action()
	battle_grid_instance.remove_object_by_instance(unit_to_move)
	battle_grid_instance.place_object_on_cell(unit_to_move, target_cell, true)
	var terrain_on_cell = battle_grid_instance.get_terrain_on_cell(target_cell)
	if is_instance_valid(terrain_on_cell):
		# Voláme přímo funkci na jednotce, která efekt zpracuje
		unit_to_move.process_terrain_effects(terrain_on_cell)
	_reset_player_selection()
	
func _apply_single_effect(effect: CardEffectData, target: Node2D) -> void:
	if not is_instance_valid(target): return
	
	match effect.effect_type:
		CardEffectData.EffectType.DEAL_DAMAGE:
			if target.has_method("take_damage"):
				var damage_to_deal = effect.value
				
				# Existující bonus z skillů
				damage_to_deal += PlayerData.global_card_damage_bonus
				
				# NOVÉ: Přidej conditional bonusy z artefaktů
				if has_node("/root/ArtifactManager"):
					var context = {
						"current_hp": PlayerData.current_hp,
						"max_hp": PlayerData.max_hp,
						"current_energy": PlayerData.current_energy
					}
					damage_to_deal += ArtifactManager.get_card_damage_bonus(context)
				
				# Critical hit logic s artefakt bonusy
				var total_crit_chance = PlayerData.get_critical_chance()
				if has_node("/root/ArtifactManager"):
					total_crit_chance += ArtifactManager.get_critical_chance()
				
				var is_critical = false
				if total_crit_chance > 0:
					var crit_roll = randi_range(1, 100)
					if crit_roll <= total_crit_chance:
						damage_to_deal *= 2
						is_critical = true
						print("💥 KRITICKÝ ZÁSAH! Poškození: %d" % damage_to_deal)
						if is_instance_valid(_player_unit_node):
							_player_unit_node._show_floating_text(damage_to_deal, "critical")
				
				target.take_damage(damage_to_deal)
				
				# NOVÉ: Trigger damage dealt artefakty
				if has_node("/root/ArtifactManager"):
					ArtifactManager.on_damage_dealt(damage_to_deal, target, is_critical)

		CardEffectData.EffectType.GAIN_BLOCK:
			if target.has_method("add_block"): target.add_block(effect.value)
			
		CardEffectData.EffectType.HEAL_UNIT:
			if target.has_method("heal"): target.heal(effect.value)
			
		CardEffectData.EffectType.HEAL_TO_FULL:
			if target.has_method("heal_to_full"): target.heal_to_full()
			
		CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK:
			if is_instance_valid(_player_unit_node) and target.has_method("take_damage"):
				target.take_damage(_player_unit_node.current_block)
				
		CardEffectData.EffectType.DRAW_CARDS:
			_cards_to_draw_queue += effect.value
			_draw_next_card_in_queue()
			
		CardEffectData.EffectType.GAIN_ENERGY: PlayerData.gain_energy(effect.value)
		
		CardEffectData.EffectType.APPLY_STATUS:
			if target.has_method("apply_status"): target.apply_status(effect.string_value, effect.value)
			
		CardEffectData.EffectType.GAIN_EXTRA_MOVE:
			if target.has_method("gain_extra_move"): target.gain_extra_move()
			
		CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK:
			if is_instance_valid(_player_unit_node) and target.has_method("take_damage"):
				var damage = _player_unit_node.current_block * 2
				target.take_damage(damage)
		
		CardEffectData.EffectType.MODIFY_INITIATIVE_NEXT_ROUND:
			if has_node("/root/TurnManager") and is_instance_valid(target) and target is Unit:
				TurnManager.modify_initiative_next_round(target, effect.value)
			else:
				printerr("Efekt MODIFY_INITIATIVE nelze aplikovat na ", target)


# Pomocná funkce pro kontrolu útočného dosahu (přidej ji do BattleScene)
func can_attack_target(attacker: Unit, target: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	
	var distance = battle_grid.get_distance(attacker.grid_position, target.grid_position)
	return distance <= attacker.unit_data.attack_range

func _get_targets_for_effect(effect: CardEffectData, initial_target_node: Node2D) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var clicked_grid_cell = battle_grid_instance.get_cell_at_world_position(get_global_mouse_position())
	if effect.target_type == CardEffectData.TargetType.ANY_GRID_CELL:
		var affected_cells = battle_grid_instance.get_cells_for_aoe(clicked_grid_cell, effect.area_of_effect_type, effect.aoe_param_x, effect.aoe_param_y)
		for cell in affected_cells:
			var unit_on_cell = battle_grid_instance.get_object_on_cell(cell)
			if is_instance_valid(unit_on_cell) and unit_on_cell.get_unit_data().faction == UnitData.Faction.ENEMY:
				targets.append(unit_on_cell)
		return targets
	match effect.target_type:
		CardEffectData.TargetType.SELF_UNIT:
			targets.append(_player_unit_node)
		CardEffectData.TargetType.SELECTED_ENEMY_UNIT:
			if is_instance_valid(initial_target_node) and initial_target_node.get_unit_data().faction == UnitData.Faction.ENEMY:
				if battle_grid_instance.get_distance(_player_unit_node.grid_position, initial_target_node.grid_position) <= _selected_card_data.range_value:
					targets.append(initial_target_node)
		CardEffectData.TargetType.ALL_ENEMY_UNITS:
			targets.assign(_enemy_units)
	return targets
	
func _reset_player_selection():
	if is_instance_valid(_selected_unit):
		_selected_unit.set_selected_visual(false)
		_selected_unit = null
	if is_instance_valid(_selected_card_ui):
		player_hand_ui_instance.set_selected_card(null)
		_selected_card_ui = null
		_selected_card_data = null
	battle_grid_instance.hide_movable_range()
	battle_grid_instance.hide_targetable_cells()
	battle_grid_instance.hide_aoe_highlight()
	# Na konci kola hráče skryjeme i danger zone pro přehlednost
	if _current_battle_state == BattleState.PLAYER_TURN:
		battle_grid_instance.hide_danger_zone()
	_player_action_state = PlayerActionState.IDLE



func _on_draw_pile_clicked(): card_pile_viewer.show_cards(PlayerData.draw_pile)
func _on_discard_pile_clicked(): card_pile_viewer.show_cards(PlayerData.discard_pile)
func _on_end_turn_button_pressed():
	if _current_battle_state != BattleState.PLAYER_TURN:
		return
	
	# ===== UPRAVENO PRO INICIATIVNÍ SYSTÉM =====
	_current_battle_state = BattleState.PROCESSING
	end_turn_button.disabled = true
	
	# Zavolej end_turn na hráči
	if is_instance_valid(_player_unit_node):
		_player_unit_node.end_turn()
	
	# END_OF_TURN artefakty
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_turn_end()
	
	# Odhoď karty
	player_hand_ui_instance.discard_hand_animated(discard_pile_button.global_position)
	# ============================================

func _on_energy_changed(new_amount: int):
	energy_label.text = "Energie: " + str(new_amount)

func _physics_process(_delta):
	var mouse_pos = get_global_mouse_position()
	var grid_cell = battle_grid_instance.get_cell_at_world_position(mouse_pos)
	var unit_under_mouse = battle_grid_instance.get_object_on_cell(grid_cell)
	if is_instance_valid(unit_under_mouse) and unit_under_mouse.get_unit_data().faction == UnitData.Faction.ENEMY:
		enemy_info_panel.update_stats(unit_under_mouse)
	else:
		enemy_info_panel.hide_panel()
	if _player_action_state == PlayerActionState.CARD_SELECTED:
		_update_card_target_preview()

func _show_valid_targets_for_card(card: CardData):
	var valid_target_cells: Array[Vector2i] = []
	var is_attack = true
	for effect in card.effects:
		match effect.target_type:
			CardEffectData.TargetType.SELECTED_ENEMY_UNIT:
				is_attack = true
				for enemy in _enemy_units:
					if is_instance_valid(enemy):
						var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, enemy.grid_position)
						if distance <= card.range_value: valid_target_cells.append(enemy.grid_position)
			CardEffectData.TargetType.SELF_UNIT:
				is_attack = false
				if not valid_target_cells.has(_player_unit_node.grid_position): valid_target_cells.append(_player_unit_node.grid_position)
	battle_grid_instance.show_targetable_cells(valid_target_cells, is_attack)

func _update_pile_counts():
	if is_instance_valid(draw_pile_button): draw_pile_button.update_count(PlayerData.draw_pile.size())
	if is_instance_valid(discard_pile_button): discard_pile_button.update_count(PlayerData.discard_pile.size())

#func _update_hand_ui():
#	player_hand_ui_instance.clear_hand()
#	for card_data in PlayerData.current_hand: player_hand_ui_instance.add_card_to_hand(card_data)
#	_update_pile_counts()


func set_enemy_intents():
	"""Zobrazí záměry nepřátel (jejich budoucí akce)"""
	for enemy_unit in _enemy_units:
		if not is_instance_valid(enemy_unit):
			continue
		
		if not enemy_unit.has_method("show_intent"):
			continue
		
		# ===== UPRAVENO: Získej akci z AI =====
		var player_units_array: Array = [_player_unit_node]
		
		var ai_instance = null
		if is_instance_valid(enemy_unit.unit_data) and is_instance_valid(enemy_unit.unit_data.ai_script):
			ai_instance = enemy_unit.unit_data.ai_script.new()
		else:
			continue
		
		var action = ai_instance.get_next_action(enemy_unit, player_units_array, battle_grid_instance)
		
		# Zobraz záměr podle typu akce
		match action.type:
			EnemyAIBase.AIAction.ActionType.ATTACK, EnemyAIBase.AIAction.ActionType.RUSH:
				var damage = enemy_unit.unit_data.attack_damage
				if action.damage_multiplier != 1.0:
					damage = int(damage * action.damage_multiplier)
				enemy_unit.show_intent(damage)
			_:
				enemy_unit.hide_intent()

func _spawn_unit(unit_data: UnitData, grid_pos: Vector2i) -> Unit:
	if not unit_data: return null
	var unit_instance: Unit = UnitScene.instantiate()
	unit_instance.unit_data = unit_data
	if battle_grid_instance.place_object_on_cell(unit_instance, grid_pos):
		return unit_instance
	else:
		unit_instance.queue_free()
		return null

func _on_card_hover_started(card_data: CardData): pass
func _on_card_hover_ended():
	if _player_action_state != PlayerActionState.CARD_SELECTED: battle_grid_instance.hide_aoe_highlight()

func _update_card_target_preview():
	if not _selected_card_data: return
	var mouse_grid_pos = battle_grid_instance.get_cell_at_world_position(get_global_mouse_position())
	if not battle_grid_instance.is_valid_grid_position(mouse_grid_pos):
		battle_grid_instance.hide_aoe_highlight()
		return
	var final_aoe_cells: Array[Vector2i] = []
	for effect in _selected_card_data.effects:
		if effect.area_of_effect_type == CardEffectData.AreaOfEffectType.SINGLE_TARGET: continue
		var potential_cells = battle_grid_instance.get_cells_for_aoe(mouse_grid_pos, effect.area_of_effect_type, effect.aoe_param_x, effect.aoe_param_y)
		for cell in potential_cells:
			if battle_grid_instance.is_cell_active(cell): final_aoe_cells.append(cell)
	battle_grid_instance.show_aoe_highlight(final_aoe_cells)

func _place_terrain_features():
	var terrains_to_spawn = [ {"data": preload("res://data/terrain/rock.tres"), "count": 3}, {"data": preload("res://data/terrain/mud.tres"), "count": 2} ]
	var occupied_cells = []
	if is_instance_valid(_player_unit_node): occupied_cells.append(_player_unit_node.grid_position)
	for enemy in _enemy_units:
		if is_instance_valid(enemy): occupied_cells.append(enemy.grid_position)
	for terrain_info in terrains_to_spawn:
		var terrain_data = terrain_info.data; var count_to_place = terrain_info.count; var placed_count = 0; var attempts = 0
		while placed_count < count_to_place and attempts < 100:
			attempts += 1
			var rand_x = randi_range(1, battle_grid_instance.grid_columns - 2)
			var rand_y = randi_range(0, battle_grid_instance.grid_rows - 1)
			var random_pos = Vector2i(rand_x, rand_y)
			if not occupied_cells.has(random_pos):
				battle_grid_instance.place_terrain(random_pos, terrain_data)
				occupied_cells.append(random_pos); placed_count += 1

func _apply_terrain_effect(unit: Node2D, terrain: TerrainData):
	if not is_instance_valid(unit) or not is_instance_valid(terrain): return
	match terrain.effect_type:
		TerrainData.TerrainEffect.APPLY_STATUS_ON_ENTER:
			if unit.has_method("apply_status") and not terrain.effect_string_value.is_empty():
				unit.apply_status(terrain.effect_string_value, terrain.effect_duration)
		TerrainData.TerrainEffect.MODIFY_DEFENSE_ON_TILE:
			if unit.has_method("add_block"): unit.add_block(terrain.effect_numeric_value)

func _generate_grid_from_shape():
	var all_shapes = [SHAPE_DEFAULT, SHAPE_CROSS, SHAPE_DIAMOND]
	var selected_shape = all_shapes.pick_random()
	battle_grid_instance.build_from_shape(selected_shape)

func _setup_camera_boundaries():
	if not (is_instance_valid(battle_grid_instance) and is_instance_valid(camera_2d)): return
	var horizontal_padding = 500.0; var top_padding = 300.0; var bottom_padding = 400.0
	var grid_pixel_width = battle_grid_instance.grid_columns * battle_grid_instance.cell_size.x
	var grid_pixel_height = battle_grid_instance.grid_rows * battle_grid_instance.cell_size.y
	camera_2d.limit_left = 0 - horizontal_padding; camera_2d.limit_top = 0 - top_padding
	camera_2d.limit_right = grid_pixel_width + horizontal_padding
	camera_2d.limit_bottom = grid_pixel_height + bottom_padding

func get_player_unit() -> Node2D:
	return _player_unit_node

func get_enemy_count() -> int:
	return _enemy_units.size()

func get_all_enemies() -> Array:
	return _enemy_units
