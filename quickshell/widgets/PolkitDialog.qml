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

    readonly property var flow: polkitAgent.flow
    readonly property var identities: root.flow ? root.flow.identities : []
    readonly property int identityCount: root.identities ? root.identities.length : 0
    property string response: ""
    property bool authFailed: false

    function clearSensitive() {
        root.response = ""
        pwInput.text = ""
    }

    function focusInput() {
        if (root.flow && root.flow.isResponseRequired)
            Qt.callLater(function() { pwInput.forceActiveFocus() })
    }

    function resetFlowState() {
        root.clearSensitive()
        root.authFailed = false
        root.focusInput()
    }

    function submitResponse() {
        if (!root.flow || !root.flow.isResponseRequired) return
        var value = root.response
        root.clearSensitive()
        root.authFailed = false
        root.flow.submit(value)
    }

    function cancelRequest() {
        if (!root.flow) return
        root.clearSensitive()
        root.authFailed = false
        root.flow.cancelAuthenticationRequest()
    }

    function selectNextIdentity() {
        if (!root.flow || root.identityCount < 2) return
        var current = -1
        for (var i = 0; i < root.identityCount; i++) {
            if (root.identities[i] === root.flow.selectedIdentity) {
                current = i
                break
            }
        }
        var next = current < 0 ? 0 : (current + 1) % root.identityCount
        root.clearSensitive()
        root.authFailed = false
        root.flow.selectedIdentity = root.identities[next]
    }

    Rectangle {
        anchors.fill: parent
        color: "#0b0a09"
        opacity: 0.95
    }

    Item {
        id: panel
        width: 380
        height: content.implicitHeight + 56
        anchors.centerIn: parent

        Rectangle {
            anchors.fill: parent
            color: root.paper
            border.color: root.ink
            border.width: 1
        }

        // Grid

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
            spacing: 12

            Text {
                text: "▸ AUTHENTICATION"
                font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 3
                color: root.accent
            }

            Text {
                text: root.flow ? (root.flow.message || "Authentication required") : ""
                font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 1
                color: root.inkStrong
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Rectangle {
                width: parent.width
                height: root.identityCount > 1 ? 32 : 0
                visible: root.identityCount > 1
                color: identityMouse.containsMouse ? root.lineVsoft : "transparent"
                border.color: root.inkSoft
                border.width: 1

                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: {
                        var identity = root.flow ? root.flow.selectedIdentity : null
                        if (!identity) return ""
                        return (identity.isGroup ? "GROUP · " : "USER · ") + identity.displayName
                    }
                    font.family: root.ff
                    font.pixelSize: 11
                    font.letterSpacing: 1
                    color: root.inkStrong
                }

                Text {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "CHANGE"
                    font.family: root.ff
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    color: root.accent
                }

                MouseArea {
                    id: identityMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.selectNextIdentity()
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.lineVsoft }

            Item {
                width: parent.width
                height: root.flow && root.flow.isResponseRequired ? 36 : 0
                visible: height > 0
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: inputScope.activeFocus ? root.ink : root.inkSoft
                    border.width: 1
                }
                FocusScope {
                    id: inputScope
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    focus: polkitAgent.isActive && root.flow && root.flow.isResponseRequired

                    TextInput {
                        id: pwInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 2
                        color: root.inkStrong
                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "·"
                        focus: true
                        onTextEdited: { root.response = text; root.authFailed = false }
                        onAccepted: root.submitResponse()
                        Keys.onEscapePressed: root.cancelRequest()
                        Text {
                            visible: parent.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.flow ? (root.flow.inputPrompt || "Response") : ""
                            font.family: root.ff; font.pixelSize: 13; font.italic: true
                            color: root.inkSoft; opacity: 0.5
                        }
                    }
                }
            }

            Text {
                visible: root.flow && root.flow.supplementaryMessage !== ""
                text: root.flow ? root.flow.supplementaryMessage : ""
                font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 2
                color: root.flow && root.flow.supplementaryIsError ? root.accent : root.inkSoft
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Text {
                visible: root.authFailed && (!root.flow || root.flow.supplementaryMessage === "")
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
                        onClicked: root.cancelRequest()
                    }
                }

                Rectangle {
                    width: 130; height: 34
                    color: btnOk.containsMouse || btnOk.pressed ? root.accent : "transparent"
                    border.color: root.accent; border.width: 1
                    opacity: root.flow && root.flow.isResponseRequired ? 1 : 0.45

                    Text {
                        anchors.centerIn: parent
                        text: "AUTHENTICATE"
                        font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 2; font.weight: Font.Bold
                        color: btnOk.containsMouse || btnOk.pressed ? root.paper : root.accent
                    }
                    MouseArea {
                        id: btnOk
                        anchors.fill: parent; hoverEnabled: true
                        enabled: root.flow && root.flow.isResponseRequired
                        onClicked: root.submitResponse()
                    }
                }
            }
        }
    }

    Connections {
        target: polkitAgent
        function onFlowChanged() { root.resetFlowState() }
        function onIsActiveChanged() {
            if (polkitAgent.isActive) root.resetFlowState()
            else root.clearSensitive()
        }
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            root.clearSensitive()
            root.authFailed = true
            root.focusInput()
        }
        function onAuthenticationSucceeded() { root.clearSensitive() }
        function onAuthenticationRequestCancelled() { root.clearSensitive() }
        function onIsResponseRequiredChanged() {
            root.clearSensitive()
            root.focusInput()
        }
        function onSelectedIdentityChanged() { root.resetFlowState() }
    }
}
