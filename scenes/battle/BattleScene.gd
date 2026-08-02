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
@onready var card_pile_viewer: PanelContainer = $OverlayLayer/CardPileViewer
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
var _coop_other_player_unit: Unit = null
var _selected_unit: Unit = null
var _enemy_units: Array[Unit] = []
# Coop: stabilní seznam VŠECH nepřátel ve spawnovém pořadí – NIKDY se z něj neodebírá.
# Mrtvé jednotky zůstanou ve svém slotu (is_instance_valid vrátí false po queue_free).
var _all_enemy_units_ordered: Array[Unit] = []

var _is_action_processing: bool = false
var _card_play_in_progress: bool = false  # blokuje druhý vstup do _try_play_selected_card_at_cell (např. dvojí signál)
var _cards_to_draw_queue: int = 0
var _is_drawing_cards: bool = false
var _is_first_turn: bool = true
var _current_turn_number: int = 0
var _is_extra_turn: bool = false
var _cards_played_this_turn: Dictionary = {}  # Tracking karet za tah pro limit použití
var _took_damage_last_turn: bool = false  # Tracking poškození pro consecrated_barrier
var _current_tooltip_card_data: CardData = null
# Coop: true = můj tah, false = tah spoluhráče (pouze když _is_coop_run())
var _coop_my_turn: bool = true
var _coop_spectator_mode: bool = false  # Coop: můj paladin zemřel, jsem divák
# Coop výběr spawnu: 0 = host vybírá, 1 = klient vybírá
var _coop_spawn_phase: int = 0
var _coop_host_spawn_cell: Vector2i = Vector2i(-1, -1)
var _coop_client_spawn_cell: Vector2i = Vector2i(-1, -1)

func _ready():
	add_to_group("battle_scene")
	# Deterministic RNG: stejný seed = stejný grid, pozice nepřátel a terén u hosta i klienta.
	# Používáme path_taken.size() (ne floors_cleared), aby měl klient stejný počet jako host při vstupu do bitvy.
	if has_node("/root/GameManager"):
		var steps = PlayerData.path_taken.size() if PlayerData.path_taken else 0
		var battle_seed = GameManager.current_seed + steps
		seed(battle_seed)
		DebugLogger.log_debug("Battle seed: %d (current_seed %d + path_steps %d)" % [battle_seed, GameManager.current_seed, steps])
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
		if TurnManager.has_signal("initiative_modifiers_changed"):
			TurnManager.initiative_modifiers_changed.connect(_on_initiative_modifiers_changed)
	else:
		printerr("CHYBA: TurnManager není dostupný!")

	PlayerData.reset_battle_stats()
	PlayerData.energy_changed.connect(_on_energy_changed)
	player_hand_ui_instance.hand_card_was_clicked.connect(_on_player_hand_card_clicked)
	player_hand_ui_instance.hand_card_drag_started.connect(_on_player_hand_card_drag_started)
	player_hand_ui_instance.hand_card_drag_released.connect(_on_player_hand_card_drag_released)
	player_hand_ui_instance.hand_card_drag_cancelled.connect(_on_player_hand_card_drag_cancelled)
	player_hand_ui_instance.card_right_clicked.connect(_on_card_right_clicked)
	player_hand_ui_instance.card_hover_exited.connect(_on_card_hover_exited_dismiss_tooltip)
	
	# Tooltip se nyní zobrazuje/schovává pomocí pravého kliknutí - žádné timery nejsou potřeba
	draw_pile_button.pile_clicked.connect(_on_draw_pile_clicked)
	discard_pile_button.pile_clicked.connect(_on_discard_pile_clicked)
	if card_pile_viewer.has_signal("card_right_clicked"):
		card_pile_viewer.card_right_clicked.connect(_on_card_right_clicked)
	if card_pile_viewer.has_signal("card_unhovered"):
		card_pile_viewer.card_unhovered.connect(_on_deck_viewer_card_unhovered)
	if not win_button.pressed.is_connected(_on_win_button_pressed):
		win_button.pressed.connect(_on_win_button_pressed)
	if is_instance_valid(win_button):
		if not OS.is_debug_build():
			win_button.hide()
	
	player_hand_ui_instance.card_draw_animation_finished.connect(_on_card_draw_animation_finished)
	player_hand_ui_instance.hand_discard_animation_finished.connect(_on_hand_discard_animation_finished)
	
	if has_node("/root/ArtifactManager") and not ArtifactManager.extra_turn_requested.is_connected(_on_artifact_extra_turn_requested):
		ArtifactManager.extra_turn_requested.connect(_on_artifact_extra_turn_requested)

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
	# Energie se zobrazuje v PlayerInfoPanelu (Unit Info Panel), samostatný label skryt
	if is_instance_valid(energy_label):
		energy_label.visible = false
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

	# 3. APLIKACE SMOOTH (frame-rate nezávislé – plynulé jako na 60 FPS)
	# 1 - exp(-k*dt) = stejná „dobrá“ plynulost při jakémkoliv FPS
	var t: float = 1.0 - exp(-camera_smoothness * delta)
	camera_3d.position = camera_3d.position.lerp(_cam_target_pos, t)
	var current_rot = camera_3d.rotation
	current_rot.y = lerp_angle(current_rot.y, _cam_target_rot_y, t)
	current_rot.x = lerp_angle(current_rot.x, _cam_target_rot_x, t)
	camera_3d.rotation = current_rot
	camera_3d.size = lerp(camera_3d.size, _cam_target_zoom, t)
	
	# 4. RAYCAST UPDATE PRO HOVER
	var grid_cell = get_grid_cell_under_mouse()
	battle_grid_instance.set_mouse_over_cell(grid_cell)
	
	var unit_under_mouse = battle_grid_instance.get_object_on_cell(grid_cell)
	_refresh_enemy_info_hover(unit_under_mouse, true)
		
	if _player_action_state == PlayerActionState.CARD_SELECTED:
		if _selected_card_data and not PlayerData.current_hand.has(_selected_card_data):
			_reset_player_selection()
		else:
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
	
	if event.is_action_pressed("ui_cancel") and _player_action_state == PlayerActionState.CARD_SELECTED:
		player_hand_ui_instance.cancel_drag_ui()
		_reset_player_selection()
		return

	# KLIKÁNÍ NA MŘÍŽKU (RAYCAST)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_grid_cell = get_grid_cell_under_mouse()
		DebugLogger.log_debug("KLIK! Grid coords: %s" % str(clicked_grid_cell))
		
		# Logika SPAWN
		if _current_battle_state == BattleState.AWAITING_PLAYER_SPAWN:
			if _is_coop_run():
				if battle_grid_instance.is_cell_a_valid_spawn_point(clicked_grid_cell):
					var host_color := Color(1.3, 1.1, 0.75, 0.7)   # zlatá
					var client_color := Color(0.5, 0.7, 1.3, 0.7)  # modrá
					if MultiplayerManager.is_server() and _coop_spawn_phase == 0:
						_coop_host_spawn_cell = clicked_grid_cell
						_coop_spawn_phase = 1
						battle_grid_instance.set_coop_selected_spawn(clicked_grid_cell, host_color)
						rpc("_rpc_coop_host_spawn", clicked_grid_cell.x, clicked_grid_cell.y)
						get_viewport().set_input_as_handled()
					elif not MultiplayerManager.is_server() and _coop_spawn_phase == 1 and clicked_grid_cell != _coop_host_spawn_cell:
						_coop_client_spawn_cell = clicked_grid_cell
						battle_grid_instance.set_coop_selected_spawn(clicked_grid_cell, client_color)
						rpc("_rpc_coop_client_spawn", clicked_grid_cell.x, clicked_grid_cell.y)
						get_viewport().set_input_as_handled()
			elif battle_grid_instance.is_cell_a_valid_spawn_point(clicked_grid_cell):
				confirm_player_spawn(clicked_grid_cell)
				get_viewport().set_input_as_handled()
			return
		
		if _current_battle_state != BattleState.PLAYER_TURN: return

		# Logika KARTY — blokovat dvojí odehrání; hned skrýt highlight a teprve pak odehrát
		if _player_action_state == PlayerActionState.CARD_SELECTED:
			if _card_play_in_progress:
				get_viewport().set_input_as_handled()
				return
			if _selected_card_data and not PlayerData.current_hand.has(_selected_card_data):
				_reset_player_selection()
				get_viewport().set_input_as_handled()
				return
			var card_to_play: CardData = _selected_card_data
			_card_play_in_progress = true
			# Okamžitě zrušit výběr a skrýt targetable highlight — další klik už uvidí IDLE
			_clear_card_selection_state_before_play()
			var did_play = _execute_card_play_at_cell(card_to_play, clicked_grid_cell)
			if not did_play:
				_card_play_in_progress = false
				player_hand_ui_instance.cancel_drag_ui()
			get_viewport().set_input_as_handled()
			
		# Logika POHYB
		elif _player_action_state == PlayerActionState.UNIT_SELECTED:
			if battle_grid_instance.is_cell_movable(clicked_grid_cell):
				_execute_move(_selected_unit, clicked_grid_cell)
			else:
				_reset_player_selection()
			get_viewport().set_input_as_handled()
		
		# Logika VÝBĚR JEDNOTKY (klik na vlastní postavu pro pohyb); klik na nepřítele/prázdno jen zkonzumujeme
		elif _player_action_state == PlayerActionState.IDLE:
			# Coop: pohyb jen když je můj tah
			if _is_coop_run() and not _coop_my_turn:
				get_viewport().set_input_as_handled()
				return
			var unit_clicked = battle_grid_instance.get_object_on_cell(clicked_grid_cell)
			if unit_clicked and unit_clicked is Unit:
				if unit_clicked.unit_data.faction == UnitData.Faction.PLAYER and unit_clicked.can_move():
					# Coop: pohybovat smíme jen svojí jednotkou
					if _is_coop_run() and unit_clicked != _player_unit_node:
						get_viewport().set_input_as_handled()
					else:
						_on_unit_selected_on_grid(unit_clicked)
						get_viewport().set_input_as_handled()
				else:
					# Klik na nepřítele nebo jinou jednotku — jen zkonzumovat, aby se nikde jinde nezpracoval jako „zahrát kartu“
					get_viewport().set_input_as_handled()

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
		if initiative_bar.has_method("advance_to_active"):
			initiative_bar.advance_to_active(unit)

	if not is_instance_valid(unit):
		TurnManager.next_turn()
		return
	
	# Zavolej start_turn na jednotce (může await — např. poison DoT)
	var extra_draw = await unit.start_turn()

	# Jednotka mohla zemřít na poison na začátku tahu
	if not is_instance_valid(unit) or unit.current_health <= 0:
		if has_node("/root/TurnManager"):
			TurnManager.next_turn()
		return
	
	# Rozhodní, zda jde o hráče nebo AI
	if unit.unit_data.faction == UnitData.Faction.PLAYER:
		_start_player_initiative_turn(unit, extra_draw)
	else:
		# Coop: tah nepřítele běží jen na hostovi, klient čeká na RPC se stavem
		if _is_coop_run() and has_node("/root/MultiplayerManager") and not MultiplayerManager.is_server():
			_current_battle_state = BattleState.ENEMY_TURN
			end_turn_button.disabled = true
			battle_grid_instance.hide_danger_zone()
			_set_enemy_intents_visible(false)
			if is_instance_valid(unit):
				unit.hide_intent()
			return
		_start_enemy_initiative_turn(unit)

func _on_initiative_modifiers_changed(_unit: Unit, _total_initiative: int):
	if is_instance_valid(initiative_bar):
		initiative_bar.refresh_initiatives()

func _start_player_initiative_turn(_player_unit: Unit, extra_draw: int = 0):
	"""Zahájí tah hráče v iniciativním systému"""
	# Coop: pokud je tah druhého hráče, jen čekáme – vyčistíme hand, aby nemohl hrát staré karty
	if _is_coop_run() and _player_unit.has_meta("owner_peer_id") and _player_unit.get_meta("owner_peer_id") != multiplayer.get_unique_id():
		_coop_my_turn = false
		_update_turn_display()
		_current_battle_state = BattleState.PLAYER_TURN
		end_turn_button.disabled = true
		PlayerData.discard_hand()
		if is_instance_valid(player_hand_ui_instance):
			player_hand_ui_instance.clear_hand()
		_update_pile_counts()
		return
	_coop_my_turn = true
	_update_turn_display()
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
	
	# Coop: po artefaktech pošli stav své jednotky druhému peerovi,
	# aby host měl správný block (např. Srdce draka) před útoky nepřátel.
	if _is_coop_run() and is_instance_valid(_player_unit_node):
		var my_idx = _coop_get_player_unit_index(_player_unit_node)
		rpc("_rpc_coop_sync_my_unit_state", my_idx, _player_unit_node.current_health, _player_unit_node.current_block)
	
	# Dober karty
	_cards_to_draw_queue = starting_hand_size + extra_draw
	_draw_next_card_in_queue()
	
	# Zobraz AI záměry
	_set_enemy_intents_visible(true)
	set_enemy_intents()

func _start_enemy_initiative_turn(enemy_unit: Unit):
	"""Zahájí tah nepřítele v iniciativním systému"""
	_current_battle_state = BattleState.ENEMY_TURN
	end_turn_button.disabled = true
	
	battle_grid_instance.hide_danger_zone()
	_set_enemy_intents_visible(false)
	if is_instance_valid(enemy_unit):
		enemy_unit.hide_intent()
	
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(enemy_unit) and enemy_unit.current_health > 0:
		await _process_enemy_actions(enemy_unit)
	await get_tree().create_timer(0.4).timeout
	
	# Jednotka mohla zemřít během akce (např. past DAMAGE_ON_ENTER)
	if is_instance_valid(enemy_unit) and enemy_unit.current_health > 0:
		enemy_unit.end_turn()
	
	# Coop: host přepočte intenty a pošle klientovi kompletní stav
	if _is_coop_run() and has_node("/root/MultiplayerManager") and MultiplayerManager.is_server():
		# Přepočítej intenty na hostovi PŘED build snapshotem
		for e in _enemy_units:
			if is_instance_valid(e) and e.has_method("update_intent"):
				e.update_intent(_player_unit_node, battle_grid_instance)
		var payload = _coop_build_battle_state_snapshot()
		var enemy_idx = _all_enemy_units_ordered.find(enemy_unit) if is_instance_valid(enemy_unit) else -1
		payload["enemy_turn_index"] = enemy_idx if enemy_idx >= 0 else 0
		rpc("_rpc_apply_enemy_turn_result", payload)
	
	# Přejdi na další tah
	TurnManager.next_turn()

func _process_enemy_actions(enemy_unit: Unit):
	"""Zpracuje VŠECHNY akce jednoho nepřítele (multi-action systém)"""
	if not is_instance_valid(enemy_unit):
		return
	
	var player_units_array: Array = [_player_unit_node]
	if is_instance_valid(_coop_other_player_unit):
		player_units_array.append(_coop_other_player_unit)
	
	var ai_instance = null
	if is_instance_valid(enemy_unit.unit_data) and is_instance_valid(enemy_unit.unit_data.ai_script):
		ai_instance = enemy_unit.unit_data.ai_script.new()
	else:
		return
	
	# Získáme POLE akcí z nového multi-action systému
	var actions: Array = ai_instance.get_actions(enemy_unit, player_units_array, battle_grid_instance)
	
	# Tracking pro berserker frustraci
	var did_attack_or_rush = false
	
	# Zpracuj každou akci postupně
	for action in actions:
		if not is_instance_valid(enemy_unit):
			break
		
		await _execute_single_action(enemy_unit, action)
		
		if not is_instance_valid(enemy_unit) or enemy_unit.current_health <= 0:
			break
		
		# Track zda útočil
		if action.type == EnemyAIBase.AIAction.ActionType.ATTACK or action.type == EnemyAIBase.AIAction.ActionType.RUSH:
			did_attack_or_rush = true
		
		# Krátká pauza mezi akcemi (pokud jich je víc)
		if actions.size() > 1 and action != actions.back():
			await get_tree().create_timer(0.3).timeout
	
	# ===== LOGIKA POČÍTÁNÍ FRUSTRACE (Berserker) =====
	if is_instance_valid(enemy_unit) and is_instance_valid(enemy_unit.unit_data.ai_script) and "BerserkerAI" in enemy_unit.unit_data.ai_script.resource_path:
		if did_attack_or_rush:
			enemy_unit.berserker_frustration = 0
			DebugLogger.log_debug("[BattleScene] Frustrace resetována (útok proveden).")
		else:
			enemy_unit.berserker_frustration += 1
			DebugLogger.log_debug("[BattleScene] Frustrace zvýšena na: %d (bez útoku)." % enemy_unit.berserker_frustration)

func _execute_single_action(enemy_unit: Unit, action: EnemyAIBase.AIAction):
	"""Provede jednu akci enemy jednotky"""
	if not is_instance_valid(enemy_unit):
		return
	
	match action.type:
		EnemyAIBase.AIAction.ActionType.ATTACK:
			# Ověř, že cíl je stále platný a v dosahu
			if not is_instance_valid(action.target_unit):
				return
			if not can_attack_target(enemy_unit, action.target_unit, battle_grid_instance):
				return
			
			# Tracking poškození pro consecrated_barrier
			if action.target_unit == _player_unit_node:
				_took_damage_last_turn = true
			
			# Elementální poškození (Mage)
			if action.special_data.get("elemental_damage", false):
				var element_type = action.special_data.get("element_type", "fire")
				var extra = _damage_multiplier_to_extra(enemy_unit, action.damage_multiplier)
				await enemy_unit.attack(action.target_unit, extra, CardEffectData.DamageType.NORMAL, false)
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
				var extra = _damage_multiplier_to_extra(enemy_unit, action.damage_multiplier)
				await enemy_unit.attack(action.target_unit, extra, CardEffectData.DamageType.NORMAL, false)
				await get_tree().create_timer(0.3).timeout
				if is_instance_valid(action.target_unit):
					await enemy_unit.attack(action.target_unit, extra, CardEffectData.DamageType.NORMAL, false)
			else:
				var extra = _damage_multiplier_to_extra(enemy_unit, action.damage_multiplier)
				var dmg_type = CardEffectData.DamageType.HOLY if action.special_data.get("holy_damage", false) else CardEffectData.DamageType.NORMAL
				await enemy_unit.attack(action.target_unit, extra, dmg_type, false)
				
				# DarkBeast bleeding efekt po útoku
				if action.special_data.get("apply_bleeding", false):
					if is_instance_valid(action.target_unit) and action.target_unit is Unit:
						var bleed_dmg = action.special_data.get("bleeding_damage", 2)
						var bleed_dur = action.special_data.get("bleeding_duration", 3)
						action.target_unit.apply_status("burning", bleed_dmg, bleed_dur)  # Reuse burning jako bleeding
						action.target_unit.show_status_text("BLEEDING!", "critical")
		
		EnemyAIBase.AIAction.ActionType.SPECIAL:
			await _process_special_action(enemy_unit, action)
		
		EnemyAIBase.AIAction.ActionType.RUSH:
			if enemy_unit.can_move():
				enemy_unit.use_move_action()
				var path = action.move_path
				
				if path.size() > 1:
					await _rush_unit_along_path(enemy_unit, path)
					if not is_instance_valid(enemy_unit) or enemy_unit.current_health <= 0:
						return
					
					if is_instance_valid(action.target_unit) and can_attack_target(enemy_unit, action.target_unit, battle_grid_instance):
						if action.target_unit == _player_unit_node:
							_took_damage_last_turn = true
						var extra = _damage_multiplier_to_extra(enemy_unit, action.damage_multiplier)
						await enemy_unit.attack(action.target_unit, extra, CardEffectData.DamageType.NORMAL, false)
		
		EnemyAIBase.AIAction.ActionType.MOVE:
			if enemy_unit.can_move():
				enemy_unit.use_move_action()
				var path = action.move_path
				
				if path.size() > 1:
					var move_dist = min(path.size() - 1, enemy_unit.get_current_movement_range())
					var truncated: Array[Vector2i] = []
					for i in range(move_dist + 1):
						truncated.append(path[i])
					await _move_unit_along_path(enemy_unit, truncated)
					if not is_instance_valid(enemy_unit) or enemy_unit.current_health <= 0:
						return
		
		EnemyAIBase.AIAction.ActionType.PASS:
			pass

func _on_combat_ended(player_won: bool):
	"""Volá se když TurnManager ukončí souboj"""
	_current_battle_state = BattleState.BATTLE_OVER
	if is_instance_valid(end_turn_button):
		end_turn_button.disabled = true

	# Dej hráči čas vidět poslední pohyb / past / smrt, než skok na odměny
	if player_won:
		if is_instance_valid(victory_label):
			victory_label.visible = true
		await get_tree().create_timer(1.8).timeout

	# Coop: jen HOST volá battle_finished (připraví rewards, pošle RPC klientovi).
	# Klient čeká na RPC receive_go_to_reward / receive_game_over.
	if _is_coop_run() and has_node("/root/MultiplayerManager") and not MultiplayerManager.is_server():
		# Klient: uložíme HP/shield do PlayerData, ale nevoláme battle_finished – čekáme na RPC.
		if player_won and is_instance_valid(_player_unit_node):
			PlayerData.current_hp = _player_unit_node.current_health
			PlayerData.global_shield = _player_unit_node.current_block
		return
	if player_won and is_instance_valid(_player_unit_node):
		GameManager.battle_finished(true, _player_unit_node.current_health, _player_unit_node.current_block)
	else:
		# Prohra – informuj klienta
		if _is_coop_run() and has_node("/root/MultiplayerManager"):
			MultiplayerManager.rpc("receive_game_over")
		GameManager.battle_finished(player_won)

# NOVÉ A UPRAVENÉ FUNKCE PRO START HRY
func start_player_spawn_selection():
	if _is_coop_run():
		_current_battle_state = BattleState.AWAITING_PLAYER_SPAWN
		_coop_spawn_phase = 0
		_coop_host_spawn_cell = Vector2i(-1, -1)
		_coop_client_spawn_cell = Vector2i(-1, -1)
		var spawn_points = battle_grid_instance.get_player_spawn_points(3)
		battle_grid_instance.show_player_spawn_points(spawn_points)
		end_turn_button.disabled = true
		return
	_current_battle_state = BattleState.AWAITING_PLAYER_SPAWN
	var spawn_points = battle_grid_instance.get_player_spawn_points(3)
	battle_grid_instance.show_player_spawn_points(spawn_points)
	end_turn_button.disabled = true

func _is_coop_run() -> bool:
	return has_node("/root/GameManager") and GameManager.is_coop_run and has_node("/root/MultiplayerManager") and MultiplayerManager.has_active_connection()

@rpc("any_peer", "call_remote")
func _rpc_coop_host_spawn(cx: int, cy: int):
	_coop_host_spawn_cell = Vector2i(cx, cy)
	_coop_spawn_phase = 1
	var host_color := Color(1.3, 1.1, 0.75, 0.7)
	battle_grid_instance.set_coop_selected_spawn(Vector2i(cx, cy), host_color)

@rpc("any_peer", "call_remote")
func _rpc_coop_client_spawn(cx: int, cy: int):
	_coop_client_spawn_cell = Vector2i(cx, cy)
	var client_color := Color(0.5, 0.7, 1.3, 0.7)
	battle_grid_instance.set_coop_selected_spawn(Vector2i(cx, cy), client_color)
	battle_grid_instance.hide_player_spawn_points()
	_coop_do_spawn_and_start()
	rpc("_rpc_coop_spawn_done", _coop_host_spawn_cell.x, _coop_host_spawn_cell.y, _coop_client_spawn_cell.x, _coop_client_spawn_cell.y)

@rpc("any_peer", "call_remote")
func _rpc_coop_spawn_done(hx: int, hy: int, cx: int, cy: int):
	_coop_host_spawn_cell = Vector2i(hx, hy)
	_coop_client_spawn_cell = Vector2i(cx, cy)
	battle_grid_instance.hide_player_spawn_points()
	_coop_do_spawn_and_start()

func _coop_do_spawn_and_start():
	_coop_spawn_two_players_at_positions(_coop_host_spawn_cell, _coop_client_spawn_cell)

func _coop_spawn_two_players_and_start():
	var spawn_points = battle_grid_instance.get_player_spawn_points(3)
	if spawn_points.size() < 2:
		printerr("Coop: potřeba alespoň 2 spawn pozice")
		return
	_coop_spawn_two_players_at_positions(spawn_points[0], spawn_points[1])

func _coop_spawn_two_players_at_positions(host_cell: Vector2i, client_cell: Vector2i):
	"""Coop: spawn na zadaných buňkách + barevné odlišení host/klient."""
	battle_grid_instance.hide_player_spawn_points()
	var host_id = 1
	var client_id = MultiplayerManager.get_other_peer_id() if MultiplayerManager.is_server() else multiplayer.get_unique_id()
	var my_id = multiplayer.get_unique_id()
	var host_unit_data = PlayerData.selected_subclass.specific_unit_data if PlayerData.selected_subclass else null
	var client_unit_data = null
	if GameManager.coop_client_subclass_path != "":
		var sub = load(GameManager.coop_client_subclass_path) as SubclassData
		if sub and sub.specific_unit_data:
			client_unit_data = sub.specific_unit_data
	if not host_unit_data:
		host_unit_data = PlayerData.selected_subclass.specific_unit_data
	if not client_unit_data:
		client_unit_data = host_unit_data
	var u1 = _spawn_unit(host_unit_data, host_cell)
	var u2 = _spawn_unit(client_unit_data, client_cell)
	if not is_instance_valid(u1) or not is_instance_valid(u2):
		printerr("Coop: nepodařilo se spawnout hráčské jednotky")
		return
	u1.set_meta("owner_peer_id", host_id)
	u2.set_meta("owner_peer_id", client_id)
	# OPRAVA: _ready() proběhla PŘED set_meta, takže obě jednotky mají HP z lokálního PlayerData.
	# Spoluhráčova jednotka potřebuje reset – její skutečné HP přijde ze snapshotu.
	if my_id == host_id:
		# Jsme host → u2 je klient, nemáme jeho data → nastavíme max HP
		u2.current_health = PlayerData.max_hp
		u2.current_block = 0
		u2.retained_block = 0
	else:
		# Jsme klient → u1 je host, nemáme jeho data → nastavíme max HP
		u1.current_health = PlayerData.max_hp
		u1.current_block = 0
		u1.retained_block = 0
	# Výraznější barevné odlišení: host = zlatý/teplý, klient = modrý/chladný
	var host_tint = Color(1.3, 1.1, 0.75)    # výrazně zlatá
	var client_tint = Color(0.75, 0.9, 1.3)  # výrazně modrá
	if u1.has_node("Sprite3D"):
		u1.get_node("Sprite3D").modulate = host_tint
	if u2.has_node("Sprite3D"):
		u2.get_node("Sprite3D").modulate = client_tint
	u1.stats_changed.connect(_on_unit_stats_changed)
	u1.died.connect(_on_unit_died)
	u2.stats_changed.connect(_on_unit_stats_changed)
	u2.died.connect(_on_unit_died)
	if my_id == host_id:
		_player_unit_node = u1
		_coop_other_player_unit = u2
		_add_coop_unit_label(u1, true)
		_add_coop_unit_label(u2, false)
	else:
		_player_unit_node = u2
		_coop_other_player_unit = u1
		_add_coop_unit_label(u2, true)
		_add_coop_unit_label(u1, false)
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_combat_start()
	spawn_enemy_units()
	_place_terrain_features()
	var all_units: Array[Unit] = [u1, u2]
	all_units.append_array(_enemy_units)
	var valid_units = all_units.filter(func(u): return is_instance_valid(u))
	call_deferred("_start_combat_with_turn_manager", valid_units)

func _add_coop_unit_label(unit: Unit, is_mine: bool):
	if not is_instance_valid(unit):
		return
	var label = Label3D.new()
	label.text = "Ty" if is_mine else "Spoluhráč"
	label.position = Vector3(0, 1.6, 0)
	label.font_size = 38
	label.outline_size = 12
	if is_mine:
		label.modulate = Color(1.0, 0.85, 0.3)  # zlatá
	else:
		label.modulate = Color(0.4, 0.7, 1.0)  # modrá
	unit.add_child(label)

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
	"""Aktualizuje zobrazení čísla tahu a v coope „Tvůj tah“ / „Tah spoluhráče“."""
	if not is_instance_valid(turn_counter_label):
		return
	var base = TranslationHelper.tr_format("ui.battle.turn", {"value": _current_turn_number})
	if _is_coop_run():
		if _coop_spectator_mode:
			base += " — " + tr("SPECTATOR")
		elif _coop_my_turn:
			base += " — " + TranslationHelper.tr_format("ui.battle.coop_your_turn", {})
		else:
			base += " — " + TranslationHelper.tr_format("ui.battle.coop_teammate_turn", {})
	turn_counter_label.text = base

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
	if not is_instance_valid(unit_node):
		return
	if unit_node == _player_unit_node:
		player_info_panel.update_stats(unit_node)
	elif unit_node in _enemy_units and unit_node.has_method("update_intent"):
		unit_node.update_intent(_player_unit_node, battle_grid_instance)

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


func _on_artifact_extra_turn_requested():
	"""Handler pro Časový krystal - spustí extra tah hráče"""
	start_extra_turn()

func _on_hand_discard_animation_finished():
	PlayerData.discard_hand()
	_update_pile_counts()
	
	# Časový krystal: zkontroluj conditional artefakty na konci tahu (každý 3. tah = extra tah)
	if has_node("/root/ArtifactManager"):
		var ctx = {
			"current_turn": _current_turn_number,
			"turn_number": _current_turn_number,
			"current_hp": PlayerData.current_hp,
			"max_hp": PlayerData.max_hp,
			"current_energy": PlayerData.current_energy,
			"hand_size": PlayerData.current_hand.size(),
			"target": get_player_unit()
		}
		ArtifactManager.check_conditional_artifacts_with_context(ctx)
		# Pokud Časový krystal triggered, emitoval extra_turn_requested a handler zavolal start_extra_turn()
		# Jinak pokračujeme s přechodem na další tah
		if _current_battle_state == BattleState.PLAYER_TURN:
			# start_extra_turn byl zavolán (nastavil stav na PLAYER_TURN) - už nic nedělej
			return
	
	# Přejdi na další tah
	var timer = get_tree().create_timer(0.3)
	timer.timeout.connect(func():
		if has_node("/root/TurnManager"):
			TurnManager.next_turn()
		if _is_coop_run() and has_node("/root/MultiplayerManager"):
			rpc("_rpc_advance_turn")
	)

@rpc("any_peer")
func _rpc_advance_turn():
	"""Coop: druhý peer taky posune kolo, aby byl turn order v syncu."""
	if has_node("/root/TurnManager"):
		TurnManager.next_turn()

func _on_win_button_pressed():
	end_battle_as_victory()

func end_battle_as_victory():
	_current_battle_state = BattleState.BATTLE_OVER
	if _is_coop_run() and has_node("/root/MultiplayerManager") and not MultiplayerManager.is_server():
		if is_instance_valid(_player_unit_node):
			PlayerData.current_hp = _player_unit_node.current_health
			PlayerData.global_shield = _player_unit_node.current_block
		return
	if is_instance_valid(_player_unit_node):
		GameManager.battle_finished(true, _player_unit_node.current_health, _player_unit_node.current_block)
	else:
		GameManager.battle_finished(true)

# OPRAVA: Změna z Node2D na Unit (nebo Node3D)
func _on_unit_died(unit_node: Unit):
	"""Zpracuje smrt jednotky"""
	DebugLogger.log_info("=== Jednotka zemřela: %s ===" % unit_node.unit_data.unit_name)
	
	# Zpracuj oživení hráče (jen pro lokálního hráče)
	if unit_node == _player_unit_node:
		if PlayerData.has_revive:
			DebugLogger.log_info("!!! BOŽSKÁ OCHRANA AKTIVOVÁNA !!!")
			PlayerData.has_revive = false
			var heal_amount = PlayerData.max_hp / 2.0
			if unit_node.has_method("heal"):
				unit_node.heal(heal_amount)
			return
	
	# Coop: když zemře JEDEN z hráčů, druhý pokračuje
	if _is_coop_run() and unit_node.unit_data.faction == UnitData.Faction.PLAYER:
		_handle_coop_player_death(unit_node)
	
	# Trigger enemy death artefakty
	if unit_node.unit_data.faction == UnitData.Faction.ENEMY:
		if has_node("/root/ArtifactManager"):
			ArtifactManager.on_enemy_death(unit_node)
	
	# Odeber ze seznamu
	if _enemy_units.has(unit_node):
		_enemy_units.erase(unit_node)
	
	battle_grid_instance.remove_object_by_instance(unit_node)
	
	# Odregistruj IHNED (před animací), ať TurnManager nepracuje se zombie jednotkou
	if has_node("/root/TurnManager"):
		TurnManager.unregister_unit(unit_node)
	
	# Okamžitě aktualizuj initiative bar (jinak mrtvý zůstane v UI do konce kola)
	if is_instance_valid(initiative_bar) and has_node("/root/TurnManager"):
		initiative_bar.update_turn_order(TurnManager.get_turn_order())
	
	# Animace zmizení pro 3D (Scale místo Modulate)
	# Nepřátelé pomaleji — ať je vidět smrt z pasti / poslední hit
	var death_dur := 0.95 if unit_node.unit_data and unit_node.unit_data.faction == UnitData.Faction.ENEMY else 0.5
	var tween = create_tween()
	tween.tween_property(unit_node, "scale", Vector3.ZERO, death_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	if is_instance_valid(unit_node):
		unit_node.queue_free()

func _handle_coop_player_death(dead_unit: Unit):
	"""Coop: jeden hráč zemřel – stane se divákem, druhý pokračuje."""
	var dead_peer_id = dead_unit.get_meta("owner_peer_id", -1)
	var is_my_unit = (dead_peer_id == multiplayer.get_unique_id())
	
	if is_my_unit:
		# Můj paladin zemřel – přepnu se do spectator módu
		_coop_my_turn = false
		_coop_spectator_mode = true
		end_turn_button.disabled = true
		# Skryj ruku karet
		PlayerData.discard_hand()
		if is_instance_valid(player_hand_ui_instance):
			player_hand_ui_instance.clear_hand()
		_update_pile_counts()
		_update_turn_display()
	
	# Informuj druheho hráče
	if has_node("/root/MultiplayerManager"):
		rpc("_rpc_coop_player_died", dead_peer_id)

@rpc("any_peer", "call_remote")
func _rpc_coop_player_died(dead_peer_id: int):
	"""Druhý hráč nás informoval o smrti svého paladina."""
	# Zjistíme jestli mrtvý je můj nebo jeho paladin
	if dead_peer_id == multiplayer.get_unique_id():
		# Můj paladin zemřel (info od hosta) – spectator mode
		_coop_spectator_mode = true
		_coop_my_turn = false
		end_turn_button.disabled = true
		PlayerData.discard_hand()
		if is_instance_valid(player_hand_ui_instance):
			player_hand_ui_instance.clear_hand()
		_update_pile_counts()
	_update_turn_display()


func spawn_enemy_units():
	DebugLogger.log_debug("=== DEBUG: SPAWNING ENEMIES ===")
	
	if not encounter_data:
		printerr("BattleScene: Chybí EncounterData!")
		return

	DebugLogger.log_debug("Encounter data: %s" % encounter_data.resource_path)
	DebugLogger.log_debug("Počet nepřátel: %d" % encounter_data.enemies.size())

	var all_active_cells = battle_grid_instance._active_cells.keys()
	var player_cells: Array[Vector2i] = []
	if is_instance_valid(_player_unit_node):
		player_cells.append(_player_unit_node.grid_position)
	if is_instance_valid(_coop_other_player_unit):
		player_cells.append(_coop_other_player_unit.grid_position)

	var available_spawn_cells: Array[Vector2i] = []
	
	for cell in all_active_cells:
		if cell.x < battle_grid_instance.grid_columns / 2.0: continue
		if cell in player_cells: continue
			
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
	
	# Coop: uložíme stabilní pořadí všech nepřátel – používá se pro RPC payload indexy
	_all_enemy_units_ordered = _enemy_units.duplicate()
	DebugLogger.log_debug("=== SPAWN DOKONČEN ===")
	DebugLogger.log_debug("Celkem nepřátel: %d" % _enemy_units.size())

func _on_player_hand_card_clicked(card_ui_node: Control, card_data_resource: CardData):
	if _current_battle_state != BattleState.PLAYER_TURN: return
	# Guard: blokovat výběr karty pokud se právě zpracovává akce nebo se hraje karta
	if _is_action_processing or _card_play_in_progress: return
	# Guard: karta musí být stále v ruce (ochrana před opakovaným výběrem právě odehrané karty)
	if not PlayerData.current_hand.has(card_data_resource): return
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

func _on_player_hand_card_drag_started(card_ui_node: Control, card_data_resource: CardData):
	if _current_battle_state != BattleState.PLAYER_TURN:
		player_hand_ui_instance.cancel_drag_ui()
		return
	# Guard: blokovat nový drag pokud se právě zpracovává akce nebo se hraje karta
	if _is_action_processing or _card_play_in_progress:
		player_hand_ui_instance.cancel_drag_ui()
		return
	if PlayerData.current_energy < card_data_resource.cost:
		player_hand_ui_instance.cancel_drag_ui()
		return
	_reset_player_selection()
	_player_action_state = PlayerActionState.CARD_SELECTED
	_selected_card_ui = card_ui_node
	_selected_card_data = card_data_resource
	_show_valid_targets_for_card(card_data_resource)

func _on_player_hand_card_drag_released(card_ui_node: Control, _card_data_resource: CardData):
	if _current_battle_state != BattleState.PLAYER_TURN:
		return
	if _is_action_processing:
		return
	if _player_action_state != PlayerActionState.CARD_SELECTED:
		return
	if _selected_card_ui != card_ui_node:
		return

	var target_cell = get_grid_cell_under_mouse()
	var did_play = _try_play_selected_card_at_cell(target_cell)
	if not did_play:
		_reset_player_selection()

func _on_player_hand_card_drag_cancelled(_card_ui_node: Control, _card_data_resource: CardData):
	_reset_player_selection()

# OPRAVA: Argument je Node3D (nebo Unit, ale Node3D je obecnější pro 3D svět)
func try_play_card(card: CardData, initial_target: Node3D, target_cell: Vector2i = Vector2i(-999, -999)) -> void:
	var effect_summaries: Array = []
	if card:
		for eff in card.effects:
			if not eff:
				continue
			var type_name = CardEffectData.EffectType.keys()[eff.effect_type]
			effect_summaries.append("%s(%s,%d)" % [type_name, eff.string_value, eff.value])
	DebugLogger.log_card_played(card.card_name if card else "null", str(initial_target.name) if initial_target else "none", effect_summaries)
	if _is_action_processing:
		_card_play_in_progress = false
		_clear_card_selection_state_before_play()
		return
	if not card:
		_card_play_in_progress = false
		_clear_card_selection_state_before_play()
		return

	# Hned na začátku skrýt targetable/movable highlight, aby nezůstal po odehrání ani při dvojím signálu
	_clear_card_selection_state_before_play()

	# Frozen - nemůže hrát karty
	if is_instance_valid(_player_unit_node) and (_player_unit_node.is_frozen or _player_unit_node.active_statuses.has("frozen")):
		DebugLogger.log_warning(tr("ui.battle.frozen_warning"))
		_show_floating_notification(tr("ui.battle.frozen_notice"), Color.CYAN)
		_card_play_in_progress = false
		_reset_player_selection()
		return

	if not PlayerData.spend_energy(card.cost):
		DebugLogger.log_warning(TranslationHelper.tr_format("ui.battle.not_enough_energy", {"name": card.get_localized_name()}))
		_card_play_in_progress = false
		_reset_player_selection()
		return

	# Kontrola limitu použití karty za tah
	if card.max_uses_per_turn > 0:
		var current_count = _cards_played_this_turn.get(card.card_id, 0)
		if current_count >= card.max_uses_per_turn:
			# Překročen limit - aplikuj debuff
			_apply_overuse_debuff(card)
			PlayerData.gain_energy(card.cost)  # Vrať energii
			_card_play_in_progress = false
			_reset_player_selection()
			return
		
		# Zvýš počítadlo
		_cards_played_this_turn[card.card_id] = current_count + 1
		
		# Vizuální feedback pro limit
		if current_count + 1 == card.max_uses_per_turn:
			_show_floating_notification(TranslationHelper.tr_format("ui.battle.card_limit", {"current": current_count + 1, "max": card.max_uses_per_turn}), Color.ORANGE)

	_is_action_processing = true
	var card_played_successfully = false
	
	var card_ui_to_remove = _selected_card_ui
	
	# Debug: ensure we see all effects (fixes "effects: []" when card has APPLY_STATUS e.g. regeneration)
	var effect_count = card.effects.size() if card else 0
	DebugLogger.log_debug("Card '%s' effects count: %d" % [card.card_id if card else "null", effect_count])
	for idx in range(effect_count):
		var eff = card.effects[idx]
		if not eff:
			DebugLogger.log_debug("  effect[%d] (null)" % idx)
			continue
		var type_name = CardEffectData.EffectType.keys()[eff.effect_type]
		DebugLogger.log_debug("  effect[%d] type=%s string_value='%s' value=%d" % [idx, type_name, eff.string_value, eff.value])
	
	# Apply non-damage effects first, then damage. Dodge on DEAL_DAMAGE must not
	# skip APPLY_STATUS / heals / etc. on the same card (poisoned_dart fantasy).
	var resolved_cell := target_cell
	if resolved_cell.x <= -900:
		resolved_cell = get_grid_cell_under_mouse()
	
	var ordered_effects: Array = []
	var damage_effects: Array = []
	for effect_data in card.effects:
		if effect_data == null:
			continue
		var is_damage := effect_data.effect_type == CardEffectData.EffectType.DEAL_DAMAGE \
			or effect_data.effect_type == CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK \
			or effect_data.effect_type == CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK
		if is_damage:
			damage_effects.append(effect_data)
		else:
			ordered_effects.append(effect_data)
	ordered_effects.append_array(damage_effects)
	
	for effect_data in ordered_effects:
		if effect_data.effect_type == CardEffectData.EffectType.PLACE_TERRAIN:
			if await _try_place_terrain_effect(effect_data, resolved_cell, card):
				card_played_successfully = true
			continue
		var targets = _get_targets_for_effect(effect_data, initial_target, card)
		if not targets.is_empty():
			card_played_successfully = true
			for target_unit in targets:
				if is_instance_valid(target_unit):
					await _apply_single_effect(effect_data, target_unit, card)
	
	# Označ akci pouze pokud byla karta úspěšně použita
	if card_played_successfully:
		if has_node("/root/AudioManager"):
			AudioManager.play_card_play()
		if is_instance_valid(_player_unit_node):
			_player_unit_node.use_action()
					
	if card_played_successfully:
		# DŮLEŽITÉ: Trigger artefaktů PO trackování ale PŘED aplikací efektů
		if has_node("/root/ArtifactManager"):
			var artifact_results = ArtifactManager.on_card_played(card)
			for result in artifact_results:
				DebugLogger.log_debug("Card play artefakt aktivován: %s" % result.description)
		
		var has_exhaust_effect = card.effects.any(func(e): return e.effect_type == CardEffectData.EffectType.EXHAUST)
		var max_uses = card.max_uses_before_removal if card.max_uses_before_removal > 0 else -1
		var usage_reached_limit := false
		if max_uses > 0:
			var n = PlayerData.increment_card_usage(card.card_id)
			if n >= max_uses:
				usage_reached_limit = true
				# Usage vyčerpán – odstranit jednu kopii z celého balíčku natrvalo
				PlayerData.master_deck.erase(card)
				PlayerData.draw_pile.erase(card)
				PlayerData.discard_pile.erase(card)
				PlayerData.emit_signal("deck_changed")
		if not usage_reached_limit:
			# Zastaralý tag ONE_TIME_USE (chová se jako 1× použití)
			var is_one_time_use = card.has_tag(CardData.CardTag.ONE_TIME_USE)
			if is_one_time_use:
				PlayerData.master_deck.erase(card)
				PlayerData.draw_pile.erase(card)
				PlayerData.discard_pile.erase(card)
				PlayerData.emit_signal("deck_changed")
			elif has_exhaust_effect:
				PlayerData.add_card_to_exhaust_pile(card)
			else:
				PlayerData.add_card_to_discard_pile(card)
		PlayerData.current_hand.erase(card)
		
		player_hand_ui_instance.force_finish_drag()
		if is_instance_valid(card_ui_to_remove):
			card_ui_to_remove.queue_free()
		player_hand_ui_instance._request_arrange()
		_update_pile_counts()
		set_enemy_intents()
		# Real-time coop: druhý peer musí vidět stejný stav (HP, blok, energii, odhozenou kartu)
		if _is_coop_run() and has_node("/root/MultiplayerManager"):
			var payload = _coop_build_card_result_payload(card)
			if payload != null:
				rpc("_rpc_apply_card_result", payload)
	else:
		DebugLogger.log_warning(TranslationHelper.tr_format("ui.battle.no_valid_target", {"name": card.get_localized_name()}))
		PlayerData.gain_energy(card.cost)
		_card_play_in_progress = false

	_is_action_processing = false
	_card_play_in_progress = false
	_reset_player_selection()

## Debug/cheat: add a card by id to the player's current hand (e.g. from DevConsole)
func add_card_to_hand(card_id: String) -> bool:
	if not is_instance_valid(_player_unit_node) or not is_instance_valid(player_hand_ui_instance):
		return false
	var pool = load("res://data/cards/reward_card_pool.tres") as CardPool
	if not is_instance_valid(pool) or pool.cards.is_empty():
		DebugLogger.log_warning("add_card_to_hand: pool invalid or empty")
		return false
	for c in pool.cards:
		if is_instance_valid(c) and c.card_id == card_id:
			return add_card_resource_to_hand(c)
	DebugLogger.log_warning("add_card_to_hand: card_id '%s' not found" % card_id)
	return false

## Debug/cheat: add an already-loaded CardData into the hand.
func add_card_resource_to_hand(card: CardData) -> bool:
	if not is_instance_valid(card):
		return false
	if not is_instance_valid(_player_unit_node) or not is_instance_valid(player_hand_ui_instance):
		return false
	PlayerData.current_hand.append(card)
	player_hand_ui_instance.add_card_to_hand(card)
	player_hand_ui_instance._request_arrange()
	_update_pile_counts()
	DebugLogger.log_debug("add_card_resource_to_hand: added '%s'" % card.card_id)
	return true

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
	label.add_theme_font_size_override("font_size", 19)
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
	# Coop: výběr jen vlastní jednotky a jen když je můj tah
	if _is_coop_run() and (unit_node != _player_unit_node or not _coop_my_turn):
		return
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
	# Coop: pohyb jen vlastní jednotky (ochrana proti desync)
	if _is_coop_run() and unit_to_move != _player_unit_node:
		_reset_player_selection()
		return
	unit_to_move.use_move_action()
	var start_cell = unit_to_move.grid_position
	var path = battle_grid_instance.find_path(start_cell, target_cell, unit_to_move)
	if path.is_empty():
		path = [start_cell, target_cell]
	var final_cell = await _move_unit_along_path(unit_to_move, path)
	_reset_player_selection()
	if not is_instance_valid(unit_to_move) or unit_to_move.current_health <= 0:
		return
	if unit_to_move == _player_unit_node:
		set_enemy_intents()
	# Real-time coop: druhý peer musí vidět stejný pohyb
	if _is_coop_run() and has_node("/root/MultiplayerManager"):
		var idx = _coop_get_player_unit_index(unit_to_move)
		if idx >= 0:
			rpc("_rpc_apply_move", idx, final_cell.x, final_cell.y)

func _move_unit_along_path(unit: Unit, path: Array[Vector2i], step_duration: float = 0.3) -> Vector2i:
	"""Krok po kroku: nejdřív vizuální došlápnutí na buňku, teprve pak ON_ENTER past/mud.
	Vrací buňku, na které jednotka skončila (nebo zemřela).
	step_duration: běžný pohyb ~0.3s; speciály (rush/dash/teleport) volej přes _dash_unit_along_path."""
	if not is_instance_valid(unit):
		return Vector2i.ZERO
	if path.is_empty():
		return unit.grid_position
	if path.size() == 1:
		return path[0]

	var final_pos: Vector2i = path[0]

	for i in range(1, path.size()):
		if not is_instance_valid(unit) or unit.current_health <= 0:
			break
		var cell: Vector2i = path[i]
		final_pos = cell

		battle_grid_instance.remove_object_by_instance(unit)
		if not battle_grid_instance.place_object_on_cell(unit, cell, true, step_duration):
			break

		if has_node("/root/AudioManager"):
			AudioManager.play_footstep()

		await get_tree().create_timer(step_duration).timeout

		if not is_instance_valid(unit) or unit.current_health <= 0:
			break

		var terrain = battle_grid_instance.get_terrain_on_cell(cell)
		if is_instance_valid(terrain):
			var dmg_dealt: int = 0
			if unit.has_method("process_terrain_effects"):
				dmg_dealt = await unit.process_terrain_effects(terrain)
			var should_consume: bool = terrain.consume_on_trigger
			var should_stop: bool = terrain.stops_movement_on_enter or terrain.terrain_id == "mud"
			var unit_label = unit.unit_data.unit_id if unit.unit_data else str(unit.name)
			if terrain.effect_type == TerrainData.TerrainEffect.DAMAGE_ON_ENTER or should_consume:
				DebugLogger.log_info("Trap triggered on %s at %s: %d damage, consumed=%s (terrain=%s)" % [
					unit_label, str(cell), dmg_dealt, str(should_consume), terrain.terrain_id
				])
			if should_consume:
				battle_grid_instance.remove_terrain(cell)
			if not is_instance_valid(unit) or unit.current_health <= 0:
				break
			if should_stop:
				break

	return final_pos

func _rush_unit_along_path(unit: Unit, path: Array[Vector2i]) -> Vector2i:
	"""Plynulý charge: jedna souvislá animace přes celou cestu (ne krokování).
	Po dojetí vyhodnotí pasti/mud po buňkách a případně zastaví dřív."""
	if not is_instance_valid(unit):
		return Vector2i.ZERO
	if path.is_empty():
		return unit.grid_position
	if path.size() == 1:
		return path[0]

	battle_grid_instance.remove_object_by_instance(unit)

	var steps := path.size() - 1
	var per_cell := clampf(0.28 / float(steps), 0.045, 0.1)
	var tween := create_tween()
	# EASE_IN = zrychlení do cíle (charge feel)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for i in range(1, path.size()):
		var world_pos := battle_grid_instance.get_world_position_for_cell(path[i])
		tween.tween_callback(func():
			if has_node("/root/AudioManager"):
				AudioManager.play_footstep()
		)
		tween.tween_property(unit, "position", world_pos, per_cell)

	await tween.finished
	if not is_instance_valid(unit):
		return path[path.size() - 1]

	# Po vizuálním charge vyhodnoť terén v pořadí (pasti po cestě)
	var final_pos: Vector2i = path[0]
	for i in range(1, path.size()):
		var cell: Vector2i = path[i]
		final_pos = cell
		unit.grid_position = cell
		unit.position = battle_grid_instance.get_world_position_for_cell(cell)

		var terrain = battle_grid_instance.get_terrain_on_cell(cell)
		if is_instance_valid(terrain):
			var dmg_dealt: int = 0
			if unit.has_method("process_terrain_effects"):
				dmg_dealt = await unit.process_terrain_effects(terrain)
			var should_consume: bool = terrain.consume_on_trigger
			var should_stop: bool = terrain.stops_movement_on_enter or terrain.terrain_id == "mud"
			var unit_label = unit.unit_data.unit_id if unit.unit_data else str(unit.name)
			if terrain.effect_type == TerrainData.TerrainEffect.DAMAGE_ON_ENTER or should_consume:
				DebugLogger.log_info("Trap triggered on %s at %s: %d damage, consumed=%s (terrain=%s)" % [
					unit_label, str(cell), dmg_dealt, str(should_consume), terrain.terrain_id
				])
			if should_consume:
				battle_grid_instance.remove_terrain(cell)
			if not is_instance_valid(unit) or unit.current_health <= 0:
				return final_pos
			if should_stop:
				break

	if is_instance_valid(unit) and unit.current_health > 0:
		battle_grid_instance.place_object_on_cell(unit, final_pos, false)
	return final_pos

func _teleport_unit_to_cell(unit: Unit, target_cell: Vector2i) -> Vector2i:
	"""Blink / shadow teleport: zmizí → objeví se na cíli (landing spouští past)."""
	if not is_instance_valid(unit):
		return Vector2i.ZERO
	if target_cell == unit.grid_position:
		return target_cell

	# Unit je Node3D — modulate je na Sprite3D, ne na rootu
	var sprite: Sprite3D = unit.get_node_or_null("Sprite3D") as Sprite3D
	var start_mod: Color = sprite.modulate if is_instance_valid(sprite) else Color.WHITE
	var start_scale: Vector3 = unit.scale

	var vanish := create_tween()
	if is_instance_valid(sprite):
		vanish.tween_property(sprite, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	vanish.parallel().tween_property(unit, "scale", start_scale * 0.35, 0.12).set_trans(Tween.TRANS_BACK)
	await vanish.finished
	if not is_instance_valid(unit):
		return target_cell

	battle_grid_instance.remove_object_by_instance(unit)
	if not battle_grid_instance.place_object_on_cell(unit, target_cell, false):
		if is_instance_valid(sprite):
			sprite.modulate = start_mod
		unit.scale = start_scale
		battle_grid_instance.place_object_on_cell(unit, unit.grid_position, false)
		return unit.grid_position

	if is_instance_valid(sprite):
		sprite.modulate.a = 0.0
	var appear := create_tween()
	if is_instance_valid(sprite):
		appear.tween_property(sprite, "modulate:a", start_mod.a, 0.14).set_trans(Tween.TRANS_SINE)
	appear.parallel().tween_property(unit, "scale", start_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await appear.finished
	if is_instance_valid(unit):
		if is_instance_valid(sprite):
			sprite.modulate = start_mod
		unit.scale = start_scale

	if not is_instance_valid(unit) or unit.current_health <= 0:
		return target_cell

	var terrain = battle_grid_instance.get_terrain_on_cell(target_cell)
	if is_instance_valid(terrain) and unit.has_method("process_terrain_effects"):
		var dmg_dealt = await unit.process_terrain_effects(terrain)
		var should_consume = terrain.consume_on_trigger
		if terrain.effect_type == TerrainData.TerrainEffect.DAMAGE_ON_ENTER or should_consume:
			var unit_label = unit.unit_data.unit_id if unit.unit_data else str(unit.name)
			DebugLogger.log_info("Trap triggered on %s at %s: %d damage, consumed=%s (terrain=%s)" % [
				unit_label, str(target_cell), dmg_dealt, str(should_consume), terrain.terrain_id
			])
		if should_consume:
			battle_grid_instance.remove_terrain(target_cell)

	return target_cell

func _dash_unit_along_path(unit: Unit, path: Array[Vector2i]) -> Vector2i:
	"""Legacy rychlý pohyb po buňkách — preferuj _rush / _teleport pro speciály."""
	if path.size() <= 2:
		return await _move_unit_along_path(unit, path, 0.1)
	return await _rush_unit_along_path(unit, path)

# Converts legacy damage_multiplier to additive bonus for DamageCalculator
func _damage_multiplier_to_extra(unit: Unit, multiplier: float) -> int:
	var base = unit.unit_data.attack_damage
	return int(base * (multiplier - 1.0))

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
			if target is Unit:
				return target.active_statuses.size() > 0
			return false
		"target_health_above_percent":
			if target is Unit:
				var unit_data = target.get_unit_data()
				var max_hp = unit_data.max_health
				var percent = (float(target.current_health) * 100.0) / float(max_hp)
				return percent > effect.condition_value
			return false
		"took_damage_last_turn":
			return _took_damage_last_turn
		_:
			return true

# OPRAVA: Argument 'target' musí být Node3D (pro 3D jednotky). card_being_played = karta (po grid kliku může být _selected_card_data null)
func _apply_single_effect(effect: CardEffectData, target: Node3D, card_being_played: CardData = null) -> void:
	if not is_instance_valid(target): return
	var card_ref: CardData = card_being_played if is_instance_valid(card_being_played) else _selected_card_data
	
	# Kontrola podmínek
	var condition_met = _check_condition(effect, target)
	var bonus_value = effect.conditional_bonus_value if condition_met else 0
	
	match effect.effect_type:
		CardEffectData.EffectType.DEAL_DAMAGE:
			if target.has_method("take_damage"):
				var base_value = effect.value
				base_value += bonus_value
				if effect.condition_type == "damage_per_block" and is_instance_valid(_player_unit_node):
					base_value += _player_unit_node.current_block * effect.conditional_bonus_value
				if effect.damage_type == CardEffectData.DamageType.HOLY and is_instance_valid(_player_unit_node) and _player_unit_node.active_statuses.has("consecrated_weapon"):
					var status_data = _player_unit_node.active_statuses["consecrated_weapon"]
					base_value += status_data.value
					_player_unit_node.active_statuses.erase("consecrated_weapon")
					_player_unit_node._update_stats_and_emit_signal()
				
				var total_crit_chance = PlayerData.get_critical_chance()
				if has_node("/root/ArtifactManager"):
					total_crit_chance += ArtifactManager.get_critical_chance()
				var is_critical = total_crit_chance > 0 and randi_range(1, 100) <= total_crit_chance
				
				var damage_to_deal = DamageCalculator.get_final_damage(
					base_value,
					_player_unit_node,
					target,
					effect.damage_type,
					is_critical,
					true,
					0
				)
				if is_critical and is_instance_valid(_player_unit_node):
					DebugLogger.log_info("💥 KRITICKÝ ZÁSAH! Poškození: %d" % damage_to_deal)
					_player_unit_node._show_floating_text(damage_to_deal, "critical")
				elif target is Unit and target.has_method("get_unit_data") and target.get_unit_data():
					var holy_bonus = UnitData.get_holy_damage_bonus(effect.damage_type, target.get_unit_data().unit_type)
					if holy_bonus > 0:
						DebugLogger.log_info("✨ HOLY BONUS +%d poškození!" % holy_bonus)
						if target.has_method("_show_floating_text"):
							target._show_floating_text(damage_to_deal, "holy_effective")
				
				var enemy_health_before = 0
				if target is Unit and target.get_unit_data().faction == UnitData.Faction.ENEMY:
					enemy_health_before = target.current_health
				
				# Dodge skips damage only; subsequent card effects (APPLY_STATUS etc.) still run.
				var hit_landed: bool = await target.take_damage(damage_to_deal, true)
				if not hit_landed:
					DebugLogger.log_info("DEAL_DAMAGE dodged — další efekty karty se přesto aplikují")
					return
				
				# Pokud byl nepřítel zabit touto kartou, zkontroluj, zda karta má gods_lightning efekt
				if target is Unit and target.get_unit_data().faction == UnitData.Faction.ENEMY:
					if enemy_health_before > 0 and target.current_health <= 0 and is_instance_valid(card_ref):
						for card_effect in card_ref.effects:
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
				# Podpora pro blok z max_hp / current_hp (používá se v unbreakable_faith)
				if effect.string_value == "max_hp" and is_instance_valid(_player_unit_node):
					block_amount = PlayerData.max_hp
				elif effect.string_value == "current_hp" and is_instance_valid(_player_unit_node):
					block_amount = PlayerData.current_hp
				
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
				var block_damage = DamageCalculator.get_final_damage(
					_player_unit_node.current_block,
					_player_unit_node,
					target,
					CardEffectData.DamageType.NORMAL,
					false,
					true,
					0
				)
				# Shield Bash: cap 15 (balance audit)
				if is_instance_valid(card_ref) and card_ref.card_id == "shield_bash":
					block_damage = mini(block_damage, 15)
				target.take_damage(block_damage, true)
				
		CardEffectData.EffectType.DRAW_CARDS:
			_cards_to_draw_queue += effect.value
			_draw_next_card_in_queue()
			
		CardEffectData.EffectType.GAIN_ENERGY: 
			# Speciální případ: gods_lightning - energie se získává pouze při zabití nepřítele
			if is_instance_valid(card_ref) and card_ref.card_id == "gods_lightning":
				pass  # Energie se přidá v damage efektu, pokud byl nepřítel zabit
			else:
				PlayerData.gain_energy(effect.value)
		
		CardEffectData.EffectType.APPLY_STATUS:
			if target.has_method("apply_status"):
				# Speciální případ: remove_all_debuffs
				if effect.string_value == "remove_all_debuffs":
					if target is Unit and target.has("active_statuses"):
						# Odstraň debuffy; zachovej buffy (regeneration, aury, until-consumed)
						var statuses_to_remove = []
						var keep_buffs := [
							"regeneration",
							"aura_devotion",
							"aura_devotion_plus",
							"defensive_stance",
							"consecrated_weapon",
							"aiming",
							"monk_blessing",
						]
						for status_id in target.active_statuses.keys():
							if status_id not in keep_buffs:
								statuses_to_remove.append(status_id)
						
						for status_id in statuses_to_remove:
							target.active_statuses.erase(status_id)
						
						if not statuses_to_remove.is_empty():
							target._update_stats_and_emit_signal()
							DebugLogger.log_info("Odstraněno %d debuffů" % statuses_to_remove.size())
				else:
					# poison: value = DMG/turn; aoe_param_x = počet kol (povinně > 0)
					# regeneration: duration = value (heal/turn i počet kol)
					# until-consumed (defensive_stance, consecrated_weapon): no turn tick
					var duration = 1
					var status_value = effect.value
					if effect.string_value == "regeneration":
						duration = effect.value
					elif effect.string_value == "poison":
						duration = effect.aoe_param_x if effect.aoe_param_x > 0 else 3
						if has_node("/root/PlayerData"):
							status_value += PlayerData.poison_damage_bonus
					elif effect.string_value == "defensive_stance" or effect.string_value == "consecrated_weapon":
						duration = 999
					elif effect.aoe_param_x > 0:
						duration = effect.aoe_param_x
					target.apply_status(effect.string_value, status_value, duration)
			
		CardEffectData.EffectType.GAIN_EXTRA_MOVE:
			if target.has_method("gain_extra_move"): target.gain_extra_move()
			
		CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK:
			if is_instance_valid(_player_unit_node) and target.has_method("take_damage"):
				var damage = DamageCalculator.get_final_damage(
					_player_unit_node.current_block,
					_player_unit_node,
					target,
					CardEffectData.DamageType.NORMAL,
					false,
					true,
					_player_unit_node.current_block
				)
				# Shield Bash+: cap 20 (balance audit)
				if is_instance_valid(card_ref) and card_ref.card_id == "shield_bash+":
					damage = mini(damage, 20)
				target.take_damage(damage, true)
		
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
# card_being_played: karta, která se právě hraje (potřeba pro range; _selected_card_data je už vynulovaná)
func _get_targets_for_effect(effect: CardEffectData, initial_target_node: Node3D, card_being_played: CardData) -> Array:
	var targets: Array = []
	var clicked_grid_cell = get_grid_cell_under_mouse() # OPRAVA: Použití 3D Raycast funkce místo get_global_mouse_position
	var grid_ref = battle_grid_instance
	if not grid_ref and has_node("BattleGrid"):
		grid_ref = get_node("BattleGrid")

	# PLAYER_CENTERED_AOE: pro ANY_GRID_CELL i ALL_ENEMY_UNITS použij pozici hráče jako střed
	var is_player_centered = is_instance_valid(card_being_played) and card_being_played.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE
	
	if effect.target_type == CardEffectData.TargetType.ANY_GRID_CELL:
		if not grid_ref:
			return targets
		var affected_cells: Array[Vector2i]
		if is_player_centered and is_instance_valid(_player_unit_node):
			affected_cells = grid_ref.get_cells_for_centered_aoe(
				_player_unit_node.grid_position, effect.area_of_effect_type,
				effect.aoe_param_x, effect.aoe_param_y)
		else:
			affected_cells = grid_ref.get_cells_for_aoe(
				clicked_grid_cell, effect.area_of_effect_type,
				effect.aoe_param_x, effect.aoe_param_y)
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
				if grid_ref and is_instance_valid(_player_unit_node) and is_instance_valid(card_being_played):
					if grid_ref.get_distance(_player_unit_node.grid_position, initial_target_node.grid_position) <= card_being_played.range_value:
						targets.append(initial_target_node)
		CardEffectData.TargetType.ALL_ENEMY_UNITS:
			# PLAYER_CENTERED_AOE: omezit na nepřátele v AOE oblasti kolem hráče
			if is_player_centered and grid_ref and is_instance_valid(_player_unit_node):
				var aoe_cells = grid_ref.get_cells_for_centered_aoe(
					_player_unit_node.grid_position, effect.area_of_effect_type,
					effect.aoe_param_x, effect.aoe_param_y)
				for cell in aoe_cells:
					var unit_on_cell = grid_ref.get_object_on_cell(cell)
					if is_instance_valid(unit_on_cell) and unit_on_cell.get_unit_data().faction == UnitData.Faction.ENEMY:
						targets.append(unit_on_cell)
			else:
				targets.assign(_enemy_units)
		CardEffectData.TargetType.ALL_ALLY_UNITS:
			# V této hře je hráč jediný spojenec, ale pro budoucí rozšíření můžeme přidat další spojence
			if is_instance_valid(_player_unit_node):
				targets.append(_player_unit_node)
		CardEffectData.TargetType.EMPTY_GRID_CELL, CardEffectData.TargetType.ANY_GRID_CELL:
			pass  # PLACE_TERRAIN řeší try_play_card zvlášť
	return targets

func _try_place_terrain_effect(effect: CardEffectData, target_cell: Vector2i, card: CardData) -> bool:
	if not battle_grid_instance or not is_instance_valid(_player_unit_node):
		return false
	if not battle_grid_instance.is_cell_active(target_cell):
		return false
	if battle_grid_instance.get_object_on_cell(target_cell) != null:
		DebugLogger.log_warning("Past lze položit jen na prázdné políčko!")
		return false
	var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, target_cell)
	if distance > card.range_value:
		DebugLogger.log_warning("Cíl je mimo dosah karty!")
		return false
	if effect.string_value.is_empty():
		DebugLogger.log_error("PLACE_TERRAIN bez cesty k TerrainData")
		return false
	var terrain = load(effect.string_value) as TerrainData
	if not is_instance_valid(terrain):
		DebugLogger.log_error("Nepodařilo se načíst terrain: %s" % effect.string_value)
		return false
	battle_grid_instance.place_terrain(target_cell, terrain)
	DebugLogger.log_info("Položen terén '%s' na %s" % [terrain.terrain_id, str(target_cell)])
	return true
	
func _clear_card_selection_state_before_play():
	"""Zruší stav 'karta vybraná' pro vstup, aby další klik na grid nespustil kartu znovu.
	_selected_card_ui ponecháme — try_play_card ho používá pro odstranění karty z ruky.
	Skryjeme i enemy range (červený pod nepřítelem), aby po odehrání karty nezůstal a nevyzýval k druhému kliku."""
	_player_action_state = PlayerActionState.IDLE
	_selected_card_data = null
	battle_grid_instance.hide_movable_range()
	battle_grid_instance.hide_targetable_cells()
	battle_grid_instance.hide_aoe_highlight()
	battle_grid_instance.hide_enemy_range()
	if _current_battle_state == BattleState.PLAYER_TURN:
		battle_grid_instance.hide_danger_zone()

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
	battle_grid_instance.hide_enemy_range()
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
	
	# Coop: sync stavu jednotky po end-of-turn artefaktech
	if _is_coop_run() and is_instance_valid(_player_unit_node):
		var my_idx = _coop_get_player_unit_index(_player_unit_node)
		rpc("_rpc_coop_sync_my_unit_state", my_idx, _player_unit_node.current_health, _player_unit_node.current_block)
	
	# Odhoď karty
	player_hand_ui_instance.discard_hand_animated(discard_pile_button.global_position)
	# ============================================

func _on_energy_changed(new_amount: int):
	energy_label.text = TranslationHelper.tr_format("ui.battle.energy", {"value": new_amount})
	player_info_panel.update_energy_display()

func _physics_process(_delta):
	# Raycast pro enemy hover (card target preview je už v _process, nevolat 2×)
	var grid_cell = get_grid_cell_under_mouse() 
	var unit_under_mouse = battle_grid_instance.get_object_on_cell(grid_cell)
	_refresh_enemy_info_hover(unit_under_mouse, false)

func _is_mouse_over_enemy_info_panel() -> bool:
	if not is_instance_valid(enemy_info_panel) or not enemy_info_panel.visible:
		return false
	return enemy_info_panel.get_global_rect().has_point(enemy_info_panel.get_global_mouse_position())

func _refresh_enemy_info_hover(unit_under_mouse: Node, show_range: bool) -> void:
	"""Enemy info při hoveru; zůstane otevřené i když myš přejede na panel (scroll)."""
	if is_instance_valid(unit_under_mouse) and unit_under_mouse.get_unit_data().faction == UnitData.Faction.ENEMY:
		enemy_info_panel.update_stats(unit_under_mouse)
		if show_range and is_instance_valid(battle_grid_instance):
			battle_grid_instance.show_enemy_range(unit_under_mouse)
		return
	if _is_mouse_over_enemy_info_panel():
		return
	enemy_info_panel.hide_panel()
	_clear_enemy_hover_highlights()

func _show_valid_targets_for_card(card: CardData):
	var valid_target_cells: Array[Vector2i] = []
	var is_attack = true
	var needs_los = card.range_type == CardData.EffectRangeType.RANGED_FIXED or card.range_type == CardData.EffectRangeType.RANGED_LINE
	
	# PLAYER_CENTERED_AOE: zobrazit AOE preview kolem hráče, hráčova buňka jako cíl
	if card.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE and is_instance_valid(_player_unit_node):
		is_attack = true
		valid_target_cells.append(_player_unit_node.grid_position)
		# Okamžitě zobrazit AOE highlight kolem hráče
		var aoe_cells: Array[Vector2i] = []
		for effect in card.effects:
			if effect.area_of_effect_type == CardEffectData.AreaOfEffectType.SINGLE_TARGET:
				continue
			var cells = battle_grid_instance.get_cells_for_centered_aoe(
				_player_unit_node.grid_position, effect.area_of_effect_type,
				effect.aoe_param_x, effect.aoe_param_y)
			for cell in cells:
				if battle_grid_instance.is_cell_active(cell) and not aoe_cells.has(cell):
					aoe_cells.append(cell)
		if not aoe_cells.is_empty():
			battle_grid_instance.show_aoe_highlight(aoe_cells)
		battle_grid_instance.show_targetable_cells(valid_target_cells, is_attack)
		return
	
	for effect in card.effects:
		match effect.target_type:
			CardEffectData.TargetType.SELECTED_ENEMY_UNIT:
				is_attack = true
				for enemy in _enemy_units:
					if is_instance_valid(enemy):
						var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, enemy.grid_position)
						if distance <= card.range_value:
							if needs_los and not battle_grid_instance.has_line_of_sight(_player_unit_node.grid_position, enemy.grid_position, enemy):
								continue
							valid_target_cells.append(enemy.grid_position)
			CardEffectData.TargetType.SELF_UNIT:
				is_attack = false
				if not valid_target_cells.has(_player_unit_node.grid_position): valid_target_cells.append(_player_unit_node.grid_position)
			CardEffectData.TargetType.EMPTY_GRID_CELL:
				is_attack = false
				for cell in battle_grid_instance.get_all_active_cells():
					if battle_grid_instance.get_object_on_cell(cell) != null:
						continue
					var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, cell)
					if distance <= card.range_value:
						valid_target_cells.append(cell)
			_:
				if effect.effect_type == CardEffectData.EffectType.PLACE_TERRAIN:
					is_attack = false
					for cell in battle_grid_instance.get_all_active_cells():
						if battle_grid_instance.get_object_on_cell(cell) != null:
							continue
						var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, cell)
						if distance <= card.range_value:
							valid_target_cells.append(cell)
	battle_grid_instance.show_targetable_cells(valid_target_cells, is_attack)

func _clear_enemy_hover_highlights():
	if battle_grid_instance and battle_grid_instance.has_method("clear_highlights"):
		battle_grid_instance.clear_highlights()
	else:
		battle_grid_instance.hide_enemy_range()

func _update_pile_counts():
	if is_instance_valid(draw_pile_button): draw_pile_button.update_count(PlayerData.draw_pile.size())
	if is_instance_valid(discard_pile_button): discard_pile_button.update_count(PlayerData.discard_pile.size())

#func _update_hand_ui():
#	player_hand_ui_instance.clear_hand()
#	for card_data in PlayerData.current_hand: player_hand_ui_instance.add_card_to_hand(card_data)
#	_update_pile_counts()


func set_enemy_intents():
	"""Zobrazí záměry nepřátel (jejich budoucí akce).
	Klient v coopu NEPOČÍTÁ intenty lokálně – čeká na data od hosta."""
	if _is_coop_run() and has_node("/root/MultiplayerManager") and not MultiplayerManager.is_server():
		# Klient: intenty přijdou ze snapshotů (_rpc_apply_enemy_turn_result).
		# Jen ukážeme ikony s daty, které už máme nastavené.
		for enemy_unit in _enemy_units:
			if is_instance_valid(enemy_unit):
				enemy_unit.show_intent()
		return
	for enemy_unit in _enemy_units:
		if not is_instance_valid(enemy_unit):
			continue
		if not enemy_unit.has_method("update_intent"):
			continue
		enemy_unit.update_intent(_player_unit_node, battle_grid_instance)

func _set_enemy_intents_visible(visible: bool) -> void:
	for enemy_unit in _enemy_units:
		if is_instance_valid(enemy_unit) and enemy_unit.has_method("set_intent_visibility_allowed"):
			enemy_unit.set_intent_visibility_allowed(visible)

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

func _on_card_hover_exited_dismiss_tooltip(card_data: CardData) -> void:
	_dismiss_tooltip_if_matches(card_data)

func _on_deck_viewer_card_unhovered() -> void:
	# DeckViewer neposílá kartu — zavři jakýkoli otevřený tooltip z vieweru/ruky.
	if card_tooltip and card_tooltip.visible:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null

func _dismiss_tooltip_if_matches(card_data: CardData) -> void:
	if not card_tooltip or not card_tooltip.visible or _current_tooltip_card_data == null or card_data == null:
		return
	var same := card_data == _current_tooltip_card_data
	if not same and not card_data.resource_path.is_empty() and not _current_tooltip_card_data.resource_path.is_empty():
		same = card_data.resource_path == _current_tooltip_card_data.resource_path
	if same:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null

func _show_card_tooltip():
	"""Zobrazí tooltip pro aktuálně vybranou kartu"""
	if not _current_tooltip_card_data or not card_tooltip:
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(360, 420)
	
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
	if not PlayerData.current_hand.has(_selected_card_data):
		_reset_player_selection()
		return
	
	# PLAYER_CENTERED_AOE: AOE je statické kolem hráče, už nastavené v _show_valid_targets_for_card
	if _selected_card_data.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE:
		return
	
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

func _try_play_selected_card_at_cell(clicked_grid_cell: Vector2i) -> bool:
	if _player_action_state != PlayerActionState.CARD_SELECTED:
		return false
	if not is_instance_valid(_selected_card_data):
		return false
	if _is_action_processing:
		return false
	if _card_play_in_progress:
		return false
	# Karta musí být stále v ruce (ochrana před dvojím odehráním)
	if not PlayerData.current_hand.has(_selected_card_data):
		_reset_player_selection()
		return false

	var card_to_play: CardData = _selected_card_data
	
	# PLAYER_CENTERED_AOE: auto-play z pozice hráče (nepotřebuje kliknutý cíl)
	if card_to_play.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE:
		if is_instance_valid(_player_unit_node):
			_card_play_in_progress = true
			_clear_card_selection_state_before_play()
			try_play_card(card_to_play, _player_unit_node)
			return true
		return false
	
	var has_self_effect = _selected_card_data.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELF_UNIT)
	var has_enemy_effect = _selected_card_data.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELECTED_ENEMY_UNIT)
	var has_empty_cell_effect = _selected_card_data.effects.any(func(e): return e.target_type == CardEffectData.TargetType.EMPTY_GRID_CELL or e.effect_type == CardEffectData.EffectType.PLACE_TERRAIN)

	# Pokud karta má pouze SELF efekty (bez ENEMY efektů), použij hráče jako cíl
	if has_self_effect and not has_enemy_effect and not has_empty_cell_effect:
		if is_instance_valid(_player_unit_node):
			_card_play_in_progress = true
			_clear_card_selection_state_before_play()
			try_play_card(card_to_play, _player_unit_node)
			return true
		return false

	var target_node = battle_grid_instance.get_object_on_cell(clicked_grid_cell)

	if has_empty_cell_effect:
		if is_instance_valid(target_node):
			DebugLogger.log_warning("Past lze položit jen na prázdné políčko!")
			return false
		if is_instance_valid(_player_unit_node) and battle_grid_instance:
			var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, clicked_grid_cell)
			if distance > card_to_play.range_value:
				DebugLogger.log_warning("Cíl je mimo dosah karty!")
				return false
		_card_play_in_progress = true
		_clear_card_selection_state_before_play()
		try_play_card(card_to_play, null, clicked_grid_cell)
		return true

	# Kontrola: Pokud karta vyžaduje nepřítele jako cíl, musí být target_node validní nepřítel
	if has_enemy_effect:
		if not is_instance_valid(target_node) or not target_node is Unit or not target_node.get_unit_data().faction == UnitData.Faction.ENEMY:
			DebugLogger.log_warning("Karta vyžaduje vybraného nepřítele!")
			return false
		if is_instance_valid(_player_unit_node) and battle_grid_instance:
			var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, target_node.grid_position)
			if distance > card_to_play.range_value:
				DebugLogger.log_warning("Cíl je mimo dosah karty!")
				return false
			var needs_los = card_to_play.range_type == CardData.EffectRangeType.RANGED_FIXED or card_to_play.range_type == CardData.EffectRangeType.RANGED_LINE
			if needs_los and not battle_grid_instance.has_line_of_sight(_player_unit_node.grid_position, target_node.grid_position, target_node):
				DebugLogger.log_warning("Cíl není v přímé viditelnosti (LoS)!")
				return false

	_card_play_in_progress = true
	_clear_card_selection_state_before_play()
	try_play_card(card_to_play, target_node, clicked_grid_cell)
	return true

func _execute_card_play_at_cell(card: CardData, clicked_grid_cell: Vector2i) -> bool:
	"""Odehraje kartu na danou buňku. Volá se až po _clear_card_selection_state_before_play(), takže stav je už IDLE.
	_card_play_in_progress už mohl nastavit volající (grid klik), aby zabránil dvojímu odehrání."""
	if _is_action_processing:
		return false
	if not is_instance_valid(card) or not PlayerData.current_hand.has(card):
		return false
	# PLAYER_CENTERED_AOE: auto-play z pozice hráče
	if card.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE:
		if is_instance_valid(_player_unit_node):
			_card_play_in_progress = true
			try_play_card(card, _player_unit_node)
			return true
		return false
	var has_self_effect = card.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELF_UNIT)
	var has_enemy_effect = card.effects.any(func(e): return e.target_type == CardEffectData.TargetType.SELECTED_ENEMY_UNIT)
	var has_empty_cell_effect = card.effects.any(func(e): return e.target_type == CardEffectData.TargetType.EMPTY_GRID_CELL or e.effect_type == CardEffectData.EffectType.PLACE_TERRAIN)
	if has_self_effect and not has_enemy_effect and not has_empty_cell_effect:
		if is_instance_valid(_player_unit_node):
			_card_play_in_progress = true
			try_play_card(card, _player_unit_node)
			return true
		return false
	var target_node = battle_grid_instance.get_object_on_cell(clicked_grid_cell)
	if has_empty_cell_effect:
		if is_instance_valid(target_node):
			return false
		if is_instance_valid(_player_unit_node) and battle_grid_instance:
			var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, clicked_grid_cell)
			if distance > card.range_value:
				return false
		_card_play_in_progress = true
		try_play_card(card, null, clicked_grid_cell)
		return true
	if has_enemy_effect:
		if not is_instance_valid(target_node) or not target_node is Unit or not target_node.get_unit_data().faction == UnitData.Faction.ENEMY:
			return false
		if is_instance_valid(_player_unit_node) and battle_grid_instance:
			var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, target_node.grid_position)
			if distance > card.range_value:
				return false
			var needs_los = card.range_type == CardData.EffectRangeType.RANGED_FIXED or card.range_type == CardData.EffectRangeType.RANGED_LINE
			if needs_los and not battle_grid_instance.has_line_of_sight(_player_unit_node.grid_position, target_node.grid_position, target_node):
				return false
	_card_play_in_progress = true
	try_play_card(card, target_node, clicked_grid_cell)
	return true

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
		TerrainData.TerrainEffect.DAMAGE_ON_ENTER:
			if unit.has_method("take_damage") and terrain.effect_numeric_value > 0:
				# Pasti nelze vyhnout
				unit.take_damage(terrain.effect_numeric_value, true, false, false)
				var unit_label = unit.unit_data.unit_id if unit is Unit and unit.unit_data else str(unit.name)
				DebugLogger.log_info("Trap triggered on %s: %d damage, consumed=%s" % [
					unit_label, terrain.effect_numeric_value, str(terrain.consume_on_trigger)
				])

func _generate_grid_from_shape():
	var all_shapes = [SHAPE_DEFAULT, SHAPE_CROSS, SHAPE_DIAMOND]
	var selected_shape = all_shapes.pick_random()
	battle_grid_instance.build_from_shape(selected_shape)

func _setup_camera_boundaries():
	pass # Ve 3D zatím hranice neřešíme

# OPRAVA: Návratový typ Node3D (nebo Unit)
func get_player_unit() -> Node3D:
	return _player_unit_node

# Coop real-time: index 0 = hostova jednotka, 1 = klientova (stejné pořadí na obou peerech)
func _coop_get_player_unit_by_index(idx: int) -> Unit:
	if idx == 0:
		return _player_unit_node if _player_unit_node != null and _player_unit_node.get_meta("owner_peer_id", -1) == 1 else _coop_other_player_unit
	if idx == 1:
		return _coop_other_player_unit if _player_unit_node != null and _player_unit_node.get_meta("owner_peer_id", -1) == 1 else _player_unit_node
	return null

func _coop_get_player_unit_index(unit: Unit) -> int:
	if not unit:
		return -1
	var owner_id = unit.get_meta("owner_peer_id", -1)
	return 0 if owner_id == 1 else 1

func _coop_sync_player_data_from_unit():
	"""Po přijetí snapshotu aktualizuje PlayerData.current_hp podle stavu VLASTNÍ jednotky.
	Bez toho by PlayerData.current_hp zůstalo zastaralé a artefakty/UI by viděly špatné HP."""
	if not _is_coop_run() or not is_instance_valid(_player_unit_node):
		return
	if _player_unit_node.current_health != PlayerData.current_hp:
		PlayerData.current_hp = _player_unit_node.current_health
		PlayerData.emit_signal("health_changed", PlayerData.current_hp, PlayerData.max_hp)

func _coop_build_battle_state_snapshot() -> Dictionary:
	"""Kompletní stav bitvy pro sync s klientem – HP, block, pozice, statusy, intenty, AI meta."""
	var u0 = _coop_get_player_unit_by_index(0)
	var u1 = _coop_get_player_unit_by_index(1)
	var enemy_hps: Array = []
	var enemy_pos: Array = []
	var enemy_statuses: Array = []
	var enemy_intents: Array = []
	var enemy_ai_meta: Array = []
	var enemy_blocks: Array = []
	for e in _all_enemy_units_ordered:
		if is_instance_valid(e):
			enemy_hps.append(e.current_health)
			enemy_pos.append({"x": e.grid_position.x, "y": e.grid_position.y})
			enemy_statuses.append(e.serialize_statuses())
			enemy_intents.append(e.serialize_intent())
			enemy_ai_meta.append(e.serialize_ai_meta())
			enemy_blocks.append(e.current_block)
		else:
			enemy_hps.append(0)
			enemy_pos.append({"x": 0, "y": 0})
			enemy_statuses.append([])
			enemy_intents.append({})
			enemy_ai_meta.append({})
			enemy_blocks.append(0)
	return {
		"enemy_hps": enemy_hps,
		"enemy_pos": enemy_pos,
		"enemy_statuses": enemy_statuses,
		"enemy_intents": enemy_intents,
		"enemy_ai_meta": enemy_ai_meta,
		"enemy_blocks": enemy_blocks,
		"player_0_hp": u0.current_health if is_instance_valid(u0) else 0,
		"player_0_block": u0.current_block if is_instance_valid(u0) else 0,
		"player_0_x": u0.grid_position.x if is_instance_valid(u0) else 0,
		"player_0_y": u0.grid_position.y if is_instance_valid(u0) else 0,
		"player_0_statuses": u0.serialize_statuses() if is_instance_valid(u0) else [],
		"player_1_hp": u1.current_health if is_instance_valid(u1) else 0,
		"player_1_block": u1.current_block if is_instance_valid(u1) else 0,
		"player_1_x": u1.grid_position.x if is_instance_valid(u1) else 0,
		"player_1_y": u1.grid_position.y if is_instance_valid(u1) else 0,
		"player_1_statuses": u1.serialize_statuses() if is_instance_valid(u1) else [],
	}

func _coop_build_card_result_payload(card: CardData) -> Dictionary:
	var u0 = _coop_get_player_unit_by_index(0)
	var u1 = _coop_get_player_unit_by_index(1)
	var enemy_hps: Array = []
	var enemy_statuses: Array = []
	var enemy_blocks: Array = []
	for e in _all_enemy_units_ordered:
		if is_instance_valid(e):
			enemy_hps.append(e.current_health)
			enemy_statuses.append(e.serialize_statuses())
			enemy_blocks.append(e.current_block)
		else:
			enemy_hps.append(0)
			enemy_statuses.append([])
			enemy_blocks.append(0)
	var payload = {
		"card_path": card.resource_path,
		"source_unit_index": _coop_get_player_unit_index(_player_unit_node),
		"enemy_hps": enemy_hps,
		"enemy_statuses": enemy_statuses,
		"enemy_blocks": enemy_blocks,
		"player_0_hp": u0.current_health if is_instance_valid(u0) else 0,
		"player_0_block": u0.current_block if is_instance_valid(u0) else 0,
		"player_0_statuses": u0.serialize_statuses() if is_instance_valid(u0) else [],
		"player_1_hp": u1.current_health if is_instance_valid(u1) else 0,
		"player_1_block": u1.current_block if is_instance_valid(u1) else 0,
		"player_1_statuses": u1.serialize_statuses() if is_instance_valid(u1) else [],
	}
	return payload

@rpc("any_peer", "call_remote")
func _rpc_apply_card_result(payload: Dictionary):
	if not _is_coop_run() or payload.is_empty():
		return
	# Aplikovat stav po odehrané kartě – HP, block, statusy pro všechny jednotky
	var enemy_hps: Array = payload.get("enemy_hps", [])
	var enemy_statuses: Array = payload.get("enemy_statuses", [])
	var enemy_blocks: Array = payload.get("enemy_blocks", [])
	for i in range(enemy_hps.size()):
		if i >= _all_enemy_units_ordered.size():
			break
		var enemy = _all_enemy_units_ordered[i]
		if not is_instance_valid(enemy):
			continue
		var target_hp: int = int(enemy_hps[i])
		var d = enemy.current_health - target_hp
		if d > 0:
			await enemy.take_damage(d, true, true)  # is_rpc_sync=true: nepřerolovat dodge
		# Block
		if i < enemy_blocks.size():
			enemy.current_block = int(enemy_blocks[i])
		# Statusy
		if i < enemy_statuses.size() and enemy_statuses[i] is Array:
			enemy.deserialize_statuses(enemy_statuses[i])
	var u0 = _coop_get_player_unit_by_index(0)
	var u1 = _coop_get_player_unit_by_index(1)
	if is_instance_valid(u0):
		u0.current_health = int(payload.get("player_0_hp", u0.current_health))
		u0.current_block = int(payload.get("player_0_block", u0.current_block))
		var p0_statuses: Array = payload.get("player_0_statuses", [])
		if not p0_statuses.is_empty():
			u0.deserialize_statuses(p0_statuses)
		else:
			u0._update_stats_and_emit_signal()
	if is_instance_valid(u1):
		u1.current_health = int(payload.get("player_1_hp", u1.current_health))
		u1.current_block = int(payload.get("player_1_block", u1.current_block))
		var p1_statuses: Array = payload.get("player_1_statuses", [])
		if not p1_statuses.is_empty():
			u1.deserialize_statuses(p1_statuses)
		else:
			u1._update_stats_and_emit_signal()
	# Coop: aktualizuj PlayerData.current_hp podle snapshotu pro MOU jednotku
	_coop_sync_player_data_from_unit()
	# NEMĚNÍME PlayerData.current_energy ani deck – každý peer má vlastní energii a balíček.
	# Klient NEPŘEPOČÍTÁVÁ intenty – ty přijdou s enemy turn snapshotem.

@rpc("any_peer", "call_remote")
func _rpc_apply_enemy_turn_result(payload: Dictionary):
	if not _is_coop_run() or payload.is_empty():
		return
	var enemy_hps: Array = payload.get("enemy_hps", [])
	var enemy_pos: Array = payload.get("enemy_pos", [])
	var enemy_statuses: Array = payload.get("enemy_statuses", [])
	var enemy_intents: Array = payload.get("enemy_intents", [])
	var enemy_ai_meta: Array = payload.get("enemy_ai_meta", [])
	var enemy_blocks: Array = payload.get("enemy_blocks", [])
	# Stabilní indexy _all_enemy_units_ordered – pozice, HP, statusy, intenty, AI meta
	for i in range(enemy_pos.size()):
		if i >= _all_enemy_units_ordered.size():
			break
		var enemy = _all_enemy_units_ordered[i]
		if not is_instance_valid(enemy):
			continue
		var pos_dict = enemy_pos[i] if enemy_pos[i] is Dictionary else {}
		var nx = int(pos_dict.get("x", enemy.grid_position.x))
		var ny = int(pos_dict.get("y", enemy.grid_position.y))
		var new_cell = Vector2i(nx, ny)
		if new_cell != enemy.grid_position:
			battle_grid_instance.remove_object_by_instance(enemy)
			battle_grid_instance.place_object_on_cell(enemy, new_cell, true)
	for i in range(enemy_hps.size()):
		if i >= _all_enemy_units_ordered.size():
			break
		var enemy = _all_enemy_units_ordered[i]
		if not is_instance_valid(enemy):
			continue
		var target_hp: int = int(enemy_hps[i])
		var d = enemy.current_health - target_hp
		if d > 0:
			await enemy.take_damage(d, true, true)  # is_rpc_sync=true: nepřerolovat dodge
		# Block
		if i < enemy_blocks.size():
			enemy.current_block = int(enemy_blocks[i])
		# Statusy
		if i < enemy_statuses.size() and enemy_statuses[i] is Array:
			enemy.deserialize_statuses(enemy_statuses[i])
		# AI meta
		if i < enemy_ai_meta.size() and enemy_ai_meta[i] is Dictionary:
			enemy.apply_ai_meta(enemy_ai_meta[i])
		# Intent (klient nepočítá lokálně, přebírá od hosta)
		if i < enemy_intents.size() and enemy_intents[i] is Dictionary:
			enemy.apply_intent_from_data(enemy_intents[i])
	# Player units
	var u0 = _coop_get_player_unit_by_index(0)
	var u1 = _coop_get_player_unit_by_index(1)
	if is_instance_valid(u0):
		u0.current_health = int(payload.get("player_0_hp", u0.current_health))
		u0.current_block = int(payload.get("player_0_block", u0.current_block))
		var px = int(payload.get("player_0_x", u0.grid_position.x))
		var py = int(payload.get("player_0_y", u0.grid_position.y))
		var pc = Vector2i(px, py)
		if pc != u0.grid_position:
			battle_grid_instance.remove_object_by_instance(u0)
			battle_grid_instance.place_object_on_cell(u0, pc, true)
		var p0_statuses: Array = payload.get("player_0_statuses", [])
		if not p0_statuses.is_empty():
			u0.deserialize_statuses(p0_statuses)
		else:
			u0._update_stats_and_emit_signal()
	if is_instance_valid(u1):
		u1.current_health = int(payload.get("player_1_hp", u1.current_health))
		u1.current_block = int(payload.get("player_1_block", u1.current_block))
		var px = int(payload.get("player_1_x", u1.grid_position.x))
		var py = int(payload.get("player_1_y", u1.grid_position.y))
		var pc = Vector2i(px, py)
		if pc != u1.grid_position:
			battle_grid_instance.remove_object_by_instance(u1)
			battle_grid_instance.place_object_on_cell(u1, pc, true)
		var p1_statuses: Array = payload.get("player_1_statuses", [])
		if not p1_statuses.is_empty():
			u1.deserialize_statuses(p1_statuses)
		else:
			u1._update_stats_and_emit_signal()
	# Coop: aktualizuj PlayerData.current_hp podle snapshotu pro MOU jednotku
	_coop_sync_player_data_from_unit()
	var enemy_turn_idx: int = int(payload.get("enemy_turn_index", 0))
	if enemy_turn_idx >= 0 and enemy_turn_idx < _all_enemy_units_ordered.size():
		var e = _all_enemy_units_ordered[enemy_turn_idx]
		if is_instance_valid(e) and e.has_method("end_turn"):
			e.end_turn()
	if has_node("/root/TurnManager"):
		TurnManager.next_turn()

@rpc("any_peer", "call_remote")
func _rpc_apply_move(unit_index: int, cell_x: int, cell_y: int):
	if not _is_coop_run():
		return
	var unit = _coop_get_player_unit_by_index(unit_index)
	if not is_instance_valid(unit) or not battle_grid_instance:
		return
	var target_cell = Vector2i(cell_x, cell_y)
	# Peer already resolved path + terrain on the mover side; just snap to final cell.
	# Re-process landing terrain only if still present (consume may have already happened locally).
	unit.use_move_action()
	battle_grid_instance.remove_object_by_instance(unit)
	battle_grid_instance.place_object_on_cell(unit, target_cell, true)
	var terrain_on_cell = battle_grid_instance.get_terrain_on_cell(target_cell)
	if is_instance_valid(terrain_on_cell) and unit.has_method("process_terrain_effects"):
		var dmg_dealt = await unit.process_terrain_effects(terrain_on_cell)
		var should_consume = terrain_on_cell.consume_on_trigger
		if terrain_on_cell.effect_type == TerrainData.TerrainEffect.DAMAGE_ON_ENTER or should_consume:
			var unit_label = unit.unit_data.unit_id if unit.unit_data else str(unit.name)
			DebugLogger.log_info("Trap triggered on %s at %s: %d damage, consumed=%s (terrain=%s)" % [
				unit_label, str(target_cell), dmg_dealt, str(should_consume), terrain_on_cell.terrain_id
			])
		if should_consume:
			battle_grid_instance.remove_terrain(target_cell)
	set_enemy_intents()

@rpc("any_peer", "call_remote")
func _rpc_coop_sync_my_unit_state(player_index: int, hp: int, block: int):
	"""Přijme stav jednotky od druhého peera (po artefaktech).
	Díky tomu host ví o klientově blocku a nepřátelé počítají damage správně."""
	if not _is_coop_run():
		return
	var unit = _coop_get_player_unit_by_index(player_index)
	if not is_instance_valid(unit):
		return
	unit.current_health = hp
	unit.current_block = block
	unit._update_stats_and_emit_signal()
	DebugLogger.log_debug("Coop sync unit state: player_%d hp=%d block=%d" % [player_index, hp, block])

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
	"""Zpracuje speciální akce AI (všechny typy)"""
	var special_type = action.special_data.get("type", "")
	
	match special_type:
		# ===== MAGE SPELLS =====
		"meteor":
			enemy_unit.show_status_text("METEORIT!", "critical")
			await get_tree().create_timer(1.0).timeout
			
			var base_dmg = enemy_unit.unit_data.attack_damage
			var extra = base_dmg
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			
			for unit in all_units:
				if unit is Unit:
					var damage = DamageCalculator.get_final_damage(
						base_dmg, enemy_unit, unit,
						CardEffectData.DamageType.NORMAL, false, false, extra
					)
					await unit.take_damage(damage, true)
					unit.apply_status("burning", 2, 3)
		
		"teleport":
			# Mage teleport - blink na cílovou pozici (landing spouští past)
			var target_pos = action.special_data.get("target_position", Vector2i(-1, -1))
			if target_pos != Vector2i(-1, -1):
				await _teleport_unit_to_cell(enemy_unit, target_pos)
				if not is_instance_valid(enemy_unit) or enemy_unit.current_health <= 0:
					return
		
		"arcane_shield":
			# Mage dá sobě block
			var block_amount = action.special_data.get("block_amount", 5)
			enemy_unit.add_block(block_amount)
			enemy_unit.show_status_text("SHIELD +%d!" % block_amount, "heal")
		
		# ===== DRUID SPELLS =====
		"spawn_spirit":
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
					if spirit_node.unit_data:
						spirit_node.unit_data.faction = UnitData.Faction.ENEMY
					_enemy_units.append(spirit_node)
					_all_enemy_units_ordered.append(spirit_node)
					spirit_node.died.connect(_on_unit_died)
					spirit_node.stats_changed.connect(_on_unit_stats_changed)
					if has_node("/root/TurnManager"):
						TurnManager.add_unit(spirit_node)
					set_enemy_intents()
		
		"entangle":
			# Druid kořeny - hráč nemůže se pohnout 1 kolo
			var target = action.special_data.get("target")
			if is_instance_valid(target) and target is Unit:
				var duration = action.special_data.get("duration", 1)
				target.apply_status("entangled", 1, duration)
				target.show_status_text("ENTANGLED!", "critical")
		
		"natures_grasp":
			# Druid - zpomalení na pozici hráče (simulace mud)
			var target_pos = action.special_data.get("target_position", Vector2i(-1, -1))
			if target_pos != Vector2i(-1, -1):
				# Aplikuj zpomalení na hráče pokud je na té pozici
				var unit_on_cell = battle_grid_instance.get_object_on_cell(target_pos)
				if is_instance_valid(unit_on_cell) and unit_on_cell is Unit:
					unit_on_cell.apply_status("chilled", 1, 2)
					unit_on_cell.show_status_text("SLOWED!", "critical")
		
		# ===== MONK ABILITIES =====
		"buff_ally":
			var target = action.special_data.get("target")
			if is_instance_valid(target) and target is Unit:
				var bonus = action.special_data.get("damage_bonus", 3)
				var duration = action.special_data.get("duration", 3)
				target.apply_status("monk_blessing", bonus, duration)
				target.show_status_text("BLESSED +%d!" % bonus, "heal")
		
		"war_cry":
			# Monk AoE buff pro všechny spojence v dosahu
			var buff_range = action.special_data.get("range", 2)
			var bonus = action.special_data.get("damage_bonus", 1)
			var duration = action.special_data.get("duration", 2)
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			for unit in all_units:
				if unit is Unit and unit != enemy_unit and is_instance_valid(unit):
					if unit.unit_data.faction == enemy_unit.unit_data.faction:
						var dist = battle_grid_instance.get_distance(enemy_unit.grid_position, unit.grid_position)
						if dist <= buff_range:
							unit.apply_status("monk_blessing", bonus, duration)
							unit.show_status_text("INSPIRED!", "heal")
		
		"meditate":
			# Monk self-heal
			var heal_amount = action.special_data.get("heal_amount", 5)
			enemy_unit.heal(heal_amount)
			enemy_unit.show_status_text("MEDITATE +%d!" % heal_amount, "heal")
		
		# ===== HEALER ABILITIES =====
		"heal_ally":
			var target = action.special_data.get("target")
			if is_instance_valid(target) and target is Unit:
				var heal_amount = action.special_data.get("heal_amount", 8)
				target.heal(heal_amount)
				target.show_status_text("HEALED +%d!" % heal_amount, "heal")
		
		"protection":
			# Healer dá block spojenci
			var target = action.special_data.get("target")
			if is_instance_valid(target) and target is Unit:
				var block_amount = action.special_data.get("block_amount", 4)
				target.add_block(block_amount)
				target.show_status_text("PROTECTED +%d!" % block_amount, "heal")
		
		"holy_nova":
			# Healer AoE heal pro spojence v dosahu
			var heal_range = action.special_data.get("range", 3)
			var heal_amount = action.special_data.get("heal_amount", 4)
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			for unit in all_units:
				if unit is Unit and unit != enemy_unit and is_instance_valid(unit):
					if unit.unit_data.faction == enemy_unit.unit_data.faction:
						var dist = battle_grid_instance.get_distance(enemy_unit.grid_position, unit.grid_position)
						if dist <= heal_range:
							unit.heal(heal_amount)
							unit.show_status_text("HEALED +%d!" % heal_amount, "heal")
		
		# ===== BERSERKER ABILITIES =====
		"tremor":
			# Berserker AoE kolem sebe - damage všem v dosahu
			enemy_unit.show_status_text("TREMOR!", "critical")
			await get_tree().create_timer(0.5).timeout
			var tremor_range = action.special_data.get("range", 2)
			var mult = action.special_data.get("damage_multiplier", 0.5)
			var base_dmg = enemy_unit.unit_data.attack_damage
			var extra = _damage_multiplier_to_extra(enemy_unit, mult)
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			for unit in all_units:
				if unit is Unit and unit != enemy_unit and is_instance_valid(unit):
					if unit.unit_data.faction != enemy_unit.unit_data.faction:
						var dist = battle_grid_instance.get_distance(enemy_unit.grid_position, unit.grid_position)
						if dist <= tremor_range:
							var damage = DamageCalculator.get_final_damage(
								base_dmg, enemy_unit, unit,
								CardEffectData.DamageType.NORMAL, false, false, extra
							)
							await unit.take_damage(damage, true)
							if unit == _player_unit_node:
								_took_damage_last_turn = true
		
		# ===== BOSS ABILITIES =====
		"dark_slash":
			# Boss line attack - damage v přímce
			var target = action.special_data.get("target")
			if is_instance_valid(target) and target is Unit:
				var mult = action.special_data.get("damage_multiplier", 1.5)
				var extra = _damage_multiplier_to_extra(enemy_unit, mult)
				await enemy_unit.attack(target, extra, CardEffectData.DamageType.NORMAL, false)
				if target == _player_unit_node:
					_took_damage_last_turn = true
		
		"shadow_dash":
			# Boss blink vedle hráče (landing spouští past)
			var target_pos = action.special_data.get("target_position", Vector2i(-1, -1))
			if target_pos != Vector2i(-1, -1):
				await _teleport_unit_to_cell(enemy_unit, target_pos)
				if not is_instance_valid(enemy_unit) or enemy_unit.current_health <= 0:
					return

		"shadow_strike":
			# Assassin blink na útočnou pozici
			var target_pos = action.special_data.get("target_position", Vector2i(-1, -1))
			if target_pos != Vector2i(-1, -1):
				if enemy_unit.can_move():
					enemy_unit.use_move_action()
				await _teleport_unit_to_cell(enemy_unit, target_pos)
				if not is_instance_valid(enemy_unit) or enemy_unit.current_health <= 0:
					return
		
		"hellfire":
			# Boss AoE kolem sebe
			enemy_unit.show_status_text("HELLFIRE!", "critical")
			await get_tree().create_timer(0.5).timeout
			var hellfire_range = action.special_data.get("range", 2)
			var mult = action.special_data.get("damage_multiplier", 1.8)
			var base_dmg = enemy_unit.unit_data.attack_damage
			var extra = _damage_multiplier_to_extra(enemy_unit, mult)
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			for unit in all_units:
				if unit is Unit and unit != enemy_unit and is_instance_valid(unit):
					if unit.unit_data.faction != enemy_unit.unit_data.faction:
						var dist = battle_grid_instance.get_distance(enemy_unit.grid_position, unit.grid_position)
						if dist <= hellfire_range:
							var damage = DamageCalculator.get_final_damage(
								base_dmg, enemy_unit, unit,
								CardEffectData.DamageType.NORMAL, false, false, extra
							)
							await unit.take_damage(damage, true)
							unit.apply_status("burning", 2, 2)
							if unit == _player_unit_node:
								_took_damage_last_turn = true
		
		"dark_barrier":
			# Boss dá sobě block na začátku tahu
			var block_amount = action.special_data.get("block_amount", 8)
			enemy_unit.add_block(block_amount)
			enemy_unit.show_status_text("DARK BARRIER +%d!" % block_amount, "heal")
		
		"demon_aura":
			# Boss pasivní damage na blízké nepřátele
			var target = action.special_data.get("target")
			var aura_dmg = action.special_data.get("damage", 2)
			if is_instance_valid(target) and target is Unit:
				await target.take_damage(aura_dmg, true)
				target.show_status_text("AURA -%d!" % aura_dmg, "critical")
				if target == _player_unit_node:
					_took_damage_last_turn = true
		
		# ===== ASSASSIN ABILITIES =====
		"disengage":
			# Assassin ústup po útoku — projít každou buňku cesty (pasti, mud)
			var disengage_path = action.special_data.get("move_path", [])
			if disengage_path is Array and disengage_path.size() > 1:
				var move_dist = min(disengage_path.size() - 1, 2)  # Max 2 pole ústup
				var truncated: Array[Vector2i] = []
				for i in range(move_dist + 1):
					truncated.append(disengage_path[i])
				await _dash_unit_along_path(enemy_unit, truncated)
				if not is_instance_valid(enemy_unit) or enemy_unit.current_health <= 0:
					return
		
		# ===== DARK BEAST ABILITIES =====
		"howl":
			# DarkBeast buff pro všechny beast spojence
			enemy_unit.show_status_text("HOWL!", "critical")
			await get_tree().create_timer(0.5).timeout
			var buff_amount = action.special_data.get("buff_amount", 2)
			var duration = action.special_data.get("duration", 3)
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			for unit in all_units:
				if unit is Unit and unit != enemy_unit and is_instance_valid(unit):
					if unit.unit_data.faction == enemy_unit.unit_data.faction:
						unit.apply_status("monk_blessing", buff_amount, duration)
						unit.show_status_text("EMPOWERED!", "heal")
		
		_:
			print("Neznámý typ speciální akce: %s" % special_type)

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
