# Deep Linking Setup Instructions

## Overview
Deep linking has been implemented to allow shared profile URLs (like `https://carto.app/profile/username`) to open the app directly and navigate to the correct user profile.

## What's Been Implemented

### 1. App Configuration ✅
- **Associated Domains**: Added `applinks:carto.app` to entitlements
- **URL Router**: Created `URLRouter` class to handle incoming URLs
- **URL Handling**: Added `onOpenURL` modifier to ContentView
- **Profile Navigation**: Implemented automatic navigation to user profiles

### 2. URL Patterns Supported ✅
- `https://carto.app/profile/username` - Opens user profile
- Future support for:
  - `https://carto.app/pin/id` - Pin details
  - `https://carto.app/list/id` - List details

## Required Web Setup

### 1. Host apple-app-site-association File
The `apple-app-site-association.json` file needs to be hosted on your domain:

**Location**: `https://carto.app/.well-known/apple-app-site-association`

**Steps**:
1. Upload the `apple-app-site-association.json` file to your web server
2. Rename it to `apple-app-site-association` (no extension)
3. Ensure it's accessible at: `https://carto.app/.well-known/apple-app-site-association`
4. Set Content-Type header to `application/json`

### 2. Update App Bundle ID
In the `apple-app-site-association` file, replace:
- `TEAMID` with your Apple Developer Team ID
- `com.yourcompany.project-columbus` with your actual bundle identifier

### 3. Test Universal Links
After hosting the file:
1. Test the association file: https://branch.io/resources/aasa-validator/
2. Test deep links by sharing a profile and tapping the link

## How It Works

### 1. URL Generation
When users tap "Share Profile", the app generates URLs like:
```
https://carto.app/profile/johndoe
```

### 2. URL Handling
When a user taps a shared link:
1. iOS checks the apple-app-site-association file
2. If the app is installed, it opens the app with the URL
3. The URLRouter parses the URL and extracts the username
4. The app navigates to the profile view for that user

### 3. Fallback Behavior
- If the app isn't installed, the link opens in Safari
- You can create a web page at that URL to show the profile or redirect to the App Store

## Testing Deep Links

### In Simulator
1. Open Safari in the simulator
2. Navigate to: `https://carto.app/profile/testuser`
3. The app should open and navigate to that user's profile

### On Device
1. Send yourself a link via Messages or Email
2. Tap the link - it should open the app

## Troubleshooting

### Links Don't Open App
1. Verify the apple-app-site-association file is hosted correctly
2. Check that the bundle ID and Team ID are correct
3. Try deleting and reinstalling the app
4. Ensure the domain matches exactly (carto.app)

### Navigation Doesn't Work
1. Check that the username exists in your database
2. Verify the URLRouter is properly integrated
3. Check console logs for error messages

## Future Enhancements
- Add support for pin and list deep links
- Implement web fallback pages
- Add analytics for deep link usage
- Support for custom schemes (carto://profile/username) 