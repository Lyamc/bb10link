# Shared defaults for the bb10 scripts (sourced). Override with environment variables.
BB_USER=${BB_USER:-BlackBerry}                       # share username set on the phone
BB_DIR=${BB_DIR:-$HOME/BlackBerry}                   # mount points live here
BB_APP=${BB_APP:-$BB_DIR/.app}                       # venv + smbfuse.py + logs
BB_SHARES=${BB_SHARES:-"media:media removable_SDCARD:SDCARD"}   # SHARE:DIR pairs (DIR under BB_DIR)
BB_KEYCHAIN_SERVICE=${BB_KEYCHAIN_SERVICE:-bb10-smb}
bb_password() {   # password from the Keychain (or BB_PASSWORD if set)
  [ -n "${BB_PASSWORD:-}" ] && { printf '%s' "$BB_PASSWORD"; return; }
  security find-generic-password -a "$BB_USER" -s "$BB_KEYCHAIN_SERVICE" -w 2>/dev/null || {
    echo "No Keychain item '$BB_KEYCHAIN_SERVICE' for account '$BB_USER'. Run: security add-generic-password -a $BB_USER -s $BB_KEYCHAIN_SERVICE -w" >&2; return 1; }
}
