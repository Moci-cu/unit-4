pragma Singleton
import QtQuick
import Quickshell

QtObject {
  // ── Dark mode state ──
  readonly property bool darkMode: darkState === "1"
  property string darkState: "0"

  // ── Dark overlay widgets ──
  readonly property color bg:     "#0a0a0a"
  readonly property color bg2:    "#0f0f0f"
  readonly property color bg3:    "#141414"
  readonly property color fg:     "#ffffff"
  readonly property color fgd:    Qt.rgba(255/255, 255/255, 255/255, 0.5)
  readonly property color fgdd:   Qt.rgba(255/255, 255/255, 255/255, 0.2)

  // ── Comic palette (Miles Morales / Spider-Verse) ──
  readonly property color paper:     "#0d0d0d"
  readonly property color ink:       "#ffffff"
  readonly property color inkStrong: "#ffffff"
  readonly property color inkSoft:   "#8a8a8a"
  readonly property color lineSoft:  Qt.rgba(204/255,26/255,26/255,0.30)
  readonly property color lineVsoft: Qt.rgba(204/255,26/255,26/255,0.15)

  // ── Accents ──
  readonly property color a1:     "#cc1a1a"
  readonly property color a2:     "#00aaff"
  readonly property color a3:     "#ffd700"
  readonly property color a4:     "#ffffff"
  readonly property color accent: "#cc1a1a"

  // ── Bordures ──
  readonly property color ln:     Qt.rgba(255/255, 255/255, 255/255, 0.10)
  readonly property color lnm:    Qt.rgba(255/255, 255/255, 255/255, 0.20)

  // ── UI elements ──
  readonly property color gold:       "#00aaff"
  readonly property color inactiveBg: Qt.rgba(255/255,255/255,255/255,0.06)

  // ── OSD bars (Volume / Brightness) ──
  readonly property color osdFilled: "#cc1a1a"
  readonly property color osdEmpty:  "#ffffff"
  readonly property color osdBg:     "#0a0a0a"

  // ── Font ──
  readonly property string mono:  "Share Tech Mono"

  // ── Timings animations ──
  readonly property int durationFast:   150
  readonly property int durationMid:    380
  readonly property int durationSlow:   650
}
