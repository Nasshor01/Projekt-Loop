# Soubor: addons/skill_tree_editor/skill_tree_editor_dock.gd
@tool
extends Control

var current_tree: PassiveSkillTreeData
var selected_node: PassiveSkillNode

# UI prvky
var tree_selector: OptionButton
var node_list: ItemList
var properties_container: VBoxContainer

# Property editory
var name_edit: LineEdit
var desc_edit: TextEdit
var cost_spin: SpinBox
var notable_check: CheckBox
var icon_picker: Button
var effects_container: VBoxContainer

func _ready():
	name = "Skill Tree Editor"
	set_custom_minimum_size(Vector2(300, 400))
	_build_ui()
	_refresh_tree_list()

func _build_ui():
	var scroll = ScrollContainer.new()
	add_child(scroll)
	
	var main_vbox = VBoxContainer.new()
	scroll.add_child(main_vbox)
	
	# Header
	var header = Label.new()
	header.text = "Skill Tree Editor"
	header.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(header)
	
	# Tree selector
	var tree_label = Label.new()
	tree_label.text = "Aktivní strom:"
	main_vbox.add_child(tree_label)
	
	tree_selector = OptionButton.new()
	tree_selector.item_selected.connect(_on_tree_selected)
	main_vbox.add_child(tree_selector)
	
	# Tlačítka pro správu stromů
	var tree_buttons = HBoxContainer.new()
	main_vbox.add_child(tree_buttons)
	
	var new_tree_btn = Button.new()
	new_tree_btn.text = "Nový"
	new_tree_btn.pressed.connect(_create_new_tree)
	tree_buttons.add_child(new_tree_btn)
	
	var load_tree_btn = Button.new()
	load_tree_btn.text = "Načíst"
	load_tree_btn.pressed.connect(_load_tree)
	tree_buttons.add_child(load_tree_btn)
	
	var save_tree_btn = Button.new()
	save_tree_btn.text = "Uložit"
	save_tree_btn.pressed.connect(_save_tree)
	tree_buttons.add_child(save_tree_btn)
	
	main_vbox.add_child(HSeparator.new())
	
	# Node list
	var node_label = Label.new()
	node_label.text = "Uzly:"
	main_vbox.add_child(node_label)
	
	node_list = ItemList.new()
	node_list.custom_minimum_size.y = 150
	node_list.item_selected.connect(_on_node_selected)
	main_vbox.add_child(node_list)
	
	# Node buttons
	var node_buttons = HBoxContainer.new()
	main_vbox.add_child(node_buttons)
	
	var add_node_btn = Button.new()
	add_node_btn.text = "+"
	add_node_btn.pressed.connect(_add_node)
	node_buttons.add_child(add_node_btn)
	
	var remove_node_btn = Button.new()
	remove_node_btn.text = "-"
	remove_node_btn.pressed.connect(_remove_node)
	node_buttons.add_child(remove_node_btn)
	
	main_vbox.add_child(HSeparator.new())
	
	# Properties editor
	var props_label = Label.new()
	props_label.text = "Vlastnosti uzlu:"
	main_vbox.add_child(props_label)
	
	properties_container = VBoxContainer.new()
	main_vbox.add_child(properties_container)
	
	_build_properties_editor()

func _build_properties_editor():
	# Name
	var name_label = Label.new()
	name_label.text = "Název:"
	properties_container.add_child(name_label)
	
	name_edit = LineEdit.new()
	name_edit.text_changed.connect(_on_property_changed)
	properties_container.add_child(name_edit)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = "Popis:"
	properties_container.add_child(desc_label)
	
	desc_edit = TextEdit.new()
	desc_edit.custom_minimum_size.y = 80
	desc_edit.text_changed.connect(_on_property_changed)
	properties_container.add_child(desc_edit)
	
	# Cost
	var cost_label = Label.new()
	cost_label.text = "Cena:"
	properties_container.add_child(cost_label)
	
	cost_spin = SpinBox.new()
	cost_spin.min_value = 0
	cost_spin.max_value = 10
	cost_spin.value_changed.connect(_on_property_changed)
	properties_container.add_child(cost_spin)
	
	# Notable
	notable_check = CheckBox.new()
	notable_check.text = "Notable skill"
	notable_check.toggled.connect(_on_property_changed)
	properties_container.add_child(notable_check)
	
	# Effects section
	var effects_label = Label.new()
	effects_label.text = "Efekty:"
	properties_container.add_child(effects_label)
	
	effects_container = VBoxContainer.new()
	properties_container.add_child(effects_container)
	
	var add_effect_btn = Button.new()
	add_effect_btn.text = "Přidat efekt"
	add_effect_btn.pressed.connect(_add_effect)
	properties_container.add_child(add_effect_btn)

func _refresh_tree_list():
	tree_selector.clear()
	
	# Najdeme všechny .tres soubory se skill tree
	var dir = DirAccess.open("res://data/skill_tree/")
	if dir:
		_scan_directory_for_trees(dir, "res://data/skill_tree/")

func _scan_directory_for_trees(dir: DirAccess, path: String):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + "/" + file_name
		
		if dir.current_is_dir() and file_name != ".":
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_scan_directory_for_trees(sub_dir, full_path)
		elif file_name.ends_with(".tres"):
			var resource = load(full_path)
			if resource is PassiveSkillTreeData:
				tree_selector.add_item(file_name.get_basename())
				tree_selector.set_item_metadata(-1, full_path)
		
		file_name = dir.get_next()

func _on_tree_selected(index: int):
	var path = tree_selector.get_item_metadata(index)
	current_tree = load(path)
	_refresh_node_list()

func _refresh_node_list():
	node_list.clear()
	if not current_tree:
		return
		
	for node in current_tree.skill_nodes:
		node_list.add_item(node.skill_name)

func _on_node_selected(index: int):
	if not current_tree or index >= current_tree.skill_nodes.size():
		return
		
	selected_node = current_tree.skill_nodes[index]
	_update_properties_editor()

func _update_properties_editor():
	if not selected_node:
		return
	
	name_edit.text = selected_node.skill_name
	desc_edit.text = selected_node.description
	cost_spin.value = selected_node.cost
	notable_check.button_pressed = selected_node.is_notable
	
	_refresh_effects_list()

func _refresh_effects_list():
	for child in effects_container.get_children():
		child.queue_free()
	
	if not selected_node:
		return
	
	for i in range(selected_node.effects.size()):
		var effect = selected_node.effects[i]
		var effect_row = HBoxContainer.new()
		effects_container.add_child(effect_row)
		
		var type_option = OptionButton.new()
		type_option.add_item("Max HP", PassiveEffectData.EffectType.ADD_MAX_HP)
		type_option.add_item("Zlato", PassiveEffectData.EffectType.ADD_STARTING_GOLD)
		type_option.add_item("Energie", PassiveEffectData.EffectType.ADD_MAX_ENERGY)
		type_option.add_item("Vzkříšení", PassiveEffectData.EffectType.GRANT_REVIVE)
		type_option.add_item("Poškození", PassiveEffectData.EffectType.ADD_CARD_DAMAGE)
		type_option.add_item("Trvalý blok", PassiveEffectData.EffectType.ADD_RETAINED_BLOCK)
		type_option.selected = effect.effect_type
		effect_row.add_child(type_option)
		
		var value_spin = SpinBox.new()
		value_spin.min_value = 0
		value_spin.max_value = 999
		value_spin.value = effect.value
		effect_row.add_child(value_spin)
		
		var remove_btn = Button.new()
		remove_btn.text = "X"
		remove_btn.pressed.connect(_remove_effect.bind(i))
		effect_row.add_child(remove_btn)

func _add_effect():
	if not selected_node:
		return
	
	var new_effect = PassiveEffectData.new()
	new_effect.effect_type = PassiveEffectData.EffectType.ADD_MAX_HP
	new_effect.value = 1
	
	selected_node.effects.append(new_effect)
	_refresh_effects_list()

func _remove_effect(index: int):
	if not selected_node or index >= selected_node.effects.size():
		return
	
	selected_node.effects.remove_at(index)
	_refresh_effects_list()

func _on_property_changed(_value = null):
	if not selected_node:
		return
	
	selected_node.skill_name = name_edit.text
	selected_node.description = desc_edit.text
	selected_node.cost = int(cost_spin.value)
	selected_node.is_notable = notable_check.button_pressed
	
	# Aktualizujeme seznam uzlů
	if node_list.get_selected_items().size() > 0:
		var index = node_list.get_selected_items()[0]
		node_list.set_item_text(index, selected_node.skill_name)

func _create_new_tree():
	current_tree = PassiveSkillTreeData.new()
	_refresh_node_list()
	print("Nový strom vytvořen")

func _add_node():
	if not current_tree:
		return
	
	var new_node = PassiveSkillNode.new()
	new_node.id = StringName("node_" + str(current_tree.skill_nodes.size()))
	new_node.skill_name = "Nový uzel"
	new_node.description = "Popis nového uzlu"
	new_node.cost = 1
	
	current_tree.skill_nodes.append(new_node)
	_refresh_node_list()

func _remove_node():
	var selected = node_list.get_selected_items()
	if selected.is_empty() or not current_tree:
		return
	
	current_tree.skill_nodes.remove_at(selected[0])
	_refresh_node_list()

func _load_tree():
	# Zde by byl dialog pro výběr souboru
	# Pro jednoduchost používáme selector
	pass

func _save_tree():
	if not current_tree:
		return
	
	var path = "res://data/skill_tree/custom_tree_" + str(Time.get_unix_time_from_system()) + ".tres"
	ResourceSaver.save(current_tree, path)
	print("Strom uložen do: ", path)
