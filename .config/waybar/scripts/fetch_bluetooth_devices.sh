#!/bin/bash

icon=$'\uF293'  # Font Awesome Bluetooth icon

# Check Bluetooth power state
power_state=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

if [[ "$power_state" == "no" ]]; then
  echo "Bluetooth off $icon"
  exit 0
fi

# Get list of connected device names
mapfile -t devices < <(bluetoothctl devices Connected | grep '^Device' | sed -E 's/^Device ([A-F0-9:]+) //')
count=${#devices[@]}

if [ "$count" -eq 0 ]; then
  echo "Bluetooth on $icon"
elif [ "$count" -eq 1 ]; then
  echo "${devices[0]} $icon"
else
  echo "$count connected devices $icon"
fi
