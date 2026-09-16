"""Validate generated registries, glyph coverage and real SDK screen-mask clipping."""
from pathlib import Path
import json
import argparse
import xml.etree.ElementTree as ET
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser(); p.add_argument('--device',default='C:/Users/liyu/AppData/Roaming/Garmin/ConnectIQ/Devices/instinct3solar45mm/device.png'); a=p.parse_args()
    metrics=json.loads((ROOT/'config/metrics.json').read_text('utf-8'))
    assert [m['id'] for m in metrics]==list(range(len(metrics)))
    strings={e.attrib['id'] for e in ET.parse(ROOT/'resources/strings/strings.xml').getroot()}
    properties={e.attrib['id']:int(e.text) for e in ET.parse(ROOT/'resources/settings/properties.xml').getroot()}
    settings=ET.parse(ROOT/'resources/settings/settings.xml').getroot()
    for s in settings:
        key=s.attrib['propertyKey'].split('.')[-1]
        assert key in properties
        assert s.attrib['title'].split('.')[-1] in strings
        assert properties[key] in [int(e.attrib['value']) for e in s[0]]
        for e in s[0]: assert e.text.split('.')[-1] in strings
    fonts={f.stem:json.loads(f.read_text('utf-8')) for f in (ROOT/'assets').glob('*.json')}
    atlases={n:Image.open(ROOT/f'resources/fonts/{n}.png').getchannel('A') for n in fonts}
    for n,atlas in atlases.items(): assert set(atlas.tobytes()) <= {0,255},n
    assert all(c in fonts['date'] for c in '周日一二三四五六月0123456789 ')
    if Path(a.device).exists():
        mask=Image.open(a.device).getchannel('A').crop((101,158,277,334))
        failures=set()
        for line in (ROOT/'.local/test-output.log').read_text('utf-8-sig').splitlines():
            if not line.startswith('DRAW|text|'): continue
            _,_,xs,ys,font,codes,align,_=line.split('|'); x,y=int(xs),int(ys)
            text=''.join(chr(int(c)) for c in codes.split(',') if c)
            width=sum(fonts[font][c]['advance'] for c in text)
            if align=='1': x-=width//2
            for c in text:
                g=fonts[font][c]
                for gy in range(g['h']):
                    for gx in range(g['w']):
                        if not atlases[font].getpixel((g['x']+gx,g['y']+gy)): continue
                        px,py=x+gx,y+gy
                        if not(0<=px<176 and 0<=py<176) or mask.getpixel((px,py))>=128:
                            failures.add((font,text,xs,ys))
                x+=g['advance']
        assert not failures, f'Glyphs clipped by physical screen mask: {sorted(failures)}'
    print('PASS: registry, settings, 1-bit glyph coverage and SDK physical mask checks.')

if __name__=='__main__': main()
