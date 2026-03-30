import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

StyledPopup {
    id: root

    function formatReset(unixTimestamp) {
        if (!unixTimestamp) return "—"
        const secsRemaining = Math.max(0, unixTimestamp - (Date.now() / 1000))
        const mins = Math.ceil(secsRemaining / 60)
        if (mins <= 0) return Translation.tr("Now")
        if (mins < 60) return Translation.tr("%1m").arg(mins)
        return Translation.tr("%1h %2m").arg(Math.floor(mins / 60)).arg(mins % 60)
    }

    function formatResetDaysHours(unixTimestamp) {
        if (!unixTimestamp) return "—"
        const secsRemaining = Math.max(0, unixTimestamp - (Date.now() / 1000))
        const hours = Math.floor(secsRemaining / 3600)
        if (hours <= 0) return Translation.tr("Now")
        const days = Math.floor(hours / 24)
        const remHours = hours % 24
        if (days === 0) return Translation.tr("%1h").arg(hours)
        if (remHours === 0) return Translation.tr("%1d").arg(days)
        return Translation.tr("%1d %2h").arg(days).arg(remHours)
    }

    function formatUSD(amount) {
        return "$" + Number(amount).toFixed(2)
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        // Provider cards row
        RowLayout {
            spacing: 16

            // GitHub
            AiApiProviderCard {
                visible: Config.options?.bar?.aiApiUsage?.github?.enable ?? true
                name: "Copilot"
                iconName: "code"
                percentage: AiApiUsage.githubPercentage
                loaded: AiApiUsage.github.loaded
                error: AiApiUsage.github.error
                rows: [
                    {
                        icon: "bolt",
                        label: Translation.tr("Used:"),
                        value: `${AiApiUsage.github.used} / ${AiApiUsage.github.limit}`
                    },
                    {
                        icon: "check_circle",
                        label: Translation.tr("Remaining:"),
                        value: AiApiUsage.github.remaining < 0
                            ? Translation.tr("Over by %1").arg(Math.abs(AiApiUsage.github.remaining))
                            : `${AiApiUsage.github.remaining}`
                    },
                    {
                        icon: "event_repeat",
                        label: Translation.tr("Resets in:"),
                        value: root.formatResetDaysHours(AiApiUsage.github.reset)
                    }
                ]
            }

            // Vertical divider
            Rectangle {
                visible: (Config.options?.bar?.aiApiUsage?.github?.enable ?? true) &&
                         (Config.options?.bar?.aiApiUsage?.claude?.enable ?? true)
                width: 1
                Layout.fillHeight: true
                color: Appearance.colors.colOutlineVariant
                opacity: 0.5
            }

            // Claude
            AiApiProviderCard {
                visible: Config.options?.bar?.aiApiUsage?.claude?.enable ?? true
                name: "Claude"
                iconName: "psychology"
                percentage: AiApiUsage.claudePercentage
                loaded: AiApiUsage.claude.loaded
                error: AiApiUsage.claude.error
                rows: [
                    {
                        icon: "hourglass_bottom",
                        label: Translation.tr("5-hour:"),
                        value: `${Math.round(AiApiUsage.claude.fiveHourUtilization)}%`
                    },
                    {
                        icon: "schedule",
                        label: Translation.tr("Resets in:"),
                        value: AiApiUsage.claude.fiveHourResetAt > 0
                            ? root.formatReset(AiApiUsage.claude.fiveHourResetAt)
                            : "—"
                    },
                    {
                        icon: "calendar_view_week",
                        label: Translation.tr("7-day:"),
                        value: `${Math.round(AiApiUsage.claude.sevenDayUtilization)}%`
                    },
                    {
                        icon: "event_repeat",
                        label: Translation.tr("Resets in:"),
                        value: AiApiUsage.claude.sevenDayResetAt > 0
                            ? root.formatResetDaysHours(AiApiUsage.claude.sevenDayResetAt)
                            : "—"
                    }
                ]
            }

            // Vertical divider
            Rectangle {
                visible: (Config.options?.bar?.aiApiUsage?.claude?.enable ?? true) &&
                         (Config.options?.bar?.aiApiUsage?.openrouter?.enable ?? true)
                width: 1
                Layout.fillHeight: true
                color: Appearance.colors.colOutlineVariant
                opacity: 0.5
            }

            // OpenRouter
            AiApiProviderCard {
                visible: Config.options?.bar?.aiApiUsage?.openrouter?.enable ?? true
                name: "OpenRouter"
                iconName: "route"
                inverted: true
                percentage: AiApiUsage.openrouterPercentage
                loaded: AiApiUsage.openrouter.loaded
                error: AiApiUsage.openrouter.error
                rows: [
                    {
                        icon: "account_balance_wallet",
                        label: Translation.tr("Balance:"),
                        value: root.formatUSD(AiApiUsage.openrouter.balance)
                    },
                    {
                        icon: "payments",
                        label: Translation.tr("Spent:"),
                        value: root.formatUSD(AiApiUsage.openrouter.totalSpent)
                    }
                ]
            }
        }

        // Footer
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: AiApiUsage.lastRefresh.length > 0
                ? Translation.tr("Refreshed at %1").arg(AiApiUsage.lastRefresh)
                : Translation.tr("Loading…")
            font {
                weight: Font.Medium
                pixelSize: Appearance.font.pixelSize.smaller
            }
            color: Appearance.colors.colOnSurfaceVariant
            opacity: 0.7
        }
    }
}
