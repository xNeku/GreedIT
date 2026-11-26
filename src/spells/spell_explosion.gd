class_name SpellExplosion
extends Node2D
## Explosión de un hechizo: daña una vez a todos los Hurtbox enemigos en `radius`
## y reproduce la animación "explode" de la escena (anillo, luz, chispas). Se borra al terminar.

@export var radius := 34.0
## Multiplicador sobre el daño base del hechizo.
@export var damage_multiplier := 1.0
@export var hitstop := 0.06
@export var shake := 3.5
@export var attack_name: StringName = &"fireball"

var spell: SpellData
var caster: Node

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.animation_finished.connect(func(_n: StringName) -> void: queue_free())
	animation_player.play(&"explode")
	_deal_damage.call_deferred()


func _deal_damage() -> void:
	# RED: solo la copia de quien lanzó el hechizo hace daño; las demás son visuales.
	if spell == null or caster == null or not is_instance_valid(caster) or not caster.is_multiplayer_authority():
		Events.camera_shake_requested.emit(shake * 0.4, 0.12)
		return
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 16 # enemy_hurtbox
	var hit_any := false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var hurtbox := result.collider as Hurtbox
		if hurtbox == null:
			continue
		var hit := HitData.roll(spell.base_damage, damage_multiplier, spell.crit_chance, spell.crit_multiplier)
		hit.knockback = (hurtbox.global_position - global_position).normalized() * spell.knockback
		hit.source = caster
		hit.attack_name = attack_name
		hit.tags = PackedStringArray(["spell", "fire", "aoe"])
		hurtbox.receive_hit(hit)
		var target := hurtbox.owner if hurtbox.owner else hurtbox.get_parent()
		Events.hit_landed.emit(hit, target)
		hit_any = true
	Events.camera_shake_requested.emit(shake, 0.18)
	if hit_any:
		Events.hitstop_requested.emit(hitstop)
