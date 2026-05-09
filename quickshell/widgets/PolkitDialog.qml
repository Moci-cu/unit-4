import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import "../theme"

pragma ComponentBehavior: Bound

Item {
    id: root

    readonly property color paper:     Theme.paper
    readonly property color ink:       Theme.ink
    readonly property color inkStrong: Theme.inkStrong
    readonly property color inkSoft:   Theme.inkSoft
    readonly property color accent:    Theme.accent
    readonly property color lineVsoft: Theme.lineVsoft

    FontLoader { id: mainFont; source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Ndot57-Regular.otf" }
    readonly property string ff: mainFont.name

    property string password: ""
    property bool authFailed: false

    Rectangle {
        anchors.fill: parent
        color: "#0b0a09"
        opacity: 0.95
    }

    Item {
        id: panel
        width: 340; height: 240
        anchors.centerIn: parent

        Rectangle {
            anchors.fill: parent
            color: root.paper
            border.color: root.ink
            border.width: 1
        }

        // Grid
        Repeater {
            model: Math.floor(panel.width / 20) + 1
            Rectangle { required property int index; x: index * 20; y: 0; width: 1; height: panel.height; color: root.lineVsoft }
        }
        Repeater {
            model: Math.floor(panel.height / 20) + 1
            Rectangle { required property int index; x: 0; y: index * 20; width: panel.width; height: 1; color: root.lineVsoft }
        }

        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
            spacing: 16

            Text {
                text: "▸ AUTHENTICATION"
                font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 3
                color: root.accent
            }

            Text {
                text: polkitAgent.flow ? (polkitAgent.flow.message || "Authentication required") : ""
                font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 1
                color: root.inkStrong
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Rectangle { width: parent.width; height: 1; color: root.lineVsoft }

            Item {
                width: parent.width; height: 36
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: inputScope.activeFocus ? root.ink : root.inkSoft
                    border.width: 1
                }
                FocusScope {
                    id: inputScope
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    focus: polkitAgent.isActive

                    TextInput {
                        id: pwInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 2
                        color: root.inkStrong
                        echoMode: TextInput.Password; passwordCharacter: "·"
                        focus: true
                        text: root.password
                        onTextEdited: { root.password = text; root.authFailed = false }
                        onAccepted: {
                            if (root.password) {
                                polkitAgent.flow.submit(root.password)
                                root.password = ""
                            }
                        }
                        Text {
                            visible: parent.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: polkitAgent.flow ? (polkitAgent.flow.inputPrompt || "Password") : ""
                            font.family: root.ff; font.pixelSize: 13; font.italic: true
                            color: root.inkSoft; opacity: 0.5
                        }
                    }
                }
            }

            Text {
                visible: root.authFailed
                text: "AUTHENTICATION FAILED"
                font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 2
                color: root.accent
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: 100; height: 34
                    color: btnCancel.containsMouse ? root.ink : "transparent"
                    border.color: root.ink; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "CANCEL"
                        font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 2
                        color: btnCancel.containsMouse ? root.paper : root.ink
                    }
                    MouseArea {
                        id: btnCancel
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            polkitAgent.flow.cancelAuthenticationRequest()
                            root.password = ""
                            root.authFailed = false
                        }
                    }
                }

                Rectangle {
                    width: 130; height: 34
                    color: btnOk.containsMouse || btnOk.pressed ? root.accent : "transparent"
                    border.color: root.accent; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "AUTHENTICATE"
                        font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 2; font.weight: Font.Bold
                        color: btnOk.containsMouse || btnOk.pressed ? root.paper : root.accent
                    }
                    MouseArea {
                        id: btnOk
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (root.password) {
                                polkitAgent.flow.submit(root.password)
                                root.password = ""
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: polkitAgent.flow
        function onAuthenticationFailed() {
            root.authFailed = true
        }
    }
}
