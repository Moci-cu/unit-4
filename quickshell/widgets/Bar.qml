import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Networking
import "../theme"

pragma ComponentBehavior: Bound

Item {
    id: root

    signal openPanel(string tab)

    // ── Bar toggle ──
    property bool barVisible: true
    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible }
    }

    GlobalShortcut {
        name: "barToggle"
        onPressed: { root.barVisible = !root.barVisible }
    }

    readonly property color paper:     Theme.darkMode ? "#1a1814" : "#d6cfb5"
    readonly property color ink:       Theme.darkMode ? "#8a7530" : "#463f2e"
    readonly property color inkStrong: Theme.darkMode ? "#8a7530" : "#2e2a1f"
    readonly property color inkSoft:   Theme.darkMode ? "#7a7030" : "#7a7358"
    readonly property color lineVsoft: Theme.darkMode ? Qt.rgba(200/255,168/255,96/255,0.10) : Qt.rgba(70/255,63/255,46/255,0.12)
    readonly property color lineSoft:  Theme.darkMode ? Qt.rgba(200/255,168/255,96/255,0.20) : Qt.rgba(70/255,63/255,46/255,0.25)
    readonly property color accent:    Theme.darkMode ? "#a04040" : "#6e2a2a"
    readonly property color inactiveBg: Theme.darkMode ? Qt.rgba(255/255,255/255,255/255,0.06) : Qt.rgba(70/255,63/255,46/255,0.22)
    readonly property color chargingBg: "#5a7a5a"

    readonly property int barHeight: 40
    readonly property int gridSize:  12

    readonly property var wsProps: {
        var hasApp = {}
        var topClass = {}
        var vals = Hyprland.toplevels.values
        for (var i = 0; i < vals.length; i++) {
            var t = vals[i]
            if (t && t.workspace) {
                var wid = t.workspace.id
                hasApp[wid] = true
                if (!topClass[wid]) {
                    var cls = t.lastIpcObject?.initialClass || t.lastIpcObject?.class
                    topClass[wid] = ((cls || "")[0] || "?")[0].toUpperCase()
                }
            }
        }
        return { hasApp: hasApp, topClass: topClass }
    }

    // Event-driven: refresh toplevels only when windows change
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event?.name || ""
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "activewindow")
                Hyprland.refreshToplevels()
        }
    }

    readonly property string activeTitle: {
        var at = Hyprland.activeToplevel
        if (!at) return "---"
        var cw = Hyprland.focusedWorkspace
        if (!cw) return "---"
        if (!at.workspace || at.workspace.id !== cw.id) return "---"
        return at.title || "---"
    }

    readonly property bool showTitleFrame: {
        var at = Hyprland.activeToplevel
        if (!at) return false
        var cw = Hyprland.focusedWorkspace
        if (!cw) return false
        return at.workspace && at.workspace.id === cw.id && at.title !== ""
    }

    property string cpuVal: "--%"
    property string memVal: "--%"
    readonly property var battery: UPower.displayDevice
    readonly property string batVal: root.battery && root.battery.ready
        ? Math.round(root.battery.percentage * 100) + "%" : "--"
    readonly property string batPower: root.pwrSmoothed !== 0
        ? (root.pwrSmoothed > 0 ? "+" : "") + Math.abs(root.pwrSmoothed).toFixed(1) + "W"
        : (root.battery && root.battery.ready
            ? (root.battery.changeRate > 0 ? "+" : "") + Math.abs(root.battery.changeRate).toFixed(1) + "W"
            : "--")
    readonly property bool   hasBattery: root.battery && root.battery.ready
    readonly property string batStatus: root.battery && root.battery.ready
        ? UPowerDeviceState.toString(root.battery.state) : "Unknown"
    readonly property string currentTime: {
        var h = sysClock.hours, m = sysClock.minutes
        return ("0" + h).slice(-2) + ":" + ("0" + m).slice(-2)
    }

    // ── WiFi (native Quickshell.Networking, 0 fork) ──
    readonly property string wifiSsid: {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type !== DeviceType.Wifi) continue
            var nets = devs[i].networks.values
            for (var j = 0; j < nets.length; j++) {
                if (nets[j].state === 2) return nets[j].name
            }
        }
        return ""
    }

    // ── BT (native Bluetooth, 0 fork) ──
    readonly property bool btOn: Bluetooth.defaultAdapter
        ? Bluetooth.defaultAdapter.enabled : false

    readonly property bool btConn: {
        var adp = Bluetooth.defaultAdapter
        if (!adp || !adp.devices) return false
        for (var i = 0; i < adp.devices.length; i++) {
            if (adp.devices[i] && adp.devices[i].connected) return true
        }
        return false
    }

    // ── CPU Temperature (FileView, 0 fork) ──
    property string cpuTemp: "--"
    property int cpuTempNum: 0
    Timer { interval: 5000; running: true; repeat: true; onTriggered: tempFile.reload() }
    FileView {
        id: tempFile
        path: "/sys/class/hwmon/hwmon5/temp1_input"
        onLoaded: { root.cpuTempNum = Math.round(parseInt(text().trim()) / 1000); root.cpuTemp = root.cpuTempNum + "°" }
    }

    // ── PWR from sysfs (current_now × voltage_now, 0 fork) ──
    property real pwrSmoothed: 0
    property int pwrVoltage: 1
    Timer { interval: 5000; running: true; repeat: true; onTriggered: pwrCur.reload() }
    FileView {
        id: pwrCur
        path: "/sys/class/power_supply/BAT0/current_now"
        onLoaded: { var cur = parseInt(text().trim()) || 0; if (cur > 0 && root.pwrVoltage > 1000000) root.pwrSmoothed = -(cur * root.pwrVoltage) / 1e12 }
    }
    Timer { interval: 300; running: true; repeat: false; onTriggered: pwrVolt.reload() }
    Connections { target: root.battery; enabled: root.battery !== null; function onStateChanged() { pwrVolt.reload() } }
    FileView {
        id: pwrVolt
        path: "/sys/class/power_supply/BAT0/voltage_now"
        onLoaded: { root.pwrVoltage = parseInt(text().trim()) || 1 }
    }

    property int lastCpuUsed:  0
    property int lastCpuTotal: 0

    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: { fileStat.reload(); fileMem.reload() }
    }
    FileView {
        id: fileStat
        path: "/proc/stat"
        onLoaded: {
            var p = text().trim().split(/\s+/)
            if (p.length < 5 || p[0] !== "cpu") return
            var used  = parseInt(p[1]) + parseInt(p[2]) + parseInt(p[3])
            var total = used + parseInt(p[4])
            if (root.lastCpuTotal > 0 && total > root.lastCpuTotal) {
                root.cpuVal = Math.round(100 * (used - root.lastCpuUsed) / (total - root.lastCpuTotal)) + "%"
            } else if (root.lastCpuTotal === 0) {
                root.cpuVal = Math.round(100 * used / total) + "%"
            }
            root.lastCpuUsed  = used
            root.lastCpuTotal = total
        }
    }
    FileView {
        id: fileMem
        path: "/proc/meminfo"
        onLoaded: {
            var lines = text().trim().split("\n")
            var total = 0, avail = 0
            for (var i = 0; i < lines.length; i++) {
                var m = lines[i].match(/MemTotal:\s+(\d+)/)
                if (m) total = parseInt(m[1])
                m = lines[i].match(/MemAvailable:\s+(\d+)/)
                if (m) avail = parseInt(m[1])
            }
            if (total > 0) root.memVal = Math.round(100 * (total - avail) / total) + "%"
        }
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top: true
            anchors.left: true
            anchors.right: true
            implicitWidth: modelData.width
            implicitHeight: root.barHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell-bar"
            visible: root.barVisible

            Rectangle {
                id: barBg
                anchors.fill: parent
                color: root.paper
                border.color: root.ink
                border.width: 2

                Canvas {
                    id: barGrid
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.strokeStyle = root.lineVsoft
                        ctx.lineWidth = 1
                        for (var x = 0; x < width; x += root.gridSize) {
                            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
                        }
                        for (var y = 0; y < height; y += root.gridSize) {
                            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                        }
                    }
                }

                Row {
                    id: wsRow
                    anchors { top: parent.top; bottom: parent.bottom; topMargin: 4; bottomMargin: 4 }
                    x: Math.max(leftInfo.x + leftInfo.width + 6, (barBg.width - wsRow.width) / 2)
                    spacing: 0

                    Rectangle {
                        height: wsRow.height
                        width: 10 * 23 + 9 * 5 + 11
                        color: Theme.darkMode ? Qt.rgba(200/255,168/255,96/255,0.05) : root.inactiveBg
                        border.color: root.inkStrong; border.width: 1

                        Row {
                            anchors { fill: parent; leftMargin: 5; rightMargin: 5 }
                            spacing: 5
                            Repeater {
                                model: 10
                                Rectangle {
                                    required property int index
                                    readonly property int wsId: index + 1
                                    readonly property bool isActive: Hyprland.focusedWorkspace
                                        ? Hyprland.focusedWorkspace.id === wsId
                                        : false

                                    width: 23; height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: isActive ? root.ink : "transparent"
                                    border.color: root.inkSoft; border.width: 1

                                    Text {
                                        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
                                        text: parent.isActive ? "◆" : (root.wsProps.hasApp[wsId] ? root.wsProps.topClass[wsId] : "◈")
                                        font.family: "Ndot 57"; font.pixelSize: 13
                                        color: parent.isActive ? root.paper : root.ink
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Hyprland.dispatch("workspace " + wsId)
                                    }

                                }
                            }
                        }
                    }
                }

                Row {
                    id: leftInfo
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 10; topMargin: 4; bottomMargin: 4 }
                    spacing: 6

                    Text {
                        font.family:"Ndot 57"; font.pixelSize:14; font.weight:Font.Bold; font.letterSpacing:1.2; opacity:0.85
                        color: root.showTitleFrame ? root.inkStrong : root.inkSoft
                        text: root.activeTitle; elide: Text.ElideRight
                        width: Math.min(implicitWidth, 200)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item { width:1; height:1 }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: btRow2.width; height: btRow2.height
                        Row { id: btRow2; spacing: 6; anchors.verticalCenter: parent.verticalCenter
                            Text { font.family:"Ndot 57"; font.pixelSize:14; font.weight:Font.Bold; font.letterSpacing:1.2; color:root.inkStrong; opacity:0.85; text:"BT"; anchors.verticalCenter:parent.verticalCenter }
                            Text { font.family:"Ndot 57"; font.pixelSize:14; font.weight:Font.Bold; font.letterSpacing:1.2; opacity:0.8; text:root.btOn?(root.btConn?"ON":"--"):"OFF"; anchors.verticalCenter:parent.verticalCenter; color:root.btOn?(root.btConn?"#8a6a30":root.inkSoft):root.inkSoft }
                        }
                        MouseArea { anchors.fill:parent; anchors.margins:-4; onClicked: root.openPanel("bt") }
                    }

                    Item { width:1; height:1 }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: wfRow2.width; height: wfRow2.height
                        Row { id: wfRow2; spacing: 6; anchors.verticalCenter: parent.verticalCenter
                            Text { font.family:"Ndot 57"; font.pixelSize:14; font.weight:Font.Bold; font.letterSpacing:1.2; color:root.inkStrong; opacity:0.85; text:"WF"; anchors.verticalCenter:parent.verticalCenter }
                            Text { font.family:"Ndot 57"; font.pixelSize:14; font.weight:Font.Bold; font.letterSpacing:1.2; opacity:0.8; text:root.wifiSsid||"---"; elide:Text.ElideRight; anchors.verticalCenter:parent.verticalCenter; color:root.wifiSsid?"#8a6a30":root.inkSoft }
                        }
                        MouseArea { anchors.fill:parent; anchors.margins:-4; onClicked: root.openPanel("wifi") }
                    }

                    Item { width:1; height:1 }

                    Text { font.family:"Ndot 57"; font.pixelSize:14; font.weight:Font.Bold; font.letterSpacing:1.2; color:root.inkStrong; opacity:0.85; text:root.currentTime; anchors.verticalCenter:parent.verticalCenter }
                }

                Item {
                    id: titleFrame
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    clip: true
                    property real leftSide: leftInfo.x + leftInfo.width + 12
                    property real rightSide: barBg.width - statsRow.x
                    property real tightSide: Math.max(leftSide, rightSide)
                    property real maxW: Math.max(barBg.width - 2 * tightSide, 0)
                    width: Math.min(wsRow.width, maxW)
                }

                Row {
                    id: statsRow
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    Text {
                        font.family: "Ndot 57"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        color: root.inkStrong
                        opacity: 0.85
                        text: "CPU"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        font.family: "Ndot 57"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        opacity: 0.8
                        color: parseFloat(root.cpuVal) > 12 ? "#6e2a2a" : (root.cpuVal !== "--%" ? root.inkSoft : root.lineSoft)
                        text: root.cpuVal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 2; height: 1 }

                    Text {
                        font.family: "Ndot 57"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        color: root.inkStrong
                        opacity: 0.85
                        text: "MEM"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        font.family: "Ndot 57"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        opacity: 0.8
                        color: root.memVal !== "--%" ? root.inkSoft : root.lineSoft
                        text: root.memVal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 2; height: 1 }

                    Text {
                        font.family: "Ndot 57"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        color: root.inkStrong
                        opacity: 0.85
                        text: "BAT"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.hasBattery
                    }
                    Text {
                        font.family: "Ndot 57"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        opacity: 0.8
                        color: root.hasBattery
                            ? (root.batStatus === "Charging" ? "#60a880" : root.inkSoft)
                            : "transparent"
                        text: root.batVal
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.hasBattery
                    }

                    Item { width: 2; height: 1 }

                    Text {
                        font.family: "Ndot 57"; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 1.2
                        color: root.inkStrong; opacity: 0.85; text: "PWR"; anchors.verticalCenter: parent.verticalCenter
                        visible: root.hasBattery
                    }
                    Text {
                        font.family: "Ndot 57"; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 1.2
                        opacity: 0.8; text: root.batPower; anchors.verticalCenter: parent.verticalCenter
                        color: Math.abs(parseFloat(root.batPower)) > 10 ? "#6e2a2a" : (root.batStatus === "Charging" ? "#60a880" : root.inkSoft)
                        visible: root.hasBattery
                    }

                    Item { width: 2; height: 1 }

                    Text {
                        font.family: "Ndot 57"; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 1.2
                        color: root.inkStrong; opacity: 0.85; text: "TEMP"; anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        font.family: "Ndot 57"; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 1.2
                        opacity: 0.8; text: root.cpuTemp || "--"; anchors.verticalCenter: parent.verticalCenter
                        color: root.cpuTempNum > 55 ? "#6e2a2a" : root.inkSoft
                    }
                }
            }
        }
    }
}
