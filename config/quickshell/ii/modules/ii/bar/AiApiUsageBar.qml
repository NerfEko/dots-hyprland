pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

MouseArea {
    id: root
    implicitWidth: rowLayout.implicitWidth + 8
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPressed: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            AiApiUsage.fetchAll()
            mouse.accepted = false
        }
    }

    component AiCircle: Item {

        id: circleItem
        required property string iconName
        required property real percentage
        required property bool loaded
        required property bool error
        property bool inverted: false

        function usageColor(pct) {
            const p = circleItem.inverted ? (1 - pct) : pct
            return Qt.hsla((1 - p) / 3, 0.68, 0.52, 1.0)
        }

        implicitWidth: 20
        implicitHeight: 20

        ClippedFilledCircularProgress {
            anchors.fill: parent
            implicitSize: 20
            lineWidth: Appearance.rounding.unsharpen
            value: circleItem.error ? 0 : circleItem.percentage
            enableAnimation: false
            colPrimary: circleItem.error
                ? Appearance.colors.colError
                : Appearance.colors.colOnSecondaryContainer

            Item {
                anchors.centerIn: parent
                width: 20
                height: 20

                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: Font.DemiBold
                    fill: 1
                    text: circleItem.iconName
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                    opacity: (!circleItem.loaded && !circleItem.error) ? 0.45 : 1.0

                    Behavior on opacity {
                        NumberAnimation { duration: 600; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 6

        AiCircle {
            iconName: "code"
            percentage: AiApiUsage.githubPercentage
            loaded: AiApiUsage.github.loaded
            error: AiApiUsage.github.error
            visible: Config.options?.bar?.aiApiUsage?.github?.enable ?? true
        }

        AiCircle {
            iconName: "psychology"
            percentage: AiApiUsage.claudePercentage
            loaded: AiApiUsage.claude.loaded
            error: AiApiUsage.claude.error
            visible: Config.options?.bar?.aiApiUsage?.claude?.enable ?? true
        }

        AiCircle {
            iconName: "route"
            percentage: AiApiUsage.openrouterPercentage
            loaded: AiApiUsage.openrouter.loaded
            error: AiApiUsage.openrouter.error
            inverted: true
            visible: Config.options?.bar?.aiApiUsage?.openrouter?.enable ?? true
        }
    }

    AiApiUsagePopup {
        hoverTarget: root
    }
}
