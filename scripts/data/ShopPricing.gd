# STS2-inspired shop pricing (deterministic-ish variance per roll).
# Card bands map: Common→STS Common, Rare→STS Uncommon, Epic→STS Rare, Legendary→above Rare.
class_name ShopPricing
extends RefCounted

## Base list prices before variance / sale / artifact modifiers.
const CARD_BASE := {
	CardData.CardRarity.BASIC: 30,
	CardData.CardRarity.COMMON: 50,
	CardData.CardRarity.UNCOMMON: 50, ## deprecated → Common
	CardData.CardRarity.RARE: 75,
	CardData.CardRarity.EPIC: 150,
	CardData.CardRarity.LEGENDARY: 225,
}

## ArtifactType → STS2-ish base (±15% applied in price_artifact).
const ARTIFACT_BASE := {
	ArtifactsData.ArtifactType.COMMON: 175,
	ArtifactsData.ArtifactType.UNCOMMON: 225,
	ArtifactsData.ArtifactType.RARE: 275,
	ArtifactsData.ArtifactType.LEGENDARY: 300,
	ArtifactsData.ArtifactType.CURSED: 150,
	ArtifactsData.ArtifactType.BOSS: 300,
	ArtifactsData.ArtifactType.EVENT: 225,
}

const CARD_VARIANCE := 0.05 ## ±5%
const ARTIFACT_VARIANCE := 0.15 ## ±15%
const SALE_MULT := 0.5

const REMOVAL_BASE := 75
const REMOVAL_INCREMENT := 25


static func card_list_price(rarity: CardData.CardRarity) -> int:
	var base: int = int(CARD_BASE.get(rarity, 50))
	return _vary(base, CARD_VARIANCE)


static func card_sale_price(rarity: CardData.CardRarity) -> int:
	return maxi(1, int(round(float(card_list_price(rarity)) * SALE_MULT)))


static func artifact_price(artifact: ArtifactsData) -> int:
	if artifact == null:
		return 200
	var base: int = int(ARTIFACT_BASE.get(artifact.artifact_type, 200))
	return _vary(base, ARTIFACT_VARIANCE)


static func removal_cost(removals_done: int) -> int:
	return REMOVAL_BASE + REMOVAL_INCREMENT * maxi(0, removals_done)


static func _vary(base: int, variance: float) -> int:
	var mult := randf_range(1.0 - variance, 1.0 + variance)
	return maxi(1, int(round(float(base) * mult)))
