class_name Hurtbox3D
extends Area3D
## Zona que recibe daño (3D). Igual que Hurtbox (2D): el golpe se aplica en quien manda sobre la víctima;
## si este ordenador no manda, se reenvía por RPC. Su dueño se conecta a `hit_received`.

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
