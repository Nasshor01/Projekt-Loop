# ===================================================================
# Soubor: res://scenes/ui/UnitInfoPanel.gd
# ===================================================================
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
	hp_label.text = "HP: %d / %d" % [unit_node.current_health, data.max_health]
	
	if unit_node.current_block > 0:
		block_label.text = "Blok: %d" % unit_node.current_block
		block_label.visible = true
	else:
		block_label.visible = false
	
	# APLabel byl odstraněn
	
	if data.faction != UnitData.Faction.PLAYER:
		attack_label.text = "Útok: %d" % data.attack_damage
		attack_label.visible = true
	else:
		attack_label.visible = false
		
	_update_status_display(unit_node)

func _update_status_display(unit_node: Node2D):
	for child in status_effects_list.get_children():
		child.queue_free()

	if not "active_statuses" in unit_node or unit_node.active_statuses.is_empty():
		status_effects_list.visible = false
		return

	status_effects_list.visible = true
	
	for status_id in unit_node.active_statuses:
		var status_data = unit_node.active_statuses[status_id]
		var status_label = Label.new()
		status_label.text = "%s: %d" % [status_id.capitalize(), status_data.value]
		status_effects_list.add_child(status_label)

func hide_panel():
	visible = false
