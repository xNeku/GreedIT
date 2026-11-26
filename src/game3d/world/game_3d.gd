class_name Game3D
extends Node
## Mundo 3D. Igual que Game (2D): arranca la red y crea un jugador por peer.
##
## RED:
##   - Los jugadores los crea el HOST con el MultiplayerSpawner "PlayerSpawner" (spawn_function)
##     y cada uno manda sobre el suyo (authority = su peer id).
##   - Un cliente, al conectar, pide su jugador con _request_spawn().
##   - Muñecos y props son parte de la escena (existen igual en todos); el host manda sobre ellos.
##
## El mundo 3D vive dentro de PixelView/World (SubViewport en baja resolución = estilo pixel art);
## el HUD va fuera, a resolución normal.

@export var player_scene: PackedScene

var _previous_scale_mode: Window.ContentScaleMode
var _previous_interpolation := false

@onready var players: Node3D = %Players
@onready var dummies: Node3D = %Dummies
@onready var player_spawner: MultiplayerSpawner = %PlayerSpawner
@onready var spawn_points: Node3D = %PlayerSpawns
@onready var hud: HUD3D = $HUD


func _enter_tree() -> void:
	# El 2D pixel art escala el viewport entero; en 3D queremos la resolución real de la pantalla.
	_previous_scale_mode = get_window().content_scale_mode
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	# La física va a 60 Hz; con interpolación lo que se mueve se dibuja suave aunque la pantalla vaya a 120 Hz.
	_previous_interpolation = get_tree().physics_interpolation
	get_tree().physics_interpolation = true


func _exit_tree() -> void:
	get_window().content_scale_mode = _previous_scale_mode
	get_tree().physics_interpolation = _previous_interpolation


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	Events.local_player_3d_ready.connect(func(p: Node) -> void: hud.set_player(p as Player3D))
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
func _request_spawn(avatar: int) -> void:
	if multiplayer.is_server():
		_add_player(multiplayer.get_remote_sender_id(), avatar)


func _add_player(peer_id: int, avatar: int) -> void:
	if players.has_node(str(peer_id)):
		return
	var points := spawn_points.get_children()
	var point := points[players.get_child_count() % points.size()] as Node3D
	player_spawner.spawn({"id": peer_id, "pos": point.global_position, "avatar": avatar})


## Se ejecuta en TODOS los peers al crear un jugador (así todos le ponen el mismo dueño).
func _spawn_player(data: Dictionary) -> Node:
	var player := player_scene.instantiate() as Player3D
	player.name = str(data.id)
	player.position = data.pos
	player.avatar_index = data.avatar
	player.set_multiplayer_authority(data.id)
	return player


func _on_peer_disconnected(peer_id: int) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func local_player() -> Player3D:
	return players.get_node_or_null(str(multiplayer.get_unique_id())) as Player3D
