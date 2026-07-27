class_name Unit
extends Node3D

const FloatingTextScene = preload("res://scenes/ui/FloatingText.tscn")
const IntentIconScene = preload("res://scenes/ui/IntentIcon.tscn")
const UnitHealthBarScene = preload("res://scenes/ui/UnitHealthBar.tscn")
const INTENT_ICON_AIMING = preload("res://art/icons/status/Aim.png")
const INTENT_ICON_RUSH = preload("res://art/icons/status/Rage_rush.png")
const INTENT_ICON_METEOR1 = preload("res://art/icons/status/Meteor1.png")
const INTENT_ICON_METEOR2 = preload("res://art/icons/status/Meteor2.png")
const INTENT_ICON_METEOR3 = preload("res://art/icons/status/Meteor3.png")
const INTENT_ICON_METEOR4 = preload("res://art/icons/status/Meteor4.png")
const INTENT_ICON_ATTACK = preload("res://art/icons/status/attack.png")
const INTENT_ICON_MOVE = preload("res://art/icons/status/move.png")

const ARCHER_AIM_DAMAGE_MULTIPLIER = 2.5
const ARCHER_AIM_DAMAGE_PERCENT = int(ARCHER_AIM_DAMAGE_MULTIPLIER * 100) # 250%
const BERSERKER_RAGE_TURNS_REQUIRED = 3
const BERSERKER_RUSH_DAMAGE_MULTIPLIER = 1.8 # matches BerserkerAI.RUSH_DAMAGE_MULTIPLIER
const BERSERKER_RUSH_DAMAGE_PERCENT = int(BERSERKER_RUSH_DAMAGE_MULTIPLIER * 100) # 180%
const MAGE_METEOR_TURNS_REQUIRED = 6
const MAGE_METEOR_DAMAGE_MULTIPLIER = 2.0
const MAGE_METEOR_DAMAGE_PERCENT = int(MAGE_METEOR_DAMAGE_MULTIPLIER * 100) # 200%
const INITIATIVE_HOVER_MODULATE := Color(2.25, 1.9, 0.35, 1.0)
const SELECTED_MODULATE := Color(1.5, 1.5, 1.5)
const INITIATIVE_HOVER_SCALE := 1.12

signal died(unit_node)
signal stats_changed(unit_node)

@export var unit_data: UnitData

var current_health: int = 0
var current_block: int = 0
var retained_block: int = 0

var grid_position: Vector2i
var is_selected: bool = false
var _initiative_bar_hovered: bool = false
var _pre_initiative_hover_modulate: Color = Color.WHITE
var _initiative_hover_tween: Tween = null
var _initiative_hover_base_scale: Vector3 = Vector3.ONE
var active_statuses: Dictionary = {}

var has_used_base_move: bool = false
var extra_moves: int = 0
var _has_acted_this_turn: bool = false
var last_attacker: Unit = null
var current_intent_id: String = ""
var current_intent_text: String = ""
var current_intent_short: String = ""
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
var _health_bar: Control = null
var _intent_world_padding_ratio: float = 0.08

func _is_local_player() -> bool:
	"""Vrátí true jen pokud je tato jednotka LOKÁLNÍHO hráče (ne coop spoluhráče).
	V solo režimu vždy true pro player faction. V coop porovnává owner_peer_id."""
	if unit_data.faction != UnitData.Faction.PLAYER:
		return false
	if not has_meta("owner_peer_id"):
		return true  # Solo režim – není nastaveno, takže jsme to my
	return get_meta("owner_peer_id") == multiplayer.get_unique_id()

func _ready():
	if unit_data:
		unit_data = unit_data.duplicate()

		if unit_data.faction == UnitData.Faction.PLAYER:
			# V coop režimu: jen lokální hráč čte z PlayerData.
			# Spoluhráčova jednotka dostane HP přes snapshot od hosta.
			if _is_local_player():
				current_health = PlayerData.current_hp
				retained_block = PlayerData.starting_retained_block
				current_block = retained_block + PlayerData.global_shield
			else:
				# Spoluhráč – nastavíme max HP ze skill tree (stejná třída),
				# skutečné HP přijde ze snapshotu.
				current_health = PlayerData.max_hp
				retained_block = 0
				current_block = 0
			
			add_to_group("player")
			add_to_group("units")
			
		else:
			if PlayerData.loop_level > 0:
				_apply_ng_plus_scaling()

			current_health = unit_data.max_health
			add_to_group("units")
			
	if _sprite_node and unit_data.sprite_texture:
		_sprite_node.texture = unit_data.sprite_texture
		var display_scale = maxf(0.1, unit_data.sprite_display_scale)
		_sprite_node.scale = Vector3(display_scale, display_scale, display_scale)
		_initiative_hover_base_scale = _sprite_node.scale
		# Offset zůstává v pixelech (node scale ho stejně zmenší ve world space).
		_sprite_node.offset = Vector2(0, unit_data.sprite_offset_y)
	
	var canvas = get_tree().root.find_child("CanvasLayer", true, false)
	if canvas:
		_health_bar = UnitHealthBarScene.instantiate()
		canvas.add_child(_health_bar)
		_refresh_health_bar()
		if unit_data and unit_data.faction == UnitData.Faction.ENEMY:
			_intent_icon = IntentIconScene.instantiate()
			canvas.add_child(_intent_icon)
			_intent_icon.visible = false
	
	# Pozice ve 3D - zarovnání na zem
	position.y = 0
	
	await get_tree().process_frame
	_refresh_health_bar()
	emit_signal("stats_changed", self)

func _exit_tree() -> void:
	if _initiative_bar_hovered:
		set_initiative_hover_visual(false)
	if _intent_icon and is_instance_valid(_intent_icon):
		_intent_icon.queue_free()
		_intent_icon = null
	if _health_bar and is_instance_valid(_health_bar):
		_health_bar.queue_free()
		_health_bar = null

func _apply_ng_plus_scaling():
	"""Aplikuje NG+ scaling na enemy jednotky - nejen čísla, ale i mechaniky."""
	var loop = PlayerData.loop_level
	var stat_multiplier = 1.0 + (loop * 0.3)
	
	# Základní stat scaling (HP, damage)
	unit_data.max_health = int(unit_data.max_health * stat_multiplier)
	unit_data.attack_damage = int(unit_data.attack_damage * stat_multiplier)
	
	# NG+2+: Nepřátelé začínají s blokem (úměrně loop levelu)
	if loop >= 2:
		var base_block = 2 + (loop - 2) * 2  # NG+2: 2, NG+3: 4, NG+4: 6...
		current_block = base_block
		retained_block = base_block
	
	# NG+3+: Elitní a Boss nepřátelé získávají bonus pohyb
	if loop >= 3:
		if unit_data.max_health >= 80:  # Elite/Boss threshold (po scalingu)
			unit_data.movement_range = min(unit_data.movement_range + 1, 6)
	
	# NG+4+: Všichni nepřátelé začínají s lehkým bufem
	if loop >= 4:
		# Rage-like status pro extra agresivitu (nepřidáváme přímo status,
		# ale zvýšíme útok o dalších 10% za každý loop nad 3)
		var extra_loop_bonus = (loop - 3) * 0.1
		unit_data.attack_damage = int(unit_data.attack_damage * (1.0 + extra_loop_bonus))

func _process(_delta: float) -> void:
	if _health_bar and is_instance_valid(_health_bar):
		_update_health_bar_screen_position()
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
	var include_card_bonuses = _is_local_player()
	var is_critical = false
	# Crit šance jen pro lokálního hráče (spoluhráčovy útoky řeší jeho klient)
	if _is_local_player():
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

## Returns false if the hit was dodged (no HP/block change). Dodge only applies to attack hits
## (allow_dodge=true); DoT / terrain / forced damage should pass allow_dodge=false.
func take_damage(amount: int, already_calculated: bool = false, is_rpc_sync: bool = false, allow_dodge: bool = true) -> bool:
	# Dodge: Assassin má 35% šanci na dodge útoku (ne DoT/pastí).
	# Přeskočit při RPC sync (výsledek už byl rozhodnut na odesílající straně).
	if allow_dodge and not is_rpc_sync and unit_data.ai_script and unit_data.ai_script.resource_path.contains("AssassinAI"):
		var dodge_roll = randi_range(1, 100)
		if dodge_roll <= 35:
			show_status_text("DODGE!", "heal")
			if has_node("/root/DebugLogger"):
				DebugLogger.log_info("💨 Assassin se vyhnul útoku! (poškození přeskočeno, ostatní efekty karty stále platí)")
			else:
				print("💨 Assassin se vyhnul útoku!")
			return false
	
	# Artefakty on_damage_taken jen pro LOKÁLNÍHO hráče (ne spoluhráče)
	if _is_local_player() and has_node("/root/ArtifactManager"):
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
		
		# PlayerData.take_damage jen pro LOKÁLNÍHO hráče
		if _is_local_player():
			PlayerData.take_damage(damage_to_deal)
	
	_update_stats_and_emit_signal()
	
	# Conditional artefakty jen pro LOKÁLNÍHO hráče
	if _is_local_player() and has_node("/root/ArtifactManager"):
		ArtifactManager.check_conditional_artifacts()
	
	if current_health <= 0:
		_die()
	return true
func reset_for_new_turn():
	current_block = retained_block
	has_used_base_move = false
	extra_moves = 0
	
	# Heal per turn jen pro lokálního hráče
	if _is_local_player() and PlayerData.heal_end_of_turn > 0:
		var heal_amount = PlayerData.heal_end_of_turn
		if PlayerData.double_healing_bonus > 0:
			heal_amount = int(float(heal_amount) * (100.0 + float(PlayerData.double_healing_bonus)) / 100.0)
		heal(heal_amount)
	
	_update_stats_and_emit_signal()

func set_aiming(state: bool):
	is_aiming = state
	if is_aiming:
		apply_status("aiming", ARCHER_AIM_DAMAGE_PERCENT, 999)
	else:
		if active_statuses.has("aiming"):
			active_statuses.erase("aiming")
			_update_stats_and_emit_signal()

func can_move() -> bool:
	# Frozen - nemůže se hýbat
	if is_frozen or active_statuses.has("frozen"):
		return false
	# Entangled - kořeny drží na místě
	if active_statuses.has("entangled"):
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
		# Keep the longer remaining duration (poison etc. must not wipe early on re-apply).
		active_statuses[status_id].duration = maxi(int(active_statuses[status_id].duration), duration)
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
	if has_node("/root/DebugLogger"):
		var unit_label = unit_data.unit_id if unit_data else name
		DebugLogger.log_info("Status '%s' applied to %s (value=%d, duration=%d)" % [status_id, unit_label, value, duration])
	_update_stats_and_emit_signal()

func process_turn_start_statuses() -> int:
	var extra_draw = 0
	if active_statuses.is_empty(): return extra_draw
	
	if active_statuses.has("aura_devotion_plus"):
		var status_data = active_statuses["aura_devotion_plus"]
		var aura_value = status_data.value
		if _is_local_player() and PlayerData.aura_enhancement > 0:
			aura_value = aura_value * (100 + PlayerData.aura_enhancement) / 100
		retained_block += aura_value
		add_block(aura_value)
	
	if active_statuses.has("aura_devotion"):
		var status_data = active_statuses["aura_devotion"]
		var aura_value = status_data.value
		if _is_local_player() and PlayerData.aura_enhancement > 0:
			aura_value = aura_value * (100 + PlayerData.aura_enhancement) / 100
		add_block(aura_value)
		
	# Regeneration: heal by value at start of turn
	if active_statuses.has("regeneration"):
		var status_data = active_statuses["regeneration"]
		var heal_amount = status_data.value
		heal(heal_amount)

	# Poison: damage at START of turn (visible before they act), then duration -= 1
	if active_statuses.has("poison"):
		await _tick_poison_status()
	if not is_instance_valid(self) or current_health <= 0:
		return extra_draw
	
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

func _tick_poison_status() -> void:
	if not active_statuses.has("poison"):
		return
	var poison_data: Dictionary = active_statuses["poison"]
	var poison_dmg: int = int(poison_data.get("value", 0))
	if has_node("/root/PlayerData") and unit_data and unit_data.faction == UnitData.Faction.ENEMY:
		poison_dmg += PlayerData.poison_damage_bonus
	if poison_dmg > 0:
		await take_damage(poison_dmg, true, false, false)
		if not is_instance_valid(self):
			return
		show_status_text("POISON -%d" % poison_dmg, "critical")
	if not active_statuses.has("poison"):
		return
	var remaining: int = int(active_statuses["poison"].get("duration", 1)) - 1
	if remaining <= 0:
		active_statuses.erase("poison")
		if has_node("/root/DebugLogger"):
			var unit_label = unit_data.unit_id if unit_data else name
			DebugLogger.log_info("Poison expired on %s" % unit_label)
	else:
		active_statuses["poison"].duration = remaining
		if has_node("/root/DebugLogger"):
			var unit_label = unit_data.unit_id if unit_data else name
			DebugLogger.log_info("Poison on %s: %d dmg, %d turns left" % [unit_label, poison_dmg, remaining])
	_update_stats_and_emit_signal()

func process_turn_end_statuses():
	if active_statuses.is_empty():
		return

	var statuses_to_remove = []
	for status_id in active_statuses.keys():
		if status_id == "aura_devotion" or status_id == "aura_devotion_plus":
			continue
		# Poison ticks at start of turn — skip here so duration isn't double-decremented
		if status_id == "poison":
			continue
		# Regeneration heals at start of turn (see process_turn_start_statuses), only tick duration here
		
		# Burning - poškození na konci tahu (DoT nelze vyhnout)
		if status_id == "burning":
			var status_data = active_statuses[status_id]
			var damage = status_data.value
			take_damage(damage, false, false, false)
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
	if _is_local_player() and has_node("/root/PlayerData"):
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
	
	# Entangled - žádný pohyb (Druid kořeny)
	if active_statuses.has("entangled"):
		current_range = 0
	
	# Frozen - žádný pohyb
	if is_frozen or active_statuses.has("frozen"):
		current_range = 0
	
	var base_positive = unit_data.movement_range > 0
	var player_bonus_positive = _is_local_player() and has_node("/root/PlayerData") and PlayerData.movement_bonus > 0
	if base_positive or player_bonus_positive:
		return max(0, current_range)
	else:
		return 0

## Applies ON_ENTER terrain. Returns damage dealt (0 for status-only / none).
## Trap/terrain damage cannot be dodged.
func process_terrain_effects(terrain_data: TerrainData) -> int:
	if not terrain_data or terrain_data.effect_type == TerrainData.TerrainEffect.NONE:
		return 0
	if terrain_data.effect_type == TerrainData.TerrainEffect.APPLY_STATUS_ON_ENTER:
		var status_id = terrain_data.effect_string_value
		var value = terrain_data.effect_numeric_value
		var duration = terrain_data.effect_duration
		if status_id != "":
			apply_status(status_id, value, duration)
		return 0
	elif terrain_data.effect_type == TerrainData.TerrainEffect.DAMAGE_ON_ENTER:
		var dmg = terrain_data.effect_numeric_value
		if dmg > 0:
			# already_calculated + allow_dodge=false: pasti vždy zraní (i Assassin)
			# await: ať volající nepokračuje v cestě dřív, než se aplikuje HP / smrt
			await take_damage(dmg, true, false, false)
			return dmg
	return 0

func heal_to_full():
	if not is_instance_valid(unit_data):
		return
	var health_before = current_health
	var max_hp_target = unit_data.max_health
	if _is_local_player() and is_instance_valid(PlayerData):
		max_hp_target = PlayerData.max_hp
	current_health = max_hp_target
	var amount_healed = current_health - health_before
	_show_floating_text(amount_healed, "heal")
	
	if _is_local_player() and amount_healed > 0:
		PlayerData.heal(amount_healed)
		
	_update_stats_and_emit_signal()

func _die():
	hide_intent()
	_intent_visibility_allowed = false
	if _intent_icon and is_instance_valid(_intent_icon):
		_intent_icon.queue_free()
		_intent_icon = null
	if _health_bar and is_instance_valid(_health_bar):
		_health_bar.queue_free()
		_health_bar = null
	# energy_on_kill zůstává pro enemy faction - oba hráči to vidí stejně
	if unit_data.faction == UnitData.Faction.ENEMY:
		if PlayerData.energy_on_kill > 0:
			PlayerData.process_energy_on_kill()
	
	emit_signal("died", self)

func heal(amount: int):
	var enhanced_amount = amount
	# Heal bonusy jen pro lokálního hráče
	if _is_local_player():
		if has_node("/root/ArtifactManager"):
			enhanced_amount += ArtifactManager.get_heal_bonus()
		enhanced_amount = PlayerData.should_heal_enhanced(enhanced_amount)
	
	var max_health_target = unit_data.max_health
	if _is_local_player():
		max_health_target = PlayerData.max_hp
	
	var health_to_restore = min(enhanced_amount, max_health_target - current_health)
	current_health += health_to_restore
	_show_floating_text(health_to_restore, "heal")
	
	# PlayerData.heal a artifact trigger jen pro lokálního hráče
	if _is_local_player() and health_to_restore > 0:
		PlayerData.heal(health_to_restore)
		if has_node("/root/ArtifactManager"):
			ArtifactManager.on_heal(health_to_restore)
		
	_update_stats_and_emit_signal()

func add_block(amount: int):
	var total_block = amount
	# Artifact a PlayerData block bonusy jen pro lokálního hráče
	if _is_local_player():
		if has_node("/root/ArtifactManager"):
			total_block += ArtifactManager.get_block_bonus()
		total_block += PlayerData.process_block_on_card_play()
	
	current_block += total_block
	_show_floating_text(total_block, "block_gain")
	
	if _is_local_player() and has_node("/root/ArtifactManager"):
		ArtifactManager.on_block_gained(total_block)
	
	_update_stats_and_emit_signal()

func get_unit_data() -> UnitData: return unit_data

func _update_stats_and_emit_signal():
	_refresh_health_bar()
	emit_signal("stats_changed", self)

func _refresh_health_bar() -> void:
	if not _health_bar or not is_instance_valid(_health_bar):
		return
	if not _health_bar.has_method("update_values"):
		return
	var max_hp = unit_data.max_health if is_instance_valid(unit_data) else 1
	if unit_data and unit_data.faction == UnitData.Faction.PLAYER and _is_local_player():
		max_hp = PlayerData.max_hp
	_health_bar.update_values(current_health, max_hp, current_block)

func _update_health_bar_screen_position() -> void:
	if not _health_bar or not is_instance_valid(_health_bar):
		return
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var half_height = _get_sprite_world_height() * 0.5
	var center = global_position + Vector3(0, _get_sprite_world_center_offset_y(), 0)
	var world_pos = center + Vector3(0, -half_height - 0.15, 0)
	var screen_pos = camera.unproject_position(world_pos)
	if _health_bar.has_method("set_screen_position"):
		_health_bar.set_screen_position(screen_pos)
	else:
		_health_bar.global_position = screen_pos

func set_selected_visual(selected: bool):
	is_selected = selected
	if not _sprite_node:
		return
	if _initiative_bar_hovered:
		_pre_initiative_hover_modulate = SELECTED_MODULATE if selected else Color.WHITE
		_apply_initiative_hover_sprite()
		return
	if selected:
		_sprite_node.modulate = SELECTED_MODULATE
	else:
		_sprite_node.modulate = Color.WHITE


func _get_battle_grid() -> BattleGrid:
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if battle_scene and battle_scene.get("battle_grid_instance"):
		return battle_scene.battle_grid_instance
	return null


func _apply_initiative_hover_sprite() -> void:
	if not _sprite_node:
		return
	_sprite_node.modulate = INITIATIVE_HOVER_MODULATE
	_start_initiative_hover_pulse()


func _start_initiative_hover_pulse() -> void:
	if not _sprite_node:
		return
	_stop_initiative_hover_pulse()
	var target_scale = _initiative_hover_base_scale * INITIATIVE_HOVER_SCALE
	_initiative_hover_tween = create_tween().set_loops()
	_initiative_hover_tween.tween_property(_sprite_node, "scale", target_scale, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_initiative_hover_tween.tween_property(_sprite_node, "scale", _initiative_hover_base_scale, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_initiative_hover_pulse() -> void:
	if _initiative_hover_tween and _initiative_hover_tween.is_valid():
		_initiative_hover_tween.kill()
	_initiative_hover_tween = null
	if _sprite_node:
		_sprite_node.scale = _initiative_hover_base_scale


func set_initiative_hover_visual(hovered: bool) -> void:
	"""Zvýrazní jednotku při hoveru slotu v initiative baru (HoMM3-styl)."""
	if not _sprite_node:
		return
	var battle_grid = _get_battle_grid()
	if hovered:
		if not _initiative_bar_hovered:
			_pre_initiative_hover_modulate = _sprite_node.modulate
			_initiative_hover_base_scale = _sprite_node.scale
			_initiative_bar_hovered = true
		_apply_initiative_hover_sprite()
		if battle_grid:
			battle_grid.show_initiative_hover_cell(grid_position)
	elif _initiative_bar_hovered:
		_stop_initiative_hover_pulse()
		_sprite_node.modulate = _pre_initiative_hover_modulate
		_initiative_bar_hovered = false
		if is_selected:
			_sprite_node.modulate = SELECTED_MODULATE
		if battle_grid:
			battle_grid.hide_initiative_hover_cell(grid_position)

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
	current_intent_short = intent_data.get("short_text", "")
	if _intent_icon and _intent_icon.has_method("set_intent"):
		_intent_icon.set_intent(intent_data.icon, intent_data.short_text)
		# Odpočet kol na ikoně
		var countdown = intent_data.get("countdown", 0)
		if _intent_icon.has_method("set_countdown"):
			_intent_icon.set_countdown(countdown)
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

func get_intent_short_text() -> String:
	return current_intent_short

func get_intent_detail_text() -> String:
	"""Krátký popis intentu bez prefixu 'Next Move:' (pro info panel)."""
	var text := current_intent_text.strip_edges()
	if text.is_empty():
		return ""
	var prefixes := [
		"Next Move: ", "Next Spell: ",
		tr("Next Move: "), tr("Next Spell: "),
		"Úmysl: ", "Další tah: ",
	]
	for prefix in prefixes:
		if prefix != "" and text.begins_with(prefix):
			return text.substr(prefix.length()).strip_edges()
	return text

func get_intent_ui() -> Node2D:
	return _intent_icon

func get_enemy_class_display() -> String:
	if not is_instance_valid(unit_data) or not is_instance_valid(unit_data.ai_script):
		return tr("Class: Unknown")
	var class_name_text = _get_ai_class_name(unit_data.ai_script.resource_path)
	return tr("Class: ") + class_name_text

func get_enemy_class_name_only() -> String:
	if not is_instance_valid(unit_data) or not is_instance_valid(unit_data.ai_script):
		return tr("Unknown")
	return _get_ai_class_name(unit_data.ai_script.resource_path)

func get_enemy_passives_display() -> String:
	var passives = _get_passives_text()
	return tr("enemy.label.passives") + passives

func get_enemy_passives_list() -> PackedStringArray:
	"""Kompaktní seznam pasiv (split podle čárky) pro chip UI."""
	var raw := _get_passives_text().strip_edges()
	var none_text := tr("enemy.passive.none")
	if raw.is_empty() or raw == none_text or raw == "None" or raw == "Žádné":
		return PackedStringArray()
	var parts := PackedStringArray()
	for part in raw.split(",", false):
		var cleaned := str(part).strip_edges()
		if not cleaned.is_empty():
			parts.append(cleaned)
	return parts

func get_status_counters_display() -> String:
	var counters := get_status_counters_list()
	if counters.is_empty():
		return tr("enemy.label.counters_none")
	return tr("enemy.label.counters") + ", ".join(counters)

func get_status_counters_list() -> PackedStringArray:
	var counters: PackedStringArray = []
	var ai_path = unit_data.ai_script.resource_path if is_instance_valid(unit_data) and is_instance_valid(unit_data.ai_script) else ""
	
	if is_aiming:
		counters.append(TranslationHelper.tr_format("enemy.counter.aiming", {"value": ARCHER_AIM_DAMAGE_PERCENT}))
	if berserker_frustration > 0:
		counters.append(TranslationHelper.tr_format("enemy.counter.rage", {"current": berserker_frustration, "max": BERSERKER_RAGE_TURNS_REQUIRED}))
	if is_permanently_enraged:
		counters.append(tr("enemy.counter.enraged"))
	if has_meta("mage_turn_count"):
		var turn_count = int(get_meta("mage_turn_count"))
		if turn_count > 0:
			counters.append(TranslationHelper.tr_format("enemy.counter.meteor", {"current": turn_count, "max": MAGE_METEOR_TURNS_REQUIRED}))
	if has_meta("spell_index"):
		var spell_names = [tr("enemy.spell.fire"), tr("enemy.spell.ice"), tr("enemy.spell.lightning"), tr("enemy.spell.shield")]
		var idx = int(get_meta("spell_index")) % 4
		counters.append(TranslationHelper.tr_format("enemy.counter.next_spell", {"spell": spell_names[idx]}))
	if has_meta("boss_phase"):
		var phase = int(get_meta("boss_phase"))
		counters.append(TranslationHelper.tr_format("enemy.counter.phase", {"value": phase}))
	if has_meta("boss_turn_count") and ai_path.contains("BossAI"):
		var btc = int(get_meta("boss_turn_count"))
		if has_meta("boss_phase") and int(get_meta("boss_phase")) == 1:
			var next_slash = 3 - (btc % 3)
			counters.append(TranslationHelper.tr_format("enemy.counter.dark_slash", {"value": next_slash}))
		else:
			var next_hellfire = 4 - (btc % 4)
			counters.append(TranslationHelper.tr_format("enemy.counter.hellfire", {"value": next_hellfire}))
	if has_meta("entangle_cooldown"):
		var cd = int(get_meta("entangle_cooldown"))
		if cd > 0:
			counters.append(TranslationHelper.tr_format("enemy.counter.entangle_cd", {"value": cd}))
	if has_meta("war_cry_cooldown"):
		var cd = int(get_meta("war_cry_cooldown"))
		if cd > 0:
			counters.append(TranslationHelper.tr_format("enemy.counter.war_cry_cd", {"value": cd}))
	if has_meta("has_howled") and get_meta("has_howled"):
		counters.append(tr("enemy.counter.howled"))
	return counters

func _calculate_intent(player_unit: Unit, battle_grid: BattleGrid) -> Dictionary:
	var intent_id = "move"
	var intent_short = tr("MOVE")
	var intent_text = tr("Next Move: Move")
	var icon = INTENT_ICON_MOVE
	var countdown = 0  # Odpočet kol (0 = nezobrazovat)
	var ai_path = unit_data.ai_script.resource_path if is_instance_valid(unit_data.ai_script) else ""
	
	# === BERSERKER RAGE ===
	var berserker_rage = ai_path.contains("BerserkerAI") and is_permanently_enraged
	if active_statuses.has("rage") or berserker_rage:
		return {
			"id": "rush", "short_text": tr("RUSH"),
			"text": tr("Next Move: Rush (%d%% DMG)") % BERSERKER_RUSH_DAMAGE_PERCENT,
			"icon": INTENT_ICON_RUSH, "countdown": 0
		}
	
	# === BOSS AI ===
	if ai_path.contains("BossAI"):
		var boss_phase = int(get_meta("boss_phase")) if has_meta("boss_phase") else 1
		var btc = int(get_meta("boss_turn_count")) if has_meta("boss_turn_count") else 0
		
		if boss_phase == 2:
			var next_hellfire = 4 - ((btc) % 4)
			if next_hellfire == 4:
				next_hellfire = 0  # Nastane tento tah
			if btc > 0 and (btc + 1) % 4 == 0:
				return {"id": "attack", "short_text": tr("HELLFIRE"), "text": tr("Next Move: Hellfire AoE"), "icon": INTENT_ICON_ATTACK, "countdown": 0}
			else:
				return {"id": "attack", "short_text": tr("ENRAGED"), "text": tr("Next Move: Enraged Attack"), "icon": INTENT_ICON_RUSH, "countdown": next_hellfire}
		else:
			var next_slash = 3 - ((btc) % 3)
			if next_slash == 3:
				next_slash = 0
			if btc > 0 and (btc + 1) % 3 == 0:
				return {"id": "attack", "short_text": tr("SLASH"), "text": tr("Next Move: Dark Slash"), "icon": INTENT_ICON_ATTACK, "countdown": 0}
			else:
				# Ukaž odpočet do dark slash
				countdown = next_slash
	
	# === DARK BEAST AI ===
	if ai_path.contains("DarkBeastAI"):
		var health_pct = float(current_health) / float(unit_data.max_health) if unit_data.max_health > 0 else 1.0
		if health_pct <= 0.3 and has_meta("has_howled") and not get_meta("has_howled"):
			return {"id": "attack", "short_text": tr("HOWL"), "text": tr("Next Move: Howl (buff allies)"), "icon": INTENT_ICON_RUSH, "countdown": 0}
		var dist = battle_grid.get_distance(grid_position, player_unit.grid_position) if is_instance_valid(player_unit) else 0
		if dist >= 3:
			return {"id": "attack", "short_text": tr("POUNCE"), "text": tr("Next Move: Pounce (+50% DMG)"), "icon": INTENT_ICON_ATTACK, "countdown": 0}
	
	# === ARCHER AIMING ===
	if ai_path.contains("ArcherAI") and is_aiming:
		intent_id = "aiming"
		intent_short = tr("AIMING")
		intent_text = tr("Next Move: Aimed Shot (%d%% DMG)") % ARCHER_AIM_DAMAGE_PERCENT
		icon = INTENT_ICON_AIMING
	# === BERSERKER RUSH / TREMOR ===
	elif ai_path.contains("BerserkerAI"):
		if _is_aligned_with_player(player_unit) and berserker_frustration >= BERSERKER_RAGE_TURNS_REQUIRED:
			intent_id = "rush"
			intent_short = tr("RUSH")
			intent_text = tr("Next Move: Rush (%d%% DMG)") % BERSERKER_RUSH_DAMAGE_PERCENT
			icon = INTENT_ICON_RUSH
		elif berserker_frustration >= 2:
			var dist = battle_grid.get_distance(grid_position, player_unit.grid_position) if is_instance_valid(player_unit) else 0
			if dist <= 4:
				intent_id = "attack"
				intent_short = tr("TREMOR")
				intent_text = tr("Next Move: Tremor AoE")
				icon = INTENT_ICON_ATTACK
		# Odpočet do rage
		if berserker_frustration < BERSERKER_RAGE_TURNS_REQUIRED:
			countdown = BERSERKER_RAGE_TURNS_REQUIRED - berserker_frustration
	# === MAGE METEOR COUNTDOWN ===
	elif ai_path.contains("MageAI"):
		var turn_count = int(get_meta("mage_turn_count")) if has_meta("mage_turn_count") else 0
		var turns_left = MAGE_METEOR_TURNS_REQUIRED - turn_count
		
		if turn_count + 1 >= MAGE_METEOR_TURNS_REQUIRED:
			intent_id = "meteor"
			intent_short = tr("METEOR")
			intent_text = tr("Next Move: Meteor (%d%% DMG to ALL)") % MAGE_METEOR_DAMAGE_PERCENT
			icon = INTENT_ICON_METEOR4
		else:
			# Meteor countdown číslo
			countdown = turns_left
			
			if turns_left >= 5:
				icon = INTENT_ICON_METEOR1
			elif turns_left >= 3:
				icon = INTENT_ICON_METEOR2
			elif turns_left >= 2:
				icon = INTENT_ICON_METEOR3
			elif turns_left >= 1:
				icon = INTENT_ICON_METEOR4
			
			# Zobraz jaký spell bude další
			if has_meta("spell_index"):
				var spell_names = ["FIRE", "ICE", "LIGHTNING", "SHIELD"]
				var idx = int(get_meta("spell_index")) % 4
				intent_short = tr(spell_names[idx])
				intent_text = tr("Next Spell: %s (Meteor in %d)") % [spell_names[idx], turns_left]
	# === ASSASSIN ===
	elif ai_path.contains("AssassinAI"):
		var dist = battle_grid.get_distance(grid_position, player_unit.grid_position) if is_instance_valid(player_unit) else 0
		if dist >= 4:
			intent_id = "attack"
			intent_short = tr("SHADOW")
			intent_text = tr("Next Move: Shadow Strike (+50% DMG)")
			icon = INTENT_ICON_ATTACK
	# === HEALER ===
	elif ai_path.contains("HealerAI"):
		var all_units = battle_grid.get_all_objects_on_grid()
		for u in all_units:
			if u is Unit and u != self and is_instance_valid(u):
				if u.unit_data.faction == unit_data.faction:
					var hp_pct = float(u.current_health) / float(u.unit_data.max_health)
					if hp_pct < 0.5:
						intent_id = "heal"
						intent_short = tr("HEAL")
						intent_text = tr("Next Move: Heal Ally")
						icon = INTENT_ICON_MOVE
						break
	# === DRUID ===
	elif ai_path.contains("DruidAI"):
		var entangle_cd = int(get_meta("entangle_cooldown")) if has_meta("entangle_cooldown") else 0
		var dist = battle_grid.get_distance(grid_position, player_unit.grid_position) if is_instance_valid(player_unit) else 0
		if entangle_cd <= 0 and dist <= 3:
			intent_id = "attack"
			intent_short = tr("ENTANGLE")
			intent_text = tr("Next Move: Entangle (root)")
			icon = INTENT_ICON_ATTACK
		elif entangle_cd > 0:
			countdown = entangle_cd  # Odpočet do entangle
	# === MONK ===
	elif ai_path.contains("MonkAI"):
		var wc_cd = int(get_meta("war_cry_cooldown")) if has_meta("war_cry_cooldown") else 0
		if wc_cd <= 0:
			intent_id = "buff"
			intent_short = tr("BUFF")
			intent_text = tr("Next Move: Blessing/War Cry")
			icon = INTENT_ICON_MOVE
		else:
			countdown = wc_cd  # Odpočet do war cry
	
	# Fallback: pokud jsme stále na "move", zkontroluj útok
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
		"icon": icon,
		"countdown": countdown
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
	if ai_path.contains("BossAI"):
		return tr("Demon Boss")
	if ai_path.contains("DarkBeastAI"):
		return tr("Dark Beast")
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
	if ai_path.contains("BossAI"):
		return tr("enemy.passive.boss")
	if ai_path.contains("DarkBeastAI"):
		return tr("enemy.passive.darkbeast")
	if ai_path.contains("AssassinAI"):
		return tr("enemy.passive.assassin")
	if ai_path.contains("BerserkerAI"):
		return tr("enemy.passive.berserker")
	if ai_path.contains("ArcherAI"):
		return tr("enemy.passive.archer")
	if ai_path.contains("MageAI"):
		return tr("enemy.passive.mage")
	if ai_path.contains("HealerAI"):
		return tr("enemy.passive.healer")
	if ai_path.contains("DruidAI"):
		return tr("enemy.passive.druid")
	if ai_path.contains("MonkAI"):
		return tr("enemy.passive.monk")
	if ai_path.contains("FighterAI"):
		return tr("enemy.passive.fighter")
	return tr("enemy.passive.none")

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
			color = Color(1.0, 0.25, 0.25)
		"heal":
			text_to_display = "+" + str(amount)
			color = Color(0.35, 1.0, 0.45)
		"block_gain":
			text_to_display = "+" + str(amount)
			color = Color(0.45, 0.85, 1.0)
		"block_loss":
			text_to_display = "-" + str(amount)
			color = Color(0.7, 0.8, 0.95)
		"critical":
			text_to_display = "CRIT! -" + str(amount)
			color = Color(1.0, 0.7, 0.15)
		"holy_effective":
			text_to_display = "✨ -" + str(amount)
			color = Color(1.0, 0.9, 0.3)

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
		"damage": color = Color(1.0, 0.25, 0.25)
		"heal": color = Color(0.35, 1.0, 0.45)
		"block_gain": color = Color(0.45, 0.85, 1.0)
		"block_loss": color = Color(0.7, 0.8, 0.95)
		"critical": color = Color(1.0, 0.7, 0.15)
		"curse": color = Color(0.85, 0.35, 1.0)
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
	var extra_draw = await process_turn_start_statuses()
	return extra_draw

func end_turn():
	print(TranslationHelper.tr_format("log.unit.turn_end", {"name": unit_data.get_localized_name()}))
	process_turn_end_statuses()

func can_act() -> bool:
	return not _has_acted_this_turn

func use_action():
	_has_acted_this_turn = true
	print(TranslationHelper.tr_format("log.unit.used_action", {"name": unit_data.get_localized_name()}))

# ===== COOP SERIALIZATION =====

func serialize_statuses() -> Array:
	"""Serializuje active_statuses do pole slovníků pro RPC."""
	var result: Array = []
	for status_id in active_statuses:
		var s = active_statuses[status_id]
		result.append({"id": status_id, "value": s.get("value", 0), "duration": s.get("duration", 0)})
	return result

func deserialize_statuses(data: Array):
	"""Přepíše active_statuses z RPC dat."""
	active_statuses.clear()
	for entry in data:
		var sid: String = entry.get("id", "")
		if sid.is_empty():
			continue
		active_statuses[sid] = {"id": sid, "value": int(entry.get("value", 0)), "duration": int(entry.get("duration", 0))}
	# Synchronizuj odvozené flagy
	is_frozen = active_statuses.has("frozen")
	movement_penalty = int(active_statuses["chilled"].value) if active_statuses.has("chilled") else 0
	is_aiming = active_statuses.has("aiming")
	_update_stats_and_emit_signal()

func serialize_intent() -> Dictionary:
	"""Serializuje aktuální intent pro RPC."""
	return {"id": current_intent_id, "text": current_intent_text, "short_text": current_intent_short}

func apply_intent_from_data(data: Dictionary):
	"""Aplikuje intent přijatý od hosta."""
	current_intent_id = data.get("id", "")
	current_intent_text = data.get("text", "")
	current_intent_short = data.get("short_text", "")
	if _intent_icon and _intent_icon.has_method("set_intent"):
		_intent_icon.set_intent(_get_intent_icon_for_id(current_intent_id), current_intent_short)
		if _intent_visibility_allowed and current_intent_id != "":
			_intent_icon.show_intent()
		else:
			_intent_icon.hide_intent()

func serialize_ai_meta() -> Dictionary:
	"""Serializuje AI meta data pro RPC (berserker, mage, boss stav)."""
	var meta: Dictionary = {}
	meta["is_permanently_enraged"] = is_permanently_enraged
	meta["berserker_frustration"] = berserker_frustration
	meta["is_aiming"] = is_aiming
	if has_meta("boss_phase"):
		meta["boss_phase"] = int(get_meta("boss_phase"))
	if has_meta("boss_turn_count"):
		meta["boss_turn_count"] = int(get_meta("boss_turn_count"))
	if has_meta("mage_turn_count"):
		meta["mage_turn_count"] = int(get_meta("mage_turn_count"))
	if has_meta("spell_index"):
		meta["spell_index"] = int(get_meta("spell_index"))
	return meta

func apply_ai_meta(meta: Dictionary):
	"""Aplikuje AI meta data přijatá od hosta."""
	is_permanently_enraged = meta.get("is_permanently_enraged", false)
	berserker_frustration = int(meta.get("berserker_frustration", 0))
	is_aiming = meta.get("is_aiming", false)
	if meta.has("boss_phase"):
		set_meta("boss_phase", int(meta["boss_phase"]))
	if meta.has("boss_turn_count"):
		set_meta("boss_turn_count", int(meta["boss_turn_count"]))
	if meta.has("mage_turn_count"):
		set_meta("mage_turn_count", int(meta["mage_turn_count"]))
	if meta.has("spell_index"):
		set_meta("spell_index", int(meta["spell_index"]))
