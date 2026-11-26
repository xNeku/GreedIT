extends Node
## Red del juego: SOLO, HOST (crear partida) o JOIN (unirse por IP).
##
## El juego SIEMPRE está escrito como si fuera coop: en solo se usa un OfflineMultiplayerPeer
## (somos el peer 1 y mandamos sobre todo), así el mismo código sirve para 1 a 4 jugadores.
## Flujo: el menú llama a play() -> se carga el mundo -> el mundo (Game) llama a start().

signal connection_failed(reason: String)

enum Mode { SOLO, HOST, JOIN }

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
const MENU_SCENE := "res://src/ui/main_menu.tscn"
## Mundo 3D (la base nueva del juego) y el sandbox 2D pixel art (el anterior).
const WORLD_3D_SCENE := "res://src/game3d/world/game_3d.tscn"
const WORLD_2D_SCENE := "res://src/world/sandbox.tscn"

var mode := Mode.SOLO
## Mundo que se carga al jugar (lo elige el menú).
var world_scene := WORLD_3D_SCENE
var address := "127.0.0.1"
var port := DEFAULT_PORT
## Personaje elegido en el menú (índice en Player.appearances en 2D, en Player3D.avatars en 3D).
var appearance_index := 0
## Último error para enseñarlo en el menú.
var last_error := ""


## Guarda el modo y carga el mundo. El mundo arrancará la red al estar listo.
func play(new_mode: Mode, new_address: String = "127.0.0.1", new_port: int = DEFAULT_PORT) -> void:
	mode = new_mode
	address = new_address
	port = new_port
	last_error = ""
	get_tree().change_scene_to_file(world_scene)


## Arranca la red según el modo. Devuelve OK o el error.
func start() -> Error:
	_reset_peer()
	match mode:
		Mode.SOLO:
			multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		Mode.HOST:
			var peer := ENetMultiplayerPeer.new()
			var err := peer.create_server(port, MAX_PLAYERS)
			if err != OK:
				_fail("No se pudo crear la partida en el puerto %d (¿ya está en uso?)" % port)
				return err
			multiplayer.multiplayer_peer = peer
		Mode.JOIN:
			var peer := ENetMultiplayerPeer.new()
			var err := peer.create_client(address, port)
			if err != OK:
				_fail("No se pudo conectar a %s:%d" % [address, port])
				return err
			multiplayer.multiplayer_peer = peer
			if not multiplayer.connection_failed.is_connected(_on_connection_failed):
				multiplayer.connection_failed.connect(_on_connection_failed)
				multiplayer.server_disconnected.connect(_on_server_disconnected)
	return OK


func is_online() -> bool:
	return mode != Mode.SOLO


## Sale de la partida y vuelve al menú.
func leave(message: String = "") -> void:
	last_error = message
	_reset_peer()
	mode = Mode.SOLO
	get_tree().change_scene_to_file(MENU_SCENE)


func _reset_peer() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _fail(reason: String) -> void:
	connection_failed.emit(reason)
	leave(reason)


func _on_connection_failed() -> void:
	_fail("No se pudo conectar a %s:%d" % [address, port])


func _on_server_disconnected() -> void:
	_fail("El host ha cerrado la partida")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("leave_game") and get_tree().current_scene \
			and get_tree().current_scene.scene_file_path in [WORLD_3D_SCENE, WORLD_2D_SCENE]:
		leave()
