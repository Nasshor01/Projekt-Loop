# Soubor: scenes/ui/MainMenu.gd
extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var village_button: Button = %VillageButton
@onready var load_run_button: Button = %LoadRunButton
@onready var multiplayer_button: Button = $VBoxContainer/MultiplayerButton
@onready var tutorial_button: Button = $VBoxContainer/TutorialButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var credits_button: Button = %CreditsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton
@onready var version_label: Label = $VersionLabel

# Multiplayer panel
@onready var mp_panel: PanelContainer = $MultiplayerPanel
@onready var mp_title_label: Label = $MultiplayerPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var mp_nickname_label: Label = $MultiplayerPanel/MarginContainer/VBoxContainer/NicknameLabel
@onready var mp_nickname_edit: LineEdit = $MultiplayerPanel/MarginContainer/VBoxContainer/NicknameEdit
@onready var mp_ip_label: Label = $MultiplayerPanel/MarginContainer/VBoxContainer/IPLabel
@onready var mp_ip_edit: LineEdit = $MultiplayerPanel/MarginContainer/VBoxContainer/IPEdit
@onready var mp_port_label: Label = $MultiplayerPanel/MarginContainer/VBoxContainer/PortLabel
@onready var mp_port_edit: LineEdit = $MultiplayerPanel/MarginContainer/VBoxContainer/PortEdit
@onready var mp_status_label: Label = $MultiplayerPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var mp_host_button: Button = $MultiplayerPanel/MarginContainer/VBoxContainer/ButtonsHBox/HostButton
@onready var mp_join_button: Button = $MultiplayerPanel/MarginContainer/VBoxContainer/ButtonsHBox/JoinButton
@onready var mp_back_button: Button = $MultiplayerPanel/MarginContainer/VBoxContainer/BackButton

# Credits panel — easy to extend with more sections/names later
const CREDITS_SECTIONS := [
	{
		"title_key": "ui.credits.trapper_challenge",
		"names": ["TheMoonIsFurious"],
	},
]

@onready var credits_panel: PanelContainer = %CreditsPanel
@onready var credits_title_label: Label = %CreditsTitleLabel
@onready var credits_special_thanks_label: Label = %CreditsSpecialThanksLabel
@onready var credits_body_label: Label = %CreditsBodyLabel
@onready var credits_back_button: Button = %CreditsBackButton

func _enter_tree():
	add_to_group("main_menu")

func _ready():
	play_button.pressed.connect(GameManager.go_to_character_select)
	if village_button:
		village_button.pressed.connect(GameManager.go_to_village)
	load_run_button.pressed.connect(_on_load_run_button_pressed)
	tutorial_button.pressed.connect(GameManager.go_to_tutorial)
	settings_button.pressed.connect(GameManager.go_to_settings)
	if credits_button:
		credits_button.pressed.connect(_on_credits_pressed)
	exit_button.pressed.connect(func():
		if has_node("/root/DebugLogger"):
			DebugLogger.mark_quitting_legally()
		get_tree().quit()
	)

	if OS.has_feature("web"):
		if multiplayer_button:
			multiplayer_button.visible = false
			multiplayer_button.disabled = true
		if mp_panel:
			mp_panel.visible = false
	else:
		multiplayer_button.pressed.connect(_on_multiplayer_pressed)
		mp_host_button.pressed.connect(_on_mp_host_pressed)
		mp_join_button.pressed.connect(_on_mp_join_pressed)
		mp_back_button.pressed.connect(_on_mp_back_pressed)
		if has_node("/root/MultiplayerManager"):
			MultiplayerManager.connection_succeeded.connect(_on_multiplayer_connection_succeeded)
			MultiplayerManager.connection_failed.connect(_on_multiplayer_connection_failed)

	if credits_back_button:
		credits_back_button.pressed.connect(_on_credits_back_pressed)

	_update_load_button_state()
	_update_ui_texts()
	_update_tutorial_gate()
	_update_version_label()
	if has_node("/root/MusicManager"):
		MusicManager.play()

func _update_ui_texts():
	if play_button:
		play_button.text = tr("ui.main_menu.new_game")
	if village_button:
		village_button.text = tr("ui.main_menu.village")
	if tutorial_button:
		tutorial_button.text = tr("ui.main_menu.tutorial")
	if settings_button:
		settings_button.text = tr("ui.main_menu.settings")
	if credits_button:
		credits_button.text = tr("ui.main_menu.credits")
	if exit_button:
		exit_button.text = tr("ui.main_menu.exit")
	if load_run_button:
		load_run_button.text = tr("ui.main_menu.load_run")
	if multiplayer_button:
		multiplayer_button.text = tr("ui.main_menu.multiplayer")
	_update_mp_panel_texts()
	_update_credits_texts()

func _update_mp_panel_texts() -> void:
	if mp_title_label:
		mp_title_label.text = tr("ui.main_menu.mp.title")
	if mp_nickname_label:
		mp_nickname_label.text = tr("ui.main_menu.mp.nickname")
	if mp_nickname_edit:
		mp_nickname_edit.placeholder_text = tr("ui.main_menu.mp.nickname_placeholder")
	if mp_ip_label:
		mp_ip_label.text = tr("ui.main_menu.mp.ip")
	if mp_ip_edit:
		mp_ip_edit.placeholder_text = tr("ui.main_menu.mp.ip_placeholder")
	if mp_port_label:
		mp_port_label.text = tr("ui.main_menu.mp.port")
	if mp_host_button:
		mp_host_button.text = tr("ui.main_menu.mp.host")
	if mp_join_button:
		mp_join_button.text = tr("ui.main_menu.mp.join")
	if mp_back_button:
		mp_back_button.text = tr("ui.common.back")

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

# ==================== CREDITS PANEL ====================

func _on_credits_pressed():
	if mp_panel:
		mp_panel.visible = false
	_update_credits_texts()
	if credits_panel:
		credits_panel.visible = true

func _on_credits_back_pressed():
	if credits_panel:
		credits_panel.visible = false

func _update_credits_texts():
	if credits_title_label:
		credits_title_label.text = tr("ui.credits.title")
	if credits_special_thanks_label:
		credits_special_thanks_label.text = tr("ui.credits.special_thanks")
	if credits_back_button:
		credits_back_button.text = tr("ui.common.back")
	if credits_body_label:
		credits_body_label.text = _build_credits_body()

func _build_credits_body() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for section in CREDITS_SECTIONS:
		var title_key: String = str(section.get("title_key", ""))
		if not title_key.is_empty():
			lines.append(tr(title_key))
		var names: Array = section.get("names", [])
		for name in names:
			lines.append("• %s" % str(name))
		lines.append("")
	while lines.size() > 0 and str(lines[lines.size() - 1]).is_empty():
		lines.remove_at(lines.size() - 1)
	return "\n".join(lines)

# ==================== MULTIPLAYER PANEL ====================

func _on_multiplayer_pressed():
	if credits_panel:
		credits_panel.visible = false
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
		mp_status_label.text = tr("ui.main_menu.mp.invalid_port")
		mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	
	var nickname = mp_nickname_edit.text.strip_edges()
	if nickname.is_empty():
		nickname = "Host"
	GameManager.coop_my_nickname = nickname
	
	if MultiplayerManager.start_host(port):
		mp_status_label.text = TranslationHelper.tr_format("ui.main_menu.mp.hosting", {"port": port})
		mp_status_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		mp_host_button.disabled = true
		mp_join_button.disabled = true
		# Host přejde do lobby až se připojí klient (viz _on_peer_connected)
		if has_node("/root/MultiplayerManager"):
			if not MultiplayerManager.peer_connected.is_connected(_on_mp_peer_connected):
				MultiplayerManager.peer_connected.connect(_on_mp_peer_connected)
	else:
		mp_status_label.text = TranslationHelper.tr_format("ui.main_menu.mp.host_failed", {"port": port})
		mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

func _on_mp_join_pressed():
	var ip = mp_ip_edit.text.strip_edges()
	var port = mp_port_edit.text.to_int()
	if ip.is_empty():
		mp_status_label.text = tr("ui.main_menu.mp.enter_ip")
		mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	if port <= 0 or port > 65535:
		mp_status_label.text = tr("ui.main_menu.mp.invalid_port")
		mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	
	var nickname = mp_nickname_edit.text.strip_edges()
	if nickname.is_empty():
		nickname = "Client"
	GameManager.coop_my_nickname = nickname
	
	mp_status_label.text = TranslationHelper.tr_format("ui.main_menu.mp.connecting", {"ip": ip, "port": port})
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
	mp_status_label.text = tr("ui.main_menu.mp.connection_failed")
	mp_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	mp_host_button.disabled = false
	mp_join_button.disabled = false
