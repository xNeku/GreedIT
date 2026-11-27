class_name BiomeData
extends Resource
## Un bioma del generador de mundo: cuánto ocupa, dónde suele salir, su suelo y qué decoración lleva.
## Se edita en el inspector (los colores y la decoración de ahora son de prueba hasta que el dueño elija assets).

enum Climate { ANY, NORTH, MID, SOUTH }

@export var id := &""
@export var display_name := ""
## Cuánto ocupa del mapa (relativo a los demás biomas).
@export_range(0.0, 5.0, 0.1) var weight := 1.0
## Dónde sale si el mundo tiene clima lógico (nieve al norte, desierto al sur...).
@export var climate: Climate = Climate.ANY
## Rocoso: salen picos sueltos que no se pueden cruzar.
@export var rocky := false
@export_group("Suelo")
## Color del suelo y el de sus manchas (se mezclan con ruido). También es el color en el mapa.
@export var ground_color := Color(0.44, 0.57, 0.28)
@export var ground_color_2 := Color(0.38, 0.52, 0.25)
@export_group("Decoración")
@export var decorations: Array[DecorationData] = []
