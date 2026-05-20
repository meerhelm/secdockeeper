find ./lib -maxdepth 20 -type f \( -name "*.freezed.dart" -o  -name "*.g.dart" -o  -name "*.auto_mappr.dart" \) -delete
rm -rf .dart_tool
rm -f pubspec.lock
flutter clean
rm -rf ios/.symlinks
rm -rf "$HOME/Library/Developer/Xcode/DerivedData"
flutter pub get
cd ios || exit
rm -rf Pods
rm -f Podfile.lock
pod install --repo-update || (echo "Pod install failed, updating CocoaPods repo..." && pod repo update && pod install)
cd ..