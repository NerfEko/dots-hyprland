pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]

    Timer {
        id: successDismiss
        interval: 1400
        onTriggered: {
            GlobalStates.faceAuthState = "idle"
            GlobalStates.faceAuthOpen = false
        }
    }

    Timer {
        id: failDismiss
        interval: 2000
        onTriggered: {
            GlobalStates.faceAuthState = "idle"
            GlobalStates.faceAuthOpen = false
        }
    }

    Loader {
        id: faceAuthLoader
        active: GlobalStates.faceAuthOpen

        sourceComponent: PanelWindow {
            id: faceAuthWindow
            visible: faceAuthLoader.active

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:faceauth"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors { top: true; left: true; right: true; bottom: true }
            implicitWidth: root.focusedScreen?.width ?? 0
            implicitHeight: root.focusedScreen?.height ?? 0

            // Dark scrim
            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: 0
                Component.onCompleted: opacity = 0.6
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                    }
                }
            }

            // Center card
            Rectangle {
                id: card
                anchors.centerIn: parent
                focus: faceAuthWindow.visible
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.faceAuthState = "idle"
                        GlobalStates.faceAuthOpen = false
                    }
                }
                width: 300
                height: 340
                radius: Appearance.rounding.verylarge
                color: Appearance.colors.colLayer0

                scale: 0.88
                opacity: 0
                Component.onCompleted: {
                    scale = 1.0
                    opacity = 1.0
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    FaceIdAnimation {
                        Layout.alignment: Qt.AlignHCenter
                        ringSize: 180
                        authState: GlobalStates.faceAuthState === "idle"
                            ? "scanning"
                            : GlobalStates.faceAuthState
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.large
                        text: {
                            if (GlobalStates.faceAuthState === "success") return "Access Granted"
                            if (GlobalStates.faceAuthState === "fail")    return "Not Recognized"
                            return "Face ID"
                        }
                        color: {
                            if (GlobalStates.faceAuthState === "success") return Appearance.m3colors.m3primary
                            if (GlobalStates.faceAuthState === "fail")    return Appearance.m3colors.m3error
                            return Appearance.colors.colOnLayer0
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                            }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        text: {
                            if (GlobalStates.faceAuthState === "success") return "Authentication successful"
                            if (GlobalStates.faceAuthState === "fail")    return "Falling back to password…"
                            return "Look at your camera"
                        }
                    }
                }
            }

        }
    }

    IpcHandler {
        target: "faceAuth"

        function open(): void {
            successDismiss.stop()
            failDismiss.stop()
            GlobalStates.faceAuthState = "scanning"
            GlobalStates.faceAuthOpen = true
        }

        function success(): void {
            GlobalStates.faceAuthState = "success"
            successDismiss.restart()
        }

        function fail(): void {
            GlobalStates.faceAuthState = "fail"
            failDismiss.restart()
        }

        function close(): void {
            successDismiss.stop()
            failDismiss.stop()
            GlobalStates.faceAuthState = "idle"
            GlobalStates.faceAuthOpen = false
        }
    }
}
