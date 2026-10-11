#!/bin/bash
# Unmount the BB10 shares mounted by mount.sh and stop their smbfuse.py processes.
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/common.sh"
usage() { cat <<U
Usage: $(basename "$0") [-s "SHARE:DIR ..."] [-d BASEDIR]
Unmount the shares mounted by mount.sh (same -s / -d / BB_SHARES / BB_DIR as mount.sh).
Use this, then mount.sh again with the new address, when the phone slept or changed IP.
U
}
while getopts "s:d:h-:" o; do case $o in
  s) BB_SHARES=$OPTARG;; d) BB_DIR=$OPTARG; BB_APP=$BB_DIR/.app;;
  h) usage; exit 0;; -) [ "$OPTARG" = help ] && { usage; exit 0; }; usage; exit 2;; *) usage; exit 2;; esac; done
for pair in $BB_SHARES; do
  d=$BB_DIR/${pair#*:}; [ -d "$d" ] && d=$(cd "$d" && pwd -P)
  mount | grep -q " on $d " || continue
  umount "$d" 2>/dev/null || diskutil unmount force "$d" >/dev/null 2>&1
  echo "Unmounted $d"
done
pkill -f "$BB_APP/smbfuse.py" 2>/dev/null; echo "Done"
