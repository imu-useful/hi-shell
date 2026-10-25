pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Current weather and forecast from Open-Meteo (no API key).
// Location: Config weather.city, else weather.latitude/longitude, else by IP (ipinfo.io).
// The last result is cached so the bar has data right after startup.
Singleton {
    id: root

    readonly property var options: Config.options.weather
    readonly property bool enabled: options.enabled
    readonly property bool imperial: options.imperial
    readonly property string tempUnit: imperial ? "°F" : "°C"
    readonly property string windUnit: imperial ? Translation.tr("mph") : Translation.tr("m/s")

    property bool loading: false
    property string error: ""
    property real updatedAt: 0

    property string city: ""
    property real latitude: 0
    property real longitude: 0

    // { temp, feelsLike, humidity, wind, windDirection, pressure, visibility, cloudCover, code, isDay }
    property var current: null
    // [{ date, max, min, code, precipitation, sunrise, sunset }]
    property var daily: []
    // Next 24 hours: [{ time, temp, code, isDay, precipitation }]
    property var hourly: []

    readonly property bool ready: current !== null
    readonly property string icon: ready ? iconFor(current.code, current.isDay) : "cloud_off"
    readonly property string description: ready ? describe(current.code) : ""
    readonly property string temperature: ready ? `${Math.round(current.temp)}${tempUnit}` : "--"

    function refresh() {
        if (!enabled || loading)
            return;
        loading = true;
        error = "";
        locate((lat, lon, name) => {
            latitude = lat;
            longitude = lon;
            city = name;
            fetchForecast();
        });
    }

    function locate(done) {
        if (options.city.trim() !== "") {
            get(`https://geocoding-api.open-meteo.com/v1/search?count=1&name=${encodeURIComponent(options.city.trim())}`, data => {
                const r = data.results?.[0];
                if (!r)
                    return fail(Translation.tr("City “%1” not found").arg(options.city));
                done(r.latitude, r.longitude, r.name);
            });
        } else if (options.latitude !== 0 || options.longitude !== 0) {
            done(options.latitude, options.longitude, city);
        } else {
            get("https://ipinfo.io/json", data => {
                const [lat, lon] = (data.loc ?? "").split(",").map(Number);
                if (isNaN(lat) || isNaN(lon))
                    return fail(Translation.tr("Could not determine location"));
                done(lat, lon, data.city ?? "");
            });
        }
    }

    function fetchForecast() {
        const params = [
            `latitude=${latitude}`, `longitude=${longitude}`, "timezone=auto", "forecast_days=7",
            "current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility",
            "hourly=temperature_2m,weather_code,is_day,precipitation_probability",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max",
            imperial ? "temperature_unit=fahrenheit&wind_speed_unit=mph" : "wind_speed_unit=ms"
        ];
        get(`https://api.open-meteo.com/v1/forecast?${params.join("&")}`, data => {
            apply(data);
            cache.setText(JSON.stringify({ city, latitude, longitude, imperial, updatedAt, data }));
        });
    }

    function apply(data) {
        const c = data.current;
        current = {
            temp: c.temperature_2m,
            feelsLike: c.apparent_temperature,
            humidity: c.relative_humidity_2m,
            wind: c.wind_speed_10m,
            windDirection: c.wind_direction_10m,
            pressure: c.pressure_msl,
            visibility: c.visibility,
            cloudCover: c.cloud_cover,
            code: c.weather_code,
            isDay: c.is_day === 1
        };
        const d = data.daily;
        daily = d.time.map((date, i) => ({
            date,
            max: d.temperature_2m_max[i],
            min: d.temperature_2m_min[i],
            code: d.weather_code[i],
            precipitation: d.precipitation_probability_max[i],
            sunrise: d.sunrise[i],
            sunset: d.sunset[i]
        }));
        const h = data.hourly;
        // Start at the current hour (current.time is e.g. "2026-10-25T12:45").
        const now = h.time.findIndex(t => t.slice(0, 13) >= c.time.slice(0, 13));
        hourly = h.time.slice(Math.max(0, now), Math.max(0, now) + 24).map((time, i) => {
            const k = Math.max(0, now) + i;
            return { time, temp: h.temperature_2m[k], code: h.weather_code[k], isDay: h.is_day[k] === 1, precipitation: h.precipitation_probability[k] };
        });
        updatedAt = Date.now();
        loading = false;
    }

    function fail(message) {
        error = message;
        loading = false;
        console.warn("Weather:", message);
        retry.restart();
    }

    function get(url, onData) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200)
                return fail(`HTTP ${xhr.status || "error"} from ${url.split("?")[0]}`);
            try {
                onData(JSON.parse(xhr.responseText));
            } catch (e) {
                fail(`Bad response: ${e}`);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // WMO weather interpretation codes.
    function describe(code) {
        if (code === 0) return Translation.tr("Clear sky");
        if (code === 1) return Translation.tr("Mainly clear");
        if (code === 2) return Translation.tr("Partly cloudy");
        if (code === 3) return Translation.tr("Overcast");
        if (code === 45 || code === 48) return Translation.tr("Fog");
        if (code >= 51 && code <= 55) return Translation.tr("Drizzle");
        if (code === 56 || code === 57) return Translation.tr("Freezing drizzle");
        if (code === 61 || code === 80) return Translation.tr("Light rain");
        if (code === 63 || code === 81) return Translation.tr("Rain");
        if (code === 65 || code === 82) return Translation.tr("Heavy rain");
        if (code === 66 || code === 67) return Translation.tr("Freezing rain");
        if (code >= 71 && code <= 77) return Translation.tr("Snow");
        if (code === 85 || code === 86) return Translation.tr("Snow showers");
        if (code === 95) return Translation.tr("Thunderstorm");
        if (code === 96 || code === 99) return Translation.tr("Thunderstorm with hail");
        return Translation.tr("Unknown");
    }

    // Material Symbols name for a weather code.
    function iconFor(code, isDay) {
        if (code <= 1) return isDay ? "clear_day" : "clear_night";
        if (code === 2) return isDay ? "partly_cloudy_day" : "partly_cloudy_night";
        if (code === 3) return "cloud";
        if (code === 45 || code === 48) return "foggy";
        if (code >= 51 && code <= 57) return "rainy_light";
        if (code === 65 || code === 82) return "rainy_heavy";
        if (code >= 61 && code <= 82 && code !== 71 && code !== 73 && code !== 75 && code !== 77) return "rainy";
        if (code >= 71 && code <= 86) return "weather_snowy";
        if (code >= 95) return "thunderstorm";
        return "cloud";
    }

    FileView {
        id: cache
        path: Paths.cache + "/weather.json"
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (c.imperial !== root.imperial)
                    return;
                root.city = c.city;
                root.latitude = c.latitude;
                root.longitude = c.longitude;
                root.apply(c.data);
                root.updatedAt = c.updatedAt;
            } catch (e) {}
        }
    }

    Connections {
        target: root.options
        function onCityChanged() { root.refresh(); }
        function onLatitudeChanged() { root.refresh(); }
        function onLongitudeChanged() { root.refresh(); }
        function onImperialChanged() { root.refresh(); }
        function onEnabledChanged() { root.refresh(); }
    }

    Timer {
        running: root.enabled
        interval: Math.max(5, root.options.refreshMinutes) * 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: retry
        interval: 120000
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "weather"

        function refresh(): void {
            root.refresh();
        }
    }
}
