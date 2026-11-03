#!/usr/bin/env bash

set -eo pipefail

case "$RUNNER_OS" in
  Windows) CPU=$(powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Select-Object -First 1).Name") ;;
  macOS) CPU=$(sysctl -n machdep.cpu.brand_string) ;;
  *) CPU=$(grep -m1 -E 'model name|Model name' /proc/cpuinfo | cut -d: -f2- || true)
     [ -n "$CPU" ] || CPU=$(lscpu | grep -m1 'Model name' | cut -d: -f2- || true) ;;
esac
CPU=$(echo "$CPU" | tr -d '\r' | sed 's/^ *//;s/ *$//')
echo "CPU: $CPU 🦎"
echo "cpu=$CPU" >> "$GITHUB_OUTPUT"

rejected=false
if [ -n "$CPU_EXPECT" ] && [[ "$CPU" != *"$CPU_EXPECT"* ]]; then
  echo "Landed on $CPU instead of $CPU_EXPECT on attempt $ATTEMPT, this leg will rerun on a different runner." >&2
  rejected=true
fi
if [ -n "$CPU_REJECT" ] && [[ "$CPU" == *"$CPU_REJECT"* ]]; then
  echo "Landed on $CPU on attempt $ATTEMPT, this leg will rerun on a different runner." >&2
  rejected=true
fi
echo "rejected=$rejected" >> "$GITHUB_OUTPUT"
