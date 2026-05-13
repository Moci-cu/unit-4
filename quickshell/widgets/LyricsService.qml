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
            if (t.length > 0 && t !== "Unknown Title" && a.length > 0 && a !== "Unknown Artist") {
                console.log("[Lyrics] using player:", t, "—", a)
                return p[i]
            }
        }
        console.log("[Lyrics] no valid player found, total players:", p.length)
        return null
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
    Timer {
        running: root.activePlayer?.playbackState == MprisPlaybackState.Playing && root.hasSyncedLines && root.initialized
        interval: 250
        repeat: true
        onTriggered: root.activePlayer.positionChanged()
    }

    LrclibLyrics {
        id: lrclib
        enabled: root.initialized && root.activePlayer?.trackTitle?.length > 0 && root.activePlayer?.trackArtist?.length > 0
        title: root.activePlayer?.trackTitle ?? ""
        artist: root.activePlayer?.trackArtist ?? ""
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
        if (currentTrackId !== "" && root.activePlayer?.trackArtist) {
            genius.fetchLyrics(root.activePlayer.trackArtist, root.activePlayer.trackTitle)
        } else {
            genius.lyricsString = ""
        }
    }
}
