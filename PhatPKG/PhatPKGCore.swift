//
//  PhatPKGCore.swift
//  PhatPKG
//
//  Created by Gil Burns on 8/24/25.
//

import Foundation

/// Core functionality for creating universal macOS packages
/// This class contains all the business logic that can be shared between GUI and CLI versions
class PhatPKGCore {
    
    /// Progress callback for reporting status updates
    typealias ProgressCallback = (String) -> Void
    
    /// Log callback for reporting detailed messages
    typealias LogCallback = (String) -> Void
    
    private let progressCallback: ProgressCallback?
    private let logCallback: LogCallback?
    
    /// Initialize the core with optional callbacks for progress and logging
    /// - Parameters:
    ///   - progressCallback: Called when progress status changes (for UI updates)
    ///   - logCallback: Called for detailed logging messages
    ///   - disableConsoleLogging: When true, disables LogManager console output to prevent duplicates (useful for CLI)
    init(progressCallback: ProgressCallback? = nil, logCallback: LogCallback? = nil, disableConsoleLogging: Bool = false) {
        self.progressCallback = progressCallback
        self.logCallback = logCallback
        
        // Configure LogManager console output
        if disableConsoleLogging {
            LogManager.shared.shouldPrintToConsole = false
        }
    }
    
    /// Main entry point for creating a universal package
    /// - Parameters:
    ///   - armInput: Path or URL to ARM64 source (app, archive, or URL)
    ///   - intelInput: Path or URL to Intel x86 source (app, archive, or URL)
    ///   - outputDirectory: Directory where the final package will be saved
    /// - Throws: Various errors during processing
    func createUniversalPackage(armInput: String, intelInput: String, outputDirectory: String) async throws {
        
        // Input validation
        guard !armInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PhatPKGError.missingInput("ARM64 source is required")
        }
        
        guard !intelInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PhatPKGError.missingInput("Intel x86 source is required")
        }
        
        guard !outputDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PhatPKGError.missingInput("Output directory is required")
        }
        
        // File type validation for local files only
        let armIsURL = isURL(armInput)
        let intelIsURL = isURL(intelInput)
        
        if !armIsURL && !intelIsURL {
            let armFileType = (armInput as NSString).pathExtension
            let intelFileType = (intelInput as NSString).pathExtension
            
            if armFileType != intelFileType {
                throw PhatPKGError.fileTypeMismatch("File types must match for local files")
            }
        }
        
        // Create temporary directories
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let armTempDirectoryURL = tempDirectoryURL.appendingPathComponent("arm64")
        let intelTempDirectoryURL = tempDirectoryURL.appendingPathComponent("x86_64")
        
        defer {
            // Cleanup main temp directory and all subdirectories
            do {
                try FileManager.default.removeItem(at: tempDirectoryURL)
                LogManager.shared.debug("Cleaned up main temp directory: \(tempDirectoryURL.path)", source: "PhatPKGCore")
            } catch {
                LogManager.shared.warning("Failed to clean up main temp directory: \(error.localizedDescription)", source: "PhatPKGCore")
            }
        }
        
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: armTempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: intelTempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // Process ARM64 source
        progressCallback?("Processing ARM64 source...")
        LogManager.shared.info("Processing ARM64 source...", source: "PhatPKGCore")
        let armAppDetails = try await extractAppDetails(inputPath: armInput, outputDirectory: armTempDirectoryURL.path)
        
        // Process Intel x86 source
        progressCallback?("Processing Intel x86 source...")
        LogManager.shared.info("Processing Intel x86 source...", source: "PhatPKGCore")
        let intelAppDetails = try await extractAppDetails(inputPath: intelInput, outputDirectory: intelTempDirectoryURL.path)
        
        // Validate architectures
        guard armAppDetails.appArch == "arm64" else {
            throw PhatPKGError.architectureMismatch("ARM64 file does not contain arm64 architecture. Found: \(armAppDetails.appArch)")
        }
        
        guard intelAppDetails.appArch == "x86_64" else {
            throw PhatPKGError.architectureMismatch("Intel x86 file does not contain x86_64 architecture. Found: \(intelAppDetails.appArch)")
        }
        
        // Validate app compatibility
        guard armAppDetails.appVersion == intelAppDetails.appVersion else {
            throw PhatPKGError.versionMismatch("App versions do not match. ARM64: \(armAppDetails.appVersion), Intel: \(intelAppDetails.appVersion)")
        }
        
        guard armAppDetails.appID == intelAppDetails.appID else {
            throw PhatPKGError.bundleIdMismatch("App bundle IDs do not match. ARM64: \(armAppDetails.appID), Intel: \(intelAppDetails.appID)")
        }
        
        // Create universal package
        progressCallback?("Creating universal package...")
        LogManager.shared.info("Creating universal package...", source: "PhatPKGCore")
        let pkgCreator = PKGCreatorUniversal()
        
        if let result = pkgCreator.createUniversalPackage(
            inputPathArm64: armAppDetails.appPath,
            inputPathx86_64: intelAppDetails.appPath,
            outputDir: outputDirectory
        ) {
            LogManager.shared.info("Successfully created universal package:", source: "PhatPKGCore")
            LogManager.shared.info("Package: \(result.packagePath)", source: "PhatPKGCore")
            LogManager.shared.info("App: \(result.appName) v\(result.appVersion)", source: "PhatPKGCore")
            LogManager.shared.info("Bundle ID: \(result.appID)", source: "PhatPKGCore")
            progressCallback?("Package created successfully")
        } else {
            throw PhatPKGError.packageCreationFailed("Failed to create universal package")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func log(_ message: String) {
        LogManager.shared.info(message, source: "PhatPKGCore")
        logCallback?("[PhatPKGCore] \(message)")
    }
    
    private func isURL(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
    }
    
    /// Downloads a file from a URL to a temporary location
    /// - Parameter urlString: The URL string to download from
    /// - Returns: Path to the downloaded file
    /// - Throws: Download errors or invalid URL errors
    private func downloadFile(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw PhatPKGError.invalidURL("Invalid URL: \(urlString)")
        }
        
        let tempDir = NSTemporaryDirectory() + UUID().uuidString
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        // Determine file extension from URL
        let pathExtension = url.pathExtension.isEmpty ? "download" : url.pathExtension
        let fileName = url.lastPathComponent.isEmpty ? "download.\(pathExtension)" : url.lastPathComponent
        let localPath = tempDir + "/" + fileName
        
        LogManager.shared.info("Downloading from: \(urlString)", source: "PhatPKGCore")
        
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: localPath))
            LogManager.shared.info("Downloaded to: \(localPath)", source: "PhatPKGCore")
            return localPath
        } catch {
            throw PhatPKGError.downloadFailed("Failed to download from \(urlString): \(error.localizedDescription)")
        }
    }
    
    /// Extracts app details from input path (handles URLs, archives, and direct .app bundles)
    /// - Parameters:
    ///   - inputPath: Path or URL to the source
    ///   - outputDirectory: Directory to copy extracted app (optional)
    /// - Returns: Tuple with app details
    /// - Throws: Various extraction and validation errors
    private func extractAppDetails(inputPath: String, outputDirectory: String?) async throws -> (appPath: String, appName: String, appID: String, appVersion: String, appArch: String) {
        
        LogManager.shared.debug("Starting extractAppDetails for: \(inputPath)", source: "PhatPKGCore")
        
        // Check if input is a URL and download if needed
        let actualPath: String
        let downloadedFilePath: String?
        if isURL(inputPath) {
            actualPath = try await downloadFile(from: inputPath)
            downloadedFilePath = actualPath
        } else {
            actualPath = inputPath
            downloadedFilePath = nil
        }
        
        let tempDir = NSTemporaryDirectory() + UUID().uuidString
        
        defer {
            // Cleanup extraction temp directory
            do {
                try FileManager.default.removeItem(atPath: tempDir)
            } catch {
                LogManager.shared.warning("Failed to clean up extraction temp directory: \(error.localizedDescription)", source: "PhatPKGCore")
            }
            
            // Cleanup downloaded file and its parent directory if it was downloaded
            if let downloadPath = downloadedFilePath {
                let downloadDir = (downloadPath as NSString).deletingLastPathComponent
                do {
                    try FileManager.default.removeItem(atPath: downloadDir)
                    LogManager.shared.debug("Cleaned up downloaded file: \(downloadPath)", source: "PhatPKGCore")
                } catch {
                    LogManager.shared.warning("Failed to clean up downloaded file directory: \(error.localizedDescription)", source: "PhatPKGCore")
                }
            }
        }
        
        // Create temporary directory
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true, attributes: nil)

        let appPath: String

        let actualPathLower = actualPath.lowercased()
        if actualPathLower.hasSuffix(".zip") || actualPathLower.hasSuffix(".tbz") || actualPathLower.hasSuffix(".tar.bz2") || actualPathLower.hasSuffix(".bz2") || actualPathLower.hasSuffix(".dmg") {
            LogManager.shared.info("Extracting archive: \(actualPath)", source: "PhatPKGCore")
            appPath = try extractArchive(atPath: actualPath, to: tempDir)
        } else if actualPath.hasSuffix(".app") {
            LogManager.shared.info("Using .app directly: \(actualPath)", source: "PhatPKGCore")
            appPath = actualPath
        } else {
            throw PhatPKGError.extractionFailed("Unsupported input type: \(actualPath)")
        }

        LogManager.shared.debug("Extracted app path: \(appPath)", source: "PhatPKGCore")
        
        // Extract app information
        LogManager.shared.debug("Extracting app name...", source: "PhatPKGCore")
        let appName = (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        LogManager.shared.debug("Getting app version...", source: "PhatPKGCore")
        let appVersion = try getAppVersion(fromApp: appPath)
        
        LogManager.shared.debug("Reading Info.plist...", source: "PhatPKGCore")
        let infoPlistPath = appPath + "/Contents/Info.plist"
        let infoPlist = NSDictionary(contentsOfFile: infoPlistPath)
        guard let appID = infoPlist?["CFBundleIdentifier"] as? String else {
            throw PhatPKGError.appNotFound("Could not retrieve app bundle identifier")
        }

        LogManager.shared.debug("Getting app architecture...", source: "PhatPKGCore")
        let appArch: String = getAppArchitecture(appPath: appPath)
        
        guard appArch != "unknown" else {
            throw PhatPKGError.architectureMismatch("Could not determine app architecture")
        }

        let finalAppPath: String
        if let outputDir = outputDirectory {
            // Copy to the temp directory to prevent deletion
            let copyPath = outputDir + "/" + appName + ".app"
            try FileManager.default.copyItem(atPath: appPath, toPath: copyPath)
            finalAppPath = copyPath
        } else {
            finalAppPath = appPath
        }
        
        return (appPath: finalAppPath, appName: appName, appID: appID, appVersion: appVersion, appArch: appArch)
    }
    
    /// Extracts compressed archives (.zip, .tbz, .bz2, .dmg) and locates the contained .app bundle
    /// - Parameters:
    ///   - path: Path to the archive file
    ///   - destination: Directory to extract the archive contents
    /// - Returns: Path to the extracted .app bundle
    /// - Throws: Errors for unsupported archive types, extraction failures, or missing .app
    private func extractArchive(atPath path: String, to destination: String) throws -> String {
        let pathLower = path.lowercased()
        
        if pathLower.hasSuffix(".zip") {
            LogManager.shared.info("Extracting ZIP file...", source: "PhatPKGCore")
            try runShellCommand("/usr/bin/ditto", arguments: ["-x", "-k", path, destination])
        } else if pathLower.hasSuffix(".tbz") || pathLower.hasSuffix(".tar.bz2") {
            LogManager.shared.info("Extracting TAR.BZ2 file...", source: "PhatPKGCore")
            try runShellCommand("/usr/bin/tar", arguments: ["-xjf", path, "-C", destination])
        } else if pathLower.hasSuffix(".bz2") && !pathLower.hasSuffix(".tar.bz2") {
            LogManager.shared.info("Extracting BZ2 file...", source: "PhatPKGCore")
            let tempBz2Path = destination + "/" + (path as NSString).lastPathComponent
            try FileManager.default.copyItem(atPath: path, toPath: tempBz2Path)
            try runShellCommand("/usr/bin/bunzip2", arguments: [tempBz2Path])
        } else if pathLower.hasSuffix(".dmg") {
            LogManager.shared.info("Mounting and extracting DMG file...", source: "PhatPKGCore")
            return try extractFromDMG(atPath: path, to: destination)
        } else {
            let fileExtension = (path as NSString).pathExtension
            throw PhatPKGError.extractionFailed("Unsupported archive type: \(fileExtension)")
        }

        // Find the .app file inside the extracted folder
        let extractedContents = try FileManager.default.contentsOfDirectory(atPath: destination)
        if let appPath = extractedContents.first(where: { $0.hasSuffix(".app") }) {
            return destination + "/" + appPath
        } else {
            throw PhatPKGError.appNotFound(".app file not found in extracted contents")
        }
    }
    
    /// Extracts .app bundle from a DMG file by mounting and copying
    /// - Parameters:
    ///   - path: Path to the DMG file
    ///   - destination: Directory to copy the extracted .app bundle
    /// - Returns: Path to the extracted .app bundle
    /// - Throws: Errors for mounting failures or missing .app
    private func extractFromDMG(atPath path: String, to destination: String) throws -> String {
        // Mount the DMG
        let mountOutput = Process()
        mountOutput.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        mountOutput.arguments = ["attach", path, "-readonly", "-nobrowse", "-noautoopen"]
        
        let mountPipe = Pipe()
        mountOutput.standardOutput = mountPipe
        mountOutput.standardError = mountPipe
        
        try mountOutput.run()
        mountOutput.waitUntilExit()
        
        guard mountOutput.terminationStatus == 0 else {
            throw PhatPKGError.extractionFailed("Failed to mount DMG file")
        }
        
        let mountData = mountPipe.fileHandleForReading.readDataToEndOfFile()
        let mountResult = String(data: mountData, encoding: .utf8) ?? ""
        
        // Extract the mount path from hdiutil output (last column of last line)
        let mountLines = mountResult.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let lastLine = mountLines.last,
              let mountPath = lastLine.components(separatedBy: "\t").last?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw PhatPKGError.extractionFailed("Could not determine mount path")
        }
        
        defer {
            // Unmount the DMG
            let unmountProcess = Process()
            unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmountProcess.arguments = ["detach", mountPath, "-quiet"]
            try? unmountProcess.run()
            unmountProcess.waitUntilExit()
        }
        
        // Find the .app file in the mounted DMG
        let mountedContents = try FileManager.default.contentsOfDirectory(atPath: mountPath)
        guard let appName = mountedContents.first(where: { $0.hasSuffix(".app") }) else {
            throw PhatPKGError.appNotFound(".app file not found in DMG")
        }
        
        let sourcePath = mountPath + "/" + appName
        let destinationPath = destination + "/" + appName
        
        // Copy the .app from the mounted DMG to destination
        try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
        
        return destinationPath
    }
    
    /// Executes shell commands with error handling and logging
    /// - Parameters:
    ///   - command: Full path to the command executable
    ///   - arguments: Array of command arguments
    /// - Throws: NSError if command execution fails or returns non-zero exit status
    private func runShellCommand(_ command: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            LogManager.shared.debug("Command output: \(output)", source: "PhatPKGCore")
        } catch {
            LogManager.shared.error("Error running command: \(error)", source: "PhatPKGCore")
            throw PhatPKGError.extractionFailed("Shell command failed: \(error.localizedDescription)")
        }
        
        if process.terminationStatus != 0 {
            throw PhatPKGError.extractionFailed("Shell command failed with exit code \(process.terminationStatus)")
        }
    }
    
    /// Determines the architecture of a macOS application bundle
    /// - Parameter appPath: Path to the .app bundle
    /// - Returns: Architecture string ("universal", "arm64", "x86_64") or "unknown" if undetermined
    private func getAppArchitecture(appPath: String) -> String {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        let macOSPath = appPath + "/Contents/MacOS"
        
        // Load the Info.plist
        guard let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let plistDict = plist as? [String: Any],
              let executableName = plistDict["CFBundleExecutable"] as? String else {
            LogManager.shared.error("Unable to read Info.plist or CFBundleExecutable key.", source: "PhatPKGCore")
            return "unknown"
        }
        
        let fullExecutablePath = "\(macOSPath)/\(executableName)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = [fullExecutablePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
        } catch {
            LogManager.shared.error("Failed to run file command: \(error)", source: "PhatPKGCore")
            return "unknown"
        }
        
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return "unknown"
        }
        
        if output.contains("arm64") && output.contains("x86_64") {
            return "universal"
        } else if output.contains("arm64") {
            return "arm64"
        } else if output.contains("x86_64") {
            return "x86_64"
        } else {
            return "unknown"
        }
    }
    
    /// Extracts the version string from an application's Info.plist file
    /// - Parameter appPath: Path to the .app bundle
    /// - Returns: Version string from CFBundleShortVersionString
    /// - Throws: Error if Info.plist cannot be read or version key is missing
    private func getAppVersion(fromApp appPath: String) throws -> String {
        let infoPlistPath = appPath + "/Contents/Info.plist"
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
              let version = infoPlist["CFBundleShortVersionString"] as? String else {
            throw PhatPKGError.appNotFound("Failed to read CFBundleShortVersionString from Info.plist")
        }
        return version
    }
}

// MARK: - Error Types

enum PhatPKGError: LocalizedError {
    case missingInput(String)
    case fileTypeMismatch(String)
    case architectureMismatch(String)
    case versionMismatch(String)
    case bundleIdMismatch(String)
    case packageCreationFailed(String)
    case downloadFailed(String)
    case extractionFailed(String)
    case invalidURL(String)
    case appNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .missingInput(let message),
             .fileTypeMismatch(let message),
             .architectureMismatch(let message),
             .versionMismatch(let message),
             .bundleIdMismatch(let message),
             .packageCreationFailed(let message),
             .downloadFailed(let message),
             .extractionFailed(let message),
             .invalidURL(let message),
             .appNotFound(let message):
            return message
        }
    }
}
