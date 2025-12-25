import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Slider with text labels instead of numeric values
Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property var options: []  // [{label: "XS", value: "XS"}, ...]
    property string defaultValue: ""

    property int currentIndex: {
        for (let i = 0; i < options.length; i++) {
            if (options[i].value === currentValue) return i
        }
        return 0
    }
    property string currentValue: defaultValue

    width: parent.width
    spacing: Theme.spacingS

    function loadValue() {
        const settings = findSettings()
        if (settings && settings.pluginService) {
            currentValue = settings.loadValue(settingKey, defaultValue)
        }
    }

    Component.onCompleted: {
        loadValue()
    }

    onCurrentValueChanged: {
        const settings = findSettings()
        if (settings) {
            settings.saveValue(settingKey, currentValue)
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
            visible: root.currentValue !== root.defaultValue
            onClicked: root.currentValue = root.defaultValue
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
            from: 0
            to: root.options.length - 1
            stepSize: 1
            value: root.currentIndex
            snapMode: Slider.SnapAlways

            onMoved: {
                root.currentValue = root.options[Math.round(value)].value
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
            text: root.options[root.currentIndex]?.label ?? ""
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
        }
    }
}
