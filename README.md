# GreedIT

ARPG cooperativo isométrico: **Terraria + Path of Exile**.
Farmear, forjar, hacerte una build bestia y tumbar bosses con tus colegas.

> Estado: **base 0.8**. 3D en tiempo real con cámara isométrica y aspecto pixel art. Un personaje (cuerpo base),
> 7 armas con combos, cargas y especiales, bola de fuego, muñecos de entrenamiento y coop de 2 a 4.
> El escenario de inicio está pendiente de elegir assets.

## Cómo abrirlo

1. Instala **Godot 4.7** (versión estándar, no hace falta la de .NET).
2. Abre Godot → *Importar* → selecciona `project.godot` de esta carpeta.
3. Pulsa **F5**. Sale el menú: **Jugar solo**, **Crear partida** o **Unirse**.

## Controles

| Acción | Tecla |
|---|---|
| Moverse | WASD / flechas (relativo a la cámara) |
| Atacar (combo) | Clic izquierdo (apunta al ratón) |
| Ataque cargado / ráfaga | Mantener clic izquierdo |
| Ataque especial | Clic derecho |
| Especial cargado (mandoble y bō: salto aplastante) | Mantener clic derecho |
| Ataque en el aire | Atacar mientras saltas |
| Lanzar la magia elegida (gasta maná) | Clic de la rueda |
| Cambiar de magia (bola de fuego, llamarada, bola de rayo, rayo) | Girar la rueda |
| Saltar (hacia donde corres) | Espacio |
| Esquivar (invulnerable) | Shift |
| Elegir hueco de la barra | 1-8 (hueco vacío = puños) |
| Zoom | + / - |
| Pantalla completa | F11 |
| Salir al menú | Esc |

## Jugar con amigos (coop)

1. Uno pulsa **Crear partida** (puerto 7777 por defecto).
2. Los demás escriben la IP del host y pulsan **Unirse**.
   - Misma red (misma casa/wifi): la IP local del host (`ipconfig` en Windows, `ip a` en Linux).
   - Por internet: el host abre el puerto **UDP 7777** en su router, o usáis una VPN tipo ZeroTier / Hamachi y ponéis esa IP.
3. Hasta 4 jugadores.

## Documentación

- [`docs/GDD.md`](docs/GDD.md): diseño del juego (qué queremos hacer).
- [`docs/BACKLOG.md`](docs/BACKLOG.md): lista de tareas y siguientes pasos.
- [`AGENTS.md`](AGENTS.md): reglas técnicas del proyecto (para humanos y para IAs: Claude, Codex...).

## Test rápido

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

Prueba el movimiento, todas las armas y el HUD, y termina con `SMOKE OK`.
Test de red (dos copias del juego, host y cliente):

```bash
godot --headless --path . res://tests/net_test.tscn -- --role=host --port=7795 &
godot --headless --path . res://tests/net_test.tscn -- --role=client --port=7795
```

## Créditos

- Personajes modulares y animaciones: [Quaternius](https://quaternius.com) (CC0).
- Entorno (árboles, rocas, montañas...): ["LowPoly Environment Pack"](https://k0rveen.itch.io/lowpoly-environment-pack) por k0rveen ([CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)).
- Armas y animaciones de armas: [KayKit](https://kaylousberg.com) por Kay Lousberg (CC0).
  Ver `assets/models/*/LICENSE.txt`.
