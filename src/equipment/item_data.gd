class_name ItemData
extends Resource
## Datos base de cualquier objeto (armas, materiales, pociones...).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 1
