#!/bin/zsh
# Records one take of the booted Simulator until Ctrl-C.
#   scripts/record.sh <name>
#   DEVICE="iPhone Duo" DISPLAY_ID=3 APPEARANCE=dark scripts/record.sh <name>
# Writes footage/raw/<name>.mov as recorded and footage/<name>.mp4 at 30 fps, 1080 px wide.
set -euo pipefail
zmodload zsh/datetime

name=${1:?usage: scripts/record.sh <name>}
device=${DEVICE:-"iPhone 18 Pro"}
appearance=${APPEARANCE:-light}
root=${0:A:h:h}
raw=$root/footage/raw/$name.mov
out=$root/footage/$name.mp4
mkdir -p $root/footage/raw

xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl ui "$device" appearance $appearance
xcrun simctl status_bar "$device" override \
  --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

display=()
if [[ -n ${DISPLAY_ID:-} ]]; then display=(--display=$DISPLAY_ID); fi

echo "Recording $device ($appearance) to $raw — Ctrl-C to stop."
# Ctrl-C reaches simctl, which finishes the file; the shell carries on to convert it.
trap 'true' INT
started=$EPOCHREALTIME
xcrun simctl io "$device" recordVideo --codec=h264 --force $display "$raw"
wall=$(( EPOCHREALTIME - started ))
trap - INT

xcrun simctl status_bar "$device" clear
# The Simulator writes a frame only when the screen changes, so a still ending is missing from
# the file; the last frame is held out to the time actually recorded.
ffmpeg -loglevel error -y -i "$raw" \
  -vf "fps=30,scale=1080:-2:flags=lanczos,tpad=stop_mode=clone:stop_duration=$wall" -t $wall \
  -c:v libx264 -crf 14 -g 15 -pix_fmt yuv420p -an "$out"
echo "Wrote $out ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out") s)."
