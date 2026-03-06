import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

QuickToggleModel {
    id: root
    name: Translation.tr("ProtonVPN")
    icon: "shield"
    hasMenu: true
    hasStatusText: true

    toggled: false
    statusText: toggled ? activeConnection.replace("ProtonVPN ", "") : Translation.tr("Off")

    property string activeConnection: ""

    mainAction: () => {
        if (toggled) {
            Quickshell.execDetached(["protonvpn", "disconnect"])
        } else {
            Quickshell.execDetached(["protonvpn", "connect"])
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: fetchActiveState.running = true
    }

    Process {
        id: fetchActiveState
        running: true
        command: ["bash", "-c", "nmcli -t -f NAME,TYPE connection show --active | grep ':wireguard$'"]
        stdout: StdioCollector {
            id: activeStateCollector
            onStreamFinished: {
                const lines = activeStateCollector.text.trim().split("\n").filter(l => l.startsWith("ProtonVPN "))
                if (lines.length > 0) {
                    root.toggled = true
                    root.activeConnection = lines[0].replace(/:wireguard$/, "").trim()
                } else {
                    root.toggled = false
                    root.activeConnection = ""
                }
            }
        }
    }

    tooltipText: root.toggled
        ? Translation.tr("ProtonVPN: %1").arg(root.activeConnection)
        : Translation.tr("ProtonVPN: disconnected")
}
