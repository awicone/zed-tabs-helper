"""Build a universal macOS app and a downloadable ZIP, without installing it."""
import hashlib
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
version = sys.argv[1] if len(sys.argv) == 2 else ''
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('Usage: python3 package.py MAJOR.MINOR.PATCH')

build = root / '.build' / 'release'
dist = root / 'dist'
staging = build / 'staging'
if staging.exists():
    shutil.rmtree(staging)
build.mkdir(parents=True, exist_ok=True)
dist.mkdir(exist_ok=True)
app = staging / 'Zed Tabs Helper.app'
macos = app / 'Contents' / 'MacOS'
macos.mkdir(parents=True)

# Compile both slices explicitly so the archive works on Intel and Apple Silicon.
slices = []
for arch in ('arm64', 'x86_64'):
    binary = build / f'ZedTabsHelper-{arch}'
    subprocess.run([
        'xcrun', 'swiftc', '-O', '-target', f'{arch}-apple-macosx13.0',
        '-module-cache-path', str(build / 'module-cache'),
        str(root / 'main.swift'), '-o', str(binary),
    ], check=True)
    slices.append(str(binary))
binary = macos / 'ZedTabsHelper'
subprocess.run(['xcrun', 'lipo', '-create', *slices, '-output', str(binary)], check=True)
(app / 'Contents' / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'local.zed-tabs-helper',
    'CFBundleName': 'Zed Tabs Helper',
    'CFBundleDisplayName': 'Zed Tabs Helper',
    'CFBundleExecutable': 'ZedTabsHelper',
    'CFBundlePackageType': 'APPL',
    'CFBundleVersion': version,
    'CFBundleShortVersionString': version,
    'LSMinimumSystemVersion': '13.0',
    'LSUIElement': True,
    'NSHighResolutionCapable': True,
}))
# Ad-hoc signing makes the bundle internally consistent; it is not notarization.
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
subprocess.run(['codesign', '--verify', '--strict', '--verbose=2', str(app)], check=True)
subprocess.run(['xcrun', 'lipo', str(binary), '-verify_arch', 'arm64', 'x86_64'], check=True)
subprocess.run([str(binary), '--self-test'], check=True)
shutil.copy2(root / 'QUICKSTART.md', staging / 'READ ME.md')
shutil.copy2(root / 'LICENSE', staging / 'LICENSE')
archive = dist / f'Zed-Tabs-Helper-{version}-universal.zip'
if archive.exists():
    archive.unlink()
# ditto preserves executable permissions and the macOS app bundle structure.
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', str(staging), str(archive)], check=True)
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(dist / 'SHA256SUMS.txt').write_text(f'{checksum}  {archive.name}\n')
print(f'Created {archive}')
