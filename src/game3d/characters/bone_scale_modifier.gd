@tool
class_name BoneScaleModifier
extends SkeletonModifier3D
## Cambia el tamaño de algunos huesos encima de cualquier animación (p. ej. cabeza más pequeña para que un
## modelo cabezón tenga proporciones más adultas). Va como hijo del Skeleton3D del personaje.
## Se ve en el editor al instante (@tool).

## Hueso -> escala (1 = normal). Todo lo pegado a ese hueso (casco...) escala con él.
@export var bone_scales := {"head": 0.72}


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone_name: String in bone_scales:
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			var s: float = bone_scales[bone_name]
			skeleton.set_bone_pose_scale(bone, skeleton.get_bone_pose_scale(bone) * s)
