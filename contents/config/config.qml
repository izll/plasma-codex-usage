/*
    SPDX-FileCopyrightText: 2025 izll
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid
import "../ui" as UI

ConfigModel {
    id: configModel

    // Tab names follow the widget's own language setting, like the pages do.
    property QtObject trans: UI.Translations {
        currentLanguage: configModel.widgetLanguage()
    }

    function widgetLanguage() {
        try {
            return Plasmoid.configuration.language || "system"
        } catch (e) {
            return "system"
        }
    }

    ConfigCategory {
        name: configModel.trans.tr("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: configModel.trans.tr("Panel")
        icon: "preferences-desktop-display"
        source: "configPanel.qml"
    }
    ConfigCategory {
        name: configModel.trans.tr("Popup")
        icon: "window"
        source: "configPopup.qml"
    }
}
