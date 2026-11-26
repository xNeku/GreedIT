extends CharacterBody3D
## PROTOTIPO B: el mismo personaje 3D, pero en un mundo 3D de verdad (cámara ortográfica, luz y sombras 3D).
## Gira suavemente hacia cualquier dirección (no hay 8 direcciones fijas).

@export var move_speed := 160.0
@export var acceleration := 2400.0
@export var friction := 2800.0
## Velocidad de giro del cuerpo hacia la dirección de movimiento.
@export var turn_speed := 14.0
@export var attack_time := 0.4
@export var attack_damage := 12.0
@export var attack_range := 46.0

var _anim := &"idle"
var _t := 0.0
var _attack_left := 0.0
var _hit_done := false
var _target_yaw := 0.0

@onready var rig: CharacterRig3D = $Character3D


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wish := Vector3(input.x, 0.0, input.y) * move_speed
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if _attack_left > 0.0:
		flat = flat.move_toward(Vector3.ZERO, friction * delta)
	else:
		flat = flat.move_toward(wish, (acceleration if input != Vector2.ZERO else friction) * delta)
	velocity = Vector3(flat.x, 0.0, flat.z)
	move_and_slide()
	if _attack_left <= 0.0 and flat.length() > 20.0:
		_target_yaw = atan2(flat.x, flat.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, _target_yaw, minf(1.0, turn_speed * delta))

	if _attack_left > 0.0:
		_attack_left -= delta
		var t := 1.0 - _attack_left / attack_time
		rig.pose(&"attack", t)
		if t >= 0.35 and not _hit_done:
			_hit_done = true
			_do_hit()
	else:
		var moving := flat.length() > 20.0
		var anim := &"run" if moving else &"idle"
		if anim != _anim:
			_anim = anim
			_t = 0.0
		_t += delta / (0.5 if moving else 1.4)
		rig.pose(_anim, fmod(_t, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_primary") and _attack_left <= 0.0:
		var aim := _mouse_on_ground()
		var to := aim - global_position
		if Vector2(to.x, to.z).length() > 1.0:
			_target_yaw = atan2(to.x, to.z)
			rig.rotation.y = _target_yaw # el golpe sale ya mirando al ratón
		_attack_left = attack_time
		_hit_done = false


## Punto del suelo (y = 0) bajo el ratón.
func _mouse_on_ground() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var normal := cam.project_ray_normal(mouse)
	if absf(normal.y) < 0.0001:
		return global_position
	return origin + normal * (-origin.y / normal.y)


func _do_hit() -> void:
	var forward := Vector3(sin(rig.rotation.y), 0.0, cos(rig.rotation.y))
	for node in get_tree().get_nodes_in_group(&"proto_dummy"):
		var dummy := node as Node3D
		var to := dummy.global_position - global_position
		to.y = 0.0
		if to.length() <= attack_range and forward.dot(to.normalized()) > 0.3:
			dummy.call("take_hit", roundi(attack_damage * randf_range(0.9, 1.1)), to.normalized())
