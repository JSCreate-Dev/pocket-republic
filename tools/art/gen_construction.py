"""Hand-drawn isometric construction stages. Run from any directory with Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

ROOT = Path(__file__).resolve().parents[2] / 'PocketRepublic/Assets.xcassets/Buildings'
S = 3
INK='#583821'; EARTH='#B87C43'; EARTH_LIGHT='#DBA968'; EARTH_DARK='#85512C'
SAND='#E6BA79'; SAND_LIGHT='#F1CB91'; STONE='#AF9C80'; STONE_LIGHT='#D9C7A3'; STONE_DARK='#7F7465'
WOOD='#A76331'; WOOD_LIGHT='#D2914D'; WOOD_DARK='#6C3B20'; ROPE='#EAD1A2'; SHADOW='#57402F'


def point(x,y): return (round(x*S),round(y*S))
def poly(d,pts,fill,outline=None,width=1):
    p=[point(*q) for q in pts]; d.polygon(p,fill=fill)
    if outline: d.line(p+[p[0]],fill=outline,width=width*S,joint='curve')
def line(d,pts,fill,width=1): d.line([point(*p) for p in pts],fill=fill,width=max(1,round(width*S)),joint='curve')
def dot(d,x,y,color,r=.75):
    X,Y=point(x,y); R=round(r*S);d.ellipse((X-R,Y-R,X+R,Y+R),fill=color)
def lerp(a,b,t): return (a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t)

def make(w,h,stage):
    W=(w+h)*32; ground=(w+h)*16; lip=10
    H=(74 if w==h==2 else 106 if w==h==3 else 90) if stage=='foundation' else (96 if w==h==2 else 136 if w==h==3 else 112)
    y0=H-lip-ground; top=(h*32,y0); right=(W-1,y0+w*16); front=(w*32,H-lip-1); left=(1,y0+h*16)
    corners=[top,right,front,left]
    im=Image.new('RGBA',(W*S,H*S)); d=ImageDraw.Draw(im)
    # Dug sidewall: three visible faces, a narrow dark cut that keeps the site grounded.
    poly(d,[left,front,(front[0],front[1]+lip-1),(left[0],left[1]+lip-1)],EARTH_DARK,INK)
    poly(d,[front,right,(right[0],right[1]+lip-1),(front[0],front[1]+lip-1)],'#936035',INK)
    poly(d,corners,EARTH,INK)
    # Large sunlit plane and a darker earth patch on the right; no painted building colors.
    inner=[lerp(p,(W/2,y0+ground/2),.13) for p in corners]
    poly(d,inner,EARTH_LIGHT)
    poly(d,[lerp(top,front,.17),lerp(top,right,.18),lerp(right,front,.73),lerp(front,left,.68)],'#C58C50')
    # A quiet grid of raked dirt / shallow footing trenches, following the two iso axes.
    u=((right[0]-top[0])/w,(right[1]-top[1])/w)
    v=((left[0]-top[0])/h,(left[1]-top[1])/h)
    def xy(a,b): return (top[0]+u[0]*a+v[0]*b,top[1]+u[1]*a+v[1]*b)
    for a in range(1,w):
        line(d,[xy(a,.22),xy(a,h-.22)],'#A16B3A',1.4)
        line(d,[xy(a+.045,.24),xy(a+.045,h-.25)],'#E0AD6E',.7)
    for b in range(1,h):
        line(d,[xy(.22,b),xy(w-.22,b)],'#A16B3A',1.4)
        line(d,[xy(.24,b+.05),xy(w-.24,b+.05)],'#DCA364',.7)
    # Perimeter stone footing on the two rear edges. Light catches the left/top face.
    for a,b in ((.3,.23),(w-.48,.28),(.3,h-.43),(w-.48,h-.44)):
        x,y=xy(a,b)
        poly(d,[(x-4,y-2),(x,y-4),(x+5,y-1),(x+1,y+1)],STONE_LIGHT,STONE_DARK)
        poly(d,[(x-4,y-2),(x+1,y+1),(x+1,y+4),(x-4,y+1)],STONE,STONE_DARK)
        poly(d,[(x+1,y+1),(x+5,y-1),(x+5,y+2),(x+1,y+4)],STONE_DARK)
    if stage=='foundation':
        # Rope-and-stake line is the strongest read at small zoom.
        for i in range(4):
            a,b=corners[i],corners[(i+1)%4]
            line(d,[lerp(a,b,.06),lerp(a,b,.49),lerp(a,b,.94)],INK,2.3)
            line(d,[lerp(a,b,.06),lerp(a,b,.49),lerp(a,b,.94)],ROPE,1.3)
        for a,b in ((0,0),(w,0),(w,h),(0,h)):
            x,y=xy(a,b); line(d,[(x,y-2),(x,y-8)],WOOD_DARK,2.4)
            line(d,[(x-.8,y-7),(x-.8,y-9)],WOOD_LIGHT,1)
            dot(d,x,y-3,ROPE,.7)
        # Corner stone stack and two little pegs add scale without a vertical shell.
        x,y=xy(.33,h-.35)
        for dx,dy in ((0,0),(6,-3)):
            poly(d,[(x+dx-5,y+dy),(x+dx,y+dy-3),(x+dx+5,y+dy),(x+dx,y+dy+3)],STONE_LIGHT,STONE_DARK)
        for a,b in ((.7,.28),(w-.3,h-.63)):
            x,y=xy(a,b); line(d,[(x,y),(x,y-4)],WOOD_DARK,1.7)
        for a,b in ((.65,.72),(w-.6,h-.72),(w/2,h/2)):
            x,y=xy(a,b); dot(d,x,y,'#8D623A',.6)
    else:
        # Rear posts first, then rails and diagonal braces, then front posts.
        lift=20 if w==h==2 else 23 if w!=h else 27
        def post(p,frontpost=False):
            x,y=p
            poly(d,[(x-2,y),(x+2,y-1),(x+2,y-lift-1),(x-2,y-lift)],WOOD,INK)
            line(d,[(x-1.1,y-2),(x-1.1,y-lift+1)],WOOD_LIGHT,1)
            poly(d,[(x-3,y-lift),(x,y-lift-2),(x+3,y-lift),(x,y-lift+1)],WOOD_LIGHT,WOOD_DARK)
            if frontpost: line(d,[(x-2,y-4),(x+2,y-6)],WOOD_DARK,1)
        post(top);post(left);post(right)
        # Two open timber levels; tile behind remains visible through the frame.
        for z in (.43,.83):
            ring=[(x,y-lift*z) for x,y in corners]
            for i in (0,3,1,2):
                a,b=ring[i],ring[(i+1)%4]
                line(d,[a,b],INK,4.2);line(d,[a,b],WOOD_LIGHT if i in (0,3) else WOOD,2.4)
        for a,b in ((top,left),(top,right),(left,front),(right,front)):
            x,y=a;xx,yy=b
            line(d,[(x,y-lift*.82),(xx,yy-lift*.42)],WOOD_DARK,2.1)
            line(d,[(x,y-lift*.82),(xx,yy-lift*.42)],WOOD_LIGHT,.8)
        # Partial decking across the rear side; separate boards with dark gaps.
        for t in (.27,.45,.63):
            a=lerp(top,left,t);b=lerp(right,front,t)
            line(d,[(a[0],a[1]-lift*.45),(b[0],b[1]-lift*.45)],WOOD_DARK,3.2)
            line(d,[(a[0],a[1]-lift*.45-1),(b[0],b[1]-lift*.45-1)],WOOD_LIGHT,1.3)
        # The rising inner shell is taller than the outer site rails.
        shell=[xy(a,b) for a,b in ((.55,.55),(w-.55,.55),(w-.55,h-.55),(.55,h-.55))]
        shell_lift=28 if w==h==2 else 31 if w!=h else 36
        for p in shell:
            x,y=p
            line(d,[(x,y),(x,y-shell_lift)],INK,4)
            line(d,[(x-.6,y-1),(x-.6,y-shell_lift+1)],WOOD_LIGHT,2)
        roof=[(x,y-shell_lift) for x,y in shell]
        for a,b in ((0,1),(1,2),(2,3),(3,0)):
            line(d,[roof[a],roof[b]],INK,4)
            line(d,[roof[a],roof[b]],WOOD_LIGHT,2)
        for a,b in ((0,3),(1,2)):
            x,y=shell[a];xx,yy=shell[b]
            line(d,[(x,y-shell_lift+2),(xx,yy-3)],WOOD_DARK,2)
        post(front,True)
        # Ladder leans on the sunlit left edge, each rung readable at 1x.
        foot=lerp(left,front,.54); high=lerp(left,front,.42)
        fx,fy=foot;hx,hy=high;hy-=lift*.85
        for offset in (-2.3,2.3): line(d,[(fx+offset,fy+1),(hx+offset,hy)],WOOD_DARK,1.7)
        for t in (.2,.4,.6,.8):
            x=fx+(hx-fx)*t;y=fy+1+(hy-fy-1)*t
            line(d,[(x-2.3,y),(x+2.3,y)],SAND_LIGHT,1.1)
        # Material stack at the front entrance edge, small enough not to obscure the plot.
        mx,my=lerp(left,front,.78)
        for k in range(3):
            x=mx+k*3.2;y=my-k*1.4+2
            line(d,[(x-6,y+2),(x+5,y-4)],INK,4)
            line(d,[(x-6,y+1),(x+5,y-5)],WOOD_LIGHT,2)
        sx,sy=lerp(right,front,.68)
        for k in range(2):
            poly(d,[(sx+k*5-3,sy-k*2),(sx+k*5+1,sy-k*2-2),(sx+k*5+5,sy-k*2),(sx+k*5+1,sy-k*2+2)],STONE_LIGHT,STONE_DARK)
        # Tiny terracotta pennant: future ambient animation can move independently.
        bx,by=top
        line(d,[(bx,by-lift-2),(bx,by-lift-10)],WOOD_DARK,1.3)
        poly(d,[(bx,by-lift-10),(bx+10,by-lift-8),(bx+6,by-lift-5),(bx,by-lift-6)],'#D75C31',WOOD_DARK)
        if w==h==3:
            # Light hand-crane arm on the large site only.
            cx,cy=top;cy-=lift
            line(d,[(cx+4,cy+2),(cx+30,cy-10)],INK,3.4)
            line(d,[(cx+4,cy+1),(cx+30,cy-11)],WOOD_LIGHT,1.8)
            line(d,[(cx+19,cy-5),(cx+23,cy+11)],ROPE,1)
            poly(d,[(cx+20,cy+10),(cx+26,cy+10),(cx+24,cy+15),(cx+21,cy+15)],STONE,STONE_DARK)
    return im, (W,H)

for w,h in ((2,2),(3,2),(2,3),(3,3)):
    for stage in ('foundation','scaffold'):
        name=f'site_{stage}_{w}x{h}'; image,size=make(w,h,stage)
        folder=ROOT/f'{name}.imageset';folder.mkdir(parents=True,exist_ok=True)
        for scale in (1,2,3):
            out=image if scale==3 else image.resize((size[0]*scale,size[1]*scale),Image.Resampling.LANCZOS)
            out.save(folder/f'{name}@{scale}x.png',optimize=True)
        data={'images':[{'idiom':'universal','filename':f'{name}@{scale}x.png','scale':f'{scale}x'} for scale in (1,2,3)],'info':{'author':'xcode','version':1}}
        (folder/'Contents.json').write_text(json.dumps(data,indent=2)+'\n')
        print(name,size)
