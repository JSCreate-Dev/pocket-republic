import numpy as np, random, math
from PIL import Image
B='/workspace/pr-art/batch2/'
def L(n,s=2): return Image.open(f'{B}{n}.imageset/{n}@{s}x.png')
def Lb(n,s=2): return Image.open(f'/workspace/pr-art/sprites/{n}.imageset/{n}@{s}x.png')
N=14; T=64*2; TH=32*2
r=random.Random(3)
ter={}
for j in range(N):
  for i in range(N):
    d=math.hypot(i-6.5,(j-6.5)*1.1)+0.6*math.sin(i*0.9+j*0.4)+0.5*math.cos(j*1.1)
    k='water' if d>6.4 else 'sand' if d>5.3 else 'grass'
    if k=='grass' and i>=8 and j<=5: k='fertile'
    if k=='grass' and i<=3 and 3<=j<=5: k='rock'
    ter[i,j]=k
road=set([(i,7) for i in range(2,12)]+[(6,j) for j in range(3,12)]+[(9,j) for j in range(7,10)])
road={p for p in road if ter[p] not in('water',)}
H=lambda i,j:(i*73856093^j*19349663)&0xffff
W_=(2*N)*64+128; Hh=N*TH+300
img=Image.new('RGBA',(W_,Hh),(14,94,140,255))
ox=W_//2-T//2; oy=200
def pos(i,j): return ox+(i-j)*T//2, oy+(i+j)*TH//2
nv={'grass':4,'fertile':4,'sand':4,'rock':3,'water':4}
for j in range(-2,N+2):
  for i in range(-2,N+2):
    k=ter.get((i,j),'water'); x,y=pos(i,j)
    img.alpha_composite(L(f'tile_{k}_{H(i,j)%nv[k]}'),(x,y))
    if k=='water':
      isl=lambda a,b: ter.get((a,b),'water')!='water'
      for dn,(a,b) in {'n':(0,-1),'e':(1,0),'s':(0,1),'w':(-1,0)}.items():
        if isl(i+a,j+b): img.alpha_composite(L(f'tile_shore_{dn}'),(x,y))
      for dn,(a,b) in {'ne':(1,-1),'se':(1,1),'sw':(-1,1),'nw':(-1,-1)}.items():
        if isl(i+a,j+b) and not isl(i+a,j) and not isl(i,j+b): img.alpha_composite(L(f'tile_shore_corner_{dn}'),(x,y))
M={1:'N',2:'E',4:'S',8:'W'}
import json; amap=json.load(open(B+'road_autotile.json'))
for (i,j) in road:
  m=sum(b for b,(a,c) in zip((1,2,4,8),((0,-1),(1,0),(0,1),(-1,0))) if (i+a,j+c) in road)
  img.alpha_composite(L(amap[str(m)]),pos(i,j))
objs=[]
bld=[('building_townHall',3,8,3),('building_house',3,4,2),('building_house',7,8,2),('building_market',7,4,2),('building_clinic',10,8,2) ]
occ=set()
for n,i,j,w in [('building_townHall',3,8,3),('building_house',7,9,2),('building_house',10,4,2),('building_clinic',2,4,2)]:
  objs.append((i+w-1+j+w-1+1.5,n,i+w-1,j+w-1,'b',w))
  for a in range(w):
    for b in range(w): occ.add((i+a,j+b))
for j in range(N):
  for i in range(N):
    if (i,j) in road or (i,j) in occ: continue
    k=ter[i,j]; h=H(i,j)%100
    if k=='grass' and h<38: objs.append((i+j+.5,['deco_palm_0','deco_palm_1','deco_palm_2','deco_bush_0','deco_bush_1','deco_flowers_0','deco_palm_0'][h%7],i,j,'d',0))
    elif k=='sand' and h<22: objs.append((i+j+.5,['deco_palm_1','deco_palm_2','deco_rock_1'][h%3],i,j,'d',0))
    elif k=='rock' and h<70: objs.append((i+j+.5,['deco_rock_0','deco_rock_1'][h%2],i,j,'d',0))
    elif k=='fertile' and h<15: objs.append((i+j+.5,'deco_bush_0',i,j,'d',0))
wk=[(4,7,'ne'),(5,7,'sw'),(6,5,'sw'),(6,10,'ne'),(9,7,'ne'),(8,7,'sw'),(6,6,'ne')]
for n,(i,j,f) in enumerate(wk): objs.append((i+j+.6,f'walker_{n%6}_{f}_f{n%2}',i,j,'w',f))
objs.append((10.6,'cart_0_f0',3,7,'w','ne'))
for z,n,i,j,t,w in sorted(objs):
  x,y=pos(i,j)
  if t=='b':
    s=Lb(n); bx=x+T//2; by=y+TH
    img.alpha_composite(s,(bx-s.width//2,by-s.height))
  else:
    s=L(n)
    if t=='w' and w=='ne' : pass
    img.alpha_composite(s,(x+T//2-s.width//2+(r.randint(-8,8) if t=='d' else 0),y+TH//2+ (10 if t=='d' else 4)-s.height))
bb=img.getbbox(); img=img.crop((60,80,W_-60,Hh-30))
img.convert('RGB').save(B+'terrain_preview.png')
