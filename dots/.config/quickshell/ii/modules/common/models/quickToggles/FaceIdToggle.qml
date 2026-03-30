import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Face ID")
    tooltipText: Translation.tr("Face authentication for sudo")
    icon: "face"
    toggled: Config.options.faceId.enabled

    mainAction: () => {
        Config.options.faceId.enabled = !Config.options.faceId.enabled
    }
}
