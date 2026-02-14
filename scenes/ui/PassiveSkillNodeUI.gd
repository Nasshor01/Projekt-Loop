# PassiveSkillNodeUI.gd – uzel pro manuální stavbu skill tree
# Přiřaď skill_id z dokumentu (např. blessed_gold, divine_insight, sacred_step).
# @tool nutné, aby SkillTreeBuilder v editoru mohl volat set_skill_id() (bez něj by to byl placeholder).
@tool
class_name PassiveSkillNodeUI
extends Control

signal unlocked(skill_id: StringName)

var _skill_id_backing: StringName = &""
@export var skill_id: StringName = &"":
	get:
		return _skill_id_backing
	set(v):
		_skill_id_backing = v

enum VisualState {
	LOCKED,      # Šedá – zamčeno
	AVAILABLE,   # Bílá – dostupné k nákupu
	PURCHASED    # Zlatá/zářící – koupeno
}

var _frame_rect: Control
var _icon_button: BaseButton
var _name_label: Label
var _sprite_bg: Node2D

func _ready() -> void:
	_resolve_editor_nodes()
	if _icon_button:
		_icon_button.pressed.connect(_on_pressed)
	if has_node("/root/SaveManager"):
		SaveManager.meta_progress_changed.connect(func(): update_visuals())
	update_visuals()

## Nastaví skill_id (např. z SkillTreeBuilderu).
func set_skill_id(id: StringName) -> void:
	_skill_id_backing = id

func _resolve_editor_nodes() -> void:
	if _frame_rect == null:
		_frame_rect = get_node_or_null("FrameRect")
	if _icon_button == null:
		_icon_button = get_node_or_null("IconButton")
	if _name_label == null:
		_name_label = get_node_or_null("NameLabel")
	if _sprite_bg == null:
		_sprite_bg = get_node_or_null("FrameSprite")

func _on_pressed() -> void:
	if not _try_purchase():
		return
	unlocked.emit(skill_id)
	update_visuals()

func _get_skill_node() -> PassiveSkillNode:
	if not has_node("/root/PlayerData") or not PlayerData:
		return null
	if not is_instance_valid(PlayerData.active_skill_tree):
		return null
	return PlayerData.active_skill_tree.get_node_by_id(skill_id)

func _is_purchased() -> bool:
	if not has_node("/root/SaveManager") or not SaveManager or not SaveManager.meta_progress:
		return false
	var count = SaveManager.meta_progress.allocated_skills.get(String(skill_id), 0)
	return count > 0

func _can_purchase() -> bool:
	if not has_node("/root/SaveManager") or not SaveManager or not SaveManager.meta_progress:
		return false
	var skill_node = _get_skill_node()
	if _is_purchased():
		if not skill_node:
			return false
		var count = SaveManager.meta_progress.allocated_skills.get(String(skill_id), 0)
		if count >= skill_node.max_allocations:
			return false
	var cost = skill_node.get_cost_for_tier() if skill_node else 1
	if SaveManager.meta_progress.skill_points < cost:
		return false
	if skill_node and not _prerequisites_met(skill_node):
		return false
	return true

func _prerequisites_met(skill_node: PassiveSkillNode) -> bool:
	if not SaveManager or not SaveManager.meta_progress:
		return false
	var allocated = SaveManager.meta_progress.allocated_skills
	for conn_id in skill_node.connected_nodes:
		var c = allocated.get(String(conn_id), 0)
		if c <= 0:
			return false
	for cond in skill_node.unlock_conditions:
		if cond == "all_nodes_unlocked":
			if not has_node("/root/PlayerData") or not PlayerData:
				return false
			var tree = PlayerData.active_skill_tree
			if not is_instance_valid(tree):
				return false
			for node in tree.skill_nodes:
				if node.id == skill_node.id:
					continue
				if allocated.get(String(node.id), 0) <= 0:
					return false
	return true

func _try_purchase() -> bool:
	if not _can_purchase():
		return false
	var skill_node = _get_skill_node()
	var cost = skill_node.get_cost_for_tier() if skill_node else 1
	var sid = String(skill_id)
	SaveManager.meta_progress.skill_points -= cost
	var cur = SaveManager.meta_progress.allocated_skills.get(sid, 0)
	SaveManager.meta_progress.allocated_skills[sid] = cur + 1
	if skill_node and skill_node.unlocks_card != "" and cur == 0:
		if not PlayerData.unlocked_cards.has(skill_node.unlocks_card):
			PlayerData.unlocked_cards.append(skill_node.unlocks_card)
		SaveManager.meta_progress.unlocked_cards = PlayerData.unlocked_cards.duplicate()
	SaveManager.save_meta_progress()
	if has_node("/root/PlayerData") and PlayerData:
		PlayerData.apply_passive_skills()
	return true

func update_visuals() -> void:
	var state: VisualState = VisualState.LOCKED
	if _is_purchased():
		state = VisualState.PURCHASED
	elif _can_purchase():
		state = VisualState.AVAILABLE

	# Barvy viditelné na tmavém (vesmírném) pozadí
	var color := Color.GRAY
	match state:
		VisualState.LOCKED:
			color = Color(0.58, 0.6, 0.65)
		VisualState.AVAILABLE:
			color = Color(0.95, 0.95, 1.0)
		VisualState.PURCHASED:
			color = Color(1.0, 0.85, 0.2)

	self_modulate = color
	if _frame_rect:
		_frame_rect.modulate = color
	if _icon_button:
		_icon_button.modulate = color
	if _sprite_bg:
		_sprite_bg.modulate = color

	if _name_label:
		var skill_node = _get_skill_node()
		if skill_node:
			_name_label.text = skill_node.skill_name
			var count = SaveManager.meta_progress.allocated_skills.get(String(skill_id), 0) if (SaveManager and SaveManager.meta_progress) else 0
			if skill_node.max_allocations > 1:
				_name_label.text += " (%d/%d)" % [count, skill_node.max_allocations]
		else:
			_name_label.text = String(skill_id)

	if state == VisualState.PURCHASED and _icon_button:
		_icon_button.modulate = Color(1.0, 0.9, 0.3)
