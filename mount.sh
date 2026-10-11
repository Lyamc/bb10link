#!/bin/bash
# Mount a BlackBerry 10 phone's SMB1 Wi-Fi shares on macOS via fuse-t + pysmb (see README).
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/common.sh"
usage() { cat <<U
Usage: $(basename "$0") [-H HOST] [-u USER] [-s "SHARE:DIR ..."] [-d BASEDIR]
Mount the phone's shares (default: media -> \$BB_DIR/media, removable_SDCARD -> \$BB_DIR/SDCARD).
  -H HOST    phone IP or name (env BB_HOST; required), e.g. 192.0.2.10 - see bb10-discover.sh
  -u USER    share username (env BB_USER, default BlackBerry)
  -s PAIRS   space-separated SHARE:DIR pairs (env BB_SHARES)
  -d DIR     base directory for mount points (env BB_DIR, default \$HOME/BlackBerry)
Password: Keychain item '$BB_KEYCHAIN_SERVICE' (account = USER), created by install.sh. Unmount with unmount.sh.
U
}
while getopts "H:u:s:d:h-:" o; do case $o in
  H) BB_HOST=$OPTARG;; u) BB_USER=$OPTARG;; s) BB_SHARES=$OPTARG;; d) BB_DIR=$OPTARG; BB_APP=$BB_DIR/.app;;
  h) usage; exit 0;; -) [ "$OPTARG" = help ] && { usage; exit 0; }; usage; exit 2;; *) usage; exit 2;; esac; done
[ -n "${BB_HOST:-}" ] || { echo "No phone address: use -H HOST or BB_HOST=... (find it with bb10-discover.sh)"; usage; exit 2; }
export BB_USER BB_KEYCHAIN_SERVICE
export FUSE_LIBRARY_PATH=${FUSE_LIBRARY_PATH:-/usr/local/lib/libfuse-t.dylib}
[ -f "$FUSE_LIBRARY_PATH" ] || { echo "fuse-t not installed: brew install --cask macos-fuse-t/homebrew-cask/fuse-t"; exit 1; }
[ -x "$BB_APP/venv/bin/python" ] && [ -f "$BB_APP/smbfuse.py" ] || { echo "Not installed in $BB_APP: run ./install.sh"; exit 1; }
bb_password >/dev/null || exit 1
nc -z -G3 "$BB_HOST" 445 >/dev/null 2>&1 || { echo "Phone $BB_HOST:445 not reachable (Wi-Fi file sharing on? phone awake? IP changed?)"; exit 1; }
rc=0
for pair in $BB_SHARES; do
  share=${pair%%:*}; dir=$BB_DIR/${pair#*:}; mkdir -p "$dir"; dir=$(cd "$dir" && pwd -P)   # mount(8) prints resolved paths
  if mount | grep -q " on $dir "; then echo "$dir already mounted"; continue; fi
  nohup "$BB_APP/venv/bin/python" "$BB_APP/smbfuse.py" "$BB_HOST" "$share" "$dir" >"$BB_APP/$share.log" 2>&1 &
  for i in $(seq 1 15); do mount | grep -q " on $dir " && break; sleep 1; done
  if mount | grep -q " on $dir "; then echo "Mounted //$BB_HOST/$share at $dir"
  else echo "FAILED $share; see $BB_APP/$share.log"; tail -5 "$BB_APP/$share.log"; rc=1; fi
done
exit $rc
