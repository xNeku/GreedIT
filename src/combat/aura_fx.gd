class_name AuraFX
extends Node3D
## Aura de usar y tirar pegada a un personaje (p. ej. tras la esquiva): enciende su efecto (`Visual`), tiñe el
## cuerpo con `body_overlay` mientras dura y se borra al acabar. Colores y duración se tocan en su escena.

## Segundos que dura encendida.
@export var duration := 1.2
## Segundos que tarda en apagarse.
@export var fade_time := 0.5
## Material que se pone por encima de las mallas del cuerpo (vacío = no tiñe).
@export var body_overlay: Material

var _tinted: Array[MeshInstance3D] = []

@onready var visual: Node3D = $Visual


func _ready() -> void:
	if body_overlay:
		for node in get_parent().find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.skin != null and mesh.material_overlay == null:
				mesh.material_overlay = body_overlay
				_tinted.append(mesh)
	if visual.has_method("open"):
		visual.call("open")
	await get_tree().create_timer(duration, false).timeout
	_untint()
	if visual.has_method("close"):
		visual.call("close")
	await get_tree().create_timer(fade_time, false).timeout
	queue_free()


func _exit_tree() -> void:
	_untint()


func _untint() -> void:
	for mesh in _tinted:
		if is_instance_valid(mesh) and mesh.material_overlay == body_overlay:
			mesh.material_overlay = null
	_tinted.clear()
