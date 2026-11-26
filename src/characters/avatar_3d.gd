class_name Avatar3D
extends Node3D
## Personaje 3D: un esqueleto humanoide con sus animaciones + todo lo que lleva puesto (cuerpo, pelo, ropa, armas).
##
## La escena de cada personaje es: este script en la raíz + un glTF con esqueleto y AnimationPlayer como "Model"
## (hoy la Universal Animation Library de Quaternius). Los esqueletos están retargeteados al humanoide de Godot
## (ver assets/models/retarget/), así que valen animaciones de cualquier modelo humanoide:
##   - `extra_animation_sources` añade las de otros modelos (sin pisar las propias)
##   - `clip_aliases` traduce nombres (p. ej. la carrera "Running_A" de KayKit -> "Jog_Fwd" de Quaternius)
## Cuerpo, ojos, pelo, barba y ropa son equipo (`default_items`): se cambian en el inspector sin tocar código.

## Hueso al que se pega cada ranura de equipo rígido (EquipmentData.Slot) si no tiene nodo en `slot_attachments`.
@export var slot_bones := {
	EquipmentData.Slot.MAIN_HAND: "RightHand",
	EquipmentData.Slot.OFF_HAND: "LeftHand",
	EquipmentData.Slot.HEAD: "Head",
	EquipmentData.Slot.BACK: "UpperChest",
	EquipmentData.Slot.CHEST: "UpperChest",
}
## Nodo (Node3D dentro de esta escena) al que se pega cada ranura; manda sobre `slot_bones`. Sirve para
## colocar a mano en el editor dónde agarra la mano un arma (el "Grip" dentro de un BoneAttachment3D).
@export var slot_attachments := {}
## Lo que el personaje lleva puesto de serie (EquipmentData por ranura): cuerpo, ojos, pelo, barba, ropa...
@export var default_items := {}
## Mallas por nombre genérico ("hair"...): las piezas dicen qué tapan (`EquipmentData.hides_body_parts`)
## con estos nombres (p. ej. una capucha oculta "hair").
@export var body_parts := {}
## Animaciones que van en bucle.
@export var looping_clips: PackedStringArray = []
## Segundos de mezcla entre animaciones.
@export var blend_time := 0.12
## Escenas de las que se copian animaciones que este modelo no tenga (mismo esqueleto retargeteado).
@export var extra_animation_sources: Array[PackedScene] = []
## Nombre que pide el juego -> animación de este modelo.
@export var clip_aliases := {}

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
## Lo equipado en cada ranura: {"item": EquipmentData, "nodes": Array[Node], "hidden": Array[Node3D]}
var _slots := {}

@onready var model: Node3D = $Model


func _ready() -> void:
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	animation_player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_merge_animations()
	for clip in looping_clips:
		if animation_player.has_animation(clip):
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for slot: EquipmentData.Slot in default_items:
		equip(default_items[slot])


## Copia a nuestro AnimationPlayer las animaciones de `extra_animation_sources` que no tengamos.
## (Las librerías importadas se comparten entre instancias: solo se copian la primera vez.)
func _merge_animations() -> void:
	if extra_animation_sources.is_empty():
		return
	var library := animation_player.get_animation_library(&"")
	for source_scene in extra_animation_sources:
		var source := source_scene.instantiate()
		for player in source.find_children("*", "AnimationPlayer", true, false):
			var source_player := player as AnimationPlayer
			for clip in source_player.get_animation_list():
				if not library.has_animation(clip):
					library.add_animation(clip, source_player.get_animation(clip))
		source.free()


# --- Animación ------------------------------------------------------------

func play(clip: String, speed: float = 1.0, restart: bool = false) -> void:
	clip = clip_aliases.get(clip, clip)
	if not animation_player.has_animation(clip):
		return
	if restart and animation_player.current_animation == clip:
		animation_player.stop(true)
	animation_player.play(clip, blend_time, speed)


## Cambia la velocidad de la animación en curso sin reiniciarla.
func set_speed(clip: String, speed: float) -> void:
	clip = clip_aliases.get(clip, clip)
	if animation_player.has_animation(clip):
		animation_player.play(clip, blend_time, speed)


func clip_length(clip: String) -> float:
	clip = clip_aliases.get(clip, clip)
	return animation_player.get_animation(clip).length if animation_player.has_animation(clip) else 0.5


func is_playing(clip: String) -> bool:
	return animation_player.is_playing() and animation_player.current_animation == clip_aliases.get(clip, clip)


# --- Equipo ---------------------------------------------------------------

## Pone una pieza en su ranura (quita la anterior). null no hace nada: usa unequip().
func equip(item: EquipmentData) -> void:
	if item == null:
		return
	unequip(item.slot)
	var entry := {"item": item, "nodes": [], "hidden": []}
	if item.scene and item.skinned:
		entry.nodes = _dress_skinned(item)
	elif item.scene:
		var instance := item.scene.instantiate() as Node3D
		var holder: Node = get_node_or_null(slot_attachments[item.slot]) if slot_attachments.has(item.slot) else null
		if holder == null:
			holder = _bone_attachment(slot_bones.get(item.slot, "RightHand"))
		holder.add_child(instance)
		instance.position = item.position_offset
		instance.rotation_degrees = item.rotation_offset_degrees
		entry.nodes = [instance]
	for part_name in item.hides_body_parts:
		var part := skeleton.find_child(body_parts.get(part_name, part_name), false, false) as Node3D
		if part and part.visible:
			part.visible = false
			entry.hidden.append(part)
	_slots[item.slot] = entry


func unequip(slot: EquipmentData.Slot) -> void:
	if not _slots.has(slot):
		return
	var entry: Dictionary = _slots[slot]
	for node: Node in entry.nodes:
		node.queue_free()
	for part: Node3D in entry.hidden:
		if is_instance_valid(part):
			part.visible = true
	_slots.erase(slot)


func equipped(slot: EquipmentData.Slot) -> EquipmentData:
	return _slots[slot].item if _slots.has(slot) else null


## Viste una pieza con esqueleto propio (mismo esqueleto que el personaje) sobre nuestro esqueleto: sus mallas
## se deforman con todas nuestras animaciones. Las mallas cuyo esqueleto no encaja se saltan.
func _dress_skinned(item: EquipmentData) -> Array:
	var source := item.scene.instantiate()
	var dressed: Array = []
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null:
			continue
		if not item.mesh_names.is_empty() and not item.mesh_names.has(String(mesh.name)):
			continue
		if not _skin_fits(mesh.skin):
			continue
		mesh.get_parent().remove_child(mesh)
		mesh.owner = null
		skeleton.add_child(mesh)
		mesh.transform = Transform3D.IDENTITY
		mesh.skeleton = mesh.get_path_to(skeleton)
		mesh.visible = true
		if item.material_override:
			mesh.material_override = item.material_override
		dressed.append(mesh)
	source.free()
	return dressed


func _skin_fits(skin: Skin) -> bool:
	for i in skin.get_bind_count():
		var bind_name := skin.get_bind_name(i)
		if bind_name != &"" and skeleton.find_bone(bind_name) < 0:
			return false
	return true


## BoneAttachment3D del hueso (usa el que ya haya o crea uno).
func _bone_attachment(bone_name: String) -> BoneAttachment3D:
	for attachment in skeleton.find_children("*", "BoneAttachment3D", false, false):
		if (attachment as BoneAttachment3D).bone_name == bone_name:
			return attachment
	var created := BoneAttachment3D.new()
	created.name = "Slot_" + bone_name
	created.bone_name = bone_name
	skeleton.add_child(created)
	return created
