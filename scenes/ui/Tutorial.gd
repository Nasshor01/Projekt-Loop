extends "res://scenes/battle/BattleScene.gd"

const PALADIN_SUBCLASS = preload("res://data/classes/Paladin.tres")
const TRAINING_DUMMY_DATA = preload("res://data/units/training_dummy.tres")
const QUICK_STRIKE_CARD = preload("res://data/cards/everyone/quick_strike.tres")
const DEFEND_CARD = preload("res://data/cards/everyone/defend.tres")
const QUICK_STEP_CARD = preload("res://data/cards/everyone/quick_step.tres")
const LESSER_HEAL_CARD = preload("res://data/cards/paladin/lesser_heal.tres")
const HEAVY_STRIKE_CARD = preload("res://data/cards/everyone/heavy_strike.tres")
const ROCK_TERRAIN = preload("res://data/terrain/rock.tres")
const MUD_TERRAIN = preload("res://data/terrain/mud.tres")
const EnemyAIBaseClass = preload("res://scripts/ai/EnemyAIBase.gd")
const TutorialSpeechClass = preload("res://scenes/ui/TutorialSpeech.gd")

@onready var tutorial_hint_label: Label = $CanvasLayer/TutorialHintLabel
@onready var complete_button: Button = $CanvasLayer/CompleteTutorialButton

enum TutorialStage {
	PLACEMENT,
	CAMERA,
	TERRAIN,
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
var _speech = null
var _terrain_placed := false
var _terrain_pulse_on := false
var _nudge_timer: Timer = null
var _player_spawn_pos := Vector2i(2, 5)
var _dummy_spawn_pos := Vector2i(6, 5)
var _rock_cell := Vector2i(5, 3)
var _mud_cell := Vector2i(3, 7)

func _ready():
	if has_node("/root/GameManager"):
		GameManager.tutorial_active = true
		if GameManager.tutorial_step.is_empty():
			GameManager.tutorial_step = GameManager.TUTORIAL_STEP_BATTLE_1
	_setup_player_data()
	starting_hand_size = 0
	super._ready()
	
	if is_instance_valid(win_button):
		win_button.hide()
	
	if is_instance_valid(complete_button):
		complete_button.visible = false
		complete_button.disabled = true
		complete_button.text = tr("ui.tutorial.complete")
	
	if is_instance_valid(tutorial_hint_label):
		tutorial_hint_label.visible = false
	
	_speech = TutorialSpeechClass.mount($CanvasLayer)
	if is_instance_valid(_speech) and not _speech.continue_pressed.is_connected(_on_speech_continue):
		_speech.continue_pressed.connect(_on_speech_continue)
	
	_nudge_timer = Timer.new()
	_nudge_timer.one_shot = true
	_nudge_timer.wait_time = 18.0
	_nudge_timer.timeout.connect(_on_nudge_timeout)
	add_child(_nudge_timer)
	
	_refresh_coach()

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
	_current_battle_state = BattleState.AWAITING_PLAYER_SPAWN
	_ensure_dummy_and_terrain()
	var player_pos = _get_safe_player_spawn_pos()
	battle_grid_instance.show_player_spawn_points([player_pos])
	battle_grid_instance.start_spawn_pulse()
	end_turn_button.disabled = true
	_refresh_coach()

func confirm_player_spawn(at_position: Vector2i):
	battle_grid_instance.hide_player_spawn_points()
	spawn_player_unit_at(at_position)
	_ensure_dummy_and_terrain()
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_combat_start()
		call_deferred("_resync_artifact_grid_visuals")
	var all_units: Array[Unit] = []
	if is_instance_valid(_player_unit_node):
		all_units.append(_player_unit_node)
	all_units.append_array(_enemy_units)
	var valid_units = all_units.filter(func(u): return is_instance_valid(u))
	_set_stage(TutorialStage.CAMERA)
	call_deferred("_start_combat_with_turn_manager", valid_units)

func spawn_enemy_units():
	if is_instance_valid(_dummy_unit):
		return
	_dummy_unit = null
	var spawn_pos = _get_safe_dummy_spawn_pos()
	var dummy_node = _spawn_unit(TRAINING_DUMMY_DATA, spawn_pos)
	if is_instance_valid(dummy_node):
		_dummy_unit = dummy_node
		_dummy_unit.unit_data.attack_damage = 10
		_dummy_unit.unit_data.max_health = 4
		_dummy_unit.current_health = 4
		_dummy_unit.unit_data.movement_range = 3
		_dummy_unit.unit_data.attack_range = 1
		if not _enemy_units.has(dummy_node):
			_enemy_units.append(dummy_node)
		if not dummy_node.died.is_connected(_on_unit_died):
			dummy_node.died.connect(_on_unit_died)
		if not dummy_node.stats_changed.is_connected(_on_unit_stats_changed):
			dummy_node.stats_changed.connect(_on_unit_stats_changed)

func _generate_grid_from_shape():
	battle_grid_instance.build_from_shape(SHAPE_DEFAULT)

func _place_terrain_features():
	if _terrain_placed or not is_instance_valid(battle_grid_instance):
		return
	var occupied: Array[Vector2i] = []
	if is_instance_valid(_player_unit_node):
		occupied.append(_player_unit_node.grid_position)
	if is_instance_valid(_dummy_unit):
		occupied.append(_dummy_unit.grid_position)
	occupied.append(_get_safe_player_spawn_pos())
	
	var rock_pos := _pick_free_cell(_rock_cell, occupied)
	if rock_pos != Vector2i(-1, -1):
		battle_grid_instance.place_terrain(rock_pos, ROCK_TERRAIN)
		_rock_cell = rock_pos
		occupied.append(rock_pos)
	
	var mud_pos := _pick_free_cell(_mud_cell, occupied)
	if mud_pos != Vector2i(-1, -1):
		battle_grid_instance.place_terrain(mud_pos, MUD_TERRAIN)
		_mud_cell = mud_pos
	_terrain_placed = true

func _ensure_dummy_and_terrain() -> void:
	spawn_enemy_units()
	_place_terrain_features()

func _pick_free_cell(preferred: Vector2i, occupied: Array[Vector2i]) -> Vector2i:
	if battle_grid_instance.is_cell_active(preferred) and not occupied.has(preferred) \
			and battle_grid_instance.get_object_on_cell(preferred) == null:
		return preferred
	for cell in battle_grid_instance._active_cells.keys():
		if occupied.has(cell):
			continue
		if battle_grid_instance.get_object_on_cell(cell) != null:
			continue
		return cell
	return Vector2i(-1, -1)

func _start_player_initiative_turn(_player_unit: Unit, _extra_draw: int = 0):
	_current_battle_state = BattleState.PROCESSING
	end_turn_button.disabled = true
	_cards_played_this_turn.clear()
	PlayerData.max_energy = 3
	PlayerData.reset_energy()
	PlayerData.current_energy = 3
	
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_turn_start()
	
	if _tutorial_stage == TutorialStage.ENEMY_ATTACK:
		_set_stage(TutorialStage.HEAL_AND_STRIKE)
	
	_apply_stage_hand()
	_set_enemy_intents_visible(true)
	set_enemy_intents()
	if _tutorial_stage == TutorialStage.INTENT_FOCUS:
		_show_dummy_attack_intent()
	
	_current_battle_state = BattleState.PLAYER_TURN
	end_turn_button.disabled = not _end_turn_allowed()
	
	if _tutorial_stage == TutorialStage.MOVE_PROMPT:
		_highlight_player_unit(true)
	elif _tutorial_stage == TutorialStage.END_TURN_PROMPT or _tutorial_stage == TutorialStage.BLOCK_END_TURN:
		_highlight_end_turn(true)
	elif _tutorial_stage == TutorialStage.INTENT_FOCUS:
		_focus_camera_on_dummy()
		_highlight_intent_icon(true)
	elif _tutorial_stage == TutorialStage.HEAL_AND_STRIKE:
		_refresh_coach()
	
	_restart_nudge()

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
		TutorialStage.BLOCK_CARD:
			_set_fixed_hand([DEFEND_CARD], [DEFEND_CARD])
		TutorialStage.HEAL_AND_STRIKE:
			_set_fixed_hand([LESSER_HEAL_CARD, QUICK_STRIKE_CARD], [LESSER_HEAL_CARD, QUICK_STRIKE_CARD])
		_:
			_set_fixed_hand([], [])

func _cards_playable() -> bool:
	return _tutorial_stage == TutorialStage.BLOCK_CARD or _tutorial_stage == TutorialStage.HEAL_AND_STRIKE

func _end_turn_allowed() -> bool:
	return _tutorial_stage == TutorialStage.END_TURN_PROMPT or _tutorial_stage == TutorialStage.BLOCK_END_TURN

func _on_player_hand_card_clicked(card_ui_node: Control, card_data_resource: CardData):
	if not _cards_playable():
		_bark_not_yet()
		return
	super._on_player_hand_card_clicked(card_ui_node, card_data_resource)

func _on_player_hand_card_drag_started(card_ui_node: Control, card_data_resource: CardData):
	if not _cards_playable():
		player_hand_ui_instance.cancel_drag_ui()
		_bark_not_yet()
		return
	super._on_player_hand_card_drag_started(card_ui_node, card_data_resource)

func try_play_card(card: CardData, initial_target: Node3D, target_cell: Vector2i = Vector2i(-999, -999)) -> void:
	if not _cards_playable():
		return
	
	if not _is_card_target_in_range(card, initial_target):
		_dummy_bark(DialogueCatalog.body("tutorial.bark.out_of_range"))
		return
	
	if _tutorial_stage == TutorialStage.BLOCK_CARD and card != DEFEND_CARD:
		return
	if _tutorial_stage == TutorialStage.HEAL_AND_STRIKE and card != LESSER_HEAL_CARD and card != QUICK_STRIKE_CARD:
		return
	
	super.try_play_card(card, initial_target, target_cell)
	
	if _tutorial_stage == TutorialStage.BLOCK_CARD and card == DEFEND_CARD:
		_set_stage(TutorialStage.BLOCK_END_TURN)

func _on_combat_ended(player_won: bool):
	_current_battle_state = BattleState.BATTLE_OVER
	if is_instance_valid(end_turn_button):
		end_turn_button.disabled = true
	if not player_won:
		return
	if is_instance_valid(victory_label):
		victory_label.visible = true
	await get_tree().create_timer(1.8).timeout
	_go_to_tutorial_reward()

func _on_unit_died(unit_node: Unit):
	if unit_node == _dummy_unit:
		_dummy_unit = null
	await super._on_unit_died(unit_node)

func _execute_move(unit_to_move: Unit, target_cell: Vector2i):
	super._execute_move(unit_to_move, target_cell)
	if unit_to_move == _player_unit_node and _tutorial_stage == TutorialStage.MOVE_PROMPT:
		_highlight_player_unit(false)
		_set_stage(TutorialStage.END_TURN_PROMPT)

func _on_unit_selected_on_grid(unit_node: Unit):
	if _tutorial_stage != TutorialStage.MOVE_PROMPT:
		return
	super._on_unit_selected_on_grid(unit_node)

func _refresh_enemy_info_hover(unit_under_mouse: Node, show_range: bool) -> void:
	if is_instance_valid(unit_under_mouse) and unit_under_mouse == _dummy_unit:
		if unit_under_mouse.get_unit_data().faction == UnitData.Faction.ENEMY:
			enemy_info_panel.update_stats(unit_under_mouse)
		return
	super._refresh_enemy_info_hover(unit_under_mouse, show_range)

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
	
	if is_instance_valid(_player_unit_node) and is_instance_valid(enemy_unit):
		var distance = battle_grid_instance.get_distance(enemy_unit.grid_position, _player_unit_node.grid_position)
		if _tutorial_stage == TutorialStage.END_TURN_PROMPT:
			if distance > 1:
				await _move_dummy_adjacent(enemy_unit, _player_unit_node.grid_position)
			_show_dummy_attack_intent()
			_set_stage(TutorialStage.INTENT_FOCUS)
		elif _tutorial_stage == TutorialStage.BLOCK_END_TURN:
			if distance > 1:
				await _move_dummy_adjacent(enemy_unit, _player_unit_node.grid_position)
			_set_stage(TutorialStage.ENEMY_ATTACK)
			await get_tree().create_timer(0.4).timeout
			if is_instance_valid(enemy_unit) and is_instance_valid(_player_unit_node):
				await enemy_unit.attack(_player_unit_node, 0, 0, false)
	
	if is_instance_valid(enemy_unit) and enemy_unit.current_health > 0:
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
			await dummy_unit.process_terrain_effects(terrain_on_cell)
			if terrain_on_cell.consume_on_trigger:
				battle_grid_instance.remove_terrain(target_cell)
		
		await get_tree().create_timer(0.08).timeout

func _move_dummy_adjacent(dummy_unit: Unit, _player_pos: Vector2i):
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
		await dummy_unit.process_terrain_effects(terrain_on_cell)
		if terrain_on_cell.consume_on_trigger:
			battle_grid_instance.remove_terrain(target_cell)

func _go_to_tutorial_reward():
	if _tutorial_stage == TutorialStage.REWARD:
		return
	_tutorial_stage = TutorialStage.REWARD
	_refresh_coach()
	
	GameManager.last_battle_rewards = {
		"gold": 0,
		"cards": [HEAVY_STRIKE_CARD],
		"artifacts": [],
		"tutorial_line_id": "tutorial.reward"
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
	
	if battle_grid_instance.is_cell_active(_dummy_spawn_pos) \
			and battle_grid_instance.get_object_on_cell(_dummy_spawn_pos) == null \
			and _dummy_spawn_pos != player_pos:
		return _dummy_spawn_pos
	
	var min_distance = QUICK_STRIKE_CARD.range_value + 2
	var max_distance = 4
	for cell in battle_grid_instance._active_cells.keys():
		if cell.x >= battle_grid_instance.grid_columns / 2.0 \
				and battle_grid_instance.get_object_on_cell(cell) == null \
				and battle_grid_instance.get_distance(player_pos, cell) >= min_distance \
				and battle_grid_instance.get_distance(player_pos, cell) <= max_distance:
			return cell
	
	return Vector2i(battle_grid_instance.grid_columns - 2, int(battle_grid_instance.grid_rows / 2))

func _on_end_turn_button_pressed():
	if not _end_turn_allowed():
		_bark_not_yet()
		return
	_highlight_end_turn(false)
	super._on_end_turn_button_pressed()

func _on_speech_continue() -> void:
	if _current_battle_state == BattleState.PROCESSING:
		await get_tree().process_frame
	match _tutorial_stage:
		TutorialStage.CAMERA:
			_set_stage(TutorialStage.TERRAIN)
		TutorialStage.TERRAIN:
			if is_instance_valid(battle_grid_instance):
				battle_grid_instance.hide_player_spawn_points()
			_set_stage(TutorialStage.MOVE_PROMPT)
		TutorialStage.INTENT_FOCUS:
			_highlight_intent_icon(false)
			_set_stage(TutorialStage.BLOCK_CARD)

func _set_stage(next_stage: TutorialStage) -> void:
	if _tutorial_stage == next_stage and next_stage != TutorialStage.PLACEMENT:
		_refresh_coach()
		return
	_tutorial_stage = next_stage
	if is_instance_valid(end_turn_button):
		end_turn_button.disabled = not _end_turn_allowed()
	if next_stage == TutorialStage.MOVE_PROMPT:
		_highlight_player_unit(true)
	elif next_stage == TutorialStage.END_TURN_PROMPT or next_stage == TutorialStage.BLOCK_END_TURN:
		_highlight_end_turn(true)
	elif next_stage == TutorialStage.TERRAIN:
		_highlight_terrain_tiles(true)
	elif next_stage == TutorialStage.INTENT_FOCUS:
		_focus_camera_on_dummy()
		_show_dummy_attack_intent()
		_highlight_intent_icon(true)
	elif next_stage == TutorialStage.BLOCK_CARD or next_stage == TutorialStage.HEAL_AND_STRIKE:
		_apply_stage_hand()
	_refresh_coach()
	_restart_nudge()

func _refresh_coach() -> void:
	if is_instance_valid(tutorial_hint_label):
		tutorial_hint_label.visible = false
	if not is_instance_valid(_speech):
		_speech = TutorialSpeechClass.mount($CanvasLayer)
		if is_instance_valid(_speech) and not _speech.continue_pressed.is_connected(_on_speech_continue):
			_speech.continue_pressed.connect(_on_speech_continue)
	if not is_instance_valid(_speech):
		return
	
	match _tutorial_stage:
		TutorialStage.PLACEMENT:
			_speech.show_catalog_action("tutorial.placement")
		TutorialStage.CAMERA:
			_speech.show_catalog_continue("tutorial.camera")
		TutorialStage.TERRAIN:
			_speech.show_catalog_continue("tutorial.terrain")
		TutorialStage.MOVE_PROMPT:
			_speech.show_catalog_action("tutorial.move")
		TutorialStage.END_TURN_PROMPT:
			_speech.show_catalog_action("tutorial.end_turn")
		TutorialStage.INTENT_FOCUS:
			_speech.show_catalog_continue("tutorial.intent")
		TutorialStage.BLOCK_CARD:
			_speech.show_catalog_action("tutorial.block")
		TutorialStage.BLOCK_END_TURN:
			_speech.show_catalog_action("tutorial.armor")
		TutorialStage.ENEMY_ATTACK:
			_speech.show_catalog_action("tutorial.attack_incoming")
		TutorialStage.HEAL_AND_STRIKE:
			_speech.show_catalog_action("tutorial.heal_strike")
		TutorialStage.REWARD:
			_speech.show_catalog_action("tutorial.reward")

func _highlight_terrain_tiles(enable: bool) -> void:
	if not is_instance_valid(battle_grid_instance):
		return
	if enable:
		var cells: Array[Vector2i] = []
		if battle_grid_instance.is_cell_active(_rock_cell):
			cells.append(_rock_cell)
		if battle_grid_instance.is_cell_active(_mud_cell):
			cells.append(_mud_cell)
		if not cells.is_empty():
			battle_grid_instance.show_player_spawn_points(cells)
			if not _terrain_pulse_on:
				battle_grid_instance.start_spawn_pulse()
				_terrain_pulse_on = true
	else:
		_terrain_pulse_on = false
		battle_grid_instance.hide_player_spawn_points()

func _restart_nudge() -> void:
	if is_instance_valid(_nudge_timer):
		_nudge_timer.start()

func _on_nudge_timeout() -> void:
	if _tutorial_stage == TutorialStage.REWARD:
		return
	_dummy_bark(DialogueCatalog.body("tutorial.bark.nudge"))
	match _tutorial_stage:
		TutorialStage.MOVE_PROMPT:
			_highlight_player_unit(true)
		TutorialStage.END_TURN_PROMPT, TutorialStage.BLOCK_END_TURN:
			_highlight_end_turn(true)
		TutorialStage.BLOCK_CARD, TutorialStage.HEAL_AND_STRIKE:
			_apply_stage_hand()
		TutorialStage.INTENT_FOCUS:
			_show_dummy_attack_intent()
			_highlight_intent_icon(true)
		TutorialStage.TERRAIN:
			_highlight_terrain_tiles(true)
	_restart_nudge()

func _bark_not_yet() -> void:
	_dummy_bark(DialogueCatalog.body("tutorial.bark.not_yet"))

func _dummy_bark(text: String) -> void:
	if is_instance_valid(_speech) and _speech.has_method("flash_bark"):
		_speech.flash_bark(text)
		return
	if is_instance_valid(_dummy_unit) and _dummy_unit.has_method("show_status_text"):
		_dummy_unit.show_status_text(text, "block_gain")

func _show_dummy_attack_intent() -> void:
	if not is_instance_valid(_dummy_unit):
		return
	var damage := 10
	if is_instance_valid(_dummy_unit.unit_data):
		damage = _dummy_unit.unit_data.attack_damage
	if _dummy_unit.has_method("force_show_attack_intent"):
		_dummy_unit.force_show_attack_intent(damage)
	else:
		_dummy_unit.set_intent_visibility_allowed(true)
		_dummy_unit.update_intent(_player_unit_node, battle_grid_instance)
		_dummy_unit.show_intent(damage)

func _kill_pulse_tween(node: Node) -> void:
	if not is_instance_valid(node) or not node.has_meta("tutorial_pulse"):
		return
	var old_tween: Tween = node.get_meta("tutorial_pulse")
	if is_instance_valid(old_tween):
		old_tween.kill()
	node.remove_meta("tutorial_pulse")

func _highlight_player_unit(enable: bool):
	if not is_instance_valid(_player_unit_node):
		return
	_player_unit_node.set_selected_visual(enable)

func _highlight_end_turn(enable: bool):
	if not is_instance_valid(end_turn_button):
		return
	_kill_pulse_tween(end_turn_button)
	if enable:
		var tween = create_tween().set_loops(12).set_trans(Tween.TRANS_SINE)
		tween.tween_property(end_turn_button, "scale", Vector2(1.08, 1.08), 0.4)
		tween.tween_property(end_turn_button, "scale", Vector2(1.0, 1.0), 0.4)
		end_turn_button.set_meta("tutorial_pulse", tween)
	else:
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
	_kill_pulse_tween(intent_ui)
	if enable:
		# Modulate only — IntentIcon already loops a bob tween on offset/scale.
		var tween = create_tween().set_loops(12).set_trans(Tween.TRANS_SINE)
		tween.tween_property(intent_ui, "modulate", Color(1.35, 1.25, 0.75, 1.0), 0.4)
		tween.tween_property(intent_ui, "modulate", Color.WHITE, 0.4)
		intent_ui.set_meta("tutorial_pulse", tween)
	else:
		intent_ui.modulate = Color.WHITE
