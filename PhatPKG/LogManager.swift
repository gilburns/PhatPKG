//
//  LogManager.swift
//  PhatPKG
//
//  Created by Gil Burns on 9/3/25.
//

import Foundation

/// Centralized logging system for PhatPKG
/// Maintains an in-memory log buffer and provides UI integration
class LogManager {
    
    // MARK: - Singleton
    static let shared = LogManager()
    
    // MARK: - Types
    enum LogLevel: String, CaseIterable {
        case info = "INFO"
        case warning = "WARNING"  
        case error = "ERROR"
        case debug = "DEBUG"
        
        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .debug: return "🔍"
            }
        }
    }
    
    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let source: String
        let message: String
        
        var formattedMessage: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return "\(formatter.string(from: timestamp)) \(level.emoji) [\(source)] \(message)"
        }
    }
    
    // MARK: - Properties
    private var logEntries: [LogEntry] = []
    private let maxEntries = 1000 // Limit memory usage
    private let queue = DispatchQueue(label: "com.phatpkg.logging", qos: .utility)
    
    /// Callback for UI updates when new logs are added
    var onNewLogEntry: ((LogEntry) -> Void)?
    
    /// When true, also prints to console (for Xcode debugging). Defaults to true for GUI app.
    var shouldPrintToConsole = true
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Log a message with specified level and source
    func log(_ message: String, level: LogLevel = .info, source: String = "PhatPKG") {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            source: source,
            message: message
        )
        
        queue.async {
            // Add to log buffer
            self.logEntries.append(entry)
            
            // Trim if needed
            if self.logEntries.count > self.maxEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxEntries)
            }
            
            // Notify UI on main queue
            DispatchQueue.main.async {
                self.onNewLogEntry?(entry)
            }
        }
        
        // Also print to console for Xcode debugging (if enabled)
        if shouldPrintToConsole {
            print(entry.formattedMessage)
        }
    }
    
    /// Get all log entries
    func getAllEntries() -> [LogEntry] {
        return queue.sync {
            return logEntries
        }
    }
    
    /// Get logs filtered by level
    func getEntries(withLevel level: LogLevel) -> [LogEntry] {
        return queue.sync {
            return logEntries.filter { $0.level == level }
        }
    }
    
    /// Export logs as formatted text
    func exportLogs() -> String {
        let entries = getAllEntries()
        
        var exportText = "PhatPKG Log Export\n"
        exportText += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))\n"
        exportText += "Total Entries: \(entries.count)\n"
        exportText += String(repeating: "-", count: 80) + "\n\n"
        
        for entry in entries {
            exportText += "\(entry.formattedMessage)\n"
        }
        
        return exportText
    }
    
    /// Clear all log entries
    func clearLogs() {
        queue.async {
            self.logEntries.removeAll()
        }
    }
    
    // MARK: - Convenience Methods
    
    func info(_ message: String, source: String = "PhatPKG") {
        log(message, level: .info, source: source)
    }
    
    func warning(_ message: String, source: String = "PhatPKG") {
        log(message, level: .warning, source: source)
    }
    
    func error(_ message: String, source: String = "PhatPKG") {
        log(message, level: .error, source: source)
    }
    
    func debug(_ message: String, source: String = "PhatPKG") {
        log(message, level: .debug, source: source)
    }
}