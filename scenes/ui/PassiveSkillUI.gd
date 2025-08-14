# Soubor: scenes/ui/PassiveSkillUI.gd (VYLEPŠENÁ VERZE s RichTextLabel tooltip)
@tool
class_name PassiveSkillUI
extends Button

signal skill_selected(skill_data: PassiveSkillNode)

var skill_data: PassiveSkillNode
@onready var icon_rect: TextureRect = $IcontRect
# STARÝ tooltip system - ponecháme pro fallback
@onready var tool_tip_label: RichTextLabel = $TooltipLabel

# NOVÝ tooltip system s RichTextLabel
var rich_tooltip: RichTextLabel
var tooltip_background: PanelContainer
var is_tooltip_visible: bool = false

# BEZPEČNÉ reference - pokud uzly neexistují, vytvoříme je
var tier_label: Label
var cost_label: Label

func _ready():
	# Najdeme nebo vytvoříme TierLabel
	tier_label = get_node_or_null("TierLabel")
	if not tier_label:
		tier_label = Label.new()
		tier_label.name = "TierLabel"
		tier_label.position = Vector2(4, 4)
		tier_label.size = Vector2(20, 20)
		tier_label.add_theme_font_size_override("font_size", 12)
		tier_label.add_theme_color_override("font_color", Color.WHITE)
		tier_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		tier_label.add_theme_constant_override("shadow_offset_x", 1)
		tier_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(tier_label)
	
	# Najdeme nebo vytvoříme CostLabel  
	cost_label = get_node_or_null("CostLabel")
	if not cost_label:
		cost_label = Label.new()
		cost_label.name = "CostLabel"
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_label.add_theme_color_override("font_color", Color.YELLOW)
		cost_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		cost_label.add_theme_constant_override("shadow_offset_x", 1)
		cost_label.add_theme_constant_override("shadow_offset_y", 1)
		cost_label.position = Vector2(44, 44)
		cost_label.size = Vector2(20, 20)
		add_child(cost_label)

	# Nastavíme základní vlastnosti
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)

	# NOVÝ: Vytvoříme rich tooltip systém
	_create_rich_tooltip()
	
	# Připojíme mouse eventy pro tooltip
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _create_rich_tooltip():
	"""Vytvoří overlay tooltip s RichTextLabel podporou"""
	if rich_tooltip:
		return # Už existuje
	
	# Vytvoříme background panel
	tooltip_background = PanelContainer.new()
	tooltip_background.name = "TooltipBackground"
	tooltip_background.visible = false
	tooltip_background.z_index = 100  # Nad vším ostatním
	tooltip_background.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Neblokuj mouse eventy
	
	# Nastavíme styl background panelu
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Tmavě šedá s průhledností
	style_box.border_color = Color(0.6, 0.6, 0.6, 0.8)
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	style_box.content_margin_left = 12
	style_box.content_margin_right = 12
	
	tooltip_background.add_theme_stylebox_override("panel", style_box)
	
	# Vytvoříme RichTextLabel
	rich_tooltip = RichTextLabel.new()
	rich_tooltip.name = "RichTooltip"
	rich_tooltip.bbcode_enabled = true
	rich_tooltip.fit_content = true
	rich_tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich_tooltip.scroll_active = false
	rich_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Nastavíme maximální šířku tooltip
	rich_tooltip.custom_minimum_size.x = 200
	rich_tooltip.custom_minimum_size.y = 0
	rich_tooltip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rich_tooltip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Přidáme do hierarchie
	tooltip_background.add_child(rich_tooltip)
	
	# Najdeme root node (obvykle main scene nebo canvas layer)
	var root = get_tree().current_scene
	if not root:
		root = get_viewport()
	
	root.add_child(tooltip_background)

func display(data: PassiveSkillNode, is_unlocked: bool, can_unlock: bool):
	self.skill_data = data
	
	# Nastavíme velikost podle typu uzlu
	var node_size = data.get_node_size() if data.has_method("get_node_size") else 64.0
	custom_minimum_size = Vector2(node_size, node_size)
	size = custom_minimum_size
	
	# Nastavíme ikonu
	if is_instance_valid(icon_rect):
		icon_rect.texture = data.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Přidáme margin pro větší uzly
		var margin = max(0, (node_size - 32) / 4)
		icon_rect.position = Vector2(margin, margin)
		icon_rect.size = Vector2(node_size - 2*margin, node_size - 2*margin)
	
	# Nastavíme tier label (pokud existuje)
	if tier_label:
		var tier_value = data.tier if "tier" in data else 1
		tier_label.text = str(tier_value)
		tier_label.visible = tier_value > 1  # Skryjeme pro tier 1
	
	# Nastavíme cost label (pokud existuje)
	if cost_label:
		var cost = data.get_cost_for_tier() if data.has_method("get_cost_for_tier") else data.cost
		cost_label.text = str(cost) if cost > 0 else ""
		cost_label.visible = cost > 0
	
	# Defaultně je vše neaktivní
	disabled = true
	
	# Nastavíme stav a barvy
	if is_unlocked:
		_set_unlocked_state(data)
	elif can_unlock:
		_set_can_unlock_state(data)
	else:
		_set_locked_state(data)
	
	# Speciální vzhled pro startovací uzly
	if "is_starter" in data and data.is_starter and not is_unlocked:
		_set_starter_state(data)
	
	# Připravíme tooltip obsah (ale nezobrazujeme ho)
	_prepare_tooltip_content(data, is_unlocked, can_unlock)
	
	# Připojíme signál
	if not is_connected("pressed", _on_skill_pressed):
		pressed.connect(_on_skill_pressed)

func _prepare_tooltip_content(data: PassiveSkillNode, is_unlocked: bool, can_unlock: bool):
	"""Připraví obsah tooltip, ale nezobrazuje ho"""
	if not rich_tooltip:
		return
	
	var tooltip_text = "[b][font_size=16]%s[/font_size][/b]\n" % data.skill_name
	tooltip_text += "%s" % data.description
	
	# Přidáme informace o efektech (pokud existují)
	if "effects" in data and not data.effects.is_empty():
		tooltip_text += "\n\n[color=cyan][b]Efekty:[/b][/color]"
		for effect in data.effects:
			tooltip_text += "\n• %s" % _format_effect_description(effect)
	
	# Přidáme informace o tieru (pokud existuje)
	if "tier" in data:
		tooltip_text += "\n\n[color=yellow][b]Tier %d[/b][/color]" % data.tier
	
	# Přidáme typ uzlu (pokud existuje)
	if "node_type" in data:
		match data.node_type:
			PassiveSkillNode.NodeType.NOTABLE: 
				tooltip_text += " [color=gold]• Notable[/color]"
			PassiveSkillNode.NodeType.KEYSTONE: 
				tooltip_text += " [color=red]• Keystone[/color]"
			PassiveSkillNode.NodeType.MASTERY: 
				tooltip_text += " [color=cyan]• Mastery[/color]"
			PassiveSkillNode.NodeType.STARTER:
				tooltip_text += " [color=lightgreen]• Starter[/color]"
	
	# Přidáme stav
	tooltip_text += "\n"
	if is_unlocked:
		tooltip_text += "\n[color=green][b]✓ Odemčeno[/b][/color]"
	elif can_unlock:
		var cost = data.get_cost_for_tier() if data.has_method("get_cost_for_tier") else data.cost
		tooltip_text += "\n[color=yellow][b]Cena: %d bodů[/b][/color]" % cost
		tooltip_text += "\n[color=green]Klikni pro odemčení[/color]"
	else:
		tooltip_text += "\n[color=red][b]Zamčeno[/b][/color]"
	
	# Nastavíme text do RichTextLabel
	rich_tooltip.text = tooltip_text

func _on_mouse_entered():
	"""Zobrazí rich tooltip při najetí myší"""
	if not rich_tooltip or not tooltip_background or not skill_data:
		return
	
	is_tooltip_visible = true
	tooltip_background.visible = true
	
	# Umístíme tooltip poblíž kurzoru
	_position_tooltip()

func _on_mouse_exited():
	"""Skryje rich tooltip při opuštění myší"""
	if not tooltip_background:
		return
	
	is_tooltip_visible = false
	tooltip_background.visible = false

func _position_tooltip():
	"""Umístí tooltip na správnou pozici"""
	if not tooltip_background or not is_tooltip_visible:
		return
	
	# Získáme pozici myši
	var mouse_pos = get_global_mouse_position()
	var viewport_size = get_viewport().size
	
	# Offset od kurzoru
	var offset = Vector2(15, -10)
	var tooltip_pos = mouse_pos + offset
	
	# Ujistíme se, že tooltip se vejde na obrazovku
	await get_tree().process_frame  # Počkáme na aktualizaci velikosti
	var tooltip_size = tooltip_background.size
	
	# Zkontrolujeme pravý okraj
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		tooltip_pos.x = mouse_pos.x - tooltip_size.x - 15
	
	# Zkontrolujeme spodní okraj
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		tooltip_pos.y = mouse_pos.y - tooltip_size.y + 10
	
	# Zkontrolujeme horní okraj
	if tooltip_pos.y < 0:
		tooltip_pos.y = 10
	
	# Zkontrolujeme levý okraj
	if tooltip_pos.x < 0:
		tooltip_pos.x = 10
	
	tooltip_background.position = tooltip_pos

# Zbytek kódu zůstává stejný...
func _set_unlocked_state(data: PassiveSkillNode):
	var color = data.get_node_color() if data.has_method("get_node_color") else Color.WHITE
	modulate = color
	_add_visual_effects(data, true)

func _set_can_unlock_state(data: PassiveSkillNode):
	disabled = false
	modulate = Color("ffd700")  # Zlatá pro dostupné
	_add_glow_effect()

func _set_locked_state(data: PassiveSkillNode):
	modulate = Color(0.3, 0.3, 0.3)
	_remove_visual_effects()

func _set_starter_state(data: PassiveSkillNode):
	disabled = false
	modulate = Color("aaddff")  # Světle modrá pro starter
	_add_pulse_effect()

func _add_visual_effects(data: PassiveSkillNode, is_unlocked: bool):
	if not "node_type" in data:
		return
		
	match data.node_type:
		PassiveSkillNode.NodeType.NOTABLE:
			_add_glow_effect(Color.GOLD)
		PassiveSkillNode.NodeType.KEYSTONE:
			_add_glow_effect(Color.CRIMSON)
			_add_pulse_effect()
		PassiveSkillNode.NodeType.MASTERY:
			_add_glow_effect(Color.CYAN)
			_add_rotate_effect()

func _add_glow_effect(glow_color: Color = Color.YELLOW):
	add_theme_color_override("font_outline_color", glow_color)
	add_theme_constant_override("outline_size", 2)

func _add_pulse_effect():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 1.0)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 1.0)

func _add_rotate_effect():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "rotation", 2 * PI, 8.0)

func _remove_visual_effects():
	var tweens = get_tree().get_processed_tweens()
	for tween in tweens:
		if tween.is_valid():
			tween.kill()
	
	scale = Vector2.ONE
	rotation = 0.0
	remove_theme_color_override("font_outline_color")
	remove_theme_constant_override("outline_size")

func _format_effect_description(effect) -> String:
	if not is_instance_valid(effect):
		return "Neplatný efekt"
		
	if not "effect_type" in effect:
		return "Neznámý efekt"
	
	var value = effect.value if "value" in effect else 0
	
	# Používáme BBCode formátování pro lepší vzhled
	if effect.effect_type == PassiveEffectData.EffectType.ADD_MAX_HP:
		return "[color=lightgreen]+%d[/color] maximálního zdraví" % value
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_STARTING_GOLD:
		return "[color=gold]+%d[/color] startovního zlata" % value  
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_MAX_ENERGY:
		return "[color=lightblue]+%d[/color] maximální energie" % value
	elif effect.effect_type == PassiveEffectData.EffectType.GRANT_REVIVE:
		return "[color=yellow]Možnost oživení[/color]" if value > 0 else ""
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_CARD_DAMAGE:
		return "[color=orange]+%d[/color] poškození všech karet" % value
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_RETAINED_BLOCK:
		return "[color=lightblue]+%d[/color] startovního bloku" % value
	else:
		return "[color=purple]Speciální efekt[/color]"

func _on_skill_pressed():
	if skill_data:
		emit_signal("skill_selected", skill_data)

# Cleanup při odstranění
func _exit_tree():
	if tooltip_background and is_instance_valid(tooltip_background):
		tooltip_background.queue_free()

# Override _draw zůstává stejný
func _draw():
	if not skill_data or not "node_type" in skill_data:
		return
	
	var rect = get_rect()
	var center = rect.size / 2
	var radius = min(rect.size.x, rect.size.y) / 2 - 4
	
	match skill_data.node_type:
		PassiveSkillNode.NodeType.BASIC:
			_draw_circle(center, radius)
		PassiveSkillNode.NodeType.NOTABLE:
			_draw_circle(center, radius, 3.0)
		PassiveSkillNode.NodeType.KEYSTONE:
			_draw_octagon(center, radius)
		PassiveSkillNode.NodeType.MASTERY:
			_draw_star(center, radius)
		PassiveSkillNode.NodeType.STARTER:
			_draw_diamond(center, radius)

func _draw_circle(center: Vector2, radius: float, border_width: float = 2.0):
	draw_circle(center, radius, Color.TRANSPARENT, false, border_width)
	draw_arc(center, radius, 0, 2*PI, 32, modulate, border_width)

func _draw_octagon(center: Vector2, radius: float):
	var points = PackedVector2Array()
	for i in range(8):
		var angle = i * PI / 4
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if points.size() > 2:
		draw_colored_polygon(points, Color(modulate.r, modulate.g, modulate.b, 0.3))

func _draw_star(center: Vector2, radius: float):
	var points = PackedVector2Array()
	for i in range(10):
		var angle = i * PI / 5
		var r = radius if i % 2 == 0 else radius * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	if points.size() > 2:
		draw_colored_polygon(points, Color(modulate.r, modulate.g, modulate.b, 0.3))

func _draw_diamond(center: Vector2, radius: float):
	var points = PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0)
	])
	draw_colored_polygon(points, Color(modulate.r, modulate.g, modulate.b, 0.3))
