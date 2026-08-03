extends ArtifactBehavior

const ALCHEMY_POOL: Array[String] = [
	"res://data/cards/paladin/lesser_heal.tres",
	"res://data/cards/paladin/holy_shield.tres",
	"res://data/cards/paladin/holy_strike.tres",
	"res://data/cards/paladin/divine_grace.tres",
]


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	runtime["discard_pick_pending"] = true


func on_hand_ready(ctx: Dictionary = {}) -> void:
	if not runtime.get("discard_pick_pending", false):
		return
	runtime["discard_pick_pending"] = false
	if not PlayerData or PlayerData.current_hand.is_empty():
		return
	# Best-effort auto-discard without UI prompt.
	var discard: CardData = PlayerData.current_hand.pick_random() as CardData
	PlayerData.current_hand.erase(discard)
	PlayerData.add_card_to_discard_pile(discard)
	_grant_temp_card()


func on_turn_end(ctx: Dictionary = {}) -> void:
	_exhaust_temp_cards()


func _grant_temp_card() -> void:
	for path in ALCHEMY_POOL:
		var card: CardData = load(path) as CardData
		if card != null:
			PlayerData.current_hand.append(card.duplicate())
			runtime["temp_cards"] = runtime.get("temp_cards", []) + [card.card_id]
			return


func _exhaust_temp_cards() -> void:
	if not PlayerData:
		return
	var temp_ids: Array = runtime.get("temp_cards", []) as Array
	for card_v in PlayerData.current_hand.duplicate():
		var card: CardData = card_v as CardData
		if card != null and temp_ids.has(card.card_id):
			PlayerData.current_hand.erase(card)
			PlayerData.add_card_to_exhaust_pile(card)
	runtime["temp_cards"] = []
