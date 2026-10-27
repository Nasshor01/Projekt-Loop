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

@export_group("Screen Shake")
## Max camera offset (orthographic world units) at full trauma.
@export var shake_max_offset: float = 0.35
## Trauma lost per second (1.0 = full shake fades in 1 s).
@export var shake_decay: float = 2.2
var _shake_trauma: float = 0.0
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
@onready var win_button: Button = $CanvasLayer/WinButton
@onready var battle_grid_instance: BattleGrid = $BattleGrid
@onready var turn_counter_label: Label = $CanvasLayer/TurnCounterLabel
@onready var initiative_bar = $CanvasLayer/InitiativeBar
@onready var card_tooltip: CardTooltip = $CanvasLayer/CardTooltip

## STS2-style artifact interact — layout lives in BattleScene.tscn under ArtifactInteractUI.
## HandPrompt (above hand) = Alchemist / Chalice. SidePrompt (right) = All-Seeing Eye.
var _artifact_interact_mode: String = "" # "", "alchemist", "chalice", "eye"
var _artifact_interact_waiting: bool = false
@onready var _artifact_interact_root: Control = %ArtifactInteractUI
@onready var _artifact_hand_prompt: Control = %HandPrompt
@onready var _artifact_side_prompt: Control = %SidePrompt
@onready var _artifact_title_label: Label = %TitleLabel
@onready var _artifact_body_label: Label = %BodyLabel
@onready var _artifact_drink_btn: Button = %DrinkButton
@onready var _artifact_skip_btn: Button = %SkipButton
@onready var _artifact_side_title_label: Label = %SideTitleLabel
@onready var _artifact_side_body_label: Label = %SideBodyLabel
@onready var _artifact_side_skip_btn: Button = %SideSkipButton

@export var camera_3d: Camera3D 

enum PlayerActionState { IDLE, CARD_SELECTED, UNIT_SELECTED }
var _player_action_state: PlayerActionState = PlayerActionState.IDLE

enum BattleState { SETUP, AWAITING_PLAYER_SPAWN, PLAYER_TURN, ENEMY_TURN, PROCESSING, BATTLE_OVER }
var _current_battle_state: BattleState = BattleState.SETUP

@export var starting_hand_size: int = 5

var _selected_card_ui: Control = null
var _selected_card_data: CardData = null
var _damage_preview_units: Array[Unit] = []
var _damage_preview_key: String = ""
var _damage_preview_results: Dictionary = {}
## Above the hand (CanvasLayer 2) so neither the arrow nor its readout hides under cards.
const TARGETING_ARROW_LAYER := 3
const ARROW_ATTACK_COLOR := Color(1.0, 0.32, 0.26)
const ARROW_UTILITY_COLOR := Color(0.45, 0.85, 1.0)
const ARROW_INVALID_COLOR := Color(0.62, 0.62, 0.68, 0.75)
## Dragged targeted card parks at the bottom once the cursor rises above this fraction of screen height.
@export var arrow_park_screen_ratio: float = 0.7
var _targeting_arrow: TargetingArrow = null
var _targeting_arrow_active: bool = false
var _interpose_lines: Array[Line2D] = []
var _arrow_card_id: int = 0
var _arrow_valid_cells: Array = []
var _arrow_is_attack: bool = true
var _arrow_uses_arrow: bool = false
const TURN_BANNER_FONT := preload("res://art/fonts/Ithaca-LVB75.ttf")
## Just below the InitiativeBar (offset_top 80 .. offset_bottom 172).
const TURN_BANNER_TOP := 196.0
const TURN_BANNER_HOLD := 0.75
const TURN_BANNER_PLAYER_COLOR := Color(1.0, 0.85, 0.35)
const TURN_BANNER_ENEMY_COLOR := Color(1.0, 0.45, 0.4)
## „Čelíš:“ pruh: pod turn bannerem, ať se nepřekrývají, když hned začne první tah.
const ENCOUNTER_INTRO_TOP := 270.0
const ENCOUNTER_INTRO_HOLD := 2.2
var _encounter_intro_panel: PanelContainer = null
var _turn_banner: PanelContainer = null
var _turn_banner_label: Label = null
var _turn_banner_tween: Tween = null
const END_TURN_PULSE_COLOR := Color(1.35, 1.2, 0.75)
const END_TURN_PULSE_SCALE := Vector2(1.06, 1.06)
const END_TURN_PULSE_HALF_PERIOD := 0.55
## Cached by _refresh_hand_playability so the per-frame pulse check stays cheap.
var _hand_has_playable_card: bool = false
var _end_turn_pulse_tween: Tween = null
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
var _last_drawn_card: CardData = null
var _is_drawing_cards: bool = false
var _drawing_turn_start_hand: bool = false  # true jen při normálním dorbírání na začátku tahu (ne mid-turn DRAW_CARDS)
var _is_first_turn: bool = true
var _current_turn_number: int = 0
var _is_extra_turn: bool = false
var _cards_played_this_turn: Dictionary = {}  # Tracking karet za tah pro limit použití
var _took_damage_last_turn: bool = false  # Tracking poškození pro consecrated_barrier
var _holy_damage_this_turn: int = 0  # Skutečné svaté poškození (blok + HP) nepřátelům tento tah — Aegis
var _on_kill_paid_this_play: bool = false  # "on_kill" energie max. jednou za zahranou kartu (i se Září)
var _current_tooltip_card_data: CardData = null
var _terrain_hover_panel: PanelContainer
var _terrain_hover_label: Label
var _terrain_hover_cell: Vector2i = Vector2i(-999, -999)
## Avoid rebuilding All-Seeing Eye ranges every frame while mouse is off enemies.
var _last_enemy_info_hover: Node = null
var _last_enemy_range_shown: Node = null
var _enemy_intent_overlay_on: bool = false
# Coop: true = můj tah, false = tah spoluhráče (pouze když _is_coop_run())
var _coop_my_turn: bool = true
var _coop_spectator_mode: bool = false  # Coop: můj paladin zemřel, jsem divák
# Coop výběr spawnu: 0 = host vybírá, 1 = klient vybírá
var _coop_spawn_phase: int = 0
var _coop_host_spawn_cell: Vector2i = Vector2i(-1, -1)
var _coop_client_spawn_cell: Vector2i = Vector2i(-1, -1)

func _ready():
	add_to_group("battle_scene")
	_apply_web_battle_quality()
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

	_wire_artifact_interact_ui()
	_build_targeting_arrow()
	_build_turn_banner()
	call_deferred("_show_encounter_intro")
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
	call_deferred("_reserve_artifacts_below_initiative")

func _exit_tree() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and is_instance_valid(gm.global_ui_instance) and gm.global_ui_instance.has_method("release_top_reservation"):
		gm.global_ui_instance.release_top_reservation()

func _reserve_artifacts_below_initiative() -> void:
	if not is_instance_valid(initiative_bar):
		return
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or not is_instance_valid(gm.global_ui_instance):
		return
	if not gm.global_ui_instance.has_method("reserve_space_below"):
		return
	var rect: Rect2 = initiative_bar.get_global_rect()
	var bottom_y: float = rect.position.y + rect.size.y
	if rect.size.y < 1.0:
		bottom_y = initiative_bar.offset_bottom
	gm.global_ui_instance.reserve_space_below(bottom_y)

func _apply_web_battle_quality() -> void:
	if not OS.has_feature("web"):
		return
	var space := get_node_or_null("SpaceBackground")
	if space:
		space.visible = false
	var light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.shadow_enabled = false

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

	# 3. APLIKACE SMOOTH (frame-rate nezávislé – plynulé jako na 60 FPS)
	# 1 - exp(-k*dt) = stejná „dobrá“ plynulost při jakémkoliv FPS
	var t: float = 1.0 - exp(-camera_smoothness * delta)
	camera_3d.position = camera_3d.position.lerp(_cam_target_pos, t)
	var current_rot = camera_3d.rotation
	current_rot.y = lerp_angle(current_rot.y, _cam_target_rot_y, t)
	current_rot.x = lerp_angle(current_rot.x, _cam_target_rot_x, t)
	camera_3d.rotation = current_rot
	camera_3d.size = lerp(camera_3d.size, _cam_target_zoom, t)
	_update_screen_shake(delta)
	
	# 4. RAYCAST UPDATE PRO HOVER
	var grid_cell = get_grid_cell_under_mouse()
	battle_grid_instance.set_mouse_over_cell(grid_cell)
	
	var unit_under_mouse = battle_grid_instance.get_object_on_cell(grid_cell)
	_refresh_enemy_info_hover(unit_under_mouse, true)
	_refresh_terrain_hover(grid_cell, unit_under_mouse)
		
	if _player_action_state == PlayerActionState.CARD_SELECTED:
		if _selected_card_data and not PlayerData.current_hand.has(_selected_card_data):
			_reset_player_selection()
		else:
			_update_card_target_preview()
			if _current_battle_state == BattleState.PLAYER_TURN:
				_update_targeting_arrow(grid_cell)
				_update_card_damage_preview(grid_cell)
				_update_targeting_arrow_readout(grid_cell)
			else:
				_clear_card_damage_preview()
				_hide_targeting_arrow()
	else:
		if not _damage_preview_units.is_empty():
			_clear_card_damage_preview()
		if _targeting_arrow_active:
			_hide_targeting_arrow()
	_update_interpose_lines()
	_update_end_turn_pulse()

## Called by Unit.take_damage. Trauma stacks; offset scales with trauma² so small hits stay subtle.
func add_screen_shake(hp_lost: int, block_lost: int, target_is_player: bool) -> void:
	var amount := 0.0
	if hp_lost > 0:
		amount = 0.2 + float(hp_lost) / 25.0
		if target_is_player:
			amount += 0.15
	elif block_lost > 0:
		amount = 0.08
	_shake_trauma = clampf(_shake_trauma + minf(amount, 0.75), 0.0, 1.0)

## Uses h_offset/v_offset so it never fights the camera position lerp; picking rays follow the offset.
func _update_screen_shake(delta: float) -> void:
	if _shake_trauma <= 0.0:
		if camera_3d.h_offset != 0.0 or camera_3d.v_offset != 0.0:
			camera_3d.h_offset = 0.0
			camera_3d.v_offset = 0.0
		return
	_shake_trauma = maxf(0.0, _shake_trauma - shake_decay * delta)
	var strength := _shake_trauma * _shake_trauma * shake_max_offset
	camera_3d.h_offset = randf_range(-1.0, 1.0) * strength
	camera_3d.v_offset = randf_range(-1.0, 1.0) * strength

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

		# All-Seeing Eye deny pick: click an enemy on the grid
		if _artifact_interact_mode == "eye" and _artifact_interact_waiting:
			var picked = _resolve_living_unit_on_cell(clicked_grid_cell)
			if is_instance_valid(picked) and picked is Unit and picked.get_unit_data().faction == UnitData.Faction.ENEMY:
				ArtifactManager.apply_prompt_result({
					"prompt_id": "all_seeing_deny",
					"accepted": true,
					"enemy": picked,
				})
				_finish_artifact_interact()
				get_viewport().set_input_as_handled()
				return
		
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

	if is_instance_valid(initiative_bar):
		if initiative_bar.has_method("refresh_from_turn_manager"):
			initiative_bar.refresh_from_turn_manager()
		elif has_node("/root/TurnManager"):
			initiative_bar.update_turn_order(TurnManager.get_turn_order())
	if is_instance_valid(battle_grid_instance) and battle_grid_instance.has_method("tick_shards"):
		battle_grid_instance.tick_shards()

func _on_turn_started(unit: Unit):
	"""Volá se když je na řadě další jednotka"""
	if is_instance_valid(initiative_bar):
		if initiative_bar.has_method("refresh_from_turn_manager"):
			initiative_bar.refresh_from_turn_manager()
		initiative_bar.set_active_unit(unit)

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
		var is_teammate: bool = _is_coop_run() and unit.has_meta("owner_peer_id") \
				and unit.get_meta("owner_peer_id") != multiplayer.get_unique_id()
		if is_teammate:
			_show_turn_banner(tr("ui.battle.coop_teammate_turn"), TURN_BANNER_PLAYER_COLOR)
		else:
			_show_turn_banner(tr("ui.battle.banner_your_turn"), TURN_BANNER_PLAYER_COLOR)
		_start_player_initiative_turn(unit, extra_draw)
	else:
		# Skipped enemy rounds (Heart of the Loop) would otherwise flash a banner per enemy.
		if not (has_node("/root/ArtifactManager") and ArtifactManager.get_run_flag("skip_enemy_round", false)):
			_show_turn_banner(TranslationHelper.tr_format("ui.battle.banner_enemy_turn",
					{"name": unit.unit_data.get_localized_name()}), TURN_BANNER_ENEMY_COLOR)
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
		if initiative_bar.has_method("refresh_from_turn_manager"):
			initiative_bar.refresh_from_turn_manager()
		elif initiative_bar.has_method("refresh_initiatives"):
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
	_holy_damage_this_turn = 0
	
	# POZNÁMKA: Tracking poškození se NERESETUJE na začátku tahu, ale na konci tahu hráče
	# aby karta consecrated_barrier mohla správně zkontrolovat, zda hráč utrpěl poškození v předchozím tahu
	
	# Reset energie
	PlayerData.reset_energy()
	
	# START_OF_TURN artefakty
	if has_node("/root/ArtifactManager"):
		if ArtifactManager.get_run_flag("skip_enemy_round", false):
			ArtifactManager.set_run_flag("skip_enemy_round", false)
		ArtifactManager.on_turn_start()
	
	# Coop: po artefaktech pošli stav své jednotky druhému peerovi,
	# aby host měl správný block (např. Srdce draka) před útoky nepřátel.
	if _is_coop_run() and is_instance_valid(_player_unit_node):
		var my_idx = _coop_get_player_unit_index(_player_unit_node)
		rpc("_rpc_coop_sync_my_unit_state", my_idx, _player_unit_node.current_health, _player_unit_node.current_block)
	
	# Dober karty
	_drawing_turn_start_hand = true
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

	# Heart of the Loop / similar: skip entire enemy round
	if has_node("/root/ArtifactManager") and ArtifactManager.get_run_flag("skip_enemy_round", false):
		await get_tree().create_timer(0.2).timeout
		TurnManager.next_turn()
		return

	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_enemy_turn_start(enemy_unit)

	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(enemy_unit) and enemy_unit.current_health > 0:
		await _process_enemy_actions(enemy_unit)
	await get_tree().create_timer(0.4).timeout
	
	# Jednotka mohla zemřít během akce (např. past DAMAGE_ON_ENTER)
	if is_instance_valid(enemy_unit) and enemy_unit.current_health > 0:
		await enemy_unit.end_turn()
	
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
	
	# Taunt: force Fighter-style approach (overrides kite/root AI for this turn).
	# Core and cocoon keep their own turn — a taunt must not make the core swing or the egg walk.
	var actions: Array
	var pinned := enemy_unit.has_meta("armor_core") or (enemy_unit.unit_data != null and enemy_unit.unit_data.unit_id == "cocoon")
	if enemy_unit.active_statuses.has("taunted") and not pinned:
		var approach_ai = load("res://scripts/ai/FighterAI.gd").new()
		actions = approach_ai.get_actions(enemy_unit, player_units_array, battle_grid_instance)
		DebugLogger.log_info("Taunt: %s forced to approach" % [
			String(enemy_unit.unit_data.unit_id) if enemy_unit.unit_data else String(enemy_unit.name)
		])
	else:
		actions = ai_instance.get_actions(enemy_unit, player_units_array, battle_grid_instance)

	# All-Seeing Eye (and similar): deny MOVE/RUSH for one turn
	if enemy_unit.has_meta("artifact_deny_move_next_turn") and bool(enemy_unit.get_meta("artifact_deny_move_next_turn")):
		var filtered: Array = []
		for action in actions:
			if action.type == EnemyAIBase.AIAction.ActionType.MOVE or action.type == EnemyAIBase.AIAction.ActionType.RUSH:
				continue
			filtered.append(action)
		actions = filtered
		enemy_unit.remove_meta("artifact_deny_move_next_turn")
	
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

	_apply_enemy_turn_end_mechanics(enemy_unit, did_attack_or_rush)

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
				var extra = _action_damage_extra(enemy_unit, action)
				var dmg_type = CardEffectData.DamageType.HOLY if action.special_data.get("holy_damage", false) else CardEffectData.DamageType.NORMAL
				var deep_freeze := int(action.special_data.get("deep_freeze_bonus", 0))
				var had_slow := false
				var chain_from := action.target_unit.grid_position
				if deep_freeze > 0 and action.target_unit is Unit and (action.target_unit as Unit).active_statuses.has("Slow"):
					extra += deep_freeze
					had_slow = true
				await enemy_unit.attack(action.target_unit, extra, dmg_type, false)
				if action.special_data.get("chain_lightning", false):
					await _resolve_chain_lightning(enemy_unit, action.target_unit, chain_from, int(action.special_data.get("chain_damage", 0)))
				if action.special_data.get("frostbite", false) and is_instance_valid(action.target_unit) and action.target_unit is Unit:
					var slow_value := int(action.special_data.get("slow_value", -2))
					var slow_duration := int(action.special_data.get("slow_duration", 2))
					(action.target_unit as Unit).replace_status("Slow", slow_value, slow_duration)
					action.target_unit.show_status_text(tr("status.float.slow"), "frost", StatusIcons.get_icon("Slow"))
					if had_slow:
						enemy_unit.show_status_text("+3", "frost")
				if action.special_data.get("burning_touch", false) and is_instance_valid(action.target_unit) and action.target_unit is Unit and action.target_unit.current_health > 0:
					var burn_value := int(action.special_data.get("burn_value", 2))
					(action.target_unit as Unit).apply_status("burning", burn_value, 3)
					action.target_unit.show_status_text(tr("status.float.burning"), "ember", StatusIcons.get_icon("burning"))
				if action.special_data.get("piercing_thrust", false):
					var behind := _unit_directly_behind(enemy_unit, action.target_unit)
					if behind != null:
						var pierce_extra := int(action.special_data.get("pierce_extra", -3))
						await enemy_unit.attack(behind, pierce_extra, dmg_type, false)
				
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
						var extra = _action_damage_extra(enemy_unit, action)
						await enemy_unit.attack(action.target_unit, extra, CardEffectData.DamageType.NORMAL, false)
		
		EnemyAIBase.AIAction.ActionType.MOVE:
			if enemy_unit.can_move():
				enemy_unit.use_move_action()
				var path = action.move_path
				
				if path.size() > 1:
					var move_dist = min(path.size() - 1, enemy_unit.get_current_movement_range())
					var truncated: Array[Vector2i] = []
					truncated.append(path[0])
					for i in range(1, move_dist + 1):
						# Guard: never allow non-adjacent jumps (A* wrap bug / bad path data).
						if battle_grid_instance.get_distance(truncated[truncated.size() - 1], path[i]) != 1:
							DebugLogger.log_error("MOVE path jump blocked: %s -> %s (unit=%s)" % [
								str(truncated[truncated.size() - 1]), str(path[i]),
								String(enemy_unit.unit_data.unit_id) if enemy_unit.unit_data else "?"
							])
							break
						truncated.append(path[i])
					if truncated.size() > 1:
						if enemy_unit.unit_data != null and enemy_unit.unit_data.unit_id == "wraith":
							await _move_ethereal_along_path(enemy_unit, truncated)
						else:
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

	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_combat_end()

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
		var coop_spawn_points = battle_grid_instance.get_player_spawn_points(3)
		battle_grid_instance.show_player_spawn_points(coop_spawn_points)
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

func _apply_battle_start_heal() -> void:
	var start_heal := VillageBonuses.get_battle_start_heal()
	if start_heal > 0:
		PlayerData.heal(start_heal)


func _coop_spawn_two_players_at_positions(host_cell: Vector2i, client_cell: Vector2i):
	"""Coop: spawn na zadaných buňkách + barevné odlišení host/klient."""
	_apply_battle_start_heal()
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
		call_deferred("_resync_artifact_grid_visuals")
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
	label.text = tr("ui.battle.coop_you") if is_mine else tr("ui.battle.coop_teammate")
	label.position = Vector3(0, 1.6, 0)
	label.font_size = 63
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


func _resync_artifact_grid_visuals() -> void:
	"""Re-apply throne/crown/grove/line visuals once the grid is fully live."""
	if not has_node("/root/ArtifactManager"):
		return
	ArtifactManager.refresh_combat_visuals()

func confirm_player_spawn(at_position: Vector2i):
	battle_grid_instance.hide_player_spawn_points()
	
	spawn_player_unit_at(at_position)
	spawn_enemy_units()
	_place_terrain_features()
	
	# NOVÉ: Reset artefaktů na začátku souboje (PŘED prvním tahem)
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_combat_start()
		# One frame later: grid/camera are fully ready — re-paint zone markers.
		call_deferred("_resync_artifact_grid_visuals")

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
	_apply_battle_start_heal()
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

func _living_enemy_count() -> int:
	var n := 0
	for enemy in _enemy_units:
		if is_instance_valid(enemy) and enemy.current_health > 0:
			n += 1
	return n

func _apply_enemy_turn_end_mechanics(enemy_unit: Unit, did_attack_or_rush: bool) -> void:
	if not is_instance_valid(enemy_unit) or enemy_unit.unit_data == null or enemy_unit.unit_data.ai_script == null:
		return
	var ai_path := String(enemy_unit.unit_data.ai_script.resource_path)
	var gained_ritual := false
	if "SkeletonAI" in ai_path:
		enemy_unit.ritual_stacks += 1
		gained_ritual = true
	elif "ScoutAI" in ai_path and not did_attack_or_rush:
		enemy_unit.ritual_stacks += 1
		gained_ritual = true
	if gained_ritual:
		enemy_unit.show_status_text(
			TranslationHelper.tr_format("enemy.counter.ritual", {"value": enemy_unit.ritual_stacks}),
			"buff"
		)
	if is_instance_valid(_player_unit_node) and is_instance_valid(battle_grid_instance):
		enemy_unit.update_intent(_player_unit_node, battle_grid_instance)
	if enemy_unit.has_method("_update_stats_and_emit_signal"):
		enemy_unit._update_stats_and_emit_signal()

func _refresh_goblin_pack_bonuses() -> void:
	if not is_instance_valid(battle_grid_instance):
		return
	for enemy in _enemy_units:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if enemy.unit_data == null or enemy.unit_data.ai_script == null:
			continue
		if not String(enemy.unit_data.ai_script.resource_path).contains("GoblinAI"):
			continue
		GoblinAI.refresh_pack_bonus(enemy, battle_grid_instance)
		if is_instance_valid(_player_unit_node):
			enemy.update_intent(_player_unit_node, battle_grid_instance)
		if enemy.has_method("_update_stats_and_emit_signal"):
			enemy._update_stats_and_emit_signal()

func start_extra_turn():
	"""Spustí PLNOHODNOTNÝ extra tah hráče"""
	DebugLogger.log_info("SPOUŠTÍM EXTRA TAH!")
	_is_extra_turn = false # Reset flag
	_holy_damage_this_turn = 0
	_show_turn_banner(tr("ui.battle.banner_your_turn"), TURN_BANNER_PLAYER_COLOR)
	
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
	_drawing_turn_start_hand = true
	_cards_to_draw_queue = starting_hand_size
	_draw_next_card_in_queue()
	
	# 5. NASTAV SPRÁVNÝ STAV
	_current_battle_state = BattleState.PLAYER_TURN
	end_turn_button.disabled = false
	_set_enemy_intents_visible(true)
	set_enemy_intents()
	


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
		_last_drawn_card = new_card
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
	if _last_drawn_card:
		_process_card_trigger_effects(_last_drawn_card, CardEffectData.EffectTrigger.ON_DRAW)
		_last_drawn_card = null
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
	_update_pile_counts()
	# Mid-turn DRAW_CARDS: only refresh hand/piles — do not re-enter turn-start finish
	# (PLAYER_TURN / End Turn / on_hand_ready / Chalice modal).
	if not _drawing_turn_start_hand:
		_refresh_hand_playability()
		return
	_drawing_turn_start_hand = false
	_current_battle_state = BattleState.PLAYER_TURN
	end_turn_button.disabled = false
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_hand_ready()
		_sync_hand_ui_after_artifacts()
		await _run_sts2_artifact_interactions()
		_sync_hand_ui_after_artifacts()
		# Refresh cost/badge display after seal/retain/temp changes.
		if is_instance_valid(player_hand_ui_instance):
			for child in player_hand_ui_instance.get_children():
				if child is CardUI and child.has_method("update_display"):
					child.update_display()
	_refresh_hand_playability()


func _wire_artifact_interact_ui() -> void:
	if is_instance_valid(_artifact_interact_root):
		_artifact_interact_root.visible = false
	if is_instance_valid(_artifact_hand_prompt):
		_artifact_hand_prompt.visible = false
	if is_instance_valid(_artifact_side_prompt):
		_artifact_side_prompt.visible = false
	if is_instance_valid(_artifact_skip_btn) and not _artifact_skip_btn.pressed.is_connected(_on_artifact_skip_pressed):
		_artifact_skip_btn.pressed.connect(_on_artifact_skip_pressed)
	if is_instance_valid(_artifact_side_skip_btn) and not _artifact_side_skip_btn.pressed.is_connected(_on_artifact_skip_pressed):
		_artifact_side_skip_btn.pressed.connect(_on_artifact_skip_pressed)
	if is_instance_valid(_artifact_drink_btn) and not _artifact_drink_btn.pressed.is_connected(_on_artifact_drink_pressed):
		_artifact_drink_btn.pressed.connect(_on_artifact_drink_pressed)


func _run_sts2_artifact_interactions() -> void:
	if not has_node("/root/ArtifactManager"):
		return
	# Drain any leftover modal prompts (legacy) without showing them as boxes.
	while ArtifactManager.has_pending_prompts():
		ArtifactManager.pop_pending_prompt()

	if bool(ArtifactManager.get_run_flag("pending_alchemist_discard", false)):
		ArtifactManager.set_run_flag("pending_alchemist_discard", false)
		await _begin_artifact_interact("alchemist")
		_sync_hand_ui_after_artifacts()

	if bool(ArtifactManager.get_run_flag("pending_chalice", false)):
		ArtifactManager.set_run_flag("pending_chalice", false)
		await _begin_artifact_interact("chalice")
		_sync_hand_ui_after_artifacts()

	if bool(ArtifactManager.get_run_flag("pending_eye_deny", false)):
		ArtifactManager.set_run_flag("pending_eye_deny", false)
		await _begin_artifact_interact("eye")


func _begin_artifact_interact(mode: String) -> void:
	if not is_instance_valid(_artifact_interact_root):
		_artifact_interact_root = get_node_or_null("%ArtifactInteractUI") as Control
	if not is_instance_valid(_artifact_interact_root):
		push_error("BattleScene: ArtifactInteractUI missing — cannot show '%s' prompt" % mode)
		return
	if not is_instance_valid(_artifact_hand_prompt):
		_artifact_hand_prompt = get_node_or_null("%HandPrompt") as Control
	if not is_instance_valid(_artifact_side_prompt):
		_artifact_side_prompt = get_node_or_null("%SidePrompt") as Control
	if not is_instance_valid(_artifact_title_label):
		_artifact_title_label = get_node_or_null("%TitleLabel") as Label
	if not is_instance_valid(_artifact_body_label):
		_artifact_body_label = get_node_or_null("%BodyLabel") as Label
	if not is_instance_valid(_artifact_drink_btn):
		_artifact_drink_btn = get_node_or_null("%DrinkButton") as Button
	if not is_instance_valid(_artifact_skip_btn):
		_artifact_skip_btn = get_node_or_null("%SkipButton") as Button
	if not is_instance_valid(_artifact_side_title_label):
		_artifact_side_title_label = get_node_or_null("%SideTitleLabel") as Label
	if not is_instance_valid(_artifact_side_body_label):
		_artifact_side_body_label = get_node_or_null("%SideBodyLabel") as Label
	if not is_instance_valid(_artifact_side_skip_btn):
		_artifact_side_skip_btn = get_node_or_null("%SideSkipButton") as Button

	_artifact_interact_mode = mode
	_artifact_interact_waiting = true
	end_turn_button.disabled = true
	if is_instance_valid(win_button):
		win_button.visible = false
	_reset_player_selection()
	DebugLogger.log_info("Showing artifact interact UI: %s" % mode, "ARTIFACTS")

	var use_hand_prompt := mode == "alchemist" or mode == "chalice"
	if is_instance_valid(_artifact_hand_prompt):
		_artifact_hand_prompt.visible = use_hand_prompt
	if is_instance_valid(_artifact_side_prompt):
		_artifact_side_prompt.visible = not use_hand_prompt

	if use_hand_prompt:
		match mode:
			"alchemist":
				if is_instance_valid(_artifact_title_label):
					_artifact_title_label.text = tr("ui.artifact.alchemist.title")
				if is_instance_valid(_artifact_body_label):
					_artifact_body_label.text = tr("ui.artifact.alchemist.body")
				if is_instance_valid(_artifact_drink_btn):
					_artifact_drink_btn.visible = false
				_set_hand_drag_enabled(false)
			"chalice":
				if is_instance_valid(_artifact_title_label):
					_artifact_title_label.text = tr("ui.artifact.chalice.title")
				if is_instance_valid(_artifact_body_label):
					_artifact_body_label.text = tr("ui.artifact.chalice.body")
				if is_instance_valid(_artifact_drink_btn):
					_artifact_drink_btn.visible = true
					_artifact_drink_btn.text = tr("ui.artifact.chalice.accept")
		if is_instance_valid(_artifact_skip_btn):
			_artifact_skip_btn.visible = true
			_artifact_skip_btn.text = tr("ui.common.skip")
	else:
		if is_instance_valid(_artifact_side_title_label):
			_artifact_side_title_label.text = tr("ui.artifact.eye.deny_title")
		if is_instance_valid(_artifact_side_body_label):
			_artifact_side_body_label.text = tr("ui.artifact.eye.deny_body")
		if is_instance_valid(_artifact_side_skip_btn):
			_artifact_side_skip_btn.text = tr("ui.common.skip")
		ArtifactManager.set_run_flag("artifact_pick_enemy_deny", true)

	_artifact_interact_root.visible = true
	_artifact_interact_root.move_to_front()

	while _artifact_interact_waiting:
		await get_tree().process_frame


func _finish_artifact_interact() -> void:
	_artifact_interact_waiting = false
	_artifact_interact_mode = ""
	if is_instance_valid(_artifact_interact_root):
		_artifact_interact_root.visible = false
	if is_instance_valid(_artifact_hand_prompt):
		_artifact_hand_prompt.visible = false
	if is_instance_valid(_artifact_side_prompt):
		_artifact_side_prompt.visible = false
	if is_instance_valid(_artifact_drink_btn):
		_artifact_drink_btn.visible = false
	_set_hand_drag_enabled(true)
	if has_node("/root/ArtifactManager"):
		ArtifactManager.set_run_flag("artifact_pick_enemy_deny", false)
	end_turn_button.disabled = false
	if is_instance_valid(win_button) and OS.is_debug_build():
		win_button.visible = true


func _on_artifact_skip_pressed() -> void:
	if not _artifact_interact_waiting:
		return
	match _artifact_interact_mode:
		"alchemist":
			ArtifactManager.apply_prompt_result({"prompt_id": "alchemist_discard", "accepted": false})
		"chalice":
			ArtifactManager.apply_prompt_result({"prompt_id": "crimson_chalice", "accepted": false})
		"eye":
			ArtifactManager.apply_prompt_result({"prompt_id": "all_seeing_deny", "accepted": false})
	_finish_artifact_interact()


func _on_artifact_drink_pressed() -> void:
	if not _artifact_interact_waiting or _artifact_interact_mode != "chalice":
		return
	ArtifactManager.apply_prompt_result({"prompt_id": "crimson_chalice", "accepted": true})
	_sync_hand_ui_after_artifacts()
	_finish_artifact_interact()


func _set_hand_drag_enabled(enabled: bool) -> void:
	if not is_instance_valid(player_hand_ui_instance):
		return
	for child in player_hand_ui_instance.get_children():
		if child is CardUI:
			child.is_draggable = enabled


func _sync_hand_ui_after_artifacts() -> void:
	"""Rebuild CardUI if artifact hooks mutated PlayerData.current_hand (Chalice/Alchemist)."""
	if not is_instance_valid(player_hand_ui_instance) or not PlayerData:
		return
	var ui_cards: Array = player_hand_ui_instance.get_children().filter(func(c): return c is CardUI)
	var ui_data: Array = []
	for c in ui_cards:
		if c.card_data:
			ui_data.append(c.card_data)
	var data_hand: Array = PlayerData.current_hand.duplicate()
	if ui_data.size() == data_hand.size():
		var same := true
		for i in range(data_hand.size()):
			if ui_data[i] != data_hand[i]:
				same = false
				break
		if same:
			_refresh_hand_playability()
			return
	player_hand_ui_instance.clear_hand()
	for card_data in data_hand:
		player_hand_ui_instance.add_card_to_hand(card_data)
	player_hand_ui_instance._request_arrange()
	_update_pile_counts()
	_refresh_hand_playability()


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
	
	if unit_node.unit_data.faction == UnitData.Faction.ENEMY and _unit_may_have_summons(unit_node):
		await _dismiss_summoned_units(unit_node)
	if _unit_is_fire_elemental(unit_node):
		await _detonate_volatile_core(unit_node)
	
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
		_refresh_goblin_pack_bonuses()
	
	battle_grid_instance.remove_object_by_instance(unit_node)
	if unit_node.unit_data and unit_node.unit_data.faction == UnitData.Faction.ENEMY:
		var skip_corpse := unit_node.unit_data.unit_id == "wraith" or unit_node.unit_data.unit_id == "cocoon"
		if unit_node.has_meta("no_corpse") and bool(unit_node.get_meta("no_corpse")):
			skip_corpse = true
		if not skip_corpse and battle_grid_instance.has_method("add_corpse"):
			battle_grid_instance.add_corpse(unit_node.grid_position)
	if unit_node.has_meta("armor_core") and battle_grid_instance.has_method("set_core_pulse"):
		battle_grid_instance.set_core_pulse(unit_node.grid_position, false)
	# After grid removal, so the corpse no longer blocks line of sight / occupies its cell.
	if _current_battle_state == BattleState.PLAYER_TURN:
		_refresh_hand_playability()
	
	# Odregistruj IHNED (před animací), ať TurnManager nepracuje se zombie jednotkou
	if has_node("/root/TurnManager"):
		TurnManager.unregister_unit(unit_node)
	
	# Okamžitě aktualizuj initiative bar (jinak mrtvý zůstane v UI do konce kola)
	if is_instance_valid(initiative_bar):
		if initiative_bar.has_method("refresh_from_turn_manager"):
			initiative_bar.refresh_from_turn_manager()
		elif has_node("/root/TurnManager"):
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

	# Opposite side of the map from the player — use the FAR edge of that half,
	# not the midfield front (legacy remap put x=6→8 and goblins looked "in the middle").
	var mid_x: float = battle_grid_instance.grid_columns / 2.0
	var cols: int = battle_grid_instance.grid_columns
	var player_avg_x: float = mid_x - 1.0
	if not player_cells.is_empty():
		var sum_x := 0
		for pc in player_cells:
			sum_x += pc.x
		player_avg_x = float(sum_x) / float(player_cells.size())
	var enemies_on_right: bool = player_avg_x < mid_x
	# Far band ≈ last ~40% of the opposite half (keeps gap after their move 2–3).
	var opposite_min: int = int(ceil(mid_x)) if enemies_on_right else 0
	var opposite_max: int = (cols - 1) if enemies_on_right else int(floor(mid_x)) - 1
	var opposite_width: int = maxi(1, opposite_max - opposite_min + 1)
	var far_depth: int = maxi(3, int(ceil(float(opposite_width) * 0.45)))
	var enemy_band_min_x: int
	var enemy_band_max_x: int
	if enemies_on_right:
		enemy_band_max_x = opposite_max
		enemy_band_min_x = maxi(opposite_min, opposite_max - far_depth + 1)
	else:
		enemy_band_min_x = opposite_min
		enemy_band_max_x = mini(opposite_max, opposite_min + far_depth - 1)

	var available_spawn_cells: Array[Vector2i] = []
	for cell in all_active_cells:
		if cell.x < enemy_band_min_x or cell.x > enemy_band_max_x:
			continue
		if cell in player_cells:
			continue
		var terrain = battle_grid_instance.get_terrain_on_cell(cell)
		var is_walkable = not terrain or terrain.is_walkable
		var is_occupied = battle_grid_instance.get_object_on_cell(cell) != null
		if is_walkable and not is_occupied:
			available_spawn_cells.append(cell)

	# Fallback: if far band empty (weird shape), use full opposite half.
	if available_spawn_cells.is_empty():
		for cell in all_active_cells:
			if enemies_on_right:
				if cell.x < mid_x:
					continue
			else:
				if cell.x >= mid_x:
					continue
			if cell in player_cells:
				continue
			var terrain2 = battle_grid_instance.get_terrain_on_cell(cell)
			if (not terrain2 or terrain2.is_walkable) and battle_grid_instance.get_object_on_cell(cell) == null:
				available_spawn_cells.append(cell)
		enemy_band_min_x = opposite_min
		enemy_band_max_x = opposite_max

	DebugLogger.log_debug("Enemy FAR spawn band x=%d..%d (player_avg_x=%.1f, enemies_on_right=%s), cells=%d" % [
		enemy_band_min_x, enemy_band_max_x, player_avg_x, str(enemies_on_right), available_spawn_cells.size()
	])

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

		var spawn_pos: Vector2i = _resolve_enemy_spawn_cell(
			enemy_entry.grid_position,
			available_spawn_cells,
			enemy_band_min_x,
			enemy_band_max_x,
			enemies_on_right
		)
		available_spawn_cells.erase(spawn_pos)
		DebugLogger.log_debug("  - spawn pozice: %s (scripted=%s)" % [str(spawn_pos), str(enemy_entry.grid_position)])

		var enemy_node = _spawn_unit(enemy_entry.unit_data, spawn_pos)
		if is_instance_valid(enemy_node):
			DebugLogger.log_debug("  ✅ Enemy spawnován!")
			_enemy_units.append(enemy_node)
			enemy_node.died.connect(_on_unit_died)
			enemy_node.stats_changed.connect(_on_unit_stats_changed)
		else:
			DebugLogger.log_error("  ❌ Spawn selhal!")
	
	# Coop: uložíme stabilní pořadí všech nepřátel – používá se pro RPC payload indexy
	_all_enemy_units_ordered = _enemy_units.duplicate()
	_refresh_goblin_pack_bonuses()
	DebugLogger.log_debug("=== SPAWN DOKONČEN ===")
	DebugLogger.log_debug("Celkem nepřátel: %d" % _enemy_units.size())


func _resolve_enemy_spawn_cell(
	scripted: Vector2i,
	available: Array[Vector2i],
	band_min_x: int,
	band_max_x: int,
	enemies_on_right: bool
) -> Vector2i:
	"""Prefer scripted Y/formation; X always stays in the FAR opposite-side band.
	Legacy .tres x=6..8 → depth from the far edge (6 = farthest back)."""
	if available.is_empty():
		return Vector2i.ZERO
	if scripted == Vector2i.ZERO:
		return available.pick_random()
	if available.has(scripted) and scripted.x >= band_min_x and scripted.x <= band_max_x:
		return scripted

	const AUTHORING_ENEMY_FRONT_X := 6
	var local_x: int = maxi(0, scripted.x - AUTHORING_ENEMY_FRONT_X)
	# local 0 = far edge; higher local = one step closer to midfield (still in far band).
	var remapped_x: int
	if enemies_on_right:
		remapped_x = clampi(band_max_x - local_x, band_min_x, band_max_x)
	else:
		remapped_x = clampi(band_min_x + local_x, band_min_x, band_max_x)
	var remapped := Vector2i(remapped_x, scripted.y)
	if available.has(remapped):
		return remapped

	var best: Vector2i = Vector2i.ZERO
	var best_dist := INF
	for cell in available:
		if cell.y != scripted.y:
			continue
		var d: int = absi(cell.x - remapped_x)
		if d < best_dist:
			best_dist = d
			best = cell
	if best_dist < INF:
		return best

	return available.pick_random()


func _on_player_hand_card_clicked(card_ui_node: Control, card_data_resource: CardData):
	if _artifact_interact_mode == "alchemist" and _artifact_interact_waiting:
		if not PlayerData.current_hand.has(card_data_resource):
			return
		ArtifactManager.apply_prompt_result({
			"prompt_id": "alchemist_discard",
			"accepted": true,
			"card": card_data_resource,
		})
		_finish_artifact_interact()
		_sync_hand_ui_after_artifacts()
		return
	if _artifact_interact_waiting:
		return
	if _current_battle_state != BattleState.PLAYER_TURN: return
	# Guard: blokovat výběr karty pokud se právě zpracovává akce nebo se hraje karta
	if _is_action_processing or _card_play_in_progress: return
	# Guard: karta musí být stále v ruce (ochrana před opakovaným výběrem právě odehrané karty)
	if not PlayerData.current_hand.has(card_data_resource): return
	if _selected_card_ui == card_ui_node:
		_reset_player_selection()
		return
	if PlayerData.current_energy < _play_cost(card_data_resource):
		DebugLogger.log_warning("Nedostatek energie!")
		return

	_reset_player_selection()
	_player_action_state = PlayerActionState.CARD_SELECTED
	_selected_card_ui = card_ui_node
	_selected_card_data = card_data_resource
	player_hand_ui_instance.set_selected_card(card_ui_node)
	_show_valid_targets_for_card(card_data_resource)

func _on_player_hand_card_drag_started(card_ui_node: Control, card_data_resource: CardData):
	if _artifact_interact_waiting:
		player_hand_ui_instance.cancel_drag_ui()
		return
	if _current_battle_state != BattleState.PLAYER_TURN:
		player_hand_ui_instance.cancel_drag_ui()
		return
	# Guard: blokovat nový drag pokud se právě zpracovává akce nebo se hraje karta
	if _is_action_processing or _card_play_in_progress:
		player_hand_ui_instance.cancel_drag_ui()
		return
	if PlayerData.current_energy < _play_cost(card_data_resource):
		player_hand_ui_instance.cancel_drag_ui()
		DebugLogger.log_warning("Nedostatek energie!")
		return
	_reset_player_selection()
	_player_action_state = PlayerActionState.CARD_SELECTED
	_selected_card_ui = card_ui_node
	_selected_card_data = card_data_resource
	_show_valid_targets_for_card(card_data_resource)

func _play_cost(card: CardData) -> int:
	if card == null:
		return 0
	if has_node("/root/ArtifactManager"):
		return ArtifactManager.get_card_cost(card)
	return card.cost

func _on_player_hand_card_drag_released(card_ui_node: Control, _card_data_resource: CardData):
	if _current_battle_state != BattleState.PLAYER_TURN:
		return
	if _is_action_processing:
		# Otherwise the selection outlives the drag and the arrow keeps following the cursor.
		if _selected_card_ui == card_ui_node:
			_reset_player_selection()
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

	if card.is_unplayable():
		_show_floating_notification(tr("card.unplayable"), Color(0.75, 0.55, 0.55))
		_card_play_in_progress = false
		_reset_player_selection()
		return

	# Hned na začátku skrýt targetable/movable highlight, aby nezůstal po odehrání ani při dvojím signálu
	_clear_card_selection_state_before_play()

	# Frozen - nemůže hrát karty
	if is_instance_valid(_player_unit_node) and (_player_unit_node.is_frozen or _player_unit_node.active_statuses.has("frozen") or _player_unit_node.active_statuses.has("silenced")):
		DebugLogger.log_warning(tr("ui.battle.frozen_warning"))
		_show_floating_notification(tr("ui.battle.silence_notice") if _player_unit_node.active_statuses.has("silenced") else tr("ui.battle.frozen_notice"), Color.CYAN)
		_card_play_in_progress = false
		_reset_player_selection()
		return

	var play_cost: int = card.cost
	if has_node("/root/ArtifactManager"):
		play_cost = ArtifactManager.get_card_cost(card, initial_target)
	if not PlayerData.spend_energy(play_cost):
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
			PlayerData.gain_energy(play_cost)  # Vrať energii
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
	var displace_effects: Array = []
	for effect_data in card.effects:
		if effect_data == null:
			continue
		if effect_data.trigger != CardEffectData.EffectTrigger.ON_PLAY:
			continue
		var is_damage := effect_data.effect_type == CardEffectData.EffectType.DEAL_DAMAGE \
			or effect_data.effect_type == CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK \
			or effect_data.effect_type == CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK
		var is_displace := effect_data.effect_type == CardEffectData.EffectType.PUSH \
			or effect_data.effect_type == CardEffectData.EffectType.PULL \
			or effect_data.effect_type == CardEffectData.EffectType.TAUNT
		if is_damage:
			damage_effects.append(effect_data)
		elif is_displace:
			displace_effects.append(effect_data)
		else:
			ordered_effects.append(effect_data)
	# Pull-then-smite (Divine Pull): displace before damage.
	# Hit-then-knockback (Holy/Shield Push): damage before displace.
	var has_pull := false
	for e in displace_effects:
		if e.effect_type == CardEffectData.EffectType.PULL:
			has_pull = true
			break
	if has_pull:
		ordered_effects.append_array(displace_effects)
		ordered_effects.append_array(damage_effects)
	else:
		ordered_effects.append_array(damage_effects)
		ordered_effects.append_array(displace_effects)

	# Shield Push: rush into a 1-tile gap before hit + push.
	if card.card_id.begins_with("shield_push"):
		if not is_instance_valid(initial_target) or not (initial_target is Unit):
			PlayerData.gain_energy(play_cost)
			_is_action_processing = false
			_card_play_in_progress = false
			_reset_player_selection()
			return
		var rushed := await _try_shield_push_rush(initial_target as Unit)
		if not rushed:
			DebugLogger.log_warning("Shield Push: cannot rush / not in range")
			PlayerData.gain_energy(play_cost)
			_is_action_processing = false
			_card_play_in_progress = false
			_reset_player_selection()
			return

	
	var radiance_used := false
	var radiance_hit_units: Array = []
	_on_kill_paid_this_play = false
	for effect_data in ordered_effects:
		if effect_data.trigger != CardEffectData.EffectTrigger.ON_PLAY:
			continue
		if effect_data.effect_type == CardEffectData.EffectType.PLACE_TERRAIN:
			if _try_place_terrain_effect(effect_data, resolved_cell, card):
				card_played_successfully = true
			continue
		var targets = _get_targets_for_effect(effect_data, initial_target, card, resolved_cell)
		if not targets.is_empty() and _effect_triggers_radiance(effect_data):
			radiance_used = true
			for splash_unit in _get_radiance_splash_targets(targets):
				targets.append(splash_unit)
			for hit_unit in targets:
				if not radiance_hit_units.has(hit_unit):
					radiance_hit_units.append(hit_unit)
		# AoE přitažení (Svatyně): nejbližší první, ať vzdálenější nečekají za blokující jednotkou
		if targets.size() > 1 and is_instance_valid(_player_unit_node) \
				and (effect_data.effect_type == CardEffectData.EffectType.TAUNT or effect_data.effect_type == CardEffectData.EffectType.PULL):
			var anchor: Vector2i = _player_unit_node.grid_position
			targets.sort_custom(func(a, b):
				if not (a is Unit and b is Unit):
					return false
				return (a as Unit).grid_position.distance_squared_to(anchor) < (b as Unit).grid_position.distance_squared_to(anchor))
		if not targets.is_empty():
			card_played_successfully = true
			for target_unit in targets:
				if is_instance_valid(target_unit):
					await _apply_single_effect(effect_data, target_unit, card)
	
	if radiance_used:
		# Záře+: zasažení (cíl i sousedé) dostanou Zranitelnost
		if is_instance_valid(_player_unit_node) and _player_unit_node.active_statuses.has("radiance_vulnerable"):
			var vuln_turns: int = int(_player_unit_node.active_statuses["radiance_vulnerable"].get("value", 1))
			vuln_turns = clampi(vuln_turns, 1, 2)
			for hit_unit in radiance_hit_units:
				if is_instance_valid(hit_unit) and hit_unit is Unit and (hit_unit as Unit).current_health > 0:
					hit_unit.apply_status("vulnerable", 1, vuln_turns)
		_consume_radiance_charge()
	
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
		
		# Svatý rytíř (power): každý zahraný útok dá blok
		if is_instance_valid(_player_unit_node) and card.has_tag(CardData.CardTag.ATTACK) \
				and _player_unit_node.active_statuses.has("block_on_attack"):
			var attack_block: int = int(_player_unit_node.active_statuses["block_on_attack"].get("value", 0))
			if attack_block > 0:
				_player_unit_node.add_block(attack_block)
				# Svatý rytíř+: tento blok vydrží i přes další tah (jako Opevnění)
				if _player_unit_node.active_statuses.has("block_on_attack_carry"):
					_player_unit_node.carried_block = mini(_player_unit_node.carried_block + attack_block,
							maxi(0, _player_unit_node.current_block - _player_unit_node.retained_block))
		
		var has_exhaust_effect = card.effects.any(func(e): return e != null and e.effect_type == CardEffectData.EffectType.EXHAUST and e.trigger == CardEffectData.EffectTrigger.ON_PLAY)
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
				var exhaust_ctx: Dictionary = {}
				if has_node("/root/ArtifactManager"):
					exhaust_ctx = ArtifactManager.on_exhaust(card)
				if bool(exhaust_ctx.get("cancel_exhaust", false)):
					# Blade of Infinity: Attack exhaust → bottom of draw pile instead.
					if bool(exhaust_ctx.get("return_to_deck_bottom", false)):
						PlayerData.draw_pile.append(card)
					else:
						PlayerData.add_card_to_discard_pile(card)
				else:
					PlayerData.add_card_to_exhaust_pile(card)
			else:
				if card.get_meta("tome_to_bottom", false):
					card.set_meta("tome_to_bottom", false)
					PlayerData.draw_pile.append(card)
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
		PlayerData.gain_energy(play_cost)
		_card_play_in_progress = false

	_is_action_processing = false
	_card_play_in_progress = false
	_reset_player_selection()
	_refresh_hand_playability()

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
	_refresh_hand_playability()
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
		var status_value = debuff.get("status_value", 1)
		if _player_unit_node.has_method("apply_status"):
			_player_unit_node.apply_status(debuff.status, status_value, duration)
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
	label.add_theme_font_size_override("font_size", 32)
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
		_refresh_hand_playability()
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
		var prev_cell: Vector2i = unit.grid_position

		battle_grid_instance.remove_object_by_instance(unit)
		if not battle_grid_instance.place_object_on_cell(unit, cell, true, step_duration):
			# CRITICAL: restore occupancy — otherwise unit is a ghost and summons can stack on it.
			if not battle_grid_instance.place_object_on_cell(unit, prev_cell, false):
				push_error("BattleScene: failed to restore unit '%s' to cell %s after blocked move" % [
					String(unit.unit_data.unit_id) if unit.unit_data else String(unit.name), str(prev_cell)
				])
			break

		final_pos = cell

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
		if is_instance_valid(unit) and unit.current_health > 0 and battle_grid_instance.has_shard(cell):
			await _trigger_shard(unit, cell)
			if not is_instance_valid(unit) or unit.current_health <= 0:
				break

	if is_instance_valid(unit) and unit.current_health > 0:
		_leave_serpent_shards(unit, path, final_pos)
	if has_node("/root/ArtifactManager") and is_instance_valid(unit) and path.size() > 1:
		ArtifactManager.on_unit_moved(unit, path[0], final_pos, path.size() - 1)
	return final_pos

func _move_ethereal_along_path(unit: Unit, path: Array[Vector2i], step_duration: float = 0.22) -> Vector2i:
	"""Wraith slides through units. Terrain and traps are not in the path. Landing cells are empty."""
	if not is_instance_valid(unit):
		return Vector2i.ZERO
	if path.is_empty():
		return unit.grid_position
	if path.size() == 1:
		return path[0]
	var anchor: Vector2i = path[0]
	for i in range(1, path.size()):
		if not is_instance_valid(unit) or unit.current_health <= 0:
			break
		var cell: Vector2i = path[i]
		var occ = battle_grid_instance.get_object_on_cell(cell)
		if is_instance_valid(occ) and occ != unit:
			battle_grid_instance.flash_ground_cell(cell, Color(0.62, 0.78, 1.0, 0.55))
			var glide := create_tween()
			glide.tween_property(unit, "position", battle_grid_instance.get_world_position_for_cell(cell), step_duration)
			await glide.finished
			continue
		battle_grid_instance.remove_object_by_instance(unit)
		if not battle_grid_instance.place_object_on_cell(unit, cell, true, step_duration):
			battle_grid_instance.place_object_on_cell(unit, anchor, false)
			break
		anchor = cell
		if has_node("/root/AudioManager"):
			AudioManager.play_footstep()
		await get_tree().create_timer(step_duration).timeout
		if not is_instance_valid(unit) or unit.current_health <= 0:
			break
		var terrain = battle_grid_instance.get_terrain_on_cell(cell)
		if is_instance_valid(terrain) and unit.has_method("process_terrain_effects"):
			await unit.process_terrain_effects(terrain)
			if terrain.consume_on_trigger:
				battle_grid_instance.remove_terrain(cell)
			if not is_instance_valid(unit) or unit.current_health <= 0:
				break
		if is_instance_valid(unit) and unit.current_health > 0 and battle_grid_instance.has_shard(cell):
			await _trigger_shard(unit, cell)
	if is_instance_valid(unit) and unit.current_health > 0 and unit.grid_position != anchor:
		battle_grid_instance.remove_object_by_instance(unit)
		battle_grid_instance.place_object_on_cell(unit, anchor, false)
	return anchor if is_instance_valid(unit) else path[0]

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
		if is_instance_valid(unit) and unit.current_health > 0 and battle_grid_instance.has_shard(cell):
			await _trigger_shard(unit, cell)
			if not is_instance_valid(unit) or unit.current_health <= 0:
				return final_pos

	if is_instance_valid(unit) and unit.current_health > 0:
		_leave_serpent_shards(unit, path, final_pos)
		if not battle_grid_instance.place_object_on_cell(unit, final_pos, false):
			# Rush left the unit off-grid; never leave a ghost (enables summon stacking).
			var fallback: Vector2i = path[0]
			if not battle_grid_instance.place_object_on_cell(unit, fallback, false):
				push_error("BattleScene: rush restore failed for '%s'" % (
					String(unit.unit_data.unit_id) if unit.unit_data else String(unit.name)
				))
			else:
				final_pos = fallback
				unit.position = battle_grid_instance.get_world_position_for_cell(fallback)
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

func _action_damage_extra(unit: Unit, action: EnemyAIBase.AIAction) -> int:
	if action.special_data.has("flat_extra"):
		return int(action.special_data["flat_extra"])
	return _damage_multiplier_to_extra(unit, action.damage_multiplier)

func _unit_is_fire_elemental(unit_node: Unit) -> bool:
	return is_instance_valid(unit_node) and is_instance_valid(unit_node.unit_data) and is_instance_valid(unit_node.unit_data.ai_script) and unit_node.unit_data.ai_script.resource_path.ends_with("FireElementalAI.gd")

func _detonate_volatile_core(unit_node: Unit) -> void:
	if not is_instance_valid(unit_node) or not is_instance_valid(battle_grid_instance):
		return
	if unit_node.get_meta("volatile_detonated", false):
		return
	unit_node.set_meta("volatile_detonated", true)
	var origin: Vector2i = unit_node.grid_position
	var victims: Array[Unit] = []
	for obj in battle_grid_instance.get_all_objects_on_grid():
		if obj is Unit and obj != unit_node and obj.current_health > 0:
			if battle_grid_instance.get_distance(origin, obj.grid_position) == 1:
				victims.append(obj)
	for victim in victims:
		if is_instance_valid(victim) and victim.current_health > 0:
			await victim.take_damage(5, true, false, false)

func _unit_directly_behind(attacker: Unit, target: Unit) -> Unit:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return null
	if not is_instance_valid(battle_grid_instance):
		return null
	var from: Vector2i = attacker.grid_position
	var to: Vector2i = target.grid_position
	var step := Vector2i.ZERO
	if from.x == to.x and from.y != to.y:
		step = Vector2i(0, 1 if to.y > from.y else -1)
	elif from.y == to.y and from.x != to.x:
		step = Vector2i(1 if to.x > from.x else -1, 0)
	else:
		return null
	var behind: Vector2i = to + step
	var occ = battle_grid_instance.get_object_on_cell(behind)
	if occ is Unit and occ != attacker and occ.current_health > 0:
		return occ
	return null

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
		"damage_per_block":
			# Handled specially in DEAL_DAMAGE (block * bonus); do not treat as condition_met bonus.
			return false
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
				# Divine/Holy displacement cards: only the Undead/Demon holy type bonus (no base hit).
				if effect.string_value == "holy_bonus_only":
					await _deal_holy_bonus_only_damage(target)
					return
				var base_value = effect.value
				base_value += bonus_value
				if effect.condition_type == "damage_per_block" and is_instance_valid(_player_unit_node):
					base_value += _player_unit_node.current_block * effect.conditional_bonus_value
				if effect.damage_type == CardEffectData.DamageType.HOLY and is_instance_valid(_player_unit_node) and _player_unit_node.active_statuses.has("consecrated_weapon") \
						and not _card_grants_consecration(card_ref):
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
				if target is Unit and target.has_method("scale_card_damage"):
					damage_to_deal = target.scale_card_damage(card_ref, damage_to_deal)
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
				var pierce_block := false
				if has_node("/root/ArtifactManager"):
					pierce_block = ArtifactManager.attacks_ignore_block(target, card_ref)
				var track_holy: bool = effect.damage_type == CardEffectData.DamageType.HOLY and target is Unit \
						and target.get_unit_data().faction == UnitData.Faction.ENEMY
				var hp_before_hit: int = target.current_health if track_holy else 0
				var block_before_hit: int = target.current_block if track_holy else 0
				var hit_landed: bool = await target.take_damage(damage_to_deal, true, false, true, false, pierce_block)
				if track_holy:
					if is_instance_valid(target):
						_holy_damage_this_turn += maxi(0, hp_before_hit - target.current_health) \
								+ maxi(0, block_before_hit - target.current_block)
					else:
						_holy_damage_this_turn += hp_before_hit + block_before_hit
				if not hit_landed:
					DebugLogger.log_info("DEAL_DAMAGE dodged — další efekty karty se přesto aplikují")
					return
				if target is Unit and target.has_method("note_card_hit"):
					target.note_card_hit(card_ref)
				
				# Poprava: GAIN_ENERGY se string_value "on_kill" se vyplatí jen když tento zásah nepřítele zabil
				if target is Unit and target.get_unit_data().faction == UnitData.Faction.ENEMY:
					if enemy_health_before > 0 and target.current_health <= 0 and is_instance_valid(card_ref) \
							and not _on_kill_paid_this_play:
						_on_kill_paid_this_play = true
						for card_effect in card_ref.effects:
							if card_effect.effect_type == CardEffectData.EffectType.GAIN_ENERGY \
									and card_effect.string_value == "on_kill":
								PlayerData.gain_energy(card_effect.value)
								DebugLogger.log_info("⚡ Poprava: Získal %d energie za zabití nepřítele!" % card_effect.value)
				
				# Tracking poškození pro consecrated_barrier (pokud je target hráč)
				if target == _player_unit_node:
					_took_damage_last_turn = true
				
				# Trigger damage dealt artefakty (card must be in ctx — Frostbite/Gilded/Plague Mace filter by it)
				if has_node("/root/ArtifactManager"):
					ArtifactManager.on_damage_dealt(damage_to_deal, target, is_critical, card_ref)

		CardEffectData.EffectType.GAIN_BLOCK:
			if target.has_method("add_block"):
				var block_amount = effect.value
				# Podpora pro blok z max_hp / current_hp (používá se v unbreakable_faith)
				if effect.string_value == "max_hp" and is_instance_valid(_player_unit_node):
					block_amount = PlayerData.max_hp
				elif effect.string_value == "current_hp" and is_instance_valid(_player_unit_node):
					block_amount = PlayerData.current_hp
				elif effect.string_value == "holy_damage_this_turn":
					block_amount = _holy_damage_this_turn + effect.value
				
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
				# NOTE: Never use Dictionary.has() or `"prop" in node` on Unit — both call .has() and crash on Node3D.
				# "retain" = blok vydrží do dalšího kola (jednou), pak zmizí jako běžný blok
				if effect.string_value.contains("retain") and target is Unit:
					var total_block_added = block_amount
					if condition_met_before and effect.conditional_bonus_value > 0:
						total_block_added += effect.conditional_bonus_value
					target.carried_block += total_block_added
					target.carried_block = mini(target.carried_block, maxi(0, target.current_block - target.retained_block))
			
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
				var block_base: int = _player_unit_node.current_block
				# Shield Push: deal half current block (10 block → 5 dmg).
				if effect.string_value == "half_block" or (is_instance_valid(card_ref) and card_ref.card_id.begins_with("shield_push")):
					block_base = block_base / 2
				if block_base <= 0:
					DebugLogger.log_info("Shield Push / block dmg: 0 block → no damage")
				else:
					var block_damage = DamageCalculator.get_final_damage(
						block_base,
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
			# "on_kill" — energie jen při zabití (vyplácí se v DEAL_DAMAGE)
			if effect.string_value == "on_kill":
				pass
			else:
				PlayerData.gain_energy(effect.value)
		
		CardEffectData.EffectType.APPLY_STATUS:
			if target.has_method("apply_status"):
				# Speciální případ: remove_all_debuffs
				if effect.string_value == "remove_all_debuffs":
					if target is Unit:
						# Odstraň debuffy; zachovej buffy (regeneration, aury, until-consumed)
						var statuses_to_remove = []
						var keep_buffs := [
							"regeneration",
							"regeneration_permanent",
							"aura_devotion",
							"aura_devotion_plus",
							"block_on_attack",
							"block_on_attack_carry",
							"fury_engine",
							"fury",
							"holy_edge",
							"radiance",
							"radiance_vulnerable",
							"defensive_stance",
							"defensive_stance_turn",
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
					var status_id: String = effect.string_value
					if effect.string_value == "regeneration":
						# +1: první odečet proběhne hned na konci tahu, kdy kartu zahraješ → léčí value× (na začátku dalších tahů)
						duration = effect.value + 1
					elif effect.string_value == "regeneration_permanent":
						# Regenerace+: vlastní status do konce boje (nesčítá se s časovou Regenerací)
						duration = 999
					elif effect.string_value == "vulnerable":
						# value = počet kol (tak to ukazuje i líc karty)
						duration = maxi(1, effect.value)
					elif effect.string_value == "poison":
						duration = effect.aoe_param_x if effect.aoe_param_x > 0 else 3
						if has_node("/root/PlayerData"):
							status_value += PlayerData.poison_damage_bonus
					elif effect.string_value in Unit.UNTIL_CONSUMED_STATUSES or effect.string_value in Unit.COMBAT_LONG_STATUSES:
						duration = 999
					elif effect.aoe_param_x > 0:
						duration = effect.aoe_param_x
					target.apply_status(status_id, status_value, duration)
			
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

		CardEffectData.EffectType.PUSH:
			if target is Unit:
				await _force_displace_unit(target as Unit, false, maxi(1, effect.value))

		CardEffectData.EffectType.PULL:
			if target is Unit:
				await _force_displace_unit(target as Unit, true, maxi(1, effect.value))

		CardEffectData.EffectType.TAUNT:
			if target is Unit:
				var pull_steps := maxi(1, effect.value)
				await _force_displace_unit(target as Unit, true, pull_steps)
				if is_instance_valid(target) and target.has_method("apply_status"):
					# Single-target: aoe_param_x = délka Výzvy. AoE (Svatyně) používá aoe_param na tvar → 1 kolo.
					var taunt_duration := 1
					if effect.area_of_effect_type == CardEffectData.AreaOfEffectType.SINGLE_TARGET and effect.aoe_param_x > 0:
						taunt_duration = effect.aoe_param_x
					target.apply_status("taunted", 1, taunt_duration)
					if target.has_method("show_status_text"):
						target.show_status_text(tr("card.effect.taunt_keyword"), "critical", preload("res://art/icons/status/Aim.png"))


func _effect_triggers_radiance(effect: CardEffectData) -> bool:
	"""Záře: jen přímý svatý útok na jeden vybraný cíl (ne AoE, ne holy_bonus_only u přitažení/tlaku)."""
	if effect == null or not is_instance_valid(_player_unit_node):
		return false
	if not _player_unit_node.active_statuses.has("radiance"):
		return false
	return effect.effect_type == CardEffectData.EffectType.DEAL_DAMAGE \
			and effect.damage_type == CardEffectData.DamageType.HOLY \
			and effect.string_value != "holy_bonus_only" \
			and effect.target_type == CardEffectData.TargetType.SELECTED_ENEMY_UNIT


func _get_radiance_splash_targets(primary_targets: Array) -> Array:
	"""Živí nepřátelé na 4 sousedních buňkách primárních cílů (bez duplicit)."""
	var splash: Array = []
	if not is_instance_valid(battle_grid_instance):
		return splash
	for primary in primary_targets:
		if not (is_instance_valid(primary) and primary is Unit):
			continue
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = battle_grid_instance.get_object_on_cell((primary as Unit).grid_position + dir)
			if not (is_instance_valid(neighbor) and neighbor is Unit):
				continue
			var unit := neighbor as Unit
			if unit.current_health <= 0 or unit.get_unit_data().faction != UnitData.Faction.ENEMY:
				continue
			if unit in primary_targets or unit in splash:
				continue
			splash.append(unit)
	return splash


func _consume_radiance_charge() -> void:
	if not is_instance_valid(_player_unit_node) or not _player_unit_node.active_statuses.has("radiance"):
		return
	var data: Dictionary = _player_unit_node.active_statuses["radiance"]
	data["value"] = int(data.get("value", 1)) - 1
	if int(data["value"]) <= 0:
		_player_unit_node.active_statuses.erase("radiance")
		_player_unit_node.active_statuses.erase("radiance_vulnerable")
	_player_unit_node._update_stats_and_emit_signal()


func _deal_holy_bonus_only_damage(target: Node3D) -> void:
	"""Deal only Undead/Demon holy type bonus (+5 and PlayerData.holy_damage_bonus). Else 0 — no floor."""
	if not is_instance_valid(target) or not (target is Unit):
		return
	var unit := target as Unit
	if not is_instance_valid(unit.unit_data):
		return
	var ut: int = unit.unit_data.unit_type
	if ut != UnitData.UnitType.UNDEAD and ut != UnitData.UnitType.DEMON:
		DebugLogger.log_info("Holy bonus-only: target is not Undead/Demon — 0 dmg")
		return
	var dmg: int = UnitData.get_holy_damage_bonus(CardEffectData.DamageType.HOLY, ut)
	if has_node("/root/PlayerData"):
		dmg += PlayerData.holy_damage_bonus
	if dmg <= 0:
		return
	DebugLogger.log_info("✨ Holy bonus-only: %d vs Undead/Demon" % dmg)
	if unit.has_method("_show_floating_text"):
		unit._show_floating_text(dmg, "holy_effective")
	var hp_before_hit: int = unit.current_health
	var block_before_hit: int = unit.current_block
	await unit.take_damage(dmg, true, false, true, false, false)
	if is_instance_valid(unit):
		_holy_damage_this_turn += maxi(0, hp_before_hit - unit.current_health) + maxi(0, block_before_hit - unit.current_block)
	else:
		_holy_damage_this_turn += hp_before_hit + block_before_hit


func _try_shield_push_rush(enemy: Unit) -> bool:
	"""Shield Push: already adjacent OK; if exactly 1 tile gap, rush into the empty cell between."""
	if not is_instance_valid(enemy) or not is_instance_valid(_player_unit_node):
		return false
	if not is_instance_valid(battle_grid_instance):
		return false
	var from: Vector2i = _player_unit_node.grid_position
	var to: Vector2i = enemy.grid_position
	var dist: int = battle_grid_instance.get_distance(from, to)
	if dist == 1:
		return true
	if dist != 2:
		return false
	# Prefer the cell that lies on a short path toward the enemy.
	var hop: Vector2i = _pick_displace_step(_player_unit_node, to, true)
	if hop.x <= -900:
		return false
	if battle_grid_instance.get_distance(hop, to) != 1:
		# Fallback: any empty neighbor of enemy that is adjacent to player.
		hop = Vector2i(-999, -999)
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var cell: Vector2i = to + offset
			if not _is_displace_cell_free(cell, _player_unit_node):
				continue
			if battle_grid_instance.get_distance(from, cell) == 1:
				hop = cell
				break
		if hop.x <= -900:
			return false
	var path_step: Array[Vector2i] = [from, hop]
	await _rush_unit_along_path(_player_unit_node, path_step)
	if not is_instance_valid(_player_unit_node) or not is_instance_valid(enemy):
		return false
	return battle_grid_instance.get_distance(_player_unit_node.grid_position, enemy.grid_position) == 1


func _force_displace_unit(unit: Unit, toward_player: bool, steps: int) -> void:
	"""Forced grid step(s) toward/away from the local player. Stops on blocked / no progress."""
	if not is_instance_valid(unit) or not is_instance_valid(_player_unit_node):
		return
	if not is_instance_valid(battle_grid_instance):
		return
	var anchor: Vector2i = _player_unit_node.grid_position
	for _i in range(maxi(0, steps)):
		if not is_instance_valid(unit) or unit.current_health <= 0:
			return
		var next_cell: Vector2i = (
			_pick_displace_step(unit, anchor, true) if toward_player
			else _pick_displace_step(unit, anchor, false)
		)
		if next_cell.x <= -900:
			break
		if next_cell == unit.grid_position:
			break
		var path_step: Array[Vector2i] = [unit.grid_position, next_cell]
		await _move_unit_along_path(unit, path_step, 0.18)


func _pick_displace_step(unit: Unit, anchor: Vector2i, toward: bool) -> Vector2i:
	"""Pick one walkable empty neighbor that decreases (toward) or increases (away) Manhattan distance.
	Pull/Taunt must NEVER step sideways/away (A* detours felt like a push)."""
	var invalid := Vector2i(-999, -999)
	if not is_instance_valid(unit) or not is_instance_valid(battle_grid_instance):
		return invalid
	var from: Vector2i = unit.grid_position
	var best: Vector2i = invalid
	var best_dist: int = battle_grid_instance.get_distance(from, anchor)
	# Already adjacent: pull/taunt does not shove — stay put (status still applies).
	if toward and best_dist <= 1:
		return invalid
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = from + offset
		if not _is_displace_cell_free(cell, unit):
			continue
		if cell == anchor:
			continue
		var dist: int = battle_grid_instance.get_distance(cell, anchor)
		if toward:
			if dist < best_dist:
				best_dist = dist
				best = cell
		else:
			if dist > best_dist:
				best_dist = dist
				best = cell
	return best


func _is_displace_cell_free(cell: Vector2i, moving_unit: Unit) -> bool:
	if not is_instance_valid(battle_grid_instance) or not battle_grid_instance.is_cell_active(cell):
		return false
	var obj = battle_grid_instance.get_object_on_cell(cell)
	if is_instance_valid(obj) and obj != moving_unit:
		return false
	var terrain = battle_grid_instance.get_terrain_on_cell(cell)
	if terrain and not terrain.is_walkable:
		return false
	return true


# Pomocná funkce pro kontrolu útočného dosahu (přidej ji do BattleScene)
func can_attack_target(attacker: Unit, target: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	
	var distance = battle_grid.get_distance(attacker.grid_position, target.grid_position)
	return distance <= attacker.unit_data.attack_range

# OPRAVA: Návratový typ Node2D změněn na Node3D (nebo Array[Unit])
# card_being_played: karta, která se právě hraje (potřeba pro range; _selected_card_data je už vynulovaná)
func _get_targets_for_effect(effect: CardEffectData, initial_target_node: Node3D, card_being_played: CardData, resolved_cell: Vector2i = Vector2i(-999, -999)) -> Array:
	var targets: Array = []
	# Prefer play-time resolved cell (mouse can move during await / animation)
	var clicked_grid_cell := resolved_cell
	if clicked_grid_cell.x <= -900:
		clicked_grid_cell = get_grid_cell_under_mouse()
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
	_clear_card_damage_preview()
	_hide_targeting_arrow()
	battle_grid_instance.hide_movable_range()
	battle_grid_instance.hide_targetable_cells()
	battle_grid_instance.hide_aoe_highlight()
	battle_grid_instance.hide_enemy_range()
	if _current_battle_state == BattleState.PLAYER_TURN:
		battle_grid_instance.hide_danger_zone()
	_restore_all_seeing_eye_preview()

func _reset_player_selection():
	if is_instance_valid(_selected_unit):
		_selected_unit.set_selected_visual(false)
		_selected_unit = null
	_hide_targeting_arrow()
	if is_instance_valid(_selected_card_ui):
		player_hand_ui_instance.set_selected_card(null)
		_selected_card_ui = null
		_selected_card_data = null
	_clear_card_damage_preview()
	battle_grid_instance.hide_movable_range()
	battle_grid_instance.hide_targetable_cells()
	battle_grid_instance.hide_aoe_highlight()
	battle_grid_instance.hide_enemy_range()
	if _current_battle_state == BattleState.PLAYER_TURN:
		battle_grid_instance.hide_danger_zone()
	_player_action_state = PlayerActionState.IDLE
	_restore_all_seeing_eye_preview()

func _restore_all_seeing_eye_preview() -> void:
	if not has_node("/root/ArtifactManager"):
		return
	if not ArtifactManager.get_run_flag("show_enemy_move_preview", false):
		return
	if not is_instance_valid(battle_grid_instance):
		return
	if not battle_grid_instance.has_method("show_all_enemy_move_previews"):
		return
	var living: Array = []
	for enemy_unit in _enemy_units:
		if is_instance_valid(enemy_unit) and enemy_unit.current_health > 0:
			living.append(enemy_unit)
	battle_grid_instance.show_all_enemy_move_previews(living)
	# Idle Eye preview is up again — next leave-hover can clear/restore once.
	_last_enemy_info_hover = null
	_last_enemy_range_shown = null



func _on_draw_pile_clicked(): card_pile_viewer.show_cards(PlayerData.draw_pile)
func _on_discard_pile_clicked(): card_pile_viewer.show_cards(PlayerData.discard_pile)

func _on_energy_changed(_new_amount: int):
	# Energy display lives on PlayerInfoPanel (standalone CanvasLayer EnergyLabel was removed).
	if is_instance_valid(player_info_panel) and player_info_panel.has_method("update_energy_display"):
		player_info_panel.update_energy_display()
	_refresh_hand_playability()

func _on_end_turn_button_pressed():
	if _current_battle_state != BattleState.PLAYER_TURN:
		return
	
	# ===== UPRAVENO PRO INICIATIVNÍ SYSTÉM =====
	_current_battle_state = BattleState.PROCESSING
	end_turn_button.disabled = true
	
	# Reset tracking poškození na konci tahu hráče (pro consecrated_barrier)
	# Toto zajistí, že v dalším tahu hráče bude tracking správně nastaven
	_took_damage_last_turn = false
	
	# Zavolej end_turn na hráči (await burning DoT / death before artifacts)
	if is_instance_valid(_player_unit_node):
		await _player_unit_node.end_turn()
	
	# END_OF_TURN artefakty
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_turn_end()
		# Time Crystal etc. may request an extra turn during on_turn_end
		if _current_battle_state == BattleState.PLAYER_TURN:
			return
	
	# Coop: sync stavu jednotky po end-of-turn artefaktech
	if _is_coop_run() and is_instance_valid(_player_unit_node):
		var my_idx = _coop_get_player_unit_index(_player_unit_node)
		rpc("_rpc_coop_sync_my_unit_state", my_idx, _player_unit_node.current_health, _player_unit_node.current_block)
	
	# END_OF_TURN karty (např. curse_pain) před odhozením ruky
	_process_end_of_turn_hand_effects()
	
	# Odhoď karty
	player_hand_ui_instance.discard_hand_animated(discard_pile_button.global_position)
	# ============================================

func _physics_process(_delta):
	if OS.has_feature("web"):
		return
	# Raycast pro enemy hover (card target preview je už v _process, nevolat 2×)
	var grid_cell = get_grid_cell_under_mouse() 
	var unit_under_mouse = battle_grid_instance.get_object_on_cell(grid_cell)
	_refresh_enemy_info_hover(unit_under_mouse, false)

func _is_mouse_over_enemy_info_panel() -> bool:
	if not is_instance_valid(enemy_info_panel) or not enemy_info_panel.visible:
		return false
	return enemy_info_panel.get_global_rect().has_point(enemy_info_panel.get_global_mouse_position())

func _effect_is_play_target(effect: CardEffectData) -> bool:
	if effect == null:
		return false
	if effect.effect_type == CardEffectData.EffectType.EXHAUST:
		return false
	if effect.trigger != CardEffectData.EffectTrigger.ON_PLAY:
		return false
	return true

func _card_has_self_play_target(card: CardData) -> bool:
	return card.effects.any(func(e): return _effect_is_play_target(e) and e.target_type == CardEffectData.TargetType.SELF_UNIT)

func _card_has_enemy_play_target(card: CardData) -> bool:
	return card.effects.any(func(e): return _effect_is_play_target(e) and (e.target_type == CardEffectData.TargetType.SELECTED_ENEMY_UNIT or e.target_type == CardEffectData.TargetType.ALL_ENEMY_UNITS))

func _card_has_empty_cell_play_target(card: CardData) -> bool:
	return card.effects.any(func(e): return _effect_is_play_target(e) and (e.target_type == CardEffectData.TargetType.EMPTY_GRID_CELL or e.effect_type == CardEffectData.EffectType.PLACE_TERRAIN))

func _process_end_of_turn_hand_effects() -> void:
	if not is_instance_valid(_player_unit_node):
		return
	for card in PlayerData.current_hand.duplicate():
		if card is CardData:
			_process_card_trigger_effects(card, CardEffectData.EffectTrigger.END_OF_TURN)

func _process_card_trigger_effects(card: CardData, trigger: CardEffectData.EffectTrigger) -> void:
	if not is_instance_valid(card):
		return
	var should_exhaust := false
	for effect in card.effects:
		if effect == null or effect.trigger != trigger:
			continue
		if effect.effect_type == CardEffectData.EffectType.EXHAUST:
			should_exhaust = true
			continue
		if is_instance_valid(_player_unit_node):
			_apply_single_effect(effect, _player_unit_node, card)
			if effect.effect_type == CardEffectData.EffectType.GAIN_ENERGY:
				PlayerData.current_energy = maxi(0, PlayerData.current_energy)
				PlayerData.emit_signal("energy_changed", PlayerData.current_energy)
	if should_exhaust:
		_exhaust_card_from_hand(card)

func _exhaust_card_from_hand(card: CardData) -> void:
	if not PlayerData.current_hand.has(card):
		return
	PlayerData.current_hand.erase(card)
	PlayerData.add_card_to_exhaust_pile(card)
	if is_instance_valid(player_hand_ui_instance):
		for child in player_hand_ui_instance.get_children():
			if child is CardUI and child.card_data == card:
				child.queue_free()
				break
		player_hand_ui_instance._request_arrange()
	_update_pile_counts()

func _unit_may_have_summons(unit: Unit) -> bool:
	if not is_instance_valid(unit):
		return false
	if unit.has_meta("summoned_units"):
		return true
	for enemy in _enemy_units:
		if not is_instance_valid(enemy) or enemy == unit:
			continue
		if enemy.has_meta("summoner") and enemy.get_meta("summoner") == unit:
			return true
	return false

func _dismiss_summoned_units(summoner: Unit) -> void:
	if not is_instance_valid(summoner):
		return
	var to_kill: Array[Unit] = []
	if summoner.has_meta("summoned_units"):
		for unit in summoner.get_meta("summoned_units"):
			if is_instance_valid(unit) and unit is Unit and unit.current_health > 0:
				to_kill.append(unit)
	for enemy in _enemy_units:
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			continue
		if not enemy.has_meta("summoner"):
			continue
		if enemy.get_meta("summoner") == summoner and not to_kill.has(enemy):
			to_kill.append(enemy)
	if to_kill.is_empty():
		return
	for unit in to_kill:
		if is_instance_valid(unit) and unit.current_health > 0:
			await unit.take_damage(unit.current_health, true, false, false, true, true)

func _refresh_enemy_info_hover(unit_under_mouse: Node, show_range: bool) -> void:
	"""Enemy info při hoveru; zůstane otevřené i když myš přejede na panel (scroll)."""
	if is_instance_valid(unit_under_mouse) and unit_under_mouse.get_unit_data().faction == UnitData.Faction.ENEMY:
		enemy_info_panel.update_stats(unit_under_mouse)
		_last_enemy_info_hover = unit_under_mouse
		# Only recompute Dijkstra/highlights when the hovered enemy changes (_process path).
		if show_range and is_instance_valid(battle_grid_instance) and unit_under_mouse != _last_enemy_range_shown:
			battle_grid_instance.show_enemy_range(unit_under_mouse)
			_last_enemy_range_shown = unit_under_mouse
		return
	if _is_mouse_over_enemy_info_panel():
		return
	# Leaving enemy hover: clear once, then restore Eye preview once — not every idle frame.
	if _last_enemy_info_hover != null:
		_last_enemy_info_hover = null
		_last_enemy_range_shown = null
		enemy_info_panel.hide_panel()
		_clear_enemy_hover_highlights()

func _refresh_terrain_hover(grid_cell: Vector2i, unit_under_mouse: Node) -> void:
	if _is_mouse_over_battle_hud() \
			or is_instance_valid(unit_under_mouse) \
			or not is_instance_valid(battle_grid_instance) \
			or not battle_grid_instance.is_cell_active(grid_cell):
		_hide_terrain_hover()
		return
	var terrain: TerrainData = battle_grid_instance.get_terrain_on_cell(grid_cell)
	if terrain == null:
		_hide_terrain_hover()
		return
	_ensure_terrain_hover_ui()
	if not is_instance_valid(_terrain_hover_panel) or not is_instance_valid(_terrain_hover_label):
		return
	if _terrain_hover_cell != grid_cell or not _terrain_hover_panel.visible:
		var title := terrain.get_localized_name()
		var desc := terrain.get_localized_description()
		if desc.is_empty() or desc == terrain.description:
			_terrain_hover_label.text = title
		else:
			_terrain_hover_label.text = "%s\n%s" % [title, desc]
		_terrain_hover_panel.visible = true
		_terrain_hover_panel.reset_size()
		_terrain_hover_cell = grid_cell
	var mouse := get_viewport().get_mouse_position()
	var vp := get_viewport().get_visible_rect().size
	var pos := mouse + Vector2(18, 18)
	pos.x = minf(pos.x, vp.x - _terrain_hover_panel.size.x - 8.0)
	pos.y = minf(pos.y, vp.y - _terrain_hover_panel.size.y - 8.0)
	pos.x = maxf(pos.x, 8.0)
	pos.y = maxf(pos.y, 8.0)
	_terrain_hover_panel.global_position = pos

func _is_mouse_over_battle_hud() -> bool:
	if _is_mouse_over_enemy_info_panel():
		return true
	var mouse := get_viewport().get_mouse_position()
	if _control_has_mouse(player_hand_ui_instance, mouse):
		return true
	if _control_has_mouse(initiative_bar, mouse):
		return true
	if _control_has_mouse(end_turn_button, mouse):
		return true
	if _control_has_mouse(draw_pile_button, mouse):
		return true
	if _control_has_mouse(discard_pile_button, mouse):
		return true
	if _control_has_mouse(player_info_panel, mouse):
		return true
	if is_instance_valid(card_tooltip) and card_tooltip.visible:
		return true
	return false

func _control_has_mouse(ctrl: Variant, mouse: Vector2) -> bool:
	if not is_instance_valid(ctrl) or not (ctrl is Control):
		return false
	var c: Control = ctrl
	if not c.visible:
		return false
	return c.get_global_rect().has_point(mouse)

func _ensure_terrain_hover_ui() -> void:
	if is_instance_valid(_terrain_hover_panel):
		return
	var layer: Node = get_node_or_null("CanvasLayer")
	if layer == null:
		return
	_terrain_hover_panel = PanelContainer.new()
	_terrain_hover_panel.name = "TerrainHoverTooltip"
	_terrain_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain_hover_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	style.border_color = Color(0.72, 0.62, 0.38, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_terrain_hover_panel.add_theme_stylebox_override("panel", style)
	_terrain_hover_label = Label.new()
	_terrain_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terrain_hover_label.custom_minimum_size = Vector2(220, 0)
	_terrain_hover_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	_terrain_hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_terrain_hover_label.add_theme_constant_override("outline_size", 3)
	_terrain_hover_panel.add_child(_terrain_hover_label)
	layer.add_child(_terrain_hover_panel)

func _hide_terrain_hover() -> void:
	_terrain_hover_cell = Vector2i(-999, -999)
	if is_instance_valid(_terrain_hover_panel):
		_terrain_hover_panel.visible = false

func _show_valid_targets_for_card(card: CardData):
	var info: Dictionary = _collect_valid_targets_for_card(card)
	var valid_target_cells: Array[Vector2i] = info.get("cells", [])
	var is_attack: bool = bool(info.get("is_attack", true))
	if card.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE and is_instance_valid(_player_unit_node):
		var aoe_cells: Array[Vector2i] = []
		for effect in card.effects:
			if effect == null or effect.trigger != CardEffectData.EffectTrigger.ON_PLAY:
				continue
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

func _collect_valid_targets_for_card(card: CardData) -> Dictionary:
	var valid_target_cells: Array[Vector2i] = []
	var is_attack := true
	if card == null or not is_instance_valid(_player_unit_node) or not is_instance_valid(battle_grid_instance):
		return {"cells": valid_target_cells, "is_attack": is_attack}

	var needs_los = card.range_type == CardData.EffectRangeType.RANGED_FIXED or card.range_type == CardData.EffectRangeType.RANGED_LINE

	if card.range_type == CardData.EffectRangeType.FULL_BOARD:
		is_attack = _card_has_enemy_play_target(card)
		valid_target_cells.append(_player_unit_node.grid_position)
		for enemy in _enemy_units:
			if is_instance_valid(enemy):
				valid_target_cells.append(enemy.grid_position)
		return {"cells": valid_target_cells, "is_attack": is_attack}

	if card.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE:
		is_attack = true
		valid_target_cells.append(_player_unit_node.grid_position)
		return {"cells": valid_target_cells, "is_attack": is_attack}

	for effect in card.effects:
		if not _effect_is_play_target(effect):
			continue
		match effect.target_type:
			CardEffectData.TargetType.SELECTED_ENEMY_UNIT:
				is_attack = true
				for enemy in _enemy_units:
					if is_instance_valid(enemy):
						var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, enemy.grid_position)
						if distance <= card.range_value:
							if needs_los and not battle_grid_instance.has_line_of_sight(_player_unit_node.grid_position, enemy.grid_position, enemy):
								continue
							if not valid_target_cells.has(enemy.grid_position):
								valid_target_cells.append(enemy.grid_position)
			CardEffectData.TargetType.ALL_ENEMY_UNITS:
				is_attack = true
				for enemy in _enemy_units:
					if is_instance_valid(enemy) and not valid_target_cells.has(enemy.grid_position):
						valid_target_cells.append(enemy.grid_position)
			CardEffectData.TargetType.SELF_UNIT:
				is_attack = false
				if not valid_target_cells.has(_player_unit_node.grid_position):
					valid_target_cells.append(_player_unit_node.grid_position)
			CardEffectData.TargetType.EMPTY_GRID_CELL:
				is_attack = false
				for cell in battle_grid_instance.get_all_active_cells():
					if _resolve_living_unit_on_cell(cell) != null:
						continue
					var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, cell)
					if distance <= card.range_value and not valid_target_cells.has(cell):
						valid_target_cells.append(cell)
			_:
				if effect.effect_type == CardEffectData.EffectType.PLACE_TERRAIN:
					is_attack = false
					for cell in battle_grid_instance.get_all_active_cells():
						if _resolve_living_unit_on_cell(cell) != null:
							continue
						var distance = battle_grid_instance.get_distance(_player_unit_node.grid_position, cell)
						if distance <= card.range_value and not valid_target_cells.has(cell):
							valid_target_cells.append(cell)
	return {"cells": valid_target_cells, "is_attack": is_attack}

func _card_has_any_valid_target_now(card: CardData) -> bool:
	if card == null:
		return false
	var has_play_effect := false
	for effect in card.effects:
		if _effect_is_play_target(effect):
			has_play_effect = true
			break
	# Cards with no ON_PLAY target effects (weird / exhaust-only) stay selectable if other gates pass.
	if not has_play_effect:
		return true
	var info: Dictionary = _collect_valid_targets_for_card(card)
	var cells: Array = info.get("cells", [])
	return not cells.is_empty()

func _evaluate_card_playability(card: CardData) -> Dictionary:
	if card == null:
		return {"playable": false, "reason": "unplayable"}
	if card.is_unplayable():
		return {"playable": false, "reason": "unplayable"}
	if is_instance_valid(_player_unit_node) and (_player_unit_node.is_frozen or _player_unit_node.active_statuses.has("frozen") or _player_unit_node.active_statuses.has("silenced")):
		return {"playable": false, "reason": "silenced" if _player_unit_node.active_statuses.has("silenced") else "frozen"}
	if PlayerData.current_energy < _play_cost(card):
		return {"playable": false, "reason": "energy"}
	if card.max_uses_per_turn > 0:
		var current_count: int = int(_cards_played_this_turn.get(card.card_id, 0))
		if current_count >= card.max_uses_per_turn:
			return {"playable": false, "reason": "max_uses"}
	if not _card_has_any_valid_target_now(card):
		return {"playable": false, "reason": "range"}
	return {"playable": true, "reason": ""}

func _refresh_hand_playability() -> void:
	if not is_instance_valid(player_hand_ui_instance) or not player_hand_ui_instance.has_method("refresh_all_playability"):
		return
	_hand_has_playable_card = false
	player_hand_ui_instance.refresh_all_playability(_evaluate_card_playability_tracked)

## Same as _evaluate_card_playability, but records whether any hand card is playable (End Turn pulse).
func _evaluate_card_playability_tracked(card: CardData) -> Dictionary:
	var result := _evaluate_card_playability(card)
	if bool(result.get("playable", false)):
		_hand_has_playable_card = true
	return result

## Pulses End Turn while the player could still do something useful (energy left + a playable card).
func _update_end_turn_pulse() -> void:
	if not is_instance_valid(end_turn_button):
		return
	var should_pulse := _current_battle_state == BattleState.PLAYER_TURN \
			and not end_turn_button.disabled \
			and PlayerData.current_energy > 0 \
			and _hand_has_playable_card
	var is_pulsing := _end_turn_pulse_tween != null and _end_turn_pulse_tween.is_valid()
	if should_pulse == is_pulsing:
		return
	if should_pulse:
		end_turn_button.pivot_offset = end_turn_button.size * 0.5
		_end_turn_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_end_turn_pulse_tween.tween_property(end_turn_button, "modulate", END_TURN_PULSE_COLOR, END_TURN_PULSE_HALF_PERIOD)
		_end_turn_pulse_tween.parallel().tween_property(end_turn_button, "scale", END_TURN_PULSE_SCALE, END_TURN_PULSE_HALF_PERIOD)
		_end_turn_pulse_tween.tween_property(end_turn_button, "modulate", Color.WHITE, END_TURN_PULSE_HALF_PERIOD)
		_end_turn_pulse_tween.parallel().tween_property(end_turn_button, "scale", Vector2.ONE, END_TURN_PULSE_HALF_PERIOD)
	else:
		_end_turn_pulse_tween.kill()
		_end_turn_pulse_tween = null
		end_turn_button.modulate = Color.WHITE
		end_turn_button.scale = Vector2.ONE

func _build_turn_banner() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TurnBannerLayer"
	layer.layer = TARGETING_ARROW_LAYER
	add_child(layer)
	_turn_banner = PanelContainer.new()
	_turn_banner.name = "TurnBanner"
	_turn_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_turn_banner.add_theme_stylebox_override("panel", style)
	_turn_banner_label = Label.new()
	_turn_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_banner_label.add_theme_font_override("font", TURN_BANNER_FONT)
	_turn_banner_label.add_theme_font_size_override("font_size", 44)
	_turn_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_turn_banner_label.add_theme_constant_override("outline_size", 8)
	_turn_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_banner.add_child(_turn_banner_label)
	_turn_banner.visible = false
	layer.add_child(_turn_banner)

## „Čelíš: název“ + tagy pod ním, jednou při vstupu do boje (jen info, žádná volba).
func _show_encounter_intro() -> void:
	if encounter_data == null or encounter_data.display_name.is_empty() or GameManager.tutorial_active:
		return
	var title_key := "ui.battle.encounter_intro"
	match encounter_data.encounter_type:
		EncounterData.EncounterType.ELITE:
			title_key = "ui.battle.encounter_intro_elite"
		EncounterData.EncounterType.BOSS:
			title_key = "ui.battle.encounter_intro_boss"
	var tag_names: Array[String] = []
	for tag_id in [encounter_data.main_tag] + encounter_data.tags:
		if not String(tag_id).is_empty():
			tag_names.append(tr("encounter.tag." + String(tag_id)))

	var layer := CanvasLayer.new()
	layer.name = "EncounterIntroLayer"
	layer.layer = TARGETING_ARROW_LAYER
	add_child(layer)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var title := Label.new()
	title.text = TranslationHelper.tr_format(title_key, {"name": tr(encounter_data.display_name)})
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TURN_BANNER_FONT)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", TURN_BANNER_ENEMY_COLOR if encounter_data.encounter_type != EncounterData.EncounterType.NORMAL else Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	if not tag_names.is_empty():
		var sub := Label.new()
		sub.text = " · ".join(tag_names)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_override("font", TURN_BANNER_FONT)
		sub.add_theme_font_size_override("font_size", 22)
		sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		sub.add_theme_constant_override("outline_size", 4)
		box.add_child(sub)
	layer.add_child(panel)
	_encounter_intro_panel = panel
	panel.reset_size()
	var screen := get_viewport().get_visible_rect().size
	panel.position = Vector2((screen.x - panel.size.x) * 0.5, ENCOUNTER_INTRO_TOP)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(ENCOUNTER_INTRO_HOLD)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(layer.queue_free)

## Short fade-in / hold / fade-out (~1.1 s). A new banner replaces one still on screen.
func _show_turn_banner(text: String, color: Color) -> void:
	if not is_instance_valid(_turn_banner):
		return
	if _turn_banner_tween and _turn_banner_tween.is_valid():
		_turn_banner_tween.kill()
	# „Čelíš:“ pruh rychle zmizí, ať se s bannerem tahu neslévá do jednoho bloku
	if is_instance_valid(_encounter_intro_panel):
		var fade := create_tween()
		fade.tween_property(_encounter_intro_panel, "modulate:a", 0.0, 0.15)
		_encounter_intro_panel = null
	_turn_banner_label.text = text
	_turn_banner_label.add_theme_color_override("font_color", color)
	_turn_banner.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_turn_banner.position = Vector2((screen.x - _turn_banner.size.x) * 0.5, TURN_BANNER_TOP)
	# Replacing a banner still on screen continues from its current alpha (no flicker).
	if not _turn_banner.visible:
		_turn_banner.modulate.a = 0.0
	_turn_banner.visible = true
	_turn_banner_tween = create_tween()
	_turn_banner_tween.tween_property(_turn_banner, "modulate:a", 1.0, 0.12)
	_turn_banner_tween.tween_interval(TURN_BANNER_HOLD)
	_turn_banner_tween.tween_property(_turn_banner, "modulate:a", 0.0, 0.25)
	_turn_banner_tween.tween_callback(_turn_banner.hide)

func _clear_enemy_hover_highlights():
	if battle_grid_instance and battle_grid_instance.has_method("clear_highlights"):
		battle_grid_instance.clear_highlights()
	else:
		battle_grid_instance.hide_enemy_range()
	_restore_all_seeing_eye_preview()

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
		_refresh_intent_threat_highlights()
		return
	for enemy_unit in _enemy_units:
		if not is_instance_valid(enemy_unit):
			continue
		if not enemy_unit.has_method("update_intent"):
			continue
		enemy_unit.update_intent(_player_unit_node, battle_grid_instance)
	# All-Seeing Eye: show move range for ALL living enemies when preview is flagged
	if has_node("/root/ArtifactManager") and ArtifactManager.get_run_flag("show_enemy_move_preview", false):
		if is_instance_valid(battle_grid_instance) and battle_grid_instance.has_method("show_all_enemy_move_previews"):
			var living: Array = []
			for enemy_unit in _enemy_units:
				if is_instance_valid(enemy_unit) and enemy_unit.current_health > 0:
					living.append(enemy_unit)
			battle_grid_instance.show_all_enemy_move_previews(living)
		elif is_instance_valid(battle_grid_instance) and battle_grid_instance.has_method("show_enemy_range"):
			for enemy_unit in _enemy_units:
				if is_instance_valid(enemy_unit) and enemy_unit.current_health > 0:
					battle_grid_instance.show_enemy_range(enemy_unit)
					break
	_refresh_intent_threat_highlights()

func _set_enemy_intents_visible(intents_visible: bool) -> void:
	_enemy_intent_overlay_on = intents_visible
	for enemy_unit in _enemy_units:
		if is_instance_valid(enemy_unit) and enemy_unit.has_method("set_intent_visibility_allowed"):
			enemy_unit.set_intent_visibility_allowed(intents_visible)
	if intents_visible:
		_refresh_intent_threat_highlights()
	else:
		_clear_intent_threat_highlights()

func _refresh_intent_threat_highlights() -> void:
	if not _enemy_intent_overlay_on or not is_instance_valid(battle_grid_instance):
		return
	if not battle_grid_instance.has_method("show_intent_threats"):
		return
	var damage: Array[Vector2i] = []
	var control: Array[Vector2i] = []
	var ember: Array[Vector2i] = []
	var ghost: Array[Vector2i] = []
	var plague: Array[Vector2i] = []
	var labels: Dictionary = {}
	for enemy_unit in _enemy_units:
		if not is_instance_valid(enemy_unit) or enemy_unit.current_health <= 0:
			continue
		if not enemy_unit.has_method("get_intent_threat_cells"):
			continue
		for threat in enemy_unit.get_intent_threat_cells():
			if typeof(threat) != TYPE_DICTIONARY:
				continue
			var cell: Vector2i = threat.get("cell", Vector2i(-999, -999))
			if not battle_grid_instance.is_cell_active(cell):
				continue
			var kind := str(threat.get("kind", "damage"))
			if kind == "control":
				if not control.has(cell):
					control.append(cell)
			elif kind == "ember":
				if not ember.has(cell):
					ember.append(cell)
			elif kind == "ghost":
				if not ghost.has(cell):
					ghost.append(cell)
			elif kind == "plague":
				if not plague.has(cell):
					plague.append(cell)
			elif not damage.has(cell):
				damage.append(cell)
			var label := str(threat.get("label", ""))
			if not label.is_empty():
				labels[cell] = label
	for node in battle_grid_instance.get_all_objects_on_grid():
		if node is Unit and node.current_health > 0 and node.active_statuses.has("plague"):
			for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbor: Vector2i = node.grid_position + offset
				if battle_grid_instance.is_cell_active(neighbor) and not plague.has(neighbor):
					plague.append(neighbor)
	for cell in control:
		damage.erase(cell)
		ember.erase(cell)
		ghost.erase(cell)
		plague.erase(cell)
	for cell in damage:
		ember.erase(cell)
		ghost.erase(cell)
		plague.erase(cell)
	battle_grid_instance.show_intent_threats(damage, control, ember, labels, ghost, plague)

func _clear_intent_threat_highlights() -> void:
	if is_instance_valid(battle_grid_instance) and battle_grid_instance.has_method("clear_intent_threats"):
		battle_grid_instance.clear_intent_threats()

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
	
	# PLAYER_CENTERED_AOE / FULL_BOARD: AOE je statické, už nastavené v _show_valid_targets_for_card
	if _selected_card_data.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE \
			or _selected_card_data.range_type == CardData.EffectRangeType.FULL_BOARD:
		return
	
	# OPRAVA: Použití 3D Raycast funkce místo get_global_mouse_position
	var mouse_grid_pos = get_grid_cell_under_mouse()
	
	if not battle_grid_instance.is_valid_grid_position(mouse_grid_pos):
		battle_grid_instance.hide_aoe_highlight()
		return
		
	var final_aoe_cells: Array[Vector2i] = []
	for effect in _selected_card_data.effects:
		if effect == null or effect.trigger != CardEffectData.EffectTrigger.ON_PLAY:
			continue
		if effect.area_of_effect_type == CardEffectData.AreaOfEffectType.SINGLE_TARGET:
			continue
		var potential_cells = battle_grid_instance.get_cells_for_aoe(mouse_grid_pos, effect.area_of_effect_type, effect.aoe_param_x, effect.aoe_param_y)
		for cell in potential_cells:
			if battle_grid_instance.is_cell_active(cell): final_aoe_cells.append(cell)
			
	battle_grid_instance.show_aoe_highlight(final_aoe_cells)

func _update_card_damage_preview(hover_cell: Vector2i) -> void:
	if not is_instance_valid(_selected_card_data) or not is_instance_valid(_player_unit_node):
		_clear_card_damage_preview()
		return
	var key := "%d|%s|%s" % [_selected_card_data.get_instance_id(), str(hover_cell), str(_targeting_arrow_active)]
	if key == _damage_preview_key:
		return
	_clear_card_damage_preview()
	_damage_preview_key = key
	var previews: Dictionary = _compute_card_damage_preview(_selected_card_data, hover_cell)
	_damage_preview_results = previews
	var arrow_target: Unit = _get_arrow_readout_unit(hover_cell)
	for unit in previews:
		var preview: Dictionary = previews[unit]
		unit.set_damage_preview(int(preview["hp_loss"]), bool(preview["lethal"]), unit != arrow_target)
		_damage_preview_units.append(unit)

func _clear_card_damage_preview() -> void:
	for unit in _damage_preview_units:
		if is_instance_valid(unit):
			unit.clear_damage_preview()
	_damage_preview_units.clear()
	_damage_preview_results = {}
	_damage_preview_key = ""

func _build_targeting_arrow() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TargetingArrowLayer"
	layer.layer = TARGETING_ARROW_LAYER
	add_child(layer)
	_targeting_arrow = TargetingArrow.new()
	_targeting_arrow.name = "TargetingArrow"
	layer.add_child(_targeting_arrow)

## Self-only cards (Defend) and auto-target AoE are played without aiming, so they get no arrow.
func _refresh_arrow_card_cache(card: CardData) -> void:
	if card.get_instance_id() == _arrow_card_id:
		return
	_arrow_card_id = card.get_instance_id()
	var info: Dictionary = _collect_valid_targets_for_card(card)
	_arrow_valid_cells = info.get("cells", []).duplicate()
	# Same rule as _try_play_selected_card_at_cell: a card with an enemy effect can't be dropped on the player.
	_arrow_is_attack = _card_has_enemy_play_target(card)
	if _arrow_is_attack and is_instance_valid(_player_unit_node):
		_arrow_valid_cells.erase(_player_unit_node.grid_position)
	_arrow_uses_arrow = card.range_type != CardData.EffectRangeType.PLAYER_CENTERED_AOE \
			and card.range_type != CardData.EffectRangeType.FULL_BOARD
	if _arrow_uses_arrow and not _arrow_is_attack and is_instance_valid(_player_unit_node) \
			and _arrow_valid_cells.size() == 1 and _arrow_valid_cells[0] == _player_unit_node.grid_position:
		_arrow_uses_arrow = false

func _update_targeting_arrow(hover_cell: Vector2i) -> void:
	if _targeting_arrow == null or not is_instance_valid(_selected_card_ui) or not (_selected_card_ui is CardUI) \
			or not is_instance_valid(_selected_card_data):
		_hide_targeting_arrow()
		return
	var card_ui := _selected_card_ui as CardUI
	_refresh_arrow_card_cache(_selected_card_data)
	if not _arrow_uses_arrow:
		if _targeting_arrow_active:
			_targeting_arrow.hide_arrow()
			_targeting_arrow_active = false
		return
	var mouse_pos := get_viewport().get_mouse_position()
	if card_ui.is_dragging:
		var screen := get_viewport().get_visible_rect().size
		var park_y := screen.y * arrow_park_screen_ratio
		# Hysteresis so the card doesn't flicker between parked and following at the threshold.
		if card_ui.has_drag_anchor() and mouse_pos.y > park_y + 40.0:
			card_ui.clear_drag_anchor()
		elif not card_ui.has_drag_anchor() and mouse_pos.y < park_y:
			card_ui.set_drag_anchor(Vector2(screen.x * 0.5, screen.y - 16.0))
		if not card_ui.has_drag_anchor():
			_targeting_arrow.hide_arrow()
			_targeting_arrow_active = false
			return
	var card_rect := card_ui.get_global_rect()
	var from := Vector2(card_rect.get_center().x, card_rect.position.y + 10.0)
	var to := mouse_pos
	var color := ARROW_INVALID_COLOR
	if _arrow_valid_cells.has(hover_cell):
		color = ARROW_ATTACK_COLOR if _arrow_is_attack else ARROW_UTILITY_COLOR
		var unit := _resolve_living_unit_on_cell(hover_cell) as Unit
		if unit != null:
			to = unit.get_aim_screen_position(camera_3d)
			var guard := unit.find_interpose_guard()
			if guard != null:
				to = guard.get_aim_screen_position(camera_3d)
		else:
			to = camera_3d.unproject_position(battle_grid_instance.get_world_position_for_cell(hover_cell))
	_targeting_arrow.update_arrow(from, to, color)
	_targeting_arrow_active = true

func _get_arrow_readout_unit(hover_cell: Vector2i) -> Unit:
	if not _targeting_arrow_active or not _arrow_valid_cells.has(hover_cell):
		return null
	return _resolve_living_unit_on_cell(hover_cell) as Unit

func _update_targeting_arrow_readout(hover_cell: Vector2i) -> void:
	if not _targeting_arrow_active:
		return
	var unit := _get_arrow_readout_unit(hover_cell)
	if unit != null and _damage_preview_results.has(unit):
		var preview: Dictionary = _damage_preview_results[unit]
		_targeting_arrow.set_damage_readout(int(preview["hp_loss"]), bool(preview["lethal"]))
	else:
		_targeting_arrow.set_damage_readout(-1, false)

func _hide_targeting_arrow() -> void:
	if is_instance_valid(_selected_card_ui) and _selected_card_ui is CardUI:
		(_selected_card_ui as CardUI).clear_drag_anchor()
	if _targeting_arrow != null:
		_targeting_arrow.hide_arrow()
	_targeting_arrow_active = false
	_arrow_card_id = 0

## Side-effect-free mirror of try_play_card damage resolution (no crit roll, no dodge roll).
## Returns { Unit: {"hp_loss": int, "lethal": bool} } for every enemy the card would hit.
func _compute_card_damage_preview(card: CardData, hover_cell: Vector2i) -> Dictionary:
	var result := {}
	if card == null or not is_instance_valid(battle_grid_instance):
		return result
	var is_auto_target := card.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE \
			or card.range_type == CardData.EffectRangeType.FULL_BOARD
	var hovered: Node3D = null
	if not is_auto_target:
		if not battle_grid_instance.is_valid_grid_position(hover_cell):
			return result
		var valid_cells: Array = _collect_valid_targets_for_card(card).get("cells", [])
		if not valid_cells.has(hover_cell):
			return result
		hovered = _resolve_living_unit_on_cell(hover_cell)
	var initial_target: Node3D = _player_unit_node if is_auto_target else hovered

	# Non-damage effects resolve first, so Vulnerable from the same card already counts.
	var temp_vulnerable: Array = []
	var consecrated_bonus: int = 0
	if _player_unit_node.active_statuses.has("consecrated_weapon") and not _card_grants_consecration(card):
		consecrated_bonus = int(_player_unit_node.active_statuses["consecrated_weapon"].value)
	for effect in card.effects:
		if effect == null or effect.trigger != CardEffectData.EffectTrigger.ON_PLAY:
			continue
		if effect.effect_type != CardEffectData.EffectType.APPLY_STATUS:
			continue
		if effect.string_value == "vulnerable":
			for t in _get_targets_for_effect(effect, initial_target, card, hover_cell):
				if is_instance_valid(t) and t is Unit and not t.active_statuses.has("vulnerable") and not temp_vulnerable.has(t):
					temp_vulnerable.append(t)

	# Temporary entries so DamageCalculator/conditions see them; all erased below, no signals emitted.
	for t in temp_vulnerable:
		t.active_statuses["vulnerable"] = { "id": "vulnerable", "value": 1, "duration": 1 }
	var totals := {}
	for effect in card.effects:
		if effect == null or effect.trigger != CardEffectData.EffectTrigger.ON_PLAY:
			continue
		if not _is_damage_effect(effect):
			continue
		for target in _get_targets_for_effect(effect, initial_target, card, hover_cell):
			if not is_instance_valid(target) or not (target is Unit) or target.current_health <= 0:
				continue
			if target.get_unit_data().faction != UnitData.Faction.ENEMY:
				continue
			var hit: Dictionary = _preview_effect_damage(effect, target, card, consecrated_bonus)
			if bool(hit["used_consecrated"]):
				consecrated_bonus = 0
			if not totals.has(target):
				totals[target] = {"normal": 0, "pierce": 0}
			var bucket: String = "pierce" if hit["pierce"] else "normal"
			totals[target][bucket] = int(totals[target][bucket]) + int(hit["damage"])
	for t in temp_vulnerable:
		if is_instance_valid(t):
			t.active_statuses.erase("vulnerable")

	for target in totals:
		var t: Dictionary = totals[target]
		var hp_loss: int = int(t["pierce"]) + maxi(0, int(t["normal"]) - target.current_block)
		result[target] = {"hp_loss": hp_loss, "lethal": hp_loss >= target.current_health}
	return result

## Consecrated Weapon buffs the NEXT Holy attack, so the granting card's own hit must not consume it.
func _card_grants_consecration(card: CardData) -> bool:
	if not is_instance_valid(card):
		return false
	for e in card.effects:
		if e != null and e.effect_type == CardEffectData.EffectType.APPLY_STATUS and e.string_value == "consecrated_weapon":
			return true
	return false

func _is_damage_effect(effect: CardEffectData) -> bool:
	return effect.effect_type == CardEffectData.EffectType.DEAL_DAMAGE \
		or effect.effect_type == CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK \
		or effect.effect_type == CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK

## Mirrors the damage branches of _apply_single_effect without consuming statuses or rolling RNG.
## consecrated_bonus is consumed by the first Holy hit (caller zeroes it when used_consecrated is true).
func _preview_effect_damage(effect: CardEffectData, target: Unit, card: CardData, consecrated_bonus: int = 0) -> Dictionary:
	var none := {"damage": 0, "pierce": false, "used_consecrated": false}
	match effect.effect_type:
		CardEffectData.EffectType.DEAL_DAMAGE:
			if effect.string_value == "holy_bonus_only":
				if not is_instance_valid(target.unit_data):
					return none
				var ut: int = target.unit_data.unit_type
				if ut != UnitData.UnitType.UNDEAD and ut != UnitData.UnitType.DEMON:
					return none
				return {"damage": maxi(0, UnitData.get_holy_damage_bonus(CardEffectData.DamageType.HOLY, ut) + PlayerData.holy_damage_bonus), "pierce": false, "used_consecrated": false}
			var base_value: int = effect.value
			if _check_condition(effect, target):
				base_value += effect.conditional_bonus_value
			if effect.condition_type == "damage_per_block":
				base_value += _player_unit_node.current_block * effect.conditional_bonus_value
			var used_consecrated: bool = effect.damage_type == CardEffectData.DamageType.HOLY and consecrated_bonus > 0
			if used_consecrated:
				base_value += consecrated_bonus
			var damage := DamageCalculator.get_final_damage(base_value, _player_unit_node, target, effect.damage_type, false, true, 0)
			var pierce := false
			if has_node("/root/ArtifactManager"):
				pierce = ArtifactManager.attacks_ignore_block(target, card)
			return {"damage": damage, "pierce": pierce, "used_consecrated": used_consecrated}
		CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK:
			var block_base: int = _player_unit_node.current_block
			if effect.string_value == "half_block" or (is_instance_valid(card) and card.card_id.begins_with("shield_push")):
				block_base = block_base / 2
			if block_base <= 0:
				return none
			var block_damage := DamageCalculator.get_final_damage(block_base, _player_unit_node, target, CardEffectData.DamageType.NORMAL, false, true, 0)
			if is_instance_valid(card) and card.card_id == "shield_bash":
				block_damage = mini(block_damage, 15)
			return {"damage": block_damage, "pierce": false, "used_consecrated": false}
		CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK:
			var double_damage := DamageCalculator.get_final_damage(_player_unit_node.current_block, _player_unit_node, target, CardEffectData.DamageType.NORMAL, false, true, _player_unit_node.current_block)
			if is_instance_valid(card) and card.card_id == "shield_bash+":
				double_damage = mini(double_damage, 20)
			return {"damage": double_damage, "pierce": false, "used_consecrated": false}
	return none

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
	
	# PLAYER_CENTERED_AOE / FULL_BOARD: auto-play z pozice hráče (nepotřebuje kliknutý cíl)
	if card_to_play.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE \
			or card_to_play.range_type == CardData.EffectRangeType.FULL_BOARD:
		if is_instance_valid(_player_unit_node):
			_card_play_in_progress = true
			_clear_card_selection_state_before_play()
			try_play_card(card_to_play, _player_unit_node)
			return true
		return false
	
	var has_self_effect = _card_has_self_play_target(_selected_card_data)
	var has_enemy_effect = _card_has_enemy_play_target(_selected_card_data)
	var has_empty_cell_effect = _card_has_empty_cell_play_target(_selected_card_data)

	# Pokud karta má pouze SELF efekty (bez ENEMY efektů), použij hráče jako cíl
	if has_self_effect and not has_enemy_effect and not has_empty_cell_effect:
		if is_instance_valid(_player_unit_node):
			_card_play_in_progress = true
			_clear_card_selection_state_before_play()
			try_play_card(card_to_play, _player_unit_node)
			return true
		return false

	var target_node = _resolve_living_unit_on_cell(clicked_grid_cell)

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
	# PLAYER_CENTERED_AOE / FULL_BOARD: auto-play z pozice hráče
	if card.range_type == CardData.EffectRangeType.PLAYER_CENTERED_AOE \
			or card.range_type == CardData.EffectRangeType.FULL_BOARD:
		if is_instance_valid(_player_unit_node):
			_card_play_in_progress = true
			try_play_card(card, _player_unit_node)
			return true
		return false
	var has_self_effect = _card_has_self_play_target(card)
	var has_enemy_effect = _card_has_enemy_play_target(card)
	var has_empty_cell_effect = _card_has_empty_cell_play_target(card)
	if has_self_effect and not has_enemy_effect and not has_empty_cell_effect:
		if is_instance_valid(_player_unit_node):
			_card_play_in_progress = true
			try_play_card(card, _player_unit_node)
			return true
		return false
	var target_node = _resolve_living_unit_on_cell(clicked_grid_cell)
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

func _resolve_living_unit_on_cell(cell: Vector2i) -> Node:
	"""Grid occupancy first; if desynced (ghost), fall back to living units claiming that cell."""
	if is_instance_valid(battle_grid_instance):
		var on_grid = battle_grid_instance.get_object_on_cell(cell)
		if is_instance_valid(on_grid):
			return on_grid
	for enemy in _enemy_units:
		if is_instance_valid(enemy) and enemy.current_health > 0 and enemy.grid_position == cell:
			return enemy
	if is_instance_valid(_player_unit_node) and _player_unit_node.current_health > 0 and _player_unit_node.grid_position == cell:
		return _player_unit_node
	return null

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
				unit.apply_status(terrain.effect_string_value, terrain.effect_numeric_value, terrain.effect_duration)
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
		u0.set_synced_block(int(payload.get("player_0_block", u0.current_block)))
		var p0_statuses: Array = payload.get("player_0_statuses", [])
		if not p0_statuses.is_empty():
			u0.deserialize_statuses(p0_statuses)
		else:
			u0._update_stats_and_emit_signal()
	if is_instance_valid(u1):
		u1.current_health = int(payload.get("player_1_hp", u1.current_health))
		u1.set_synced_block(int(payload.get("player_1_block", u1.current_block)))
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
		u0.set_synced_block(int(payload.get("player_0_block", u0.current_block)))
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
		u1.set_synced_block(int(payload.get("player_1_block", u1.current_block)))
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
			await e.end_turn()
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
	unit.set_synced_block(block)
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

func _trigger_shard(unit: Unit, cell: Vector2i) -> void:
	if not is_instance_valid(unit) or not battle_grid_instance.consume_shard(cell):
		return
	unit.show_status_text(tr("status.float.shard"), "frost")
	await unit.take_damage(3, true, false, false)

func _leave_serpent_shards(unit: Unit, path: Array, final_pos: Vector2i) -> void:
	if not is_instance_valid(unit) or unit.current_health <= 0 or not unit._ai_is("CrystalSerpentAI.gd"):
		return
	var left: Array[Vector2i] = []
	for cell in path:
		if cell == final_pos:
			break
		if cell is Vector2i:
			left.append(cell)
	battle_grid_instance.place_shards(left)

func _flash_screen_line(from_cell: Vector2i, to_cell: Vector2i, color: Color, hold: float) -> void:
	var layer := get_node_or_null("CanvasLayer")
	if layer == null or camera_3d == null or battle_grid_instance == null:
		return
	var line := Line2D.new()
	line.width = 6.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var from_world := battle_grid_instance.get_world_position_for_cell(from_cell) + Vector3(0, 0.7, 0)
	var to_world := battle_grid_instance.get_world_position_for_cell(to_cell) + Vector3(0, 0.7, 0)
	line.points = PackedVector2Array([
		camera_3d.unproject_position(from_world),
		camera_3d.unproject_position(to_world),
	])
	layer.add_child(line)
	await get_tree().create_timer(hold).timeout
	if is_instance_valid(line):
		line.queue_free()

func _update_interpose_lines() -> void:
	for line in _interpose_lines:
		if is_instance_valid(line):
			line.queue_free()
	_interpose_lines.clear()
	var layer := get_node_or_null("CanvasLayer")
	if layer == null or camera_3d == null or not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("units"):
		if not (node is Unit) or node.current_health <= 0 or not node._ai_is("DwarfGuardianAI.gd"):
			continue
		var cd := int(node.get_meta("interpose_cd")) if node.has_meta("interpose_cd") else 0
		if cd > 0:
			continue
		for other in get_tree().get_nodes_in_group("units"):
			if other == node or not (other is Unit) or other.current_health <= 0 or other.unit_data == null:
				continue
			if other.unit_data.faction != node.unit_data.faction:
				continue
			var dist := absi(other.grid_position.x - node.grid_position.x) + absi(other.grid_position.y - node.grid_position.y)
			if dist != 1:
				continue
			var link := Line2D.new()
			link.width = 4.0
			link.default_color = Color(1.0, 0.82, 0.28, 0.85)
			link.points = PackedVector2Array([
				node.get_aim_screen_position(camera_3d),
				other.get_aim_screen_position(camera_3d),
			])
			layer.add_child(link)
			_interpose_lines.append(link)

func _resolve_chain_lightning(attacker: Unit, primary: Unit, origin: Vector2i, amount: int) -> void:
	if amount <= 0 or not is_instance_valid(attacker) or not battle_grid_instance.is_cell_active(origin):
		return
	var best: Unit = null
	var best_dist := 99
	for node in battle_grid_instance.get_all_objects_on_grid():
		if not (node is Unit) or node == attacker or node == primary or node.current_health <= 0:
			continue
		if node.unit_data == null or node.unit_data.faction == attacker.unit_data.faction:
			continue
		var dist := battle_grid_instance.get_distance(origin, node.grid_position)
		if dist >= 1 and dist <= 2 and dist < best_dist:
			best_dist = dist
			best = node
	if best == null:
		return
	await _flash_screen_line(origin, best.grid_position, Color(1.0, 0.92, 0.35), 0.4)
	if is_instance_valid(best) and best.current_health > 0:
		await best.take_damage(amount, true, false, false)
		if best == _player_unit_node:
			_took_damage_last_turn = true

func _resolve_combat_windup(enemy: Unit) -> void:
	if not is_instance_valid(enemy):
		return
	var data := enemy.combat_windup()
	var kind := str(data.get("kind", ""))
	var lock_turns := int(data.get("lock_turns", 0))
	var target: Unit = null
	if enemy.has_meta("windup_target") and enemy.get_meta("windup_target") is Unit:
		target = enemy.get_meta("windup_target")
	var dir := Vector2i(int(data.get("dx", 0)), int(data.get("dy", 0)))
	var cell := Vector2i(int(data.get("cx", -999)), int(data.get("cy", -999)))
	enemy.clear_combat_windup()
	if lock_turns > 0:
		enemy.set_meta("windup_lock", lock_turns)
	match kind:
		"bull_rush":
			await _resolve_bull_rush(enemy, dir)
		"crush":
			if is_instance_valid(enemy):
				enemy.set_meta("crush_rest", true)
			await _resolve_crush(enemy, cell)
		"wail":
			await _resolve_marked_hit(enemy, target, 8, "ui.banner.wail", "weakness", 1, 2, Color(0.72, 0.35, 1.0))
		"song":
			await _resolve_marked_hit(enemy, target, 3, "ui.banner.song", "silenced", 1, 1, Color(0.45, 0.62, 1.0))

func _resolve_bull_rush(enemy: Unit, dir: Vector2i) -> void:
	_show_turn_banner(tr("ui.banner.bull_rush"), Color(1.0, 0.55, 0.15))
	if dir == Vector2i.ZERO or not is_instance_valid(enemy) or enemy.current_health <= 0:
		return
	var pos := enemy.grid_position
	for _step in 3:
		var next: Vector2i = pos + dir
		if not battle_grid_instance.is_cell_active(next):
			break
		var occ = battle_grid_instance.get_object_on_cell(next)
		if occ is Unit and occ != enemy and occ.current_health > 0:
			await occ.take_damage(13, true, false, false)
			if occ == _player_unit_node:
				_took_damage_last_turn = true
			if is_instance_valid(enemy) and enemy.current_health > 0:
				await enemy.take_damage(4, true, false, false)
			break
		if is_instance_valid(occ):
			break
		var step_path: Array[Vector2i] = [pos, next]
		await _move_unit_along_path(enemy, step_path, 0.12)
		if not is_instance_valid(enemy) or enemy.current_health <= 0:
			return
		pos = enemy.grid_position
		if pos != next:
			break

func _resolve_crush(enemy: Unit, cell: Vector2i) -> void:
	_show_turn_banner(tr("ui.banner.crush"), Color(1.0, 0.45, 0.12))
	if not is_instance_valid(enemy) or not battle_grid_instance.is_cell_active(cell):
		return
	var center = battle_grid_instance.get_object_on_cell(cell)
	if center is Unit and center != enemy and center.current_health > 0:
		await center.take_damage(22, true, false, false)
		if center == _player_unit_node:
			_took_damage_last_turn = true
	if not is_instance_valid(enemy):
		return
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = cell + offset
		var splash = battle_grid_instance.get_object_on_cell(next)
		if splash is Unit and splash != enemy and splash.current_health > 0:
			await splash.take_damage(11, true, false, false)
			if splash == _player_unit_node:
				_took_damage_last_turn = true

func _resolve_marked_hit(enemy: Unit, target: Unit, amount: int, banner_key: String, status_id: String, status_value: int, status_duration: int, color: Color) -> void:
	_show_turn_banner(tr(banner_key), color)
	if not is_instance_valid(enemy) or not is_instance_valid(target) or target.current_health <= 0:
		return
	await _flash_screen_line(enemy.grid_position, target.grid_position, color, 0.4)
	if not is_instance_valid(target) or target.current_health <= 0:
		return
	await target.take_damage(amount, true, false, false)
	if target == _player_unit_node:
		_took_damage_last_turn = true
	if is_instance_valid(target) and target.current_health > 0:
		target.apply_status(status_id, status_value, status_duration)
		if status_id == "silenced":
			target.show_status_text(tr("status.float.silence"), "curse", StatusIcons.get_icon("silenced"))
		elif status_id == "weakness":
			target.show_status_text(tr("status.float.weakness"), "curse", StatusIcons.get_icon("weakness"))

func _register_spawned_enemy(unit_data: UnitData, cell: Vector2i) -> Unit:
	var node := _spawn_unit(unit_data, cell)
	if not is_instance_valid(node):
		return null
	if node.unit_data:
		node.unit_data.faction = UnitData.Faction.ENEMY
	_enemy_units.append(node)
	_all_enemy_units_ordered.append(node)
	node.died.connect(_on_unit_died)
	node.stats_changed.connect(_on_unit_stats_changed)
	if has_node("/root/TurnManager"):
		TurnManager.add_unit(node)
	if is_instance_valid(initiative_bar) and initiative_bar.has_method("refresh_from_turn_manager"):
		initiative_bar.refresh_from_turn_manager()
	return node

func _raise_dead(necro: Unit, cell: Vector2i) -> void:
	_show_turn_banner(tr("ui.banner.raise"), Color(0.72, 0.72, 0.78))
	if not is_instance_valid(necro) or not battle_grid_instance.is_cell_active(cell):
		return
	if is_instance_valid(battle_grid_instance.get_object_on_cell(cell)):
		return
	battle_grid_instance.flash_ground_cell(cell, Color(0.55, 0.55, 0.62, 0.5))
	var data := load("res://data/units/raised_skeleton.tres") as UnitData
	var skel := _register_spawned_enemy(data, cell)
	if is_instance_valid(skel):
		skel.set_meta("owner_id", necro.get_instance_id())
	set_enemy_intents()

func _harvest_corpse(necro: Unit, cell: Vector2i) -> void:
	if not is_instance_valid(necro) or not battle_grid_instance.has_method("has_corpse"):
		return
	if not battle_grid_instance.has_corpse(cell):
		return
	await _flash_screen_line(cell, necro.grid_position, Color(0.62, 0.62, 0.68), 0.35)
	if not is_instance_valid(necro) or necro.current_health <= 0:
		return
	if battle_grid_instance.take_corpse(cell):
		necro.heal(8)

func _lay_egg(mother: Unit, cell: Vector2i) -> void:
	_show_turn_banner(tr("ui.banner.egg"), Color(0.9, 0.42, 0.14))
	if not is_instance_valid(mother) or not battle_grid_instance.is_cell_active(cell):
		return
	if is_instance_valid(battle_grid_instance.get_object_on_cell(cell)):
		return
	battle_grid_instance.flash_ground_cell(cell, Color(1.0, 0.45, 0.12, 0.5))
	var data := load("res://data/units/cocoon.tres") as UnitData
	var egg := _register_spawned_enemy(data, cell)
	if is_instance_valid(egg):
		egg.set_meta("owner_id", mother.get_instance_id())
		egg.set_meta("hatch_turns", 2)
		egg.set_meta("just_laid", true)
		egg.set_meta("no_corpse", true)
	set_enemy_intents()

func _hatch_cocoon(cocoon: Unit) -> void:
	if not is_instance_valid(cocoon):
		return
	var cell := cocoon.grid_position
	_show_turn_banner(tr("ui.banner.hatch"), Color(0.95, 0.38, 0.12))
	cocoon.set_meta("no_corpse", true)
	battle_grid_instance.remove_object_by_instance(cocoon)
	var data := load("res://data/units/spiderling.tres") as UnitData
	var spider := _register_spawned_enemy(data, cell)
	if _enemy_units.has(cocoon):
		_enemy_units.erase(cocoon)
	if _all_enemy_units_ordered.has(cocoon):
		_all_enemy_units_ordered.erase(cocoon)
	if has_node("/root/TurnManager"):
		TurnManager.unregister_unit(cocoon)
	if is_instance_valid(cocoon):
		cocoon.queue_free()
	set_enemy_intents()
	if not is_instance_valid(spider):
		return

func _inoculate(doctor: Unit, ally: Unit, block_amount: int) -> void:
	_show_turn_banner(tr("ui.banner.inoculate"), Color(0.35, 0.82, 0.4))
	if not is_instance_valid(doctor) or not is_instance_valid(ally) or ally.current_health <= 0:
		return
	await _flash_screen_line(doctor.grid_position, ally.grid_position, Color(0.4, 0.9, 0.45), 0.35)
	if not is_instance_valid(ally) or ally.current_health <= 0:
		return
	if ally.has_method("cleanse_harmful"):
		ally.cleanse_harmful()
	ally.add_block(block_amount)

func _plague_mark(doctor: Unit, target: Unit) -> void:
	if not is_instance_valid(doctor) or not is_instance_valid(target) or target.current_health <= 0:
		return
	if battle_grid_instance.get_distance(doctor.grid_position, target.grid_position) > doctor.unit_data.attack_range:
		return
	await doctor.attack(target)
	if target == _player_unit_node:
		_took_damage_last_turn = true
	if not is_instance_valid(target) or target.current_health <= 0:
		return
	if target.has_method("apply_plague"):
		target.apply_plague()
	target.show_status_text(tr("status.float.plague"), "plague")
	battle_grid_instance.flash_ground_cell(target.grid_position, Color(0.28, 0.86, 0.34, 0.55))

func _process_special_action(enemy_unit: Unit, action: EnemyAIBase.AIAction) -> void:
	"""Zpracuje speciální akce AI (všechny typy)"""
	var special_type = action.special_data.get("type", "")
	
	match special_type:
		"begin_windup":
			var banner_key := str(action.special_data.get("banner", ""))
			if banner_key != "":
				_show_turn_banner(tr(banner_key), Color(1.0, 0.55, 0.2))
		"raise_dead":
			_raise_dead(enemy_unit, action.special_data.get("cell", Vector2i(-999, -999)))
		"corpse_harvest":
			await _harvest_corpse(enemy_unit, action.special_data.get("cell", Vector2i(-999, -999)))
		"lay_egg":
			_lay_egg(enemy_unit, action.special_data.get("cell", Vector2i(-999, -999)))
		"hatch_egg":
			_hatch_cocoon(enemy_unit)
		"armor_restore":
			if is_instance_valid(enemy_unit) and enemy_unit.has_method("restore_armor_from_core"):
				enemy_unit.restore_armor_from_core()
		"inoculate":
			await _inoculate(enemy_unit, action.target_unit, int(action.special_data.get("block", 6)))
		"plague_mark":
			await _plague_mark(enemy_unit, action.target_unit)
		"resolve_windup":
			await _resolve_combat_windup(enemy_unit)
		"temptation":
			var pull_target: Unit = action.target_unit
			var pull_dest: Vector2i = action.special_data.get("dest", Vector2i(-999, -999))
			if is_instance_valid(pull_target) and pull_target.current_health > 0 and pull_dest.x > -900:
				if battle_grid_instance.get_distance(pull_target.grid_position, pull_dest) == 1 and not is_instance_valid(battle_grid_instance.get_object_on_cell(pull_dest)):
					await _flash_screen_line(pull_target.grid_position, pull_dest, Color(0.35, 0.65, 1.0), 0.35)
					if is_instance_valid(pull_target) and pull_target.current_health > 0:
						var pull_path: Array[Vector2i] = [pull_target.grid_position, pull_dest]
						await _move_unit_along_path(pull_target, pull_path, 0.16)
		# ===== MAGE SPELLS =====
		"meteor":
			enemy_unit.show_status_text("METEORIT!", "critical")
			await get_tree().create_timer(1.0).timeout
			
			var base_dmg = enemy_unit.unit_data.attack_damage
			var extra = base_dmg + enemy_unit.get_bonus_attack_damage()
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			
			for unit in all_units:
				if is_instance_valid(unit) and unit is Unit:
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
					spirit_node.set_meta("summoner", enemy_unit)
					if not enemy_unit.has_meta("summoned_units"):
						enemy_unit.set_meta("summoned_units", [])
					var summoned: Array = enemy_unit.get_meta("summoned_units")
					summoned.append(spirit_node)
					enemy_unit.set_meta("summoned_units", summoned)
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
				if is_instance_valid(unit) and unit is Unit and unit != enemy_unit:
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
				if is_instance_valid(unit) and unit is Unit and unit != enemy_unit:
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
			extra += enemy_unit.get_bonus_attack_damage()
			var all_units = battle_grid_instance.get_all_objects_on_grid()
			for unit in all_units:
				if is_instance_valid(unit) and unit is Unit and unit != enemy_unit:
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
				if is_instance_valid(unit) and unit is Unit and unit != enemy_unit:
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
		"seismic_slam":
			var slam_damage := int(action.special_data.get("damage", 5))
			enemy_unit.show_status_text(tr("status.float.slam"), "damage")
			await get_tree().create_timer(0.35).timeout
			var slam_units = battle_grid_instance.get_all_objects_on_grid()
			for unit in slam_units:
				if is_instance_valid(unit) and unit is Unit and unit != enemy_unit and unit.current_health > 0:
					if unit.unit_data.faction != enemy_unit.unit_data.faction:
						var dist = battle_grid_instance.get_distance(enemy_unit.grid_position, unit.grid_position)
						if dist == 1:
							await unit.take_damage(slam_damage, true, false, false)
							if unit == _player_unit_node:
								_took_damage_last_turn = true
		"wing_gust":
			var gust_target: Unit = action.target_unit
			var dest: Vector2i = action.special_data.get("dest", Vector2i(-999, -999))
			if is_instance_valid(gust_target) and gust_target.current_health > 0 and dest.x > -900:
				if battle_grid_instance.get_distance(gust_target.grid_position, dest) == 1:
					var occ = battle_grid_instance.get_object_on_cell(dest)
					if not is_instance_valid(occ):
						gust_target.show_status_text(tr("status.float.gust"), "damage")
						var gust_path: Array[Vector2i] = [gust_target.grid_position, dest]
						await _move_unit_along_path(gust_target, gust_path, 0.18)
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
				if is_instance_valid(unit) and unit is Unit and unit != enemy_unit:
					if unit.unit_data.faction == enemy_unit.unit_data.faction:
						unit.apply_status("monk_blessing", buff_amount, duration)
						unit.show_status_text("EMPOWERED!", "heal")
		
		_:
			print("Neznámý typ speciální akce: %s" % special_type)

func _find_spawn_position(near_unit: Unit) -> Vector2i:
	"""Najde volnou pozici pro spawn: nejdřív adjacent, pak BFS dál. Nikdy na obsazené / ghost buňky."""
	if not is_instance_valid(near_unit) or not is_instance_valid(battle_grid_instance):
		return Vector2i(-1, -1)

	var origin: Vector2i = near_unit.grid_position
	var occupied: Dictionary = {}
	for obj in battle_grid_instance.get_all_objects_on_grid():
		if is_instance_valid(obj) and "grid_position" in obj:
			occupied[obj.grid_position] = true
	# Also treat living units' claimed grid_position as occupied (guards against grid desync ghosts).
	for enemy in _enemy_units:
		if is_instance_valid(enemy) and enemy.current_health > 0:
			occupied[enemy.grid_position] = true
	if is_instance_valid(_player_unit_node) and _player_unit_node.current_health > 0:
		occupied[_player_unit_node.grid_position] = true
	occupied[origin] = true

	var adjacent: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in adjacent:
		var pos: Vector2i = origin + offset
		if battle_grid_instance.is_cell_active(pos) and not occupied.has(pos) and battle_grid_instance.get_object_on_cell(pos) == null:
			return pos

	# BFS ring search up to distance 4
	var visited: Dictionary = {origin: true}
	var queue: Array[Vector2i] = [origin]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for offset in adjacent:
			var pos: Vector2i = current + offset
			if visited.has(pos):
				continue
			visited[pos] = true
			if not battle_grid_instance.is_cell_active(pos):
				continue
			if battle_grid_instance.get_distance(origin, pos) > 4:
				continue
			queue.append(pos)
			if not occupied.has(pos) and battle_grid_instance.get_object_on_cell(pos) == null:
				return pos

	return Vector2i(-1, -1)
