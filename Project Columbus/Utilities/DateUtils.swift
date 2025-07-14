//
//  DateUtils.swift
//  Project Columbus
//
//  Created by Assistant
//
//  DESCRIPTION:
//  This file contains comprehensive date and time utility functions for Project Columbus (Carto).
//  It provides a centralized set of formatters and helper functions for consistent date/time
//  handling throughout the application.
//
//  FEATURES:
//  - Multiple date formatters for different display contexts
//  - ISO8601 parsing and formatting for API integration
//  - Relative time formatting (e.g., "2 hours ago")
//  - Smart date display logic for various UI contexts
//  - Time interval formatting for duration display
//  - Date range utilities for filtering and comparisons
//  - Age calculation utilities
//
//  ARCHITECTURE:
//  - Static formatters for performance optimization
//  - Comprehensive utility functions for common operations
//  - Thread-safe formatter implementations
//  - Fallback parsing for robust date handling
//

import Foundation

// MARK: - Date Utilities

/**
 * DateUtils
 * 
 * A comprehensive utility struct that provides standardized date and time formatting
 * functionality throughout the Project Columbus app. This struct contains static
 * formatters and utility functions to ensure consistent date/time handling across
 * all UI components and data operations.
 * 
 * FORMATTER CATEGORIES:
 * - ISO8601 formatters for API communication
 * - Display formatters for user-facing content
 * - Relative time formatters for social features
 * - Time-only formatters for specific contexts
 * 
 * UTILITY FUNCTIONS:
 * - Date range checking and validation
 * - Smart date display logic
 * - Time interval calculations
 * - Age and duration computations
 */
struct DateUtils {
    
    // MARK: - ISO8601 Formatters
    
    /**
     * ISO8601 formatter with fractional seconds support
     * 
     * This formatter is used for parsing and formatting dates that include
     * fractional seconds, commonly used in API responses and database timestamps.
     * It ensures compatibility with high-precision timestamp formats.
     */
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /**
     * Basic ISO8601 formatter without fractional seconds
     * 
     * This formatter serves as a fallback for parsing ISO8601 dates that
     * don't include fractional seconds. It provides robust date parsing
     * capabilities for various API responses and legacy data formats.
     */
    static let iso8601BasicFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // MARK: - Display Formatters
    
    /**
     * Standard display formatter for general date/time presentation
     * 
     * This formatter provides a balanced approach to date/time display,
     * showing both date and time information in a user-friendly format.
     * Used for general timestamps throughout the app.
     */
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /**
     * Short date formatter for compact date display
     * 
     * This formatter shows only the date portion without time information.
     * Ideal for contexts where space is limited or time is not relevant,
     * such as list items or summary views.
     */
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    /**
     * Time-only formatter for displaying just the time portion
     * 
     * This formatter shows only the time without date information.
     * Useful for contexts where the date is implied or already displayed
     * elsewhere, such as message timestamps within a conversation.
     */
    static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    /**
     * Relative date formatter for social features
     * 
     * This formatter provides human-readable relative time strings
     * like "2 hours ago", "yesterday", etc. It's particularly useful
     * for social features where recency is important.
     */
    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    // MARK: - Core Conversion Functions
    
    /**
     * Converts an ISO8601 string to a Date object
     * 
     * This function attempts to parse an ISO8601 date string using both
     * the fractional seconds formatter and the basic formatter as fallback.
     * This ensures robust parsing of various ISO8601 formats.
     * 
     * @param string The ISO8601 date string to parse
     * @return Optional Date object, nil if parsing fails
     */
    static func dateFromISO8601String(_ string: String) -> Date? {
        return iso8601Formatter.date(from: string) ?? iso8601BasicFormatter.date(from: string)
    }
    
    /**
     * Converts a Date object to an ISO8601 string
     * 
     * This function formats a Date object into a standard ISO8601 string
     * with fractional seconds support. Used for API communication and
     * database storage operations.
     * 
     * @param date The Date object to format
     * @return ISO8601 formatted string
     */
    static func iso8601StringFromDate(_ date: Date) -> String {
        return iso8601Formatter.string(from: date)
    }
    
    /**
     * Generates a relative time string from a date
     * 
     * This function creates human-readable relative time strings
     * like "2 hours ago", "yesterday", etc. It's particularly useful
     * for social features and activity feeds.
     * 
     * @param date The date to compare against current time
     * @return Relative time string (e.g., "2 hours ago")
     */
    static func relativeTimeString(from date: Date) -> String {
        return relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Date Range Checking
    
    /**
     * Checks if a date falls within today
     * 
     * This function determines whether a given date occurs within
     * the current calendar day, useful for filtering and display logic.
     * 
     * @param date The date to check
     * @return Boolean indicating if the date is today
     */
    static func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    /**
     * Checks if a date falls within yesterday
     * 
     * This function determines whether a given date occurred yesterday,
     * useful for smart date display and activity filtering.
     * 
     * @param date The date to check
     * @return Boolean indicating if the date was yesterday
     */
    static func isYesterday(_ date: Date) -> Bool {
        return Calendar.current.isDateInYesterday(date)
    }
    
    /**
     * Checks if a date falls within the last week
     * 
     * This function determines whether a given date occurred within
     * the past 7 days, useful for recent activity filtering.
     * 
     * @param date The date to check
     * @return Boolean indicating if the date is within the last week
     */
    static func isWithinLastWeek(_ date: Date) -> Bool {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return date >= weekAgo
    }
    
    /**
     * Checks if a date falls within the last month
     * 
     * This function determines whether a given date occurred within
     * the past month, useful for activity filtering and analytics.
     * 
     * @param date The date to check
     * @return Boolean indicating if the date is within the last month
     */
    static func isWithinLastMonth(_ date: Date) -> Bool {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return date >= monthAgo
    }
    
    /**
     * Checks if a date falls within the last year
     * 
     * This function determines whether a given date occurred within
     * the past year, useful for long-term activity filtering.
     * 
     * @param date The date to check
     * @return Boolean indicating if the date is within the last year
     */
    static func isWithinLastYear(_ date: Date) -> Bool {
        let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return date >= yearAgo
    }
    
    // MARK: - Smart Display Functions
    
    /**
     * Generates a smart date string with contextual formatting
     * 
     * This function provides intelligent date display that adapts based
     * on how recent the date is. It returns "Today", "Yesterday", the
     * day of the week for recent dates, or a formatted date for older dates.
     * 
     * @param date The date to format
     * @return Smart date string optimized for context
     */
    static func smartDateString(from date: Date) -> String {
        if isToday(date) {
            return "Today"
        } else if isYesterday(date) {
            return "Yesterday"
        } else if isWithinLastWeek(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day of week (e.g., "Monday")
            return formatter.string(from: date)
        } else {
            return shortDateFormatter.string(from: date)
        }
    }
    
    /**
     * Generates a smart time string with date context
     * 
     * This function creates intelligent time display that includes date
     * context when needed. For today's events, it shows just the time.
     * For other dates, it includes the date information.
     * 
     * @param date The date to format
     * @return Smart time string with appropriate context
     */
    static func smartTimeString(from date: Date) -> String {
        let dateString = smartDateString(from: date)
        let timeString = timeOnlyFormatter.string(from: date)
        
        if dateString == "Today" {
            return timeString
        } else {
            return "\(dateString) at \(timeString)"
        }
    }
    
    // MARK: - Calculation Utilities
    
    /**
     * Calculates age from a date of birth
     * 
     * This function computes the current age in years from a given
     * date of birth, handling leap years and calendar edge cases properly.
     * 
     * @param dateOfBirth The birth date
     * @return Age in years as an integer
     */
    static func age(from dateOfBirth: Date) -> Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year ?? 0
    }
    
    /**
     * Converts a time interval to a human-readable string
     * 
     * This function formats time intervals into readable duration strings
     * in HH:MM:SS or MM:SS format, useful for displaying elapsed time
     * or duration information.
     * 
     * @param interval The time interval in seconds
     * @return Formatted time string (e.g., "2:30:45" or "5:23")
     */
    static func timeIntervalString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Date Boundary Utilities
    
    /**
     * Gets the start of day for a given date
     * 
     * This function returns a Date object representing the beginning
     * of the day (00:00:00) for the given date, useful for date range
     * calculations and filtering.
     * 
     * @param date The date to get the start of day for
     * @return Date object representing the start of the day
     */
    static func startOfDay(for date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    /**
     * Gets the end of day for a given date
     * 
     * This function returns a Date object representing the end of the
     * day (23:59:59) for the given date, useful for date range calculations
     * and filtering operations.
     * 
     * @param date The date to get the end of day for
     * @return Date object representing the end of the day
     */
    static func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay(for: date)) ?? date
    }
} 