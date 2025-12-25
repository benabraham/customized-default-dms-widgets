import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// SliderSetting with proper step support using Qt Controls Slider
Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property int defaultValue: 0
    property int value: defaultValue
    property int minimum: 0
    property int maximum: 100
    property int stepSize: 1
    property string unit: ""

    width: parent.width
    spacing: Theme.spacingS

    function loadValue() {
        const settings = findSettings()
        if (settings && settings.pluginService) {
            value = settings.loadValue(settingKey, defaultValue)
        }
    }

    Component.onCompleted: {
        loadValue()
    }

    onValueChanged: {
        const settings = findSettings()
        if (settings) {
            settings.saveValue(settingKey, value)
        }
    }

    function findSettings() {
        let item = parent
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) {
                return item
            }
            item = item.parent
        }
        return null
    }

    Item {
        width: parent.width
        height: labelText.height

        StyledText {
            id: labelText
            text: root.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        DankActionButton {
            buttonSize: 28
            iconName: "refresh"
            iconSize: 16
            iconColor: Theme.surfaceText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.value !== root.defaultValue
            onClicked: root.value = root.defaultValue
        }
    }

    StyledText {
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
        visible: root.description !== ""
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM

        Slider {
            id: slider
            width: parent.width - valueLabel.width - Theme.spacingM
            height: 48
            from: root.minimum
            to: root.maximum
            stepSize: root.stepSize
            value: root.value
            snapMode: Slider.SnapAlways

            onMoved: {
                root.value = Math.round(value)
            }

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 12
                radius: Theme.cornerRadius
                color: Theme.outline

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: Theme.cornerRadius
                    color: Theme.primary
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 8
                height: 24
                radius: Theme.cornerRadius
                color: Theme.primary
                border.width: 3
                border.color: Theme.surfaceContainerHighest

                scale: slider.pressed ? 1.05 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: Theme.shortDuration }
                }
            }
        }

        StyledText {
            id: valueLabel
            text: root.value + root.unit
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
        }
    }
}
