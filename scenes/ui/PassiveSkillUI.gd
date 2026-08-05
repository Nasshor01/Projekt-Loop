# Soubor: scenes/ui/PassiveSkillUI.gd (ZJEDNODUŠENÁ VERZE)
@tool
class_name PassiveSkillUI
extends Button

signal skill_selected(skill_data: PassiveSkillNode)

var skill_data: PassiveSkillNode
@onready var icon_rect: TextureRect = $IcontRect

# BEZPEČNÉ reference
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
		tier_label.add_theme_font_size_override("font_size", 20)
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
		cost_label.add_theme_font_size_override("font_size", 17)
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
		
		# Přidáme margin pro větší uzly
		var margin = max(0, (node_size - 32) / 4)
		var icon_size = node_size - 2*margin
		
		# Nastavíme anchors na TOP_LEFT, abychom mohli volně nastavit position a size
		icon_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
		icon_rect.position = Vector2(margin, margin)
		icon_rect.size = Vector2(icon_size, icon_size)
	
	# Nastavíme tier label
	if tier_label:
		var tier_value = data.tier if "tier" in data else 1
		tier_label.text = str(tier_value)
		tier_label.visible = tier_value > 1
	
	# Nastavíme cost label
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
	
	# JEDNODUCHY TOOLTIP - prostý text bez BBCode
	tooltip_text = _create_simple_tooltip(data, is_unlocked, can_unlock)
	
	# Připojíme signál
	if not is_connected("pressed", _on_skill_pressed):
		pressed.connect(_on_skill_pressed)

func _create_simple_tooltip(data: PassiveSkillNode, is_unlocked: bool, can_unlock: bool) -> String:
	"""Vytvoří prostý tooltip text bez BBCode"""
	var tooltip = "%s\n" % data.get_localized_name()
	tooltip += "%s" % data.get_localized_description()
	
	# Přidáme informace o efektech
	if "effects" in data and not data.effects.is_empty():
		tooltip += "\n\n" + tr("skill.tooltip.effects")
		for effect in data.effects:
			tooltip += "\n• %s" % _format_effect_simple(effect)
	
	# Přidáme informace o tieru
	if "tier" in data:
		tooltip += "\n\n" + TranslationHelper.tr_format("skill.tooltip.tier_plain", {"value": data.tier})
	
	# Přidáme typ uzlu
	if "node_type" in data:
		match data.node_type:
			PassiveSkillNode.NodeType.NOTABLE: 
				tooltip += " • " + tr("skill.tooltip.notable_plain")
			PassiveSkillNode.NodeType.KEYSTONE: 
				tooltip += " • " + tr("skill.tooltip.keystone_plain")
			PassiveSkillNode.NodeType.MASTERY: 
				tooltip += " • " + tr("skill.tooltip.mastery_plain")
			PassiveSkillNode.NodeType.STARTER:
				tooltip += " • " + tr("skill.tooltip.starter_plain")
	
	# Přidáme stav
	if is_unlocked:
		tooltip += "\n\n" + tr("skill.tooltip.unlocked")
	elif can_unlock:
		var cost = data.get_cost_for_tier() if data.has_method("get_cost_for_tier") else data.cost
		tooltip += "\n\n" + TranslationHelper.tr_format("skill.tooltip.cost", {"value": cost})
		tooltip += "\n" + tr("skill.tooltip.click_to_unlock")
	else:
		tooltip += "\n\n" + tr("skill.tooltip.locked")
	
	return tooltip

func _format_effect_simple(effect) -> String:
	"""Jednoduché formátování efektů bez BBCode"""
	if not is_instance_valid(effect):
		return tr("skill.effect.invalid")
		
	if not "effect_type" in effect:
		return tr("skill.effect.unknown")
	
	var value = effect.value if "value" in effect else 0
	
	if effect.effect_type == PassiveEffectData.EffectType.ADD_MAX_HP:
		return TranslationHelper.tr_format("skill.effect.add_max_hp", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_STARTING_GOLD:
		return TranslationHelper.tr_format("skill.effect.add_starting_gold", {"value": value})  
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_MAX_ENERGY:
		return TranslationHelper.tr_format("skill.effect.add_max_energy", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.GRANT_REVIVE:
		return tr("skill.effect.grant_revive") if value > 0 else ""
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_CARD_DAMAGE:
		return TranslationHelper.tr_format("skill.effect.add_card_damage", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_HOLY_DAMAGE:
		return TranslationHelper.tr_format("skill.effect.add_holy_damage", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.ADD_RETAINED_BLOCK:
		return TranslationHelper.tr_format("skill.effect.add_retained_block", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.HEAL_END_OF_TURN:
		return TranslationHelper.tr_format("skill.effect.heal_end_of_turn", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.AURA_ENHANCEMENT:
		return TranslationHelper.tr_format("skill.effect.aura_enhancement", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.THORNS_DAMAGE:
		return TranslationHelper.tr_format("skill.effect.thorns_damage", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.AVATAR_STARTING_BLOCK:
		return TranslationHelper.tr_format("skill.effect.avatar_starting_block", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.ENERGY_ON_KILL:
		return TranslationHelper.tr_format("skill.effect.energy_on_kill", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.DRAW_CARD_FIRST_TURN:
		return TranslationHelper.tr_format("skill.effect.draw_card_first_turn", {"value": value})
	elif effect.effect_type == PassiveEffectData.EffectType.MOVEMENT_BONUS:
		return TranslationHelper.tr_format("skill.effect.movement_bonus", {"value": value})
	else:
		return tr("skill.effect.special")

# Visual effects a styling - VYLEPŠENÉ
func _set_unlocked_state(data: PassiveSkillNode):
	var color = data.get_node_color() if data.has_method("get_node_color") else Color.WHITE
	modulate = color
	_add_visual_effects(data)
	# Přidáme glow efekt pro odemčené uzly
	_add_glow_effect(color)

func _set_can_unlock_state(_data: PassiveSkillNode):
	disabled = false
	modulate = Color("ffd700")  # Zlatá pro dostupné
	_add_glow_effect()

func _set_locked_state(_data: PassiveSkillNode):
	modulate = Color(0.3, 0.3, 0.3)
	_remove_visual_effects()

func _set_starter_state(_data: PassiveSkillNode):
	disabled = false
	modulate = Color("aaddff")  # Světle modrá pro starter
	_add_pulse_effect()

func _add_visual_effects(data: PassiveSkillNode):
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

func _add_glow_effect(glow_color: Color = Color.YELLOW):
	add_theme_color_override("font_outline_color", glow_color)
	add_theme_constant_override("outline_size", 2)

# ✅ OPRAVENO: Vlastní tween místo get_processed_tweens()
var pulse_tween: Tween = null

func _add_pulse_effect():
	# ✅ OPRAVENO: Používáme vlastní tween místo create_tween() bez reference
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 1.0)
	pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 1.0)

func _remove_visual_effects():
	# ✅ OPRAVENO: Používáme vlastní tween místo get_processed_tweens()
	# get_processed_tweens() by zabilo tweens celé hry!
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
	
	scale = Vector2.ONE
	rotation = 0.0
	remove_theme_color_override("font_outline_color")
	remove_theme_constant_override("outline_size")

func _on_skill_pressed():
	if skill_data:
		emit_signal("skill_selected", skill_data)

# Custom kreslení různých tvarů uzlů
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
	# Vylepšené kreslení - přidáme vnitřní výplň
	var fill_color = Color(modulate.r, modulate.g, modulate.b, 0.2)
	draw_circle(center, radius, fill_color)
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
