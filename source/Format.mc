using Toybox.Math;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

module Format {
    function number(v) {
        if (v == null) { return "--"; }
        return Math.round(v).toNumber().toString();
    }
    function compact(v) {
        if (v == null) { return "--"; }
        if (v.abs() >= 1000000) { return (v / 1000000.0).format("%.1f") + "M"; }
        if (v.abs() >= 10000) { return (v / 1000.0).format("%.1f") + "k"; }
        return number(v);
    }
    function metric(id, v) {
        if (id == Metrics.NONE) { return ""; }
        if (v == null) { return "--"; }
        if (id == Metrics.SUNRISE || id == Metrics.SUNSET) { return v; }
        if (id == Metrics.DISTANCE) { return (v / 100000.0).format("%.1f") + "k"; }
        if (id == Metrics.WIND) { return v.format("%.1f"); }
        return compact(v) + Metrics.UNITS[id];
    }
    function clock(moment) {
        if (moment == null) { return "--:--"; }
        var t = Gregorian.info(moment, Time.FORMAT_SHORT);
        return t.hour.format("%02d") + ":" + t.min.format("%02d");
    }
    function fresh(now, when, age) {
        if (when == null) { return false; }
        var d = now - when.value();
        return d >= -60 && d <= age;
    }
    function windIndex(bearing) {
        if (bearing == null) { return -1; }
        return (((bearing % 360) + 360 + 22.5) / 45).toNumber() % 8;
    }
}
