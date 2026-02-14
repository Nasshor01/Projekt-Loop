# ===================================================================
# KeywordTooltipContainer.gd - Container that instances KeywordTooltipBox
# ===================================================================
extends VBoxContainer
class_name KeywordTooltipContainer

const KEYWORD_TOOLTIP_BOX_SCENE = preload("res://scenes/ui/KeywordTooltipBox.tscn")


## Clears and repopulates with KeywordTooltipBox for each keyword key.
## Pass the result of KeywordManager.parse_text_for_keywords().
func populate_from_keywords(keys: Array) -> void:
	populate_from_card_keywords(keys, null)


## Clears and repopulates from card: effect-based keywords + text-based, with dynamic descriptions (e.g. Holy +5/+8).
func populate_from_card(card_data: CardData) -> void:
	if not card_data:
		populate_from_keywords([])
		return
	var text_keys: Array = KeywordManager.parse_text_for_keywords(card_data.get_localized_description()) if KeywordManager else []
	var effect_keys: Array[String] = card_data.get_keywords_from_effects()
	var seen := {}
	var keys: Array[String] = []
	for k in text_keys:
		if k is String and not seen.get(k, false):
			seen[k] = true
			keys.append(k)
	for k in effect_keys:
		if not seen.get(k, false):
			seen[k] = true
			keys.append(k)
	populate_from_card_keywords(keys, card_data)


func populate_from_card_keywords(keys: Array, card_data: CardData) -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
	
	if keys.is_empty():
		visible = false
		return
	
	for key in keys:
		if not key is String:
			continue
		if not KeywordManager.get_keyword_data(key).is_empty():
			var box = KEYWORD_TOOLTIP_BOX_SCENE.instantiate() as KeywordTooltipBox
			add_child(box)
			var desc := KeywordManager.get_keyword_description_dynamic(key, card_data)
			box.setup(key, desc)
	
	visible = true
