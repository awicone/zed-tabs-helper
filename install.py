import os
import plistlib
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent
home = Path.home()
app = home / 'Applications/Zed Tabs Helper.app'
support = home / 'Library/Application Support/Zed Tabs Helper'
label = 'local.zed-tabs-helper'
# Preserve the identity of an existing installation, including Accessibility access.
existing_info = app / 'Contents/Info.plist'
if existing_info.exists():
    label = plistlib.loads(existing_info.read_bytes())['CFBundleIdentifier']
agent = home / 'Library/LaunchAgents' / (label + '.plist')
uid = os.getuid()
if not (root / 'ZedTabsHelper').is_file():
    raise SystemExit('Build the app first: ./build.sh')
subprocess.run([str(root / 'ZedTabsHelper'), '--self-test'], check=True)
subprocess.run(['/bin/launchctl', 'bootout', f'gui/{uid}/{label}'], capture_output=True)
support.mkdir(parents=True, exist_ok=True)
(app / 'Contents/MacOS').mkdir(parents=True, exist_ok=True)
shutil.copy2(root / 'ZedTabsHelper', app / 'Contents/MacOS/ZedTabsHelper')
shutil.copy2(root / 'main.swift', support / 'main.swift')
info = {
    'CFBundleIdentifier': label,
    'CFBundleName': 'Zed Tabs Helper',
    'CFBundleDisplayName': 'Zed Tabs Helper',
    'CFBundleExecutable': 'ZedTabsHelper',
    'CFBundlePackageType': 'APPL',
    'CFBundleVersion': '2',
    'CFBundleShortVersionString': '0.1.0',
    'LSUIElement': True,
    'NSHighResolutionCapable': True,
}
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['/usr/bin/codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
agent.parent.mkdir(parents=True, exist_ok=True)
agent.write_bytes(plistlib.dumps({
    'Label': label,
    'ProgramArguments': [str(app / 'Contents/MacOS/ZedTabsHelper')],
    'RunAtLoad': True,
    'ProcessType': 'Interactive',
    'StandardOutPath': str(support / 'helper.log'),
    'StandardErrorPath': str(support / 'helper.log'),
}))
subprocess.run(['/bin/launchctl', 'bootstrap', f'gui/{uid}', str(agent)], check=True)
print(f'Installed: {app}')
print(f'Login startup: {agent}')
print(f'Log: {support / "helper.log"}')
