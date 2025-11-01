extends ColorRect

# Signály, které menu vysílá, když uživatel klikne na tlačítko.
# GlobalUI.gd se na ně napojí a řekne GameManageru, co má dělat.
signal back_to_game_pressed
signal restart_run_pressed
signal save_run_pressed
signal back_to_char_select_pressed
signal save_and_quit_pressed
signal back_to_menu_pressed

# Přímé reference na tlačítka ve scéně
@onready var restart_run_button = %RestartRunButton
@onready var save_run_button = %SaveRunButton
@onready var back_to_char_select_button = %BackToCharSelectButton
@onready var save_and_quit_button = %SaveAndQuitButton
@onready var back_to_menu_button = %BackToMenuButton
@onready var back_to_game_button = %BackToGameButton

func _ready():
	# Menu je na začátku skryté
	hide()

	# Propojení tlačítek s jejich obslužnými funkcemi
	restart_run_button.pressed.connect(_on_restart_run_pressed)
	save_run_button.pressed.connect(_on_save_run_pressed)
	back_to_char_select_button.pressed.connect(_on_back_to_char_select_pressed)
	save_and_quit_button.pressed.connect(_on_save_and_quit_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	back_to_game_button.pressed.connect(_on_back_to_game_pressed)

func _unhandled_input(event):
	# Pokud je menu viditelné a hráč stiskne 'Esc' (ui_cancel)
	if visible and event.is_action_pressed("ui_cancel"):
		# Zavoláme funkci pro návrat do hry a označíme událost jako zpracovanou,
		# aby se nešířila dál.
		_on_back_to_game_pressed()
		get_viewport().set_input_as_handled()

# --- Funkce volané po stisknutí tlačítek ---

func _on_back_to_game_pressed():
	emit_signal("back_to_game_pressed")
	hide()

func _on_restart_run_pressed():
	emit_signal("restart_run_pressed")
	hide()

func _on_save_run_pressed():
	emit_signal("save_run_pressed")
	hide()

func _on_back_to_char_select_pressed():
	emit_signal("back_to_char_select_pressed")
	hide()

func _on_save_and_quit_pressed():
	emit_signal("save_and_quit_pressed")
	hide()

func _on_back_to_menu_pressed():
	emit_signal("back_to_menu_pressed")
	hide()
