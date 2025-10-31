extends CanvasLayer

@onready var hp_label: Label = $MainPanel/MarginContainer/MainLayout/LeftSection/HPDisplay/HPLabel
@onready var gold_label: Label = $MainPanel/MarginContainer/MainLayout/CenterSection/GoldDisplay/GoldLabel
@onready var floor_label: Label = $MainPanel/MarginContainer/MainLayout/CenterSection/FloorDisplay/FloorLabel
@onready var ng_plus_label: Label = $MainPanel/MarginContainer/MainLayout/CenterSection/NGPlusDisplay/NGPlusLabel
@onready var deck_button: Button = $MainPanel/MarginContainer/MainLayout/RightSection/DeckButton
@onready var menu_button: Button = $MainPanel/MarginContainer/MainLayout/RightSection/MenuButton


func _ready():
	# Připojení na signály z PlayerData
	PlayerData.health_changed.connect(_on_health_changed)
	PlayerData.gold_changed.connect(_on_gold_changed)
	PlayerData.floor_changed.connect(_on_floor_changed)
	PlayerData.ng_plus_changed.connect(_on_ng_plus_changed)

	# Připojení tlačítek
	deck_button.pressed.connect(_on_deck_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

	# Nastavení počátečních hodnot
	_on_health_changed(PlayerData.current_hp, PlayerData.max_hp)
	_on_gold_changed(PlayerData.gold)
	_on_floor_changed(PlayerData.floors_cleared)
	_on_ng_plus_changed(PlayerData.ng_plus_level)
	_update_deck_button()


func _on_health_changed(new_hp: int, new_max_hp: int):
	if is_instance_valid(hp_label):
		hp_label.text = "HP: %d/%d" % [new_hp, new_max_hp]


func _on_gold_changed(new_amount: int):
	if is_instance_valid(gold_label):
		gold_label.text = "Zlato: %d" % new_amount


func _on_floor_changed(new_floor: int):
	if is_instance_valid(floor_label):
		# Přidáme +1, protože floors_cleared je 0 na prvním patře
		floor_label.text = "Patro: %d" % (new_floor + 1)


func _on_ng_plus_changed(new_level: int):
	if is_instance_valid(ng_plus_label):
		if new_level > 0:
			ng_plus_label.text = "NG+ %d" % new_level
		else:
			ng_plus_label.text = "Normal"


func _update_deck_button():
	if is_instance_valid(deck_button):
		deck_button.text = "Balíček (%d)" % PlayerData.master_deck.size()


func _on_deck_button_pressed():
	print("Tlačítko 'Balíček' bylo stisknuto. Zde se otevře obrazovka s balíčkem.")
	# TODO: Implementovat zobrazení balíčku karet


func _on_menu_button_pressed():
	print("Tlačítko 'Menu' bylo stisknuto. Zde se otevře hlavní menu.")
	# TODO: Implementovat zobrazení menu
