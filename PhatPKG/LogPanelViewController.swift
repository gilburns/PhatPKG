//
//  LogPanelViewController.swift
//  PhatPKG
//
//  Created by Gil Burns on 9/3/25.
//

import Cocoa

class LogPanelViewController: NSViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var logTextView: NSTextView!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var levelFilterPopUp: NSPopUpButton!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var autoScrollCheckbox: NSButton!
    
    // MARK: - Properties
    private var currentFilter: LogManager.LogLevel?
    private var autoScrollEnabled = true
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLogManager()
        refreshLogs()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        // Configure text view
        logTextView.isEditable = false
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.textColor = NSColor.textColor
        
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        
        // Setup filter popup
        levelFilterPopUp.removeAllItems()
        levelFilterPopUp.addItem(withTitle: "All Levels")
        levelFilterPopUp.menu?.addItem(NSMenuItem.separator())
        
        for level in LogManager.LogLevel.allCases {
            levelFilterPopUp.addItem(withTitle: "\(level.emoji) \(level.rawValue)")
        }
        
        levelFilterPopUp.selectItem(at: 0)
        
        // Setup auto-scroll checkbox
        autoScrollCheckbox.state = .on
        autoScrollEnabled = true
    }
    
    private func setupLogManager() {
        LogManager.shared.onNewLogEntry = { [weak self] entry in
            DispatchQueue.main.async {
                self?.appendLogEntry(entry)
            }
        }
    }
    
    // MARK: - Log Display Methods
    private func refreshLogs() {
        let entries: [LogManager.LogEntry]
        
        if let filter = currentFilter {
            entries = LogManager.shared.getEntries(withLevel: filter)
        } else {
            entries = LogManager.shared.getAllEntries()
        }
        
        let logText = entries.map { $0.formattedMessage }.joined(separator: "\n")
        logTextView.string = logText
        
        if autoScrollEnabled {
            scrollToBottom()
        }
    }
    
    private func appendLogEntry(_ entry: LogManager.LogEntry) {
        // Check if entry matches current filter
        if let filter = currentFilter, entry.level != filter {
            return
        }
        
        // Append to text view
        let currentText = logTextView.string
        let newText = currentText.isEmpty ? entry.formattedMessage : "\n" + entry.formattedMessage
        
        logTextView.string = currentText + newText
        
        if autoScrollEnabled {
            scrollToBottom()
        }
    }
    
    private func scrollToBottom() {
        let range = NSRange(location: logTextView.string.count, length: 0)
        logTextView.scrollRangeToVisible(range)
    }
    
    // MARK: - IBActions
    @IBAction func levelFilterChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        
        if selectedIndex == 0 {
            // "All Levels" selected
            currentFilter = nil
        } else {
            // Skip separator, so index 2 = first level, index 3 = second level, etc.
            let levelIndex = selectedIndex - 2
            if levelIndex >= 0 && levelIndex < LogManager.LogLevel.allCases.count {
                currentFilter = LogManager.LogLevel.allCases[levelIndex]
            }
        }
        
        refreshLogs()
    }
    
    @IBAction func clearLogs(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Clear All Logs"
        alert.informativeText = "Are you sure you want to clear all log entries? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            LogManager.shared.clearLogs()
            logTextView.string = ""
        }
    }
    
    @IBAction func exportLogs(_ sender: NSButton) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Logs"
        savePanel.nameFieldStringValue = "PhatPKG-Logs-\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)).txt"
        savePanel.allowedContentTypes = [.plainText]
        
        savePanel.begin { [weak self] result in
            if result == .OK, let url = savePanel.url {
                self?.performLogExport(to: url)
            }
        }
    }
    
    @IBAction func autoScrollToggled(_ sender: NSButton) {
        autoScrollEnabled = sender.state == .on
        if autoScrollEnabled {
            scrollToBottom()
        }
    }
    
    private func performLogExport(to url: URL) {
        let logContent = LogManager.shared.exportLogs()
        
        do {
            try logContent.write(to: url, atomically: true, encoding: .utf8)
            
            let alert = NSAlert()
            alert.messageText = "Export Successful"
            alert.informativeText = "Logs have been exported to:\n\(url.path)"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Failed to export logs: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}