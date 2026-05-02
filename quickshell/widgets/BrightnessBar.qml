import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

pragma ComponentBehavior: Bound

ShellRoot {
    id: root

    readonly property int segments: 30
    readonly property int hoverWidth: 65
    readonly property int barWidth: 40
    readonly property int barHeight: 420
    readonly property int leftOffset: 18
    readonly property int hideDelay: 400

    readonly property int segFilledW: 14
    readonly property int segEmptyW:  4
    readonly property int segEmptyH:  4
    readonly property int segFilledH: 3
    readonly property int segActiveW: 22
    readonly property int segActiveH: 5

    readonly property color colFilled: "#a89a7e"
    readonly property color colEmpty:  "#c8b89a"
    readonly property color colBg:     "#0f0d0a"

    property real brightness: -1
    property bool userInteracting: false
    property bool autoRevealed: false

    Timer {
        id: autoHideTimer
        interval: 1500
        repeat: false
        onTriggered: root.autoRevealed = false
    }

    function triggerAutoReveal() {
        root.autoRevealed = true
        autoHideTimer.restart()
    }

    // ── IPC: triggered by Hyprland keybind → qs ipc call brightness increment/decrement ──
    IpcHandler {
        target: "brightness"
        function increment(): void { root.showOSD() }
        function decrement(): void { root.showOSD() }
    }

    function showOSD() {
        root.userInteracting = false
        root.readBrightness()
        root.triggerAutoReveal()
    }

    function readBrightness() {
        if (!readProc.running) readProc.running = true
    }

    function setBrightness(v) {
        v = Math.max(0, Math.min(1, v))
        root.brightness = v
        var pct = Math.round(v * 100)
        setProc.command = ["brightnessctl", "set", pct + "%", "--quiet"]
        setProc.running = true
    }

    // ── Initial read on startup ──
    Timer { interval: 200; running: true; repeat: false; onTriggered: root.readBrightness() }

    Process { id: setProc; command: ["sh","-c","true"]; running: false }
    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(",")
                if (parts.length >= 5) {
                    var cur = parseFloat(parts[3]) / 100
                    if (cur >= 0) {
                        root.brightness = Math.max(0, Math.min(1, cur))
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            property bool revealed: root.autoRevealed
                                  || barMouseArea.containsMouse
                                  || barMouseArea.pressed
                                  || hideTimer.running

            implicitWidth: revealed
                ? (root.leftOffset + root.barWidth + 10)
                : 1
            implicitHeight: revealed ? (root.barHeight + 40) : 1

            margins.top: revealed ? (modelData.height - implicitHeight) / 2 : -100

            visible: true

            Timer {
                id: hideTimer
                interval: root.hideDelay
                repeat: false
            }

            Item {
                id: barContainer
                width: root.barWidth
                height: root.barHeight
                anchors.verticalCenter: parent.verticalCenter
                x: panel.revealed ? parent.width - root.barWidth - root.leftOffset : parent.width
                opacity: panel.revealed ? 1 : 0

                Behavior on x       { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Rectangle {
                    anchors.fill: parent
                    color: root.colBg
                    opacity: 0.55
                    border.color: root.colFilled
                    border.width: 1
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Repeater {
                        model: root.segments
                        Item {
                            required property int index
                            width: parent.width
                            height: (root.barHeight - 12 - (root.segments - 1) * 2) / root.segments

                            property real segLevel: 1 - (index / (root.segments - 1))
                            property bool filled: root.brightness >= segLevel - 0.0001
                            property real segStep: 1 / (root.segments - 1)
                            property bool active: filled && (root.brightness < segLevel + segStep - 0.0001)

                            Rectangle {
                                anchors.centerIn: parent
                                width:  parent.active ? root.segActiveW
                                      : parent.filled ? root.segFilledW
                                      :                 root.segEmptyW
                                height: parent.active ? root.segActiveH
                                      : parent.filled ? root.segFilledH
                                      :                 root.segEmptyH
                                radius: parent.filled ? 1 : 0
                                color: parent.filled ? root.colFilled : root.colEmpty

                                Behavior on width   { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on height  { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on color   { ColorAnimation  { duration: 220 } }
                                Behavior on radius  { NumberAnimation { duration: 220 } }
                            }
                        }
                    }
                }

                MouseArea {
                    id: barMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton

                    function yToBrightness(y) {
                        var m = 6
                        var h = height - 2 * m
                        return Math.max(0, Math.min(1, 1 - (y - m) / h))
                    }

                    onEntered: hideTimer.stop()
                    onExited:  hideTimer.restart()

                    onPressed: function(e) {
                        root.userInteracting = true
                        root.setBrightness(yToBrightness(e.y))
                    }
                    onReleased: root.userInteracting = false
                    onPositionChanged: function(e) {
                        if (pressed) root.setBrightness(yToBrightness(e.y))
                    }
                    onWheel: function(e) {
                        var step = 0.08
                        if (e.angleDelta.y > 0) root.setBrightness(root.brightness + step)
                        else                    root.setBrightness(root.brightness - step)
                        hideTimer.restart()
                    }
                }

                Text {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: -16
                    text: root.brightness >= 0 ? Math.round(root.brightness * 100) + "%" : "--%"
                    font.family: "Ndot 57"
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    color: root.colFilled
                    opacity: 0.8
                }
            }
        }
    }
}
