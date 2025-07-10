# Supabase Backup - v0.74.0

## Backup Information
- **Version**: v0.74.0
- **Date**: 2025-07-09 23:18:52
- **Project ID**: rthgzxorsccgeztwaxnt
- **Timestamp**: 20250709_231852

## Features Included

### 🎉 v0.74.0 - Major Feature Release
- **Real-Time Friend Activity Feed**: Live activity tracking with push notifications
- **Smart Recommendations Engine**: ML-powered personalized suggestions
- **4 New Tables**: friend_activities, activity_feed_subscriptions, place_recommendations, user_interactions
- **Enhanced Security**: 7 new RLS policies for social features

### 🔐 v0.73.7 Features (Included)
- **Encrypted Location Sharing**: End-to-end encryption with P256 ECDH
- **Friend Groups**: Private location sharing groups
- **Privacy Tiers**: Precise, approximate, and city-level sharing
- **Auto-expiration**: Time-based location sharing

## Database Structure

### New Tables in v0.74.0
1. **friend_activities**: Real-time activity tracking
2. **activity_feed_subscriptions**: User subscription preferences
3. **place_recommendations**: ML-generated recommendations
4. **user_interactions**: User behavior tracking for ML

### Total Database Stats
- **Tables**: 30 (26 from v0.73.7 + 4 new)
- **RLS Policies**: 74 (67 from v0.73.7 + 7 new)
- **Performance Indexes**: 16+ (optimized for real-time queries)

## Restoration Instructions
```bash
# Restore schema
psql -h db.rthgzxorsccgeztwaxnt.supabase.co -U postgres -d postgres < supabase_backup_v0.74.0.sql

# Apply RLS policies
# Use the Supabase dashboard or API to restore policies from supabase_policies_backup_v0.74.0.json
```

## Files in this Backup
- **supabase_backup_v0.74.0.sql**: Complete database schema with all tables and data
- **supabase_policies_backup_v0.74.0.json**: All RLS policies in JSON format
- **backup_manifest.json**: Detailed backup metadata
- **README.md**: This file
