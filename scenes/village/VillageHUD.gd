# Always-on village chrome. Lives on a CanvasLayer so camera pan never moves it.
class_name VillageHUD
extends CanvasLayer

signal back_pressed
signal reset_pressed
signal new_run_pressed
signal upgrade_pressed
signal detail_closed

const TIP_MARGIN := 14.0
const TIP_PAD := 10.0

@onready var title_label: Label = %TitleLabel
@onready var shards_label: Label = %ShardsLabel
@onready var shards_caption: Label = %ShardsCaption
@onready var back_button: Button = %BackButton
@onready var reset_upgrades_button: Button = %ResetUpgradesButton
@onready var new_run_button: Button = %NewRunButton
@onready var reset_upgrades_dialog: ConfirmationDialog = %ResetUpgradesDialog
@onready var detail_dim: ColorRect = %DetailDim
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var detail_title: Label = %DetailTitle
@onready var detail_body: RichTextLabel = %DetailBody
@onready var detail_upgrade_button: Button = %DetailUpgradeButton
@onready var detail_close_button: Button = %DetailCloseButton
@onready var building_tip: PanelContainer = %BuildingTip
@onready var building_tip_label: RichTextLabel = %BuildingTipLabel

var _tip_token: int = 0


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	reset_upgrades_button.pressed.connect(func() -> void: reset_pressed.emit())
	new_run_button.pressed.connect(func() -> void: new_run_pressed.emit())
	detail_close_button.pressed.connect(func() -> void: detail_closed.emit())
	detail_upgrade_button.pressed.connect(func() -> void: upgrade_pressed.emit())
	detail_dim.gui_input.connect(_on_dim_gui_input)
	hide_detail()
	hide_world_tooltip()
	apply_static_texts()


func apply_static_texts() -> void:
	title_label.text = tr("village.title")
	shards_caption.text = tr("village.shards_label")
	back_button.text = tr("village.back")
	reset_upgrades_button.text = tr("village.reset_upgrades")
	reset_upgrades_dialog.title = tr("village.reset_upgrades_title")
	reset_upgrades_dialog.ok_button_text = tr("ui.common.confirm")
	reset_upgrades_dialog.cancel_button_text = tr("ui.common.back")
	new_run_button.text = tr("village.new_run")
	detail_close_button.text = tr("ui.common.close")
	var completed = SaveManager.is_tutorial_completed() if SaveManager else false
	new_run_button.disabled = not completed


func set_shards_value(amount: int) -> void:
	shards_label.text = str(amount)


func set_reset_enabled(enabled: bool, label: String) -> void:
	reset_upgrades_button.disabled = not enabled
	reset_upgrades_button.text = label


func popup_reset_confirm(dialog_text: String) -> void:
	reset_upgrades_dialog.dialog_text = dialog_text
	reset_upgrades_dialog.popup_centered()


func bind_reset_confirmed(cb: Callable) -> void:
	if not reset_upgrades_dialog.confirmed.is_connected(cb):
		reset_upgrades_dialog.confirmed.connect(cb)


func show_detail(title: String, body: String, upgrade_label: String, can_upgrade: bool, show_upgrade: bool) -> void:
	hide_world_tooltip()
	detail_title.text = title
	detail_body.text = body
	detail_upgrade_button.visible = show_upgrade
	detail_upgrade_button.text = upgrade_label
	detail_upgrade_button.disabled = not can_upgrade
	detail_dim.visible = true
	detail_panel.visible = true


func hide_detail() -> void:
	detail_panel.visible = false
	detail_dim.visible = false


func show_world_tooltip(bbcode: String, screen_rect: Rect2) -> void:
	if detail_panel.visible:
		return
	_tip_token += 1
	var token := _tip_token
	building_tip_label.text = bbcode
	building_tip.visible = true
	await get_tree().process_frame
	if token != _tip_token or not building_tip.visible:
		return
	building_tip.reset_size()
	var tip_size := building_tip.get_combined_minimum_size()
	tip_size.x = maxf(tip_size.x, 360.0)
	building_tip.size = tip_size
	building_tip.global_position = _clamp_tip(screen_rect, tip_size)


func hide_world_tooltip() -> void:
	_tip_token += 1
	if building_tip:
		building_tip.visible = false
	if is_instance_valid(ArtifactHoverTooltip.instance):
		ArtifactHoverTooltip.instance.hide_tip()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		detail_closed.emit()


func _clamp_tip(anchor_rect: Rect2, tip_size: Vector2) -> Vector2:
	var screen := get_viewport().get_visible_rect()
	var min_x := screen.position.x + TIP_PAD
	var max_x := screen.end.x - tip_size.x - TIP_PAD
	var min_y := screen.position.y + TIP_PAD
	var max_y := screen.end.y - tip_size.y - TIP_PAD
	if max_x < min_x:
		max_x = min_x
	if max_y < min_y:
		max_y = min_y
	var candidates: Array[Vector2] = [
		Vector2(anchor_rect.end.x + TIP_MARGIN, anchor_rect.position.y),
		Vector2(anchor_rect.position.x - tip_size.x - TIP_MARGIN, anchor_rect.position.y),
		Vector2(anchor_rect.position.x, anchor_rect.end.y + TIP_MARGIN),
		Vector2(anchor_rect.position.x, anchor_rect.position.y - tip_size.y - TIP_MARGIN),
	]
	var best := candidates[0]
	var best_score := -INF
	for pos in candidates:
		var clamped := Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))
		var score := -(absf(clamped.x - pos.x) + absf(clamped.y - pos.y))
		if score > best_score:
			best_score = score
			best = clamped
	return best
