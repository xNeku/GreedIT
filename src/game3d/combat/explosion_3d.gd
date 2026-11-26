class_name Explosion3D
extends OneShotFX
## Explosión con daño en área (bola de fuego...). Se ve en todos los peers; solo la copia del dueño
## (`deal_damage`) hace daño: busca Hurtbox3D en un radio con una consulta de física.

@export var radius := 2.8
## Capas que golpea (5 = enemy_hurtbox).
@export_flags_3d_physics var hit_mask := 16

var damage := 18.0
var crit_chance := 0.1
var crit_multiplier := 1.8
var knockback := 8.0
var shooter: Node
var deal_damage := false


func _ready() -> void:
	super._ready()
	Events.camera_shake_requested.emit(0.35, 0.18)
	if deal_damage:
		_apply_damage.call_deferred()


func _apply_damage() -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.8, 0))
	query.collision_mask = hit_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var hurtbox := result.collider as Hurtbox3D
		if hurtbox == null:
			continue
		var hit := HitData.roll(damage, 1.0, crit_chance, crit_multiplier)
		var push := hurtbox.global_position - global_position
		hit.knockback = Vector2(push.x, push.z).normalized() * knockback
		hit.source = shooter
		hit.attack_name = &"explosion"
		hurtbox.receive_hit(hit)
