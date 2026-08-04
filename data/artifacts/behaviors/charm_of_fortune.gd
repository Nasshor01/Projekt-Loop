extends ArtifactBehavior

const SHOP_DISCOUNT_PERCENT := 12
const FREE_CHANCE := 0.08
const GOLD_BONUS_CHANCE := 0.15
const GOLD_BONUS_PERCENT := 25


func modify_shop_price(_ctx: Dictionary, price: int) -> int:
	var discounted := int(float(price) * (100.0 - SHOP_DISCOUNT_PERCENT) / 100.0)
	if randf() < FREE_CHANCE:
		return 0
	return discounted


func modify_gold_reward(_ctx: Dictionary, gold: int) -> int:
	if randf() < GOLD_BONUS_CHANCE:
		return gold + int(float(gold) * GOLD_BONUS_PERCENT / 100.0)
	return gold
