class_name Unit
extends Node3D

const FloatingTextScene = preload("res://scenes/ui/FloatingText.tscn")
const IntentIconsRowScene = preload("res://scenes/ui/IntentIconsRow.tscn")
const UnitHealthBarScene = preload("res://scenes/ui/UnitHealthBar.tscn")
const INTENT_ICON_AIMING = preload("res://art/icons/status/Aim.png")
const INTENT_ICON_RUSH = preload("res://art/icons/status/Rage_rush.png")
const INTENT_ICON_METEOR1 = preload("res://art/icons/status/Meteor1.png")
const INTENT_ICON_METEOR2 = preload("res://art/icons/status/Meteor2.png")
const INTENT_ICON_METEOR3 = preload("res://art/icons/status/Meteor3.png")
const INTENT_ICON_METEOR4 = preload("res://art/icons/status/Meteor4.png")
const INTENT_ICON_ATTACK = preload("res://art/icons/status/attack.png")
const INTENT_ICON_MOVE = preload("res://art/icons/status/move.png")
const INTENT_ICON_BLOCK = preload("res://art/icons/status/block.png")
const INTENT_ICON_HEAL = preload("res://art/icons/status/Heal.png")
const INTENT_ICON_HOLY = preload("res://art/icons/status/holy_damage.png")
const FLOAT_ICON_CRIT = preload("res://art/icons/status/Attack_Heavy.png")

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
const HIT_FLASH_HP_COLOR := Color(2.2, 0.45, 0.4)
const HIT_FLASH_BLOCK_COLOR := Color(0.75, 1.2, 2.0)
const HIT_FLASH_DURATION := 0.22
## Statusy, které netikají na konci tahu — drží se, dokud je nespotřebuje trigger (zásah / holy útok).
const UNTIL_CONSUMED_STATUSES := ["defensive_stance", "defensive_stance_turn", "consecrated_weapon", "aiming", "radiance", "radiance_vulnerable"]
## Statusy, které drží celý boj (powery a jejich stacky) — nikdy netikají.
const COMBAT_LONG_STATUSES := ["aura_devotion", "aura_devotion_plus", "block_on_attack", "block_on_attack_carry", "fury_engine", "fury", "holy_edge", "regeneration_permanent"]

signal died(unit_node)
signal stats_changed(unit_node)

@export var unit_data: UnitData

var current_health: int = 0
var current_block: int = 0
var retained_block: int = 0
## Block that survives exactly one turn reset (Fortification), then expires.
var carried_block: int = 0

var grid_position: Vector2i
var is_selected: bool = false
var _initiative_bar_hovered: bool = false
var _pre_initiative_hover_modulate: Color = Color.WHITE
var _initiative_hover_tween: Tween = null
var _hit_flash_tween: Tween = null
var _hit_flash_color: Color = HIT_FLASH_HP_COLOR
## Sprite tint outside of selection / initiative hover (e.g. coop tint), captured when a flash starts.
var _hit_flash_base_modulate: Color = Color.WHITE
var _initiative_hover_base_scale: Vector3 = Vector3.ONE
var active_statuses: Dictionary = {}

var has_used_base_move: bool = false
var extra_moves: int = 0
var _has_acted_this_turn: bool = false
var last_attacker: Unit = null
var current_intent_id: String = ""
var current_intent_text: String = ""
var current_intent_short: String = ""
## Up to 2 player-facing intents: [{id, short_text, text, countdown}]. Primary aliases above = [0].
var current_intents: Array = []
var _intent_visibility_allowed: bool = false

# Elementární status efekty
var is_frozen: bool = false  # Frozen - nemůže hrát karty ani se hýbat
var movement_penalty: int = 0  # Chilled - snížení pohybu

#---------------------------------------------
#pro enemy AI
var is_aiming: bool = false
var berserker_frustration: int = 0
var is_permanently_enraged: bool = false
# Per-enemy telegraphed bonuses (ritual stacks, goblin pack, …).
var ritual_stacks: int = 0
var pack_attack_bonus: int = 0
var _intent_threats: Array = []
var _body_pulse_on: bool = false


func get_bonus_attack_damage() -> int:
	return ritual_stacks + pack_attack_bonus


func get_telegraphed_attack_damage(extra_additive: int = 0) -> int:
	if not is_instance_valid(unit_data):
		return 0
	var dmg := unit_data.attack_damage + extra_additive + get_bonus_attack_damage() + _deep_freeze_bonus_vs_nearest_player()
	# Keep in sync with DamageCalculator weakness (-25% outgoing).
	if active_statuses.has("weakness"):
		dmg = int(dmg * 0.75)
	return maxi(0, dmg)


func _refresh_attack_intent_numbers() -> void:
	"""Přepočítá jen číslo útoku v už zobrazeném záměru (bez nového AI náhledu / rerollu)."""
	# Archer aim telegraphs its own multiplied number (ArcherAI.show_intent) — don't overwrite it.
	if current_intents.is_empty() or is_aiming:
		return
	_apply_attack_damage_to_intent_preview(current_intents)
	_sync_primary_intent_aliases()
	_refresh_intent_row_ui()


func _apply_attack_damage_to_intent_preview(preview: Array) -> void:
	if not is_instance_valid(unit_data):
		return
	var extra := 0
	if _ai_is("LancerAI.gd") and _is_in_contact_with_nearest_player():
		extra = 4 - unit_data.attack_damage
	elif _ai_is("HarpyAI.gd"):
		extra = 1
	elif _ai_is("StormElementalAI.gd") and StormElementalAI.is_charged(self):
		extra = 3
	var shown := get_telegraphed_attack_damage(extra)
	var deep_freeze := _deep_freeze_bonus_vs_nearest_player()
	var pierce_shown := get_telegraphed_attack_damage(4 - unit_data.attack_damage)
	for i in preview.size():
		var entry: Dictionary = preview[i]
		var intent_id := str(entry.get("id", ""))
		if intent_id == "attack" or (_ai_is("HarpyAI.gd") and intent_id == "rush"):
			entry["short_text"] = str(shown)
			if deep_freeze > 0:
				entry["text"] = TranslationHelper.tr_format("enemy.frost.intent_bonus", {"value": shown})
			preview[i] = entry
		elif intent_id == "pierce" and _ai_is("LancerAI.gd"):
			entry["short_text"] = str(pierce_shown)
			preview[i] = entry
		elif intent_id == "bite":
			entry["short_text"] = str(get_telegraphed_attack_damage(1))
			preview[i] = entry
#---------------------------------------------

@onready var _sprite_node: Sprite3D = $Sprite3D
var _intent_row: Control = null
var _health_bar: Control = null
var _intent_world_padding_ratio: float = 0.08
var _intent_head_trim_ratio: float = 0.14
var _intent_screen_gap_min: float = 2.0
var _intent_screen_gap_max: float = 6.0
var _web_ui_throttle: bool = false

func _is_local_player() -> bool:
	"""Vrátí true jen pokud je tato jednotka LOKÁLNÍHO hráče (ne coop spoluhráče).
	V solo režimu vždy true pro player faction. V coop porovnává owner_peer_id."""
	if unit_data.faction != UnitData.Faction.PLAYER:
		return false
	if not has_meta("owner_peer_id"):
		return true  # Solo režim – není nastaveno, takže jsme to my
	return get_meta("owner_peer_id") == multiplayer.get_unique_id()

func _ready():
	_web_ui_throttle = OS.has_feature("web")
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
	
	var world_ui = _get_unit_world_ui_layer()
	if world_ui:
		_health_bar = UnitHealthBarScene.instantiate()
		world_ui.add_child(_health_bar)
		_refresh_health_bar()
		if unit_data and unit_data.faction == UnitData.Faction.ENEMY:
			_intent_row = IntentIconsRowScene.instantiate()
			world_ui.add_child(_intent_row)
			_intent_row.visible = false
	
	# Pozice ve 3D - zarovnání na zem
	position.y = 0
	
	await get_tree().process_frame
	_refresh_health_bar()
	emit_signal("stats_changed", self)

func _get_unit_world_ui_layer() -> CanvasLayer:
	# Prefer layer below battle hand UI so HP bars never steal card clicks.
	var scene = get_tree().current_scene
	if scene:
		var world_ui := scene.get_node_or_null("UnitWorldUILayer") as CanvasLayer
		if world_ui:
			return world_ui
		var canvas := scene.get_node_or_null("CanvasLayer") as CanvasLayer
		if canvas:
			return canvas
	return get_tree().root.find_child("CanvasLayer", true, false) as CanvasLayer

func _exit_tree() -> void:
	if _initiative_bar_hovered:
		set_initiative_hover_visual(false)
	if _intent_row and is_instance_valid(_intent_row):
		_intent_row.queue_free()
		_intent_row = null
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
	if _web_ui_throttle and Engine.get_process_frames() % 3 != 0:
		return
	if _health_bar and is_instance_valid(_health_bar):
		_update_health_bar_screen_position()
	if _intent_row and _intent_row.visible:
		_update_intent_icon_screen_position()
		_update_intent_icon_scale()
	_update_body_pulse()

func set_last_attacker(attacker: Unit):
	last_attacker = attacker

func get_last_attacker() -> Unit:
	if is_instance_valid(last_attacker):
		return last_attacker
	last_attacker = null  # clear stale reference (attacker may have been freed)
	return null

func attack(target: Node, extra_additive: int = 0, damage_type: int = 0, _is_holy: bool = false) -> void:
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
		base_value, self, target, damage_type, is_critical, include_card_bonuses, extra_additive + get_bonus_attack_damage()
	)
	if is_critical:
		_show_floating_text(damage, "critical")
		print("💥 KRITICKÝ ZÁSAH! %d poškození" % damage)
	
	await target.take_damage(damage, true)

## Returns false if the hit was dodged (no HP/block change). Dodge only applies to attack hits
## (allow_dodge=true); DoT / terrain / forced damage should pass allow_dodge=false.
## skip_artifacts: used by deferred artifact damage so hooks don't double-fire.
func take_damage(amount: int, already_calculated: bool = false, is_rpc_sync: bool = false, allow_dodge: bool = true, skip_artifacts: bool = false, ignore_block: bool = false, from_interpose: bool = false) -> bool:
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
	
	var attacker = get_last_attacker() if has_method("get_last_attacker") else null

	var damage_to_deal = amount
	# Obranný postoj+: polovina ze všech útoků do začátku tvého dalšího tahu (nespotřebuje se)
	if not already_calculated and active_statuses.has("defensive_stance_turn"):
		damage_to_deal = max(1, int(damage_to_deal * 0.5))
	if not already_calculated and active_statuses.has("defensive_stance"):
		damage_to_deal = max(1, int(damage_to_deal * 0.5))
		active_statuses.erase("defensive_stance")
		_update_stats_and_emit_signal()
	elif already_calculated and active_statuses.has("defensive_stance") and damage_to_deal > 0:
		active_statuses.erase("defensive_stance")
		_update_stats_and_emit_signal()
	
	if not from_interpose and damage_to_deal > 0:
		var guard := find_interpose_guard()
		if guard != null:
			guard.set_meta("interpose_cd", 3)
			await guard.take_damage(damage_to_deal, true, is_rpc_sync, false, true, false, true)
			return true

	var absorbed_by_block = 0 if ignore_block else mini(damage_to_deal, current_block)
	
	if absorbed_by_block > 0:
		_show_floating_text(absorbed_by_block, "block_loss")

	# SFX: hit landed (block and/or HP). Local player = take; enemies = deal.
	if (absorbed_by_block > 0 or damage_to_deal > 0) and has_node("/root/AudioManager"):
		if unit_data.faction == UnitData.Faction.PLAYER:
			if _is_local_player():
				AudioManager.play_hit_take()
		else:
			AudioManager.play_hit_deal()

	if absorbed_by_block > 0 or damage_to_deal > 0:
		var hp_hit: int = damage_to_deal - absorbed_by_block
		_play_hit_flash(hp_hit > 0)
		var battle_scene = get_tree().get_first_node_in_group("battle_scene")
		if battle_scene and battle_scene.has_method("add_screen_shake"):
			battle_scene.add_screen_shake(hp_hit, absorbed_by_block, unit_data.faction == UnitData.Faction.PLAYER)

	current_block -= absorbed_by_block
	damage_to_deal -= absorbed_by_block
	
	retained_block = mini(retained_block, current_block)
	carried_block = clampi(carried_block, 0, current_block - retained_block)
	
	if absorbed_by_block > 0 and damage_to_deal > 0:
		await get_tree().create_timer(0.3).timeout

	# Thorns reflect — player pool lives on PlayerData; enemies use status.
	var thorns_amt := 0
	if _is_local_player() and has_node("/root/PlayerData"):
		thorns_amt = PlayerData.get_thorns_damage()
	elif active_statuses.has("thorns"):
		thorns_amt = int(active_statuses["thorns"].get("value", 0))
	if absorbed_by_block + damage_to_deal > 0 and thorns_amt > 0 and is_instance_valid(attacker):
		if attacker.has_method("take_damage"):
			attacker.take_damage(thorns_amt, true, false, false)
			if _is_local_player() and has_node("/root/ArtifactManager"):
				ArtifactManager.on_thorns_damage(thorns_amt, attacker)

	if damage_to_deal > 0:
		var deferred := false
		if not skip_artifacts and _is_local_player() and has_node("/root/ArtifactManager"):
			var art_ctx: Dictionary = ArtifactManager.on_unblocked_damage(damage_to_deal, attacker)
			deferred = bool(art_ctx.get("damage_deferred", false))

		if not deferred:
			current_health -= damage_to_deal
			_show_floating_text(damage_to_deal, "damage")
			
			if current_health < 0:
				current_health = 0
			_try_interrupt_windup()
			
			if _is_local_player():
				PlayerData.take_damage(damage_to_deal)
			# Hněv (power): každá ztráta HP přidá stacky. Podle frakce, ne lokality — v coopu
			# počítá host nepřátelský tah i za klientovu jednotku a statusy pak synchronizuje.
			if unit_data.faction == UnitData.Faction.PLAYER and active_statuses.has("fury_engine") and current_health > 0:
				apply_status("fury", int(active_statuses["fury_engine"].get("value", 1)), 999)
		else:
			_show_floating_text(damage_to_deal, "block_loss")
	
	_update_stats_and_emit_signal()
	
	if current_health <= 0:
		if _is_local_player() and has_node("/root/ArtifactManager"):
			if ArtifactManager.before_death(self):
				_update_stats_and_emit_signal()
				return true
		_die()
	return true
## Authoritative block from coop sync — keeps retained/carried within the new total.
func set_synced_block(value: int) -> void:
	current_block = maxi(0, value)
	retained_block = mini(retained_block, current_block)
	carried_block = clampi(carried_block, 0, current_block - retained_block)

func reset_for_new_turn():
	current_block = retained_block + carried_block
	carried_block = 0
	if active_statuses.has("defensive_stance_turn"):
		active_statuses.erase("defensive_stance_turn")
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
		var unit_label = String(unit_data.unit_id) if unit_data else String(name)
		DebugLogger.log_info("Status '%s' applied to %s (value=%d, duration=%d)" % [status_id, unit_label, value, duration])
	if status_id == "weakness":
		_refresh_attack_intent_numbers()
	_update_stats_and_emit_signal()
	if has_node("/root/ArtifactManager"):
		ArtifactManager.on_status_applied(self, status_id, value, duration)

## Nahradí status místo sčítání hodnoty. Frostbite tak zůstane na −2, ne −4, −6…
func replace_status(status_id: String, value: int, duration: int = 1) -> void:
	if active_statuses.has(status_id):
		active_statuses.erase(status_id)
	apply_status(status_id, value, duration)

func _is_frost_elemental() -> bool:
	return _ai_is("FrostElementalAI.gd")

func _ai_is(file_name: String) -> bool:
	return is_instance_valid(unit_data) and is_instance_valid(unit_data.ai_script) and unit_data.ai_script.resource_path.ends_with(file_name)

func combat_windup() -> Dictionary:
	if has_meta("combat_windup") and typeof(get_meta("combat_windup")) == TYPE_DICTIONARY:
		return get_meta("combat_windup")
	return {}

func windup_kind() -> String:
	return str(combat_windup().get("kind", ""))

func set_combat_windup(data: Dictionary) -> void:
	set_meta("combat_windup", data)

func clear_combat_windup() -> void:
	if has_meta("combat_windup"):
		remove_meta("combat_windup")
	if has_meta("windup_target"):
		remove_meta("windup_target")

func _try_interrupt_windup() -> void:
	var data := combat_windup()
	if data.is_empty() or not bool(data.get("interruptible", false)):
		return
	var kind := str(data.get("kind", ""))
	var lock_turns := int(data.get("lock_turns", 2))
	clear_combat_windup()
	set_meta("windup_lock", lock_turns)
	if kind == "song":
		set_meta("siren_step", "song")
	show_status_text(tr("status.float.interrupted"), "curse")

func find_interpose_guard() -> Unit:
	if not is_inside_tree() or unit_data == null or _ai_is("DwarfGuardianAI.gd"):
		return null
	for node in get_tree().get_nodes_in_group("units"):
		if not (node is Unit) or node == self or node.current_health <= 0:
			continue
		if node.unit_data == null or node.unit_data.faction != unit_data.faction:
			continue
		if not node._ai_is("DwarfGuardianAI.gd"):
			continue
		var dist := absi(node.grid_position.x - grid_position.x) + absi(node.grid_position.y - grid_position.y)
		if dist != 1:
			continue
		var cd := int(node.get_meta("interpose_cd")) if node.has_meta("interpose_cd") else 0
		if cd > 0:
			continue
		return node
	return null

func _nearest_living_player() -> Unit:
	var best: Unit = null
	var best_dist := 999999
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Unit) or node.current_health <= 0:
			continue
		var dist := absi(node.grid_position.x - grid_position.x) + absi(node.grid_position.y - grid_position.y)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best

func _is_in_contact_with_nearest_player() -> bool:
	var player := _nearest_living_player()
	if player == null:
		return false
	var dist := absi(player.grid_position.x - grid_position.x) + absi(player.grid_position.y - grid_position.y)
	return dist <= 1

func _apply_opening_block() -> void:
	if unit_data == null or unit_data.faction != UnitData.Faction.ENEMY:
		return
	if _ai_is("EarthGolemAI.gd"):
		var moved := has_meta("earth_moved_last") and bool(get_meta("earth_moved_last"))
		if not moved:
			add_block(6)
	elif _ai_is("DwarfGuardianAI.gd"):
		add_block(8)

func _update_body_pulse() -> void:
	if not is_instance_valid(_sprite_node):
		return
	if _initiative_bar_hovered or _is_hit_flashing() or is_selected:
		return
	var tint := _body_pulse_color()
	if tint.a <= 0.0:
		if _body_pulse_on:
			_sprite_node.modulate = Color.WHITE
			_body_pulse_on = false
		return
	_body_pulse_on = true
	var wave := (sin(Time.get_ticks_msec() / 320.0) + 1.0) * 0.5
	_sprite_node.modulate = tint.lerp(Color(1, 0.97, 0.9), wave)

func _body_pulse_color() -> Color:
	if _ai_is("FireElementalAI.gd"):
		return Color(1.0, 0.42, 0.12)
	if _ai_is("DwarfGuardianAI.gd"):
		return Color(1.0, 0.82, 0.28)
	if _ai_is("StormElementalAI.gd") and StormElementalAI.is_charged(self):
		return Color(1.0, 0.86, 0.25)
	if _ai_is("EarthGolemAI.gd"):
		var moved := has_meta("earth_moved_last") and bool(get_meta("earth_moved_last"))
		if not moved:
			return Color(1.0, 0.82, 0.28)
	return Color(0, 0, 0, 0)

func _deep_freeze_bonus_vs_nearest_player() -> int:
	if not _is_frost_elemental() or not is_inside_tree():
		return 0
	var best: Unit = null
	var best_dist := 999999
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Unit) or node.current_health <= 0:
			continue
		var dist := absi(node.grid_position.x - grid_position.x) + absi(node.grid_position.y - grid_position.y)
		if dist < best_dist:
			best_dist = dist
			best = node
	if best == null:
		return 0
	return FrostElementalAI.bonus_if_slowed(best)

func process_turn_start_statuses() -> int:
	var extra_draw = 0
	_apply_opening_block()
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
	if active_statuses.has("regeneration_permanent"):
		heal(int(active_statuses["regeneration_permanent"].value))

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
			var unit_label = String(unit_data.unit_id) if unit_data else String(name)
			DebugLogger.log_info("Poison expired on %s" % unit_label)
	else:
		active_statuses["poison"].duration = remaining
		if has_node("/root/DebugLogger"):
			var unit_label = String(unit_data.unit_id) if unit_data else String(name)
			DebugLogger.log_info("Poison on %s: %d dmg, %d turns left" % [unit_label, poison_dmg, remaining])
	_update_stats_and_emit_signal()

func process_turn_end_statuses() -> void:
	if active_statuses.is_empty():
		return

	var statuses_to_remove = []
	var stats_dirty := false
	for status_id in active_statuses.keys():
		if status_id in COMBAT_LONG_STATUSES:
			continue
		# Poison ticks at start of turn — skip here so duration isn't double-decremented
		if status_id == "poison":
			continue
		# Combat thorns (Spiral Bulwark etc.) last whole fight — cleaned on combat end
		if status_id == "thorns":
			continue
		# "Next hit / next attack" buffs must survive end-of-turn into enemy turns
		if status_id in UNTIL_CONSUMED_STATUSES:
			continue
		# Regeneration heals at start of turn (see process_turn_start_statuses), only tick duration here
		
		# Burning is a stack: deal current value at end of turn, then value -= 1. Lifetime is the stack, not duration.
		if status_id == "burning":
			var status_data = active_statuses[status_id]
			var damage = status_data.value
			# take_damage already shows the damage float — do not double-float here
			await take_damage(damage, true, false, false)
			if not is_instance_valid(self) or current_health <= 0:
				return
			status_data.value = max(0, status_data.value - 1)
			stats_dirty = true
			if status_data.value <= 0:
				statuses_to_remove.append(status_id)
			if has_node("/root/DebugLogger"):
				var unit_label = String(unit_data.unit_id) if unit_data else String(name)
				if status_data.value <= 0:
					DebugLogger.log_info("Burning expired on %s after %d dmg" % [unit_label, damage])
				else:
					DebugLogger.log_info("Burning on %s: %d dmg, %d left" % [unit_label, damage, status_data.value])
			continue

		active_statuses[status_id].duration -= 1
		stats_dirty = true
		if active_statuses[status_id].duration <= 0:
			statuses_to_remove.append(status_id)

	if statuses_to_remove.is_empty() and not stats_dirty:
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
	if _intent_row and is_instance_valid(_intent_row):
		_intent_row.queue_free()
		_intent_row = null
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
		if active_statuses.has("dexterity"):
			total_block += int(active_statuses["dexterity"].get("value", 0))
	
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
	if _health_bar.has_method("update_statuses"):
		_health_bar.update_statuses(active_statuses)

func set_damage_preview(hp_loss: int, lethal: bool, show_label: bool = true) -> void:
	if _health_bar and is_instance_valid(_health_bar) and _health_bar.has_method("set_damage_preview"):
		_health_bar.set_damage_preview(hp_loss, lethal, show_label)

## Screen point at the sprite's visual center (targeting arrow tip).
func get_aim_screen_position(camera: Camera3D) -> Vector2:
	return camera.unproject_position(global_position + Vector3(0, _get_sprite_world_center_offset_y(), 0))

func clear_damage_preview() -> void:
	if _health_bar and is_instance_valid(_health_bar) and _health_bar.has_method("clear_damage_preview"):
		_health_bar.clear_damage_preview()

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


## Short tint pulse on hit (red = HP lost, blue = fully blocked); fades back to the resting tint.
func _play_hit_flash(hp_hit: bool) -> void:
	if not _sprite_node:
		return
	if _is_hit_flashing():
		_hit_flash_tween.kill()
	else:
		_hit_flash_base_modulate = Color.WHITE if (_initiative_bar_hovered or is_selected) else _sprite_node.modulate
	_hit_flash_color = HIT_FLASH_HP_COLOR if hp_hit else HIT_FLASH_BLOCK_COLOR
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_method(_apply_hit_flash, 1.0, 0.0, HIT_FLASH_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_hit_flash(strength: float) -> void:
	if not _sprite_node:
		return
	var tint := _resting_sprite_modulate().lerp(_hit_flash_color, strength)
	tint.a = _sprite_node.modulate.a
	_sprite_node.modulate = tint


func _is_hit_flashing() -> bool:
	return _hit_flash_tween != null and _hit_flash_tween.is_valid() and _hit_flash_tween.is_running()


## Tint the sprite should have when no hit flash is playing.
func _resting_sprite_modulate() -> Color:
	if _initiative_bar_hovered:
		return INITIATIVE_HOVER_MODULATE
	if is_selected:
		return SELECTED_MODULATE
	return _hit_flash_base_modulate


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
			_pre_initiative_hover_modulate = _resting_sprite_modulate() if _is_hit_flashing() else _sprite_node.modulate
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
	if not _intent_row or not _intent_visibility_allowed:
		return
	if attack_damage > 0 and not current_intents.is_empty():
		# ArcherAI may stamp damage onto the attack telegraph during its turn setup.
		for i in range(current_intents.size()):
			var entry: Dictionary = current_intents[i]
			if str(entry.get("id", "")) == "attack":
				entry["short_text"] = str(attack_damage)
				current_intents[i] = entry
				break
		_sync_primary_intent_aliases()
	_refresh_intent_row_ui()

func force_show_attack_intent(damage: int = 0) -> void:
	"""Tutorial / scripted telegraph: show Attack even when AI script is missing."""
	var short := str(damage) if damage > 0 else tr("ATTACK")
	current_intents = [_make_intent_entry("attack", short, tr("Next Move: Attack"))]
	_sync_primary_intent_aliases()
	_intent_visibility_allowed = true
	_refresh_intent_row_ui()

func hide_intent():
	if _intent_row and _intent_row.has_method("hide_row"):
		_intent_row.hide_row()
	elif _intent_row:
		_intent_row.visible = false

func set_intent_visibility_allowed(allowed: bool) -> void:
	_intent_visibility_allowed = allowed
	if not allowed:
		hide_intent()

func update_intent(player_unit: Unit, battle_grid: BattleGrid) -> void:
	if not is_instance_valid(unit_data) or unit_data.faction != UnitData.Faction.ENEMY:
		return
	if not is_instance_valid(battle_grid):
		return
	current_intents = _calculate_intent_list(player_unit, battle_grid)
	_intent_threats = _build_intent_threats(player_unit, battle_grid)
	_sync_primary_intent_aliases()
	_refresh_intent_row_ui()

func _sync_primary_intent_aliases() -> void:
	if current_intents.is_empty():
		current_intent_id = ""
		current_intent_text = ""
		current_intent_short = ""
		return
	var primary: Dictionary = current_intents[0]
	# Threat-first: if they will hit this turn, panel / coop snapshot must not read as MOVE.
	for entry in current_intents:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var intent_id := str(entry.get("id", ""))
		if intent_id == "attack" or intent_id == "rush" or intent_id == "meteor" or intent_id == "aiming":
			primary = entry
			break
	current_intent_id = str(primary.get("id", ""))
	current_intent_text = str(primary.get("text", ""))
	current_intent_short = str(primary.get("short_text", ""))

func _refresh_intent_row_ui() -> void:
	if not _intent_row:
		return
	var row_payload: Array = []
	for entry in current_intents:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var intent_id := str(entry.get("id", ""))
		row_payload.append({
			"icon": _get_intent_icon_for_id(intent_id),
			"short_text": str(entry.get("short_text", "")),
			"countdown": int(entry.get("countdown", 0)),
		})
	if _intent_row.has_method("set_intents"):
		_intent_row.set_intents(row_payload)
	if _intent_visibility_allowed and not row_payload.is_empty():
		if _intent_row.has_method("show_row"):
			_intent_row.show_row()
		else:
			_intent_row.visible = true
		_update_intent_icon_screen_position()
		_update_intent_icon_scale()
	else:
		hide_intent()

func _update_intent_icon_screen_position() -> void:
	if not _intent_row:
		return
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var center = global_position + Vector3(0, _get_sprite_world_center_offset_y(), 0)
	var half_height = _get_sprite_world_height() * 0.5
	var world_top = center + Vector3(0, half_height, 0)
	var screen_top = camera.unproject_position(world_top)
	var screen_center_x = screen_top.x
	var sprite_screen_h := _get_sprite_screen_height(camera)
	# Texture tops often include transparent padding — anchor slightly lower.
	var head_top_y: float = screen_top.y + sprite_screen_h * _intent_head_trim_ratio

	var gap_px: float = _intent_screen_gap_min
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var zoom_t: float = inverse_lerp(5.0, 30.0, camera.size)
		gap_px = lerpf(_intent_screen_gap_min, _intent_screen_gap_max, clampf(zoom_t, 0.0, 1.0))

	var screen_pos := Vector2(screen_center_x, head_top_y)
	if _intent_row.has_method("get_anchor_offset_below_center"):
		var below: float = float(_intent_row.get_anchor_offset_below_center()) * 0.78
		screen_pos.y = head_top_y - gap_px - below
	else:
		var world_pos = world_top + Vector3(0, _get_sprite_world_height() * _intent_world_padding_ratio, 0)
		screen_pos = camera.unproject_position(world_pos)

	if _intent_row.has_method("set_screen_position"):
		_intent_row.set_screen_position(screen_pos)
	else:
		_intent_row.position = screen_pos

func _update_intent_icon_scale() -> void:
	if not _intent_row:
		return
	if not _intent_row.has_method("get_icon_texture_size"):
		return
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var sprite_screen_height = _get_sprite_screen_height(camera)
	if sprite_screen_height <= 0:
		return
	var target_icon_height = clamp(sprite_screen_height * 0.25, 18.0, 48.0)
	var icon_size: Vector2 = _intent_row.get_icon_texture_size()
	if icon_size.y <= 0:
		return
	var scale_value = target_icon_height / icon_size.y
	if _intent_row.has_method("set_row_scale"):
		_intent_row.set_row_scale(scale_value)
	elif _intent_row.has_method("set_icon_scale"):
		_intent_row.set_icon_scale(scale_value)

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

func get_intent_entries() -> Array:
	"""Up to 2 intents for UnitInfoPanel: [{short_text, text}, ...]."""
	var entries: Array = []
	for item in current_intents:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		entries.append({
			"short_text": str(item.get("short_text", "")),
			"text": str(item.get("text", "")),
		})
		if entries.size() >= 2:
			break
	return entries

func get_intent_threat_cells() -> Array:
	return _intent_threats

func _build_intent_threats(player_unit: Unit, battle_grid: BattleGrid) -> Array:
	var out: Array = []
	if not is_instance_valid(player_unit) or not is_instance_valid(battle_grid):
		return out
	if is_instance_valid(unit_data) and is_instance_valid(unit_data.ai_script):
		var ai = unit_data.ai_script.new()
		if ai != null and ai.has_method("preview_threats"):
			var custom = ai.preview_threats(self, player_unit, battle_grid)
			if typeof(custom) == TYPE_ARRAY:
				return custom
	var will_strike := false
	var is_meteor := false
	var will_close := false
	var is_rush := false
	for entry in current_intents:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var intent_id := str(entry.get("id", ""))
		if intent_id == "meteor":
			is_meteor = true
			will_strike = true
		elif intent_id == "rush":
			is_rush = true
			will_strike = true
		elif intent_id == "attack" or intent_id == "aiming":
			will_strike = true
		elif intent_id == "move":
			will_close = true
	if not will_strike:
		return out
	if is_meteor:
		for obj in battle_grid.get_all_objects_on_grid():
			if obj is Unit and obj != self and obj.current_health > 0 and obj.unit_data.faction != unit_data.faction:
				out.append({"cell": obj.grid_position, "kind": "damage"})
		return out
	var in_range := _can_attack_player(player_unit, battle_grid)
	if not in_range and not will_close and not is_rush:
		return out
	var kind := "control" if _is_frost_elemental() else "damage"
	out.append({"cell": player_unit.grid_position, "kind": kind})
	return out

func get_intent_ui() -> Control:
	if _intent_row and _intent_row.has_method("get_primary_intent_ui"):
		return _intent_row.get_primary_intent_ui()
	return _intent_row

func get_enemy_class_display() -> String:
	if not is_instance_valid(unit_data) or not is_instance_valid(unit_data.ai_script):
		return tr("Class: Unknown")
	var class_name_text = _get_ai_class_name(unit_data.ai_script.resource_path)
	var range_txt := tr("enemy.label.melee") if unit_data.attack_range <= 1 else tr("enemy.label.ranged")
	return tr("Class: ") + class_name_text + " · " + range_txt

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
	if ritual_stacks > 0:
		counters.append(TranslationHelper.tr_format("enemy.counter.ritual", {"value": ritual_stacks}))
	if pack_attack_bonus > 0:
		counters.append(TranslationHelper.tr_format("enemy.counter.pack", {"value": pack_attack_bonus}))
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
	if _ai_is("EarthGolemAI.gd") and has_meta("slam_cooldown"):
		var slam_cd := int(get_meta("slam_cooldown"))
		if slam_cd > 0:
			counters.append(TranslationHelper.tr_format("enemy.earth.slam_cd", {"value": slam_cd}))
	if _ai_is("DwarfGuardianAI.gd") and has_meta("interpose_cd"):
		var cover_cd := int(get_meta("interpose_cd"))
		if cover_cd > 0:
			counters.append(TranslationHelper.tr_format("enemy.dwarf.interpose_cd", {"value": cover_cd}))
	if has_meta("windup_lock") and int(get_meta("windup_lock")) > 0:
		counters.append(TranslationHelper.tr_format("enemy.counter.windup_lock", {"value": int(get_meta("windup_lock"))}))
	return counters

## Returns up to 2 player-facing intent dicts: {id, short_text, text, countdown}.
## Exclusive specials (Rush/Meteor/Aiming/…) = 1 icon.
## Default melee plan uses EnemyAIBase.preview_combat_intents (ATTACK / ATTACK+MOVE / MOVE).
## Never calls get_actions() — that mutates Boss/Mage/Monk/Druid meta.
func _calculate_intent_list(player_unit: Unit, battle_grid: BattleGrid) -> Array:
	var ai_path = unit_data.ai_script.resource_path if is_instance_valid(unit_data.ai_script) else ""
	var countdown := 0

	# === BERSERKER RAGE (exclusive) ===
	var berserker_rage = ai_path.contains("BerserkerAI") and is_permanently_enraged
	if active_statuses.has("rage") or berserker_rage:
		return [_make_intent_entry(
			"rush", tr("RUSH"),
			tr("Next Move: Rush (%d%% DMG)") % BERSERKER_RUSH_DAMAGE_PERCENT
		)]

	# === BOSS AI (exclusive specials; otherwise fall through to preview + slash countdown) ===
	if ai_path.contains("BossAI"):
		var boss_phase = int(get_meta("boss_phase")) if has_meta("boss_phase") else 1
		var btc = int(get_meta("boss_turn_count")) if has_meta("boss_turn_count") else 0
		if boss_phase == 2:
			var next_hellfire = 4 - (btc % 4)
			if next_hellfire == 4:
				next_hellfire = 0
			if btc > 0 and (btc + 1) % 4 == 0:
				return [_make_intent_entry("attack", tr("HELLFIRE"), tr("Next Move: Hellfire AoE"))]
			return [_make_intent_entry(
				"attack", tr("ENRAGED"), tr("Next Move: Enraged Attack"), next_hellfire
			)]
		else:
			var next_slash = 3 - (btc % 3)
			if next_slash == 3:
				next_slash = 0
			if btc > 0 and (btc + 1) % 3 == 0:
				return [_make_intent_entry("attack", tr("SLASH"), tr("Next Move: Dark Slash"))]
			countdown = next_slash

	# === DARK BEAST AI (exclusive) ===
	if ai_path.contains("DarkBeastAI"):
		var health_pct = float(current_health) / float(unit_data.max_health) if unit_data.max_health > 0 else 1.0
		if health_pct <= 0.3 and has_meta("has_howled") and not get_meta("has_howled"):
			return [_make_intent_entry("attack", tr("HOWL"), tr("Next Move: Howl (buff allies)"))]
		var dist = battle_grid.get_distance(grid_position, player_unit.grid_position) if is_instance_valid(player_unit) else 0
		if dist >= 3:
			return [_make_intent_entry("attack", tr("POUNCE"), tr("Next Move: Pounce (+50% DMG)"))]

	# === ARCHER AIMING (exclusive) ===
	if ai_path.contains("ArcherAI") and is_aiming:
		return [_make_intent_entry(
			"aiming", tr("AIMING"),
			tr("Next Move: Aimed Shot (%d%% DMG)") % ARCHER_AIM_DAMAGE_PERCENT
		)]

	# === BERSERKER lined rush / tremor (exclusive when labeled) ===
	if ai_path.contains("BerserkerAI"):
		if _is_aligned_with_player(player_unit) and berserker_frustration >= BERSERKER_RAGE_TURNS_REQUIRED:
			return [_make_intent_entry(
				"rush", tr("RUSH"),
				tr("Next Move: Rush (%d%% DMG)") % BERSERKER_RUSH_DAMAGE_PERCENT
			)]
		if berserker_frustration >= 2:
			var b_dist = battle_grid.get_distance(grid_position, player_unit.grid_position) if is_instance_valid(player_unit) else 0
			if b_dist <= 4 and not _can_attack_player(player_unit, battle_grid) and not _can_move_then_attack_this_turn(player_unit, battle_grid):
				var tremor_cd := 0
				if berserker_frustration < BERSERKER_RAGE_TURNS_REQUIRED:
					tremor_cd = BERSERKER_RAGE_TURNS_REQUIRED - berserker_frustration
				return [_make_intent_entry("attack", tr("TREMOR"), tr("Next Move: Tremor AoE"), tremor_cd)]
		if berserker_frustration < BERSERKER_RAGE_TURNS_REQUIRED:
			countdown = BERSERKER_RAGE_TURNS_REQUIRED - berserker_frustration

	# === MAGE METEOR (exclusive when casting; else spell label + countdown on preview) ===
	if ai_path.contains("MageAI"):
		var turn_count = int(get_meta("mage_turn_count")) if has_meta("mage_turn_count") else 0
		var turns_left = MAGE_METEOR_TURNS_REQUIRED - turn_count
		if turn_count + 1 >= MAGE_METEOR_TURNS_REQUIRED:
			return [_make_intent_entry(
				"meteor", tr("METEOR"),
				tr("Next Move: Meteor (%d%% DMG to ALL)") % MAGE_METEOR_DAMAGE_PERCENT
			)]
		countdown = turns_left
		if has_meta("spell_index"):
			var spell_names = ["FIRE", "ICE", "LIGHTNING", "SHIELD"]
			var idx = int(get_meta("spell_index")) % 4
			return [_make_intent_entry(
				"attack", tr(spell_names[idx]),
				tr("Next Spell: %s (Meteor in %d)") % [spell_names[idx], turns_left],
				countdown
			)]

	# === ASSASSIN shadow (exclusive) ===
	if ai_path.contains("AssassinAI"):
		var a_dist = battle_grid.get_distance(grid_position, player_unit.grid_position) if is_instance_valid(player_unit) else 0
		if a_dist >= 4:
			return [_make_intent_entry("attack", tr("SHADOW"), tr("Next Move: Shadow Strike (+50% DMG)"))]

	# === HEALER ally heal (exclusive) ===
	if ai_path.contains("HealerAI"):
		var all_units = battle_grid.get_all_objects_on_grid()
		for u in all_units:
			if is_instance_valid(u) and u is Unit and u != self:
				if u.unit_data.faction == unit_data.faction:
					var hp_pct = float(u.current_health) / float(u.unit_data.max_health)
					if hp_pct < 0.5:
						return [_make_intent_entry("heal", tr("HEAL"), tr("Next Move: Heal Ally"))]

	# === DRUID entangle (exclusive when ready) ===
	if ai_path.contains("DruidAI"):
		var entangle_cd = int(get_meta("entangle_cooldown")) if has_meta("entangle_cooldown") else 0
		var d_dist = battle_grid.get_distance(grid_position, player_unit.grid_position) if is_instance_valid(player_unit) else 0
		if entangle_cd <= 0 and d_dist <= 3:
			return [_make_intent_entry("attack", tr("ENTANGLE"), tr("Next Move: Entangle (root)"))]
		elif entangle_cd > 0:
			countdown = entangle_cd

	# === MONK war cry (exclusive when ready) ===
	if ai_path.contains("MonkAI"):
		var wc_cd = int(get_meta("war_cry_cooldown")) if has_meta("war_cry_cooldown") else 0
		if wc_cd <= 0:
			return [_make_intent_entry("buff", tr("BUFF"), tr("Next Move: Blessing/War Cry"))]
		countdown = wc_cd

	# === Default: pure AI preview (1 or 2 combat intents) ===
	var preview := _preview_combat_intents_from_ai(player_unit, battle_grid)
	if preview.is_empty():
		return []
	_apply_attack_damage_to_intent_preview(preview)
	if countdown > 0:
		var first: Dictionary = preview[0]
		first["countdown"] = countdown
		preview[0] = first
	return preview

func _make_intent_entry(id: String, short_text: String, text: String, countdown: int = 0) -> Dictionary:
	return {
		"id": id,
		"short_text": short_text,
		"text": text,
		"countdown": countdown,
	}

func _preview_combat_intents_from_ai(player_unit: Unit, battle_grid: BattleGrid) -> Array:
	# Tutorial dummy / missing AI: telegraph ATTACK in range, never invent MOVE.
	if not is_instance_valid(unit_data) or not is_instance_valid(unit_data.ai_script):
		if _can_attack_player(player_unit, battle_grid):
			return [_make_intent_entry("attack", tr("ATTACK"), tr("Next Move: Attack"))]
		return []

	var ai = unit_data.ai_script.new()
	if ai == null or not ai.has_method("preview_combat_intents"):
		if _can_attack_player(player_unit, battle_grid):
			return [_make_intent_entry("attack", tr("ATTACK"), tr("Next Move: Attack"))]
		if _can_move_then_attack_this_turn(player_unit, battle_grid):
			return [
				_make_intent_entry("attack", tr("ATTACK"), tr("Next Move: Attack")),
				_make_intent_entry("move", tr("MOVE"), tr("Next Move: Move")),
			]
		return []

	var raw: Array = ai.preview_combat_intents(self, player_unit, battle_grid)
	var out: Array = []
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		out.append(_make_intent_entry(
			str(item.get("id", "move")),
			str(item.get("short_text", tr("MOVE"))),
			str(item.get("text", tr("Next Move: Move"))),
			int(item.get("countdown", 0))
		))
		if out.size() >= 2:
			break
	return out

func _can_attack_player(player_unit: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(player_unit):
		return false
	var distance = battle_grid.get_distance(grid_position, player_unit.grid_position)
	return distance <= unit_data.attack_range

func _can_move_then_attack_this_turn(player_unit: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(player_unit):
		return false
	if not is_instance_valid(unit_data) or not is_instance_valid(unit_data.ai_script):
		return false
	var ai = unit_data.ai_script.new()
	if ai == null or not ai.has_method("can_move_then_attack_this_turn"):
		return false
	return ai.can_move_then_attack_this_turn(self, player_unit, battle_grid)

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
	if ai_path.contains("FrostElementalAI"):
		return tr("enemy.class.frost")
	if ai_path.contains("FireElementalAI"):
		return tr("enemy.class.fire")
	if ai_path.contains("EarthGolemAI"):
		return tr("enemy.class.earth")
	if ai_path.contains("LancerAI"):
		return tr("enemy.class.lancer")
	if ai_path.contains("HarpyAI"):
		return tr("enemy.class.harpy")
	if ai_path.contains("DwarfGuardianAI"):
		return tr("enemy.class.dwarf")
	if ai_path.contains("StormElementalAI"):
		return tr("enemy.class.storm")
	if ai_path.contains("CrystalSerpentAI"):
		return tr("enemy.class.serpent")
	if ai_path.contains("MinotaurAI"):
		return tr("enemy.class.minotaur")
	if ai_path.contains("CyclopsAI"):
		return tr("enemy.class.cyclops")
	if ai_path.contains("BansheeAI"):
		return tr("enemy.class.banshee")
	if ai_path.contains("SirenAI"):
		return tr("enemy.class.siren")
	if ai_path.contains("FighterAI"):
		return tr("Fighter")
	return tr("Unknown")

func get_enemy_ability_entries() -> Array:
	"""Řádky bloku Umí: {title, text}. Text je jedna věta, kterou hráč čte bez tooltipu."""
	if _is_frost_elemental():
		return [
			{"title": "", "text": tr("enemy.frost.frostbite.text")},
			{"title": "", "text": tr("enemy.frost.deep_freeze.text")},
		]
	if _ai_is("FireElementalAI.gd"):
		return [
			{"title": "", "text": tr("enemy.fire.burning_touch.text")},
			{"title": "", "text": tr("enemy.fire.volatile_core.text")},
		]
	if _ai_is("EarthGolemAI.gd"):
		return [
			{"title": "", "text": tr("enemy.earth.stone_stance.text")},
			{"title": "", "text": tr("enemy.earth.seismic_slam.text")},
		]
	if _ai_is("LancerAI.gd"):
		return [
			{"title": "", "text": tr("enemy.lancer.pierce.text")},
			{"title": "", "text": tr("enemy.lancer.close.text")},
		]
	if _ai_is("HarpyAI.gd"):
		return [
			{"title": "", "text": tr("enemy.harpy.dive.text")},
			{"title": "", "text": tr("enemy.harpy.gust.text")},
		]
	if _ai_is("DwarfGuardianAI.gd"):
		return [
			{"title": "", "text": tr("enemy.dwarf.shield_wall.text")},
			{"title": "", "text": tr("enemy.dwarf.interpose.text")},
		]
	if _ai_is("StormElementalAI.gd"):
		return [
			{"title": "", "text": tr("enemy.storm.chain.text")},
			{"title": "", "text": tr("enemy.storm.charged.text")},
		]
	if _ai_is("CrystalSerpentAI.gd"):
		return [
			{"title": "", "text": tr("enemy.serpent.trail.text")},
			{"title": "", "text": tr("enemy.serpent.bite.text")},
		]
	if _ai_is("MinotaurAI.gd"):
		return [
			{"title": "", "text": tr("enemy.minotaur.rush.text")},
			{"title": "", "text": tr("enemy.minotaur.crash.text")},
		]
	if _ai_is("CyclopsAI.gd"):
		return [
			{"title": "", "text": tr("enemy.cyclops.blow.text")},
			{"title": "", "text": tr("enemy.cyclops.splash.text")},
		]
	if _ai_is("BansheeAI.gd"):
		return [
			{"title": "", "text": tr("enemy.banshee.wail.text")},
			{"title": "", "text": tr("enemy.banshee.weak.text")},
		]
	if _ai_is("SirenAI.gd"):
		return [
			{"title": "", "text": tr("enemy.siren.song.text")},
			{"title": "", "text": tr("enemy.siren.silence.text")},
			{"title": "", "text": tr("enemy.siren.pull.text")},
		]
	var raw := _get_passives_text().strip_edges()
	var none_text := tr("enemy.passive.none")
	if raw.is_empty() or raw == none_text or raw == "None" or raw == "Žádné":
		return []
	return [{"title": "", "text": raw}]

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
		"attack", "slam", "pierce", "gust", "windup", "bite": return INTENT_ICON_ATTACK
		"heal": return INTENT_ICON_HEAL
		"buff", "block", "defend": return INTENT_ICON_BLOCK
		"move": return INTENT_ICON_MOVE
	return INTENT_ICON_MOVE

func _show_floating_text(amount: int, type: String):
	if amount <= 0:
		return
	var instance = FloatingTextScene.instantiate()
	var text_to_display: String
	var color: Color
	var icon: Texture2D = null

	match type:
		"damage":
			text_to_display = "-" + str(amount)
			color = Color(1.0, 0.25, 0.25)
			icon = INTENT_ICON_ATTACK
		"heal":
			text_to_display = "+" + str(amount)
			color = Color(0.35, 1.0, 0.45)
			icon = INTENT_ICON_HEAL
		"block_gain":
			text_to_display = "+" + str(amount)
			color = Color(0.45, 0.85, 1.0)
			icon = INTENT_ICON_BLOCK
		"block_loss":
			text_to_display = "-" + str(amount)
			color = Color(0.7, 0.8, 0.95)
			icon = INTENT_ICON_BLOCK
		"critical":
			text_to_display = "CRIT! -" + str(amount)
			color = Color(1.0, 0.7, 0.15)
			icon = FLOAT_ICON_CRIT
		"holy_effective":
			text_to_display = "-" + str(amount)
			color = Color(1.0, 0.9, 0.3)
			icon = INTENT_ICON_HOLY

	var canvas = get_tree().root.find_child("CanvasLayer", true, false)
	if canvas:
		canvas.add_child(instance)
		var float_size: Vector2 = await instance.prepare(text_to_display, color, icon)
		var camera = get_viewport().get_camera_3d()
		if camera:
			var world_pos_above_unit = global_position + Vector3(0, 1.5, 0)
			var screen_pos = camera.unproject_position(world_pos_above_unit)
			var camera_forward = -camera.global_transform.basis.z
			var to_unit = (world_pos_above_unit - camera.global_position).normalized()
			var is_in_front = camera_forward.dot(to_unit) > 0
			var viewport_size = get_viewport().get_visible_rect().size
			var margin = 50
			if is_in_front and \
			   screen_pos.x >= -margin and screen_pos.x <= viewport_size.x + margin and \
			   screen_pos.y >= -margin and screen_pos.y <= viewport_size.y + margin:
				instance.position = screen_pos + Vector2(-float_size.x * 0.5, -40)
			else:
				instance.position = viewport_size * 0.5 + Vector2(0, -100)
		else:
			var viewport_size = get_viewport().get_visible_rect().size
			instance.position = viewport_size * 0.5
		instance.animate()
	else:
		instance.queue_free()

func show_status_text(text_to_show: String, color_type: String, icon: Texture2D = null):
	var instance = FloatingTextScene.instantiate()
	var color: Color
	var status_icon: Texture2D = icon

	match color_type:
		"damage":
			color = Color(1.0, 0.25, 0.25)
			if status_icon == null:
				status_icon = INTENT_ICON_ATTACK
		"heal":
			color = Color(0.35, 1.0, 0.45)
			if status_icon == null:
				status_icon = INTENT_ICON_HEAL
		"block_gain":
			color = Color(0.45, 0.85, 1.0)
			if status_icon == null:
				status_icon = INTENT_ICON_BLOCK
		"block_loss":
			color = Color(0.7, 0.8, 0.95)
			if status_icon == null:
				status_icon = INTENT_ICON_BLOCK
		"critical":
			color = Color(1.0, 0.7, 0.15)
			if status_icon == null:
				status_icon = FLOAT_ICON_CRIT
		"curse":
			color = Color(0.85, 0.35, 1.0)
		"frost":
			color = Color(0.45, 0.9, 1.0)
			if status_icon == null:
				status_icon = StatusIcons.get_icon("Slow")
		"ember":
			color = Color(1.0, 0.45, 0.12)
			if status_icon == null:
				status_icon = StatusIcons.get_icon("burning")
		_:
			color = Color.WHITE

	var canvas = get_tree().root.find_child("CanvasLayer", true, false)
	if canvas:
		canvas.add_child(instance)
		var float_size: Vector2 = await instance.prepare(text_to_show, color, status_icon)
		var camera = get_viewport().get_camera_3d()
		if camera:
			var world_pos_above_unit = global_position + Vector3(0, 1.5, 0)
			var screen_pos = camera.unproject_position(world_pos_above_unit)
			var camera_forward = -camera.global_transform.basis.z
			var to_unit = (world_pos_above_unit - camera.global_position).normalized()
			var is_in_front = camera_forward.dot(to_unit) > 0
			var viewport_size = get_viewport().get_visible_rect().size
			var margin = 50
			if is_in_front and \
			   screen_pos.x >= -margin and screen_pos.x <= viewport_size.x + margin and \
			   screen_pos.y >= -margin and screen_pos.y <= viewport_size.y + margin:
				instance.position = screen_pos + Vector2(-float_size.x * 0.5, -40)
			else:
				instance.position = viewport_size * 0.5 + Vector2(0, -100)
		else:
			var viewport_size = get_viewport().get_visible_rect().size
			instance.position = viewport_size * 0.5
		instance.animate()
	else:
		instance.queue_free()

func start_turn() -> int:
	print(TranslationHelper.tr_format("log.unit.turn_start", {"name": unit_data.get_localized_name()}))
	_has_acted_this_turn = false
	reset_for_new_turn()
	var extra_draw = await process_turn_start_statuses()
	return extra_draw

func end_turn() -> void:
	print(TranslationHelper.tr_format("log.unit.turn_end", {"name": unit_data.get_localized_name()}))
	await process_turn_end_statuses()

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
	"""Serializuje aktuální intent(y) pro RPC."""
	var intents_payload: Array = []
	for item in current_intents:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		intents_payload.append({
			"id": str(item.get("id", "")),
			"text": str(item.get("text", "")),
			"short_text": str(item.get("short_text", "")),
			"countdown": int(item.get("countdown", 0)),
		})
	return {
		"id": current_intent_id,
		"text": current_intent_text,
		"short_text": current_intent_short,
		"intents": intents_payload,
	}

func apply_intent_from_data(data: Dictionary):
	"""Aplikuje intent přijatý od hosta (1 nebo 2 ikony)."""
	current_intents.clear()
	var raw_intents = data.get("intents", [])
	if typeof(raw_intents) == TYPE_ARRAY and not raw_intents.is_empty():
		for item in raw_intents:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			current_intents.append(_make_intent_entry(
				str(item.get("id", "")),
				str(item.get("short_text", "")),
				str(item.get("text", "")),
				int(item.get("countdown", 0))
			))
			if current_intents.size() >= 2:
				break
	else:
		var single_id := str(data.get("id", ""))
		if not single_id.is_empty():
			current_intents.append(_make_intent_entry(
				single_id,
				str(data.get("short_text", "")),
				str(data.get("text", ""))
			))
	_sync_primary_intent_aliases()
	_refresh_intent_row_ui()

func serialize_ai_meta() -> Dictionary:
	"""Serializuje AI meta data pro RPC (berserker, mage, boss stav)."""
	var meta: Dictionary = {}
	meta["is_permanently_enraged"] = is_permanently_enraged
	meta["berserker_frustration"] = berserker_frustration
	meta["ritual_stacks"] = ritual_stacks
	meta["pack_attack_bonus"] = pack_attack_bonus
	meta["is_aiming"] = is_aiming
	if has_meta("boss_phase"):
		meta["boss_phase"] = int(get_meta("boss_phase"))
	if has_meta("boss_turn_count"):
		meta["boss_turn_count"] = int(get_meta("boss_turn_count"))
	if has_meta("mage_turn_count"):
		meta["mage_turn_count"] = int(get_meta("mage_turn_count"))
	if has_meta("spell_index"):
		meta["spell_index"] = int(get_meta("spell_index"))
	if has_meta("slam_cooldown"):
		meta["slam_cooldown"] = int(get_meta("slam_cooldown"))
	if has_meta("earth_moved_last"):
		meta["earth_moved_last"] = bool(get_meta("earth_moved_last"))
	return meta

func apply_ai_meta(meta: Dictionary):
	"""Aplikuje AI meta data přijatá od hosta."""
	is_permanently_enraged = meta.get("is_permanently_enraged", false)
	berserker_frustration = int(meta.get("berserker_frustration", 0))
	ritual_stacks = int(meta.get("ritual_stacks", 0))
	pack_attack_bonus = int(meta.get("pack_attack_bonus", 0))
	is_aiming = meta.get("is_aiming", false)
	if meta.has("boss_phase"):
		set_meta("boss_phase", int(meta["boss_phase"]))
	if meta.has("boss_turn_count"):
		set_meta("boss_turn_count", int(meta["boss_turn_count"]))
	if meta.has("mage_turn_count"):
		set_meta("mage_turn_count", int(meta["mage_turn_count"]))
	if meta.has("spell_index"):
		set_meta("spell_index", int(meta["spell_index"]))
	if meta.has("slam_cooldown"):
		set_meta("slam_cooldown", int(meta["slam_cooldown"]))
	if meta.has("earth_moved_last"):
		set_meta("earth_moved_last", bool(meta["earth_moved_last"]))
