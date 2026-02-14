class_name Unit
extends Node3D

const FloatingTextScene = preload("res://scenes/ui/FloatingText.tscn")
const IntentIconScene = preload("res://scenes/ui/IntentIcon.tscn")
const INTENT_ICON_AIMING = preload("res://art/icons/status/Aim.png")
const INTENT_ICON_RUSH = preload("res://art/icons/status/Rage_rush.png")
const INTENT_ICON_METEOR1 = preload("res://art/icons/status/Meteor1.png")
const INTENT_ICON_METEOR2 = preload("res://art/icons/status/Meteor2.png")
const INTENT_ICON_METEOR3 = preload("res://art/icons/status/Meteor3.png")
const INTENT_ICON_METEOR4 = preload("res://art/icons/status/Meteor4.png")
const INTENT_ICON_ATTACK = preload("res://art/icons/status/attack.png")
const INTENT_ICON_MOVE = preload("res://art/icons/status/move.png")

const ARCHER_AIM_DAMAGE_MULTIPLIER = 2.5
const BERSERKER_RAGE_TURNS_REQUIRED = 5
const BERSERKER_RUSH_DAMAGE_MULTIPLIER = 3.0
const MAGE_METEOR_TURNS_REQUIRED = 10
const MAGE_METEOR_DAMAGE_MULTIPLIER = 2.0

signal died(unit_node)
signal stats_changed(unit_node)

@export var unit_data: UnitData

var current_health: int = 0
var current_block: int = 0
var retained_block: int = 0

var grid_position: Vector2i
var is_selected: bool = false
var active_statuses: Dictionary = {}

var has_used_base_move: bool = false
var extra_moves: int = 0
var _has_acted_this_turn: bool = false
var last_attacker: Unit = null
var current_intent_id: String = ""
var current_intent_text: String = ""
var _intent_visibility_allowed: bool = false

# Elementární status efekty
var is_frozen: bool = false  # Frozen - nemůže hrát karty ani se hýbat
var movement_penalty: int = 0  # Chilled - snížení pohybu

#---------------------------------------------
#pro enemy AI
var is_aiming: bool = false
var berserker_frustration: int = 0
var is_permanently_enraged: bool = false
#---------------------------------------------

@onready var _sprite_node: Sprite3D = $Sprite3D
var _intent_icon: Node2D = null
var _intent_world_padding_ratio: float = 0.08

func _ready():
	if unit_data:
		unit_data = unit_data.duplicate()

		if unit_data.faction == UnitData.Faction.PLAYER:
			current_health = PlayerData.current_hp
			retained_block = PlayerData.starting_retained_block
			current_block = retained_block + PlayerData.global_shield
			
			add_to_group("player")
			add_to_group("units")
			
		else:
			if PlayerData.loop_level > 0:
				var multiplier = 1.0 + (PlayerData.loop_level * 0.3)  # Změněno z 0.5 na 0.3 pro lepší scaling
				unit_data.max_health = int(unit_data.max_health * multiplier)
				unit_data.attack_damage = int(unit_data.attack_damage * multiplier)

			current_health = unit_data.max_health
			add_to_group("units")
			
	if _sprite_node and unit_data.sprite_texture:
		_sprite_node.texture = unit_data.sprite_texture
	
	if unit_data and unit_data.faction == UnitData.Faction.ENEMY:
		var canvas = get_tree().root.find_child("CanvasLayer", true, false)
		if canvas:
			_intent_icon = IntentIconScene.instantiate()
			canvas.add_child(_intent_icon)
			_intent_icon.visible = false
	
	# Pozice ve 3D - zarovnání na zem
	position.y = 0
	
	await get_tree().process_frame
	emit_signal("stats_changed", self)

func _process(_delta: float) -> void:
	if _intent_icon and _intent_icon.visible:
		_update_intent_icon_screen_position()
		_update_intent_icon_scale()

func set_last_attacker(attacker: Unit):
	last_attacker = attacker

func get_last_attacker() -> Unit:
	if is_instance_valid(last_attacker):
		return last_attacker
	last_attacker = null  # clear stale reference (attacker may have been freed)
	return null

func attack(target: Node, extra_additive: int = 0, damage_type: int = 0, is_holy: bool = false) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"): return
	
	if target.has_method("set_last_attacker"):
		target.set_last_attacker(self)
	
	var base_value = unit_data.attack_damage
	var include_card_bonuses = (unit_data.faction == UnitData.Faction.PLAYER)
	var is_critical = false
	if unit_data.faction == UnitData.Faction.PLAYER:
		var total_crit_chance = PlayerData.get_critical_chance()
		if has_node("/root/ArtifactManager"):
			total_crit_chance += ArtifactManager.get_critical_chance()
		is_critical = total_crit_chance > 0 and randi_range(1, 100) <= total_crit_chance
	
	var damage = DamageCalculator.get_final_damage(
		base_value, self, target, damage_type, is_critical, include_card_bonuses, extra_additive
	)
	if is_critical:
		_show_floating_text(damage, "critical")
		print("💥 KRITICKÝ ZÁSAH! %d poškození" % damage)
	
	await target.take_damage(damage, true)

func take_damage(amount: int, already_calculated: bool = false) -> void:
	if unit_data.ai_script and unit_data.ai_script.resource_path.contains("AssassinAI"):
		var dodge_roll = randi_range(1, 100)
		if dodge_roll <= 35:
			show_status_text("DODGE!", "heal")
			print("💨 Assassin se vyhnul útoku!")
			return
	
	if unit_data.faction == UnitData.Faction.PLAYER and has_node("/root/ArtifactManager"):
		var attacker = get_last_attacker()
		ArtifactManager.on_damage_taken(amount, attacker)

	var damage_to_deal = amount
	if not already_calculated and active_statuses.has("defensive_stance"):
		damage_to_deal = max(1, int(damage_to_deal * 0.5))
		active_statuses.erase("defensive_stance")
		_update_stats_and_emit_signal()
	elif already_calculated and active_statuses.has("defensive_stance") and damage_to_deal > 0:
		active_statuses.erase("defensive_stance")
		_update_stats_and_emit_signal()
	
	var absorbed_by_block = min(damage_to_deal, current_block)
	
	if absorbed_by_block > 0:
		_show_floating_text(absorbed_by_block, "block_loss")

	current_block -= absorbed_by_block
	damage_to_deal -= absorbed_by_block
	
	retained_block = min(retained_block, current_block)
	
	if absorbed_by_block > 0 and damage_to_deal > 0:
		await get_tree().create_timer(0.3).timeout

	if damage_to_deal > 0:
		current_health -= damage_to_deal
		_show_floating_text(damage_to_deal, "damage")
		
		if current_health < 0:
			current_health = 0
		
		if unit_data.faction == UnitData.Faction.PLAYER:
			PlayerData.take_damage(damage_to_deal)
	
	_update_stats_and_emit_signal()
	
	if unit_data.faction == UnitData.Faction.PLAYER and has_node("/root/ArtifactManager"):
		ArtifactManager.check_conditional_artifacts()
	
	if current_health <= 0:
		_die()

func reset_for_new_turn():
	current_block = retained_block
	has_used_base_move = false
	extra_moves = 0
	
	if unit_data.faction == UnitData.Faction.PLAYER and PlayerData.heal_end_of_turn > 0:
		var heal_amount = PlayerData.heal_end_of_turn
		if PlayerData.double_healing_bonus > 0:
			heal_amount = int(float(heal_amount) * (100.0 + float(PlayerData.double_healing_bonus)) / 100.0)
		heal(heal_amount)
	
	_update_stats_and_emit_signal()

func set_aiming(state: bool):
	is_aiming = state
	if is_aiming:
		apply_status("aiming", 250, 999)
		show_status_text("Míří!", "critical")
	else:
		if active_statuses.has("aiming"):
			active_statuses.erase("aiming")
			_update_stats_and_emit_signal()

func can_move() -> bool:
	# Frozen - nemůže se hýbat
	if is_frozen or active_statuses.has("frozen"):
		return false
	return not has_used_base_move or extra_moves > 0

func use_move_action():
	if extra_moves > 0:
		extra_moves -= 1
	elif not has_used_base_move:
		has_used_base_move = true

func gain_extra_move():
	extra_moves += 1

func apply_status(status_id: String, value: int, duration: int = 1):
	if active_statuses.has(status_id):
		active_statuses[status_id].value += value
		# Pro frozen/chilled - aktualizuj movement_penalty
		if status_id == "chilled":
			movement_penalty = active_statuses[status_id].value
			# Pokud má 3+ chilled, stane se frozen
			if movement_penalty >= 3:
				is_frozen = true
				apply_status("frozen", 1, 1)
		if status_id == "frozen":
			is_frozen = true
	else:
		active_statuses[status_id] = { "id": status_id, "value": value, "duration": duration }
		# Pro frozen/chilled - nastav movement_penalty
		if status_id == "chilled":
			movement_penalty = value
			if value >= 3:
				is_frozen = true
				apply_status("frozen", 1, 1)
		if status_id == "frozen":
			is_frozen = true
	_update_stats_and_emit_signal()

func process_turn_start_statuses() -> int:
	var extra_draw = 0
	if active_statuses.is_empty(): return extra_draw
	
	if active_statuses.has("aura_devotion_plus"):
		var status_data = active_statuses["aura_devotion_plus"]
		var aura_value = status_data.value
		if unit_data.faction == UnitData.Faction.PLAYER and PlayerData.aura_enhancement > 0:
			aura_value = aura_value * (100 + PlayerData.aura_enhancement) / 100
		retained_block += aura_value
		add_block(aura_value)
	
	if active_statuses.has("aura_devotion"):
		var status_data = active_statuses["aura_devotion"]
		var aura_value = status_data.value
		if unit_data.faction == UnitData.Faction.PLAYER and PlayerData.aura_enhancement > 0:
			aura_value = aura_value * (100 + PlayerData.aura_enhancement) / 100
		add_block(aura_value)
		
	# Regeneration: heal by value at start of turn
	if active_statuses.has("regeneration"):
		var status_data = active_statuses["regeneration"]
		var heal_amount = status_data.value
		heal(heal_amount)
	
	var statuses_to_remove = []
	for status_id in active_statuses.keys():
		var status_data = active_statuses[status_id]
		match status_id:
			"draw_plus_one":
				extra_draw += status_data.value
				statuses_to_remove.append(status_id)
				
	for status_id in statuses_to_remove:
		active_statuses.erase(status_id)
		
	if not statuses_to_remove.is_empty():
		_update_stats_and_emit_signal()
		
	return extra_draw

func process_turn_end_statuses():
	if active_statuses.is_empty():
		return

	var statuses_to_remove = []
	for status_id in active_statuses.keys():
		if status_id == "aura_devotion" or status_id == "aura_devotion_plus":
			continue
		# Regeneration heals at start of turn (see process_turn_start_statuses), only tick duration here
		
		# Burning - poškození na konci tahu
		if status_id == "burning":
			var status_data = active_statuses[status_id]
			var damage = status_data.value
			take_damage(damage)
			_show_floating_text(damage, "damage")
			# Snížíme hodnotu nebo duration
			status_data.value = max(0, status_data.value - 1)  # Snížíme poškození každé kolo
			if status_data.value <= 0:
				statuses_to_remove.append(status_id)

		active_statuses[status_id].duration -= 1
		if active_statuses[status_id].duration <= 0:
			statuses_to_remove.append(status_id)

	if statuses_to_remove.is_empty():
		return

	for status_id in statuses_to_remove:
		active_statuses.erase(status_id)
		# Reset frozen pokud zmizí chilled/frozen
		if status_id == "frozen" or status_id == "chilled":
			is_frozen = false
			movement_penalty = 0

	_update_stats_and_emit_signal()

func get_current_movement_range() -> int:
	var current_range = unit_data.movement_range
	# Hráč: base_movement_range + PlayerData.movement_bonus (pasivní strom, např. Svatý krok)
	if unit_data.faction == UnitData.Faction.PLAYER and has_node("/root/PlayerData"):
		current_range += PlayerData.movement_bonus
	if unit_data.ai_script and unit_data.ai_script.resource_path.contains("BerserkerAI"):
		current_range = 2
	if active_statuses.has("Slow"):
		current_range += active_statuses["Slow"].value
	
	# Chilled - snížení pohybu
	if active_statuses.has("chilled"):
		var chilled_data = active_statuses["chilled"]
		movement_penalty = chilled_data.value
		current_range = max(0, current_range - movement_penalty)
	
	# Frozen - žádný pohyb
	if is_frozen or active_statuses.has("frozen"):
		current_range = 0
	
	var base_positive = unit_data.movement_range > 0
	var player_bonus_positive = unit_data.faction == UnitData.Faction.PLAYER and has_node("/root/PlayerData") and PlayerData.movement_bonus > 0
	if base_positive or player_bonus_positive:
		return max(0, current_range)
	else:
		return 0

func process_terrain_effects(terrain_data: TerrainData):
	if not terrain_data or terrain_data.effect_type == TerrainData.TerrainEffect.NONE:
		return
	if terrain_data.effect_type == TerrainData.TerrainEffect.APPLY_STATUS_ON_ENTER:
		var status_id = terrain_data.effect_string_value
		var value = terrain_data.effect_numeric_value
		var duration = terrain_data.effect_duration
		if status_id != "":
			apply_status(status_id, value, duration)

func heal_to_full():
	if not is_instance_valid(unit_data):
		return
	var health_before = current_health
	var max_hp_target = unit_data.max_health
	if unit_data.faction == UnitData.Faction.PLAYER and is_instance_valid(PlayerData):
		max_hp_target = PlayerData.max_hp
	current_health = max_hp_target
	var amount_healed = current_health - health_before
	_show_floating_text(amount_healed, "heal")
	
	if unit_data.faction == UnitData.Faction.PLAYER and amount_healed > 0:
		PlayerData.heal(amount_healed)
		
	_update_stats_and_emit_signal()

func _die():
	hide_intent()
	_intent_visibility_allowed = false
	if _intent_icon and is_instance_valid(_intent_icon):
		_intent_icon.queue_free()
	if unit_data.faction == UnitData.Faction.ENEMY:
		if PlayerData.energy_on_kill > 0:
			PlayerData.process_energy_on_kill()
	
	emit_signal("died", self)

func heal(amount: int):
	var enhanced_amount = amount
	if unit_data.faction == UnitData.Faction.PLAYER:
		if has_node("/root/ArtifactManager"):
			enhanced_amount += ArtifactManager.get_heal_bonus()
		enhanced_amount = PlayerData.should_heal_enhanced(enhanced_amount)
	
	var max_health_target = unit_data.max_health
	if unit_data.faction == UnitData.Faction.PLAYER:
		max_health_target = PlayerData.max_hp
	
	var health_to_restore = min(enhanced_amount, max_health_target - current_health)
	current_health += health_to_restore
	_show_floating_text(health_to_restore, "heal")
	
	if unit_data.faction == UnitData.Faction.PLAYER and health_to_restore > 0:
		PlayerData.heal(health_to_restore)
		if has_node("/root/ArtifactManager"):
			ArtifactManager.on_heal(health_to_restore)
		
	_update_stats_and_emit_signal()

func add_block(amount: int):
	var total_block = amount
	if unit_data.faction == UnitData.Faction.PLAYER:
		if has_node("/root/ArtifactManager"):
			total_block += ArtifactManager.get_block_bonus()
		total_block += PlayerData.process_block_on_card_play()
	
	current_block += total_block
	_show_floating_text(total_block, "block_gain")
	
	if unit_data.faction == UnitData.Faction.PLAYER and has_node("/root/ArtifactManager"):
		ArtifactManager.on_block_gained(total_block)
	
	_update_stats_and_emit_signal()

func get_unit_data() -> UnitData: return unit_data

func _update_stats_and_emit_signal(): emit_signal("stats_changed", self)

func set_selected_visual(selected: bool):
	is_selected = selected
	if _sprite_node:
		if selected:
			_sprite_node.modulate = Color(1.5, 1.5, 1.5)
		else:
			_sprite_node.modulate = Color.WHITE

func show_intent(attack_damage: int = 0):
	if not _intent_icon or not _intent_visibility_allowed:
		return
	if _intent_icon.has_method("set_intent"):
		var label_text = str(attack_damage) if attack_damage > 0 else ""
		_intent_icon.set_intent(_get_intent_icon_for_id(current_intent_id), label_text)
	_intent_icon.visible = true
	_update_intent_icon_screen_position()
	_update_intent_icon_scale()

func hide_intent():
	if _intent_icon:
		_intent_icon.visible = false

func set_intent_visibility_allowed(allowed: bool) -> void:
	_intent_visibility_allowed = allowed
	if not allowed:
		hide_intent()

func update_intent(player_unit: Unit, battle_grid: BattleGrid) -> void:
	if not is_instance_valid(unit_data) or unit_data.faction != UnitData.Faction.ENEMY:
		return
	if not is_instance_valid(battle_grid):
		return
	var intent_data = _calculate_intent(player_unit, battle_grid)
	current_intent_id = intent_data.id
	current_intent_text = intent_data.text
	if _intent_icon and _intent_icon.has_method("set_intent"):
		_intent_icon.set_intent(intent_data.icon, intent_data.short_text)
		if _intent_visibility_allowed and intent_data.id != "":
			_intent_icon.show_intent()
		else:
			_intent_icon.hide_intent()

func _update_intent_icon_screen_position() -> void:
	if not _intent_icon:
		return
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var center = global_position + Vector3(0, _get_sprite_world_center_offset_y(), 0)
	var half_height = _get_sprite_world_height() * 0.5
	var world_pos = center + Vector3(0, half_height + (_get_sprite_world_height() * _intent_world_padding_ratio), 0)
	var screen_pos = camera.unproject_position(world_pos)
	if _intent_icon.has_method("set_screen_position"):
		_intent_icon.set_screen_position(screen_pos)
	else:
		_intent_icon.position = screen_pos

func _update_intent_icon_scale() -> void:
	if not _intent_icon:
		return
	if not _intent_icon.has_method("get_icon_texture_size") or not _intent_icon.has_method("set_icon_scale"):
		return
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var sprite_screen_height = _get_sprite_screen_height(camera)
	if sprite_screen_height <= 0:
		return
	var target_icon_height = clamp(sprite_screen_height * 0.25, 18.0, 48.0)
	var icon_size: Vector2 = _intent_icon.get_icon_texture_size()
	if icon_size.y <= 0:
		return
	var scale_value = target_icon_height / icon_size.y
	_intent_icon.set_icon_scale(scale_value)

func _get_sprite_world_height() -> float:
	if not is_instance_valid(_sprite_node) or not is_instance_valid(unit_data) or not unit_data.sprite_texture:
		return 1.0
	var tex_size: Vector2 = unit_data.sprite_texture.get_size()
	var scale_y = _sprite_node.global_transform.basis.get_scale().y
	return tex_size.y * _sprite_node.pixel_size * scale_y

func _get_sprite_world_center_offset_y() -> float:
	if not is_instance_valid(_sprite_node):
		return 0.0
	var scale_y = _sprite_node.global_transform.basis.get_scale().y
	return _sprite_node.offset.y * _sprite_node.pixel_size * scale_y

func _get_sprite_screen_height(camera: Camera3D) -> float:
	var half_height = _get_sprite_world_height() * 0.5
	var center = global_position + Vector3(0, _get_sprite_world_center_offset_y(), 0)
	var world_bottom = center + Vector3(0, -half_height, 0)
	var world_top = center + Vector3(0, half_height, 0)
	var screen_bottom = camera.unproject_position(world_bottom)
	var screen_top = camera.unproject_position(world_top)
	return abs(screen_bottom.y - screen_top.y)

func get_intent_display_text() -> String:
	return current_intent_text

func get_intent_ui() -> Node2D:
	return _intent_icon

func get_enemy_class_display() -> String:
	if not is_instance_valid(unit_data) or not is_instance_valid(unit_data.ai_script):
		return tr("Class: Unknown")
	var class_name_text = _get_ai_class_name(unit_data.ai_script.resource_path)
	return tr("Class: ") + class_name_text

func get_enemy_passives_display() -> String:
	var passives = _get_passives_text()
	return tr("Passives: ") + passives

func get_status_counters_display() -> String:
	var counters: Array[String] = []
	if is_aiming:
		counters.append(tr("Aiming: YES"))
	if berserker_frustration > 0:
		counters.append(tr("Rage: %d/%d turns") % [berserker_frustration, BERSERKER_RAGE_TURNS_REQUIRED])
	if has_meta("mage_turn_count"):
		var turn_count = int(get_meta("mage_turn_count"))
		if turn_count > 0:
			counters.append(tr("Meteor: %d/%d turns") % [turn_count, MAGE_METEOR_TURNS_REQUIRED])
	if counters.is_empty():
		return tr("Status/Counters: None")
	return tr("Status/Counters: ") + ", ".join(counters)

func _calculate_intent(player_unit: Unit, battle_grid: BattleGrid) -> Dictionary:
	var intent_id = "move"
	var intent_short = tr("MOVE")
	var intent_text = tr("Next Move: Move")
	var icon = INTENT_ICON_MOVE
	# Rage status or Berserker permanent rage overrides all other intents – must not revert to move/attack while active
	var ai_path = unit_data.ai_script.resource_path if is_instance_valid(unit_data.ai_script) else ""
	var berserker_rage = ai_path.contains("BerserkerAI") and is_permanently_enraged
	if active_statuses.has("rage") or berserker_rage:
		return {
			"id": "rush",
			"short_text": tr("RUSH"),
			"text": tr("Next Move: Rush (300% DMG)"),
			"icon": INTENT_ICON_RUSH
		}
	
	if ai_path.contains("ArcherAI") and is_aiming:
		intent_id = "aiming"
		intent_short = tr("AIMING")
		intent_text = tr("Next Move: Aiming (250% DMG)")
		icon = INTENT_ICON_AIMING
	elif ai_path.contains("BerserkerAI") and _is_aligned_with_player(player_unit) and berserker_frustration >= BERSERKER_RAGE_TURNS_REQUIRED:
		intent_id = "rush"
		intent_short = tr("RUSH")
		intent_text = tr("Next Move: Rush (300% DMG)")
		icon = INTENT_ICON_RUSH
	elif ai_path.contains("MageAI"):
		var turn_count = int(get_meta("mage_turn_count")) if has_meta("mage_turn_count") else 0
		if turn_count >= MAGE_METEOR_TURNS_REQUIRED:
			intent_id = "meteor"
			intent_short = tr("METEOR")
			intent_text = tr("Next Move: Meteor (200% DMG)")
			icon = INTENT_ICON_METEOR4
		else:
			var turns_left = MAGE_METEOR_TURNS_REQUIRED - turn_count
			if turns_left >= 8:
				icon = INTENT_ICON_METEOR1
			elif turns_left >= 5:
				icon = INTENT_ICON_METEOR2
			elif turns_left >= 2:
				icon = INTENT_ICON_METEOR3
			elif turns_left >= 1:
				icon = INTENT_ICON_METEOR4
	
	if intent_id == "move":
		if _can_attack_player(player_unit, battle_grid):
			intent_id = "attack"
			intent_short = tr("ATTACK")
			intent_text = tr("Next Move: Attack")
			icon = INTENT_ICON_ATTACK
	
	return {
		"id": intent_id,
		"short_text": intent_short,
		"text": intent_text,
		"icon": icon
	}

func _can_attack_player(player_unit: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(player_unit):
		return false
	var distance = battle_grid.get_distance(grid_position, player_unit.grid_position)
	return distance <= unit_data.attack_range

func _is_aligned_with_player(player_unit: Unit) -> bool:
	if not is_instance_valid(player_unit):
		return false
	return grid_position.x == player_unit.grid_position.x or grid_position.y == player_unit.grid_position.y

func _get_ai_class_name(ai_path: String) -> String:
	if ai_path.contains("AssassinAI"):
		return tr("Assassin")
	if ai_path.contains("BerserkerAI"):
		return tr("Berserker")
	if ai_path.contains("ArcherAI"):
		return tr("Archer")
	if ai_path.contains("MageAI"):
		return tr("Mage")
	if ai_path.contains("HealerAI"):
		return tr("Healer")
	if ai_path.contains("DruidAI"):
		return tr("Druid")
	if ai_path.contains("MonkAI"):
		return tr("Monk")
	if ai_path.contains("FighterAI"):
		return tr("Fighter")
	return tr("Unknown")

func _get_passives_text() -> String:
	var ai_path = unit_data.ai_script.resource_path if is_instance_valid(unit_data.ai_script) else ""
	if ai_path.contains("AssassinAI"):
		return tr("35% Dodge, 25% Double Strike")
	if ai_path.contains("BerserkerAI"):
		return tr("Rage after 5 turns, Rush 300% DMG")
	if ai_path.contains("ArcherAI"):
		return tr("Aim for 250% DMG")
	if ai_path.contains("MageAI"):
		return tr("Meteor after 10 turns")
	if ai_path.contains("HealerAI"):
		return tr("Heals allies")
	if ai_path.contains("DruidAI"):
		return tr("Summons spirits")
	if ai_path.contains("MonkAI"):
		return tr("Blesses allies")
	if ai_path.contains("FighterAI"):
		return tr("Balanced strikes")
	return tr("None")

func _get_intent_icon_for_id(intent_id: String) -> Texture2D:
	match intent_id:
		"aiming": return INTENT_ICON_AIMING
		"rush": return INTENT_ICON_RUSH
		"meteor": return INTENT_ICON_METEOR4
		"attack": return INTENT_ICON_ATTACK
		"move": return INTENT_ICON_MOVE
	return INTENT_ICON_MOVE

func _show_floating_text(amount: int, type: String):
	if amount <= 0:
		return
	var instance = FloatingTextScene.instantiate()
	var text_to_display: String
	var color: Color

	match type:
		"damage":
			text_to_display = "-" + str(amount)
			color = Color.CRIMSON
		"heal":
			text_to_display = "+" + str(amount)
			color = Color.PALE_GREEN
		"block_gain":
			text_to_display = "+" + str(amount)
			color = Color.LIGHT_SKY_BLUE
		"block_loss":
			text_to_display = "-" + str(amount)
			color = Color.SLATE_GRAY
		"critical":
			text_to_display = "CRIT! -" + str(amount)
			color = Color.ORANGE
		"holy_effective":
			text_to_display = "✨ -" + str(amount)
			color = Color.GOLD

	var canvas = get_tree().root.find_child("CanvasLayer", true, false)
	if canvas:
		canvas.add_child(instance)
		var camera = get_viewport().get_camera_3d()
		if camera:
			# Použijeme přímo global_position jednotky (střed buňky na mřížce)
			# a přidáme offset pouze nahoru - žádný horizontální offset
			# global_position jednotky je přesně na středu grid cell
			var world_pos_above_unit = global_position + Vector3(0, 1.5, 0)  # 1.5 metru nad zemí (nad hlavou)
			var screen_pos = camera.unproject_position(world_pos_above_unit)
			
			# Kontrola, jestli je pozice před kamerou (ne za kamerou)
			var camera_forward = -camera.global_transform.basis.z
			var to_unit = (world_pos_above_unit - camera.global_position).normalized()
			var is_in_front = camera_forward.dot(to_unit) > 0
			
			# Kontrola, jestli je pozice viditelná na obrazovce
			var viewport_size = get_viewport().get_visible_rect().size
			var margin = 50  # Povolíme malý okraj mimo obrazovku
			if is_in_front and \
			   screen_pos.x >= -margin and screen_pos.x <= viewport_size.x + margin and \
			   screen_pos.y >= -margin and screen_pos.y <= viewport_size.y + margin:
				# Text je viditelný - použijeme pozici s offsetem nahoru
				# Nastavíme text nejdřív, abychom mohli získat jeho šířku
				instance.text = text_to_display
				# Získáme šířku textu pro zarovnání na střed
				var font = instance.get_theme_font("font")
				var font_size = instance.get_theme_font_size("font_size")
				var text_size = font.get_string_size(text_to_display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				# Odečteme polovinu šířky, aby byl text zarovnaný na střed postavy
				instance.position = screen_pos + Vector2(-text_size.x * 0.5, -40)
			else:
				# Pozice není viditelná - použijeme fallback pozici uprostřed obrazovky
				instance.position = viewport_size * 0.5 + Vector2(0, -100)
		else:
			var viewport_size = get_viewport().get_visible_rect().size
			instance.position = viewport_size * 0.5
			
		instance.start(text_to_display, color)
	else:
		instance.queue_free()

func show_status_text(text_to_show: String, color_type: String):
	var instance = FloatingTextScene.instantiate()
	var color: Color

	match color_type:
		"damage": color = Color.CRIMSON
		"heal": color = Color.PALE_GREEN
		"block_gain": color = Color.LIGHT_SKY_BLUE
		"block_loss": color = Color.SLATE_GRAY
		"critical": color = Color.ORANGE
		"curse": color = Color.PURPLE
		_: color = Color.WHITE

	var canvas = get_tree().root.find_child("CanvasLayer", true, false)
	if canvas:
		canvas.add_child(instance)
		var camera = get_viewport().get_camera_3d()
		if camera:
			# Použijeme přímo global_position jednotky (střed buňky na mřížce)
			# a přidáme offset pouze nahoru - žádný horizontální offset
			# global_position jednotky je přesně na středu grid cell
			var world_pos_above_unit = global_position + Vector3(0, 1.5, 0)  # 1.5 metru nad zemí (nad hlavou)
			var screen_pos = camera.unproject_position(world_pos_above_unit)
			
			# Kontrola, jestli je pozice před kamerou (ne za kamerou)
			var camera_forward = -camera.global_transform.basis.z
			var to_unit = (world_pos_above_unit - camera.global_position).normalized()
			var is_in_front = camera_forward.dot(to_unit) > 0
			
			# Kontrola, jestli je pozice viditelná na obrazovce
			var viewport_size = get_viewport().get_visible_rect().size
			var margin = 50  # Povolíme malý okraj mimo obrazovku
			if is_in_front and \
			   screen_pos.x >= -margin and screen_pos.x <= viewport_size.x + margin and \
			   screen_pos.y >= -margin and screen_pos.y <= viewport_size.y + margin:
				# Text je viditelný - použijeme pozici s offsetem nahoru
				# Nastavíme text nejdřív, abychom mohli získat jeho šířku
				instance.text = text_to_show
				# Získáme šířku textu pro zarovnání na střed
				var font = instance.get_theme_font("font")
				var font_size = instance.get_theme_font_size("font_size")
				var text_size = font.get_string_size(text_to_show, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				# Odečteme polovinu šířky, aby byl text zarovnaný na střed postavy
				instance.position = screen_pos + Vector2(-text_size.x * 0.5, -40)
			else:
				# Pozice není viditelná - použijeme fallback pozici uprostřed obrazovky
				instance.position = viewport_size * 0.5 + Vector2(0, -100)
		else:
			var viewport_size = get_viewport().get_visible_rect().size
			instance.position = viewport_size * 0.5

		instance.start(text_to_show, color)
	else:
		instance.queue_free()

func start_turn() -> int:
	print(TranslationHelper.tr_format("log.unit.turn_start", {"name": unit_data.get_localized_name()}))
	_has_acted_this_turn = false
	reset_for_new_turn()
	var extra_draw = process_turn_start_statuses()
	return extra_draw

func end_turn():
	print(TranslationHelper.tr_format("log.unit.turn_end", {"name": unit_data.get_localized_name()}))
	process_turn_end_statuses()

func can_act() -> bool:
	return not _has_acted_this_turn

func use_action():
	_has_acted_this_turn = true
	print(TranslationHelper.tr_format("log.unit.used_action", {"name": unit_data.get_localized_name()}))
