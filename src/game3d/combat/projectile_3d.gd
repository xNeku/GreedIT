class_name Projectile3D
extends Area3D
## Proyectil 3D (virote, proyectil mágico). Lo crea Player3D en todos los peers; solo la copia del
## dueño hace daño (las demás son `visual_only`).
## Capa: player_attacks (4). Máscara: world (1) + enemy_hurtbox (5).

@export var lifetime := 1.5
@export var knockback := 5.0

var direction := Vector3.FORWARD
var speed := 18.0
var damage := 10.0
var crit_chance := 0.1
var crit_multiplier := 2.0
var shooter: Node
var visual_only := false


func _ready() -> void:
	look_at(global_position + direction, Vector3.UP)
	area_entered.connect(_on_area_entered)
	body_entered.connect(func(_b: Node3D) -> void: queue_free())


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox3D
	if hurtbox == null:
		return
	if not visual_only:
		var hit := HitData.roll(damage, 1.0, crit_chance, crit_multiplier)
		hit.knockback = Vector2(direction.x, direction.z).normalized() * knockback
		hit.source = shooter
		hit.attack_name = &"projectile"
		hurtbox.receive_hit(hit)
	queue_free()
