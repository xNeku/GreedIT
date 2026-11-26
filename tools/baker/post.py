"""Retoque pixel art: paleta de los sprites originales + contorno de 1 px."""
from PIL import Image
import numpy as np, glob, os, sys
R=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','assets','sprites')
OUT=np.array([24,14,16])
def palette():
    cols=set()
    files=glob.glob(f'{R}/characters/male/**/*.png',recursive=True)+[f'{R}/weapons/sword.png']
    for f in files:
        a=np.array(Image.open(f).convert('RGBA')).reshape(-1,4)
        for c in a[a[:,3]>0][:,:3]: cols.add(tuple(int(v) for v in c))
    for c in [(150,96,58),(124,78,46),(96,58,36),(60,40,30),(214,180,90),(176,118,74),(110,68,40)]: cols.add(c)
    return np.array(sorted(cols),float)
PAL=palette()
def process(path,out):
    a=np.array(Image.open(path).convert('RGBA')).astype(float)
    m=a[...,3]>10
    px=a[m][:,:3]
    d=((px[:,None,:]-PAL[None])**2).sum(2); q=PAL[d.argmin(1)]
    o=np.zeros_like(a); o[m,:3]=q; o[m,3]=255
    pad=np.pad(m,1); edge=np.zeros_like(m)
    for dy,dx in ((-1,0),(1,0),(0,-1),(0,1)): edge|=pad[1+dy:m.shape[0]+1+dy,1+dx:m.shape[1]+1+dx]
    ring=edge&~m
    o[ring,:3]=OUT; o[ring,3]=255
    Image.fromarray(o.astype(np.uint8)).save(out)
if __name__=='__main__':
    src,dst=sys.argv[1],sys.argv[2]; os.makedirs(dst,exist_ok=True)
    for f in sorted(glob.glob(f'{src}/*.png')): process(f,f'{dst}/{os.path.basename(f)}')
