module WeatherIcons {
    // Garmin Weather.CONDITION_* 0..53. All official conditions have a mapping.
    const MAP = [Icons.SUN, Icons.PARTLY, Icons.CLOUD, Icons.RAIN, Icons.SNOW,
        Icons.WIND, Icons.STORM, Icons.SLEET, Icons.FOG, Icons.FOG, Icons.HAIL,
        Icons.RAIN, Icons.STORM, Icons.UNKNOWN, Icons.RAIN, Icons.RAIN,
        Icons.SNOW, Icons.SNOW, Icons.SLEET, Icons.SLEET, Icons.CLOUD,
        Icons.SLEET, Icons.PARTLY, Icons.PARTLY, Icons.RAIN, Icons.RAIN,
        Icons.RAIN, Icons.RAIN, Icons.STORM, Icons.FOG, Icons.FOG,
        Icons.RAIN, Icons.WIND, Icons.FOG, Icons.HAIL, Icons.FOG,
        Icons.WIND, Icons.WIND, Icons.FOG, Icons.FOG, Icons.SUN,
        Icons.STORM, Icons.STORM, Icons.SNOW, Icons.SLEET, Icons.RAIN,
        Icons.SNOW, Icons.SLEET, Icons.SNOW, Icons.SLEET, Icons.SLEET,
        Icons.SLEET, Icons.PARTLY, Icons.UNKNOWN];
    function glyph(condition, night) {
        if (condition == null || condition < 0 || condition >= MAP.size()) { return Icons.UNKNOWN; }
        if (night && (condition == 0 || condition == 40 || condition == 22 || condition == 23)) { return Icons.MOON; }
        return MAP[condition];
    }
}
