import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

pragma ComponentBehavior: Bound

ShellRoot {
    id: root

    readonly property color paper:     "#d6cfb5"
    readonly property color ink:       "#463f2e"
    readonly property color inkStrong: "#2e2a1f"
    readonly property color inkSoft:   "#7a7358"
    readonly property color lineVsoft: Qt.rgba(70/255,63/255,46/255,0.12)
    readonly property color lineSoft:  Qt.rgba(70/255,63/255,46/255,0.25)
    readonly property color accent:    "#6e2a2a"
    readonly property color inactiveBg: Qt.rgba(70/255,63/255,46/255,0.22)

    readonly property int barHeight: 40
    readonly property int gridSize:  12

    readonly property var wsLabels: [
        "いち","に","さん","し","ご",
        "ろく","しち","はち","きゅう","じゅう"
    ]

    // Event-driven app detection: map wsId -> bool
    readonly property var wsHasApp: {
        var map = {}
        var vals = Hyprland.toplevels.values
        for (var i = 0; i < vals.length; i++) {
            var t = vals[i]
            if (t && t.workspace) map[t.workspace.id] = true
        }
        return map
    }

    // ── Bar window ──
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

            Rectangle {
                id: barBg
                anchors.fill: parent
                color: root.paper
                border.color: root.ink
                border.width: 1

                // Grid overlay (12px cell, 2D — launcher style)
                Repeater {
                    model: Math.floor(barBg.width / root.gridSize) + 1
                    Rectangle {
                        required property int index
                        x: index * root.gridSize
                        y: 0
                        width: 1
                        height: barBg.height
                        color: root.lineVsoft
                    }
                }
                Repeater {
                    model: Math.floor(barBg.height / root.gridSize) + 1
                    Rectangle {
                        required property int index
                        x: 0
                        y: index * root.gridSize
                        width: barBg.width
                        height: 1
                        color: root.lineVsoft
                    }
                }

                // Workspaces row
                Row {
                    id: wsRow
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 4
                        bottomMargin: 4
                    }
                    spacing: 25

                    Repeater {
                        model: 10
                        Rectangle {
                            required property int index
                            readonly property int wsId: index + 1
                            readonly property bool isActive: Hyprland.focusedWorkspace
                                ? Hyprland.focusedWorkspace.id === wsId
                                : false

                            width: (wsRow.width - 9 * wsRow.spacing) / 10
                            height: wsRow.height - 2
                            color: isActive ? root.ink : root.inactiveBg

                            // Bottom border: thick if workspace has apps
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: root.wsHasApp[wsId] === true ? 3 : 0
                                color: root.ink
                                visible: height > 0
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "■"
                                    font.family: "Ndot 57"
                                    font.pixelSize: 12
                                    color: parent.parent.isActive ? root.paper : root.ink
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.wsLabels[index]
                                    font.family: "Ndot77JPExtended"
                                    font.pixelSize: 18
                                    font.letterSpacing: 1.5
                                    font.weight: Font.Bold
                                    color: parent.parent.isActive ? root.paper : root.inkSoft
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + wsId)
                            }
                        }
                    }
                }
            }
        }
    }
}
