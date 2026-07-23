# MultiplayerManager – síťová vrstva pro coop (ENet).
# Pouze připojení, peer ID, RPC. Herní logika zůstává v GameManager.
extends Node

const DEFAULT_PORT = 9050

signal connection_succeeded()
signal connection_failed()
signal peer_connected(peer_id: int, name: String)
signal peer_disconnected(peer_id: int)
signal server_disconnected()

var _peer: ENetMultiplayerPeer = null
var _other_peer_id: int = -1

func _ready():
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_host(port: int = DEFAULT_PORT) -> bool:
	if _peer != null:
		close_connection()
	_peer = ENetMultiplayerPeer.new()
	var err = _peer.create_server(port)
	if err != OK:
		push_error("MultiplayerManager: Failed to create server on port %d, error %d" % [port, err])
		return false
	multiplayer.multiplayer_peer = _peer
	_other_peer_id = -1
	print("MultiplayerManager: Host listening on port %d" % port)
	return true


func join(ip: String, port: int = DEFAULT_PORT) -> bool:
	if _peer != null:
		close_connection()
	_peer = ENetMultiplayerPeer.new()
	# IPv6 adresa může obsahovat dvojtečky – ENet v Godot bere host a port zvlášť
	var err = _peer.create_client(ip, port)
	if err != OK:
		push_error("MultiplayerManager: Failed to connect to %s:%d, error %d" % [ip, port, err])
		connection_failed.emit()
		return false
	multiplayer.multiplayer_peer = _peer
	_other_peer_id = 1  # Server je vždy peer_id 1
	print("MultiplayerManager: Connecting to %s:%d" % [ip, port])
	return true


func close_connection():
	if _peer != null:
		multiplayer.multiplayer_peer = null
		_peer.close()
		_peer = null
	_other_peer_id = -1
	print("MultiplayerManager: Disconnected")


func is_server() -> bool:
	return multiplayer.multiplayer_peer != null && multiplayer.is_server()


func get_my_peer_id() -> int:
	return multiplayer.get_unique_id()


func get_other_peer_id() -> int:
	return _other_peer_id


func has_active_connection() -> bool:
	return multiplayer.multiplayer_peer != null && multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func get_connected_peers() -> Array:
	var arr: Array = []
	if multiplayer.multiplayer_peer == null:
		return arr
	for pid in multiplayer.get_peers():
		arr.append(pid)
	return arr


func _on_multiplayer_peer_connected(id: int):
	print("MultiplayerManager: Peer connected: %d" % id)
	_other_peer_id = id
	peer_connected.emit(id, "")


func _on_multiplayer_peer_disconnected(id: int):
	print("MultiplayerManager: Peer disconnected: %d" % id)
	if _other_peer_id == id:
		_other_peer_id = -1
	peer_disconnected.emit(id)


func _on_connected_to_server():
	print("MultiplayerManager: Connected to server")
	connection_succeeded.emit()


func _on_connection_failed():
	print("MultiplayerManager: Connection failed")
	connection_failed.emit()


func _on_server_disconnected():
	print("MultiplayerManager: Server disconnected")
	server_disconnected.emit()
	close_connection()


# --- RPC pro sync seedu a přechod na mapu (volá GameManager) ---

@rpc("any_peer")
func receive_run_seed(seed_val: int):
	if not has_node("/root/GameManager"):
		return
	GameManager.current_seed = seed_val
	GameManager.is_coop_run = true
	seed(seed_val)
	print("MultiplayerManager: Received run seed: %d" % seed_val)

@rpc("any_peer")
func receive_go_to_map():
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_go_to_map()

@rpc("any_peer")
func receive_coop_node_action(node_index: int, action_type: String, encounter_path: String):
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_follow_node(node_index, action_type, encounter_path)

@rpc("any_peer")
func receive_start_battle(encounter_path: String):
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_go_to_battle(encounter_path)

@rpc("any_peer")
func receive_return_to_map():
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_return_to_map()

@rpc("any_peer")
func receive_go_to_reward(gold: int, encounter_type: int, card_paths: Array = []):
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_go_to_reward(gold, encounter_type, card_paths)

@rpc("any_peer")
func receive_battle_ended_by_peer(gold: int, final_hp: int, final_shield: int, encounter_type: int, card_paths: Array = []):
	"""Klient ukončil bitvu (výhra). Jen host reaguje."""
	if not has_node("/root/GameManager"):
		return
	if not is_server():
		return
	GameManager.coop_host_on_battle_ended_by_client(gold, final_hp, final_shield, encounter_type, card_paths)

# receive_card_chosen odstraněno – coop reward sync nyní běží přímo v RewardScene._rpc_coop_reward_card_chosen

@rpc("any_peer")
func receive_game_over():
	"""Klient obdrží info že run skončil prohrou."""
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_game_over()

@rpc("any_peer")
func receive_go_to_shop(shop_items: Array = []):
	"""Klient obdrží shop data od hosta."""
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_go_to_shop(shop_items)

@rpc("any_peer")
func receive_go_to_event(event_path: String):
	"""Klient obdrží event od hosta."""
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_go_to_event(event_path)

@rpc("any_peer")
func receive_go_to_rest():
	"""Klient přejde do rest scene."""
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_go_to_rest()

@rpc("any_peer")
func receive_go_to_treasure(artifact_paths: Array = []):
	"""Klient obdrží treasure data od hosta."""
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_client_go_to_treasure(artifact_paths)

@rpc("any_peer")
func receive_scene_ready(peer_id: int, scene_name: String):
	"""Peer oznámil že je připravený v dané scéně."""
	if not has_node("/root/GameManager"):
		return
	GameManager.coop_peer_scene_ready(peer_id, scene_name)
