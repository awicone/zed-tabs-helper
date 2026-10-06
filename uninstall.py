"""Stop the helper and move its app and login item to Trash; keep settings backups."""
import os
import plistlib
import subprocess
from datetime import datetime
from pathlib import Path

home = Path.home()
app = home / 'Applications/Zed Tabs Helper.app'
info = app / 'Contents/Info.plist'
if not info.exists():
    raise SystemExit('Zed Tabs Helper is not installed in ~/Applications.')
label = plistlib.loads(info.read_bytes())['CFBundleIdentifier']
agent = home / 'Library/LaunchAgents' / (label + '.plist')
subprocess.run(['/bin/launchctl', 'bootout', f'gui/{os.getuid()}/{label}'], capture_output=True)
subprocess.run([str(app / 'Contents/MacOS/ZedTabsHelper'), '--disable-helper'], check=True)
trash = home / '.Trash'
trash.mkdir(exist_ok=True)
stamp = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
for path in (app, agent):
    if path.exists():
        path.rename(trash / f'{path.name}-{stamp}')
print('Helper stopped. App and login item moved to Trash.')
print('Zed now uses separate windows with confirm_quit disabled.')
print('Settings backup and logs remain in ~/Library/Application Support/Zed Tabs Helper/.')
