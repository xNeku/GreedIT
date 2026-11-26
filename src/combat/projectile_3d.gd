class_name Projectile3D
extends Area3D
## Proyectil 3D (virote, daga, proyectil mágico, bola de fuego). Lo crea Player3D en todos los peers; solo la
## copia del dueño hace daño (las demás son `visual_only`).
## Si tiene `explosion_scene`, al chocar o llegar a su distancia máxima explota (daño en área).
## Capa: player_attacks (4). Máscara: world (1) + enemy_hurtbox (5).

@export var lifetime := 1.5
@export var knockback := 5.0
## Atraviesa enemigos (si no, desaparece al primer golpe).
@export var pierce := false
## Explosión al chocar o al llegar a `max_distance` (Explosion3D).
@export var explosion_scene: PackedScene

var direction := Vector3.FORWARD
var speed := 18.0
var damage := 10.0
var crit_chance := 0.1
var crit_multiplier := 2.0
## Distancia a la que explota / desaparece (0 = sin límite, solo `lifetime`).
var max_distance := 0.0
var shooter: Node
var visual_only := false

var _travelled := 0.0
var _hit: Array[Hurtbox3D] = []
var _done := false


func _ready() -> void:
	look_at(global_position + direction, Vector3.UP)
	area_entered.connect(_on_area_entered)
	body_entered.connect(func(_b: Node3D) -> void: _finish())


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += direction * step
	_travelled += step
	lifetime -= delta
	if lifetime <= 0.0 or (max_distance > 0.0 and _travelled >= max_distance):
		_finish()


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox3D
	if hurtbox == null or _hit.has(hurtbox) or _done:
		return
	_hit.append(hurtbox)
	if explosion_scene:
		_finish()
		return
	if not visual_only:
		var hit := HitData.roll(damage, 1.0, crit_chance, crit_multiplier)
		hit.knockback = Vector2(direction.x, direction.z).normalized() * knockback
		hit.source = shooter
		hit.attack_name = &"projectile"
		hurtbox.receive_hit(hit)
	if not pierce:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if explosion_scene:
		var explosion := explosion_scene.instantiate() as Explosion3D
		explosion.damage = damage
		explosion.crit_chance = crit_chance
		explosion.crit_multiplier = crit_multiplier
		explosion.knockback = knockback
		explosion.shooter = shooter
		explosion.deal_damage = not visual_only
		get_parent().add_child(explosion)
		explosion.global_position = global_position
	queue_free()
