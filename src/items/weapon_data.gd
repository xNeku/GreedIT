class_name WeaponData
extends ItemData
## Datos de un arma. La escena (`weapon_scene`) define CÓMO se mueve y golpea;
## este recurso define CUÁNTO: daño, críticos, tiempos de carga, etc.

enum Family { FISTS, SWORD, DAGGER, MACE, BOW, AXE, SPEAR, STAFF, BO }
## Qué pasa al MANTENER clic izquierdo.
enum HoldMode {
	CHARGE, ## Carga un ataque fuerte que sale al soltar (animación "charge" -> "heavy").
	REPEAT, ## Repite el combo más rápido mientras mantienes (tacatacata).
}

@export var family: Family = Family.SWORD
## Escena del arma (raíz con weapon.gd).
@export var weapon_scene: PackedScene

@export_group("A la espalda")
## Textura del arma guardada a la espalda (vacía = no se ve, p. ej. puños).
@export var back_texture: Texture2D
## Desplazamiento de la textura para que el agarre quede en el origen.
@export var back_texture_offset := Vector2.ZERO
## Posición en el lienzo del personaje (pies en 0,0; +X = hacia donde mira).
@export var back_position := Vector2.ZERO
@export var back_rotation_degrees := 0.0

@export_group("Daño")
@export var base_damage: float = 10.0
@export_range(0.0, 1.0) var crit_chance: float = 0.1
@export var crit_multiplier: float = 2.0
## Crítico extra para ataques aéreos y de caída (el salto premia).
@export_range(0.0, 1.0) var air_crit_bonus: float = 0.25
## Si el ataque aéreo te hace caer en picado (y hacer "slam" al aterrizar).
@export var air_attack_plunges: bool = true

@export_group("Combo (clic izquierdo)")
## Nº de animaciones light_1..light_N del combo.
@export var combo_length: int = 3
## Segundos tras un golpe en los que el combo sigue vivo.
@export var combo_window: float = 0.6
@export var hold_mode: HoldMode = HoldMode.CHARGE
## Segundos manteniendo para que cuente como "mantener".
@export var hold_threshold: float = 0.22
## Velocidad de las animaciones en modo REPEAT.
@export var repeat_speed_scale: float = 1.5
## Segundos para llegar a carga completa (modo CHARGE).
@export var max_charge_time: float = 0.9
## Multiplicador de daño con carga completa.
@export var max_charge_multiplier: float = 2.5

@export_group("Clic derecho")
@export var alt_cooldown: float = 0.8
## Si se puede MANTENER clic derecho: pulsar = "alt" (al soltar); mantener = "alt_charge" -> "alt_heavy".
@export var alt_hold_enabled: bool = false

@export_group("Proyectiles")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 420.0
