pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    property string filePath: `${Directories.assetsPath}/themes/ghostty/catalog.json`
    property var catalog: ({})
    property var importedThemes: []

    function legacySwatches(value) {
        switch (value) {
        case "auto":
            return root.reactiveResolvedTheme?.previewColors ?? ["#1e1e2e", "#89b4fa", "#f38ba8", "#a6e3a1", "#cdd6f4"];
        case "dracula":
            return ["#282a36", "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2"];
        case "dracula-plus":
            return ["#212121", "#82aaff", "#c792ea", "#ffcb6b", "#f8f8f2"];
        case "scheme-content":
            return ["#1f1b24", "#6750a4", "#625b71", "#7d5260", "#f4eff4"];
        case "scheme-expressive":
            return ["#1d1b20", "#b58392", "#7b8f6a", "#8f6d8f", "#f1eef4"];
        case "scheme-fidelity":
            return ["#171c22", "#7fc8ff", "#b8c4ff", "#d6b7ff", "#edf3fa"];
        case "scheme-fruit-salad":
            return ["#201a18", "#6fbd44", "#d0a53a", "#c96f5d", "#f5efe9"];
        case "scheme-monochrome":
            return ["#1b1b1f", "#c6c6d0", "#9e9ea6", "#7b7b84", "#f5f5fa"];
        case "scheme-neutral":
            return ["#201f24", "#a8a0b3", "#c3bccc", "#8b8695", "#f5eff7"];
        case "scheme-rainbow":
            return ["#1c1b1f", "#ff6b6b", "#ffd93d", "#6bcBef", "#f7f2fa"];
        case "scheme-tonal-spot":
            return ["#201f24", "#65558f", "#625b71", "#7d5260", "#f5eff7"];
        default:
            return ["#1e1e2e", "#89b4fa", "#f38ba8", "#a6e3a1", "#cdd6f4"];
        }
    }

    readonly property var legacyOptions: [
        { "mode": "legacy-palette", "value": "auto", "displayName": Translation.tr("Legacy: Auto"), "icon": "history", "swatches": root.legacySwatches("auto") },
        { "mode": "legacy-palette", "value": "dracula", "displayName": Translation.tr("Legacy: Dracula"), "icon": "history", "swatches": root.legacySwatches("dracula") },
        { "mode": "legacy-palette", "value": "dracula-plus", "displayName": Translation.tr("Legacy: Dracula+"), "icon": "history", "swatches": root.legacySwatches("dracula-plus") },
        { "mode": "legacy-palette", "value": "scheme-content", "displayName": Translation.tr("Legacy: Content"), "icon": "history", "swatches": root.legacySwatches("scheme-content") },
        { "mode": "legacy-palette", "value": "scheme-expressive", "displayName": Translation.tr("Legacy: Expressive"), "icon": "history", "swatches": root.legacySwatches("scheme-expressive") },
        { "mode": "legacy-palette", "value": "scheme-fidelity", "displayName": Translation.tr("Legacy: Fidelity"), "icon": "history", "swatches": root.legacySwatches("scheme-fidelity") },
        { "mode": "legacy-palette", "value": "scheme-fruit-salad", "displayName": Translation.tr("Legacy: Fruit Salad"), "icon": "history", "swatches": root.legacySwatches("scheme-fruit-salad") },
        { "mode": "legacy-palette", "value": "scheme-monochrome", "displayName": Translation.tr("Legacy: Monochrome"), "icon": "history", "swatches": root.legacySwatches("scheme-monochrome") },
        { "mode": "legacy-palette", "value": "scheme-neutral", "displayName": Translation.tr("Legacy: Neutral"), "icon": "history", "swatches": root.legacySwatches("scheme-neutral") },
        { "mode": "legacy-palette", "value": "scheme-rainbow", "displayName": Translation.tr("Legacy: Rainbow"), "icon": "history", "swatches": root.legacySwatches("scheme-rainbow") },
        { "mode": "legacy-palette", "value": "scheme-tonal-spot", "displayName": Translation.tr("Legacy: Tonal Spot"), "icon": "history", "swatches": root.legacySwatches("scheme-tonal-spot") }
    ]

    readonly property bool available: importedThemes.length > 0
    readonly property var reactiveResolvedTheme: importedThemeById(Config.options.appearance.theme.resolvedId)
    readonly property string reactiveStatusText: reactiveResolvedTheme ? Translation.tr("Matched: %1").arg(reactiveResolvedTheme.displayName) : Translation.tr("Match updates when wallpaper changes")

    readonly property var options: {
        const imported = root.importedThemes.map(theme => ({
            "mode": "imported",
            "value": theme.id,
            "displayName": theme.displayName,
            "icon": theme.isDark ? "dark_mode" : "light_mode",
            "swatches": theme.previewColors ?? [],
            "helperText": theme.sourceName,
        }));

        return [
            {
                "mode": "reactive-wallpaper",
                "value": "reactive-wallpaper",
                "displayName": Translation.tr("Reactive wallpaper"),
                "icon": "wallpaper",
                "swatches": root.reactiveResolvedTheme?.previewColors ?? [],
                "helperText": root.reactiveStatusText,
            },
            ...imported,
            ...root.legacyOptions,
        ];
    }

    function importedThemeById(id) {
        for (const theme of root.importedThemes) {
            if (theme.id === id) return theme;
        }
        return null;
    }

    function currentOption() {
        const mode = Config.options.appearance.theme.mode;
        if (mode === "imported") {
            const importedTheme = importedThemeById(Config.options.appearance.theme.selectedId);
            if (importedTheme) {
                return {
                    "mode": "imported",
                    "value": importedTheme.id,
                    "displayName": importedTheme.displayName,
                    "icon": importedTheme.isDark ? "dark_mode" : "light_mode",
                    "swatches": importedTheme.previewColors ?? [],
                    "helperText": importedTheme.sourceName,
                };
            }
        }

        if (mode === "reactive-wallpaper") {
            return {
                "mode": "reactive-wallpaper",
                "value": "reactive-wallpaper",
                "displayName": Translation.tr("Reactive wallpaper"),
                "icon": "wallpaper",
                "swatches": root.reactiveResolvedTheme?.previewColors ?? [],
                "helperText": root.reactiveStatusText,
            };
        }

        const legacy = root.legacyOptions.find(option => option.value === Config.options.appearance.palette.type);
        return legacy ?? root.legacyOptions[0];
    }

    function currentOptionIndex() {
        const current = currentOption();
        return root.options.findIndex(option => option.mode === current.mode && option.value === current.value);
    }

    function reload() {
        fileView.reload();
    }

    Component.onCompleted: reload()

    FileView {
        id: fileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true

        onLoaded: {
            const parsed = JSON.parse(fileView.text());
            root.catalog = parsed;
            root.importedThemes = parsed.themes ?? [];
        }

        onLoadFailed: {
            root.catalog = ({ "themes": [] });
            root.importedThemes = [];
        }
    }
}
