import QtQuick

// Wheel / touchpad scrolling turned into whole steps: one mouse-wheel notch is one
// step, and a touchpad swipe gives a step every `touchpadDistance` px instead of one
// per event (which would race through values). Up and right are positive.
WheelHandler {
    id: root

    property real touchpadDistance: 30
    property real accumulated: 0

    signal stepped(int steps)

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: event => {
        // Angle units: 120 per wheel notch, ~8 per pixel of touchpad movement. Mice also
        // report pixel deltas on Wayland, so tell them apart by the device and by whole
        // notches (multiples of 120), not by pixelDelta.
        const delta = event.angleDelta.y || -event.angleDelta.x;
        const notch = delta % 120 === 0 || event.device.type === PointerDevice.Mouse;
        const unit = notch ? 120 : touchpadDistance * 8;
        accumulated += delta;
        const steps = accumulated > 0 ? Math.floor(accumulated / unit) : Math.ceil(accumulated / unit);
        if (steps !== 0) {
            accumulated -= steps * unit;
            root.stepped(steps);
        }
    }
}
