# CARTO Deployment Scripts

This directory contains automated deployment scripts for the CARTO iOS app.

## 🚀 Quick Start

### Setup Check (Recommended First)
```bash
# Verify your setup before deploying
./scripts/check_setup.sh
```

This will check:
- ✅ Xcode installation
- ✅ Project files
- ✅ Code signing certificates
- ✅ Build configuration
- ✅ Archive capability

### Complete Deployment (Recommended)
```bash
# Deploy everything in one command
./scripts/deploy.sh "Your commit message here"
```

This will:
1. ✅ Add and commit all changes
2. ✅ Push to GitHub repository  
3. ✅ Archive the app for Release
4. ✅ Upload to TestFlight for internal testing

### TestFlight Only
```bash
# Just upload to TestFlight (if code is already committed)
./scripts/deploy_testflight.sh
```

## 📋 Prerequisites

### Required
- ✅ Xcode with valid Apple Developer account
- ✅ App Store Connect access
- ✅ Valid code signing certificates
- ✅ Git repository configured

### Optional (for cleaner output)
```bash
# Install xcpretty for prettier build logs
gem install xcpretty
```

## 📱 TestFlight Process

After running the deployment script:

1. **Archive & Upload** (~5-10 minutes)
   - App is archived for Release configuration
   - Binary uploaded to App Store Connect

2. **Apple Processing** (~5-10 minutes)
   - Apple processes the binary
   - Build appears in TestFlight

3. **Internal Testing Ready** 🎉
   - Build available for internal testers
   - Push notifications sent to testers

## 🔧 Configuration

The scripts automatically detect:
- ✅ Project name and scheme
- ✅ Current version number (MARKETING_VERSION)
- ✅ Build number (CURRENT_PROJECT_VERSION)
- ✅ Code signing settings

## 📊 Example Usage

```bash
# After implementing a new feature
./scripts/deploy.sh "v0.54.1: Added pin sharing feature"

# Output:
# 🚀 Starting complete CARTO deployment...
# 📝 Committing changes...
# ☁️ Pushing to repository...
# 📱 Deploying to TestFlight...
# 📦 Archiving app...
# ☁️ Uploading to TestFlight...
# 🎉 Successfully uploaded CARTO v0.54.1 to TestFlight!
```

## 🐛 Troubleshooting

### Common Issues

**"Failed to Use Accounts" or "No accounts"**
1. Open Xcode → Preferences → Accounts
2. Click "+" and sign in with your Apple ID
3. Select your team and click "Download Manual Profiles"
4. Ensure your Apple Developer Program membership is active
5. Try running `./scripts/check_setup.sh` to verify

**"No signing certificate found"**
- Check Xcode → Preferences → Accounts
- Ensure Apple Developer account is signed in
- Verify certificates in Keychain Access

**"Archive failed"**
- Ensure project builds successfully in Xcode first
- Check for any compilation errors
- Verify scheme is set to Release configuration

**"Upload failed"**
- Check App Store Connect access
- Verify app bundle ID matches App Store Connect
- Ensure version number is incremented

### Manual Fallback

If scripts fail, you can always use Xcode:
1. Product → Archive
2. Distribute App → App Store Connect
3. Upload

## 🔗 Links

- [App Store Connect](https://appstoreconnect.apple.com)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [Xcode Build Settings](https://developer.apple.com/documentation/xcode/build-settings-reference) 