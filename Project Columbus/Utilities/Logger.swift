//
//  Logger.swift
//  Project Columbus
//
//  Created by Assistant on Date
//
//  DESCRIPTION:
//  This file contains a comprehensive logging system for Project Columbus (Carto).
//  It provides structured logging with multiple levels, categories, and output targets
//  to facilitate debugging, monitoring, and troubleshooting throughout the application.
//
//  FEATURES:
//  - Multiple log levels (debug, info, warning, error, success)
//  - Categorized logging for different app components
//  - Automatic file/line/function tracking
//  - Debug vs release mode handling
//  - Integration with Apple's unified logging system
//  - Convenient global logging functions
//
//  ARCHITECTURE:
//  - Singleton pattern for centralized logging
//  - Enum-based type safety for levels and categories
//  - Automatic formatting and metadata inclusion
//  - Dual output (console + system logger)
//  - Category-specific loggers for organization
//

import Foundation
import os.log

// MARK: - Log Level System

/**
 * LogLevel
 * 
 * Defines the various severity levels for log messages throughout the application.
 * Each level has a specific purpose and visual representation for easy identification
 * in logs and console output.
 */
enum LogLevel: String, CaseIterable {
    case debug = "🔍 DEBUG"        // Detailed information for debugging
    case info = "ℹ️ INFO"          // General informational messages
    case warning = "⚠️ WARNING"    // Potential issues or warnings
    case error = "❌ ERROR"        // Error conditions and failures
    case success = "✅ SUCCESS"    // Successful operations and completions
    
    /**
     * Maps log levels to corresponding OSLogType values
     * This enables proper integration with Apple's unified logging system
     */
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .success: return .info
        }
    }
}

// MARK: - Log Category System

/**
 * LogCategory
 * 
 * Defines logical categories for organizing log messages by functional area.
 * This categorization helps with filtering, searching, and debugging specific
 * parts of the application.
 */
enum LogCategory: String, CaseIterable {
    case authentication = "Auth"           // User authentication and authorization
    case networking = "Network"            // Network requests and API calls
    case database = "Database"             // Database operations and queries
    case location = "Location"             // Location services and GPS
    case ui = "UI"                        // User interface operations
    case storage = "Storage"              // File system and data storage
    case notifications = "Notifications"   // Push notifications and alerts
    case general = "General"              // General application operations
    
    /**
     * Subsystem identifier for Apple's unified logging system
     * All categories share the same subsystem for consistent organization
     */
    var subsystem: String {
        return "com.carto.app"
    }
}

// MARK: - Logger Implementation

/**
 * Logger
 * 
 * A comprehensive logging system that provides structured, categorized logging
 * with automatic metadata inclusion and multiple output targets.
 * 
 * FEATURES:
 * - Singleton pattern for consistent logging throughout the app
 * - Category-based organization for better log filtering
 * - Automatic file, function, and line number tracking
 * - Debug vs release mode handling
 * - Integration with Apple's unified logging system
 * - Convenient wrapper methods for common operations
 * 
 * USAGE:
 * - Use Logger.shared methods for detailed logging
 * - Use global functions for quick logging
 * - Choose appropriate categories for better organization
 * - Use appropriate log levels for proper severity indication
 */
class Logger {
    /// Shared singleton instance for consistent logging
    static let shared = Logger()
    
    /// Dictionary of category-specific loggers for Apple's unified logging
    private var loggers: [LogCategory: os.Logger] = [:]
    
    /// Debug mode flag determined at compile time
    #if DEBUG
    private let isDebugMode = true
    #else
    private let isDebugMode = false
    #endif
    
    /**
     * Private initializer to enforce singleton pattern
     * Initializes category-specific loggers for Apple's unified logging system
     */
    private init() {
        // Initialize loggers for each category
        for category in LogCategory.allCases {
            loggers[category] = os.Logger(subsystem: category.subsystem, category: category.rawValue)
        }
    }
    
    // MARK: - Primary Logging Methods
    
    /**
     * Logs a debug message with detailed diagnostic information
     * 
     * @param message The message to log
     * @param category The functional category (defaults to general)
     * @param file The source file (automatically captured)
     * @param function The function name (automatically captured)
     * @param line The line number (automatically captured)
     */
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /**
     * Logs an informational message
     * 
     * @param message The message to log
     * @param category The functional category (defaults to general)
     * @param file The source file (automatically captured)
     * @param function The function name (automatically captured)
     * @param line The line number (automatically captured)
     */
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /**
     * Logs a warning message for potential issues
     * 
     * @param message The message to log
     * @param category The functional category (defaults to general)
     * @param file The source file (automatically captured)
     * @param function The function name (automatically captured)
     * @param line The line number (automatically captured)
     */
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /**
     * Logs an error message for failures and exceptions
     * 
     * @param message The message to log
     * @param category The functional category (defaults to general)
     * @param file The source file (automatically captured)
     * @param function The function name (automatically captured)
     * @param line The line number (automatically captured)
     */
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /**
     * Logs a success message for completed operations
     * 
     * @param message The message to log
     * @param category The functional category (defaults to general)
     * @param file The source file (automatically captured)
     * @param function The function name (automatically captured)
     * @param line The line number (automatically captured)
     */
    func success(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Convenience Methods for Specific Operations
    
    /**
     * Logs authentication-related operations
     * 
     * @param message The message to log
     * @param level The log level (defaults to info)
     */
    func logAuthOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .authentication)
    }
    
    /**
     * Logs network-related operations
     * 
     * @param message The message to log
     * @param level The log level (defaults to info)
     */
    func logNetworkOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .networking)
    }
    
    /**
     * Logs database-related operations
     * 
     * @param message The message to log
     * @param level The log level (defaults to info)
     */
    func logDatabaseOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .database)
    }
    
    /**
     * Logs location-related operations
     * 
     * @param message The message to log
     * @param level The log level (defaults to info)
     */
    func logLocationOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .location)
    }
    
    /**
     * Logs UI-related operations
     * 
     * @param message The message to log
     * @param level The log level (defaults to info)
     */
    func logUIOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .ui)
    }
    
    // MARK: - Core Logging Implementation
    
    /**
     * Core logging method that handles message formatting and output
     * 
     * This method formats the log message with metadata and sends it to
     * both the system logger and console output (in debug mode).
     * 
     * @param message The message to log
     * @param level The severity level
     * @param category The functional category
     * @param file The source file
     * @param function The function name
     * @param line The line number
     */
    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        // Extract filename from full path for cleaner output
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        // Log to Apple's unified logging system
        if let logger = loggers[category] {
            logger.log(level: level.osLogType, "\(formattedMessage)")
        }
        
        // Also log to console in debug mode for easier development
        if isDebugMode {
            print("\(level.rawValue) [\(category.rawValue)] \(formattedMessage)")
        }
    }
}

// MARK: - Global Convenience Functions

/**
 * Global convenience functions for quick logging without accessing the singleton
 * These functions provide a more concise way to log messages while maintaining
 * the same functionality as the Logger class methods.
 */

/**
 * Logs a debug message using the global logger instance
 * 
 * @param message The message to log
 * @param category The functional category (defaults to general)
 * @param file The source file (automatically captured)
 * @param function The function name (automatically captured)
 * @param line The line number (automatically captured)
 */
func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

/**
 * Logs an informational message using the global logger instance
 * 
 * @param message The message to log
 * @param category The functional category (defaults to general)
 * @param file The source file (automatically captured)
 * @param function The function name (automatically captured)
 * @param line The line number (automatically captured)
 */
func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

/**
 * Logs a warning message using the global logger instance
 * 
 * @param message The message to log
 * @param category The functional category (defaults to general)
 * @param file The source file (automatically captured)
 * @param function The function name (automatically captured)
 * @param line The line number (automatically captured)
 */
func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

/**
 * Logs an error message using the global logger instance
 * 
 * @param message The message to log
 * @param category The functional category (defaults to general)
 * @param file The source file (automatically captured)
 * @param function The function name (automatically captured)
 * @param line The line number (automatically captured)
 */
func logError(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}

/**
 * Logs a success message using the global logger instance
 * 
 * @param message The message to log
 * @param category The functional category (defaults to general)
 * @param file The source file (automatically captured)
 * @param function The function name (automatically captured)
 * @param line The line number (automatically captured)
 */
func logSuccess(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.success(message, category: category, file: file, function: function, line: line)
} 