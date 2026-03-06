import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

WindowDialog {
    id: root
    backgroundHeight: 500

    WindowDialogTitle {
        text: Translation.tr("GPU Mode")
    }

    // Warning banner when logout is required
    Loader {
        Layout.fillWidth: true
        Layout.topMargin: -10
        active: GpuMode.pendingAction !== ""
        visible: active
        sourceComponent: Rectangle {
            implicitHeight: warningRow.implicitHeight + 16
            color: Appearance.colors.colWarning
            radius: Appearance.rounding.small

            RowLayout {
                id: warningRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 8
                }
                spacing: 8

                MaterialSymbol {
                    text: "warning"
                    iconSize: 20
                    color: Appearance.colors.colOnWarning
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Action required: %1").arg(GpuMode.pendingAction)
                    color: Appearance.colors.colOnWarning
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // Pending mode indicator
    Loader {
        Layout.fillWidth: true
        Layout.topMargin: GpuMode.pendingAction !== "" ? 4 : -10
        active: GpuMode.pendingMode !== ""
        visible: active
        sourceComponent: Rectangle {
            implicitHeight: pendingRow.implicitHeight + 16
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding.small

            RowLayout {
                id: pendingRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 8
                }
                spacing: 8

                MaterialSymbol {
                    text: "schedule"
                    iconSize: 20
                    color: Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Pending switch to: %1").arg(GpuMode.pendingMode)
                    color: Appearance.colors.colOnPrimaryContainer
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    WindowDialogSectionHeader {
        text: Translation.tr("Select Mode")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    // GPU mode list
    StyledListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0

        model: GpuMode.supportedModes
        delegate: GpuModeItem {
            required property string modelData
            required property int index
            modeName: modelData
            anchors {
                left: parent?.left
                right: parent?.right
            }
        }
    }

    WindowDialogSeparator {}

    // Power status info
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: GpuMode.powerStatus === "Active" ? "bolt" : "power_off"
            iconSize: 18
            color: Appearance.colors.colOnLayer1
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("dGPU Power: %1").arg(GpuMode.powerStatus)
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }

    WindowDialogButtonRow {
        Layout.fillWidth: true

        DialogButton {
            buttonText: Translation.tr("Refresh")
            onClicked: GpuMode.refresh()
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }

    // GPU mode list item component
    component GpuModeItem: RippleButton {
        id: modeItem
        required property string modeName
        
        readonly property bool isCurrentMode: GpuMode.currentMode === modeName
        readonly property bool isPendingMode: GpuMode.pendingMode === modeName
        readonly property string modeIcon: GpuMode.getIconForMode(modeName)
        readonly property string modeDescription: GpuMode.getDescriptionForMode(modeName)

        implicitHeight: modeContent.implicitHeight + 16
        buttonRadius: 0
        colBackground: isCurrentMode ? Appearance.colors.colPrimaryContainer : "transparent"
        colBackgroundHover: isCurrentMode ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover

        onClicked: {
            if (!isCurrentMode) {
                GpuMode.setMode(modeName)
            }
        }

        RowLayout {
            id: modeContent
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Appearance.rounding.large + 8
                rightMargin: Appearance.rounding.large + 8
            }
            spacing: 12

            // Mode icon
            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: Appearance.rounding.full
                color: modeItem.isCurrentMode ? Appearance.colors.colPrimary : Appearance.colors.colLayer2

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: modeItem.modeIcon
                    iconSize: 22
                    color: modeItem.isCurrentMode ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                }
            }

            // Mode info
            Column {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    spacing: 8

                    StyledText {
                        text: modeItem.modeName
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: modeItem.isCurrentMode ? Font.Bold : Font.Normal
                        color: modeItem.isCurrentMode ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                    }

                    // Current mode indicator
                    Loader {
                        active: modeItem.isCurrentMode
                        visible: active
                        sourceComponent: Rectangle {
                            implicitWidth: currentLabel.implicitWidth + 12
                            implicitHeight: currentLabel.implicitHeight + 4
                            radius: height / 2
                            color: Appearance.colors.colPrimary

                            StyledText {
                                id: currentLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Current")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }

                    // Pending mode indicator
                    Loader {
                        active: modeItem.isPendingMode && !modeItem.isCurrentMode
                        visible: active
                        sourceComponent: Rectangle {
                            implicitWidth: pendingLabel.implicitWidth + 12
                            implicitHeight: pendingLabel.implicitHeight + 4
                            radius: height / 2
                            color: Appearance.colors.colSecondary

                            StyledText {
                                id: pendingLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Pending")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondary
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                StyledText {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    text: modeItem.modeDescription
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: ColorUtils.transparentize(
                        modeItem.isCurrentMode ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1,
                        0.3
                    )
                    wrapMode: Text.WordWrap
                }

                // Logout warning for this mode
                Loader {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    active: !modeItem.isCurrentMode && GpuMode.requiresLogout(modeItem.modeName)
                    visible: active
                    sourceComponent: RowLayout {
                        spacing: 4
                        MaterialSymbol {
                            text: "logout"
                            iconSize: 14
                            color: Appearance.colors.colWarning
                        }
                        StyledText {
                            text: Translation.tr("Requires logout")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colWarning
                        }
                    }
                }
            }

            // Chevron
            MaterialSymbol {
                text: "chevron_right"
                iconSize: 20
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.5)
                visible: !modeItem.isCurrentMode
            }
        }
    }
}
