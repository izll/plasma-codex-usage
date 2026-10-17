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
    // Inside the ring the tiled app icon would leave a wide empty margin, so the
    // bare OpenAI knot is drawn instead, in the theme's text colour.
    readonly property string openaiKnotPath: "M14.949 6.547a3.94 3.94 0 0 0-.348-3.273 4.11 4.11 0 0 0-4.4-1.934A4.1 4.1 0 0 0 8.423.2 4.15 4.15 0 0 0 6.305.086a4.1 4.1 0 0 0-1.891.948 4.04 4.04 0 0 0-1.158 1.753 4.1 4.1 0 0 0-1.563.679A4 4 0 0 0 .554 4.72a3.99 3.99 0 0 0 .502 4.731 3.94 3.94 0 0 0 .346 3.274 4.11 4.11 0 0 0 4.402 1.933c.382.425.852.764 1.377.995.526.231 1.095.35 1.67.346 1.78.002 3.358-1.132 3.901-2.804a4.1 4.1 0 0 0 1.563-.68 4 4 0 0 0 1.14-1.253 3.99 3.99 0 0 0-.506-4.716m-6.097 8.406a3.05 3.05 0 0 1-1.945-.694l.096-.054 3.23-1.838a.53.53 0 0 0 .265-.455v-4.49l1.366.778q.02.011.025.035v3.722c-.003 1.653-1.361 2.992-3.037 2.996m-6.53-2.75a2.95 2.95 0 0 1-.36-2.01l.095.057L5.29 12.09a.53.53 0 0 0 .527 0l3.949-2.246v1.555a.05.05 0 0 1-.022.041L6.473 13.3c-1.454.826-3.311.335-4.15-1.098m-.85-6.94A3.02 3.02 0 0 1 3.07 3.949v3.785a.51.51 0 0 0 .262.451l3.93 2.237-1.366.779a.05.05 0 0 1-.048 0L2.585 9.342a2.98 2.98 0 0 1-1.113-4.094zm11.216 2.571L8.747 5.576l1.362-.776a.05.05 0 0 1 .048 0l3.265 1.86a3 3 0 0 1 1.173 1.207 2.96 2.96 0 0 1-.27 3.2 3.05 3.05 0 0 1-1.36.997V8.279a.52.52 0 0 0-.276-.445m1.36-2.015-.097-.057-3.226-1.855a.53.53 0 0 0-.53 0L6.249 6.153V4.598a.04.04 0 0 1 .019-.04L9.533 2.7a3.07 3.07 0 0 1 3.257.139c.474.325.843.778 1.066 1.303.223.526.289 1.103.191 1.664zM5.503 8.575 4.139 7.8a.05.05 0 0 1-.026-.037V4.049c0-.57.166-1.127.476-1.607s.752-.864 1.275-1.105a3.08 3.08 0 0 1 3.234.41l-.096.054-3.23 1.838a.53.53 0 0 0-.265.455zm.742-1.577 1.758-1 1.762 1v2l-1.755 1-1.762-1z"
    readonly property string ringLogoSource: "data:image/svg+xml;utf8," + encodeURIComponent(
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'><path fill='"
        + Kirigami.Theme.textColor.toString() + "' d='" + compact.openaiKnotPath + "'/></svg>")
    readonly property int barWidth: Math.round(32 * root.metricsScale)
    // In a vertical layout the widget's height follows usageRow's implicit
    // height, so a bar sized to its parent's height would feed back into it
    // and never settle (plasmashell hangs). Give it its own height there.
    readonly property int barHeight: fitted(Math.round(Kirigami.Units.iconSizes.medium * root.metricsScale))
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
            Layout.preferredHeight: root.isVerticalLayout ? compact.barHeight : parent.height
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
            centerIcon: (Plasmoid.configuration.ringCenter || "percent").indexOf("logo") === 0 ? compact.ringLogoSource : ""
            logoScale: Math.max(50, Math.min(Plasmoid.configuration.ringLogoSize || 85, 100)) / 100
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
