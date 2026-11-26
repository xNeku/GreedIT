# GreedIT

ARPG cooperativo top-down en pixel art: **Terraria + Path of Exile**.
Farmear, forjar, hacerte una build bestia y tumbar bosses con tus colegas.

> Estado: **sandbox 0.6**. Coop de 2 a 4 jugadores, personaje en 8 direcciones, 6 armas, bola de fuego, primeros mobs (goblin, esqueleto y zombi, al norte del mapa), muñecos de entrenamiento y recolección (minería, herboristería y pesca).

## Cómo abrirlo

1. Instala **Godot 4.7** (versión estándar, no hace falta la de .NET).
2. Abre Godot → *Importar* → selecciona `project.godot` de esta carpeta.
3. Pulsa **F5**. Sale el menú: **Jugar solo**, **Crear partida** o **Unirse**.

## Jugar con amigos (coop)

1. Uno pulsa **Crear partida** (puerto 7777 por defecto).
2. Los demás escriben la IP del host y pulsan **Unirse**.
   - Misma red (misma casa/wifi): la IP local del host (`ipconfig` en Windows, `ip a` en Linux).
   - Por internet: el host abre el puerto **UDP 7777** en su router, o usáis una VPN tipo ZeroTier / Hamachi y ponéis esa IP.
3. Hasta 4 jugadores. Cada uno elige chico/chica en el menú.

## Controles

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
