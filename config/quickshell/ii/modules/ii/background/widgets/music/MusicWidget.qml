import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "music"

    implicitHeight: background.implicitHeight
    implicitWidth: background.implicitWidth

    property MprisPlayer player: MprisController.activePlayer
    
    property string cachedTitle: ""
    property string cachedArtist: ""
    property string cachedArtUrl: ""
    property int cachedLoopState: 0
    property real cachedPosition: 0
    
    onPlayerChanged: {
        if (player) {
            cachedTitle = player.trackTitle || cachedTitle
            cachedArtist = player.trackArtist || cachedArtist
            cachedArtUrl = player.trackArtUrl || cachedArtUrl
            cachedPosition = player.position
            if (player.loopState === MprisLoopState.None) cachedLoopState = 0;
            else if (player.loopState === MprisLoopState.Track) cachedLoopState = 1;
            else if (player.loopState === MprisLoopState.Playlist) cachedLoopState = 2;
        }
    }

    Connections {
        target: MprisController
        function onTrackChanged() {
            if (player) {
                cachedTitle = player.trackTitle || cachedTitle
                cachedArtist = player.trackArtist || cachedArtist
                cachedArtUrl = player.trackArtUrl || cachedArtUrl
            }
        }
    }

    Timer {
        running: player
        interval: 1500
        repeat: true
        onTriggered: {
            if (player) {
                player.positionChanged()
                cachedTitle = player.trackTitle || cachedTitle
                cachedArtist = player.trackArtist || cachedArtist
                cachedArtUrl = player.trackArtUrl || cachedArtUrl
                cachedPosition = player.position
                if (player.loopState === MprisLoopState.None) cachedLoopState = 0;
                else if (player.loopState === MprisLoopState.Track) cachedLoopState = 1;
                else if (player.loopState === MprisLoopState.Playlist) cachedLoopState = 2;
            }
        }
    }

    Component.onCompleted: {
        if (player) {
            cachedTitle = player.trackTitle || ""
            cachedArtist = player.trackArtist || ""
            cachedArtUrl = player.trackArtUrl || ""
        }
    }

    Rectangle {
        id: background
        implicitHeight: contentColumn.implicitHeight + 20
        implicitWidth: Math.max(280, contentColumn.implicitWidth + 20)

        readonly property int artSideMargin: 10
        readonly property int artSize: implicitWidth - (artSideMargin * 2)
        color: ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.2)
        radius: Appearance.rounding.normal

        Image {
            id: blurredBg
            anchors.fill: parent
            source: root.wallpaperPath
            sourceSize.width: background.width * root.wallpaperScale
            sourceSize.height: background.height * root.wallpaperScale
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: true

            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: blurredBg
            }
        }

        Rectangle {
            anchors.fill: parent
            color: ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.15)
            radius: background.radius
        }

        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: background.artSize
                Layout.preferredHeight: Layout.preferredWidth
                radius: 12
                color: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.5)

                StyledImage {
                    id: albumImage
                    anchors.fill: parent
                    source: cachedArtUrl
                    fillMode: Image.PreserveAspectCrop

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: albumImage.width
                            height: albumImage.height
                            radius: 12
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSecondaryContainer
                    elide: Text.ElideRight
                    text: cachedTitle.length > 0 ? StringUtils.cleanMusicTitle(cachedTitle) : Translation.tr("No media")
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: cachedArtist
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 20

                StyledSlider {
                    anchors.fill: parent
                    configuration: StyledSlider.Configuration.Wavy
                    highlightColor: Appearance.colors.colPrimary
                    trackColor: Appearance.colors.colSecondaryContainer
                    handleColor: Appearance.colors.colPrimary
                    usePercentTooltip: false
                    value: player && player.length > 0 ? (player.position / player.length) : 0
                    onMoved: {
                        if (player && player.length > 0) {
                            player.position = value * player.length;
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Item { width: 28 }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: player && (player.shuffle = !player.shuffle)

                    colBackground: player && player.shuffle ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover

                    contentItem: MaterialSymbol {
                        iconSize: 18
                        fill: player && player.shuffle ? 1 : 0.3
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: player && player.shuffle ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                        text: "shuffle"
                    }
                }

                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: {
                        if (player) {
                            if (player.position < 3) {
                                player.previous();
                            } else {
                                player.position = 0;
                            }
                        }
                    }

                    colBackground: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover

                    contentItem: MaterialSymbol {
                        iconSize: 22
                        fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Appearance.colors.colOnSecondaryContainer
                        text: "skip_previous"
                    }
                }

                RippleButton {
                    implicitWidth: 44
                    implicitHeight: 44
                    onClicked: player?.togglePlaying()

                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover

                    contentItem: MaterialSymbol {
                        iconSize: 28
                        fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Appearance.colors.colOnPrimary
                        text: player && player.isPlaying ? "pause" : "play_arrow"
                    }
                }

                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: player?.next()

                    colBackground: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover

                    contentItem: MaterialSymbol {
                        iconSize: 22
                        fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Appearance.colors.colOnSecondaryContainer
                        text: "skip_next"
                    }
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    enabled: false

                    colBackground: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.5)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.5)

                    contentItem: MaterialSymbol {
                        iconSize: 18
                        fill: 0.3
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnSecondaryContainer, 0.4)
                        text: "repeat"
                    }
                }

                Item { width: 32 }
            }

            Item { Layout.preferredHeight: 5 }
        }
    }
}
