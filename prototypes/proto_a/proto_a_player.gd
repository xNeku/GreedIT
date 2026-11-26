extends CharacterBody2D
## PROTOTIPO A: el personaje 3D horneado a hojas de sprites (tools/baker).
## Cada hoja: filas = 8 direcciones, columnas = fotogramas. El script elige fila (dirección) y columna (tiempo).

@export var move_speed := 160.0
@export var acceleration := 2400.0
@export var friction := 2800.0
## Hoja de sprites por animación.
@export var sheets: Dictionary = {}
@export var frame_counts: Dictionary = {"idle": 4, "run": 8, "attack": 6}
## Fotogramas por segundo de cada animación.
@export var fps: Dictionary = {"idle": 5.0, "run": 16.0, "attack": 15.0}
@export var attack_damage := 12.0

var anim := "idle"
var dir := 0
var _t := 0.0
var _attacking := false
var _hit_done := false

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _attacking:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(input * move_speed, (acceleration if input != Vector2.ZERO else friction) * delta)
	move_and_slide()
	if not _attacking and velocity.length() > 20.0:
		dir = _dir_from(velocity)
	var new_anim := "attack" if _attacking else ("run" if velocity.length() > 20.0 else "idle")
	if new_anim != anim:
		anim = new_anim
		_t = 0.0
	_t += delta * float(fps[anim])
	var count: int = frame_counts[anim]
	var f := int(_t)
	if anim == "attack":
		if f >= 2 and not _hit_done:
			_hit_done = true
			_do_hit()
		if f >= count:
			_attacking = false
			anim = "idle"
			_t = 0.0
			f = 0
			count = frame_counts[anim]
	f = f % count
	sprite.texture = sheets[anim]
	sprite.hframes = count
	sprite.vframes = 8
	sprite.frame = dir * count + f


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_primary") and not _attacking:
		var to_mouse := get_global_mouse_position() - global_position
		dir = _dir_from(to_mouse)
		hitbox.position = Vector2(0, -20) + to_mouse.normalized() * 26.0
		_attacking = true
		_hit_done = false
		anim = "attack"
		_t = 0.0


## Dirección de pantalla -> fila de la hoja (0 = hacia abajo/cámara, 2 = derecha, 4 = arriba, 6 = izquierda).
func _dir_from(v: Vector2) -> int:
	return posmod(2 - roundi(rad_to_deg(v.angle()) / 45.0), 8)


func _do_hit() -> void:
	for area in hitbox.get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox:
			var hit := HitData.roll(attack_damage, 1.0, 0.15, 2.0)
			hit.knockback = (hurtbox.global_position - global_position).normalized() * 80.0
			hit.source = self
			hurtbox.receive_hit(hit)
	Events.camera_shake_requested.emit(1.5, 0.1)
