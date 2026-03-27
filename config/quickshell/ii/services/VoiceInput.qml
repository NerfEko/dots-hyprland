pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions as CF
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Voice input service.
 * Manages real-time STT via faster-whisper, audio level visualizer via CAVA,
 * LLM text processing via Ollama, and text injection via wtype.
 */
Singleton {
    id: root

    // ── Public state ────────────────────────────────────────────────────────
    property bool isListening: false
    property bool isLoading: false    // model loading on first start
    property bool isGenerating: false // LLM running
    property bool llmMode: false      // showing LLM output (not raw transcript)
    property string liveText: ""      // current partial segment (in-progress)
    property string fullText: ""      // finalized transcript
    property string llmText: ""       // LLM generated text
    property string undoText: ""      // pre-LLM snapshot for undo
    property list<real> audioBars: [] // 50 values 0..1 for visualizer

    readonly property bool canUndo: llmMode && undoText.length > 0

    readonly property string displayText: llmMode ? llmText
        : fullText.length > 0
            ? (liveText.length > 0 ? fullText + " " + liveText : fullText)
            : liveText

    // ── Script paths ────────────────────────────────────────────────────────
    readonly property string scriptPath:
        CF.FileUtils.trimFileProtocol(`${Directories.scriptPath}/voice/transcribe-venv.sh`)
    readonly property string cavaConfigPath:
        CF.FileUtils.trimFileProtocol(`${Directories.scriptPath}/voice/voice_input_cava.txt`)

    // ── Public API ──────────────────────────────────────────────────────────

    function startListening() {
        if (isListening || isLoading) return
        fullText   = ""
        liveText   = ""
        llmText    = ""
        undoText   = ""
        llmMode    = false
        audioBars  = []
        isLoading  = true
        sttProc.running = true
    }

    function stopListening() {
        sttProc.running  = false  // SIGTERM → script flushes buffer → prints final segment
        cavaProc.running = false
        if (isGenerating) { llmProc.running = false; isGenerating = false }
        isListening = false
        isLoading   = false
        audioBars   = []
        // flush any in-progress partial into fullText
        if (liveText.length > 0) {
            fullText = (fullText + " " + liveText).trim()
            liveText = ""
        }
    }

    function cleanText() {
        if (displayText.trim().length === 0) return
        const src = llmMode ? llmText : fullText
        if (src.trim().length === 0) return
        const prompt = `Fix grammar, punctuation, and formatting of this transcribed speech. Output only the corrected text, nothing else:\n\n${src}`
        runLlm(prompt)
    }

    function summarizeText() {
        if (displayText.trim().length === 0) return
        const src = llmMode ? llmText : fullText
        if (src.trim().length === 0) return
        const prompt = `Summarize this text concisely in 1–3 sentences. Output only the summary, nothing else:\n\n${src}`
        runLlm(prompt)
    }

    function copyText() {
        const text = llmMode ? llmText : fullText
        if (text.trim().length > 0)
            Quickshell.clipboardText = text
    }

    function acceptText() {
        const text = llmMode ? llmText : displayText
        if (text.trim().length === 0) {
            GlobalStates.voiceInputOpen = false
            return
        }
        const addr = GlobalStates.voiceInputPreviousWindowAddress
        GlobalStates.voiceInputOpen = false
        // Closing the popup returns keyboard focus; wait briefly then type
        injectTimer.targetText = text
        injectTimer.targetAddr = addr
        injectTimer.restart()
    }

    function resetLlm() {
        if (isGenerating) llmProc.running = false
        llmText      = ""
        undoText     = ""
        llmMode      = false
        isGenerating = false
    }

    function undoLlm() {
        if (!canUndo) return
        if (isGenerating) { llmProc.running = false; isGenerating = false }
        fullText = undoText
        undoText = ""
        llmText  = ""
        llmMode  = false
    }

    // ── Internal ─────────────────────────────────────────────────────────────

    function runLlm(prompt) {
        if (isGenerating) llmProc.running = false
        undoText     = llmMode ? undoText : fullText  // preserve original across multiple LLM runs
        llmText      = ""
        llmMode      = true
        isGenerating = true

        const payload = JSON.stringify({
            model:  "llama3.1:8b",
            prompt: prompt,
            stream: true,
        })

        llmProc.command = [
            "curl", "-s", "http://localhost:11434/api/generate",
            "-H", "Content-Type: application/json",
            "-d", payload,
        ]
        llmProc.running = true
    }

    // ── STT Process ──────────────────────────────────────────────────────────
    Process {
        id: sttProc
        command: [root.scriptPath, "base"]

        stdout: SplitParser {
            onRead: line => {
                if (line.length === 0) return
                try {
                    const obj = JSON.parse(line)
                    switch (obj.type) {
                    case "status":
                        if (obj.value === "ready") {
                            root.isLoading  = false
                            root.isListening = true
                            cavaProc.running = true
                        } else if (obj.value === "stopped") {
                            root.isListening = false
                        } else if (obj.value === "loading") {
                            root.isLoading = true
                        }
                        break
                    case "level":
                        root.audioBars = obj.bars ?? []
                        break
                    case "partial":
                        root.liveText = obj.text ?? ""
                        break
                    case "segment":
                        const seg = obj.text ?? ""
                        if (seg.length > 0)
                            root.fullText = root.fullText.length > 0
                                ? root.fullText + " " + seg
                                : seg
                        root.liveText = ""
                        break
                    case "error":
                        console.error("[VoiceInput] STT:", obj.message)
                        root.isListening = false
                        root.isLoading   = false
                        break
                    }
                } catch (e) {
                    // non-JSON line from script (e.g. pip warning) — ignore
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.isListening = false
                root.isLoading   = false
                root.audioBars   = []
                cavaProc.running = false
            }
        }
    }

    // ── CAVA audio visualizer ────────────────────────────────────────────────
    // Runs only while STT is active; provides the bar data for the wave widget.
    Process {
        id: cavaProc
        command: ["cava", "-p", root.cavaConfigPath]

        stdout: SplitParser {
            onRead: data => {
                if (!root.isListening) return
                const parts = data.split(";")
                if (parts.length < 2) return
                const bars = parts
                    .map(p => parseFloat(p.trim()))
                    .filter(v => !isNaN(v))
                    .map(v => Math.min(1.0, v / 1000.0))
                if (bars.length > 0)
                    root.audioBars = bars
            }
        }

        onRunningChanged: {
            if (!running) root.audioBars = []
        }
    }

    // ── Ollama LLM Process ───────────────────────────────────────────────────
    Process {
        id: llmProc

        stdout: SplitParser {
            onRead: line => {
                if (line.length === 0) return
                try {
                    const obj = JSON.parse(line)
                    if (typeof obj.response === "string")
                        root.llmText += obj.response
                    if (obj.done === true)
                        root.isGenerating = false
                } catch (e) {}
            }
        }

        onExited: (code, status) => {
            root.isGenerating = false
            if (code !== 0)
                console.error("[VoiceInput] Ollama exited with code", code)
        }
    }

    // ── Text injection ───────────────────────────────────────────────────────
    Timer {
        id: injectTimer
        property string targetText: ""
        property string targetAddr: ""
        interval: 180
        repeat: false
        onTriggered: {
            if (targetText.trim().length === 0) return
            // Single-quote-escape for bash
            const escaped = "'" + targetText.replace(/'/g, "'\\''") + "'"
            if (targetAddr.length > 0) {
                Quickshell.execDetached(["bash", "-c",
                    `hyprctl dispatch focuswindow address:${targetAddr} && sleep 0.08 && wtype ${escaped}`])
            } else {
                Quickshell.execDetached(["wtype", targetText])
            }
        }
    }

    // ── React to open/close ──────────────────────────────────────────────────

    // On first load the singleton may wake up after voiceInputOpen is already true,
    // so the Connections signal will have been missed — catch that here.
    Component.onCompleted: {
        if (GlobalStates.voiceInputOpen) root.startListening()
    }

    Connections {
        target: GlobalStates
        function onVoiceInputOpenChanged() {
            if (GlobalStates.voiceInputOpen) {
                root.startListening()
            } else {
                root.stopListening()
                // Reset all state when fully closed
                root.fullText    = ""
                root.liveText    = ""
                root.llmText     = ""
                root.undoText    = ""
                root.llmMode     = false
            }
        }
    }
}
