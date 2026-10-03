"""Remove only a proven inactive empty index.lock under the shared Git mutex."""
import ctypes
from ctypes import wintypes
import os
import hashlib
import subprocess
import psutil
import produce as p
from creature_animation_lock import exclusive

os.environ['GIT_OPTIONAL_LOCKS'] = '0'

def inactive():
    names = {'git', 'git.exe', 'git-remote-https.exe', 'git-remote-http.exe'}
    active = [(proc.info['pid'], proc.info['name']) for proc in psutil.process_iter(['pid', 'name']) if (proc.info['name'] or '').lower() in names]
    assert not active, active

with exclusive('git'):
    assert subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=p.ROOT).strip() == b''
    index = p.ROOT / '.git/index'
    before = hashlib.sha256(index.read_bytes()).hexdigest()
    lock = (p.ROOT / '.git/index.lock').resolve()
    assert lock == (p.ROOT.resolve() / '.git/index.lock') and lock.is_file() and not lock.is_symlink()
    assert lock.stat().st_size == 0
    inactive()
    api = ctypes.WinDLL('kernel32', use_last_error=True)
    api.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    api.CreateFileW.restype = wintypes.HANDLE
    api.GetFileSizeEx.argtypes = [wintypes.HANDLE, ctypes.POINTER(ctypes.c_longlong)]
    api.SetFileInformationByHandle.argtypes = [wintypes.HANDLE, ctypes.c_int, wintypes.LPVOID, wintypes.DWORD]
    api.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = api.CreateFileW(str(lock), 0x80000000 | 0x00010000, 0, None, 3, 128, None)
    assert handle != ctypes.c_void_p(-1).value, ctypes.get_last_error()
    try:
        size = ctypes.c_longlong()
        assert api.GetFileSizeEx(handle, ctypes.byref(size)) and size.value == 0
        inactive()
        assert hashlib.sha256(index.read_bytes()).hexdigest() == before
        disposition = wintypes.BOOLEAN(1)
        assert api.SetFileInformationByHandle(handle, 4, ctypes.byref(disposition), ctypes.sizeof(disposition)), ctypes.get_last_error()
    finally:
        assert api.CloseHandle(handle)
    assert not lock.exists()
    assert hashlib.sha256(index.read_bytes()).hexdigest() == before
    print('REMOVED_ONLY_EMPTY_STALE_LOCK_EXCLUSIVE_HANDLE_INDEX_UNCHANGED', before, flush=True)
