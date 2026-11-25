class_name TrainingDummy
extends StaticBody2D
## Muñeco de entrenamiento: recibe golpes, se tambalea como un muelle,
## escupe paja, muestra números de daño y un medidor de DPS.

@export var damage_number_scene: PackedScene
@export_group("Tambaleo (muelle)")
## Rigidez del muelle que lo devuelve a vertical.
@export var spring_stiffness := 180.0
## Amortiguación (más = deja de oscilar antes).
@export var spring_damping := 9.0
## Cuánto lo inclina el knockback.
@export var knockback_to_wobble := 0.09
@export var max_angle := 0.9
@export_group("DPS")
## Ventana (s) para calcular el DPS.
@export var dps_window := 4.0
## Segundos sin recibir golpes para reiniciar el contador.
@export var reset_after := 4.0

var _angle := 0.0
var _angular_velocity := 0.0
var _flash := 0.0
var _squash := 0.0
var _hits: Array[Vector2] = [] # x = tiempo, y = daño
var _total := 0
var _hit_count := 0
var _last_hit_time := -100.0
var _last_hit := 0
var _last_crit := false

@onready var pivot: Node2D = $Pivot
@onready var body_sprite: Sprite2D = $Pivot/Body
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var straw: CPUParticles2D = $Straw
@onready var number_spawn: Marker2D = $NumberSpawn
@onready var stats_label: Label = $StatsLabel


func _ready() -> void:
	hurtbox.hit_received.connect(_on_hit_received)
	_update_label()


func _on_hit_received(hit: HitData) -> void:
	var now := _now()
	_hits.append(Vector2(now, hit.amount))
	_total += hit.amount
	_hit_count += 1
	_last_hit_time = now
	_last_hit = hit.amount
	_last_crit = hit.is_crit

	var push := hit.knockback.x if absf(hit.knockback.x) > 1.0 else hit.knockback.length() * 0.5
	_angular_velocity += push * knockback_to_wobble
	_flash = 1.0
	_squash = 0.25 if hit.is_crit else 0.15

	straw.direction = hit.knockback.normalized() if hit.knockback != Vector2.ZERO else Vector2.UP
	straw.restart()
	_spawn_number(hit)
	_update_label()


func _spawn_number(hit: HitData) -> void:
	if damage_number_scene == null:
		return
	var number := damage_number_scene.instantiate() as DamageNumber
	number.amount = hit.amount
	number.is_crit = hit.is_crit
	# Capa "world_overlay" (CanvasLayer que sigue a la cámara): no la oscurece la iluminación.
	var container := get_tree().get_first_node_in_group(&"world_overlay")
	(container if container else get_parent()).add_child(number)
	number.global_position = number_spawn.global_position


func _physics_process(delta: float) -> void:
	# Muelle amortiguado: a'' = -k·a - c·a'
	var accel := -spring_stiffness * _angle - spring_damping * _angular_velocity
	_angular_velocity += accel * delta
	_angle = clampf(_angle + _angular_velocity * delta, -max_angle, max_angle)
	pivot.rotation = _angle

	_squash = move_toward(_squash, 0.0, delta * 1.5)
	pivot.scale = Vector2(1.0 + _squash, 1.0 - _squash)

	_flash = move_toward(_flash, 0.0, delta * 8.0)
	(body_sprite.material as ShaderMaterial).set_shader_parameter("flash_amount", _flash)


func _process(_delta: float) -> void:
	var now := _now()
	if _hit_count > 0 and now - _last_hit_time > reset_after:
		_hits.clear()
		_total = 0
		_hit_count = 0
		_update_label()
	elif _hit_count > 0:
		_update_label()


func _update_label() -> void:
	if _hit_count == 0:
		stats_label.text = "¡Pégame!"
		return
	var now := _now()
	while not _hits.is_empty() and now - _hits[0].x > dps_window:
		_hits.pop_front()
	var window_damage := 0.0
	for h in _hits:
		window_damage += h.y
	var span := clampf(now - (_hits[0].x if not _hits.is_empty() else now), 1.0, dps_window)
	stats_label.text = "DPS %d · Total %d\nÚltimo %d%s · Golpes %d" % [
		roundi(window_damage / span), _total, _last_hit, " CRIT" if _last_crit else "", _hit_count]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
