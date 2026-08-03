extends ArtifactBehavior

func modify_shop_price(price: int, _item = null) -> int:
	var p := int(round(float(price) * 0.88))
	if randf() < 0.08:
		notify_triggered("Charm of Fortune: free!")
		return 0
	return p

func modify_gold_reward(gold: int) -> int:
	if randf() < 0.15:
		notify_triggered("Charm of Fortune: +25% gold")
		return int(round(float(gold) * 1.25))
	return gold
