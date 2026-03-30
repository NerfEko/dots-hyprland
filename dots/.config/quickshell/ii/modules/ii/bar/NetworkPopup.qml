import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    component SpeedCard: Item {
        id: card
        required property string cardIcon
        required property string cardName
        required property real cardSpeed       // bytes/sec
        required property list<real> cardHistoryNorm
        required property color cardColor
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
                    color: card.cardColor
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
                    text: NetworkTraffic.formatSpeed(card.cardSpeed)
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Appearance.font.pixelSize.normal
                        weight: Font.DemiBold
                    }
                    color: card.cardColor
                }
            }

            // Thin progress bar (relative to current window max)
            Item {
                Layout.fillWidth: true
                implicitHeight: 4
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: Appearance.colors.colSecondaryContainer
                }
                Rectangle {
                    width: parent.width * (card.cardHistoryNorm.length > 0
                        ? Math.min(card.cardHistoryNorm[card.cardHistoryNorm.length - 1], 1.0) : 0)
                    height: parent.height
                    radius: 2
                    color: card.cardColor
                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }
            }

            // Sparkline
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer
                clip: true

                Graph {
                    anchors.fill: parent
                    values: card.cardHistoryNorm
                    points: NetworkTraffic.historyLength
                    alignment: Graph.Alignment.Right
                    color: card.cardColor
                    fillOpacity: 0.25
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        implicitWidth: 460
        spacing: 12

        // Speed cards
        RowLayout {
            spacing: 20
            Layout.fillWidth: true

            SpeedCard {
                Layout.fillWidth: true
                cardIcon: "upload"
                cardName: "Upload"
                cardSpeed: NetworkTraffic.uploadSpeed
                cardHistoryNorm: NetworkTraffic.uploadHistoryNorm
                cardColor: Appearance.colors.colPrimary
            }

            SpeedCard {
                Layout.fillWidth: true
                cardIcon: "download"
                cardName: "Download"
                cardSpeed: NetworkTraffic.downloadSpeed
                cardHistoryNorm: NetworkTraffic.downloadHistoryNorm
                cardColor: Appearance.colors.colOnSecondaryContainer
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colSecondaryContainer
        }

        // Top process — single row, only shown when nethogs has data
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: NetworkTraffic.topProcesses.length > 0

            MaterialSymbol {
                text: "monitoring"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext
                fill: 1
            }
            StyledText {
                text: NetworkTraffic.topProcesses[0]?.name ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            RowLayout {
                spacing: 3
                MaterialSymbol {
                    text: "upload"
                    iconSize: Appearance.font.pixelSize.smallie
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: (NetworkTraffic.topProcesses[0]?.sent ?? 0).toFixed(1)
                    font { family: Appearance.font.family.numbers; pixelSize: Appearance.font.pixelSize.smallie }
                    color: Appearance.colors.colPrimary
                }
            }
            RowLayout {
                spacing: 3
                MaterialSymbol {
                    text: "download"
                    iconSize: Appearance.font.pixelSize.smallie
                    color: Appearance.colors.colOnSecondaryContainer
                }
                StyledText {
                    text: (NetworkTraffic.topProcesses[0]?.recv ?? 0).toFixed(1) + " KB/s"
                    font { family: Appearance.font.family.numbers; pixelSize: Appearance.font.pixelSize.smallie }
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colSecondaryContainer
        }

        // Connection details
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            // Left: name, type, IP
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: Network.ethernet ? "lan" : "wifi"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSurfaceVariant
                        fill: 1
                    }
                    StyledText {
                        text: Network.networkName || (Network.ethernet ? "Ethernet" : "No connection")
                        font {
                            weight: Font.DemiBold
                            pixelSize: Appearance.font.pixelSize.normal
                        }
                        color: Appearance.colors.colOnSurfaceVariant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    spacing: 6
                    visible: NetworkTraffic.localIp !== ""
                    MaterialSymbol {
                        text: "router"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: NetworkTraffic.localIp
                        font {
                            family: Appearance.font.family.numbers
                            pixelSize: Appearance.font.pixelSize.small
                        }
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            // Right: WiFi signal + details
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: Network.wifi && !Network.ethernet

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    MaterialSymbol {
                        text: "signal_cellular_alt"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        text: "Signal"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: `${Network.networkStrength}%`
                        font {
                            family: Appearance.font.family.numbers
                            pixelSize: Appearance.font.pixelSize.small
                            weight: Font.DemiBold
                        }
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: Appearance.colors.colSecondaryContainer
                    }
                    Rectangle {
                        width: parent.width * (Network.networkStrength / 100)
                        height: parent.height
                        radius: 2
                        color: Appearance.colors.colOnSecondaryContainer
                        Behavior on width {
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }
                    }
                }

                RowLayout {
                    spacing: 16
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 4
                        visible: Network.active?.frequency > 0
                        MaterialSymbol {
                            text: "router"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: {
                                const f = Network.active?.frequency ?? 0
                                if (f <= 0) return ""
                                if (f < 3000) return "2.4 GHz"
                                if (f < 5925) return "5 GHz"
                                return "6 GHz"
                            }
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }

                    RowLayout {
                        spacing: 4
                        visible: Network.active?.security !== ""
                        MaterialSymbol {
                            text: Network.active?.isSecure ? "lock" : "lock_open"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: Network.active?.security ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }
}
