class_name PlayerCamera
extends Camera2D
## Cámara del jugador: se adelanta un poco hacia el ratón y vibra con los golpes.

## Fracción de la distancia al ratón que la cámara se adelanta.
@export var mouse_lead := 0.1
@export var max_lead := 48.0
@export var shake_decay := 18.0

var _shake_strength := 0.0
var _shake_time := 0.0


func _ready() -> void:
	Events.camera_shake_requested.connect(shake)


func shake(strength: float, duration: float = 0.15) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)


func _process(delta: float) -> void:
	var to_mouse := get_global_mouse_position() - (get_parent() as Node2D).global_position
	var lead := (to_mouse * mouse_lead).limit_length(max_lead)
	var shake_offset := Vector2.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		_shake_strength = move_toward(_shake_strength, 0.0, shake_decay * delta)
	offset = (lead + shake_offset).round()
