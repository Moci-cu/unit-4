#!/bin/bash
cmds=$(hyprctl clients -j | jq -r '
  .[] | select(.class != "quickshell") |
  "dispatch hl.dsp.focus({window=\"address:\(.address)\"}); dispatch hl.dsp.window.close()"
' | tr '\n' ';')
[ -n "$cmds" ] && hyprctl --batch "$cmds"
