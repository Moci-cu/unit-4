//@ pragma Env QS_NO_RELOAD_POPUP=1
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "widgets"
import "components"
import "settings"

ShellRoot {
    id: root

    // ── NOTIFICATIONS ──
    Notifications {}

    // ── VOLUMEBAR ──
    VolumeBar {}

    // ── BRIGHTNESSBAR ──
    BrightnessBar {}

    // ── PLAYERCTL ──
    property bool   playerVisible: false
    property bool   playerOnTop:   false
    property string mpTitle:    "END OF EVANGELION"
    property string mpArtist:   "NEON GENESIS // ANNO"
    property string mpCoverUrl: ""
    property bool   mpPlaying:  false
    property real   mpPosition: 0
    property real   mpLength:   341

    Process {
        id: playerctlMeta
        command: ["playerctl","metadata","--follow","--format",
                  "{{title}}|{{artist}}|{{mpris:artUrl}}|{{status}}|{{position}}|{{mpris:length}}"]
        running: root.playerVisible
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|")
                if (p.length >= 4) {
                    if (p[0]) root.mpTitle    = p[0]
                    if (p[1]) root.mpArtist   = p[1]
                    root.mpCoverUrl = p[2] || ""
                    root.mpPlaying  = (p[3] === "Playing")
                    root.mpPosition = parseFloat(p[4] || "0") / 1000000
                    root.mpLength   = Math.max(1, parseFloat(p[5] || "341000000") / 1000000)
                }
            }
        }
    }
    Process { id: pcPlay; command: ["playerctl","play-pause"]; running: false }
    Process { id: pcNext; command: ["playerctl","next"];       running: false }
    Process { id: pcPrev; command: ["playerctl","previous"];   running: false }

    property string currentUser: Quickshell.env("USER") || "user"

    // ── IPC handlers (event-driven, zero polling) ──
    IpcHandler {
        target: "menu"
        function toggle(): void { root.menuFireToggle() }
    }
    IpcHandler {
        target: "player"
        function toggle(): void { root.playerVisible = !root.playerVisible }
    }
    IpcHandler {
        target: "front"
        function toggle(): void { root.playerOnTop = !root.playerOnTop }
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
        }
    }

    // ── PLAYER ──
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top:true;anchors.right:true
            margins.top:Math.round(modelData.height*Settings.playerPositionY);margins.right:20
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: root.playerOnTop
            color: "transparent"
            implicitWidth: Settings.playerWidth
            implicitHeight: playerItem.implicitHeight
            visible: root.playerVisible

            Player {
                id: playerItem
                anchors.fill: parent
                mpTitle: root.mpTitle
                mpArtist: root.mpArtist
                mpCoverUrl: root.mpCoverUrl
                mpPlaying: root.mpPlaying
                mpPosition: root.mpPosition
                mpLength: root.mpLength
                onPlayPause: pcPlay.running = true
                onNextTrack: pcNext.running = true
                onPrevTrack: pcPrev.running = true
            }

            Connections {
                target: root
                function onPlayerVisibleChanged() {
                    playerItem.toggleVisible()
                }
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

    // ── PLAYERCTL (event-driven via --follow, zero polling) ──
}
