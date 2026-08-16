# Spatial village hub: world plateau + always-visible CanvasLayer HUD.
extends Node

@onready var world: VillageWorld = $VillageWorld
@onready var hud: VillageHUD = $VillageHUD

var _open_building_id: String = ""


func _ready() -> void:
	hud.back_pressed.connect(GameManager.go_to_main_menu)
	hud.reset_pressed.connect(_on_reset_upgrades_pressed)
	hud.bind_reset_confirmed(_on_reset_upgrades_confirmed)
	hud.new_run_pressed.connect(_on_new_run_pressed)
	hud.detail_closed.connect(_hide_detail)
	hud.upgrade_pressed.connect(_on_detail_upgrade_pressed)
	if SaveManager:
		SaveManager.meta_progress_changed.connect(_refresh)
	for slot in world.get_building_slots():
		if not slot.slot_clicked.is_connected(_on_slot_clicked):
			slot.slot_clicked.connect(_on_slot_clicked)
		if not slot.slot_hovered.is_connected(_on_slot_hovered):
			slot.slot_hovered.connect(_on_slot_hovered)
		if not slot.slot_unhovered.is_connected(_on_slot_unhovered):
			slot.slot_unhovered.connect(_on_slot_unhovered)
	_hide_detail()
	_refresh()


func _on_slot_hovered(building_id: String) -> void:
	if not _open_building_id.is_empty():
		return
	var slot := _slot_for(building_id)
	if slot == null:
		return
	hud.show_world_tooltip(VillageBonuses.format_building_bbcode(building_id, false), slot.get_screen_rect())


func _on_slot_unhovered() -> void:
	hud.hide_world_tooltip()


func _slot_for(building_id: String) -> VillageBuildingSlot:
	for slot in world.get_building_slots():
		if slot.building_id == building_id:
			return slot
	return null


func _on_slot_clicked(building_id: String) -> void:
	_on_slot_unhovered()
	_open_building_id = building_id
	_fill_detail(building_id)


func _fill_detail(building_id: String) -> void:
	world.camera_locked = true
	var name := VillageBonuses.get_building_name(building_id)
	if not VillageBonuses.is_line_unlocked(building_id):
		hud.show_detail(name, VillageBonuses.format_building_bbcode(building_id, true), "", false, false)
		return
	if not VillageBonuses.is_meta_building(building_id):
		hud.show_detail(name, VillageBonuses.format_building_bbcode(building_id, true), "", false, false)
		return
	var level := VillageBonuses.get_level(building_id)
	var max_lv := VillageBonuses.get_max_level(building_id)
	var title := "%s  —  %s" % [
		name,
		TranslationHelper.tr_format("village.level", {"current": level, "max": max_lv})
	]
	var upgrade_label := tr("village.maxed")
	var can_upgrade := false
	var show_upgrade := true
	if level < max_lv:
		if not VillageBonuses.meets_hero_level_gate(building_id):
			var hero_id := VillageBonuses.get_required_hero_id(building_id)
			upgrade_label = TranslationHelper.tr_format("village.requires_hero_level", {
				"hero": _hero_label(hero_id),
				"level": VillageBonuses.get_required_hero_level_for_next(building_id)
			})
			can_upgrade = false
		else:
			var cost := VillageBonuses.get_upgrade_cost(building_id)
			upgrade_label = TranslationHelper.tr_format("village.upgrade", {"cost": cost})
			can_upgrade = VillageBonuses.can_upgrade(building_id)
	hud.show_detail(title, VillageBonuses.format_building_bbcode(building_id, true), upgrade_label, can_upgrade, show_upgrade)


func _hero_label(hero_id: String) -> String:
	var key := "class.%s" % hero_id
	var name := tr(key)
	if name == key:
		return hero_id.capitalize()
	return name


func _hide_detail() -> void:
	_open_building_id = ""
	world.camera_locked = false
	hud.hide_detail()


func _on_detail_upgrade_pressed() -> void:
	if _open_building_id.is_empty():
		return
	if VillageBonuses.try_upgrade(_open_building_id):
		_refresh()


func _on_reset_upgrades_pressed() -> void:
	var refund := VillageBonuses.get_total_spent_shards()
	if refund <= 0:
		return
	hud.popup_reset_confirm(TranslationHelper.tr_format(
		"village.reset_upgrades_confirm",
		{"value": refund}
	))


func _on_reset_upgrades_confirmed() -> void:
	VillageBonuses.try_reset_all_upgrades()
	_refresh()


func _on_new_run_pressed() -> void:
	GameManager.go_to_character_select()


func _refresh() -> void:
	hud.set_shards_value(SaveManager.get_shards())
	if VillageBonuses.has_any_upgrades():
		var refund := VillageBonuses.get_total_spent_shards()
		hud.set_reset_enabled(true, TranslationHelper.tr_format("village.reset_upgrades_refund", {"value": refund}))
	else:
		hud.set_reset_enabled(false, tr("village.reset_upgrades"))
	for slot in world.get_building_slots():
		var lv := 0
		if VillageBonuses.is_meta_building(slot.building_id):
			lv = VillageBonuses.get_level(slot.building_id)
		slot.set_display_level(lv)
		slot.set_locked_visual(not VillageBonuses.is_line_unlocked(slot.building_id))
	if not _open_building_id.is_empty():
		_fill_detail(_open_building_id)
