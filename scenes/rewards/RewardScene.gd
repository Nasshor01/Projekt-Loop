# Soubor: scenes/rewards/RewardScene.gd
extends CanvasLayer

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
const REWARD_HOVER_SCALE := 1.06

@onready var title_label: Label = %TitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var gold_display: HBoxContainer = %GoldRewardDisplay
@onready var skip_button: Button = %SkipButton
@onready var card_tooltip: CardTooltip = %CardTooltip
@onready var tutorial_hint_label: Label = %TutorialHintLabel
@onready var tutorial_card_added_label: Label = %TutorialCardAddedLabel

var card_slots: Array[LayoutSlot] = []
var artifact_slots: Array[LayoutSlot] = []

# Tooltip management
var _current_tooltip_card_data: CardData = null
var _tutorial_return_to_menu := false
var _tutorial_hint_text := ""
var _tutorial_final_reward := false
# Combo reward (elite): artifact + card — can take both, or card/skip without artifact
var _combo_mode: bool = false
var _artifact_claimed: bool = false
var _card_resolved: bool = false
# Coop shared reward
var _coop_my_choice_path: String = ""      # cesta ke kartě, kterou jsem vybral (prázdná = ještě nevybral)
var _coop_other_choice_path: String = ""   # cesta ke kartě druhého hráče
var _coop_my_skipped: bool = false         # skipnul jsem?
var _coop_other_done: bool = false         # druhý hráč vybral/skipnul?
var _reward_hover_ready: bool = false
var _reward_hovered_card: CardUI = null
var _reward_hover_tweens: Dictionary = {}  # CardUI -> Tween

func _ready():
	# Jen inicializace, ŽÁDNÁ logika pro UI
	print("DEBUG: RewardScene._ready() volán")
	_collect_layout_slots()
	for slot in card_slots:
		if is_instance_valid(slot):
			slot.visible = false
	for slot in artifact_slots:
		if is_instance_valid(slot):
			slot.visible = false
	
	# Tooltip se nyní zobrazuje/schovává pomocí pravého kliknutí - žádné timery nejsou potřeba


func _collect_layout_slots() -> void:
	"""Picks up CardSlot_0..N / ArtifactSlot_0..N from Slots — add more in editor freely."""
	card_slots.clear()
	artifact_slots.clear()
	var root := get_node_or_null("Slots")
	if root == null:
		return
	var i := 0
	while true:
		var slot := root.get_node_or_null("CardSlot_%d" % i) as LayoutSlot
		if slot == null:
			break
		card_slots.append(slot)
		i += 1
	i = 0
	while true:
		var slot := root.get_node_or_null("ArtifactSlot_%d" % i) as LayoutSlot
		if slot == null:
			break
		artifact_slots.append(slot)
		i += 1
	print("DEBUG: layout slots cards=", card_slots.size(), " artifacts=", artifact_slots.size())


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
		gold_display.visible = true
	else:
		gold_display.visible = false

	var has_cards := not card_choices.is_empty()
	var has_artifacts := not artifact_rewards.is_empty()
	_combo_mode = has_cards and has_artifacts
	_artifact_claimed = false
	_card_resolved = false

	# 2. Karty → CardSlot_i
	for slot in card_slots:
		slot.visible = false
		slot.clear_mounted()
	if has_cards:
		title_label.text = tr("ui.reward.choose_card")
		if tutorial_card_added_label:
			tutorial_card_added_label.text = tr("ui.reward.tutorial_card_added")
		for i in range(card_choices.size()):
			if i >= card_slots.size():
				break
			var card_data: CardData = card_choices[i]
			var slot: LayoutSlot = card_slots[i]
			slot.visible = true
			var card_ui: CardUI = CardUIScene.instantiate()
			slot.mount(card_ui)
			card_ui.load_card(card_data)
			card_ui.apply_display_mode(CardUI.DisplayMode.REWARD)
			card_ui.custom_minimum_size = REWARD_CARD_SIZE
			card_ui.size = REWARD_CARD_SIZE
			card_ui.set_process(false)
			card_ui.card_clicked.connect(_on_card_clicked)
			card_ui.card_right_clicked.connect(_on_card_right_clicked)
			slot.fit_mounted()
			call_deferred("_sync_reward_card_layout", card_ui)
		# Hover až po layoutu — jinak spawn pod kurzorem spustí falešný mouse_entered.
		call_deferred("_enable_reward_card_hover")

	# 3. Artefakty → ArtifactSlot_i
	for slot in artifact_slots:
		slot.visible = false
		slot.clear_mounted()
	if has_artifacts:
		if not has_cards:
			title_label.text = tr("ui.reward.title")
		for i in range(artifact_rewards.size()):
			if i >= artifact_slots.size():
				break
			var artifact_data: ArtifactsData = artifact_rewards[i]
			var slot: LayoutSlot = artifact_slots[i]
			slot.visible = true
			var artifact_ui = ArtifactChoiceUIScene.instantiate()
			slot.mount(artifact_ui)
			artifact_ui.set_icon_only(true)
			artifact_ui.display_artifact(artifact_data)
			artifact_ui.artifact_chosen.connect(_on_artifact_selected)
			slot.fit_mounted()
		
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
	_card_resolved = true
	for card_ui in _iter_reward_card_uis():
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in card_slots:
		slot.visible = false
	skip_button.disabled = true
	# Elite combo: karta bez artefaktu = artefakt přeskočen
	if _combo_mode and not _artifact_claimed:
		_hide_untaken_artifacts()
	if _tutorial_return_to_menu:
		_show_tutorial_card_added()
		await get_tree().create_timer(0.8).timeout
	_finish_reward()

func _on_skip_pressed():
	if _is_coop():
		_coop_on_skip()
		return
	_card_resolved = true
	if encounter_type == EncounterData.EncounterType.NORMAL and not card_choices.is_empty():
		PlayerData.add_gold(SKIP_CARD_GOLD_NORMAL)
		if gold_reward > 0:
			gold_label.text = TranslationHelper.tr_format("ui.reward.gold", {"value": gold_reward + SKIP_CARD_GOLD_NORMAL})
			gold_display.visible = true
		else:
			gold_display.visible = true
			gold_label.text = TranslationHelper.tr_format("ui.reward.gold", {"value": SKIP_CARD_GOLD_NORMAL})
	# Elite combo: skip karty bez artefaktu = artefakt nebereš
	if _combo_mode and not _artifact_claimed:
		_hide_untaken_artifacts()
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
	for card_ui in _iter_reward_card_uis():
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	for child in _iter_reward_card_uis():
		var card_data_node: CardData = child.card_data
		if not card_data_node:
			continue
		var path = card_data_node.resource_path
		if path == _coop_my_choice_path:
			child.modulate = Color(0.5, 1.0, 0.5) # zelená = moje
			child.mouse_filter = Control.MOUSE_FILTER_STOP  # Klikatelná pro odznačení
		elif path == _coop_other_choice_path:
			child.modulate = Color(0.4, 0.6, 1.0) # modrá = druhý hráč
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif _coop_my_skipped:
			child.modulate = Color(0.7, 0.7, 0.7)
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			# Karta je volná – normální barva, klikatelná
			child.modulate = Color(1, 1, 1)
			child.mouse_filter = Control.MOUSE_FILTER_STOP
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
	if _artifact_claimed:
		return
	PlayerData.add_artifact(artifact_to_add)
	_artifact_claimed = true
	# Deaktivujeme všechny volby artefaktů; vybraný zvýrazníme
	for child in _iter_reward_artifact_uis():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if child.artifact_data != artifact_to_add:
			child.modulate = Color(0.5, 0.5, 0.5)
		else:
			child.modulate = Color(0.55, 1.0, 0.55)
	# Elite combo: artefakt vzatý — ještě karta nebo skip
	if _combo_mode and not _card_resolved:
		title_label.text = tr("ui.reward.choose_card")
		return
	# Boss-only (nebo karta už vyřešená): končíme
	skip_button.disabled = true
	_finish_reward()


func _hide_untaken_artifacts() -> void:
	for slot in artifact_slots:
		if not is_instance_valid(slot):
			continue
		var mounted := slot.get_mounted()
		if is_instance_valid(mounted):
			mounted.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.visible = false

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
	"""Tooltip vedle vybrané karty — ne přes ostatní volby."""
	if not _current_tooltip_card_data or not card_tooltip:
		return

	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(360, 420)
	var tip_pos := Vector2(20, 90)

	var card_ui := _find_reward_card_ui(_current_tooltip_card_data)
	if is_instance_valid(card_ui):
		var card_rect := Rect2(card_ui.global_position, card_ui.get_scaled_size())
		var space_right: float = screen_size.x - card_rect.position.x - card_rect.size.x - 16.0
		var space_left: float = card_rect.position.x - 16.0
		if space_right >= tooltip_size.x or space_right >= space_left:
			tip_pos.x = card_rect.position.x + card_rect.size.x + 12.0
		else:
			tip_pos.x = card_rect.position.x - tooltip_size.x - 12.0
		tip_pos.y = card_rect.position.y
	else:
		# Fallback: levý roh — nepřekrývá pravou část gridu
		tip_pos = Vector2(20, 90)

	card_tooltip.show_tooltip(_current_tooltip_card_data, tip_pos)

func _find_reward_card_ui(card_data: CardData) -> CardUI:
	for card_ui in _iter_reward_card_uis():
		var cd: CardData = card_ui.card_data
		if cd == card_data:
			return card_ui
		if cd and card_data and cd.resource_path == card_data.resource_path and not card_data.resource_path.is_empty():
			return card_ui
	return null

func _iter_reward_card_uis() -> Array[CardUI]:
	var cards: Array[CardUI] = []
	for slot in card_slots:
		if not is_instance_valid(slot) or not slot.visible:
			continue
		var mounted := slot.get_mounted()
		if mounted is CardUI:
			cards.append(mounted as CardUI)
	return cards

func _iter_reward_artifact_uis() -> Array:
	var arts: Array = []
	for slot in artifact_slots:
		if not is_instance_valid(slot) or not slot.visible:
			continue
		var mounted := slot.get_mounted()
		if is_instance_valid(mounted):
			arts.append(mounted)
	return arts

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

func _enable_reward_card_hover() -> void:
	"""Počkej na layout slotů, reset scale, teprve pak zapni hover."""
	await get_tree().process_frame
	await get_tree().process_frame
	_reward_hover_ready = true
	_reward_hovered_card = null
	for card_ui in _iter_reward_card_uis():
		_kill_reward_hover_tween(card_ui)
		var base: Vector2 = card_ui.original_scale if card_ui.original_scale != Vector2.ZERO else Vector2.ONE
		card_ui.scale = base
		card_ui.target_scale = base
		_wire_reward_card_hover(card_ui)

func _wire_reward_card_hover(card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui):
		return
	# Jednou na kartu (volá se až z _enable_reward_card_hover).
	card_ui.mouse_entered.connect(_on_reward_card_hover_enter.bind(card_ui))
	card_ui.mouse_exited.connect(_on_reward_card_hover_exit.bind(card_ui))

func _reward_card_base_scale(card_ui: CardUI) -> Vector2:
	return card_ui.original_scale if card_ui.original_scale != Vector2.ZERO else Vector2.ONE

func _kill_reward_hover_tween(card_ui: CardUI) -> void:
	if _reward_hover_tweens.has(card_ui):
		var old: Tween = _reward_hover_tweens[card_ui]
		if old and old.is_valid():
			old.kill()
		_reward_hover_tweens.erase(card_ui)

func _tween_reward_card_scale(card_ui: CardUI, to_scale: Vector2) -> void:
	_kill_reward_hover_tween(card_ui)
	var tween := create_tween()
	_reward_hover_tweens[card_ui] = tween
	tween.tween_property(card_ui, "scale", to_scale, 0.12)

func _on_reward_card_hover_enter(card_ui: CardUI) -> void:
	if not _reward_hover_ready or not is_instance_valid(card_ui):
		return
	if _reward_hovered_card == card_ui:
		return
	# Jen jedna hover-karta — reset ostatních (layout přesuny někdy ztratí mouse_exited).
	if is_instance_valid(_reward_hovered_card) and _reward_hovered_card != card_ui:
		_tween_reward_card_scale(_reward_hovered_card, _reward_card_base_scale(_reward_hovered_card))
	_reward_hovered_card = card_ui
	_tween_reward_card_scale(card_ui, _reward_card_base_scale(card_ui) * REWARD_HOVER_SCALE)

func _on_reward_card_hover_exit(card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui):
		return
	if _reward_hovered_card == card_ui:
		_reward_hovered_card = null
	_tween_reward_card_scale(card_ui, _reward_card_base_scale(card_ui))
	_dismiss_tooltip_if_card(card_ui.card_data)

func _dismiss_tooltip_if_card(card_data: CardData) -> void:
	"""Zavře tooltip, když myš opustí kartu, ke které patří."""
	if not card_tooltip or not card_tooltip.visible or _current_tooltip_card_data == null or card_data == null:
		return
	var same := card_data == _current_tooltip_card_data
	if not same and not card_data.resource_path.is_empty() and not _current_tooltip_card_data.resource_path.is_empty():
		same = card_data.resource_path == _current_tooltip_card_data.resource_path
	if same:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null

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
