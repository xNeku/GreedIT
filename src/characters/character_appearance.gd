class_name CharacterAppearance
extends Resource
## Aspecto de un personaje, por capas. Cada textura ocupa el MISMO lienzo
## (52x70 px, pies abajo en el centro) salvo las manos, que van recortadas.
## Para crear un pelo / ropa / piel nueva: pinta sobre ese lienzo y asígnala aquí.

@export_group("Cuerpo")
@export var head: Texture2D
@export var eyes: Texture2D
@export var torso: Texture2D
@export var leg_l: Texture2D
@export var leg_r: Texture2D
@export var hand_l: Texture2D
@export var hand_r: Texture2D
@export var skin_tint := Color.WHITE

@export_group("Pelo")
@export var hair: Texture2D
@export var hair_tint := Color.WHITE

@export_group("Ropa")
@export var cloth_top: Texture2D
@export var cloth_bottom: Texture2D
@export var boot_l: Texture2D
@export var boot_r: Texture2D
