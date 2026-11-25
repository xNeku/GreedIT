class_name Projectile
extends Area2D
## Proyectil genérico (flechas, dagas lanzadas...). Lo crea Weapon.spawn_projectile().
## Capa: player_attacks (4). Máscara: world (1) + enemy_hurtbox (5).

@export var speed := 420.0
@export var lifetime := 1.2
## Radianes/segundo que gira el sprite (para dagas lanzadas).
@export var spin_speed := 0.0
## A cuántos enemigos atraviesa antes de desaparecer.
@export var pierce := 0
@export var knockback_force := 40.0
@export var hitstop := 0.03
@export var shake := 1.0
@export var attack_name: StringName = &"projectile"

var direction := Vector2.RIGHT
var weapon: Weapon
var damage_multiplier := 1.0
var _hit: Array[Hurtbox] = []

@onready var sprite: Node2D = $Sprite


func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	if spin_speed != 0.0:
		sprite.rotation += spin_speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or _hit.has(hurtbox):
		return
	_hit.append(hurtbox)
	if is_instance_valid(weapon):
		weapon.deal_hit(hurtbox, damage_multiplier, knockback_force, attack_name,
				PackedStringArray(["projectile"]), hitstop, shake, global_position - direction * 8.0)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1


func _on_body_entered(_body: Node2D) -> void:
	queue_free()
