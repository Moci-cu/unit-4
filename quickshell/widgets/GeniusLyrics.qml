pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell

Item {
    id: root
    visible: false

    signal lyricsUpdated(string lyrics)

    readonly property var geniusApiKey: Quickshell.env("GENIUS_API_KEY") || ""
    property string lyricsString: ""
    property bool hasString: false

    function fetchLyrics(artist, title) {
        console.log("[Genius Lyrics] Fetching lyrics for", artist, "-", title)
        var scriptPath = Quickshell.env("HOME") + "/.config/quickshell/scripts/lyrics/genius-lyrics.js"
        if (!root.geniusApiKey) {
            root.hasString = false
            root.lyricsString = ""
            return
        }
        fetchLyricsProcess.command = ["node", scriptPath, root.geniusApiKey, artist, title]
        fetchLyricsProcess.running = true
    }

    Process {
        id: fetchLyricsProcess
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                lyricsUpdated(this.text)
            }   
        }
    }   
}