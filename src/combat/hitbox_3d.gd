class_name Hitbox3D
extends Area3D
## Zona que hace daño (3D). La enciende el ataque (`active`). Golpea una vez a cada objetivo por activación.
## Capa: player_attacks (4). Máscara: enemy_hurtbox (5).

signal hurtbox_entered(hurtbox: Hurtbox3D, hitbox: Hitbox3D)

@export var active := false:
	set(value):
		if value and not active:
			_already_hit.clear() # cada activación nueva puede volver a golpear a todos
		active = value
		monitoring = value # apagada no gasta nada en la física
@export var damage_multiplier := 1.0
## Empuje (unidades/segundo) que recibe el objetivo.
@export var knockback_force := 6.0

var _already_hit: Array[Hurtbox3D] = []


func _ready() -> void:
	monitorable = false
	monitoring = active


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox3D
		if hurtbox == null or _already_hit.has(hurtbox):
			continue
		_already_hit.append(hurtbox)
		hurtbox_entered.emit(hurtbox, self)
