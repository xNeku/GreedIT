class_name Hitbox
extends Area2D
## Zona que hace daño. Se activa/desactiva desde el AnimationPlayer del arma
## (pista de la propiedad `active`). Solo golpea una vez a cada objetivo por activación.
## Capa: player_attacks (4). Máscara: enemy_hurtbox (5).

signal hurtbox_entered(hurtbox: Hurtbox, hitbox: Hitbox)

## Encendido por la animación durante los frames activos del ataque.
@export var active: bool = false:
	set(value):
		active = value
		if active:
			_already_hit.clear()
## Multiplicador sobre el daño base del arma.
@export var damage_multiplier: float = 1.0
## Fuerza de empuje que recibe el objetivo.
@export var knockback_force: float = 60.0
## Segundos de hitstop al impactar.
@export var hitstop: float = 0.04
## Intensidad de vibración de cámara al impactar.
@export var shake: float = 1.5
## Nombre del ataque (para números, logs y futuros talentos).
@export var attack_name: StringName = &"attack"
## Etiquetas libres: "slam", "projectile", "aoe"... Las usarán talentos y afijos.
@export var tags: PackedStringArray = PackedStringArray()

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	monitorable = false


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or _already_hit.has(hurtbox):
			continue
		_already_hit.append(hurtbox)
		hurtbox_entered.emit(hurtbox, self)
