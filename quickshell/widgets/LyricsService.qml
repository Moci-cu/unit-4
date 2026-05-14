import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Simplified LyricsService for NieR dots
Item {
    id: root
    visible: false

    readonly property var activePlayer: {
        var p = Mpris.players.values
        for (var i = 0; i < p.length; i++) {
            var t = p[i].trackTitle || ""
            var a = p[i].trackArtist || ""
            if (t.length > 0 && t !== "Unknown Title") return p[i]
        }
        // Fallback: try any player with identity (Termusic, etc.)
        for (var j = 0; j < p.length; j++) {
            if (p[j].identity || p[j].trackTitle) return p[j]
        }
        return null
    }

    // Fallback: extract artist/title from filename when MPRIS metadata is empty
    readonly property string activeTitle: {
        var t = root.activePlayer?.trackTitle ?? ""
        if (t && t !== "Unknown Title") return t
        return root.filenameTitle
    }
    readonly property string activeArtist: {
        var a = root.activePlayer?.trackArtist ?? ""
        if (a && a !== "Unknown Artist") return a
        return root.filenameArtist
    }

    // Try to extract artist - title from filename via Process
    property string filenameTitle: ""
    property string filenameArtist: ""

    Timer {
        id: filenameExtract
        interval: 500; repeat: false
        running: root.activePlayer !== null && root.initialized
        onTriggered: extractFilename.running = true
    }
    Process {
        id: extractFilename
        command: ["sh", "-c", "dbus-send --print-reply --dest=" + (root.activePlayer?.identity || "org.mpris.MediaPlayer2.termusic") + " /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata' 2>/dev/null | grep 'xesam:url' -A2 | tail -1 | sed 's/.*string \"//' | sed 's/\"$//' | sed 's|file://||' | xargs -I{} basename '{}' .opus .m4a .mp3 .flac .wav .ogg .webm 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text.trim()
                if (!raw) return
                var parts = raw.split(" - ")
                if (parts.length >= 2) {
                    root.filenameArtist = parts[0].trim()
                    root.filenameTitle = parts.slice(1).join(" - ").trim()
                } else {
                    root.filenameTitle = raw
                }
            }
        }
    }
    readonly property string currentTrackId: root.activePlayer?.trackTitle ?? ""

    readonly property alias syncedLines: lrclib.lines
    readonly property alias currentIndex: lrclib.currentIndex
    readonly property string statusText: lrclib.displayText
    readonly property bool hasSyncedLines: lrclib.lines.length > 0

    readonly property alias geniusHasLyrics: genius.hasString
    readonly property string plainLyrics: genius.lyricsString

    property bool initialized: false

    function init() { root.initialized = true }

    // https://quickshell.org/docs/master/types/Quickshell.Services.Mpris/MprisPlayer/#position
    property bool _lastTimerRun: false
    Timer {
        running: {
            var cond = root.activePlayer?.playbackState == MprisPlaybackState.Playing && root.hasSyncedLines && root.initialized
            if (cond !== root._lastTimerRun) {
                root._lastTimerRun = cond
                console.log("[Lyrics] timer running:", cond, "state:", root.activePlayer?.playbackState, "hasLines:", root.hasSyncedLines)
            }
            return cond
        }
        interval: 250
        repeat: true
        onTriggered: root.activePlayer.positionChanged()
    }

    LrclibLyrics {
        id: lrclib
        enabled: root.initialized && root.activeTitle?.length > 0 && root.activeArtist?.length > 0
        title: root.activeTitle
        artist: root.activeArtist
        duration: root.activePlayer?.length ?? 0
        position: root.activePlayer?.position ?? 0
    }

    GeniusLyrics {
        id: genius
        property string lyricsString: ""
        property bool hasString: false
        onLyricsUpdated: (lyrics) => {
            genius.hasString = true
            genius.lyricsString = lyrics
        }
    }

    onCurrentTrackIdChanged: {
        if (!root.initialized) return
        if (activeArtist && activeTitle) {
            genius.fetchLyrics(activeArtist, activeTitle)
        } else {
            genius.lyricsString = ""
        }
    }
}
