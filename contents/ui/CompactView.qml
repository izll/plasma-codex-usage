import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: compact

    readonly property string effectivePanelStyle: Plasmoid.configuration.panelStyle || "text"
    readonly property int effectiveIconSize: Plasmoid.configuration.iconSize > 0 ? Plasmoid.configuration.iconSize : Kirigami.Units.iconSizes.smallMedium

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
                width: 8
                height: 8
                radius: 4
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
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
            opacity: root.hasNetworkError ? 0.5 : 1.0
        }

        PlasmaComponents.Label {
            visible: root.showUsageStats && compact.effectivePanelStyle === "text" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            text: Math.round(root.weeklyUsagePercent) + "%"
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            font.bold: true
            color: root.useTimeAware ? root.getUsageColor(root.weeklyUsagePercent, root.weeklyTimePct) : Kirigami.Theme.textColor
            opacity: root.hasNetworkError ? 0.5 : 1.0
        }

        // === BAR STYLE ===

        Item {
            visible: root.showUsageStats && compact.effectivePanelStyle === "bar" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: 32
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
                font.pixelSize: 9
                font.bold: true
                color: Kirigami.Theme.textColor
                style: Text.Outline
                styleColor: Kirigami.Theme.backgroundColor
            }
        }

        // === RING STYLE ===

        UsageRing {
            visible: root.showUsageStats && compact.effectivePanelStyle === "ring" && (Plasmoid.configuration.showWeekly !== false) && root.metricsVisible
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            opacity: root.hasNetworkError ? 0.5 : 1.0
            percent: root.weeklyUsagePercent
            ringColor: root.getUsageColor(root.weeklyUsagePercent, root.useTimeAware ? root.weeklyTimePct : undefined)
            markerRel: root.useTimeAware && root.weeklyTimePct >= 0 ? root.weeklyTimePct / 100 : -1
            lineWidth: 3
            fontScale: 0.3
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
