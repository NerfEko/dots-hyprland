pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.voiceInput
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    GlobalShortcut {
        name: "voiceInputToggle"
        description: "Toggle voice input overlay (Super+L)"
        onPressed: {
            if (!GlobalStates.voiceInputOpen) {
                const addr = ToplevelManager.activeToplevel?.HyprlandToplevel?.address ?? ""
                GlobalStates.voiceInputPreviousWindowAddress = addr ? `0x${addr}` : ""
            }
            GlobalStates.voiceInputOpen = !GlobalStates.voiceInputOpen
        }
    }

    Loader {
        id: popupLoader
        // Extra guard: only show after Config is ready to avoid phantom opens on startup
        active: Config.ready && GlobalStates.voiceInputOpen

        sourceComponent: PanelWindow {
            id: popupWindow
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:voiceInput"
            WlrLayershell.layer: WlrLayer.Overlay
            // OnDemand: gets keyboard events when focused, but doesn't steal focus globally
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            // Full screen so the dim backdrop covers everything
            anchors.top:    true
            anchors.bottom: true
            anchors.left:   true
            anchors.right:  true

            // ── Click-outside-to-close (invisible, no dim) ────────────────
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    VoiceInput.stopListening()
                    GlobalStates.voiceInputOpen = false
                }
            }

            // ── Drop shadow ────────────────────────────────────────────────
            StyledRectangularShadow {
                target: card
            }

            // ── Card ───────────────────────────────────────────────────────
            VoiceInputContent {
                id: card

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom:           parent.bottom
                    bottomMargin:     Appearance.sizes.hyprlandGapsOut ?? 16
                }
                width:  Math.min(parent.width * 0.60, 860)
                height: Math.floor(popupWindow.screen.height * 0.18)

                // Slide-up entry animation
                property bool entered: false
                opacity: entered ? 1 : 0
                transform: Translate {
                    y: card.entered ? 0 : 36
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Component.onCompleted: Qt.callLater(() => {
                    card.entered = true
                    card.forceActiveFocus()
                })
            }
        }
    }
}
