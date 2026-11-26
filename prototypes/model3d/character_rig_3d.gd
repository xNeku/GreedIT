class_name CharacterRig3D
extends Node3D
## PROTOTIPO: personaje 3D por piezas (vóxeles generados desde los sprites con tools/baker/voxelize.py).
## Esqueleto simple: Hips -> Torso -> Head, Hips -> Cloth / LegL / LegR, y manos flotantes (HandL, HandR -> Sword).
## Las armaduras se cuelgan del pivote de la pieza que cubren (p. ej. ArmorChest dentro de Torso): encajan solas.
## pose(anim, t) coloca el esqueleto en el instante t (0..1) de la animación. La usan el horneado a sprites
## (prototipo A) y el juego 3D real (prototipo B).

## Material de los vóxeles (color por vértice, luz por bandas; con o sin contorno).
@export var material: Material
@export var show_armor := true:
	set(value):
		show_armor = value
		if is_node_ready():
			armor.visible = value

var _rest := {}

@onready var hips: Node3D = $Hips
@onready var torso: Node3D = $Hips/Torso
@onready var head: Node3D = $Hips/Torso/Head
@onready var cloth: Node3D = $Hips/Cloth
@onready var leg_l: Node3D = $Hips/LegL
@onready var leg_r: Node3D = $Hips/LegR
@onready var hand_l: Node3D = $HandL
@onready var hand_r: Node3D = $HandR
@onready var sword: Node3D = $HandR/Sword
@onready var armor: Node3D = $Hips/Torso/ArmorChest


func _ready() -> void:
	if material:
		for mi in find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = material
	for n: Node3D in [hips, torso, head, cloth, leg_l, leg_r, hand_l, hand_r, sword]:
		_rest[n] = n.transform
	armor.visible = show_armor


## Coloca la pose de `anim` en el instante t (0..1).
func pose(anim: StringName, t: float) -> void:
	for n: Node3D in _rest:
		n.transform = _rest[n]
	sword.visible = anim == &"attack"
	var s := sin(t * TAU)
	var c := cos(t * TAU)
	match anim:
		&"idle":
			torso.position.y += 0.6 * (1.0 - c) * 0.5
			hand_l.position.y += -c * 0.8
			hand_r.position.y += -c * 0.8
		&"run":
			hips.position.y += 2.0 * absf(s)
			hips.rotation.x = deg_to_rad(8.0) # inclinado hacia delante
			leg_l.rotation.x = deg_to_rad(40.0) * s
			leg_r.rotation.x = -deg_to_rad(40.0) * s
			hand_l.position += Vector3(0, 2.0 * absf(s), -9.0 * s)
			hand_r.position += Vector3(0, 2.0 * absf(s), 9.0 * s)
			torso.rotation.y = deg_to_rad(8.0) * s
		&"attack":
			# tajo: la mano derecha va de arriba-atrás a abajo-delante, la espada gira con ella y el torso acompaña
			var k := clampf(t * 1.5, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 3.0)
			torso.rotation.y = deg_to_rad(lerpf(-30.0, 30.0, e))
			hips.rotation.x = deg_to_rad(lerpf(-4.0, 10.0, e))
			hand_r.position += Vector3(lerpf(-8, -2, e), lerpf(22, 2, e), lerpf(-6, 18, e))
			sword.rotation.x = deg_to_rad(lerpf(-40.0, 115.0, e))
			hand_l.position += Vector3(lerpf(6, -2, e), lerpf(2, -2, e), lerpf(8, -6, e))
			leg_l.rotation.x = deg_to_rad(lerpf(-12, 18, e))
			leg_r.rotation.x = deg_to_rad(lerpf(12, -12, e))
