class_name StaticBatcher
extends Node3D
## Optimización de decoración estática (árboles, rocas, plantas, terreno...): en el editor sus hijos son objetos
## normales (se mueven y se editan uno a uno); al empezar la partida, todas las mallas iguales de cada zona se
## juntan en un MultiMesh (una sola llamada de dibujo por malla y zona) y los originales se borran.
## Se agrupa por zonas (`cell_size`) para que lo que queda fuera de la pantalla no se dibuje.
## No toca colisiones: van aparte (StaticBody del mundo).

## Lado (metros) de cada zona de agrupado.
@export var cell_size := 24.0
## Si estas mallas proyectan sombra (el suelo no hace falta: ahorra mucho en el mapa de sombras).
@export var cast_shadows := true


func _ready() -> void:
	_batch.call_deferred()


func _batch() -> void:
	var to_local := global_transform.affine_inverse()
	var groups := {} # [mesh, celda] -> Array[Transform3D]
	var meshes := {}
	var done: Array[Node] = []
	for child in get_children():
		var parts := child.find_children("*", "MeshInstance3D", true, false)
		if child is MeshInstance3D:
			parts.append(child)
		var batchable := not parts.is_empty()
		for node in parts:
			var mi := node as MeshInstance3D
			if mi.mesh == null or mi.material_override != null or _has_surface_override(mi):
				batchable = false
		if not batchable:
			continue
		for node in parts:
			var mi := node as MeshInstance3D
			var xf := to_local * mi.global_transform
			var cell := Vector2i(floori(xf.origin.x / cell_size), floori(xf.origin.z / cell_size))
			var key := "%d|%d|%d" % [mi.mesh.get_instance_id(), cell.x, cell.y]
			if not groups.has(key):
				groups[key] = []
				meshes[key] = mi.mesh
			(groups[key] as Array).append(xf)
		done.append(child)
	for key: String in groups:
		var transforms: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[key]
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	for child in done:
		child.queue_free()


func _has_surface_override(mi: MeshInstance3D) -> bool:
	for i in mi.get_surface_override_material_count():
		if mi.get_surface_override_material(i) != null:
			return true
	return false
