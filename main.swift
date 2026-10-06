import AppKit
import ApplicationServices

let manager = FileManager.default
let support = manager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Zed Tabs Helper")
let settings = manager.homeDirectoryForCurrentUser.appendingPathComponent(".config/zed/settings.json")
let zedID = "dev.zed.Zed"

func log(_ message: String) {
    print("\(ISO8601DateFormatter().string(from: Date())) \(message)")
    fflush(stdout)
}

// Modify only top-level scalar settings, preserving JSONC comments and unrelated fields.
func replacing(_ input: String, key: String, value: String) throws -> String {
    let bytes = Array(input.utf8)
    var i = 0, depth = 0
    var opening: Int?
    var matches: [Range<Int>] = []
    while i < bytes.count {
        if bytes[i] == 47 && i + 1 < bytes.count {
            if bytes[i+1] == 47 {
                while i < bytes.count && bytes[i] != 10 { i += 1 }
                continue
            }
            if bytes[i+1] == 42 {
                i += 2
                while i + 1 < bytes.count && !(bytes[i] == 42 && bytes[i+1] == 47) { i += 1 }
                i += 2; continue
            }
        }
        if bytes[i] == 123 { if opening == nil { opening = i }; depth += 1; i += 1; continue }
        if bytes[i] == 125 { depth -= 1; i += 1; continue }
        if bytes[i] == 34 {
            let start = i
            i += 1
            while i < bytes.count {
                if bytes[i] == 92 { i += 2; continue }
                if bytes[i] == 34 { break }
                i += 1
            }
            let end = i; i += 1
            if depth != 1 { continue }
            let name = String(decoding: bytes[(start+1)..<end], as: UTF8.self)
            var j = i
            while j < bytes.count && [9,10,13,32].contains(bytes[j]) { j += 1 }
            if name != key || j >= bytes.count || bytes[j] != 58 { continue }
            j += 1
            while j < bytes.count && [9,10,13,32].contains(bytes[j]) { j += 1 }
            let valueStart = j
            if j < bytes.count && bytes[j] == 34 {
                j += 1
                while j < bytes.count {
                    if bytes[j] == 92 { j += 2; continue }
                    if bytes[j] == 34 { j += 1; break }
                    j += 1
                }
            } else {
                while j < bytes.count && ![9,10,13,32,44,125,47].contains(bytes[j]) { j += 1 }
            }
            matches.append(valueStart..<j)
            i = j
        } else { i += 1 }
    }
    guard matches.count <= 1, let open = opening else {
        throw NSError(domain: "Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ambiguous settings; refusing to edit"])
    }
    var result = bytes
    if let range = matches.first { result.replaceSubrange(range, with: value.utf8) }
    else {
        let rest = String(decoding: bytes[(open+1)...], as: UTF8.self)
        let empty = rest.trimmingCharacters(in: .whitespacesAndNewlines) == "}"
        result.insert(contentsOf: Array("\n  \"\(key)\": \(value)\(empty ? "" : ",")\n".utf8), at: open+1)
    }
    return String(decoding: result, as: UTF8.self)
}

func update(_ values: [(String, String)]) throws {
    let original = try String(contentsOf: settings, encoding: .utf8)
    var edited = original
    for (key, value) in values { edited = try replacing(edited, key: key, value: value) }
    guard edited != original else { return }
    // Do not overwrite a concurrent edit from Zed or another process.
    guard try String(contentsOf: settings, encoding: .utf8) == original else {
        throw NSError(domain: "Settings", code: 2, userInfo: [NSLocalizedDescriptionKey: "Settings changed concurrently; retry later"])
    }
    let backup = support.appendingPathComponent("settings.original.json")
    if !manager.fileExists(atPath: backup.path) { try original.write(to: backup, atomically: true, encoding: .utf8) }
    try edited.write(to: settings, atomically: true, encoding: .utf8)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}
func elements(_ element: AXUIElement, _ name: String = "AXChildren") -> [AXUIElement] {
    attribute(element, name) as? [AXUIElement] ?? []
}
func text(_ element: AXUIElement, _ name: String) -> String { attribute(element, name) as? String ?? "" }
func descendants(_ root: AXUIElement, limit: Int = 150) -> [AXUIElement] {
    var queue = [root], index = 0
    while index < queue.count && queue.count < limit {
        queue.append(contentsOf: elements(queue[index])); index += 1
    }
    return Array(queue.prefix(limit))
}
func quitButton(_ application: AXUIElement) -> AXUIElement? {
    // Match the native quit sheet by its full message and button label. A generic
    // "Quit" search could accidentally act on an unrelated dialog or menu.
    for window in elements(application, "AXWindows") {
        var candidates = elements(window, "AXSheets")
        if ["AXDialog", "AXSystemDialog"].contains(text(window, "AXSubrole")) { candidates.append(window) }
        candidates += elements(window).filter { text($0, "AXRole") == "AXSheet" }
        for candidate in candidates {
            let nodes = descendants(candidate)
            let exactPrompt = nodes.contains {
                text($0, "AXValue") == "Are you sure you want to quit?" || text($0, "AXTitle") == "Are you sure you want to quit?"
            }
            guard exactPrompt else { continue }
            return nodes.first { text($0, "AXRole") == "AXButton" && text($0, "AXTitle") == "Quit" }
        }
    }
    return nil
}
func mergeWindows(_ application: AXUIElement) -> Bool {
    guard let raw = attribute(application, "AXMenuBar"), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return false }
    let bar = unsafeBitCast(raw, to: AXUIElement.self)
    guard let windowMenu = elements(bar).first(where: { text($0, "AXTitle") == "Window" }) else { return false }
    guard let item = descendants(windowMenu).first(where: { text($0, "AXTitle") == "Merge All Windows" }) else { return false }
    guard (attribute(item, "AXEnabled") as? Bool) == true else { return false }
    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
}

final class Helper: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var timer: Timer?
    var pid: pid_t?
    var started = Date()
    // Startup phases: 0 = wait for restoration, 1 = tabs disabled,
    // 2 = tabs enabled / waiting to merge, 3 = startup work finished.
    var phase = 0
    var quitting = false
    var quitDeadline = Date.distantPast
    var failed = false
    var merges = 0
    var lastMerge = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? manager.createDirectory(at: support, withIntermediateDirectories: true)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "Z↔"
        let menu = NSMenu()
        menu.addItem(withTitle: "Zed Tabs Helper", action: nil, keyEquivalent: "")
        let permission = menu.addItem(withTitle: "Allow Accessibility Access…", action: #selector(permissions), keyEquivalent: "")
        permission.target = self
        let repair = menu.addItem(withTitle: "Retry Merging Windows", action: #selector(repair), keyEquivalent: "")
        repair.target = self
        menu.addItem(NSMenuItem.separator())
        let stop = menu.addItem(withTitle: "Stop Helper", action: #selector(stop), keyEquivalent: "")
        stop.target = self
        status.menu = menu
        permissions()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }
    @objc func permissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    @objc func repair() { phase = 0; started = Date().addingTimeInterval(-7); merges = 0; quitting = false; failed = false }
    @objc func stop() {
        // Leave a safe, restorable separate-window configuration when stopping.
        try? update([("use_system_window_tabs", "false"), ("confirm_quit", "false")])
        NSApp.terminate(nil)
    }
    func tick() {
        // Permission may be granted while the helper is already running. Wait
        // without changing settings until Accessibility access is available.
        guard AXIsProcessTrusted() else { status.button?.title = "Z↔!"; return }
        status.button?.title = failed ? "Z↔!" : "Z↔"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: zedID).first
        guard let running, !running.isTerminated else {
            if pid != nil {
                log("Zed exited")
                pid = nil; phase = 0; quitting = false
            }
            // This runs only while Zed is closed, before its next normal startup.
            do { try update([("use_system_window_tabs", "false"), ("restore_on_startup", "\"last_session\""), ("confirm_quit", "true")]) }
            catch { if !failed { log("Settings error: \(error)") }; failed = true }
            return
        }
        if pid != running.processIdentifier {
            pid = running.processIdentifier; started = Date(); phase = 0; quitting = false; merges = 0; failed = false
            do { try update([("confirm_quit", "true"), ("restore_on_startup", "\"last_session\"")]) }
            catch { log("Cannot configure Zed: \(error)"); failed = true; return }
            log("Detected Zed launch")
        }
        let application = AXUIElementCreateApplication(running.processIdentifier)
        if quitting {
            if Date() >= quitDeadline {
                if let button = quitButton(application) {
                    // Only the exact quit confirmation; never Save/Discard dialogs.
                    let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
                    log("Confirmed requested quit: \(result.rawValue)")
                }
                quitting = false
                // If the user cancels saving afterward, restore tabs later.
                phase = 0; started = Date(); merges = 0
            }
            return
        }
        if quitButton(application) != nil {
            // Keep Zed alive at its confirmation sheet while it reloads the
            // disabled-tabs setting; toggling it after termination is too late.
            do {
                try update([("use_system_window_tabs", "false")])
                quitting = true; quitDeadline = Date().addingTimeInterval(0.8)
                log("Quit requested; disabling tabs before confirmation")
            } catch { log("Cannot prepare quit: \(error)"); failed = true }
            return
        }
        if failed { return }
        let elapsed = Date().timeIntervalSince(started)
        do {
            if phase == 0 && elapsed >= 1.5 {
                try update([("use_system_window_tabs", "false")]); phase = 1; started = Date()
            } else if phase == 1 && elapsed >= 0.6 {
                try update([("use_system_window_tabs", "true")]); phase = 2; started = Date()
                log("Tabs re-enabled")
            } else if phase == 2 && elapsed >= 0.6 && merges < 3 && Date().timeIntervalSince(lastMerge) > 1 {
                // Wait for the user to return to Zed instead of stealing focus.
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                if mergeWindows(application) { log("Requested Merge All Windows"); phase = 3 }
                lastMerge = Date(); merges += 1
                if merges >= 3 && phase != 3 { log("Merge unavailable; use Window > Merge All Windows if needed"); phase = 3 }
            }
        } catch { log("Settings error: \(error)"); failed = true }
    }
}

if CommandLine.arguments.contains("--self-test") {
    let sample = "{\n // hi\n \"nested\": {\"confirm_quit\": false},\n \"use_system_window_tabs\": true, // tabs\n \"label\": \"Hello 🌍\"\n}\n"
    let disabled = try replacing(sample, key: "use_system_window_tabs", value: "false")
    let restored = try replacing(disabled, key: "use_system_window_tabs", value: "true")
    precondition(restored == sample)
    let added = try replacing(sample, key: "confirm_quit", value: "true")
    precondition(added.contains("\"confirm_quit\": true") && added.contains("\"confirm_quit\": false"))
    let empty = try replacing("{}", key: "confirm_quit", value: "true")
    _ = try JSONSerialization.jsonObject(with: Data(empty.utf8))
    do { _ = try replacing("{\"confirm_quit\":true,\"confirm_quit\":false}", key: "confirm_quit", value: "true"); fatalError("duplicate key accepted") } catch { }
    print("Settings tests passed")
} else if CommandLine.arguments.contains("--disable-helper") {
    try update([("use_system_window_tabs", "false"), ("confirm_quit", "false")])
    print("Helper settings disabled; Zed will use separate windows.")
} else if CommandLine.arguments.contains("--probe") {
    print("accessibility=\(AXIsProcessTrusted()) zed_running=\(NSRunningApplication.runningApplications(withBundleIdentifier: zedID).count)")
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let helper = Helper()
    app.delegate = helper
    app.run()
}
