# Soubor: res://scenes/ui/UnitInfoPanel.gd
# Unit Info Panel s dedikovanými sloty: HP (jen nepřítel), Block, Energy (jen hráč).
# HP hráče je v Global UI, takže v tomto panelu se u hráče nezobrazuje.
extends PanelContainer

# Status ikony - preload
const ICON_BURNING = preload("res://art/icons/status/Bleed.png")
const ICON_CHILLED = preload("res://art/icons/status/Freeze.png")
const ICON_SHOCKED = preload("res://art/icons/status/Stunned.png")
const ICON_FROZEN = preload("res://art/icons/status/Freeze.png")
const ICON_ENTANGLED = preload("res://art/icons/status/Slow_Down.png")
const ICON_MONK_BLESSING = preload("res://art/icons/status/Strenght.png")
const ICON_REGENERATION = preload("res://art/icons/status/Regeneration.png")
const ICON_SLOW = preload("res://art/icons/status/Slow_Down.png")
const ICON_VULNERABLE = preload("res://art/icons/status/Vulnerable.png")
const ICON_AIMING = preload("res://art/icons/status/Aim.png")
const ICON_AURA_DEVOTION = preload("res://art/icons/status/block.png")
const ICON_POISON = preload("res://art/icons/status/Poison.png")
const ICON_WEAKNESS = preload("res://art/icons/status/Weakness.png")
const ICON_THORNS = preload("res://art/icons/status/Thorns.png")
const ICON_HEAL = preload("res://art/icons/status/Heal.png")
const ICON_ATTACK = preload("res://art/icons/status/attack.png")
const ICON_BLOCK = preload("res://art/icons/status/block.png")
const ICON_RAGE = preload("res://art/icons/status/Rage_rush.png")
const ICON_LEECH = preload("res://art/icons/status/Leech.png")
const ICON_DEFAULT = preload("res://art/icons/status/Poison.png")

const STATUS_ICON_SIZE = 20  # Velikost ikony v panelu

@onready var name_label: Label = %NameLabel
@onready var hp_slot: HBoxContainer = %HPSlot
@onready var hp_label: Label = %HPLabel
@onready var block_slot: HBoxContainer = %BlockSlot
@onready var block_label: Label = %BlockLabel
@onready var energy_slot: HBoxContainer = %EnergySlot
@onready var energy_label: Label = %EnergyLabel
@onready var enemy_section: VBoxContainer = %EnemySection
@onready var attack_label: Label = %AttackLabel
@onready var class_label: Label = %ClassLabel
@onready var passives_label: Label = %PassivesLabel
@onready var counters_label: Label = %CountersLabel
@onready var intent_label: Label = %IntentLabel
@onready var status_effects_list: VBoxContainer = %StatusEffectsList

func update_stats(unit_node: Node):
	if not name_label or not hp_slot or not block_slot or not energy_slot or not enemy_section or not status_effects_list:
		printerr(tr("UnitInfoPanel: Missing required nodes!"))
		visible = false
		return
	if not is_instance_valid(unit_node) or not unit_node.has_method("get_unit_data"):
		visible = false
		return

	visible = true
	var data = unit_node.get_unit_data()
	name_label.text = data.get_localized_name()

	# --- Dedikované sloty: HP / Block / Energy ---
	if data.faction == UnitData.Faction.PLAYER:
		# Coop: pokud klikáme na jednotku DRUHÉHO hráče, ukaž její HP a skryj energii
		var is_other_coop_unit = false
		if GameManager.is_coop_run and unit_node.has_meta("owner_peer_id"):
			var owner_id = unit_node.get_meta("owner_peer_id")
			if owner_id != unit_node.multiplayer.get_unique_id():
				is_other_coop_unit = true
		if is_other_coop_unit:
			hp_slot.visible = true
			hp_label.text = TranslationHelper.tr_format("ui.unit_info.hp", {"current": unit_node.current_health, "max": data.max_health})
			energy_slot.visible = false
		else:
			hp_slot.visible = false
			energy_slot.visible = true
			energy_label.text = TranslationHelper.tr_format("ui.unit_info.energy", {"current": PlayerData.current_energy, "max": PlayerData.max_energy})
	else:
		hp_slot.visible = true
		energy_slot.visible = false
		hp_label.text = TranslationHelper.tr_format("ui.unit_info.hp", {"current": unit_node.current_health, "max": data.max_health})

	# Block slot: vždy viditelný
	block_slot.visible = true
	if unit_node.current_block > 0:
		if unit_node.retained_block > 0:
			block_label.text = TranslationHelper.tr_format("ui.unit_info.block_retained", {"current": unit_node.current_block, "retained": unit_node.retained_block})
			block_label.tooltip_text = tr("ui.unit_info.block_tooltip_retained")
		else:
			block_label.text = TranslationHelper.tr_format("ui.unit_info.block", {"value": unit_node.current_block})
			block_label.tooltip_text = tr("ui.unit_info.block_tooltip")
	else:
		block_label.text = TranslationHelper.tr_format("ui.unit_info.block", {"value": 0})
		block_label.tooltip_text = ""

	if data.faction == UnitData.Faction.ENEMY:
		attack_label.text = TranslationHelper.tr_format("ui.unit_info.attack", {"value": data.attack_damage})
		attack_label.visible = true
	else:
		attack_label.visible = false

	_update_enemy_details(unit_node, data)
	_update_status_display(unit_node)

func _update_enemy_details(unit_node: Node, data: UnitData) -> void:
	if data.faction != UnitData.Faction.ENEMY:
		enemy_section.visible = false
		return
	enemy_section.visible = true
	if unit_node.has_method("get_enemy_class_display"):
		class_label.text = unit_node.get_enemy_class_display()
	else:
		class_label.text = tr("ui.unit_info.class_unknown")
	if unit_node.has_method("get_enemy_passives_display"):
		passives_label.text = unit_node.get_enemy_passives_display()
	else:
		passives_label.text = tr("ui.unit_info.passives_none")
	if unit_node.has_method("get_status_counters_display"):
		counters_label.text = unit_node.get_status_counters_display()
	else:
		counters_label.text = tr("ui.unit_info.counters_none")
	if unit_node.has_method("get_intent_display_text"):
		intent_label.text = unit_node.get_intent_display_text()
	else:
		intent_label.text = tr("ui.unit_info.intent_unknown")

func _update_status_display(unit_node: Node):
	# Vymaž staré statusy
	for child in status_effects_list.get_children():
		child.queue_free()
		
	if not "active_statuses" in unit_node or unit_node.active_statuses.is_empty():
		status_effects_list.visible = false
		return
		
	status_effects_list.visible = true
	
	for status_id in unit_node.active_statuses:
		var status_data = unit_node.active_statuses[status_id]
		var row = _create_status_row(status_id, status_data)
		status_effects_list.add_child(row)

func _create_status_row(status_id: String, status_data: Dictionary) -> HBoxContainer:
	"""Vytvoří řádek se statusem: [ikona] text"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	
	# Ikona
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _get_status_icon(status_id)
	row.add_child(icon_rect)
	
	# Text
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 13)
	
	var info = _get_status_display_info(status_id, status_data)
	label.text = info.text
	label.add_theme_color_override("font_color", info.color)
	
	row.add_child(label)
	return row

func _get_status_icon(status_id: String) -> Texture2D:
	"""Vrátí ikonu pro daný status"""
	match status_id:
		"burning":
			return ICON_BURNING
		"chilled":
			return ICON_CHILLED
		"shocked":
			return ICON_SHOCKED
		"frozen":
			return ICON_FROZEN
		"entangled":
			return ICON_ENTANGLED
		"monk_blessing":
			return ICON_MONK_BLESSING
		"regeneration":
			return ICON_REGENERATION
		"Slow":
			return ICON_SLOW
		"vulnerable":
			return ICON_VULNERABLE
		"aiming":
			return ICON_AIMING
		"aura_devotion", "aura_devotion_plus":
			return ICON_AURA_DEVOTION
		"weakness":
			return ICON_WEAKNESS
		"thorns":
			return ICON_THORNS
		"poison":
			return ICON_POISON
		"rage":
			return ICON_RAGE
		"defensive_stance":
			return ICON_BLOCK
		"leech":
			return ICON_LEECH
	return ICON_DEFAULT

func _get_status_display_info(status_id: String, status_data: Dictionary) -> Dictionary:
	"""Vrátí text a barvu pro daný status"""
	var dur = status_data.get("duration", 0)
	var val = status_data.get("value", 0)
	
	match status_id:
		"aiming":
			return {"text": TranslationHelper.tr_format("status.label.aiming", {"value": val - 100}), "color": Color.ORANGE}
		"aura_devotion":
			return {"text": TranslationHelper.tr_format("status.label.aura_devotion", {"value": val}), "color": Color.LIGHT_BLUE}
		"aura_devotion_plus":
			return {"text": TranslationHelper.tr_format("status.label.aura_devotion_plus", {"value": val}), "color": Color.CYAN}
		"burning":
			return {"text": "%d DMG (%d t)" % [val, dur], "color": Color.ORANGE_RED}
		"chilled":
			return {"text": "-%d Move (%d t)" % [val, dur], "color": Color.LIGHT_BLUE}
		"shocked":
			return {"text": "Shocked (%d t)" % dur, "color": Color.YELLOW}
		"frozen":
			return {"text": "FROZEN! (%d t)" % dur, "color": Color.DEEP_SKY_BLUE}
		"entangled":
			return {"text": "Rooted (%d t)" % dur, "color": Color.DARK_GREEN}
		"monk_blessing":
			return {"text": "+%d DMG (%d t)" % [val, dur], "color": Color.GOLD}
		"regeneration":
			return {"text": "+%d HP/t (%d t)" % [val, dur], "color": Color.GREEN}
		"Slow":
			return {"text": "%d Move (%d t)" % [val, dur], "color": Color.SLATE_GRAY}
		"vulnerable":
			return {"text": "+50%% DMG (%d t)" % dur, "color": Color.INDIAN_RED}
		"defensive_stance":
			return {"text": "-50%% DMG (%d t)" % dur, "color": Color.STEEL_BLUE}
		"weakness":
			return {"text": "-%d DMG (%d t)" % [val, dur], "color": Color.DIM_GRAY}
		"thorns":
			return {"text": "%d reflect (%d t)" % [val, dur], "color": Color.DARK_ORANGE}
		"poison":
			return {"text": "%d DMG/t (%d t)" % [val, dur], "color": Color.PURPLE}
		"rage":
			return {"text": "+%d DMG (%d t)" % [val, dur], "color": Color.RED}
		_:
			var display_name = status_id.replace("_", " ").capitalize()
			return {"text": "%s %d (%d t)" % [display_name, val, dur], "color": Color.WHITE}

func hide_panel():
	visible = false

func update_from_player_data():
	var unit_data = PlayerData.selected_subclass.specific_unit_data
	if not is_instance_valid(unit_data):
		hide_panel()
		return
	name_label.text = unit_data.get_localized_name()
	# HP hráče není v panelu — je v Global UI
	hp_slot.visible = false
	block_slot.visible = true
	block_label.text = TranslationHelper.tr_format("ui.unit_info.block", {"value": 0})
	block_label.tooltip_text = ""
	energy_slot.visible = true
	energy_label.text = TranslationHelper.tr_format("ui.unit_info.energy", {"current": PlayerData.current_energy, "max": PlayerData.max_energy})
	enemy_section.visible = false
	status_effects_list.visible = false
	for child in status_effects_list.get_children():
		child.queue_free()
	show()

func update_energy_display():
	"""Aktualizuje jen zobrazení energie (volá se při změně energie u hráče)."""
	if visible and energy_slot.visible and energy_label:
		energy_label.text = TranslationHelper.tr_format("ui.unit_info.energy", {"current": PlayerData.current_energy, "max": PlayerData.max_energy})
