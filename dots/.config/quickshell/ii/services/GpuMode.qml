pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Service for managing GPU modes via supergfxctl.
 * Supports Integrated, Hybrid, and AsusMuxDgpu modes.
 */
Singleton {
    id: root

    // Current GPU mode
    property string currentMode: "Unknown"
    // Supported modes on this system
    property list<string> supportedModes: []
    // Whether supergfxctl is available
    property bool available: false
    // Pending action required (e.g., "Logout", "Reboot", etc.)
    property string pendingAction: ""
    // Pending mode change
    property string pendingMode: ""
    // Whether the GPU is currently powered on
    property string powerStatus: "Unknown"

    // Mode metadata for UI display
    readonly property var modeInfo: ({
        "Integrated": {
            icon: "memory",
            description: "Use integrated GPU only (power saving)",
            requiresLogout: true
        },
        "Hybrid": {
            icon: "swap_horiz",
            description: "Use iGPU with dGPU on-demand (recommended)",
            requiresLogout: true
        },
        "AsusMuxDgpu": {
            icon: "developer_board",
            description: "Use dedicated GPU directly (MUX switch)",
            requiresLogout: true
        },
        "NvidiaNoModeset": {
            icon: "videocam_off",
            description: "Nvidia without display output",
            requiresLogout: true
        },
        "Vfio": {
            icon: "devices",
            description: "GPU passthrough for VMs",
            requiresLogout: true
        },
        "AsusEgpu": {
            icon: "dock",
            description: "External GPU mode",
            requiresLogout: true
        },
        "Unknown": {
            icon: "help",
            description: "Unknown GPU mode",
            requiresLogout: false
        }
    })

    // Check if switching to a mode requires logout
    function requiresLogout(targetMode: string): bool {
        // Most GPU mode switches require logout
        return modeInfo[targetMode]?.requiresLogout ?? true
    }

    // Get icon for a mode
    function getIconForMode(mode: string): string {
        return modeInfo[mode]?.icon ?? "developer_board"
    }

    // Get description for a mode
    function getDescriptionForMode(mode: string): string {
        return modeInfo[mode]?.description ?? mode
    }

    // Set GPU mode
    function setMode(mode: string): void {
        if (!supportedModes.includes(mode)) {
            console.warn("GpuMode: Unsupported mode:", mode)
            return
        }
        setModeProcess.command = ["supergfxctl", "-m", mode]
        setModeProcess.running = true
    }

    // Cycle to next mode
    function cycleMode(): void {
        if (supportedModes.length === 0) return
        const currentIndex = supportedModes.indexOf(currentMode)
        const nextIndex = (currentIndex + 1) % supportedModes.length
        setMode(supportedModes[nextIndex])
    }

    // Refresh all GPU state
    function refresh(): void {
        getModeProcess.running = true
        getSupportedProcess.running = true
        getPendingActionProcess.running = true
        getPendingModeProcess.running = true
        getPowerStatusProcess.running = true
    }

    reloadableId: "gpumode"

    Component.onCompleted: {
        checkAvailableProcess.running = true
    }

    // Check if supergfxctl is available
    Process {
        id: checkAvailableProcess
        command: ["which", "supergfxctl"]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0)
            if (root.available) {
                root.refresh()
            }
        }
    }

    // Get current mode
    Process {
        id: getModeProcess
        command: ["supergfxctl", "-g"]
        stdout: SplitParser {
            onRead: data => {
                root.currentMode = data.trim()
            }
        }
    }

    // Get supported modes
    Process {
        id: getSupportedProcess
        command: ["supergfxctl", "-s"]
        stdout: SplitParser {
            onRead: data => {
                // Output format: [Integrated, Hybrid, AsusMuxDgpu]
                const cleaned = data.trim().replace(/[\[\]]/g, "")
                root.supportedModes = cleaned.split(",").map(m => m.trim()).filter(m => m.length > 0)
            }
        }
    }

    // Get pending action
    Process {
        id: getPendingActionProcess
        command: ["supergfxctl", "-p"]
        stdout: SplitParser {
            onRead: data => {
                const action = data.trim()
                root.pendingAction = (action === "No action required" || action === "None") ? "" : action
            }
        }
    }

    // Get pending mode
    Process {
        id: getPendingModeProcess
        command: ["supergfxctl", "-P"]
        stdout: SplitParser {
            onRead: data => {
                const mode = data.trim()
                root.pendingMode = (mode === "Unknown" || mode === "None") ? "" : mode
            }
        }
    }

    // Get power status
    Process {
        id: getPowerStatusProcess
        command: ["supergfxctl", "-S"]
        stdout: SplitParser {
            onRead: data => {
                root.powerStatus = data.trim()
            }
        }
    }

    // Set mode process
    Process {
        id: setModeProcess
        onExited: (exitCode, exitStatus) => {
            // Refresh state after mode change attempt
            root.refresh()
        }
    }

    // Periodic refresh timer
    Timer {
        interval: 5000
        running: root.available
        repeat: true
        onTriggered: root.refresh()
    }
}
