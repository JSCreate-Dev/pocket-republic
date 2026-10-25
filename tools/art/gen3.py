import numpy as np, json, os
from PIL import Image, ImageDraw
from collections import deque
from scipy import ndimage
exec(open('gen2.py').read().split('def hexc')[0])
SRC='/cursor/stores/store-88c5a30a-5cd7-4d3f-a1d6-3983458c5e21/grok-bot/agents/3153ac7f-b0a9-484a-a535-d7601c3eab7d/attachments/c48f5ef17f6d6f3cd62a4ec59657eae16e72eff29dc00e4e1ad83ea0c648a2ea.jpg'
im=np.asarray(Image.open(SRC).convert('RGB')).astype(np.int32)
bg=np.median(np.concatenate([im[:8].reshape(-1,3),im[-8:].reshape(-1,3)]),axis=0)
d=np.sqrt(((im-bg)**2).sum(2))
alpha=np.clip((d-60)/50,0,1)
lab,n=ndimage.label(alpha>0.5)
sizes=ndimage.sum(np.ones_like(lab),lab,range(1,n+1))
objs=[i+1 for i,s in enumerate(sizes) if s>2000]
sl=ndimage.find_objects(lab)
boxes=[(sl[i-1],i) for i in objs]
boxes.sort(key=lambda b:(b[0][0].start>288, b[0][1].start))
names=['deco_palm_0','deco_palm_1','deco_palm_2','deco_bush_0','deco_bush_1','deco_rock_0','deco_rock_1','deco_flowers_0']
tw={'deco_palm_0':52,'deco_palm_1':44,'deco_palm_2':52,'deco_bush_0':38,'deco_bush_1':38,'deco_rock_0':40,'deco_rock_1':34,'deco_flowers_0':34}
a3=alpha[...,None]; rgb=np.where(a3>0.01,(im-(1-a3)*bg)/np.maximum(a3,0.01),0)
meta={}
for (s,idx),nm in zip(boxes,names):
    y0,y1,x0,x1=s[0].start,s[0].stop,s[1].start,s[1].stop
    m=ndimage.binary_dilation(lab[y0:y1,x0:x1]==idx,iterations=3)
    a=alpha[y0:y1,x0:x1]*m
    img=Image.fromarray(np.dstack([np.clip(rgb[y0:y1,x0:x1],0,255),a*255]).astype(np.uint8),'RGBA')
    w3=tw[nm]*3; h3=round(img.height*w3/img.width); big=img.resize((w3,h3),Image.LANCZOS)
    save_set(nm,from3x(big)); meta[nm]={'size1x':[tw[nm],h3//3],'anchor':[0.5,0.0]}
    if 'palm' in nm:  # sway frames: shear top
        for f,k in enumerate((0.06,-0.06),1):
            arr=np.asarray(big); out=np.zeros_like(arr); hh=arr.shape[0]
            for y in range(hh):
                t=(1-y/hh)**2; sh=int(round(k*t*hh)); out[y]=np.roll(arr[y],sh,axis=0)
            save_set(f'{nm}_sway{f}',from3x(Image.fromarray(out)))
print(len(boxes),meta)
json.dump(meta,open(OUT+'decos.json','w'),indent=1)
# walkers
SK=['#F1C9A5','#D9A27A','#A8714C','#6B4429','#E6B48E','#8D5A3B']
SH=['#D2552E','#00C2EE','#F5D58A','#A9D8C8','#F2B8C6','#F2A47A']
HAIR=['#3B2A1E','#1E1A18','#7A4A24','#2B2B2B','#C9A06A','#4A2E1E']
PANTS=['#3E4E6A','#6B5A44','#3E4E6A','#55606B','#6B5A44','#3E4E6A']
OL=(40,32,30,255)
def walker(i,face,f):
    W_,H_=10,16; im=Image.new('RGBA',(W_,H_)); p=im.load()
    def c(h): return tuple(int(h[k:k+2],16) for k in (1,3,5))+(255,)
    sk,sh,hr,pa=c(SK[i]),c(SH[i]),c(HAIR[i]),c(PANTS[i])
    sh_d=tuple(int(x*0.78) for x in sh[:3])+(255,)
    def rect(x0,y0,x1,y1,col):
        for y in range(y0,y1+1):
            for x in range(x0,x1+1): p[x,y]=col
    rect(3,1,6,4,sk); rect(3,0,6,1,hr)
    if face=='ne': rect(3,0,6,3,hr); rect(6,2,6,3,sk)
    else: p[4,3]=OL; p[6,3]=OL; rect(3,0,3,2,hr)
    rect(2,5,7,10,sh); rect(6,5,7,10,sh_d)
    # arms
    sw=1 if f else 0
    rect(1,6+sw,1,9+sw,sk); rect(8,6-sw+1,8,9-sw,sk)
    rect(3,11,6,12,pa)
    if f==0: rect(3,13,3,15,pa); rect(6,13,6,14,pa); p[3,15]=OL; p[6,14]=OL
    else: rect(4,13,4,14,pa); rect(5,13,5,15,pa); p[4,14]=OL; p[5,15]=OL
    if i%2==1 and face=='sw': rect(3,0,6,0,hr); p[2,1]=hr; p[7,1]=hr  # longer hair variant
    # outline
    a=np.asarray(im)[...,3]>0; arr=np.asarray(im).copy()
    dil=ndimage.binary_dilation(a)&~a
    arr[dil]=(40,32,30,200)
    big=np.zeros((H_+2,W_+2,4),np.uint8); big[1:-1,1:-1]=arr
    dil2=ndimage.binary_dilation(big[...,3]>0)&~(big[...,3]>0)
    return Image.fromarray(np.asarray(im))  # crisp, outline baked via OL pixels
def addol(img):
    a=np.asarray(img).copy(); m=a[...,3]>0
    pad=np.zeros((a.shape[0]+2,a.shape[1]+2,4),np.uint8); pad[1:-1,1:-1]=a
    mp=pad[...,3]>0; ring=ndimage.binary_dilation(mp)&~mp; ring[...,]=ring
    ring[2:,:]&=True
    pad[ring]=(52,38,34,255); return Image.fromarray(pad)
def nn(img): return {s:img.resize((img.width*s,img.height*s),Image.NEAREST) for s in (1,2,3)}
for i in range(6):
    for face in ('ne','sw'):
        for f in (0,1): save_set(f'walker_{i}_{face}_f{f}',nn(addol(walker(i,face,f))))
def cart(f):
    im=Image.new('RGBA',(18,13)); d=ImageDraw.Draw(im)
    d.polygon([(1,4),(13,4),(15,9),(3,9)],fill=(160,110,60)); d.line([(1,4),(13,4)],fill=(200,150,90))
    d.ellipse([2,0,6,5],fill=(242,98,42)); d.ellipse([6,0,10,5],fill=(245,213,138)); d.ellipse([9,1,13,5],fill=(93,170,69))
    d.line([(15,7),(17,6)],fill=(120,80,40))
    d.ellipse([3,7,8,12],fill=(80,55,35)); d.ellipse([4,8,7,11],fill=(190,150,100))
    if f: d.line([(4,9),(7,10)],fill=(80,55,35))
    else: d.line([(5,8),(6,11)],fill=(80,55,35))
    return im
for f in (0,1): save_set(f'cart_0_f{f}',nn(addol(cart(f))))
# icons at 72px (24pt)
def icon(name,draw):
    im=Image.new('RGBA',(288,288)); d=ImageDraw.Draw(im); draw(d)
    big=im.resize((72,72),Image.LANCZOS)
    save_set(name,{3:big,2:big.resize((48,48),Image.LANCZOS),1:big.resize((24,24),Image.LANCZOS)})
O='#5A3A22'
def coin(d): d.ellipse([24,24,264,264],fill='#C98E1E'); d.ellipse([24,16,264,248],fill='#F5C542',outline=O,width=14); d.ellipse([84,72,204,192],outline='#C98E1E',width=16); d.text
def people(d):
    d.ellipse([150,40,240,130],fill='#D2552E',outline=O,width=12); d.pieslice([120,140,270,300],180,360,fill='#D2552E',outline=O,width=12)
    d.ellipse([50,60,150,160],fill='#00A9D0',outline=O,width=12); d.pieslice([20,170,180,340],180,360,fill='#00A9D0',outline=O,width=12)
def food(d):
    d.ellipse([40,70,250,270],fill='#F2622A',outline=O,width=14); d.ellipse([80,110,130,160],fill='#F7A07A')
    d.line([(145,80),(160,24)],fill=O,width=16); d.ellipse([160,20,240,70],fill='#5DAA45',outline=O,width=10)
def happy(d):
    d.ellipse([24,24,264,264],fill='#F5D58A',outline=O,width=14); d.ellipse([90,95,120,135],fill=O); d.ellipse([168,95,198,135],fill=O)
    d.arc([80,120,208,220],20,160,fill=O,width=16)
def day(d):
    import math
    for k in range(8):
        a=k*math.pi/4; d.line([(144+70*math.cos(a),144+70*math.sin(a)),(144+128*math.cos(a),144+128*math.sin(a))],fill='#F2A21A',width=22)
    d.ellipse([74,74,214,214],fill='#F5C542',outline=O,width=12)
def decree(d):
    d.rounded_rectangle([60,30,228,250],18,fill='#F4EBDD',outline=O,width=12)
    for y in (80,120,160): d.line([(90,y),(198,y)],fill='#B89A7A',width=12)
    d.ellipse([150,180,250,280],fill='#D2552E',outline=O,width=10)
def alert(d):
    d.polygon([(144,24),(270,250),(18,250)],fill='#F2622A'); d.line([(144,24),(270,250),(18,250),(144,24)],fill=O,width=14,joint='curve')
    d.rounded_rectangle([130,90,158,180],12,fill='white'); d.ellipse([128,196,160,228],fill='white')
for n,fn in [('icon_coin',coin),('icon_people',people),('icon_food',food),('icon_happy',happy),('icon_day',day),('icon_decree',decree),('icon_alert',alert)]: icon(n,fn)
