# Personaje 3D → sprites pixel art (prototipo)

El personaje 3D vive en `prototypes/model3d/character_3d.tscn` (piezas de vóxeles + esqueleto simple + `pose()`).
Lo usan los dos prototipos del menú: **A** (horneado a hojas de sprites) y **B** (3D real).

1. `voxelize.py`: convierte las capas 2D del personaje (frente, perfil y espalda) en piezas 3D de vóxeles
   (casco visual con sección elíptica; cabeza calva por defecto) y las guarda como `.gltf` en `model/<personaje>/`.
   También crea la espada (sprite extruido) y un peto de cuero (cáscara alrededor del torso).
2. `baker.tscn`: renderiza `character_3d.tscn` en 8 direcciones (idle, run, attack) a baja resolución.
3. `post.py`: ajusta los colores a la paleta de los sprites originales y añade el contorno de 1 px.
4. `make_sheets.py`: junta los fotogramas en hojas (filas = direcciones, columnas = fotogramas) para el prototipo A.

```bash
python3 tools/baker/voxelize.py
godot --headless --path . --import
godot --path . res://tools/baker/baker.tscn -- --out=/tmp/bake/raw
python3 tools/baker/post.py /tmp/bake/raw /tmp/bake/px
python3 tools/baker/make_sheets.py /tmp/bake/px prototypes/proto_a/sheets
```

Las armaduras se cuelgan del mismo pivote que la pieza del cuerpo que cubren, así que encajan solas
en cualquier animación y dirección.
