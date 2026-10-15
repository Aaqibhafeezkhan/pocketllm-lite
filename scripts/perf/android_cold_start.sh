#!/usr/bin/env bash
# Measures cold-start time and idle memory for an installed PocketLLM build.
#
#   scripts/perf/android_cold_start.sh [runs] [adb-serial]
#
# Requires: adb on PATH, the app installed (a release build gives meaningful
# numbers; debug builds are JIT-compiled and much slower), and a device that is
# otherwise idle. Prints a CSV: run,total_ms,wait_ms. `am start -W` reports the
# time from the launch request to the first displayed frame of the activity.
#
# These are launch-to-first-frame figures, not "time to a usable chat". Always
# record the device model and whether it was an emulator when you quote them.

set -euo pipefail

RUNS="${1:-6}"
SERIAL="${2:-}"
PKG="com.pocketllm.pocketllm_lite"
ADB=(adb)
[ -n "$SERIAL" ] && ADB=(adb -s "$SERIAL")

echo "device: $("${ADB[@]}" shell getprop ro.product.model | tr -d '\r')"
echo "android: $("${ADB[@]}" shell getprop ro.build.version.release | tr -d '\r')"
echo "abi: $("${ADB[@]}" shell getprop ro.product.cpu.abi | tr -d '\r')"
echo "emulator: $("${ADB[@]}" shell getprop ro.kernel.qemu | tr -d '\r')"
echo "run,total_ms,wait_ms"

for i in $(seq 1 "$RUNS"); do
  "${ADB[@]}" shell am force-stop "$PKG"
  sleep 2
  out="$("${ADB[@]}" shell am start -W -n "$PKG/.MainActivity" | tr -d '\r')"
  total="$(echo "$out" | awk '/TotalTime/ {print $2}')"
  wait="$(echo "$out" | awk '/WaitTime/ {print $2}')"
  echo "$i,$total,$wait"
  sleep 4
done

echo "--- idle memory (dumpsys meminfo, after the last launch) ---"
"${ADB[@]}" shell dumpsys meminfo "$PKG" | grep -E "TOTAL PSS|Native Heap:|Java Heap:" || true
