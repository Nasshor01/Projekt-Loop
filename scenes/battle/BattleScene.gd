extends Node3D

# --- KONFIGURACE KAMERY (To, co ti chybělo) ---
@export_group("Camera Settings")
@export var camera_move_speed: float = 15.0
@export var camera_rotation_speed: float = 2.0
@export var camera_zoom_speed: float = 2.0
@export var camera_min_zoom: float = 5.0
@export var camera_max_zoom: float = 30.0
@export var camera_smoothness: float = 10.0
@export var camera_min_pitch: float = -85.0 # Úplně shora (téměř -90)
@export var camera_max_pitch: float = -30.0 # Pohled zešikma (horizont)

# Cílové hodnoty pro plynulý pohyb
var _cam_target_pos: Vector3
var _cam_target_rot_y: float
var _cam_target_rot_x: float
var _cam_target_zoom: float
# ---------------------------------------------

const UnitScene = preload("res://scenes/battle/Unit.tscn")
# Konstanty tvarů gridu (pro generování)
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
@onready var turn_counter_label: Label = $CanvasLayer/TurnCounterLabel
@onready var initiative_bar = $CanvasLayer/InitiativeBar
@onready var card_tooltip: CardTooltip = $CanvasLayer/CardTooltip

@export var camera_3d: Camera3D 

enum PlayerActionState { IDLE, CARD_SELECTED, UNIT_SELECTED }
var _player_action_state: PlayerActionState = PlayerActionState.IDLE

enum BattleState { SETUP, AWAITING_PLAYER_SPAWN, PLAYER_TURN, ENEMY_TURN, PROCESSING, BATTLE_OVER }
var _current_battle_state: BattleState = BattleState.SETUP

@export var starting_hand_size: int = 5

var _selected_card_ui: Control = null
var _selected_card_data: CardData = null
var _player_unit_node: Unit = null
var _selected_unit: Unit = null
var _enemy_units: Array[Unit] = []

var _is_action_processing: bool = false
var _cards_to_draw_queue: int = 0
var _is_drawing_cards: bool = false
var _is_first_turn: bool = true
var _current_turn_number: int = 0
var _is_extra_turn: bool = false
var _cards_played_this_turn: Dictionary = {}  # Tracking karet za tah pro limit použití
var _took_damage_last_turn: bool = false  # Tracking poškození pro consecrated_barrier
var _current_tooltip_card_data: CardData = null

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
	player_hand_ui_instance.card_right_clicked.connect(_on_card_right_clicked)
	
	# Tooltip se nyní zobrazuje/schovává pomocí pravého kliknutí - žádné timery nejsou potřeba
	draw_pile_button.pile_clicked.connect(_on_draw_pile_clicked)
	discard_pile_button.pile_clicked.connect(_on_discard_pile_clicked)
	if not win_button.pressed.is_connected(_on_win_button_pressed):
		win_button.pressed.connect(_on_win_button_pressed)
	
	player_hand_ui_instance.card_draw_animation_finished.connect(_on_card_draw_animation_finished)
	player_hand_ui_instance.hand_discard_animation_finished.connect(_on_hand_discard_animation_finished)

	_update_ui_texts()
	
	_setup_camera_boundaries()
	battle_grid_instance.set_camera(camera_3d)
	_generate_grid_from_shape()
	
	# Inicializace cílových hodnot kamery
	if camera_3d:
		_cam_target_pos = camera_3d.position
		_cam_target_rot_y = camera_3d.rotation.y
		_cam_target_zoom = camera_3d.size
		_cam_target_rot_x = camera_3d.rotation.x
	
	start_player_spawn_selection()

func _update_ui_texts():
	if is_instance_valid(end_turn_button):
		end_turn_button.text = tr("ui.battle.end_turn")
	if is_instance_valid(victory_label):
		victory_label.text = tr("ui.battle.victory")
	if is_instance_valid(win_button):
		win_button.text = tr("ui.battle.instant_win")
	_update_turn_display()
	_on_energy_changed(PlayerData.current_energy)

func _process(delta):
	if not camera_3d: return

	# 1. POHYB KAMERY
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var forward_vec = -camera_3d.global_transform.basis.z
	forward_vec.y = 0 
	forward_vec = forward_vec.normalized()
	
	var right_vec = camera_3d.global_transform.basis.x
	right_vec.y = 0
	right_vec.normalized()
	
	var move_vec = (right_vec * input_dir.x + forward_vec * -input_dir.y)
	
	if move_vec.length() > 0:
		_cam_target_pos += move_vec * camera_move_speed * delta

	# 2. ROTACE KAMERY (Q/E)
	var rot_input = 0
	if Input.is_key_pressed(KEY_Q): rot_input += 1
	if Input.is_key_pressed(KEY_E): rot_input -= 1
	
	_cam_target_rot_y += rot_input * camera_rotation_speed * delta

	# 3. APLIKACE LERPU (PLYNULOST)
	camera_3d.position = camera_3d.position.lerp(_cam_target_pos, camera_smoothness * delta)
	
	var current_rot = camera_3d.rotation
	current_rot.y = lerp_angle(current_rot.y, _cam_target_rot_y, camera_smoothness * delta)
	current_rot.x = lerp_angle(current_rot.x, _cam_target_rot_x, camera_smoothness * delta)
	camera_3d.rotation = current_rot
	
	camera_3d.size = lerp(camera_3d.size, _cam_target_zoom, camera_smoothness * delta)
	
	# 4. RAYCAST UPDATE PRO HOVER
	var grid_cell = get_grid_cell_under_mouse()
	battle_grid_instance.set_mouse_over_cell(grid_cell)
	
	var unit_under_mouse = battle_grid_instance.get_object_on_cell(grid_cell)
	if is_instance_valid(unit_under_mouse) and unit_under_mouse.get_unit_data().faction == UnitData.Faction.ENEMY:
		enemy_info_panel.update_stats(unit_under_mouse)
	else:
		enemy_info_panel.hide_panel()
		
	if _player_action_state == PlayerActionState.CARD_SELECTED:
		_update_card_target_preview()

func _unhandled_input(event: InputEvent):
	if _is_action_processing: return
	
	# --- 1. OVLÁDÁNÍ KAMERY MYŠÍ (NOVÉ) ---
	# Pokud hýbeš myší a držíš PROSTŘEDNÍ tlačítko (kolečko)
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			# 1. Rotace do stran (Y osa)
			_cam_target_rot_y -= event.relative.x * 0.005
			
			# 2. Náklon nahoru/dolů (X osa) - NOVÉ
			_cam_target_rot_x -= event.relative.y * 0.005
			
			# OMEZENÍ (CLAMP) - Aby se kamera nepřetočila přes hlavu
			# Musíme převést stupně na radiány, protože Godot používá radiány
			var min_rad = deg_to_rad(camera_min_pitch)
			var max_rad = deg_to_rad(camera_max_pitch)
			_cam_target_rot_x = clamp(_cam_target_rot_x, min_rad, max_rad)
	# --------------------------------------

	# ZOOM KAMERY (Kolečko - Scroll)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_target_zoom = clamp(_cam_target_zoom - camera_zoom_speed, camera_min_zoom, camera_max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_target_zoom = clamp(_cam_target_zoom + camera_zoom_speed, camera_min_zoom, camera_max_zoom)

	if card_pile_viewer.visible and event.is_action_pressed("ui_cancel"):
		card_pile_viewer.hide()
		return

	# KLIKÁNÍ NA MŘÍŽKU (RAYCAST)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_grid_cell = get_grid_cell_under_mouse()
		DebugLogger.log_debug("KLIK! Grid coords: %s" % str(clicked_grid_cell))
		
		# Logika SPAWN
		if _current_battle_state == BattleState.AWAITING_PLAYER_SPAWN:
			if battle_grid_instance.is_cell_a_valid_spawn_point(clicked_grid_cell):
				confirm_player_spawn(clicked_grid_cell)
				get_viewport().set_input_as_handled()
			return
		
		if _current_battle_state != BattleState.PLAYER_TURN: return

		# Logika KARTY
		if _player_action_state == PlayerActionState.CARD_SELECTED:
			var has_self_effect = false
			var has_enemy_effect = false
			if is_instance_valid(_selected_card_data):
				has_self_effect = _selected_card_data.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELF_UNIT)
				has_enemy_effect = _selected_card_data.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELECTED_ENEMY_UNIT)
			
			# Pokud karta má pouze SELF efekty (bez ENEMY efektů), použij hráče jako cíl
			if has_self_effect and not has_enemy_effect:
				if is_instance_valid(_player_unit_node):
					try_play_card(_selected_card_data, _player_unit_node)
					get_viewport().set_input_as_handled()
				else:
					_reset_player_selection()
					get_viewport().set_input_as_handled()
				return
			
			var target_node = battle_grid_instance.get_object_on_cell(clicked_grid_cell)
			
			# Kontrola: Pokud karta vyžaduje nepřítele jako cíl, musí být target_node validní nepřítel
			if has_enemy_effect:
				if not is_instance_valid(target_node) or not target_node is Unit or not target_node.get_unit_data().faction == UnitData.Faction.ENEMY:
					# Karta vyžaduje nepřítele, ale klikli jsme na prázdnou buňku nebo ne-nepřítele
					DebugLogger.log_warning("Karta vyžaduje vybraného nepřítele!")
					get_viewport().set_input_as_handled()
					return
			
			try_play_card(_selected_card_data, target_node)
			get_viewport().set_input_as_handled()
			
		# Logika POHYB
		elif _player_action_state == PlayerActionState.UNIT_SELECTED:
			if battle_grid_instance.is_cell_movable(clicked_grid_cell):
				_execute_move(_selected_unit, clicked_grid_cell)
			else:
				_reset_player_selection()
			get_viewport().set_input_as_handled()
		
		# Logika VÝBĚR JEDNOTKY
		elif _player_action_state == PlayerActionState.IDLE:
			var unit_clicked = battle_grid_instance.get_object_on_cell(clicked_grid_cell)
			if unit_clicked and unit_clicked is Unit:
				if unit_clicked.unit_data.faction == UnitData.Faction.PLAYER and unit_clicked.can_move():
					_on_unit_selected_on_grid(unit_clicked)

# ===== NOVÉ FUNKCE PRO INICIATIVNÍ SYSTÉM =====

func _on_round_started(round_number: int):
	"""Volá se na začátku každého kola"""
	_current_turn_number = round_number
	_update_turn_display()
	DebugLogger.log_info("=== KOLO %d ===" % round_number)

	if is_instance_valid(initiative_bar) and has_node("/root/TurnManager"):
		initiative_bar.update_turn_order(TurnManager.get_turn_order())

func _on_turn_started(unit: Unit):
	"""Volá se když je na řadě další jednotka"""
	if is_instance_valid(initiative_bar):
		initiative_bar.set_active_unit(unit)

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

func _start_player_initiative_turn(_player_unit: Unit, extra_draw: int = 0):
	"""Zahájí tah hráče v iniciativním systému"""
	_current_battle_state = BattleState.PROCESSING
	end_turn_button.disabled = true
	
	# Reset tracking karet za tah
	_cards_played_this_turn.clear()
	
	# POZNÁMKA: Tracking poškození se NERESETUJE na začátku tahu, ale na konci tahu hráče
	# aby karta consecrated_barrier mohla správně zkontrolovat, zda hráč utrpěl poškození v předchozím tahu
	
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
			# Tracking poškození pro consecrated_barrier
			if is_instance_valid(action.target_unit) and action.target_unit == _player_unit_node:
				_took_damage_last_turn = true
			
			# Elementální poškození (Mage)
			if action.special_data.get("elemental_damage", false):
				var element_type = action.special_data.get("element_type", "fire")
				await enemy_unit.attack(action.target_unit, action.damage_multiplier)
				# Aplikuj elementální efekt
				if is_instance_valid(action.target_unit) and action.target_unit is Unit:
					match element_type:
						"fire":
							action.target_unit.apply_status("burning", 2, 3)
						"ice":
							action.target_unit.apply_status("chilled", 1, 2)
						"lightning":
							action.target_unit.apply_status("shocked", 1, 1)
			# Assassin double attack
			elif action.special_data.get("double_attack", false):
				await enemy_unit.attack(action.target_unit, action.damage_multiplier)
				await get_tree().create_timer(0.3).timeout  # Krátká pauza mezi útoky
				await enemy_unit.attack(action.target_unit, action.damage_multiplier)
			# Holy damage (Healer) - už je v multiplier
			else:
				await enemy_unit.attack(action.target_unit, action.damage_multiplier)
		
		EnemyAIBase.AIAction.ActionType.SPECIAL:
			await _process_special_action(enemy_unit, action)
		
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
			DebugLogger.log_debug("[BattleScene] Frustrace resetována (útok proveden).")
		
		# Pokud to byl pohyb nebo pass (a AI ještě není v rage), zvyšíme frustraci
		# POZNÁMKA: Pokud chcete, aby se frustrace zvyšovala i v RAGE módu (pokud se netrefí),
		# odstraňte podmínku 'and not enemy_unit.is_permanently_enraged'
		elif (action.type == EnemyAIBase.AIAction.ActionType.MOVE or action.type == EnemyAIBase.AIAction.ActionType.PASS):
			enemy_unit.berserker_frustration += 1
			DebugLogger.log_debug("[BattleScene] Frustrace zvýšena na: %d (bez útoku)." % enemy_unit.berserker_frustration)

func _on_combat_ended(player_won: bool):
	"""Volá se když TurnManager ukončí souboj"""
	_current_battle_state = BattleState.BATTLE_OVER
	
	if player_won and is_instance_valid(_player_unit_node):
		GameManager.battle_finished(true, _player_unit_node.current_health, _player_unit_node.current_block)
	else:
		GameManager.battle_finished(player_won)

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
	
# ==============================================

	# ===== Zahájení souboje přes TurnManager =====
	# Předáme pouze validní jednotky
	var valid_units = all_units.filter(func(u): return is_instance_valid(u))
	call_deferred("_start_combat_with_turn_manager", valid_units)
	# ==========================================


func spawn_player_unit_at(grid_pos: Vector2i):
	if PlayerData.selected_subclass and PlayerData.selected_subclass.specific_unit_data:
		_player_unit_node = _spawn_unit(PlayerData.selected_subclass.specific_unit_data, grid_pos)
		if is_instance_valid(_player_unit_node):
			_player_unit_node.stats_changed.connect(_on_unit_stats_changed)
			_player_unit_node.died.connect(_on_unit_died)




func _update_turn_display():
	"""Aktualizuje zobrazení čísla tahu"""
	if is_instance_valid(turn_counter_label):
		turn_counter_label.text = TranslationHelper.tr_format("ui.battle.turn", {"value": _current_turn_number})

func start_extra_turn():
	"""Spustí PLNOHODNOTNÝ extra tah hráče"""
	DebugLogger.log_info("SPOUŠTÍM EXTRA TAH!")
	_is_extra_turn = false # Reset flag
	
	# 1. ODHOĎ SOUČASNÉ KARTY (jako konec normálního tahu)
	PlayerData.discard_hand()
	player_hand_ui_instance.clear_hand() # Vyčisti UI
	_update_pile_counts()
	
	# 2. RESETUJ ENERGII
	PlayerData.reset_energy()
	
	# 3. RESETUJ POHYB JEDNOTKY (KLÍČOVÉ!)
	if is_instance_valid(_player_unit_node):
		_player_unit_node.reset_for_new_turn() # Toto resetuje pohyb!
	
	# 4. DOBÍREJ NOVÉ KARTY (normální množství)
	_cards_to_draw_queue = starting_hand_size
	_draw_next_card_in_queue()
	
	# 5. NASTAV SPRÁVNÝ STAV
	_current_battle_state = BattleState.PLAYER_TURN
	end_turn_button.disabled = false
	


# Přidejte debug do signálu stats_changed
# OPRAVA: Změna z Node2D na Node3D
func _on_unit_stats_changed(unit_node: Node3D):
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
	DebugLogger.log_debug("Míchám odhazovací balíček...")
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
	DebugLogger.log_debug("Dobírání dokončeno.")
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

func _on_win_button_pressed():
	end_battle_as_victory()

func end_battle_as_victory():
	_current_battle_state = BattleState.BATTLE_OVER
	if is_instance_valid(_player_unit_node):
		GameManager.battle_finished(true, _player_unit_node.current_health, _player_unit_node.current_block)
	else:
		GameManager.battle_finished(true)

# OPRAVA: Změna z Node2D na Unit (nebo Node3D)
func _on_unit_died(unit_node: Unit):
	"""Zpracuje smrt jednotky"""
	DebugLogger.log_info("=== Jednotka zemřela: %s ===" % unit_node.unit_data.unit_name)
	
	# Zpracuj oživení hráče
	if unit_node == _player_unit_node:
		if PlayerData.has_revive:
			DebugLogger.log_info("!!! BOŽSKÁ OCHRANA AKTIVOVÁNA !!!")
			PlayerData.has_revive = false
			var heal_amount = PlayerData.max_hp / 2.0
			if unit_node.has_method("heal"):
				unit_node.heal(heal_amount)
			return
	
	# Trigger enemy death artefakty
	# POZNÁMKA: Ujisti se, že ArtifactManager.on_enemy_death bere jako argument 'Node' nebo 'Unit', ne 'Node2D'
	if unit_node.unit_data.faction == UnitData.Faction.ENEMY:
		if has_node("/root/ArtifactManager"):
			ArtifactManager.on_enemy_death(unit_node)
	
	# Odeber ze seznamu
	if _enemy_units.has(unit_node):
		_enemy_units.erase(unit_node)
	
	battle_grid_instance.remove_object_by_instance(unit_node)
	
	# Animace zmizení pro 3D (Scale místo Modulate)
	var tween = create_tween()
	# Zmenšíme jednotku do nuly (zmizí)
	tween.tween_property(unit_node, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Odregistruj až PO animaci
	await tween.finished
	
	# POZNÁMKA: Ujisti se, že TurnManager.unregister_unit bere jako argument 'Node' nebo 'Unit'
	if has_node("/root/TurnManager"):
		TurnManager.unregister_unit(unit_node)
	
	unit_node.queue_free()


func spawn_enemy_units():
	DebugLogger.log_debug("=== DEBUG: SPAWNING ENEMIES ===")
	
	if not encounter_data:
		printerr("BattleScene: Chybí EncounterData!")
		return

	DebugLogger.log_debug("Encounter data: %s" % encounter_data.resource_path)
	DebugLogger.log_debug("Počet nepřátel: %d" % encounter_data.enemies.size())

	var all_active_cells = battle_grid_instance._active_cells.keys()
	var player_cell = Vector2i.ZERO
	if is_instance_valid(_player_unit_node):
		player_cell = _player_unit_node.grid_position

	var available_spawn_cells: Array[Vector2i] = []
	
	for cell in all_active_cells:
		if cell.x < battle_grid_instance.grid_columns / 2.0: continue
		if cell == player_cell: continue
			
		var terrain = battle_grid_instance.get_terrain_on_cell(cell)
		var is_walkable = not terrain or terrain.is_walkable
		var is_occupied = battle_grid_instance.get_object_on_cell(cell) != null
		
		if is_walkable and not is_occupied:
			available_spawn_cells.append(cell)

	DebugLogger.log_debug("Dostupných spawn pozic: %d" % available_spawn_cells.size())

	for i in range(encounter_data.enemies.size()):
		var enemy_entry = encounter_data.enemies[i]
		DebugLogger.log_debug("=== SPAWNING ENEMY %d ===" % (i + 1))
		
		if not enemy_entry or not enemy_entry.unit_data:
			DebugLogger.log_error("CHYBA: Nevalidní enemy entry!")
			continue
			
		DebugLogger.log_debug("Enemy data:")
		DebugLogger.log_debug("  - unit_name: %s" % enemy_entry.unit_data.unit_name)
		DebugLogger.log_debug("  - max_health: %d" % enemy_entry.unit_data.max_health)
		DebugLogger.log_debug("  - ai_script: %s" % str(enemy_entry.unit_data.ai_script))
		
		if available_spawn_cells.is_empty():
			printerr("Nedostatek spawn pozic!")
			break
			
		var random_pos = available_spawn_cells.pick_random()
		available_spawn_cells.erase(random_pos)
		DebugLogger.log_debug("  - spawn pozice: %s" % str(random_pos))

		var enemy_node = _spawn_unit(enemy_entry.unit_data, random_pos)
		if is_instance_valid(enemy_node):
			DebugLogger.log_debug("  ✅ Enemy spawnován!")
			_enemy_units.append(enemy_node)
			enemy_node.died.connect(_on_unit_died)
			enemy_node.stats_changed.connect(_on_unit_stats_changed)
		else:
			DebugLogger.log_error("  ❌ Spawn selhal!")
	
	DebugLogger.log_debug("=== SPAWN DOKONČEN ===")
	DebugLogger.log_debug("Celkem nepřátel: %d" % _enemy_units.size())

func _on_player_hand_card_clicked(card_ui_node: Control, card_data_resource: CardData):
	if _current_battle_state != BattleState.PLAYER_TURN: return
	if _selected_card_ui == card_ui_node:
		_reset_player_selection()
		return
	if PlayerData.current_energy < card_data_resource.cost:
		DebugLogger.log_warning("Nedostatek energie!")
		return

	_reset_player_selection()
	_player_action_state = PlayerActionState.CARD_SELECTED
	_selected_card_ui = card_ui_node
	_selected_card_data = card_data_resource
	player_hand_ui_instance.set_selected_card(card_ui_node)
	_show_valid_targets_for_card(card_data_resource)

# OPRAVA: Argument je Node3D (nebo Unit, ale Node3D je obecnější pro 3D svět)
func try_play_card(card: CardData, initial_target: Node3D) -> void:
	DebugLogger.log_card_played(card.card_name, str(initial_target.name) if initial_target else "none")
	if _is_action_processing: return
	if not card: return
	
	# Frozen - nemůže hrát karty
	if is_instance_valid(_player_unit_node) and (_player_unit_node.is_frozen or _player_unit_node.active_statuses.has("frozen")):
		DebugLogger.log_warning(tr("ui.battle.frozen_warning"))
		_show_floating_notification(tr("ui.battle.frozen_notice"), Color.CYAN)
		return
	
	if not PlayerData.spend_energy(card.cost):
		DebugLogger.log_warning(TranslationHelper.tr_format("ui.battle.not_enough_energy", {"name": card.get_localized_name()}))
		return

	# Kontrola limitu použití karty za tah
	if card.max_uses_per_turn > 0:
		var current_count = _cards_played_this_turn.get(card.card_id, 0)
		if current_count >= card.max_uses_per_turn:
			# Překročen limit - aplikuj debuff
			_apply_overuse_debuff(card)
			PlayerData.gain_energy(card.cost)  # Vrať energii
			return
		
		# Zvýš počítadlo
		_cards_played_this_turn[card.card_id] = current_count + 1
		
		# Vizuální feedback pro limit
		if current_count + 1 == card.max_uses_per_turn:
			_show_floating_notification(TranslationHelper.tr_format("ui.battle.card_limit", {"current": current_count + 1, "max": card.max_uses_per_turn}), Color.ORANGE)

	_is_action_processing = true
	var card_played_successfully = false
	
	var card_ui_to_remove = _selected_card_ui
	
	# Projdi všechny efekty a zkontroluj, zda mají platné cíle
	for effect_data in card.effects:
		var targets = _get_targets_for_effect(effect_data, initial_target)
		if not targets.is_empty():
			card_played_successfully = true
			for target_unit in targets:
				if is_instance_valid(target_unit):
					await _apply_single_effect(effect_data, target_unit)
	
	# Označ akci pouze pokud byla karta úspěšně použita
	if card_played_successfully:
		if is_instance_valid(_player_unit_node):
			_player_unit_node.use_action()
					
	if card_played_successfully:
		# DŮLEŽITÉ: Trigger artefaktů PO trackování ale PŘED aplikací efektů
		if has_node("/root/ArtifactManager"):
			var artifact_results = ArtifactManager.on_card_played(card)
			for result in artifact_results:
				DebugLogger.log_debug("Card play artefakt aktivován: %s" % result.description)
		
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
		DebugLogger.log_warning(TranslationHelper.tr_format("ui.battle.no_valid_target", {"name": card.get_localized_name()}))
		PlayerData.gain_energy(card.cost)

	_is_action_processing = false
	_reset_player_selection()

func _apply_overuse_debuff(card: CardData):
	"""Aplikuje debuff při překročení limitu použití karty"""
	if not card.debuff_on_overuse or card.debuff_on_overuse.is_empty():
		return
	
	if not is_instance_valid(_player_unit_node):
		return
	
	var debuff = card.debuff_on_overuse
	var messages: Array[String] = []
	
	# Poškození
	if debuff.has("damage") and debuff.damage > 0:
		_player_unit_node.take_damage(debuff.damage)
		messages.append(TranslationHelper.tr_format("ui.battle.debuff_damage", {"value": debuff.damage}))
	
	# Ztráta energie
	if debuff.has("energy_loss") and debuff.energy_loss > 0:
		var energy_to_lose = min(debuff.energy_loss, PlayerData.current_energy)
		if energy_to_lose > 0:
			PlayerData.current_energy -= energy_to_lose
			PlayerData.emit_signal("energy_changed", PlayerData.current_energy)
			messages.append(TranslationHelper.tr_format("ui.battle.debuff_energy", {"value": energy_to_lose}))
	
	# Status efekt
	if debuff.has("status") and not debuff.status.is_empty():
		var duration = debuff.get("status_duration", 1)
		if _player_unit_node.has_method("apply_status"):
			_player_unit_node.apply_status(debuff.status, duration)
			messages.append(tr("status." + debuff.status))
	
	# Vizuální feedback
	if not messages.is_empty():
		var text = tr("ui.battle.limit_exceeded") + " " + ", ".join(messages)
		_show_floating_notification(text, Color.RED)
		DebugLogger.log_warning(TranslationHelper.tr_format("ui.battle.limit_exceeded_log", {"name": card.get_localized_name()}))

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

# Kontrola podmínek pro efekt
func _check_condition(effect: CardEffectData, target: Node3D) -> bool:
	if not effect.has_condition or effect.condition_type.is_empty():
		return true
	
	if not is_instance_valid(_player_unit_node):
		return false
	
	match effect.condition_type:
		"block_above":
			return _player_unit_node.current_block > effect.condition_value
		"block_below":
			return _player_unit_node.current_block < effect.condition_value
		"health_below_percent":
			var percent = (float(PlayerData.current_hp) * 100.0) / float(PlayerData.max_hp)
			return percent < effect.condition_value
		"health_above_percent":
			var percent = (float(PlayerData.current_hp) * 100.0) / float(PlayerData.max_hp)
			return percent > effect.condition_value
		"target_has_debuff":
			if target is Unit and target.has("active_statuses"):
				return target.active_statuses.size() > 0
			return false
		"target_health_above_percent":
			if target is Unit and target.has("current_health") and target.has("get_unit_data"):
				var unit_data = target.get_unit_data()
				var max_hp = unit_data.max_health
				var percent = (float(target.current_health) * 100.0) / float(max_hp)
				return percent > effect.condition_value
			return false
		"took_damage_last_turn":
			return _took_damage_last_turn
		_:
			return true

# OPRAVA: Argument 'target' musí být Node3D (pro 3D jednotky)
func _apply_single_effect(effect: CardEffectData, target: Node3D) -> void:
	if not is_instance_valid(target): return
	
	# Kontrola podmínek
	var condition_met = _check_condition(effect, target)
	var bonus_value = effect.conditional_bonus_value if condition_met else 0
	
	match effect.effect_type:
		CardEffectData.EffectType.DEAL_DAMAGE:
			if target.has_method("take_damage"):
				var damage_to_deal = effect.value
				
				# Podmíněné bonusy z karty
				damage_to_deal += bonus_value
				
				# Speciální podmínka: damage_per_block (holy_vengeance)
				if effect.condition_type == "damage_per_block" and is_instance_valid(_player_unit_node):
					damage_to_deal += _player_unit_node.current_block * effect.conditional_bonus_value
				
				# Status efekt: consecrated_weapon (+5 poškození na příští útok)
				if is_instance_valid(_player_unit_node) and _player_unit_node.active_statuses.has("consecrated_weapon"):
					var status_data = _player_unit_node.active_statuses["consecrated_weapon"]
					damage_to_deal += status_data.value
					# Odstraň status po použití
					_player_unit_node.active_statuses.erase("consecrated_weapon")
					_player_unit_node._update_stats_and_emit_signal()
				
				# Existující bonus z skillů
				damage_to_deal += PlayerData.global_card_damage_bonus
				
				# Přidej conditional bonusy z artefaktů
				if has_node("/root/ArtifactManager"):
					var context = {
						"current_hp": PlayerData.current_hp,
						"max_hp": PlayerData.max_hp,
						"current_energy": PlayerData.current_energy
					}
					damage_to_deal += ArtifactManager.get_card_damage_bonus(context)
				
				# Systém efektivity poškození (holy damage vs undead/demon)
				var damage_type = effect.damage_type
				
				# Aplikuj efektivitu poškození, pokud je cíl Unit
				if target is Unit:
					var target_unit_data = target.get_unit_data()
					if target_unit_data:
						var effectiveness = UnitData.get_damage_effectiveness(damage_type, target_unit_data.unit_type)
						if effectiveness != 1.0:
							var original_damage = damage_to_deal
							damage_to_deal = int(damage_to_deal * effectiveness)
							if effectiveness > 1.0:
								DebugLogger.log_info("✨ EFEKTIVNÍ POŠKOZENÍ! %d -> %d (x%.2f)" % [original_damage, damage_to_deal, effectiveness])
								# Vizuální feedback - zobrazíme efektivní poškození jinou barvou na cíli
								if target is Unit and target.has_method("_show_floating_text"):
									target._show_floating_text(damage_to_deal, "holy_effective")
				
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
						DebugLogger.log_info("💥 KRITICKÝ ZÁSAH! Poškození: %d" % damage_to_deal)
						if is_instance_valid(_player_unit_node):
							_player_unit_node._show_floating_text(damage_to_deal, "critical")
				
				# Tracking pro gods_lightning (energie při zabití nepřítele)
				var enemy_health_before = 0
				if target is Unit and target.get_unit_data().faction == UnitData.Faction.ENEMY:
					enemy_health_before = target.current_health
				
				await target.take_damage(damage_to_deal)
				
				# Pokud byl nepřítel zabit touto kartou, zkontroluj, zda karta má gods_lightning efekt
				if target is Unit and target.get_unit_data().faction == UnitData.Faction.ENEMY:
					if enemy_health_before > 0 and target.current_health <= 0:
						# Zkontroluj, zda aktuální karta má GAIN_ENERGY efekt (gods_lightning)
						for card_effect in _selected_card_data.effects:
							if card_effect.effect_type == CardEffectData.EffectType.GAIN_ENERGY:
								PlayerData.gain_energy(card_effect.value)
								DebugLogger.log_info("⚡ Gods Lightning: Získal %d energie za zabití nepřítele!" % card_effect.value)
				
				# Tracking poškození pro consecrated_barrier (pokud je target hráč)
				if target == _player_unit_node:
					_took_damage_last_turn = true
				
				# Trigger damage dealt artefakty
				# POZNÁMKA: Ujisti se, že ArtifactManager.on_damage_dealt bere jako argument 'Node' nebo 'Unit'
				if has_node("/root/ArtifactManager"):
					ArtifactManager.on_damage_dealt(damage_to_deal, target, is_critical)

		CardEffectData.EffectType.GAIN_BLOCK:
			if target.has_method("add_block"):
				var block_amount = effect.value
				# Podpora pro blok z max_hp (používá se v unbreakable_faith)
				if effect.string_value == "max_hp" and is_instance_valid(_player_unit_node):
					block_amount = PlayerData.max_hp
				
				# Pro podmíněné efekty: kontrolujeme blok PŘED přidáním základního bloku
				# Pokud je podmínka splněna, přidáme bonusový blok
				# POZNÁMKA: Pro "block_above" kontrolujeme blok PŘED přidáním nového bloku
				var condition_met_before = _check_condition(effect, target)
				
				# Přidej základní blok
				target.add_block(block_amount)
				
				# Pokud byla podmínka splněna PŘED přidáním bloku, přidej bonus
				if condition_met_before and effect.conditional_bonus_value > 0:
					target.add_block(effect.conditional_bonus_value)
				
				# Podpora pro retained_block (blok, který nezmizí na konci tahu)
				# Pokud string_value obsahuje "retain", nastavíme retained_block
				if effect.string_value.contains("retain") and target.has("retained_block"):
					var total_block_added = block_amount
					if condition_met_before and effect.conditional_bonus_value > 0:
						total_block_added += effect.conditional_bonus_value
					target.retained_block += total_block_added
					# Ujistíme se, že retained_block nepřesáhne current_block
					target.retained_block = min(target.retained_block, target.current_block)
			
		CardEffectData.EffectType.HEAL_UNIT:
			if target.has_method("heal"):
				var heal_amount = effect.value
				# Podmíněné bonusy z karty (např. massive_healing)
				# Pokud je podmínka splněna a conditional_bonus_value > 0, použij bonusovou hodnotu místo základní
				if condition_met and effect.conditional_bonus_value > 0:
					heal_amount = effect.conditional_bonus_value
				target.heal(heal_amount)
			
		CardEffectData.EffectType.HEAL_TO_FULL:
			if target.has_method("heal_to_full"): target.heal_to_full()
			
		CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK:
			if is_instance_valid(_player_unit_node) and target.has_method("take_damage"):
				target.take_damage(_player_unit_node.current_block)
				
		CardEffectData.EffectType.DRAW_CARDS:
			_cards_to_draw_queue += effect.value
			_draw_next_card_in_queue()
			
		CardEffectData.EffectType.GAIN_ENERGY: 
			# Speciální případ: gods_lightning - energie se získává pouze při zabití nepřítele
			# Takže tady nic neděláme, energie se přidá v damage efektu
			if _selected_card_data and _selected_card_data.card_id == "gods_lightning":
				pass  # Energie se přidá v damage efektu, pokud byl nepřítel zabit
			else:
				PlayerData.gain_energy(effect.value)
		
		CardEffectData.EffectType.APPLY_STATUS:
			if target.has_method("apply_status"):
				# Speciální případ: remove_all_debuffs
				if effect.string_value == "remove_all_debuffs":
					if target is Unit and target.has("active_statuses"):
						# Odstraň všechny debuff statusy (zachovej buffy jako regeneration, aura_devotion)
						var statuses_to_remove = []
						for status_id in target.active_statuses.keys():
							# Zachovej buffy (regeneration, aura_devotion, aura_devotion_plus)
							if status_id != "regeneration" and status_id != "aura_devotion" and status_id != "aura_devotion_plus":
								statuses_to_remove.append(status_id)
						
						for status_id in statuses_to_remove:
							target.active_statuses.erase(status_id)
						
						if not statuses_to_remove.is_empty():
							target._update_stats_and_emit_signal()
							DebugLogger.log_info("Odstraněno %d debuffů" % statuses_to_remove.size())
				else:
					target.apply_status(effect.string_value, effect.value)
			
		CardEffectData.EffectType.GAIN_EXTRA_MOVE:
			if target.has_method("gain_extra_move"): target.gain_extra_move()
			
		CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK:
			if is_instance_valid(_player_unit_node) and target.has_method("take_damage"):
				var damage = _player_unit_node.current_block * 2
				target.take_damage(damage)
		
		CardEffectData.EffectType.MODIFY_INITIATIVE_NEXT_ROUND:
			# POZNÁMKA: Ujisti se, že TurnManager bere jako argument 'Node' nebo 'Unit'
			if has_node("/root/TurnManager") and is_instance_valid(target):
				TurnManager.modify_initiative_next_round(target, effect.value)
			else:
				printerr("Efekt MODIFY_INITIATIVE nelze aplikovat na ", target)


# Pomocná funkce pro kontrolu útočného dosahu (přidej ji do BattleScene)
func can_attack_target(attacker: Unit, target: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	
	var distance = battle_grid.get_distance(attacker.grid_position, target.grid_position)
	return distance <= attacker.unit_data.attack_range

# OPRAVA: Návratový typ Node2D změněn na Node3D (nebo Array[Unit])
func _get_targets_for_effect(effect: CardEffectData, initial_target_node: Node3D) -> Array:
	var targets: Array = []
	var clicked_grid_cell = get_grid_cell_under_mouse() # OPRAVA: Použití 3D Raycast funkce místo get_global_mouse_position
	var grid_ref = battle_grid_instance
	if not grid_ref and has_node("BattleGrid"):
		grid_ref = get_node("BattleGrid")
	
	if effect.target_type == CardEffectData.TargetType.ANY_GRID_CELL:
		if not grid_ref:
			return targets
		var affected_cells = grid_ref.get_cells_for_aoe(clicked_grid_cell, effect.area_of_effect_type, effect.aoe_param_x, effect.aoe_param_y)
		for cell in affected_cells:
			var unit_on_cell = grid_ref.get_object_on_cell(cell)
			if is_instance_valid(unit_on_cell) and unit_on_cell.get_unit_data().faction == UnitData.Faction.ENEMY:
				targets.append(unit_on_cell)
		return targets
	match effect.target_type:
		CardEffectData.TargetType.SELF_UNIT:
			if is_instance_valid(_player_unit_node):
				targets.append(_player_unit_node)
		CardEffectData.TargetType.SELECTED_ENEMY_UNIT:
			if is_instance_valid(initial_target_node) and initial_target_node.get_unit_data().faction == UnitData.Faction.ENEMY:
				if grid_ref and is_instance_valid(_player_unit_node) and _selected_card_data and grid_ref.get_distance(_player_unit_node.grid_position, initial_target_node.grid_position) <= _selected_card_data.range_value:
					targets.append(initial_target_node)
		CardEffectData.TargetType.ALL_ENEMY_UNITS:
			targets.assign(_enemy_units)
		CardEffectData.TargetType.ALL_ALLY_UNITS:
			# V této hře je hráč jediný spojenec, ale pro budoucí rozšíření můžeme přidat další spojence
			if is_instance_valid(_player_unit_node):
				targets.append(_player_unit_node)
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
	
	# Reset tracking poškození na konci tahu hráče (pro consecrated_barrier)
	# Toto zajistí, že v dalším tahu hráče bude tracking správně nastaven
	_took_damage_last_turn = false
	
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
	energy_label.text = TranslationHelper.tr_format("ui.battle.energy", {"value": new_amount})

func _physics_process(_delta):
	# Použijeme novou funkci pro Raycast místo 2D mouse position
	var grid_cell = get_grid_cell_under_mouse() 
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

# OPRAVA: Return type je Unit (což je Node3D, takže ok, ale explicitní Unit je lepší)
func _spawn_unit(unit_data: UnitData, grid_pos: Vector2i) -> Unit:
	if not unit_data: return null
	var unit_instance: Unit = UnitScene.instantiate()
	unit_instance.unit_data = unit_data
	if battle_grid_instance.place_object_on_cell(unit_instance, grid_pos):
		return unit_instance
	else:
		unit_instance.queue_free()
		return null

func _on_card_right_clicked(card_data: CardData):
	"""Toggle tooltip při pravém kliknutí na kartu"""
	if not card_tooltip:
		return
	
	# Pokud je tooltip zobrazený pro tuto kartu, schováme ho
	if card_tooltip.visible and _current_tooltip_card_data == card_data:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null
	else:
		# Jinak zobrazíme tooltip pro tuto kartu
		_current_tooltip_card_data = card_data
		_show_card_tooltip()

func _show_card_tooltip():
	"""Zobrazí tooltip pro aktuálně vybranou kartu"""
	if not _current_tooltip_card_data or not card_tooltip:
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(350, 250)  # Velikost tooltipu
	
	# Zobrazíme tooltip v pravém horním rohu, aby nepřekážel kartám ani gridu
	# PlayerHandUI je dole (cca 448-576), grid je nahoře a uprostřed
	# Pravý horní roh je volný (kromě malého "Okamžitá výhra" tlačítka)
	var tooltip_pos = Vector2(
		screen_size.x - tooltip_size.x - 20,  # Vpravo s odstupem
		80  # Odshora s odstupem pod top bar
	)
	
	# Zkontrolujeme, jestli tooltip nevyjde z obrazovky (bezpečnostní kontrola)
	if tooltip_pos.x + tooltip_size.x > screen_size.x:
		tooltip_pos.x = screen_size.x - tooltip_size.x - 10
	
	if tooltip_pos.y + tooltip_size.y > screen_size.y:
		tooltip_pos.y = screen_size.y - tooltip_size.y - 10
	
	if tooltip_pos.x < 0:
		tooltip_pos.x = 10
	
	if tooltip_pos.y < 0:
		tooltip_pos.y = 10
	
	card_tooltip.show_tooltip(_current_tooltip_card_data, tooltip_pos)

func _update_card_target_preview():
	if not _selected_card_data: return
	
	# OPRAVA: Použití 3D Raycast funkce místo get_global_mouse_position
	var mouse_grid_pos = get_grid_cell_under_mouse()
	
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

# OPRAVA: Argument unit je Node3D (nebo Unit)
func _apply_terrain_effect(unit: Node3D, terrain: TerrainData):
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
	pass # Ve 3D zatím hranice neřešíme

# OPRAVA: Návratový typ Node3D (nebo Unit)
func get_player_unit() -> Node3D:
	return _player_unit_node

func get_enemy_count() -> int:
	return _enemy_units.size()

func get_all_enemies() -> Array:
	return _enemy_units

# NOVÁ FUNKCE PRO 3D RAYCAST (Náhrada za get_global_mouse_position)
func get_grid_cell_under_mouse() -> Vector2i:
	var mouse_pos = get_viewport().get_mouse_position()
	if not camera_3d: return Vector2i(-1, -1)
	
	# Vytvoříme rovinu podlahy (Y = 0)
	var drop_plane = Plane(Vector3.UP, 0)
	
	var ray_origin = camera_3d.project_ray_origin(mouse_pos)
	var ray_normal = camera_3d.project_ray_normal(mouse_pos)
	
	var intersection = drop_plane.intersects_ray(ray_origin, ray_normal)
	
	if intersection:
		# Přepočet 3D pozice na indexy mřížky
		# Předpokládáme, že cell_size_3d je v BattleGrid nastaveno (default 2.0)
		var cell_size = 2.0 
		if battle_grid_instance and "cell_size_3d" in battle_grid_instance:
			cell_size = battle_grid_instance.cell_size_3d
			
		var grid_x = round(intersection.x / cell_size)
		var grid_y = round(intersection.z / cell_size)
		return Vector2i(grid_x, grid_y)
	
	return Vector2i(-1, -1)

func _process_special_action(enemy_unit: Unit, action: EnemyAIBase.AIAction) -> void:
	"""Zpracuje speciální akce AI (meteorit, spawn, buff, heal)"""
	var special_type = action.special_data.get("type", "")
	
	match special_type:
		"meteor":
			# Mage meteorit - poškození všem jednotkám na gridu
			enemy_unit.show_status_text("☄️ METEORIT!", "critical")
			await get_tree().create_timer(1.0).timeout
			
			var damage = int(enemy_unit.unit_data.attack_damage * action.special_data.get("damage_multiplier", 2.0))
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			
			for unit in all_units:
				if unit is Unit:
					await unit.take_damage(damage)
					# Aplikuje burning všem
					unit.apply_status("burning", 2, 3)
			
			# Zapálí celý grid (můžeme přidat vizuální efekt)
			print("🔥 Grid je zapálen!")
		
		"spawn_spirit":
			# Druid spawn spiritu
			var spawn_pos = _find_spawn_position(enemy_unit)
			if spawn_pos != Vector2i(-1, -1):
				var is_guardian = action.special_data.get("is_guardian", false)
				var spirit_unit_data
				if is_guardian:
					spirit_unit_data = preload("res://data/units/guardian_spirit.tres")
				else:
					spirit_unit_data = preload("res://data/units/wolf_spirit.tres")
				
				var spirit_node = _spawn_unit(spirit_unit_data, spawn_pos)
				if is_instance_valid(spirit_node):
					_enemy_units.append(spirit_node)
					spirit_node.died.connect(_on_unit_died)
					spirit_node.stats_changed.connect(_on_unit_stats_changed)
					# Přidáme spirit do TurnManager
					if has_node("/root/TurnManager"):
						TurnManager.add_unit(spirit_node)
					if is_guardian:
						print("🛡️ Druid spawnul guardian spiritu na pozici: %s" % spawn_pos)
					else:
						print("🌿 Druid spawnul spiritu na pozici: %s" % spawn_pos)
				else:
					print("❌ Chyba při spawnu spiritu")
		
		"buff_ally":
			# Monk buffuje spojence
			var target = action.special_data.get("target")
			if is_instance_valid(target) and target is Unit:
				var bonus = action.special_data.get("damage_bonus", 2)
				var duration = action.special_data.get("duration", 3)
				target.apply_status("monk_blessing", bonus, duration)
				target.show_status_text("BLESSED!", "heal")
				print("✨ Monk požehnal spojence: +%d damage na %d kol" % [bonus, duration])
		
		"heal_ally":
			# Healer léčí spojence
			var target = action.special_data.get("target")
			if is_instance_valid(target) and target is Unit:
				var heal_amount = action.special_data.get("heal_amount", 8)
				target.heal(heal_amount)
				target.show_status_text("HEALED!", "heal")
				print("💚 Healer vyléčil spojence za %d HP" % heal_amount)
		
		_:
			print("⚠️ Neznámý typ speciální akce: %s" % special_type)

func _find_spawn_position(near_unit: Unit) -> Vector2i:
	"""Najde volnou pozici pro spawn jednotky poblíž"""
	var adjacent = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT
	]
	
	for offset in adjacent:
		var pos = near_unit.grid_position + offset
		if battle_grid_instance.is_cell_active(pos):
			var obj = battle_grid_instance.get_object_on_cell(pos)
			if not obj:
				return pos
	
	return Vector2i(-1, -1)
