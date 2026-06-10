import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import "../theme"

pragma ComponentBehavior: Bound

Item {
    id: root

    signal openPanel(string tab)

    property bool barVisible: true
    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible }
    }
    GlobalShortcut {
        name: "barToggle"
        onPressed: { root.barVisible = !root.barVisible }
    }

    readonly property color bg:        Qt.rgba(11/255, 10/255, 9/255, 0.92)
    readonly property color inkDim:    Qt.rgba(224/255,200/255,136/255,0.4)
    readonly property color sep:       Qt.rgba(224/255,200/255,136/255,0.08)
    readonly property color borderBot: Qt.rgba(224/255,200/255,136/255,0.15)
    readonly property color cpuColor:  "#c87060"
    readonly property color memColor:  "#6090c8"
    readonly property color netColor:  "#60a880"
    readonly property color wsGold:    "#e0c888"
    readonly property color wsDim:     Qt.rgba(224/255,200/255,136/255,0.3)
    readonly property color wsHover:   Qt.rgba(224/255,200/255,136/255,0.7)
    readonly property color wsHoverBg: Qt.rgba(224/255,200/255,136/255,0.05)
    readonly property color wsAppLine: Qt.rgba(224/255,200/255,136/255,0.5)

    readonly property int barHeight: 28
    readonly property int wsDotWidth: 20

    readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property var wsWithApps: ({})

    Component.onCompleted: {
        refreshApps()
        resolveTempSensor()
        refreshWifiLabel()
        wifiInitialRefresh.start()
        if (root.hasBattery) root.batPower = Math.abs(root.battery.changeRate).toFixed(1) + "W"
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { wsRefresh.start() }
        function onRawEvent(event) {
            var n = event?.name || ""
            if (n === "openwindow" || n === "closewindow" || n === "movewindow")
                wsRefresh.start()
        }
    }
    Timer {
        id: wsRefresh
        interval: 0
        repeat: false
        onTriggered: refreshApps()
    }
    function refreshApps() {
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        var vals = Hyprland.toplevels.values || []
        var set = {}
        for (var i = 0; i < vals.length; i++) {
            var t = vals[i]
            if (t && t.workspace && t.workspace.id > 0) set[t.workspace.id] = true
        }
        root.wsWithApps = set
    }

    readonly property string activeTitle: {
        var at = Hyprland.activeToplevel
        if (!at) return ""
        var cw = Hyprland.focusedWorkspace
        if (!cw) return ""
        if (!at.workspace || at.workspace.id !== cw.id) return ""
        return at.title || ""
    }

    property string cpuVal: "--%"
    property string memVal: "--%"
    property string cpuTemp: "--"
    property int cpuTempNum: 0
    property int lastCpuUsed: 0
    property int lastCpuTotal: 0

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { fileStat.reload(); fileMem.reload() }
    }
    FileView {
        id: fileStat
        path: "/proc/stat"
        onLoaded: {
            var p = text().trim().split(/\s+/)
            if (p.length < 9 || p[0] !== "cpu") return
            // user, nice, system, idle, iowait, irq, softirq, steal
            var user = parseInt(p[1])
            var nice = parseInt(p[2])
            var system = parseInt(p[3])
            var idle = parseInt(p[4])
            var iowait = parseInt(p[5]) || 0
            var irq = parseInt(p[6]) || 0
            var softirq = parseInt(p[7]) || 0
            var steal = parseInt(p[8]) || 0
            var used = user + nice + system + iowait + irq + softirq + steal
            var total = used + idle
            if (root.lastCpuTotal > 0 && total > root.lastCpuTotal)
                root.cpuVal = Math.round(100 * (used - root.lastCpuUsed) / (total - root.lastCpuTotal)) + "%"
            else if (root.lastCpuTotal === 0)
                root.cpuVal = Math.round(100 * used / total) + "%"
            root.lastCpuUsed = used
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

    Timer { interval: 5000; running: true; repeat: true; onTriggered: tempFile.reload() }
    FileView {
        id: tempFile
        path: ""
        onLoaded: {
            if (path === "") return
            root.cpuTempNum = Math.round(parseInt(text().trim()) / 1000)
            root.cpuTemp = "TEMP " + root.cpuTempNum + "°"
        }
    }

    function resolveTempSensor() {
        var knownSensors = ["coretemp", "k10temp"]
        var basePath = "/sys/class/hwmon/"

        for (var i = 0; i < 10; i++) {
            var hwmonPath = basePath + "hwmon" + i + "/name"
            var tempInputPath = basePath + "hwmon" + i + "/temp1_input"

            var nameFile = Qt.createQmlObject(
                'import Quickshell.Io; FileView { path: "' + hwmonPath + '" }',
                root
            )

            try {
                var sensorName = nameFile.text().trim()
                if (knownSensors.indexOf(sensorName) !== -1) {
                    tempFile.path = tempInputPath
                    tempFile.reload()
                    nameFile.destroy()
                    return
                }
            } catch (e) {
                // File doesn't exist or can't be read, continue
            }

            nameFile.destroy()
        }

        // Fallback to hardcoded path if no sensor found
        tempFile.path = "/sys/class/hwmon/hwmon5/temp1_input"
        tempFile.reload()
    }

    // ── Battery (UPower native, 0 fork) ──
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: root.battery && root.battery.isPresent
    readonly property string batPercent: root.hasBattery ? Math.round(root.battery.percentage * 100) + "%" : ""
    readonly property string batCharging: root.hasBattery && root.battery.state === UPowerDeviceState.Charging ? " +" : ""
    property string batPower: ""
    readonly property color batColor: root.hasBattery
        ? (root.battery.state === UPowerDeviceState.Charging ? root.netColor : (root.battery.percentage * 100 < 15 ? "#c86060" : root.cpuColor))
        : "transparent"

    Timer {
        interval: 1000
        running: root.hasBattery
        repeat: true
        onTriggered: {
            if (root.hasBattery)
                root.batPower = Math.abs(root.battery.changeRate).toFixed(1) + "W"
        }
    }

    readonly property var wifiDevice: {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        }
        return null
    }
    readonly property string nativeWifiSsid: {
        if (!root.wifiDevice || !root.wifiDevice.networks) return ""
        var nets = root.wifiDevice.networks.values || root.wifiDevice.networks
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected || nets[i].state === ConnectionState.Connected)
                return nets[i].name || ""
        }
        return ""
    }
    property string wifiSsidName: ""
    property bool wifiFallbackResolved: false
    property string wifiFallbackCandidate: ""
    property int wifiFallbackAttempts: 0
    property bool wifiFallbackPending: false
    readonly property string wifiSsid: "NET " + (wifiSsidName || "--")

    function refreshWifiLabel() {
        var nativeName = root.nativeWifiSsid
        if (nativeName !== "") {
            root.wifiSsidName = nativeName
            root.wifiFallbackResolved = true
            root.wifiFallbackAttempts = 0
            return
        }
        if (root.wifiFallbackResolved || wifiNameFallback.running) return
        root.wifiFallbackCandidate = ""
        wifiNameFallback.command = [
            "nmcli", "-t", "-f", "IN-USE,SSID",
            "device", "wifi", "list", "--rescan", "no"
        ]
        wifiNameFallback.running = true
    }

    function scheduleWifiRefresh() {
        root.wifiFallbackResolved = false
        root.wifiFallbackAttempts = 0
        if (wifiNameFallback.running) {
            root.wifiFallbackPending = true
        } else {
            wifiFallbackRetry.restart()
        }
    }

    onNativeWifiSsidChanged: {
        if (root.nativeWifiSsid !== "") root.refreshWifiLabel()
        else root.scheduleWifiRefresh()
    }

    Connections {
        target: root.wifiDevice
        function onConnectedChanged() { root.scheduleWifiRefresh() }
        function onStateChanged() { root.scheduleWifiRefresh() }
    }

    Process {
        id: wifiNameFallback
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("*:") === 0) {
                        root.wifiFallbackCandidate = lines[i].substring(2)
                            .replace(/\\:/g, ":").replace(/\\\\/g, "\\")
                        break
                    }
                }
            }
        }
        onExited: function(code) {
            wifiNameFallback.command = []
            if (code === 0 && root.wifiFallbackCandidate !== "") {
                root.wifiSsidName = root.wifiFallbackCandidate
                root.wifiFallbackResolved = true
                root.wifiFallbackAttempts = 0
                root.wifiFallbackPending = false
                return
            }
            root.wifiFallbackResolved = false
            root.wifiFallbackAttempts += 1
            if (root.wifiFallbackPending || root.wifiFallbackAttempts < 5) {
                root.wifiFallbackPending = false
                wifiFallbackRetry.restart()
            } else {
                root.wifiSsidName = ""
            }
        }
    }

    Timer {
        id: wifiInitialRefresh
        interval: 1000
        repeat: false
        onTriggered: root.refreshWifiLabel()
    }

    Timer {
        id: wifiFallbackRetry
        interval: 800
        repeat: false
        onTriggered: root.refreshWifiLabel()
    }

    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    readonly property string currentTime: {
        var h = sysClock.hours, m = sysClock.minutes
        return ("0" + h).slice(-2) + ":" + ("0" + m).slice(-2)
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
                anchors.fill: parent
                color: root.bg

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1; color: root.borderBot
                }

                Rectangle {
                    id: workspaceStrip
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    width: workspaceRow.width + 10
                    height: 24
                    radius: 4
                    color: Qt.rgba(18/255, 16/255, 11/255, 0.82)

                    Row {
                        id: workspaceRow
                        anchors.centerIn: parent
                        width: 10 * root.wsDotWidth
                        height: parent.height

                        Repeater {
                            model: 10
                            delegate: Item {
                                id: workspaceItem
                                required property int index
                                readonly property int wsId: index + 1
                                readonly property bool isFocused: root.focusedWs === wsId
                                readonly property bool hasApp: root.wsWithApps[wsId] || false

                                width: root.wsDotWidth
                                height: workspaceStrip.height

                                Rectangle {
                                    anchors.fill: parent
                                    color: workspaceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                }

                                Canvas {
                                    id: workspaceIcon
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    antialiasing: true

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cx = width / 2
                                        var cy = height / 2

                                        if (workspaceItem.isFocused) {
                                            ctx.fillStyle = "#e0c888"
                                            ctx.beginPath()
                                            ctx.moveTo(cx, cy)
                                            ctx.arc(cx, cy, 7, Math.PI * 0.23, Math.PI * 1.77, false)
                                            ctx.closePath()
                                            ctx.fill()
                                        } else if (workspaceItem.hasApp) {
                                            ctx.fillStyle = "#b8a66f"
                                            ctx.beginPath()
                                            ctx.moveTo(2, 14)
                                            ctx.lineTo(2, 8)
                                            ctx.bezierCurveTo(2, 2.5, 4.5, 1, 8, 1)
                                            ctx.bezierCurveTo(11.5, 1, 14, 2.5, 14, 8)
                                            ctx.lineTo(14, 14)
                                            ctx.lineTo(11.8, 12.3)
                                            ctx.lineTo(10, 14)
                                            ctx.lineTo(8, 12.3)
                                            ctx.lineTo(6, 14)
                                            ctx.lineTo(4.2, 12.3)
                                            ctx.closePath()
                                            ctx.fill()

                                            ctx.fillStyle = "#3a342a"
                                            ctx.beginPath()
                                            ctx.arc(6, 6.8, 1.1, 0, Math.PI * 2)
                                            ctx.arc(10, 6.8, 1.1, 0, Math.PI * 2)
                                            ctx.fill()
                                        } else {
                                            ctx.strokeStyle = "#89794d"
                                            ctx.lineWidth = 1.5
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, 4.8, 0, Math.PI * 2)
                                            ctx.stroke()

                                            ctx.fillStyle = "#e0c888"
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, 1.9, 0, Math.PI * 2)
                                            ctx.fill()
                                        }
                                    }
                                }

                                onIsFocusedChanged: workspaceIcon.requestPaint()
                                onHasAppChanged: workspaceIcon.requestPaint()

                                MouseArea {
                                    id: workspaceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Hyprland.dispatch("workspace " + workspaceItem.wsId)
                                }
                            }
                        }
                    }
                }

                Text {
                    id: activeWindowTitle
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 2 * Math.max(workspaceStrip.width + 16, systemStats.width) - 32)
                    text: root.activeTitle
                    font.family: "Ndot 57"
                    font.pixelSize: 15
                    font.letterSpacing: 1
                    font.weight: Font.Medium
                    color: Qt.rgba(224/255, 200/255, 136/255, 0.72)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    id: systemStats
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }

                    Item {
                        width: tempLabel.width + 20
                        height: parent.height
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 1
                            color: root.sep
                        }
                        Text {
                            id: tempLabel
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: root.cpuTemp || "TEMP --"
                            font.family: "Ndot 57"
                            font.pixelSize: 14
                            font.letterSpacing: 1
                            color: root.cpuTempNum > 53 ? "#c86060" : root.cpuColor
                        }
                    }

                    Item {
                        width: batLabel.width + 20
                        height: parent.height
                        visible: root.hasBattery
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 1
                            color: root.sep
                        }
                        Text {
                            id: batLabel
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "BAT " + root.batPercent + root.batCharging
                            font.family: "Ndot 57"
                            font.pixelSize: 14
                            font.letterSpacing: 1
                            color: root.batColor
                        }
                    }

                    Item {
                        width: pwrLabel.width + 20
                        height: parent.height
                        visible: root.hasBattery
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 1
                            color: root.sep
                        }
                        Text {
                            id: pwrLabel
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "PWR " + root.batPower
                            font.family: "Ndot 57"
                            font.pixelSize: 14
                            font.letterSpacing: 1
                            color: root.cpuColor
                        }
                    }

                    Item {
                        width: cpuLabel.width + 20
                        height: parent.height
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 1
                            color: root.sep
                        }
                        Text {
                            id: cpuLabel
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "CPU " + root.cpuVal
                            font.family: "Ndot 57"
                            font.pixelSize: 14
                            font.letterSpacing: 1
                            color: parseFloat(root.cpuVal) > 12 ? "#c86060" : (root.cpuVal !== "--" ? root.cpuColor : root.inkDim)
                        }
                    }

                    Item {
                        width: memLabel.width + 20
                        height: parent.height
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 1
                            color: root.sep
                        }
                        Text {
                            id: memLabel
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "MEM " + root.memVal
                            font.family: "Ndot 57"
                            font.pixelSize: 14
                            font.letterSpacing: 1
                            color: root.memVal !== "--" ? root.memColor : root.inkDim
                        }
                    }

                    Item {
                        width: netLabel.width + 20
                        height: parent.height
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 1
                            color: root.sep
                        }
                        Text {
                            id: netLabel
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: root.wifiSsid
                            font.family: "Ndot 57"
                            font.pixelSize: 14
                            font.letterSpacing: 1
                            color: root.netColor
                        }
                    }

                    Item {
                        width: clockLabel.width + 20
                        height: parent.height
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 1
                            color: root.sep
                        }
                        Text {
                            id: clockLabel
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: root.currentTime
                            font.family: "Ndot 57"
                            font.pixelSize: 14
                            font.letterSpacing: 2
                            color: "#e0c888"
                        }
                    }
                }
            }
        }
    }
}
