using Toybox.Test;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;
using Toybox.Lang;

(:test)
function formattingAndWeather(logger) {
    Test.assertEqual(Format.metric(Metrics.BODY,null),"--");
    Test.assertEqual(Format.metric(Metrics.PRESSURE,1013.25),"1013");
    Test.assertEqual(Format.metric(Metrics.DISTANCE,523000),"5.2k");
    Test.assertEqual(Format.metric(Metrics.STEPS,13486),"13.5k");
    Test.assertEqual(Format.metric(Metrics.STRESS,0),"0");
    Test.assertEqual(Format.windIndex(0),0);
    Test.assertEqual(Format.windIndex(45),1);
    Test.assertEqual(Format.windIndex(359),0);
    Test.assertEqual(Format.windIndex(-45),7);
    Test.assertEqual(Format.windIndex(null),-1);
    Test.assertEqual(WeatherIcons.MAP.size(),54);
    for(var i=0;i<54;i+=1) { Test.assert(WeatherIcons.glyph(i,false)!=null); }
    Test.assertEqual(WeatherIcons.glyph(0,true),Icons.MOON);
    Test.assertEqual(WeatherIcons.glyph(999,false),Icons.UNKNOWN);
    Test.assertEqual(WeatherIcons.glyph(null,false),Icons.UNKNOWN);
    Test.assert(!Format.fresh(10000,new Time.Moment(100),300));
    Test.assert(Format.fresh(10000,new Time.Moment(9999),300));
    Test.assert(!Format.fresh(10000,new Time.Moment(11000),300));
    return true;
}

(:test)
function settingsAndDemand(logger) {
    var c=new Config();
    Test.assertEqual(c.validate("8",6,4,8),6);
    Test.assertEqual(c.validate(99,6,4,8),6);
    Test.assertEqual(c.validate(null,6,4,8),6);
    Application.Properties.setValue("slotCount",8);
    Application.Properties.setValue("slot8",Metrics.OXYGEN);
    c.reload(); Test.assertEqual(c.count,8); Test.assert(c.needed[Metrics.OXYGEN]);
    Application.Properties.setValue("slotCount",4); c.reload();
    Test.assert(!c.needed[Metrics.OXYGEN]);
    Application.Properties.setValue("slotCount",6);
    Application.Properties.setValue("slot8",Metrics.DISTANCE);
    c.reload();
    return true;
}

(:test)
function sensorScheduling(logger) {
    var c=new Config(); var m=new DataModel();
    for(var i=0;i<Metrics.COUNT;i+=1) { c.needed[i]=false; }
    var now=Time.now().value();
    m.refreshLive(c,now);
    Test.assertEqual(m.sampleReads,0);
    Test.assertEqual(m.weatherReads,1);
    Test.assert(!m.refreshLive(c,now+1));
    Test.assertEqual(m.weatherReads,1);
    c.needed[Metrics.BODY]=true; c.needed[Metrics.PRESSURE]=true;
    m.refreshLive(c,now+60);
    Test.assertEqual(m.sampleReads,2);
    m.refreshLive(c,now+61); Test.assertEqual(m.sampleReads,2);
    m.refreshLive(c,now-3600); Test.assertEqual(m.weatherReads,2);
    Test.assert(m.due(100,200,60));
    return true;
}

(:test)
class CaptureDc {
    var dc;
    var fonts as Lang.Array;
    var names as Lang.Array;
    function initialize(realDc,v) {
        dc=realDc; fonts=[v.iconFont,v.tinyFont,v.dataFont,v.timeFont,v.bubbleFont,v.dateFont,v.smallIconFont];
        names=["icons","tiny","data","time","bubble","date","iconssmall"];
    }
    function emit(s) { System.println("DRAW|"+s); }
    function getTextWidthInPixels(t,f) { return dc.getTextWidthInPixels(t,f); }
    function drawText(x,y,font,value,align) {
        var name="";
        for(var i=0;i<fonts.size();i+=1) { if(font==fonts[i]) { name=names[i]; } }
        Test.assert(name!="");
        var w=dc.getTextWidthInPixels(value,font);
        // Tests catch missing glyphs and right-column overflow before hardware installation.
        Test.assert(w>0);
        var codes=""; var chars=value.toCharArray() as Lang.Array;
        for(var j=0;j<chars.size();j+=1) { codes+=chars[j].toNumber()+","; }
        emit("text|"+x+"|"+y+"|"+name+"|"+codes+"|"+align+"|"+w);
        dc.drawText(x,y,font,value,align);
    }
    function drawLine(a,b,c,d) { emit("line|"+a+"|"+b+"|"+c+"|"+d); dc.drawLine(a,b,c,d); }
    function drawCircle(a,b,c) { emit("circle|"+a+"|"+b+"|"+c); dc.drawCircle(a,b,c); }
    function drawRectangle(a,b,c,d) { emit("rect|"+a+"|"+b+"|"+c+"|"+d); dc.drawRectangle(a,b,c,d); }
    function fillRectangle(a,b,c,d) { emit("fill|"+a+"|"+b+"|"+c+"|"+d); dc.fillRectangle(a,b,c,d); }
    function setClip(a,b,c,d) { emit("clip|"+a+"|"+b+"|"+c+"|"+d); dc.setClip(a,b,c,d); }
    function clearClip() { emit("unclip"); dc.clearClip(); }
    function setColor(a,b) { emit("color|"+a+"|"+b); dc.setColor(a,b); }
}

(:test)
function renderAllLayouts(logger) {
    var bitmap=Graphics.createBufferedBitmap({:width=>176,:height=>176,:palette=>[Graphics.COLOR_BLACK,Graphics.COLOR_WHITE]});
    var realDc=bitmap.get().getDc();
    var v=new FieldView(); v.onLayout(realDc);
    v.model.values=[null,8432,76,128,1013,1246,82,68,523000,24,98,24,65,20,3.0,2,38,"06:12","18:24"];
    v.model.formatValues(); v.model.dateText="周三 09月16日";
    v.model.sunrise="06:12"; v.model.sunset="18:24";
    v.model.connected=true; v.model.alarms=true; v.model.notifications=2;
    v.model.direction=1; v.model.weatherGlyph=Icons.CLOUD; v.model.stepRatio=0.8432;
    var capture=new CaptureDc(realDc,v);
    Test.assert(realDc.getTextWidthInPixels(v.model.dateText,v.dateFont)<=108);
    Test.assert(realDc.getTextWidthInPixels("23:59",v.timeFont)<=127);
    for(var theme=0;theme<2;theme+=1) {
        for(var count=4;count<=8;count+=2) {
            v.config.light=theme==1; v.config.count=count;
            v.fg=theme==1 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
            v.bg=theme==1 ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            realDc.setColor(v.fg,v.bg); realDc.clear();
            System.println("FRAME|"+theme+"|"+count);
            capture.setColor(v.fg,v.bg); v.drawFace(capture,10,48); v.drawSeconds(capture,32);
            System.println("END_FRAME");
        }
    }
    // Maximum-length values and every selectable metric in compact mode.
    for(var id=1;id<Metrics.COUNT;id+=1) {
        v.config.slots[0]=id; v.model.values[id]=id==Metrics.SUNRISE || id==Metrics.SUNSET ? "23:59" : 999999;
        v.model.formatValues(); v.drawSlots(realDc);
    }
    var mem=System.getSystemStats();
    logger.debug("TEST memory used="+mem.usedMemory+" free="+mem.freeMemory);
    return true;
}

(:test)
function deviceSettingsMenu(logger) {
    var menu=new SettingsMenu();
    Test.assertEqual(SettingsCatalog.KEYS.size(),15);
    for(var i=0;i<SettingsCatalog.KEYS.size();i+=1) {
        Test.assert(menu.getItem(i)!=null);
        var options=SettingsCatalog.choices(i) as Lang.Array<Lang.Array>;
        Test.assert(options.size()>0);
        for(var j=0;j<options.size();j+=1) { Test.assert(WatchUi.loadResource(options[j][1])!=null); }
    }
    return true;
}

(:test)
function secondsAndRedrawBudget(logger) {
    var bitmap=Graphics.createBufferedBitmap({:width=>176,:height=>176,:palette=>[Graphics.COLOR_BLACK,Graphics.COLOR_WHITE]});
    var dc=bitmap.get().getDc(); var v=new FieldView(); v.onLayout(dc);
    v.config.secondsMode=0; v.onUpdate(dc);
    var reads=v.model.sampleReads; var weather=v.model.weatherReads;
    Test.assertEqual(v.fullDraws,1); Test.assertEqual(v.secondDraws,0);
    v.onUpdate(dc); Test.assertEqual(v.fullDraws,1);
    v.config.secondsMode=2; v.onPartialUpdate(dc);
    Test.assertEqual(v.secondDraws,1);
    Test.assertEqual(v.model.sampleReads,reads); Test.assertEqual(v.model.weatherReads,weather);
    v.partialAllowed=false; v.onPartialUpdate(dc); Test.assertEqual(v.secondDraws,1);
    v.config.secondsMode=1; v.sleeping=true; Test.assert(!v.secondsVisible());
    v.sleeping=false; Test.assert(v.secondsVisible());
    return true;
}
