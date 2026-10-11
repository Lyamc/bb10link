#!/usr/bin/env python3
"""Userspace SMB1 (NT1) FUSE filesystem for a BlackBerry 10 phone's Wi-Fi file share.

macOS no longer speaks SMB1, which is all BB10 offers. This mounts one share via pysmb (SMB1 client)
and fusepy on top of fuse-t (kext-free FUSE for macOS).

Usage: smbfuse.py HOST SHARE MOUNTPOINT
  env BB_USER              share username (default: BlackBerry)
  env BB_KEYCHAIN_SERVICE  Keychain item holding the password (default: bb10-smb, account = BB_USER)
  env BB_PASSWORD          password (only if you don't want to use the Keychain)
"""
import os, sys, errno, stat, time, tempfile, threading, subprocess, io

if len(sys.argv) != 4 or sys.argv[1] in ("-h", "--help"):
    print(__doc__.strip())
    sys.exit(0 if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help") else 2)

from smb.SMBConnection import SMBConnection
from smb.smb_structs import OperationFailure
from fuse import FUSE, FuseOSError, Operations

HOST, SHARE, MNT = sys.argv[1], sys.argv[2], sys.argv[3]
USER = os.environ.get("BB_USER", "BlackBerry")
SERVICE = os.environ.get("BB_KEYCHAIN_SERVICE", "bb10-smb")
PW = os.environ.get("BB_PASSWORD") or subprocess.check_output(
    ["security", "find-generic-password", "-a", USER, "-s", SERVICE, "-w"]).decode().strip()


class SMBFS(Operations):
    def __init__(self):
        self.lock = threading.RLock(); self.conn = None; self.dirty = {}; self.fh = 0
        self.connect()

    def connect(self):
        c = SMBConnection(USER, PW, "MACFUSE", "BLACKBERRY", use_ntlm_v2=True, is_direct_tcp=True)
        if not c.connect(HOST, 445, timeout=15):
            raise RuntimeError("SMB auth failed")
        self.conn = c

    def call(self, fn, *a):
        with self.lock:
            for i in range(2):
                try:
                    return getattr(self.conn, fn)(SHARE, *a)
                except OperationFailure:
                    raise FuseOSError(errno.ENOENT)
                except Exception:
                    if i:
                        raise FuseOSError(errno.EIO)
                    self.connect()   # phone dropped the session (sleep / Wi-Fi blip): reconnect once

    def _attr(self, f):
        mode = (stat.S_IFDIR | 0o755) if f.isDirectory else (stat.S_IFREG | 0o644)
        return dict(st_mode=mode, st_size=f.file_size, st_mtime=f.last_write_time, st_atime=f.last_access_time,
                    st_ctime=f.create_time, st_nlink=2 if f.isDirectory else 1, st_uid=os.getuid(), st_gid=os.getgid())

    def getattr(self, path, fh=None):
        if path in self.dirty:
            f = self.dirty[path]; f.seek(0, 2); now = time.time()
            return dict(st_mode=stat.S_IFREG | 0o644, st_size=f.tell(), st_mtime=now, st_atime=now, st_ctime=now,
                        st_nlink=1, st_uid=os.getuid(), st_gid=os.getgid())
        if path == "/":
            return dict(st_mode=stat.S_IFDIR | 0o755, st_nlink=2, st_uid=os.getuid(), st_gid=os.getgid(), st_mtime=time.time())
        name = os.path.basename(path)
        if name.startswith("._") or name == ".DS_Store":   # keep Finder metadata off the phone
            raise FuseOSError(errno.ENOENT)
        return self._attr(self.call("getAttributes", path))

    def readdir(self, path, fh):
        return [".", ".."] + [f.filename for f in self.call("listPath", path) if f.filename not in (".", "..")]

    def open(self, path, flags):
        self.fh += 1; return self.fh

    def create(self, path, mode, fi=None):
        self.dirty[path] = tempfile.TemporaryFile(); self.flush(path, 0); self.fh += 1; return self.fh

    def read(self, path, size, offset, fh):
        if path in self.dirty:
            f = self.dirty[path]; f.seek(offset); return f.read(size)
        buf = io.BytesIO()
        with self.lock:
            try:
                self.conn.retrieveFileFromOffset(SHARE, path, buf, offset, size)
            except Exception:
                self.connect(); self.conn.retrieveFileFromOffset(SHARE, path, buf, offset, size)
        return buf.getvalue()

    def _load(self, path):
        # writes are buffered in a local temp file and uploaded whole on flush/close
        if path not in self.dirty:
            t = tempfile.TemporaryFile()
            with self.lock:
                self.conn.retrieveFile(SHARE, path, t)
            self.dirty[path] = t
        return self.dirty[path]

    def write(self, path, data, offset, fh):
        f = self._load(path); f.seek(offset); f.write(data); return len(data)

    def truncate(self, path, length, fh=None):
        f = self._load(path); f.truncate(length); self.flush(path, fh)

    def flush(self, path, fh):
        f = self.dirty.get(path)
        if f is not None:
            f.seek(0)
            with self.lock:
                self.conn.storeFile(SHARE, path, f)

    def release(self, path, fh):
        f = self.dirty.pop(path, None)
        if f is not None:
            f.seek(0)
            with self.lock:
                self.conn.storeFile(SHARE, path, f)
            f.close()

    def fsync(self, path, ds, fh): self.flush(path, fh)
    def unlink(self, path): self.call("deleteFiles", path)
    def mkdir(self, path, mode): self.call("createDirectory", path)
    def rmdir(self, path): self.call("deleteDirectory", path)
    def rename(self, old, new): self.call("rename", old, new)
    def chmod(self, path, mode): return 0
    def chown(self, path, uid, gid): return 0
    def utimens(self, path, times=None): return 0

    def statfs(self, path):
        # SMB1 free-space query isn't exposed by pysmb: report fixed values
        return dict(f_bsize=4096, f_frsize=4096, f_blocks=1 << 24, f_bfree=1 << 23, f_bavail=1 << 23, f_namemax=255)


if __name__ == "__main__":
    FUSE(SMBFS(), MNT, foreground=True, nothreads=True, volname=f"BB10-{SHARE}", fsname=f"//{HOST}/{SHARE}")
