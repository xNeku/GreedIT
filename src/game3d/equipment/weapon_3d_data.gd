class_name Weapon3DData
extends EquipmentData
## Arma 3D: su modelo (`scene`) y sus ataques (Attack3D). Todo se edita en el inspector del `.tres`.
##
## Controles (igual que en el 2D):
##   clic izq. pulsado  -> `combo` (se encadena pulsando otra vez)
##   clic izq. mantenido -> `hold_mode`: CHARGE = carga y al soltar `heavy`; REPEAT = ráfaga del combo
##   clic der.          -> `alt`;  mantenido -> carga y al soltar `alt_hold` (si existe)
##   atacar en el aire  -> `air` (p. ej. caída en picado con golpe al aterrizar)

enum Kind { MELEE, RANGED, MAGIC }
enum HoldMode { NONE, CHARGE, REPEAT }

@export var kind: Kind = Kind.MELEE
## Arma de la otra mano (dagas dobles...). Se equipa a la vez.
@export var offhand_scene: PackedScene
## Si se puede llevar escudo en la otra mano (armas de una mano sin arma secundaria).
@export var allows_shield := false
## Animación en reposo con esta arma.
@export var idle_clip := "Idle"
## Chuleta de controles que enseña el HUD.
@export_multiline var moves_hint := ""

@export_group("Daño")
@export var base_damage := 10.0
@export_range(0.0, 1.0) var crit_chance := 0.1
@export var crit_multiplier := 2.0
## Alcance y anchura de la zona de golpe delante del personaje (metros).
@export var reach := 1.8
@export var width := 1.8
@export var knockback := 6.0

@export_group("Clic izquierdo")
@export var combo: Array[Attack3D] = []
## Segundos tras un golpe en los que el combo sigue.
@export var combo_window := 0.6
@export var hold_mode: HoldMode = HoldMode.CHARGE
## Segundos manteniendo para que cuente como "mantener".
@export var hold_threshold := 0.2
## Ataque al soltar la carga (HoldMode.CHARGE).
@export var heavy: Attack3D
## Segundos para la carga completa y daño extra con carga completa.
@export var max_charge_time := 0.9
@export var max_charge_multiplier := 2.5
## Velocidad extra de la ráfaga (HoldMode.REPEAT).
@export var repeat_speed_scale := 1.4

@export_group("Clic derecho")
@export var alt: Attack3D
## Al mantener y soltar el clic derecho (vacío = mantener no hace nada especial).
@export var alt_hold: Attack3D
@export var alt_cooldown := 0.6

@export_group("En el aire")
@export var air: Attack3D

@export_group("Proyectiles")
@export var projectile_scene: PackedScene
@export var projectile_speed := 18.0
