# ===================================================================
# Soubor: res://scenes/ui/CardTooltip.gd
# POPIS: Tooltip pro zobrazení detailního popisu karty při hoveru
# ===================================================================
extends PanelContainer
class_name CardTooltip

const TOOLTIP_WIDTH := 360.0
const MAX_TOOLTIP_HEIGHT := 520.0
const VIEWPORT_MARGIN := 12.0
# GlobalUI MainPanel is 80px tall; keep tooltips clear of the top HUD bar.
const TOP_SAFE_MARGIN := 90.0

@onready var scroll_container: ScrollContainer = $MarginContainer/ScrollContainer
@onready var name_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $MarginContainer/ScrollContainer/VBoxContainer/DescriptionLabel
@onready var effects_label: RichTextLabel = $MarginContainer/ScrollContainer/VBoxContainer/EffectsLabel
@onready var cost_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/CostLabel
@onready var keyword_separator: HSeparator = $MarginContainer/ScrollContainer/VBoxContainer/KeywordSeparator
@onready var keyword_container: KeywordTooltipContainer = $MarginContainer/ScrollContainer/VBoxContainer/KeywordTooltipContainer

var _show_tween: Tween = null

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)

func show_tooltip(card_data: CardData, tooltip_pos: Vector2):
	"""Zobrazí tooltip s informacemi o kartě na zadané pozici"""
	if not card_data:
		hide_tooltip()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = null
	modulate.a = 1.0
	
	if name_label:
		name_label.text = card_data.get_localized_name()
	if cost_label:
		cost_label.text = TranslationHelper.tr_format("card.tooltip.cost", {"value": card_data.cost})
	
	if description_label:
		description_label.text = card_data.get_localized_description()
	
	var additional_info: Array[String] = []
	
	match card_data.range_type:
		CardData.EffectRangeType.NONE:
			additional_info.append(tr("card.tooltip.range.none"))
		CardData.EffectRangeType.SELF:
			additional_info.append(tr("card.tooltip.range.self"))
		CardData.EffectRangeType.MELEE:
			additional_info.append(TranslationHelper.tr_format("card.tooltip.range.melee", {"value": card_data.range_value}))
		CardData.EffectRangeType.RANGED_FIXED:
			additional_info.append(TranslationHelper.tr_format("card.tooltip.range.ranged_fixed", {"value": card_data.range_value}))
		CardData.EffectRangeType.RANGED_LINE:
			additional_info.append(TranslationHelper.tr_format("card.tooltip.range.ranged_line", {"value": card_data.range_value}))
		CardData.EffectRangeType.GRID_AOE:
			additional_info.append(tr("card.tooltip.range.grid_aoe"))
		CardData.EffectRangeType.FULL_BOARD:
			additional_info.append(tr("card.tooltip.range.full_board"))
	
	var rarity_names = {
		CardData.CardRarity.BASIC: tr("card.rarity.basic"),
		CardData.CardRarity.COMMON: tr("card.rarity.common"),
		CardData.CardRarity.UNCOMMON: tr("card.rarity.common"), ## deprecated
		CardData.CardRarity.RARE: tr("card.rarity.rare"),
		CardData.CardRarity.EPIC: tr("card.rarity.epic"),
		CardData.CardRarity.LEGENDARY: tr("card.rarity.legendary")
	}
	var display_rarity = card_data.rarity
	if display_rarity == CardData.CardRarity.UNCOMMON:
		display_rarity = CardData.CardRarity.COMMON
	if rarity_names.has(display_rarity):
		additional_info.append(TranslationHelper.tr_format("card.tooltip.rarity", {"value": rarity_names[display_rarity]}))
	
	if card_data.is_upgraded:
		additional_info.append(tr("card.tooltip.upgraded"))
	
	if effects_label:
		if not additional_info.is_empty():
			effects_label.text = "\n".join(additional_info)
			effects_label.visible = true
		else:
			effects_label.text = ""
			effects_label.visible = false
	
	if keyword_container and KeywordManager:
		keyword_container.populate_from_card(card_data)
	
	if keyword_separator:
		keyword_separator.visible = keyword_container != null and keyword_container.get_child_count() > 0
	
	if scroll_container:
		scroll_container.scroll_vertical = 0
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	visible = true
	await _fit_content_height()
	if not is_instance_valid(self) or not visible:
		return
	global_position = _clamp_tooltip_position(tooltip_pos)
	
	if modulate.a < 0.5:
		modulate.a = 0.0
		_show_tween = create_tween()
		_show_tween.tween_property(self, "modulate:a", 1.0, 0.2)
		_show_tween.finished.connect(_on_show_tween_finished)
	else:
		modulate.a = 1.0

func _fit_content_height() -> void:
	"""Shrink panel to content; enable scroll only when content exceeds max height."""
	await get_tree().process_frame
	if not is_instance_valid(self) or not visible:
		return
	var content := scroll_container.get_child(0) as Control if scroll_container else null
	if not content:
		return
	var content_h = content.get_combined_minimum_size().y
	var margins = 28.0 # top+bottom margin approx
	var desired = content_h + margins
	var capped = minf(desired, MAX_TOOLTIP_HEIGHT)
	custom_minimum_size = Vector2(TOOLTIP_WIDTH, capped)
	size = Vector2(TOOLTIP_WIDTH, capped)
	if scroll_container:
		if desired > MAX_TOOLTIP_HEIGHT:
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			scroll_container.custom_minimum_size.y = MAX_TOOLTIP_HEIGHT - margins
		else:
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll_container.custom_minimum_size.y = content_h
	await get_tree().process_frame

func _clamp_tooltip_position(preferred: Vector2) -> Vector2:
	var screen_size = get_viewport().get_visible_rect().size
	var tip_size = size
	if tip_size.x < 1.0 or tip_size.y < 1.0:
		tip_size = custom_minimum_size
	var pos = preferred
	var min_x = VIEWPORT_MARGIN
	var max_x = screen_size.x - tip_size.x - VIEWPORT_MARGIN
	var min_y = _get_top_safe_margin()
	var max_y = screen_size.y - tip_size.y - VIEWPORT_MARGIN
	if max_x < min_x:
		pos.x = min_x
	else:
		pos.x = clampf(pos.x, min_x, max_x)
	if max_y < min_y:
		# Prefer keeping the top below the HUD even if the bottom clips slightly.
		pos.y = min_y
	else:
		pos.y = clampf(pos.y, min_y, max_y)
	return pos

func _get_top_safe_margin() -> float:
	"""Reserve space for GlobalUI top bar when the HUD is visible."""
	if Engine.is_editor_hint() or not is_inside_tree():
		return VIEWPORT_MARGIN
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and is_instance_valid(gm.global_ui_instance) and gm.global_ui_instance.visible:
		return TOP_SAFE_MARGIN
	return VIEWPORT_MARGIN

func _on_show_tween_finished():
	_show_tween = null

func hide_tooltip():
	"""Skryje tooltip s fade out efektem"""
	if not visible:
		return
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
		_show_tween = null
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
