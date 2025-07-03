//
//  DateUtils.swift
//  Project Columbus
//
//  Created by Assistant
//

import Foundation

// MARK: - Date Utilities
struct DateUtils {
    
    // MARK: - Formatters
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let iso8601BasicFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    // MARK: - Utility Functions
    
    /// Convert ISO8601 string to Date
    static func dateFromISO8601String(_ string: String) -> Date? {
        return iso8601Formatter.date(from: string) ?? iso8601BasicFormatter.date(from: string)
    }
    
    /// Convert Date to ISO8601 string
    static func iso8601StringFromDate(_ date: Date) -> String {
        return iso8601Formatter.string(from: date)
    }
    
    /// Get relative time string (e.g., "2 hours ago")
    static func relativeTimeString(from date: Date) -> String {
        return relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Check if date is today
    static func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    /// Check if date is yesterday
    static func isYesterday(_ date: Date) -> Bool {
        return Calendar.current.isDateInYesterday(date)
    }
    
    /// Check if date is within the last week
    static func isWithinLastWeek(_ date: Date) -> Bool {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return date >= weekAgo
    }
    
    /// Check if date is within the last month
    static func isWithinLastMonth(_ date: Date) -> Bool {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return date >= monthAgo
    }
    
    /// Check if date is within the last year
    static func isWithinLastYear(_ date: Date) -> Bool {
        let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return date >= yearAgo
    }
    
    /// Get smart date string (today, yesterday, or date)
    static func smartDateString(from date: Date) -> String {
        if isToday(date) {
            return "Today"
        } else if isYesterday(date) {
            return "Yesterday"
        } else if isWithinLastWeek(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day of week
            return formatter.string(from: date)
        } else {
            return shortDateFormatter.string(from: date)
        }
    }
    
    /// Get smart time string with date context
    static func smartTimeString(from date: Date) -> String {
        let dateString = smartDateString(from: date)
        let timeString = timeOnlyFormatter.string(from: date)
        
        if dateString == "Today" {
            return timeString
        } else {
            return "\(dateString) at \(timeString)"
        }
    }
    
    /// Calculate age from date of birth
    static func age(from dateOfBirth: Date) -> Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year ?? 0
    }
    
    /// Get time interval in human readable format
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
    
    /// Get start of day for a date
    static func startOfDay(for date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
    
    /// Get end of day for a date
    static func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay(for: date)) ?? date
    }
} 