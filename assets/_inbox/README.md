# Buzón de assets

Aquí se dejan los zips de packs (modelos, animaciones, efectos...) para probarlos antes de decidir con cuáles
nos quedamos.

- Los zips **no van a `main`** (están en `.gitignore`): se suben a la rama `inbox` con el comando de abajo.
  Así `main` no carga con packs que a lo mejor no usamos.
- Claude los descomprime, mete en `assets/models/...` solo lo elegido (con su script de importación) y borra la
  rama `inbox`.

Subir los zips (desde la carpeta del proyecto):

```bash
git checkout -b inbox && git add -f assets/_inbox/*.zip && git commit -m "Zips de assets para probar" && git push -u origin inbox
```

Ojo: GitHub no acepta archivos de más de 100 MB.
