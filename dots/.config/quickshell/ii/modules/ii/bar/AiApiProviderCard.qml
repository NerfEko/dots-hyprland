import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    required property string name
    required property string iconName
    required property real percentage
    required property bool loaded
    required property bool error

    // Optional provider-specific rows: list of {icon, label, value} objects
    property var rows: []
    property bool inverted: false

    spacing: 10

    function usageColor(pct) {
        const p = root.inverted ? (1 - pct) : pct
        return Qt.hsla((1 - p) / 3, 0.68, 0.52, 1.0)
    }

    // Header: provider name + colored accent dot
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: root.error
                ? Appearance.colors.colError
                : !root.loaded
                    ? Appearance.colors.colOutlineVariant
                    : root.usageColor(root.percentage)

            Behavior on color {
                ColorAnimation { duration: 800; easing.type: Easing.OutCubic }
            }
        }

        StyledText {
            text: root.name
            font {
                weight: Font.DemiBold
                pixelSize: Appearance.font.pixelSize.normal
            }
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    // Large animated arc
    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 64
        implicitHeight: 64

        // Error state
        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.error
            text: "error"
            iconSize: 32
            color: Appearance.colors.colError
        }

        // Loading pulse
        SequentialAnimation {
            running: !root.loaded && !root.error
            loops: Animation.Infinite

            NumberAnimation {
                target: loadingCircle
                property: "opacity"
                to: 0.25
                duration: 700
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: loadingCircle
                property: "opacity"
                to: 0.7
                duration: 700
                easing.type: Easing.InOutSine
            }
        }

        ClippedFilledCircularProgress {
            id: loadingCircle
            anchors.fill: parent
            implicitSize: 64
            lineWidth: 5
            value: 0.65
            enableAnimation: false
            visible: !root.loaded && !root.error
            colPrimary: Appearance.colors.colOutlineVariant
            opacity: 0.4

            Item {
                anchors.centerIn: parent
                width: 64; height: 64
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        ClippedFilledCircularProgress {
            id: mainCircle
            anchors.fill: parent
            implicitSize: 64
            lineWidth: 5
            value: root.error ? 0 : root.percentage
            enableAnimation: true
            animationDuration: 900
            visible: root.loaded && !root.error
            colPrimary: root.usageColor(root.percentage)

            Behavior on colPrimary {
                ColorAnimation { duration: 800; easing.type: Easing.OutCubic }
            }

            Item {
                anchors.centerIn: parent
                width: 64; height: 64

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: -2

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${Math.round(root.percentage * 100)}%`
                        font {
                            pixelSize: Appearance.font.pixelSize.small
                            weight: Font.DemiBold
                        }
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.iconName
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }
    }

    // Data rows
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: root.rows

            StyledPopupValueRow {
                required property var modelData
                Layout.fillWidth: true
                icon: modelData.icon
                label: modelData.label
                value: modelData.value
            }
        }
    }
}
