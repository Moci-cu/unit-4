//@ pragma Env QS_NO_RELOAD_POPUP=1
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Networking
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

    // ── Coffee mode (ii-vynx IdleInhibitor pattern) ──
    property bool coffeeMode: false
    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            implicitWidth: 0; implicitHeight: 0
            color: "transparent"
            anchors { right: true; bottom: true }
            mask: Region { item: null }
        }
        enabled: root.coffeeMode
    }

    // ── ii-vynx GlobalShortcuts ──
    GlobalShortcut {
        name: "lock"
        onPressed: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/lock.sh"])
    }
    GlobalShortcut {
        name: "lockFocus"
        onPressed: {} // lock screen handles own focus
    }

    // ── NOTIFICATIONS ──
    Notifications {}

    // ── VOLUMEBAR ──
    VolumeBar {}

    // ── BRIGHTNESSBAR ──
    BrightnessBar {}

    // ── BAR (in-process, merged from quickshell-bar) ──
    Bar {}

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

            Connections {
                target: menuItem
                function onCoffeeModeChanged() { root.coffeeMode = menuItem.coffeeMode }
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