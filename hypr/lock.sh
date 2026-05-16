#!/bin/bash
# lock.sh — Lance hyprlock avec fond pixel wave NieR
BG="$HOME/.config/hypr/lockbg.png"
GEN="$HOME/.config/hypr/gen-lockbg"

# Generate pixel wave background (C++ binary, ~1ms)
if [ -x "$GEN" ]; then
    "$GEN" "$BG" &
    sleep 0.05
fi

exec hyprlock
