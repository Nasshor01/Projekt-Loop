# ===================================================================
# Soubor: res://scenes/ui/CardTooltip.gd
# POPIS: Tooltip pro zobrazení detailního popisu karty při hoveru
# ===================================================================
extends PanelContainer
class_name CardTooltip

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var effects_label: Label = $MarginContainer/VBoxContainer/EffectsLabel
@onready var cost_label: Label = $MarginContainer/VBoxContainer/CostLabel

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_tooltip(card_data: CardData, tooltip_pos: Vector2):
	"""Zobrazí tooltip s informacemi o kartě na zadané pozici"""
	if not card_data:
		hide_tooltip()
		return
	
	# Nastavíme texty
	if name_label:
		name_label.text = card_data.get_localized_name()
	if cost_label:
		cost_label.text = TranslationHelper.tr_format("card.tooltip.cost", {"value": card_data.cost})
	
	# Použijeme původní dlouhý popis karty (ne zjednodušený)
	if description_label:
		description_label.text = card_data.get_localized_description()
	
	# Zobrazíme další informace (range, rarity, tags)
	var additional_info: Array[String] = []
	
	# Range informace
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
	
	# Rarity
	var rarity_names = {
		CardData.CardRarity.BASIC: tr("card.rarity.basic"),
		CardData.CardRarity.COMMON: tr("card.rarity.common"),
		CardData.CardRarity.UNCOMMON: tr("card.rarity.uncommon"),
		CardData.CardRarity.RARE: tr("card.rarity.rare"),
		CardData.CardRarity.EPIC: tr("card.rarity.epic"),
		CardData.CardRarity.LEGENDARY: tr("card.rarity.legendary")
	}
	if rarity_names.has(card_data.rarity):
		additional_info.append(TranslationHelper.tr_format("card.tooltip.rarity", {"value": rarity_names[card_data.rarity]}))
	
	# Upgradovaná verze
	if card_data.is_upgraded:
		additional_info.append(tr("card.tooltip.upgraded"))
	
	if effects_label:
		if not additional_info.is_empty():
			effects_label.text = "\n".join(additional_info)
		else:
			effects_label.text = ""
	
	# Nastavíme pozici
	global_position = tooltip_pos
	
	# Zobrazíme tooltip
	visible = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_tooltip():
	"""Skryje tooltip s fade out efektem"""
	if not visible:
		return
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false)
