# Efectos visuales (VFX)

- `binbun/`: packs gratis de **BinbunVFX Vol. 2** (Binbun3D, https://bun3d.com), licencia **CC0** (sin atribución
  obligatoria; se agradece mencionarle). Hechos para Godot: cada efecto es una escena con su `AnimationPlayer`
  ("main") y un script `VFXControllerBB` (`play()`, `stop()`, colores y emisión en el inspector).
  - `ElementalMagicFX/effects/`: fuego al lanzar (`cast`), proyectil (`projectile`) y área en el suelo (`area`).
  - `ElectricFX/effects/`: bola de rayo (`ball`) e impacto de rayo (`zap`).
  - `StatusFX/effects/`: estado "congelado" (`status/vfx_status_shatter.tscn`, se pone como hijo del personaje) y su
    material para el cuerpo (`overlay/shatter_overlay.tres`, va en `material_overlay` de sus mallas).
  - `shared/`: scripts comunes y escenas de demo.
  Están **de prueba**: el dueño decide cuáles se usan. Su luz (OmniLight) sale el doble de fuerte que la nuestra
  (ver `DayNightCycle.light_scale`): al usarlos, bajarla a la mitad.
