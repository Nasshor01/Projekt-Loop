# Soubor: scenes/ui/EndOfRunScreen.gd (OPRAVENÁ VERZE)
extends Control

# Proměnné pro uložení výsledku běhu
var xp_earned: int = 0
var shards_earned: int = 0
var run_was_a_victory: bool = false

@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var xp_label: Label = $VBoxContainer/XPLabel
@onready var shards_label: Label = $VBoxContainer/ShardsLabel
@onready var play_again_button: Button = $VBoxContainer/PlayAgainButton
@onready var village_button: Button = $VBoxContainer/VillageButton
@onready var end_run_button: Button = $VBoxContainer/EndRunButton

# Tuto funkci stále volá GameManager, aby nám předal data
func setup(p_xp_earned: int, p_run_was_a_victory: bool):
	self.xp_earned = p_xp_earned
	self.run_was_a_victory = p_run_was_a_victory
	self.shards_earned = PlayerData.current_run_shards if has_node("/root/PlayerData") else 0

	# Zobrazíme správné texty
	if run_was_a_victory:
		result_label.text = tr("ui.end_run.victory")
		play_again_button.text = tr("ui.end_run.play_again_ng")
	else:
		result_label.text = tr("ui.end_run.defeat")
		play_again_button.text = tr("ui.end_run.play_again")
		
	xp_label.text = TranslationHelper.tr_format("ui.end_run.xp", {"value": xp_earned})
	if shards_label:
		shards_label.text = TranslationHelper.tr_format("ui.end_run.shards", {"value": shards_earned})
	if village_button:
		village_button.text = tr("ui.end_run.village")
	end_run_button.text = tr("ui.end_run.main_menu")
	
	# Připojíme signály k tlačítkům
	if not play_again_button.pressed.is_connected(_on_play_again_pressed):
		play_again_button.pressed.connect(_on_play_again_pressed)
	if village_button and not village_button.pressed.is_connected(GameManager.go_to_village):
		village_button.pressed.connect(GameManager.go_to_village)
	if not end_run_button.pressed.is_connected(GameManager.go_to_main_menu):
		end_run_button.pressed.connect(GameManager.go_to_main_menu)

func _ready():
	pass

func _on_play_again_pressed():
	if GameManager.tutorial_active:
		GameManager.restart_tutorial()
		return
	# Podle výsledku běhu zavoláme správnou funkci
	if run_was_a_victory:
		GameManager.start_new_game_plus()
	else:
		GameManager.start_new_run()
