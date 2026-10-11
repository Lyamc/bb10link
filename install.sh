#!/bin/bash
# One-time setup: Python venv with pysmb + fusepy, smbfuse.py, mount points, Keychain password, fuse-t check.
set -e
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/common.sh"
usage() { cat <<U
Usage: $(basename "$0") [-d BASEDIR] [-u USER] [--no-keychain]
  -d DIR         base directory (env BB_DIR, default \$HOME/BlackBerry); the app goes in DIR/.app (env BB_APP)
  -u USER        share username set on the phone (env BB_USER, default BlackBerry)
  --no-keychain  don't store the password now
Steps: checks fuse-t (prints the brew command if missing), creates DIR/.app/venv, installs requirements.txt,
copies smbfuse.py, creates mount points for \$BB_SHARES, and stores the share password in the Keychain
(security add-generic-password prompts for it; nothing is written to disk in plain text).
U
}
KC=1
while [ $# -gt 0 ]; do case $1 in
  -d) BB_DIR=$2; BB_APP=$BB_DIR/.app; shift 2;; -u) BB_USER=$2; shift 2;; --no-keychain) KC=0; shift;;
  -h|--help) usage; exit 0;; *) usage; exit 2;; esac; done

if [ ! -f /usr/local/lib/libfuse-t.dylib ]; then
  echo "fuse-t is not installed. Install it (needs your admin password), then re-run this script:"
  echo "    brew install --cask macos-fuse-t/homebrew-cask/fuse-t"
  exit 1
fi
command -v python3 >/dev/null || { echo "python3 not found (install Xcode Command Line Tools or brew install python)"; exit 1; }
mkdir -p "$BB_APP"
[ -x "$BB_APP/venv/bin/python" ] || python3 -m venv "$BB_APP/venv"
"$BB_APP/venv/bin/pip" install -q --upgrade pip
"$BB_APP/venv/bin/pip" install -q -r "$HERE/requirements.txt"
install -m 755 "$HERE/smbfuse.py" "$BB_APP/smbfuse.py"
for pair in $BB_SHARES; do mkdir -p "$BB_DIR/${pair#*:}"; done
echo "Installed to $BB_APP; mount points under $BB_DIR"
if [ $KC = 1 ]; then
  if security find-generic-password -a "$BB_USER" -s "$BB_KEYCHAIN_SERVICE" >/dev/null 2>&1; then
    echo "Keychain item '$BB_KEYCHAIN_SERVICE' for '$BB_USER' already exists (delete with: security delete-generic-password -a $BB_USER -s $BB_KEYCHAIN_SERVICE)"
  else
    echo "Enter the phone's file-sharing password (Settings > Storage and Access on the phone):"
    security add-generic-password -a "$BB_USER" -s "$BB_KEYCHAIN_SERVICE" -w
  fi
fi
echo "Next: BB_HOST=<phone IP> $HERE/mount.sh   (find the IP with $HERE/bb10-discover.sh)"
