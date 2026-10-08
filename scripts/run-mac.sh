#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
xcodebuild -project TopMovies.xcodeproj -scheme TopMovies -configuration Release -destination 'platform=macOS' -derivedDataPath build/mac CODE_SIGNING_ALLOWED=NO build
mkdir -p build
ditto build/mac/Build/Products/Release/TopMovies.app build/TopMovies.app
codesign --force --sign - --entitlements TopMovies/Resources/TopMovies.entitlements build/TopMovies.app
open build/TopMovies.app
