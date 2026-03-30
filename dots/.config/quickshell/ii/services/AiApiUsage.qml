pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

/**
 * AI API usage tracking service.
 * Fetches usage data from GitHub, Claude.ai, and OpenRouter.
 *
 * Required API keys in KeyringStorage.keyringData.apiKeys:
 *   - github_token         : GitHub personal access token
 *   - claude_session_cookie: Claude.ai sessionKey cookie value
 *                            (open DevTools → Application → Cookies → claude.ai → sessionKey)
 *   - openrouter_api_key   : OpenRouter API key
 */
Singleton {
    id: root

    readonly property int fetchIntervalMs: (Config.options?.bar?.aiApiUsage?.fetchInterval ?? 2) * 60 * 1000

    property var github: ({
        used: 0, limit: 5000, remaining: 5000,
        reset: 0, loaded: false, error: false
    })
    property var claude: ({
        fiveHourUtilization: 0, fiveHourResetAt: 0,
        sevenDayUtilization: 0, sevenDayResetAt: 0,
        loaded: false, error: false
    })
    property var openrouter: ({
        balance: 0.0, totalCredits: 0.0,
        loaded: false, error: false
    })

    readonly property real githubPercentage: github.limit > 0 ? Math.min(1, github.used / github.limit) : 0
    readonly property real claudePercentage: Math.min(1, claude.fiveHourUtilization / 100)
    readonly property real openrouterPercentage: Math.max(0, Math.min(1, openrouter.balance / 20))

    property string lastRefresh: ""

    function fetchAll() {
        root.lastRefresh = new Date().toLocaleTimeString(Qt.locale(), "h:mm ap")
        if (!KeyringStorage.loaded) {
            KeyringStorage.fetchKeyringData()
            return
        }
        fetchGithub()
        fetchClaude()
        fetchOpenrouter()
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            if (KeyringStorage.loaded) root.fetchAll()
        }
    }

    function fetchGithub() {
        const token = KeyringStorage.keyringData?.apiKeys?.github_token ?? ""
        if (!token || !(Config.options?.bar?.aiApiUsage?.github?.enable ?? true)) return
        // Uses Copilot internal API to track premium interaction quota
        githubFetcher.command[2] = `curl -sf -m 10 \
            -H "Authorization: Bearer ${token}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            https://api.github.com/copilot_internal/user | \
            jq '{
                used:      (.quota_snapshots.premium_interactions.entitlement - (.quota_snapshots.premium_interactions.remaining | floor)),
                limit:     .quota_snapshots.premium_interactions.entitlement,
                remaining: (.quota_snapshots.premium_interactions.remaining | floor),
                reset:     (.quota_reset_date_utc | split(".")[0] + "Z" | fromdateiso8601)
            }'`
        githubFetcher.running = true
    }

    function fetchClaude() {
        const sessionKey = KeyringStorage.keyringData?.apiKeys?.claude_session_cookie ?? ""
        if (!sessionKey || !(Config.options?.bar?.aiApiUsage?.claude?.enable ?? true)) return
        // Unofficial Claude.ai internal API — may change without notice
        // Step 1: get org UUID from /api/account, then fetch usage from /api/organizations/{uuid}/usage
        claudeFetcher.command[2] = `
            ORG=$(curl -sf -m 10 \
                -H "Cookie: sessionKey=${sessionKey}" \
                -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64)" \
                -H "Referer: https://claude.ai" \
                https://claude.ai/api/account | jq -r '.memberships[0].organization.uuid // empty') && \
            [ -n "$ORG" ] && \
            curl -sf -m 10 \
                -H "Cookie: sessionKey=${sessionKey}" \
                -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64)" \
                -H "Referer: https://claude.ai" \
                "https://claude.ai/api/organizations/$ORG/usage" | \
            jq '{
                fiveHourUtilization: (.five_hour.utilization // 0),
                fiveHourResetAt:     ((.five_hour.resets_at // null) | if . then (split(".")[0] + "Z" | fromdateiso8601) else 0 end),
                sevenDayUtilization: (.seven_day.utilization // 0),
                sevenDayResetAt:     ((.seven_day.resets_at // null) | if . then (split(".")[0] + "Z" | fromdateiso8601) else 0 end)
            }'`
        claudeFetcher.running = true
    }

    function fetchOpenrouter() {
        const key = KeyringStorage.keyringData?.apiKeys?.openrouter_api_key ?? ""
        if (!key || !(Config.options?.bar?.aiApiUsage?.openrouter?.enable ?? true)) return
        openrouterFetcher.command[2] = `curl -sf -m 10 \
            -H "Authorization: Bearer ${key}" \
            https://openrouter.ai/api/v1/credits | \
            jq '{balance: ((.data.total_credits // 0) - (.data.total_usage // 0)), totalSpent: (.data.total_usage // 0)}'`
        openrouterFetcher.running = true
    }

    Process {
        id: githubFetcher
        command: ["bash", "-c", ""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0) {
                    root.github = Object.assign({}, root.github, { error: true, loaded: true })
                    return
                }
                try {
                    const d = JSON.parse(text)
                    root.github = {
                        used: d.used ?? 0,
                        limit: d.limit ?? 5000,
                        remaining: d.remaining ?? 5000,
                        reset: d.reset ?? 0,
                        loaded: true, error: false
                    }
                } catch (e) {
                    root.github = Object.assign({}, root.github, { error: true, loaded: true })
                    console.error("[AiApiUsage] GitHub:", e.message)
                }
            }
        }
    }

    Process {
        id: claudeFetcher
        command: ["bash", "-c", ""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0) {
                    root.claude = Object.assign({}, root.claude, { error: true, loaded: true })
                    return
                }
                try {
                    const d = JSON.parse(text)
                    root.claude = {
                        fiveHourUtilization: d.fiveHourUtilization ?? 0,
                        fiveHourResetAt: d.fiveHourResetAt ?? 0,
                        sevenDayUtilization: d.sevenDayUtilization ?? 0,
                        sevenDayResetAt: d.sevenDayResetAt ?? 0,
                        loaded: true, error: false
                    }
                } catch (e) {
                    root.claude = Object.assign({}, root.claude, { error: true, loaded: true })
                    console.error("[AiApiUsage] Claude:", e.message)
                }
            }
        }
    }

    Process {
        id: openrouterFetcher
        command: ["bash", "-c", ""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0) {
                    root.openrouter = Object.assign({}, root.openrouter, { error: true, loaded: true })
                    return
                }
                try {
                    const d = JSON.parse(text)
                    root.openrouter = {
                        balance: d.balance ?? 0,
                        totalSpent: d.totalSpent ?? 0,
                        loaded: true, error: false
                    }
                } catch (e) {
                    root.openrouter = Object.assign({}, root.openrouter, { error: true, loaded: true })
                    console.error("[AiApiUsage] OpenRouter:", e.message)
                }
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: root.fetchIntervalMs
        triggeredOnStart: true
        onTriggered: root.fetchAll()
    }
}
