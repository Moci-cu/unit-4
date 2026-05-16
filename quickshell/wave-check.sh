#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════
# wave-check.sh
# Vérifie au démarrage Hyprland que les vidéos de la vague de pixels
# (reveal + hide) sont présentes. Si non, les génère en bloquant.
#
# Usage :
#   - Lancer manuellement : ./wave-check.sh
#   - Au démarrage : exec-once = ~/.config/quickshell/wave-check.sh
# ═════════════════════════════════════════════════════════════════════

set -e

# ── Paths génériques (respecte XDG) ──
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

QS_DIR="$CONFIG_HOME/quickshell"
VIDEOS_DIR="$QS_DIR/videos"
LOG_DIR="$CACHE_HOME/quickshell"
LOG_FILE="$LOG_DIR/wave-check.log"

# Fichiers attendus (noms utilisés par lockscreen.qml et WallpaperPicker.qml)
REVEAL_VIDEO="$VIDEOS_DIR/wave_reveal.mp4"
HIDE_VIDEO="$VIDEOS_DIR/wave_hide.mp4"

# Générateur C++ (remplace pixel_wave.py + pixel-wave-close-video.py)
PIXEL_VIDEO="$QS_DIR/pixel_video"

# ── Préparation ──
mkdir -p "$VIDEOS_DIR" "$LOG_DIR"

# Redirection stdout + stderr vers le log (avec timestamp)
exec > >(while IFS= read -r line; do printf '[%s] %s\n' "$(date +%H:%M:%S)" "$line"; done >> "$LOG_FILE") 2>&1

echo "═══════════════════════════════════════════════════════════"
echo "wave-check.sh — démarrage"
echo "  videos dir : $VIDEOS_DIR"
echo "═══════════════════════════════════════════════════════════"

# ── Vérification présence du générateur ──
if [[ ! -x "$PIXEL_VIDEO" ]]; then
    echo "❌ Générateur pixel_video manquant ou non exécutable : $PIXEL_VIDEO"
    echo "Abandon."
    exit 1
fi

# ── Vérif et génération reveal ──
if [[ -f "$REVEAL_VIDEO" ]]; then
    echo "✓ wave_reveal.mp4 présent"
else
    echo "⚠ wave_reveal.mp4 manquant — génération…"
    "$PIXEL_VIDEO" reveal 1920 1080 60 1.0 "$REVEAL_VIDEO" medium
    if [[ -f "$REVEAL_VIDEO" ]]; then
        echo "✓ wave_reveal.mp4 généré"
    else
        echo "❌ échec génération wave_reveal.mp4"
        exit 2
    fi
fi

# ── Vérif et génération hide ──
if [[ -f "$HIDE_VIDEO" ]]; then
    echo "✓ wave_hide.mp4 présent"
else
    echo "⚠ wave_hide.mp4 manquant — génération…"
    "$PIXEL_VIDEO" hide 1920 1080 60 1.2 "$HIDE_VIDEO" medium
    if [[ -f "$HIDE_VIDEO" ]]; then
        echo "✓ wave_hide.mp4 généré"
    else
        echo "❌ échec génération wave_hide.mp4"
        exit 3
    fi
fi

echo "═══════════════════════════════════════════════════════════"
echo "wave-check.sh — terminé"
echo "═══════════════════════════════════════════════════════════"
