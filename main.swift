import AppKit
import ServiceManagement

struct Device: Decodable, Equatable {
    let udid: String
    let name: String
    let deviceTypeIdentifier: String?

    var symbolName: String {
        deviceTypeIdentifier?.contains("iPad") == true ? "ipad" : "iphone.gen3"
    }
}

struct SimctlError: LocalizedError {
    let errorDescription: String?
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let slowMotionKey = "com.apple.UIKit.SimulatorSlowMotionAnimationState"
    private static let locations: [(name: String, coordinate: String)] = [
        ("Dubai", "25.1972,55.2744"),
        ("Abu Dhabi", "24.4539,54.3773"),
        ("London", "51.5074,-0.1278"),
        ("New York", "40.7580,-73.9855"),
        ("Cupertino", "37.3349,-122.0090"),
    ]

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let defaults = UserDefaults.standard
    private var devices: [Device] = []
    private var device: Device?
    private var slowMotion: Bool?
    private var isRefreshing = false
    private var locationByDevice: [String: String] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: "SimTools")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "SimTools"
        menu.delegate = self
        statusItem.menu = menu
        refresh()
    }

    // MARK: - Menu

    // simctl takes ~500 ms, so the menu opens from cached state and updates in place once fresh state arrives.
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
        refresh()
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let selected = defaults.string(forKey: "selectedDevice")
        DispatchQueue.global().async {
            let devices = self.bootedDevices()
            let slowMotion = (devices.first { $0.udid == selected } ?? devices.first).flatMap(self.isSlowMotionOn)
            DispatchQueue.main.async {
                self.isRefreshing = false
                guard devices != self.devices || slowMotion != self.slowMotion else { return }
                self.devices = devices
                self.slowMotion = slowMotion
                self.rebuildMenu()
            }
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        device = devices.first { $0.udid == defaults.string(forKey: "selectedDevice") } ?? devices.first

        menu.addItem(deviceItem(devices))
        menu.addItem(.separator())

        addItem("Shake", symbol: "iphone.gen3.radiowaves.left.and.right", action: #selector(shake))
        addItem("Slow Animations", symbol: "tortoise", action: #selector(toggleSlowMotion)).state = slowMotion == true ? .on : .off
        addItem("Open URL…", symbol: "link", action: #selector(openURL))
        menu.addItem(locationItem())
        menu.addItem(.separator())

        addItem("Launch at Login", symbol: "power", action: #selector(toggleLaunchAtLogin), needsDevice: false).state =
            SMAppService.mainApp.status == .enabled ? .on : .off
        let quit = menu.addItem(withTitle: "Quit SimTools", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "xmark.square", accessibilityDescription: nil)
    }

    @discardableResult
    private func addItem(_ title: String, symbol: String, action: Selector, needsDevice: Bool = true, to menu: NSMenu? = nil) -> NSMenuItem {
        let item = (menu ?? self.menu).addItem(withTitle: title, action: needsDevice && device == nil ? nil : action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    private func deviceItem(_ devices: [Device]) -> NSMenuItem {
        let item = NSMenuItem(title: device?.name ?? "No Booted Simulator", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: device?.symbolName ?? "iphone.slash", accessibilityDescription: nil)
        guard !devices.isEmpty else { return item }

        let submenu = NSMenu()
        for candidate in devices {
            let option = submenu.addItem(withTitle: candidate.name, action: #selector(selectDevice(_:)), keyEquivalent: "")
            option.target = self
            option.image = NSImage(systemSymbolName: candidate.symbolName, accessibilityDescription: nil)
            option.representedObject = candidate.udid
            option.state = candidate.udid == device?.udid ? .on : .off
        }
        item.submenu = submenu
        return item
    }

    private func locationItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Location", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "location", accessibilityDescription: nil)
        guard let device else { return item }

        let submenu = NSMenu()
        let current = locationByDevice[device.udid]
        for location in Self.locations {
            let option = addItem(location.name, symbol: "mappin.and.ellipse", action: #selector(setLocation(_:)), to: submenu)
            option.representedObject = location.coordinate
            option.state = location.coordinate == current ? .on : .off
        }
        submenu.addItem(.separator())
        let custom = addItem("Custom…", symbol: "pencil", action: #selector(setCustomLocation), to: submenu)
        custom.state = current != nil && !Self.locations.contains { $0.coordinate == current } ? .on : .off
        addItem("Clear", symbol: "location.slash", action: #selector(clearLocation), to: submenu)
        item.submenu = submenu
        return item
    }

    // MARK: - Actions

    @objc private func selectDevice(_ sender: NSMenuItem) {
        defaults.set(sender.representedObject as? String, forKey: "selectedDevice")
        slowMotion = nil
        refresh()
    }

    @objc private func shake() {
        notifyutil(["-p", "com.apple.UIKit.SimulatorShake"])
    }

    @objc private func toggleSlowMotion() {
        let enable = slowMotion != true
        slowMotion = enable
        notifyutil(["-s", Self.slowMotionKey, enable ? "1" : "0", "-p", Self.slowMotionKey])
    }

    @objc private func openURL() {
        guard let device else { return }
        let clipboard = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestion = clipboard?.contains("://") == true ? clipboard : defaults.string(forKey: "lastURL")
        guard let url = prompt("Open URL on \(device.name)", message: "Deep link or web URL", value: suggestion ?? "") else { return }
        defaults.set(url, forKey: "lastURL")
        perform(["openurl", device.udid, url])
    }

    @objc private func setLocation(_ sender: NSMenuItem) {
        guard let coordinate = sender.representedObject as? String else { return }
        applyLocation(coordinate)
    }

    @objc private func setCustomLocation() {
        guard let input = prompt("Set Location", message: "Latitude, longitude", value: defaults.string(forKey: "customLocation") ?? "") else { return }
        let parts = input.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, (-90...90).contains(parts[0]), (-180...180).contains(parts[1]) else {
            return showError("“\(input)” isn't a valid coordinate. Use the form 25.1972, 55.2744.")
        }
        defaults.set(input, forKey: "customLocation")
        applyLocation("\(parts[0]),\(parts[1])")
    }

    @objc private func clearLocation() {
        guard let device else { return }
        locationByDevice[device.udid] = nil
        perform(["location", device.udid, "clear"])
    }

    private func applyLocation(_ coordinate: String) {
        guard let device else { return }
        locationByDevice[device.udid] = coordinate
        perform(["location", device.udid, "set", coordinate])
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - simctl

    private func bootedDevices() -> [Device] {
        guard case .success(let output) = simctl(["list", "devices", "booted", "-j"]),
              let list = try? JSONDecoder().decode([String: [String: [Device]]].self, from: Data(output.utf8))
        else { return [] }
        return list["devices", default: [:]].values.flatMap { $0 }.sorted { $0.name < $1.name }
    }

    private func isSlowMotionOn(_ device: Device) -> Bool? {
        guard case .success(let output) = simctl(["spawn", device.udid, "notifyutil", "-g", Self.slowMotionKey]) else { return nil }
        return output.split(separator: " ").last.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) != "0" }
    }

    private func notifyutil(_ args: [String]) {
        guard let device else { return }
        perform(["spawn", device.udid, "notifyutil"] + args)
    }

    private func perform(_ args: [String]) {
        DispatchQueue.global().async {
            if case .failure(let error) = self.simctl(args) {
                DispatchQueue.main.async { self.showError(error.localizedDescription) }
            }
        }
    }

    private func simctl(_ args: [String]) -> Result<String, Error> {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return .failure(error)
        }
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return .failure(SimctlError(errorDescription: String(decoding: errorOutput, as: UTF8.self)))
        }
        return .success(String(decoding: output, as: UTF8.self))
    }

    // MARK: - Dialogs

    private func prompt(_ title: String, message: String, value: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = value
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let input = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return input.isEmpty ? nil : input
    }

    private func showError(_ message: String) {
        NSSound.beep()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Simulator command failed"
        alert.informativeText = message.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
