APP_NAME = Khipro
BUNDLE_ID = com.khipro.inputmethod.Khipro
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
SOURCES = Sources/main.swift Sources/KhiproInputController.swift Sources/KhiproEngine.swift
KHIPRO_DIR = Vendor/khipro
KHIPRO_RELEASE_API = https://api.github.com/repos/KhiproTeam/khipro-library/releases/latest
MACOS_MIN = 11
SWIFTC = xcrun swiftc
BINARY = $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
SWIFT_FLAGS = -framework AppKit -framework InputMethodKit \
	-I $(KHIPRO_DIR)/include \
	-import-objc-header Sources/KhiproBridge.h \
	-L $(KHIPRO_DIR)/lib -lkhipro -lc++

all: bundle

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

bundle:
	mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources
	$(SWIFTC) $(SOURCES) $(SWIFT_FLAGS) -target arm64-apple-macos$(MACOS_MIN) -o $(BUILD_DIR)/$(APP_NAME).arm64
	$(SWIFTC) $(SOURCES) $(SWIFT_FLAGS) -target x86_64-apple-macos$(MACOS_MIN) -o $(BUILD_DIR)/$(APP_NAME).x86_64
	lipo -create $(BUILD_DIR)/$(APP_NAME).arm64 $(BUILD_DIR)/$(APP_NAME).x86_64 -output $(BINARY)
	rm -f $(BUILD_DIR)/$(APP_NAME).arm64 $(BUILD_DIR)/$(APP_NAME).x86_64
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp Resources/menu-icon.tiff $(APP_BUNDLE)/Contents/Resources/
	cp -R Resources/en.lproj Resources/bn.lproj $(APP_BUNDLE)/Contents/Resources/
	cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/
	codesign --force --sign - $(APP_BUNDLE) # ponytail: ad-hoc; Developer ID + notarize needed for public distribution
	@echo ""
	@echo "=== Build complete: $(APP_BUNDLE) ==="

install: bundle
	rm -rf ~/Library/Input\ Methods/$(APP_NAME).app
	cp -R $(APP_BUNDLE) ~/Library/Input\ Methods/
	-killall $(APP_NAME) # restart so the new binary is the one macOS talks to
	@echo ""
	@echo "=== Installed to ~/Library/Input Methods/$(APP_NAME).app ==="
	@echo "Log out and log in to activate, or run:"
	@echo "  sudo killall -HUP SystemUIServer"
	@echo "Then enable in System Settings > Keyboard > Input Sources"

uninstall:
	rm -rf ~/Library/Input\ Methods/$(APP_NAME).app
	@echo "=== Uninstalled ==="

dmg: bundle
	./create-dmg.sh

open-dmg: dmg
	open build/$(APP_NAME).dmg

smoke: $(BUILD_DIR)
	clang tests/smoke.c -I $(KHIPRO_DIR)/include -L $(KHIPRO_DIR)/lib -lkhipro -lc++ -o $(BUILD_DIR)/smoke
	$(BUILD_DIR)/smoke

# Run the library's conformance TSVs through the vendored engine (both variants).
test: smoke
	clang tests/conformance.c -I $(KHIPRO_DIR)/include -L $(KHIPRO_DIR)/lib -lkhipro -lc++ -o $(BUILD_DIR)/conformance
	$(BUILD_DIR)/conformance tests/khipro-testcases.tsv
	$(BUILD_DIR)/conformance tests/khipro-testcases-touch.tsv touch

# Replace Vendor/khipro with the latest khipro-library GitHub release, then
# verify it still links and converts.
update-engine: $(BUILD_DIR)
	@url=$$(curl -sL $(KHIPRO_RELEASE_API) | grep -o 'https://[^"]*macos-universal\.tar\.gz' | head -1); \
	[ -n "$$url" ] || { echo "No macos-universal asset in the latest release"; exit 1; }; \
	echo "  fetching $$url"; \
	rm -rf $(BUILD_DIR)/engine && mkdir -p $(BUILD_DIR)/engine; \
	curl -sL "$$url" | tar xz -C $(BUILD_DIR)/engine || exit 1; \
	cp $(BUILD_DIR)/engine/macos/universal/lib/libkhipro.a $(KHIPRO_DIR)/lib/; \
	cp $(BUILD_DIR)/engine/macos/universal/include/khipro/khipro.h $(KHIPRO_DIR)/include/khipro/; \
	rm -rf $(BUILD_DIR)/engine
	@$(MAKE) --no-print-directory smoke

# Regenerate icon assets: AppIcon.icns from logo.png, menu icon from logo.png too.
icons: logo.png $(BUILD_DIR)
	swift Resources/make-menu-icon.swift logo.png $(BUILD_DIR)/m32.tiff 32 144
	swift Resources/make-menu-icon.swift logo.png $(BUILD_DIR)/m16.tiff 16 72
	tiffutil -cat $(BUILD_DIR)/m32.tiff $(BUILD_DIR)/m16.tiff -out Resources/menu-icon.tiff
	rm -f $(BUILD_DIR)/m32.tiff $(BUILD_DIR)/m16.tiff
	rm -rf $(BUILD_DIR)/Khipro.iconset && mkdir -p $(BUILD_DIR)/Khipro.iconset
	for s in 16 32 64 128 256 512; do \
		sips -z $$s $$s logo.png --out $(BUILD_DIR)/Khipro.iconset/icon_$${s}x$${s}.png >/dev/null; \
		d=$$((s*2)); sips -z $$d $$d logo.png --out $(BUILD_DIR)/Khipro.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns $(BUILD_DIR)/Khipro.iconset -o Resources/AppIcon.icns
	rm -rf $(BUILD_DIR)/Khipro.iconset
	@echo "=== Regenerated Resources/menu-icon.tiff and Resources/AppIcon.icns ==="

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all bundle install uninstall dmg open-dmg smoke test update-engine icons clean
