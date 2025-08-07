# Soubor: scenes/ui/PassiveSkillUI.gd (OPRAVENÁ FINÁLNÍ VERZE)
class_name PassiveSkillUI
extends Button

signal skill_selected(skill_data: PassiveSkillNode)

var skill_data: PassiveSkillNode

@onready var icon_rect: TextureRect = $TextureRect

func display(data: PassiveSkillNode, is_unlocked: bool, can_unlock: bool):
	self.skill_data = data
	
	if is_instance_valid(icon_rect):
		icon_rect.texture = data.icon
		custom_minimum_size = Vector2(96, 96)
		
		# --- ZDE JE KLÍČOVÁ OPRAVA ---
		# 1. Řekneme TextureRectu, aby ignoroval původní velikost textury a vyplnil celé tlačítko.
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
		# 2. A zde mu řekneme, JAK to má vyplnit – se zachováním poměru stran a vycentrováním.
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if is_unlocked:
		disabled = true
		modulate = Color.WHITE
		tooltip_text = "[b]%s[/b]\n%s\n\n[color=green]Odemčeno[/color]" % [data.skill_name, data.description]
	elif can_unlock:
		disabled = false
		modulate = Color(0.9, 0.9, 0.9)
		tooltip_text = "[b]%s[/b]\n%s\n\nCena: %d bodů" % [data.skill_name, data.description, data.cost]
	else:
		disabled = true
		modulate = Color(0.3, 0.3, 0.3)
		tooltip_text = "[b]%s[/b]\n%s\n\n[color=red]Zamčeno[/color]" % [data.skill_name, data.description]
		
	if not is_connected("pressed", _on_skill_pressed):
		pressed.connect(_on_skill_pressed)

func _on_skill_pressed():
	# Když hráč klikne, vyšleme signál s daty našeho nového PassiveSkillNode
	emit_signal("skill_selected", skill_data)
