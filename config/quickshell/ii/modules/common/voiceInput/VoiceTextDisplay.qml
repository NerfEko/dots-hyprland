pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * Scrollable text display for voice transcription / LLM output.
 *
 * Crossfade animation: set frozenText = current text BEFORE triggering a
 * transformation (Clean / Summarize / Undo). The old text dissolves out while
 * the new text fades in, giving a "transform" feel rather than a wipe.
 *
 * Shimmer sweep plays on top while isGenerating is true.
 */
Item {
    id: root

    property string text: ""
    property bool   isGenerating: false
    property string placeholder: "Start speaking…"
    property real   innerPadding: 12

    // Set this to VoiceInput.displayText just before calling cleanText /
    // summarizeText / undoLlm.  Cleared automatically after the animation.
    property string frozenText: ""

    readonly property bool hasText: text.length > 0

    onFrozenTextChanged: {
        if (frozenText.length > 0) {
            liveLayer.opacity = 0
            frozenLayer.opacity = 1
            dissolveOut.restart()
            fadeIn.restart()
        }
    }

    // ── Background ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Qt.rgba(
            Appearance.colors.colLayer0.r,
            Appearance.colors.colLayer0.g,
            Appearance.colors.colLayer0.b,
            0.38
        )
        border.width: 1
        border.color: Qt.rgba(
            Appearance.m3colors.m3outlineVariant.r,
            Appearance.m3colors.m3outlineVariant.g,
            Appearance.m3colors.m3outlineVariant.b,
            0.25
        )
    }

    // ── Frozen text — dissolves out ────────────────────────────────────────
    Item {
        id: frozenLayer
        anchors { fill: parent; margins: root.innerPadding }
        clip: true
        opacity: 0
        visible: opacity > 0

        Text {
            width: parent.width
            text:  root.frozenText
            color: Appearance.m3colors.m3onSurface
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
            font {
                family:       Appearance.font.family.main
                pixelSize:    Appearance.font.pixelSize.normal
                variableAxes: Appearance.font.variableAxes.main
            }
        }

        // Dissolve out + drift up slightly
        SequentialAnimation {
            id: dissolveOut
            ParallelAnimation {
                NumberAnimation {
                    target: frozenLayer; property: "opacity"
                    from: 1; to: 0; duration: 380; easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: frozenLayer; property: "y"
                    from: 0; to: -10; duration: 380; easing.type: Easing.InCubic
                }
            }
            ScriptAction { script: { frozenLayer.y = 0; root.frozenText = "" } }
        }
    }

    // ── Live text — fades in ───────────────────────────────────────────────
    Flickable {
        id: liveLayer
        anchors { fill: parent; margins: root.innerPadding }
        contentHeight: textContent.implicitHeight
        clip: true
        opacity: 1

        onContentHeightChanged: {
            if (contentHeight > height)
                contentY = contentHeight - height
        }

        // Fade in after a short delay so frozen text has started to leave
        SequentialAnimation {
            id: fadeIn
            PauseAnimation  { duration: 120 }
            NumberAnimation {
                target: liveLayer; property: "opacity"
                from: 0; to: 1; duration: 460; easing.type: Easing.OutCubic
            }
        }

        Text {
            id: textContent
            width: liveLayer.width
            text:  root.hasText ? root.text : root.placeholder
            color: root.hasText
                ? Appearance.m3colors.m3onSurface
                : Qt.rgba(
                    Appearance.m3colors.m3onSurface.r,
                    Appearance.m3colors.m3onSurface.g,
                    Appearance.m3colors.m3onSurface.b,
                    0.45
                  )
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
            font {
                family:       Appearance.font.family.main
                pixelSize:    Appearance.font.pixelSize.normal
                variableAxes: Appearance.font.variableAxes.main
            }
        }
    }

    // ── Shimmer sweep (while LLM is generating) ────────────────────────────
    Item {
        id: shimmerLayer
        anchors.fill: parent
        clip: true
        visible: root.isGenerating
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        property real pos: -0.35
        NumberAnimation on pos {
            running: root.isGenerating
            loops:   Animation.Infinite
            from:   -0.35; to: 1.35
            duration: 1400; easing.type: Easing.Linear
        }

        Canvas {
            anchors.fill: parent
            property real pos: shimmerLayer.pos
            onPosChanged: requestPaint()
            onPaint: {
                const ctx  = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const cx   = pos * width
                const hw   = width * 0.28
                const grad = ctx.createLinearGradient(cx - hw, 0, cx + hw, 0)
                grad.addColorStop(0.0,  Qt.rgba(1, 1, 1, 0.0))
                grad.addColorStop(0.35, Qt.rgba(1, 1, 1, 0.08))
                grad.addColorStop(0.5,  Qt.rgba(1, 1, 1, 0.18))
                grad.addColorStop(0.65, Qt.rgba(1, 1, 1, 0.08))
                grad.addColorStop(1.0,  Qt.rgba(1, 1, 1, 0.0))
                ctx.fillStyle = grad
                ctx.fillRect(0, 0, width, height)
            }
        }
    }
}
