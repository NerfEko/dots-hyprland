import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "roku"

    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight
    readonly property int buttonGap: 8
    readonly property int actionButtonSize: 50
    readonly property int navButtonSize: 58
    readonly property int centerButtonSize: 74

    readonly property var activeDevice: RokuRemote.activeDevice
    readonly property var devices: RokuRemote.availableDevices
    readonly property var selectorModel: devices.map(device => ({
        displayName: `${device.name}${device.ecpSettingMode === "limited" ? " (limited)" : ""}`,
        value: device.id,
        icon: (device.id === Config.options.background.widgets.roku.preferredDeviceId) ? "star" : "tv"
    }))

    Rectangle {
        id: background
        implicitWidth: 268
        implicitHeight: contentColumn.implicitHeight + 28
        color: ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.2)
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.2)

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

        Popup {
            id: selectorPopup
            parent: background
            x: Math.max(0, Math.min(background.width - width, selectorButton.x + selectorButton.width - width))
            y: selectorButton.y + selectorButton.height + 6
            width: Math.max(180, Math.min(220, background.width - 8))
            padding: 8
            modal: false
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            background: Item {
                StyledRectangularShadow {
                    target: selectorPopupBackground
                }

                Rectangle {
                    id: selectorPopupBackground
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainerHigh
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.25)
                }
            }

            contentItem: Column {
                spacing: 4

                Repeater {
                    model: root.selectorModel

                    delegate: RippleButton {
                        required property var modelData
                        readonly property bool isCurrent: modelData.value === (RokuRemote.activeDevice?.id ?? "")

                        width: selectorPopup.availableWidth
                        implicitHeight: 38
                        buttonRadius: Appearance.rounding.small
                        colBackground: isCurrent
                            ? Appearance.colors.colSecondaryContainer
                            : ColorUtils.transparentize(Appearance.colors.colLayer3, 1)
                        colBackgroundHover: isCurrent
                            ? Appearance.colors.colSecondaryContainerHover
                            : Appearance.colors.colLayer3Hover

                        onClicked: {
                            RokuRemote.setPreferredDeviceId(modelData.value);
                            selectorPopup.close();
                        }

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.icon ?? "tv"
                                iconSize: 18
                                color: isCurrent ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer3
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.displayName
                                elide: Text.ElideRight
                                color: isCurrent ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer3
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: Appearance.colors.colPrimary

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "tv"
                        iconSize: 18
                        fill: 1
                        color: Appearance.colors.colOnPrimary
                    }
                }

                Item {
                    Layout.fillWidth: true

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                        color: Appearance.colors.colSubtext
                        text: {
                            if (RokuRemote.isDiscovering)
                                return Translation.tr("Discovering devices...");
                            if (root.activeDevice)
                                return root.activeDevice.name;
                            return Translation.tr("No Roku TV found");
                        }
                    }
                }

                RemoteIconButton {
                    id: selectorButton
                    visible: root.devices.length > 1
                    iconName: "keyboard_arrow_down"
                    buttonSize: 30
                    onClicked: selectorPopup.visible ? selectorPopup.close() : selectorPopup.open()

                    contentRotation: selectorPopup.visible ? 180 : 0
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 5
                    color: root.activeDevice
                        ? Appearance.m3colors.m3success
                        : ColorUtils.applyAlpha(Appearance.colors.colOnSecondaryContainer, 0.35)
                }

                RemoteIconButton {
                    iconName: RokuRemote.isDiscovering ? "sync" : "refresh"
                    buttonSize: 42
                    enabled: !RokuRemote.isDiscovering
                    onClicked: RokuRemote.refreshDevices()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: !root.activeDevice

                Rectangle {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: ColorUtils.applyAlpha(Appearance.colors.colSecondaryContainer, 0.45)
                    implicitHeight: statusColumn.implicitHeight + 24

                    ColumnLayout {
                        id: statusColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.colors.colOnSecondaryContainer
                            text: RokuRemote.isDiscovering
                                ? Translation.tr("Scanning your local network for Roku TVs...")
                                : Translation.tr("No Roku TV is available right now.")
                        }

                        StyledText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.colors.colSubtext
                            text: RokuRemote.lastError.length > 0
                                ? RokuRemote.lastError
                                : Translation.tr("Make sure the TV is on the same LAN and local network control is enabled.")
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: root.activeDevice != null

                Item {
                    Layout.fillWidth: true
                    implicitHeight: remoteControls.implicitHeight

                    Column {
                        id: remoteControls
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        spacing: 10

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.buttonGap

                            RemoteIconButton {
                                iconName: "arrow_back"
                                label: Translation.tr("Back")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.back()
                            }

                            RemoteIconButton {
                                iconName: "home"
                                label: Translation.tr("Home")
                                accent: true
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.home()
                            }

                            RemoteIconButton {
                                iconName: "more_horiz"
                                label: Translation.tr("Info")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.info()
                            }
                        }

                        Grid {
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: 3
                            rowSpacing: root.buttonGap
                            columnSpacing: root.buttonGap

                            Item { implicitWidth: root.navButtonSize; implicitHeight: root.navButtonSize }

                            Item {
                                implicitWidth: root.centerButtonSize
                                implicitHeight: root.navButtonSize

                                RemoteIconButton {
                                    anchors.centerIn: parent
                                    iconName: "keyboard_arrow_up"
                                    buttonSize: root.navButtonSize
                                    onClicked: RokuRemote.up()
                                }
                            }

                            Item { implicitWidth: root.navButtonSize; implicitHeight: root.navButtonSize }

                            Item {
                                implicitWidth: root.navButtonSize
                                implicitHeight: root.centerButtonSize

                                RemoteIconButton {
                                    anchors.centerIn: parent
                                    iconName: "keyboard_arrow_left"
                                    buttonSize: root.navButtonSize
                                    onClicked: RokuRemote.left()
                                }
                            }

                            RemoteIconButton {
                                iconName: "check"
                                label: "OK"
                                accent: true
                                buttonSize: root.centerButtonSize
                                onClicked: RokuRemote.select()
                            }

                            Item {
                                implicitWidth: root.navButtonSize
                                implicitHeight: root.centerButtonSize

                                RemoteIconButton {
                                    anchors.centerIn: parent
                                    iconName: "keyboard_arrow_right"
                                    buttonSize: root.navButtonSize
                                    onClicked: RokuRemote.right()
                                }
                            }

                            Item { implicitWidth: root.navButtonSize; implicitHeight: root.navButtonSize }

                            Item {
                                implicitWidth: root.centerButtonSize
                                implicitHeight: root.navButtonSize

                                RemoteIconButton {
                                    anchors.centerIn: parent
                                    iconName: "keyboard_arrow_down"
                                    buttonSize: root.navButtonSize
                                    onClicked: RokuRemote.down()
                                }
                            }

                            Item { implicitWidth: root.navButtonSize; implicitHeight: root.navButtonSize }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.buttonGap

                            RemoteIconButton {
                                iconName: "fast_rewind"
                                label: Translation.tr("Rev")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.rewind()
                            }

                            RemoteIconButton {
                                iconName: "play_arrow"
                                label: Translation.tr("Play")
                                accent: true
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.playPause()
                            }

                            RemoteIconButton {
                                iconName: "fast_forward"
                                label: Translation.tr("Fwd")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.fastForward()
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.buttonGap

                            RemoteIconButton {
                                iconName: "replay"
                                label: Translation.tr("Replay")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.instantReplay()
                            }

                            RemoteIconButton {
                                iconName: "search"
                                label: Translation.tr("Search")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.search()
                            }

                            RemoteIconButton {
                                iconName: "power_settings_new"
                                label: Translation.tr("Power")
                                buttonSize: root.actionButtonSize
                                visible: root.activeDevice?.supportsPower ?? false
                                onClicked: RokuRemote.power()
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.buttonGap
                            visible: root.activeDevice?.supportsVolume ?? false

                            RemoteIconButton {
                                iconName: "volume_down"
                                label: Translation.tr("Vol-")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.volumeDown()
                            }

                            RemoteIconButton {
                                iconName: "volume_off"
                                label: Translation.tr("Mute")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.volumeMute()
                            }

                            RemoteIconButton {
                                iconName: "volume_up"
                                label: Translation.tr("Vol+")
                                buttonSize: root.actionButtonSize
                                onClicked: RokuRemote.volumeUp()
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colSubtext
                    visible: RokuRemote.lastError.length > 0 || RokuRemote.activeDeviceIsLimited
                    text: RokuRemote.lastError.length > 0
                        ? RokuRemote.lastError
                        : Translation.tr("Limited mode: only volume buttons work until Roku network access is set to Enabled.")
                }
            }
        }
    }

    component RemoteIconButton: RippleButton {
        id: button

        property string iconName: ""
        property string label: ""
        property bool accent: false
        property int buttonSize: 52
        property real contentRotation: 0

        implicitWidth: buttonSize
        implicitHeight: buttonSize

        colBackground: accent ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
        colBackgroundHover: accent ? Appearance.colors.colPrimaryHover : Appearance.colors.colSecondaryContainerHover

        contentItem: Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 8)
                spacing: button.label.length > 0 ? 2 : 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: button.iconName
                    iconSize: button.buttonSize >= 70 ? 28 : 24
                    fill: 1
                    color: button.accent ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                    rotation: button.contentRotation

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    visible: button.label.length > 0
                    text: button.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    color: button.accent ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                }
            }
        }
    }
}
