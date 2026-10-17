/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    property string cfg_language
    property string cfg_panelStyle
    property bool cfg_showWeekly
    property string cfg_panelLayout
    property int cfg_metricsScale
    property int cfg_panelMargin
    property string cfg_ringCenter
    property int cfg_ringLogoSize
    property bool cfg_showWindowLabels
    property bool cfg_showIcon
    property string cfg_panelIcon
    property int cfg_iconSize

    readonly property bool ringStyle: (cfg_panelStyle || "ring") === "ring"

    // Translation helper
    Translations {
        id: trans
        currentLanguage: cfg_language || "system"
    }

    function tr(text) { return trans.tr(text); }

    Kirigami.FormLayout {
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
            Kirigami.FormData.label: tr("Show in panel:")
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

        RowLayout {
            Kirigami.FormData.label: tr("Metrics size (panel and popup):")
            QQC2.Slider {
                from: 100
                to: 300
                stepSize: 10
                snapMode: QQC2.Slider.SnapAlways
                value: cfg_metricsScale
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                // onValueChanged, not onMoved: wheel/keyboard changes must mark the page dirty too
                onValueChanged: if (cfg_metricsScale !== value) cfg_metricsScale = value
            }
            QQC2.Label {
                text: Math.round(cfg_metricsScale) + "%"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
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

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Ring")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Ring center:")
            enabled: configPage.ringStyle
            model: [tr("Percent"), tr("Logo"), tr("Logo + %")]
            currentIndex: cfg_ringCenter === "logo" ? 1 : cfg_ringCenter === "logo_percent" ? 2 : 0
            onCurrentIndexChanged: cfg_ringCenter = ["percent", "logo", "logo_percent"][currentIndex]
        }

        RowLayout {
            Kirigami.FormData.label: tr("Ring logo size:")
            enabled: configPage.ringStyle && (cfg_ringCenter || "percent").indexOf("logo") === 0
            QQC2.Slider {
                from: 50
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways
                value: cfg_ringLogoSize
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                onValueChanged: if (cfg_ringLogoSize !== value) cfg_ringLogoSize = value
            }
            QQC2.Label {
                text: Math.round(cfg_ringLogoSize) + "%"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Window labels:")
            enabled: configPage.ringStyle
            text: tr("Show 5h/7d on rings")
            checked: cfg_showWindowLabels
            onCheckedChanged: cfg_showWindowLabels = checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: tr("Icon")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Icon:")
            text: tr("Show Codex icon")
            checked: cfg_showIcon
            onCheckedChanged: cfg_showIcon = checked
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: tr("Panel icon:")
            enabled: cfg_showIcon
            model: ["ChatGPT", "OpenAI"]
            currentIndex: (cfg_panelIcon || "chatgpt") === "openai" ? 1 : 0
            onCurrentIndexChanged: cfg_panelIcon = currentIndex === 1 ? "openai" : "chatgpt"
        }

        RowLayout {
            Kirigami.FormData.label: tr("Icon size:")
            enabled: cfg_showIcon

            QQC2.Slider {
                from: 0
                to: 64
                stepSize: 2
                snapMode: QQC2.Slider.SnapAlways
                value: cfg_iconSize
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                onValueChanged: if (cfg_iconSize !== value) cfg_iconSize = value
            }
            QQC2.Label {
                text: cfg_iconSize === 0 ? tr("Auto") : cfg_iconSize + "px"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }
    }
}
