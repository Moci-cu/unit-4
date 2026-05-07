//@ pragma Env QS_NO_RELOAD_POPUP=1
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "widgets"
import "components"
import "settings"
import "theme"

ShellRoot {
    id: root

    // ── Dark mode state reader ──
    FileView {
        id: dmFile
        path: Quickshell.env("HOME") + "/.config/quickshell/dark-mode.state"
        onLoaded: { Theme.darkState = text().trim() }
    }
    Timer { interval: 100; running: true; repeat: false; onTriggered: dmFile.reload() }

    // ── NOTIFICATIONS ──
    Notifications {}

    // ── VOLUMEBAR ──
    VolumeBar {}

    // ── BRIGHTNESSBAR ──
    BrightnessBar {}

    property string currentUser: Quickshell.env("USER") || "user"

    // ── IPC handlers ──
    IpcHandler {
        target: "menu"
        function toggle(): void { root.menuFireToggle() }
    }
    signal sysPanelFireToggle()
    IpcHandler {
        target: "syspanel"
        function toggle(): void { root.sysPanelFireToggle() }
    }

    readonly property string menuActiveMonitor: Hyprland.focusedMonitor
        ? Hyprland.focusedMonitor.name
        : ""
    signal menuFireToggle()

    // ── MENU ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top:true;anchors.left:true;anchors.right:true;anchors.bottom:true
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: menuItem.menuOpen || menuItem.animRunning
            color: "transparent"
            WlrLayershell.keyboardFocus: menuItem.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            implicitWidth: modelData.width
            implicitHeight: modelData.height
            visible: menuItem.menuOpen || menuItem.animRunning

            Menu {
                id: menuItem
                anchors.fill: parent
                screenW: modelData.width
                screenH: modelData.height
            }

            Connections {
                target: root
                function onMenuFireToggle() {
                    if (root.menuActiveMonitor !== modelData.name) return
                    if (menuItem.menuOpen) menuItem.closeMenu()
                    else menuItem.openMenu()
                }
            }

            IdleInhibitor {
                window: parent
                enabled: menuItem.coffeeMode
            }
        }
    }

    // ── SYSTEM PANEL ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top: true; anchors.left: true; anchors.right: true; anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: sysPanelItem.panelOpen || sysPanelItem.animRunning
            color: "transparent"
            WlrLayershell.keyboardFocus: sysPanelItem.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            implicitWidth: modelData.width
            implicitHeight: modelData.height
            visible: sysPanelItem.panelOpen || sysPanelItem.animRunning

            SystemPanel {
                id: sysPanelItem
                anchors.fill: parent
                screenW: modelData.width
                screenH: modelData.height
            }

            Connections {
                target: root
                function onSysPanelFireToggle() {
                    sysPanelItem.togglePanel()
                }
            }
        }
    }

}