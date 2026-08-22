#!/bin/bash
# ============================================================
# Build ORE Tile Helper APK — Universal (Android 7-16, all arch)
# ============================================================
# Requirements:
#   - Android SDK installed (ANDROID_HOME or ANDROID_SDK_ROOT)
#   - Build tools (aapt2, d8, apksigner)
#   - JDK 11+
#
# Usage:
#   chmod +x build.sh
#   ./build.sh
#
# Output:
#   build/ore-tile.apk
#
# Supports:
#   - Android 7.0 (API 24) to Android 16 (API 36)
#   - ARM, ARM64, x86, x86_64 (pure Java, no native code)
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
MIN_API=24
TARGET_API=36

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

echo "SDK: $SDK"

# ---- Find latest build-tools ----
BUILD_TOOLS=$(ls -d "$SDK/build-tools/"* 2>/dev/null | sort -V | tail -1)
if [ -z "$BUILD_TOOLS" ]; then
    echo "Error: No build-tools found in $SDK"
    exit 1
fi
echo "Build-tools: $BUILD_TOOLS"

# ---- Find latest platform (must be >= target API) ----
PLATFORM=""
for api in $(seq $TARGET_API -1 $MIN_API); do
    if [ -d "$SDK/platforms/android-$api" ]; then
        PLATFORM="$SDK/platforms/android-$api"
        echo "Platform: android-$api"
        break
    fi
done

if [ -z "$PLATFORM" ]; then
    # Fallback: use any available platform
    PLATFORM=$(ls -d "$SDK/platforms/android-"* 2>/dev/null | sort -V | tail -1)
    if [ -z "$PLATFORM" ]; then
        echo "Error: No Android platform found in $SDK"
        exit 1
    fi
    echo "Platform (fallback): $(basename $PLATFORM)"
fi

AAPT2="$BUILD_TOOLS/aapt2"
D8="$BUILD_TOOLS/d8"
APKSIGNER="$BUILD_TOOLS/apksigner"
ZIPALIGN="$BUILD_TOOLS/zipalign"

# ---- Clean ----
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/compiled_res" "$BUILD_DIR/classes"

echo ""
echo "=== Compiling resources ==="
"$AAPT2" compile --dir "$RES_DIR" -o "$BUILD_DIR/compiled_res/"

echo "=== Linking ==="
"$AAPT2" link \
    -o "$BUILD_DIR/unsigned.apk" \
    -I "$PLATFORM/android.jar" \
    --manifest "$MANIFEST" \
    --java "$BUILD_DIR/gen" \
    --min-sdk-version $MIN_API \
    --target-sdk-version $TARGET_API \
    "$BUILD_DIR/compiled_res"/*.flat

echo "=== Compiling Java ==="
# Include both src/ and gen/ (aapt2 generates R.java in gen/)
find "$SRC_DIR" "$BUILD_DIR/gen" -name "*.java" > "$BUILD_DIR/sources.txt"
javac \
    -source 11 -target 11 \
    -classpath "$PLATFORM/android.jar" \
    -d "$BUILD_DIR/classes" \
    @"$BUILD_DIR/sources.txt"

echo "=== Converting to DEX ==="
find "$BUILD_DIR/classes" -name "*.class" > "$BUILD_DIR/classfiles.txt"
"$D8" \
    --output "$BUILD_DIR/" \
    --min-api $MIN_API \
    --lib "$PLATFORM/android.jar" \
    @"$BUILD_DIR/classfiles.txt"

echo "=== Adding DEX to APK ==="
cd "$BUILD_DIR"
cp unsigned.apk unsigned_with_dex.apk
zip -j unsigned_with_dex.apk classes.dex
cd ..

echo "=== Aligning ==="
"$ZIPALIGN" -f 4 "$BUILD_DIR/unsigned_with_dex.apk" "$BUILD_DIR/aligned.apk"

echo "=== Signing ==="
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

# ---- Verify ----
echo ""
echo "=== APK Verification ==="
"$APKSIGNER" verify "$BUILD_DIR/ore-tile.apk" 2>/dev/null && echo "Signature: VALID" || echo "Signature: WARNING"
"$ZIPALIGN" -c 4 "$BUILD_DIR/ore-tile.apk" 2>/dev/null && echo "Alignment: VALID" || echo "Alignment: WARNING"

echo ""
echo "✅ Build complete!"
echo "📦 Output: $BUILD_DIR/ore-tile.apk"
echo ""
echo "Supported:"
echo "  - Android ${MIN_API}+ (API ${MIN_API} to API ${TARGET_API})"
echo "  - ARM, ARM64, x86, x86_64 (pure Java)"
echo ""
echo "Install with:"
echo "  adb install $BUILD_DIR/ore-tile.apk"
