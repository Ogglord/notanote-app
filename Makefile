APP_NAME = LogSeq Todos
BINARY_NAME = LogSeqTodos
BUILD_DIR = .build/release
BUNDLE_DIR = build/$(APP_NAME).app
DMG_NAME = LogSeqTodos.dmg
VERSION = 1.0

.PHONY: build run bundle install installer clean

build:
	swift build -c release

run: build
	$(BUILD_DIR)/$(BINARY_NAME)

icon:
	mkdir -p build/icon.iconset
	swift Scripts/generate_icon.swift build/icon.iconset
	iconutil -c icns build/icon.iconset -o build/AppIcon.icns

bundle: build
	mkdir -p "$(BUNDLE_DIR)/Contents/MacOS"
	mkdir -p "$(BUNDLE_DIR)/Contents/Resources"
	cp $(BUILD_DIR)/$(BINARY_NAME) "$(BUNDLE_DIR)/Contents/MacOS/"
	cp Sources/Resources/Info.plist "$(BUNDLE_DIR)/Contents/"
	@if [ -f build/AppIcon.icns ]; then \
		cp build/AppIcon.icns "$(BUNDLE_DIR)/Contents/Resources/"; \
	fi
	echo -n "APPL????" > "$(BUNDLE_DIR)/Contents/PkgInfo"

installer: bundle
	@echo "Creating DMG installer..."
	rm -rf build/dmg
	mkdir -p build/dmg
	cp -R "$(BUNDLE_DIR)" build/dmg/
	ln -s /Applications build/dmg/Applications
	rm -f "build/$(DMG_NAME)"
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder build/dmg \
		-ov -format UDZO \
		"build/$(DMG_NAME)"
	rm -rf build/dmg
	@echo "Installer created: build/$(DMG_NAME)"

install: bundle
	cp -R "$(BUNDLE_DIR)" "/Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf build
