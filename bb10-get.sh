#!/bin/bash
# Copy files FROM the phone with smbclient (SMB1/NT1), or list a directory.
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/common.sh"
SHARE=media; LOCAL=.
usage() { cat <<U
Usage: $(basename "$0") [-H HOST] [-u USER] [-S SHARE] [-o LOCAL_DIR] REMOTE_PATH...
       $(basename "$0") [-H HOST] -l [REMOTE_DIR]        list a directory
Download REMOTE_PATH(s) (relative to the share, e.g. camera/IMG_0001.jpg) into LOCAL_DIR (default .).
  -H HOST  phone address (env BB_HOST, required)    -u USER  (env BB_USER)    -S SHARE (default media)
Needs smbclient (brew install samba). Password from the Keychain item '$BB_KEYCHAIN_SERVICE'.
U
}
LIST=0
while getopts "H:u:S:o:lh-:" o; do case $o in
  H) BB_HOST=$OPTARG;; u) BB_USER=$OPTARG;; S) SHARE=$OPTARG;; o) LOCAL=$OPTARG;; l) LIST=1;;
  h) usage; exit 0;; -) [ "$OPTARG" = help ] && { usage; exit 0; }; usage; exit 2;; *) usage; exit 2;; esac; done
shift $((OPTIND - 1))
[ -n "${BB_HOST:-}" ] || { usage; exit 2; }
command -v smbclient >/dev/null || { echo "smbclient not found: brew install samba"; exit 1; }
PW=$(bb_password) || exit 1
if [ $LIST = 1 ]; then cmds="cd \"${1:-/}\"; ls"
else
  [ $# -gt 0 ] || { usage; exit 2; }
  mkdir -p "$LOCAL"; cmds="lcd \"$LOCAL\";"
  for r in "$@"; do d=$(dirname "$r"); cmds="$cmds cd \"/$d\"; get \"$(basename "$r")\";"; done
fi
PASSWD=$PW smbclient "//$BB_HOST/$SHARE" -U "$BB_USER" --option='client min protocol=NT1' --option='client max protocol=NT1' -c "$cmds"
