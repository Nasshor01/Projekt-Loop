extends ArtifactBehavior

const ALCHEMY_POOL: Array[String] = [
	"res://data/cards/alchemy/alchemy_vial.tres",
	"res://data/cards/alchemy/alchemy_tonic.tres",
	"res://data/cards/alchemy/alchemy_spark.tres",
	"res://data/cards/alchemy/alchemy_reagent.tres",
]
const PROMPT_ID := "alchemist_discard"


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	runtime["discard_pick_pending"] = true


func on_hand_ready(_ctx: Dictionary = {}) -> void:
	if not runtime.get("discard_pick_pending", false):
		return
	runtime["discard_pick_pending"] = false
	if not PlayerData or PlayerData.current_hand.is_empty():
		return
	if not _root_has_node("/root/ArtifactManager"):
		return
	ArtifactManager.set_run_flag("pending_alchemist_discard", true)


func on_prompt_result(prompt_id: String, result: Dictionary) -> void:
	if prompt_id != PROMPT_ID:
		return
	if not bool(result.get("accepted", false)):
		return
	var discard: CardData = result.get("card") as CardData
	if discard == null or not PlayerData or not PlayerData.current_hand.has(discard):
		return
	PlayerData.current_hand.erase(discard)
	PlayerData.add_card_to_discard_pile(discard)
	_grant_temp_card()


func on_turn_end(_ctx: Dictionary = {}) -> void:
	_exhaust_temp_cards()


func _grant_temp_card() -> void:
	if ALCHEMY_POOL.is_empty() or not PlayerData:
		return
	var path: String = ALCHEMY_POOL[randi_range(0, ALCHEMY_POOL.size() - 1)]
	var template: CardData = load(path) as CardData
	if template == null:
		return
	var card: CardData = template.duplicate(true)
	card.set_meta("alchemy_temp", true)
	PlayerData.current_hand.append(card)
	runtime["temp_cards"] = runtime.get("temp_cards", []) + [card]


func _exhaust_temp_cards() -> void:
	if not PlayerData:
		return
	var temps: Array = runtime.get("temp_cards", []) as Array
	for card_v in temps:
		var card: CardData = card_v as CardData
		if card == null:
			continue
		if PlayerData.current_hand.has(card):
			PlayerData.current_hand.erase(card)
			PlayerData.add_card_to_exhaust_pile(card)
	runtime["temp_cards"] = []
