import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Settings from pluginData (persisted via PluginSettings)
    readonly property bool screensaverEnabled: pluginData.enabled !== undefined ? pluginData.enabled : true
    readonly property int dimTimeoutMin: pluginData.dimTimeout || 2
    readonly property int dimBrightness: pluginData.dimBrightness || 50
    readonly property int holdDurationMin: pluginData.holdDuration || 3
    readonly property int dpmsDelayMin: pluginData.dpmsDelay || 14
    readonly property int fadeDurationSec: pluginData.fadeDuration || 10
    readonly property string configuredDevice: pluginData.ddcDevice || ""

    // State machine: active -> dimming -> holding -> blacking -> black -> dpms
    property string state: "active"
    property int savedBrightness: -1
    property string ddcDevice: ""
    property real fadeStartTime: 0
    property int fadeFromBrightness: 0
    property int fadeToBrightness: 0

    function findDdcDevice() {
        if (!DisplayService.devices || DisplayService.devices.length === 0)
            return "";

        // Use configured device if valid
        if (configuredDevice) {
            const found = DisplayService.devices.find(d => d.id === configuredDevice);
            if (found)
                return configuredDevice;
        }

        // Auto-detect: prefer DDC devices
        const ddc = DisplayService.devices.find(d => d.class === "ddc");
        return ddc ? ddc.id : "";
    }

    // Refresh DDC device when devices list changes
    onConfiguredDeviceChanged: ddcDevice = findDdcDevice()

    Connections {
        target: DisplayService
        function onDevicesChanged() {
            root.ddcDevice = root.findDdcDevice();
        }
    }

    // Idle monitor for dim detection
    IdleMonitor {
        id: idleMonitor
        enabled: root.screensaverEnabled && root.ddcDevice !== ""
        timeout: root.dimTimeoutMin * 60
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                root.startScreensaver();
            } else {
                root.stopScreensaver();
            }
        }
    }

    function startScreensaver() {
        if (state !== "active")
            return;

        savedBrightness = DisplayService.getDeviceBrightness(ddcDevice);
        if (savedBrightness <= 0)
            savedBrightness = 25;

        // Don't dim if already at or below target
        if (savedBrightness <= dimBrightness) {
            console.info("Screensaver: Already at or below dim level, skipping to hold");
            state = "holding";
            stageTimer.interval = holdDurationMin * 60 * 1000;
            stageTimer.start();
            return;
        }

        console.info("Screensaver: Dimming from " + savedBrightness + "% to " + dimBrightness + "%");
        startFade(savedBrightness, dimBrightness, "dimming");
    }

    function stopScreensaver() {
        if (state === "active")
            return;

        const wasState = state;
        fadeTimer.stop();
        stageTimer.stop();

        if (wasState === "dpms")
            CompositorService.powerOnMonitors();

        if (savedBrightness > 0 && ddcDevice) {
            console.info("Screensaver: Restoring brightness to " + savedBrightness + "%");
            DisplayService.setBrightness(savedBrightness, ddcDevice, true);
        }

        state = "active";
        savedBrightness = -1;
    }

    function startFade(from, to, newState) {
        fadeFromBrightness = from;
        fadeToBrightness = to;
        fadeStartTime = Date.now();
        state = newState;
        fadeTimer.start();
    }

    // Fade timer - updates DDC brightness every 400ms (~2.5 FPS, within DDC limits)
    Timer {
        id: fadeTimer
        interval: 400
        repeat: true

        onTriggered: {
            const elapsed = (Date.now() - root.fadeStartTime) / 1000;
            const duration = root.fadeDurationSec;
            const t = Math.min(1.0, elapsed / duration);

            // Ease out cubic for smooth deceleration
            const eased = 1 - Math.pow(1 - t, 3);

            const brightness = Math.round(
                root.fadeFromBrightness + (root.fadeToBrightness - root.fadeFromBrightness) * eased
            );

            // DDC minimum is 1 (VCP value 1, not true 0)
            DisplayService.setBrightness(Math.max(1, brightness), root.ddcDevice, true);

            if (t >= 1.0) {
                fadeTimer.stop();
                root.handleFadeComplete();
            }
        }
    }

    function handleFadeComplete() {
        if (state === "dimming") {
            state = "holding";
            stageTimer.interval = holdDurationMin * 60 * 1000;
            stageTimer.start();
            console.info("Screensaver: Holding at " + dimBrightness + "% for " + holdDurationMin + " min");
        } else if (state === "blacking") {
            state = "black";
            stageTimer.interval = dpmsDelayMin * 60 * 1000;
            stageTimer.start();
            console.info("Screensaver: At minimum brightness, DPMS in " + dpmsDelayMin + " min");
        }
    }

    // Stage transition timer (hold -> blacking, black -> dpms)
    Timer {
        id: stageTimer
        repeat: false

        onTriggered: {
            if (root.state === "holding") {
                console.info("Screensaver: Fading to black");
                root.startFade(root.dimBrightness, 1, "blacking");
            } else if (root.state === "black") {
                console.info("Screensaver: Powering off monitors (DPMS)");
                root.state = "dpms";
                CompositorService.powerOffMonitors();
            }
        }
    }

    Component.onCompleted: {
        ddcDevice = findDdcDevice();
        if (ddcDevice)
            console.info("Screensaver: Started with DDC device: " + ddcDevice);
        else
            console.warn("Screensaver: No DDC device found, will activate when available");
    }

    Component.onDestruction: {
        if (state !== "active")
            stopScreensaver();
        console.info("Screensaver: Stopped");
    }
}
