import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"

pragma ComponentBehavior: Bound

Item {
    id: root
    property bool visible_panel: false

    readonly property color paper: Theme.darkMode ? "#1a1814" : "#e8e0c8"
    readonly property color ink: Theme.darkMode ? "#8a7530" : "#3a342a"
    readonly property color inkSoft: Theme.darkMode ? "#5a5520" : "#8a8570"
    readonly property color accent: Theme.darkMode ? "#a04040" : "#6e2a2a"
    readonly property color dimBg: Theme.darkMode ? "#0f0c07" : "#e0d8c0"

    FontLoader { id: ndotFont; source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Ndot57-Regular.otf" }
    readonly property string ff: ndotFont.name

    GlobalShortcut {
        name: "lyricsToggle"
        onPressed: {
            root.visible_panel = !root.visible_panel
            if (root.visible_panel) lyricsService.init()
        }
    }

    LyricsService { id: lyricsService }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.layer: WlrLayer.Bottom
            implicitWidth: modelData.width
            implicitHeight: modelData.height
            visible: root.visible_panel

            Rectangle {
                anchors.fill: parent
                color: root.dimBg
                opacity: 0.75
                MouseArea { anchors.fill: parent; onClicked: root.visible_panel = false }
            }

            Item {
                anchors { centerIn: parent }
                width: Math.min(parent.width - 100, 720)
                height: parent.height - 100

                Column {
                    anchors.fill: parent
                    spacing: 0

                    // Header: track info
                    Item { width: 1; height: 30 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "▸ LYRICS"
                        font.family: root.ff; font.pixelSize: 16; font.letterSpacing: 4; font.weight: Font.Bold
                        color: root.accent
                    }
                    Item { width: 1; height: 12 }
                    Text {
                        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
                        text: lyricsService.activePlayer?.trackTitle ?? "No track playing"
                        font.family: root.ff; font.pixelSize: 18; font.letterSpacing: 2; font.weight: Font.Bold
                        color: root.ink; elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: lyricsService.activePlayer?.trackArtist ?? ""
                        font.family: root.ff; font.pixelSize: 14; font.letterSpacing: 2
                        color: root.ink; opacity: 0.6
                    }
                    Item { width: 1; height: 16 }
                    Rectangle { width: parent.width - 60; height: 1; color: root.ink; opacity: 0.15; anchors.horizontalCenter: parent.horizontalCenter }
                    Item { width: 1; height: 24 }

                    // Synced lyrics display
                    Item {
                        anchors { left: parent.left; right: parent.right }
                        height: parent.height - 170
                        visible: lyricsService.hasSyncedLines
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            contentWidth: parent.width
                            contentHeight: lyricsColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: lyricsColumn
                                width: parent.width
                                spacing: 10

                                Repeater {
                                    model: lyricsService.syncedLines.length > 0 ? lyricsService.syncedLines.length : 0

                                    delegate: Item {
                                        required property int index
                                        property int lineIdx: index
                                        property bool isCurrent: index === lyricsService.currentIndex
                                        width: parent.width - 40
                                        height: lineTxt.implicitHeight + (isCurrent ? 12 : 0)
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        Text {
                                            id: lineTxt
                                            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
                                            text: lyricsService.syncedLines[lineIdx]?.text ?? ""
                                            font.family: root.ff
                                            font.pixelSize: isCurrent ? 22 : 15
                                            font.letterSpacing: isCurrent ? 2 : 1.5
                                            font.weight: isCurrent ? Font.Bold : Font.Normal
                                            color: root.ink
                                            opacity: isCurrent ? 1.0 : (Math.abs(lineIdx - lyricsService.currentIndex) <= 2 ? 0.4 : 0.15)
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            textFormat: Text.PlainText
                                        }
                                    }
                                }

                                // Bottom padding
                                Item { width: 1; height: 100 }
                            }
                        }
                    }

                    // Loading / fallback text
                    Item {
                        anchors { left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 20 }
                        height: parent.height - 170
                        visible: !lyricsService.hasSyncedLines

                        Column {
                            anchors.centerIn: parent
                            spacing: 16

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: lyricsService.statusText.indexOf("Fetching") >= 0 ? "◉" : "♪"
                                font.family: root.ff; font.pixelSize: 24
                                color: root.accent
                                RotationAnimation on rotation {
                                    running: lyricsService.statusText.indexOf("Fetching") >= 0
                                    from: 0; to: 360; duration: 2000; loops: Animation.Infinite
                                }
                            }
                            Text {
                                anchors { left: parent.left; right: parent.right }
                                text: {
                                    var s = lyricsService.statusText
                                    if (!s) return "Searching lyrics..."
                                    return s
                                }
                                font.family: root.ff; font.pixelSize: 16; font.letterSpacing: 1.5
                                color: root.inkSoft
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                anchors { left: parent.left; right: parent.right }
                                visible: lyricsService.plainLyrics.length > 0
                                text: lyricsService.plainLyrics
                                font.family: root.ff; font.pixelSize: 14; font.letterSpacing: 1.5; lineHeight: 1.7
                                color: root.inkSoft
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap; clip: true; elide: Text.ElideRight
                                maximumLineCount: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
