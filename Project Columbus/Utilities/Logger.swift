//
//  Logger.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import Foundation
import os.log

// MARK: - Log Level
enum LogLevel: String, CaseIterable {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case success = "✅ SUCCESS"
    
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

// MARK: - Log Category
enum LogCategory: String, CaseIterable {
    case authentication = "Auth"
    case networking = "Network"
    case database = "Database"
    case location = "Location"
    case ui = "UI"
    case storage = "Storage"
    case notifications = "Notifications"
    case general = "General"
    
    var subsystem: String {
        return "com.carto.app"
    }
}

// MARK: - Logger
class Logger {
    static let shared = Logger()
    
    private var loggers: [LogCategory: os.Logger] = [:]
    
    #if DEBUG
    private let isDebugMode = true
    #else
    private let isDebugMode = false
    #endif
    
    private init() {
        // Initialize loggers for each category
        for category in LogCategory.allCases {
            loggers[category] = os.Logger(subsystem: category.subsystem, category: category.rawValue)
        }
    }
    
    // MARK: - Public Logging Methods
    
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    func success(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Convenience Methods for Common Operations
    
    func logAuthOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .authentication)
    }
    
    func logNetworkOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .networking)
    }
    
    func logDatabaseOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .database)
    }
    
    func logLocationOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .location)
    }
    
    func logUIOperation(_ message: String, level: LogLevel = .info) {
        log(message, level: level, category: .ui)
    }
    
    // MARK: - Private Methods
    
    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        // Log to system logger
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
func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}

func logSuccess(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.success(message, category: category, file: file, function: function, line: line)
} 