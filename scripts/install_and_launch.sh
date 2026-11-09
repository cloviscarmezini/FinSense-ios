#!/bin/bash

# Log for verification & debugging
LOG_FILE="/tmp/finsense_install.log"
echo "=== $(date): FinSense Build & Install Triggered ===" >> "$LOG_FILE"
echo "TARGET_DEVICE_IDENTIFIER: ${TARGET_DEVICE_IDENTIFIER}" >> "$LOG_FILE"
echo "RUN_DESTINATION_DEVICE_UDID: ${RUN_DESTINATION_DEVICE_UDID}" >> "$LOG_FILE"
echo "RUN_DESTINATION_DEVICE_NAME: ${RUN_DESTINATION_DEVICE_NAME}" >> "$LOG_FILE"
echo "PLATFORM_NAME: ${PLATFORM_NAME}" >> "$LOG_FILE"
echo "TARGET_DEVICE_PLATFORM_NAME: ${TARGET_DEVICE_PLATFORM_NAME}" >> "$LOG_FILE"
echo "RUN_DESTINATION_DEVICE_PLATFORM_NAME: ${RUN_DESTINATION_DEVICE_PLATFORM_NAME}" >> "$LOG_FILE"
echo "BUILT_PRODUCTS_DIR: ${BUILT_PRODUCTS_DIR}" >> "$LOG_FILE"
echo "SRCROOT: ${SRCROOT}" >> "$LOG_FILE"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "$SRCROOT" ]; then
    PROJECT_ROOT="$SRCROOT"
fi

# Locate the compiled FinSense executable
EXECUTABLE_PATH=""
if [ -n "$BUILT_PRODUCTS_DIR" ] && [ -f "$BUILT_PRODUCTS_DIR/FinSense" ]; then
    EXECUTABLE_PATH="$BUILT_PRODUCTS_DIR/FinSense"
elif [ -f "$PROJECT_ROOT/build/FinSense.app/FinSense" ]; then
    EXECUTABLE_PATH="$PROJECT_ROOT/build/FinSense.app/FinSense"
fi

APP_BUNDLE_DIR="$PROJECT_ROOT/build/FinSense.app"
if [ -n "$BUILT_PRODUCTS_DIR" ]; then
    APP_BUNDLE_DIR="$BUILT_PRODUCTS_DIR/FinSense.app"
fi

# Assemble / update the .app bundle
mkdir -p "$APP_BUNDLE_DIR"
if [ -n "$EXECUTABLE_PATH" ] && [ "$EXECUTABLE_PATH" != "$APP_BUNDLE_DIR/FinSense" ]; then
    cp "$EXECUTABLE_PATH" "$APP_BUNDLE_DIR/FinSense"
fi
cp "$PROJECT_ROOT/Info.plist" "$APP_BUNDLE_DIR/Info.plist"

# 1. Determine Device Identifier
DEVICE_ID="${TARGET_DEVICE_IDENTIFIER}"
if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" = "placeholder" ] || [[ "$DEVICE_ID" == dvtdevice* ]]; then
    if [ -n "$RUN_DESTINATION_DEVICE_UDID" ] && [ "$RUN_DESTINATION_DEVICE_UDID" != "placeholder" ] && [[ "$RUN_DESTINATION_DEVICE_UDID" != dvtdevice* ]]; then
        DEVICE_ID="$RUN_DESTINATION_DEVICE_UDID"
    fi
fi

# 2. Determine Reality: Physical Device vs Simulator
IS_PHYSICAL=0
if [ "$PLATFORM_NAME" = "iphoneos" ] || [ "$TARGET_DEVICE_PLATFORM_NAME" = "iphoneos" ] || [ "$RUN_DESTINATION_DEVICE_PLATFORM_NAME" = "iphoneos" ] || [[ "$BUILT_PRODUCTS_DIR" == *"-iphoneos"* ]]; then
    IS_PHYSICAL=1
elif [ -n "$DEVICE_ID" ] && xcrun simctl list devices 2>/dev/null | grep -q "$DEVICE_ID"; then
    IS_PHYSICAL=0
elif [ -n "$DEVICE_ID" ] && xcrun devicectl list devices 2>/dev/null | grep "$DEVICE_ID" | grep -q "physical"; then
    IS_PHYSICAL=1
fi

# 3. Fallbacks if DEVICE_ID is still empty / placeholder
if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" = "placeholder" ] || [[ "$DEVICE_ID" == dvtdevice* ]]; then
    if [ "$IS_PHYSICAL" = "1" ]; then
        if [ -n "$RUN_DESTINATION_DEVICE_NAME" ]; then
            DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | grep -F "$RUN_DESTINATION_DEVICE_NAME" | sed -E 's/.* ([0-9A-Fa-f-]+) \(UDID\).*/\1/' | head -n 1)
        fi
        if [ -z "$DEVICE_ID" ]; then
            DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | grep "physical" | grep "connected" | sed -E 's/.* ([0-9A-Fa-f-]+) \(UDID\).*/\1/' | head -n 1)
        fi
        # Default physical fallback if connected to Clovis's iPhone
        if [ -z "$DEVICE_ID" ] && xcrun devicectl list devices 2>/dev/null | grep -q "00008110-001621461491A01E"; then
            DEVICE_ID="00008110-001621461491A01E"
        fi
    else
        if [ -n "$RUN_DESTINATION_DEVICE_NAME" ]; then
            DEVICE_ID=$(xcrun simctl list devices 2>/dev/null | grep -F "$RUN_DESTINATION_DEVICE_NAME" | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' | head -n 1)
        fi
        if [ -z "$DEVICE_ID" ]; then
            DEVICE_ID=$(xcrun simctl list devices 2>/dev/null | grep -i "iphone" | grep "Booted" | head -n 1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
        fi
        if [ -z "$DEVICE_ID" ]; then
            DEVICE_ID=$(xcrun simctl list devices 2>/dev/null | grep "iPhone 18 Pro" | head -n 1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
        fi
        if [ -z "$DEVICE_ID" ]; then
            DEVICE_ID="E70E682A-0D28-4887-A345-380BDC015123"
        fi
    fi
fi

echo "Selected Device: $DEVICE_ID (IS_PHYSICAL=$IS_PHYSICAL)" >> "$LOG_FILE"

# 4. Compile AppIcon Asset Catalog into bundle with appropriate platform
ACTOOL_PLATFORM="iphonesimulator"
if [ "$IS_PHYSICAL" = "1" ]; then
    ACTOOL_PLATFORM="iphoneos"
fi

if [ -d "$PROJECT_ROOT/Sources/FinSense/Resources/Assets.xcassets" ]; then
    xcrun actool "$PROJECT_ROOT/Sources/FinSense/Resources/Assets.xcassets" \
        --compile "$APP_BUNDLE_DIR" \
        --platform "$ACTOOL_PLATFORM" \
        --minimum-deployment-target 17.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "/tmp/actool_partial.plist" >> "$LOG_FILE" 2>&1 || true

    if [ -f "$PROJECT_ROOT/Sources/FinSense/Resources/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png" ]; then
        cp "$PROJECT_ROOT/Sources/FinSense/Resources/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png" "$APP_BUNDLE_DIR/AppIcon60x60@3x.png"
    elif [ -f "$PROJECT_ROOT/Sources/FinSense/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-60x60@3x.png" ]; then
        cp "$PROJECT_ROOT/Sources/FinSense/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-60x60@3x.png" "$APP_BUNDLE_DIR/AppIcon60x60@3x.png"
    fi
fi

# 5. Code signing
SIGN_IDENTITY=""
PROVISIONING_PROFILE=""
ENTITLEMENTS_FILE="/tmp/finsense_entitlements.plist"
rm -f "$ENTITLEMENTS_FILE"

if [ "$IS_PHYSICAL" = "1" ]; then
    SIGN_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep -E "Apple Development|iPhone Developer" | head -n 1 | awk -F'"' '{print $2}' || true)
    
    # Locate matching provisioning profile if available
    for prof in "$HOME/Library/MobileDevice/Provisioning Profiles/"*.mobileprovision "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/"*.mobileprovision; do
        if [ -f "$prof" ]; then
            if security cms -D -i "$prof" 2>/dev/null | grep -qE "br\.com\.finsense\.ios|\*"; then
                PROVISIONING_PROFILE="$prof"
                break
            fi
        fi
    done

    if [ -n "$PROVISIONING_PROFILE" ]; then
        echo "Found Provisioning Profile: $PROVISIONING_PROFILE" >> "$LOG_FILE"
        cp "$PROVISIONING_PROFILE" "$APP_BUNDLE_DIR/embedded.mobileprovision"
        security cms -D -i "$PROVISIONING_PROFILE" 2>/dev/null | plutil -extract Entitlements xml1 -o "$ENTITLEMENTS_FILE" - 2>/dev/null || true
    fi
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing with identity: $SIGN_IDENTITY" >> "$LOG_FILE"
    if [ -f "$ENTITLEMENTS_FILE" ]; then
        codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_FILE" --timestamp=none "$APP_BUNDLE_DIR" >> "$LOG_FILE" 2>&1 || true
    else
        codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP_BUNDLE_DIR" >> "$LOG_FILE" 2>&1 || true
    fi
else
    echo "Signing ad-hoc (-)" >> "$LOG_FILE"
    codesign --force --sign - --timestamp=none "$APP_BUNDLE_DIR" >> "$LOG_FILE" 2>&1 || true
fi

# Keep project root build/ directory synchronized
if [ "$APP_BUNDLE_DIR" != "$PROJECT_ROOT/build/FinSense.app" ]; then
    mkdir -p "$PROJECT_ROOT/build"
    rm -rf "$PROJECT_ROOT/build/FinSense.app"
    cp -R "$APP_BUNDLE_DIR" "$PROJECT_ROOT/build/FinSense.app"
fi

# 6. Install and Launch on the resolved target
if [ "$IS_PHYSICAL" = "1" ]; then
    if [ -z "$DEVICE_ID" ]; then
        echo "No physical device connected or identified. Build completed without install." >> "$LOG_FILE"
        exit 0
    fi

    echo "Installing to physical device: $DEVICE_ID..." >> "$LOG_FILE"
    INSTALL_OUTPUT=$(xcrun devicectl device install app --device "$DEVICE_ID" "$APP_BUNDLE_DIR" 2>&1)
    INSTALL_EXIT=$?
    echo "$INSTALL_OUTPUT" >> "$LOG_FILE"

    if [ $INSTALL_EXIT -ne 0 ]; then
        if echo "$INSTALL_OUTPUT" | grep -qiE "0xe8008014|ApplicationVerificationFailed|invalid signature|integrity could not be verified"; then
            echo "ERROR: Code signature verification rejected by iOS (0xe8008014)." >> "$LOG_FILE"
            osascript -e 'display alert "FinSense: Assinatura Rejeitada pelo iPhone" message "O iOS desinstalou o FinSense imediatamente após o envio (Erro 0xe8008014: ApplicationVerificationFailed).\n\nDispositivos físicos da Apple não aceitam assinatura ad-hoc.\n\nPara rodar no seu iPhone:\n1. Abra o FinSense.xcodeproj no Xcode\n2. Vá em Signing & Capabilities e selecione sua Team (Apple ID)\n3. Execute o app diretamente pelo Xcode (Cmd+R)." as critical' 2>/dev/null || true
        elif echo "$INSTALL_OUTPUT" | grep -qi "developer mode"; then
            echo "WARNING: Developer Mode is disabled on the physical device." >> "$LOG_FILE"
            osascript -e 'display alert "FinSense: Modo Desenvolvedor Desativado" message "Ative o Modo de Desenvolvedor no iPhone em Ajustes > Privacidade e Segurança > Modo de Desenvolvedor, e reinicie o aparelho." as critical' 2>/dev/null || true
        elif echo "$INSTALL_OUTPUT" | grep -qi "device was still locked"; then
            echo "WARNING: Physical device is locked. Please unlock the device." >> "$LOG_FILE"
            osascript -e 'display alert "FinSense: iPhone Bloqueado" message "Desbloqueie a tela do seu iPhone para permitir a instalação do app." as warning' 2>/dev/null || true
        else
            echo "ERROR: Physical device installation failed." >> "$LOG_FILE"
            osascript -e 'display alert "FinSense: Falha na Instalação" message "Ocorreu um erro ao instalar o app no iPhone. Verifique os logs em /tmp/finsense_install.log." as warning' 2>/dev/null || true
        fi
        exit $INSTALL_EXIT
    fi

    echo "Launching br.com.finsense.ios on physical device: $DEVICE_ID..." >> "$LOG_FILE"
    LAUNCH_OUTPUT=$(xcrun devicectl device process launch --device "$DEVICE_ID" br.com.finsense.ios 2>&1)
    LAUNCH_EXIT=$?
    echo "$LAUNCH_OUTPUT" >> "$LOG_FILE"

    echo "=== FinSense physical device deployment finished (install=$INSTALL_EXIT, launch=$LAUNCH_EXIT) ===" >> "$LOG_FILE"
else
    echo "Installing to simulator: $DEVICE_ID..." >> "$LOG_FILE"

    # Boot device if not already booted
    DEVICE_STATUS=$(xcrun simctl list devices 2>/dev/null | grep "$DEVICE_ID" | grep -o "Booted" || true)
    if [ "$DEVICE_STATUS" != "Booted" ]; then
        echo "Booting $DEVICE_ID..." >> "$LOG_FILE"
        xcrun simctl boot "$DEVICE_ID" 2>> "$LOG_FILE" || true
    fi

    # Install the app
    xcrun simctl install "$DEVICE_ID" "$APP_BUNDLE_DIR" >> "$LOG_FILE" 2>&1

    # Launch or focus DeviceHub (replaces old Simulator.app)
    echo "Launching DeviceHub..." >> "$LOG_FILE"
    open -a "/Applications/Xcode.app/Contents/Applications/DeviceHub.app" 2>> "$LOG_FILE" || true

    # Launch the app bundle
    echo "Launching br.com.finsense.ios..." >> "$LOG_FILE"
    xcrun simctl launch "$DEVICE_ID" br.com.finsense.ios >> "$LOG_FILE" 2>&1

    echo "=== FinSense simulator deployment completed ===" >> "$LOG_FILE"
fi
