import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    // Translations
    Translations {
        id: i18n
        currentLanguage: Plasmoid.configuration.language || "system"
    }

    // ── Primary usage (weekly / primary) ──
    property real weeklyUsagePercent: 0
    property var weeklyResetTime: null
    property int weeklyWindowMinutes: 10080

    // ── Secondary usage (optional) ──
    property real secondaryUsagePercent: 0
    property var secondaryResetTime: null
    property int secondaryWindowMinutes: 0
    property bool hasSecondary: false

    // ── Account ──
    property string planName: ""
    property string accountEmail: ""

    // ── State ──
    property string lastUpdate: ""
    property string errorMsg: ""
    property bool isLoading: false

    // ── Snapshot timestamp from the log entry ──
    property var snapshotAt: null

    // ── Token stats from log entry ──
    property real totalInputTokens: 0
    property real totalOutputTokens: 0
    property real totalCachedTokens: 0
    property real totalReasoningTokens: 0
    property real lastInputTokens: 0
    property real lastOutputTokens: 0
    property real lastReasoningTokens: 0

    // ── Network error ──
    property bool hasNetworkError: false
    readonly property bool metricsVisible: root.errorMsg === "" || root.hasNetworkError

    // ── Process & version ──
    property bool codexRunning: true
    property string codexVersion: ""
    property string latestVersion: ""
    readonly property bool updateAvailable: Plasmoid.configuration.enableUpdateCheck !== false
        && root.codexVersion !== "" && root.latestVersion !== ""
        && isNewerVersion(root.latestVersion, root.codexVersion)

    // ── Trend history ──
    property var usageSamples: []

    // ── Quick links ──
    property var parsedQuickLinks: []

    // ── Stale detection ──
    property double lastSuccessTime: 0
    property double lastFetchTime: 0
    property bool isStale: false
    readonly property int staleThresholdMs: Math.max(Plasmoid.configuration.refreshInterval || 5, 1) * 60000 * 3

    // ── Time-aware coloring ──
    property double nowTick: Date.now()
    readonly property real weeklyTimePct: elapsedPct(root.weeklyResetTime, root.weeklyWindowMinutes * 60000)

    // ── Notification state ──
    property var alertedThresholds: ({})

    // ── Visibility ──
    readonly property bool showUsageStats: {
        var vis = Plasmoid.configuration.processVisibility || "always"
        return vis === "always" || root.codexRunning
    }

    // ── Panel styling ──
    readonly property bool isVerticalLayout: Plasmoid.configuration.panelLayout === "vertical"
    readonly property string effectivePanelStyle: {
        var s = Plasmoid.configuration.panelStyle || "ring"
        return s === "circular" ? "ring" : s
    }
    readonly property bool useTimeAware: Plasmoid.configuration.useTimeAwareColors !== false

    // ── Background ──
    readonly property bool isOnPanel: Plasmoid.location === PlasmaCore.Types.TopEdge
        || Plasmoid.location === PlasmaCore.Types.BottomEdge
        || Plasmoid.location === PlasmaCore.Types.LeftEdge
        || Plasmoid.location === PlasmaCore.Types.RightEdge
    readonly property bool useCustomBackground: !isOnPanel && Plasmoid.configuration.backgroundOpacity < 1.0
    Plasmoid.backgroundHints: root.useCustomBackground ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground

    // ── Card/classic popup switch ──
    readonly property bool useCardPopup: (Plasmoid.configuration.popupStyle || "card") === "card"

    // ────────────────────────────────────────────────
    // Quick links
    // ────────────────────────────────────────────────
    function reloadQuickLinks() {
        try { parsedQuickLinks = JSON.parse(Plasmoid.configuration.quickLinks || "[]") }
        catch (e) { parsedQuickLinks = [] }
    }

    Connections {
        target: Plasmoid.configuration
        function onQuickLinksChanged() { root.reloadQuickLinks() }
    }

    // ────────────────────────────────────────────────
    // Cache writer
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: cacheWriter
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName) }
    }

    // ────────────────────────────────────────────────
    // Cache reader
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: cacheReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (stdout.length > 10) {
                try {
                    var cache = JSON.parse(stdout)
                    var age = Date.now() - (cache.timestamp || 0)
                    if (age < 86400000) {
                        root.weeklyUsagePercent = cache.weekly || 0
                        root.weeklyWindowMinutes = cache.weeklyWindowMinutes || 10080
                        root.weeklyResetTime = cache.weeklyResetTs ? new Date(cache.weeklyResetTs) : null
                        root.hasSecondary = cache.hasSecondary || false
                        root.secondaryUsagePercent = cache.secondary || 0
                        root.secondaryWindowMinutes = cache.secondaryWindowMinutes || 0
                        root.secondaryResetTime = cache.secondaryResetTs ? new Date(cache.secondaryResetTs) : null
                        root.planName = cache.plan || ""
                        root.totalInputTokens = cache.totalInput || 0
                        root.totalOutputTokens = cache.totalOutput || 0
                        root.totalCachedTokens = cache.totalCached || 0
                        root.totalReasoningTokens = cache.totalReasoning || 0
                        root.lastInputTokens = cache.lastInput || 0
                        root.lastOutputTokens = cache.lastOutput || 0
                        root.usageSamples = cache.samples || []
                        root.lastSuccessTime = cache.timestamp
                        root.lastUpdate = Qt.formatTime(new Date(cache.timestamp), "hh:mm:ss") + " *"
                        root.isStale = age > root.staleThresholdMs
                        console.log("Codex Usage: Loaded cache, age:", Math.round(age / 60000), "min, stale:", root.isStale)
                    } else {
                        console.log("Codex Usage: Cache too old, ignoring")
                    }
                } catch (e) {
                    console.log("Codex Usage: Cache parse error:", e)
                }
            }
        }
    }

    function saveCache() {
        var cache = {
            weekly: root.weeklyUsagePercent,
            weeklyWindowMinutes: root.weeklyWindowMinutes,
            weeklyResetTs: root.weeklyResetTime ? root.weeklyResetTime.getTime() : null,
            hasSecondary: root.hasSecondary,
            secondary: root.secondaryUsagePercent,
            secondaryWindowMinutes: root.secondaryWindowMinutes,
            secondaryResetTs: root.secondaryResetTime ? root.secondaryResetTime.getTime() : null,
            plan: root.planName,
            totalInput: root.totalInputTokens,
            totalOutput: root.totalOutputTokens,
            totalCached: root.totalCachedTokens,
            totalReasoning: root.totalReasoningTokens,
            lastInput: root.lastInputTokens,
            lastOutput: root.lastOutputTokens,
            samples: root.usageSamples,
            timestamp: Date.now()
        }
        var json = JSON.stringify(cache)
        cacheWriter.connectSource("echo '" + json.replace(/'/g, "'\\''") + "' > $HOME/.local/share/codex-usage-cache.json")
    }

    // ────────────────────────────────────────────────
    // Stale checker
    // ────────────────────────────────────────────────
    Timer {
        id: staleTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            if (root.lastSuccessTime > 0) {
                root.isStale = (Date.now() - root.lastSuccessTime) > root.staleThresholdMs
            }
        }
    }

    // ────────────────────────────────────────────────
    // Clock timer (for time-aware coloring)
    // ────────────────────────────────────────────────
    Timer {
        id: clockTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.nowTick = Date.now()
    }

    // ────────────────────────────────────────────────
    // Process checker (visibility feature)
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: processChecker
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = data["stdout"] || ""
            disconnectSource(sourceName)

            var wasRunning = root.codexRunning
            root.codexRunning = stdout.trim().length > 0

            var vis = Plasmoid.configuration.processVisibility || "always"
            if (vis === "fully_hidden") {
                Plasmoid.status = root.codexRunning
                    ? PlasmaCore.Types.ActiveStatus
                    : PlasmaCore.Types.HiddenStatus
            }

            if (root.codexRunning && !wasRunning) {
                fetchUsage()
            }
        }
    }

    function checkCodexProcess() {
        processChecker.connectSource("pgrep -f codex 2>/dev/null")
    }

    function updateProcessVisibility() {
        var vis = Plasmoid.configuration.processVisibility || "always"
        if (vis === "always") {
            root.codexRunning = true
            Plasmoid.status = PlasmaCore.Types.ActiveStatus
        } else if (vis === "hide_usage") {
            Plasmoid.status = PlasmaCore.Types.ActiveStatus
            checkCodexProcess()
        } else {
            Plasmoid.status = PlasmaCore.Types.HiddenStatus
            checkCodexProcess()
        }
    }

    Timer {
        id: processCheckTimer
        interval: Math.max(Plasmoid.configuration.processCheckInterval || 30, 5) * 1000
        running: (Plasmoid.configuration.processVisibility || "always") !== "always"
        repeat: true
        onTriggered: checkCodexProcess()
    }

    Connections {
        target: Plasmoid.configuration
        function onProcessVisibilityChanged() {
            updateProcessVisibility()
        }
    }

    // ────────────────────────────────────────────────
    // Account info (email from auth.json JWT)
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: authReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (stdout.length > 0) {
                try {
                    var authData = JSON.parse(stdout)
                    var idToken = (authData.tokens || {}).id_token || ""
                    if (idToken) {
                        var parts = idToken.split(".")
                        if (parts.length >= 2) {
                            var payload = parts[1]
                            payload = payload.replace(/-/g, "+").replace(/_/g, "/")
                            while (payload.length % 4) payload += "="
                            var decoded = Qt.atob(payload)
                            var claims = JSON.parse(decoded)
                            if (claims.email) {
                                root.accountEmail = claims.email
                                console.log("Codex Usage: Account email:", root.accountEmail)
                            }
                        }
                    }
                } catch (e) {
                    console.log("Codex Usage: Auth parse error:", e)
                }
            }
        }
    }

    // ────────────────────────────────────────────────
    // Version detection
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: versionReader
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            var match = stdout.match(/(\d+\.\d+\.\d+)/)
            if (match) {
                root.codexVersion = match[1]
                console.log("Codex Usage: Detected version:", root.codexVersion)
            }
        }
    }

    // ────────────────────────────────────────────────
    // Update checker (npm registry)
    // ────────────────────────────────────────────────
    Timer {
        id: updateCheckTimer
        interval: 21600000
        running: Plasmoid.configuration.enableUpdateCheck !== false
        repeat: true
        onTriggered: checkForUpdate()
        onRunningChanged: if (running) checkForUpdate()
    }

    Plasma5Support.DataSource {
        id: updateChecker
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (stdout.length > 2) {
                try {
                    root.latestVersion = JSON.parse(stdout).version || ""
                    console.log("Codex Usage: latest version:", root.latestVersion, "installed:", root.codexVersion)
                } catch (e) { console.log("Codex Usage: update check parse error:", e) }
            } else {
                console.log("Codex Usage: update check failed, no response")
            }
        }
    }

    function checkForUpdate() {
        if (Plasmoid.configuration.enableUpdateCheck === false) return
        updateChecker.connectSource("curl -sS --max-time 10 https://registry.npmjs.org/@openai/codex/latest 2>/dev/null")
    }

    // Version recheck timer: runs while updateAvailable to detect upgrade
    Timer {
        id: versionRecheckTimer
        interval: 60000
        running: root.updateAvailable && Plasmoid.configuration.enableUpdateCheck !== false
        repeat: true
        onTriggered: versionReader.connectSource("codex --version 2>/dev/null")
        onRunningChanged: if (running) versionReader.connectSource("codex --version 2>/dev/null")
    }

    // ────────────────────────────────────────────────
    // Desktop notifications
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: notifier
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName) }
    }

    function sendNotification(title, body) {
        if (Plasmoid.configuration.enableNotifications === false) return
        var esc = function(s) { return String(s).replace(/'/g, "'\\''") }
        notifier.connectSource("notify-send -a 'Codex Usage' -i codex-usage-widget '" + esc(title) + "' '" + esc(body) + "'")
    }

    function checkFieldAlert(field, label, percent, timePct, thresholds) {
        var last = root.alertedThresholds[field] || 0

        if (percent < thresholds[0]) {
            if (last !== 0) {
                var updated = root.alertedThresholds
                updated[field] = 0
                root.alertedThresholds = updated
                if (last >= 95 && percent < 20) {
                    sendNotification(i18n.tr("Quota Reset"), label + ": " + i18n.tr("quota has been reset. Codex is ready to use again."))
                }
            }
            return
        }

        var crossed = 0
        for (var i = 0; i < thresholds.length; i++) {
            if (percent >= thresholds[i]) crossed = thresholds[i]
        }
        if (crossed <= last) return

        var updatedUp = root.alertedThresholds
        updatedUp[field] = crossed
        root.alertedThresholds = updatedUp

        if (root.useTimeAware && crossed < 90 && timePct >= 0 && percent <= timePct) return

        sendNotification(i18n.tr("Usage Notice"), label + " " + i18n.tr("usage has reached") + " " + Math.round(percent) + "%")
    }

    function checkAlerts() {
        checkFieldAlert("weekly", i18n.tr("Weekly"), root.weeklyUsagePercent, root.weeklyTimePct, [50, 80, 95])
    }

    // ────────────────────────────────────────────────
    // Data fetcher (shell script)
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: usageFetcher
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            root.isLoading = false

            if (stdout === "NODATA" || stdout.length < 5) {
                root.errorMsg = i18n.tr("No session logs found")
                console.log("Codex Usage: No data from fetch script")
                return
            }

            try {
                var entry = JSON.parse(stdout)
                var payload = entry.payload || entry
                var rateLimits = payload.rate_limits || {}
                var info = payload.info || {}

                // Primary usage
                var primary = rateLimits.primary
                if (primary) {
                    root.weeklyUsagePercent = primary.used_percent || 0
                    root.weeklyWindowMinutes = primary.window_minutes || 10080
                    if (primary.resets_at) {
                        root.weeklyResetTime = new Date(primary.resets_at * 1000)
                    }
                }

                // Secondary usage (optional)
                var secondary = rateLimits.secondary
                if (secondary && typeof secondary === "object") {
                    root.hasSecondary = true
                    root.secondaryUsagePercent = secondary.used_percent || 0
                    root.secondaryWindowMinutes = secondary.window_minutes || 0
                    if (secondary.resets_at) {
                        root.secondaryResetTime = new Date(secondary.resets_at * 1000)
                    }
                } else {
                    root.hasSecondary = false
                    root.secondaryUsagePercent = 0
                    root.secondaryWindowMinutes = 0
                    root.secondaryResetTime = null
                }

                // Plan type
                var planType = rateLimits.plan_type || ""
                var planMap = {
                    "pro": "Pro",
                    "plus": "Plus",
                    "team": "Team"
                }
                root.planName = planMap[planType] || (planType ? planType.charAt(0).toUpperCase() + planType.slice(1) : "")

                // Token stats
                var total = info.total_token_usage || {}
                root.totalInputTokens = total.input_tokens || 0
                root.totalOutputTokens = total.output_tokens || 0
                root.totalCachedTokens = total.cached_input_tokens || 0
                root.totalReasoningTokens = total.reasoning_output_tokens || 0

                var last = info.last_token_usage || {}
                root.lastInputTokens = last.input_tokens || 0
                root.lastOutputTokens = last.output_tokens || 0
                root.lastReasoningTokens = last.reasoning_output_tokens || 0

                // Snapshot time
                if (entry.timestamp) {
                    root.snapshotAt = new Date(entry.timestamp)
                }

                root.lastUpdate = Qt.formatTime(new Date(), "hh:mm:ss")
                root.lastSuccessTime = Date.now()
                root.isStale = false
                root.errorMsg = ""

                // Trend history
                var samples = root.usageSamples.slice()
                var nowTs = Date.now()
                if (samples.length === 0 || nowTs - samples[samples.length - 1].t >= 900000) {
                    samples.push({ t: nowTs, weekly: root.weeklyUsagePercent })
                }
                root.usageSamples = samples.filter(function(s) { return nowTs - s.t < 604800000 })

                root.nowTick = Date.now()
                checkAlerts()
                saveCache()

                console.log("Codex Usage: Data loaded - weekly:", root.weeklyUsagePercent, "plan:", root.planName)
            } catch (e) {
                console.log("Codex Usage: JSON parse error:", e)
                root.errorMsg = i18n.tr("Parse error")
            }
        }
    }

    function fetchUsage() {
        var now = Date.now()
        if (root.lastFetchTime > 0 && (now - root.lastFetchTime) < 55000) {
            console.log("Codex Usage: Skipping fetch, too soon since last request")
            root.isLoading = false
            return
        }
        root.lastFetchTime = now
        root.isLoading = true
        root.errorMsg = ""

        var script = Qt.resolvedUrl("../scripts/fetch_usage.sh").toString().replace("file://", "")
        usageFetcher.connectSource("sh '" + script + "'")
    }

    function refresh() {
        root.lastFetchTime = 0
        fetchUsage()
    }

    // ────────────────────────────────────────────────
    // Refresh timer
    // ────────────────────────────────────────────────
    Timer {
        id: refreshTimer
        interval: Math.max(Plasmoid.configuration.refreshInterval || 5, 1) * 60000
        running: true
        repeat: true
        onTriggered: fetchUsage()
    }

    // ────────────────────────────────────────────────
    // Terminal launcher
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: codexLauncher
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            console.log("Codex Usage: Terminal launched")
        }
    }

    function launchInTerminal(cmd) {
        codexLauncher.connectSource("bash -c 'cd $HOME && if command -v konsole >/dev/null; then konsole --hold -e bash -lc \"" + cmd + "\"; elif command -v gnome-terminal >/dev/null; then gnome-terminal -- bash -lc \"" + cmd + "; exec bash\"; elif command -v xfce4-terminal >/dev/null; then xfce4-terminal --hold -e \"bash -lc \\\"" + cmd + "\\\"\"; elif command -v xterm >/dev/null; then xterm -hold -e bash -lc \"" + cmd + "\"; fi &'")
    }

    // ────────────────────────────────────────────────
    // Icon installer
    // ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: iconInstaller
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) { disconnectSource(sourceName) }
    }

    // ────────────────────────────────────────────────
    // Helper functions
    // ────────────────────────────────────────────────
    function elapsedPct(resetTime, periodMs) {
        if (!resetTime) return -1
        var remaining = resetTime.getTime() - root.nowTick
        if (remaining <= 0 || remaining > periodMs) return -1
        return Math.max(0, Math.min(100, (periodMs - remaining) / periodMs * 100))
    }

    function getUsageColor(percent, timePct) {
        if (timePct === undefined || timePct === null || timePct < 0) {
            if (percent < 50) return Kirigami.Theme.positiveTextColor
            if (percent < 80) return Kirigami.Theme.neutralTextColor
            return Kirigami.Theme.negativeTextColor
        }
        if (percent >= 100 || percent > timePct) return Kirigami.Theme.negativeTextColor
        if (percent > timePct * 0.75) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.positiveTextColor
    }

    function formatTimeRemaining(resetTime) {
        if (!resetTime) return ""
        var now = new Date()
        var diff = resetTime.getTime() - now.getTime()
        if (diff <= 0) return ""

        var hours = Math.floor(diff / (1000 * 60 * 60))
        var minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))

        if (hours > 24) {
            var days = Math.floor(hours / 24)
            hours = hours % 24
            return days + i18n.tr("d") + " " + hours + i18n.tr("h")
        } else if (hours > 0) {
            return hours + i18n.tr("h") + " " + minutes + i18n.tr("m")
        } else {
            return minutes + i18n.tr("m")
        }
    }

    function formatTokens(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
        if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
        return "" + n
    }

    function isNewerVersion(a, b) {
        var pa = a.split(".").map(Number)
        var pb = b.split(".").map(Number)
        for (var i = 0; i < 3; i++) {
            if ((pa[i] || 0) > (pb[i] || 0)) return true
            if ((pa[i] || 0) < (pb[i] || 0)) return false
        }
        return false
    }

    // ────────────────────────────────────────────────
    // Compact representation (panel)
    // ────────────────────────────────────────────────
    compactRepresentation: CompactView {}

    // ────────────────────────────────────────────────
    // Full representation (popup)
    // ────────────────────────────────────────────────
    fullRepresentation: Item {
        id: fullRepItem

        readonly property bool classicScrollable: Plasmoid.configuration.scrollableContent === true

        property var classicCardOrder: []

        function parseClassicCardOrder() {
            try {
                classicCardOrder = JSON.parse(Plasmoid.configuration.cardOrder || "[]")
            } catch (e) {
                classicCardOrder = []
            }
            if (classicCardOrder.length === 0) {
                classicCardOrder = [
                    {id: "usage", enabled: true},
                    {id: "tokens", enabled: true},
                    {id: "codex", enabled: true},
                    {id: "trend", enabled: true},
                    {id: "links", enabled: true}
                ]
            }
        }

        Component.onCompleted: parseClassicCardOrder()
        Connections {
            target: Plasmoid.configuration
            function onCardOrderChanged() { fullRepItem.parseClassicCardOrder() }
        }

        property var classicCardComponents: ({
            "usage": classicUsageComp,
            "tokens": classicTokensComp,
            "codex": classicCodexComp,
            "trend": classicTrendComp,
            "links": classicLinksComp
        })

        function classicCardVisible(id) {
            if (id === "tokens") return root.totalInputTokens > 0 || root.totalOutputTokens > 0
            if (id === "codex") return root.codexVersion !== ""
            if (id === "trend") return root.usageSamples.length >= 2
            if (id === "links") return root.parsedQuickLinks.length > 0
            return true
        }

        property real targetWidth: root.useCardPopup
            ? (cardLoader.item ? cardLoader.item.Layout.preferredWidth : Kirigami.Units.gridUnit * 17)
            : Kirigami.Units.gridUnit * 16
        property real targetHeight: root.useCardPopup
            ? (cardLoader.item ? cardLoader.item.Layout.preferredHeight : Kirigami.Units.gridUnit * 20)
            : classicColumn.implicitHeight + Kirigami.Units.largeSpacing * 2

        Layout.minimumWidth: root.useCardPopup
            ? (cardLoader.item ? cardLoader.item.Layout.minimumWidth : Kirigami.Units.gridUnit * 16)
            : Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: root.useCardPopup
            ? (cardLoader.item ? cardLoader.item.Layout.minimumHeight : Kirigami.Units.gridUnit * 16)
            : fullRepItem.classicScrollable ? Kirigami.Units.gridUnit * 4 : Math.min(classicColumn.implicitHeight + Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 24)
        Layout.preferredWidth: targetWidth
        Layout.preferredHeight: targetHeight
        Layout.maximumWidth: resizeForcer.running ? targetWidth : -1
        Layout.maximumHeight: resizeForcer.running ? targetHeight : -1

        onTargetWidthChanged: resizeForcer.restart()
        onTargetHeightChanged: resizeForcer.restart()

        Timer {
            id: resizeForcer
            interval: 150
        }

        Loader {
            id: cardLoader
            anchors.fill: parent
            anchors.margins: root.useCustomBackground ? Kirigami.Units.mediumSpacing : 0
            active: root.useCardPopup
            source: "FullView.qml"
        }

        // ── Classic popup Components ──

        Component {
            id: classicUsageComp
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                // Primary (weekly) usage
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: i18n.tr("Weekly")
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Label {
                            text: Math.round(root.weeklyUsagePercent) + "%"
                            color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 10
                        radius: 5
                        color: Kirigami.Theme.backgroundColor
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                        Rectangle {
                            width: parent.width * Math.min(root.weeklyUsagePercent / 100, 1)
                            height: parent.height
                            radius: 5
                            color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
                        }
                    }

                    PlasmaComponents.Label {
                        visible: root.weeklyResetTime !== null
                        text: i18n.tr("Resets:") + " " + (root.weeklyResetTime ? Qt.formatDateTime(root.weeklyResetTime, "MMM d, hh:mm") : "") + (root.weeklyResetTime ? " (" + formatTimeRemaining(root.weeklyResetTime) + ")" : "")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                // Secondary usage (if present)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: root.hasSecondary

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: i18n.tr("Secondary")
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Label {
                            text: Math.round(root.secondaryUsagePercent) + "%"
                            color: root.getUsageColor(root.secondaryUsagePercent)
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 10
                        radius: 5
                        color: Kirigami.Theme.backgroundColor
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                        Rectangle {
                            width: parent.width * Math.min(root.secondaryUsagePercent / 100, 1)
                            height: parent.height
                            radius: 5
                            color: root.getUsageColor(root.secondaryUsagePercent)
                        }
                    }

                    PlasmaComponents.Label {
                        visible: root.secondaryResetTime !== null
                        text: i18n.tr("Resets:") + " " + (root.secondaryResetTime ? Qt.formatDateTime(root.secondaryResetTime, "MMM d, hh:mm") : "") + (root.secondaryResetTime ? " (" + formatTimeRemaining(root.secondaryResetTime) + ")" : "")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        Component {
            id: classicTokensComp
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: i18n.tr("Token Stats (Total)")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Input")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.totalInputTokens)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Output")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.totalOutputTokens)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Cached")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.totalCachedTokens)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Reasoning")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.totalReasoningTokens)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    height: 1
                    color: Kirigami.Theme.disabledTextColor
                    opacity: 0.2
                }

                PlasmaComponents.Label {
                    text: i18n.tr("Last Request")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Input")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.lastInputTokens)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Output")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.lastOutputTokens)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        Component {
            id: classicCodexComp
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: "Codex CLI"
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Installed")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.codexVersion
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        Component {
            id: classicTrendComp
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: i18n.tr("7-day trend")
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                TrendChart {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    samples: root.usageSamples
                    lineColor: "#10a37f"
                }
            }
        }

        Component {
            id: classicLinksComp
            RowLayout {
                Layout.topMargin: Kirigami.Units.smallSpacing

                Item { Layout.fillWidth: true }
                Repeater {
                    model: root.parsedQuickLinks
                    PlasmaComponents.Button {
                        required property var modelData
                        text: modelData.name
                        icon.name: modelData.icon || "internet-web-browser"
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        onClicked: Qt.openUrlExternally(modelData.url)
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ── Classic popup layout ──
        Item {
            anchors.fill: parent
            anchors.margins: root.useCustomBackground ? Kirigami.Units.mediumSpacing : 0
            visible: !root.useCardPopup

            ColumnLayout {
                id: classicColumn
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.mediumSpacing

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: i18n.tr("Codex Usage")
                        font.bold: true
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.3
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        visible: root.planName !== ""
                        Layout.preferredWidth: classicPlanLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                        Layout.preferredHeight: classicPlanLabel.implicitHeight + Kirigami.Units.smallSpacing
                        radius: 3
                        color: Kirigami.Theme.highlightColor
                        PlasmaComponents.Label {
                            id: classicPlanLabel
                            anchors.centerIn: parent
                            text: root.planName
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: Kirigami.Theme.highlightedTextColor
                        }
                    }
                }

                // Scrollable middle content
                Flickable {
                    id: classicFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: fullRepItem.classicScrollable
                    Layout.preferredHeight: classicScrollContent.implicitHeight
                    contentHeight: classicScrollContent.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    PlasmaComponents.ScrollBar.vertical: PlasmaComponents.ScrollBar {
                        id: classicScrollBar
                        policy: classicFlickable.contentHeight > classicFlickable.height
                            ? PlasmaComponents.ScrollBar.AsNeeded
                            : PlasmaComponents.ScrollBar.AlwaysOff
                        leftInset: 0
                        rightInset: 0
                        rightPadding: 0
                    }

                    ColumnLayout {
                        id: classicScrollContent
                        width: classicFlickable.width - (classicScrollBar.visible ? classicScrollBar.width : 0)
                        spacing: 0

                        // Error message
                        Rectangle {
                            visible: root.errorMsg !== ""
                            Layout.fillWidth: true
                            Layout.preferredHeight: classicErrorCol.implicitHeight + Kirigami.Units.largeSpacing
                            radius: 5
                            color: Kirigami.Theme.negativeBackgroundColor

                            ColumnLayout {
                                id: classicErrorCol
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing

                                PlasmaComponents.Label {
                                    text: root.errorMsg
                                    color: Kirigami.Theme.negativeTextColor
                                    font.bold: true
                                }
                                PlasmaComponents.Label {
                                    text: root.errorMsg === i18n.tr("No session logs found")
                                        ? i18n.tr("Run 'codex' to generate session logs")
                                        : i18n.tr("Will retry automatically")
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    color: Kirigami.Theme.negativeTextColor
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Kirigami.Theme.disabledTextColor
                            opacity: 0.3
                        }

                        // Dynamic classic sections via cardOrder
                        Repeater {
                            model: {
                                void(root.totalInputTokens, root.totalOutputTokens, root.usageSamples, root.parsedQuickLinks)
                                return fullRepItem.classicCardOrder.filter(function(c) {
                                    return c.enabled && fullRepItem.classicCardComponents[c.id] !== undefined && fullRepItem.classicCardVisible(c.id)
                                })
                            }
                            delegate: ColumnLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 0

                                Rectangle {
                                    visible: index > 0
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    Layout.bottomMargin: 2
                                    height: 1
                                    color: Kirigami.Theme.disabledTextColor
                                    opacity: 0.3
                                }

                                Loader {
                                    Layout.fillWidth: true
                                    sourceComponent: fullRepItem.classicCardComponents[modelData.id] || null
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            visible: (Plasmoid.configuration.refreshInterval || 5) < 2
                            text: i18n.tr("Values under 2 min may cause excessive disk reads")
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: Kirigami.Theme.neutralTextColor
                            font.italic: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Footer (outside Flickable, always visible)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    height: 1
                    color: Kirigami.Theme.disabledTextColor
                    opacity: 0.3
                }

                Rectangle {
                    visible: root.updateAvailable
                    Layout.fillWidth: true
                    Layout.preferredHeight: classicUpdateRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.alpha("#10a37f", 0.12)

                    RowLayout {
                        id: classicUpdateRow
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            text: "Codex " + root.latestVersion + " " + i18n.tr("available")
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.bold: true
                            color: "#10a37f"
                        }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Button {
                            text: i18n.tr("Update")
                            icon.name: "update-none"
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            onClicked: root.launchInTerminal("npm update -g @openai/codex")
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: root.lastUpdate !== "" ? i18n.tr("Updated:") + " " + root.lastUpdate : i18n.tr("Loading...")
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Button {
                        icon.name: "view-refresh"
                        text: i18n.tr("Refresh")
                        onClicked: root.refresh()
                    }
                }
            }
        }
    }

    // ────────────────────────────────────────────────
    // Custom background (desktop only)
    // ────────────────────────────────────────────────
    Rectangle {
        visible: root.useCustomBackground
        anchors.fill: parent
        color: "transparent"
        radius: Kirigami.Units.cornerRadius
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        border.width: 1

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Kirigami.Theme.backgroundColor
            opacity: Plasmoid.configuration.backgroundOpacity
        }
    }

    // ────────────────────────────────────────────────
    // Tooltip
    // ────────────────────────────────────────────────
    Plasmoid.icon: "codex-usage-widget"
    toolTipMainText: i18n.tr("Codex Usage")
    toolTipSubText: {
        var parts = []
        if (Plasmoid.configuration.showWeekly !== false) {
            var weeklyStr = i18n.tr("Weekly") + ": " + Math.round(root.weeklyUsagePercent) + "%"
            var weeklyRemaining = formatTimeRemaining(root.weeklyResetTime)
            if (weeklyRemaining) weeklyStr += " (" + weeklyRemaining + ")"
            parts.push(weeklyStr)
        }
        if (root.hasSecondary) {
            parts.push(i18n.tr("Secondary") + ": " + Math.round(root.secondaryUsagePercent) + "%")
        }
        return parts.join(" | ")
    }

    // ────────────────────────────────────────────────
    // Initialization
    // ────────────────────────────────────────────────
    Component.onCompleted: {
        console.log("Codex Usage: Widget loaded")
        reloadQuickLinks()
        var iconSource = Qt.resolvedUrl("../icons/codex-usage-widget.svg").toString().replace("file://", "")
        iconInstaller.connectSource("bash -c 'ICON_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps && mkdir -p $ICON_DIR && cp \"" + iconSource + "\" $ICON_DIR/codex-usage-widget.svg && chmod 644 $ICON_DIR/codex-usage-widget.svg 2>/dev/null'")
        cacheReader.connectSource("cat $HOME/.local/share/codex-usage-cache.json 2>/dev/null")
        authReader.connectSource("cat ${CODEX_CONFIG_DIR:-$HOME/.codex}/auth.json 2>/dev/null")
        versionReader.connectSource("codex --version 2>/dev/null")
        if (Plasmoid.configuration.enableUpdateCheck !== false) checkForUpdate()
        fetchUsage()
        updateProcessVisibility()
    }
}
