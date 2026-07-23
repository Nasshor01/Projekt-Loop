# Minimální coop lobby: host čeká na hráče, klient čeká na start.
extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready():
	start_button.visible = MultiplayerManager.is_server()
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)

	MultiplayerManager.peer_connected.connect(_on_peer_connected)
	MultiplayerManager.peer_disconnected.connect(_on_peer_disconnected)
	MultiplayerManager.server_disconnected.connect(_on_server_disconnected)

	_update_status()

func _update_status():
	if MultiplayerManager.is_server():
		var peers = MultiplayerManager.get_connected_peers()
		if peers.is_empty():
			status_label.text = "Čekám na hráče…"
		else:
			status_label.text = "Hráč 2 připojen."
		start_button.disabled = peers.is_empty()
	else:
		status_label.text = "Připojeno. Čekej na start."

func _on_peer_connected(_peer_id: int, _name: String):
	_update_status()

func _on_peer_disconnected(_peer_id: int):
	_update_status()

func _on_server_disconnected():
	GameManager.go_to_main_menu()

func _on_start_pressed():
	# Bod 3+4: host spustí coop run (seed + sync), pak oba přejdou na výběr postavy
	GameManager.start_coop_run()
	GameManager.go_to_character_select()
	rpc("_rpc_go_to_character_select")

@rpc("any_peer")
func _rpc_go_to_character_select():
	# Pouze na klientovi: přechod na výběr postavy (host už přešel lokálně)
	GameManager.go_to_character_select()

func _on_back_pressed():
	MultiplayerManager.close_connection()
	GameManager.go_to_main_menu()
