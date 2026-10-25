import numpy as np, json, os, math, random
from PIL import Image, ImageDraw, ImageFilter
from collections import deque
OUT='/workspace/pr-art/batch2/'
def save_set(name, imgs):  # imgs: {1:img,2:img,3:img}
    d=OUT+name+'.imageset'; os.makedirs(d,exist_ok=True)
    for s,im in imgs.items(): im.save(f'{d}/{name}@{s}x.png',optimize=True)
    json.dump({"images":[{"idiom":"universal","filename":f"{name}@{s}x.png","scale":f"{s}x"} for s in (1,2,3)],"info":{"author":"xcode","version":1}},open(d+'/Contents.json','w'),indent=2)
def from3x(im):
    return {3:im,2:im.resize((im.width*2//3,im.height*2//3),Image.LANCZOS),1:im.resize((im.width//3,im.height//3),Image.LANCZOS)}
def hexc(h): return np.array([int(h[i:i+2],16) for i in (1,3,5)],float)
S=3; W,H=64*S,32*S
ys,xs=np.mgrid[0:H,0:W]+0.5
U=((xs-W/2)/(W/2)+ys/(H/2))/2; V=(ys/(H/2)-(xs-W/2)/(W/2))/2
MASK=(U>=-0.012)&(U<=1.012)&(V>=-0.012)&(V<=1.012)
def smooth_noise(seed,cells=6):
    r=np.random.RandomState(seed); g=r.rand(cells+1,cells+1)
    # periodic: wrap so tiles butt (edge values same)
    g[-1,:]=g[0,:]; g[:,-1]=g[:,0]
    uu=np.clip(U,0,1)*cells; vv=np.clip(V,0,1)*cells
    i=np.minimum(uu.astype(int),cells-1); j=np.minimum(vv.astype(int),cells-1); fu=uu-i; fv=vv-j
    fu=fu*fu*(3-2*fu); fv=fv*fv*(3-2*fv)
    return (g[i,j]*(1-fu)*(1-fv)+g[i+1,j]*fu*(1-fv)+g[i,j+1]*(1-fu)*fv+g[i+1,j+1]*fu*fv)
def to_img(rgb,alpha):
    return Image.fromarray(np.dstack([np.clip(rgb,0,255),np.clip(alpha,0,255)]).astype(np.uint8),'RGBA')
def uv2xy(u,v): return ((u-v)*W/2+W/2, (u+v)*H/2)
TER={'grass':('#5DAA45',4),'fertile':('#4A8A3A',4),'sand':('#E8C77A',4),'rock':('#8A8D86',3),'water':('#1478A8',4)}
def terrain(kind,var,frame=0):
    base=hexc(TER[kind][0]); seed=hash((kind,var))%9999
    n=smooth_noise(seed)-0.5; n2=smooth_noise(seed+7,14)-0.5
    tone=[0,0.04,-0.035,0.02][var]
    rgb=base[None,None,:]*(1+tone+0.07*n[...,None]+0.04*n2[...,None])
    if kind=='water':
        deep=hexc('#0E5E8C'); rgb=rgb*0.75+deep*0.25*(1+0.2*n[...,None])
    im=to_img(rgb,MASK*255); d=ImageDraw.Draw(im); r=random.Random(seed*10+frame*0+1)
    def inside(u,v,m=0.06): return m<u<1-m and m<v<1-m
    if kind in('grass','fertile'):
        dk=tuple(int(c) for c in base*0.72); lt=tuple(int(min(255,c*1.25)) for c in base)
        for _ in range(14):
            u,v=r.random(),r.random()
            if not inside(u,v,0.1): continue
            x,y=uv2xy(u,v)
            for k in(-1,0,1): d.line([(x+k*4,y),(x+k*5,y-7)],fill=dk,width=2)
            d.line([(x,y-1),(x+1,y-7)],fill=lt,width=2)
        if kind=='fertile':
            for _ in range(40):
                u,v=r.random(),r.random()
                if inside(u,v): x,y=uv2xy(u,v); d.ellipse([x-2,y-1,x+2,y+1],fill=(110,78,48))
        if kind=='grass' and var==3:
            for _ in range(3):
                u,v=r.uniform(.2,.8),r.uniform(.2,.8); x,y=uv2xy(u,v); d.ellipse([x-3,y-3,x+3,y+3],fill=(245,213,138))
    if kind=='sand':
        c=tuple(int(x) for x in base*0.88)
        for k in range(4):
            v0=0.2+k*0.2+r.uniform(-.05,.05)
            pts=[uv2xy(u,v0+0.02*math.sin(u*9+k)) for u in np.linspace(.08,.92,20)]
            d.line(pts,fill=c,width=2)
        for _ in range(6):
            u,v=r.random(),r.random()
            if inside(u,v): x,y=uv2xy(u,v); d.ellipse([x-2,y-1,x+2,y+1],fill=(250,240,220))
    if kind=='rock':
        c=(92,95,90)
        for _ in range(3):
            u,v=r.uniform(.2,.8),r.uniform(.2,.8); pts=[uv2xy(u,v)]
            for _ in range(4): u+=r.uniform(-.12,.12); v+=r.uniform(-.12,.12); pts.append(uv2xy(min(max(u,.08),.92),min(max(v,.08),.92)))
            d.line(pts,fill=c,width=2)
        for _ in range(4):
            u,v=r.uniform(.15,.85),r.uniform(.15,.85); x,y=uv2xy(u,v); d.ellipse([x-6,y-3,x+6,y+3],fill=(160,163,156)); d.ellipse([x-5,y-3,x+4,y+1],fill=(178,180,172))
    if kind=='water':
        r2=random.Random(seed*3+frame)
        for _ in range(5):
            u,v=r2.uniform(.15,.85),r2.uniform(.15,.85); x,y=uv2xy(u,v); L=r2.randint(6,14)
            d.line([(x-L,y),(x+L,y)],fill=(120,215,240),width=2)
    a=np.asarray(im).copy(); a[...,3]=np.where(MASK,a[...,3],0); return Image.fromarray(a)
for k,(c,nv) in TER.items():
    for v in range(nv):
        save_set(f'tile_{k}_{v}',from3x(terrain(k,v)))
        if k=='water': save_set(f'tile_water_{v}_f1',from3x(terrain(k,v,1)))
# shore foam
def foam(cond_dist,seed):
    r=np.random.RandomState(seed); n=smooth_noise(seed,10)
    dist=cond_dist
    a=np.clip(1-(dist-0.02-0.08*n)/0.06,0,1)
    line=np.exp(-((dist-0.17-0.04*n)/0.025)**2)*0.6
    al=np.maximum(a,line)*MASK
    return to_img(np.ones((H,W,3))*255,al*235)
Uc,Vc=np.clip(U,0,1),np.clip(V,0,1)
shore={'n':Vc,'e':1-Uc,'s':1-Vc,'w':Uc,
 'ne':np.hypot(1-Uc,Vc)*1.0,'se':np.hypot(1-Uc,1-Vc),'sw':np.hypot(Uc,1-Vc),'nw':np.hypot(Uc,Vc)}
for k,dist in shore.items():
    name=f'tile_shore_{k}' if len(k)==1 else f'tile_shore_corner_{k}'
    save_set(name,from3x(foam(dist,len(k)*11+ord(k[0]))))
# roads (overlay)
RW=0.27
def road(conn,seed=5):
    du,dv=np.abs(Uc-.5),np.abs(Vc-.5)
    m=(du<RW)&(dv<RW)
    if 'N' in conn: m|=(du<RW)&(Vc<.5)
    if 'S' in conn: m|=(du<RW)&(Vc>.5)
    if 'W' in conn: m|=(dv<RW)&(Uc<.5)
    if 'E' in conn: m|=(dv<RW)&(Uc>.5)
    m&=MASK
    # distance to non-road (approx via erosion)
    mi=Image.fromarray((m*255).astype(np.uint8)); inner=np.asarray(mi.filter(ImageFilter.MinFilter(9)))>128
    n=smooth_noise(seed,8)
    base=hexc('#B98E57')*(1+0.08*(n[...,None]-.5))
    # cobbles
    cu=(Uc*10)%1; cv=(Vc*10+((Uc*10).astype(int)%2)*.5)%1
    gap=(cu<.1)|(cv<.1)
    rgb=np.where(gap[...,None],base*0.82,base*(1+0.05*np.sin(Uc*37+Vc*23))[...,None])
    curb=m&~inner
    rgb=np.where(curb[...,None],hexc('#E6D2A0')[None,None,:],rgb)
    edge=m&~(np.asarray(mi.filter(ImageFilter.MinFilter(3)))>128)
    rgb=np.where((edge&(Vc>.5)|(edge&(Uc>.5)))[...,None],hexc('#9C7A48')[None,None,:],rgb)
    return to_img(rgb,m*255)
R={'road_single':'','road_cross':'NESW','road_straight_ns':'NS','road_straight_ew':'EW',
 'road_corner_ne':'NE','road_corner_es':'ES','road_corner_sw':'SW','road_corner_wn':'WN',
 'road_t_nes':'NES','road_t_esw':'ESW','road_t_swn':'SWN','road_t_wne':'WNE',
 'road_end_n':'N','road_end_e':'E','road_end_s':'S','road_end_w':'W'}
mapping={}
for name,c in R.items():
    save_set(name,from3x(road(c))); mask=sum(b for b,ch in zip((1,2,4,8),'NESW') if ch in c); mapping[mask]=name
json.dump({str(k):mapping[k] for k in sorted(mapping)},open(OUT+'road_autotile.json','w'),indent=1)
