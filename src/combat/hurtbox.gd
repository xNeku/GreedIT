class_name Hurtbox
extends Area2D
## Zona que recibe daño. Su dueño se conecta a `hit_received`.
## Capa: enemy_hurtbox (5) o player_hurtbox (6).

signal hit_received(hit: HitData)


func _ready() -> void:
	monitoring = false


func receive_hit(hit: HitData) -> void:
	hit_received.emit(hit)
