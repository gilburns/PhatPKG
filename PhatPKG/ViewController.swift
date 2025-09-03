//
//  ViewController.swift
//  PhatPKG
//
//  Created by Gil Burns on 8/24/25.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet var arm64SourceFile: NSTextField!
    @IBOutlet var intelX86SourceFile: NSTextField!
    @IBOutlet var outputDirectory: NSTextField!
    
    @IBOutlet var arm64SelectButton: NSButton!
    @IBOutlet var intelX86SelectButton: NSButton!
    @IBOutlet var outputDirectorySelectButton: NSButton!
    
    @IBOutlet var buildButton: NSButton!
    
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var progressLabel: NSTextField!
    
    // MARK: - Log Panel Outlets
    @IBOutlet weak var showLogPanelButton: NSButton!
    @IBOutlet weak var logPanelContainer: NSView!
    
    
    // MARK: - Log Panel Properties
    private var logPanelViewController: LogPanelViewController?
    private var logPanelVisible = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up text field change notifications
        arm64SourceFile.target = self
        arm64SourceFile.action = #selector(textFieldChanged(_:))
        
        intelX86SourceFile.target = self
        intelX86SourceFile.action = #selector(textFieldChanged(_:))
        
        outputDirectory.target = self
        outputDirectory.action = #selector(textFieldChanged(_:))
        
        updateBuildButtonState()
        setupLogPanel()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Lock window size
        if let window = view.window {
            
            let windowWidth = view.window?.frame.width ?? 0
            let windowHeight = view.window?.frame.height ?? 0

            let fixedSize = NSSize(width: windowWidth, height: windowHeight)
            window.minSize = fixedSize
            window.maxSize = fixedSize
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


    // MARK: Actions
    @IBAction func selectArm64SourceFile(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: self.view.window!) { (response) in
            if response == .init(rawValue: 1) {
                
                let path = panel.urls.first?.path ?? ""
                self.arm64SourceFile.stringValue = path
                self.updateBuildButtonState()
            }
        }
    }

    @IBAction func selectIntelX86SourceFile(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: self.view.window!) { (response) in
            if response == .init(rawValue: 1) {
                
                let path = panel.urls.first?.path ?? ""
                self.intelX86SourceFile.stringValue = path
                self.updateBuildButtonState()
            }
        }
    }
    
    @IBAction func selectOutputDirectory(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories.toggle()
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: self.view.window!) { (response) in
            if response == .init(rawValue: 1) {
                
                let path = panel.urls.first?.path ?? ""
                self.outputDirectory.stringValue = path
                self.updateBuildButtonState()
            }
        }
    }
    
    
    @IBAction func buildPhatPKG(_ sender: Any?) {
        progressIndicator.startAnimation(nil)
        uiStateIsEnabled(for: false)
        LogManager.shared.info("Starting universal package build...", source: "ViewController")
        progressLabel.stringValue = "Building universal package..."
        
        Task {
            do {
                let core = PhatPKGCore(
                    progressCallback: { [weak self] progress in
                        DispatchQueue.main.async {
                            self?.progressLabel.stringValue = progress
                        }
                    },
                    logCallback: { [weak self] message in
                        LogManager.shared.log(message, source: "PhatPKGCore")
                    }
                )
                
                try await core.createUniversalPackage(
                    armInput: arm64SourceFile.stringValue,
                    intelInput: intelX86SourceFile.stringValue,
                    outputDirectory: outputDirectory.stringValue
                )
                
                DispatchQueue.main.async {
                    self.progressLabel.stringValue = "Package created successfully!"
                    LogManager.shared.info("Package created successfully!", source: "ViewController")
                }
                
            } catch {
                LogManager.shared.error("Build failed: \(error.localizedDescription)", source: "ViewController")
                DispatchQueue.main.async {
                    self.progressLabel.stringValue = "Build failed: \(error.localizedDescription)"
                }
            }
            
            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                self.uiStateIsEnabled(for: true)

                self.updateBuildButtonState()
            }
        }
    }
    
    @IBAction func openGitHubWiki(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "https://github.com/gilburns/PhatPKG/wiki")!)
    }
    
    @IBAction func openGitHubRepository(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "https://github.com/gilburns/PhatPKG")!)
    }
    
    @IBAction func toggleLogPanel(_ sender: Any?) {
        toggleLogPanelVisibility()
    }

    // MARK: - Text Field Actions
    
    @objc func textFieldChanged(_ sender: NSTextField) {
        updateBuildButtonState()
    }
    
    // MARK: - Helpers
    
    /// Updates the build button state based on required field validation
    func updateBuildButtonState() {
        let hasArm64Source = isValidInput(arm64SourceFile.stringValue)
        let hasIntelSource = isValidInput(intelX86SourceFile.stringValue)
        let hasOutputDirectory = !outputDirectory.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        buildButton.isEnabled = hasArm64Source && hasIntelSource && hasOutputDirectory
    }
    
    /// Updates the interface elements based on the building state
    func uiStateIsEnabled(for state: Bool) {
        
        buildButton.isEnabled = state
        arm64SourceFile.isEnabled = state
        arm64SelectButton.isEnabled = state
        intelX86SourceFile.isEnabled = state
        intelX86SelectButton.isEnabled = state
        outputDirectory.isEnabled = state
        outputDirectorySelectButton.isEnabled = state

    }
    
    /// Validates if input is either a valid file path or URL
    func isValidInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        
        // Check if it's a URL
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed) != nil
        }
        
        // Check if it's a file path
        return !trimmed.isEmpty
    }
    
    // MARK: - Log Panel Methods
    
    private func setupLogPanel() {
        // Initialize log panel but keep it hidden
        logPanelContainer.isHidden = true
        showLogPanelButton.title = "Show Logs"
        
        // Load log panel view controller
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let logVC = storyboard.instantiateController(withIdentifier: "LogPanelViewController") as? LogPanelViewController {
            logPanelViewController = logVC
            
            // Add as child view controller
            addChild(logVC)
            logPanelContainer.addSubview(logVC.view)
            
            // Setup constraints
            logVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                logVC.view.topAnchor.constraint(equalTo: logPanelContainer.topAnchor),
                logVC.view.leadingAnchor.constraint(equalTo: logPanelContainer.leadingAnchor),
                logVC.view.trailingAnchor.constraint(equalTo: logPanelContainer.trailingAnchor),
                logVC.view.bottomAnchor.constraint(equalTo: logPanelContainer.bottomAnchor)
            ])
        }
    }
    
    private func toggleLogPanelVisibility() {
        logPanelVisible.toggle()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.allowsImplicitAnimation = true
            
            if logPanelVisible {
                logPanelContainer.isHidden = false
                showLogPanelButton.title = "Hide Logs"
                showLogPanelButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Hide Logs")
                
                // Expand window height
                if let window = view.window {
                    let currentFrame = window.frame
                    let newFrame = NSRect(
                        x: currentFrame.origin.x,
                        y: currentFrame.origin.y - 200, // Move up to accommodate panel
                        width: currentFrame.width,
                        height: currentFrame.height + 200 // Add height for panel
                    )
                    window.setFrame(newFrame, display: true, animate: true)
                    
                    let newSize = NSSize(width: currentFrame.width, height: currentFrame.height + 200)
                    window.minSize = newSize
                    window.maxSize = newSize
                    
                }
            } else {
                logPanelContainer.isHidden = true
                showLogPanelButton.title = "Show Logs"
                showLogPanelButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Show Logs")

                // Collapse window height
                if let window = view.window {
                    let currentFrame = window.frame
                    let newFrame = NSRect(
                        x: currentFrame.origin.x,
                        y: currentFrame.origin.y + 200, // Move down
                        width: currentFrame.width,
                        height: currentFrame.height - 200 // Remove height
                    )
                    window.setFrame(newFrame, display: true, animate: true)
                    
                    let newSize = NSSize(width: currentFrame.width, height: currentFrame.height - 200)
                    window.minSize = newSize
                    window.maxSize = newSize

                }
            }
        })
    }
    
    /// Logs messages using the centralized LogManager
    /// - Parameter message: Message to log
    func log(_ message: String) {
        LogManager.shared.info(message, source: "ViewController")
    }
}

