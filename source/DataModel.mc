using Toybox.ActivityMonitor;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Weather;
using Toybox.Math;
using Toybox.Lang;

class DataModel {
    var values as Lang.Array;
    var texts as Lang.Array;
    var temperature = "--°";
    var wind = "--";
    var direction = -1;
    var weatherGlyph = Icons.UNKNOWN;
    var sunrise = "--:--";
    var sunset = "--:--";
    var dateText = "";
    var connected = false;
    var alarms = false;
    var dnd = false;
    var notifications = 0;
    var stepRatio = 0;
    var lastData = -1;
    var lastWeather = -1;
    var lastStatus = -1;
    var lastDay = -1;
    var weatherData;
    var sunKey = "";
    var riseMoment;
    var setMoment;
    var sampleReads = 0;
    var weatherReads = 0;
    const DAYS = ["日", "一", "二", "三", "四", "五", "六"];
    // Blood-oxygen freshness: 3 minutes normally, 1 minute during vigorous
    // exercise (heart rate >= VIGOROUS_HR in the last VIGOROUS_HR_AGE seconds).
    const OXYGEN_AGE = 180;
    const OXYGEN_AGE_VIGOROUS = 60;
    const VIGOROUS_HR = 120;
    const VIGOROUS_HR_AGE = 120;

    function initialize() {
        values = new[Metrics.COUNT]; texts = new[Metrics.COUNT];
        for (var i=0; i<Metrics.COUNT; i+=1) { texts[i] = "--"; }
    }
    function invalidate() { lastData=-1; lastWeather=-1; lastStatus=-1; lastDay=-1; sunKey=""; }
    function due(now, last, period) { return last < 0 || now < last || now-last >= period; }
    function latest(iterator, now, maxAge) {
        // Never scan history; at most one cached sample per selected sensor.
        sampleReads += 1;
        if (iterator == null) { return null; }
        var sample = iterator.next();
        if (sample == null || !Format.fresh(now, sample.when, maxAge)) { return null; }
        return sample.data;
    }
    function oxygenAge(hr) {
        return hr != null && hr >= VIGOROUS_HR ? OXYGEN_AGE_VIGOROUS : OXYGEN_AGE;
    }
    (:live)
    function refresh(config, now) { return refreshLive(config, now); }
    (:fixture)
    function refresh(config, now) { return refreshFixture(config, now); }

    function refreshLive(config as Config, now) {
        var changed = false;
        var local = Gregorian.info(new Time.Moment(now), Time.FORMAT_SHORT);
        var day = local.year*10000 + local.month*100 + local.day;
        if (day != lastDay) {
            lastDay = day; lastData = -1;
            dateText = "周" + DAYS[local.day_of_week-1] + " " + local.month.format("%02d") + "月" + local.day.format("%02d") + "日";
            changed = true;
        }
        if (due(now, lastStatus, 60)) {
            lastStatus = now;
            var s = System.getDeviceSettings();
            connected = s.phoneConnected; alarms = s.alarmCount > 0;
            notifications = s.notificationCount;
            dnd = s has :doNotDisturb && s.doNotDisturb;
            values[Metrics.NOTIFICATIONS] = notifications;
            values[Metrics.BATTERY] = System.getSystemStats().battery;
            changed = true;
        }
        if (due(now, lastWeather, config.weatherInterval)) {
            lastWeather=now; weatherReads+=1;
            weatherData=Weather.getCurrentConditions();
            changed=true;
        }
        // Check expiration even between weather reads; never leave an old sunny icon up indefinitely.
        var valid = weatherData != null && Format.fresh(now, weatherData.observationTime, 7200);
        var oldGlyph = weatherGlyph;
        if (valid) {
            values[Metrics.TEMPERATURE] = weatherData.temperature;
            values[Metrics.HUMIDITY] = weatherData.relativeHumidity;
            values[Metrics.RAIN] = weatherData.precipitationChance;
            values[Metrics.WIND] = weatherData.windSpeed;
            direction = Format.windIndex(weatherData.windBearing);
            var location = weatherData.observationLocationPosition;
            if (location != null) {
                var degrees = location.toDegrees() as Lang.Array;
                // ~1 km location buckets; recompute when date, timezone, or location changes.
                var key = day + ":" + (degrees[0]*100).toNumber() + ":" + (degrees[1]*100).toNumber() + ":" + System.getClockTime().timeZoneOffset;
                if (!key.equals(sunKey)) {
                    sunKey=key;
                    riseMoment=Weather.getSunrise(location,new Time.Moment(now));
                    setMoment=Weather.getSunset(location,new Time.Moment(now));
                    sunrise=Format.clock(riseMoment); sunset=Format.clock(setMoment);
                    changed=true;
                }
            } else { clearSun(); }
            var night = riseMoment != null && setMoment != null && (now < riseMoment.value() || now >= setMoment.value());
            weatherGlyph=WeatherIcons.glyph(weatherData.condition,night);
        } else {
            if (values[Metrics.TEMPERATURE] != null || direction != -1) { changed=true; }
            values[Metrics.TEMPERATURE]=null; values[Metrics.HUMIDITY]=null;
            values[Metrics.RAIN]=null; values[Metrics.WIND]=null;
            weatherGlyph=Icons.UNKNOWN; direction=-1; clearSun();
        }
        if (!oldGlyph.equals(weatherGlyph)) { changed=true; }
        values[Metrics.SUNRISE]=sunrise; values[Metrics.SUNSET]=sunset;
        if (due(now,lastData,config.interval)) {
            lastData=now; changed=true;
            var need=config.needed;
            if (need[Metrics.STEPS] || need[Metrics.CALORIES] || need[Metrics.DISTANCE] || need[Metrics.ACTIVE]) {
                var a=ActivityMonitor.getInfo();
                values[Metrics.STEPS]=a.steps; values[Metrics.CALORIES]=a.calories;
                values[Metrics.DISTANCE]=a.distance;
                values[Metrics.ACTIVE]=a.activeMinutesDay == null ? null : a.activeMinutesDay.total;
                stepRatio=0;
                if (a.steps != null && a.stepGoal != null && a.stepGoal>0) { stepRatio=a.steps >= a.stepGoal ? 1.0 : a.steps.toFloat()/a.stepGoal; }
            }
            var options={:period=>1, :order=>SensorHistory.ORDER_NEWEST_FIRST};
            if (need[Metrics.HEART]) { values[Metrics.HEART]=latest(SensorHistory.getHeartRateHistory(options),now,300); }
            if (need[Metrics.BODY]) { values[Metrics.BODY]=latest(SensorHistory.getBodyBatteryHistory(options),now,900); }
            if (need[Metrics.ALTITUDE]) { values[Metrics.ALTITUDE]=latest(SensorHistory.getElevationHistory(options),now,900); }
            if (need[Metrics.PRESSURE]) {
                var pa=latest(SensorHistory.getPressureHistory(options),now,900);
                values[Metrics.PRESSURE]=pa == null ? null : pa/100.0;
            }
            if (need[Metrics.STRESS]) {
                var stress=latest(SensorHistory.getStressHistory(options),now,900);
                values[Metrics.STRESS]=stress != null && stress >= 0 ? stress : null;
            }
            if (need[Metrics.OXYGEN]) {
                var hr=latest(SensorHistory.getHeartRateHistory(options),now,VIGOROUS_HR_AGE);
                values[Metrics.OXYGEN]=latest(SensorHistory.getOxygenSaturationHistory(options),now,oxygenAge(hr));
            }
        }
        if (changed) { formatValues(); }
        return changed;
    }
    function clearSun() { sunrise="--:--"; sunset="--:--"; riseMoment=null; setMoment=null; sunKey=""; }
    function formatValues() {
        for(var i=0;i<Metrics.COUNT;i+=1) { texts[i]=Format.metric(i,values[i]); }
        temperature=Format.number(values[Metrics.TEMPERATURE])+"°";
        wind=values[Metrics.WIND] == null ? "--" : values[Metrics.WIND].format("%.0f");
    }
    (:fixture)
    function refreshFixture(config, now) {
        if (lastData >= 0) { return false; }
        lastData=now;
        values=[null,8432,76,128,1013,1246,82,68,523000,24,98,24,65,20,3.0,2,38,"06:12","18:24"];
        dateText="周三 09月16日"; sunrise="06:12"; sunset="18:24";
        connected=true; alarms=true; notifications=2; direction=1;
        weatherGlyph=Icons.CLOUD; stepRatio=0.8432; formatValues(); return true;
    }
}
