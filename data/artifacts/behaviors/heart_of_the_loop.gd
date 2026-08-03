extends ArtifactBehavior

const LOOP_INTERVAL := 4
const LOW_HP_THRESHOLD_PERCENT := 25
const SKIP_ENEMY_USES := 1


func on_combat_start(ctx: Dictionary = {}) -> void:
	if PlayerData:
		PlayerData.gain_energy(1)
	runtime["skip_enemy_uses"] = 0


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var turn := _get_turn_number(ctx)
	if turn > 0 and turn % LOOP_INTERVAL == 0:
		_repeat_last_attack(ctx)
	_check_low_hp_skip(ctx)


func on_card_played(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if card and _card_is_attack(card):
		runtime["last_attack_card_id"] = card.card_id
		runtime["last_attack_base_damage"] = _estimate_card_damage(card)


func _repeat_last_attack(ctx: Dictionary) -> void:
	var card_id := String(runtime.get("last_attack_card_id", ""))
	if card_id.is_empty():
		return
	var damage := int(runtime.get("last_attack_base_damage", 0))
	if damage <= 0:
		return
	var enemy := _random_living_enemy()
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(damage, true, false, false)
	ctx["repeated_attack"] = card_id


func _estimate_card_damage(card: CardData) -> int:
	for effect in card.effects:
		if effect.effect_type == CardEffectData.EffectType.DEAL_DAMAGE:
			return effect.value
	return 0


func _check_low_hp_skip(ctx: Dictionary) -> void:
	if not PlayerData:
		return
	if int(runtime.get("skip_enemy_uses", 0)) >= SKIP_ENEMY_USES:
		return
	var pct := PlayerData.current_hp * 100 / maxi(1, PlayerData.max_hp)
	if pct <= LOW_HP_THRESHOLD_PERCENT:
		ctx["skip_enemy_turn"] = true
		runtime["skip_enemy_uses"] = int(runtime.get("skip_enemy_uses", 0)) + 1
