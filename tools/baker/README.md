# Prototipo: personaje 3D → sprites pixel art

Prueba de concepto (no está conectada al juego todavía).

1. `voxelize.py`: convierte las capas 2D del personaje (frente, perfil y espalda) en piezas 3D de vóxeles
   (casco visual con sección elíptica) y las guarda como `.gltf` en `model/<personaje>/`. También crea la espada
   (sprite extruido) y un peto de cuero (cáscara alrededor del torso).
2. `baker.tscn`: monta las piezas en un esqueleto simple (cadera → torso → cabeza, piernas, manos flotantes),
   las anima (`idle`, `run`, `attack`) y renderiza cada fotograma en 8 direcciones a baja resolución.
3. `post.py`: ajusta los colores a la paleta de los sprites originales y añade el contorno de 1 px.

```bash
python3 tools/baker/voxelize.py
godot --headless --path . --import
godot --path . res://tools/baker/baker.tscn -- --out=/tmp/bake/raw --anims=idle,run,attack
python3 tools/baker/post.py /tmp/bake/raw /tmp/bake/px
```

Las armaduras se cuelgan del mismo pivote que la pieza del cuerpo que cubren, así que encajan solas
en cualquier animación y dirección.
