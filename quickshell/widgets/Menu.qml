import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

pragma ComponentBehavior: Bound

Item {
    id: root

    readonly property int lw: 780
    readonly property int lh: 540
    property real screenW: 1920
    property real screenH: 1080

    property bool   menuOpen:        false
    property bool   animRunning:     false
    property string currentCat: "all"
    property string searchQuery: ""
    property int    focusIdx:   0
    property string clockStr:   "--:--:--"

    readonly property color paper:     Theme.paper
    readonly property color ink:       Theme.ink
    readonly property color inkStrong: Theme.inkStrong
    readonly property color inkSoft:   Theme.inkSoft
    readonly property color lineSoft:  Theme.lineSoft
    readonly property color lineVsoft: Theme.lineVsoft
    readonly property color accent:    Theme.accent

    FontLoader { id: mainFont; source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Ndot57-Regular.otf" }
    readonly property string ff: mainFont.name

    property var  apps: []
    property bool appsLoaded: false
    property bool nightMode: false
    property int  nightTemp: 4000

    // ── TLP current profile ──
    // ── TLP current profile ──
    property string tlpProfile: ""

    // ── Coffee mode (keep screen awake) ──
    property bool coffeeMode: false
    property string coffeeStateFile: Quickshell.env("HOME") + "/.config/quickshell/coffee-mode.state"

    Process {
        id: coffeeRead
        command: ["cat", root.coffeeStateFile]
        running: false
        stdout: SplitParser {
            onRead: data => { if (data.trim() === "1") root.coffeeMode = true }
        }
    }
    Process {
        id: coffeeWrite
        property string state: "0"
        command: ["sh", "-c", "echo " + state + " > " + root.coffeeStateFile]
        running: false
    }

    function toggleCoffeeMode() {
        root.coffeeMode = !root.coffeeMode
        coffeeWrite.state = root.coffeeMode ? "1" : "0"
        coffeeWrite.running = true
    }
    Process {
        id: tlpGetProc
        command: ["tlpctl", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { root.tlpProfile = this.text.trim() || "" }
        }
    }

    // ── Special system actions (not real apps) ──
    readonly property var specialItems: [
        { id: "S01", name: "Lock Screen",      cmd: "__lock__",      desktopId: "__lock__",      meta: "quickshell", keywords: "lock screen lockscreen",            icon: "⬡", cat: "sys" },
        { id: "S02", name: "Logout",           cmd: "__logout__",    desktopId: "__logout__",    meta: "hyprland",   keywords: "logout exit hyprland session",      icon: "✕", cat: "sys" },
        { id: "S03", name: "Sleep",            cmd: "__sleep__",     desktopId: "__sleep__",     meta: "systemctl",  keywords: "sleep suspend standby",             icon: "◈", cat: "sys" },
        { id: "S04", name: "Reboot",           cmd: "__reboot__",    desktopId: "__reboot__",    meta: "systemctl",  keywords: "reboot restart",                    icon: "↻", cat: "sys" },
        { id: "S05", name: "Shut Down",        cmd: "__shutdown__",  desktopId: "__shutdown__",  meta: "systemctl",  keywords: "shutdown poweroff halt power off",  icon: "⏻", cat: "sys" },
        { id: "S06", name: "Kill All Apps", cmd: "__killactive__",desktopId: "__killactive__", meta: "hyprland",   keywords: "kill close terminate workspace apps",icon: "✕", cat: "sys" },
        { id: "S07", name: "Power: Performance", cmd: "tlpctl performance", desktopId: "tlpctl performance", meta: "tlpctl", keywords: "power performance profile tlpctl", icon: "⬡", cat: "sys" },
        { id: "S08", name: "Power: Balanced",    cmd: "tlpctl balanced",    desktopId: "tlpctl balanced",    meta: "tlpctl", keywords: "power balanced profile tlpctl",    icon: "⬡", cat: "sys" },
        { id: "S09", name: "Power: Power-saver", cmd: "tlpctl power-saver", desktopId: "tlpctl power-saver", meta: "tlpctl", keywords: "power saver profile tlpctl",   icon: "⬡", cat: "sys" }
    ]

    readonly property var catLabels: ({
        "all":"ALL","dev":"DEVELOP","sys":"SYSTEM","net":"NETWORK",
        "media":"MEDIA","office":"OFFICE","graphics":"GRAPHICS",
        "games":"GAMES","other":"OTHER"
    })

    readonly property var catOrder: ["all","dev","sys","net","media","office","graphics","games","other"]

    readonly property var catKeys: {
        var present = {"all": true}
        for (var i = 0; i < apps.length; i++) present[apps[i].cat] = true
        for (var j = 0; j < specialItems.length; j++) present[specialItems[j].cat] = true
        return catOrder.filter(function(k) { return present[k] })
    }

    function _allItems() {
        var merged = apps.slice()
        merged.push.apply(merged, specialItems)
        return merged
    }

    readonly property var filteredApps: {
        var q = searchQuery.toLowerCase().trim()
        return _allItems().filter(function(a) {
            var catOk = currentCat === "all" || a.cat === currentCat
            if (!q) return catOk
            var nameOk = a.name.toLowerCase().indexOf(q) >= 0
            var metaOk = (a.meta || "").toLowerCase().indexOf(q) >= 0
            var kwOk   = (a.keywords || "").toLowerCase().indexOf(q) >= 0
            return catOk && (nameOk || metaOk || kwOk)
        })
    }

    Process {
        id: desktopReader
        command: ["bash", Qt.resolvedUrl("../list-apps.sh").toString().replace("file://","")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                var result = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    var parts = line.split("|")
                    if (parts.length < 2) continue
                    var name      = parts[0].trim()
                    var desktopId = parts[1].trim()
                    var cats      = parts[2] || ""
                    var rawExec   = (parts[3] || "").replace(/%[A-Za-z]/g,"").trim()
                    if (!name || !desktopId) continue
                    var launchCmd = rawExec || desktopId

                    var cat = "other"
                    if (/Development|IDE|TextEditor|Debugger/i.test(cats))          cat = "dev"
                    else if (/WebBrowser|Email|Chat|Network|FileTransfer/i.test(cats)) cat = "net"
                    else if (/Audio|Video|Player|Music/i.test(cats))                cat = "media"
                    else if (/Office|Spreadsheet|WordProcessor|Presentation/i.test(cats)) cat = "office"
                    else if (/Graphics|Photography|2DGraphics/i.test(cats))         cat = "graphics"
                    else if (/Game|Emulator/i.test(cats))                           cat = "games"
                    else if (/System|Utility|Monitor|Settings/i.test(cats))         cat = "sys"

                    var nl = name.toLowerCase()
                    var ico = "·"
                    if (/terminal|kitty|alacritty|console/.test(nl)) ico = "▸"
                    else if (/firefox|chromium|browser/.test(nl))     ico = "○"
                    else if (/nvim|vim|editor|code|helix/.test(nl))   ico = "⌥"
                    else if (/file|yazi|ranger/.test(nl))             ico = "▤"
                    else if (/btop|htop|monitor/.test(nl))            ico = "▲"
                    else if (/music|audio|pulse/.test(nl))            ico = "♪"
                    else if (/video|mpv|vlc/.test(nl))                ico = "▶"
                    else if (/lock|hyprlock/.test(nl))                ico = "⬡"
                    else if (/libre|office|calc|writer/.test(nl))     ico = "≡"
                    else if (/gimp|inkscape|image/.test(nl))          ico = "⬜"
                    else if (cat === "dev")      ico = "⌥"
                    else if (cat === "net")      ico = "○"
                    else if (cat === "media")    ico = "▶"
                    else if (cat === "sys")      ico = "◈"
                    else if (cat === "office")   ico = "≡"

                    result.push({
                        id:        String(i+1).padStart(2,"0"),
                        name:      name,
                        cat:       cat,
                        meta:      desktopId,
                        desktopId: launchCmd,
                        cmd:       launchCmd,
                        icon:      ico
                    })
                }
                root.apps = result
                root.appsLoaded = true
            }
        }
    }

    function launchApp(cmd) {
        if (!cmd) return
        if (cmd === "__lock__") {
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/lock.sh"])
        } else if (cmd === "__logout__") {
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
        } else if (cmd === "__sleep__") {
            Quickshell.execDetached(["systemctl", "suspend"])
        } else if (cmd === "__reboot__") {
            Quickshell.execDetached(["systemctl", "reboot"])
        } else if (cmd === "__shutdown__") {
            Quickshell.execDetached(["systemctl", "poweroff"])
        } else if (cmd === "__killactive__") {
            root.killActiveApps()
        } else {
            var parts = cmd.trim().split(/\s+/)
            if (parts.length === 0 || parts[0] === "") return
            Quickshell.execDetached(parts)
        }
        root.closeMenu()
    }

    function launch(cmd) {
        if (!cmd || cmd === "") return
        Quickshell.execDetached(cmd.trim().split(/\s+/))
        root.closeMenu()
    }

    function killActiveApps() {
        var vals = Hyprland.toplevels.values
        var qs = "quickshell"
        var cmds = []
        for (var i = 0; i < vals.length; i++) {
            var t = vals[i]
            if (!t) continue
            var tc = t.clazz
            if (tc && tc.toLowerCase().indexOf(qs) >= 0) continue
            var addr = t.address
            if (addr) {
                var a = String(addr)
                if (a.indexOf("0x") !== 0) a = "0x" + a
                cmds.push("dispatch killwindow address:" + a)
            }
        }
        root.closeMenu()
        if (cmds.length > 0)
            Quickshell.execDetached(["hyprctl", "--batch", cmds.join("; ")])
    }

    property string nightStateFile: Quickshell.env("HOME") + "/.config/quickshell/night-mode.state"

    Process {
        id: nightOn
        command: ["sh", "-c", "pidof hyprsunset || nohup hyprsunset >/dev/null 2>&1 & sleep 0.5; hyprctl hyprsunset temperature " + root.nightTemp]
        running: false
        stdout: SplitParser { onRead: data => { console.log("night on:", data) } }
    }

    Process {
        id: nightOff
        command: ["hyprctl", "hyprsunset", "identity"]
        running: false
    }

    Process {
        id: nightStateWrite
        property string state: "0"
        command: ["sh", "-c", "echo " + state + " > " + root.nightStateFile]
        running: false
    }

    Process {
        id: nightStateRead
        command: ["cat", root.nightStateFile]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "1") {
                    root.nightMode = true
                    nightOn.running = true
                }
            }
        }
    }

    function toggleNightMode() {
        root.nightMode = !root.nightMode
        if (root.nightMode) {
            nightOn.running = true
            nightStateWrite.state = "1"
        } else {
            nightOff.running = true
            nightStateWrite.state = "0"
        }
        nightStateWrite.running = true
    }

    function toggleDarkMode() {
        var f = Quickshell.env("HOME") + "/.config/quickshell/dark-mode.state"
        Quickshell.execDetached(["sh", "-c",
            'val=$(cat ' + f + ' 2>/dev/null); [ "$val" = "1" ] && echo 0 > ' + f + ' || echo 1 > ' + f +
            '; systemctl --user restart quickshell-bar quickshell-network quickshell'])
        root.closeMenu()
    }

    Timer {
        interval: 1000; running: root.menuOpen; repeat: true
        onTriggered: {
            var d = new Date()
            root.clockStr = String(d.getHours()).padStart(2,"0") + ":"
                + String(d.getMinutes()).padStart(2,"0") + ":"
                + String(d.getSeconds()).padStart(2,"0")
        }
    }

    Timer {
        id: focusTimer; interval: 50; repeat: true; running: false
        property int attempts: 0
        onTriggered: {
            searchInput.forceActiveFocus()
            attempts++
            if (attempts >= 8) { running = false; attempts = 0 }
        }
    }

    Component.onCompleted: {
        var d = new Date()
        clockStr = String(d.getHours()).padStart(2,"0") + ":"
            + String(d.getMinutes()).padStart(2,"0") + ":"
            + String(d.getSeconds()).padStart(2,"0")
        desktopReader.running = true
        nightStateRead.running = true
        coffeeRead.running = true
    }

    Item {
        id: panelHost
        x: (root.screenW - root.lw) / 2
        y: (root.screenH - root.lh) / 2
        width:  root.lw
        height: root.lh
        clip:   true
        visible: root.menuOpen || root.animRunning
        opacity: 0
        scale: 0.96
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            id:     panelContent
            anchors.fill: parent
             color:  root.paper
             border.color: root.ink; border.width: 1

            // GLSL glitch — GPU driven via Behavior on time
            // Glitch — NieR palette (Timer-based, chroma overlays)
            Rectangle { id: chromaR; anchors.fill: parent; color: root.accent; opacity: 0; z: 100 }
            Rectangle { id: chromaC; x: 4; y: 2; width: parent.width; height: parent.height; color: root.ink; opacity: 0; z: 100 }
            Rectangle { id: chromaB; y: 0; width: parent.width; height: 4; color: root.paper; opacity: 0; z: 101 }

            Timer {
                id: glitchTimer
                interval: 40; running: false; repeat: true
                property int step: 0
                property real ox: 0
                onTriggered: {
                    step++
                    if (step === 1) { chromaR.opacity = 0.35; chromaC.opacity = 0.25; panelHost.x = ox + 8
                    } else if (step === 2) { panelHost.x = ox - 10; chromaR.opacity = 0.15; chromaC.opacity = 0.35
                    } else if (step === 3) { panelHost.x = ox + 4; chromaR.opacity = 0; chromaC.opacity = 0; chromaB.opacity = 0.6; chromaB.y = root.lh * 0.3
                    } else if (step === 4) { chromaB.opacity = 0; chromaR.opacity = 0.4; chromaC.opacity = 0
                    } else if (step === 5) { chromaR.opacity = 0; panelHost.x = ox
                    } else { panelHost.x = ox; chromaR.opacity = 0; chromaC.opacity = 0; chromaB.opacity = 0; step = 0; glitchTimer.stop() }
                }
            }

            Repeater {
                model: Math.floor(root.lw/20)+1
                Rectangle { required property int index; x:index*20; y:0; width:1; height:root.lh; color:root.lineVsoft }
            }
            Repeater {
                model: Math.floor(root.lh/20)+1
                Rectangle { required property int index; x:0; y:index*20; width:root.lw; height:1; color:root.lineVsoft }
            }

            MouseArea {
                anchors.fill: parent; z: -1
                onClicked: searchInput.forceActiveFocus()
                propagateComposedEvents: true
            }

            Rectangle {
                id: scanLine; x:0; width:root.lw; height:2; z:20; opacity:0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position:0.0; color:"transparent" }
                    GradientStop { position:0.5; color:root.accent }
                    GradientStop { position:1.0; color:"transparent" }
                }
                NumberAnimation on y {
                    id: scanAnim; from:0; to:root.lh; duration:700; running:false
                    easing.type: Easing.Linear
                    onStarted:  scanLine.opacity = 1
                    onFinished: scanLine.opacity = 0
                }
            }

            Item {
                id: header; width:parent.width; height:52

                Row {
                    anchors { left:parent.left; right:parent.right; verticalCenter:parent.verticalCenter
                              leftMargin:28; rightMargin:28 }
                    Row {
                        spacing:14; anchors.verticalCenter:parent.verticalCenter
                        Text { text:"SYSTEM"; font.family:root.ff; font.pixelSize:15; font.letterSpacing:3.5; font.weight:Font.Medium; color:root.inkStrong }
                        Rectangle { width:24; height:1; color:root.inkSoft; anchors.verticalCenter:parent.verticalCenter }
                        Text { text:"システム"; font.family:root.ff; font.pixelSize:14; font.letterSpacing:2; color:root.inkSoft }
                    }
                    Item { width:parent.width - 340; height:1 }
                    Row {
                        spacing:14; anchors.verticalCenter:parent.verticalCenter
                        Item {
                            width:120; height:16; clip:true
                            Text {
                                id:lhTick
                                text: root.clockStr + " · " + root.apps.length + " APPS · "
                                font.family:root.ff; font.pixelSize:13; font.letterSpacing:1.5; color:root.inkSoft; y:2
                                NumberAnimation on x {
                                    from:120; to:-lhTick.implicitWidth
                                    duration:12000; loops:Animation.Infinite; running:root.menuOpen
                                }
                            }
                        }
                        Text { text:"SESSION 0471"; font.family:root.ff; font.pixelSize:13; font.letterSpacing:2.5; color:root.inkSoft }
                    }
                }
                Rectangle { anchors.bottom:parent.bottom; width:parent.width; height:1; color:root.lineSoft }
            }

            Rectangle { anchors.top: header.bottom; width: parent.width; height: 1; color: root.lineSoft }

            Item {
                id: body
                anchors { top:header.bottom; bottom:footer.top }
                width: parent.width

                Item {
                    id:sidebar; width:160; height:parent.height
                    Rectangle { anchors.right:parent.right; width:1; height:parent.height; color:root.lineSoft }
                    Column {
                        anchors { top:parent.top; topMargin:16 }
                        width:parent.width

                        Repeater {
                            model: root.catKeys
                            delegate: Item {
                                required property string modelData
                                width:160; height:34
                                property bool isActive: root.currentCat === modelData

                                Rectangle {
                                    anchors.fill:parent
                                    color: parent.isActive ? root.ink : (catMA.containsMouse ? Qt.rgba(70/255,63/255,46/255,0.07) : "transparent")
                                    Behavior on color { ColorAnimation { duration:150 } }
                                }
                                Row {
                                    anchors { left:parent.left; leftMargin:22; verticalCenter:parent.verticalCenter }
                                    spacing:8
                                    Rectangle {
                                        anchors.verticalCenter:parent.verticalCenter
                                        width: catMA.containsMouse || parent.parent.isActive ? 10 : 4; height:1
                                        color: parent.parent.isActive ? root.paper : root.inkSoft
                                        Behavior on width { NumberAnimation { duration:200; easing.type:Easing.OutQuart } }
                                        Behavior on color { ColorAnimation { duration:150 } }
                                    }
                                    Text {
                                        anchors.verticalCenter:parent.verticalCenter
                                        text: root.catLabels[modelData] || modelData.toUpperCase()
                                        font.family:root.ff; font.pixelSize:14; font.letterSpacing:2
                                        color: parent.parent.isActive ? root.paper : (catMA.containsMouse ? root.inkStrong : root.inkSoft)
                                        Behavior on color { ColorAnimation { duration:150 } }
                                    }
                                }
                                Text {
                                    anchors { right:parent.right; rightMargin:12; verticalCenter:parent.verticalCenter }
                                    text: root._allItems().filter(function(a){ return modelData==="all"||a.cat===modelData }).length.toString().padStart(2,"0")
                                    font.family:root.ff; font.pixelSize:13; font.letterSpacing:1
                                    color: parent.isActive ? Qt.rgba(214/255,207/255,181/255,0.6) : Qt.rgba(122/255,115/255,88/255,0.5)
                                }
                                MouseArea { id:catMA; anchors.fill:parent; hoverEnabled:true
                                    onClicked: { root.currentCat=modelData; root.focusIdx=0; searchInput.forceActiveFocus() } }
                            }
                        }

                        Item {
                            width:160; height:48
                            Column {
                                anchors { left:parent.left; leftMargin:22; bottom:parent.bottom; bottomMargin:6 }
                                spacing:4
                                Text { text:root.filteredApps.length+"/"+root.apps.length+" NODES"; font.family:root.ff; font.pixelSize:12; font.letterSpacing:2; color:root.inkSoft; opacity:0.6 }
                                Rectangle {
                                    width:72; height:2; color:root.lineSoft
                                    Rectangle {
                                        height:parent.height; color:root.accent
                                        SequentialAnimation on x { running:root.menuOpen; loops:Animation.Infinite
                                            NumberAnimation { from:0; to:44; duration:1400; easing.type:Easing.InOutSine }
                                        NumberAnimation { from:44; to:0; duration:1400; easing.type:Easing.InOutSine } }
                                        SequentialAnimation on width { running:root.menuOpen; loops:Animation.Infinite
                                            NumberAnimation { from:10; to:28; duration:1400; easing.type:Easing.InOutSine }
                                        NumberAnimation { from:28; to:10; duration:1400; easing.type:Easing.InOutSine } }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors { left:sidebar.right; right:parent.right; top:parent.top; bottom:parent.bottom }
                    Column {
                        anchors.fill:parent

                        Item {
                            width:parent.width; height:46
                            Row {
                                anchors { left:parent.left; right:parent.right; verticalCenter:parent.verticalCenter
                                          leftMargin:24; rightMargin:24 }
                                spacing:10
                                Text { anchors.verticalCenter:parent.verticalCenter; text:"▸"; font.family:root.ff; font.pixelSize:16; color:root.accent }
                                FocusScope {
                                    id:searchScope; width:parent.width-60; height:30
                                    anchors.verticalCenter:parent.verticalCenter
                                    focus: root.menuOpen

                                    TextInput {
                                        id:           searchInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family:root.ff; font.pixelSize:17; font.letterSpacing:0.5; font.weight:Font.Normal
                                        color:        root.inkStrong
                                        cursorVisible:activeFocus
                                        focus:        true
                                        selectByMouse:true
                                        text:         root.searchQuery

                                        onTextEdited: { root.searchQuery=text; root.focusIdx=0 }

                                        Keys.onPressed: function(event) {
                                            if (event.modifiers & Qt.ControlModifier) {
                                                if (event.key === Qt.Key_J) {
                                                    root.focusIdx=Math.min(root.filteredApps.length-1,root.focusIdx+1)
                                                    appList.positionViewAtIndex(root.focusIdx, ListView.Contain)
                                                } else if (event.key === Qt.Key_K) {
                                                    root.focusIdx=Math.max(0,root.focusIdx-1)
                                                    appList.positionViewAtIndex(root.focusIdx, ListView.Contain)
                                                }
                                            }
                                        }

                                        Keys.onEscapePressed: root.closeMenu()
                                        Keys.onUpPressed: {
                                            root.focusIdx=Math.max(0,root.focusIdx-1)
                                            appList.positionViewAtIndex(root.focusIdx, ListView.Contain)
                                        }
                                        Keys.onDownPressed: {
                                            root.focusIdx=Math.min(root.filteredApps.length-1,root.focusIdx+1)
                                            appList.positionViewAtIndex(root.focusIdx, ListView.Contain)
                                        }
                                        Keys.onReturnPressed: {
                                            var a=root.filteredApps[root.focusIdx]
                                            if(a) root.launchApp(a.desktopId)
                                        }

                                        Text {
                                            visible:parent.text===""
                                            anchors.verticalCenter:parent.verticalCenter
                                            text:"search application..."
                                            font.family:root.ff; font.pixelSize:17; font.italic:true; font.weight:Font.Light
                                            color:root.inkSoft; opacity:0.5
                                        }
                                    }
                                }
                            }
                            Rectangle { anchors.bottom:parent.bottom; width:parent.width; height:1; color:root.lineSoft }
                        }

                        ListView {
                            id:appList; width:parent.width; height:parent.parent.height-46
                            clip:true; model:root.filteredApps; keyNavigationEnabled:false

                            delegate: Item {
                                id:appDelegate; required property int index; required property var modelData
                                width:appList.width; height:46
                                property bool isFocused: index===root.focusIdx

                                Rectangle {
                                    anchors.fill:parent; color:root.ink
                                    opacity: appMA.containsMouse||parent.isFocused ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration:120 } }
                                }
                                Rectangle {
                                    anchors { left:parent.left; top:parent.top; bottom:parent.bottom }
                                    width:2; color:root.accent
                                    opacity: appMA.containsMouse||parent.isFocused ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration:120 } }
                                }
                                Rectangle {
                                    anchors.bottom:parent.bottom
                                    visible: index<root.filteredApps.length-1
                                    x:24; width:parent.width-48; height:1; color:root.lineSoft; opacity:0.5
                                }

                                Row {
                                    anchors {
                                        left:parent.left; right:parent.right; verticalCenter:parent.verticalCenter
                                        leftMargin:  appMA.containsMouse||appDelegate.isFocused ? 32 : 24
                                        rightMargin: 24
                                    }
                                    spacing:14
                                    Behavior on anchors.leftMargin { NumberAnimation { duration:180; easing.type:Easing.OutQuart } }

                                    Text {
                                        anchors.verticalCenter:parent.verticalCenter
                                        text:modelData.id; width:22; font.family:root.ff; font.pixelSize:13; font.letterSpacing:1.5
                                        color: appMA.containsMouse||appDelegate.isFocused ? Qt.rgba(214/255,207/255,181/255,0.5) : root.inkSoft
                                        Behavior on color { ColorAnimation { duration:120 } }
                                    }
                                    Rectangle {
                                        anchors.verticalCenter:parent.verticalCenter
                                        width:28; height:28; color:"transparent"
                                        border.color: appMA.containsMouse||appDelegate.isFocused ? Qt.rgba(214/255,207/255,181/255,0.8) : root.ink
                                        border.width:1
                                        Behavior on border.color { ColorAnimation { duration:120 } }
                                        Text {
                                            anchors.centerIn:parent; text:modelData.icon; font.family:root.ff; font.pixelSize:16
                                            color: appMA.containsMouse||appDelegate.isFocused ? Qt.rgba(214/255,207/255,181/255,0.9) : root.ink
                                            Behavior on color { ColorAnimation { duration:120 } }
                                        }
                                    }
                                    Column {
                                        anchors.verticalCenter:parent.verticalCenter; spacing:2
                                        Text {
                                            text:modelData.name; font.family:root.ff; font.pixelSize:16; font.letterSpacing:1.2; font.weight:Font.Medium
                                            color: appMA.containsMouse||appDelegate.isFocused ? Qt.rgba(214/255,207/255,181/255,1) : root.ink
                                            Behavior on color { ColorAnimation { duration:120 } }
                                        }
                                        Text {
                                            text:modelData.meta; font.family:root.ff; font.pixelSize:13; font.letterSpacing:1.5
                                            color: appMA.containsMouse||appDelegate.isFocused ? Qt.rgba(214/255,207/255,181/255,0.5) : root.inkSoft
                                            Behavior on color { ColorAnimation { duration:120 } }
                                        }
                                    }
                                    Item { width:appList.width-310; height:1 }
                                    Text {
                                        anchors.verticalCenter:parent.verticalCenter
                                        text:(root.catLabels[modelData.cat]||modelData.cat).toUpperCase()
font.family:root.ff; font.pixelSize:13; font.letterSpacing:2
                                        color: appMA.containsMouse||appDelegate.isFocused ? Qt.rgba(214/255,207/255,181/255,0.4) : root.inkSoft
                                        Behavior on color { ColorAnimation { duration:120 } }
                                    }
                                    Text {
                                        anchors.verticalCenter:parent.verticalCenter
text:"▸"; font.family:root.ff; font.pixelSize:18; color:root.accent
                                        opacity: appMA.containsMouse||appDelegate.isFocused ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration:120 } }
                                    }
                                }

                                MouseArea {
                                    id:appMA; anchors.fill:parent; hoverEnabled:true
                                    onEntered: root.focusIdx=index
                                    onClicked: root.launchApp(modelData.desktopId)
                                }
                            }

                            Item {
                                visible: root.filteredApps.length===0 && root.appsLoaded
                                width:appList.width; height:60
                                Text { anchors.centerIn:parent; text:"▸ NO RESULTS"; font.family:root.ff; font.pixelSize:14; font.letterSpacing:3; color:root.inkSoft; opacity:0.5 }
                            }
                        }
                    }
                }
            }

            Item {
                id:footer; anchors.bottom:parent.bottom; width:parent.width; height:44
                Rectangle { anchors.top:parent.top; width:parent.width; height:1; color:root.lineSoft }
                Row {
                    anchors { left:parent.left; right:parent.right; verticalCenter:parent.verticalCenter
                              leftMargin:28; rightMargin:28 }
                    Row {
                        spacing:0
                        Repeater {
                            model:[
                                {l:"NIGHT",    cmd:"__night__"},
                                {l:"DARK",     cmd:"__dark__"},
                                {l:"COFFEE",   cmd:"__coffee__"},
                                {l:"LOCK",     cmd:Quickshell.env("HOME")+"/.config/quickshell/lock.sh"},
                                {l:"SLEEP",    cmd:"systemctl suspend"},
                                {l:"REBOOT",   cmd:"systemctl reboot"},
                                {l:"SHUTDOWN", cmd:"systemctl poweroff", danger:true}
                            ]
                            delegate: Item {
                                required property var modelData
                                required property int index
                                height:44; width:faLbl.implicitWidth+24
                                Rectangle {
                                    visible:index>0
                                    anchors{left:parent.left;top:parent.top;bottom:parent.bottom}
                                    width:1; color:root.lineSoft
                                }
                                Text {
                                    id:faLbl; anchors.centerIn:parent
                                    text:modelData.l; font.family:root.ff; font.pixelSize:13; font.letterSpacing:2.5; font.weight:Font.Bold
                                    color: {
                                        if (modelData.cmd === "__night__" && root.nightMode) return root.accent
                                        if (modelData.cmd === "__coffee__" && root.coffeeMode) return root.accent
                                        return faMA.containsMouse ? (modelData.danger===true ? root.accent : root.inkStrong) : root.inkSoft
                                    }
                                    Behavior on color { ColorAnimation { duration:150 } }
                                }
                                Rectangle {
                                    anchors{bottom:parent.bottom;horizontalCenter:parent.horizontalCenter;bottomMargin:6}
                                    width: {
                                        if (modelData.cmd === "__night__" && root.nightMode) return faLbl.implicitWidth
                                        if (modelData.cmd === "__coffee__" && root.coffeeMode) return faLbl.implicitWidth
                                        return faMA.containsMouse?faLbl.implicitWidth:0
                                    }
                                    height:1; color:root.accent
                                    Behavior on width { NumberAnimation { duration:200; easing.type:Easing.OutQuart } }
                                }
                                MouseArea { id:faMA; anchors.fill:parent; hoverEnabled:true; onClicked: {
                                    if (modelData.cmd === "__night__") root.toggleNightMode()
                                    else if (modelData.cmd === "__dark__") root.toggleDarkMode()
                                    else if (modelData.cmd === "__coffee__") root.toggleCoffeeMode()
                                    else root.launch(modelData.cmd)
                                } }
                            }
                        }
                    }
                    Text {
                        visible: root.tlpProfile !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TLP: " + root.tlpProfile.toUpperCase()
                        font.family: root.ff; font.pixelSize: 13; font.letterSpacing: 2.5; font.weight: Font.Black; color: root.inkSoft; opacity: 0.85
                    }
                    Item { width:parent.width-380; height:1 }
                    Row {
                        spacing:14; anchors.verticalCenter:parent.verticalCenter
                        Repeater {
                            model:[["↑↓","NAV"],["↵","OPEN"],["ESC","CLOSE"]]
                            Row {
                                required property var modelData
                                spacing:5; anchors.verticalCenter:parent.verticalCenter
                                Rectangle {
                                    width:kbdT.implicitWidth+8; height:16; color:"transparent"
                                    border.color:root.lineSoft; border.width:1
                                    Text { id:kbdT; anchors.centerIn:parent; text:modelData[0]; font.family:root.ff; font.pixelSize:13; font.letterSpacing:1; color:root.ink }
                                }
                                Text { text:modelData[1]; anchors.verticalCenter:parent.verticalCenter; font.family:root.ff; font.pixelSize:13; font.letterSpacing:2; color:root.inkSoft }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer { id: hideDone; interval: 140; onTriggered: { panelHost.visible = false; root.animRunning = false } }

    function openMenu() {
        if (menuOpen) return
        menuOpen    = true; animRunning = true
        searchQuery = ""; focusIdx = 0; currentCat = "all"; searchInput.text = ""
        if (!appsLoaded) desktopReader.running = true
        panelHost.visible = true; panelHost.x = (root.screenW - root.lw) / 2
        glitchTimer.ox = panelHost.x; glitchTimer.step = 0; glitchTimer.start()
        panelHost.opacity = 1; panelHost.scale = 1
        scanAnim.start(); focusTimer.attempts = 0; focusTimer.restart()
        tlpGetProc.running = true
    }

    function closeMenu() {
        if (!menuOpen) return
        menuOpen = false; animRunning = true
        glitchTimer.stop(); glitchTimer.step = 0
        chromaR.opacity = 0; chromaC.opacity = 0; chromaB.opacity = 0
        panelHost.x = (root.screenW - root.lw) / 2
        panelHost.opacity = 0; panelHost.scale = 0.96
        hideDone.restart()
    }
}