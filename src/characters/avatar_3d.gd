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
## Huesos de las animaciones de `extra_animation_sources` que en nuestro esqueleto se llaman distinto
## (p. ej. KayKit gira la muñeca con "hand.r", que en el nuestro es "RightHand").
@export var animation_bone_remap := {}
## Huesos que añadimos al esqueleto: nombre -> [hueso padre, reposo (Transform3D)]. Sirven para el arma: KayKit
## gira el arma dentro de la mano al atacar (su hueso "handslot"), y eso llega a nuestro "WeaponR"/"WeaponL".
@export var extra_bones := {}

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
## Lo equipado en cada ranura: {"item": EquipmentData, "nodes": Array[Node], "hidden": Array[Node3D]}
var _slots := {}

@onready var model: Node3D = $Model


func _ready() -> void:
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	animation_player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_add_extra_bones()
	_merge_animations()
	for clip in looping_clips:
		if animation_player.has_animation(clip):
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for slot: EquipmentData.Slot in default_items:
		equip(default_items[slot])


func _add_extra_bones() -> void:
	for bone_name: String in extra_bones:
		if skeleton.find_bone(bone_name) >= 0:
			continue
		var info: Array = extra_bones[bone_name]
		var bone := skeleton.get_bone_count()
		skeleton.add_bone(bone_name)
		skeleton.set_bone_parent(bone, skeleton.find_bone(info[0]))
		skeleton.set_bone_rest(bone, info[1])
		skeleton.reset_bone_pose(bone)
	# los BoneAttachment3D que apuntan a estos huesos se crearon antes de que existieran: que los busquen otra vez
	for attachment in skeleton.find_children("*", "BoneAttachment3D", false, false):
		var bone_attachment := attachment as BoneAttachment3D
		if extra_bones.has(bone_attachment.bone_name):
			bone_attachment.bone_name = bone_attachment.bone_name


## Copia a nuestro AnimationPlayer las animaciones de `extra_animation_sources` que no tengamos.
## (Las librerías importadas se comparten entre instancias: solo se copian la primera vez.)
func _merge_animations() -> void:
	if extra_animation_sources.is_empty():
		return
	var library := animation_player.get_animation_library(&"")
	for source_scene in extra_animation_sources:
		var source := source_scene.instantiate()
		var source_skeletons := source.find_children("*", "Skeleton3D", true, false)
		var source_skeleton: Skeleton3D = source_skeletons[0] if not source_skeletons.is_empty() else null
		for player in source.find_children("*", "AnimationPlayer", true, false):
			var source_player := player as AnimationPlayer
			for clip in source_player.get_animation_list():
				if not library.has_animation(clip):
					library.add_animation(clip, _adapt_rotations(source_player.get_animation(clip), source_skeleton))
		source.free()
	# las animaciones que no mueven los huesos añadidos los dejan en reposo (si no, se quedarían como en la anterior)
	for clip_name in library.get_animation_list():
		_add_rest_tracks(library.get_animation(clip_name))


func _add_rest_tracks(clip: Animation) -> void:
	var prefix := ""
	for track in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			prefix = str(clip.track_get_path(track)).get_slice(":", 0)
			break
	if prefix == "":
		return
	for bone_name: String in extra_bones:
		var path := NodePath(prefix + ":" + bone_name)
		if clip.find_track(path, Animation.TYPE_ROTATION_3D) >= 0:
			continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, path)
		clip.rotation_track_insert_key(track, 0.0, (extra_bones[bone_name][1] as Transform3D).basis.get_rotation_quaternion())


## Pasa los giros de un esqueleto a otro. Los dos están en la misma pose de reposo vistos desde fuera, pero un
## hueso puede tener otro giro "local" (KayKit no tiene clavícula: su hombro va sin girar y el brazo lleva todo el
## giro), así que copiar los giros tal cual levanta los brazos. Se copia el giro de cada hueso visto desde fuera:
##   nuevo = (reposo global del padre nuestro)⁻¹ · (reposo global del padre suyo) · giro · (reposo global suyo)⁻¹ · (reposo global nuestro)
func _adapt_rotations(source_clip: Animation, source_skeleton: Skeleton3D) -> Animation:
	if source_skeleton == null:
		return source_clip
	var clip := source_clip.duplicate(true) as Animation
	var path_prefix := ""
	for track in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			path_prefix = str(clip.track_get_path(track)).get_slice(":", 0)
			break
	for track in range(clip.get_track_count() - 1, -1, -1):
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D \
				and animation_bone_remap.has(clip.track_get_path(track).get_concatenated_subnames()):
			clip.remove_track(track) # solo se pasa el giro (las posiciones son de otro tamaño de muñeco)
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var source_name := clip.track_get_path(track).get_concatenated_subnames()
		var our_name: String = animation_bone_remap.get(source_name, source_name)
		var ours := skeleton.find_bone(our_name)
		var theirs := source_skeleton.find_bone(source_name)
		if ours < 0 or theirs < 0:
			continue
		if our_name != source_name:
			if clip.find_track(NodePath(path_prefix + ":" + our_name), Animation.TYPE_ROTATION_3D) >= 0:
				continue
			clip.track_set_path(track, NodePath(path_prefix + ":" + our_name))
		var before := _global_rest(skeleton, skeleton.get_bone_parent(ours)).inverse() \
				* _global_rest(source_skeleton, source_skeleton.get_bone_parent(theirs))
		var after := _global_rest(source_skeleton, theirs).inverse() * _global_rest(skeleton, ours)
		if before.is_equal_approx(Quaternion.IDENTITY) and after.is_equal_approx(Quaternion.IDENTITY):
			continue
		for key in clip.track_get_key_count(track):
			var value: Quaternion = clip.track_get_key_value(track, key)
			clip.track_set_key_value(track, key, (before * value * after).normalized())
	return clip


func _global_rest(target: Skeleton3D, bone: int) -> Quaternion:
	if bone < 0:
		return Quaternion.IDENTITY
	return target.get_bone_global_rest(bone).basis.get_rotation_quaternion()


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
