pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.voiceInput
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

/**
 * Compact glass card for the voice input popup.
 * Designed for ~15-18% screen height.
 * Layout: [header row] / [wave + live text] / [button row]
 */
Item {
    id: root

    readonly property real radius: Appearance.rounding.large ?? 20

    // ── Glass background ──────────────────────────────────────────────────
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(
            Appearance.m3colors.m3surfaceContainer.r,
            Appearance.m3colors.m3surfaceContainer.g,
            Appearance.m3colors.m3surfaceContainer.b,
            0.62
        )
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: cardBg.width; height: cardBg.height; radius: cardBg.radius
            }
        }
    }

    // Glass rim
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
    }

    // ── Key handling ──────────────────────────────────────────────────────
    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            VoiceInput.stopListening()
            GlobalStates.voiceInputOpen = false
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            VoiceInput.acceptText()
            event.accepted = true
        }
    }

    // Swallow background clicks (prevent fallthrough to backdrop close handler).
    // Declared before ColumnLayout so buttons (higher z-order) still receive events.
    MouseArea { anchors.fill: parent }

    // ── Layout ────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 8

        // ── Row 1: mic indicator + status/text + close ────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Pulsing mic circle
            Rectangle {
                id: micCircle
                width: 28; height: 28; radius: 14
                color: VoiceInput.isListening
                    ? Qt.rgba(Appearance.m3colors.m3primary.r, Appearance.m3colors.m3primary.g, Appearance.m3colors.m3primary.b, 0.18)
                    : VoiceInput.isLoading
                        ? Qt.rgba(Appearance.m3colors.m3secondary.r, Appearance.m3colors.m3secondary.g, Appearance.m3colors.m3secondary.b, 0.18)
                        : Qt.rgba(0.5, 0.5, 0.5, 0.10)
                Behavior on color { ColorAnimation { duration: 250 } }

                SequentialAnimation on scale {
                    running: VoiceInput.isListening
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.15; duration: 650; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 650; easing.type: Easing.InOutSine }
                }
                RotationAnimation on rotation {
                    running: VoiceInput.isLoading && !VoiceInput.isListening
                    loops: Animation.Infinite; from: 0; to: 360
                    duration: 1500; easing.type: Easing.Linear
                    onStopped: micCircle.rotation = 0
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: VoiceInput.isListening ? "mic" : VoiceInput.isLoading ? "sync" : "mic_off"
                    iconSize: 15
                    color: VoiceInput.isListening ? Appearance.m3colors.m3primary
                         : VoiceInput.isLoading   ? Appearance.m3colors.m3secondary
                         : Appearance.m3colors.m3outline
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // Status label
            StyledText {
                text: VoiceInput.isLoading    ? "Loading model…"
                    : VoiceInput.isGenerating ? "Processing…"
                    : VoiceInput.isListening  ? "Listening"
                    : "Voice Input"
                font.pixelSize: Appearance.font.pixelSize.small ?? 13
                color: Qt.rgba(Appearance.m3colors.m3onSurface.r, Appearance.m3colors.m3onSurface.g, Appearance.m3colors.m3onSurface.b, 0.7)
            }

            // LLM badge
            Rectangle {
                visible: VoiceInput.llmMode
                height: 18; width: llmLabel.implicitWidth + 12; radius: 9
                color: Qt.rgba(Appearance.m3colors.m3secondary.r, Appearance.m3colors.m3secondary.g, Appearance.m3colors.m3secondary.b, 0.18)
                StyledText {
                    id: llmLabel; anchors.centerIn: parent
                    text: VoiceInput.isGenerating ? "generating…" : "llm"
                    font.pixelSize: 10
                    color: Appearance.m3colors.m3secondary
                }
            }

            Item { Layout.fillWidth: true }

            // Close
            RippleButton {
                implicitWidth: 26; implicitHeight: 26; buttonRadius: 13
                colBackground: "transparent"
                onClicked: { VoiceInput.stopListening(); GlobalStates.voiceInputOpen = false }
                MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 15; color: Appearance.m3colors.m3onSurface }
            }
        }

        // ── Row 2: wave bars (left) + transcript text (right) ─────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Mini wave visualizer
            VoiceWaveBar {
                implicitWidth: 80
                Layout.fillHeight: true
                bars: VoiceInput.audioBars
                active: VoiceInput.isListening
                color: Appearance.m3colors.m3primary
            }

            // Live transcript / LLM output
            VoiceTextDisplay {
                id: textDisplay
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: VoiceInput.displayText
                isGenerating: VoiceInput.isGenerating
                placeholder: VoiceInput.isLoading ? "Loading speech model…" : "Start speaking…"
            }
        }

        // ── Row 3: action buttons ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            // Stop / Listen
            RippleButton {
                implicitHeight: 30; implicitWidth: stopLbl.implicitWidth + 22; buttonRadius: 15
                colBackground: VoiceInput.isListening
                    ? Qt.rgba(Appearance.m3colors.m3errorContainer.r, Appearance.m3colors.m3errorContainer.g, Appearance.m3colors.m3errorContainer.b, 0.85)
                    : Qt.rgba(Appearance.m3colors.m3primary.r, Appearance.m3colors.m3primary.g, Appearance.m3colors.m3primary.b, 0.12)
                colBackgroundHover: VoiceInput.isListening
                    ? Appearance.m3colors.m3errorContainer
                    : Qt.rgba(Appearance.m3colors.m3primary.r, Appearance.m3colors.m3primary.g, Appearance.m3colors.m3primary.b, 0.22)
                onClicked: { if (VoiceInput.isListening) VoiceInput.stopListening(); else VoiceInput.startListening() }
                RowLayout {
                    anchors.centerIn: parent; spacing: 3
                    MaterialSymbol { text: VoiceInput.isListening ? "stop" : "mic"; iconSize: 13; color: VoiceInput.isListening ? Appearance.m3colors.m3onErrorContainer : Appearance.m3colors.m3primary }
                    StyledText { id: stopLbl; text: VoiceInput.isListening ? "Stop" : "Listen"; font.pixelSize: 12; color: VoiceInput.isListening ? Appearance.m3colors.m3onErrorContainer : Appearance.m3colors.m3primary }
                }
            }

            RippleButton {
                implicitHeight: 30; implicitWidth: cleanLbl.implicitWidth + 22; buttonRadius: 15
                enabled: VoiceInput.fullText.length > 0 && !VoiceInput.isGenerating; opacity: enabled ? 1 : 0.35
                onClicked: { textDisplay.frozenText = VoiceInput.displayText; VoiceInput.cleanText() }
                RowLayout { anchors.centerIn: parent; spacing: 3
                    MaterialSymbol { text: "auto_fix_high"; iconSize: 13; color: Appearance.m3colors.m3onSurface }
                    StyledText { id: cleanLbl; text: "Clean"; font.pixelSize: 12; color: Appearance.m3colors.m3onSurface }
                }
            }

            RippleButton {
                implicitHeight: 30; implicitWidth: sumLbl.implicitWidth + 22; buttonRadius: 15
                enabled: VoiceInput.fullText.length > 0 && !VoiceInput.isGenerating; opacity: enabled ? 1 : 0.35
                onClicked: { textDisplay.frozenText = VoiceInput.displayText; VoiceInput.summarizeText() }
                RowLayout { anchors.centerIn: parent; spacing: 3
                    MaterialSymbol { text: "summarize"; iconSize: 13; color: Appearance.m3colors.m3onSurface }
                    StyledText { id: sumLbl; text: "Summarize"; font.pixelSize: 12; color: Appearance.m3colors.m3onSurface }
                }
            }

            RippleButton {
                implicitHeight: 30; implicitWidth: undoLbl.implicitWidth + 22; buttonRadius: 15
                visible: VoiceInput.canUndo
                onClicked: { textDisplay.frozenText = VoiceInput.displayText; VoiceInput.undoLlm() }
                RowLayout { anchors.centerIn: parent; spacing: 3
                    MaterialSymbol { text: "undo"; iconSize: 13; color: Appearance.m3colors.m3tertiary }
                    StyledText { id: undoLbl; text: "Undo"; font.pixelSize: 12; color: Appearance.m3colors.m3tertiary }
                }
            }

            Item { Layout.fillWidth: true }

            // Copy
            RippleButton {
                implicitHeight: 30; implicitWidth: 30; buttonRadius: 15
                enabled: VoiceInput.displayText.length > 0; opacity: enabled ? 1 : 0.35
                onClicked: VoiceInput.copyText()
                MaterialSymbol { anchors.centerIn: parent; text: "content_copy"; iconSize: 13; color: Appearance.m3colors.m3onSurface }
            }

            // Accept (primary filled)
            RippleButton {
                implicitHeight: 30; implicitWidth: acceptLbl.implicitWidth + 26; buttonRadius: 15
                enabled: VoiceInput.displayText.length > 0; opacity: enabled ? 1 : 0.35
                colBackground: Appearance.m3colors.m3primary
                colBackgroundHover: Qt.rgba(Appearance.m3colors.m3primary.r, Appearance.m3colors.m3primary.g, Appearance.m3colors.m3primary.b, 0.82)
                onClicked: VoiceInput.acceptText()
                RowLayout { anchors.centerIn: parent; spacing: 3
                    MaterialSymbol { text: "keyboard_return"; iconSize: 13; color: Appearance.m3colors.m3onPrimary }
                    StyledText { id: acceptLbl; text: "Accept"; font.pixelSize: 12; color: Appearance.m3colors.m3onPrimary }
                }
            }
        }
    }
}
