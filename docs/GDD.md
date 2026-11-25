# GreedIT: Documento de diseño (GDD)

> Documento vivo. Lo que está aquí es la intención de diseño, no lo implementado.
> Para lo implementado y lo pendiente, mira `BACKLOG.md`.

## 1. Concepto

**Terraria + Path of Exile**, vista desde arriba, en pixel art (estética entre Terraria y Stoneshard).
Sin historia aparente: farmear, forjarte una build bestia y superar a los bosses que tocan.
Coop de **2 a 4 jugadores**: tus colegas se unen a tu mundo.

Pilares:
1. **Combate hack & slash con armas, no con hechizos.** Clic izquierdo, clic derecho, pulsar o mantener, y salto.
2. **Build = arma + maestría + talentos + forja + brebajes.**
3. **Progresión larga por bosses**: cada boss desbloquea materiales, equipo y eventos.
4. **Profesiones que se fusionan**: minería, pesca, alquimia y cocina alimentan la forja y los brebajes.

## 2. Mundo

- Mapa **continuo** tipo Terraria pero top-down, generado por **semilla**, cargado por chunks.
- No hay base libre: hay **puntos de spawn** (cofre infinito + hamaca entre dos árboles). Las estaciones
  (mesa de trabajo, yunque...) solo se colocan en el área pequeña de esos puntos.
- Tres capas, cada una un mapa continuo propio:
  1. **Overworld**: biomas de nieve, desierto, bosque y montaña, con cuevas y dungeons. Los bosses van
     cambiando qué minerales aparecen y qué eventos ocurren. Tras el último boss se abre un **pozo-portal** al infierno.
  2. **Infierno**: vacío, lleno de bestias, dungeons y bosses. Pura guerra, pocas zonas tranquilas, recursos propios.
  3. **Cielo**: tras el infierno, un evento trae una legión de ángeles; al matarlos aparece un **haz de luz** que te sube.
     Zona limpia y bonita, catedrales como dungeons, ángeles y clérigos como enemigos.

## 3. Combate

### Controles
- Clic izquierdo: **pulsar** = combo; **mantener** = depende del arma (cargar ataque fuerte o ráfaga continua).
- Clic derecho: ataque especial del arma.
- **Salto** (marca de la casa, inspirado en Conquer Online): saltas hacia el cursor en un arco. En el aire pasas por
  encima de enemigos. Atacar en el aire = ataque aéreo + caída en picado con impacto al aterrizar.
- **Dash**: lo darán objetos (de momento viene de serie para probar).
- No hay más habilidades activas. Todo sale de las armas y lo que las modifica.

### Armas
- Puedes llevar todas las armas (hotbar estilo Terraria) y cambiar al vuelo.
- Cada **familia** tiene su propio moveset: puños, espada, daga, maza, arco (implementadas); hacha, lanza, bastón (futuras).
- **Maestría**: usar una familia da puntos de maestría de esa familia. Desbloquea golpes nuevos en el combo y es
  requisito para cosas como el dual wield.
- **Peso y fuerza**: un arma pesada sin fuerza suficiente se puede usar, pero más lenta y con menos daño (penalización suave).

### Talentos (rollo WoW)
Cuatro ramas mezclables: **Vida**, **Destreza**, **Daño (Fuerza)** y **Magia**. Cada jugador forja su "clase" mezclando.
Talentos clave que rompen reglas, por ejemplo:
- *Ambidiestro* (Destreza): dual wield. Requiere además maestría de la familia y fuerza.
- *Titán* (Daño + Vida): armas a dos manos en una mano.
- *Puños arcanos* (Magia + Destreza): los puños escalan con magia y sueltan descargas.
- *Berserker*, *Danza de armas* (cambiar de arma a mitad de combo da crítico)...

Técnicamente, talentos, afijos y brebajes son **modificadores que escuchan eventos** (`hit_landed`, aterrizar, cambiar de arma...).

## 4. Progresión

- XP por matar → subes de nivel → puntos de talento.
- **Escalado por progreso del mundo** (bosses derrotados, capa actual), **no** por el nivel del jugador.
  Volver a una zona vieja y arrasar es parte de la gracia.
- Largo, pero el bucle de 30 segundos (pegar, lootear, picar) tiene que molar por sí solo.

## 5. Profesiones, forja y brebajes

- Minería, pesca, alquimia y cocina.
- **Forja**: los materiales que usas deciden los **modificadores (afijos)** del arma o armadura.
  El crafteo ES el sistema de afijos.
- **Brebajes**: cada ingrediente tiene propiedades según su bioma (ardiente, vital, volátil, helado...).
  Combinarlas da efectos. Cocina = buffs largos, alquimia = buffs cortos y fuertes.

## 6. Muerte

- Al morir sueltas los **materiales de profesión** en un saco donde caíste. Tienes X minutos para recuperarlo.
- Equipo, XP y maestría no se pierden nunca.
- En coop, un compañero puede recoger tu saco y devolvértelo.

## 7. Personaje y estética

- Personaje por capas (piel, ojos, pelo, ropa, botas, manos flotantes) para personalización y armaduras visibles.
- Manos separadas del cuerpo (estilo "rayman"): las mueve el arma, lo que facilita animar.
- Iluminación 2D con sombras: mazmorras oscuras, antorchas y braseros.

## 8. Técnica

- Godot 4.7, GDScript tipado, renderer Compatibility.
- Multijugador host-cliente con autoridad del host, **pensado desde el principio** (aunque se implemente después).
- Todo en escenas y recursos editables. Ver `AGENTS.md`.
