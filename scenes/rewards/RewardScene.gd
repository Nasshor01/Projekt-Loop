# Soubor: scenes/rewards/RewardScene.gd (OPRAVENÁ VERZE)
extends PanelContainer

# --- Proměnné, které nastaví GameManager ---
var gold_reward: int = 0
var card_choices: Array = []
var artifact_rewards: Array = []
var encounter_type: int = EncounterData.EncounterType.NORMAL

# Kolik zlata dostane hráč za skip karty po běžném monsteru (cashback)
const SKIP_CARD_GOLD_NORMAL: int = 10

# --- Přednačtené scény ---
const CardUIScene = preload("res://scenes/ui/CardUI.tscn")
const ArtifactChoiceUIScene = preload("res://scenes/ui/ArtifactChoiceUI.tscn")
const REWARD_CARD_SIZE = CardUI.DESIGN_SIZE
const REWARD_CARD_SCALE = Vector2(0.95, 0.95)

# --- Cesty k UI prvkům ---
@onready var title_label: Label = $VBoxContainer/ScrollContainer/ScrollContent/CenterContainer/TitleLabel
@onready var gold_label: Label = $VBoxContainer/ScrollContainer/ScrollContent/GoldRewardDisplay/GoldLabel
@onready var card_container: HBoxContainer = $VBoxContainer/ScrollContainer/ScrollContent/CardContainer
@onready var artifact_container: HBoxContainer = $VBoxContainer/ScrollContainer/ScrollContent/ArtifactContainer
@onready var skip_button: Button = $VBoxContainer/SkipButton
@onready var card_tooltip: CardTooltip = $CanvasLayer/CardTooltip
@onready var tutorial_hint_label: Label = $VBoxContainer/ScrollContainer/ScrollContent/TutorialHintLabel
@onready var tutorial_card_added_label: Label = $VBoxContainer/ScrollContainer/ScrollContent/TutorialCardAddedLabel

# Tooltip management
var _current_tooltip_card_data: CardData = null
var _tutorial_return_to_menu := false
var _tutorial_hint_text := ""
var _tutorial_final_reward := false
# Coop shared reward
var _coop_my_choice_path: String = ""      # cesta ke kartě, kterou jsem vybral (prázdná = ještě nevybral)
var _coop_other_choice_path: String = ""   # cesta ke kartě druhého hráče
var _coop_my_skipped: bool = false         # skipnul jsem?
var _coop_other_done: bool = false         # druhý hráč vybral/skipnul?

func _ready():
	# Jen inicializace, ŽÁDNÁ logika pro UI
	print("DEBUG: RewardScene._ready() volán")
	
	# Tooltip se nyní zobrazuje/schovává pomocí pravého kliknutí - žádné timery nejsou potřeba


func setup_ui():
	print("DEBUG: setup_ui() volán")
	print("DEBUG: gold_reward = ", gold_reward)
	print("DEBUG: card_choices.size() = ", card_choices.size())
	print("DEBUG: artifact_rewards.size() = ", artifact_rewards.size())
	
	_apply_tutorial_overrides()
	
	# 1. Zlato
	PlayerData.add_gold(gold_reward)
	if gold_reward > 0:
		gold_label.text = TranslationHelper.tr_format("ui.reward.gold", {"value": gold_reward})
		gold_label.visible = true
	else:
		gold_label.visible = false
		
	# 2. Karty
	if not card_choices.is_empty():
		title_label.text = tr("ui.reward.choose_card")
		card_container.alignment = BoxContainer.ALIGNMENT_CENTER
		card_container.add_theme_constant_override("separation", 50)
		if tutorial_card_added_label:
			tutorial_card_added_label.text = tr("ui.reward.tutorial_card_added")
		for card_data in card_choices:
			var card_ui = CardUIScene.instantiate()
			card_container.add_child(card_ui)
			card_ui.load_card(card_data)
			if card_ui is CardUI:
				card_ui.apply_display_mode(CardUI.DisplayMode.REWARD)
				card_ui.custom_minimum_size = REWARD_CARD_SIZE
				card_ui.pivot_offset = card_ui.custom_minimum_size * 0.5
				card_ui.set_process(false)
				call_deferred("_sync_reward_card_layout", card_ui)
			card_ui.card_clicked.connect(_on_card_clicked)
			card_ui.card_right_clicked.connect(_on_card_right_clicked)
	else:
		card_container.visible = false
		
	# 3. Artefakty
	if not artifact_rewards.is_empty():
		# Pokud nejsou karty, změníme nadpis
		if card_choices.is_empty():
			title_label.text = tr("ui.reward.title")
		
		# Vytvoříme UI pro artefakty
		for artifact_data in artifact_rewards:
			var artifact_ui = ArtifactChoiceUIScene.instantiate()
			artifact_container.add_child(artifact_ui)
			artifact_ui.display_artifact(artifact_data)
			artifact_ui.artifact_chosen.connect(_on_artifact_selected)
	else:
		artifact_container.visible = false
		
	# 4. Tlačítko "Přeskočit" / "Pokračovat"
	# TEPRVE NYNÍ nastavujeme tlačítko, když už máme správné hodnoty
	if card_choices.is_empty() and artifact_rewards.is_empty():
		skip_button.text = tr("ui.common.continue")
		skip_button.pressed.connect(_finish_reward)
	# Pokud jsou jen artefakty na výběr (např. po bossovi)
	elif card_choices.is_empty() and not artifact_rewards.is_empty():
		skip_button.visible = false # Po bossovi si musíš vybrat
	# Standardní situace s výběrem karty
	else:
		if encounter_type == EncounterData.EncounterType.NORMAL:
			skip_button.text = TranslationHelper.tr_format("ui.reward.skip_card_gold", {"value": SKIP_CARD_GOLD_NORMAL})
		else:
			skip_button.text = tr("ui.reward.skip_card")
		skip_button.pressed.connect(_on_skip_pressed)
	
	if has_node("/root/GameManager") and GameManager.tutorial_active and GameManager.tutorial_step == GameManager.TUTORIAL_STEP_REWARD_1:
		skip_button.visible = false

func _is_coop() -> bool:
	return has_node("/root/GameManager") and GameManager.is_coop_run and has_node("/root/MultiplayerManager") and MultiplayerManager.has_active_connection()

func _on_card_clicked(card_to_add: CardData):
	if _is_coop():
		_coop_on_card_clicked(card_to_add)
		return
	# Solo: výběr karty
	PlayerData.master_deck.append(card_to_add)
	for child in card_container.get_children():
		child.mouse_filter = MOUSE_FILTER_IGNORE
	card_container.visible = false
	skip_button.disabled = true
	if artifact_container.get_child_count() == 0:
		if _tutorial_return_to_menu:
			_show_tutorial_card_added()
			await get_tree().create_timer(0.8).timeout
		_finish_reward()
	else:
		skip_button.text = tr("ui.common.continue")
		skip_button.disabled = false
		if skip_button.pressed.is_connected(_on_skip_pressed):
			skip_button.pressed.disconnect(_on_skip_pressed)
		skip_button.pressed.connect(_finish_reward)

func _on_skip_pressed():
	if _is_coop():
		_coop_on_skip()
		return
	if encounter_type == EncounterData.EncounterType.NORMAL and not card_choices.is_empty():
		PlayerData.add_gold(SKIP_CARD_GOLD_NORMAL)
		if gold_reward > 0:
			gold_label.text = TranslationHelper.tr_format("ui.reward.gold", {"value": gold_reward + SKIP_CARD_GOLD_NORMAL})
		else:
			gold_label.visible = true
			gold_label.text = TranslationHelper.tr_format("ui.reward.gold", {"value": SKIP_CARD_GOLD_NORMAL})
	_finish_reward()

# ===== COOP sdílený reward =====

func _coop_on_card_clicked(card_to_add: CardData):
	"""Lokální hráč klikl na kartu v coop reward – toggle (klik znovu = odznačení)."""
	if _coop_my_skipped:
		return
	# Toggle: kliknutí na STEJNOU kartu = odznačit
	if _coop_my_choice_path == card_to_add.resource_path:
		# Odebrat kartu z decku
		for i in range(PlayerData.master_deck.size() - 1, -1, -1):
			if PlayerData.master_deck[i].resource_path == _coop_my_choice_path:
				PlayerData.master_deck.remove_at(i)
				break
		_coop_my_choice_path = ""
		skip_button.disabled = false
		_coop_update_card_visuals()
		rpc("_rpc_coop_reward_card_deselected")
		return
	# Nelze vzít kartu, kterou má druhý hráč
	if card_to_add.resource_path == _coop_other_choice_path:
		return
	# Pokud už mám jinou kartu vybranou, nejdřív ji odeberu
	if not _coop_my_choice_path.is_empty():
		for i in range(PlayerData.master_deck.size() - 1, -1, -1):
			if PlayerData.master_deck[i].resource_path == _coop_my_choice_path:
				PlayerData.master_deck.remove_at(i)
				break
	_coop_my_choice_path = card_to_add.resource_path
	PlayerData.master_deck.append(card_to_add)
	_coop_update_card_visuals()
	skip_button.disabled = true
	rpc("_rpc_coop_reward_card_chosen", card_to_add.resource_path)
	_coop_check_both_done()

func _coop_on_skip():
	"""Lokální hráč přeskočil (skip) v coop reward."""
	if not _coop_my_choice_path.is_empty() or _coop_my_skipped:
		return
	_coop_my_skipped = true
	if encounter_type == EncounterData.EncounterType.NORMAL and not card_choices.is_empty():
		PlayerData.add_gold(SKIP_CARD_GOLD_NORMAL)
	# Disable vstup
	skip_button.disabled = true
	for child in card_container.get_children():
		child.mouse_filter = MOUSE_FILTER_IGNORE
	rpc("_rpc_coop_reward_skipped")
	_coop_check_both_done()

@rpc("any_peer", "call_remote")
func _rpc_coop_reward_card_chosen(card_path: String):
	"""Druhý hráč vybral (nebo změnil) kartu – jen vizuální update, karta se do MÉHO decku NEDÁVÁ."""
	_coop_other_choice_path = card_path
	_coop_other_done = true
	_coop_update_card_visuals()
	_coop_check_both_done()

@rpc("any_peer", "call_remote")
func _rpc_coop_reward_card_deselected():
	"""Druhý hráč odznačil svou kartu."""
	_coop_other_choice_path = ""
	_coop_other_done = false
	_coop_update_card_visuals()

@rpc("any_peer", "call_remote")
func _rpc_coop_reward_skipped():
	"""Druhý hráč přeskočil."""
	_coop_other_done = true
	_coop_update_card_visuals()
	_coop_check_both_done()

func _coop_update_card_visuals():
	"""Vizuální aktualizace karet: moje = zelená (klikatelná pro odznačení), druhého = modrá (disable)."""
	for child in card_container.get_children():
		if not child is CardUI:
			continue
		var card_data_node: CardData = child.card_data if "card_data" in child else null
		if not card_data_node:
			continue
		var path = card_data_node.resource_path
		if path == _coop_my_choice_path:
			child.modulate = Color(0.5, 1.0, 0.5) # zelená = moje
			child.mouse_filter = MOUSE_FILTER_STOP  # Klikatelná pro odznačení
		elif path == _coop_other_choice_path:
			child.modulate = Color(0.4, 0.6, 1.0) # modrá = druhý hráč
			child.mouse_filter = MOUSE_FILTER_IGNORE
		elif _coop_my_skipped:
			child.modulate = Color(0.7, 0.7, 0.7)
			child.mouse_filter = MOUSE_FILTER_IGNORE
		else:
			# Karta je volná – normální barva, klikatelná
			child.modulate = Color(1, 1, 1)
			child.mouse_filter = MOUSE_FILTER_STOP
	# Skip button
	if _coop_my_skipped:
		skip_button.disabled = true
	elif not _coop_my_choice_path.is_empty():
		skip_button.disabled = true
	else:
		skip_button.disabled = false

func _coop_check_both_done():
	"""Pokud oba vybrali/skipli, přejít na mapu."""
	var i_am_done = not _coop_my_choice_path.is_empty() or _coop_my_skipped
	if i_am_done and _coop_other_done:
		# Krátká pauza aby oba viděli výsledek
		await get_tree().create_timer(0.8).timeout
		# Po pauze ověříme znovu – někdo mohl odznačit kartu
		var still_done = (not _coop_my_choice_path.is_empty() or _coop_my_skipped) and _coop_other_done
		if still_done:
			_finish_reward()

func _on_artifact_selected(artifact_to_add: ArtifactsData):
	PlayerData.add_artifact(artifact_to_add)
	# Deaktivujeme všechny ostatní volby artefaktů, aby hráč mohl vybrat jen jeden
	for child in artifact_container.get_children():
		child.mouse_filter = MOUSE_FILTER_IGNORE
		if child.artifact_data != artifact_to_add:
			child.modulate = Color(0.5, 0.5, 0.5)
	skip_button.disabled = true
	# Po výběru artefaktu rovnou jdeme na mapu
	_finish_reward()

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

func _on_card_hovered(card_data: CardData):
	if not card_tooltip:
		return
	_current_tooltip_card_data = card_data
	_show_card_tooltip()

func _on_card_hover_exited():
	if not card_tooltip:
		return
	card_tooltip.hide_tooltip()
	_current_tooltip_card_data = null

func _show_card_tooltip():
	"""Zobrazí tooltip pro aktuálně vybranou kartu"""
	if not _current_tooltip_card_data or not card_tooltip:
		return
	
	# Preferovaný roh; CardTooltip si pozici clampne pod GlobalUI lištu a do viewportu.
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(360, 420)
	var tooltip_pos = Vector2(
		screen_size.x - tooltip_size.x - 20,
		90  # Pod GlobalUI top bar (80px) + malý odstup
	)
	card_tooltip.show_tooltip(_current_tooltip_card_data, tooltip_pos)

func _apply_tutorial_overrides():
	if not Engine.is_editor_hint() and has_node("/root/GameManager"):
		var rewards = GameManager.last_battle_rewards
		if rewards.has("tutorial_return_to_menu"):
			_tutorial_return_to_menu = bool(rewards.get("tutorial_return_to_menu", false))
		if rewards.has("tutorial_hint_text"):
			_tutorial_hint_text = str(rewards.get("tutorial_hint_text", ""))
		if GameManager.tutorial_active and GameManager.tutorial_step == GameManager.TUTORIAL_STEP_FINAL_REWARD:
			_tutorial_final_reward = true
	
	if is_instance_valid(tutorial_hint_label) and _tutorial_hint_text != "":
		tutorial_hint_label.visible = true
		tutorial_hint_label.text = _tutorial_hint_text

func _show_tutorial_card_added():
	if is_instance_valid(tutorial_card_added_label):
		tutorial_card_added_label.visible = true

func _sync_reward_card_layout(card_ui: CardUI):
	if not is_instance_valid(card_ui):
		return
	card_ui.set_target_position(card_ui.position)

func _finish_reward():
	if _tutorial_final_reward and has_node("/root/GameManager"):
		SaveManager.set_tutorial_completed(true)
		GameManager.tutorial_active = false
		GameManager.tutorial_step = GameManager.TUTORIAL_STEP_COMPLETE
		GameManager.go_to_main_menu()
	elif _tutorial_return_to_menu:
		SaveManager.set_tutorial_completed(true)
		GameManager.go_to_main_menu()
	elif has_node("/root/GameManager") and GameManager.tutorial_active and GameManager.tutorial_step == GameManager.TUTORIAL_STEP_REWARD_1:
		GameManager.tutorial_step = GameManager.TUTORIAL_STEP_MAP_CAMP
		GameManager.reward_chosen()
	else:
		GameManager.reward_chosen()
