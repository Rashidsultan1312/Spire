#!/bin/bash
set -euo pipefail

# inject.sh — патчит Xcode проект после экспорта из Godot (4.0–4.6)
# Использование: bash inject.sh путь/к/Game.xcodeproj

XCODEPROJ="${1:?Использование: inject.sh путь/к/project.xcodeproj}"
PBXPROJ="$XCODEPROJ/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
    echo "ОШИБКА: $PBXPROJ не найден"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWIFT_SRC="$SCRIPT_DIR/WebViewBridge.swift"
PROJECT_DIR="$(dirname "$XCODEPROJ")"
SWIFT_DST="$PROJECT_DIR/WebViewBridge.swift"

if [ ! -f "$SWIFT_SRC" ]; then
    echo "ОШИБКА: WebViewBridge.swift не найден в $SCRIPT_DIR"
    exit 1
fi

# 1. копируем Swift
cp "$SWIFT_SRC" "$SWIFT_DST"
echo "[OK] WebViewBridge.swift скопирован"

# 2. добавляем в Xcode (если ещё нет)
if grep -q "WebViewBridge.swift" "$PBXPROJ"; then
    echo "[—] WebViewBridge.swift уже в проекте"
else
    FILE_REF=$(python3 -c "import random; print(format(random.getrandbits(96), '024X'))")
    BUILD_FILE=$(python3 -c "import random; print(format(random.getrandbits(96), '024X'))")

    sed -i '' "/\/\* End PBXFileReference section \*\//i\\
		${FILE_REF} /* WebViewBridge.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WebViewBridge.swift; sourceTree = \"<group>\"; };
" "$PBXPROJ"

    sed -i '' "/\/\* End PBXBuildFile section \*\//i\\
		${BUILD_FILE} /* WebViewBridge.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${FILE_REF} /* WebViewBridge.swift */; };
" "$PBXPROJ"

    sed -i '' "/\/\* Sources \*\/ = {/,/};/{
        /files = (/a\\
				${BUILD_FILE} /* WebViewBridge.swift in Sources */,
    }" "$PBXPROJ"

    MAIN_GROUP=$(grep 'mainGroup = ' "$PBXPROJ" | head -1 | sed 's/.*mainGroup = \([A-F0-9]*\).*/\1/')
    if [ -n "$MAIN_GROUP" ]; then
        sed -i '' "/${MAIN_GROUP}.*isa = PBXGroup/,/};/{
            /children = (/a\\
				${FILE_REF} /* WebViewBridge.swift */,
        }" "$PBXPROJ"
    fi

    echo "[OK] WebViewBridge.swift добавлен в проект"
fi

# 3. WebKit.framework
if grep -q "WebKit.framework" "$PBXPROJ"; then
    echo "[—] WebKit.framework уже есть"
else
    WK_REF=$(python3 -c "import random; print(format(random.getrandbits(96), '024X'))")
    WK_BUILD=$(python3 -c "import random; print(format(random.getrandbits(96), '024X'))")

    sed -i '' "/\/\* End PBXFileReference section \*\//i\\
		${WK_REF} /* WebKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WebKit.framework; path = System/Library/Frameworks/WebKit.framework; sourceTree = SDKROOT; };
" "$PBXPROJ"

    sed -i '' "/\/\* End PBXBuildFile section \*\//i\\
		${WK_BUILD} /* WebKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${WK_REF} /* WebKit.framework */; };
" "$PBXPROJ"

    sed -i '' "/\/\* Frameworks \*\/ = {/,/};/{
        /files = (/a\\
				${WK_BUILD} /* WebKit.framework in Frameworks */,
    }" "$PBXPROJ"

    echo "[OK] WebKit.framework добавлен"
fi

# 4. Swift версия (5.0 — совместима с Godot 4.0+)
if grep -q "SWIFT_VERSION" "$PBXPROJ"; then
    echo "[—] SWIFT_VERSION уже задан"
else
    sed -i '' '/buildSettings = {/a\
				SWIFT_VERSION = 5.0;
' "$PBXPROJ"
    echo "[OK] SWIFT_VERSION = 5.0"
fi

# 5. DEFINES_MODULE + CLANG_ENABLE_MODULES (нужно для Swift↔ObjC)
if grep -q "DEFINES_MODULE" "$PBXPROJ"; then
    echo "[—] DEFINES_MODULE уже задан"
else
    sed -i '' '/buildSettings = {/a\
				DEFINES_MODULE = YES;\
				CLANG_ENABLE_MODULES = YES;
' "$PBXPROJ"
    echo "[OK] DEFINES_MODULE + CLANG_ENABLE_MODULES"
fi

# 6. Bridging header (пустой, нужен для Swift↔ObjC в некоторых конфигах)
BRIDGE_HEADER="$PROJECT_DIR/BridgingHeader.h"
if [ ! -f "$BRIDGE_HEADER" ]; then
    echo "// Bridging header for WebViewBridge (Swift↔ObjC)" > "$BRIDGE_HEADER"
    echo "[OK] BridgingHeader.h создан"
fi
PROJ_NAME=$(basename "$XCODEPROJ" .xcodeproj)
if ! grep -q "SWIFT_OBJC_BRIDGING_HEADER" "$PBXPROJ"; then
    sed -i '' '/buildSettings = {/a\
				SWIFT_OBJC_BRIDGING_HEADER = "BridgingHeader.h";
' "$PBXPROJ"
    echo "[OK] SWIFT_OBJC_BRIDGING_HEADER задан"
else
    echo "[—] SWIFT_OBJC_BRIDGING_HEADER уже задан"
fi

# 7. фикс плейсхолдеров (Godot 4.4+)
if grep -q '\$pbx_' "$PBXPROJ"; then
    sed -i '' 's/\$pbx_dir/Sources/g' "$PBXPROJ"
    echo "[OK] Godot 4.4+ плейсхолдеры пофикшены"
else
    echo "[—] плейсхолдеров нет (Godot 4.0–4.3)"
fi

# 8. ObjC bootstrap (всегда перезаписываем)
BOOTSTRAP_FILE="$PROJECT_DIR/WebViewBootstrap.m"

cat > "$BOOTSTRAP_FILE" << 'OBJC'
#import <Foundation/Foundation.h>

__attribute__((constructor))
static void initWebViewBridge(void) {
    NSLog(@"[WebView] constructor");
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"WebViewBridge");
        if (cls) {
            SEL sel = NSSelectorFromString(@"initBridge");
            if ([cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [cls performSelector:sel];
#pragma clang diagnostic pop
                NSLog(@"[WebView] мост запущен");
            }
        } else {
            NSLog(@"[WebView] класс не найден — проверь @objc(WebViewBridge)");
        }
    });
}
OBJC
echo "[OK] WebViewBootstrap.m обновлён"

if ! grep -q "WebViewBootstrap.m" "$PBXPROJ"; then
    BOOT_REF=$(python3 -c "import random; print(format(random.getrandbits(96), '024X'))")
    BOOT_BUILD=$(python3 -c "import random; print(format(random.getrandbits(96), '024X'))")

    sed -i '' "/\/\* End PBXFileReference section \*\//i\\
		${BOOT_REF} /* WebViewBootstrap.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = WebViewBootstrap.m; sourceTree = \"<group>\"; };
" "$PBXPROJ"

    sed -i '' "/\/\* End PBXBuildFile section \*\//i\\
		${BOOT_BUILD} /* WebViewBootstrap.m in Sources */ = {isa = PBXBuildFile; fileRef = ${BOOT_REF} /* WebViewBootstrap.m */; };
" "$PBXPROJ"

    sed -i '' "/\/\* Sources \*\/ = {/,/};/{
        /files = (/a\\
				${BOOT_BUILD} /* WebViewBootstrap.m in Sources */,
    }" "$PBXPROJ"

    MAIN_GROUP=$(grep 'mainGroup = ' "$PBXPROJ" | head -1 | sed 's/.*mainGroup = \([A-F0-9]*\).*/\1/')
    if [ -n "$MAIN_GROUP" ]; then
        sed -i '' "/${MAIN_GROUP}.*isa = PBXGroup/,/};/{
            /children = (/a\\
				${BOOT_REF} /* WebViewBootstrap.m */,
        }" "$PBXPROJ"
    fi
    echo "[OK] WebViewBootstrap.m добавлен в проект"
else
    echo "[—] WebViewBootstrap.m уже в проекте"
fi

# 9. ATS (WebView может грузить любые сайты)
INFO_PLIST=$(find "$PROJECT_DIR" -name "*-Info.plist" -maxdepth 2 2>/dev/null | head -1)
if [ -z "$INFO_PLIST" ]; then
    INFO_PLIST=$(find "$PROJECT_DIR" -name "Info.plist" -maxdepth 2 2>/dev/null | grep -v xcarchive | grep -v xcframework | head -1)
fi
if [ -z "$INFO_PLIST" ]; then
    INFO_PLIST=$(find "$PROJECT_DIR" -name "Export-Info.plist" -maxdepth 2 2>/dev/null | head -1)
fi

if [ -n "$INFO_PLIST" ] && [ -f "$INFO_PLIST" ]; then
    if ! grep -q "NSAppTransportSecurity" "$INFO_PLIST"; then
        /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$INFO_PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$INFO_PLIST" 2>/dev/null || true
        echo "[OK] ATS настроен"
    else
        echo "[—] ATS уже настроен"
    fi
else
    echo "[!] Info.plist не найден — ATS нужно настроить вручную в Xcode"
fi

echo ""
echo "=== Готово ==="
echo "Работает с Godot 4.0–4.6, iOS 12+, все iPhone"
echo "Открывай проект в Xcode, собирай и запускай."
