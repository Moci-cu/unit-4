import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "widgets"

ShellRoot {
    id: root

    signal netPanelFireToggle(string tab)

    // ── File-based command from bar ──
    property string lastCmd: ""

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: cmdFile.reload()
    }

    FileView {
        id: cmdFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-netpanel-cmd"
        onLoaded: {
            var raw = text().trim()
            if (!raw || raw === root.lastCmd) return
            root.lastCmd = raw
            var parts = raw.split(":")
            if (parts.length >= 2 && parts[0] === "open") {
                root.netPanelFireToggle(parts[1] || "wifi")
            }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top: true; anchors.left: true; anchors.right: true; anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: netItem.panelOpen || netItem.animRunning
            color: "transparent"
            WlrLayershell.keyboardFocus: netItem.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            implicitWidth: modelData.width
            implicitHeight: modelData.height
            visible: netItem.panelOpen || netItem.animRunning
            WlrLayershell.namespace: "quickshell-network"

            NetworkPopup {
                id: netItem
                anchors.fill: parent
                screenW: modelData.width
                screenH: modelData.height
            }

            Connections {
                target: root
                function onNetPanelFireToggle(tab: string) {
                    netItem.togglePanel(tab)
                }
            }
        }
    }
}
