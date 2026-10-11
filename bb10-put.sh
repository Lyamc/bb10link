#!/bin/bash
# Copy files TO the phone with smbclient (SMB1/NT1), no mount needed.
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/common.sh"
SHARE=media; DEST=downloads
usage() { cat <<U
Usage: $(basename "$0") [-H HOST] [-u USER] [-S SHARE] [-r REMOTE_DIR] FILE...
Upload FILE(s) to //HOST/SHARE/REMOTE_DIR (default: media/downloads, where File Manager finds APK/BAR files).
  -H HOST  phone address (env BB_HOST, required)    -u USER  (env BB_USER, default BlackBerry)
Needs smbclient (brew install samba). Password from the Keychain item '$BB_KEYCHAIN_SERVICE'.
Example: BB_HOST=192.0.2.10 $(basename "$0") app.apk
U
}
while getopts "H:u:S:r:h-:" o; do case $o in
  H) BB_HOST=$OPTARG;; u) BB_USER=$OPTARG;; S) SHARE=$OPTARG;; r) DEST=$OPTARG;;
  h) usage; exit 0;; -) [ "$OPTARG" = help ] && { usage; exit 0; }; usage; exit 2;; *) usage; exit 2;; esac; done
shift $((OPTIND - 1))
[ -n "${BB_HOST:-}" ] && [ $# -gt 0 ] || { usage; exit 2; }
command -v smbclient >/dev/null || { echo "smbclient not found: brew install samba"; exit 1; }
PW=$(bb_password) || exit 1
cmds="cd \"$DEST\";"
for f in "$@"; do [ -f "$f" ] || { echo "no such file: $f"; exit 1; }; cmds="$cmds put \"$f\" \"$(basename "$f")\";"; done
# password via the PASSWD environment variable, so it is not on the smbclient command line
PASSWD=$PW smbclient "//$BB_HOST/$SHARE" -U "$BB_USER" --option='client min protocol=NT1' --option='client max protocol=NT1' -c "$cmds"
