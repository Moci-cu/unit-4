pragma Singleton
import QtQuick
import Quickshell

QtObject {
  // ── Dark mode state ──
  readonly property bool darkMode: darkState === "1"
  property string darkState: "0"

  // ── Dark overlay widgets ──
  readonly property color bg:     "#0b0a09"
  readonly property color bg2:    "#111008"
  readonly property color bg3:    "#1a1814"
  readonly property color fg:     "#e0c888"
  readonly property color fgd:    Qt.rgba(224/255, 200/255, 136/255, 0.5)
  readonly property color fgdd:   Qt.rgba(224/255, 200/255, 136/255, 0.2)

  // ── Dynamic Paper palette (light / dark) ──
  readonly property color paper:     Theme.darkMode ? "#1a1814" : "#d6cfb5"
  readonly property color ink:       Theme.darkMode ? "#b8a060" : "#463f2e"
  readonly property color inkStrong: Theme.darkMode ? "#e0c888" : "#2e2a1f"
  readonly property color inkSoft:   Theme.darkMode ? "#a89860" : "#7a7358"
  readonly property color lineSoft:  Theme.darkMode ? Qt.rgba(224/255,200/255,136/255,0.20) : Qt.rgba(70/255,63/255,46/255,0.23)
  readonly property color lineVsoft: Theme.darkMode ? Qt.rgba(224/255,200/255,136/255,0.12) : Qt.rgba(70/255,63/255,46/255,0.10)

  // ── Accents ──
  readonly property color a1:     "#c87060"
  readonly property color a2:     "#60a880"
  readonly property color a3:     "#6090c8"
  readonly property color a4:     "#e0c888"
  readonly property color accent: Theme.darkMode ? "#a04040" : "#6e2a2a"

  // ── Bordures ──
  readonly property color ln:     Qt.rgba(224/255, 200/255, 136/255, 0.12)
  readonly property color lnm:    Qt.rgba(224/255, 200/255, 136/255, 0.22)

  // ── UI elements ──
  readonly property color gold:       "#c0a858"
  readonly property color inactiveBg: Theme.darkMode ? Qt.rgba(200/255,168/255,96/255,0.1) : Qt.rgba(70/255,63/255,46/255,0.22)

  // ── OSD bars (Volume / Brightness) ──
  readonly property color osdFilled: "#d0b870"
  readonly property color osdEmpty:  "#e0c888"
  readonly property color osdBg:     "#0f0d0a"

  // ── Font ──
  readonly property string mono:  "Share Tech Mono"

  // ── Timings animations ──
  readonly property int durationFast:   150
  readonly property int durationMid:    380
  readonly property int durationSlow:   650
}
