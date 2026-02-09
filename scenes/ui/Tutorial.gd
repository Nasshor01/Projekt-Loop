extends "res://scenes/battle/BattleScene.gd"

const PALADIN_SUBCLASS = preload("res://data/classes/Paladin.tres")
const TRAINING_DUMMY_DATA = preload("res://data/units/training_dummy.tres")
const QUICK_STRIKE_CARD = preload("res://data/cards/everyone/quick_strike.tres")
const DEFEND_CARD = preload("res://data/cards/everyone/defend.tres")
const QUICK_STEP_CARD = preload("res://data/cards/everyone/quick_step.tres")
const LESSER_HEAL_CARD = preload("res://data/cards/paladin/lesser_heal.tres")
const HEAVY_STRIKE_CARD = preload("res://data/cards/everyone/heavy_strike.tres")
const EnemyAIBaseClass = preload("res://scripts/ai/EnemyAIBase.gd")

@onready var tutorial_hint_label: Label = $CanvasLayer/TutorialHintLabel
@onready var complete_button: Button = $CanvasLayer/CompleteTutorialButton

enum TutorialStage {
	PLACEMENT,
	CAMERA,
	MOVE_PROMPT,
	END_TURN_PROMPT,
	INTENT_FOCUS,
	BLOCK_CARD,
	BLOCK_END_TURN,
	ENEMY_ATTACK,
	HEAL_AND_STRIKE,
	REWARD
}
var _tutorial_stage: TutorialStage = TutorialStage.PLACEMENT

var _dummy_unit: Unit = null
var _player_spawn_pos := Vector2i(2, 5)
var _dummy_spawn_pos := Vector2i(12, 5)

func _ready():
	_setup_player_data()
	starting_hand_size = 0
	super._ready()
	
	if is_instance_valid(win_button):
		win_button.hide()
	
	if is_instance_valid(complete_button):
		complete_button.visible = false
		complete_button.disabled = true
		complete_button.text = tr("ui.tutorial.complete")
	
	_update_tutorial_hint()

func _setup_player_data():
	var paladin_subclass: SubclassData = PALADIN_SUBCLASS
	PlayerData.selected_subclass = paladin_subclass
	PlayerData.selected_class = paladin_subclass.parent_class
	
	PlayerData.max_energy = 3
	PlayerData.current_energy = 3
	PlayerData.max_hp = 50
	PlayerData.current_hp = 50
	PlayerData.global_shield = 0
	PlayerData.starting_retained_block = 0
	
	PlayerData.master_deck.clear()
	PlayerData.master_deck.append_array([QUICK_STRIKE_CARD, DEFEND_CARD, QUICK_STEP_CARD])

func start_player_spawn_selection():
	_tutorial_stage = TutorialStage.PLACEMENT
	_update_tutorial_hint()
	_current_battle_state = BattleState.AWAITING_PLAYER_SPAWN
	var player_pos = _get_safe_player_spawn_pos()
	battle_grid_instance.show_player_spawn_points([player_pos])
	battle_grid_instance.start_spawn_pulse()
	end_turn_button.disabled = true

func confirm_player_spawn(at_position: Vector2i):
	super.confirm_player_spawn(at_position)
	_tutorial_stage = TutorialStage.CAMERA
	_update_tutorial_hint()

func spawn_enemy_units():
	_dummy_unit = null
	var spawn_pos = _get_safe_dummy_spawn_pos()
	var dummy_node = _spawn_unit(TRAINING_DUMMY_DATA, spawn_pos)
	if is_instance_valid(dummy_node):
		_dummy_unit = dummy_node
		_dummy_unit.unit_data.attack_damage = 10
		_dummy_unit.unit_data.max_health = 4
		_dummy_unit.current_health = 4
		_enemy_units.append(dummy_node)
		dummy_node.died.connect(_on_unit_died)
		dummy_node.stats_changed.connect(_on_unit_stats_changed)

func _generate_grid_from_shape():
	battle_grid_instance.build_from_shape(SHAPE_DEFAULT)

func _place_terrain_features():
	return

func _start_player_initiative_turn(_player_unit: Unit, _extra_draw: int = 0):
	_current_battle_state = BattleState.PROCESSING
	end_turn_button.disabled = true
	_cards_played_this_turn.clear()
	PlayerData.max_energy = 3
	PlayerData.reset_energy()
	PlayerData.current_energy = 3
	
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_turn_start()
	
	_apply_stage_hand()
	set_enemy_intents()
	
	_current_battle_state = BattleState.PLAYER_TURN
	end_turn_button.disabled = false
	
	if _tutorial_stage == TutorialStage.MOVE_PROMPT:
		_highlight_player_unit(true)
	elif _tutorial_stage == TutorialStage.END_TURN_PROMPT or _tutorial_stage == TutorialStage.BLOCK_END_TURN:
		_highlight_end_turn(true)
	elif _tutorial_stage == TutorialStage.ENEMY_ATTACK:
		_tutorial_stage = TutorialStage.HEAL_AND_STRIKE
		_update_tutorial_hint()
		_apply_stage_hand()
	elif _tutorial_stage == TutorialStage.INTENT_FOCUS:
		_focus_camera_on_dummy()
		_highlight_intent_icon(true)
		await get_tree().create_timer(0.8).timeout
		_highlight_intent_icon(false)
		_tutorial_stage = TutorialStage.BLOCK_CARD
		_update_tutorial_hint()
		_apply_stage_hand()
	elif _tutorial_stage == TutorialStage.HEAL_AND_STRIKE:
		_update_tutorial_hint()

func _set_fixed_hand(cards: Array[CardData], allowed_cards: Array[CardData]):
	PlayerData.current_hand.clear()
	PlayerData.draw_pile.clear()
	PlayerData.discard_pile.clear()
	PlayerData.exhaust_pile.clear()
	
	if is_instance_valid(player_hand_ui_instance):
		player_hand_ui_instance.clear_hand()
	
	for card in cards:
		PlayerData.current_hand.append(card)
		if is_instance_valid(player_hand_ui_instance):
			player_hand_ui_instance.add_card_to_hand(card)
			var card_ui = player_hand_ui_instance.get_child(player_hand_ui_instance.get_child_count() - 1)
			if card_ui is CardUI:
				var is_allowed = allowed_cards.has(card)
				card_ui.is_draggable = is_allowed
				card_ui.mouse_filter = Control.MOUSE_FILTER_STOP if is_allowed else Control.MOUSE_FILTER_IGNORE
	
	if is_instance_valid(player_hand_ui_instance):
		player_hand_ui_instance._request_arrange()
	_update_pile_counts()

func _apply_stage_hand():
	match _tutorial_stage:
		TutorialStage.MOVE_PROMPT, TutorialStage.END_TURN_PROMPT, TutorialStage.INTENT_FOCUS, TutorialStage.BLOCK_END_TURN, TutorialStage.ENEMY_ATTACK:
			_set_fixed_hand([], [])
		TutorialStage.BLOCK_CARD:
			_set_fixed_hand([DEFEND_CARD], [DEFEND_CARD])
		TutorialStage.HEAL_AND_STRIKE:
			_set_fixed_hand([LESSER_HEAL_CARD, QUICK_STRIKE_CARD], [LESSER_HEAL_CARD, QUICK_STRIKE_CARD])
		_:
			_set_fixed_hand([], [])

func _on_player_hand_card_clicked(card_ui_node: Control, card_data_resource: CardData):
	if _tutorial_stage != TutorialStage.BLOCK_CARD and _tutorial_stage != TutorialStage.HEAL_AND_STRIKE:
		return
	super._on_player_hand_card_clicked(card_ui_node, card_data_resource)

func _on_player_hand_card_drag_started(card_ui_node: Control, card_data_resource: CardData):
	if _tutorial_stage != TutorialStage.BLOCK_CARD and _tutorial_stage != TutorialStage.HEAL_AND_STRIKE:
		player_hand_ui_instance.cancel_drag_ui()
		return
	super._on_player_hand_card_drag_started(card_ui_node, card_data_resource)

func try_play_card(card: CardData, initial_target: Node3D) -> void:
	if _tutorial_stage != TutorialStage.BLOCK_CARD and _tutorial_stage != TutorialStage.HEAL_AND_STRIKE:
		return
	
	if not _is_card_target_in_range(card, initial_target):
		return
	
	if _tutorial_stage == TutorialStage.BLOCK_CARD and card != DEFEND_CARD:
		return
	if _tutorial_stage == TutorialStage.HEAL_AND_STRIKE and card != LESSER_HEAL_CARD and card != QUICK_STRIKE_CARD:
		return
	
	super.try_play_card(card, initial_target)
	
	if _tutorial_stage == TutorialStage.BLOCK_CARD and card == DEFEND_CARD:
		_tutorial_stage = TutorialStage.BLOCK_END_TURN
		_update_tutorial_hint()
		_highlight_end_turn(true)

func _on_combat_ended(_player_won: bool):
	_current_battle_state = BattleState.BATTLE_OVER
	if _player_won:
		_go_to_tutorial_reward()

func _on_unit_died(unit_node: Unit):
	var was_dummy = unit_node == _dummy_unit
	await super._on_unit_died(unit_node)
	if was_dummy:
		_dummy_unit = null
		_go_to_tutorial_reward()

func _update_tutorial_hint():
	if not is_instance_valid(tutorial_hint_label):
		return
	
	match _tutorial_stage:
		TutorialStage.PLACEMENT:
			tutorial_hint_label.text = tr("ui.tutorial.placement_hint")
		TutorialStage.CAMERA:
			tutorial_hint_label.text = tr("ui.tutorial.camera_hint")
		TutorialStage.MOVE_PROMPT:
			tutorial_hint_label.text = tr("ui.tutorial.move_prompt")
		TutorialStage.END_TURN_PROMPT:
			tutorial_hint_label.text = tr("ui.tutorial.end_turn_prompt")
		TutorialStage.INTENT_FOCUS:
			tutorial_hint_label.text = tr("ui.tutorial.intent_focus")
		TutorialStage.BLOCK_CARD:
			tutorial_hint_label.text = tr("ui.tutorial.block_card_prompt")
		TutorialStage.BLOCK_END_TURN:
			tutorial_hint_label.text = tr("ui.tutorial.end_turn_after_block")
		TutorialStage.ENEMY_ATTACK:
			tutorial_hint_label.text = tr("ui.tutorial.enemy_attack_hint")
		TutorialStage.HEAL_AND_STRIKE:
			tutorial_hint_label.text = tr("ui.tutorial.heal_and_strike")
		TutorialStage.REWARD:
			tutorial_hint_label.text = tr("ui.tutorial.reward_hint")

func _execute_move(unit_to_move: Unit, target_cell: Vector2i):
	super._execute_move(unit_to_move, target_cell)
	if unit_to_move == _player_unit_node and _tutorial_stage == TutorialStage.MOVE_PROMPT:
		_highlight_player_unit(false)
		_tutorial_stage = TutorialStage.END_TURN_PROMPT
		_update_tutorial_hint()
		_highlight_end_turn(true)

func _on_unit_selected_on_grid(unit_node: Unit):
	if _tutorial_stage != TutorialStage.MOVE_PROMPT:
		return
	super._on_unit_selected_on_grid(unit_node)

func _unhandled_input(event: InputEvent):
	super._unhandled_input(event)
	if _tutorial_stage != TutorialStage.CAMERA:
		return
	
	var did_camera_action = false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			did_camera_action = true
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			did_camera_action = true
	elif event is InputEventKey:
		if event.pressed and (event.keycode == KEY_W or event.keycode == KEY_A or event.keycode == KEY_S or event.keycode == KEY_D or event.keycode == KEY_Q or event.keycode == KEY_E):
			did_camera_action = true
	
	if did_camera_action:
		_tutorial_stage = TutorialStage.MOVE_PROMPT
		_update_tutorial_hint()

func _is_card_target_in_range(card: CardData, target: Node3D) -> bool:
	if not is_instance_valid(card) or not is_instance_valid(target):
		return false
	if not target is Unit:
		return false
	
	var requires_enemy = card.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELECTED_ENEMY_UNIT)
	if requires_enemy and target.unit_data.faction != UnitData.Faction.ENEMY:
		return false
	
	if card.range_value <= 0:
		return true
	
	if is_instance_valid(_player_unit_node) and is_instance_valid(battle_grid_instance):
		var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, target.grid_position)
		return distance <= card.range_value
	
	return false

func _start_enemy_initiative_turn(enemy_unit: Unit):
	if enemy_unit != _dummy_unit:
		super._start_enemy_initiative_turn(enemy_unit)
		return
	
	_current_battle_state = BattleState.ENEMY_TURN
	end_turn_button.disabled = true
	
	battle_grid_instance.hide_danger_zone()
	enemy_unit.hide_intent()
	
	await get_tree().create_timer(0.3).timeout
	
	if is_instance_valid(_player_unit_node):
		var distance = battle_grid_instance.get_distance(enemy_unit.grid_position, _player_unit_node.grid_position)
		if _tutorial_stage == TutorialStage.END_TURN_PROMPT:
			if distance > 1:
				_move_dummy_adjacent(enemy_unit, _player_unit_node.grid_position)
			_tutorial_stage = TutorialStage.INTENT_FOCUS
		elif _tutorial_stage == TutorialStage.BLOCK_END_TURN and distance <= 1:
			_tutorial_stage = TutorialStage.ENEMY_ATTACK
			await get_tree().create_timer(0.4).timeout
			await enemy_unit.attack(_player_unit_node, 1.0)
	
	enemy_unit.end_turn()
	if has_node("/root/TurnManager"):
		TurnManager.next_turn()

func _move_dummy_towards_player(dummy_unit: Unit, player_pos: Vector2i):
	var ai_base = EnemyAIBaseClass.new()
	var path = ai_base.find_path_to_adjacent(dummy_unit, _player_unit_node, battle_grid_instance)
	if path.is_empty():
		return
	
	var max_steps = max(1, dummy_unit.get_current_movement_range())
	var step_index = min(max_steps, path.size() - 1)
	if step_index <= 0:
		return
	
	dummy_unit.use_move_action()
	for i in range(1, step_index + 1):
		var target_cell = path[i]
		if not battle_grid_instance.is_cell_active(target_cell):
			break
		if battle_grid_instance.get_object_on_cell(target_cell) != null:
			break
		
		battle_grid_instance.remove_object_by_instance(dummy_unit)
		battle_grid_instance.place_object_on_cell(dummy_unit, target_cell, true)
		var terrain_on_cell = battle_grid_instance.get_terrain_on_cell(target_cell)
		if is_instance_valid(terrain_on_cell):
			dummy_unit.process_terrain_effects(terrain_on_cell)
		
		await get_tree().create_timer(0.08).timeout

func _move_dummy_adjacent(dummy_unit: Unit, player_pos: Vector2i):
	var ai_base = EnemyAIBaseClass.new()
	var path = ai_base.find_path_to_adjacent(dummy_unit, _player_unit_node, battle_grid_instance)
	if path.is_empty():
		return
	var step_index = path.size() - 1
	dummy_unit.use_move_action()
	var target_cell = path[step_index]
	battle_grid_instance.remove_object_by_instance(dummy_unit)
	battle_grid_instance.place_object_on_cell(dummy_unit, target_cell, true)
	var terrain_on_cell = battle_grid_instance.get_terrain_on_cell(target_cell)
	if is_instance_valid(terrain_on_cell):
		dummy_unit.process_terrain_effects(terrain_on_cell)

func _go_to_tutorial_reward():
	if _tutorial_stage == TutorialStage.REWARD:
		return
	_tutorial_stage = TutorialStage.REWARD
	_update_tutorial_hint()
	
	GameManager.last_battle_rewards = {
		"gold": 0,
		"cards": [HEAVY_STRIKE_CARD],
		"artifacts": [],
		"tutorial_hint_text": tr("ui.tutorial.reward_hint")
	}
	GameManager.tutorial_step = GameManager.TUTORIAL_STEP_REWARD_1
	
	_current_battle_state = BattleState.BATTLE_OVER
	GameManager._change_scene("res://scenes/rewards/RewardScene.tscn")

func _get_safe_player_spawn_pos() -> Vector2i:
	if battle_grid_instance.is_cell_active(_player_spawn_pos) and battle_grid_instance.get_object_on_cell(_player_spawn_pos) == null:
		return _player_spawn_pos
	
	for cell in battle_grid_instance._active_cells.keys():
		if cell.x < battle_grid_instance.grid_columns / 2.0 and battle_grid_instance.get_object_on_cell(cell) == null:
			return cell
	
	return Vector2i(0, 0)

func _get_safe_dummy_spawn_pos() -> Vector2i:
	var player_pos = _player_spawn_pos
	if is_instance_valid(_player_unit_node):
		player_pos = _player_unit_node.grid_position
	
	var min_distance = QUICK_STRIKE_CARD.range_value + 1
	var max_distance = 3
	if is_instance_valid(_player_unit_node):
		max_distance = max(2, min(_player_unit_node.get_current_movement_range(), 3))

	if battle_grid_instance.is_cell_active(_dummy_spawn_pos) \
		and battle_grid_instance.get_object_on_cell(_dummy_spawn_pos) == null \
		and battle_grid_instance.get_distance(player_pos, _dummy_spawn_pos) >= min_distance \
		and battle_grid_instance.get_distance(player_pos, _dummy_spawn_pos) <= max_distance:
		return _dummy_spawn_pos
	
	for cell in battle_grid_instance._active_cells.keys():
		if cell.x >= battle_grid_instance.grid_columns / 2.0 \
			and battle_grid_instance.get_object_on_cell(cell) == null \
			and battle_grid_instance.get_distance(player_pos, cell) >= min_distance \
			and battle_grid_instance.get_distance(player_pos, cell) <= max_distance:
			return cell
	
	return Vector2i(battle_grid_instance.grid_columns - 2, int(battle_grid_instance.grid_rows / 2))

func _on_end_turn_button_pressed():
	if _tutorial_stage == TutorialStage.END_TURN_PROMPT or _tutorial_stage == TutorialStage.BLOCK_END_TURN:
		_highlight_end_turn(false)
		super._on_end_turn_button_pressed()
		return

func _highlight_player_unit(enable: bool):
	if not is_instance_valid(_player_unit_node):
		return
	_player_unit_node.set_selected_visual(enable)

func _highlight_end_turn(enable: bool):
	if not is_instance_valid(end_turn_button):
		return
	if enable:
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tween.tween_property(end_turn_button, "scale", Vector2(1.08, 1.08), 0.4)
		tween.tween_property(end_turn_button, "scale", Vector2(1.0, 1.0), 0.4)
		end_turn_button.set_meta("tutorial_pulse", tween)
	else:
		if end_turn_button.has_meta("tutorial_pulse"):
			var old_tween: Tween = end_turn_button.get_meta("tutorial_pulse")
			if is_instance_valid(old_tween):
				old_tween.kill()
			end_turn_button.remove_meta("tutorial_pulse")
		end_turn_button.scale = Vector2.ONE

func _focus_camera_on_dummy():
	if not is_instance_valid(camera_3d) or not is_instance_valid(_dummy_unit):
		return
	var focus_pos = _dummy_unit.global_position + Vector3(0, 1.5, 0)
	_cam_target_pos = focus_pos + Vector3(-3.0, 6.0, 6.0)
	camera_3d.look_at(focus_pos, Vector3.UP)

func _highlight_intent_icon(enable: bool):
	if not is_instance_valid(_dummy_unit):
		return
	if not _dummy_unit.has_method("get_intent_ui"):
		return
	var intent_ui = _dummy_unit.get_intent_ui()
	if not is_instance_valid(intent_ui):
		return
	if enable:
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tween.tween_property(intent_ui, "scale", Vector2(1.15, 1.15), 0.4)
		tween.tween_property(intent_ui, "scale", Vector2(1.0, 1.0), 0.4)
		intent_ui.set_meta("tutorial_pulse", tween)
	else:
		if intent_ui.has_meta("tutorial_pulse"):
			var old_tween: Tween = intent_ui.get_meta("tutorial_pulse")
			if is_instance_valid(old_tween):
				old_tween.kill()
			intent_ui.remove_meta("tutorial_pulse")
		intent_ui.scale = Vector2.ONE
