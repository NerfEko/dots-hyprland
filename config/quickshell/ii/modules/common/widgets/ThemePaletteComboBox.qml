pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

StyledComboBox {
    id: root

    property string searchText: ""
    readonly property var currentItemData: (root.currentIndex >= 0 && Array.isArray(root.model) && root.currentIndex < root.model.length) ? root.model[root.currentIndex] : null
    readonly property var filteredItems: {
        const source = Array.isArray(root.model) ? root.model : [];
        const query = root.searchText.trim().toLowerCase();
        return source
            .map((item, index) => ({
                originalIndex: index,
                data: item,
            }))
            .filter(entry => {
                if (!query.length) return true;
                const name = String(entry.data?.displayName ?? "").toLowerCase();
                const helper = String(entry.data?.helperText ?? "").toLowerCase();
                const value = String(entry.data?.value ?? "").toLowerCase();
                return name.includes(query) || helper.includes(query) || value.includes(query);
            });
    }

    implicitWidth: 420

    function swatchesFor(item) {
        return item && Array.isArray(item.swatches) ? item.swatches : [];
    }

    function selectOriginalIndex(index) {
        if (index < 0)
            return;
        root.popup.close();
        root.searchText = "";
        root.activated(index);
    }

    contentItem: Item {
        implicitWidth: buttonLayout.implicitWidth
        implicitHeight: buttonLayout.implicitHeight

        RowLayout {
            id: buttonLayout
            anchors.fill: parent
            spacing: 10
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Loader {
                Layout.alignment: Qt.AlignVCenter
                active: !!root.currentItemData?.icon
                visible: active
                sourceComponent: MaterialSymbol {
                    text: root.currentItemData?.icon ?? ""
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                color: Appearance.colors.colOnSecondaryContainer
                text: root.currentItemData?.displayName ?? root.displayText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 5
                visible: repeater.count > 0

                Repeater {
                    id: repeater
                    model: root.swatchesFor(root.currentItemData).slice(0, 5)
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 999
                        color: modelData
                        border.width: 1
                        border.color: ColorUtils.mix(color, Appearance.colors.colOnSecondaryContainer, 0.45)
                    }
                }
            }
        }
    }

    popup: Popup {
        y: root.height + 4
        width: Math.max(root.width, 420)
        height: 420
        padding: 8

        onOpened: searchField.forceActiveFocus()
        onClosed: root.searchText = ""

        enter: Transition {
            PropertyAnimation {
                properties: "opacity"
                to: 1
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        exit: Transition {
            PropertyAnimation {
                properties: "opacity"
                to: 0
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        background: Item {
            StyledRectangularShadow {
                target: popupBackground
            }

            Rectangle {
                id: popupBackground
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainerHigh
            }
        }

        contentItem: Item {
            implicitWidth: contentLayout.implicitWidth
            implicitHeight: contentLayout.implicitHeight

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                spacing: 8

                MaterialTextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Search themes")
                    text: root.searchText
                    onTextChanged: root.searchText = text
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.filteredItems.length === 0
                    text: Translation.tr("No themes matched your search")
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.Wrap
                }

                StyledListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: root.filteredItems

                    delegate: ItemDelegate {
                    id: itemDelegate
                    required property var modelData
                    readonly property var itemData: modelData.data
                    readonly property int originalIndex: modelData.originalIndex

                    width: ListView.view ? ListView.view.width : root.width
                    implicitHeight: 56

                    property color rowColor: {
                        if (root.currentIndex === itemDelegate.originalIndex) {
                            if (itemDelegate.down) return Appearance.colors.colSecondaryContainerActive;
                            if (itemDelegate.hovered) return Appearance.colors.colSecondaryContainerHover;
                            return Appearance.colors.colSecondaryContainer;
                        }
                        if (itemDelegate.down) return Appearance.colors.colLayer3Active;
                        if (itemDelegate.hovered) return Appearance.colors.colLayer3Hover;
                        return ColorUtils.transparentize(Appearance.colors.colLayer3);
                    }
                    property color rowText: root.currentIndex === itemDelegate.originalIndex ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer3

                    onClicked: root.selectOriginalIndex(itemDelegate.originalIndex)

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: itemDelegate.rowColor

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Loader {
                            Layout.alignment: Qt.AlignVCenter
                            active: !!itemDelegate.itemData?.icon
                            visible: active
                            sourceComponent: MaterialSymbol {
                                text: itemDelegate.itemData?.icon ?? ""
                                iconSize: Appearance.font.pixelSize.large
                                color: itemDelegate.rowText
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                color: itemDelegate.rowText
                                text: itemDelegate.itemData?.displayName ?? ""
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !!itemDelegate.itemData?.helperText
                                color: ColorUtils.mix(itemDelegate.rowText, itemDelegate.rowColor, 0.35)
                                text: itemDelegate.itemData?.helperText ?? ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 5
                            visible: swatchRepeater.count > 0

                            Repeater {
                                id: swatchRepeater
                                model: root.swatchesFor(itemDelegate.itemData).slice(0, 5)
                                delegate: Rectangle {
                                    required property var modelData
                                    implicitWidth: 12
                                    implicitHeight: 12
                                    radius: 999
                                    color: modelData
                                    border.width: 1
                                    border.color: ColorUtils.mix(color, itemDelegate.rowText, 0.4)
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }
}
