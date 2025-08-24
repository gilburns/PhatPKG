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
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Lock window size
//        if let window = view.window {
//            let fixedSize = NSSize(width: 550, height: 272)
//            window.setContentSize(fixedSize)
//            window.minSize = fixedSize
//            window.maxSize = fixedSize
//        }
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
                        self?.log(message)
                    }
                )
                
                try await core.createUniversalPackage(
                    armInput: arm64SourceFile.stringValue,
                    intelInput: intelX86SourceFile.stringValue,
                    outputDirectory: outputDirectory.stringValue
                )
                
                DispatchQueue.main.async {
                    self.progressLabel.stringValue = "Package created successfully!"
                }
                
            } catch {
                log("Build failed: \(error.localizedDescription)")
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
    
    /// Logs messages to console
    /// Provides consistent logging format for update operations
    /// - Parameter message: Message to log
    func log(_ message: String) {
        print("[PhatPKG] \(message)")
    }
}

