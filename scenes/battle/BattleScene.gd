extends Node2D

const SHAPE_DEFAULT = [
	"111111111111111",
	"111111111111111",
	"111111111111111",
	"111111111111111",
	"111111111111111",
	"111111111111111",
	"111111111111111",
	"111111111111111",
	"111111111111111",
	"111111111111111",
]

const SHAPE_CROSS = [
	"0001111111000",
	"0001111111000",
	"1111111111111",
	"1111111111111",
	"1111111111111",
	"1111111111111",
	"0001111111000",
	"0001111111000",
]

const SHAPE_DIAMOND = [
	"00001110000",
	"00011111000",
	"00111111100",
	"01111111110",
	"11111111111",
	"01111111110",
	"00111111100",
	"00011111000",
	"00001110000",
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

# Ostatní reference, které nejsou v CanvasLayer
@onready var battle_grid_instance: BattleGrid = $BattleGrid
@onready var camera_2d: Camera2D = $Camera2D
@export var camera_speed = 1.0 # Citlivost pohybu myší
@export var camera_zoom_speed = 0.1 # Rychlost/citlivost zoomování
@export var camera_min_zoom = 0.5 # Jak nejvíce lze kameru oddálit
@export var camera_max_zoom = 2.0 # Jak nejvíce lze kameru přiblížit

enum PlayerActionState { IDLE, CARD_SELECTED, UNIT_SELECTED }
var _player_action_state: PlayerActionState = PlayerActionState.IDLE
enum TurnState { PLAYER_TURN, ENEMY_TURN, PROCESSING, BATTLE_OVER }
var _current_turn_state: TurnState = TurnState.PROCESSING

@export var starting_hand_size: int = 5

var _selected_card_ui: Control = null
var _selected_card_data: CardData = null
var _player_unit_node: Node2D = null
var _selected_unit: Node2D = null
var _enemy_units: Array[Node2D] = []

func _ready():
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
	
	if is_instance_valid(camera_2d) and camera_2d.has_method("set_camera_limits"):
		camera_2d.set_camera_limits(battle_grid_instance.grid_columns, battle_grid_instance.grid_rows, battle_grid_instance.cell_size)
	
	_generate_grid_from_shape()
	spawn_player_unit()
	spawn_enemy_units()
	_place_terrain_features()
	await get_tree().create_timer(0.2).timeout
	start_player_turn()

func _on_win_button_pressed():
	print("DEBUG: Okamžitá výhra aktivována.")
	end_battle_as_victory()

func _on_player_died(_unit_node: Node2D):
	_current_turn_state = TurnState.BATTLE_OVER
	GameManager.battle_finished(false)

func _on_enemy_died(enemy_node: Node2D):
	if _enemy_units.has(enemy_node):
		_enemy_units.erase(enemy_node)
	battle_grid_instance.remove_object_by_instance(enemy_node)
	if _enemy_units.is_empty():
		end_battle_as_victory()

func spawn_player_unit():
	if PlayerData.selected_subclass and PlayerData.selected_subclass.specific_unit_data:
		_player_unit_node = _spawn_unit(PlayerData.selected_subclass.specific_unit_data, Vector2i(1, battle_grid_instance.grid_rows / 2))
		if is_instance_valid(_player_unit_node):
			_player_unit_node.unit_selected.connect(_on_unit_selected_on_grid)
			_player_unit_node.stats_changed.connect(_on_unit_stats_changed)
			_player_unit_node.died.connect(_on_player_died)

func start_player_turn():
	_current_turn_state = TurnState.PLAYER_TURN
	end_turn_button.disabled = false
	PlayerData.reset_energy()
	
	if is_instance_valid(_player_unit_node):
		_player_unit_node.reset_for_new_turn()
		var extra_draw = _player_unit_node.process_turn_start_statuses()
		PlayerData.draw_new_hand(starting_hand_size + extra_draw)
	
	for unit in _enemy_units:
		if is_instance_valid(unit):
			unit.reset_for_new_turn()
			unit.process_turn_start_statuses()
			
	set_enemy_intents()
	_update_hand_ui()

func start_enemy_turn():
	_current_turn_state = TurnState.ENEMY_TURN
	end_turn_button.disabled = true
	
	if is_instance_valid(_player_unit_node):
		_player_unit_node.process_turn_end_statuses()

	_reset_player_selection()
	PlayerData.discard_hand()
	player_hand_ui_instance.clear_hand()
	_update_pile_counts()
	await get_tree().create_timer(0.5).timeout
	process_enemy_actions()

func _on_player_hand_card_clicked(card_ui_node: Control, card_data_resource: CardData):
	if _current_turn_state != TurnState.PLAYER_TURN: return
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

func try_play_card(card: CardData, initial_target: Node2D):
	if not card: return
	if not PlayerData.spend_energy(card.cost):
		print("Nedostatek energie!")
		return

	var card_played_successfully = false
	for effect_data in card.effects:
		if effect_data.target_type == CardEffectData.TargetType.ANY_GRID_CELL:
			card_played_successfully = true
		
		var targets = _get_targets_for_effect(effect_data, initial_target)
		if not targets.is_empty():
			card_played_successfully = true
			for target_unit in targets:
				if is_instance_valid(target_unit):
					_apply_single_effect(effect_data, target_unit)
					
	if card_played_successfully:
		var has_exhaust_effect = card.effects.any(func(e): return e.effect_type == CardEffectData.EffectType.EXHAUST)
		if has_exhaust_effect:
			PlayerData.add_card_to_exhaust_pile(card)
		else:
			PlayerData.add_card_to_discard_pile(card)
		PlayerData.current_hand.erase(card)
		_reset_player_selection()
		_update_hand_ui()
	else:
		print("Karta '%s' nenašla žádný platný cíl." % card.card_name)
		PlayerData.gain_energy(card.cost)

func _on_unit_selected_on_grid(unit_node: Node2D):
	if _current_turn_state != TurnState.PLAYER_TURN: return
	
	if unit_node.unit_data.faction == UnitData.Faction.PLAYER and unit_node.can_move():
		_reset_player_selection()
		_player_action_state = PlayerActionState.UNIT_SELECTED
		_selected_unit = unit_node
		_selected_unit.set_selected_visual(true)
		var current_move_range = unit_node.get_current_movement_range()
		battle_grid_instance.show_movable_range(unit_node.grid_position, current_move_range)
	else:
		print("Tuto jednotku nelze vybrat nebo se již v tomto kole pohnula.")

func _execute_move(unit_to_move: Node2D, target_cell: Vector2i):
	unit_to_move.use_move_action()
	battle_grid_instance.remove_object_by_instance(unit_to_move)
	battle_grid_instance.place_object_on_cell(unit_to_move, target_cell, true)


	var terrain_on_cell = battle_grid_instance.get_terrain_on_cell(target_cell)
	if is_instance_valid(terrain_on_cell):
		_apply_terrain_effect(unit_to_move, terrain_on_cell)

	_reset_player_selection()
	
func _apply_single_effect(effect: CardEffectData, target: Node2D):
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
			PlayerData.draw_cards(effect.value)
			_update_hand_ui()
		CardEffectData.EffectType.GAIN_ENERGY:
			PlayerData.gain_energy(effect.value)
		CardEffectData.EffectType.APPLY_STATUS:
			if target.has_method("apply_status"): target.apply_status(effect.string_value, effect.value)
		CardEffectData.EffectType.GAIN_EXTRA_MOVE:
			if target.has_method("gain_extra_move"): target.gain_extra_move()
		_:
			pass

func process_enemy_actions():
	var ai_controller = AIController.new()
	for enemy_unit in _enemy_units:
		if not is_instance_valid(enemy_unit): continue
		
		enemy_unit.hide_intent()

		var action = ai_controller.get_next_action(enemy_unit, [_player_unit_node], battle_grid_instance)
		match action.type:
			AIController.AIAction.ActionType.ATTACK:
				enemy_unit.attack(action.target_unit)
			AIController.AIAction.ActionType.MOVE:
				if enemy_unit.can_move():
					enemy_unit.use_move_action()
					var path = action.move_path
					if path.size() > 1:
						var move_dist = min(path.size() - 1, enemy_unit.get_current_movement_range())
						if move_dist > 0:
							var target_pos = path[move_dist]
							battle_grid_instance.remove_object_by_instance(enemy_unit)
							battle_grid_instance.place_object_on_cell(enemy_unit, target_pos, true)

							var terrain_on_cell = battle_grid_instance.get_terrain_on_cell(target_pos)
							if is_instance_valid(terrain_on_cell):
								_apply_terrain_effect(enemy_unit, terrain_on_cell)
							
							await get_tree().create_timer(0.4).timeout
							
							var attack_action = ai_controller.get_next_action(enemy_unit, [_player_unit_node], battle_grid_instance)
							if attack_action.type == AIController.AIAction.ActionType.ATTACK:
								enemy_unit.attack(attack_action.target_unit)

		enemy_unit.process_turn_end_statuses()

	await get_tree().create_timer(0.5).timeout
	start_player_turn()

# Soubor: BattleScene.gd

func _unhandled_input(event: InputEvent):
	# --- Logika pro ovládání kamery ---
	# Tato část kódu se provede vždy.
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE or event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		camera_2d.position -= event.relative / camera_2d.zoom * camera_speed

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var new_zoom_value = camera_2d.zoom / (1 + camera_zoom_speed)
			camera_2d.zoom = new_zoom_value.clamp(Vector2(camera_min_zoom, camera_min_zoom), Vector2(camera_max_zoom, camera_max_zoom))
			
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var new_zoom_value = camera_2d.zoom * (1 + camera_zoom_speed)
			camera_2d.zoom = new_zoom_value.clamp(Vector2(camera_min_zoom, camera_min_zoom), Vector2(camera_max_zoom, camera_max_zoom))

	# --- Původní herní logika ---
	# Zbytek kódu se provede, pouze pokud je na tahu hráč.
	if _current_turn_state != TurnState.PLAYER_TURN: return
	if card_pile_viewer.visible:
		if event.is_action_pressed("ui_cancel"): card_pile_viewer.hide(); return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _player_action_state == PlayerActionState.CARD_SELECTED:
			var is_self_targeting_card = false
			if is_instance_valid(_selected_card_data):
				is_self_targeting_card = _selected_card_data.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELF_UNIT)

			if is_self_targeting_card:
				if is_instance_valid(_player_unit_node):
					try_play_card(_selected_card_data, _player_unit_node)
					get_viewport().set_input_as_handled()
					return
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

func _get_targets_for_effect(effect: CardEffectData, initial_target_node: Node2D) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var clicked_grid_cell = battle_grid_instance.get_cell_at_world_position(get_global_mouse_position())

	if effect.target_type == CardEffectData.TargetType.ANY_GRID_CELL:
		var affected_cells = battle_grid_instance.get_cells_for_aoe(
			clicked_grid_cell,
			effect.area_of_effect_type,
			effect.aoe_param_x,
			effect.aoe_param_y
		)
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
	_player_action_state = PlayerActionState.IDLE

func _on_unit_stats_changed(unit_node: Node2D):
	if not is_instance_valid(unit_node): return
	if unit_node == _player_unit_node:
		player_info_panel.update_stats(unit_node)

func _on_draw_pile_clicked(): card_pile_viewer.show_cards(PlayerData.draw_pile)
func _on_discard_pile_clicked(): card_pile_viewer.show_cards(PlayerData.discard_pile)

func _on_end_turn_button_pressed():
	if _current_turn_state == TurnState.PLAYER_TURN:
		start_enemy_turn()

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
						if distance <= card.range_value:
							valid_target_cells.append(enemy.grid_position)
			CardEffectData.TargetType.SELF_UNIT:
				is_attack = false
				if not valid_target_cells.has(_player_unit_node.grid_position):
					valid_target_cells.append(_player_unit_node.grid_position)
	battle_grid_instance.show_targetable_cells(valid_target_cells, is_attack)

func _update_pile_counts():
	if is_instance_valid(draw_pile_button):
		draw_pile_button.update_count(PlayerData.draw_pile.size())
	if is_instance_valid(discard_pile_button):
		discard_pile_button.update_count(PlayerData.discard_pile.size())

func _update_hand_ui():
	player_hand_ui_instance.clear_hand()
	for card_data in PlayerData.current_hand:
		player_hand_ui_instance.add_card_to_hand(card_data)
	_update_pile_counts()

func set_enemy_intents():
	for enemy_unit in _enemy_units:
		if is_instance_valid(enemy_unit) and enemy_unit.has_method("show_intent"):
			var damage = 0
			if enemy_unit.get_unit_data():
				damage = enemy_unit.get_unit_data().attack_damage
			enemy_unit.show_intent(damage)

func spawn_enemy_units():
	if not encounter_data:
		printerr("BattleScene: Chybí EncounterData!")
		return

	# --- NOVÁ LOGIKA PRO NÁHODNÝ SPAWN ---

	# 1. Definujeme oblast, kde se nepřátelé mohou objevit (pravá polovina mřížky).
	var spawn_start_x = battle_grid_instance.grid_columns / 2
	var spawn_end_x = battle_grid_instance.grid_columns - 1
	var spawn_start_y = 0
	var spawn_end_y = battle_grid_instance.grid_rows - 1
	
	# 2. Vytvoříme seznam všech možných volných pozic v této oblasti.
	var available_spawn_cells: Array[Vector2i] = []
	for y in range(spawn_start_y, spawn_end_y + 1):
		for x in range(spawn_start_x, spawn_end_x + 1):
			var cell = Vector2i(x, y)
			# Ujistíme se, že políčko je průchozí a není obsazené.
			var terrain = battle_grid_instance.get_terrain_on_cell(cell)
			var is_walkable = not terrain or terrain.is_walkable
			
			if battle_grid_instance.get_object_on_cell(cell) == null and is_walkable:
				available_spawn_cells.append(cell)

	# 3. Projdeme nepřátele a každému přiřadíme náhodnou pozici.
	for enemy_entry in encounter_data.enemies:
		if not enemy_entry is EncounterEntry or not enemy_entry.unit_data:
			continue
		
		# Pokud už nejsou volná místa, skončíme.
		if available_spawn_cells.is_empty():
			printerr("Nedostatek volných pozic pro spawn nepřátel!")
			break
			
		# Vybereme náhodnou pozici a hned ji ze seznamu odstraníme,
		# aby se na ní neobjevil další nepřítel.
		var random_pos = available_spawn_cells.pick_random()
		available_spawn_cells.erase(random_pos)

		var enemy_node = _spawn_unit(enemy_entry.unit_data, random_pos)
		if is_instance_valid(enemy_node):
			_enemy_units.append(enemy_node)
			enemy_node.died.connect(_on_enemy_died)
			enemy_node.stats_changed.connect(_on_unit_stats_changed)

func _spawn_unit(unit_data: UnitData, grid_pos: Vector2i) -> Node2D:
	if not unit_data: return null
	var unit_instance = UnitScene.instantiate()
	unit_instance.unit_data = unit_data
	if battle_grid_instance.place_object_on_cell(unit_instance, grid_pos):
		return unit_instance
	else:
		unit_instance.queue_free()
		return null

func end_battle_as_victory():
	_current_turn_state = TurnState.BATTLE_OVER
	if is_instance_valid(_player_unit_node):
		PlayerData.current_hp = _player_unit_node.current_health
	GameManager.battle_finished(true)

func _on_card_hover_started(card_data: CardData):
	pass

func _on_card_hover_ended():
	if _player_action_state != PlayerActionState.CARD_SELECTED:
		battle_grid_instance.hide_aoe_highlight()



# Soubor: BattleScene.gd

func _update_card_target_preview():
	if not _selected_card_data: return

	var mouse_grid_pos = battle_grid_instance.get_cell_at_world_position(get_global_mouse_position())

	# Stále kontrolujeme, jestli je myš v obdélníku, aby to nepočítalo zbytečně
	if not battle_grid_instance.is_valid_grid_position(mouse_grid_pos):
		battle_grid_instance.hide_aoe_highlight()
		return
	
	var final_aoe_cells: Array[Vector2i] = []

	for effect in _selected_card_data.effects:
		if effect.area_of_effect_type == CardEffectData.AreaOfEffectType.SINGLE_TARGET:
			continue

		# 1. Získáme "hrubý" geometrický tvar od BattleGrid (jako v původní verzi)
		var potential_cells = battle_grid_instance.get_cells_for_aoe(
			mouse_grid_pos,
			effect.area_of_effect_type,
			effect.aoe_param_x,
			effect.aoe_param_y
		)
		
		# 2. Z tohoto tvaru vybereme jen buňky, které na mapě reálně existují
		for cell in potential_cells:
			if battle_grid_instance.is_cell_active(cell):
				final_aoe_cells.append(cell)

	# 3. Zobrazíme pouze platné buňky
	battle_grid_instance.show_aoe_highlight(final_aoe_cells)

func _place_terrain_features():
	var terrains_to_spawn = [
		{
			"data": preload("res://data/terrain/rock.tres"),
			"count": 3
		},
		{
			"data": preload("res://data/terrain/mud.tres"),
			"count": 2
		}
	]
	
	var occupied_cells = []

	if is_instance_valid(_player_unit_node):
		occupied_cells.append(_player_unit_node.grid_position)
	for enemy in _enemy_units:
		if is_instance_valid(enemy):
			occupied_cells.append(enemy.grid_position)

	for terrain_info in terrains_to_spawn:
		var terrain_data = terrain_info.data
		var count_to_place = terrain_info.count
		var placed_count = 0
		var attempts = 0
		
		while placed_count < count_to_place and attempts < 100:
			attempts += 1
			var rand_x = randi_range(1, battle_grid_instance.grid_columns - 2)
			var rand_y = randi_range(0, battle_grid_instance.grid_rows - 1)
			var random_pos = Vector2i(rand_x, rand_y)

			if not occupied_cells.has(random_pos):
				battle_grid_instance.place_terrain(random_pos, terrain_data)
				occupied_cells.append(random_pos)
				placed_count += 1

func _apply_terrain_effect(unit: Node2D, terrain: TerrainData):
	"""
	Zpracuje a aplikuje efekty z terénu na jednotku, která na něj vstoupila.
	"""
	if not is_instance_valid(unit) or not is_instance_valid(terrain):
		return

	# Použijeme match pro různé typy efektů z vašeho TerrainData.gd
	match terrain.effect_type:
		TerrainData.TerrainEffect.NONE:
			pass # Nic se nestane

		TerrainData.TerrainEffect.APPLY_STATUS_ON_ENTER:
			if unit.has_method("apply_status") and not terrain.effect_string_value.is_empty():
				print("%s vstupuje na '%s' a získává status '%s'." % [unit.unit_data.unit_name, terrain.terrain_name, terrain.effect_string_value])
				unit.apply_status(terrain.effect_string_value, terrain.effect_duration)

		TerrainData.TerrainEffect.MODIFY_DEFENSE_ON_TILE:
			if unit.has_method("add_block"):
				print("%s vstupuje na '%s' a získává %d bloku." % [unit.unit_data.unit_name, terrain.terrain_name, terrain.effect_numeric_value])
				unit.add_block(terrain.effect_numeric_value)

		# Zde můžete v budoucnu přidat další case pro MODIFY_ATTACK_ON_TILE atd.
		_:
			pass


func _generate_grid_from_shape():
	var all_shapes = [SHAPE_DEFAULT, SHAPE_CROSS, SHAPE_DIAMOND]
	var selected_shape = all_shapes.pick_random()
	
	# ZAVOLÁME NOVOU FUNKCI Z BATTLEGRID
	battle_grid_instance.build_from_shape(selected_shape)
