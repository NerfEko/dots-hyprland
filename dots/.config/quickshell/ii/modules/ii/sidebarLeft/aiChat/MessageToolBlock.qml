pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root
    // These are needed on the parent loader
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ""
    property var messageData: ({})
    property bool done: true
    property bool completed: false

    // Tool-specific properties
    property string toolName: ""
    property string toolTitle: ""
    property string toolStatus: "running"
    property string toolInput: ""

    property real toolBlockBackgroundRounding: Appearance.rounding.small
    property real toolBlockHeaderPaddingVertical: 3
    property real toolBlockHeaderPaddingHorizontal: 10
    property real toolBlockComponentSpacing: 2

    property var collapseAnimation: Appearance.animation.elementMoveFast
    property bool collapsed: true
    property bool hasOutput: (segmentContent && segmentContent.trim().length > 0) || (isSubagent && agentPrompt.length > 0)

    // File preview properties
    property bool isFileEditTool: {
        const name = toolName.toLowerCase();
        return name === "write" || name === "edit" || name === "read";
    }
    property string filePath: {
        if (!isFileEditTool || !toolInput) return "";
        try {
            const parsed = JSON.parse(toolInput);
            return parsed.filePath || parsed.path || parsed.file || "";
        } catch (e) {
            // Try regex extraction as fallback
            const match = toolInput.match(/"filePath"\s*:\s*"([^"]+)"/);
            return match ? match[1] : "";
        }
    }
    property bool previewVisible: false
    property string previewContent: ""
    property bool previewLoading: false

    // Subagent/task properties — parsed from toolInput when toolName === "task"
    property bool isSubagent: toolName.toLowerCase() === "task"
    property var parsedInput: {
        if (!toolInput) return ({});
        try { return JSON.parse(toolInput); } catch (e) { return ({}); }
    }
    property string agentType: isSubagent ? (parsedInput.agent ?? parsedInput.subagent_type ?? "") : ""
    property string agentDescription: isSubagent ? (parsedInput.description ?? "") : ""
    property string agentPrompt: isSubagent ? (parsedInput.prompt ?? "") : ""

    // Agent type icon mapping
    property string agentIcon: {
        if (!isSubagent) return "";
        const t = agentType.toLowerCase();
        if (t === "coderagent" || t === "coder") return "code";
        if (t === "explore") return "explore";
        if (t === "general") return "smart_toy";
        if (t === "testengineer" || t === "test") return "science";
        if (t === "codereviewer" || t === "codereview") return "rate_review";
        if (t === "buildagent" || t === "build") return "construction";
        if (t === "docwriter" || t === "doc") return "article";
        if (t === "contextscout") return "radar";
        if (t === "patternanalyst") return "analytics";
        if (t === "contextorganizer") return "category";
        if (t === "taskmanager") return "assignment";
        return "smart_toy";
    }

    // Agent type color accent
    property color agentColor: {
        if (!isSubagent) return Appearance.colors.colOnLayer2;
        const t = agentType.toLowerCase();
        if (t === "coderagent" || t === "coder") return Appearance.m3colors.m3primary ?? "#8AB4F8";
        if (t === "explore") return Appearance.m3colors.m3tertiary ?? "#78C8A0";
        if (t === "testengineer" || t === "test") return "#F0A060";
        if (t === "codereviewer" || t === "codereview") return "#C080F0";
        if (t === "buildagent" || t === "build") return "#F08080";
        return Appearance.colors.colOnLayer2;
    }

    // Transient tools: show compact while running, collapse away when done
    property bool isTransientTool: {
        const name = toolName.toLowerCase();
        return name === "glob" || name === "grep" || name === "read" ||
               name === "todowrite" || name === "todo_write";
    }
    // Whether this transient tool has finished and should be hidden
    property bool transientDone: isTransientTool && (toolStatus === "completed" || toolStatus === "error")

    // Icon for tool type
    property string toolIcon: {
        if (isSubagent && agentIcon !== "") return agentIcon;
        const name = toolName.toLowerCase();
        if (name === "read") return "description";
        if (name === "write") return "edit_document";
        if (name === "edit") return "edit_note";
        if (name === "bash") return "terminal";
        if (name === "glob") return "folder_open";
        if (name === "grep") return "search";
        if (name === "webfetch" || name === "web_fetch") return "language";
        if (name === "task") return "smart_toy";
        if (name === "todowrite" || name === "todo_write") return "checklist";
        if (name === "question") return "help";
        return "build";
    }

    // Status icon
    property string statusIcon: {
        if (toolStatus === "completed") return "check_circle";
        if (toolStatus === "error") return "error";
        return "pending";
    }

    property color statusColor: {
        if (toolStatus === "completed") return Appearance.m3colors.m3tertiary ?? Appearance.colors.colSubtext;
        if (toolStatus === "error") return Appearance.m3colors.m3error ?? "#FF5555";
        return Appearance.colors.colSubtext;
    }

    Layout.fillWidth: true
    implicitHeight: transientDone ? 0 :
                    isTransientTool ? transientRow.implicitHeight :
                    (collapsed && !previewVisible ? header.implicitHeight : columnLayout.implicitHeight)
    clip: true
    visible: implicitHeight > 0 || transientHeightAnim.running

    // Don't use layer masking for transient tools (they're simple inline elements)
    layer.enabled: !isTransientTool
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: toolBlockBackgroundRounding
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            id: transientHeightAnim
            duration: collapseAnimation.duration
            easing.type: collapseAnimation.type
            easing.bezierCurve: collapseAnimation.bezierCurve
        }
    }

    // ─── Transient tool: compact inline row (shown while running) ────────
    RowLayout {
        id: transientRow
        visible: root.isTransientTool && !root.transientDone
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 6

        MaterialSymbol {
            text: root.toolIcon
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            opacity: 0.7
        }

        StyledText {
            Layout.fillWidth: false
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
            color: Appearance.colors.colSubtext
            opacity: 0.7
            text: root.toolName || "tool"
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            opacity: 0.5
            text: root.toolTitle || ""
        }

        MaterialSymbol {
            text: "pending"
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            opacity: 0.5

            RotationAnimator on rotation {
                from: 0; to: 360; duration: 2000
                running: root.isTransientTool && !root.transientDone
                loops: Animation.Infinite
            }
        }
    }

    // ─── Full tool block (non-transient tools) ──────────────────────────

    // Process to read file content for preview
    Process {
        id: fileReadProc
        command: ["bash", "-c", "head -n 200 '" + StringUtils.shellSingleQuoteEscape(root.filePath) + "' < /dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.previewContent = this.text;
                root.previewLoading = false;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.previewContent = "(Could not read file)";
                root.previewLoading = false;
            }
        }
    }

    function loadPreview() {
        if (root.filePath === "") return;
        root.previewLoading = true;
        root.previewContent = "";
        fileReadProc.running = false;
        fileReadProc.command = ["bash", "-c", "head -n 200 '" + StringUtils.shellSingleQuoteEscape(root.filePath) + "' < /dev/null"];
        fileReadProc.running = true;
    }

    ColumnLayout {
        id: columnLayout
        visible: !root.isTransientTool
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Rectangle { // Header background
            id: header
            color: Appearance.colors.colSurfaceContainerHighest
            Layout.fillWidth: true
            implicitHeight: toolBlockTitleBarRowLayout.implicitHeight + toolBlockHeaderPaddingVertical * 2

            MouseArea { // Click to reveal
                id: headerMouseArea
                enabled: root.hasOutput
                anchors.fill: parent
                cursorShape: root.hasOutput ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true
                onClicked: {
                    root.collapsed = !root.collapsed
                }
            }

            RowLayout { // Header content
                id: toolBlockTitleBarRowLayout
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: toolBlockHeaderPaddingHorizontal
                anchors.rightMargin: toolBlockHeaderPaddingHorizontal
                spacing: 8

                MaterialSymbol { // Tool type icon
                    Layout.fillWidth: false
                    Layout.topMargin: 7
                    Layout.bottomMargin: 7
                    Layout.leftMargin: 3
                    text: root.toolIcon
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.isSubagent ? root.agentColor : Appearance.colors.colOnLayer2
                }

                StyledText { // Tool name
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root.isSubagent ? root.agentColor : Appearance.colors.colOnLayer2
                    text: root.isSubagent ? (root.agentType || "agent") : (root.toolName || "tool")
                }

                StyledText { // Title / description
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignLeft
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    text: root.isSubagent ? (root.agentDescription || root.toolTitle || "") : (root.toolTitle || "")
                }

                // Preview file button — only for file edit/write/read tools with a valid path
                RippleButton {
                    id: previewButton
                    visible: root.isFileEditTool && root.filePath !== "" && root.toolStatus === "completed"
                    implicitWidth: previewButtonRow.implicitWidth + 12
                    implicitHeight: 22
                    Layout.fillWidth: false
                    Layout.fillHeight: false
                    colBackground: root.previewVisible ?
                        Appearance.colors.colSecondaryContainer :
                        (previewButton.containsMouse ? Appearance.colors.colLayer2Hover : ColorUtils.transparentize(Appearance.colors.colLayer2, 1))
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active

                    onClicked: {
                        if (!root.previewVisible) {
                            root.loadPreview();
                            root.previewVisible = true;
                        } else {
                            root.previewVisible = false;
                        }
                    }

                    contentItem: RowLayout {
                        id: previewButtonRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: "visibility"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            text: root.previewVisible ? "Hide" : "Preview"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    StyledToolTip {
                        text: root.previewVisible ? "Hide file preview" : "Preview file: " + root.filePath
                    }
                }

                MaterialSymbol { // Status icon
                    Layout.fillWidth: false
                    text: root.statusIcon
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.statusColor

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 2000
                        running: root.toolStatus !== "completed" && root.toolStatus !== "error"
                        loops: Animation.Infinite
                    }
                }

                RippleButton { // Expand button
                    id: expandButton
                    visible: root.hasOutput
                    implicitWidth: 22
                    implicitHeight: 22
                    colBackground: headerMouseArea.containsMouse ? Appearance.colors.colLayer2Hover
                        : ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active

                    onClicked: { root.collapsed = !root.collapsed }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_down"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer2
                        rotation: root.collapsed ? 0 : 180
                        Behavior on rotation {
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                    }
                }
            }
        }

        Item { // Collapsible output content
            id: content
            Layout.fillWidth: true
            implicitHeight: collapsed ? 0 : contentBackground.implicitHeight + toolBlockComponentSpacing
            clip: true

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: collapseAnimation.duration
                    easing.type: collapseAnimation.type
                    easing.bezierCurve: collapseAnimation.bezierCurve
                }
            }

            Rectangle {
                id: contentBackground
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: contentColumn.implicitHeight + 12
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: contentColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 6
                    }
                    spacing: 4

                    // Subagent prompt display (for task tools)
                    StyledText {
                        visible: root.isSubagent && root.agentPrompt.length > 0
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.Wrap
                        color: Appearance.colors.colOnLayer1
                        text: root.agentPrompt.substring(0, 2000)
                    }

                    // Separator between prompt and output
                    Rectangle {
                        visible: root.isSubagent && root.agentPrompt.length > 0 && root.segmentContent && root.segmentContent.trim().length > 0
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.colors.colSurfaceContainerHighest
                    }

                    // Standard tool output
                    StyledText {
                        id: outputText
                        visible: root.segmentContent && root.segmentContent.trim().length > 0
                        Layout.fillWidth: true
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.Wrap
                        color: Appearance.colors.colSubtext
                        text: root.segmentContent ? root.segmentContent.trim().substring(0, 2000) : ""
                    }
                }
            }
        }

        // File preview section
        Item {
            id: previewSection
            Layout.fillWidth: true
            implicitHeight: root.previewVisible ? previewBackground.implicitHeight + toolBlockComponentSpacing : 0
            clip: true
            visible: root.previewVisible || previewHeightAnim.running

            Behavior on implicitHeight {
                NumberAnimation {
                    id: previewHeightAnim
                    duration: collapseAnimation.duration
                    easing.type: collapseAnimation.type
                    easing.bezierCurve: collapseAnimation.bezierCurve
                }
            }

            Rectangle {
                id: previewBackground
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: previewColumnLayout.implicitHeight
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: previewColumnLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    // Preview header bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: previewHeaderRow.implicitHeight + 6
                        color: Appearance.colors.colSurfaceContainerHighest

                        RowLayout {
                            id: previewHeaderRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            MaterialSymbol {
                                text: "draft"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.m3colors.m3tertiary ?? Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.filePath
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.monospace
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideMiddle
                            }

                            // Copy file path
                            RippleButton {
                                implicitWidth: 20
                                implicitHeight: 20
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: {
                                    Quickshell.clipboardText = root.filePath;
                                }
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "content_copy"
                                    iconSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colOnLayer2
                                }
                                StyledToolTip { text: "Copy file path" }
                            }

                            // Copy file content
                            RippleButton {
                                implicitWidth: 20
                                implicitHeight: 20
                                visible: root.previewContent !== "" && !root.previewLoading
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: {
                                    Quickshell.clipboardText = root.previewContent;
                                }
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "file_copy"
                                    iconSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colOnLayer2
                                }
                                StyledToolTip { text: "Copy file content" }
                            }

                            // Refresh preview
                            RippleButton {
                                implicitWidth: 20
                                implicitHeight: 20
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: {
                                    root.loadPreview();
                                }
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "refresh"
                                    iconSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colOnLayer2
                                }
                                StyledToolTip { text: "Refresh preview" }
                            }
                        }
                    }

                    // Preview content
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.min(previewContentText.implicitHeight + 12, 400)
                        color: Appearance.colors.colLayer1
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 6
                            contentWidth: previewContentText.implicitWidth
                            contentHeight: previewContentText.implicitHeight
                            flickableDirection: Flickable.VerticalFlick
                            boundsBehavior: Flickable.StopAtBounds

                            StyledText {
                                id: previewContentText
                                width: parent.parent.width - 12
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                wrapMode: Text.Wrap
                                color: Appearance.colors.colOnLayer1
                                text: {
                                    if (root.previewLoading) return "Loading...";
                                    if (root.previewContent === "") return "(Empty file)";
                                    return root.previewContent;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
