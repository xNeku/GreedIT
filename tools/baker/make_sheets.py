"""Junta los fotogramas procesados en hojas de sprites: una por animación, filas = 8 direcciones, columnas = fotogramas."""
from PIL import Image
import json, os, sys, shutil
src, dst = sys.argv[1], sys.argv[2]
meta = json.load(open(os.path.join(os.path.dirname(src.rstrip('/')), 'raw', 'meta.json')))
os.makedirs(dst, exist_ok=True)
cell = meta['cell']
for anim, n in meta['frames'].items():
    if not os.path.exists(f'{src}/{anim}_d0_f0.png'): continue
    sheet = Image.new('RGBA', (cell * n, cell * 8))
    for d in range(8):
        for f in range(n):
            sheet.alpha_composite(Image.open(f'{src}/{anim}_d{d}_f{f}.png'), (f * cell, d * cell))
    sheet.save(f'{dst}/{anim}.png')
shutil.copy(os.path.join(os.path.dirname(src.rstrip('/')), 'raw', 'meta.json'), f'{dst}/meta.json')
print('hojas en', dst, meta)
