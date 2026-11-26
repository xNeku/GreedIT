class_name EnemyProjectile
extends Area2D
## Proyectil enemigo (huesos del esqueleto...). Daña al jugador y desaparece al chocar.
## Capa: enemy_attacks (7). Máscara: world (1) + player_hurtbox (6).

@export var lifetime := 1.6
## Radianes/segundo que gira el sprite.
@export var spin_speed := 14.0
@export var knockback_force := 90.0

var direction := Vector2.RIGHT
var speed := 200.0
var damage := 6.0
var source: Node
## Copia solo visual (en los clientes): no hace daño.
var visual_only := false

@onready var sprite: Node2D = $Sprite


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(func(_b: Node2D) -> void: queue_free())


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	sprite.rotation += spin_speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null:
		return
	if visual_only:
		queue_free()
		return
	var hit := HitData.roll(damage, 1.0, 0.0, 1.0)
	hit.knockback = direction * knockback_force
	hit.source = source
	hit.attack_name = &"projectile"
	hurtbox.receive_hit(hit)
	queue_free()
