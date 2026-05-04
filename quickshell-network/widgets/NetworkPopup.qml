import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking

pragma ComponentBehavior: Bound

Item {
    id: root

    property bool panelOpen: false
    property bool animRunning: false
    property real screenW: 1920
    property real screenH: 1080
    property string currentTab: "wifi"

    onCurrentTabChanged: {
        if (panelOpen && currentTab === "wifi" && root.wifiDevice)
            root.wifiDevice.scannerEnabled = true
    }

    readonly property int panelW: 360
    readonly property int panelH: 440
    readonly property int gridSize: 12

    // ── Dark mode ──
    readonly property bool darkMode: dm.text().trim() === "1"
    FileView { id: dm; path: Quickshell.env("HOME") + "/.config/quickshell/dark-mode.state"; onLoaded: {  } }
    Timer { interval: 200; running: true; repeat: false; onTriggered: dm.reload() }

    readonly property color paper:     root.darkMode ? "#1a1814" : "#d6cfb5"
    readonly property color ink:       root.darkMode ? "#8a7530" : "#463f2e"
    readonly property color inkStrong: root.darkMode ? "#8a7530" : "#2e2a1f"
    readonly property color inkSoft:   root.darkMode ? "#7a7030" : "#7a7358"
    readonly property color lineVsoft: root.darkMode ? Qt.rgba(200/255,168/255,96/255,0.10) : Qt.rgba(70/255,63/255,46/255,0.10)
    readonly property color lineSoft:  root.darkMode ? Qt.rgba(200/255,168/255,96/255,0.30) : Qt.rgba(70/255,63/255,46/255,0.23)
    readonly property color accent:    root.darkMode ? "#a04040" : "#6e2a2a"
    readonly property color green:     "#8a6a30"

    FontLoader { id: mainFont; source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Ndot57-Regular.otf" }
    FontLoader { id: jpFont; source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Ndot77JPExtended.otf" }
    readonly property string ff:   mainFont.name
    readonly property string ffjp: jpFont.name

    // ── WiFi (native Quickshell.Networking, 0 fork) ──
    readonly property var wifiDevice: {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        }
        return null
    }

    readonly property bool wifiPower: Networking.wifiEnabled

    // state: 2 = Connected (iwd backend tidak set .connected)
    readonly property var wifiConnected: {
        if (!root.wifiDevice) return null
        var nets = root.wifiDevice.networks.values
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].state === 2) return nets[i]
        }
        return null
    }

    readonly property bool wifiConnecting: {
        if (!root.wifiDevice) return false
        var nets = root.wifiDevice.networks.values
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].stateChanging && nets[i].name === root.targetSsid) return true
        }
        return false
    }

    readonly property bool wifiLoading: !root.wifiDevice && !Networking.wifiHardwareEnabled && !root.wifiInitDone
    property bool wifiInitDone: false

    Timer {
        id: wifiInitTimer
        interval: 4000; running: true; repeat: false
        onTriggered: { root.wifiInitDone = true }
    }

    function tryConnect(ssid) {
        root.targetSsid = ssid
        root.showPassword = false
        root.wifiError = ""
        root.connFailCount = 0
        root.connPasswordAttempt = false
        if (!root.wifiDevice) return
        var nets = root.wifiDevice.networks.values
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].name === ssid) { nets[i].connect(); return }
        }
    }

    function doConnectWithPassword(pw) {
        root.showPassword = false
        root.connPasswordAttempt = true
        if (!pw || !root.wifiDevice) { pwInput.text = ""; return }
        pwInput.text = ""
        root.wifiError = ""
        pwConnect.command = ["nmcli", "device", "wifi", "connect", root.targetSsid, "password", pw]
        pwConnect.running = true
    }

    Process {
        id: pwConnect
        command: []
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim()
                if (txt) {
                    root.wifiError = txt.substring(0, 120)
                    errorTimer.restart()
                    root.targetSsid = ""
                }
            }
        }
        onExited: function(code) {
            if (code !== 0 && !root.wifiError) {
                root.wifiError = "Connection failed"
                errorTimer.restart()
                root.targetSsid = ""
            }
        }
    }

    // Detect connect failure via state polling (signal unreliable with iwd)
    property int connFailCount: 0
    property bool connPasswordAttempt: false
    Timer {
        id: connFailDetect
        interval: 600; running: root.targetSsid !== "" && !root.showPassword && !root.connPasswordAttempt; repeat: true
        onTriggered: {
            if (!root.targetSsid || !root.wifiDevice) { root.connFailCount = 0; return }
            if (root.connPasswordAttempt) return
            var nets = root.wifiDevice.networks.values
            for (var i = 0; i < nets.length; i++) {
                if (nets[i].name !== root.targetSsid) continue
                if (nets[i].state === 2) { root.targetSsid = ""; root.connFailCount = 0; return }
                if (nets[i].stateChanging) { root.connFailCount = 0; return }
            }
            root.connFailCount++
            if (root.connFailCount >= 2) {
                root.showPassword = true
                root.connFailCount = 0
            }
        }
    }


    // ── Password input ──
    property bool   showPassword: false
    property string targetSsid: ""
    property string wifiError: ""

    Timer {
        id: errorTimer
        interval: 6000; running: false; repeat: false
        onTriggered: { root.wifiError = "" }
    }

    Timer {
        id: connWatchdog
        interval: 10000; running: root.targetSsid !== ""; repeat: false
        onTriggered: {
            root.targetSsid = ""
            root.showPassword = false
        }
    }

    // ── BT (native Bluetooth API, reactive) ──
    readonly property var btAdp: Bluetooth.defaultAdapter
    readonly property bool btPower: root.btAdp ? root.btAdp.enabled : false
    readonly property bool btDisabled: root.btAdp ? root.btAdp.state === BluetoothAdapterState.Disabled : true
    readonly property bool btBlocked: root.btAdp ? root.btAdp.state === BluetoothAdapterState.Blocked : false
    readonly property bool btDiscovering: root.btAdp ? root.btAdp.discovering : false

    readonly property int btConnectedCount: {
        if (!root.btAdp || !root.btAdp.devices) return 0
        var c = 0
        for (var i = 0; i < root.btAdp.devices.length; i++) {
            if (root.btAdp.devices[i] && root.btAdp.devices[i].connected) c++
        }
        return c
    }
    readonly property int btDeviceCount: {
        if (!root.btAdp || !root.btAdp.devices) return 0
        return root.btAdp.devices.length
    }

    // ── Panel container (top-right corner) ──
    Item {
        id: panelHost
        x: root.screenW - root.panelW - 12
        y: 50
        width: root.panelW
        height: root.panelH
        clip: true
        visible: root.panelOpen || root.animRunning
        opacity: root.panelOpen ? 1 : 0
        scale: root.panelOpen ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            color: root.paper
            border.color: root.ink
            border.width: 2
            Rectangle { x: -1; y: -1; width: 3; height: 3; color: root.ink }
            Rectangle { x: parent.width - 1; y: -1; width: 3; height: 3; color: root.ink }
            Rectangle { x: -1; y: parent.height - 1; width: 3; height: 3; color: root.ink }
            Rectangle { x: parent.width - 1; y: parent.height - 1; width: 3; height: 3; color: root.ink }

            Repeater {
                model: Math.floor(parent.width / 24) + 1
                Rectangle { required property int index; x: index * 24; y: 2; width: 4; height: 4; radius: 2; color: root.lineVsoft }
            }
            Repeater {
                model: Math.floor(parent.height / 24) + 1
                Rectangle { required property int index; x: 2; y: index * 24; width: 4; height: 4; radius: 2; color: root.lineVsoft }
            }

            Item {
                id: header
                width: parent.width
                height: 42
                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 18 }
                    Row {
                        spacing: 8; anchors.verticalCenter: parent.verticalCenter
                        Text { text: "◈"; font.family: root.ff; font.pixelSize: 11; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "NETWORK"; font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 3; font.weight: Font.Medium; color: root.inkStrong; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle { width: 16; height: 1; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "ネット"; font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 2; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Item { width: parent.width - 280; height: 1 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"; font.family: root.ff; font.pixelSize: 14; color: root.inkSoft
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            onClicked: root.closePanel()
                        }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.lineSoft }
            }

            Item {
                id: tabBar
                anchors { top: header.bottom; left: parent.left; right: parent.right }
                height: 34

                Row {
                    anchors.fill: parent

                    Rectangle {
                        width: parent.width / 2; height: parent.height
                        color: root.currentTab === "wifi" ? root.ink : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 2
                            color: root.currentTab === "wifi" ? root.accent : root.lineSoft
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "WiFi"
                            font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 2; font.weight: Font.Medium
                            color: root.currentTab === "wifi" ? root.paper : root.inkSoft
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.currentTab = "wifi" } }
                    }

                    Rectangle {
                        width: parent.width / 2; height: parent.height
                        color: root.currentTab === "bt" ? root.ink : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 2
                            color: root.currentTab === "bt" ? root.accent : root.lineSoft
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "BT"
                            font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 2; font.weight: Font.Medium
                            color: root.currentTab === "bt" ? root.paper : root.inkSoft
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.currentTab = "bt" } }
                    }
                }
            }

            Item {
                id: body
                anchors { top: tabBar.bottom; bottom: footer.top; left: parent.left; right: parent.right }

                // ────── WiFi Tab ──────
                Item {
                    anchors { fill: parent; margins: 12 }
                    opacity: root.currentTab === "wifi" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Text {
                        visible: root.wifiLoading
                        anchors.centerIn: parent
                        text: "Initializing..."
                        font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 2; color: root.inkSoft
                    }

                    Column {
                        id: wifiInfo
                        visible: root.wifiConnected && !root.wifiLoading
                        width: parent.width
                        spacing: 6

                        Rectangle {
                            width: parent.width; height: wifiInfoCol.implicitHeight + 16
                            color: Qt.rgba(70/255,63/255,46/255,0.08)
                            border.color: root.lineSoft; border.width: 1
                            Column {
                                id: wifiInfoCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                spacing: 4
                                Text {
                                    text: "Connected: " + (root.wifiConnected ? root.wifiConnected.name : "")
                                    font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 1; font.weight: Font.Medium
                                    color: root.inkStrong; elide: Text.ElideRight
                                    width: parent.width
                                }
                                Row {
                                    spacing: 16
                                    Text {
                                        text: root.wifiConnected
                                            ? getIcon(root.wifiConnected.signalStrength) + " " + Math.round(root.wifiConnected.signalStrength * 100) + "%"
                                            : ""
                                        font.family: root.ff; font.pixelSize: 12; color: root.inkSoft
                                    }
                                    Text {
                                        text: root.wifiConnected
                                            ? WifiSecurityType.toString(root.wifiConnected.security)
                                            : ""
                                        font.family: root.ff; font.pixelSize: 12; color: root.inkSoft
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width; height: 30
                            color: disconnectMA.containsMouse ? root.accent : "transparent"
                            border.color: root.lineSoft; border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                text: "Disconnect"
                                font.family: root.ff; font.pixelSize: 12; font.letterSpacing: 2
                                color: disconnectMA.containsMouse ? root.paper : root.inkSoft
                            }
                            MouseArea {
                                id: disconnectMA
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: { if (root.wifiConnected) root.wifiConnected.disconnect() }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: root.lineSoft }
                    }

                    Rectangle {
                        visible: root.wifiError !== ""
                        width: parent.width; height: 34
                        color: Qt.rgba(110/255,42/255,42/255,0.15)
                        border.color: root.accent; border.width: 1
                        Text {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            verticalAlignment: Text.AlignVCenter
                            text: root.wifiError
                            font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 1; color: root.accent
                            elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.wifiError = "" }
                    }

                    Item {
                        id: pwBox
                        visible: root.showPassword
                        width: parent.width; height: 80
                        Rectangle {
                            width: parent.width; height: parent.height
                            color: Qt.rgba(70/255,63/255,46/255,0.08)
                            border.color: root.accent; border.width: 1
                            Column {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 8 }
                                spacing: 6
                                Text {
                                    text: "Password for  " + root.targetSsid
                                    font.family: root.ff; font.pixelSize: 12; font.letterSpacing: 1; color: root.inkStrong
                                }
                                Row {
                                    spacing: 6
                                    Rectangle {
                                        width: 190; height: 28
                                        color: root.paper
                                        border.color: root.ink; border.width: 1
                                        TextInput {
                                            id: pwInput
                                            anchors { fill: parent; margins: 6 }
                                            font.family: root.ff; font.pixelSize: 13; color: root.inkStrong
                                            echoMode: TextInput.Password
                                            focus: root.showPassword
                                            onAccepted: { root.doConnectWithPassword(text); text = "" }
                                        }
                                    }
                                    Rectangle {
                                        width: 60; height: 28
                                        color: pwBtnMa.containsMouse ? root.ink : "transparent"
                                        border.color: root.ink; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "OK"
                                            font.family: root.ff; font.pixelSize: 11; font.letterSpacing: 1; font.weight: Font.Bold
                                            color: pwBtnMa.containsMouse ? root.paper : root.ink
                                        }
                                        MouseArea {
                                            id: pwBtnMa
                                            anchors.fill: parent; hoverEnabled: true
                                            onClicked: { root.doConnectWithPassword(pwInput.text); pwInput.text = "" }
                                        }
                                    }
                                    Rectangle {
                                        width: 28; height: 28
                                        color: pwCancelMA.containsMouse ? root.accent : "transparent"
                                        border.color: root.accent; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            font.family: root.ff; font.pixelSize: 14; color: pwCancelMA.containsMouse ? root.paper : root.accent
                                        }
                                        MouseArea {
                                            id: pwCancelMA
                                            anchors.fill: parent; hoverEnabled: true
                                            onClicked: { root.showPassword = false; root.targetSsid = ""; pwInput.text = "" }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        visible: !root.showPassword && !root.wifiLoading
                        anchors.top: root.wifiConnected && !root.wifiLoading ? wifiInfo.bottom : parent.top
                        anchors.topMargin: 6
                        Text {
                            text: root.wifiConnected
                                ? "Available Networks"
                                : (root.wifiPower ? "Networks" : "WiFi is OFF")
                            font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 2; color: root.inkSoft
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: Math.max(0, parent.width - 180); height: 1 }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 20
                            color: scanMA.containsMouse ? root.ink : "transparent"
                            border.color: root.lineSoft; border.width: 1
                            visible: root.wifiPower && root.wifiDevice
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "Scan"
                                font.family: root.ff; font.pixelSize: 9; font.letterSpacing: 1
                                color: scanMA.containsMouse ? root.paper : root.inkSoft
                            }
                            MouseArea {
                                id: scanMA
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (root.wifiDevice) { root.wifiDevice.scannerEnabled = false; root.wifiDevice.scannerEnabled = true }
                                }
                            }
                        }
                    }

                    ListView {
                        id: wifiList
                        visible: !root.showPassword && !root.wifiLoading
                        anchors {
                            top: root.showPassword ? pwBox.bottom
                                : (root.wifiConnected && !root.wifiLoading ? wifiInfo.bottom : parent.top)
                            topMargin: 26
                            bottom: parent.bottom; left: parent.left; right: parent.right
                        }
                        clip: true; spacing: 2
                        model: root.wifiDevice && !root.wifiLoading ? root.wifiDevice.networks : null

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool isConnected: modelData.state === 2
                            readonly property bool isConnecting: root.wifiConnecting && root.targetSsid === modelData.name
                            readonly property string secLabel: {
                                var s = WifiSecurityType.toString(modelData.security)
                                return s !== "None" ? s : ""
                            }
                            width: wifiList.width; height: 34
                            color: isConnecting ? Qt.rgba(90/255,122/255,90/255,0.12)
                                : (wfMA.containsMouse ? Qt.rgba(70/255,63/255,46/255,0.08) : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                x: 8; width: parent.width - 16; height: 1; color: root.lineVsoft
                                visible: index < wifiList.count - 1
                            }

                            Row {
                                anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                                spacing: 6
                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16; height: 16
                                    Text {
                                        anchors.centerIn: parent
                                        text: isConnecting ? "◈" : getIcon(modelData.signalStrength)
                                        font.family: root.ff; font.pixelSize: isConnecting ? 10 : 14
                                        color: isConnecting ? root.green : (isConnected ? root.green : root.ink)
                                        RotationAnimation on rotation {
                                            running: isConnecting; loops: Animation.Infinite
                                            from: 0; to: 360; duration: 1200
                                        }
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 16 - 6 - 60 - 4
                                    spacing: 1
                                    Text {
                                        text: modelData.name || ""
                                        font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 1; font.weight: Font.Medium
                                        color: root.inkStrong; elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: secLabel
                                        font.family: root.ff; font.pixelSize: 10; color: root.inkSoft
                                        visible: secLabel !== ""
                                    }
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 60; height: 24
                                    color: isConnected ? root.green
                                        : (isConnecting ? root.green : (wfMA.containsMouse ? root.ink : "transparent"))
                                    border.color: isConnected ? root.green : (isConnecting ? root.green : root.ink)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: isConnected ? "Connected" : (isConnecting ? "..." : "Connect")
                                        font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 1
                                        color: isConnected || isConnecting || wfMA.containsMouse ? root.paper : root.inkSoft
                                    }
                                }
                            }

                            MouseArea {
                                id: wfMA
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (isConnected) modelData.disconnect()
                                    else if (!root.wifiConnecting) root.tryConnect(modelData.name)
                                }
                            }

                            Connections {
                                target: modelData
                                function onConnectionFailed(reason) {
                                    if (modelData.name !== root.targetSsid) return
                                    if (reason === ConnectionFailReason.NoSecrets) root.showPassword = true
                                    else { root.wifiError = "Failed: " + ConnectionFailReason.toString(reason); errorTimer.restart(); root.targetSsid = "" }
                                }
                            }
                        }

                        Text {
                            visible: root.wifiDevice && root.wifiPower && root.wifiDevice.networks.values.length === 0 && !root.wifiLoading
                            anchors { top: parent.top; topMargin: 30; horizontalCenter: parent.horizontalCenter }
                            text: "No networks found"
                            font.family: root.ff; font.pixelSize: 12; color: root.inkSoft; opacity: 0.6
                        }
                    }
                }

                // ────── Bluetooth Tab ──────
                Item {
                    id: btTab
                    anchors { fill: parent; margins: 12 }
                    opacity: root.currentTab === "bt" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Column {
                        anchors { fill: parent }
                        spacing: 0

                        Rectangle {
                            visible: root.btBlocked
                            width: parent.width; height: 24
                            color: Qt.rgba(110/255,42/255,42/255,0.2)
                            border.color: root.accent
                            Text {
                                anchors.centerIn: parent
                                text: "BT blocked by rfkill.  Run: rfkill unblock bluetooth"
                                font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 1; color: root.accent
                            }
                        }

                        Rectangle { visible: root.btBlocked; width: parent.width; height: 4; color: "transparent" }

                        Row {
                            width: parent.width; spacing: 8; height: 34
                            Rectangle {
                                width: parent.width / 2 - 4; height: 32
                                color: root.btPower ? root.green : Qt.rgba(70/255,63/255,46/255,0.08)
                                border.color: root.lineSoft; border.width: 1
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Row {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { text: "BT"; font.family: root.ff; font.pixelSize: 12; font.letterSpacing: 2; font.weight: Font.Bold; color: root.btPower ? root.paper : root.inkSoft }
                                    Text {
                                        text: BluetoothAdapterState.toString(root.btAdp ? root.btAdp.state : BluetoothAdapterState.Disabled)
                                        font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 1
                                        color: root.btBlocked ? root.accent : (root.btPower ? root.paper : root.inkSoft)
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.btAdp && !root.btBlocked
                                    onClicked: { if (root.btAdp) root.btAdp.enabled = !root.btAdp.enabled }
                                }
                            }
                            Rectangle {
                                width: parent.width / 2 - 4; height: 32
                                color: root.btDiscovering ? root.accent : Qt.rgba(70/255,63/255,46/255,0.08)
                                border.color: root.lineSoft; border.width: 1
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Row {
                                    anchors.centerIn: parent; spacing: 6
                                    Text { text: "Scan"; font.family: root.ff; font.pixelSize: 12; font.letterSpacing: 2; font.weight: Font.Bold; color: root.btDiscovering ? root.paper : root.inkSoft }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 6; height: 6; radius: 3
                                        color: root.btDiscovering ? root.paper : "transparent"
                                        SequentialAnimation on opacity {
                                            running: root.btDiscovering; loops: Animation.Infinite
                                            NumberAnimation { from: 1; to: 0.2; duration: 500 }
                                            NumberAnimation { from: 0.2; to: 1; duration: 500 }
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; enabled: root.btAdp && root.btPower
                                    onClicked: { if (root.btAdp && root.btPower) root.btAdp.discovering = !root.btAdp.discovering }
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 6; color: "transparent" }

                        Text {
                            text: "Connected"
                            font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 2; color: root.inkSoft
                            height: 20
                            visible: root.btConnectedCount > 0
                        }

                        Repeater {
                            id: btConnRepeater
                            model: root.btAdp ? root.btAdp.devices : null
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                visible: modelData && modelData.connected
                                width: parent.width; height: visible ? 36 : 0
                                color: Qt.rgba(90/255,122/255,90/255,0.12)
                                border.color: root.lineSoft; border.width: 1
                                Row {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                                    spacing: 6
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "▪"; font.family: root.ff; font.pixelSize: 12; color: root.green }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 14 - 6 - 70
                                        spacing: 1
                                        Text {
                                            text: modelData ? (modelData.name || modelData.address) : ""
                                            font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 1; font.weight: Font.Medium
                                            color: root.inkStrong; elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        Text {
                                            text: modelData && modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                                            font.family: root.ff; font.pixelSize: 10; color: root.inkSoft
                                            visible: modelData && modelData.batteryAvailable
                                        }
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 70; height: 24
                                        color: dcMA.containsMouse ? root.accent : "transparent"
                                        border.color: root.accent; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Disconnect"
                                            font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 1
                                            color: dcMA.containsMouse ? root.paper : root.accent
                                        }
                                        MouseArea {
                                            id: dcMA
                                            anchors.fill: parent; hoverEnabled: true
                                            onClicked: { if (modelData) modelData.disconnect() }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Devices"
                            font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 2; color: root.inkSoft
                            height: 20
                        }

                        ListView {
                            id: btDevList
                            width: parent.width
                            height: Math.max(0, parent.height - y)
                            clip: true; spacing: 2
                            model: root.btAdp ? root.btAdp.devices : null
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                visible: modelData && !modelData.connected
                                width: btDevList.width; height: visible ? 34 : 0
                                color: btMA.containsMouse ? Qt.rgba(70/255,63/255,46/255,0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    x: 8; width: parent.width - 16; height: 1; color: root.lineVsoft
                                }
                                Row {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                                    spacing: 6
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "▸"; font.family: root.ff; font.pixelSize: 10; color: root.inkSoft }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData ? (modelData.name || modelData.address) : ""
                                        font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 1
                                        color: root.inkStrong; elide: Text.ElideRight
                                        width: parent.width - 10 - 6 - 70
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 70; height: 24
                                        color: btMA.containsMouse ? root.ink : "transparent"
                                        border.color: root.ink; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData ? (modelData.paired ? "Connect" : "Pair") : ""
                                            font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 1
                                            color: btMA.containsMouse ? root.paper : root.inkSoft
                                        }
                                    }
                                }
                                MouseArea {
                                    id: btMA
                                    anchors.fill: parent; hoverEnabled: true
                                    onClicked: {
                                        if (!modelData) return
                                        if (modelData.paired) modelData.connect()
                                        else modelData.pair()
                                    }
                                }
                            }
                            Text {
                                visible: root.btDeviceCount - root.btConnectedCount === 0
                                anchors { top: parent.top; topMargin: 20; horizontalCenter: parent.horizontalCenter }
                                text: root.btBlocked ? "Unblock rfkill first."
                                    : (root.btPower ? (root.btDiscovering ? "Scanning..." : "No available devices") : "BT is OFF")
                                font.family: root.ff; font.pixelSize: 12; color: root.inkSoft; opacity: 0.6
                            }
                        }
                    }
                }
            }

            Item {
                id: footer
                anchors.bottom: parent.bottom
                width: parent.width
                height: 34
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.lineSoft }
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "◇"; font.family: root.ff; font.pixelSize: 10; color: root.inkSoft; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: root.currentTab === "wifi" ? "WiFi · Native API" : "BT · BlueZ reactive"
                        font.family: root.ff; font.pixelSize: 10; font.letterSpacing: 1.5; color: root.inkSoft; opacity: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Timer { id: hideDone; interval: 180; onTriggered: { panelHost.visible = false; root.animRunning = false } }
    }

    function getIcon(strength) {
        var s = typeof strength === 'number' ? strength : 0
        if (s >= 0.8) return "󰤨"
        if (s >= 0.6) return "󰤥"
        if (s >= 0.4) return "󰤢"
        if (s >= 0.2) return "󰤟"
        return "󰤯"
    }

    function openPanel(tab) {
        if (tab) root.currentTab = tab
        if (panelOpen) return
        panelOpen = true; animRunning = true
        panelHost.visible = true
        panelHost.x = root.screenW - root.panelW - 12
        if (root.currentTab === "wifi" && root.wifiDevice) root.wifiDevice.scannerEnabled = true
    }

    function closePanel() {
        if (!panelOpen) return
        panelOpen = false; animRunning = true
        hideDone.restart()
    }

    function togglePanel(tab) {
        if (panelOpen && (!tab || tab === root.currentTab)) closePanel()
        else openPanel(tab)
    }
}
