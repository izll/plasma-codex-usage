/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: full
    clip: true

    readonly property color accent: "#10a37f"
    readonly property color cardColor: Qt.alpha(Kirigami.Theme.textColor, 0.07)

    property double footerNow: Date.now()

    Timer {
        interval: 1000
        running: full.visible
        repeat: true
        onTriggered: full.footerNow = Date.now()
    }

    readonly property string statusText: {
        if (root.lastSuccessTime <= 0) return i18n.tr("Loading...")
        var ago = Math.max(0, Math.floor((full.footerNow - root.lastSuccessTime) / 1000))
        var duration
        if (ago < 60) duration = ago + "s"
        else if (ago < 3600) duration = Math.floor(ago / 60) + "m"
        else duration = Math.floor(ago / 3600) + "h " + Math.floor((ago % 3600) / 60) + "m"
        var text = i18n.tr("Updated {duration} ago").replace("{duration}", duration)
        return text
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 19
    Layout.preferredWidth: Kirigami.Units.gridUnit * 21
    readonly property bool scrollable: Plasmoid.configuration.scrollableContent === true
    Layout.minimumHeight: full.scrollable ? Kirigami.Units.gridUnit * 4 : (mainColumn.implicitHeight + Kirigami.Units.smallSpacing * 2)
    Layout.preferredHeight: mainColumn.implicitHeight + Kirigami.Units.smallSpacing * 2

    property var cardOrder: []

    function parseCardOrder() {
        try {
            cardOrder = JSON.parse(Plasmoid.configuration.cardOrder || "[]")
        } catch (e) {
            cardOrder = []
        }
        if (cardOrder.length === 0) {
            cardOrder = [
                {id: "account", enabled: true},
                {id: "usage", enabled: true},
                {id: "tokens", enabled: true},
                {id: "codex", enabled: true},
                {id: "trend", enabled: true},
                {id: "links", enabled: true}
            ]
        }
    }

    Component.onCompleted: parseCardOrder()
    Connections {
        target: Plasmoid.configuration
        function onCardOrderChanged() { full.parseCardOrder() }
    }

    function isCardContentVisible(cardId) {
        switch (cardId) {
            case "account": return root.accountEmail !== "" || root.planName !== ""
            case "usage": return true
            case "tokens": return root.totalInputTokens > 0 || root.totalOutputTokens > 0
            case "codex": return root.codexVersion !== ""
            case "trend": return root.usageSamples.length >= 2
            case "links": return root.parsedQuickLinks.length > 0
            default: return true
        }
    }

    property var cardComponents: ({
        "account": cardAccountComp,
        "usage": cardUsageComp,
        "tokens": cardTokensComp,
        "codex": cardCodexComp,
        "trend": cardTrendComp,
        "links": cardLinksComp
    })

    // ===== Card Component definitions =====

    Component {
        id: cardAccountComp
        Rectangle {
            visible: root.accountEmail !== "" || root.planName !== ""
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? accountInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: accountInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                    text: i18n.tr("Account")
                }

                RowLayout {
                    visible: root.accountEmail !== ""
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: i18n.tr("Email"); opacity: 0.65 }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.accountEmail
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    visible: root.planName !== ""
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: i18n.tr("Plan"); opacity: 0.65 }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.planName
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    Component {
        id: cardUsageComp
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.mediumSpacing

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Kirigami.Units.cornerRadius
                color: full.cardColor
                implicitHeight: weeklyCol.implicitHeight + Kirigami.Units.mediumSpacing * 2

                ColumnLayout {
                    id: weeklyCol
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.mediumSpacing
                    spacing: Kirigami.Units.smallSpacing

                    UsageRing {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.hasSecondary ? 56 : 72
                        Layout.preferredHeight: root.hasSecondary ? 56 : 72
                        percent: root.weeklyUsagePercent
                        ringColor: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
                        markerRel: root.useTimeAware && root.weeklyTimePct >= 0 ? root.weeklyTimePct / 100 : -1
                        lineWidth: root.hasSecondary ? 5 : 6; showPercentSign: true; fontScale: 0.22
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: i18n.tr("Weekly")
                        font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.weeklyResetTime !== null && root.formatTimeRemaining(root.weeklyResetTime) !== ""
                        text: i18n.tr("resets in") + " " + root.formatTimeRemaining(root.weeklyResetTime)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.65; elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                visible: root.hasSecondary
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Kirigami.Units.cornerRadius
                color: full.cardColor
                implicitHeight: secondaryCol.implicitHeight + Kirigami.Units.mediumSpacing * 2

                ColumnLayout {
                    id: secondaryCol
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.mediumSpacing
                    spacing: Kirigami.Units.smallSpacing

                    UsageRing {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 56; Layout.preferredHeight: 56
                        percent: root.secondaryUsagePercent
                        ringColor: root.getUsageColor(root.secondaryUsagePercent, root.useTimeAware ? root.secondaryTimePct : undefined)
                        markerRel: root.useTimeAware && root.secondaryTimePct >= 0 ? root.secondaryTimePct / 100 : -1
                        lineWidth: 5; showPercentSign: true; fontScale: 0.22
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: i18n.tr("Secondary")
                        font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.secondaryResetTime !== null && root.formatTimeRemaining(root.secondaryResetTime) !== ""
                        text: i18n.tr("resets in") + " " + root.formatTimeRemaining(root.secondaryResetTime)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.65; elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Component {
        id: cardTokensComp
        Rectangle {
            visible: root.totalInputTokens > 0 || root.totalOutputTokens > 0
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? tokensInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: tokensInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1; font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                        text: i18n.tr("Token Usage")
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label { text: i18n.tr("session logs"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.55 }
                }

                readonly property bool hasLast: root.lastInputTokens > 0 || root.lastOutputTokens > 0

                GridLayout {
                    Layout.fillWidth: true
                    columns: tokensInner.hasLast ? 3 : 2
                    columnSpacing: Kirigami.Units.mediumSpacing
                    rowSpacing: Kirigami.Units.smallSpacing / 2

                    // Column headers
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: i18n.tr("Total")
                        font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.7; Layout.alignment: Qt.AlignRight
                    }
                    PlasmaComponents.Label {
                        visible: tokensInner.hasLast
                        text: i18n.tr("Last Request")
                        font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.7; Layout.alignment: Qt.AlignRight
                    }

                    // Input row
                    PlasmaComponents.Label {
                        text: "↓ " + i18n.tr("Input"); opacity: 0.65
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.totalInputTokens)
                        font.bold: true; Layout.alignment: Qt.AlignRight
                    }
                    PlasmaComponents.Label {
                        visible: tokensInner.hasLast
                        text: root.formatTokens(root.lastInputTokens)
                        Layout.alignment: Qt.AlignRight
                    }

                    // Output row
                    PlasmaComponents.Label {
                        text: "↑ " + i18n.tr("Output"); opacity: 0.65
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    PlasmaComponents.Label {
                        text: root.formatTokens(root.totalOutputTokens)
                        font.bold: true; Layout.alignment: Qt.AlignRight
                    }
                    PlasmaComponents.Label {
                        visible: tokensInner.hasLast
                        text: root.formatTokens(root.lastOutputTokens)
                        Layout.alignment: Qt.AlignRight
                    }

                    // Cached row
                    PlasmaComponents.Label {
                        visible: root.totalCachedTokens > 0
                        text: "⟳ " + i18n.tr("Cached"); opacity: 0.65
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    PlasmaComponents.Label {
                        visible: root.totalCachedTokens > 0
                        text: root.formatTokens(root.totalCachedTokens)
                        font.bold: true; Layout.alignment: Qt.AlignRight
                    }
                    Item {
                        visible: root.totalCachedTokens > 0 && tokensInner.hasLast
                    }

                    // Reasoning row
                    PlasmaComponents.Label {
                        visible: root.totalReasoningTokens > 0 || root.lastReasoningTokens > 0
                        text: "🧠 " + i18n.tr("Reasoning"); opacity: 0.65
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    PlasmaComponents.Label {
                        visible: root.totalReasoningTokens > 0 || root.lastReasoningTokens > 0
                        text: root.totalReasoningTokens > 0 ? root.formatTokens(root.totalReasoningTokens) : "—"
                        font.bold: root.totalReasoningTokens > 0; Layout.alignment: Qt.AlignRight
                    }
                    PlasmaComponents.Label {
                        visible: (root.totalReasoningTokens > 0 || root.lastReasoningTokens > 0) && tokensInner.hasLast
                        text: root.lastReasoningTokens > 0 ? root.formatTokens(root.lastReasoningTokens) : "—"
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }
    }

    Component {
        id: cardCodexComp
        Rectangle {
            visible: root.codexVersion !== ""
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? codexInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: codexInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1; font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                    text: "Codex CLI"
                }
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: i18n.tr("Installed"); opacity: 0.65 }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label { text: root.codexVersion }
                }
            }
        }
    }

    Component {
        id: cardTrendComp
        Rectangle {
            visible: root.usageSamples.length >= 2
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? trendInner.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            ColumnLayout {
                id: trendInner
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1; font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.2; font.bold: true; opacity: 0.55
                        text: i18n.tr("7-day trend")
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label { text: i18n.tr("weekly usage"); font.pixelSize: Kirigami.Theme.smallFont.pixelSize; opacity: 0.55 }
                }

                TrendChart {
                    Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                    samples: root.usageSamples; lineColor: "#10a37f"
                }
            }
        }
    }

    Component {
        id: cardLinksComp
        Rectangle {
            visible: root.parsedQuickLinks.length > 0
            Layout.fillWidth: true
            radius: Kirigami.Units.cornerRadius
            color: full.cardColor
            implicitHeight: visible ? linksFlow.implicitHeight + Kirigami.Units.mediumSpacing * 2 : 0

            RowLayout {
                id: linksFlow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.mediumSpacing
                spacing: Kirigami.Units.smallSpacing
                Item { Layout.fillWidth: true }

                Repeater {
                    model: root.parsedQuickLinks
                    delegate: Rectangle {
                        radius: Kirigami.Units.cornerRadius
                        color: linkMa.containsMouse
                            ? Qt.alpha(Kirigami.Theme.textColor, 0.15)
                            : Qt.alpha(Kirigami.Theme.textColor, 0.08)
                        implicitWidth: linkRow.implicitWidth + Kirigami.Units.mediumSpacing * 2
                        implicitHeight: linkRow.implicitHeight + Kirigami.Units.smallSpacing * 2

                        RowLayout {
                            id: linkRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                source: modelData.icon || "internet-web-browser"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }
                            PlasmaComponents.Label {
                                text: modelData.name
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }
                        }
                        MouseArea {
                            id: linkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(modelData.url)
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    // ===== Main layout =====

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        anchors.leftMargin: Kirigami.Units.mediumSpacing
        anchors.rightMargin: Kirigami.Units.mediumSpacing
        spacing: Kirigami.Units.smallSpacing

        // ===== Header (always shown) =====
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/codex.svg")
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            PlasmaComponents.Label {
                text: i18n.tr("Codex Usage")
                font.bold: true
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.25
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                visible: root.planName !== ""
                Layout.preferredWidth: planLabel.implicitWidth + Kirigami.Units.largeSpacing
                Layout.preferredHeight: planLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: height / 2
                color: Qt.alpha(full.accent, 0.18)

                PlasmaComponents.Label {
                    id: planLabel
                    anchors.centerIn: parent
                    text: root.planName
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true; color: full.accent
                }
            }
        }

        // ===== Card content =====
        Flickable {
            id: cardFlickable
            Layout.fillWidth: true
            Layout.fillHeight: full.scrollable
            Layout.preferredHeight: scrollContent.implicitHeight
            contentHeight: scrollContent.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            PlasmaComponents.ScrollBar.vertical: PlasmaComponents.ScrollBar {
                id: cardScrollBar
                policy: cardFlickable.contentHeight > cardFlickable.height
                    ? PlasmaComponents.ScrollBar.AsNeeded
                    : PlasmaComponents.ScrollBar.AlwaysOff
                leftInset: 0
                rightInset: 0
                rightPadding: 0
            }

            ColumnLayout {
                id: scrollContent
                width: cardFlickable.width - (cardScrollBar.visible ? cardScrollBar.width : 0)
                spacing: Kirigami.Units.smallSpacing

                // ===== Error cards =====
                Rectangle {
                    visible: root.errorMsg !== "" && !root.hasNetworkError
                    Layout.fillWidth: true
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.12)
                    implicitHeight: errorColumn.implicitHeight + Kirigami.Units.largeSpacing * 2

                    ColumnLayout {
                        id: errorColumn
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            text: "⚠ " + root.errorMsg
                            color: Kirigami.Theme.negativeTextColor
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        PlasmaComponents.Label {
                            text: i18n.tr("Will retry automatically")
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: Kirigami.Theme.negativeTextColor
                        }
                    }
                }

                // Network error notice (cached data still shown)
                Rectangle {
                    visible: root.hasNetworkError
                    Layout.fillWidth: true
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.alpha(Kirigami.Theme.neutralTextColor, 0.12)
                    implicitHeight: cardNetErrorLabel.implicitHeight + Kirigami.Units.largeSpacing * 2

                    PlasmaComponents.Label {
                        id: cardNetErrorLabel
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        text: "⚠ " + i18n.tr("Network error - showing cached data")
                        color: Kirigami.Theme.neutralTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        wrapMode: Text.WordWrap
                    }
                }

                // Stale data notice
                Rectangle {
                    visible: root.isStale
                    Layout.fillWidth: true
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.alpha(Kirigami.Theme.neutralTextColor, 0.12)
                    implicitHeight: staleLabel.implicitHeight + Kirigami.Units.largeSpacing * 2

                    PlasmaComponents.Label {
                        id: staleLabel
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        text: "⚠ " + i18n.tr("Data may be stale")
                        color: Kirigami.Theme.neutralTextColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        wrapMode: Text.WordWrap
                    }
                }

                // ===== Dynamic cards from cardOrder =====
                Repeater {
                    id: cardsRepeater
                    model: full.cardOrder

                    Item {
                        id: cardWrapper
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: cardContent.item ? cardContent.item.implicitHeight : 0
                        visible: modelData.enabled !== false && full.isCardContentVisible(modelData.id)

                        Loader {
                            id: cardContent
                            active: cardWrapper.modelData.enabled !== false
                            anchors.left: parent.left
                            anchors.right: parent.right
                            sourceComponent: full.cardComponents[cardWrapper.modelData.id] || null
                        }
                    }
                }

                // Refresh-interval warning
                PlasmaComponents.Label {
                    visible: (Plasmoid.configuration.refreshInterval || 5) < 5
                    text: "⚠ " + i18n.tr("Values under 5 min may cause rate limiting")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.neutralTextColor
                    font.italic: true
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }

                // ===== Footer =====
                RowLayout {
                    id: footerRow
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        visible: root.updateAvailable
                        Layout.preferredWidth: updateLabel.implicitWidth + Kirigami.Units.largeSpacing
                        Layout.preferredHeight: updateLabel.implicitHeight + Kirigami.Units.smallSpacing
                        radius: height / 2
                        color: Qt.alpha(full.accent, 0.18)

                        PlasmaComponents.Label {
                            id: updateLabel
                            anchors.centerIn: parent
                            text: "⬆ " + root.latestVersion + " " + i18n.tr("available")
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.bold: true; color: full.accent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchInTerminal("codex update")
                        }
                    }

                    PlasmaComponents.Label {
                        text: full.statusText
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.65; elide: Text.ElideRight
                        Layout.fillWidth: false
                    }

                    Item { Layout.fillWidth: true }

                    PlasmaComponents.ToolButton {
                        icon.name: "view-refresh"
                        text: i18n.tr("Refresh")
                        onClicked: root.refresh()
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
