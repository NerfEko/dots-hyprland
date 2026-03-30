import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function usageColor(pct) {
        if (pct >= 0.9) return Appearance.colors.colError
        if (pct >= 0.75) return Appearance.colors.colPrimary
        return Appearance.colors.colOnSecondaryContainer
    }

    component ResourceCard: Item {
        id: card
        required property string cardIcon
        required property string cardName
        required property real cardValue
        required property list<real> cardHistory
        property string cardSubtitle: ""
        property string cardDetail: ""
        implicitHeight: cardCol.implicitHeight

        ColumnLayout {
            id: cardCol
            width: parent.width
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: card.cardIcon
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.usageColor(card.cardValue)
                    fill: 1
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: card.cardName
                    font {
                        weight: Font.DemiBold
                        pixelSize: Appearance.font.pixelSize.normal
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                    Layout.fillWidth: true
                }
                StyledText {
                    text: `${Math.round(card.cardValue * 100)}%`
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Appearance.font.pixelSize.normal
                        weight: Font.DemiBold
                    }
                    color: root.usageColor(card.cardValue)
                }
            }

            StyledText {
                visible: card.cardSubtitle !== ""
                text: card.cardSubtitle
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Thin progress bar
            Item {
                Layout.fillWidth: true
                implicitHeight: 4

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: Appearance.colors.colSecondaryContainer
                }
                Rectangle {
                    width: parent.width * Math.min(card.cardValue, 1.0)
                    height: parent.height
                    radius: 2
                    color: root.usageColor(card.cardValue)
                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }
            }

            // Sparkline graph
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer
                clip: true

                Graph {
                    anchors.fill: parent
                    values: card.cardHistory
                    points: ResourceUsage.historyLength
                    alignment: Graph.Alignment.Right
                    color: root.usageColor(card.cardValue)
                    fillOpacity: 0.25
                }
            }

            StyledText {
                visible: card.cardDetail !== ""
                text: card.cardDetail
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        implicitWidth: 404
        spacing: 12

        // CPU + RAM
        RowLayout {
            spacing: 20
            Layout.fillWidth: true

            ResourceCard {
                Layout.fillWidth: true
                cardIcon: "planner_review"
                cardName: "CPU"
                cardValue: ResourceUsage.cpuUsage
                cardHistory: ResourceUsage.cpuUsageHistory
                cardSubtitle: ResourceUsage.cpuModel !== "--" ? ResourceUsage.cpuModel : ""
                cardDetail: {
                    const parts = []
                    if (ResourceUsage.cpuCores !== "--") parts.push(ResourceUsage.cpuCores + " cores")
                    if (ResourceUsage.cpuFrequency > 0) parts.push(ResourceUsage.cpuFrequency.toFixed(2) + " GHz")
                    if (ResourceUsage.maxAvailableCpuString !== "--") parts.push("max " + ResourceUsage.maxAvailableCpuString)
                    return parts.join(" · ")
                }
            }

            ResourceCard {
                Layout.fillWidth: true
                cardIcon: "memory"
                cardName: "RAM"
                cardValue: ResourceUsage.memoryUsedPercentage
                cardHistory: ResourceUsage.memoryUsageHistory
                cardSubtitle: `${root.formatKB(ResourceUsage.memoryUsed)} of ${root.formatKB(ResourceUsage.memoryTotal)}`
                cardDetail: `Free: ${root.formatKB(ResourceUsage.memoryFree)}`
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colSecondaryContainer
        }

        // GPU + Swap
        RowLayout {
            spacing: 20
            Layout.fillWidth: true

            ResourceCard {
                Layout.fillWidth: true
                cardIcon: "stadia_controller"
                cardName: "GPU"
                cardValue: ResourceUsage.gpuUsage
                cardHistory: ResourceUsage.gpuUsageHistory
                cardSubtitle: ResourceUsage.gpuModel !== "--" ? ResourceUsage.gpuModel : ""
                cardDetail: ResourceUsage.gpuVramTotal > 0
                    ? `VRAM: ${root.formatKB(ResourceUsage.gpuVramUsed)} / ${root.formatKB(ResourceUsage.gpuVramTotal)}`
                    : ""
            }

            ResourceCard {
                Layout.fillWidth: true
                visible: ResourceUsage.swapTotal > 0
                cardIcon: "swap_horiz"
                cardName: "Swap"
                cardValue: ResourceUsage.swapUsedPercentage
                cardHistory: ResourceUsage.swapUsageHistory
                cardSubtitle: `${root.formatKB(ResourceUsage.swapUsed)} of ${root.formatKB(ResourceUsage.swapTotal)}`
                cardDetail: `Free: ${root.formatKB(ResourceUsage.swapFree)}`
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colSecondaryContainer
        }

        // Packages
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: "package_2"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: ResourceUsage.installedPackages >= 0
                        ? ResourceUsage.installedPackages.toLocaleString()
                        : "..."
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Appearance.font.pixelSize.normal
                        weight: Font.DemiBold
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: "installed"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: ResourceUsage.updatablePackages > 0 ? "upgrade" : "check_circle"
                    iconSize: Appearance.font.pixelSize.large
                    color: ResourceUsage.updatablePackages > 0
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: {
                        if (ResourceUsage.updatablePackages < 0) return "checking..."
                        if (ResourceUsage.updatablePackages === 0) return "up to date"
                        const n = ResourceUsage.updatablePackages
                        return `${n} update${n !== 1 ? "s" : ""} available`
                    }
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: ResourceUsage.updatablePackages > 0
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
                }
            }
        }
    }
}
