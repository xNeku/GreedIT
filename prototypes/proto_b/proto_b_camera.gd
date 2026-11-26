extends Camera3D
## PROTOTIPO B: cámara ortográfica que sigue al jugador desde arriba (inclinada 30º) y vibra con los golpes.

@export var target: Node3D
@export var offset := Vector3(0, 300, 520)
@export var smoothing := 9.0

var _shake := 0.0


func _ready() -> void:
	Events.camera_shake_requested.connect(func(strength: float, _d: float) -> void: _shake = maxf(_shake, strength))


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + offset
	global_position = global_position.lerp(goal, minf(1.0, smoothing * delta))
	_shake = move_toward(_shake, 0.0, delta * 20.0)
	h_offset = randf_range(-1, 1) * _shake
	v_offset = randf_range(-1, 1) * _shake
