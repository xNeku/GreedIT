@tool
extends EditorScenePostImport
## Script de importación de TODOS los modelos 3D (.glb / .gltf) para el estilo pixel art:
##  - luz por bandas (toon) en vez de degradado realista
##  - texturas sin suavizado (nearest), que con la resolución baja dan píxeles limpios
##  - contorno oscuro (`assets/materials/outline_3d.tres`) en personajes, armas y props
##    (no en suelos ni paredes, que se pegarían entre baldosas)
## Se aplica al importar: en el editor ya se ven así. Para un modelo propio, en su pestaña Importar pon
## este script en "Import Script" (los de assets/models ya lo llevan).

const OUTLINE := preload("res://assets/materials/outline_3d.tres")
## Mallas sin contorno (por prefijo del nombre del archivo).
const NO_OUTLINE_PREFIXES: PackedStringArray = ["floor", "wall", "stairs"]


func _post_import(scene: Node) -> Object:
	var file := get_source_file().get_file().to_lower()
	var outline := true
	for prefix in NO_OUTLINE_PREFIXES:
		if file.begins_with(prefix):
			outline = false
	var done := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as StandardMaterial3D
			if material == null or done.has(material):
				continue
			done[material] = true
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			material.roughness = 1.0
			material.metallic = 0.0
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if outline:
				material.next_pass = OUTLINE
	return scene
