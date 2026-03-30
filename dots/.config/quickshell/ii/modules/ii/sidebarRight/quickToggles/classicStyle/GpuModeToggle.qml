import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import Quickshell.Io

QuickToggleButton {
    id: root
    buttonIcon: GpuMode.getIconForMode(GpuMode.currentMode)
    toggled: GpuMode.currentMode !== "Hybrid"

    onClicked: {
        GpuMode.cycleMode()
    }

    StyledToolTip {
        text: Translation.tr("GPU Mode: %1").arg(GpuMode.currentMode)
    }
}
