pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions as CF
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string discoveryScriptPath: CF.FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/roku/discover.py"))
    property list<var> devices: []
    readonly property list<var> availableDevices: devices.filter(device => device.available !== false)
    readonly property bool hasDevices: availableDevices.length > 0
    readonly property string preferredDeviceId: Config.options.background.widgets.roku.preferredDeviceId
    property string selectedDeviceId: ""
    readonly property var selectedDevice: availableDevices.find(device => device.id === selectedDeviceId) ?? null
    readonly property var preferredDevice: availableDevices.find(device => device.id === preferredDeviceId) ?? null
    readonly property var activeDevice: selectedDevice ?? preferredDevice ?? availableDevices[0] ?? null
    readonly property bool activeDeviceIsLimited: activeDevice?.ecpSettingMode === "limited"
    readonly property int fastDiscoveryIntervalMs: Math.max(10, Config.options.background.widgets.roku.discoveryInterval) * 1000
    readonly property int connectedDiscoveryIntervalMs: Math.max(180, Config.options.background.widgets.roku.discoveryInterval * 6) * 1000
    property bool isDiscovering: false
    property bool commandPending: false
    property string lastError: ""
    property string lastCommand: ""

    function refreshDevices() {
        if (!Config.ready || root.isDiscovering)
            return;

        root.lastError = "";
        root.isDiscovering = true;
        discoveryProc.exec(["python3", root.discoveryScriptPath, "--timeout", String(Math.max(0.5, Config.options.background.widgets.roku.discoveryTimeout))]);
    }

    function selectDevice(deviceId) {
        root.selectedDeviceId = deviceId ?? "";
    }

    function setPreferredDeviceId(deviceId) {
        const normalizedId = deviceId ?? "";
        Config.options.background.widgets.roku.preferredDeviceId = normalizedId;
        root.selectedDeviceId = normalizedId;
    }

    function clearDeviceSelection() {
        root.selectedDeviceId = "";
    }

    function keyAllowedInLimitedMode(commandKey) {
        return ["VolumeUp", "VolumeDown", "VolumeMute"].includes(commandKey);
    }

    function sendKey(key) {
        const commandKey = String(key ?? "").trim();
        if (commandKey.length === 0)
            return;

        if (!root.activeDevice) {
            root.lastError = "No Roku device is available.";
            return;
        }

        if (root.activeDeviceIsLimited && !root.keyAllowedInLimitedMode(commandKey)) {
            root.lastError = "This Roku is in limited network control mode. Only volume buttons work until Network access is set to Enabled on the TV.";
            return;
        }

        root.lastCommand = commandKey;
        root.lastError = "";
        root.commandPending = true;
        commandProc.exec([
            "curl",
            "-fsS",
            "-m",
            "2",
            "-o",
            "/dev/null",
            "-X",
            "POST",
            `http://${root.activeDevice.host}:8060/keypress/${commandKey}`
        ]);
    }

    function home() { sendKey("Home"); }
    function back() { sendKey("Back"); }
    function up() { sendKey("Up"); }
    function down() { sendKey("Down"); }
    function left() { sendKey("Left"); }
    function right() { sendKey("Right"); }
    function select() { sendKey("Select"); }
    function playPause() { sendKey("Play"); }
    function rewind() { sendKey("Rev"); }
    function fastForward() { sendKey("Fwd"); }
    function instantReplay() { sendKey("InstantReplay"); }
    function info() { sendKey("Info"); }
    function search() { sendKey("Search"); }
    function power() { sendKey("Power"); }
    function volumeUp() { sendKey("VolumeUp"); }
    function volumeDown() { sendKey("VolumeDown"); }
    function volumeMute() { sendKey("VolumeMute"); }

    onDevicesChanged: {
        if (root.selectedDeviceId.length > 0 && !root.availableDevices.some(device => device.id === root.selectedDeviceId))
            root.selectedDeviceId = "";
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                root.refreshDevices();
        }
    }

    Timer {
        interval: (root.activeDevice && root.lastError.length === 0)
            ? root.connectedDiscoveryIntervalMs
            : root.fastDiscoveryIntervalMs
        repeat: true
        running: Config.ready && Config.options.background.widgets.roku.enable
        onTriggered: root.refreshDevices()
    }

    Component.onCompleted: {
        if (Config.ready)
            root.refreshDevices();
    }

    Process {
        id: discoveryProc

        stdout: StdioCollector {
            id: discoveryStdout

            onStreamFinished: {
                const payload = text.trim();
                if (payload.length === 0) {
                    root.devices = [];
                    return;
                }

                try {
                    const parsed = JSON.parse(payload);
                    root.devices = Array.isArray(parsed) ? parsed : [];
                } catch (error) {
                    root.devices = [];
                    root.lastError = `Failed to parse Roku discovery output: ${error}`;
                }
            }
        }

        stderr: StdioCollector {
            id: discoveryStderr
        }

        onExited: (exitCode, exitStatus) => {
            root.isDiscovering = false;
            if (exitCode !== 0) {
                const message = discoveryStderr.text.trim();
                root.lastError = message.length > 0 ? message : "Roku discovery failed.";
            } else if (root.devices.length === 0 && discoveryStderr.text.trim().length > 0) {
                root.lastError = discoveryStderr.text.trim();
            }
        }
    }

    Process {
        id: commandProc

        stderr: StdioCollector {
            id: commandStderr
        }

        onExited: (exitCode, exitStatus) => {
            root.commandPending = false;
            if (exitCode !== 0) {
                const message = commandStderr.text.trim();
                root.lastError = message.length > 0 ? message : `Failed to send Roku command ${root.lastCommand}.`;
            }
        }
    }
}
