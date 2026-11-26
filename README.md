# GreedIT

ARPG cooperativo con cámara en diagonal: **Terraria + Path of Exile**.
Farmear, forjar, hacerte una build bestia y tumbar bosses con tus colegas.

> Estado: **base 3D 0.7**. El juego pasa a **3D en tiempo real con aspecto pixel art** (se pinta a baja resolución,
> luz por bandas y contorno de 1 px): personajes con esqueleto y animaciones,
> equipo por ranuras (armas en las manos, casco, capa, escudo y armaduras que se deforman con el cuerpo),
> 7 armas, muñecos y una mazmorra con luces y sombras. Coop de 2 a 4 desde el principio.
> Los modelos son de muestra (KayKit, CC0) hasta que estén los nuestros de Blender.
> El sandbox 2D pixel art anterior sigue disponible desde el menú.

## Cómo abrirlo

1. Instala **Godot 4.7** (versión estándar, no hace falta la de .NET).
2. Abre Godot → *Importar* → selecciona `project.godot` de esta carpeta.
3. Pulsa **F5**. Sale el menú: elige **Mundo** (3D nuevo o 2D pixel art) y personaje, y luego
   **Jugar solo**, **Crear partida** o **Unirse**.

## Controles (mundo 3D)

| Acción | Tecla |
|---|---|
| Moverse | WASD / flechas (relativo a la cámara) |
| Atacar (combo) | Clic izquierdo (apunta al ratón) |
| Ataque cargado / ráfaga | Mantener clic izquierdo |
| Ataque especial | Clic derecho |
| Especial cargado (mandoble: salto aplastante) | Mantener clic derecho |
| Ataque aéreo (caída en picado) | Atacar mientras saltas |
| Bola de fuego (gasta maná) | Clic de la rueda |
| Saltar (hacia donde corres) | Espacio |
| Esquivar (invulnerable) | Shift |
| Cámara isométrica / diagonal | Tab |
| Zoom | + / - |
| Cambiar arma | 1-7 / girar la rueda |
| Cambiar personaje | C |
| Quitar/poner casco · capa · escudo | H · G · V |
| Poner/quitar armadura (con esqueleto) | B |
| Pantalla completa | F11 |
| Salir al menú | Esc |

## Prototipos de personaje 3D

En el menú, **Prototipos de personaje 3D** abre dos pruebas con el personaje convertido a 3D (calvo):

- **A: 3D → sprites**: el personaje 3D renderizado a hojas de sprites en 8 direcciones, dentro del mundo 2D actual.
- **B: 3D real**: el mismo personaje en un mundo 3D con cámara ortográfica, luces y sombras 3D y giro libre.

En ambos: WASD para moverse, clic izquierdo para atacar y Esc para volver al menú.

## Jugar con amigos (coop)

1. Uno pulsa **Crear partida** (puerto 7777 por defecto).
2. Los demás escriben la IP del host y pulsan **Unirse**.
   - Misma red (misma casa/wifi): la IP local del host (`ipconfig` en Windows, `ip a` en Linux).
   - Por internet: el host abre el puerto **UDP 7777** en su router, o usáis una VPN tipo ZeroTier / Hamachi y ponéis esa IP.
3. Hasta 4 jugadores. Cada uno elige chico/chica en el menú.

## Controles (sandbox 2D)

| Acción | Tecla |
|---|---|
| Moverse | WASD / flechas |
| Apuntar | Ratón |
| Atacar (combo) | Clic izquierdo (pulsar) |
| Ataque cargado / ráfaga | Clic izquierdo (mantener) |
| Ataque especial | Clic derecho |
| Especial cargado (maza: salto aplastante) | Clic derecho (mantener) |
| Saltar (hacia donde corres) | Espacio |
| Ataque aéreo (caída en picado) | Atacar mientras saltas |
| Dash | Shift |
| Bola de fuego (gasta maná) | Clic de la rueda |
| Minar / recolectar / pescar | E (cerca del recurso) |
| Pescar: tirar cuando pica | E cuando sale "¡Tira!" |
| Cambiar arma | 1-6 / girar la rueda |
| Cambiar personaje | C |
| Pantalla completa | F11 |
| Salir al menú | Esc |

## Documentación

- [`docs/GDD.md`](docs/GDD.md): diseño del juego (qué queremos hacer).
- [`docs/BACKLOG.md`](docs/BACKLOG.md): lista de tareas y siguientes pasos.
- [`AGENTS.md`](AGENTS.md): reglas técnicas del proyecto (para humanos y para IAs: Claude, Codex...).

## Test rápido

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

Prueba todas las armas, el salto y las profesiones, y termina con `SMOKE OK` si todo va bien.

Test de red (abre dos copias del juego, host y cliente, y comprueba que el coop funciona):

```bash
godot --headless --path . res://tests/net_test.tscn -- --role=host --port=7790 &
godot --headless --path . res://tests/net_test.tscn -- --role=client --port=7790
```

Lo mismo para el mundo 3D (`SMOKE 3D OK`, y `NET CLIENT OK` / `NET HOST OK`):

```bash
godot --headless --path . res://tests/smoke_test_3d.tscn
godot --headless --path . res://tests/net_test_3d.tscn -- --role=host --port=7795 &
godot --headless --path . res://tests/net_test_3d.tscn -- --role=client --port=7795
```

## Créditos

- Personajes modulares y animaciones: [Quaternius](https://quaternius.com) (CC0).
- Personajes, armas y mazmorra de muestra: [KayKit](https://kaylousberg.com) por Kay Lousberg (CC0).
  Ver `assets/models/*/LICENSE.txt`.
