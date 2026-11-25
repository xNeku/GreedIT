class_name WeaponTrail
extends Line2D
## Estela del arma. Sigue a `target` (un Marker2D en la punta) mientras `emitting` esté activo.
## La animación del arma enciende y apaga `emitting`.

@export var target: Node2D
@export var max_points := 7
@export var emitting := false


func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	clear_points()


func _process(_delta: float) -> void:
	if emitting and target:
		add_point(target.global_position)
		while get_point_count() > max_points:
			remove_point(0)
	elif get_point_count() > 0:
		remove_point(0)
