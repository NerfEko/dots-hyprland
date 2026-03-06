import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 500

    // Parsed state
    property string activeConnection: ""
    property var servers: []
    property bool loading: true

    onVisibleChanged: if (visible) refreshTimer.restart()

    Timer {
        id: refreshTimer
        interval: 5000
        running: root.visible
        repeat: true
        onTriggered: fetchStatus.running = true
        Component.onCompleted: fetchStatus.running = true
    }

    Process {
        id: fetchStatus
        running: true
        command: ["bash", "/home/eko/.config/ags/scripts/protonvpn/vpn_status.sh"]
        stdout: StdioCollector {
            id: statusCollector
            onStreamFinished: {
                try {
                    const data = JSON.parse(statusCollector.text.trim())
                    root.activeConnection = data.active || ""
                    root.servers = data.servers || []
                } catch (e) {
                    root.servers = []
                }
                root.loading = false
            }
        }
    }

    WindowDialogTitle {
        text: Translation.tr("ProtonVPN")
    }

    StyledIndeterminateProgressBar {
        visible: root.loading
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }

    WindowDialogSeparator {
        visible: !root.loading
    }

    ListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0

        model: root.servers
        delegate: VpnServerItem {
            required property var modelData
            serverName: modelData.name      ?? ""
            city:       modelData.city      ?? ""
            country:    modelData.country   ?? ""
            load:       modelData.load      ?? 0
            fastest:    modelData.fastest   ?? false
            connected:  modelData.name      === root.activeConnection
            width: ListView.view.width
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        Item { Layout.fillWidth: true }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
