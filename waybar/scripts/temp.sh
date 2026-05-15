#!/bin/bash
temp=$(( $(cat /sys/class/hwmon/hwmon5/temp1_input) / 1000 ))
cls=""
[ "$temp" -gt 65 ] && cls="critical"
[ "$temp" -gt 50 ] && cls="warn"
printf '{"text":"TEMP %s°","class":"%s"}\n' "$temp" "$cls"
