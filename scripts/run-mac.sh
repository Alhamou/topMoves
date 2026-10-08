#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
xcodebuild -project TopMovies.xcodeproj -scheme TopMovies -configuration Release -destination 'platform=macOS' -derivedDataPath build/mac CODE_SIGNING_ALLOWED=NO build
mkdir -p build
ditto build/mac/Build/Products/Release/TopMovies.app build/TopMovies.app
plutil -replace CFBundleIconFile -string "AppIcon" build/TopMovies.app/Contents/Info.plist
codesign --force --sign - --entitlements TopMovies/Resources/TopMovies.entitlements build/TopMovies.app
touch build/TopMovies.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f build/TopMovies.app 2>/dev/null || true
open build/TopMovies.app
