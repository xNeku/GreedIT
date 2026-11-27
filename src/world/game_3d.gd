class_name Game3D
extends Node
## Mundo del juego. Arranca la red (solo / host / unirse) y crea un jugador por peer.
##
## RED:
##   - Los jugadores los crea el HOST con el MultiplayerSpawner "PlayerSpawner" (spawn_function)
##     y cada uno manda sobre el suyo (authority = su peer id).
##   - Un cliente, al conectar, pide su jugador con _request_spawn().
##   - Muñecos y props son parte de la escena (existen igual en todos); el host manda sobre ellos.
##
## El mundo 3D vive dentro de PixelView/World (SubViewport, estilo pixel art); el HUD va fuera.
## El terreno lo genera `Land` (WorldStreamer) a partir de su semilla: todos los peers generan el mismo mundo.

@export var player_scene: PackedScene

@onready var land: WorldStreamer = %Land
@onready var players: Node3D = %Players
@onready var dummies: Node3D = %Dummies
@onready var player_spawner: MultiplayerSpawner = %PlayerSpawner
@onready var spawn_points: Node3D = %PlayerSpawns
@onready var hud: HUD3D = $HUD


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	Events.local_player_ready.connect(hud.set_player)
	land.prepare() # el suelo de la base tiene que existir antes de que aparezca nadie
	hud.world_map.land = land
	if Net.start() != OK:
		return
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_add_player(multiplayer.get_unique_id())
	else:
		multiplayer.connected_to_server.connect(func() -> void: _request_spawn.rpc_id(1))


## Un cliente pide su personaje al host.
@rpc("any_peer", "call_remote", "reliable")
func _request_spawn() -> void:
	if multiplayer.is_server():
		_add_player(multiplayer.get_remote_sender_id())


func _add_player(peer_id: int) -> void:
	if players.has_node(str(peer_id)):
		return
	var points := spawn_points.get_children()
	var point := points[players.get_child_count() % points.size()] as Node3D
	player_spawner.spawn({"id": peer_id, "pos": point.global_position})


## Se ejecuta en TODOS los peers al crear un jugador (así todos le ponen el mismo dueño).
func _spawn_player(data: Dictionary) -> Node:
	var player := player_scene.instantiate() as Player3D
	player.name = str(data.id)
	player.position = data.pos
	player.set_multiplayer_authority(data.id)
	return player


func _on_peer_disconnected(peer_id: int) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func local_player() -> Player3D:
	return players.get_node_or_null(str(multiplayer.get_unique_id())) as Player3D
