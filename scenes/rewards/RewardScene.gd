# Soubor: scenes/rewards/RewardScene.gd (KOMPLETNĚ NOVÁ VERZE)
extends PanelContainer

var gold_reward: int = 0

# Načteme si náš nový, spravovatelný pool karet
const CARD_REWARD_POOL = preload("res://data/cards/reward_card_pool.tres")

@onready var card_container = $VBoxContainer/CardContainer
@onready var gold_label: Label = $VBoxContainer/GoldRewardDisplay/GoldLabel
# PŘIDÁNO: Cesta k novému tlačítku
@onready var skip_button: Button = $VBoxContainer/SkipButton

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")
const NUM_CARD_CHOICES = 3

func _ready():
	PlayerData.add_gold(gold_reward)
	gold_label.text = "Získáno zlata: %d" % gold_reward
	
	# PŘIDÁNO: Tlačítko Přeskočit teď funguje jako tlačítko Pokračovat
	# Místo něj deaktivujeme a skrýváme CardContainer
	skip_button.pressed.connect(GameManager.reward_chosen)
	
	# Vygenerujeme karty z poolu
	var available_cards = CARD_REWARD_POOL.cards.duplicate()
	available_cards.shuffle()
	
	var card_choices = available_cards.slice(0, NUM_CARD_CHOICES)
	
	for card_data in card_choices:
		var card_ui = CardUIScene.instantiate()
		card_container.add_child(card_ui)
		card_ui.load_card(card_data)
		card_ui.gui_input.connect(_on_card_selected.bind(card_data))

func _on_card_selected(event: InputEvent, card_to_add: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("Karta vybrána: ", card_to_add.card_name)
		
		PlayerData.master_deck.append(card_to_add)
		
		# Po výběru karty rovnou přejdeme na mapu
		GameManager.reward_chosen()
