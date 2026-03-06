import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

WMouseAreaButton {
    id: root

    required property int workspace
    property bool newWorkspace: false
    property bool droppable: false

    readonly property bool isActiveWorkspace: HyprlandData.activeWorkspace?.id === root.workspace
    readonly property real screenWidth: QsWindow.window?.width ?? 0
    readonly property real screenHeight: QsWindow.window?.height ?? 0
    readonly property real screenAspectRatio: screenWidth / screenHeight
    readonly property real windowScale: wallpaperHeight / screenHeight

    property real wallpaperHeight: 155 // was 124, increased 1.25x

    height: ListView.view?.height ?? 100
    implicitWidth: 305 // was 244, increased 1.25x

    colBackground: ColorUtils.transparentize(Looks.colors.bg2, (isActiveWorkspace || droppable) ? 0 : 1)
    Behavior on color {
        animation: Looks.transition.color.createObject(this)
    }

    scale: root.containsPress ? 0.95 : 1
    Behavior on scale {
        NumberAnimation {
            id: scaleAnim
            duration: 300
            easing.type: Easing.OutExpo
        }
    }

    // Content
    ColumnLayout {
        id: contentItem
        anchors {
            fill: parent
            leftMargin: 15 // was 12, 1.25x
            rightMargin: 15 // was 12, 1.25x
            topMargin: 11 // was 9, 1.25x
            bottomMargin: 10 // was 8, 1.25x
        }
        spacing: 10 // was 8, 1.25x

        WText {
            Layout.fillWidth: true
            Layout.fillHeight: false
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            text: root.newWorkspace ? Translation.tr("New desktop") : Translation.tr("Desktop %1").arg(root.workspace)
        }

        Rectangle {
            id: wsBg
            height: root.wallpaperHeight
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Looks.colors.bg1

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: wsBg.width
                    height: wsBg.height
                    radius: Looks.radius.medium
                }
            }

            // Workspace content
            Loader {
                anchors.fill: parent
                active: !root.newWorkspace
                sourceComponent: StyledImage {
                    cache: true
                    sourceSize: Qt.size(root.screenAspectRatio * root.wallpaperHeight, root.wallpaperHeight)
                    source: Config.options.background.wallpaperPath
                    fillMode: Image.PreserveAspectCrop

                    Repeater {
                        model: ScriptModel {
                            values: HyprlandData.toplevelsForWorkspace(root.workspace)
                        }
                        delegate: ScreencopyView {
                            required property var modelData
                            readonly property var hyprlandWindowData: HyprlandData.windowByAddress[`0x${modelData.HyprlandToplevel?.address}`]
                            captureSource: modelData
                            live: true
                            width: hyprlandWindowData?.size[0] * root.windowScale
                            height: hyprlandWindowData?.size[1] * root.windowScale
                            x: hyprlandWindowData?.at[0] * root.windowScale
                            y: hyprlandWindowData?.at[1] * root.windowScale
                        }
                    }
                }
            }

            // New plus icon
            Loader {
                anchors.centerIn: parent
                active: root.newWorkspace
                sourceComponent: FluentIcon {
                    icon: "add"
                }
            }

            Rectangle {
                z: 2
                visible: root.droppable && !root.newWorkspace
                anchors.fill: parent
                color: Looks.colors.accent
                opacity: 0.2
            }
        }
    }

    // Active indicator
    WFadeLoader {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
        }
        shown: root.isActiveWorkspace

        sourceComponent: Rectangle {
            id: activeIndicator
            implicitWidth: 40 // was 32, 1.25x
            implicitHeight: 4 // was 3, 1.25x
            color: Looks.colors.accent
            radius: height / 2
        }
    }
}
