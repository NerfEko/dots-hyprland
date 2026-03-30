pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, CPU, and GPU usage.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property real gpuUsage: 0
    property real cpuFrequency: 0
    property real gpuVramTotal: 0
    property real gpuVramUsed: 0
    property int installedPackages: -1
    property int updatablePackages: -1

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"
    property string cpuModel: "--"
    property string cpuCores: "--"
    property string gpuModel: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []
    property list<real> gpuUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateGpuUsageHistory() {
        gpuUsageHistory = [...gpuUsageHistory, gpuUsage]
        if (gpuUsageHistory.length > historyLength) {
            gpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateGpuUsageHistory()
    }

	Timer {
		interval: 1
        running: true
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()
            fileGpuUsage.reload()
            fileCpuFreq.reload()
            fileGpuVramTotal.reload()
            fileGpuVramUsed.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // Parse GPU usage (AMD)
            const textGpuUsage = fileGpuUsage.text()
            const gpuUsageValue = parseInt(textGpuUsage.trim())
            if (!isNaN(gpuUsageValue)) {
                gpuUsage = gpuUsageValue / 100.0
            }

            // Parse CPU frequency (kHz -> GHz)
            const freqKHz = parseInt(fileCpuFreq.text().trim())
            if (!isNaN(freqKHz) && freqKHz > 0) {
                cpuFrequency = freqKHz / 1000000.0
            }

            // Parse GPU VRAM (bytes -> KB)
            const vramTotalBytes = parseInt(fileGpuVramTotal.text().trim())
            if (!isNaN(vramTotalBytes) && vramTotalBytes > 0) {
                gpuVramTotal = vramTotalBytes / 1024
            }
            const vramUsedBytes = parseInt(fileGpuVramUsed.text().trim())
            if (!isNaN(vramUsedBytes) && vramUsedBytes >= 0) {
                gpuVramUsed = vramUsedBytes / 1024
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    FileView { id: fileGpuUsage; path: "/sys/class/drm/card1/device/gpu_busy_percent" }
    FileView { id: fileCpuFreq; path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" }
    FileView { id: fileGpuVramTotal; path: "/sys/class/drm/card1/device/mem_info_vram_total" }
    FileView { id: fileGpuVramUsed; path: "/sys/class/drm/card1/device/mem_info_vram_used" }

    // Package counts - refresh every 10 minutes
    Timer {
        interval: 600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            installedPackagesProc.running = true
            updatablePackagesProc.running = true
        }
    }

    Process {
        id: installedPackagesProc
        command: ["bash", "-c", "pacman -Qq 2>/dev/null | wc -l"]
        running: false
        stdout: StdioCollector {
            id: installedPkgOutput
            onStreamFinished: {
                const n = parseInt(installedPkgOutput.text.trim())
                if (!isNaN(n)) root.installedPackages = n
                installedPackagesProc.running = false
            }
        }
    }

    Process {
        id: updatablePackagesProc
        command: ["bash", "-c", "yay -Qu 2>/dev/null | wc -l"]
        running: false
        stdout: StdioCollector {
            id: updatablePkgOutput
            onStreamFinished: {
                const n = parseInt(updatablePkgOutput.text.trim())
                root.updatablePackages = isNaN(n) ? 0 : n
                updatablePackagesProc.running = false
            }
        }
    }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }

    Process {
        id: findCpuModelProc
        command: ["bash", "-c", "grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//;s/^AMD //;s/^Intel(R) //;s/ with Radeon Graphics//;s/ CPU @ .*//' | xargs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuModel = text.trim() || "--"
            }
        }
    }

    Process {
        id: findCpuCoresProc
        command: ["bash", "-c", "nproc"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuCores = text.trim() || "--"
            }
        }
    }

    Process {
        id: findGpuModelProc
        command: ["bash", "-c", "lspci | grep -i 'vga\\|3d\\|display' | head -1 | cut -d: -f3 | sed 's/.*\\[\\(.*\\)\\].*/\\1/;s/^AMD.ATI //;s/^AMD //' | xargs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.gpuModel = text.trim() || "--"
            }
        }
    }
}
