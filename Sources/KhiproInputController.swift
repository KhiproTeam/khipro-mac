import Cocoa
import InputMethodKit
import os

private let log = Logger(subsystem: "com.khipro.inputmethod.Khipro", category: "input")

@objc(KhiproInputController) class KhiproInputController: IMKInputController {
    private let engine = Engine()
    private var preediting = false

    private let notFound = NSRange(location: NSNotFound, length: NSNotFound)

    // Return/Enter, Tab, Esc, arrows, Home/End/PageUp/PageDown, forward-delete.
    // These are not typed text: commit the composition, then let the app act on the key.
    private static let passthroughKeys: Set<UInt16> = [
        36, 76, 48, 53, 123, 124, 125, 126, 115, 119, 116, 121, 117,
    ]
    private static let backspaceKey: UInt16 = 51

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown, let client = client() else { return false }
        let typed = event.characters ?? ""
        log.debug("key \(event.keyCode) chars=\(typed, privacy: .public)")

        let shortcut = !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        if shortcut || Self.passthroughKeys.contains(event.keyCode) {
            commitComposition(sender)
            return false
        }
        if event.keyCode == Self.backspaceKey {
            // Only own backspace while composing; otherwise the app deletes normally.
            guard preediting else { return false }
            let out = engine.backspace()
            apply(out, client: client)
            return out.consumed
        }
        guard let text = event.characters, let scalar = text.unicodeScalars.first,
              scalar.value >= 0x20, scalar.value != 0x7f,
              !(0xF700...0xF8FF).contains(scalar.value) // AppKit function-key private-use range
        else {
            commitComposition(sender)
            return false
        }
        let out = engine.feed(text)
        apply(out, client: client)
        return out.consumed
    }

    override func activateServer(_ sender: Any!) {
        engine.reset()
        preediting = false
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
    }

    override func commitComposition(_ sender: Any!) {
        guard preediting, let client = client() else { return }
        let out = engine.commit()
        // Clear the marked range before inserting, or the client keeps the underline.
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: notFound)
        if !out.committedDelta.isEmpty {
            client.insertText(out.committedDelta, replacementRange: notFound)
        }
        preediting = false
    }

    private func apply(_ out: KhiproOutput, client: IMKTextInput) {
        if !out.committedDelta.isEmpty {
            client.insertText(out.committedDelta, replacementRange: notFound)
        }
        if out.preedit.isEmpty {
            client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: notFound)
            preediting = false
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: NSColor(white: 0.5, alpha: 1.0),
            ]
            let marked = NSAttributedString(string: out.preedit, attributes: attrs)
            client.setMarkedText(marked, selectionRange: NSRange(location: out.preedit.utf16.count, length: 0), replacementRange: notFound)
            preediting = true
        }
    }
}
