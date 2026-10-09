import Foundation

// Thin Swift wrapper over the libkhipro C ABI (Vendor/khipro). The engine logic
// lives in the C++ library; this just marshals strings in and out.

struct KhiproOutput {
    let committedDelta: String
    let preedit: String
    let consumed: Bool
}

final class Engine {
    private let handle: OpaquePointer

    init(variant: khipro_variant = KHIPRO_VARIANT_DEFAULT) {
        handle = khipro_create(variant)
    }

    deinit {
        khipro_destroy(handle)
    }

    func feed(_ key: String) -> KhiproOutput { wrap(khipro_feed_key(handle, key)) }
    func backspace() -> KhiproOutput { wrap(khipro_backspace(handle)) }
    func commit() -> KhiproOutput { wrap(khipro_commit(handle)) }
    func reset() { khipro_reset(handle) }

    private func wrap(_ r: khipro_result) -> KhiproOutput {
        // C strings are owned by the engine and valid until the next call; copy now.
        KhiproOutput(
            committedDelta: r.committed_delta.map(String.init(cString:)) ?? "",
            preedit: r.preedit.map(String.init(cString:)) ?? "",
            consumed: r.consumed != 0
        )
    }
}
