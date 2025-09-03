//
//  main.swift
//  PhatPKG-CLI
//
//  Created by Gil Burns on 8/24/25.
//

import ArgumentParser
import Foundation

/// Command-line tool for creating universal macOS packages from separate ARM64 and Intel x86_64 applications
@available(macOS 10.15, *)
@main
struct PhatPKGCLI: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "PhatPKG-CLI",
        abstract: "Create universal macOS packages from separate ARM64 and Intel x86_64 applications.",
        discussion: """
            PhatPKG-CLI creates a universal installer package that automatically detects the system 
            architecture and installs the appropriate version of your app.
            
            Supported input formats:
            • Local files: .app, .zip, .tar.bz2, .tbz, .bz2, .dmg
            • Remote URLs: Any HTTPS URL to supported formats
            
            Examples:
              PhatPKG-CLI --arm64 MyApp-arm64.zip --intel MyApp-x86.zip --output ~/Desktop
              PhatPKG-CLI --arm64 https://example.com/MyApp-arm64.dmg --intel https://example.com/MyApp.dmg --output ./packages
            """,
        version: "1.1.0"
    )
    
    @Option(name: .shortAndLong, help: "Path or URL to ARM64 (Apple Silicon) application source")
    var arm64: String
    
    @Option(name: .shortAndLong, help: "Path or URL to Intel x86_64 application source")
    var intel: String
    
    @Option(name: .shortAndLong, help: "Output directory for the universal package")
    var output: String
    
    @Flag(name: .shortAndLong, help: "Show verbose output during processing")
    var verbose = false
    
    func run() async throws {
        // Print banner
        print("🎯 PhatPKG CLI v\(Self.configuration.version)")
        print("Creating universal macOS package...\n")
        
        // Validate inputs
        guard !arm64.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError("ARM64 source path cannot be empty")
        }
        
        guard !intel.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError("Intel source path cannot be empty")
        }
        
        guard !output.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError("Output directory cannot be empty")
        }
        
        // Expand tilde in output path
        let expandedOutput = NSString(string: output).expandingTildeInPath
        
        // Verify output directory exists or can be created
        let outputURL = URL(fileURLWithPath: expandedOutput)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
        
        // Create progress and log callbacks
        let progressCallback: (String) -> Void = { progress in
            print("📦 \(progress)")
        }
        
        let logCallback: (String) -> Void = { message in
            if self.verbose {
                print(message)
            }
        }
        
        // Create PhatPKGCore instance (disable console logging to prevent duplicates)
        let core = PhatPKGCore(progressCallback: progressCallback, logCallback: logCallback, disableConsoleLogging: true)
        
        do {
            // Process the universal package creation
            try await core.createUniversalPackage(
                armInput: arm64,
                intelInput: intel,
                outputDirectory: expandedOutput
            )
            
            print("\n✅ Successfully created universal package!")
            print("📁 Check your output directory: \(expandedOutput)")
            
        } catch let error as PhatPKGError {
            print("\n❌ Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("\n❌ Unexpected error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}
