# Zed Tabs Helper — quick start

An unofficial workaround for Zed's macOS window-tab restoration issues.
The helper toggles system tabs after launch, merges project windows, and prepares
Zed's settings before a normal quit so the next session can restore.

## Install the ready-made app

1. Unzip the download and move **Zed Tabs Helper.app** to your Applications folder.
2. Open it. This release is ad-hoc signed, without Apple notarization. If macOS
   blocks it, use **System Settings → Privacy & Security → Open Anyway** after
   attempting to open it, then confirm. Only do this for a download you trust.
3. Enable the app under **Privacy & Security → Accessibility**. The menu bar item
   is `Z↔`; `Z↔!` indicates missing permission or an error.
4. To start it at login, add the app to **System Settings → General → Login Items
   (or Login Items & Extensions) → Open at Login**.
5. Open your projects in separate Zed windows, then bring Zed to the foreground.
   Allow a few seconds for the first merge. Use normal Quit (Cmd+Q) with project
   windows still open when you finish.

No compiler, Python, or Terminal is needed for this installation.

## Requirements and limitations

- Universal app: Apple Silicon and Intel; built for macOS 13 or later.
- Stable Zed, English menu/dialog labels, settings at `~/.config/zed/settings.json`.
- The original quit/relaunch flow was tested on Apple Silicon with Zed 1.22.0.
  Intel and older macOS versions have not been tested interactively.
- Force Quit, crashes, shutdown, or closing the last window may lose the session.
- The helper changes `restore_on_startup`, `confirm_quit`, and
  `use_system_window_tabs`. It preserves unrelated settings and saves the first
  settings snapshot in `~/Library/Application Support/Zed Tabs Helper/`.
- It makes no network requests and does not read project source files.
- After an update, Accessibility can show enabled but be stale. Stop the helper,
  remove its old Accessibility entry, add the installed app again, then relaunch.

For windows opened later, choose **Z↔ → Retry Merging Windows**.
To uninstall this manual installation, choose **Stop Helper**, remove the Login
Item, and move the app to Trash. Stop Helper disables system tabs and quit
confirmation; `restore_on_startup: last_session` and the backup remain.

If you previously installed from source using `install.py`, use that source
installation's `uninstall.py` before switching to this manual installation, so
its LaunchAgent does not start a second helper.

Source, full documentation, and updates:
https://github.com/awicone/zed-tabs-helper
