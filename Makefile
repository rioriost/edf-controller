VERSION ?= 0.1.4
NOTARY_PROFILE ?= git-labeler-notary
CODESIGN_IDENTITY ?= Developer ID Application: Ryo Fujita (23889H77KX)
CASK_RELEASE_BASE_URL ?= https://github.com/rioriost/edf-controller/releases/download
CASK_HOMEPAGE ?= https://github.com/rioriost/edf-controller
CASK_OUTPUT ?= ../homebrew-cask/Casks/edf-controller.rb

.PHONY: build test check app app-signed notarize-macos clean

build:
	swift build

test:
	swift test

check:
	swift test -Xswiftc -warnings-as-errors
	zsh -n scripts/build-app.sh scripts/notarize-release.sh scripts/update-cask.sh
	plutil -lint Resources/Info.plist

app:
	VERSION="$(VERSION)" scripts/build-app.sh

app-signed:
	CODE_SIGN_IDENTITY="$(CODESIGN_IDENTITY)" VERSION="$(VERSION)" scripts/build-app.sh

notarize-macos:
	CODE_SIGN_IDENTITY="$(CODESIGN_IDENTITY)" \
	NOTARY_PROFILE="$(NOTARY_PROFILE)" \
	CASK_RELEASE_BASE_URL="$(CASK_RELEASE_BASE_URL)" \
	CASK_HOMEPAGE="$(CASK_HOMEPAGE)" \
	CASK_OUTPUT="$(CASK_OUTPUT)" \
	VERSION="$(VERSION)" \
	scripts/notarize-release.sh

clean:
	rm -rf .build dist
