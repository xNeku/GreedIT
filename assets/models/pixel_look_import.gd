@tool
extends EditorScenePostImport
## Script de importación de TODOS los modelos 3D (.glb / .gltf) con el look elegido por el dueño (Look Lab):
##  - todos los materiales pasan a `world_lit.gdshader`: solo el color (y su textura sin suavizar), sin brillos,
##    relieve ni oclusión; luz suave de día y por bandas de noche (ajuste global `light_bands`)
## Se aplica al importar: en el editor ya se ven así. Para un modelo propio, en su pestaña Importar pon
## este script en "Import Script" (los de assets/models ya lo llevan).

## Material único del juego: luz suave o por bandas según la hora (ver world_lit.gdshader).
const WORLD_SHADER := preload("res://assets/materials/world_lit.gdshader")


func _post_import(scene: Node) -> Object:
	var done := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var source := mesh.surface_get_material(i) as BaseMaterial3D
			if source == null:
				continue
			if not done.has(source):
				var material := ShaderMaterial.new()
				material.shader = WORLD_SHADER
				material.resource_name = source.resource_name
				material.set_shader_parameter(&"albedo_color", source.albedo_color)
				if source.albedo_texture:
					material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
				done[source] = material
			mesh.surface_set_material(i, done[source])
	return scene
