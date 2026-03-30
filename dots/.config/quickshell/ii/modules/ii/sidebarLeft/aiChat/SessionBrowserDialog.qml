import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 550
    backgroundWidth: 450

    property var sessions: Ai.sessionsList
    property bool loading: Ai.sessionsLoading

    onVisibleChanged: {
        if (visible) {
            Ai.listSessions();
        }
    }

    Connections {
        target: Ai
        function onSessionDeleted(sid) {
            // Trigger refresh - sessionsList binding will update
            Ai.listSessions();
        }
    }

    function formatTimeAgo(isoStr) {
        if (!isoStr) return "";
        const then = new Date(isoStr);
        const now = new Date();
        const diffMs = now - then;
        const diffMin = Math.floor(diffMs / 60000);
        if (diffMin < 1) return "just now";
        if (diffMin < 60) return diffMin + "m ago";
        const diffHr = Math.floor(diffMin / 60);
        if (diffHr < 24) return diffHr + "h ago";
        const diffDay = Math.floor(diffHr / 24);
        if (diffDay < 7) return diffDay + "d ago";
        return then.toLocaleDateString();
    }

    WindowDialogTitle {
        text: Translation.tr("Sessions")
    }

    StyledIndeterminateProgressBar {
        visible: root.loading
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }

    WindowDialogSeparator {
        visible: !root.loading
    }

    // Empty state
    StyledText {
        visible: !root.loading && root.sessions.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 20
        Layout.bottomMargin: 20
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance.font.pixelSize.normal
        color: Appearance.colors.colSubtext
        text: Translation.tr("No sessions found")
    }

    ListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0

        model: root.sessions
        delegate: Item {
            id: sessionItem
            required property var modelData
            required property int index
            width: ListView.view.width
            implicitHeight: sessionDialogItem.implicitHeight

            property bool isActive: modelData.id === Ai.sessionId
            property string sessionTitle: modelData.title || ("Session " + (index + 1))
            property string timeStr: root.formatTimeAgo(modelData.time?.updated ?? modelData.time?.created ?? "")
            property var summary: modelData.summary ?? ({})
            property int additions: summary.additions ?? 0
            property int deletions: summary.deletions ?? 0
            property int files: summary.files ?? 0

            DialogListItem {
                id: sessionDialogItem
                anchors.fill: parent
                active: sessionItem.isActive

                onClicked: {
                    if (!sessionItem.isActive) {
                        Ai.switchSession(sessionItem.modelData.id, sessionItem.sessionTitle);
                        root.dismiss();
                    }
                }

                contentItem: RowLayout {
                    id: sessionRow
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: sessionItem.isActive ? "radio_button_checked" : "chat_bubble_outline"
                                iconSize: Appearance.font.pixelSize.normal
                                color: sessionItem.isActive ?
                                    (Appearance.m3colors.m3primary ?? Appearance.colors.colPrimary) :
                                    Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: sessionItem.sessionTitle
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: sessionItem.isActive ? Font.DemiBold : Font.Normal
                                color: sessionItem.isActive ?
                                    (Appearance.m3colors.m3primary ?? Appearance.colors.colPrimary) :
                                    Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            StyledText {
                                text: sessionItem.timeStr
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                            }
                        }

                        // Summary line (files changed, additions/deletions)
                        RowLayout {
                            visible: sessionItem.files > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: Appearance.font.pixelSize.normal + 6
                            spacing: 8

                            StyledText {
                                visible: sessionItem.files > 0
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                                text: sessionItem.files + (sessionItem.files === 1 ? " file" : " files")
                            }
                            StyledText {
                                visible: sessionItem.additions > 0
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.m3colors.m3tertiary ?? "#78C8A0"
                                text: "+" + sessionItem.additions
                            }
                            StyledText {
                                visible: sessionItem.deletions > 0
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.m3colors.m3error ?? "#FF5555"
                                text: "-" + sessionItem.deletions
                            }
                        }
                    }

                    // Delete button
                    RippleButton {
                        visible: !sessionItem.isActive
                        implicitWidth: 28
                        implicitHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer3, 1)
                        colBackgroundHover: Appearance.colors.colLayer3Hover
                        colRipple: Appearance.colors.colLayer3Active

                        onClicked: {
                            Ai.deleteSession(sessionItem.modelData.id);
                        }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete_outline"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }

                        StyledToolTip {
                            text: Translation.tr("Delete session")
                        }
                    }
                }
            }
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Refresh")
            onClicked: Ai.listSessions()
        }

        Item { Layout.fillWidth: true }

        DialogButton {
            buttonText: Translation.tr("New Session")
            onClicked: {
                Ai.clearMessages();
                root.dismiss();
            }
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
