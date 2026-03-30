import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    // "scanning" | "success" | "fail"
    property string authState: "scanning"
    property int ringSize: 200

    implicitWidth: ringSize
    implicitHeight: ringSize

    readonly property color ringColor: {
        if (authState === "success") return Appearance.m3colors.m3primary
        if (authState === "fail")    return Appearance.m3colors.m3error
        return Appearance.m3colors.m3primary
    }

    readonly property real ringOpacity: {
        if (authState === "success") return 1.0
        if (authState === "fail")    return 1.0
        return 1.0
    }

    // ---- Success fill circle ----
    Rectangle {
        id: successFill
        anchors.centerIn: parent
        width: root.ringSize * 0.82
        height: root.ringSize * 0.82
        radius: width / 2
        color: Appearance.m3colors.m3primaryContainer
        opacity: root.authState === "success" ? 0.3 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }

    // ---- Outer rotating sweep ring ----
    property real outerRotation: 0
    RotationAnimation on outerRotation {
        running: root.authState === "scanning"
        from: 0
        to: 360
        duration: 2400
        easing.type: Easing.Linear
        loops: Animation.Infinite
    }

    Shape {
        id: outerRing
        anchors.centerIn: parent
        width: root.ringSize
        height: root.ringSize
        rotation: root.outerRotation
        opacity: root.authState === "fail" ? 0.4 : 1.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: 3
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.ringSize / 2
                centerY: root.ringSize / 2
                radiusX: root.ringSize / 2 - 4
                radiusY: root.ringSize / 2 - 4
                startAngle: -90
                sweepAngle: root.authState === "success" ? 360 : 260
                Behavior on sweepAngle {
                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // ---- Middle pulsing ring ----
    property real middleOpacity: 1.0
    SequentialAnimation on middleOpacity {
        running: root.authState === "scanning"
        loops: Animation.Infinite
        NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
    }

    Shape {
        anchors.centerIn: parent
        width: root.ringSize * 0.70
        height: root.ringSize * 0.70
        opacity: root.authState === "scanning" ? root.middleOpacity : (root.authState === "success" ? 0.6 : 0.0)
        Behavior on opacity { NumberAnimation { duration: 300 } }

        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.ringSize * 0.70 / 2
                centerY: root.ringSize * 0.70 / 2
                radiusX: root.ringSize * 0.70 / 2 - 3
                radiusY: root.ringSize * 0.70 / 2 - 3
                startAngle: -90
                sweepAngle: 360
            }
        }
    }

    // ---- Scan line sweeping top → bottom ----
    property real scanLineY: 0
    SequentialAnimation on scanLineY {
        running: root.authState === "scanning"
        loops: Animation.Infinite
        NumberAnimation { to: root.ringSize; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 0 }
    }

    Item {
        id: scanLineClip
        anchors.centerIn: parent
        width: root.ringSize
        height: root.ringSize
        visible: root.authState === "scanning"
        clip: true

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.scanLineY - 1
            width: root.ringSize * 0.55
            height: 2
            radius: 1
            opacity: 0.55
            color: root.ringColor
        }
    }

    // ---- Center icon ----
    MaterialSymbol {
        id: centerIcon
        anchors.centerIn: parent
        iconSize: root.ringSize * 0.28
        fill: root.authState === "success" ? 1 : 0
        text: {
            if (root.authState === "success") return "check_circle"
            if (root.authState === "fail")    return "no_accounts"
            return "face"
        }
        color: root.ringColor
        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
            }
        }

        property real iconScale: 1.0
        scale: iconScale
    }

    // ---- Shake on fail ----
    property real shakeOffset: 0

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeOffset"; to: -16; duration: 45 }
        NumberAnimation { target: root; property: "shakeOffset"; to: 16;  duration: 45 }
        NumberAnimation { target: root; property: "shakeOffset"; to: -10; duration: 38 }
        NumberAnimation { target: root; property: "shakeOffset"; to: 10;  duration: 38 }
        NumberAnimation { target: root; property: "shakeOffset"; to: -5;  duration: 32 }
        NumberAnimation { target: root; property: "shakeOffset"; to: 5;   duration: 32 }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0;   duration: 28 }
    }

    // ---- Icon bounce on state change ----
    SequentialAnimation {
        id: iconBounce
        NumberAnimation { target: centerIcon; property: "iconScale"; to: 0.65; duration: 90 }
        NumberAnimation { target: centerIcon; property: "iconScale"; to: 1.2; duration: 220; easing.type: Easing.OutBack }
        NumberAnimation { target: centerIcon; property: "iconScale"; to: 1.0; duration: 100 }
    }

    onAuthStateChanged: {
        if (authState === "fail") {
            shakeAnim.start()
            iconBounce.start()
        } else if (authState === "success") {
            iconBounce.start()
        } else if (authState === "scanning") {
            shakeOffset = 0
        }
    }

    // Apply shake as x offset
    transform: Translate { x: root.shakeOffset }
}
