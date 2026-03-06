pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions as CF
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services.ai

/**
 * AI service powered by OpenCode HTTP Server API.
 * Uses SSE (Server-Sent Events) via GET /event for real-time token streaming.
 * Messages sent via POST /session/{id}/prompt_async.
 * Server: opencode serve --port 4096 --hostname 127.0.0.1
 */
Singleton {
    id: root

    property Component aiMessageComponent: AiMessageData {}
    readonly property string interfaceRole: "interface"
    readonly property string apiBase: "http://127.0.0.1:4096"

    signal responseFinished()

    // ─── OpenCode session & server state ──────────────────────────────────
    property string sessionId: ""
    property string sessionTitle: ""
    property bool serverAvailable: false
    property bool sessionBusy: false

    // Tracks the assistant message currently being streamed
    property string currentAssistantMsgId: ""
    property AiMessageData currentMessage: null

    // Reasoning/thinking buffer for current message
    property string currentReasoning: ""

    // Track tool parts by partID so we can update status transitions
    property var toolParts: ({})

    // ─── Pending permission requests ─────────────────────────────────────
    property var pendingPermissions: []

    // ─── System prompt & config ──────────────────────────────────────────
    property string systemPrompt: {
        let prompt = Config.options?.ai?.systemPrompt ?? "";
        for (let key in root.promptSubstitutions) {
            prompt = prompt.split(key).join(root.promptSubstitutions[key]);
        }
        return prompt;
    }

    property var messageIDs: []
    property var messageByID: ({})
    property var postResponseHook
    property real temperature: Persistent.states?.ai?.temperature ?? 0.5
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }

    function idForMessage(message) {
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    property list<var> defaultPrompts: []
    property list<var> userPrompts: []
    property list<var> promptFiles: [...defaultPrompts, ...userPrompts]
    property list<var> savedChats: []

    property var promptSubstitutions: {
        "{DISTRO}": SystemInfo.distroName,
        "{DATETIME}": `${DateTime.time}, ${DateTime.collapsedCalendarFormat}`,
        "{WINDOWCLASS}": ToplevelManager.activeToplevel?.appId ?? "Unknown",
        "{DE}": `${SystemInfo.desktopEnvironment} (${SystemInfo.windowingSystem})`
    }

    // ─── Agent (build / plan) ────────────────────────────────────────────
    property string currentAgent: Persistent.states?.ai?.agent || "build"

    function toggleAgent() {
        const next = root.currentAgent === "plan" ? "build" : "plan";
        root.currentAgent = next;
        Persistent.states.ai.agent = next;
    }

    // ─── Models ──────────────────────────────────────────────────────────
    property var models: ({})
    property var modelList: []
    property string currentModelId: Persistent.states?.ai?.model || ""

    // File attachment
    property string pendingFilePath: ""

    Component.onCompleted: {
        fetchModels.running = true;
        // Start SSE listener after a brief delay to let server be ready
        sseReconnectTimer.interval = 1000;
        sseReconnectTimer.start();
    }

    // ─── Icon & name guessing ────────────────────────────────────────────
    function guessModelIcon(modelId) {
        const lower = modelId.toLowerCase();
        if (lower.includes("claude") || lower.includes("anthropic")) return "anthropic-symbolic";
        if (lower.includes("gemini")) return "google-gemini-symbolic";
        if (lower.includes("gpt") || lower.includes("codex") || lower.includes("openai")) return "openai-symbolic";
        if (lower.includes("deepseek")) return "deepseek-symbolic";
        if (lower.includes("mistral")) return "mistral-symbolic";
        if (lower.includes("llama")) return "ollama-symbolic";
        if (lower.includes("grok")) return "xai-symbolic";
        return "neurology";
    }

    function guessModelName(modelId) {
        const parts = modelId.split("/");
        const modelPart = parts.length > 1 ? parts[1] : parts[0];
        return modelPart.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    }

    function ensureModel(modelId) {
        if (!root.models[modelId]) {
            root.models[modelId] = {
                "name": guessModelName(modelId),
                "icon": guessModelIcon(modelId),
                "description": modelId,
            };
            if (root.modelList.indexOf(modelId) === -1) {
                root.modelList = [...root.modelList, modelId];
            }
        }
    }

    // ─── Fetch models from CLI ───────────────────────────────────────────
    Process {
        id: fetchModels
        running: false
        command: ["bash", "-c", "opencode models < /dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                const lines = text.split("\n").filter(l => l.trim().length > 0);
                let newModels = {};
                let newModelList = [];
                lines.forEach(modelId => {
                    modelId = modelId.trim();
                    if (modelId.length === 0) return;
                    newModels[modelId] = {
                        "name": root.guessModelName(modelId),
                        "icon": root.guessModelIcon(modelId),
                        "description": modelId,
                    };
                    newModelList.push(modelId);
                });
                root.models = newModels;
                root.modelList = newModelList;

                if (!root.currentModelId || root.modelList.indexOf(root.currentModelId) === -1) {
                    const preferred = [
                        "github-copilot/claude-sonnet-4",
                        "github-copilot/claude-opus-4",
                        "github-copilot/gpt-4o",
                        "github-copilot/gemini-2.5-pro",
                    ];
                    let found = false;
                    for (let i = 0; i < preferred.length; i++) {
                        if (root.modelList.indexOf(preferred[i]) !== -1) {
                            root.currentModelId = preferred[i];
                            found = true;
                            break;
                        }
                    }
                    if (!found && root.modelList.length > 0) {
                        root.currentModelId = root.modelList[0];
                    }
                }
            }
        }
    }

    // ─── Prompt & saved chat listing ─────────────────────────────────────
    Process {
        id: getDefaultPrompts
        running: true
        command: ["ls", "-1", Directories.defaultAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.defaultPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.defaultAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getUserPrompts
        running: true
        command: ["ls", "-1", Directories.userAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.userPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.userAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getSavedChats
        running: true
        command: ["ls", "-1", Directories.aiChats]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.savedChats = text.split("\n")
                    .filter(fileName => fileName.endsWith(".json"))
                    .map(fileName => `${Directories.aiChats}/${fileName}`)
            }
        }
    }

    FileView {
        id: promptLoader
        watchChanges: false;
        onLoadedChanged: {
            if (!promptLoader.loaded) return;
            Config.options.ai.systemPrompt = promptLoader.text();
            root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
    }

    function loadPrompt(filePath) {
        promptLoader.path = "";
        promptLoader.path = filePath;
        promptLoader.reload();
    }

    // ─── Message management ──────────────────────────────────────────────
    function addMessage(message, role) {
        if (message.length === 0) return;
        const aiMessage = aiMessageComponent.createObject(root, {
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
        });
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function removeMessage(index) {
        if (index < 0 || index >= messageIDs.length) return;
        const id = root.messageIDs[index];
        root.messageIDs.splice(index, 1);
        root.messageIDs = [...root.messageIDs];
        delete root.messageByID[id];
    }

    function getModel() {
        root.ensureModel(root.currentModelId || "unknown");
        return root.models[root.currentModelId] ?? { name: "No model", icon: "neurology", description: "" };
    }

    function setModel(modelId, feedback = true, setPersistentState = true) {
        if (!modelId) modelId = "";
        modelId = modelId.trim();
        if (root.modelList.indexOf(modelId) !== -1) {
            root.currentModelId = modelId;
            if (setPersistentState) Persistent.states.ai.model = modelId;
            if (feedback) root.addMessage(Translation.tr("Model set to **%1**").arg(root.models[modelId].name), root.interfaceRole);
            return;
        }
        const lower = modelId.toLowerCase();
        const matches = root.modelList.filter(m => m.toLowerCase().includes(lower));
        if (matches.length === 1) {
            root.currentModelId = matches[0];
            if (setPersistentState) Persistent.states.ai.model = matches[0];
            if (feedback) root.addMessage(Translation.tr("Model set to **%1**").arg(root.models[matches[0]].name), root.interfaceRole);
            return;
        }
        if (matches.length > 1) {
            if (feedback) root.addMessage(Translation.tr("Multiple matches:\n```\n%1\n```").arg(matches.join("\n")), root.interfaceRole);
            return;
        }
        if (feedback) root.addMessage(Translation.tr("Model not found. Available models:\n```\n%1\n```").arg(root.modelList.join("\n")), root.interfaceRole);
    }

    function getTemperature() { return root.temperature; }

    function setTemperature(value) {
        if (isNaN(value) || value < 0 || value > 2) {
            root.addMessage(Translation.tr("Temperature must be between 0 and 2"), root.interfaceRole);
            return;
        }
        Persistent.states.ai.temperature = value;
        root.temperature = value;
        root.addMessage(Translation.tr("Temperature set to %1").arg(value), root.interfaceRole);
    }

    function printTemperature() {
        root.addMessage(Translation.tr("Temperature: %1").arg(root.temperature), root.interfaceRole);
    }

    function clearMessages() {
        root.messageIDs = [];
        root.messageByID = ({});
        root.sessionId = "";
        root.sessionTitle = "";
        root.currentAssistantMsgId = "";
        root.currentMessage = null;
        root.currentReasoning = "";
        root.toolParts = ({});
        root.pendingPermissions = [];
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.total = -1;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SSE LISTENER — Long-running curl for Server-Sent Events
    // Receives all real-time events (text deltas, tool updates, etc.)
    // ═══════════════════════════════════════════════════════════════════════
    Timer {
        id: sseReconnectTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!sseListener.running) {
                sseListener.running = true;
            }
        }
    }

    Process {
        id: sseListener
        running: false
        command: ["curl", "-sN", root.apiBase + "/event"]

        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                // SSE format: "data: {...}" — strip prefix and parse
                const lines = data.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (!line.startsWith("data: ")) continue;
                    const jsonStr = line.substring(6); // strip "data: "
                    try {
                        const event = JSON.parse(jsonStr);
                        root.handleSSEEvent(event);
                    } catch (e) {
                        console.log("[Ai] SSE parse error:", e, "data:", jsonStr.substring(0, 200));
                    }
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.serverAvailable = false;
            sseReconnectTimer.interval = 3000;
            sseReconnectTimer.start();
        }
    }

    // ─── SSE Event Router ────────────────────────────────────────────────
    function handleSSEEvent(event) {
        const type = event.type;
        const props = event.properties;

        if (type === "server.connected") {
            root.serverAvailable = true;
            return;
        }
        if (type === "server.heartbeat") return;

        // Filter events to our session only
        const eventSessionId = props?.sessionID ?? props?.info?.sessionID ?? "";
        if (eventSessionId && root.sessionId && eventSessionId !== root.sessionId) return;

        switch (type) {
        case "message.part.delta":
            handlePartDelta(props);
            break;
        case "message.part.updated":
            handlePartUpdated(props);
            break;
        case "message.updated":
            handleMessageUpdated(props);
            break;
        case "session.status":
            handleSessionStatus(props);
            break;
        case "session.idle":
            handleSessionIdle(props);
            break;
        case "session.updated":
            handleSessionUpdated(props);
            break;
        case "session.error":
            handleSessionError(props);
            break;
        case "permission.asked":
            handlePermissionAsked(props);
            break;
        case "permission.replied":
            handlePermissionReplied(props);
            break;
        default:
            // session.diff, session.compacted, file.edited, etc.
            break;
        }
    }

    // ─── Handle text deltas (TOKEN-BY-TOKEN STREAMING) ───────────────────
    function handlePartDelta(props) {
        if (!root.currentMessage) return;

        if (props.field === "reasoning") {
            const delta = props.delta ?? "";
            if (delta.length === 0) return;
            // Buffer reasoning content and show thinking indicator
            root.currentReasoning += delta;
            root.currentMessage.thinking = true;
            return;
        }

        if (props.field === "text") {
            const delta = props.delta ?? "";
            if (delta.length === 0) return;

            // If we have buffered reasoning, flush it as a <think> block first
            if (root.currentReasoning.length > 0) {
                root.currentMessage.rawContent += "<think>\n" + root.currentReasoning + "\n</think>\n\n";
                root.currentReasoning = "";
            }

            // Streaming text — append delta to message content
            if (root.currentMessage.thinking) root.currentMessage.thinking = false;
            root.currentMessage.rawContent += delta;
            root.currentMessage.content = root.currentMessage.rawContent;
        }
    }

    // ─── Handle part lifecycle (start, text final, tool, step-finish) ────
    function handlePartUpdated(props) {
        const part = props.part;
        if (!part || !root.currentMessage) return;

        switch (part.type) {
        case "step-start":
            // Step is starting — show thinking indicator
            if (root.currentMessage && !root.currentMessage.done) {
                root.currentMessage.thinking = true;
            }
            break;

        case "text":
            // Text part update — could be initial (empty) or final (full text)
            // We rely on deltas for streaming, so this is mostly confirmation
            break;

        case "reasoning":
            // Reasoning/thinking content
            break;

        case "tool":
            handleToolPart(part);
            break;

        case "subtask":
            handleSubtaskPart(part);
            break;

        case "step-finish":
            // Step finished — capture token counts
            const tokens = part.tokens;
            if (tokens) {
                root.tokenCount.input = tokens.input ?? -1;
                root.tokenCount.output = tokens.output ?? -1;
                root.tokenCount.total = tokens.total ?? -1;
            }
            break;
        }
    }

    // ─── Handle tool use lifecycle ───────────────────────────────────────
    function handleToolPart(part) {
        if (!root.currentMessage) return;
        const partId = part.id;
        const tool = part.tool ?? "tool";
        const state = part.state ?? {};
        const status = state.status ?? "pending";

        if (status === "pending" || status === "running") {
            // Flush any buffered reasoning before tool starts
            if (root.currentReasoning.length > 0) {
                root.currentMessage.rawContent += "<think>\n" + root.currentReasoning + "\n</think>\n\n";
                root.currentMessage.content = root.currentMessage.rawContent;
                root.currentReasoning = "";
            }
            // Tool is starting/running — show pending indicator
            root.currentMessage.functionPending = true;
            root.currentMessage.functionName = state.title ?? tool;
            // Track this tool part
            root.toolParts[partId] = { tool: tool, status: status };
        }
        else if (status === "completed" || status === "error") {
            // Tool finished — clear pending, append <tool> tag to content
            root.currentMessage.functionPending = false;
            root.currentMessage.functionName = "";

            const title = state.title ?? tool;
            const output = (status === "completed") ? (state.output ?? "") : (state.error ?? "Error");
            const input = state.input ? JSON.stringify(state.input) : "";

            const toolTag = `\n\n<tool name="${tool}" title="${title.replace(/"/g, '&quot;')}" status="${status}"${input ? ` input="${input.replace(/"/g, '&quot;').substring(0, 500)}"` : ""}>${output ? output.substring(0, 2000) : ""}</tool>\n\n`;

            if (root.currentMessage.thinking) root.currentMessage.thinking = false;
            root.currentMessage.rawContent += toolTag;
            root.currentMessage.content = root.currentMessage.rawContent;

            // Clean up tracking
            delete root.toolParts[partId];
        }
    }

    // ─── Handle subtask parts (subagent invocations) ────────────────────
    function handleSubtaskPart(part) {
        if (!root.currentMessage) return;

        // Flush any buffered reasoning before subtask
        if (root.currentReasoning.length > 0) {
            root.currentMessage.rawContent += "<think>\n" + root.currentReasoning + "\n</think>\n\n";
            root.currentMessage.content = root.currentMessage.rawContent;
            root.currentReasoning = "";
        }

        const agent = part.agent ?? "general";
        const description = part.description ?? "";
        const prompt = part.prompt ?? "";
        const sessionID = part.sessionID ?? "";

        // Render subtask as a tool tag with agent metadata
        const input = JSON.stringify({ agent: agent, description: description, prompt: prompt.substring(0, 500), sessionID: sessionID });
        const toolTag = `\n\n<tool name="task" title="${description.replace(/"/g, '&quot;')}" status="running" input="${input.replace(/"/g, '&quot;')}">${agent} agent: ${description}</tool>\n\n`;

        if (root.currentMessage.thinking) root.currentMessage.thinking = false;
        root.currentMessage.rawContent += toolTag;
        root.currentMessage.content = root.currentMessage.rawContent;
    }

    // ─── Handle message-level updates ────────────────────────────────────
    function handleMessageUpdated(props) {
        const info = props.info;
        if (!info) return;

        // We only care about assistant messages for our session
        if (info.role !== "assistant") return;
        if (info.sessionID !== root.sessionId) return;

        // Capture model info from the response
        if (info.modelID && info.providerID) {
            const fullModelId = info.providerID + "/" + info.modelID;
            root.ensureModel(fullModelId);
            if (root.currentMessage) {
                root.currentMessage.model = fullModelId;
            }
        }

        // If message has completed time, it's done
        if (info.time?.completed) {
            if (root.currentMessage && !root.currentMessage.done) {
                finishCurrentMessage();
            }
            return;
        }

        // NEW assistant message creation (no completed time) — this handles
        // multi-message tool continuation. After a tool call finishes and the
        // model sends a follow-up response, OpenCode creates a new assistant
        // message with a different ID. We need to create a new placeholder.
        if (!info.time?.completed && root.currentMessage === null && root.sessionBusy) {
            const modelId = root.currentModelId;
            root.ensureModel(modelId || "unknown");
            const assistantMsg = root.aiMessageComponent.createObject(root, {
                "role": "assistant",
                "model": modelId,
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false,
            });
            const id = idForMessage(assistantMsg);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = assistantMsg;
            root.currentMessage = assistantMsg;
            root.currentAssistantMsgId = id;

            // Apply model info if available
            if (info.modelID && info.providerID) {
                assistantMsg.model = info.providerID + "/" + info.modelID;
            }
        }

        // Update token counts from final message update
        if (info.tokens) {
            root.tokenCount.input = info.tokens.input ?? -1;
            root.tokenCount.output = info.tokens.output ?? -1;
            root.tokenCount.total = info.tokens.total ?? -1;
        }
    }

    // ─── Handle session status changes ───────────────────────────────────
    function handleSessionStatus(props) {
        if (props.sessionID !== root.sessionId) return;
        const status = props.status;
        if (status.type === "busy") {
            root.sessionBusy = true;
        } else if (status.type === "idle") {
            root.sessionBusy = false;
        }
    }

    // ─── Handle session idle — response fully complete ───────────────────
    function handleSessionIdle(props) {
        if (props.sessionID !== root.sessionId) return;
        root.sessionBusy = false;
        if (root.currentMessage && !root.currentMessage.done) {
            finishCurrentMessage();
        }
    }

    // ─── Handle session updates (title, etc.) ────────────────────────────
    function handleSessionUpdated(props) {
        const info = props.info ?? props;
        if (!info) return;
        const sid = info.id ?? info.sessionID ?? "";
        if (sid && root.sessionId && sid !== root.sessionId) return;
        if (info.title && info.title.length > 0) {
            root.sessionTitle = info.title;
        }
    }

    // ─── Handle session errors ───────────────────────────────────────────
    function handleSessionError(props) {
        const sid = props.sessionID ?? "";
        if (sid && root.sessionId && sid !== root.sessionId) return;
        const error = props.error ?? props.message ?? "Unknown error";
        console.log("[Ai] Session error:", JSON.stringify(props));
        root.addMessage("**Error:** " + error, root.interfaceRole);
        if (root.currentMessage && !root.currentMessage.done) {
            finishCurrentMessage();
        }
    }

    // ─── Handle permission requests ─────────────────────────────────────
    // permission.asked event props: { id, sessionID, permission, patterns, metadata, always, tool: { messageID, callID } }
    // permission types: "edit", "bash", "webfetch", "doom_loop", "external_directory"
    function handlePermissionAsked(props) {
        // Build a user-friendly title from the permission data
        const permType = props.permission ?? "unknown";
        const metadata = props.metadata ?? {};
        let title = permType;
        switch (permType) {
        case "edit":
            title = "Edit file: " + (metadata.filepath ?? metadata.file ?? "unknown");
            break;
        case "bash":
            title = "Run command: " + (metadata.command ?? "unknown");
            break;
        case "webfetch":
            title = "Fetch URL: " + (metadata.url ?? "unknown");
            break;
        case "external_directory":
            title = "Access directory: " + (metadata.parentDir ?? metadata.filepath ?? "unknown");
            break;
        case "doom_loop":
            title = "Agent retry loop detected";
            break;
        default:
            title = permType;
        }

        const permObj = {
            id: props.id,
            type: permType,
            sessionID: props.sessionID,
            title: title,
            patterns: props.patterns ?? [],
            metadata: metadata,
            tool: props.tool ?? {},
        };

        const existing = root.pendingPermissions.findIndex(p => p.id === props.id);
        if (existing >= 0) {
            let updated = root.pendingPermissions.slice();
            updated[existing] = permObj;
            root.pendingPermissions = updated;
        } else {
            root.pendingPermissions = root.pendingPermissions.concat([permObj]);
        }
    }

    function handlePermissionReplied(props) {
        // props: { sessionID, requestID, reply }
        root.pendingPermissions = root.pendingPermissions.filter(p => p.id !== props.requestID);
    }

    function respondToPermission(permissionId, response) {
        // response: "once" | "always" | "reject"
        permissionResponder.send(root.sessionId, permissionId, response);
        // Optimistically remove from pending list
        root.pendingPermissions = root.pendingPermissions.filter(p => p.id !== permissionId);
    }

    // ─── Finish current assistant message ────────────────────────────────
    function finishCurrentMessage() {
        if (!root.currentMessage) return;

        // Flush any remaining buffered reasoning
        if (root.currentReasoning.length > 0) {
            root.currentMessage.rawContent += "<think>\n" + root.currentReasoning + "\n</think>\n\n";
            root.currentMessage.content = root.currentMessage.rawContent;
            root.currentReasoning = "";
        }

        // Desktop notification when sidebar is closed
        if (!GlobalStates.sidebarLeftOpen) {
            const preview = root.currentMessage.rawContent
                .replace(/<think>[\s\S]*?<\/think>/g, "")
                .replace(/<tool[^>]*>[\s\S]*?<\/tool>/g, "")
                .trim().substring(0, 200);
            const title = root.sessionTitle || "OpenCode";
            if (preview.length > 0) {
                Quickshell.execDetached(["notify-send", title, preview, "-a", "Shell"]);
            }
        }

        root.currentMessage.thinking = false;
        root.currentMessage.functionPending = false;
        root.currentMessage.done = true;
        root.currentAssistantMsgId = "";
        root.currentMessage = null;
        root.toolParts = ({});

        if (root.postResponseHook) {
            root.postResponseHook();
            root.postResponseHook = null;
        }
        root.saveChat("lastSession");
        root.responseFinished();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SESSION CREATOR — POST /session
    // ═══════════════════════════════════════════════════════════════════════
    Process {
        id: sessionCreator
        running: false
        property string pendingUserMessage: ""
        command: ["curl", "-s", "-X", "POST",
                  "-H", "Content-Type: application/json",
                  "-d", "{}",
                  root.apiBase + "/session"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                try {
                    const session = JSON.parse(text);
                    root.sessionId = session.id;
                    // Now send the pending message
                    if (sessionCreator.pendingUserMessage.length > 0) {
                        const msg = sessionCreator.pendingUserMessage;
                        sessionCreator.pendingUserMessage = "";
                        root.doSendMessage(msg);
                    }
                } catch (e) {
                    console.log("[Ai] Session create error:", e, text);
                    root.addMessage("**Error:** Could not create session. Is `opencode serve` running?", root.interfaceRole);
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.log("[Ai] Session create process failed, code:", exitCode);
                root.addMessage("**Error:** Could not connect to OpenCode server. Is `opencode serve --port 4096` running?", root.interfaceRole);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MESSAGE SENDER — POST /session/{id}/prompt_async
    // Returns 204 immediately; response streams via SSE
    // ═══════════════════════════════════════════════════════════════════════
    Process {
        id: messageSender
        running: false

        function send(sessionId, userText) {
            // Build JSON body
            const modelId = root.currentModelId;
            let body = { parts: [{ type: "text", text: userText }] };

            // Include agent selection (build or plan)
            body.agent = root.currentAgent;

            // Include model selection
            if (modelId && modelId.includes("/")) {
                const slash = modelId.indexOf("/");
                body.model = {
                    providerID: modelId.substring(0, slash),
                    modelID: modelId.substring(slash + 1),
                };
            }

            // File attachment
            if (root.pendingFilePath && root.pendingFilePath.length > 0) {
                body.parts.push({
                    type: "file",
                    mime: "application/octet-stream",
                    url: "file://" + root.pendingFilePath,
                });
            }

            const jsonBody = JSON.stringify(body);
            const url = root.apiBase + "/session/" + sessionId + "/prompt_async";

            messageSender.running = false;
            messageSender.command = [
                "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                "-X", "POST",
                "-H", "Content-Type: application/json",
                "-d", jsonBody,
                url
            ];
            messageSender.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const code = text.trim();
                if (code === "204") {
                    // Message accepted
                } else {
                    if (code === "404") {
                        root.addMessage("**Error:** Session not found. Try `/clear` to start a new session.", root.interfaceRole);
                    } else if (code === "400") {
                        root.addMessage("**Error:** Bad request (400). Check message format.", root.interfaceRole);
                    } else if (code === "000") {
                        root.addMessage("**Error:** Could not connect to OpenCode server. Is `opencode serve --port 4096` running?", root.interfaceRole);
                    }
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.log("[Ai] Message sender failed, code:", exitCode);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ABORT — POST /session/{id}/abort
    // ═══════════════════════════════════════════════════════════════════════
    Process {
        id: abortProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const code = text.trim();
                if (code !== "200") {
                    console.log("[Ai] Abort error, HTTP:", code);
                }
            }
        }
    }

    function abortSession() {
        if (!root.sessionId || root.sessionId.length === 0) return;
        abortProcess.running = false;
        abortProcess.command = [
            "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "-X", "POST",
            root.apiBase + "/session/" + root.sessionId + "/abort"
        ];
        abortProcess.running = true;

        // Finish the current message immediately on the UI side
        if (root.currentMessage && !root.currentMessage.done) {
            finishCurrentMessage();
        }
        root.sessionBusy = false;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PERMISSION RESPONDER — POST /session/{id}/permissions/{permissionID}
    // ═══════════════════════════════════════════════════════════════════════
    Process {
        id: permissionResponder
        running: false

        function send(sessionId, permissionId, response) {
            const body = JSON.stringify({ response: response });
            const url = root.apiBase + "/session/" + sessionId + "/permissions/" + permissionId;

            permissionResponder.running = false;
            permissionResponder.command = [
                "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                "-X", "POST",
                "-H", "Content-Type: application/json",
                "-d", body,
                url
            ];
            permissionResponder.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const code = text.trim();
                if (code !== "200") {
                    console.log("[Ai] Permission response error, HTTP:", code);
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PUBLIC API
    // ═══════════════════════════════════════════════════════════════════════

    function sendUserMessage(message) {
        if (message.length === 0) return;

        // Create user message with file attachment if present
        const userMsg = aiMessageComponent.createObject(root, {
            "role": "user",
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
            "localFilePath": root.pendingFilePath || "",
        });
        const uid = idForMessage(userMsg);
        root.messageIDs = [...root.messageIDs, uid];
        root.messageByID[uid] = userMsg;

        if (!root.sessionId || root.sessionId.length === 0) {
            // Need to create a session first
            sessionCreator.pendingUserMessage = message;
            sessionCreator.running = false;
            sessionCreator.running = true;
        } else {
            root.doSendMessage(message);
        }
    }

    function doSendMessage(message) {
        const modelId = root.currentModelId;
        root.ensureModel(modelId || "unknown");

        // Create assistant message placeholder
        const assistantMsg = root.aiMessageComponent.createObject(root, {
            "role": "assistant",
            "model": modelId,
            "content": "",
            "rawContent": "",
            "thinking": true,
            "done": false,
        });
        const id = idForMessage(assistantMsg);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = assistantMsg;

        root.currentMessage = assistantMsg;
        root.currentAssistantMsgId = id;

        // Send via HTTP
        messageSender.send(root.sessionId, message);

        // Clear attachment after sending
        root.pendingFilePath = "";
    }

    function attachFile(filePath: string) {
        root.pendingFilePath = CF.FileUtils.trimFileProtocol(filePath);
    }

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= messageIDs.length) return;
        const id = root.messageIDs[messageIndex];
        const message = root.messageByID[id];
        if (message.role !== "assistant") return;

        let userPrompt = "";
        for (let i = messageIndex - 1; i >= 0; i--) {
            const prevId = root.messageIDs[i];
            const prevMsg = root.messageByID[prevId];
            if (prevMsg.role === "user") {
                userPrompt = prevMsg.rawContent;
                break;
            }
        }

        for (let i = root.messageIDs.length - 1; i >= messageIndex; i--) {
            root.removeMessage(i);
        }

        if (userPrompt.length > 0) {
            root.doSendMessage(userPrompt);
        }
    }

    // ─── Chat save/load ──────────────────────────────────────────────────
    function chatToJson() {
        return root.messageIDs.map(id => {
            const message = root.messageByID[id];
            return ({
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "model": message.model,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionResponse": message.functionResponse,
                "visibleToUser": message.visibleToUser,
            });
        });
    }

    FileView {
        id: chatSaveFile
        property string chatName: ""
        path: chatName.length > 0 ? `${Directories.aiChats}/${chatName}.json` : ""
        blockLoading: true
    }

    function saveChat(chatName) {
        chatSaveFile.chatName = chatName.trim();
        const saveContent = JSON.stringify(root.chatToJson());
        chatSaveFile.setText(saveContent);
        getSavedChats.running = true;
    }

    function loadChat(chatName) {
        try {
            chatSaveFile.chatName = chatName.trim();
            chatSaveFile.reload();
            const saveContent = chatSaveFile.text();
            const saveData = JSON.parse(saveContent);
            root.clearMessages();
            root.messageIDs = saveData.map((_, i) => i);
            for (let i = 0; i < saveData.length; i++) {
                const message = saveData[i];
                if (message.model) root.ensureModel(message.model);
                root.messageByID[i] = root.aiMessageComponent.createObject(root, {
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "content": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": message.thinking,
                    "done": message.done,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionResponse": message.functionResponse,
                    "visibleToUser": message.visibleToUser,
                });
            }
        } catch (e) {
            console.log("[Ai] Could not load chat:", e);
        } finally {
            getSavedChats.running = true;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SESSION HISTORY — List, switch, delete OpenCode sessions
    // ═══════════════════════════════════════════════════════════════════════

    signal sessionsLoaded(var sessions)
    signal sessionDeleted(string sessionId)
    property var sessionsList: []
    property bool sessionsLoading: false

    // List sessions — GET /session
    Process {
        id: listSessionsProc
        running: false
        command: ["curl", "-s", root.apiBase + "/session"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sessionsLoading = false;
                if (text.length === 0) return;
                try {
                    const sessions = JSON.parse(text);
                    // Filter out subtask sessions (those with parentID) and sort by time
                    const filtered = sessions
                        .filter(s => !s.parentID)
                        .sort((a, b) => {
                            const ta = a.time?.updated ?? a.time?.created ?? "";
                            const tb = b.time?.updated ?? b.time?.created ?? "";
                            return tb.localeCompare(ta); // newest first
                        });
                    root.sessionsList = filtered;
                    root.sessionsLoaded(filtered);
                } catch (e) {
                    console.log("[Ai] Session list parse error:", e);
                }
            }
        }
    }

    function listSessions() {
        root.sessionsLoading = true;
        listSessionsProc.running = false;
        listSessionsProc.running = true;
    }

    // Load messages from a session — GET /session/{id}/message
    Process {
        id: loadSessionMessagesProc
        running: false
        property string targetSessionId: ""
        property string targetSessionTitle: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                try {
                    const messages = JSON.parse(text);
                    root.clearMessages();
                    root.sessionId = loadSessionMessagesProc.targetSessionId;
                    root.sessionTitle = loadSessionMessagesProc.targetSessionTitle;

                    for (let i = 0; i < messages.length; i++) {
                        const msg = messages[i];
                        const info = msg.info;
                        const parts = msg.parts ?? [];
                        if (!info || !info.role) continue;
                        // Skip system messages
                        if (info.role === "system") continue;

                        // Reconstruct content from parts
                        let content = "";
                        for (let j = 0; j < parts.length; j++) {
                            const part = parts[j];
                            if (part.type === "text") {
                                content += part.text ?? "";
                            } else if (part.type === "reasoning") {
                                content += "<think>\n" + (part.text ?? "") + "\n</think>\n\n";
                            } else if (part.type === "tool") {
                                const tool = part.tool ?? "tool";
                                const state = part.state ?? {};
                                const title = state.title ?? tool;
                                const status = state.status ?? "completed";
                                const output = state.output ?? state.error ?? "";
                                const input = state.input ? JSON.stringify(state.input) : "";
                                content += `\n\n<tool name="${tool}" title="${title.replace(/"/g, '&quot;')}" status="${status}"${input ? ` input="${input.replace(/"/g, '&quot;').substring(0, 500)}"` : ""}>${output ? output.substring(0, 2000) : ""}</tool>\n\n`;
                            } else if (part.type === "subtask") {
                                const agent = part.agent ?? "general";
                                const desc = part.description ?? "";
                                const prompt = part.prompt ?? "";
                                const inp = JSON.stringify({ agent: agent, description: desc, prompt: prompt.substring(0, 500) });
                                content += `\n\n<tool name="task" title="${desc.replace(/"/g, '&quot;')}" status="completed" input="${inp.replace(/"/g, '&quot;')}">${agent} agent: ${desc}</tool>\n\n`;
                            }
                        }

                        const modelId = (info.providerID && info.modelID) ? (info.providerID + "/" + info.modelID) : "";
                        if (modelId) root.ensureModel(modelId);

                        const aiMsg = root.aiMessageComponent.createObject(root, {
                            "role": info.role,
                            "content": content,
                            "rawContent": content,
                            "thinking": false,
                            "done": true,
                            "model": modelId,
                        });
                        const id = root.idForMessage(aiMsg);
                        root.messageIDs = [...root.messageIDs, id];
                        root.messageByID[id] = aiMsg;
                    }
                } catch (e) {
                    console.log("[Ai] Session messages load error:", e);
                    root.addMessage("**Error:** Could not load session messages.", root.interfaceRole);
                }
            }
        }
    }

    function switchSession(sid, title) {
        loadSessionMessagesProc.targetSessionId = sid;
        loadSessionMessagesProc.targetSessionTitle = title || "";
        loadSessionMessagesProc.running = false;
        loadSessionMessagesProc.command = ["curl", "-s", root.apiBase + "/session/" + sid + "/message"];
        loadSessionMessagesProc.running = true;
    }

    // Delete a session — DELETE /session/{id}
    Process {
        id: deleteSessionProc
        running: false
        property string targetSessionId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const code = text.trim();
                if (code === "200" || code === "204") {
                    root.sessionDeleted(deleteSessionProc.targetSessionId);
                    // If we deleted the active session, clear
                    if (deleteSessionProc.targetSessionId === root.sessionId) {
                        root.clearMessages();
                    }
                    // Refresh list
                    root.listSessions();
                } else {
                    console.log("[Ai] Delete session error, HTTP:", code);
                }
            }
        }
    }

    function deleteSession(sid) {
        deleteSessionProc.targetSessionId = sid;
        deleteSessionProc.running = false;
        deleteSessionProc.command = [
            "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "-X", "DELETE",
            root.apiBase + "/session/" + sid
        ];
        deleteSessionProc.running = true;
    }
}
