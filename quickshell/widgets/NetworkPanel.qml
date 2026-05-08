import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

pragma ComponentBehavior: Bound

Item {
    id: root

    signal netPanelToggle(string tab)

    function togglePanel(tab: string) {
        root.netPanelToggle(tab)
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
                function onNetPanelToggle(tab: string) {
                    netItem.togglePanel(tab)
                }
            }
        }
    }
}
