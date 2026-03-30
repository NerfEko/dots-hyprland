import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    implicitWidth: icon.implicitWidth + 8
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    property bool connected: Network.ethernet || Network.wifi
    property color iconColor: {
        if (!connected) return Appearance.colors.colError
        if (Network.ethernet) return Appearance.colors.colPrimary
        return Appearance.colors.colOnSecondaryContainer
    }

    ClippedFilledCircularProgress {
        id: icon
        anchors.centerIn: parent
        lineWidth: Appearance.rounding.unsharpen
        value: Network.ethernet ? 1.0 : (Network.wifi ? Network.networkStrength / 100 : 0)
        implicitSize: 20
        colPrimary: root.iconColor
        accountForLightBleeding: connected
        enableAnimation: false

        Item {
            anchors.centerIn: parent
            width: icon.implicitSize
            height: icon.implicitSize

            MaterialSymbol {
                anchors.centerIn: parent
                font.weight: Font.DemiBold
                fill: 1
                text: Network.materialSymbol
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSecondaryContainer
            }
        }
    }

    NetworkPopup {
        hoverTarget: root
    }
}
