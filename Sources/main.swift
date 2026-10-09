import Cocoa
import InputMethodKit

@objc(KhiproAppDelegate) class KhiproAppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: "Khipro_Connection", bundleIdentifier: Bundle.main.bundleIdentifier!)
    }
}

let app = NSApplication.shared
let delegate = KhiproAppDelegate()
app.delegate = delegate
app.run()
