class_name EquipmentData
extends ItemData
## Pieza de equipo 3D (arma, escudo, casco, ropa, y también cuerpo, pelo y barba del personaje).
##
## Dos maneras de ponerla sobre el personaje:
##  - `scene` (rígida): un glTF que se pega al hueso de la ranura (armas a la mano, casco a la cabeza...).
##  - `scene` + `skinned`: un glTF con el MISMO esqueleto (exportado sobre el cuerpo base en Blender).
##    Sus mallas se "visten" sobre el esqueleto del personaje y se deforman con él: encaja en cualquier animación.

## OUTFIT = conjunto de ropa entero (cuerpo, brazos, piernas, botas) de los personajes modulares.
## BODY / FACE / HAIR / BEARD = el cuerpo base, ojos y cejas, pelo y barba (también son "equipo": se cambian igual).
enum Slot { MAIN_HAND, OFF_HAND, HEAD, BACK, CHEST, OUTFIT, BODY, FACE, HAIR, BEARD }

@export var slot: Slot = Slot.MAIN_HAND
@export var scene: PackedScene
@export var skinned := false
## Solo piezas `skinned`: qué mallas de la escena usar (vacío = todas las que tengan esqueleto).
@export var mesh_names: PackedStringArray = []
## Partes del personaje que esta pieza tapa y se ocultan (nombres de `Avatar3D.body_parts`, p. ej. una capucha
## tapa "hair").
@export var hides_body_parts: PackedStringArray = []
## Material que se pone a todas sus mallas (p. ej. el cuerpo base algo encogido para que no asome por la ropa).
@export var material_override: Material
@export var position_offset := Vector3.ZERO
@export var rotation_offset_degrees := Vector3.ZERO
