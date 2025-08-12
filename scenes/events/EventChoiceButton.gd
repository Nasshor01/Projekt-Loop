# ==============================================
# 2. DOKONČENÍ EventChoiceButton.gd
# ==============================================
# Soubor: res://scenes/events/EventChoiceButton.gd

extends Button

var choice_data: EventChoice
@onready var base_text_color = Color.WHITE
@onready var disabled_text_color = Color(0.5, 0.5, 0.5)

func _ready():
	# Nastav základní styl
	add_theme_font_size_override("font_size", 16)
	custom_minimum_size.y = 50

func set_choice_data(data: EventChoice):
	choice_data = data
	
	# Vytvoř text s cenou a šancí
	var button_text = data.choice_text
	
	# Přidej cenu
	var cost_parts = []
	if data.costs.has("gold") and data.costs.gold > 0:
		cost_parts.append("-%d Gold" % data.costs.gold)
	if data.costs.has("hp") and data.costs.hp > 0:
		cost_parts.append("-%d HP" % data.costs.hp)
	if data.costs.has("max_hp") and data.costs.max_hp > 0:
		cost_parts.append("-%d Max HP" % data.costs.max_hp)
	
	if not cost_parts.is_empty():
		button_text += "\n[Cena: %s]" % ", ".join(PackedStringArray(cost_parts))
	
	# Přidej šanci na úspěch pokud je < 100%
	if data.success_chance < 1.0:
		var chance_percent = int(data.success_chance * 100)
		button_text += " (%d%% šance)" % chance_percent
	
	text = button_text
	
	# Nastav tooltip
	if data.choice_tooltip != "":
		tooltip_text = data.choice_tooltip
	else:
		# Vytvoř automatický tooltip z rewards
		var reward_parts = []
		if data.rewards.has("gold") and data.rewards.gold > 0:
			reward_parts.append("+%d Gold" % data.rewards.gold)
		if data.rewards.has("heal") and data.rewards.heal > 0:
			reward_parts.append("+%d HP" % data.rewards.heal)
		if data.rewards.has("max_hp") and data.rewards.max_hp > 0:
			reward_parts.append("+%d Max HP" % data.rewards.max_hp)
		
		if not reward_parts.is_empty():
			tooltip_text = "Možné odměny: %s" % ", ".join(PackedStringArray(reward_parts))
