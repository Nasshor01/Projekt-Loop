# Soubor: addons/skill_tree_editor/skill_tree_editor_plugin.gd
@tool
extends EditorPlugin

const SkillTreeEditorDock = preload("res://addons/skill_tree_builder/skill_tree_editor_dock.gd")

var dock

func _enter_tree():
	dock = SkillTreeEditorDock.new()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree():
	remove_control_from_docks(dock)
