import Foundation

#if canImport(AppKit)
import AppKit

@main
struct WaneApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
#else
@main
struct WaneApp {
    static func main() {
        print("Wane is a macOS menu bar app. Build on macOS to run the UI.")
    }
}
#endif
