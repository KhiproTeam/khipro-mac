# Khipro for macOS

A macOS input method for typing Bangla with the **Khipro** compositional layout.
It is a thin [InputMethodKit](https://developer.apple.com/documentation/inputmethodkit)
app over [`libkhipro`](https://github.com/khiproteam/library) — the engine logic
lives in the C++ library (vendored in `Vendor/khipro/`), so this repo only handles
the macOS integration and packaging.

## Requirements

- macOS 11+ (the app is built universal: arm64 + x86_64)
- Xcode command-line tools (`swiftc`, `clang`, `lipo`, `iconutil`, `sips`)

## Build & install

```bash
make            # build build/Khipro.app (universal)
make install    # build, then copy to ~/Library/Input Methods/
```

After `make install`, activate it:

1. Log out and back in (or run `sudo killall -HUP SystemUIServer`).
2. **System Settings ▸ Keyboard ▸ Input Sources ▸ +  ▸ Bangla ▸ Khipro**.
3. Pick **Khipro** from the input-source menu in the menu bar and start typing.

## Installer DMG

```bash
make dmg        # build build/Khipro.dmg; drag Khipro onto the Input Methods shortcut (/Library/Input Methods, needs admin password)
make open-dmg   # build the DMG and open it
```

The DMG background is rendered from `Resources/make-bg.swift` (native AppKit, no
deps) each time, so edits to it take effect on the next `make dmg`.

## Icons

`logo.png` (repo root) is the single source image. Regenerate the icon assets
after changing it:

```bash
make icons      # -> Resources/menu-icon.png (input source) + Resources/AppIcon.icns
```

## Other targets

```bash
make smoke          # link tests/smoke.c against libkhipro and run a quick sanity check
make update-engine  # pull the latest engine release into Vendor/ (see below)
make uninstall      # remove from ~/Library/Input Methods/
make clean          # remove build/
```

## Layout

```
Sources/        Swift app: IMK controller, C-ABI engine shim, bridging header
Vendor/khipro/  libkhipro.a (universal) + C header — the engine, committed
Resources/      menu/app icons, DMG background renderer
Info.plist      input-method bundle metadata
Makefile        build / install / dmg / icons / smoke
create-dmg.sh   DMG packaging
tests/smoke.c   engine link/integration check
logo.png        source image for the icons (see `make icons`)
```

## Updating the engine

The engine is the prebuilt static lib in `Vendor/khipro/`, taken from the
[khipro-library](https://github.com/KhiproTeam/khipro-library) releases.

```bash
make update-engine
```

pulls the `khipro-*-macos-universal` artifact from the **latest** release,
drops `libkhipro.a` + `khipro.h` into `Vendor/khipro/`, and runs `make smoke`
to confirm it links and converts. Commit the updated `Vendor/` files, then
`make` to rebuild the app against them.

`make smoke` on its own prints the bundled engine/library version.

## License

MIT — see [LICENSE](LICENSE) if present, otherwise the upstream
[khipro library](https://github.com/khiproteam/library) terms.
