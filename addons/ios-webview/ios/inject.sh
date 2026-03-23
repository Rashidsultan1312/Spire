#!/bin/bash
set -euo pipefail

# inject.sh — патчит Xcode проект после экспорта из Godot
# Совместимость: Godot 4.0–4.6, iOS 12+, iPhone + iPad
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

echo "=== WebView inject ==="
echo "Xcode project: $XCODEPROJ"
echo "Project dir:   $PROJECT_DIR"

gen_id() {
    python3 -c "import random; print(format(random.getrandbits(96), '024X'))"
}

# Бэкап
cp "$PBXPROJ" "$PBXPROJ.webview-backup"
echo "[OK] бэкап project.pbxproj"

# --- 1. WebViewBridge.swift ---

cp "$SWIFT_SRC" "$SWIFT_DST"
echo "[OK] WebViewBridge.swift скопирован"

if grep -q "WebViewBridge.swift" "$PBXPROJ"; then
    echo "[—] WebViewBridge.swift уже в проекте"
else
    FILE_REF=$(gen_id)
    BUILD_FILE=$(gen_id)

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

# --- 2. WebViewBootstrap.m (ObjC constructor) ---

BOOTSTRAP_FILE="$PROJECT_DIR/WebViewBootstrap.m"
cat > "$BOOTSTRAP_FILE" << 'OBJC'
#import <Foundation/Foundation.h>

__attribute__((constructor))
static void initWebViewBridge(void) {
    NSLog(@"[WebView] constructor — bootstrap");
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
            } else {
                NSLog(@"[WebView] initBridge не найден в классе");
            }
        } else {
            NSLog(@"[WebView] класс WebViewBridge не найден");
        }
    });
}
OBJC
echo "[OK] WebViewBootstrap.m создан"

if ! grep -q "WebViewBootstrap.m" "$PBXPROJ"; then
    BOOT_REF=$(gen_id)
    BOOT_BUILD=$(gen_id)

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

# --- 3. WebKit.framework ---

if grep -q "WebKit.framework" "$PBXPROJ"; then
    echo "[—] WebKit.framework уже есть"
else
    WK_REF=$(gen_id)
    WK_BUILD=$(gen_id)

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

# --- 4. Build Settings ---

add_build_setting() {
    local KEY="$1"
    local VALUE="$2"
    if grep -q "$KEY" "$PBXPROJ"; then
        echo "[—] $KEY уже задан"
    else
        sed -i '' "/buildSettings = {/a\\
				$KEY = $VALUE;
" "$PBXPROJ"
        echo "[OK] $KEY = $VALUE"
    fi
}

add_build_setting "SWIFT_VERSION" "5.0"
add_build_setting "DEFINES_MODULE" "YES"
add_build_setting "CLANG_ENABLE_MODULES" "YES"

# --- 5. Bridging Header ---

BRIDGE_HEADER="$PROJECT_DIR/BridgingHeader.h"
if [ ! -f "$BRIDGE_HEADER" ]; then
    echo "// Bridging header for WebViewBridge (Swift <-> ObjC)" > "$BRIDGE_HEADER"
    echo "[OK] BridgingHeader.h создан"
fi

if ! grep -q "SWIFT_OBJC_BRIDGING_HEADER" "$PBXPROJ"; then
    sed -i '' '/buildSettings = {/a\
				SWIFT_OBJC_BRIDGING_HEADER = "BridgingHeader.h";
' "$PBXPROJ"
    echo "[OK] SWIFT_OBJC_BRIDGING_HEADER задан"
else
    echo "[—] SWIFT_OBJC_BRIDGING_HEADER уже задан"
fi

# --- 6. Godot 4.4+ placeholder fix ---

if grep -q '\$pbx_' "$PBXPROJ"; then
    sed -i '' 's/\$pbx_dir/Sources/g' "$PBXPROJ"
    echo "[OK] Godot 4.4+ плейсхолдеры пофикшены"
else
    echo "[—] плейсхолдеров нет"
fi

# --- 7. ATS (разрешить любые URL) ---

INFO_PLIST=""
for pattern in "*-Info.plist" "Info.plist" "Export-Info.plist"; do
    found=$(find "$PROJECT_DIR" -maxdepth 2 -name "$pattern" ! -path "*/xcarchive/*" ! -path "*/xcframework/*" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        INFO_PLIST="$found"
        break
    fi
done

if [ -n "$INFO_PLIST" ] && [ -f "$INFO_PLIST" ]; then
    if ! grep -q "NSAppTransportSecurity" "$INFO_PLIST"; then
        /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$INFO_PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$INFO_PLIST" 2>/dev/null || true
        echo "[OK] ATS — NSAllowsArbitraryLoads = true"
    else
        echo "[—] ATS уже настроен"
    fi
    echo "    Info.plist: $INFO_PLIST"
else
    echo "[!] Info.plist не найден — ATS надо настроить вручную"
fi

# --- 8. Валидация ---

echo ""
echo "=== Проверка ==="

ERRORS=0

check_in_project() {
    local FILE="$1"
    if grep -q "$FILE" "$PBXPROJ"; then
        echo "  [✓] $FILE в проекте"
    else
        echo "  [✗] $FILE НЕ в проекте!"
        ERRORS=$((ERRORS + 1))
    fi
}

check_in_project "WebViewBridge.swift"
check_in_project "WebViewBootstrap.m"
check_in_project "WebKit.framework"

if grep -q "SWIFT_VERSION" "$PBXPROJ"; then
    echo "  [✓] SWIFT_VERSION задан"
else
    echo "  [✗] SWIFT_VERSION не задан!"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "SWIFT_OBJC_BRIDGING_HEADER" "$PBXPROJ"; then
    echo "  [✓] Bridging Header задан"
else
    echo "  [✗] Bridging Header не задан!"
    ERRORS=$((ERRORS + 1))
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "=== Всё ОК — собирай проект ==="
else
    echo "=== ОШИБКИ: $ERRORS — проверь вывод выше ==="
    exit 1
fi

echo "Совместимость: Godot 4.0–4.6, iOS 12+, iPhone + iPad"
