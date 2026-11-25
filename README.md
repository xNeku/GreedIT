# GreedIT

ARPG cooperativo top-down en pixel art: **Terraria + Path of Exile**.
Farmear, forjar, hacerte una build bestia y tumbar bosses con tus colegas.

> Estado: **sandbox de combate 0.1**. Tienes un personaje, 5 armas y muñecos de entrenamiento para probar el movimiento y el combate.

## Cómo abrirlo

1. Instala **Godot 4.7** (versión estándar, no hace falta la de .NET).
2. Abre Godot → *Importar* → selecciona `project.godot` de esta carpeta.
3. Pulsa **F5**. Arranca `src/world/sandbox.tscn`.

## Controles

| Acción | Tecla |
|---|---|
| Moverse | WASD / flechas |
| Apuntar | Ratón |
| Atacar (combo) | Clic izquierdo (pulsar) |
| Ataque cargado / ráfaga | Clic izquierdo (mantener) |
| Ataque especial | Clic derecho |
| Salto hacia el cursor | Espacio |
| Ataque aéreo (caída en picado) | Atacar mientras saltas |
| Dash | Shift |
| Cambiar arma | 1-5 / rueda del ratón |
| Cambiar personaje | C |
| Pantalla completa | F11 |

## Documentación

- [`docs/GDD.md`](docs/GDD.md): diseño del juego (qué queremos hacer).
- [`docs/BACKLOG.md`](docs/BACKLOG.md): lista de tareas y siguientes pasos.
- [`AGENTS.md`](AGENTS.md): reglas técnicas del proyecto (para humanos y para IAs: Claude, Codex...).

## Test rápido

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

Prueba todas las armas contra un muñeco y termina con `SMOKE OK` si todo hace daño.
