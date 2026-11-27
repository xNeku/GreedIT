class_name WorldSettings
extends Resource
## Reglas de un mundo generado (las mismas que el World Lab). Cada mundo (normal, infierno, cielo) es un .tres.

@export var display_name := "Mundo normal"
@export_group("Tamaño y forma")
## Lado del mundo en km (9 km = unos 20 minutos andando de punta a punta a 7,5 m/s).
@export_range(2.0, 16.0, 0.5) var size_km := 9.0
## Celdas por lado del mapa grande (cada celda mide size_km * 1000 / cells metros).
@export var cells := 256
@export var start_in_center := true
## Bordes de los biomas: 0 = rectos, 1 = muy deformados.
@export_range(0.0, 1.0, 0.05) var border_warp := 0.6
## Nieve al norte, desierto y jungla al sur.
@export var logical_climate := true
@export_group("Biomas")
@export var biomes: Array[BiomeData] = []
## Bioma en el que empiezas.
@export var start_biome := &"bosque"
@export_group("Barreras")
## Cordilleras (o ríos de lava, o abismos) que obligan a rodear.
@export_range(0, 20) var ranges := 7
## Largo de cada una (fracción del mapa).
@export_range(0.1, 0.9, 0.05) var range_length := 0.45
## Grosor (en celdas del mapa grande).
@export_range(1.0, 8.0, 0.5) var range_thickness := 3.5
## Pasos para cruzar cada una.
@export_range(1, 4) var passes_per_range := 2
@export_group("Sitios")
@export var dungeons := 24
@export var mines := 14
@export var caves := 14
@export var camps := 4
@export var bosses := 4
@export var events := 50
@export_group("Terreno")
## Altura de las montañas (m). Ojo: con la cámara isométrica, más altas tapan más.
@export var mountain_height := 10.0
## Relieve del suelo llano (m): bajo = casi plano.
@export var relief := 0.6
## Radio (m) alrededor del inicio que se deja llano y limpio.
@export var base_radius := 22.0
@export var rock_color := Color(0.5, 0.45, 0.38)
@export var rock_color_2 := Color(0.6, 0.54, 0.45)
## Lo que sale en las laderas de las montañas.
@export var mountain_decorations: Array[DecorationData] = []
