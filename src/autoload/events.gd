extends Node
## Bus de eventos global.
## Los sistemas que reaccionan a lo que pasa en combate (talentos, afijos de forja,
## brebajes, logros...) se conectan aquí en vez de tocar el código del arma.

## Un golpe ha impactado. `target` es el nodo dueño del Hurtbox.
signal hit_landed(hit: HitData, target: Node)
## Petición de vibración de cámara.
signal camera_shake_requested(strength: float, duration: float)
## Petición de "hitstop" (congelar el juego unos milisegundos para dar peso al golpe).
signal hitstop_requested(duration: float)

## El jugador que controla este ordenador ya está en el mundo (para enganchar HUD, cámara...).
signal local_player_ready(player: Player)
