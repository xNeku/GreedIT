class_name ShaderWarmup
extends Node3D
## Evita los tirones de la primera vez: Godot compila cada shader la primera vez que lo dibuja, y eso congela el
## juego un instante (la primera bola de fuego, la primera explosión...). Al cargar el mundo, este nodo saca una
## copia de cada efecto delante de la cámara durante unos frames (sin que hagan nada) y luego las borra.

## Escenas a precalentar (efectos, proyectiles, números de daño...).
@export var scenes: Array[PackedScene] = []
@export var frames := 3


func _ready() -> void:
	_warm.call_deferred()


func _warm() -> void:
	var camera := get_viewport().get_camera_3d()
	var spot := Vector3.ZERO
	if camera:
		spot = camera.global_position - camera.global_basis.z * 20.0
	var copies: Array[Node] = []
	for scene in scenes:
		if scene == null:
			continue
		var copy := scene.instantiate()
		copy.process_mode = Node.PROCESS_MODE_DISABLED # que no hagan daño ni se muevan
		if "visual_only" in copy:
			copy.set("visual_only", true)
		if copy is Area3D:
			(copy as Area3D).monitoring = false
		add_child(copy)
		if copy is Node3D:
			(copy as Node3D).global_position = spot
			(copy as Node3D).scale = Vector3.ONE * 0.05
		copies.append(copy)
	for i in frames:
		await get_tree().process_frame
	for copy in copies:
		copy.queue_free()
