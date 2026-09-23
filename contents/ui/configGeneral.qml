/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    id: configPage

    property string cfg_language
    property int cfg_refreshInterval
    property string cfg_panelLayout
    property bool cfg_showIcon
    property int cfg_iconSize
    property string cfg_panelIcon
    property string cfg_ringCenter
    property int cfg_panelMargin
    property string cfg_panelStyle
    property bool cfg_showWeekly
    property string cfg_quickLinks
    property string cfg_popupStyle
    property bool cfg_enableNotifications
    property bool cfg_enableUpdateCheck
    property string cfg_cardOrder
    property string cfg_processVisibility
    property int cfg_processCheckInterval
    property bool cfg_useTimeAwareColors
    property double cfg_backgroundOpacity
    property bool cfg_scrollableContent

    property var quickLinksModel: []
    property var cardOrderModel: []

    readonly property var defaultCardOrder: [
        {id: "account", enabled: true},
        {id: "usage", enabled: true},
        {id: "tokens", enabled: true},
        {id: "trend", enabled: true},
        {id: "links", enabled: true}
    ]

    readonly property var cardNames: ({
        "account": "Account",
        "usage": "Usage",
        "tokens": "Token Stats",
        "trend": "7-day Trend",
        "links": "Quick Links"
    })

    function cardDisplayName(cardId) {
        return tr(cardNames[cardId] || cardId)
    }

    onCfg_cardOrderChanged: {
        try { cardOrderModel = JSON.parse(cfg_cardOrder || "[]") }
        catch (e) { cardOrderModel = defaultCardOrder.slice() }
        if (cardOrderModel.length === 0) cardOrderModel = defaultCardOrder.slice()
    }

    function saveCardOrder() {
        cfg_cardOrder = JSON.stringify(cardOrderModel)
    }

    function moveCard(index, direction) {
        var list = cardOrderModel.slice()
        var target = index + direction
        if (target < 0 || target >= list.length) return
        var tmp = list[index]
        list[index] = list[target]
        list[target] = tmp
        cardOrderModel = list
        saveCardOrder()
    }

    function toggleCard(index) {
        var list = cardOrderModel.slice()
        var item = Object.assign({}, list[index])
        item.enabled = !item.enabled
        list[index] = item
        cardOrderModel = list
        saveCardOrder()
    }

    onCfg_quickLinksChanged: {
        try { quickLinksModel = JSON.parse(cfg_quickLinks || "[]") }
        catch (e) { quickLinksModel = [] }
    }

    // Translation helper
    Translations {
        id: trans
        currentLanguage: cfg_language || "system"
    }

    function tr(text) { return trans.tr(text); }

    function updateQuickLink(index, field, value) {
        var links = quickLinksModel.slice()
        if (index >= 0 && index < links.length) {
            var link = Object.assign({}, links[index])
            link[field] = value
            links[index] = link
            cfg_quickLinks = JSON.stringify(links)
        }
    }

    function removeQuickLink(index) {
        var links = quickLinksModel.slice()
        links.splice(index, 1)
        cfg_quickLinks = JSON.stringify(links)
    }

    function addQuickLink() {
        var links = quickLinksModel.slice()
        links.push({name: "", url: "", icon: "internet-web-browser"})
        cfg_quickLinks = JSON.stringify(links)
    }

    property int iconEditIndex: -1

    readonly property var defaultQuickLinks: [
        {name: "Codex", url: "https://chatgpt.com", icon: "internet-web-browser"},
        {name: "Usage", url: "https://platform.openai.com/usage", icon: "office-chart-bar"},
        {name: "Platform", url: "https://platform.openai.com/", icon: "utilities-terminal"}
    ]

    Component.onCompleted: {
        try { quickLinksModel = JSON.parse(cfg_quickLinks || "[]") }
        catch (e) { quickLinksModel = [] }
        try { cardOrderModel = JSON.parse(cfg_cardOrder || "[]") }
        catch (e) { cardOrderModel = defaultCardOrder.slice() }
        if (cardOrderModel.length === 0) cardOrderModel = defaultCardOrder.slice()
    }

    readonly property var languageValues: [
        "system", "en_US", "hu_HU", "de_DE", "fr_FR", "es_ES",
        "it_IT", "pt_BR", "ru_RU", "pl_PL", "nl_NL", "tr_TR",
        "ja_JP", "ko_KR", "zh_CN", "zh_TW"
    ]

    readonly property var languageNames: [
        tr("System default"), "English", "Magyar", "Deutsch",
        "Français", "Español", "Italiano", "Português (Brasil)",
        "Русский", "Polski", "Nederlands", "Türkçe",
        "日本語", "한국어", "简体中文", "繁體中文"
    ]

    Kirigami.FormLayout {

        // --- Language ---

        QQC2.ComboBox {
            id: languageCombo
            Kirigami.FormData.label: tr("Language:")

            model: languageNames
            currentIndex: languageValues.indexOf(cfg_language)

            onActivated: index => {
                cfg_language = languageValues[index]
            }
        }

        // --- Panel display ---

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Panel display")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Style:")
            model: [tr("Text"), tr("Ring"), tr("Bar")]
            currentIndex: cfg_panelStyle === "ring" ? 1 : cfg_panelStyle === "bar" ? 2 : 0
            onCurrentIndexChanged: {
                var styles = ["text", "ring", "bar"]
                cfg_panelStyle = styles[currentIndex]
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Icon:")
            text: tr("Show Codex icon")
            checked: cfg_showIcon
            onCheckedChanged: cfg_showIcon = checked
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Panel icon:")
            enabled: cfg_showIcon || (cfg_ringCenter || "percent").indexOf("logo") === 0
            model: ["ChatGPT", "OpenAI"]
            currentIndex: (cfg_panelIcon || "chatgpt") === "openai" ? 1 : 0
            onCurrentIndexChanged: cfg_panelIcon = currentIndex === 1 ? "openai" : "chatgpt"
        }

        RowLayout {
            Kirigami.FormData.label: tr("Panel margin:")
            QQC2.SpinBox {
                from: 0
                to: 32
                value: cfg_panelMargin
                onValueChanged: cfg_panelMargin = value
                textFromValue: function(value) { return value + "px" }
                valueFromText: function(text) { return parseInt(text) || 0 }
            }
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Ring center:")
            model: [tr("Percent"), tr("Logo"), tr("Logo + %")]
            currentIndex: cfg_ringCenter === "logo" ? 1 : cfg_ringCenter === "logo_percent" ? 2 : 0
            onCurrentIndexChanged: cfg_ringCenter = ["percent", "logo", "logo_percent"][currentIndex]
        }

        RowLayout {
            Kirigami.FormData.label: tr("Icon size:")
            enabled: cfg_showIcon

            QQC2.SpinBox {
                from: 0
                to: 64
                stepSize: 2
                value: cfg_iconSize
                onValueChanged: cfg_iconSize = value
                textFromValue: function(value) { return value === 0 ? tr("Auto") : value + "px" }
                valueFromText: function(text) { return parseInt(text) || 0 }
            }
        }

        QQC2.CheckBox {
            text: tr("Show weekly usage")
            checked: cfg_showWeekly
            onCheckedChanged: cfg_showWeekly = checked
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Layout:")
            model: [tr("Horizontal"), tr("Vertical")]
            currentIndex: cfg_panelLayout === "vertical" ? 1 : 0
            onCurrentIndexChanged: cfg_panelLayout = currentIndex === 1 ? "vertical" : "horizontal"
        }

        // --- Widget style ---

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Widget style")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Widget style:")
            model: [tr("Classic"), tr("Card")]
            currentIndex: cfg_popupStyle === "classic" ? 0 : 1
            onCurrentIndexChanged: cfg_popupStyle = currentIndex === 0 ? "classic" : "card"
        }

        // --- Scrollable content ---

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Scrollable content:")
            text: tr("Enable scrollable content")
            checked: cfg_scrollableContent
            onToggled: cfg_scrollableContent = checked
        }

        // --- Sections ---

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Sections")
        }

        ColumnLayout {
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: configPage.cardOrderModel
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.CheckBox {
                        checked: modelData.enabled !== false
                        onClicked: configPage.toggleCard(index)
                    }

                    QQC2.Label {
                        text: configPage.cardDisplayName(modelData.id)
                        Layout.fillWidth: true
                        opacity: modelData.enabled !== false ? 1.0 : 0.5
                    }

                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: index > 0
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: configPage.moveCard(index, -1)
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    }

                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: index < configPage.cardOrderModel.length - 1
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: configPage.moveCard(index, 1)
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    }
                }
            }

            QQC2.Button {
                text: tr("Reset to default")
                icon.name: "edit-undo"
                onClicked: {
                    configPage.cardOrderModel = configPage.defaultCardOrder.slice()
                    configPage.saveCardOrder()
                }
            }
        }

        // --- Notifications ---

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Notifications")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Notifications:")
            text: tr("Threshold and reset notifications")
            checked: cfg_enableNotifications
            onCheckedChanged: cfg_enableNotifications = checked
        }

        // --- Update check ---

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Update check:")
            text: tr("Check for Codex CLI updates")
            checked: cfg_enableUpdateCheck
            onCheckedChanged: cfg_enableUpdateCheck = checked
        }

        // --- Refresh interval ---

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Refresh interval")
        }

        RowLayout {
            Kirigami.FormData.label: tr("Refresh interval:")

            QQC2.SpinBox {
                id: refreshSpinBox
                from: 1
                to: 999
                stepSize: 1
                value: cfg_refreshInterval

                onValueChanged: {
                    cfg_refreshInterval = value
                }
            }

            QQC2.Label {
                text: tr("minutes")
            }
        }

        QQC2.Label {
            visible: cfg_refreshInterval < 5
            text: "⚠ " + tr("Values under 5 min may cause rate limiting")
            color: Kirigami.Theme.negativeTextColor
            font.italic: true
            Layout.fillWidth: true
        }

        // --- Visibility ---

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Visibility")
        }

        QQC2.ComboBox {
            id: processVisibilityCombo
            Kirigami.FormData.label: tr("When Codex is not running:")
            model: [tr("Always show full widget"), tr("Hide usage, only show icon"), tr("Fully hide widget")]
            currentIndex: cfg_processVisibility === "hide_usage" ? 1 : cfg_processVisibility === "fully_hidden" ? 2 : 0
            onCurrentIndexChanged: {
                var values = ["always", "hide_usage", "fully_hidden"]
                cfg_processVisibility = values[currentIndex]
            }
        }

        RowLayout {
            Kirigami.FormData.label: tr("Process check interval:")
            enabled: processVisibilityCombo.currentIndex > 0

            QQC2.SpinBox {
                id: processCheckSpinBox
                from: 5
                to: 300
                stepSize: 5
                value: cfg_processCheckInterval

                onValueChanged: {
                    cfg_processCheckInterval = value
                }
            }

            QQC2.Label {
                text: tr("seconds")
            }
        }

        // --- Time-aware colors ---

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Colors")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Colors:")
            text: tr("Time-proportional warnings")
            checked: cfg_useTimeAwareColors
            onCheckedChanged: cfg_useTimeAwareColors = checked
        }

        // --- Background opacity ---

        RowLayout {
            Kirigami.FormData.label: tr("Background opacity (desktop):")

            QQC2.Slider {
                id: opacitySlider
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: cfg_backgroundOpacity
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10

                onMoved: {
                    cfg_backgroundOpacity = value
                }
            }

            QQC2.Label {
                text: opacitySlider.value >= 1.0 ? tr("Theme") : Math.round(opacitySlider.value * 100) + "%"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }

        // --- Quick links ---

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Quick links")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Quick links") + ":"
            text: tr("Show quick links in popup")
            checked: configPage.quickLinksModel.length > 0
            onClicked: {
                if (checked) {
                    cfg_quickLinks = JSON.stringify(configPage.defaultQuickLinks)
                } else {
                    cfg_quickLinks = "[]"
                }
            }
        }

        ColumnLayout {
            visible: configPage.quickLinksModel.length > 0
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: configPage.quickLinksModel
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        icon.name: modelData.icon || "internet-web-browser"
                        display: QQC2.AbstractButton.IconOnly
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                        onClicked: {
                            configPage.iconEditIndex = index
                            iconDialog.open()
                        }
                        QQC2.ToolTip.text: modelData.icon || ""
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.TextField {
                        text: modelData.name || ""
                        placeholderText: tr("Name")
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        onTextChanged: configPage.updateQuickLink(index, "name", text)
                    }

                    QQC2.TextField {
                        text: modelData.url || ""
                        placeholderText: "https://..."
                        Layout.fillWidth: true
                        onTextChanged: configPage.updateQuickLink(index, "url", text)
                    }

                    QQC2.Button {
                        icon.name: "edit-delete"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: configPage.removeQuickLink(index)
                    }
                }
            }

            QQC2.Button {
                icon.name: "list-add"
                text: tr("Add link")
                onClicked: configPage.addQuickLink()
            }
        }

        KIconThemes.IconDialog {
            id: iconDialog
            onIconNameChanged: {
                if (iconName && configPage.iconEditIndex >= 0) {
                    configPage.updateQuickLink(configPage.iconEditIndex, "icon", iconName)
                    configPage.iconEditIndex = -1
                }
            }
        }
    }
}
