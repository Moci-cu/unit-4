import QtQuick
import Quickshell
import Quickshell.Io

pragma ComponentBehavior: Bound

Item {
    id: root

    property bool panelOpen: false
    property bool animRunning: false
    property real screenW: 1920
    property real screenH: 1080

    readonly property int panelW: 440
    readonly property int panelH: 280
    readonly property int gridSize: 12

    readonly property color paper:     "#d6cfb5"
    readonly property color ink:       "#463f2e"
    readonly property color inkStrong: "#2e2a1f"
    readonly property color inkSoft:   "#7a7358"
    readonly property color lineVsoft: Qt.rgba(70/255,63/255,46/255,0.12)
    readonly property color lineSoft:  Qt.rgba(70/255,63/255,46/255,0.25)
    readonly property color accent:    "#6e2a2a"

    FontLoader { id: mainFont; source: "/home/mocicu/.local/share/fonts/Ndot57-Regular.otf" }
    readonly property string ff: mainFont.name

    property string cpuVal: "--"
    property string memVal: "--"
    property string batVal: "--"
    property string netVal: "--"
    property string clkVal: "--:--"

    property int lastCpuUsed: 0
    property int lastCpuTotal: 0

    // ── Clock (1s, gated) ──
    Timer {
        interval: 1000
        running: root.panelOpen
        repeat: true
        onTriggered: {
            var d = new Date()
            root.clkVal = String(d.getHours()).padStart(2,"0") + ":" + String(d.getMinutes()).padStart(2,"0")
        }
    }

    // ── CPU: head -1 /proc/stat (no awk, parse in QML) ──
    Timer { interval: 2000; running: root.panelOpen; repeat: true; onTriggered: cpuProc.running = true }
    Process {
        id: cpuProc
        command: ["head","-1","/proc/stat"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(/\s+/)
                if (p.length < 5 || p[0] !== "cpu") return
                var used = parseInt(p[1]) + parseInt(p[2]) + parseInt(p[3])
                var total = used + parseInt(p[4])
                if (root.lastCpuTotal > 0 && total > root.lastCpuTotal) {
                    root.cpuVal = Math.round(100 * (used - root.lastCpuUsed) / (total - root.lastCpuTotal)) + "%"
                }
                root.lastCpuUsed = used
                root.lastCpuTotal = total
            }
        }
    }

    // ── Memory: grep /proc/meminfo directly (no free) ──
    Timer { interval: 3000; running: root.panelOpen; repeat: true; onTriggered: memProc.running = true }
    Process {
        id: memProc
        command: ["grep","-E","^MemTotal:|^MemAvailable:","/proc/meminfo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                var total = 0, avail = 0
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    var m = line.match(/MemTotal:\s+(\d+)/)
                    if (m) total = parseInt(m[1])
                    m = line.match(/MemAvailable:\s+(\d+)/)
                    if (m) avail = parseInt(m[1])
                }
                if (total > 0) {
                    root.memVal = Math.round(100 * (total - avail) / total) + "%"
                }
            }
        }
    }

    // ── Battery: cat sysfs directly (already optimal) ──
    Timer { interval: 5000; running: root.panelOpen; repeat: true; onTriggered: batProc.running = true }
    Process {
        id: batProc
        command: ["sh","-c","cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo '--'"]
        running: false
        stdout: SplitParser {
            onRead: data => { root.batVal = data.trim() + "%" }
        }
    }

    // ── Network: read /sys/class/net directly (no nmcli) ──
    Timer { interval: 3000; running: root.panelOpen; repeat: true; onTriggered: netProc.running = true }
    Process {
        id: netProc
        command: ["sh","-c","for i in wlan0 wlp2s0 wlp3s0 eth0 enp3s0; do if [ -r /sys/class/net/\$i/operstate ]; then cat /sys/class/net/\$i/operstate; exit; fi; done; echo 'down'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                root.netVal = (s === "up") ? "UP" : ((s === "down") ? "DOWN" : s)
            }
        }
    }

    // ── Panel content ──
    Item {
        id: panelHost
        x: (root.screenW - root.panelW) / 2
        y: (root.screenH - root.panelH) / 2
        width:  root.panelW
        height: root.panelH
        clip: true
        visible: root.panelOpen || root.animRunning
        opacity: root.panelOpen ? 1 : 0
        scale:   root.panelOpen ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: root.paper
            border.color: root.ink
            border.width: 1

            Repeater {
                model: Math.floor(parent.width / root.gridSize) + 1
                Rectangle { required property int index; x: index * root.gridSize; y: 0; width: 1; height: parent.height; color: root.lineVsoft }
            }
            Repeater {
                model: Math.floor(parent.height / root.gridSize) + 1
                Rectangle { required property int index; x: 0; y: index * root.gridSize; width: parent.width; height: 1; color: root.lineVsoft }
            }

            Item {
                id: header
                width: parent.width
                height: 46
                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 22; rightMargin: 22 }
                    Row {
                        spacing: 10; anchors.verticalCenter: parent.verticalCenter
                        Text { text:"◈"; font.family:root.ff; font.pixelSize: 12; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text:"SYSTEM MONITOR"; font.family:root.ff; font.pixelSize: 11; font.letterSpacing: 3; font.weight: Font.Medium; color: root.inkStrong; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: 20; height: 1; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                        Text { text:"システム監視"; font.family:root.ff; font.pixelSize: 10; font.letterSpacing: 2; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Item { width: parent.width - 300; height: 1 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"; font.family:root.ff; font.pixelSize: 14; color: root.inkSoft
                        MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.lineSoft }
            }

            Item {
                anchors { top: header.bottom; bottom: footer.top; left: parent.left; right: parent.right }

                Grid {
                    anchors { fill: parent; margins: 14 }
                    columns: 2
                    spacing: 12

                    Repeater {
                        model: [
                            { icon: "▲", label: "CPU",  val: function() { return root.cpuVal } },
                            { icon: "⬛", label: "MEM",  val: function() { return root.memVal } },
                            { icon: "◆", label: "BAT",  val: function() { return root.batVal } },
                            { icon: "○", label: "NET",  val: function() { return root.netVal } }
                        ]
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: (parent.width - 12) / 2
                            height: (parent.height - 12) / 2
                            color: Qt.rgba(70/255,63/255,46/255,0.08)
                            border.color: root.lineSoft
                            border.width: 1

                            Row {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 12
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.family: root.ff
                                    font.pixelSize: 18
                                    color: root.ink
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: modelData.label
                                        font.family: root.ff
                                        font.pixelSize: 9
                                        font.letterSpacing: 2
                                        color: root.inkSoft
                                    }
                                    Text {
                                        text: modelData.val()
                                        font.pixelSize: 16
                                        font.family: root.ff
                                        font.letterSpacing: 1
                                        color: root.ink
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: footer
                anchors.bottom: parent.bottom
                width: parent.width
                height: 46
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.lineSoft }
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Text { text: "◇"; font.family:root.ff; font.pixelSize: 14; color: root.ink; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: root.clkVal
                        font.pixelSize: 18
                        font.family: root.ff
                        font.letterSpacing: 2
                        color: root.ink
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
        var d = new Date()
        clkVal = String(d.getHours()).padStart(2,"0") + ":" + String(d.getMinutes()).padStart(2,"0")
        cpuProc.running = true; memProc.running = true; batProc.running = true; netProc.running = true
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
