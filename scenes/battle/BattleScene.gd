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
const AIController = preload("res://scripts/EnemyAIController.gd")

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
@onready var camera_2d: Camera2D = $Camera2D

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
var _player_unit_node: Node2D = null
var _selected_unit: Node2D = null
var _enemy_units: Array[Node2D] = []
var _is_action_processing: bool = false
var _cards_to_draw_queue: int = 0
var _is_drawing_cards: bool = false
var _is_first_turn: bool = true

func _ready():
	DebugLogger.log_info("Battle scene loaded", "BATTLE")
	player_info_panel.update_from_player_data()
	_current_battle_state = BattleState.SETUP
	_is_first_turn = true
	victory_label.visible = false
	enemy_info_panel.hide_panel()
	card_pile_viewer.hide()

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


# NOVÉ A UPRAVENÉ FUNKCE PRO START HRY
func start_player_spawn_selection():
	_current_battle_state = BattleState.AWAITING_PLAYER_SPAWN
	var spawn_points = battle_grid_instance.get_player_spawn_points(3) # Zobrazí pozice v prvních 3 sloupcích
	battle_grid_instance.show_player_spawn_points(spawn_points)
	end_turn_button.disabled = true
	
func confirm_player_spawn(at_position: Vector2i):
	battle_grid_instance.hide_player_spawn_points()
	
	spawn_player_unit_at(at_position)
	spawn_enemy_units()
	_place_terrain_features()
	
	# Už zde neaplikujeme artefakty, přesunuli jsme to
	call_deferred("start_player_turn")


func spawn_player_unit_at(grid_pos: Vector2i):
	print("DEBUG před spawnem: PlayerData.current_hp = %d, max_hp = %d" % [PlayerData.current_hp, PlayerData.max_hp])
	if PlayerData.selected_subclass and PlayerData.selected_subclass.specific_unit_data:
		_player_unit_node = _spawn_unit(PlayerData.selected_subclass.specific_unit_data, grid_pos)
		if is_instance_valid(_player_unit_node):
			_player_unit_node.unit_selected.connect(_on_unit_selected_on_grid)
			_player_unit_node.stats_changed.connect(_on_unit_stats_changed)
			_player_unit_node.died.connect(_on_player_died)



func start_player_turn():
	_current_battle_state = BattleState.PROCESSING
	end_turn_button.disabled = true
	
	PlayerData.reset_energy()
	
	if is_instance_valid(_player_unit_node):
		_player_unit_node.reset_for_new_turn()
		
		if _is_first_turn:
			# --- OPRAVENO ZDE ---
			for artifact in PlayerData.artifacts:
				if artifact.effect_id == "start_of_combat_block":
					_player_unit_node.add_block(artifact.value)
					print("Artefakt '%s' přidal hráči %d blocku." % [artifact.artifact_name, artifact.value])
			_is_first_turn = false
		
		var extra_draw = _player_unit_node.process_turn_start_statuses()
		_cards_to_draw_queue = starting_hand_size + extra_draw
		_draw_next_card_in_queue()
	
	for unit in _enemy_units:
		if is_instance_valid(unit):
			unit.reset_for_new_turn()
			unit.process_turn_start_statuses()
			
	set_enemy_intents()
	battle_grid_instance.show_danger_zone(_enemy_units)

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

func start_enemy_turn():
	_current_battle_state = BattleState.ENEMY_TURN
	end_turn_button.disabled = true
	
	battle_grid_instance.hide_danger_zone()
	
	if is_instance_valid(_player_unit_node):
		_player_unit_node.process_turn_end_statuses()

	_reset_player_selection()
	
	# Spustíme animaci odhození. Zbytek logiky se provede po jejím dokončení.
	player_hand_ui_instance.discard_hand_animated(discard_pile_button.global_position)

func _on_hand_discard_animation_finished():
	# Tato funkce se zavolá, až když animace odhození skončí.
	PlayerData.discard_hand()
	_update_pile_counts()
	
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(process_enemy_actions)
# Starou funkci _update_hand_ui() SMAŽTE NEBO ZAKOMENTUJTE, již není potřeba.
# func _update_hand_ui():
# 	player_hand_ui_instance.clear_hand()
# 	for card_data in PlayerData.current_hand: player_hand_ui_instance.add_card_to_hand(card_data)
# 	_update_pile_counts()

func end_battle_as_victory():
	_current_battle_state = BattleState.BATTLE_OVER
	if is_instance_valid(_player_unit_node):
		# UPOZORNĚNÍ: Přímé nastavování current_hp obejde náš nový signál.
		# Prozatím to necháme, ale do budoucna by bylo lepší mít
		# funkci PlayerData.set_health(), která signál také vyšle.
		PlayerData.current_hp = _player_unit_node.current_health
	GameManager.battle_finished(true)

func _on_win_button_pressed():
	end_battle_as_victory()

func _on_player_died(_unit_node: Node2D):
	DebugLogger.log_critical("PLAYER DIED! HP: %d, Floor: %d" % [PlayerData.current_hp, PlayerData.floors_cleared], "BATTLE")
	_current_battle_state = BattleState.BATTLE_OVER
	GameManager.battle_finished(false)

func _on_enemy_died(enemy_node: Node2D):
	DebugLogger.log_enemy_action(enemy_node.unit_data.unit_name, "died", {"remaining_enemies": _enemy_units.size() - 1})
	if _enemy_units.has(enemy_node):
		_enemy_units.erase(enemy_node)
	battle_grid_instance.remove_object_by_instance(enemy_node)
	if _enemy_units.is_empty():
		end_battle_as_victory()

func spawn_enemy_units():
	if not encounter_data:
		printerr("BattleScene: Chybí EncounterData!")
		return

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

	for enemy_entry in encounter_data.enemies:
		if not enemy_entry is EncounterEntry or not enemy_entry.unit_data: continue
		
		if available_spawn_cells.is_empty():
			printerr("Nedostatek volných pozic pro spawn nepřátel!")
			break
			
		var random_pos = available_spawn_cells.pick_random()
		available_spawn_cells.erase(random_pos)

		var enemy_node = _spawn_unit(enemy_entry.unit_data, random_pos)
		if is_instance_valid(enemy_node):
			_enemy_units.append(enemy_node)
			enemy_node.died.connect(_on_enemy_died)
			enemy_node.stats_changed.connect(_on_unit_stats_changed)

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
	var card_played_successfully = false
	
	# Uložíme si referenci na kartu, kterou hrajeme
	var card_ui_to_remove = _selected_card_ui
	
	for effect_data in card.effects:
		var targets = _get_targets_for_effect(effect_data, initial_target)
		if not targets.is_empty():
			card_played_successfully = true
			for target_unit in targets:
				if is_instance_valid(target_unit):
					_apply_single_effect(effect_data, target_unit) # Už zde není await
					
	if card_played_successfully:
		var has_exhaust_effect = card.effects.any(func(e): return e.effect_type == CardEffectData.EffectType.EXHAUST)
		if has_exhaust_effect:
			PlayerData.add_card_to_exhaust_pile(card)
		else:
			PlayerData.add_card_to_discard_pile(card)
		PlayerData.current_hand.erase(card)
		
		# OPRAVA: Odstraníme vizuální kartu a seřadíme zbytek
		if is_instance_valid(card_ui_to_remove):
			card_ui_to_remove.queue_free()
		player_hand_ui_instance._request_arrange()
		_update_pile_counts()
	else:
		print("Karta '%s' nenašla žádný platný cíl." % card.card_name)
		PlayerData.gain_energy(card.cost)

	_is_action_processing = false
	_reset_player_selection()
	
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
			if target.has_method("take_damage"): target.take_damage(effect.value)
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
			# OPRAVA: Místo přímého volání UI jen přidáme karty do fronty
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

func process_enemy_actions() -> void:
	_is_action_processing = true
	var ai_controller = AIController.new()
	for enemy_unit in _enemy_units:
		if not is_instance_valid(enemy_unit): continue
		enemy_unit.hide_intent()
		var action = ai_controller.get_next_action(enemy_unit, [_player_unit_node], battle_grid_instance)
		
		match action.type:
			AIController.AIAction.ActionType.ATTACK:
				await enemy_unit.attack(action.target_unit)
				
			AIController.AIAction.ActionType.MOVE:
				if enemy_unit.can_move():
					enemy_unit.use_move_action()
					var path = action.move_path
					
					if path.size() > 1:
						var move_dist = min(path.size() - 1, enemy_unit.get_current_movement_range())
						var final_target_pos = path[move_dist]
						
						# <<< ZDE JE NOVÁ LOGIKA PRO NEPŘÍTELE A BAHNO >>>
						# Projdeme naplánovanou cestu a zkontrolujeme, jestli nevede přes bahno.
						for i in range(1, move_dist + 1):
							var path_cell = path[i]
							var terrain_on_cell = battle_grid_instance.get_terrain_on_cell(path_cell)
							if is_instance_valid(terrain_on_cell) and terrain_on_cell.terrain_name == "Mud":
								# Našli jsme bahno! Toto bude nový cíl a pohyb zde končí.
								final_target_pos = path_cell
								break # Ukončíme cyklus, našli jsme první bahnité pole na cestě.
						
						# Přesuneme nepřítele na finální pozici (buď původní, nebo na bahno).
						battle_grid_instance.remove_object_by_instance(enemy_unit)
						battle_grid_instance.place_object_on_cell(enemy_unit, final_target_pos, true)
						
						# Aplikujeme efekt terénu z cílového políčka (což je teď bahno).
						var target_terrain = battle_grid_instance.get_terrain_on_cell(final_target_pos)
						if is_instance_valid(target_terrain):
							enemy_unit.process_terrain_effects(target_terrain)
							
						await get_tree().create_timer(0.4).timeout
						
						# Po přesunu zkusíme znovu zaútočit, jestli je hráč v dosahu.
						var attack_action = ai_controller.get_next_action(enemy_unit, [_player_unit_node], battle_grid_instance)
						if attack_action.type == AIController.AIAction.ActionType.ATTACK:
							await enemy_unit.attack(attack_action.target_unit)

		enemy_unit.process_turn_end_statuses()

	await get_tree().create_timer(0.5).timeout
	_is_action_processing = false
	start_player_turn()

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

func _on_unit_stats_changed(unit_node: Node2D):
	if is_instance_valid(unit_node) and unit_node == _player_unit_node:
		player_info_panel.update_stats(unit_node)

func _on_draw_pile_clicked(): card_pile_viewer.show_cards(PlayerData.draw_pile)
func _on_discard_pile_clicked(): card_pile_viewer.show_cards(PlayerData.discard_pile)
func _on_end_turn_button_pressed():
	if _current_battle_state == BattleState.PLAYER_TURN: start_enemy_turn()
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
	for enemy_unit in _enemy_units:
		if is_instance_valid(enemy_unit) and enemy_unit.has_method("show_intent"):
			var damage = 0
			if enemy_unit.get_unit_data(): damage = enemy_unit.get_unit_data().attack_damage
			enemy_unit.show_intent(damage)

func _spawn_unit(unit_data: UnitData, grid_pos: Vector2i) -> Node2D:
	if not unit_data: return null
	var unit_instance = UnitScene.instantiate()
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
