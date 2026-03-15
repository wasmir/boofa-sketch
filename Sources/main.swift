import AppKit

// MARK: - CLI Arguments

struct SketchConfig {
    let outputDir: String
    let drawingId: String

    static func fromCommandLine() -> SketchConfig? {
        let args = CommandLine.arguments
        var outputDir: String?
        var drawingId: String?

        var i = 1
        while i < args.count {
            switch args[i] {
            case "--output-dir":
                i += 1
                if i < args.count { outputDir = args[i] }
            case "--drawing-id":
                i += 1
                if i < args.count { drawingId = args[i] }
            default:
                break
            }
            i += 1
        }

        guard let dir = outputDir, let id = drawingId else {
            return nil
        }
        return SketchConfig(outputDir: dir, drawingId: id)
    }
}

// MARK: - Result Output

struct SketchResult {
    static func done(png: String, width: Int, height: Int) {
        let json = "{\"status\":\"done\",\"png\":\"\(png)\",\"width\":\(width),\"height\":\(height)}"
        print(json)
    }

    static func cancelled() {
        print("{\"status\":\"cancelled\"}")
    }

    static func error(_ message: String) {
        fputs("{\"status\":\"error\",\"message\":\"\(message)\"}\n", stderr)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: SketchMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let config = SketchConfig.fromCommandLine() else {
            SketchResult.error("Missing required arguments: --output-dir and --drawing-id")
            NSApp.terminate(nil)
            return
        }

        controller = SketchMenuController(config: config)
        controller?.setup()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // We manage termination ourselves
    }
}

// MARK: - Entry Point

@main
enum BoofaSketchApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
