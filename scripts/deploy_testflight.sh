#!/bin/bash

# CARTO TestFlight Deployment Script
# This script archives the app and uploads it to TestFlight for internal testing

set -e  # Exit on any error

echo "🚀 Starting CARTO TestFlight deployment..."

# Configuration
PROJECT_NAME="Project Columbus copy"
SCHEME_NAME="Project Columbus"
WORKSPACE_PATH="Project Columbus copy.xcodeproj"
ARCHIVE_PATH="./build/CARTO.xcarchive"
EXPORT_PATH="./build/export"
BUILD_DIR="./build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create build directory
echo -e "${BLUE}📁 Creating build directory...${NC}"
mkdir -p "$BUILD_DIR"

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

# Get the current version from the project
VERSION=$(xcodebuild -project "$WORKSPACE_PATH" -showBuildSettings -configuration Release | grep MARKETING_VERSION | head -1 | sed 's/.*= //')
BUILD_NUMBER=$(xcodebuild -project "$WORKSPACE_PATH" -showBuildSettings -configuration Release | grep CURRENT_PROJECT_VERSION | head -1 | sed 's/.*= //')

echo -e "${GREEN}📱 Building CARTO v${VERSION} (Build ${BUILD_NUMBER})${NC}"

# Archive the app
echo -e "${BLUE}📦 Archiving app...${NC}"

# Check if xcpretty is available for cleaner output
if command -v xcpretty &> /dev/null; then
    XCPRETTY_CMD="| xcpretty"
else
    XCPRETTY_CMD=""
    echo -e "${YELLOW}💡 Install xcpretty for cleaner output: gem install xcpretty${NC}"
fi

xcodebuild archive \
    -project "$WORKSPACE_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    $XCPRETTY_CMD

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ Archive failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive created successfully!${NC}"

# Create export options plist
echo -e "${BLUE}📝 Creating export options...${NC}"
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>manageAppVersionAndBuildNumber</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EOF

# Export and upload to App Store Connect
echo -e "${BLUE}☁️ Uploading to TestFlight...${NC}"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 Successfully uploaded CARTO v${VERSION} to TestFlight!${NC}"
    echo -e "${YELLOW}📱 The build will be available for internal testing once Apple processes it (usually 5-10 minutes).${NC}"
    echo -e "${BLUE}🔗 Check your build status at: https://appstoreconnect.apple.com${NC}"
    
    # Clean up build artifacts (optional)
    echo -e "${BLUE}🧹 Cleaning up build artifacts...${NC}"
    rm -rf "$BUILD_DIR"
    
else
    echo -e "${RED}❌ Upload to TestFlight failed!${NC}"
    
    # Check for common issues and provide helpful messages
    if grep -q "Failed to Use Accounts" "$BUILD_DIR"/*.log 2>/dev/null || grep -q "No accounts" "$BUILD_DIR"/*.log 2>/dev/null; then
        echo -e "${YELLOW}🔐 Apple Developer Account Issue:${NC}"
        echo -e "${YELLOW}   1. Open Xcode → Preferences → Accounts${NC}"
        echo -e "${YELLOW}   2. Sign in with your Apple Developer account${NC}"
        echo -e "${YELLOW}   3. Download certificates and provisioning profiles${NC}"
        echo -e "${YELLOW}   4. Try running the script again${NC}"
    elif grep -q "No signing certificate" "$BUILD_DIR"/*.log 2>/dev/null; then
        echo -e "${YELLOW}📋 Code Signing Issue:${NC}"
        echo -e "${YELLOW}   1. Check your Apple Developer account status${NC}"
        echo -e "${YELLOW}   2. Verify certificates in Keychain Access${NC}"
        echo -e "${YELLOW}   3. Update provisioning profiles in Xcode${NC}"
    else
        echo -e "${YELLOW}💡 General troubleshooting:${NC}"
        echo -e "${YELLOW}   1. Ensure you have a valid Apple Developer account${NC}"
        echo -e "${YELLOW}   2. Check App Store Connect access${NC}"
        echo -e "${YELLOW}   3. Verify bundle ID matches App Store Connect${NC}"
        echo -e "${YELLOW}   4. Try archiving manually in Xcode first${NC}"
    fi
    
    echo -e "${BLUE}🔗 For detailed logs, check: https://appstoreconnect.apple.com${NC}"
    exit 1
fi

echo -e "${GREEN}✅ TestFlight deployment complete!${NC}" 