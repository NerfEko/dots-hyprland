import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Io
import Quickshell

QuickToggleButton {
    id: root
    toggled: false
    buttonIcon: "shield"

    property string activeConnection: ""

    altAction: () => {
        openVpnDialog();
    }

    signal openVpnDialog()

    onClicked: {
        if (toggled) {
            Quickshell.execDetached(["nmcli", "device", "disconnect", "proton0"])
        } else {
            if (activeConnection !== "") {
                Quickshell.execDetached(["nmcli", "connection", "up", activeConnection])
            } else {
                // Connect to the most recently used ProtonVPN connection
                Quickshell.execDetached([
                    "bash", "-c",
                    "nmcli -t -f NAME,TYPE,TIMESTAMP connection show | grep wireguard | grep '^ProtonVPN ' | sort -t: -k3 -rn | head -1 | cut -d: -f1 | xargs -I{} nmcli connection up '{}'"
                ])
            }
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

    StyledToolTip {
        text: root.toggled
            ? Translation.tr("ProtonVPN: %1\nLMB disconnect · RMB server list").arg(root.activeConnection)
            : Translation.tr("ProtonVPN: disconnected\nLMB connect · RMB server list")
    }
}
