extends Node
## Sensación de juego global: hitstop y pantalla completa.

## Escala de tiempo mientras dura un hitstop.
@export var hitstop_time_scale := 0.05
## Duración máxima acumulable de hitstop (evita congelones con muchos golpes a la vez).
@export var max_hitstop := 0.12

var _hitstop_until_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.hitstop_requested.connect(_on_hitstop_requested)


func _process(_delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_until_ms:
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_MAXIMIZED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
		)


func _on_hitstop_requested(duration: float) -> void:
	if duration <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var target := now + int(minf(duration, max_hitstop) * 1000.0)
	_hitstop_until_ms = maxi(_hitstop_until_ms, target)
	Engine.time_scale = hitstop_time_scale
