# bb10link: BlackBerry 10 file-share tools for macOS

Mount a BlackBerry 10 phone's Wi-Fi file share on a modern Mac and copy files to and from it.
This is for things like sideloading APK/BAR files, pulling photos, or dropping media onto the phone.

BB10 shares storage over **SMB1 (NT1) only**. Current macOS releases (including macOS 26) have no SMB1 client, so
`mount_smbfs` / Finder's "Connect to Server" fail with an *Authentication error* even when the password is right.
This repo provides:

- **`smbfuse.py`**, a small userspace SMB1 filesystem. It uses [pysmb](https://github.com/miketeo/pysmb) for SMB1 and
  [fusepy](https://github.com/fusepy/fusepy) on [fuse-t](https://www.fuse-t.org/) for a **kext-free** FUSE mount, so there's
  no kernel extension and no reduced-security mode.
- **`mount.sh` / `unmount.sh`** mount the phone's `media` and `removable_SDCARD` shares under `~/BlackBerry/`.
- **`bb10-put.sh` / `bb10-get.sh`** are one-shot copies with `smbclient` (no mount needed).
- **`bb10-discover.sh`** finds the phone on your network.
- **`install.sh`** does the one-time setup: venv, dependencies, mount points, and the password in the macOS Keychain.

Every script supports `-h` / `--help`.

## Requirements

- macOS on Apple Silicon or Intel, with [Homebrew](https://brew.sh) and Python 3 (Xcode Command Line Tools are enough).
- [fuse-t](https://www.fuse-t.org/): `brew install --cask macos-fuse-t/homebrew-cask/fuse-t` (asks for your admin password).
- Optional, for `bb10-put.sh` / `bb10-get.sh`: `brew install samba` (provides `smbclient`).
- A BlackBerry 10 phone (Z10, Q10, Z30, Passport, Classic, ...) on the same Wi-Fi network, with
  **Settings > Storage and Access > Access Using Wi-Fi** turned on. The Wi-Fi sharing username (default `BlackBerry`)
  and password are set on that same screen.

## Install

```sh
git clone https://github.com/Lyamc/bb10link.git
cd bb10link
./install.sh            # options: -d BASEDIR (default ~/BlackBerry), -u USER, --no-keychain
```

`install.sh` does the following:
1. Checks for fuse-t and prints the brew command if it's missing.
2. Creates `~/BlackBerry/.app/venv`, installs `requirements.txt` and copies `smbfuse.py` there.
3. Creates the mount points `~/BlackBerry/media` and `~/BlackBerry/SDCARD`.
4. Stores the share password in the Keychain. It runs
   `security add-generic-password -a BlackBerry -s bb10-smb -w`, which prompts for the password, so it is never written to a file.

## Usage

```sh
./bb10-discover.sh                       # find the phone, e.g. "192.0.2.10  BLACKBERRY-1A2B  <- BlackBerry"
BB_HOST=192.0.2.10 ./mount.sh            # or: ./mount.sh -H 192.0.2.10
open ~/BlackBerry/media                  # browse / copy with Finder or cp
./unmount.sh
```

Configuration is through flags or environment variables:

| Variable | Flag | Default | Meaning |
|---|---|---|---|
| `BB_HOST` | `-H` | (required) | Phone IP address or name |
| `BB_USER` | `-u` | `BlackBerry` | Share username |
| `BB_DIR` | `-d` | `$HOME/BlackBerry` | Base directory for mount points (app in `$BB_DIR/.app`) |
| `BB_SHARES` | `-s` | `media:media removable_SDCARD:SDCARD` | `SHARE:DIR` pairs to mount |
| `BB_KEYCHAIN_SERVICE` | | `bb10-smb` | Keychain item holding the password |

Copying without mounting:

```sh
BB_HOST=192.0.2.10 ./bb10-put.sh app.apk            # -> media/downloads
BB_HOST=192.0.2.10 ./bb10-get.sh -l camera           # list a directory
BB_HOST=192.0.2.10 ./bb10-get.sh -o ~/Pictures camera/IMG_0001.jpg
```

### Sideloading an Android APK (or a BB10 BAR)
1. On the phone: **Settings > Security and Privacy > Application Permissions**, turn on "Allow apps from other sources
   to be installed". The exact wording varies by OS 10.x version.
2. Copy the file into the phone's `downloads` folder, either with `cp app.apk ~/BlackBerry/media/downloads/` while
   mounted, or with `bb10-put.sh app.apk`.
3. On the phone, open **File Manager > Downloads**, tap the file and choose Install.
   BAR files need the Development Mode tools instead.

### Finding the phone's IP
- `./bb10-discover.sh` scans your /24 for SMB and shows NetBIOS names. BB10 phones appear as `BLACKBERRY-xxxx`.
  Use `-i en0` or `-n 192.0.2` to choose the network.
- On the phone, it's under **Settings > Network Connections > Wi-Fi**: tap the connected network to see its IP address.

## Troubleshooting

- **`mount_smbfs: Authentication error`, or Finder rejects the password.** This is expected: macOS dropped SMB1.
  Use `mount.sh` (FUSE) or `bb10-put.sh` / `bb10-get.sh` (smbclient, NT1) instead.
- **Guest listing works but opening a share says access denied.** Wrong username/password, or Wi-Fi sharing has no
  password set. Re-set it on the phone and update the Keychain item:
  `security delete-generic-password -a BlackBerry -s bb10-smb` then `./install.sh`.
- **Development Mode password.** That is a separate password, used for `blackberry-deploy`. It is not the
  file-sharing password.
- **The mount goes stale after the phone sleeps or its IP changes.** Run `./unmount.sh`, then
  `BB_HOST=<new IP> ./mount.sh`. Keeping the phone on the charger with the screen awake helps for long copies.
  `smbfuse.py` reconnects once on errors.
- **`Phone x:445 not reachable`.** The phone is asleep, Wi-Fi sharing is off, it's on another network, or there's
  client isolation on the access point.
- **USB.** The phone's USB networking address (169.254.x.x) relies on the old BlackBerry USB driver, which doesn't
  load on modern macOS, so use Wi-Fi.
- **Logs.** Each share's log is in `~/BlackBerry/.app/<share>.log`.

## Limitations

- Single-threaded and synchronous. Typical throughput is about 2-3 MB/s over Wi-Fi.
- Writes are buffered: each file is staged in a local temp file and uploaded whole when it's closed.
- Fixed permissions (0644/0755). chmod/chown/utimes are accepted but ignored, and free space is reported as a fixed value.
- macOS metadata files (`._*`, `.DS_Store`) are hidden and never written to the phone.

## License

MIT, see [LICENSE](LICENSE). Dependencies keep their own licenses: pysmb (zlib), fusepy (ISC), fuse-t
(see fuse-t.org) and Samba's smbclient (GPLv3, installed separately).
