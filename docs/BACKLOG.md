# Backlog

Leyenda: `[ ]` pendiente · `[~]` en curso (pon tu nombre) · `[x]` hecho

## Hito 0: Sandbox de combate (hecho)

- [x] Proyecto Godot 4.7 pixel-perfect (960x540, nearest, snap a píxel)
- [x] Personaje por capas a partir del arte original (chico y chica), manos separadas
- [x] Movimiento con inercia, dash, salto hacia el cursor (estilo Conquer) con sombra
- [x] Sistema de armas: combo al pulsar, carga o ráfaga al mantener, clic derecho, ataque aéreo + caída en picado
- [x] Puños, espada, daga (lanzable), maza, arco (disparo cargado que perfora, triple, lluvia aérea)
- [x] Hitbox / Hurtbox / HitData + bus `Events` (base para talentos y afijos)
- [x] Muñeco de entrenamiento: tambaleo de muelle, flash, paja, números de daño, DPS
- [x] Hitstop, vibración de cámara, cámara que se adelanta al ratón
- [x] Sandbox con luces, sombras (columnas), braseros con fuego y hotbar 1-5
- [x] Test de humo headless (`tests/smoke_test.tscn`)

## Hito 1: Sensación de combate (siguiente)

- [ ] Ajustar a mano tiempos y poses de cada arma en el editor (prioridad: que se sienta bien)
- [ ] Sonidos placeholder (golpe, swing, salto, aterrizaje)
- [ ] Trails de arma (Line2D) y partículas de impacto por tipo de arma
- [ ] Buffer de input más fino y ventana de cancelación configurable por animación
- [ ] Saltar por encima de obstáculos bajos (capa "low_obstacles" que se ignora en el aire)
- [ ] Hurtbox del jugador + vida + muerte (saco de materiales con temporizador)
- [ ] Mando: apuntado con stick (ya existe `Player.aim_target_override`)

## Hito 2: Primer enemigo de verdad

- [ ] Enemigo básico con IA (perseguir, atacar, retroceder) y vida
- [ ] Knockback real en enemigos (CharacterBody2D)
- [ ] Drop de loot simple
- [ ] XP y subida de nivel

## Hito 3: Mundo

- [ ] Generación por semilla con `FastNoiseLite` + `TileMapLayer` por chunks
- [ ] Bioma bosque + cueva
- [ ] Punto de spawn (cofre infinito, hamaca) y área de estaciones
- [ ] Minería (picar bloques/vetas)

## Hito 4: Coop

- [ ] Arquitectura host-cliente (MultiplayerSpawner / MultiplayerSynchronizer)
- [ ] Sincronizar jugador, armas, golpes
- [ ] Chunks cargados por jugador

## Sistemas de build (diseño pendiente)

- [ ] Maestría por familia de arma (puntos al usarla)
- [ ] Árbol de talentos (Vida / Destreza / Daño / Magia) + talentos clave
- [ ] Peso de armas vs fuerza (penalización suave)
- [ ] Dual wield
- [ ] Agarre a dos manos para armas pesadas (ahora todas van a una mano; la mano libre flota)
- [ ] Forja: materiales → afijos
- [ ] Brebajes: ingredientes con propiedades por bioma

## Arte

- [ ] Paleta de piel/pelo intercambiable por shader (en vez de `self_modulate`)
- [ ] Vistas de espalda y perfil del personaje (ahora solo hay frontal)
- [ ] Sprites de armas definitivos y más armas (hacha, lanza, bastón)
- [ ] Fuente pixel para la UI y los números de daño
- [ ] Tileset de suelo y paredes de mazmorra
