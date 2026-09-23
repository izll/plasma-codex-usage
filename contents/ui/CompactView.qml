import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: compact

    readonly property string effectivePanelStyle: Plasmoid.configuration.panelStyle || "text"

    // Cap the metrics at the panel's thickness, which the panel fixes: the
    // height in a horizontal panel, the width in a vertical one. When the
    // widget's own layout stacks its metrics along the thick axis, each one
    // gets half of it. The desktop is not capped.
    readonly property bool inHorizontalPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property bool inVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int availableHeight: {
        if (inHorizontalPanel && compact.height > 0)
            return Math.max(12, root.isVerticalLayout ? Math.floor(compact.height / 2) - 2 : compact.height)
        if (inVerticalPanel && compact.width > 0)
            return Math.max(12, root.isVerticalLayout ? compact.width - 4 : Math.floor(compact.width / 2) - 2)
        return -1
    }
    function fitted(size) {
        return compact.availableHeight < 0 ? size : Math.min(size, compact.availableHeight)
    }
    readonly property int ringSize: fitted(Math.round(28 * root.metricsScale))
    // The stroke grows more slowly than the ring, so larger rings stay elegant.
    readonly property int ringLineWidth: Math.max(2, Math.round(3 + (compact.ringSize - 28) * 0.06))
    readonly property real ringFontScale: Math.min(0.36, 0.3 + (root.metricsScale - 1) * 0.04)
    readonly property int barWidth: Math.round(32 * root.metricsScale)
    readonly property int barFontSize: compact.availableHeight < 0
        ? Math.round(9 * root.metricsScale)
        : Math.min(Math.round(9 * root.metricsScale), Math.round(compact.availableHeight * 0.5))
    readonly property int dotSize: fitted(Math.round(10 * root.metricsScale))
    // Capped so the text fits the panel thickness (line height is ~1.4x the pixel size).
    readonly property int textFontSize: compact.availableHeight < 0
        ? Math.round(Kirigami.Theme.defaultFont.pixelSize * root.metricsScale)
        : Math.min(Math.round(Kirigami.Theme.defaultFont.pixelSize * root.metricsScale),
                   Math.max(Kirigami.Theme.defaultFont.pixelSize, Math.floor(compact.availableHeight / 1.4)))
    // An explicit icon size is not scaled (the settings show it in pixels), but
    // it is capped at the panel thickness; "Auto" follows the metrics scale.
    readonly property int effectiveIconSize: fitted(Plasmoid.configuration.iconSize > 0
        ? Plasmoid.configuration.iconSize
        : Math.round(Kirigami.Units.iconSizes.smallMedium * root.metricsScale))

    Layout.minimumWidth: usageRow.implicitWidth + (Plasmoid.configuration.panelMargin !== undefined ? Plasmoid.configuration.panelMargin : 4) * 2
    Layout.minimumHeight: root.isVerticalLayout ? usageRow.implicitHeight + (Plasmoid.configuration.panelMargin !== undefined ? Plasmoid.configuration.panelMargin : 4) * 2 : Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: usageRow.implicitWidth + (Plasmoid.configuration.panelMargin !== undefined ? Plasmoid.configuration.panelMargin : 4) * 2
    Layout.preferredHeight: root.isVerticalLayout ? usageRow.implicitHeight + (Plasmoid.configuration.panelMargin !== undefined ? Plasmoid.configuration.panelMargin : 4) * 2 : -1

    MouseArea {
        anchors.fill: parent
        onClicked: root.expanded = !root.expanded
    }

    GridLayout {
        id: usageRow
        anchors.centerIn: parent
        columns: root.isVerticalLayout ? 1 : -1
        rows: root.isVerticalLayout ? -1 : 1
        flow: root.isVerticalLayout ? GridLayout.TopToBottom : GridLayout.LeftToRight
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing / 2

        // Codex icon with error/update indicator
        Item {
            visible: Plasmoid.configuration.showIcon !== false
            Layout.preferredWidth: compact.effectiveIconSize
            Layout.preferredHeight: compact.effectiveIconSize
            Layout.rightMargin: Kirigami.Units.smallSpacing

            Image {
                anchors.fill: parent
                source: (Plasmoid.configuration.panelIcon || "chatgpt") === "openai"
                    ? Qt.resolvedUrl("../icons/codex.svg")
                    : Qt.resolvedUrl("../icons/chatgpt.svg")
                sourceSize: Qt.size(parent.width * Screen.devicePixelRatio, parent.height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Rectangle {
                visible: root.hasNetworkError || root.updateAvailable
                width: Math.max(8, Math.round(compact.effectiveIconSize / 3))
                height: width
                radius: width / 2
                color: root.hasNetworkError
                    ? Kirigami.Theme.negativeTextColor
                    : "#10a37f"
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -2
                anchors.bottomMargin: -2
            }
        }

        // Error state
        PlasmaComponents.Label {
            visible: root.showUsageStats && root.errorMsg !== "" && !root.hasNetworkError
            text: "⚠"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            color: Kirigami.Theme.negativeTextColor
        }

        // === TEXT STYLE ===

        Rectangle {
            visible: root.showUsageStats && compact.effectivePanelStyle === "text" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: compact.dotSize
            Layout.preferredHeight: compact.dotSize
            radius: compact.dotSize / 2
            color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
            opacity: root.hasNetworkError ? 0.5 : 1.0
        }

        PlasmaComponents.Label {
            visible: root.showUsageStats && compact.effectivePanelStyle === "text" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            text: Math.round(root.weeklyUsagePercent) + "%"
            font.pixelSize: compact.textFontSize
            font.bold: true
            color: root.useTimeAware ? root.getUsageColor(root.weeklyUsagePercent, root.weeklyTimePct) : Kirigami.Theme.textColor
            opacity: root.hasNetworkError ? 0.5 : 1.0
        }

        // === BAR STYLE ===

        Item {
            visible: root.showUsageStats && compact.effectivePanelStyle === "bar" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: compact.barWidth
            Layout.preferredHeight: parent.height
            opacity: root.hasNetworkError ? 0.5 : 1.0

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: Math.max((parent.height - 2) * Math.min(root.weeklyUsagePercent / 100, 1), 1)
                    radius: 2
                    color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
                }

                Rectangle {
                    visible: root.useTimeAware && root.weeklyTimePct >= 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    y: parent.height - 1 - (parent.height - 2) * Math.min(Math.max(root.weeklyTimePct, 0), 100) / 100
                    height: 2
                    color: Kirigami.Theme.textColor
                    opacity: 0.6
                }
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: Math.round(root.weeklyUsagePercent)
                font.pixelSize: compact.barFontSize
                font.bold: true
                color: Kirigami.Theme.textColor
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }

        // === RING STYLE ===

        UsageRing {
            visible: root.showUsageStats && compact.effectivePanelStyle === "ring" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: compact.ringSize
            Layout.preferredHeight: compact.ringSize
            opacity: root.hasNetworkError ? 0.5 : 1.0
            percent: root.weeklyUsagePercent
            ringColor: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
            markerRel: root.useTimeAware && root.weeklyTimePct >= 0 ? root.weeklyTimePct / 100 : -1
            lineWidth: compact.ringLineWidth
            fontScale: compact.ringFontScale
            cornerLabel: Plasmoid.configuration.showWindowLabels === true ? root.windowLabel(root.weeklyWindowMinutes) : ""
            centerIcon: (Plasmoid.configuration.ringCenter || "percent").indexOf("logo") === 0
                ? Qt.resolvedUrl((Plasmoid.configuration.panelIcon || "chatgpt") === "openai"
                    ? "../icons/codex.svg" : "../icons/chatgpt.svg").toString()
                : ""
            centerPercentOverlay: (Plasmoid.configuration.ringCenter || "percent") === "logo_percent"
        }

        // Error text
        PlasmaComponents.Label {
            visible: root.showUsageStats && root.errorMsg !== "" && !root.hasNetworkError
            text: root.errorMsg
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: Kirigami.Theme.negativeTextColor
        }
    }
}
