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
    property int cfg_refreshInterval
    property bool cfg_enableNotifications
    property bool cfg_enableUpdateCheck
    property bool cfg_useTimeAwareColors
    property string cfg_processVisibility
    property int cfg_processCheckInterval

    // Translation helper
    Translations {
        id: trans
        currentLanguage: cfg_language || "system"
    }

    function tr(text) { return trans.tr(text); }

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
        QQC2.ComboBox {
            id: languageCombo
            Kirigami.FormData.label: tr("Language:")

            model: languageNames
            currentIndex: languageValues.indexOf(cfg_language)

            onActivated: index => {
                cfg_language = languageValues[index]
            }
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

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Notifications:")
            text: tr("Threshold and reset notifications")
            checked: cfg_enableNotifications
            onCheckedChanged: cfg_enableNotifications = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: tr("Update check:")
            text: tr("Check for Codex CLI updates")
            checked: cfg_enableUpdateCheck
            onCheckedChanged: cfg_enableUpdateCheck = checked
        }

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
    }
}
