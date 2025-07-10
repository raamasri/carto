# 🔒 Supabase Backend Backup Documentation

This directory contains a complete backup of your Supabase backend rules, policies, and configurations for your encrypted location sharing app.

## 📁 Backup Files

### 1. `supabase_backup.sql`
- **Complete SQL backup** of all database schema, RLS policies, and configurations
- Ready to restore to a new Supabase project
- Includes all tables, indexes, foreign keys, and triggers
- Contains the encrypted location sharing feature implementation

### 2. `supabase_policies_backup.json` 
- **Structured JSON backup** of all RLS policies
- Easy to read and reference
- Includes policy details, foreign keys, and indexes
- Migration history included

### 3. `backup_supabase.sh`
- **Automated backup script** (for future use)
- Can be run to create new backups
- Includes verification and summary

## 🔧 How to Restore

### Option 1: Complete Restore (Recommended)
```bash
# 1. Create new Supabase project
# 2. Get the database URL from project settings
# 3. Run the backup SQL file
psql "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres" -f supabase_backup.sql
```

### Option 2: Manual Restore
1. Copy each CREATE TABLE statement from `supabase_backup.sql`
2. Run them in your new Supabase project's SQL editor
3. Copy and run all RLS policies
4. Verify all indexes and foreign keys are created

## 🛡️ Security Features Backed Up

### Row Level Security (RLS)
- ✅ All tables have RLS enabled
- ✅ Users can only access their own data
- ✅ Friend groups properly restrict access
- ✅ Shared locations use sender/recipient controls

### Encrypted Location Sharing
- ✅ `shared_locations` table with encryption fields
- ✅ `user_public_keys` table for P256 keys
- ✅ `friend_groups` with privacy tiers
- ✅ Performance indexes for queries

### Access Controls
- ✅ Users own their profiles, pins, and lists
- ✅ Friend groups controlled by creators
- ✅ Location sharing requires explicit consent
- ✅ Public keys readable for encryption

## 📊 Database Schema Overview

### Core Tables
- `users` - User profiles and authentication
- `pins` - Location pins and reviews
- `lists` - User-created pin collections
- `follows` - Social following relationships
- `notifications` - App notifications

### Location Sharing Tables
- `friend_groups` - Privacy-tiered friend groups
- `friend_group_members` - Group membership
- `shared_locations` - Encrypted location shares
- `user_public_keys` - P256 public keys for encryption
- `location_privacy_settings` - User privacy controls

### Performance Optimizations
- Indexes on foreign keys
- Composite indexes for common queries
- Optimized indexes for location sharing
- Proper constraints and cascades

## 🔄 Migration History

Your backup includes all migrations up to:
- `20250710042415` - optimize_shared_locations_performance_v3

## ⚠️ Important Notes

1. **Auth Integration**: The backup assumes Supabase Auth is enabled
2. **Environment Variables**: Update your app's Supabase URL and keys
3. **Testing**: Always test the restore in a development environment first
4. **Data Migration**: This backup includes schema only, not user data

## 🚀 Next Steps

1. **Store Safely**: Keep these backup files in version control
2. **Regular Backups**: Run the backup script monthly
3. **Test Restore**: Practice restoring to ensure it works
4. **Document Changes**: Update backups when you modify the schema

## 📞 Support

If you need help with the backup or restore process:
1. Check the Supabase documentation
2. Verify all RLS policies are active after restore
3. Test your app's core functions
4. Monitor for any permission errors

---

**Generated**: 2025-01-10  
**Project**: rthgzxorsccgeztwaxnt  
**Feature**: Encrypted Location Sharing with RLS 