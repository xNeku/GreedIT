class_name MobSpawner
extends Marker2D
## Mantiene vivos `count` enemigos de `enemy_scene` alrededor de este punto.
## Cuando uno muere, aparece otro a los `respawn_delay` segundos (para farmear y probar).

@export var enemy_scene: PackedScene
@export var count := 2
@export var spawn_radius := 50.0
@export var respawn_delay := 5.0

var _alive: Array[Enemy] = []


func _ready() -> void:
	for i in count:
		_spawn.call_deferred()


func _spawn() -> void:
	if enemy_scene == null:
		return
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.position = position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, spawn_radius)
	enemy.died.connect(_on_enemy_died)
	get_parent().add_child(enemy)
	_alive.append(enemy)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive.erase(enemy)
	get_tree().create_timer(respawn_delay).timeout.connect(_spawn)


func alive() -> Array[Enemy]:
	return _alive
