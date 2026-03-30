import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("OLED Mode")
    tooltipText: Translation.tr("OLED Mode | Blackens UI elements to protect OLED display")
    icon: "screen_lock_portrait"
    toggled: Config.options.oledMode.enable

    mainAction: () => {
        Config.options.oledMode.enable = !Config.options.oledMode.enable;
    }
    hasMenu: false
}
