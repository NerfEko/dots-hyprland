import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell

QuickToggleButton {
    id: root
    buttonIcon: "aspect_ratio"
    toggled: false

    onClicked: {
        Quickshell.execDetached(["/home/eko/.config/hypr/scripts/toggle-display-mode.sh"])
    }

    StyledToolTip {
        text: Translation.tr("Toggle Display Mode")
    }
}