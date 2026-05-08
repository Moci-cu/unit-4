import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../theme"

pragma ComponentBehavior: Bound

Item {
    id: root

    property bool panelOpen: false
    property bool animRunning: false
    property real screenW: 1920
    property real screenH: 1080

    readonly property int panelW: 418
    readonly property int panelH: 308
    readonly property int gridSize: 12

    // ── Dark mode ──
    readonly property bool darkMode: Theme.darkMode

    readonly property color paper:     root.darkMode ? "#1a1814" : "#d6cfb5"
    readonly property color ink:       root.darkMode ? "#8a7530" : "#463f2e"
    readonly property color inkStrong: root.darkMode ? "#8a7530" : "#2e2a1f"
    readonly property color inkSoft:   root.darkMode ? "#7a7030" : "#7a7358"
    readonly property color lineVsoft: root.darkMode ? Qt.rgba(200/255,168/255,96/255,0.10) : Qt.rgba(70/255,63/255,46/255,0.10)
    readonly property color lineSoft:  root.darkMode ? Qt.rgba(200/255,168/255,96/255,0.30) : Qt.rgba(70/255,63/255,46/255,0.23)
    readonly property color accent:    root.darkMode ? "#a04040" : "#6e2a2a"
    readonly property color gold:      "#8a6a30"

    FontLoader { id: mainFont; source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Ndot57-Regular.otf" }
    readonly property string ff: mainFont.name

    // ── Battery (UPower D-Bus, 0 fork) ──
    readonly property var batt: UPower.displayDevice
    readonly property bool battReady: root.batt && root.batt.ready
    readonly property real battPct: root.battReady ? Math.round(root.batt.percentage * 100) : 0
    readonly property int battTimeRemaining: root.battReady ? root.batt.timeToEmpty : 0
    readonly property int battTimeToFull: root.battReady ? root.batt.timeToFull : 0
    readonly property real battPower: root.battReady ? root.batt.changeRate : 0

    // ── Uptime (FileView, 0 fork) ──
    property real upSec: 0
    readonly property string upStr: {
        var s = root.upSec
        if (s < 60) return Math.floor(s) + "s"
        if (s < 3600) return Math.floor(s / 60) + "m"
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        if (s < 86400) return h + "h " + m + "m"
        var d = Math.floor(h / 24)
        return d + "d " + (h % 24) + "h"
    }
    Timer { interval: 10000; running: root.panelOpen; repeat: true; onTriggered: upFile.reload() }
    FileView {
        id: upFile
        path: "/proc/uptime"
        onLoaded: { root.upSec = parseFloat(text().split(" ")[0]) || 0 }
    }
    readonly property real battEnergy: root.battReady ? root.batt.energy : 0
    readonly property real battCapacity: root.battReady ? root.batt.energyCapacity : 0
    readonly property bool battCharging: root.battReady && root.batt.state === UPowerDeviceState.Charging
    readonly property bool battDischarging: root.battReady && root.batt.state === UPowerDeviceState.Discharging

    function fmtTime(sec) {
        if (sec <= 0) return ""
        var h = Math.floor(sec / 3600)
        var m = Math.floor((sec % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    // ── Panel ──
    Item {
        id: panelHost
        x: (root.screenW - root.panelW) / 2
        y: (root.screenH - root.panelH) / 2
        width: root.panelW
        height: root.panelH
        clip: true
        visible: root.panelOpen || root.animRunning
        opacity: root.panelOpen ? 1 : 0
        scale: root.panelOpen ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: root.paper
            border.color: root.ink
            border.width: 1

            Rectangle { x: -1; y: -1; width: 2; height: 2; color: root.ink }
            Rectangle { x: parent.width - 1; y: -1; width: 2; height: 2; color: root.ink }
            Rectangle { x: -1; y: parent.height - 1; width: 2; height: 2; color: root.ink }
            Rectangle { x: parent.width - 1; y: parent.height - 1; width: 2; height: 2; color: root.ink }

            Repeater {
                model: Math.floor(parent.width / root.gridSize) + 1
                Rectangle { required property int index; x: index * root.gridSize; y: 0; width: 1; height: parent.height; color: root.lineVsoft }
            }
            Repeater {
                model: Math.floor(parent.height / root.gridSize) + 1
                Rectangle { required property int index; x: 0; y: index * root.gridSize; width: parent.width; height: 1; color: root.lineVsoft }
            }

            // Header
            Item {
                width: parent.width; height: 42
                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 18 }
                    Row {
                        spacing: 8; anchors.verticalCenter: parent.verticalCenter
                        Text { text: "◈"; font.family: root.ff; font.pixelSize: 12; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "SYSTEM"; font.family: root.ff; font.pixelSize: 12; font.letterSpacing: 3; font.weight: Font.Medium; color: root.inkStrong; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: 16; height: 1; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "システム"; font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 2; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Item { width: parent.width - 280; height: 1 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"; font.family: root.ff; font.pixelSize: 15; color: root.inkSoft
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.closePanel() }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.lineSoft }
            }

            // Body
            Item {
                anchors { top: parent.top; topMargin: 42; bottom: footer.top; left: parent.left; right: parent.right; margins: 16 }

                Column {
                    anchors.fill: parent
                    spacing: 14

                    // Remaining time (prominent, centered)
                    Item {
                        width: parent.width; height: 56
                        visible: root.battReady && (root.battDischarging || root.battCharging)
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(70/255,63/255,46/255,0.06)
                            border.color: root.lineSoft; border.width: 1
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.battDischarging ? "Remaining" : "Until full"
                                font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 2; color: root.inkSoft
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.battDischarging ? root.fmtTime(root.battTimeRemaining) : root.fmtTime(root.battTimeToFull)
                                font.family: root.ff; font.pixelSize: 24; font.weight: Font.Bold; color: root.inkStrong
                            }
                        }
                    }

                    // Battery bar + percentage
                    Item {
                        width: parent.width; height: 36
                        visible: root.battReady
                        Row {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            spacing: 12; anchors.verticalCenter: parent.verticalCenter
                            Text { text: "■"; font.family: root.ff; font.pixelSize: 15; color: root.battCharging ? root.gold : root.ink; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Battery"; font.family: root.ff; font.pixelSize: 12; font.letterSpacing: 2; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 190; height: 16
                                color: "transparent"
                                border.color: root.ink; border.width: 1

                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 2 }
                                    width: Math.max(0, (parent.width - 4) * root.battPct / 100)
                                    color: root.battCharging ? root.gold : root.ink
                                    opacity: 0.6
                                }
                            }

                            Text {
                                text: root.battPct + "%"
                                font.family: root.ff; font.pixelSize: 15; font.weight: Font.Bold
                                color: root.battCharging ? root.gold : root.inkStrong
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Detail rows
                    Rectangle { width: parent.width; height: 1; color: root.lineSoft; visible: root.battReady }

                    Column {
                        width: parent.width
                        spacing: 6
                        visible: root.battReady

                        Row {
                            width: parent.width; height: 24
                            Text { text: "Uptime"; width: 90; font.family: root.ff; font.pixelSize: 12; font.letterSpacing: 2; color: root.inkSoft }
                            Text { text: root.upStr; font.family: root.ff; font.pixelSize: 15; font.weight: Font.Medium; color: root.ink; horizontalAlignment: Text.AlignRight; width: parent.width - 90 }
                        }

                        Row {
                            width: parent.width; height: 24
                            visible: root.battCapacity > 0
                            Text { text: "Capacity"; width: 90; font.family: root.ff; font.pixelSize: 12; font.letterSpacing: 2; color: root.inkSoft }
                            Text { text: root.battEnergy.toFixed(1) + " / " + root.battCapacity.toFixed(1) + " Wh"; font.family: root.ff; font.pixelSize: 15; font.weight: Font.Medium; color: root.ink; horizontalAlignment: Text.AlignRight; width: parent.width - 90 }
                        }
                    }

                    // No battery
                    Text {
                        visible: !root.battReady
                        width: parent.width
                        text: "No battery detected"
                        font.family: root.ff; font.pixelSize: 13; color: root.inkSoft
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Footer
            Item {
                id: footer
                anchors.bottom: parent.bottom
                width: parent.width; height: 34
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.lineSoft }
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "◇"; font.family: root.ff; font.pixelSize: 11; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "Uptime · Battery"
                        font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 1.5; color: root.inkSoft; opacity: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Timer { id: hideDone; interval: 240; onTriggered: { panelHost.visible = false; root.animRunning = false } }
    }

    function openPanel() {
        if (panelOpen) return
        panelOpen = true; animRunning = true
        panelHost.visible = true
        panelHost.x = (screenW - panelW) / 2
        upFile.reload()
    }

    function closePanel() {
        if (!panelOpen) return
        panelOpen = false; animRunning = true
        hideDone.restart()
    }

    function togglePanel() {
        if (panelOpen) closePanel()
        else openPanel()
    }
}
