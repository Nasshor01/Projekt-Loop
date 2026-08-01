extends CanvasLayer

## Emitován při zavření v overlay režimu (během runu) – GlobalUI zavře popup a unpause
signal overlay_closed

var _overlay_mode: bool = false

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var language_label: Label = $Panel/VBoxContainer/LanguageSection/LanguageLabel
@onready var language_option: OptionButton = %LanguageOptionButton
@onready var reports_checkbox: CheckBox = %ReportsCheckBox
@onready var fullscreen_checkbox: CheckBox = %FullscreenCheckBox
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var current_locale: String = "en"

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	language_option.item_selected.connect(_on_language_selected)
	reports_checkbox.toggled.connect(_on_reports_toggled)
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	
	_setup_language_options()
	_load_current_language()
	_load_report_preference()
	_load_fullscreen_preference()
	_load_music_volume()
	_load_sfx_volume()
	_update_ui_texts()

func _setup_language_options():
	"""Nastaví možnosti jazyka v OptionButton"""
	language_option.clear()
	language_option.add_item(tr("ui.settings.lang.english"), 0)
	language_option.add_item(tr("ui.settings.lang.czech"), 1)
	language_option.set_item_metadata(0, "en")
	language_option.set_item_metadata(1, "cs")

func _load_current_language():
	"""Načte aktuální jazyk a nastaví OptionButton"""
	# Nejdřív zkusíme načíst z uložených preferencí
	var saved_locale = _load_language_preference()
	if saved_locale != "":
		TranslationServer.set_locale(saved_locale)
		current_locale = saved_locale
	else:
		current_locale = TranslationServer.get_locale()
	
	# Nastavíme OptionButton
	if current_locale.begins_with("cs"):
		language_option.selected = 1
	else:
		language_option.selected = 0

func _on_language_selected(index: int):
	"""Změna jazyka"""
	var locale = language_option.get_item_metadata(index)
	if locale != current_locale:
		TranslationServer.set_locale(locale)
		current_locale = locale
		# Uložíme preferenci jazyka
		_save_language_preference(locale)
		_update_ui_texts()
		# Aktualizujeme i MainMenu, pokud je viditelný
		_update_main_menu_if_visible()

func _save_language_preference(locale: String):
	"""Uloží preferenci jazyka do ConfigFile"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		config = ConfigFile.new()
	config.set_value("settings", "language", locale)
	config.save("user://settings.cfg")

func _load_language_preference() -> String:
	"""Načte preferenci jazyka z ConfigFile"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		return config.get_value("settings", "language", "en")
	return "en"

func _update_ui_texts():
	"""Aktualizuje UI texty pomocí překladů"""
	if title_label:
		title_label.text = tr("ui.settings.title")
	if language_label:
		language_label.text = tr("ui.settings.language")
	if close_button:
		close_button.text = tr("ui.settings.close")
	if reports_checkbox:
		reports_checkbox.text = tr("ui.settings.reports_checkbox")
		reports_checkbox.tooltip_text = tr("ui.settings.reports_tooltip")
	if fullscreen_checkbox:
		fullscreen_checkbox.text = tr("ui.settings.fullscreen")
		fullscreen_checkbox.tooltip_text = tr("ui.settings.fullscreen_tooltip")
	# Music volume label - optional, slider shows value
	if $Panel/VBoxContainer/MusicSection.has_node("MusicVolumeLabel"):
		$Panel/VBoxContainer/MusicSection/MusicVolumeLabel.text = tr("ui.settings.music_volume")
	if $Panel/VBoxContainer.has_node("SfxSection") and $Panel/VBoxContainer/SfxSection.has_node("SfxVolumeLabel"):
		$Panel/VBoxContainer/SfxSection/SfxVolumeLabel.text = tr("ui.settings.sfx_volume")

func _load_music_volume():
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK and cfg.has_section_key("settings", "music_volume"):
		var v = cfg.get_value("settings", "music_volume", 100)
		music_volume_slider.value = v
	elif has_node("/root/MusicManager"):
		music_volume_slider.value = int(MusicManager.get_volume_linear() * 100)

func _on_music_volume_changed(value: float):
	if has_node("/root/MusicManager"):
		MusicManager.set_volume_linear(value / 100.0)
	var cfg = ConfigFile.new()
	var _err = cfg.load("user://settings.cfg")
	cfg.set_value("settings", "music_volume", int(value))
	cfg.save("user://settings.cfg")

func _load_sfx_volume():
	if not sfx_volume_slider:
		return
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK and cfg.has_section_key("settings", "sfx_volume"):
		sfx_volume_slider.value = cfg.get_value("settings", "sfx_volume", 100)
	elif has_node("/root/AudioManager"):
		sfx_volume_slider.value = int(AudioManager.get_volume_linear() * 100)

func _on_sfx_volume_changed(value: float):
	if has_node("/root/AudioManager"):
		AudioManager.set_volume_linear(value / 100.0)
	var cfg = ConfigFile.new()
	var _err = cfg.load("user://settings.cfg")
	cfg.set_value("settings", "sfx_volume", int(value))
	cfg.save("user://settings.cfg")

func _update_main_menu_if_visible():
	"""Aktualizuje MainMenu texty, pokud je viditelný"""
	# Najdeme MainMenu přes skupinu
	var main_menu_nodes = get_tree().get_nodes_in_group("main_menu")
	for main_menu in main_menu_nodes:
		if main_menu and main_menu.has_method("_update_ui_texts"):
			main_menu._update_ui_texts()
			break

func _on_close_pressed():
	hide()
	if _overlay_mode:
		_overlay_mode = false
		emit_signal("overlay_closed")
		get_tree().paused = false
	else:
		GameManager.go_to_main_menu()

func show_settings():
	show()
	_load_current_language()
	_load_report_preference()
	_load_fullscreen_preference()
	_load_music_volume()
	_load_sfx_volume()

func _on_reports_toggled(value: bool):
	if has_node("/root/DebugLogger"):
		DebugLogger.apply_report_consent(value)
	else:
		_save_report_preference(value)

func _load_report_preference():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	var value = true
	if err == OK and config.has_section_key("settings", "can_send_reports"):
		value = bool(config.get_value("settings", "can_send_reports", true))
	if reports_checkbox:
		reports_checkbox.button_pressed = value

func _save_report_preference(value: bool):
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		config = ConfigFile.new()
	config.set_value("settings", "can_send_reports", value)
	config.save("user://settings.cfg")

func _load_fullscreen_preference():
	var fullscreen = _get_saved_fullscreen()
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = fullscreen
	_apply_fullscreen(fullscreen)

func _get_saved_fullscreen() -> bool:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK and config.has_section_key("settings", "fullscreen"):
		return bool(config.get_value("settings", "fullscreen", false))
	return false

func _apply_fullscreen(fullscreen: bool):
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_fullscreen_toggled(checked: bool):
	_apply_fullscreen(checked)
	_save_fullscreen_preference(checked)

func _save_fullscreen_preference(value: bool):
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		config = ConfigFile.new()
	config.set_value("settings", "fullscreen", value)
	config.save("user://settings.cfg")

func show_as_overlay():
	"""Zobrazí Settings jako overlay během runu (z popup menu). Při zavření vrátí do hry."""
	_overlay_mode = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	show_settings()

func hide_settings():
	hide()
