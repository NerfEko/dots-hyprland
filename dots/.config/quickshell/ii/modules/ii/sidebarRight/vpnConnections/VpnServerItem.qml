import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell

DialogListItem {
    id: root

    required property string serverName   // e.g. "US-NY#184"
    required property string city
    required property string country
    required property int    load         // 0-100
    required property bool   fastest
    required property bool   connected

    active: connected

    onClicked: {
        if (connected) {
            Quickshell.execDetached(["protonvpn", "disconnect"])
        } else {
            Quickshell.execDetached(["protonvpn", "connect", serverName])
        }
    }

    contentItem: RowLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 10

        // Shield icon
        MaterialSymbol {
            iconSize: Appearance.font.pixelSize.larger
            text: "shield"
            color: root.connected
                ? Appearance.m3colors.m3primary
                : Appearance.colors.colOnSurfaceVariant
        }

        // Name + city column
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                spacing: 6
                StyledText {
                    text: root.serverName
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.normal
                    elide: Text.ElideRight
                }
                // "Fastest" badge
                Loader {
                    active: root.fastest
                    visible: active
                    sourceComponent: Rectangle {
                        radius: height / 2
                        color: Appearance.m3colors.m3secondaryContainer
                        implicitWidth: fastestLabel.implicitWidth + 10
                        implicitHeight: fastestLabel.implicitHeight + 4
                        StyledText {
                            id: fastestLabel
                            anchors.centerIn: parent
                            text: Translation.tr("Fastest")
                            color: Appearance.m3colors.m3onSecondaryContainer
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }

            StyledText {
                visible: root.city !== ""
                text: root.city !== "" ? "%1, %2".arg(root.city).arg(root.country) : root.country
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
                opacity: 0.7
            }

            // Load bar
            RowLayout {
                spacing: 6
                Rectangle {
                    id: loadBarBg
                    Layout.fillWidth: true
                    height: 3
                    radius: 2
                    color: Appearance.colors.colSurfaceVariant

                    Rectangle {
                        width: parent.width * (root.load / 100)
                        height: parent.height
                        radius: parent.radius
                        color: root.load > 75 ? Appearance.m3colors.m3error
                             : root.load > 50 ? Appearance.m3colors.m3tertiary
                             : Appearance.m3colors.m3primary
                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }
                StyledText {
                    text: "%1%".arg(root.load)
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    opacity: 0.7
                }
            }
        }

        // Active checkmark
        MaterialSymbol {
            visible: root.connected
            text: "check_circle"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.m3colors.m3primary
        }
    }
}
