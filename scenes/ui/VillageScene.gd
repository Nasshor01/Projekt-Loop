# Soubor: scenes/ui/VillageScene.gd
# Loop Vesnice — seznam budov (shop-style), bez skill tree grafu.
extends Control

const ICON_WELL = preload("res://art/sprites/village/well.png")
const ICON_MARKET = preload("res://art/sprites/village/market.png")
const ICON_LIBRARY = preload("res://art/sprites/village/library.png")
const ICON_CHAPEL = preload("res://art/sprites/village/chapel.png")
const ICON_SHARD = preload("res://art/sprites/village/shard.png")
const TEX_BACKGROUND = preload("res://art/sprites/village/pozadí-Sheet-export.png")

@onready var background: TextureRect = %Background
@onready var title_label: Label = %TitleLabel
@onready var shard_icon: TextureRect = %ShardIcon
@onready var shards_label: Label = %ShardsLabel
@onready var buildings_list: VBoxContainer = %BuildingsList
@onready var back_button: Button = %BackButton
@onready var reset_upgrades_button: Button = %ResetUpgradesButton
@onready var new_run_button: Button = %NewRunButton
@onready var reset_upgrades_dialog: ConfirmationDialog = %ResetUpgradesDialog

func _ready() -> void:
	if background:
		background.texture = TEX_BACKGROUND
	if shard_icon:
		shard_icon.texture = ICON_SHARD
	back_button.pressed.connect(GameManager.go_to_main_menu)
	reset_upgrades_button.pressed.connect(_on_reset_upgrades_pressed)
	reset_upgrades_dialog.confirmed.connect(_on_reset_upgrades_confirmed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	if SaveManager:
		SaveManager.meta_progress_changed.connect(_refresh)
	_update_static_texts()
	_refresh()

func _update_static_texts() -> void:
	title_label.text = tr("village.title")
	back_button.text = tr("village.back")
	reset_upgrades_button.text = tr("village.reset_upgrades")
	reset_upgrades_dialog.title = tr("village.reset_upgrades_title")
	reset_upgrades_dialog.ok_button_text = tr("ui.common.confirm")
	reset_upgrades_dialog.cancel_button_text = tr("ui.common.back")
	new_run_button.text = tr("village.new_run")
	var completed = SaveManager.is_tutorial_completed() if SaveManager else false
	new_run_button.disabled = not completed

func _on_reset_upgrades_pressed() -> void:
	var refund := VillageBonuses.get_total_spent_shards()
	if refund <= 0:
		return
	reset_upgrades_dialog.dialog_text = TranslationHelper.tr_format(
		"village.reset_upgrades_confirm",
		{"value": refund}
	)
	reset_upgrades_dialog.popup_centered()

func _on_reset_upgrades_confirmed() -> void:
	VillageBonuses.try_reset_all_upgrades()
	_refresh()

func _on_new_run_pressed() -> void:
	GameManager.go_to_character_select()

func _refresh() -> void:
	shards_label.text = TranslationHelper.tr_format("village.shards", {"value": SaveManager.get_shards()})
	reset_upgrades_button.disabled = not VillageBonuses.has_any_upgrades()
	if VillageBonuses.has_any_upgrades():
		var refund := VillageBonuses.get_total_spent_shards()
		reset_upgrades_button.text = TranslationHelper.tr_format("village.reset_upgrades_refund", {"value": refund})
	else:
		reset_upgrades_button.text = tr("village.reset_upgrades")
	_rebuild_building_rows()

func _rebuild_building_rows() -> void:
	for child in buildings_list.get_children():
		child.queue_free()
	for building_id in VillageBonuses.BUILDING_ORDER:
		buildings_list.add_child(_make_building_row(building_id))

func _make_building_row(building_id: String) -> PanelContainer:
	var level := VillageBonuses.get_level(building_id)
	var max_lv := VillageBonuses.get_max_level(building_id)
	var cost := VillageBonuses.get_upgrade_cost(building_id)
	var can_up := VillageBonuses.can_upgrade(building_id)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.88)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _building_icon(building_id)
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var name_label := Label.new()
	name_label.text = "%s  —  %s" % [
		VillageBonuses.get_building_name(building_id),
		TranslationHelper.tr_format("village.level", {"current": level, "max": max_lv})
	]
	name_label.add_theme_font_size_override("font_size", 27)
	text_col.add_child(name_label)

	var current_label := Label.new()
	current_label.text = VillageBonuses.get_current_effect_text(building_id)
	current_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(current_label)

	var next_label := Label.new()
	next_label.text = VillageBonuses.get_next_effect_text(building_id)
	next_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.7))
	next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(next_label)

	var upgrade_btn := Button.new()
	upgrade_btn.custom_minimum_size = Vector2(140, 40)
	if level >= max_lv:
		upgrade_btn.text = tr("village.maxed")
		upgrade_btn.disabled = true
	else:
		upgrade_btn.text = TranslationHelper.tr_format("village.upgrade", {"cost": cost})
		upgrade_btn.disabled = not can_up
	upgrade_btn.pressed.connect(_on_upgrade_pressed.bind(building_id))
	row.add_child(upgrade_btn)

	return panel

func _building_icon(building_id: String) -> Texture2D:
	match building_id:
		VillageBonuses.WELL:
			return ICON_WELL
		VillageBonuses.MARKET:
			return ICON_MARKET
		VillageBonuses.LIBRARY:
			return ICON_LIBRARY
		VillageBonuses.CHAPEL:
			return ICON_CHAPEL
	return null

func _on_upgrade_pressed(building_id: String) -> void:
	if VillageBonuses.try_upgrade(building_id):
		_refresh()
