# Soubor: res://scenes/ui/UnitInfoPanel.gd
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var hp_label: Label = %HPLabel
@onready var block_label: Label = %BlockLabel
@onready var attack_label: Label = %AttackLabel
@onready var class_label: Label = %ClassLabel
@onready var passives_label: Label = %PassivesLabel
@onready var counters_label: Label = %CountersLabel
@onready var intent_label: Label = %IntentLabel
@onready var status_effects_list: VBoxContainer = %StatusEffectsList

func update_stats(unit_node: Node):
	if not name_label or not hp_label or not block_label or not attack_label or not status_effects_list or not class_label or not passives_label or not counters_label or not intent_label:
		printerr(tr("UnitInfoPanel: Missing required label/container nodes!"))
		visible = false
		return
		
	if not is_instance_valid(unit_node) or not unit_node.has_method("get_unit_data"):
		visible = false
		return
	
	visible = true
	var data = unit_node.get_unit_data()
	
	name_label.text = data.get_localized_name()
	
	# Zobrazení HP (zůstává stejné)
	if data.faction == UnitData.Faction.PLAYER:
		hp_label.text = TranslationHelper.tr_format("ui.unit_info.hp", {"current": unit_node.current_health, "max": PlayerData.max_hp})
	else:
		hp_label.text = TranslationHelper.tr_format("ui.unit_info.hp", {"current": unit_node.current_health, "max": data.max_health})
	
	# --- NOVÁ VYLEPŠENÁ LOGIKA PRO BLOK ---
	if unit_node.current_block > 0:
		block_label.visible = true
		
		# Zkontrolujeme, jestli má jednotka i nějaký udržitelný blok ("retained_block")
		if unit_node.retained_block > 0:
			# Pokud ano, zobrazíme ho v závorce pro lepší přehlednost
			# Příklad: Blok: 50 (20)
			block_label.text = TranslationHelper.tr_format("ui.unit_info.block_retained", {"current": unit_node.current_block, "retained": unit_node.retained_block})
			block_label.tooltip_text = tr("ui.unit_info.block_tooltip_retained")
		else:
			# Pokud je všechen blok jen dočasný, ukážeme jen celkovou hodnotu
			# Příklad: Blok: 10
			block_label.text = TranslationHelper.tr_format("ui.unit_info.block", {"value": unit_node.current_block})
			block_label.tooltip_text = tr("ui.unit_info.block_tooltip")
	else:
		# Pokud není žádný blok, label skryjeme
		block_label.visible = false
	# --- KONEC NOVÉ LOGIKY PRO BLOK ---
	
	# Zobrazení útoku (zůstává stejné)
	if data.faction != UnitData.Faction.PLAYER:
		attack_label.text = TranslationHelper.tr_format("ui.unit_info.attack", {"value": data.attack_damage})
		attack_label.visible = true
	else:
		attack_label.visible = false
	
	_update_enemy_details(unit_node, data)
		
	_update_status_display(unit_node)

func _update_enemy_details(unit_node: Node, data: UnitData) -> void:
	if data.faction != UnitData.Faction.ENEMY:
		class_label.visible = false
		passives_label.visible = false
		counters_label.visible = false
		intent_label.visible = false
		return
	
	class_label.visible = true
	passives_label.visible = true
	counters_label.visible = true
	intent_label.visible = true
	
	if unit_node.has_method("get_enemy_class_display"):
		class_label.text = unit_node.get_enemy_class_display()
	else:
		class_label.text = tr("Class: Unknown")
	
	if unit_node.has_method("get_enemy_passives_display"):
		passives_label.text = unit_node.get_enemy_passives_display()
	else:
		passives_label.text = tr("Passives: None")
	
	if unit_node.has_method("get_status_counters_display"):
		counters_label.text = unit_node.get_status_counters_display()
	else:
		counters_label.text = tr("Status/Counters: None")
	
	if unit_node.has_method("get_intent_display_text"):
		intent_label.text = unit_node.get_intent_display_text()
	else:
		intent_label.text = tr("Next Move: Unknown")

func _update_status_display(unit_node: Node):
	# Vymaž staré statusy
	for child in status_effects_list.get_children():
		child.queue_free()
		
	if not "active_statuses" in unit_node or unit_node.active_statuses.is_empty():
		status_effects_list.visible = false
		return
		
	status_effects_list.visible = true
	
	# Zobraz každý status s příslušnou ikonou a popisem
	for status_id in unit_node.active_statuses:
		var status_data = unit_node.active_statuses[status_id]
		var status_label = Label.new()
		
		# Speciální zobrazení pro různé typy statusů
		match status_id:
			"aiming":
				status_label.text = TranslationHelper.tr_format("status.label.aiming", {"value": status_data.value - 100})
				status_label.add_theme_color_override("font_color", Color.ORANGE)
			"aura_devotion":
				status_label.text = TranslationHelper.tr_format("status.label.aura_devotion", {"value": status_data.value})
				status_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
			"aura_devotion_plus":
				status_label.text = TranslationHelper.tr_format("status.label.aura_devotion_plus", {"value": status_data.value})  
				status_label.add_theme_color_override("font_color", Color.CYAN)
			_:
				# Výchozí zobrazení
				var display_name = status_id.replace("_", " ").capitalize()
				status_label.text = "%s: %d" % [display_name, status_data.value]
		
		status_effects_list.add_child(status_label)

func hide_panel():
	visible = false

func update_from_player_data():
	# Vezmeme si data o classu hráče
	var unit_data = PlayerData.selected_subclass.specific_unit_data
	if not is_instance_valid(unit_data):
		hide_panel()
		return
		
	name_label.text = unit_data.get_localized_name()
	# Aktuální HP vezmeme přímo z PlayerData
	hp_label.text = TranslationHelper.tr_format("ui.unit_info.hp", {"current": PlayerData.current_hp, "max": PlayerData.max_hp})
	
	# Ostatní věci, které hráč na začátku nemá, skryjeme
	block_label.visible = false
	attack_label.visible = false
	status_effects_list.visible = false
	class_label.visible = false
	passives_label.visible = false
	counters_label.visible = false
	intent_label.visible = false
	show()
