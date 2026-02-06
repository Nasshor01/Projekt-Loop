# Soubor: scenes/ui/EndOfRunScreen.gd (OPRAVENÁ VERZE)
extends Control

# Proměnné pro uložení výsledku běhu
var xp_earned: int = 0
var run_was_a_victory: bool = false

@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var xp_label: Label = $VBoxContainer/XPLabel
@onready var play_again_button: Button = $VBoxContainer/PlayAgainButton
@onready var end_run_button: Button = $VBoxContainer/EndRunButton

# Tuto funkci stále volá GameManager, aby nám předal data
func setup(p_xp_earned: int, p_run_was_a_victory: bool):
	self.xp_earned = p_xp_earned
	self.run_was_a_victory = p_run_was_a_victory

	# Zobrazíme správné texty
	if run_was_a_victory:
		result_label.text = tr("ui.end_run.victory")
		play_again_button.text = tr("ui.end_run.play_again_ng")
	else:
		result_label.text = tr("ui.end_run.defeat")
		play_again_button.text = tr("ui.end_run.play_again")
		
	xp_label.text = TranslationHelper.tr_format("ui.end_run.xp", {"value": xp_earned})
	end_run_button.text = tr("ui.end_run.main_menu")
	
	# Připojíme signály k tlačítkům
	play_again_button.pressed.connect(_on_play_again_pressed)
	end_run_button.pressed.connect(GameManager.go_to_main_menu)

# PŘIDÁNO: Funkce _ready() se zavolá AUTOMATICKY AŽ POTÉ, co jsou všechny @onready var načtené
func _ready():
	pass

func _on_play_again_pressed():
	# Podle výsledku běhu zavoláme správnou funkci
	if run_was_a_victory:
		GameManager.start_new_game_plus()
	else:
		GameManager.start_new_run()
