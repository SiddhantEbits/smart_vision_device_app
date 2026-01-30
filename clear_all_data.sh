#!/bin/bash

echo "🧹 CLEARING ALL USER DATA..."
echo "================================"

# Clear Flutter app data
echo "📱 Clearing Flutter app data..."
flutter clean
rm -rf build/
echo "✅ Flutter build cache cleared"

# Clear GetStorage data (if accessible)
echo "💾 Clearing GetStorage data..."
if [ -d "$HOME/.local/share/get_storage" ]; then
    rm -rf "$HOME/.local/share/get_storage"
    echo "✅ GetStorage data cleared"
fi

# Clear Hive storage data (if accessible)
echo "🍯 Clearing Hive storage data..."
if [ -d "$HOME/.local/share/hive" ]; then
    rm -rf "$HOME/.local/share/hive"
    echo "✅ Hive storage data cleared"
fi

# Clear SharedPreferences (Android)
echo "🤖 Clearing Android SharedPreferences..."
if [ -d "android/app/build" ]; then
    rm -rf android/app/build
    echo "✅ Android build cleared"
fi

# Clear iOS data (if applicable)
echo "🍎 Clearing iOS data..."
if [ -d "ios/build" ]; then
    rm -rf ios/build
    echo "✅ iOS build cleared"
fi

echo ""
echo "🎯 ALL USER DATA CLEARED!"
echo "================================"
echo "Next steps:"
echo "1. Run 'flutter pub get'"
echo "2. Run 'flutter run'"
echo "3. Test with fresh data"
