import AppKit

// MARK: - Sketch Responder ViewController

class SketchViewController: NSViewController, NSServicesMenuRequestor {
    let config: SketchConfig
    var didReceiveImage = false

    init(config: SketchConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func loadView() {
        // Minimal empty view — the window only exists for the responder chain
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    }

    override var acceptsFirstResponder: Bool { true }

    override func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?
    ) -> Any? {
        if sendType == nil && returnType != nil {
            return self
        }
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }

    func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        return false
    }

    func readSelection(from pboard: NSPasteboard) -> Bool {
        guard let image = NSImage(pasteboard: pboard) else {
            SketchResult.error("No image in pasteboard")
            return false
        }

        didReceiveImage = true

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            SketchResult.error("Failed to convert image to PNG")
            NSApp.terminate(nil)
            return false
        }

        let pngFileName = "\(config.drawingId).png"
        let pngPath = "\(config.outputDir)/\(pngFileName)"

        do {
            try pngData.write(to: URL(fileURLWithPath: pngPath))
            let width = Int(image.size.width)
            let height = Int(image.size.height)
            SketchResult.done(png: pngFileName, width: width, height: height)
        } catch {
            SketchResult.error(error.localizedDescription)
        }

        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
        return true
    }
}

// MARK: - Menu & Window Controller

class SketchMenuController: NSObject, NSWindowDelegate, NSMenuDelegate {
    let config: SketchConfig
    var window: NSWindow?
    var viewController: SketchViewController?
    var didOutputResult = false

    init(config: SketchConfig) {
        self.config = config
        super.init()
    }

    private func outputCancelledAndQuit() {
        guard !didOutputResult else { return }
        guard !(viewController?.didReceiveImage ?? false) else { return }
        didOutputResult = true
        SketchResult.cancelled()
        NSApp.terminate(nil)
    }

    func setup() {
        let imageReturnTypes = NSImage.imageTypes.map { NSPasteboard.PasteboardType($0) }
        NSApp.registerServicesMenuSendTypes([], returnTypes: imageReturnTypes)

        // Build main menu bar with "Import from Device" items
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        let appMenuItem = mainMenu.addItem(withTitle: "", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Devices menu — system auto-populates importFromDeviceIdentifier
        let devicesMenu = NSMenu(title: "Devices")
        let devicesMenuItem = mainMenu.addItem(withTitle: "Devices", action: nil, keyEquivalent: "")
        devicesMenuItem.submenu = devicesMenu

        let importPlaceholder = NSMenuItem()
        importPlaceholder.identifier = NSMenuItem.importFromDeviceIdentifier
        devicesMenu.addItem(importPlaceholder)

        NSApp.mainMenu = mainMenu

        let vc = SketchViewController(config: config)
        self.viewController = vc

        // Tiny window positioned at mouse — only exists for responder chain.
        // Traffic light buttons are hidden, content is empty.
        let mouseLocation = NSEvent.mouseLocation
        let win = NSWindow(
            contentRect: NSRect(x: mouseLocation.x - 1, y: mouseLocation.y - 1, width: 1, height: 1),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .statusBar
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Hide traffic light buttons
        win.standardWindowButton(.closeButton)?.isHidden = true
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true
        win.contentViewController = vc
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(vc)
        self.window = win

        // Set Dock icon from bundled icns
        if let iconPath = Bundle.main.path(forResource: "app", ofType: "icns") {
            NSApp.applicationIconImage = NSImage(contentsOfFile: iconPath)
        }

        NSApp.activate(ignoringOtherApps: true)

        // Auto-open the Devices submenu after system validates it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tryAutoOpenDevicesMenu()
        }
    }

    private func tryAutoOpenDevicesMenu() {
        guard let vc = viewController, let win = window else { return }

        // Pop up a contextual menu — the system injects Continuity items
        // when the view's responder chain has a valid NSServicesMenuRequestor.
        // With a proper titled window + NSViewController, items should be enabled.
        let menu = NSMenu()
        menu.delegate = self

        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: vc.view.convert(NSPoint(x: 5, y: 5), to: nil),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: win.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ) else { return }

        NSMenu.popUpContextMenu(menu, with: event, for: vc.view)
    }

    // MARK: - NSMenuDelegate

    func menuDidClose(_ menu: NSMenu) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.outputCancelledAndQuit()
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        outputCancelledAndQuit()
    }
}
