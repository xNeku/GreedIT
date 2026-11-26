# Retarget (compartir animaciones entre esqueletos)

Godot traduce cada esqueleto al **humanoide estándar** (`SkeletonProfileHumanoid`: Hips, Spine, Chest, Head,
LeftUpperArm...) al importar. Así una animación hecha para un esqueleto sirve para otro.

- `ual_bone_map.tres`: esqueleto de Quaternius / Unreal (pelvis, spine_01, upperarm_l...). Lo usan la
  Universal Animation Library y la ropa modular.
- `kaykit_bone_map.tres`: esqueleto de KayKit (hips, upperarm.l, wrist.l...). Lo usa
  `kaykit_adventurers/animations/KayKit_Animations.glb`, una copia del caballero que solo sirve como fuente de
  animaciones de armas (los personajes KayKit originales no se tocan).

Para un modelo nuevo (Blender, Mixamo...): en su pestaña Importar → Skeleton3D → Retarget → Bone Map, crea uno
(Godot casi siempre adivina los huesos solo) o usa uno de estos si el esqueleto es el mismo.
