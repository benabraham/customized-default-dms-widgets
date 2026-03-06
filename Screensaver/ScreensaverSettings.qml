import QtQuick
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "screensaver"

    StyledText {
        text: "Screensaver"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Multi-stage DDC brightness dimming to protect OLED panels from burn-in. Uses hardware brightness (I2C/DDC) which is independent of gamma/night light."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "enabled"
        label: "Enable Screensaver"
        description: "Start dimming after idle timeout"
        defaultValue: true
    }

    SteppedSliderSetting {
        settingKey: "dimTimeout"
        label: "Dim After"
        description: "Minutes of idle before dimming starts"
        minimum: 1
        maximum: 10
        defaultValue: 2
        unit: "min"
    }

    SteppedSliderSetting {
        settingKey: "dimBrightness"
        label: "Dim Brightness"
        description: "Brightness level during dim stage"
        minimum: 5
        maximum: 80
        defaultValue: 50
        unit: "%"
    }

    SteppedSliderSetting {
        settingKey: "holdDuration"
        label: "Hold Dim"
        description: "How long to stay at dim brightness before fading to black"
        minimum: 1
        maximum: 10
        defaultValue: 3
        unit: "min"
    }

    SteppedSliderSetting {
        settingKey: "dpmsDelay"
        label: "DPMS After Black"
        description: "Minutes at minimum brightness before powering off monitors"
        minimum: 1
        maximum: 30
        defaultValue: 14
        unit: "min"
    }

    SteppedSliderSetting {
        settingKey: "fadeDuration"
        label: "Fade Speed"
        description: "Duration of each brightness fade transition"
        minimum: 3
        maximum: 20
        defaultValue: 10
        unit: "s"
    }

    StyledText {
        text: {
            if (!DisplayService.brightnessAvailable)
                return "No DDC devices detected";

            const ddcDevices = DisplayService.devices.filter(d => d.class === "ddc");
            if (ddcDevices.length === 0)
                return "No DDC devices found (only backlight/LED detected)";

            return "DDC device: " + ddcDevices.map(d => d.id).join(", ");
        }
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }
}
