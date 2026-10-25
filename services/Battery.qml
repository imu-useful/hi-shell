pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.common

// Laptop battery (UPower display device) with low / critical warnings.
Singleton {
    id: root

    readonly property var options: Config.options.battery
    readonly property UPowerDevice device: UPower.displayDevice

    readonly property bool available: device !== null && device.isLaptopBattery
    readonly property real percentage: available ? device.percentage : 0 // 0..1
    readonly property int percent: Math.round(percentage * 100)
    readonly property bool charging: available && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: available && device.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property bool low: available && !charging && percent <= options.low
    readonly property bool critical: available && !charging && percent <= options.critical
    readonly property real watts: available ? Math.abs(device.changeRate) : 0
    readonly property real health: available && device.healthSupported ? device.healthPercentage : -1

    // Seconds until empty (discharging) / full (charging); 0 if unknown.
    readonly property real timeLeft: !available ? 0 : charging ? device.timeToFull : device.timeToEmpty
    readonly property string timeLeftText: timeLeft > 0 ? formatDuration(timeLeft) : ""

    readonly property string icon: {
        if (!available)
            return "battery_unknown";
        if (charging || full)
            return "battery_charging_full";
        const bars = Math.min(6, Math.floor(percentage * 7));
        return bars >= 6 ? "battery_full" : `battery_${bars}_bar`;
    }

    function formatDuration(seconds) {
        const h = Math.floor(seconds / 3600), m = Math.round(seconds % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    function warn(urgency, title) {
        if (options.warnings)
            Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-u", urgency, "-i", "battery-caution", title, `${percent}% remaining${timeLeftText ? ", " + timeLeftText : ""}`]);
    }

    onLowChanged: if (low && !critical) warn("normal", "Battery low")
    onCriticalChanged: if (critical) warn("critical", "Battery critical")
}
