pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live network traffic service: upload/download speeds from /proc/net/dev.
 */
Singleton {
    id: root

    property real uploadSpeed: 0      // bytes/sec
    property real downloadSpeed: 0    // bytes/sec
    property string localIp: ""
    property var prevTotals: null     // { rx, tx, ts }

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> uploadHistory: []
    property list<real> downloadHistory: []
    property list<real> uploadHistoryNorm: []
    property list<real> downloadHistoryNorm: []
    property list<var> topProcesses: []
    property var nethogsBlock: []

    function parseNethogsBlock(lines) {
        // Format: program/pid/uid\tsent_kbps\trecv_kbps
        const processes = []
        for (const line of lines) {
            const parts = line.split('\t').map(s => s.trim())
            if (parts.length < 3) continue
            const programId = parts[0]
            if (programId.startsWith("unknown")) continue
            const sent = parseFloat(parts[1])
            const recv = parseFloat(parts[2])
            if (isNaN(sent) || isNaN(recv)) continue
            // Extract name: strip numeric PID/UID segments from path
            const segments = programId.split('/').filter(s => s && isNaN(parseInt(s)))
            const name = segments[segments.length - 1] || programId
            if (!name) continue
            processes.push({ name, sent, recv, total: sent + recv })
        }
        processes.sort((a, b) => b.total - a.total)
        root.topProcesses = processes.slice(0, 1)
    }

    function formatSpeed(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024)    return Math.round(bps / 1024) + " KB/s"
        return Math.round(bps) + " B/s"
    }

    function updateHistories() {
        uploadHistory = [...uploadHistory.slice(-(historyLength - 1)), uploadSpeed]
        downloadHistory = [...downloadHistory.slice(-(historyLength - 1)), downloadSpeed]

        const maxUp = Math.max(1, ...uploadHistory)
        const maxDown = Math.max(1, ...downloadHistory)
        uploadHistoryNorm = uploadHistory.map(v => v / maxUp)
        downloadHistoryNorm = downloadHistory.map(v => v / maxDown)
    }

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            fileNetDev.reload()

            const now = Date.now()
            const lines = fileNetDev.text().split('\n')
            let totalRx = 0
            let totalTx = 0

            for (const line of lines) {
                const trimmed = line.trim()
                if (!trimmed || trimmed.startsWith('Inter') || trimmed.startsWith('face')) continue
                const colonIdx = trimmed.indexOf(':')
                if (colonIdx < 0) continue
                const iface = trimmed.substring(0, colonIdx).trim()
                if (iface === 'lo') continue
                const fields = trimmed.substring(colonIdx + 1).trim().split(/\s+/)
                totalRx += parseInt(fields[0]) || 0
                totalTx += parseInt(fields[8]) || 0
            }

            if (root.prevTotals) {
                const elapsed = (now - root.prevTotals.ts) / 1000
                if (elapsed > 0) {
                    root.downloadSpeed = Math.max(0, (totalRx - root.prevTotals.rx) / elapsed)
                    root.uploadSpeed   = Math.max(0, (totalTx - root.prevTotals.tx) / elapsed)
                }
            }
            root.prevTotals = { rx: totalRx, tx: totalTx, ts: now }
            root.updateHistories()

            interval = Config.options?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileNetDev; path: "/proc/net/dev" }

    // Long-running nethogs process for per-process bandwidth
    Process {
        id: nethogsProc
        command: ["nethogs", "-t", "-d", "3"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("Refreshing:")) {
                    if (root.nethogsBlock.length > 0)
                        root.parseNethogsBlock(root.nethogsBlock)
                    root.nethogsBlock = []
                } else if (line.trim() !== "") {
                    root.nethogsBlock = [...root.nethogsBlock, line]
                }
            }
        }
    }

    // Refresh local IP every 30 seconds
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: localIpProc.running = true
    }

    Process {
        id: localIpProc
        command: ["bash", "-c", "ip -4 addr | awk '/inet /{print $2}' | grep -v '^127\\.' | head -1 | cut -d/ -f1"]
        running: false
        stdout: StdioCollector {
            id: localIpOutput
            onStreamFinished: {
                const ip = localIpOutput.text.trim()
                if (ip) root.localIp = ip
                localIpProc.running = false
            }
        }
    }
}
