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
    property string cachedAlbum: ""
    property int cachedLoopState: 0
    property real cachedPosition: 0

    property string artUrl: ""
    property string lastArtFetchTitle: ""
    property string hdArtUrl: artUrl ? artUrl.replace(/\/\d+x\d+[a-z]+\.[a-z]+$/, '/512x512bb.jpg') : ""
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(hdArtUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property string artImageSource: ""

    function fetchArtUrl() {
        artUrlFetcher.running = true
    }

    Process {
        id: artUrlFetcher
        command: ["bash", "-c", "url=$(playerctl metadata xesam:artUrl 2>/dev/null); [ -z \"$url\" ] && url=$(playerctl metadata mpris:artUrl 2>/dev/null); printf '%s' \"$url\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const url = text.trim()
                if (root.artUrl !== url) root.artUrl = url
            }
        }
    }

    onArtUrlChanged: {
        if (hdArtUrl.length === 0) { root.artImageSource = ""; return; }
        root.artImageSource = ""
        const target = hdArtUrl
        const path = root.artFilePath
        coverArtDownloader.running = false
        coverArtDownloader.command = ["bash", "-c",
            `[ -f '${path}' ] || { curl -sSL '${target}' -o '${path}.tmp' && mv '${path}.tmp' '${path}' || { rm -f '${path}.tmp'; exit 1; }; }; printf '%s' '${path}'`
        ]
        coverArtDownloader.running = true
    }

    Process {
        id: coverArtDownloader
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length > 0) root.artImageSource = "file://" + path
            }
        }
    }

    onPlayerChanged: {
        if (player) {
            cachedTitle = player.trackTitle || cachedTitle
            cachedArtist = player.trackArtist || cachedArtist
            cachedAlbum = player.album || cachedAlbum
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
                cachedAlbum = player.album || cachedAlbum
            }
            root.fetchArtUrl()
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
                cachedAlbum = player.album || cachedAlbum
                cachedPosition = player.position
                if (player.loopState === MprisLoopState.None) cachedLoopState = 0;
                else if (player.loopState === MprisLoopState.Track) cachedLoopState = 1;
                else if (player.loopState === MprisLoopState.Playlist) cachedLoopState = 2;
            }
            const title = cachedTitle
            if (title.length > 0 && title !== root.lastArtFetchTitle) {
                root.lastArtFetchTitle = title
                root.fetchArtUrl()
            }
        }
    }

    Component.onCompleted: {
        if (player) {
            cachedTitle = player.trackTitle || ""
            cachedArtist = player.trackArtist || ""
            cachedAlbum = player.album || ""
        }
        root.fetchArtUrl()
    }

    Rectangle {
        id: background
        implicitHeight: contentColumn.implicitHeight + 30
        implicitWidth: Math.max(280, contentColumn.implicitWidth + 40)
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
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 22
            anchors.bottomMargin: 18
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 10

            Item {
                id: artItem
                Layout.fillWidth: true
                implicitHeight: artImageSource.length > 0 ? width : 0
                clip: true

                Rectangle {
                    id: artContainer
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.5)

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artContainer.width
                            height: artContainer.height
                            radius: artContainer.radius
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        source: root.artImageSource
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        sourceSize.width: artContainer.width
                        sourceSize.height: artContainer.height
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSecondaryContainer
                    elide: Text.ElideRight
                    text: cachedTitle.length > 0 ? StringUtils.cleanMusicTitle(cachedTitle) : Translation.tr("No media")
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSecondaryContainer
                    elide: Text.ElideRight
                    text: cachedArtist
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: cachedAlbum
                    horizontalAlignment: Text.AlignHCenter
                    visible: cachedAlbum && cachedAlbum.length > 0
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
                    trackDotSize: 0
                    stopIndicatorValues: []
                    usePercentTooltip: false
                    showTooltip: false
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
