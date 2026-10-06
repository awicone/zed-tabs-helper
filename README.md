# Zed Tabs Helper

For anyone who needs project tabs badly enough to try a slightly ridiculous workaround like this one :)

A tiny macOS menu bar app for [Zed's window tabs bug](https://github.com/zed-industries/zed/issues/49724). It does the `use_system_window_tabs: false → true` dance and merges your windows after launch. Before a normal quit, it disables tabs again so Zed can restore your projects next time.

## Download

**[Download the app — Apple Silicon + Intel](https://github.com/awicone/zed-tabs-helper/raw/refs/heads/main/downloads/Zed-Tabs-Helper-0.1.0-universal.zip)** · [Checksum](downloads/SHA256SUMS.txt)

No Xcode, Python, or Terminal needed.

1. Unzip and move **Zed Tabs Helper.app** to Applications.
2. Open it and allow **Accessibility** in System Settings. It's not Apple-notarized, so you may need **Privacy & Security → Open Anyway** first.
3. Add it to **General → Login Items → Open at Login** if you want it to start automatically.
4. Open your projects in Zed and give it a few seconds. Quit with **Cmd+Q**, leaving the project windows open.

## A few catches

- macOS 13+, stable Zed, English menus. Tested on Apple Silicon with Zed 1.22.0; Intel hasn't been tested interactively.
- This is a workaround. Force Quit, crashes, and closing the last window may still lose the session.
- It changes `use_system_window_tabs`, `confirm_quit`, and `restore_on_startup` in `~/.config/zed/settings.json`. The first settings backup is saved in `~/Library/Application Support/Zed Tabs Helper/`. No network requests or project-file access.
- `Z↔!` usually means missing Accessibility access. After an update, you may need to remove and re-add the app there, then restart it.
- Opened more windows? Click **Z↔ → Retry Merging Windows** with Zed in the foreground.

To remove it: **Stop Helper**, remove the Login Item, trash the app. [More installation details](QUICKSTART.md), including switching from an older source installation.

## Build it yourself

Requires Swift Command Line Tools and Python 3. From a clone of this repo:

```sh
./build.sh
python3 install.py
```

That installer adds login startup automatically; undo it with `python3 uninstall.py`. To package a universal ZIP: `python3 package.py 0.1.0`.

MIT. Unofficial, not affiliated with Zed.
