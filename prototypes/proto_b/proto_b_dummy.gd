extends StaticBody3D
## PROTOTIPO B: muñeco de entrenamiento en 3D (sprite plano que mira a la cámara) que se tambalea y saca números.

@export var number_scene: PackedScene
@export var spring_stiffness := 180.0
@export var spring_damping := 9.0

var _angle := 0.0
var _angular_velocity := 0.0
var _flash := 0.0
## Golpes recibidos (para el test).
var hits := 0

@onready var pivot: Node3D = $Pivot
@onready var body: Sprite3D = $Pivot/Body


func take_hit(amount: int, direction: Vector3) -> void:
	hits += 1
	_angular_velocity += (direction.x if absf(direction.x) > 0.2 else 0.5) * -9.0
	_flash = 1.0
	if number_scene:
		var number := number_scene.instantiate() as Node3D
		number.set("text", str(amount))
		get_parent().add_child(number)
		number.global_position = global_position + Vector3(randf_range(-6, 6), 78, 0)
	Events.camera_shake_requested.emit(1.5, 0.1)


func _physics_process(delta: float) -> void:
	var accel := -spring_stiffness * _angle - spring_damping * _angular_velocity
	_angular_velocity += accel * delta
	_angle = clampf(_angle + _angular_velocity * delta, -0.9, 0.9)
	pivot.rotation.z = _angle
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	body.modulate = Color(1, 1, 1).lerp(Color(3, 3, 3), _flash)
