#!/bin/bash
# ============================================================
# Build ORE Tile Helper APK
# ============================================================
# Requirements:
#   - Android SDK installed (ANDROID_HOME or ANDROID_SDK_ROOT)
#   - Build tools (aapt2, d8, apksigner)
#
# Usage:
#   chmod +x build.sh
#   ./build.sh
#
# Output:
#   build/ore-tile.apk
# ============================================================

set -e

# ---- Config ----
PACKAGE="com.openglrenderer.tile"
APP_NAME="ORE Tile"
VERSION="1.0"
BUILD_DIR="build"
SRC_DIR="src"
RES_DIR="res"
MANIFEST="AndroidManifest.xml"

# ---- Find Android SDK ----
if [ -n "$ANDROID_HOME" ]; then
    SDK="$ANDROID_HOME"
elif [ -n "$ANDROID_SDK_ROOT" ]; then
    SDK="$ANDROID_SDK_ROOT"
elif [ -d "$HOME/Android/Sdk" ]; then
    SDK="$HOME/Android/Sdk"
elif [ -d "$HOME/Library/Android/sdk" ]; then
    SDK="$HOME/Library/Android/sdk"
else
    echo "Error: Android SDK not found."
    echo "Set ANDROID_HOME or ANDROID_SDK_ROOT."
    exit 1
fi

# Find latest build-tools
BUILD_TOOLS=$(ls -d "$SDK/build-tools/"* 2>/dev/null | sort -V | tail -1)
if [ -z "$BUILD_TOOLS" ]; then
    echo "Error: No build-tools found in $SDK"
    exit 1
fi

echo "Using build-tools: $BUILD_TOOLS"

AAPT2="$BUILD_TOOLS/aapt2"
D8="$BUILD_TOOLS/d8"
APKSIGNER="$BUILD_TOOLS/apksigner"
ZIPALIGN="$BUILD_TOOLS/zipalign"

# ---- Clean ----
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/compiled_res" "$BUILD_DIR/classes"

echo "=== Compiling resources ==="
"$AAPT2" compile --dir "$RES_DIR" -o "$BUILD_DIR/compiled_res/"

echo "=== Linking ==="
"$AAPT2" link \
    -o "$BUILD_DIR/unsigned.apk" \
    -I "$SDK/platforms/android-34/android.jar" \
    --manifest "$MANIFEST" \
    --java "$BUILD_DIR/gen" \
    "$BUILD_DIR/compiled_res"/*.flat

echo "=== Compiling Java ==="
# Find all java files
find "$SRC_DIR" -name "*.java" > "$BUILD_DIR/sources.txt"
javac \
    -source 11 -target 11 \
    -classpath "$SDK/platforms/android-34/android.jar" \
    -d "$BUILD_DIR/classes" \
    @"$BUILD_DIR/sources.txt"

echo "=== Converting to DEX ==="
# Find all class files
find "$BUILD_DIR/classes" -name "*.class" > "$BUILD_DIR/classfiles.txt"
"$D8" \
    --output "$BUILD_DIR/" \
    --lib "$SDK/platforms/android-34/android.jar" \
    @"$BUILD_DIR/classfiles.txt"

echo "=== Adding DEX to APK ==="
cd "$BUILD_DIR"
# Add classes.dex to the APK
cp unsigned.apk unsigned_with_dex.apk
zip -j unsigned_with_dex.apk classes.dex
cd ..

echo "=== Aligning ==="
"$ZIPALIGN" -f 4 "$BUILD_DIR/unsigned_with_dex.apk" "$BUILD_DIR/aligned.apk"

echo "=== Signing ==="
# Generate debug keystore if not exists
KEYSTORE="$BUILD_DIR/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
    keytool -genkeypair \
        -keystore "$KEYSTORE" \
        -storepass android \
        -keypass android \
        -alias debugkey \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "CN=Debug,O=Debug,C=US" 2>/dev/null
fi

"$APKSIGNER" sign \
    --ks "$KEYSTORE" \
    --ks-pass pass:android \
    --key-pass pass:android \
    --ks-key-alias debugkey \
    --out "$BUILD_DIR/ore-tile.apk" \
    "$BUILD_DIR/aligned.apk"

echo ""
echo "✅ Build complete!"
echo "📦 Output: $BUILD_DIR/ore-tile.apk"
echo ""
echo "Install with:"
echo "  adb install $BUILD_DIR/ore-tile.apk"
echo ""
echo "Or copy to device and install manually."
