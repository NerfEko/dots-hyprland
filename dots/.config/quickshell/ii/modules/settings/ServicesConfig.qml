import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    Component.onCompleted: {
        if (!KeyringStorage.loaded) KeyringStorage.fetchKeyringData()
    }

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("System prompt")
            text: Config.options.ai.systemPrompt
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Qt.callLater(() => {
                    Config.options.ai.systemPrompt = text;
                });
            }
        }
    }

    ContentSection {
        icon: "key"
        title: Translation.tr("AI API Keys")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Keys are stored in the system keyring, not in config files.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
            wrapMode: Text.WordWrap
        }

        ContentSubsection {
            title: Translation.tr("GitHub")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextArea {
                    id: githubTokenField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Personal access token")
                    text: KeyringStorage.keyringData?.apiKeys?.github_token ?? ""
                    wrapMode: TextEdit.NoWrap
                }

                RippleButton {
                    Layout.fillHeight: true
                    implicitWidth: implicitHeight
                    onClicked: {
                        KeyringStorage.setNestedField(["apiKeys", "github_token"], githubTokenField.text.trim())
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "save"
                        iconSize: 20
                    }
                    StyledToolTip {
                        text: Translation.tr("Save to keyring")
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Claude.ai")

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Open DevTools → Application → Cookies → claude.ai → sessionKey")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextArea {
                    id: claudeCookieField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("sessionKey cookie value")
                    text: KeyringStorage.keyringData?.apiKeys?.claude_session_cookie ?? ""
                    wrapMode: TextEdit.NoWrap
                }

                RippleButton {
                    Layout.fillHeight: true
                    implicitWidth: implicitHeight
                    onClicked: {
                        KeyringStorage.setNestedField(["apiKeys", "claude_session_cookie"], claudeCookieField.text.trim())
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "save"
                        iconSize: 20
                    }
                    StyledToolTip {
                        text: Translation.tr("Save to keyring")
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("OpenRouter")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextArea {
                    id: openrouterKeyField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("API key")
                    text: KeyringStorage.keyringData?.apiKeys?.openrouter_api_key ?? ""
                    wrapMode: TextEdit.NoWrap
                }

                RippleButton {
                    Layout.fillHeight: true
                    implicitWidth: implicitHeight
                    onClicked: {
                        KeyringStorage.setNestedField(["apiKeys", "openrouter_api_key"], openrouterKeyField.text.trim())
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "save"
                        iconSize: 20
                    }
                    StyledToolTip {
                        text: Translation.tr("Save to keyring")
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "music_cast"
        title: Translation.tr("Music Recognition")

        ConfigSpinBox {
            icon: "timer_off"
            text: Translation.tr("Total duration timeout (s)")
            value: Config.options.musicRecognition.timeout
            from: 10
            to: 100
            stepSize: 2
            onValueChanged: {
                Config.options.musicRecognition.timeout = value;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (s)")
            value: Config.options.musicRecognition.interval
            from: 2
            to: 10
            stepSize: 1
            onValueChanged: {
                Config.options.musicRecognition.interval = value;
            }
        }
    }

    ContentSection {
        icon: "cell_tower"
        title: Translation.tr("Networking")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("User agent (for services that require it)")
            text: Config.options.networking.userAgent
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.networking.userAgent = text;
            }
        }
    }

    ContentSection {
        icon: "memory"
        title: Translation.tr("Resources")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (ms)")
            value: Config.options.resources.updateInterval
            from: 100
            to: 10000
            stepSize: 100
            onValueChanged: {
                Config.options.resources.updateInterval = value;
            }
        }
        
    }

    ContentSection {
        icon: "file_open"
        title: Translation.tr("Save paths")

        ContentSubsection {
            title: Translation.tr("Video Recording Path")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Video Recording Path")
                    text: Config.options.screenRecord.savePath
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.screenRecord.savePath = text;
                    }
                }

                RippleButton {
                    Layout.fillHeight: true
                    implicitWidth: implicitHeight
                    onClicked: {
                        videoPathDialog.open()
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "folder_open"
                        iconSize: 20
                    }
                    StyledToolTip {
                        text: Translation.tr("Browse for folder")
                    }
                }
            }
        }
        
        ContentSubsection {
            title: Translation.tr("Screenshot Path")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Screenshot Path (leave empty to just copy)")
                    text: Config.options.screenSnip.savePath
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.screenSnip.savePath = text;
                    }
                }

                RippleButton {
                    Layout.fillHeight: true
                    implicitWidth: implicitHeight
                    onClicked: {
                        screenshotPathDialog.open()
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "folder_open"
                        iconSize: 20
                    }
                    StyledToolTip {
                        text: Translation.tr("Browse for folder")
                    }
                }
            }
        }
    }

    FolderDialog {
        id: videoPathDialog
        title: Translation.tr("Select Video Recording Folder")
        onAccepted: {
            Config.options.screenRecord.savePath = videoPathDialog.selectedFolder.toString().replace("file://", "")
        }
    }

    FolderDialog {
        id: screenshotPathDialog
        title: Translation.tr("Select Screenshot Folder")
        onAccepted: {
            Config.options.screenSnip.savePath = screenshotPathDialog.selectedFolder.toString().replace("file://", "")
        }
    }

    ContentSection {
        icon: "search"
        title: Translation.tr("Search")

        ConfigSwitch {
            text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
            checked: Config.options.search.sloppy
            onCheckedChanged: {
                Config.options.search.sloppy = checked;
            }
            StyledToolTip {
                text: Translation.tr("Could be better if you make a ton of typos,\nbut results can be weird and might not work with acronyms\n(e.g. \"GIMP\" might not give you the paint program)")
            }
        }

        ContentSubsection {
            title: Translation.tr("Prefixes")
            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Action")
                    text: Config.options.search.prefix.action
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.action = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Clipboard")
                    text: Config.options.search.prefix.clipboard
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.clipboard = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Emojis")
                    text: Config.options.search.prefix.emojis
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.emojis = text;
                    }
                }
            }

            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Math")
                    text: Config.options.search.prefix.math
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.math = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Shell command")
                    text: Config.options.search.prefix.shellCommand
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.shellCommand = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Web search")
                    text: Config.options.search.prefix.webSearch
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.webSearch = text;
                    }
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Web search")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Base URL")
                text: Config.options.search.engineBaseUrl
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.search.engineBaseUrl = text;
                }
            }
        }
    }

    // There's no update indicator in ii for now so we shouldn't show this yet
    // ContentSection {
    //     icon: "deployed_code_update"
    //     title: Translation.tr("System updates (Arch only)")

    //     ConfigSwitch {
    //         text: Translation.tr("Enable update checks")
    //         checked: Config.options.updates.enableCheck
    //         onCheckedChanged: {
    //             Config.options.updates.enableCheck = checked;
    //         }
    //     }

    //     ConfigSpinBox {
    //         icon: "av_timer"
    //         text: Translation.tr("Check interval (mins)")
    //         value: Config.options.updates.checkInterval
    //         from: 60
    //         to: 1440
    //         stepSize: 60
    //         onValueChanged: {
    //             Config.options.updates.checkInterval = value;
    //         }
    //     }
    // }

    ContentSection {
        icon: "weather_mix"
        title: Translation.tr("Weather")
        ConfigRow {
            ConfigSwitch {
                buttonIcon: "assistant_navigation"
                text: Translation.tr("Enable GPS based location")
                checked: Config.options.bar.weather.enableGPS
                onCheckedChanged: {
                    Config.options.bar.weather.enableGPS = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Fahrenheit unit")
                checked: Config.options.bar.weather.useUSCS
                onCheckedChanged: {
                    Config.options.bar.weather.useUSCS = checked;
                }
                StyledToolTip {
                    text: Translation.tr("It may take a few seconds to update")
                }
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }
    }
}
