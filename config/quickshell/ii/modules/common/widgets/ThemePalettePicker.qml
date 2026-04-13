pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property var model: []
    property int currentIndex: -1
    property int previewIndex: currentIndex
    property string dialogTitle: Translation.tr("Themes")
    property string searchText: ""

    readonly property var currentOption: (Array.isArray(root.model) && root.currentIndex >= 0 && root.currentIndex < root.model.length) ? root.model[root.currentIndex] : null
    readonly property var previewOption: (Array.isArray(root.model) && root.previewIndex >= 0 && root.previewIndex < root.model.length) ? root.model[root.previewIndex] : root.currentOption
    readonly property var filteredItems: {
        const source = Array.isArray(root.model) ? root.model : [];
        const query = root.searchText.trim().toLowerCase();
        return source
            .map((item, index) => ({ originalIndex: index, data: item }))
            .filter(entry => {
                if (!query.length) return true;
                const name = String((entry.data && entry.data.displayName) || "").toLowerCase();
                const helper = String((entry.data && entry.data.helperText) || "").toLowerCase();
                const value = String((entry.data && entry.data.value) || "").toLowerCase();
                return name.includes(query) || helper.includes(query) || value.includes(query);
            });
    }

    signal picked(int index)

    implicitHeight: openButton.implicitHeight

    function swatchesFor(item) {
        return item && Array.isArray(item.swatches) ? item.swatches.slice(0, 5) : [];
    }

    function previewBackground(item) {
        const swatches = swatchesFor(item);
        return swatches.length > 0 ? swatches[0] : Appearance.colors.colLayer2;
    }

    function previewForeground(item) {
        const swatches = swatchesFor(item);
        return swatches.length > 4 ? swatches[4] : Appearance.colors.colOnLayer2;
    }

    function updatePreview(index) {
        if (index >= 0 && Array.isArray(root.model) && index < root.model.length)
            root.previewIndex = index;
    }

    function stripeWidth(totalWidth, count, spacing, minWidth) {
        if (count <= 0)
            return 0;
        return Math.max(minWidth, Math.floor((totalWidth - spacing * (count - 1)) / count));
    }

    function choose(index) {
        root.updatePreview(index);
        browser.close();
        root.searchText = "";
        root.picked(index);
    }

    RippleButton {
        id: openButton
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: 68
        buttonRadius: Appearance.rounding.normal
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        onClicked: {
            root.previewIndex = root.currentIndex;
            browser.open();
        }

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 42
                radius: Appearance.rounding.small
                color: root.previewBackground(root.currentOption)
                border.width: 1
                border.color: ColorUtils.mix(color, root.previewForeground(root.currentOption), 0.6)

                RowLayout {
                    id: buttonSwatchRow
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    Repeater {
                        id: buttonSwatchRepeater
                        model: root.swatchesFor(root.currentOption)
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: root.stripeWidth(buttonSwatchRow.width, buttonSwatchRepeater.count, buttonSwatchRow.spacing, 6)
                            implicitHeight: buttonSwatchRow.height
                            radius: 999
                            color: modelData
                            border.width: 1
                            border.color: ColorUtils.mix(color, root.previewForeground(root.currentOption), 0.5)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.currentOption ? root.currentOption.displayName : Translation.tr("Choose theme")
                    color: Appearance.colors.colOnLayer2
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.currentOption && root.currentOption.helperText ? root.currentOption.helperText : Translation.tr("Browse imported themes, reactive mode, or legacy presets")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "palette"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer2
            }
        }
    }

    Popup {
        id: browser
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(((root.Window.window ? root.Window.window.width : 900) - 40), 980)
        height: Math.min(((root.Window.window ? root.Window.window.height : 700) - 40), 700)
        x: Math.round((root.width - width) / 2)
        y: Math.round((openButton.height - height) / 2)
        padding: 0

        onOpened: {
            root.previewIndex = root.currentIndex;
            searchField.forceActiveFocus();
        }
        onClosed: root.searchText = ""

        background: Rectangle {
            id: popupBackground
            radius: Appearance.rounding.large
            color: Appearance.m3colors.m3surfaceContainerHigh
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            StyledRectangularShadow {
                target: popupBackground
            }
        }

        contentItem: Item {
            implicitWidth: contentRow.implicitWidth + 40
            implicitHeight: contentRow.implicitHeight + 40

            RowLayout {
                id: contentRow
                anchors.fill: parent
                anchors.margins: 20
                spacing: 18

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 0.52
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        WindowDialogTitle {
                            Layout.fillWidth: true
                            text: root.dialogTitle
                        }

                        MaterialTextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Search themes")
                            text: root.searchText
                            onTextChanged: root.searchText = text
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Search or scroll through the catalog")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.filteredItems.length === 0
                            text: Translation.tr("No themes matched your search")
                            color: Appearance.colors.colSubtext
                        }

                        StyledListView {
                            id: themeList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            model: root.filteredItems

                            delegate: Rectangle {
                                id: listCard
                                required property var modelData
                                readonly property var itemData: modelData.data
                                readonly property int originalIndex: modelData.originalIndex
                                readonly property bool selected: root.currentIndex === originalIndex
                                readonly property bool previewed: root.previewIndex === originalIndex

                                width: ListView.view.width
                                implicitHeight: 86
                                radius: Appearance.rounding.normal
                                color: selected ? Appearance.colors.colSecondaryContainer : (previewed ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)
                                border.width: 1
                                border.color: selected ? Appearance.colors.colPrimary : (previewed ? Appearance.colors.colOutline : Appearance.colors.colOutlineVariant)

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.updatePreview(listCard.originalIndex)
                                    onClicked: root.choose(listCard.originalIndex)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 72
                                        Layout.preferredHeight: 46
                                        radius: Appearance.rounding.small
                                        color: root.previewBackground(listCard.itemData)
                                        border.width: 1
                                        border.color: ColorUtils.mix(color, root.previewForeground(listCard.itemData), 0.6)

                                        RowLayout {
                                            id: listSwatchRow
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 4

                                            Repeater {
                                                id: listSwatchRepeater
                                                model: root.swatchesFor(listCard.itemData)
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    implicitWidth: root.stripeWidth(listSwatchRow.width, listSwatchRepeater.count, listSwatchRow.spacing, 6)
                                                    implicitHeight: listSwatchRow.height
                                                    radius: 999
                                                    color: modelData
                                                    border.width: 1
                                                    border.color: ColorUtils.mix(color, root.previewForeground(listCard.itemData), 0.45)
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: (listCard.itemData && listCard.itemData.displayName) || ""
                                            color: listCard.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: (listCard.itemData && listCard.itemData.helperText) || ""
                                            visible: text.length > 0
                                            color: listCard.selected ? ColorUtils.mix(Appearance.colors.colOnSecondaryContainer, Appearance.colors.colSecondaryContainer, 0.3) : Appearance.colors.colSubtext
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        WindowDialogButtonRow {
                            Layout.fillWidth: true

                            Item { Layout.fillWidth: true }

                            DialogButton {
                                buttonText: Translation.tr("Close")
                                onClicked: browser.close()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 0.48
                    radius: Appearance.rounding.normal
                    color: root.previewBackground(root.previewOption)
                    border.width: 1
                    border.color: ColorUtils.mix(color, root.previewForeground(root.previewOption), 0.65)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.previewOption ? root.previewOption.displayName : Translation.tr("Theme preview")
                                    color: root.previewForeground(root.previewOption)
                                    font.pixelSize: Appearance.font.pixelSize.title
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.previewOption && root.previewOption.helperText ? root.previewOption.helperText : Translation.tr("Hover a theme to preview its colors")
                                    color: ColorUtils.mix(root.previewForeground(root.previewOption), root.previewBackground(root.previewOption), 0.3)
                                    wrapMode: Text.Wrap
                                }
                            }

                            DialogButton {
                                buttonText: (root.previewIndex === root.currentIndex) ? Translation.tr("Selected") : Translation.tr("Use theme")
                                enabled: root.previewIndex >= 0 && root.previewIndex !== root.currentIndex
                                onClicked: root.choose(root.previewIndex)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 170
                            radius: Appearance.rounding.normal
                            color: ColorUtils.mix(root.previewBackground(root.previewOption), root.previewForeground(root.previewOption), 0.92)
                            border.width: 1
                            border.color: ColorUtils.mix(color, root.previewForeground(root.previewOption), 0.7)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                StyledText {
                                    text: Translation.tr("Preview")
                                    color: root.previewForeground(root.previewOption)
                                    font.pixelSize: Appearance.font.pixelSize.large
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    radius: Appearance.rounding.small
                                    color: root.previewBackground(root.previewOption)
                                    border.width: 1
                                    border.color: ColorUtils.mix(color, root.previewForeground(root.previewOption), 0.65)

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Translation.tr("Background / surface")
                                        color: root.previewForeground(root.previewOption)
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    radius: Appearance.rounding.small
                                    color: root.swatchesFor(root.previewOption).length > 1 ? root.swatchesFor(root.previewOption)[1] : root.previewForeground(root.previewOption)
                                    border.width: 1
                                    border.color: ColorUtils.mix(color, root.previewForeground(root.previewOption), 0.6)

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Translation.tr("Accent")
                                        color: root.previewBackground(root.previewOption)
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Palette")
                                color: root.previewForeground(root.previewOption)
                                font.pixelSize: Appearance.font.pixelSize.larger
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 5
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    model: root.swatchesFor(root.previewOption)
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 64
                                        radius: Appearance.rounding.small
                                        color: modelData
                                        border.width: 1
                                        border.color: ColorUtils.mix(color, root.previewForeground(root.previewOption), 0.55)

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 6
                                            text: parent.color
                                            color: ColorUtils.mix(root.previewForeground(root.previewOption), parent.color, 0.2)
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.swatchesFor(root.previewOption).length === 0
                                text: Translation.tr("This option does not provide imported palette swatches.")
                                color: ColorUtils.mix(root.previewForeground(root.previewOption), root.previewBackground(root.previewOption), 0.3)
                                wrapMode: Text.Wrap
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
