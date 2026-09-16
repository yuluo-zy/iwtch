"""Build-time only: single-bit icon/font atlases and settings from the metric registry.

Pillow is the only dependency. No font files are redistributed: tiny glyph subsets
are rasterized from the developer's installed fonts. Override --latin/--cjk on other OSes.
"""
from pathlib import Path
import argparse
import json
import math
from xml.sax.saxutils import escape
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['none','steps','energy','mountain','pressure','flame','battery','heart',
         'distance','stress','oxygen','thermometer','droplet','umbrella','wind',
         'message','stopwatch','sunrise','sunset','bluetooth','alarm','phone','moon',
         'sun','cloud','partly','rain','snow','storm','fog','sleet','hail','unknown',
         'wind0','wind1','wind2','wind3','wind4','wind5','wind6','wind7']
ICONS = {name: chr(0xE000+i) for i,name in enumerate(NAMES)}

def icon(name):
    im = Image.new('1', (13,13)); d=ImageDraw.Draw(im)
    def line(p,w=1): d.line(p,fill=1,width=w)
    def ellipse(b,fill=None): d.ellipse(b,fill=fill,outline=1)
    def poly(p): d.polygon(p,fill=1)
    def sun():
        ellipse((4,4,8,8),1)
        for p in [[(6,0),(6,2)],[(6,10),(6,12)],[(0,6),(2,6)],[(10,6),(12,6)],[(1,1),(2,2)],[(10,10),(11,11)],[(1,11),(2,10)],[(10,2),(11,1)]]: line(p)
    def cloud():
        ellipse((1,4,7,10),1); ellipse((4,2,10,10),1); ellipse((8,5,12,10),1)
        d.rectangle((3,6,10,10),fill=1)
    if name == 'steps':
        ellipse((1,1,4,6),1); ellipse((7,4,10,9),1); d.rectangle((1,8,3,10),fill=1); d.rectangle((7,11,9,12),fill=1)
    elif name in ['energy','storm']:
        if name=='storm': cloud()
        poly([(7,0),(2,7),(6,7),(4,12),(11,4),(7,4)])
    elif name=='mountain': poly([(0,11),(5,2),(8,7),(10,5),(12,11)]); poly0=[(4,5),(5,3),(7,6)]; d.polygon(poly0,fill=0)
    elif name=='pressure':
        d.arc((0,1,12,13),180,360,fill=1); line([(1,8),(2,8)]); line([(6,2),(6,3)]); line([(10,8),(11,8)]); line([(6,9),(9,5)],2)
    elif name=='flame':
        poly([(7,0),(10,5),(12,8),(10,12),(3,12),(1,8),(4,4),(4,8),(7,5)]); d.polygon([(6,8),(8,11),(5,11)],fill=0)
    elif name=='battery':
        d.rectangle((0,3,10,10),outline=1); d.rectangle((11,5,12,8),fill=1); d.rectangle((2,5,7,8),fill=1)
    elif name=='heart':
        ellipse((0,2,6,8),1); ellipse((6,2,12,8),1); poly([(0,5),(12,5),(6,12)])
    elif name=='distance':
        line([(1,11),(4,1)],2); line([(9,11),(12,1)],2); line([(6,10),(7,8)]); line([(8,5),(9,2)])
    elif name=='stress': line([(0,7),(3,7),(5,1),(7,11),(9,5),(12,5)],2)
    elif name=='oxygen':
        ellipse((0,2,7,10)); line([(10,5),(12,5),(12,8),(10,11),(12,11)])
    elif name=='thermometer':
        ellipse((4,0,8,10)); ellipse((3,7,9,12),1); line([(6,3),(6,9)],2)
    elif name=='droplet': poly([(6,0),(11,8),(10,11),(6,12),(2,11),(1,8)])
    elif name=='umbrella':
        d.arc((0,0,12,12),180,360,fill=1); line([(0,6),(12,6)]); line([(6,6),(6,11),(4,12),(3,10)])
    elif name=='wind':
        line([(0,4),(9,4),(11,2),(9,0),(7,1)]); line([(0,7),(12,7)]); line([(0,10),(8,10),(10,12)])
    elif name=='message':
        d.rectangle((0,1,12,9),outline=1); line([(2,9),(2,12),(5,9)]); line([(3,4),(9,4)]); line([(3,6),(7,6)])
    elif name=='stopwatch':
        ellipse((1,3,11,12)); line([(4,0),(8,0)],2); line([(6,1),(6,3)]); line([(6,5),(6,8),(8,8)])
    elif name in ['sunrise','sunset']:
        d.arc((2,6,10,14),180,360,fill=1); line([(0,11),(12,11)])
        if name=='sunrise': line([(6,0),(6,5)]); line([(3,3),(6,0),(9,3)])
        else: line([(6,0),(6,5)]); line([(3,2),(6,5),(9,2)])
    elif name=='bluetooth': line([(3,3),(9,9),(6,12),(6,0),(9,3),(3,9)],1)
    elif name=='alarm':
        ellipse((2,2,10,10)); line([(6,4),(6,6),(8,7)]); line([(0,2),(3,0)]); line([(9,0),(12,2)]); line([(3,11),(2,12)]); line([(9,11),(10,12)])
    elif name=='phone': poly([(0,1),(3,0),(5,4),(3,6),(6,9),(8,7),(12,9),(11,12),(7,12),(3,9),(0,5)])
    elif name=='moon': ellipse((1,0,11,11),1); d.ellipse((5,0,13,8),fill=0)
    elif name=='sun': sun()
    elif name=='cloud': cloud()
    elif name=='partly': sun(); cloud()
    elif name in ['rain','sleet','hail']:
        cloud(); d.rectangle((0,9,12,12),fill=0)
        for x in [2,6,10]:
            if name=='hail': d.rectangle((x,11,x+1,12),fill=1)
            else: line([(x,10),(x-1,12)])
        if name=='sleet': line([(6,9),(6,12)]); line([(4,11),(8,11)])
    elif name=='snow':
        line([(6,0),(6,12)]); line([(1,3),(11,9)]); line([(1,9),(11,3)]); line([(4,1),(6,3),(8,1)]); line([(4,11),(6,9),(8,11)])
    elif name=='fog':
        for y in [3,6,9]: line([(1 if y==6 else 3,y),(11,y)])
    elif name=='unknown':
        line([(3,2),(4,1),(8,1),(10,3),(9,5),(6,7),(6,8)]); d.point((6,11),fill=1)
    elif name.startswith('wind'):
        a=int(name[-1])*math.pi/4
        def p(x,y): return (round(6+x*math.cos(a)-y*math.sin(a)),round(6+x*math.sin(a)+y*math.cos(a)))
        line([p(0,5),p(0,-5)],2); poly([p(0,-6),p(-3,-1),p(3,-1)])
    return im

def write_font(name, glyphs, height):
    out=ROOT/'resources/fonts'; out.mkdir(parents=True,exist_ok=True)
    width=256; x=y=0; positions=[]
    for char,img,adv in glyphs:
        if x+img.width>width: x=0; y+=height+1
        positions.append((char,img,adv,x,y)); x+=img.width+1
    atlas=Image.new('RGBA',(width,y+height),(0,0,0,0))
    lines=[f'info face="{name}" size={height} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',f'common lineHeight={height} base={height} scaleW={width} scaleH={atlas.height} pages=1 packed=0',f'page id=0 file="{name}.png"',f'chars count={len(positions)}']
    metadata={}
    for char,img,adv,x,y in positions:
        ink=Image.new('RGBA',img.size,'white'); ink.putalpha(img.convert('L')); atlas.paste(ink,(x,y))
        lines.append(f'char id={ord(char)} x={x} y={y} width={img.width} height={img.height} xoffset=0 yoffset=0 xadvance={adv} page=0 chnl=15')
        metadata[char]={'x':x,'y':y,'w':img.width,'h':img.height,'advance':adv}
    atlas.save(out/f'{name}.png'); (out/f'{name}.fnt').write_text('\n'.join(lines),encoding='utf-8')
    (ROOT/'assets'/f'{name}.json').write_text(json.dumps(metadata,ensure_ascii=False),encoding='utf-8')

def text_font(name, chars, height, font_path, digit_width=None):
    font=ImageFont.truetype(font_path,height)
    glyphs=[]
    for c in chars:
        if c==' ': glyphs.append((c,Image.new('1',(3,height)),3)); continue
        if digit_width and c==':':
            im=Image.new('1',(5,height)); d=ImageDraw.Draw(im)
            for cy in [height//3,2*height//3]: d.rectangle((1,cy,3,cy+3),fill=1)
            glyphs.append((c,im,7)); continue
        box=font.getbbox(c); tmp=Image.new('L',(max(1,box[2]-box[0]),max(1,box[3]-box[1])))
        ImageDraw.Draw(tmp).text((-box[0],-box[1]),c,font=font,fill=255,stroke_width=0)
        target_w=digit_width if digit_width and c.isdigit() else max(2,round(tmp.width*height/max(1,tmp.height)*0.65)) if digit_width else tmp.width
        target_h=height if digit_width else min(height,tmp.height)
        tmp=tmp.resize((target_w,target_h),Image.Resampling.LANCZOS).point(lambda v:255 if v>=110 else 0).convert('1')
        im=Image.new('1',(target_w,height)); im.paste(tmp,(0,0 if digit_width else max(0,(height-target_h)//2)))
        glyphs.append((c,im,target_w+(2 if digit_width else 1)))
    write_font(name,glyphs,height)

def generate_settings(metrics):
    settings=ROOT/'resources/settings'; settings.mkdir(parents=True,exist_ok=True)
    strings={'AppName':'本能 · FIELD','theme':'显示模式','slotCount':'底部数据数量','bubble':'右上小窗指标','seconds':'秒数模式','dataInterval':'指标采样间隔（秒）','weatherInterval':'天气读取间隔（分钟）','progress':'步数进度条'}
    props=[]; entries=[]; catalog=[]
    def setting(key,default,options):
        catalog.append((key,default,options))
        props.append(f'<property id="{key}" type="number">{default}</property>')
        opts=[]
        for value,label in options:
            sid=f'{key}_{value}'; strings[sid]=label; opts.append(f'<listEntry value="{value}">@Strings.{sid}</listEntry>')
        entries.append(f'<setting propertyKey="@Properties.{key}" title="@Strings.{key}"><settingConfig type="list">'+''.join(opts)+'</settingConfig></setting>')
    setting('theme',0,[(0,'黑底白字'),(1,'白底黑字')]); setting('slotCount',6,[(4,'4 项 · 舒展'),(6,'6 项 · 标准'),(8,'8 项 · 紧凑')])
    setting('bubble',7,[(m['id'],m['label']) for m in metrics if m['id']])
    setting('seconds',1,[(0,'关闭 · 最低负荷'),(1,'仅抬腕显示 · 推荐'),(2,'常显 · 局部刷新')])
    setting('dataInterval',60,[(60,'60 秒'),(120,'120 秒'),(300,'300 秒')]); setting('weatherInterval',15,[(5,'5 分钟'),(15,'15 分钟'),(30,'30 分钟'),(60,'60 分钟')]); setting('progress',1,[(0,'关闭'),(1,'开启')])
    for i,default in enumerate([1,2,3,4,5,6,9,8],1):
        key=f'slot{i}'; strings[key]=f'数据槽 {i}（逐行从左到右）'; setting(key,default,[(m['id'],m['label']) for m in metrics])
    (settings/'properties.xml').write_text('<properties>\n'+'\n'.join(props)+'\n</properties>',encoding='utf-8')
    (settings/'settings.xml').write_text('<settings>\n'+'\n'.join(entries)+'\n</settings>',encoding='utf-8')
    out=ROOT/'resources/strings'; out.mkdir(exist_ok=True)
    (out/'strings.xml').write_text('<strings>\n'+ '\n'.join(f'<string id="{k}">{escape(v)}</string>' for k,v in strings.items())+'\n</strings>',encoding='utf-8')
    mc='// Generated by tools/generate_assets.py. Edit config/metrics.json.\nmodule Metrics {\n'
    mc+='\n'.join(f'    const {m["key"]} = {m["id"]};' for m in metrics)
    mc+=f'\n    const COUNT = {len(metrics)};\n'
    mc+='    const ICONS = ['+', '.join(json.dumps(ICONS[m['icon']],ensure_ascii=False) for m in metrics)+'];\n'
    mc+='    const UNITS = ['+', '.join(json.dumps(m['unit'],ensure_ascii=False) for m in metrics)+'];\n}\n'
    (ROOT/'source/Metrics.mc').write_text(mc,encoding='utf-8')
    menu='// Generated; resource strings are only loaded when opening settings.\nmodule SettingsCatalog {\n'
    menu+='    const KEYS = ['+', '.join(json.dumps(k) for k,_,_ in catalog)+'];\n'
    menu+='    const TITLES = ['+', '.join('Rez.Strings.'+k for k,_,_ in catalog)+'];\n'
    menu+='    function choices(index) {\n        switch(index) {\n'
    for i,(key,default,opts) in enumerate(catalog):
        menu+=f'            case {i}: return ['+', '.join(f'[{v}, Rez.Strings.{key}_{v}]' for v,label in opts)+'];\n'
    menu+='        }\n        return [];\n    }\n}\n'
    (ROOT/'source/SettingsCatalog.mc').write_text(menu,encoding='utf-8')

def main():
    p=argparse.ArgumentParser(); p.add_argument('--latin',default='C:/Windows/Fonts/arialbd.ttf'); p.add_argument('--cjk',default='C:/Windows/Fonts/msyh.ttc'); args=p.parse_args()
    (ROOT/'assets').mkdir(exist_ok=True)
    write_font('icons',[(ICONS[n],icon(n),13) for n in NAMES],13)
    write_font('iconssmall',[(ICONS[n],icon(n).resize((11,11),Image.Resampling.NEAREST),11) for n in NAMES],11)
    chars='0123456789:+-.%kmMs/° '
    text_font('tiny',chars,9,args.latin); text_font('data',chars,12,args.latin)
    text_font('time','0123456789:',39,args.latin,23)
    text_font('bubble',chars,21,args.latin,12)
    text_font('date','周日一二三四五六月0123456789 ',12,args.cjk)
    fonts=['icons','iconssmall','tiny','data','time','bubble','date']
    (ROOT/'resources/fonts/fonts.xml').write_text('<fonts>'+''.join(f'<font id="{n.title()}" filename="{n}.fnt" antialias="false"/>' for n in fonts)+'</fonts>',encoding='utf-8')
    (ROOT/'source/Icons.mc').write_text('// Generated monochrome glyph codes; no runtime rasterization.\nmodule Icons {\n'+''.join(f'    const {n.upper()} = "{ICONS[n]}";\n' for n in NAMES)+'    const DIRECTIONS = ['+', '.join('"'+ICONS[f'wind{i}']+'"' for i in range(8))+'];\n}\n',encoding='utf-8')
    metrics=json.loads((ROOT/'config/metrics.json').read_text(encoding='utf-8')); generate_settings(metrics)
    out=ROOT/'resources/drawables'; out.mkdir(exist_ok=True)
    launcher=Image.new('1',(62,62)); d=ImageDraw.Draw(launcher); d.ellipse((1,1,60,60),outline=1,width=2); d.text((11,17),'10',font=ImageFont.truetype(args.latin,30),fill=1); launcher.save(out/'launcher.png')
    (out/'drawables.xml').write_text('<drawables><bitmap id="LauncherIcon" filename="launcher.png"/></drawables>',encoding='utf-8')
    sheet=Image.new('RGB',(520,math.ceil(len(NAMES)/5)*60),'#20242a'); d=ImageDraw.Draw(sheet)
    for i,n in enumerate(NAMES):
        x=(i%5)*104; y=(i//5)*60; sheet.paste(icon(n).resize((26,26),Image.Resampling.NEAREST),(x+4,y+3)); d.text((x+4,y+33),n,fill='white')
    sheet.save(ROOT/'assets/icon-catalog.png')
    print(f'Generated {len(NAMES)} icons at 2 sizes, 7 font atlases, {len(metrics)-1} metrics and app settings.')

if __name__=='__main__': main()
