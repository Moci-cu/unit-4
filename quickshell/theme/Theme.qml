pragma Singleton
import QtQuick

QtObject {
  // ── Dark / Sepia palette (overlay widgets) ──
  readonly property color bg:     "#0b0a09"
  readonly property color bg2:    "#111008"
  readonly property color bg3:    "#1a1814"
  readonly property color fg:     "#c8b89a"
  readonly property color fgd:    Qt.rgba(200/255, 184/255, 154/255, 0.5)
  readonly property color fgdd:   Qt.rgba(200/255, 184/255, 154/255, 0.2)

  // ── Paper / Launcher palette (light panels) ──
  readonly property color paper:     "#d6cfb5"
  readonly property color ink:       "#463f2e"
  readonly property color inkStrong: "#2e2a1f"
  readonly property color inkSoft:   "#7a7358"
  readonly property color lineSoft:  Qt.rgba(70/255, 63/255, 46/255, 0.25)
  readonly property color lineVsoft: Qt.rgba(70/255, 63/255, 46/255, 0.12)

  // ── Accents ──
  readonly property color a1:     "#c87060"
  readonly property color a2:     "#60a880"
  readonly property color a3:     "#6090c8"
  readonly property color a4:     "#c8a860"
  readonly property color accent: "#6e2a2a"

  // ── Bordures ──
  readonly property color ln:     Qt.rgba(200/255, 184/255, 154/255, 0.12)
  readonly property color lnm:    Qt.rgba(200/255, 184/255, 154/255, 0.22)

  // ── Font ──
  readonly property string mono:  "Share Tech Mono"

  // ── Timings animations ──
  readonly property int durationFast:   150
  readonly property int durationMid:    380
  readonly property int durationSlow:   650
}
