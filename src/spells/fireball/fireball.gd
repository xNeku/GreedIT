class_name Fireball
extends Area2D
## Bola de fuego: vuela recta con su luz y su estela, y explota al tocar un enemigo, una pared
## o al acabar su vida. La explosión (`explosion_scene`) hace el daño en área.
## Capa: player_attacks (4). Máscara: world (1) + enemy_hurtbox (5).

@export var lifetime := 1.1
@export var explosion_scene: PackedScene

var direction := Vector2.RIGHT
var speed := 300.0
var spell: SpellData
var caster: Node
var _exploded := false

@onready var trail: CPUParticles2D = $Trail


func _ready() -> void:
	rotation = direction.angle()
	area_entered.connect(func(area: Area2D) -> void:
		if area is Hurtbox:
			explode())
	body_entered.connect(func(_body: Node2D) -> void: explode())


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		explode()


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	if explosion_scene:
		var explosion := explosion_scene.instantiate() as SpellExplosion
		explosion.spell = spell
		explosion.caster = caster
		get_parent().add_child(explosion)
		explosion.global_position = global_position
	# La estela se queda un momento flotando antes de desaparecer.
	trail.emitting = false
	trail.reparent(get_parent())
	get_tree().create_timer(trail.lifetime + 0.1).timeout.connect(trail.queue_free)
	queue_free()
