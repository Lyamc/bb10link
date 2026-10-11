#!/bin/bash
# Find BlackBerry 10 phones with file sharing on: scan the local /24 for TCP 445, then ask for the NetBIOS name.
usage() { cat <<U
Usage: $(basename "$0") [-i INTERFACE | -n A.B.C]
Scans A.B.C.1-254 for SMB (port 445) and shows each host's NetBIOS name via smbutil
(BB10 phones show up as BLACKBERRY-xxxx). Default network: the /24 of the default-route interface.
  -i IF    use this interface's address (e.g. en0)    -n A.B.C  scan this /24 prefix (e.g. 192.0.2)
U
}
IF=""; NET=""
while getopts "i:n:h-:" o; do case $o in
  i) IF=$OPTARG;; n) NET=$OPTARG;; h) usage; exit 0;; -) [ "$OPTARG" = help ] && { usage; exit 0; }; usage; exit 2;; *) usage; exit 2;; esac; done
if [ -z "$NET" ]; then
  [ -n "$IF" ] || IF=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
  IP=$(ipconfig getifaddr "$IF" 2>/dev/null) || { echo "no IPv4 address on ${IF:-default interface}; use -n A.B.C"; exit 1; }
  NET=${IP%.*}
fi
echo "Scanning $NET.1-254 for SMB (445)..."
T=$(mktemp)
for h in $(seq 1 254); do (nc -z -G1 "$NET.$h" 445 >/dev/null 2>&1 && echo "$NET.$h" >> "$T") & done; wait
[ -s "$T" ] || { echo "no SMB hosts found (phone awake? Wi-Fi file sharing on under Settings > Storage and Access?)"; rm -f "$T"; exit 1; }
sort -t. -k4 -n "$T" | while read -r ip; do
  name=$(smbutil status "$ip" 2>/dev/null | awk -F': ' '/Server:/ {print $2}')
  tag=""; case "$name" in BLACKBERRY*) tag="  <- BlackBerry";; esac
  echo "$ip  ${name:-?}$tag"
done
rm -f "$T"
