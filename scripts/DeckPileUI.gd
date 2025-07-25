# ===================================================================
# Soubor: res://scenes/ui/DeckPileUI.gd
# POPIS: Skript pro klikatelnou ikonu balíčku.
# ===================================================================
extends TextureButton

@onready var count_label: Label = $CountLabel

func _ready():
	# Signál 'pressed' je vestavěný v TextureButton.
	# Připojíme ho sami k sobě, abychom ho mohli přeposlat dál.
	pressed.connect(_on_pressed)

# Přepošleme signál výše, aby ho BattleScene mohla zachytit.
signal pile_clicked

func _on_pressed():
	emit_signal("pile_clicked")

# Funkce pro aktualizaci počtu karet na popisku.
func update_count(count: int):
	if count_label:
		count_label.text = str(count)
