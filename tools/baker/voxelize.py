"""Casco visual por piezas: frente (x,y) ∩ perfil (z,y) -> vóxeles coloreados con frente/espalda/perfil."""
from PIL import Image
import numpy as np, os, json, base64, struct
R=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','assets','sprites','characters')
OUTDIR=os.path.join(os.path.dirname(os.path.abspath(__file__)),'model')
W,H=52,70
def load(p):
    p=f'{R}/{p}.png'
    return np.array(Image.open(p).convert('RGBA')) if os.path.exists(p) else np.zeros((H,W,4),np.uint8)
def over(*ls):
    o=np.zeros((H,W,4),np.uint8)
    for l in ls:
        m=l[...,3]>0; o[m]=l[m]
    return o
def strip_outline(img, keep_dark=None):
    """Quita el contorno oscuro (borde) y lo sustituye por el color interior vecino: el contorno lo pone el render."""
    o=img.copy(); a=img[...,3]>0
    dark=(img[...,:3].astype(int).sum(2)<95)&a
    if keep_dark is not None: dark&=~keep_dark
    for it in range(3):
        ys,xs=np.where(dark)
        changed=False
        for y,x in zip(ys,xs):
            best=None
            for dy,dx in ((0,1),(0,-1),(1,0),(-1,0),(1,1),(-1,-1),(1,-1),(-1,1)):
                yy,xx=y+dy,x+dx
                if 0<=yy<H and 0<=xx<W and a[yy,xx] and not dark[yy,xx]:
                    best=o[yy,xx]; break
            if best is not None:
                o[y,x]=best; dark[y,x]=False; changed=True
        if not changed: break
    return o
FALLBACK=[]
def nearest_color(img,y,x,depth=0):
    if img[y,x,3]>0: return img[y,x,:3]
    a=img[...,3]>0
    for r in range(1,4):
        for dy in range(-r,r+1):
            for dx in range(-r,r+1):
                yy,xx=y+dy,x+dx
                if 0<=yy<H and 0<=xx<W and a[yy,xx]: return img[yy,xx,:3]
    # sin color en esta vista: probar con las otras vistas de la pieza (misma fila)
    for other in FALLBACK:
        if other is img: continue
        xs=np.where(other[y,:,3]>0)[0]
        if len(xs): return other[y,xs[len(xs)//2],:3]
    return np.array([120,80,60])

def segments(mask_row):
    xs=np.where(mask_row)[0]
    if len(xs)==0: return []
    segs=[]; start=xs[0]; prev=xs[0]
    for x in xs[1:]:
        if x!=prev+1: segs.append((start,prev)); start=x
        prev=x
    segs.append((start,prev)); return segs

def carve(front, side, back, depth_hint=None, round_xs=True):
    """Casco visual con sección elíptica: por cada fila, cada tramo de la silueta frontal (frente ∪ espalda espejada)
    se combina con el tramo del perfil formando un óvalo (cuerpos redondeados en vez de cajas)."""
    fm=front[...,3]>0
    if back is not None: fm=fm|(back[:, ::-1, 3]>0)
    sm=side[...,3]>0
    vox=np.zeros((H,W,W),bool)   # [fila, x, z]
    for r in range(H):
        xsegs=segments(fm[r]); zsegs=segments(sm[r])
        if not xsegs: continue
        if not zsegs:
            if depth_hint is None: continue
            zsegs=[(26-depth_hint//2,26+depth_hint//2-1)]
        for (x0,x1) in xsegs:
            cx=(x0+x1+1)/2; rx=(x1-x0+1)/2
            for (z0,z1) in zsegs:
                cz=(z0+z1+1)/2; rz=(z1-z0+1)/2
                for x in range(x0,x1+1):
                    for z in range(z0,z1+1):
                        if not round_xs or ((x+0.5-cx)/rx)**2+((z+0.5-cz)/rz)**2<=1.05:
                            vox[r,x,z]=True
    return vox

def mesh_from_vox(vox, front, side, back, top_from='front'):
    """Caras expuestas, coloreadas según hacia dónde miran."""
    pos=[]; col=[]; idx=[]
    Hh,Ww,Dd=vox.shape
    def add_quad(corners,c):
        b=len(pos)
        for p in corners: pos.append(p); col.append(c)
        idx.extend([b,b+1,b+2,b,b+2,b+3])
    rr,xx,zz=np.where(vox)
    for r,x,z in zip(rr,xx,zz):
        X=x-26; Y=69-r; Z=z-26    # vóxel ocupa [X,X+1]x[Y,Y+1]x[Z,Z+1]
        def empty(r2,x2,z2):
            return not(0<=r2<Hh and 0<=x2<Ww and 0<=z2<Dd) or not vox[r2,x2,z2]
        # +Z (frente)
        if empty(r,x,z+1): add_quad([(X,Y,Z+1),(X+1,Y,Z+1),(X+1,Y+1,Z+1),(X,Y+1,Z+1)], nearest_color(front,r,x))
        # -Z (espalda): la vista de espaldas va espejada
        if empty(r,x,z-1): add_quad([(X+1,Y,Z),(X,Y,Z),(X,Y+1,Z),(X+1,Y+1,Z)], nearest_color(back,r,W-1-x))
        # +X (lado derecho del modelo): perfil
        if empty(r,x+1,z): add_quad([(X+1,Y,Z+1),(X+1,Y,Z),(X+1,Y+1,Z),(X+1,Y+1,Z+1)], nearest_color(side,r,z))
        # -X
        if empty(r,x-1,z): add_quad([(X,Y,Z),(X,Y,Z+1),(X,Y+1,Z+1),(X,Y+1,Z)], nearest_color(side,r,z))
        # +Y (arriba)
        if empty(r-1,x,z): add_quad([(X,Y+1,Z+1),(X+1,Y+1,Z+1),(X+1,Y+1,Z),(X,Y+1,Z)], nearest_color(front,r,x))
        # -Y (abajo)
        if empty(r+1,x,z): add_quad([(X,Y,Z),(X+1,Y,Z),(X+1,Y,Z+1),(X,Y,Z+1)], (nearest_color(front,r,x)*0.6).astype(int))
    return pos,col,idx

def write_gltf(path,pos,col,idx,origin=(0,0,0)):
    pos=np.array(pos,np.float32)-np.array(origin,np.float32)
    col=np.array(col,np.float32)/255.0
    # sRGB -> lineal (glTF guarda colores de vértice en lineal)
    col=col.astype(np.float32)  # se guardan en sRGB; el material usa vertex_color_is_srgb
    col4=np.concatenate([col,np.ones((len(col),1),np.float32)],1)
    # normales planas por cara (cada quad tiene 4 vértices propios)
    nrm=np.zeros_like(pos)
    for q in range(0,len(pos),4):
        a,b,c=pos[q],pos[q+1],pos[q+2]; n=np.cross(b-a,c-a); n/=np.linalg.norm(n)+1e-9; nrm[q:q+4]=n
    idx=np.array(idx,np.uint32)
    bufs=[pos.tobytes(),nrm.tobytes(),col4.tobytes(),idx.tobytes()]
    data=b''.join(bufs); offs=np.cumsum([0]+[len(b) for b in bufs])
    g={"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"mesh":0,"name":os.path.basename(path)[:-5]}],
       "meshes":[{"primitives":[{"attributes":{"POSITION":0,"NORMAL":1,"COLOR_0":2},"indices":3}]}],
       "buffers":[{"byteLength":len(data),"uri":"data:application/octet-stream;base64,"+base64.b64encode(data).decode()}],
       "bufferViews":[{"buffer":0,"byteOffset":int(offs[i]),"byteLength":len(bufs[i])} for i in range(4)],
       "accessors":[
         {"bufferView":0,"componentType":5126,"count":len(pos),"type":"VEC3","min":pos.min(0).tolist(),"max":pos.max(0).tolist()},
         {"bufferView":1,"componentType":5126,"count":len(pos),"type":"VEC3"},
         {"bufferView":2,"componentType":5126,"count":len(pos),"type":"VEC4"},
         {"bufferView":3,"componentType":5125,"count":len(idx),"type":"SCALAR"}]}
    with open(path,'w') as f: json.dump(g,f)

SKIN=[(215,148,110),(211,139,102),(183,112,81)]
def skull(cx=26.0,cy=15.0,rx=10.5,ry=10.0):
    """Cráneo calvo: óvalo de piel con luz arriba a la izquierda."""
    o=np.zeros((H,W,4),np.uint8)
    for y in range(H):
        for x in range(W):
            dx=(x+0.5-cx)/rx; dy=(y+0.5-cy)/ry
            if dx*dx+dy*dy<=1:
                t=0 if (dx+dy)<-0.6 else (2 if (dx+dy)>0.7 else 1)
                o[y,x]=(*SKIN[t],255)
    return o

def build(g, bald=True):
    os.makedirs(f'{OUTDIR}/{g}',exist_ok=True)
    F=lambda n: load(f'{g}/{n}'); S=lambda n: load(f'{g}/side/{n}'); B=lambda n,alt=None: load(f'{g}/{alt or n}')
    eyes_f=F('eyes'); eyes_s=S('eyes')
    if bald:
        head_parts=(over(skull(),F('head'),eyes_f), over(S('head'),eyes_s), over(skull(),B('head','head_back')), (0,44,0))
    else:
        head_parts=(over(F('head'),eyes_f), over(S('head'),eyes_s), B('head','head_back'), (0,44,0))
    parts={
      # nombre: (frente, perfil, espalda, pivote)
      'head':  head_parts,
      'hair':  (F('hair'), S('hair'), B('hair','hair_back'), (0,44,0)),
      'torso': (over(F('torso'),F('cloth_top')), over(S('torso'),S('cloth_top')), over(B('torso','torso_back'),F('cloth_top')), (0,30,0)),
      'cloth': (F('cloth_bottom'), S('cloth_bottom'), F('cloth_bottom'), (0,24,0)),
      'leg_l': (over(F('leg_l'),F('boot_l')), over(S('leg_l'),S('boot_l')), over(F('leg_r'),F('boot_r')), (-5,22,0)),
      'leg_r': (over(F('leg_r'),F('boot_r')), over(S('leg_r'),S('boot_r')), over(F('leg_l'),F('boot_l')), (5,22,0)),
    }
    if bald:
        del parts['hair']
        p=f'{OUTDIR}/{g}/hair.gltf'
        if os.path.exists(p): os.remove(p)
    info={}
    for name,(fr,sd,bk,pivot) in parts.items():
        keep=(eyes_f[...,3]>0) if name=='head' else None
        fr2=strip_outline(fr,keep); sd2=strip_outline(sd,(eyes_s[...,3]>0) if name=='head' else None); bk2=strip_outline(bk)
        if name in ('leg_l','leg_r'):
            # en perfil ambas piernas se solapan: usar la silueta de las dos
            sd=over(S('leg_l'),S('boot_l'),S('leg_r'),S('boot_r')); sd2=strip_outline(sd)
        vox=carve(fr,sd,bk)
        if name=='hair':
            # el pelo no debe rellenar la cara: quitar vóxeles que quedan delante del cráneo por debajo del flequillo
            head_vox=carve(parts['head'][0],parts['head'][1],parts['head'][2])
            vox&=~head_vox
        FALLBACK[:]=[fr2,sd2,bk2]
        pos,col,idx=mesh_from_vox(vox,fr2,sd2,bk2)
        write_gltf(f'{OUTDIR}/{g}/{name}.gltf',pos,col,idx,origin=pivot)
        info[name]={'voxels':int(vox.sum()),'pivot':pivot}
    # manos: frente del sprite recortado, 7 de fondo
    for side_name in ('hand_l','hand_r'):
        hand=load(f'{g}/{side_name}'); hh,hw=hand.shape[:2]
        canvas=np.zeros((H,W,4),np.uint8); canvas[69-hh+1:70,26-hw//2:26-hw//2+hw]=hand
        sd=np.zeros((H,W,4),np.uint8)
        ys=np.where(canvas[...,3].any(1))[0]
        for r in ys:
            w=int(round(7*np.sqrt(max(0,1-((r-ys.mean())/(len(ys)/2+0.5))**2))))+1
            sd[r,26-w//2:26-w//2+w]=canvas[r,np.where(canvas[r,:,3]>0)[0][len(np.where(canvas[r,:,3]>0)[0])//2]]
        vox=carve(canvas,sd,canvas)
        pos,col,idx=mesh_from_vox(vox,strip_outline(canvas),strip_outline(sd),strip_outline(canvas))
        cy=(69-ys.max()+69-ys.min())/2+0.5
        write_gltf(f'{OUTDIR}/{g}/{side_name}.gltf',pos,col,idx,origin=(0,cy,0))
        info[side_name]={'voxels':int(vox.sum())}
    return info

def extrude(img, depth):
    """Vóxeles de un sprite plano (armas): la imagen en el plano XY con `depth` de grosor."""
    h,w=img.shape[:2]
    vox=np.zeros((h,w,depth),bool); vox[:,:,:]=(img[...,3]>0)[:,:,None]
    return vox

def mesh_generic(vox, color_fn, origin):
    pos=[]; col=[]; idx=[]
    Hh,Ww,Dd=vox.shape
    def add(corners,c):
        b=len(pos)
        for p in corners: pos.append(p); col.append(c)
        idx.extend([b,b+1,b+2,b,b+2,b+3])
    rr,xx,zz=np.where(vox)
    for r,x,z in zip(rr,xx,zz):
        X=x; Y=Hh-1-r; Z=z
        e=lambda r2,x2,z2: not(0<=r2<Hh and 0<=x2<Ww and 0<=z2<Dd) or not vox[r2,x2,z2]
        c=color_fn(r,x,z)
        if e(r,x,z+1): add([(X,Y,Z+1),(X+1,Y,Z+1),(X+1,Y+1,Z+1),(X,Y+1,Z+1)],c)
        if e(r,x,z-1): add([(X+1,Y,Z),(X,Y,Z),(X,Y+1,Z),(X+1,Y+1,Z)],c)
        if e(r,x+1,z): add([(X+1,Y,Z+1),(X+1,Y,Z),(X+1,Y+1,Z),(X+1,Y+1,Z+1)],(np.array(c)*0.85).astype(int))
        if e(r,x-1,z): add([(X,Y,Z),(X,Y,Z+1),(X,Y+1,Z+1),(X,Y+1,Z)],(np.array(c)*0.85).astype(int))
        if e(r-1,x,z): add([(X,Y+1,Z+1),(X+1,Y+1,Z+1),(X+1,Y+1,Z),(X,Y+1,Z)],c)
        if e(r+1,x,z): add([(X,Y,Z),(X+1,Y,Z),(X+1,Y,Z+1),(X,Y,Z+1)],(np.array(c)*0.6).astype(int))
    return pos,col,idx

def build_extras(g):
    # Espada: sprite horizontal (empuñadura a la izquierda) -> vertical, empuñadura en el origen
    sword=np.array(Image.open(os.path.join(R,'..','weapons','sword.png')).convert('RGBA'))
    sword=np.rot90(sword,1)            # punta hacia arriba
    sword=strip_outline_any(sword)
    vox=extrude(sword,3)
    h,w=sword.shape[:2]
    grip_row=h-1-7                     # 7 px desde abajo (antes x=7 en horizontal)
    pos,col,idx=mesh_generic(vox,lambda r,x,z: sword[r,x,:3],(0,0,0))
    write_gltf(f'{OUTDIR}/{g}/sword.gltf',pos,col,idx,origin=(w/2,h-1-grip_row,1.5))
    # Peto de cuero: cáscara de 1 vóxel alrededor del torso (filas del pecho), con correas
    F=lambda n: load(f'{g}/{n}'); S=lambda n: load(f'{g}/side/{n}'); B=lambda n: load(f'{g}/{n}')
    torso=carve(F('torso'),S('torso'),B('torso_back'))
    dil=torso.copy()
    for ax in (1,2):
        for sh in (1,-1): dil|=np.roll(torso,sh,axis=ax)
    dil|=np.roll(torso,-1,axis=0)
    shell=dil&~torso
    shell[:24]=False; shell[37:]=False          # del pecho a la cintura
    LEATHER=[(150,96,58),(124,78,46),(96,58,36)]
    STRAP=(60,40,30); BUCKLE=(214,180,90)
    def leather(r,x,z):
        if x in (21,22) and z>26: return STRAP          # correa en diagonal (simplificada)
        if r in (30,31): return STRAP if (x+z)%7 else BUCKLE
        return LEATHER[(r+x//3+z//4)%3 if (r%5) else 2]
    pos=[];col=[];idx=[]
    rr,xx,zz=np.where(shell)
    def add(corners,c):
        b=len(pos)
        for p in corners: pos.append(p); col.append(c)
        idx.extend([b,b+1,b+2,b,b+2,b+3])
    for r,x,z in zip(rr,xx,zz):
        X=x-26; Y=69-r; Z=z-26; c=leather(r,x,z)
        e=lambda r2,x2,z2: not(0<=r2<H and 0<=x2<W and 0<=z2<W) or not shell[r2,x2,z2]
        if e(r,x,z+1): add([(X,Y,Z+1),(X+1,Y,Z+1),(X+1,Y+1,Z+1),(X,Y+1,Z+1)],c)
        if e(r,x,z-1): add([(X+1,Y,Z),(X,Y,Z),(X,Y+1,Z),(X+1,Y+1,Z)],c)
        if e(r,x+1,z): add([(X+1,Y,Z+1),(X+1,Y,Z),(X+1,Y+1,Z),(X+1,Y+1,Z+1)],c)
        if e(r,x-1,z): add([(X,Y,Z),(X,Y,Z+1),(X,Y+1,Z+1),(X,Y+1,Z)],c)
        if e(r-1,x,z): add([(X,Y+1,Z+1),(X+1,Y+1,Z+1),(X+1,Y+1,Z),(X,Y+1,Z)],c)
        if e(r+1,x,z): add([(X,Y,Z),(X+1,Y,Z),(X+1,Y,Z+1),(X,Y,Z+1)],c)
    write_gltf(f'{OUTDIR}/{g}/armor_chest.gltf',pos,col,idx,origin=(0,30,0))

def strip_outline_any(img):
    o=img.copy(); h,w=img.shape[:2]; a=img[...,3]>0
    dark=(img[...,:3].astype(int).sum(2)<95)&a
    for y,x in zip(*np.where(dark)):
        for dy,dx in ((0,1),(0,-1),(1,0),(-1,0)):
            yy,xx=y+dy,x+dx
            if 0<=yy<h and 0<=xx<w and a[yy,xx] and not dark[yy,xx]: o[y,x]=img[yy,xx]; break
    return o


if __name__=='__main__':
    print(build('male', bald=True))
    build_extras('male')
