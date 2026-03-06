import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    id: root
    name: Translation.tr("GPU Mode")
    
    // Show current mode, or pending mode if switching
    statusText: {
        if (GpuMode.pendingMode) {
            return Translation.tr("Switching to %1...").arg(GpuMode.pendingMode)
        }
        return GpuMode.currentMode
    }
    
    tooltipText: {
        let tooltip = Translation.tr("GPU Mode: %1").arg(GpuMode.currentMode)
        if (GpuMode.pendingAction) {
            tooltip += "\n" + Translation.tr("Action required: %1").arg(GpuMode.pendingAction)
        }
        tooltip += "\n" + Translation.tr("Right-click to select mode")
        return tooltip
    }
    
    // Use different icons based on current mode
    icon: GpuMode.getIconForMode(GpuMode.currentMode)
    
    // Toggled when not in Hybrid mode (default/balanced mode)
    toggled: GpuMode.currentMode !== "Hybrid"
    
    // Whether the toggle is available
    available: GpuMode.available
    
    // Main action cycles through modes
    mainAction: () => {
        GpuMode.cycleMode()
    }
    
    // Has menu for mode selection dialog
    hasMenu: true
}
