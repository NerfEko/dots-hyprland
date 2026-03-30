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
    name: Translation.tr("Display Mode")
    toggled: false
    icon: "aspect_ratio"

    mainAction: () => {
        Quickshell.execDetached(["/home/eko/.config/hypr/scripts/toggle-display-mode.sh"])
    }

    tooltipText: Translation.tr("Toggle between ultrawide and 16:9 display modes")
}