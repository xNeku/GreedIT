class_name Hurtbox
extends Area2D
## Zona que recibe daño. Su dueño se conecta a `hit_received`.
## Capa: enemy_hurtbox (5) o player_hurtbox (6).
##
## RED: el golpe lo calcula quien ataca, pero se APLICA en quien manda sobre la víctima
## (el host para mobs y muñecos, cada jugador para sí mismo). Si este ordenador no manda,
## receive_hit() reenvía el golpe por RPC a quien sí. En solo, se aplica directamente.

signal hit_received(hit: HitData)


func _ready() -> void:
	monitoring = false


func receive_hit(hit: HitData) -> void:
	if is_multiplayer_authority():
		hit_received.emit(hit)
	else:
		_remote_hit.rpc_id(get_multiplayer_authority(), hit.to_dict())


@rpc("any_peer", "call_remote", "reliable")
func _remote_hit(data: Dictionary) -> void:
	if is_multiplayer_authority():
		hit_received.emit(HitData.from_dict(data, self))
