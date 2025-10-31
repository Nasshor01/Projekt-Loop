# Soubor: res://scenes/ui/UnitInfoPanel.gd
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var hp_label: Label = %HPLabel
@onready var block_label: Label = %BlockLabel
@onready var attack_label: Label = %AttackLabel
@onready var status_effects_list: VBoxContainer = %StatusEffectsList

func update_stats(unit_node: Node2D):
	if not name_label or not hp_label or not block_label or not attack_label or not status_effects_list:
		printerr("UnitInfoPanel: Některé z Label/Kontejner uzlů nebyly nalezeny!")
		visible = false
		return
		
	if not is_instance_valid(unit_node) or not unit_node.has_method("get_unit_data"):
		visible = false
		return
	
	visible = true
	var data = unit_node.get_unit_data()
	
	name_label.text = data.unit_name
	
	# Zobrazení HP (zůstává stejné)
	if data.faction == UnitData.Faction.PLAYER:
		hp_label.text = "HP: %d / %d" % [unit_node.current_health, PlayerData.max_hp]
	else:
		hp_label.text = "HP: %d / %d" % [unit_node.current_health, data.max_health]
	
	# --- NOVÁ VYLEPŠENÁ LOGIKA PRO BLOK ---
	if unit_node.current_block > 0:
		block_label.visible = true
		
		# Zkontrolujeme, jestli má jednotka i nějaký udržitelný blok ("retained_block")
		if unit_node.retained_block > 0:
			# Pokud ano, zobrazíme ho v závorce pro lepší přehlednost
			# Příklad: Blok: 50 (20)
			block_label.text = "Blok: %d (%d)" % [unit_node.current_block, unit_node.retained_block]
			block_label.tooltip_text = "Celkový blok (z toho v závorce je udržitelný pro další kolo)"
		else:
			# Pokud je všechen blok jen dočasný, ukážeme jen celkovou hodnotu
			# Příklad: Blok: 10
			block_label.text = "Blok: %d" % unit_node.current_block
			block_label.tooltip_text = "Celkový blok"
	else:
		# Pokud není žádný blok, label skryjeme
		block_label.visible = false
	# --- KONEC NOVÉ LOGIKY PRO BLOK ---
	
	# Zobrazení útoku (zůstává stejné)
	if data.faction != UnitData.Faction.PLAYER:
		attack_label.text = "Útok: %d" % data.attack_damage
		attack_label.visible = true
	else:
		attack_label.visible = false
		
	_update_status_display(unit_node)

func _update_status_display(unit_node: Node2D):
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
				status_label.text = "🎯 Míří (+%d%% dmg)" % (status_data.value - 100)
				status_label.add_theme_color_override("font_color", Color.ORANGE)
			"aura_devotion":
				status_label.text = "✨ Aura oddanosti (+%d blok)" % status_data.value
				status_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
			"aura_devotion_plus":
				status_label.text = "✨ Aura oddanosti+ (+%d blok)" % status_data.value  
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
		
	name_label.text = unit_data.unit_name
	# Aktuální HP vezmeme přímo z PlayerData
	hp_label.text = "HP: %d / %d" % [PlayerData.current_hp, PlayerData.max_hp]
	
	# Ostatní věci, které hráč na začátku nemá, skryjeme
	block_label.visible = false
	attack_label.visible = false
	status_effects_list.visible = false
	show()
