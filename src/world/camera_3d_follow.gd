class_name FollowCamera3D
extends Camera3D
## Cámara isométrica (estilo Diablo) que sigue al jugador local con suavizado, temblor y zoom (+ / -).
## Solo existe una por ordenador: sigue a SU jugador (Events.local_player_ready).
##
## Ortográfica = sin perspectiva, como el pixel art. Con `pixel_snap` la cámara se mueve de píxel en píxel.

@export_group("Vista")
## Isométrica estilo Diablo: girada 45° y a 30° del suelo (las líneas del suelo salen 2:1, como el pixel art).
@export var yaw_degrees := 45.0
@export_range(20.0, 90.0) var pitch_degrees := 30.0
## Distancia de la cámara (en ortográfica no cambia el tamaño, solo lo que entra delante).
@export var distance := 30.0

@export_group("Zoom")
## Alto visible en metros (más = más lejos). Las teclas + y - lo cambian entre min y max.
@export var zoom_min := 9.0
@export var zoom_max := 26.0
@export var zoom_step := 1.5

@export_group("Seguimiento")
## Suavizado del seguimiento (más = más pegada).
@export var follow_speed := 9.0
## Cuánto se adelanta hacia el ratón (metros).
@export var mouse_lead := 1.5
@export var target: Node3D
## Pegar la cámara a la rejilla de píxeles (evita que los bordes "bailen" al moverse).
@export var pixel_snap := true

## Lo que la cámara se ha desviado al pegarse a la rejilla, en píxeles. PixelView mueve la imagen esto.
var snap_offset := Vector2.ZERO

var _shake := 0.0
var _shake_time := 0.0
var _focus := Vector3.ZERO


func _ready() -> void:
	Events.local_player_ready.connect(func(player: Node) -> void:
		target = player as Node3D
		_focus = _target_position()
		_update(1.0, 0.0))
	Events.camera_shake_requested.connect(func(strength: float, duration: float) -> void:
		_shake = maxf(_shake, strength)
		_shake_time = maxf(_shake_time, duration))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		size = clampf(size - zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed("zoom_out"):
		size = clampf(size + zoom_step, zoom_min, zoom_max)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_update(minf(1.0, follow_speed * delta), delta)


## Posición del jugador suavizada entre pasos de física (sin tirones aunque la pantalla vaya a 120 Hz).
func _target_position() -> Vector3:
	return target.get_global_transform_interpolated().origin


func _update(weight: float, delta: float) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	var lead := Vector3.ZERO
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x > 0 and mouse_lead > 0.0:
		var m := get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5)
		lead = (Vector3(m.x, 0, m.y).limit_length(0.5) * 2.0 * mouse_lead).rotated(Vector3.UP, yaw)
	_focus = _focus.lerp(_target_position() + lead, weight)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var eye := _focus + offset
	look_at_from_position(eye, _focus + Vector3(0, 0.8, 0), Vector3.UP)
	snap_offset = Vector2.ZERO
	var height := float(get_viewport().get_visible_rect().size.y)
	if pixel_snap and projection == PROJECTION_ORTHOGONAL and height > 0.0:
		var texel := size / height
		var right := global_basis.x
		var up := global_basis.y
		var p := Vector2(eye.dot(right), eye.dot(up))
		var snapped := (p / texel).round() * texel
		global_position = eye + right * (snapped.x - p.x) + up * (snapped.y - p.y)
		snap_offset = Vector2(snapped.x - p.x, -(snapped.y - p.y)) / texel
	if _shake_time > 0.0:
		_shake_time -= delta
		h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		v_offset = randf_range(-1.0, 1.0) * _shake * 0.3
	else:
		h_offset = 0.0
		v_offset = 0.0
