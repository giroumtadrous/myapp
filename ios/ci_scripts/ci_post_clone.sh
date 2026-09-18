#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

flutter config --no-enable-swift-package-manager
flutter doctor
flutter pub get
flutter precache --ios

cd ios
pod install