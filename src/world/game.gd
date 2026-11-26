class_name Game
extends Node2D
## Mundo de juego. Arranca la red (solo / host / unirse) y crea un jugador por cada peer.
##
## RED:
##   - Los jugadores los crea el HOST con el MultiplayerSpawner "PlayerSpawner" (spawn_function),
##     y cada uno manda sobre el suyo (authority = su peer id).
##   - Los mobs los crea el host (MobSpawner) y "MobNetSpawner" los replica a los clientes.
##   - Un cliente, al conectar, pide su jugador con _request_spawn().

@export var player_scene: PackedScene

@onready var players: Node2D = $World/Players
@onready var player_spawner: MultiplayerSpawner = $World/PlayerSpawner
@onready var spawn_points: Node2D = $World/PlayerSpawns
@onready var hud: HUD = $HUD


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	Events.local_player_ready.connect(hud.set_player)
	if Net.start() != OK:
		return
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_add_player(multiplayer.get_unique_id(), Net.appearance_index)
	else:
		multiplayer.connected_to_server.connect(func() -> void:
			_request_spawn.rpc_id(1, Net.appearance_index))


## Un cliente pide su personaje al host.
@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(appearance: int) -> void:
	if multiplayer.is_server():
		_add_player(multiplayer.get_remote_sender_id(), appearance)


func _add_player(peer_id: int, appearance: int) -> void:
	if players.has_node(str(peer_id)):
		return
	var points := spawn_points.get_children()
	var point := points[players.get_child_count() % points.size()] as Node2D
	player_spawner.spawn({"id": peer_id, "pos": point.position, "look": appearance})


## Se ejecuta en TODOS los peers al crear un jugador (así todos le ponen el mismo dueño).
func _spawn_player(data: Dictionary) -> Node:
	var player := player_scene.instantiate() as Player
	player.name = str(data.id)
	player.position = data.pos
	player.appearance_index = data.look
	player.set_multiplayer_authority(data.id)
	return player


func _on_peer_disconnected(peer_id: int) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func local_player() -> Player:
	return players.get_node_or_null(str(multiplayer.get_unique_id())) as Player
