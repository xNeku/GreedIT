class_name EquipmentData
extends ItemData
## Pieza de equipo 3D (arma, escudo, casco, capa, armadura).
##
## Tres maneras de ponerla sobre el personaje:
##  - `builtin_node`: una malla que el modelo ya trae (p. ej. el casco del caballero de KayKit). Se muestra/oculta.
##  - `scene` (rígida): un glTF que se pega al hueso de la ranura (armas a la mano, casco a la cabeza...).
##  - `scene` + `skinned`: un glTF con el MISMO esqueleto (exportado sobre el cuerpo base en Blender).
##    Sus mallas se "visten" sobre el esqueleto del personaje y se deforman con él: encaja en cualquier animación.

enum Slot { MAIN_HAND, OFF_HAND, HEAD, BACK, CHEST }

@export var slot: Slot = Slot.MAIN_HAND
@export var builtin_node := ""
@export var scene: PackedScene
@export var skinned := false
## Solo piezas `skinned`: qué mallas de la escena usar (vacío = todas las que tengan esqueleto).
@export var mesh_names: PackedStringArray = []
## Partes del cuerpo que esta pieza tapa y se ocultan: "head", "body", "arm_l", "arm_r", "leg_l", "leg_r"
## (ver `Avatar3D.body_parts`). P. ej. un peto tapa "body".
@export var hides_body_parts: PackedStringArray = []
@export var position_offset := Vector3.ZERO
@export var rotation_offset_degrees := Vector3.ZERO
