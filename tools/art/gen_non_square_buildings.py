"""Draw the three non-square building sprites on their real isometric footprints."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

OUT=Path(__file__).resolve().parents[2]/'PocketRepublic/Assets.xcassets/Buildings'
S=3
INK='#51351E'; INK_SOFT='#715034'; SAND='#E9BE7D'; SAND_L='#F6D49A'; SAND_D='#C6955C'; PLINTH='#B7844F'
WOOD='#A86B3B'; WOOD_L='#D79758'; WOOD_D='#6E4225'; BRICK='#934B2C'; BRICK_L='#B86A3F'; ROOF='#414344'; ROOF_L='#66615B'; ROOF_D='#252C2D'
CREAM='#F4EBDD'; TURQ='#23ADBA'; BLUE='#148B9C'; RED='#D2552E'; ORANGE='#F2622A'; GREEN='#5DAA45'; GREEN_D='#397C34'; GOLD='#F5C542'

def pt(p): return tuple(round(q*S) for q in p)
def polygon(d,points,fill,outline=None,width=1):
 p=list(map(pt,points));d.polygon(p,fill=fill)
 if outline:d.line(p+[p[0]],fill=outline,width=round(width*S),joint='curve')
def line(d,points,fill,width=1):d.line(list(map(pt,points)),fill=fill,width=round(width*S),joint='curve')
def ellipse(d,box,fill,outline=None,width=1):d.ellipse(tuple(round(z*S) for z in box),fill=fill,outline=outline,width=round(width*S))
def lerp(p,q,t):return(p[0]+(q[0]-p[0])*t,p[1]+(q[1]-p[1])*t)
def light(p,h):return(p[0],p[1]-h)
def shift(p,dx,dy):return(p[0]+dx,p[1]+dy)

class Scene:
 def __init__(self,w,h,height):
  self.w=w;self.h=h;self.width=(w+h)*32;self.height=height;self.im=Image.new('RGBA',(self.width*S,height*S));self.d=ImageDraw.Draw(self.im)
  y0=height-1-(w+h)*16-7
  self.top=(h*32,y0);self.right=(self.width-1,y0+w*16);self.front=(w*32,height-8);self.left=(1,y0+h*16)
 def xy(self,a,b):
  t=self.top;return(t[0]+32*a-32*b,t[1]+16*a+16*b)
 def base(self):
  d=self.d;t,r,f,l=self.top,self.right,self.front,self.left
  # Thin plinth matches the tan foundation under existing finished buildings.
  polygon(d,[l,f,shift(f,0,7),shift(l,0,7)],PLINTH,INK_SOFT)
  polygon(d,[f,r,shift(r,0,7),shift(f,0,7)],SAND_D,INK_SOFT)
  polygon(d,[t,r,f,l],SAND,INK_SOFT,1.3)
  polygon(d,[lerp(t,(self.width/2,(t[1]+f[1])/2),.12),lerp(r,(self.width/2,(t[1]+f[1])/2),.12),lerp(f,(self.width/2,(t[1]+f[1])/2),.12),lerp(l,(self.width/2,(t[1]+f[1])/2),.12)],SAND_L)
  for a in range(1,self.w):line(d,[self.xy(a,.05),self.xy(a,self.h-.05)],'#D7A96F',.65)
  for b in range(1,self.h):line(d,[self.xy(.05,b),self.xy(self.w-.05,b)],'#D7A96F',.65)
  line(d,[t,l,f],SAND_L,1.1)
 def save(self,name):
  folder=OUT/f'building_{name}.imageset';folder.mkdir(parents=True,exist_ok=True)
  for scale in (1,2,3):
   image=self.im if scale==3 else self.im.resize((self.width*scale,self.height*scale),Image.Resampling.LANCZOS)
   image.save(folder/f'building_{name}@{scale}x.png',optimize=True)
  manifest=folder/'Contents.json'
  if not manifest.exists():
   manifest.write_text(json.dumps({'images':[{'idiom':'universal','filename':f'building_{name}@{s}x.png','scale':f'{s}x'} for s in (1,2,3)],'info':{'author':'xcode','version':1}},indent=2)+'\n')

def stall(sc,a,b,awning):
 d=sc.d; p=sc.xy(a,b); x,y=p
 # Merchant counter: sunlit top, dark near face, shaded right face.
 polygon(d,[(x-15,y-2),(x,y-9),(x+17,y-1),(x+2,y+6)],WOOD_L,INK)
 polygon(d,[(x-15,y-2),(x+2,y+6),(x+2,y+17),(x-15,y+9)],WOOD,INK)
 polygon(d,[(x+2,y+6),(x+17,y-1),(x+17,y+10),(x+2,y+17)],WOOD_D,INK)
 # Colorful produce baskets show this is a market even at the far zoom.
 for ox,oy,color in [(-8,-5,RED),(-2,-8,GREEN),(4,-6,GOLD),(10,-7,ORANGE)]:
  ellipse(d,(x+ox-3,y+oy-2,x+ox+2,y+oy+2),color)
 # Thin posts, roof frame and high striped fabric awning.
 for ox,oy in [(-14,-2),(15,0)]:line(d,[(x+ox,y+oy),(x+ox,y+oy-25)],WOOD_D,2.3)
 roof=[(x-20,y-27),(x-4,y-38),(x+21,y-26),(x+4,y-15)]
 polygon(d,roof,awning,INK)
 for i in range(4):
  p0=lerp(roof[0],roof[1],(i+.5)/4);p1=lerp(roof[3],roof[2],(i+.5)/4)
  polygon(d,[lerp(roof[0],roof[1],i/4),lerp(roof[0],roof[1],(i+1)/4),lerp(roof[3],roof[2],(i+1)/4),lerp(roof[3],roof[2],i/4)],CREAM if i%2==0 else awning)
 line(d,[roof[0],roof[3],roof[2]],INK,1.3)
 for k in range(5):
  p=lerp(roof[3],roof[2],k/4);line(d,[p,shift(p,0,3)],awning,2)

def market():
 sc=Scene(3,2,123);sc.base();d=sc.d
 # Stalls follow the true 3x2 lot. The open center reads as a plaza.
 stall(sc,.73,.48,TURQ)
 stall(sc,1.9,.45,RED)
 stall(sc,.52,1.45,RED)
 stall(sc,1.77,1.4,TURQ)
 # Market crates and hand-painted produce dots at the entrance.
 for a,b,c in [(1.25,1.43,GREEN),(1.45,1.58,ORANGE),(1.65,1.55,GOLD)]:
  x,y=sc.xy(a,b);polygon(d,[(x-4,y-2),(x,y-4),(x+4,y-2),(x,y)],WOOD_L,INK_SOFT)
  ellipse(d,(x-2,y-5,x+2,y-2),c)
 sc.save('market')

def workshop():
 sc=Scene(3,2,163);sc.base();d=sc.d
 # A broad timber-and-brick shed, long axis along +x.
 A=sc.xy(.45,.36);B=sc.xy(2.63,.36);C=sc.xy(2.63,1.58);D=sc.xy(.45,1.58)
 wall=55
 polygon(d,[light(D,wall),light(C,wall),C,D],BRICK,INK,1.3)
 polygon(d,[light(B,wall),light(C,wall),C,B],WOOD_D,INK,1.3)
 polygon(d,[light(A,wall),light(D,wall),D,A],WOOD,INK,1.3)
 # Triangular gables sit beneath the two pitched roof planes.
 ridgeA=light(lerp(A,D,.5),wall+32);ridgeB=light(lerp(B,C,.5),wall+32)
 polygon(d,[light(A,wall),ridgeA,light(D,wall)],BRICK_L,INK)
 polygon(d,[light(B,wall),ridgeB,light(C,wall)],WOOD_D,INK)
 line(d,[light(B,wall),ridgeB,light(C,wall)],WOOD_L,1)
 # Wall panels / exposed beams: strong silhouette and simple subdivisions.
 for t in (.28,.53,.78):
  p=lerp(D,C,t);line(d,[p,light(p,wall)],WOOD_D,2.5)
 for t in (.33,.66):
  p=lerp(A,D,t);line(d,[p,light(p,wall)],WOOD_L,2)
 for k in range(3):
  p=lerp(D,C,(k+.5)/3);q=light(p,wall*.5)
  line(d,[shift(q,-10,-5),shift(q,9,5)],BRICK_L,1.2)
 for t in (.35,.68):
  p=lerp(B,C,t)
  polygon(d,[shift(p,-3,-39),shift(p,5,-35),shift(p,5,-25),shift(p,-3,-29)],'#DCA453',INK)
  line(d,[shift(p,1,-37),shift(p,1,-27)],WOOD_D,.8)
 # Door and a glowing workshop window.
 door=lerp(D,C,.7)
 polygon(d,[shift(door,-10,-31),shift(door,7,-23),shift(door,7,0),shift(door,-10,-8)],WOOD_D,INK)
 line(d,[shift(door,-6,-26),shift(door,-6,-8)],WOOD_L,1.2)
 ellipse(d,(door[0]+1,door[1]-11,door[0]+2,door[1]-10),GOLD)
 window=lerp(A,D,.46)
 polygon(d,[shift(window,-7,-40),shift(window,5,-34),shift(window,5,-22),shift(window,-7,-28)],GOLD,INK)
 line(d,[shift(window,-1,-37),shift(window,-1,-25)],INK,1)
 # High charcoal pitched roof with terracotta ridge trim.
 eaves=[light(p,wall+3) for p in (A,B,C,D)]
 ridge0=light(lerp(A,D,.5),wall+32);ridge1=light(lerp(B,C,.5),wall+32)
 polygon(d,[eaves[0],eaves[1],ridge1,ridge0],ROOF_L,INK,1.4)
 polygon(d,[ridge0,ridge1,eaves[2],eaves[3]],ROOF,INK,1.4)
 for k in range(1,7):
  p=lerp(ridge0,ridge1,k/7);q=lerp(eaves[3],eaves[2],k/7)
  line(d,[p,q],ROOF_D,.7)
 for t in (.25,.5,.75):
  a=lerp(ridge0,eaves[3],t);b=lerp(ridge1,eaves[2],t)
  line(d,[a,b],ROOF_L,.7)
 line(d,[ridge0,ridge1],BRICK_L,2)
 # Brick chimney and a small stack of planks at the door.
 cx,cy=lerp(ridge0,ridge1,.25)
 polygon(d,[(cx-5,cy+3),(cx+1,cy+6),(cx+1,cy-9),(cx-5,cy-12)],BRICK,INK)
 polygon(d,[(cx+1,cy+6),(cx+7,cy+3),(cx+7,cy-12),(cx+1,cy-9)],BRICK_L,INK)
 polygon(d,[(cx-7,cy-12),(cx,cy-16),(cx+9,cy-12),(cx+2,cy-8)],BRICK_L,INK)
 px,py=sc.xy(2.28,1.7)
 for k in range(3):line(d,[(px-17,py-k*3),(px+10,py-k*3-14)],WOOD_D,3)
 sc.save('workshop')

def dock():
 sc=Scene(2,3,140);sc.base();d=sc.d
 # The 2x3 diamond has its long axis on +y; a shallow-water strip traces its east shore.
 water=[sc.xy(1.35,.3),sc.xy(2,.3),sc.xy(2,2.85),sc.xy(1.35,2.85)]
 polygon(d,water,TURQ)
 for b in (.55,1.28,2.02,2.68):
  a=sc.xy(1.62,b);bb=sc.xy(1.92,b)
  line(d,[a,bb],CREAM,.65)
 # Long wooden pier boards run in the +y direction over water.
 pier=[sc.xy(.45,.4),sc.xy(1.67,.4),sc.xy(1.67,2.63),sc.xy(.45,2.63)]
 shadow=[shift(p,0,8) for p in pier]
 polygon(d,[pier[3],pier[2],shadow[2],shadow[3]],WOOD_D,INK)
 polygon(d,[pier[1],pier[2],shadow[2],shadow[1]],WOOD_D,INK)
 polygon(d,pier,WOOD_L,INK,1.4)
 for b in (.58,.87,1.16,1.45,1.74,2.03,2.32):
  line(d,[sc.xy(.48,b),sc.xy(1.65,b)],WOOD_D,1.4)
  line(d,[sc.xy(.48,b+.035),sc.xy(1.65,b+.035)],SAND,.7)
 # Mooring posts along the long right edge, behind the small harbormaster hut.
 for b in (.42,1.32,2.46):
  x,y=sc.xy(1.68,b)
  polygon(d,[(x-3,y),(x+2,y-2),(x+2,y-20),(x-3,y-18)],WOOD_D,INK)
  polygon(d,[(x-4,y-19),(x,y-22),(x+4,y-19),(x,y-16)],WOOD_L,INK)
 # Tiny timber hut at landward end. Its red roof echoes the other buildings.
 x,y=sc.xy(.69,.7)
 polygon(d,[(x-15,y-33),(x+2,y-42),(x+19,y-33),(x+19,y-4),(x+2,y+5),(x-15,y-4)],WOOD,INK)
 polygon(d,[(x+2,y-42),(x+19,y-33),(x+19,y-4),(x+2,y+5)],WOOD_D,INK)
 polygon(d,[(x-18,y-34),(x+2,y-48),(x+23,y-35),(x+3,y-22)],RED,INK,1.2)
 line(d,[(x-15,y-32),(x+2,y-44)],ORANGE,1.2)
 polygon(d,[(x-7,y-15),(x+1,y-19),(x+1,y+1),(x-7,y-3)],INK)
 # Crates and a coiled rope at the pier approach.
 for dx,dy in ((0,0),(8,-5)):
  px,py=sc.xy(.67,1.98);px+=dx;py+=dy
  polygon(d,[(px-7,py-2),(px,py-6),(px+7,py-2),(px,py+2)],SAND_D,INK)
  polygon(d,[(px-7,py-2),(px,py+2),(px,py+10),(px-7,py+6)],WOOD,INK)
  polygon(d,[(px,py+2),(px+7,py-2),(px+7,py+6),(px,py+10)],WOOD_D,INK)
 rx,ry=sc.xy(1.1,2.34)
 ellipse(d,(rx-6,ry-3,rx+6,ry+3),WOOD_L,WOOD_D)
 ellipse(d,(rx-3,ry-1,rx+3,ry+2),WOOD_D)
 # One skiff in the shallows makes the pier's destination obvious.
 bx,by=sc.xy(1.77,1.77)
 polygon(d,[(bx-13,by+3),(bx+3,by-5),(bx+16,by),(bx+2,by+9)],WOOD_D,INK)
 polygon(d,[(bx-9,by+2),(bx+3,by-3),(bx+11,by),(bx+1,by+6)],SAND_D,INK_SOFT)
 line(d,[(bx-4,by-9),(bx+9,by+7)],WOOD_L,1.3)
 sc.save('dock')

market();workshop();dock()
