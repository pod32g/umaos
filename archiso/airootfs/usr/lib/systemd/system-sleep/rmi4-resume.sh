#!/usr/bin/env bash
# Fix Synaptics RMI4 touchpad failing to resume after suspend.
# Unbinds and rebinds the SMBus device to reinitialize the touchpad.
# Without this, the touchpad is dead after waking from sleep on
# laptops with Synaptics TM3625 (and similar) touchpads.

case "$1" in
  post)
    for dev in /sys/bus/i2c/drivers/rmi4_smbus/*/; do
      [[ -d "$dev" ]] || continue
      addr="$(basename "$dev")"
      [[ "$addr" =~ ^[0-9]+-[0-9a-f]+$ ]] || continue
      echo "$addr" > /sys/bus/i2c/drivers/rmi4_smbus/unbind 2>/dev/null
      sleep 0.5
      echo "$addr" > /sys/bus/i2c/drivers/rmi4_smbus/bind 2>/dev/null
    done
    ;;
esac
