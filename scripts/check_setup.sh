#!/bin/bash

# CARTO Setup Check Script
# Verifies Apple Developer account and code signing setup

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Checking CARTO deployment setup...${NC}"

# Configuration
PROJECT_NAME="Project Columbus copy"
SCHEME_NAME="Project Columbus"
WORKSPACE_PATH="Project Columbus copy.xcodeproj"

# Check 1: Xcode Command Line Tools
echo -e "${BLUE}📱 Checking Xcode installation...${NC}"
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -1)
    echo -e "${GREEN}✅ ${XCODE_VERSION}${NC}"
else
    echo -e "${RED}❌ Xcode command line tools not found${NC}"
    echo -e "${YELLOW}   Install with: xcode-select --install${NC}"
    exit 1
fi

# Check 2: Project exists
echo -e "${BLUE}📂 Checking project files...${NC}"
if [ -f "$WORKSPACE_PATH" ]; then
    echo -e "${GREEN}✅ Project file found${NC}"
else
    echo -e "${RED}❌ Project file not found: $WORKSPACE_PATH${NC}"
    exit 1
fi

# Check 3: Get signing identity
echo -e "${BLUE}🔐 Checking code signing setup...${NC}"
SIGNING_IDENTITIES=$(security find-identity -v -p codesigning | grep "Apple Development\|Apple Distribution" | wc -l | tr -d ' ')

if [ "$SIGNING_IDENTITIES" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $SIGNING_IDENTITIES signing identit(y/ies)${NC}"
    security find-identity -v -p codesigning | grep "Apple Development\|Apple Distribution" | head -3
else
    echo -e "${RED}❌ No Apple Developer signing certificates found${NC}"
    echo -e "${YELLOW}   1. Open Xcode → Preferences → Accounts${NC}"
    echo -e "${YELLOW}   2. Sign in with your Apple ID${NC}"
    echo -e "${YELLOW}   3. Download certificates${NC}"
    exit 1
fi

# Check 4: Build settings
echo -e "${BLUE}⚙️ Checking build configuration...${NC}"
BUNDLE_ID=$(xcodebuild -project "$WORKSPACE_PATH" -showBuildSettings -configuration Release | grep PRODUCT_BUNDLE_IDENTIFIER | head -1 | sed 's/.*= //')
VERSION=$(xcodebuild -project "$WORKSPACE_PATH" -showBuildSettings -configuration Release | grep MARKETING_VERSION | head -1 | sed 's/.*= //')
BUILD_NUMBER=$(xcodebuild -project "$WORKSPACE_PATH" -showBuildSettings -configuration Release | grep CURRENT_PROJECT_VERSION | head -1 | sed 's/.*= //')

echo -e "${GREEN}✅ Bundle ID: $BUNDLE_ID${NC}"
echo -e "${GREEN}✅ Version: $VERSION${NC}"
echo -e "${GREEN}✅ Build: $BUILD_NUMBER${NC}"

# Check 5: Test build (archive only, no export)
echo -e "${BLUE}🔨 Testing archive build...${NC}"
TEMP_ARCHIVE="/tmp/CARTO_test.xcarchive"
rm -rf "$TEMP_ARCHIVE"

if xcodebuild archive \
    -project "$WORKSPACE_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -archivePath "$TEMP_ARCHIVE" \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    > /dev/null 2>&1; then
    
    echo -e "${GREEN}✅ Archive build successful${NC}"
    rm -rf "$TEMP_ARCHIVE"
else
    echo -e "${RED}❌ Archive build failed${NC}"
    echo -e "${YELLOW}   Try building in Xcode first to resolve any issues${NC}"
    exit 1
fi

# Summary
echo -e "${GREEN}🎉 Setup check complete!${NC}"
echo -e "${BLUE}📋 Summary:${NC}"
echo -e "   • Xcode: Ready"
echo -e "   • Project: Found"
echo -e "   • Code Signing: $SIGNING_IDENTITIES certificate(s)"
echo -e "   • Bundle ID: $BUNDLE_ID"
echo -e "   • Version: $VERSION (Build $BUILD_NUMBER)"
echo -e "   • Archive: Successful"
echo ""
echo -e "${GREEN}✅ Ready for TestFlight deployment!${NC}"
echo -e "${BLUE}   Run: ./scripts/deploy_testflight.sh${NC}"
echo -e "${BLUE}   Or:  ./scripts/deploy.sh \"commit message\"${NC}" 