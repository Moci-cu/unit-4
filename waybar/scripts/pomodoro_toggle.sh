#!/bin/bash
STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pomodoro_state"

if [ ! -f "$STATE_FILE" ]; then
  echo "RUNNING=true" > "$STATE_FILE"
  echo "START_TIME=$(date +%s)" >> "$STATE_FILE"
  echo "DURATION=1500" >> "$STATE_FILE"
else
  source "$STATE_FILE"
  if [ "$RUNNING" = "true" ]; then
    echo "RUNNING=false" > "$STATE_FILE"
  else
    echo "RUNNING=true" > "$STATE_FILE"
    echo "START_TIME=$(date +%s)" >> "$STATE_FILE"
    echo "DURATION=1500" >> "$STATE_FILE"
  fi
fi