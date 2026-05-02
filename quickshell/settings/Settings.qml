pragma Singleton
import QtQuick
import Quickshell

// ╔══════════════════════════════════════════════════════════════╗
// ║  SETTINGS — options de configuration du rice NieR           ║
// ║  Modifie les valeurs ici pour personnaliser le comportement  ║
// ╚══════════════════════════════════════════════════════════════╝

QtObject {

    // ── SCALE GLOBAL ────────────────────────────────────────────

    // Multiplicateur global appliqué à toutes les tailles
    // 1.0 = taille normale, 1.25 = 25% plus grand, 0.8 = 20% plus petit
    readonly property real scale: 1

    // Unité scalée — applique scale à une taille de base
    function s(px) { return Math.round(px * scale) }

    // ── PLAYER ──────────────────────────────────────────────────

    // Fond du player : true = fond sombre opaque / false = transparent
    readonly property bool playerBackground: true

    // Couleur du fond (utilisée seulement si playerBackground = true)
    readonly property color playerBgColor: Qt.rgba(11/255, 10/255, 9/255, 0.92)

    // Position verticale du player (0.0 = haut, 1.0 = bas de l'écran)
    readonly property real playerPositionY: 0.39

    // Largeur du player en pixels (scalée automatiquement)
    readonly property int playerWidth: 640


    // ── COMPANIONS ──────────────────────────────────────────────

    // Taille des sprites
    readonly property int companionsSpriteSize: s(128)

}
