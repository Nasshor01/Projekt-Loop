# Soubor: res://scenes/events/EventChoiceButton.gd (NOVÁ VERZE)
extends Button

@onready var label: RichTextLabel = $RichTextLabel
var choice_data: EventChoice

func _ready():
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	custom_minimum_size.y = 60

func set_choice_data_new(data: EventChoice):
	choice_data = data
	
	# Použij nový systém
	label.bbcode_enabled = true
	label.text = "[center]" + data.get_full_text() + "[/center]"
	
	# Nastav tooltip
	tooltip_text = data.get_tooltip()

# Zachovej kompatibilitu se starým systémem
func set_choice_data(data: EventChoice):
	set_choice_data_new(data)
