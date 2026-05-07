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

    // ── COMPANIONS ──────────────────────────────────────────────

    // Taille des sprites
    readonly property int companionsSpriteSize: s(128)

}
