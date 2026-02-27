APP_NAME = NotaNote
BINARY_NAME = NotaNote
BUILD_DIR = .build/release
BUNDLE_DIR = build/$(APP_NAME).app
DMG_NAME = NotaNote.dmg
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
	cp build/AppIcon.icns Sources/App/Resources/AppIcon.icns
	cp build/icon.iconset/menubar-not.png Sources/App/Resources/menubar-not.png
	cp build/icon.iconset/menubar-not@2x.png Sources/App/Resources/menubar-not@2x.png
	cp build/icon.iconset/menubar-alt.png Sources/App/Resources/menubar-alt.png
	cp build/icon.iconset/menubar-alt@2x.png Sources/App/Resources/menubar-alt@2x.png

bundle: build
	mkdir -p "$(BUNDLE_DIR)/Contents/MacOS"
	mkdir -p "$(BUNDLE_DIR)/Contents/Resources"
	cp $(BUILD_DIR)/$(BINARY_NAME) "$(BUNDLE_DIR)/Contents/MacOS/"
	cp Sources/App/Resources/Info.plist "$(BUNDLE_DIR)/Contents/"
	cp Sources/App/Resources/AppIcon.icns "$(BUNDLE_DIR)/Contents/Resources/"
	echo -n "APPL????" > "$(BUNDLE_DIR)/Contents/PkgInfo"
	codesign --force --sign - --entitlements Sources/App/Resources/NotaNote.entitlements "$(BUNDLE_DIR)"

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
	@pkill -x $(BINARY_NAME) 2>/dev/null || true
	@sleep 0.5
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUNDLE_DIR)" "/Applications/$(APP_NAME).app"
	@echo "Installed to /Applications/$(APP_NAME).app"
	open "/Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf build
