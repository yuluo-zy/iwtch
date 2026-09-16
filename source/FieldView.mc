using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Time;
using Toybox.Math;

class FieldView extends WatchUi.WatchFace {
    var config as Config;
    var model as DataModel;
    var iconFont; var smallIconFont; var tinyFont; var dataFont; var timeFont; var bubbleFont; var dateFont;
    var fg; var bg;
    var sleeping=true;
    var partialAllowed=true;
    var dirty=true;
    var lastMinute=-1;
    var lastSecond=-1;
    var lastPoll=-1;
    var fullDraws=0;
    var secondDraws=0;

    function initialize() { WatchFace.initialize(); config=new Config(); model=new DataModel(); }
    function onLayout(dc) {
        iconFont=WatchUi.loadResource(Rez.Fonts.Icons);
        smallIconFont=WatchUi.loadResource(Rez.Fonts.Iconssmall);
        tinyFont=WatchUi.loadResource(Rez.Fonts.Tiny);
        dataFont=WatchUi.loadResource(Rez.Fonts.Data);
        timeFont=WatchUi.loadResource(Rez.Fonts.Time);
        bubbleFont=WatchUi.loadResource(Rez.Fonts.Bubble);
        dateFont=WatchUi.loadResource(Rez.Fonts.Date);
        dirty=true;
    }
    function settingsChanged() { config.reload(); model.invalidate(); lastPoll=-1; dirty=true; }
    function onShow() { dirty=true; }
    function onExitSleep() { sleeping=false; dirty=true; WatchUi.requestUpdate(); }
    function onEnterSleep() { sleeping=true; dirty=true; WatchUi.requestUpdate(); }
    function secondsVisible() { return config.secondsMode==2 && partialAllowed || config.secondsMode==1 && !sleeping; }
    (:live)
    function clock() { return System.getClockTime(); }
    (:fixture)
    function clock() { return new FixtureClock(); }
    function onUpdate(dc) {
        var begin=beginMeasurement();
        var now=Time.now().value();
        var changed=false;
        // Awake callbacks can arrive every second. Data processing stays on the minute path.
        var pollMinute=now/60;
        if(dirty || lastPoll!=pollMinute) { changed=model.refresh(config,now); lastPoll=pollMinute; }
        var c=clock();
        var hour=c.hour;
        var minute=c.min;
        var second=c.sec;
        var minuteKey=hour*60+minute;
        if (dirty || changed || minuteKey!=lastMinute) {
            fg=config.light ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
            bg=config.light ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            dc.clearClip(); dc.setColor(fg,bg); dc.clear();
            drawFace(dc,hour,minute);
            dirty=false; lastMinute=minuteKey; lastSecond=-1; fullDraws+=1;
        }
        if (secondsVisible() && lastSecond!=second) { drawSeconds(dc,second); }
        endMeasurement(begin);
    }
    (:quiet)
    function beginMeasurement() { return 0; }
    (:quiet)
    function endMeasurement(begin) {}
    (:diagnostic)
    function beginMeasurement() { return System.getTimer(); }
    (:diagnostic)
    function endMeasurement(begin) {
        var stats=System.getSystemStats();
        System.println("PERF used="+stats.usedMemory+" free="+stats.freeMemory+" total="+stats.totalMemory+" updateMs="+(System.getTimer()-begin)+" full="+fullDraws+" seconds="+secondDraws+" sensorReads="+model.sampleReads+" weatherReads="+model.weatherReads);
    }
    function onPartialUpdate(dc) {
        // Strict power-budget path: no properties, history, weather, allocation of buffers,
        // layout, or full-screen drawing. Just a 24 x 9 pixel seconds rectangle.
        if (config.secondsMode!=2 || !partialAllowed || dirty) { return; }
        drawSeconds(dc,System.getClockTime().sec);
    }
    function drawSeconds(dc,second) {
        dc.setClip(140,105,24,9); dc.setColor(bg,bg); dc.fillRectangle(140,105,24,9);
        dc.setColor(fg,bg); dc.drawText(140,105,tinyFont,second.format("%02d"),Graphics.TEXT_JUSTIFY_LEFT);
        dc.clearClip(); lastSecond=second; secondDraws+=1;
    }
    function icon(dc,x,y,glyph) { dc.drawText(x,y,iconFont,glyph,Graphics.TEXT_JUSTIFY_LEFT); }
    function text(dc,x,y,font,value) { dc.drawText(x,y,font,value,Graphics.TEXT_JUSTIFY_LEFT); }
    function fit(dc,x,y,maxWidth,value,preferred) {
        var font=preferred;
        if(dc.getTextWidthInPixels(value,font)>maxWidth) { font=tinyFont; }
        if(dc.getTextWidthInPixels(value,font)>maxWidth) { value="--"; }
        text(dc,x,y,font,value);
    }
    function drawFace(dc,hour,minute) {
        // Main upper area ends at x=112. Fixed subwindow is x=113..174, y=0..61.
        icon(dc,30,7,model.weatherGlyph); fit(dc,46,7,35,model.temperature,dataFont);
        icon(dc,83,5,model.direction<0 ? Icons.UNKNOWN : Icons.DIRECTIONS[model.direction]);
        fit(dc,70,21,31,model.wind+"m/s",tinyFont);
        icon(dc,8,33,Icons.SUNRISE); text(dc,22,35,tinyFont,model.sunrise);
        icon(dc,58,33,Icons.SUNSET); text(dc,72,35,tinyFont,model.sunset);
        fit(dc,9,50,108,model.dateText,dateFont);
        dc.drawLine(9,66,121,66);
        // A sparse outline, not an animated or semantically misleading gauge.
        dc.drawCircle(144,30,27);
        icon(dc,138,9,Metrics.ICONS[config.bubble]);
        var bubbleText=model.texts[config.bubble];
        var font=bubbleFont;
        if(dc.getTextWidthInPixels(bubbleText,font)>48) { font=dataFont; }
        if(dc.getTextWidthInPixels(bubbleText,font)>48) { font=tinyFont; }
        dc.drawText(144,29,font,bubbleText,Graphics.TEXT_JUSTIFY_CENTER);
        text(dc,9,73,timeFont,hour.format("%02d")+":"+minute.format("%02d"));
        if(model.connected) { icon(dc,137,79,Icons.BLUETOOTH); icon(dc,137,92,Icons.PHONE); }
        if(model.alarms) { icon(dc,152,79,Icons.ALARM); }
        if(model.notifications>0) {
            icon(dc,152,92,Icons.MESSAGE);
            text(dc,166,94,tinyFont,model.notifications>9 ? "+" : model.notifications.toString());
        }
        else if(model.dnd) { icon(dc,152,92,Icons.MOON); }
        dc.drawLine(9,116,166,116);
        drawSlots(dc);
    }
    function drawSlots(dc) {
        var rowHeight=config.count==8 ? 12 : config.count==4 ? 22 : 16;
        var start=config.count==4 ? 122 : 120;
        dc.drawLine(87,120,87,163);
        for(var i=0;i<config.count;i+=1) {
            var id=config.slots[i]; if(id==Metrics.NONE) { continue; }
            var row=i/2; var col=i%2;
            var y=start+row*rowHeight;
            // Bottom clipped corners narrow the final row's safe horizontal region.
            var x=col==0 ? (y>=156 ? 32 : y>=144 ? 25 : 12) : 95;
            text(dc,x,y,config.count==8 ? smallIconFont : iconFont,Metrics.ICONS[id]);
            var font=config.count==8 ? tinyFont : dataFont;
            var maxWidth=col==0 ? 85-(x+15) : (y>=150 ? 151 : 167)-(x+15);
            fit(dc,x+15,y,maxWidth,model.texts[id],font);
            if(config.progress && id==Metrics.STEPS && config.count!=8) {
                var barY=y+(config.count==4 ? 15 : 13);
                dc.drawRectangle(x+15,barY,maxWidth,2);
                dc.fillRectangle(x+15,barY,(maxWidth*model.stepRatio).toNumber(),2);
            }
        }
    }
}

(:fixture)
class FixtureClock {
    var hour=10;
    var min=48;
    var sec=32;
    function initialize() {}
}
