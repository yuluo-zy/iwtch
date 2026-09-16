"""Replay actual Monkey C simulator test draw calls with the shipped font atlases.

This is a deterministic renderer preview, not a simulator screenshot. Font widths
are checked against those returned by Garmin's real Graphics.Dc in the test run.
"""
from pathlib import Path
import json
import argparse
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser(); p.add_argument('log',nargs='?',default='.local/test-output.log'); p.add_argument('--device',default='C:/Users/liyu/AppData/Roaming/Garmin/ConnectIQ/Devices/instinct3solar45mm/device.png'); a=p.parse_args()
    metadata={n:json.loads((ROOT/f'assets/{n}.json').read_text('utf-8')) for n in ['icons','iconssmall','tiny','data','time','bubble','date']}
    atlas={n:Image.open(ROOT/f'resources/fonts/{n}.png').convert('RGBA') for n in metadata}
    out=ROOT/'preview'; out.mkdir(exist_ok=True)
    frames=[]; im=None; fg=255; clip=None
    for line in (ROOT/a.log).read_text('utf-8-sig').splitlines():
        if line.startswith('FRAME|'):
            _,theme,count=line.split('|'); theme=int(theme); count=int(count)
            im=Image.new('L',(176,176),255 if theme else 0); clip=None
        elif line=='END_FRAME':
            im.save(out/f'face-{theme}-{count}-176.png'); frames.append((theme,count,im.copy())); im=None
        elif line.startswith('DRAW|') and im is not None:
            parts=line.split('|')[1:]; op=parts[0]
            if op=='color': fg=0 if parts[1]=='0' else 255; continue
            if op=='clip': clip=tuple(map(int,parts[1:])); continue
            if op=='unclip': clip=None; continue
            layer=im.copy(); d=ImageDraw.Draw(layer)
            if op=='text':
                x,y=int(parts[1]),int(parts[2]); font=parts[3]
                text=''.join(chr(int(c)) for c in parts[4].split(',') if c)
                width=sum(metadata[font][c]['advance'] for c in text)
                assert width==int(parts[6]),(font,text,width,parts[6])
                if parts[5]=='1': x-=width//2
                for c in text:
                    g=metadata[font][c]; mask=atlas[font].crop((g['x'],g['y'],g['x']+g['w'],g['y']+g['h'])).getchannel('A')
                    layer.paste(fg,(x,y,x+g['w'],y+g['h']),mask); x+=g['advance']
            elif op=='line': d.line(tuple(map(int,parts[1:])),fill=fg)
            elif op=='circle':
                x,y,r=map(int,parts[1:]); d.ellipse((x-r,y-r,x+r,y+r),outline=fg)
            elif op in ['rect','fill']:
                x,y,w,h=map(int,parts[1:]); d.rectangle((x,y,x+w-1,y+h-1),fill=fg if op=='fill' else None,outline=fg)
            else: raise ValueError(op)
            if clip:
                x,y,w,h=clip; im.paste(layer.crop((x,y,x+w,y+h)),(x,y))
            else: im=layer
    assert len(frames)==6
    # Approximate display cut-corners; actual device mask remains the simulator's responsibility.
    sheet=Image.new('RGB',(1200,850),'#e8e7e3'); d=ImageDraw.Draw(sheet)
    f=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
    d.text((32,16),'FIELD / 本能 3 Solar · 实际绘图代码预览',font=f,fill='#222222')
    for theme,count,frame in frames:
        x=40+(count-4)//2*395; y=65+theme*390
        d.text((x,y),f'{count} 项 / '+('白底' if theme else '黑底'),font=f,fill='#333333')
        sheet.paste(frame.convert('RGB').resize((352,352),Image.Resampling.NEAREST),(x,y+33))
    sheet.save(out/'layouts.png')
    if Path(a.device).exists():
        device=Image.open(a.device).convert('RGBA')
        board=Image.new('RGB',(device.width*2,device.height+45),'#e8e7e3')
        for theme,count,frame in frames:
            if count!=6: continue
            under=Image.new('RGBA',device.size,'#e8e7e3'); under.paste(frame.convert('RGBA'),(101,158))
            under.alpha_composite(device); board.paste(under.convert('RGB'),(theme*device.width,45))
        ImageDraw.Draw(board).text((20,8),'代码绘图 + SDK 屏幕遮罩（非真机照片）',font=f,fill='#222222')
        board.save(out/'device-preview.png')
    print('Verified actual Garmin text widths; exported all six renderer previews to preview/.')

if __name__=='__main__': main()
