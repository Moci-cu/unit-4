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
    readonly property color fieldBg:   Qt.rgba(18/255,16/255,11/255,0.72)
    readonly property color fieldEdge: Qt.rgba(224/255,200/255,136/255,0.13)
    readonly property color cpuColor:  "#c87060"
    readonly property color memColor:  "#6090c8"
    readonly property color netColor:  "#60a880"
    readonly property color wsGold:    "#e0c888"
    readonly property color wsDim:     Qt.rgba(224/255,200/255,136/255,0.3)
    readonly property color wsHover:   Qt.rgba(224/255,200/255,136/255,0.7)
    readonly property color wsHoverBg: Qt.rgba(224/255,200/255,136/255,0.05)
    readonly property color wsAppLine: Qt.rgba(224/255,200/255,136/255,0.5)
    readonly property color statusText: Qt.rgba(224/255,200/255,136/255,0.72)
    readonly property color statusDim:  Qt.rgba(224/255,200/255,136/255,0.48)

    readonly property int barHeight: 35
    readonly property int wsDotWidth: 22

    readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property var wsWithApps: ({})

    Component.onCompleted: {
        refreshApps()
        resolveTempSensor()
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
    readonly property bool batteryCharging: root.hasBattery && root.battery.state === UPowerDeviceState.Charging
    readonly property bool batteryFull: root.hasBattery
        && root.battery.percentage >= 0.995
        && root.battery.state !== UPowerDeviceState.Discharging
    readonly property bool batteryPowered: root.batteryCharging || root.batteryFull
    property real batteryFillLevel: root.hasBattery ? root.battery.percentage : 0
    property real batteryChargePhase: 0
    readonly property string batPower: root.hasBattery
        ? Math.abs(root.battery.changeRate).toFixed(1) + "W"
        : ""
    property string tlpProfile: ""
    readonly property bool batteryPowerSaver: root.tlpProfile === "power-saver"
    readonly property color batteryFillColor: root.hasBattery && root.battery.percentage <= 0.2
        ? "#c86060"
        : root.wsGold
    readonly property string powerProfileHelper: Quickshell.env("HOME") + "/.config/hypr/scripts/power-profile.sh"
    readonly property string powerProfileState: Quickshell.env("XDG_RUNTIME_DIR") + "/dots-power-profile.state"

    FileView {
        id: powerProfileFile
        path: root.powerProfileState
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.tlpProfile = text().trim()
    }

    Process {
        id: powerProfileSync
        command: [root.powerProfileHelper, "sync"]
        running: true
        onExited: powerProfileFile.reload()
    }

    Behavior on batteryFillLevel {
        NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
    }

    Timer {
        interval: 120
        running: root.batteryCharging && !root.batteryFull
        repeat: true
        onTriggered: {
            root.batteryChargePhase += 0.08
            if (root.batteryChargePhase > 1)
                root.batteryChargePhase = 0
        }
    }

    onBatteryChargingChanged: {
        root.batteryChargePhase = 0
    }

    readonly property var wifiDevice: {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        }
        return null
    }
    readonly property var connectedWifiNetwork: {
        if (!root.wifiDevice) return null
        if (!root.wifiDevice.networks) return null
        var nets = root.wifiDevice.networks.values || root.wifiDevice.networks
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected || nets[i].state === ConnectionState.Connected)
                return nets[i]
        }
        return null
    }
    readonly property bool wifiConnected: root.connectedWifiNetwork !== null
        || (root.wifiDevice && root.wifiDevice.connected)
    readonly property int wifiSignalBars: {
        if (!root.wifiConnected) return 0
        if (!root.connectedWifiNetwork
                || typeof root.connectedWifiNetwork.signalStrength !== "number")
            return 1
        var strength = Math.max(0, Math.min(1, root.connectedWifiNetwork.signalStrength))
        return strength >= 0.75 ? 3 : strength >= 0.5 ? 2 : 1
    }

    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    readonly property string currentTime: {
        var h = sysClock.hours, m = sysClock.minutes
        return ("0" + h).slice(-2) + ":" + ("0" + m).slice(-2)
    }
    readonly property string currentDate: Qt.formatDate(sysClock.date, "ddd dd MMM").toUpperCase()

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

                Item {
                    id: centerContent
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 2 * (systemStats.width + 32))
                    height: parent.height

                    Row {
                        id: centerCluster
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            id: workspaceStrip
                            width: workspaceRow.width + 10
                            height: 28
                            radius: 4
                            color: root.fieldBg
                            border.width: 1
                            border.color: root.fieldEdge

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
                                    width: 20
                                    height: 20
                                    antialiasing: true

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var scale = width / 16
                                        var cx = 8
                                        var cy = 8
                                        ctx.save()
                                        ctx.scale(scale, scale)

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
                                        ctx.restore()
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

                        Rectangle {
                            width: dateTimeRow.implicitWidth + 18
                            height: 28
                            radius: 4
                            color: root.fieldBg
                            border.width: 1
                            border.color: root.fieldEdge

                            Row {
                                id: dateTimeRow
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    id: dateLabel
                                    text: root.currentDate
                                    font.family: "Ndot 57"
                                    font.pixelSize: 15
                                    font.letterSpacing: 1
                                    color: root.statusText
                                    transform: Translate { y: -1 }
                                }

                                Rectangle {
                                    width: 1
                                    height: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.sep
                                }

                                Text {
                                    id: centerClock
                                    text: root.currentTime
                                    font.family: "Ndot 57"
                                    font.pixelSize: 16
                                    font.letterSpacing: 2
                                    color: root.wsGold
                                    transform: Translate { y: -1 }
                                }
                            }
                        }
                    }
                }

                Row {
                    id: activeWindowInfo
                    anchors {
                        left: parent.left
                        leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    width: Math.max(0, centerContent.x + centerCluster.x - 26)
                    spacing: 7
                    visible: width > 0

                    Canvas {
                        id: activeWindowMark
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        antialiasing: true

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.save()
                            ctx.scale(width / 16, height / 16)
                            ctx.strokeStyle = root.statusDim
                            ctx.fillStyle = root.wsGold
                            ctx.lineWidth = 1

                            ctx.beginPath()
                            ctx.arc(8, 8, 6.5, 0, Math.PI * 2)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.moveTo(8, 3.5)
                            ctx.lineTo(9.2, 6.8)
                            ctx.lineTo(12.5, 8)
                            ctx.lineTo(9.2, 9.2)
                            ctx.lineTo(8, 12.5)
                            ctx.lineTo(6.8, 9.2)
                            ctx.lineTo(3.5, 8)
                            ctx.lineTo(6.8, 6.8)
                            ctx.closePath()
                            ctx.fill()
                            ctx.restore()
                        }
                    }

                    Text {
                        id: activeWindowTitle
                        width: Math.max(0, activeWindowInfo.width - activeWindowMark.width - activeWindowInfo.spacing)
                        text: root.activeTitle !== "" ? root.activeTitle : "---"
                        font.family: "Ndot 57"
                        font.pixelSize: 17
                        font.letterSpacing: 1
                        font.weight: Font.Medium
                        color: root.activeTitle !== "" ? root.statusText : root.statusDim
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: systemStats
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    spacing: 6

                    Item {
                        width: resourceRow.width + 24
                        height: parent.height
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 28
                            radius: 4
                            color: root.fieldBg
                            border.width: 1
                            border.color: root.fieldEdge
                        }
                        Row {
                            id: resourceRow
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12

                            Row {
                                spacing: 5

                                Canvas {
                                    id: cpuIcon
                                    width: 20
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    antialiasing: true

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var scale = width / 14
                                        ctx.save()
                                        ctx.scale(scale, scale)
                                        ctx.strokeStyle = root.statusText
                                        ctx.lineWidth = 1.2

                                        ctx.strokeRect(3.5, 3.5, 7, 7)
                                        ctx.strokeRect(5.5, 5.5, 3, 3)

                                        for (var i = 0; i < 3; i++) {
                                            var pin = 4.5 + i * 2.5
                                            ctx.beginPath()
                                            ctx.moveTo(pin, 1.5)
                                            ctx.lineTo(pin, 3.5)
                                            ctx.moveTo(pin, 10.5)
                                            ctx.lineTo(pin, 12.5)
                                            ctx.moveTo(1.5, pin)
                                            ctx.lineTo(3.5, pin)
                                            ctx.moveTo(10.5, pin)
                                            ctx.lineTo(12.5, pin)
                                            ctx.stroke()
                                        }
                                        ctx.restore()
                                    }
                                }

                                Text {
                                    text: root.cpuVal
                                    font.family: "Ndot 57"
                                    font.pixelSize: 16
                                    font.letterSpacing: 1
                                    color: parseFloat(root.cpuVal) > 12 ? "#c86060" : (root.cpuVal !== "--" ? root.statusText : root.statusDim)
                                }
                            }
                            Row {
                                spacing: 5

                                Canvas {
                                    width: 20
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    antialiasing: true

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.save()
                                        ctx.scale(width / 18, height / 18)
                                        ctx.strokeStyle = root.statusText
                                        ctx.fillStyle = root.statusText
                                        ctx.lineWidth = 1.2

                                        ctx.beginPath()
                                        ctx.moveTo(1.5, 5)
                                        ctx.lineTo(3, 3.5)
                                        ctx.lineTo(15, 3.5)
                                        ctx.lineTo(16.5, 5)
                                        ctx.lineTo(16.5, 12)
                                        ctx.lineTo(14.5, 14)
                                        ctx.lineTo(3.5, 14)
                                        ctx.lineTo(1.5, 12)
                                        ctx.closePath()
                                        ctx.stroke()

                                        for (var i = 0; i < 3; i++)
                                            ctx.strokeRect(4 + i * 3.5, 6, 2.5, 5)

                                        ctx.beginPath()
                                        ctx.moveTo(1.5, 7)
                                        ctx.lineTo(4, 7)
                                        ctx.moveTo(14, 10)
                                        ctx.lineTo(16.5, 10)
                                        ctx.stroke()

                                        for (var j = 0; j < 4; j++) {
                                            var contact = 4.5 + j * 3
                                            ctx.beginPath()
                                            ctx.moveTo(contact, 14)
                                            ctx.lineTo(contact, 16)
                                            ctx.stroke()
                                        }

                                        ctx.beginPath()
                                        ctx.arc(2.8, 9.5, 0.8, 0, Math.PI * 2)
                                        ctx.arc(15.2, 7.5, 0.8, 0, Math.PI * 2)
                                        ctx.fill()
                                        ctx.restore()
                                    }
                                }

                                Text {
                                    text: root.memVal
                                    font.family: "Ndot 57"
                                    font.pixelSize: 16
                                    font.letterSpacing: 1
                                    color: root.memVal !== "--" ? root.statusText : root.statusDim
                                }
                            }

                            Row {
                                spacing: 5

                                Canvas {
                                    id: tempIcon
                                    width: 20
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    antialiasing: true

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.save()
                                        ctx.scale(width / 18, height / 18)
                                        var iconColor = root.cpuTempNum > 53 ? "#c86060" : root.statusText
                                        ctx.strokeStyle = iconColor
                                        ctx.fillStyle = iconColor
                                        ctx.lineWidth = 1.5

                                        ctx.beginPath()
                                        ctx.arc(9, 13, 3.5, 0, Math.PI * 2)
                                        ctx.stroke()
                                        ctx.beginPath()
                                        ctx.moveTo(7.5, 11)
                                        ctx.lineTo(7.5, 4)
                                        ctx.arc(9, 4, 1.5, Math.PI, 0)
                                        ctx.lineTo(10.5, 11)
                                        ctx.stroke()

                                        ctx.fillRect(8.25, 7, 1.5, 6)
                                        ctx.beginPath()
                                        ctx.arc(9, 13, 2, 0, Math.PI * 2)
                                        ctx.fill()
                                        ctx.restore()
                                    }

                                    Connections {
                                        target: root
                                        function onCpuTempNumChanged() { tempIcon.requestPaint() }
                                    }
                                }

                                Text {
                                    text: root.cpuTemp ? root.cpuTemp.replace(/^TEMP\s*/, "") : "--"
                                    font.family: "Ndot 57"
                                    font.pixelSize: 16
                                    font.letterSpacing: 1
                                    color: root.cpuTempNum > 53 ? "#c86060" : root.statusText
                                }
                            }
                        }
                    }

                    Item {
                        width: powerRow.width + 24
                        height: parent.height
                        visible: root.hasBattery
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 28
                            radius: 4
                            color: root.fieldBg
                            border.width: 1
                            border.color: root.fieldEdge
                        }
                        Row {
                            id: powerRow
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12

                            Item {
                                width: 48
                                height: 26
                                anchors.verticalCenter: parent.verticalCenter

                                Canvas {
                                    id: batteryIcon
                                    anchors.fill: parent
                                    antialiasing: true

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.save()
                                        ctx.scale(width / 46, height / 24)
                                        var actualLevel = Math.max(0, Math.min(1, root.batteryFillLevel))
                                        var level = root.batteryCharging && !root.batteryFull
                                            ? actualLevel * root.batteryChargePhase
                                            : actualLevel

                                        ctx.strokeStyle = root.wsGold
                                        ctx.lineWidth = 1.3
                                        ctx.beginPath()
                                        ctx.moveTo(3, 4.5)
                                        ctx.lineTo(39, 4.5)
                                        ctx.lineTo(42, 7.5)
                                        ctx.lineTo(42, 16.5)
                                        ctx.lineTo(39, 19.5)
                                        ctx.lineTo(3, 19.5)
                                        ctx.lineTo(1, 17.5)
                                        ctx.lineTo(1, 6.5)
                                        ctx.closePath()
                                        ctx.stroke()

                                        ctx.fillStyle = Qt.rgba(
                                            root.batteryFillColor.r,
                                            root.batteryFillColor.g,
                                            root.batteryFillColor.b,
                                            0.38
                                        )
                                        ctx.fillRect(3.5, 7, 35.5 * level, 10)

                                        ctx.fillStyle = root.wsGold
                                        ctx.fillRect(43, 9, 2, 6)

                                        if (root.batteryPowered) {
                                            ctx.beginPath()
                                            ctx.moveTo(25.5, 0.5)
                                            ctx.lineTo(14.5, 12.5)
                                            ctx.lineTo(22, 12.5)
                                            ctx.lineTo(18.5, 23.5)
                                            ctx.lineTo(31.5, 9.5)
                                            ctx.lineTo(24, 9.5)
                                            ctx.closePath()
                                            ctx.strokeStyle = root.bg
                                            ctx.lineWidth = 3
                                            ctx.lineJoin = "round"
                                            ctx.stroke()
                                            ctx.fillStyle = root.wsGold
                                            ctx.fill()
                                        } else if (root.batteryPowerSaver) {
                                            ctx.fillStyle = root.wsGold
                                            ctx.strokeStyle = root.wsGold
                                            ctx.lineWidth = 1.4

                                            ctx.beginPath()
                                            ctx.moveTo(23, 2)
                                            ctx.bezierCurveTo(14, 9, 13.5, 16.5, 22, 21.5)
                                            ctx.bezierCurveTo(32, 15, 32, 8, 23, 2)
                                            ctx.closePath()
                                            ctx.fill()

                                            ctx.beginPath()
                                            ctx.moveTo(23, 3)
                                            ctx.bezierCurveTo(22, 10, 23, 17, 17.5, 23)
                                            ctx.stroke()
                                        }
                                        ctx.restore()
                                    }

                                    Connections {
                                        target: root
                                        function onBatteryFillLevelChanged() { batteryIcon.requestPaint() }
                                        function onBatteryChargePhaseChanged() { batteryIcon.requestPaint() }
                                        function onBatteryChargingChanged() { batteryIcon.requestPaint() }
                                        function onBatteryFullChanged() { batteryIcon.requestPaint() }
                                        function onBatteryPowerSaverChanged() { batteryIcon.requestPaint() }
                                        function onBatteryFillColorChanged() { batteryIcon.requestPaint() }
                                    }
                                }

                                Text {
                                    anchors {
                                        left: parent.left
                                        leftMargin: 2
                                        right: parent.right
                                        rightMargin: 4
                                        verticalCenter: parent.verticalCenter
                                    }
                                    visible: !root.batteryPowered && !root.batteryPowerSaver
                                    text: root.batPercent.replace("%", "")
                                    font.family: "Ndot 57"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0
                                    horizontalAlignment: Text.AlignHCenter
                                    color: root.wsGold
                                }
                            }
                            Row {
                                spacing: 5

                                Canvas {
                                    width: 20
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    antialiasing: true

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.save()
                                        ctx.scale(width / 18, height / 18)
                                        ctx.strokeStyle = root.statusText
                                        ctx.lineWidth = 1.4

                                        ctx.beginPath()
                                        ctx.arc(9, 9, 6.5, Math.PI * 0.72, Math.PI * 2.28)
                                        ctx.stroke()

                                        ctx.beginPath()
                                        ctx.moveTo(9, 1.5)
                                        ctx.lineTo(9, 6.5)
                                        ctx.stroke()

                                        ctx.beginPath()
                                        ctx.moveTo(5, 11)
                                        ctx.lineTo(7.3, 8.7)
                                        ctx.lineTo(9.2, 10.6)
                                        ctx.lineTo(13, 6.8)
                                        ctx.stroke()

                                        ctx.fillStyle = root.statusText
                                        ctx.beginPath()
                                        ctx.arc(13, 6.8, 1, 0, Math.PI * 2)
                                        ctx.fill()
                                        ctx.restore()
                                    }
                                }

                                Text {
                                    text: root.batPower
                                    font.family: "Ndot 57"
                                    font.pixelSize: 16
                                    font.letterSpacing: 1
                                    color: root.statusDim
                                }
                            }
                        }
                    }

                    Item {
                        width: 62
                        height: parent.height
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 1
                            color: root.sep
                        }
                        Canvas {
                            id: networkIcon
                            anchors.centerIn: parent
                            width: 38
                            height: 16
                            antialiasing: true

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.save()
                                ctx.scale(width / 36, height / 14)
                                ctx.fillStyle = root.wsGold
                                ctx.strokeStyle = root.statusDim
                                ctx.lineWidth = 1.2

                                for (var i = 0; i < 3; i++) {
                                    var x = 1 + i * 12
                                    ctx.beginPath()
                                    ctx.moveTo(x + 3, 3)
                                    ctx.lineTo(x + 10, 3)
                                    ctx.lineTo(x + 7, 11)
                                    ctx.lineTo(x, 11)
                                    ctx.closePath()
                                    if (i < root.wifiSignalBars)
                                        ctx.fill()
                                    else
                                        ctx.stroke()
                                }
                                ctx.restore()
                            }

                            Connections {
                                target: root
                                function onWifiSignalBarsChanged() { networkIcon.requestPaint() }
                            }
                        }
                    }

                }
            }
        }
    }
}
