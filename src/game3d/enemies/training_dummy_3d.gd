class_name TrainingDummy3D
extends StaticBody3D
## Muñeco de entrenamiento 3D: se tambalea como un muelle, suelta paja, enseña números de daño y DPS.
## RED: lo controla el host. Su Hurtbox3D le reenvía los golpes y él avisa a todos con `_show_hit`.

@export var damage_label_scene: PackedScene
## Material que va encima de las mallas del muñeco (material_overlay) y se ilumina al recibir un golpe.
@export var flash_material: StandardMaterial3D
@export_group("Tambaleo (muelle)")
## Rigidez del muelle que lo devuelve a vertical.
@export var spring_stiffness := 140.0
## Amortiguación (más = deja de oscilar antes).
@export var spring_damping := 8.0
## Cuánto lo inclina el empuje del golpe.
@export var knockback_to_wobble := 0.6
@export var max_angle := 0.7
@export_group("DPS")
## Ventana (s) para calcular el DPS.
@export var dps_window := 4.0
## Segundos sin recibir golpes para reiniciar el contador.
@export var reset_after := 4.0

var _tilt := Vector2.ZERO
var _tilt_velocity := Vector2.ZERO
var _flash := 0.0
var _hits: Array[Vector2] = [] # x = tiempo, y = daño
var _total := 0
var _hit_count := 0
var _last_hit_time := -100.0
## Golpes recibidos desde que existe (no se reinicia; útil para tests).
var total_hits := 0

@onready var pivot: Node3D = $Pivot
@onready var hurtbox: Hurtbox3D = $Hurtbox
@onready var straw: CPUParticles3D = $Pivot/Straw
@onready var label_spawn: Marker3D = $Pivot/LabelSpawn
@onready var stats_label: Label3D = $StatsLabel


func _ready() -> void:
	hurtbox.hit_received.connect(func(hit: HitData) -> void: _show_hit.rpc(hit.amount, hit.is_crit, hit.knockback))
	_update_label()


@rpc("authority", "call_local", "reliable")
func _show_hit(amount: int, is_crit: bool, knockback: Vector2) -> void:
	var now := _now()
	_hits.append(Vector2(now, amount))
	_total += amount
	_hit_count += 1
	total_hits += 1
	_last_hit_time = now
	_tilt_velocity += knockback.normalized() * knockback_to_wobble * (8.0 if is_crit else 5.0)
	_flash = 1.0
	straw.restart()
	if damage_label_scene:
		var label := damage_label_scene.instantiate() as DamageLabel3D
		label.amount = amount
		label.is_crit = is_crit
		get_parent().add_child(label)
		label.global_position = label_spawn.global_position + Vector3(randf_range(-0.4, 0.4), 0, 0)
	_update_label()


func _physics_process(delta: float) -> void:
	# Muelle amortiguado en dos ejes: a'' = -k·a - c·a'
	_tilt_velocity += (-spring_stiffness * _tilt - spring_damping * _tilt_velocity) * delta
	_tilt = (_tilt + _tilt_velocity * delta).limit_length(max_angle)
	pivot.rotation = Vector3(_tilt.y, 0.0, -_tilt.x)
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	if flash_material:
		flash_material.albedo_color.a = _flash * 0.8


func _process(_delta: float) -> void:
	if _hit_count > 0:
		if _now() - _last_hit_time > reset_after:
			_hits.clear()
			_total = 0
			_hit_count = 0
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
	stats_label.text = "DPS %d · Total %d · Golpes %d" % [roundi(window_damage / span), _total, _hit_count]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
