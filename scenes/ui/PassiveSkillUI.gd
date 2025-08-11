# Soubor: scenes/ui/PassiveSkillUI.gd (OPRAVENÁ VERZE - kompatibilní se stávající scénou)
@tool
class_name PassiveSkillUI
extends Button

signal skill_selected(skill_data: PassiveSkillNode)

var skill_data: PassiveSkillNode
@onready var icon_rect: TextureRect = $TextureRect
# BEZPEČNÉ reference - pokud uzly neexistují, vytvoříme je nebo použijeme jiný přístup
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
		# Jednoduché pozicionování bez anchor problémů
		cost_label.position = Vector2(44, 44)
		cost_label.size = Vector2(20, 20)
		add_child(cost_label)

	# Nastavíme základní vlastnosti
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)

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
	
	# Vytvoříme tooltip
	_update_tooltip(data, is_unlocked, can_unlock)
	
	# Připojíme signál
	if not is_connected("pressed", _on_skill_pressed):
		pressed.connect(_on_skill_pressed)

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
	# Pouze pokud má data podporu pro node_type
	if not "node_type" in data:
		return
		
	# Přidáme vizuální efekty podle typu uzlu
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
	# Jednoduchý glow efekt pomocí outline
	add_theme_color_override("font_outline_color", glow_color)
	add_theme_constant_override("outline_size", 2)

func _add_pulse_effect():
	# Pulzující animace
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 1.0)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 1.0)

func _add_rotate_effect():
	# Jemná rotace pro mastery uzly
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "rotation", 2 * PI, 8.0)

func _remove_visual_effects():
	# Zastavíme všechny animace
	var tweens = get_tree().get_processed_tweens()
	for tween in tweens:
		if tween.is_valid():
			tween.kill()
	
	scale = Vector2.ONE
	rotation = 0.0
	remove_theme_color_override("font_outline_color")
	remove_theme_constant_override("outline_size")

func _update_tooltip(data: PassiveSkillNode, is_unlocked: bool, can_unlock: bool):
	var tooltip = "[b]%s[/b]\n%s" % [data.skill_name, data.description]
	
	# Přidáme informace o efektech (pokud existují)
	if "effects" in data and not data.effects.is_empty():
		tooltip += "\n\n[color=cyan]Efekty:[/color]"
		for effect in data.effects:
			tooltip += "\n• %s" % _format_effect_description(effect)
	
	# Přidáme informace o tieru (pokud existuje)
	if "tier" in data:
		tooltip += "\n\n[color=yellow]Tier %d[/color]" % data.tier
	
	# Přidáme typ uzlu (pokud existuje)
	if "node_type" in data:
		match data.node_type:
			PassiveSkillNode.NodeType.NOTABLE: tooltip += " [color=gold]• Notable[/color]"
			PassiveSkillNode.NodeType.KEYSTONE: tooltip += " [color=red]• Keystone[/color]"
			PassiveSkillNode.NodeType.MASTERY: tooltip += " [color=cyan]• Mastery[/color]"
	
	# Přidáme stav
	if is_unlocked:
		tooltip += "\n\n[color=green]✓ Odemčeno[/color]"
	elif can_unlock:
		var cost = data.get_cost_for_tier() if data.has_method("get_cost_for_tier") else data.cost
		tooltip += "\n\n[color=yellow]Cena: %d bodů[/color]" % cost
		tooltip += "\n[color=green]Klikni pro odemčení[/color]"
	else:
		tooltip += "\n\n[color=red]Zamčeno[/color]"
	
	tooltip_text = tooltip

func _format_effect_description(effect) -> String:
	# Bezpečné formátování efektů
	if not is_instance_valid(effect):
		return "Neplatný efekt"
		
	if not "effect_type" in effect:
		return "Neznámý efekt"
	
	var value = effect.value if "value" in effect else 0
	
	# Pokud máme nové enumy, použijeme je, jinak fallback
	if effect.effect_type == PassiveEffectData.EffectType.ADD_MAX_HP:
		return "+%d maximálního zdraví" % value
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_STARTING_GOLD:
		return "+%d startovního zlata" % value  
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_MAX_ENERGY:
		return "+%d maximální energie" % value
	elif effect.effect_type == PassiveEffectData.EffectType.GRANT_REVIVE:
		return "Možnost oživení" if value > 0 else ""
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_CARD_DAMAGE:
		return "+%d poškození všech karet" % value
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_RETAINED_BLOCK:
		return "+%d startovního bloku" % value
	else:
		return "Speciální efekt"

func _on_skill_pressed():
	if skill_data:
		emit_signal("skill_selected", skill_data)

# VOLITELNÉ: Override pro custom kreslení různých tvarů uzlů
func _draw():
	if not skill_data or not "node_type" in skill_data:
		return
	
	var rect = get_rect()
	var center = rect.size / 2
	var radius = min(rect.size.x, rect.size.y) / 2 - 4
	
	# Nakreslíme tvar podle typu uzlu
	match skill_data.node_type:
		PassiveSkillNode.NodeType.BASIC:
			_draw_circle(center, radius)
		PassiveSkillNode.NodeType.NOTABLE:
			_draw_circle(center, radius, 3.0)  # Tlustší okraj
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
