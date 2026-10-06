# Zed Tabs Helper

A small macOS menu bar helper that automates the `use_system_window_tabs: false → true` workaround for Zed. It also disables system tabs before a normal quit, so Zed can restore the open projects on the next launch.

Built for [zed-industries/zed#49724](https://github.com/zed-industries/zed/issues/49724) and the related [restart issue #44042](https://github.com/zed-industries/zed/issues/44042). This is an unofficial workaround, not a fix in Zed itself.

## What it does

- Watches for Zed to start, toggles system tabs, and requests **Window → Merge All Windows** when Zed is in the foreground.
- Enables Zed's quit confirmation. When you choose Quit or press Cmd+Q, the helper recognizes that exact confirmation, disables system tabs, waits briefly, and presses Quit for you.
- Leaves system tabs disabled while Zed is closed and sets `restore_on_startup` to `last_session`.
- Can run at login and adds a small `Z↔` menu bar item. No separate launch or quit scripts to click.

It never confirms Save/Discard dialogs. It does not read your source files, edit Zed's database, or make network requests. Accessibility access is used to inspect Zed's windows and operate its quit confirmation and Window menu.

## Requirements

- macOS and the stable Zed app (`dev.zed.Zed`).
- English Zed menu and dialog labels.
- For building from source only: Xcode Command Line Tools with a recent Swift compiler, plus Python 3 for installation.
- Zed settings at `~/.config/zed/settings.json`.

The normal quit/relaunch workaround was tested locally with Zed 1.22.0. Startup timings depend on the machine and project; this has not been tested across all macOS or Zed versions.

## Download the app

Download [Zed Tabs Helper 0.1.0 for Apple Silicon and Intel](https://github.com/awicone/zed-tabs-helper/raw/refs/heads/main/downloads/Zed-Tabs-Helper-0.1.0-universal.zip). The SHA-256 checksum is in [downloads/SHA256SUMS.txt](downloads/SHA256SUMS.txt). No compiler or Python is needed. Follow the included [quick-start guide](QUICKSTART.md) to install it, grant Accessibility access, and enable login startup. The app is ad-hoc signed, not Apple-notarized.

## Install from source

Clone this repository, then build and install:

```sh
git clone https://github.com/awicone/zed-tabs-helper.git
cd zed-tabs-helper
chmod +x build.sh
./build.sh
python3 install.py
```

No `sudo` is needed. `build.sh` compiles the included Swift source without downloading dependencies. The app is locally ad-hoc signed, not notarized by Apple.

Then enable **Zed Tabs Helper** in **System Settings → Privacy & Security → Accessibility**. The helper waits without changing settings until access is granted. macOS may ask again after a rebuild.

Open each repository in a separate Zed window. After installation, allow a few seconds for the first merge. From then on, use your usual Zed icon and Quit command.

## Menu

- **Allow Accessibility Access…** requests the required macOS permission.
- **Retry Merging Windows** repeats the startup workaround.
- **Stop Helper** disables tabs and quit confirmation, then exits the helper. It will run again at the next login; uninstall it to remove login startup.

`Z↔!` means Accessibility access is missing or the helper encountered an error. Check the local log below.

## Files and settings

Installed files:

```text
~/Applications/Zed Tabs Helper.app
~/Library/LaunchAgents/local.zed-tabs-helper.plist
~/Library/Application Support/Zed Tabs Helper/
```

An update preserves the existing app's bundle ID and launch-agent filename.

The helper changes only these top-level settings in Zed's `settings.json`:

```json
{
  "restore_on_startup": "last_session",
  "confirm_quit": true,
  "use_system_window_tabs": true
}
```

`use_system_window_tabs` changes during startup and exit. Other fields and JSONC comments are preserved. The first settings snapshot is stored as `settings.original.json` in the helper's support directory. `helper.log` contains lifecycle events and errors; it is not uploaded anywhere.

## Limitations

- This uses UI automation and timed settings changes. A future Zed update may change the behavior or labels.
- The quit confirmation may briefly appear before the helper handles it. Only the exact **“Are you sure you want to quit?”** dialog with a **Quit** button is handled.
- Force Quit, crashes, shutdown, and closing the last window are not guaranteed to preserve the session. Use normal Quit with the project windows still open.
- Automatic merging happens after startup and only while Zed is in the foreground. For windows opened later, use **Retry Merging Windows**.
- The helper cannot recover a session Zed has already lost or keep terminal processes alive after quitting.
- It does not change Git state or merge repositories. It merges macOS windows into tabs.

Default delays: 1.5 seconds after detecting Zed, 0.6 seconds between settings changes, 0.6 seconds before merging, and 0.8 seconds before confirming quit. Detection runs every 0.2 seconds. If your system needs more time, these values are in `main.swift`.

## Accessibility after an update

Rebuilding an ad-hoc signed app can invalidate its previous Accessibility permission even if System Settings still shows the switch enabled. This occurred during local testing after an update.

If the helper shows `Z↔!`, remove its entry from **System Settings → Privacy & Security → Accessibility**, add the current app from `~/Applications/Zed Tabs Helper.app`, and enable it again. You may also need to restart the helper. The original normal-quit/relaunch flow worked locally; permission renewal after rebuilds is still a known rough edge.

**Retry Merging Windows** does nothing while Accessibility permission is missing. If settings already show `use_system_window_tabs: false`, the Window menu may not offer merging until access is restored and the helper finishes toggling the setting.

## Uninstall

From the source folder:

```sh
python3 uninstall.py
```

This stops the login agent, disables system tabs and quit confirmation, and moves the app and launch-agent file to Trash. It leaves `restore_on_startup: last_session` enabled and keeps the settings backup and logs. You can restore your preferred settings manually from the backup without overwriting later edits.

## Checks

```sh
./ZedTabsHelper --self-test
./ZedTabsHelper --probe
```

The self-test checks settings editing on sample strings without touching your configuration. The probe reports Accessibility permission and whether Zed is running. A complete UI test still requires trying Quit and relaunch with real Zed windows.

## Build a release

Run `python3 package.py 0.1.0` on macOS to build and verify a universal app archive in `dist/`. The script does not install or launch the helper UI. The included GitHub Actions workflow is configured to publish version tags in Releases. The first tag did not start a run, so the verified local build is provided in `downloads/` until automated publishing is confirmed. Update `RELEASE_NOTES.md` before tagging a new version.

## License

MIT. Not affiliated with Zed Industries.
