# Soubor: scenes/ui/MainMenu.gd
extends Control

@onready var title_label: Label = $Label
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var load_run_button: Button = %LoadRunButton
@onready var multiplayer_button: Button = $VBoxContainer/MultiplayerButton
@onready var tutorial_button: Button = $VBoxContainer/TutorialButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton
@onready var version_label: Label = $VersionLabel

# Multiplayer panel
@onready var mp_panel: PanelContainer = $MultiplayerPanel
@onready var mp_nickname_edit: LineEdit = $MultiplayerPanel/MarginContainer/VBoxContainer/NicknameEdit
@onready var mp_ip_edit: LineEdit = $MultiplayerPanel/MarginContainer/VBoxContainer/IPEdit
@onready var mp_port_edit: LineEdit = $MultiplayerPanel/MarginContainer/VBoxContainer/PortEdit
@onready var mp_status_label: Label = $MultiplayerPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var mp_host_button: Button = $MultiplayerPanel/MarginContainer/VBoxContainer/ButtonsHBox/HostButton
@onready var mp_join_button: Button = $MultiplayerPanel/MarginContainer/VBoxContainer/ButtonsHBox/JoinButton
@onready var mp_back_button: Button = $MultiplayerPanel/MarginContainer/VBoxContainer/BackButton

func _enter_tree():
	add_to_group("main_menu")

func _ready():
	play_button.pressed.connect(GameManager.go_to_character_select)
	load_run_button.pressed.connect(_on_load_run_button_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	tutorial_button.pressed.connect(GameManager.go_to_tutorial)
	settings_button.pressed.connect(GameManager.go_to_settings)
	exit_button.pressed.connect(func():
		if has_node("/root/DebugLogger"):
			DebugLogger.mark_quitting_legally()
		get_tree().quit()
	)

	mp_host_button.pressed.connect(_on_mp_host_pressed)
	mp_join_button.pressed.connect(_on_mp_join_pressed)
	mp_back_button.pressed.connect(_on_mp_back_pressed)

	if has_node("/root/MultiplayerManager"):
		MultiplayerManager.connection_succeeded.connect(_on_multiplayer_connection_succeeded)
		MultiplayerManager.connection_failed.connect(_on_multiplayer_connection_failed)

	_update_load_button_state()
	_update_ui_texts()
	_update_tutorial_gate()
	_update_version_label()

func _update_ui_texts():
	if title_label:
		title_label.text = tr("game.title")
	if play_button:
		play_button.text = tr("ui.main_menu.new_game")
	if tutorial_button:
		tutorial_button.text = tr("ui.main_menu.tutorial")
	if settings_button:
		settings_button.text = tr("ui.main_menu.settings")
	if exit_button:
		exit_button.text = tr("ui.main_menu.exit")
	if load_run_button:
		load_run_button.text = tr("ui.main_menu.load_run")
	if multiplayer_button:
		multiplayer_button.text = tr("ui.main_menu.multiplayer")

func _update_tutorial_gate():
	var completed = SaveManager.is_tutorial_completed()
	if play_button:
		play_button.disabled = not completed

func _update_version_label():
	if version_label:
		var version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
		version_label.text = "Pre-Alpha " + version

func _on_load_run_button_pressed():
	if not SaveManager.has_saved_run():
		print(tr("ui.main_menu.no_saved_run"))
		return
	GameManager.load_and_start_saved_run()

func _update_load_button_state():
	if not is_instance_valid(load_run_button):
		return
	load_run_button.disabled = not SaveManager.has_saved_run()

# ==================== MULTIPLAYER PANEL ====================

func _on_multiplayer_pressed():
	mp_panel.visible = true
	mp_status_label.text = ""
	mp_host_button.disabled = false
	mp_join_button.disabled = false
	# Prefill port
	if mp_port_edit.text.is_empty():
		mp_port_edit.text = str(MultiplayerManager.DEFAULT_PORT)

func _on_mp_back_pressed():
	mp_panel.visible = false
	mp_status_label.text = ""

func _on_mp_host_pressed():
	var port = mp_port_edit.text.to_int()
	if port <= 0 or port > 65535:
		mp_status_label.text = "Invalid port (1–65535)."
		mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	
	var nickname = mp_nickname_edit.text.strip_edges()
	if nickname.is_empty():
		nickname = "Host"
	GameManager.coop_my_nickname = nickname
	
	if MultiplayerManager.start_host(port):
		mp_status_label.text = "Hosting on port %d... Waiting for player." % port
		mp_status_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		mp_host_button.disabled = true
		mp_join_button.disabled = true
		# Host přejde do lobby až se připojí klient (viz _on_peer_connected)
		if has_node("/root/MultiplayerManager"):
			if not MultiplayerManager.peer_connected.is_connected(_on_mp_peer_connected):
				MultiplayerManager.peer_connected.connect(_on_mp_peer_connected)
	else:
		mp_status_label.text = "Failed to host (port %d may be in use)." % port
		mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

func _on_mp_join_pressed():
	var ip = mp_ip_edit.text.strip_edges()
	var port = mp_port_edit.text.to_int()
	if ip.is_empty():
		mp_status_label.text = "Enter IP address."
		mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	if port <= 0 or port > 65535:
		mp_status_label.text = "Invalid port (1–65535)."
		mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	
	var nickname = mp_nickname_edit.text.strip_edges()
	if nickname.is_empty():
		nickname = "Client"
	GameManager.coop_my_nickname = nickname
	
	mp_status_label.text = "Connecting to %s:%d..." % [ip, port]
	mp_status_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	mp_host_button.disabled = true
	mp_join_button.disabled = true
	MultiplayerManager.join(ip, port)

func _on_mp_peer_connected(_peer_id: int, _name: String):
	# Host: klient se připojil -> přejdi do lobby
	GameManager.go_to_lobby()

func _on_multiplayer_connection_succeeded():
	mp_panel.visible = false
	GameManager.go_to_lobby()

func _on_multiplayer_connection_failed():
	mp_status_label.text = "Connection failed. Check IP, port, and VPN."
	mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	mp_host_button.disabled = false
	mp_join_button.disabled = false
