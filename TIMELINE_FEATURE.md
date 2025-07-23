# Timeline Feature Documentation

## Overview

The Timeline feature automatically tracks places users visit and creates post drafts based on their location history. This feature provides a seamless way for users to document their journeys and share experiences with different audiences.

## Key Features

### 🕒 Automatic Timeline Tracking
- **Location Detection**: Automatically detects when users arrive at new locations
- **Duration Tracking**: Records how long users stay at each place  
- **Smart Filtering**: Only tracks significant location changes (configurable sensitivity)
- **Minimum Stay Duration**: Configurable threshold to avoid tracking brief stops

### 📝 Automatic Post Draft Creation
- **Draft Generation**: Creates a post draft for each timeline entry automatically
- **Editable Content**: Users can add titles, descriptions, ratings, and reactions
- **Media Support**: Support for adding photos and videos to drafts
- **Friend Mentions**: Ability to mention friends in posts

### 🔒 Privacy-First Sharing Controls
- **Just Me**: Private posts visible only to the account owner
- **Close Friends**: Visible only to users in close friends groups
- **Mutuals**: Visible to mutual followers (people you follow who follow you back)
- **Public**: Visible to everyone

### ⚙️ Customizable Settings
- **Timeline Control**: Enable/disable timeline tracking
- **Duration Threshold**: Set minimum stay duration (1-30 minutes)
- **Location Sensitivity**: Adjust distance threshold for new locations (50-500 meters)
- **Data Management**: Export, import, and clear timeline data

## Architecture

### Data Models

#### TimelineEntry
```swift
struct TimelineEntry {
    let id: UUID
    let userId: UUID
    let locationName: String
    let city: String
    let latitude: Double
    let longitude: Double
    let arrivalTime: Date
    let departureTime: Date?
    let duration: TimeInterval?
    let isCurrentLocation: Bool
    let createdAt: Date
    let updatedAt: Date
}
```

#### PostDraft
```swift
struct PostDraft {
    let id: UUID
    let userId: UUID
    let timelineEntryId: UUID
    // Location data...
    var title: String
    var content: String
    var rating: Double?
    var reaction: Reaction?
    var mediaURLs: [String]
    var tags: [String]
    var mentionedFriends: [UUID]
    var sharingType: PostDraftSharingType
    var isPublished: Bool
    var publishedAt: Date?
}
```

### Database Schema

The feature uses two main tables:

- **timeline_entries**: Stores location visits and durations
- **post_drafts**: Stores automatic post drafts with user content

Both tables include:
- Row Level Security (RLS) policies for data privacy
- Automatic timestamp updates
- Duration calculation triggers
- Comprehensive indexing for performance

### Components

#### TimelineManager
- **Purpose**: Core manager for timeline tracking and draft creation
- **Responsibilities**: 
  - Location change detection
  - Timeline entry management
  - Automatic draft creation
  - Database operations

#### TimelineView
- **Purpose**: Main interface for viewing timeline entries
- **Features**:
  - Time-based filtering (Today, This Week, This Month, All Time)
  - Grouped display by date
  - Draft count indicator
  - Settings and drafts access

#### PostDraftsView
- **Purpose**: Interface for managing post drafts
- **Features**:
  - Draft editing capabilities
  - Publishing controls
  - Sharing settings
  - Draft deletion

#### TimelineSettingsView
- **Purpose**: Configuration interface for timeline feature
- **Features**:
  - Timeline enable/disable
  - Tracking sensitivity settings
  - Privacy controls
  - Data management options

## Setup Instructions

### 1. Database Setup

Run the provided setup script to create the necessary database tables:

```bash
./setup_timeline_tables.sh
```

This will create:
- `timeline_entries` table
- `post_drafts` table  
- Required indexes
- RLS policies
- Database triggers

### 2. App Integration

The timeline feature is automatically integrated into the app's navigation sidebar. Users can access it through:

1. **Main Navigation**: Timeline option in the sidebar menu
2. **Settings**: Timeline settings in the main settings menu
3. **Drafts**: Post drafts accessible from timeline view

### 3. Location Permissions

The timeline feature requires location permissions to function:

- **When In Use**: Minimum requirement for timeline tracking
- **Always**: Recommended for continuous tracking
- **Precise Location**: Required for accurate place detection

## User Experience Flow

### 1. Enable Timeline
- User navigates to Timeline in sidebar
- If disabled, user sees enable prompt
- User enables timeline and grants location permissions

### 2. Automatic Tracking
- App detects significant location changes
- Creates timeline entry when user stays ≥5 minutes (configurable)
- Automatically generates post draft

### 3. Draft Management
- User views timeline and sees draft count indicator
- User can edit drafts: add content, ratings, reactions
- User selects sharing audience
- User publishes draft or keeps private

### 4. Timeline Review
- User can review their timeline by time periods
- View location details and durations
- Access related post drafts

## Privacy Considerations

### Data Protection
- **Owner-Only Access**: Timeline entries are private by default
- **RLS Policies**: Database-level security ensures data isolation
- **Sharing Controls**: Granular control over post visibility

### Location Privacy
- **Opt-In**: Timeline feature is disabled by default
- **User Control**: Users can disable tracking at any time
- **Data Deletion**: Users can clear all timeline data

### Sharing Privacy
- **Just Me**: Complete privacy, visible only to owner
- **Close Friends**: Leverages existing friend group system
- **Mutuals**: Uses mutual follow relationships
- **Public**: Open visibility with user consent

## Technical Implementation Details

### Location Tracking
- Uses `CLLocationManager` for location updates
- Implements significant location change detection
- Respects user's location privacy settings
- Includes battery optimization considerations

### Data Storage
- Supabase PostgreSQL database
- Real-time sync capabilities
- Offline support with local caching
- Automatic conflict resolution

### Performance Optimizations
- Efficient database queries with proper indexing
- Lazy loading of timeline data
- Memory-efficient location tracking
- Background processing for draft creation

## Future Enhancements

### Planned Features
- **Timeline Sharing**: Allow sharing timeline with friends
- **Location Insights**: Analytics on places visited
- **Smart Suggestions**: AI-powered draft content suggestions
- **Export Options**: Multiple export formats (JSON, CSV, GPX)
- **Integration**: Connect with other social platforms

### Potential Improvements
- **Geofencing**: Custom location boundaries
- **Activity Recognition**: Detect transportation modes
- **Weather Integration**: Include weather data in timeline
- **Photo Integration**: Automatic photo association
- **Collaboration**: Shared timeline entries with friends

## Troubleshooting

### Common Issues

#### Timeline Not Tracking
- Check location permissions
- Verify timeline is enabled in settings
- Ensure app has background refresh enabled
- Check minimum stay duration settings

#### Drafts Not Creating
- Verify database connection
- Check timeline entry creation
- Review minimum stay duration
- Ensure user has valid session

#### Sharing Not Working
- Verify friend relationships in database
- Check RLS policies
- Confirm sharing type selection
- Review user permissions

### Debug Information
- Timeline manager logs location updates
- Database operations include error logging
- UI provides feedback for user actions
- Settings show current configuration

## Support

For technical issues or questions about the timeline feature:

1. Check the troubleshooting section above
2. Review the database logs for errors
3. Verify location permissions and settings
4. Test with different location sensitivity settings

The timeline feature is designed to be privacy-first and user-controlled, providing a seamless way to document and share location-based experiences.