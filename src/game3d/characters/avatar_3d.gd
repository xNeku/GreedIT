class_name Avatar3D
extends Node3D
## Personaje 3D: un modelo con esqueleto (glTF de Blender / Mixamo / KayKit) + su equipo + sus animaciones.
##
## La escena de cada personaje es: este script en la raíz + el glTF instanciado como "Model".
## Requisitos del modelo (los cumplen los de KayKit y los que se exporten de Blender con el mismo esqueleto):
##   - un Skeleton3D con huesos para las ranuras (ver `slot_bones` / `slot_attachments`)
##   - un AnimationPlayer con las animaciones
## Con esqueletos "retargeteados" al humanoide de Godot (ver assets/models/retarget/) un personaje puede usar
## animaciones de otros modelos: `extra_animation_sources` las añade (sin pisar las suyas) y `clip_aliases`
## traduce nombres (p. ej. la carrera "Running_A" de KayKit -> "Jog_Fwd" de Quaternius).
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
## Nodo (Node3D dentro de esta escena) al que se pega cada ranura; manda sobre `slot_bones`. Sirve para
## colocar a mano en el editor dónde agarra la mano un arma (p. ej. un "Grip" dentro de un BoneAttachment3D).
@export var slot_attachments := {}
## Ropa que el personaje lleva puesta de serie (EquipmentData por ranura, p. ej. el conjunto y la capucha).
## H / G la quitan y la ponen con `set_outfit_visible`.
@export var default_items := {}
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
	# Accesorios de serie (pegados a huesos): ocultos hasta que se equipen.
	for attachment in skeleton.find_children("*", "BoneAttachment3D", false, false):
		for child in attachment.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false
	for slot: EquipmentData.Slot in default_items:
		equip(default_items[slot])


## Copia a nuestro AnimationPlayer las animaciones de `extra_animation_sources` que no tengamos.
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


## Velocidad de la animación en curso (sin reiniciarla).
func set_speed(clip: String, speed: float) -> void:
	clip = clip_aliases.get(clip, clip)
	if animation_player.has_animation(clip):
		animation_player.play(clip, blend_time, speed)


func clip_length(clip: String) -> float:
	clip = clip_aliases.get(clip, clip)
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
		var holder: Node = get_node_or_null(slot_attachments[item.slot]) if slot_attachments.has(item.slot) else null
		if holder == null:
			holder = _bone_attachment(slot_bones.get(item.slot, "hand.r"))
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
	if entry.has("builtin"):
		(entry.builtin as Node3D).visible = false
	for node: Node in entry.nodes:
		node.queue_free()
	for part: Node3D in entry.hidden:
		part.visible = true
	_slots.erase(slot)


## Muestra u oculta la ropa de serie de una ranura (casco, capa...). Si hay algo equipado ahí, manda lo equipado.
func set_outfit_visible(slot: EquipmentData.Slot, on: bool) -> void:
	if default_items.has(slot):
		var default_item: EquipmentData = default_items[slot]
		var current := equipped(slot)
		if on and current == null:
			equip(default_item)
		elif not on and current == default_item:
			unequip(slot)
		return
	if not outfit.has(slot):
		return
	var node := skeleton.find_child(outfit[slot], true, false) as Node3D
	if node:
		node.visible = on and not _slots.has(slot)


func equipped(slot: EquipmentData.Slot) -> EquipmentData:
	return _slots[slot].item if _slots.has(slot) else null


## Viste una pieza con esqueleto propio (mismo esqueleto que el personaje) sobre nuestro esqueleto.
## Las mallas cuyo esqueleto no encaja (huesos con otros nombres) se saltan.
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


func _skin_fits(skin: Skin) -> bool:
	for i in skin.get_bind_count():
		var bind_name := skin.get_bind_name(i)
		if bind_name != &"" and skeleton.find_bone(bind_name) < 0:
			return false
	return true
