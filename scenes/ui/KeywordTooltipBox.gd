# ===================================================================
# KeywordTooltipBox.gd - Single keyword tooltip row
# ===================================================================
extends HBoxContainer
class_name KeywordTooltipBox

@onready var icon_texture: TextureRect = $IconTexture
@onready var title_label: Label = $TextContainer/TitleLabel
@onready var description_label: RichTextLabel = $TextContainer/DescriptionLabel

var _keyword_key: String = ""


func setup(keyword_key: String, custom_description: String = "") -> void:
	_keyword_key = keyword_key
	if not KeywordManager:
		return
	
	var data = KeywordManager.get_keyword_data(keyword_key)
	if data.is_empty():
		visible = false
		return
	
	title_label.text = KeywordManager.get_keyword_title(keyword_key)
	var desc := custom_description if not custom_description.is_empty() else KeywordManager.get_keyword_description(keyword_key)
	var color = KeywordManager.get_keyword_color(keyword_key)
	description_label.text = "[color=%s]%s[/color]" % [color, desc]
	
	var icon_path = KeywordManager.get_keyword_icon_path(keyword_key)
	if icon_path and ResourceLoader.exists(icon_path):
		var tex = load(icon_path) as Texture2D
		if tex:
			icon_texture.texture = tex
			icon_texture.visible = true
	else:
		icon_texture.visible = false
	
	visible = true
