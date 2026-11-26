class_name Avatar3D
extends Node3D
## Personaje 3D: un modelo con esqueleto (glTF de Blender / Mixamo / KayKit) + su equipo + sus animaciones.
##
## La escena de cada personaje es: este script en la raíz + el glTF instanciado como "Model".
## Requisitos del modelo (los cumplen los de KayKit y los que se exporten de Blender con el mismo esqueleto):
##   - un Skeleton3D con huesos para las ranuras (ver `slot_bones`)
##   - un AnimationPlayer con las animaciones
## Las mallas que el modelo trae pegadas a huesos (armas, escudos, casco, capa de muestra) se ocultan al empezar:
## se ven solo si se equipan como `builtin_node`.

## Hueso al que se pega cada ranura de equipo (EquipmentData.Slot).
@export var slot_bones := {
	EquipmentData.Slot.MAIN_HAND: "handslot.r",
	EquipmentData.Slot.OFF_HAND: "handslot.l",
	EquipmentData.Slot.HEAD: "head",
	EquipmentData.Slot.BACK: "chest",
	EquipmentData.Slot.CHEST: "chest",
}
## Mallas del cuerpo por nombre genérico ("body", "head"...). Las armaduras dicen qué partes tapan
## (`EquipmentData.hides_body_parts`) con estos nombres, así sirven para cualquier personaje.
@export var body_parts := {
	"head": "Knight_Head", "body": "Knight_Body", "arm_l": "Knight_ArmLeft", "arm_r": "Knight_ArmRight",
	"leg_l": "Knight_LegLeft", "leg_r": "Knight_LegRight",
}
## Ropa de serie del modelo (mallas que trae pegadas a huesos) por ranura: se ve con `set_outfit_visible`.
@export var outfit := {
	EquipmentData.Slot.HEAD: "Knight_Helmet",
	EquipmentData.Slot.BACK: "Knight_Cape",
}
## Animaciones que van en bucle.
@export var looping_clips: PackedStringArray = [
	"Idle", "Running_A", "Running_B", "Walking_A", "Walking_B", "Jump_Idle", "Blocking",
	"2H_Melee_Idle", "Unarmed_Idle", "Spellcasting", "1H_Ranged_Aiming", "2H_Ranged_Aiming",
]
## Segundos de mezcla entre animaciones.
@export var blend_time := 0.12

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
## Lo equipado en cada ranura: {"item": EquipmentData, "nodes": Array[Node], "hidden": Array[Node3D]}
var _slots := {}

@onready var model: Node3D = $Model


func _ready() -> void:
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	animation_player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in looping_clips:
		if animation_player.has_animation(clip):
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# Accesorios de serie (pegados a huesos): ocultos hasta que se equipen.
	for attachment in skeleton.find_children("*", "BoneAttachment3D", false, false):
		for child in attachment.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false


# --- Animación ------------------------------------------------------------

func play(clip: String, speed: float = 1.0, restart: bool = false) -> void:
	if not animation_player.has_animation(clip):
		return
	if restart and animation_player.current_animation == clip:
		animation_player.stop(true)
	animation_player.play(clip, blend_time, speed)


func clip_length(clip: String) -> float:
	return animation_player.get_animation(clip).length if animation_player.has_animation(clip) else 0.5


# --- Equipo ---------------------------------------------------------------

## Pone una pieza en su ranura (quita la anterior). null en `item` no hace nada: usa unequip().
func equip(item: EquipmentData) -> void:
	if item == null:
		return
	unequip(item.slot)
	var entry := {"item": item, "nodes": [], "hidden": []}
	if item.builtin_node != "":
		var node := skeleton.find_child(item.builtin_node, true, false) as Node3D
		if node:
			node.visible = true
			entry.builtin = node
	elif item.scene and item.skinned:
		entry.nodes = _dress_skinned(item)
	elif item.scene:
		var instance := item.scene.instantiate() as Node3D
		_bone_attachment(slot_bones.get(item.slot, "hand.r")).add_child(instance)
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
	if entry.has("builtin"):
		(entry.builtin as Node3D).visible = false
	for node: Node in entry.nodes:
		node.queue_free()
	for part: Node3D in entry.hidden:
		part.visible = true
	_slots.erase(slot)


## Muestra u oculta la ropa de serie de una ranura (casco, capa...). Si hay algo equipado ahí, manda lo equipado.
func set_outfit_visible(slot: EquipmentData.Slot, on: bool) -> void:
	if not outfit.has(slot):
		return
	var node := skeleton.find_child(outfit[slot], true, false) as Node3D
	if node:
		node.visible = on and not _slots.has(slot)


func equipped(slot: EquipmentData.Slot) -> EquipmentData:
	return _slots[slot].item if _slots.has(slot) else null


## Viste una pieza con esqueleto propio (mismo esqueleto que el personaje) sobre nuestro esqueleto.
func _dress_skinned(item: EquipmentData) -> Array:
	var source := item.scene.instantiate()
	var dressed: Array = []
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null:
			continue
		if not item.mesh_names.is_empty() and not item.mesh_names.has(String(mesh.name)):
			continue
		mesh.get_parent().remove_child(mesh)
		mesh.owner = null
		skeleton.add_child(mesh)
		mesh.transform = Transform3D.IDENTITY
		mesh.skeleton = mesh.get_path_to(skeleton)
		mesh.visible = true
		dressed.append(mesh)
	source.free()
	return dressed


## BoneAttachment3D del hueso (usa el que traiga el modelo o crea uno).
func _bone_attachment(bone_name: String) -> BoneAttachment3D:
	for attachment in skeleton.find_children("*", "BoneAttachment3D", false, false):
		if (attachment as BoneAttachment3D).bone_name == bone_name:
			return attachment
	var created := BoneAttachment3D.new()
	created.name = "Slot_" + bone_name.replace(".", "_")
	created.bone_name = bone_name
	skeleton.add_child(created)
	return created
