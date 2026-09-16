using Toybox.Application;
using Toybox.Lang;

class Config {
    var light;
    var count;
    var slots as Lang.Array = [];
    var bubble;
    var secondsMode;
    var interval;
    var weatherInterval;
    var progress;
    var needed as Lang.Array = [];
    function initialize() { reload(); }
    function readInt(key, fallback, low, high) {
        var v = Application.Properties.getValue(key);
        return validate(v, fallback, low, high);
    }
    function validate(v, fallback, low, high) {
        if (!(v instanceof Lang.Number) || v < low || v > high) { return fallback; }
        return v;
    }
    function reload() {
        light = readInt("theme", 0, 0, 1) == 1;
        count = readInt("slotCount", 6, 4, 8);
        if (count != 4 && count != 6 && count != 8) { count = 6; }
        bubble = readInt("bubble", Metrics.HEART, 1, Metrics.COUNT - 1);
        secondsMode = readInt("seconds", 1, 0, 2);
        interval = readInt("dataInterval", 60, 60, 300);
        weatherInterval = readInt("weatherInterval", 15, 5, 60) * 60;
        progress = readInt("progress", 1, 0, 1) == 1;
        slots = new[8];
        needed = new[Metrics.COUNT];
        for (var k = 0; k < Metrics.COUNT; k += 1) { needed[k] = false; }
        var defaults = [1, 2, 3, 4, 5, 6, 9, 8];
        for (var i = 0; i < 8; i += 1) {
            slots[i] = readInt("slot" + (i + 1), defaults[i], 0, Metrics.COUNT - 1);
            if (i < count) { needed[slots[i]] = true; }
        }
        needed[bubble] = true;
    }
}
