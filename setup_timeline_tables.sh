#!/bin/bash

# Setup Timeline Tables Script
# Project Columbus - Timeline Feature
# Created: 2025-01-10

echo "🚀 Setting up Timeline tables for Project Columbus..."

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "❌ psql command not found. Please install PostgreSQL client tools."
    exit 1
fi

# Check if timeline_schema.sql exists
if [ ! -f "timeline_schema.sql" ]; then
    echo "❌ timeline_schema.sql file not found in current directory."
    exit 1
fi

# Prompt for database connection details
echo "📋 Enter your Supabase database connection details:"
read -p "Host (e.g., db.xxx.supabase.co): " DB_HOST
read -p "Port (default: 5432): " DB_PORT
read -p "Database name (default: postgres): " DB_NAME
read -p "Username (default: postgres): " DB_USER
read -s -p "Password: " DB_PASSWORD
echo

# Set defaults
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-postgres}
DB_USER=${DB_USER:-postgres}

# Construct connection string
PGPASSWORD=$DB_PASSWORD

echo "🔗 Connecting to database..."

# Execute the schema file
if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f timeline_schema.sql; then
    echo "✅ Timeline tables created successfully!"
    echo ""
    echo "📊 The following tables have been created:"
    echo "   • timeline_entries - Stores user location visits and durations"
    echo "   • post_drafts - Stores automatic post drafts from timeline entries"
    echo ""
    echo "🔒 Row Level Security policies have been applied to ensure data privacy."
    echo "🚀 Your timeline feature is ready to use!"
else
    echo "❌ Failed to create timeline tables. Please check your connection details and try again."
    exit 1
fi

echo ""
echo "📝 Next steps:"
echo "   1. Build and run your iOS app"
echo "   2. Enable timeline in the app settings"
echo "   3. Start exploring places to build your timeline!"