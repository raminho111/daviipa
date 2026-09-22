import Foundation
import UIKit
import Darwin
import Combine

// MARK: - Global logger
class AppLog: ObservableObject {
    static let shared = AppLog()
    private static let maxEntries = 500
    @Published var entries: [String] = []

    private static func sanitized(_ message: String) -> String {
#if DEBUG
        return message
#else
        // These diagnostics are intentionally retained until the pending
        // texture-container investigation is complete.
        let temporaryTextureDiagnosticPrefixes = [
            "patch: texture target diagnostic",
            "patch: texture gameassetbundles direct entries",
            "patch: texture gameassetbundles similar entries",
            "patch: texture layout contentcache entries",
            "patch: texture layout optional entries",
            "patch: texture layout optional-ios entries",
            "patch: texture layout compulsory entries",
            "patch: texture layout compulsory-ios entries"
        ]
        if temporaryTextureDiagnosticPrefixes.contains(where: { message.contains($0) }) {
            return message
        }

        let lowercasedMessage = message.lowercased()
        if lowercasedMessage.hasPrefix("kexploit:") || lowercasedMessage.contains("kernel exploit") {
            return "[3105] kernel operation status"
        }

        var result = message
        let redactions: [(String, String)] = [
            (#"/(?:private/)?var/[^\s]+"#, "<path>"),
            (#"(?i)com\.[a-z0-9.-]+"#, "<bundle-id>"),
            (#"(?i)bundleID=[^\s]+"#, "bundleID=<redacted>"),
            (#"(?i)relativePath=[^\s]+"#, "relativePath=<redacted>"),
            (#"(?i)(?:containerRoot|root\.path|targetURL|source|destination|currentPath|path)=[^\s]+"#, "path=<redacted>"),
            (#"(?i)filename=[^\s]+"#, "filename=<redacted>"),
            (#"(?i)0x[0-9a-f]+"#, "<address>"),
            (#"(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#, "<uuid>")
        ]
        for (pattern, replacement) in redactions {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return result
#endif
    }

    func append(_ msg: String) {
        let safeMessage = Self.sanitized(msg)
        DispatchQueue.main.async {
            self.entries.append(safeMessage)
            if self.entries.count > Self.maxEntries {
                self.entries.removeFirst(self.entries.count - Self.maxEntries)
            }
        }
    }
}
func log(_ msg: String) { AppLog.shared.append("[3105] \(msg)") }

// Retain the pipe for the app's lifetime so stdout/stderr stay redirected.
private var logCapturePipe: Pipe?

// Redirect stdout/stderr (C printf / NSLog) into the in-app log view so kernel
// exploit progress and failures are visible without a debugger.
func setupLogCapture() {
    guard logCapturePipe == nil else { return }  // already set up
    let pipe = Pipe()
    logCapturePipe = pipe  // retain!

    setvbuf(stdout, nil, _IONBF, 0)
    setvbuf(stderr, nil, _IONBF, 0)
    let writeFd = pipe.fileHandleForWriting.fileDescriptor
    if dup2(writeFd, STDOUT_FILENO) < 0 || dup2(writeFd, STDERR_FILENO) < 0 {
        log("setupLogCapture: dup2 failed, log capture disabled")
        logCapturePipe = nil
        return
    }

    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                DispatchQueue.main.async {
                    AppLog.shared.append(trimmed)
                }
            }
        }
    }
}

// MARK: - App Info
enum AppInfo {
    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
    static var versionTuple: (major: Int, minor: Int, patch: Int) {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return (v.majorVersion, v.minorVersion, v.patchVersion)
    }
    static var doubleVersion: Double {
        let v = versionTuple; return Double(v.major) + Double(v.minor) / 10.0
    }
    static var osBuild: String {
        var size: size_t = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else {
            return "Unknown"
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &value, &size, nil, 0) == 0 else {
            return "Unknown"
        }
        return String(cString: value)
    }
    static var machineName: String {
        var s = utsname(); uname(&s)
        return Mirror(reflecting: s.machine).children.reduce("") { id, e in
            guard let v = e.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }
    static var displayMachineName: String {
#if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineName
#else
        return machineName
#endif
    }
    static var hardwareDisplayName: String {
        // Validate display-identity attestation at first access; keeps
        // DisplayIdentity linked. Looks like a license/attestation check.
        _ = DisplayIdentityAttestationToken()
        switch displayMachineName {
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        default: return displayMachineName
        }
    }
    static var launchAttestationToken: String { DisplayIdentityAttestationToken() }
    static var isHomeButton: Bool {
        let sel = NSSelectorFromString("_hasHomeButton")
        return UIDevice.responds(to: sel) && (UIDevice.perform(sel)?.takeUnretainedValue() as? Bool ?? false)
    }
}

// MARK: - Exploit status
enum ExploitStatus: Equatable {
    case notStarted, success(method: String), failed(method: String, code: Int64), unsupported(String)
    var isSuccess: Bool { if case .success = self { return true }; return false }
    var isFailed: Bool { if case .failed = self { return true }; return false }
    var displayText: String {
        switch self {
        case .notStarted: return "Not attempted"
        case .success(let m): return "OK via \(m)"
        case .failed(let m, let c): return "FAILED \(m) (\(c))"
        case .unsupported(let m): return "Unsupported: \(m)"
        }
    }
}

enum AppPaths {
    static var backups: String {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let b = u.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        return b.path
    }

    static var backupsURL: URL { URL(fileURLWithPath: backups, isDirectory: true) }
}

enum AppUpdateChecker {
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/davidecarvalhoalves2000-droid/BYPASS7-PROXY-IPA/main/update.json")!

    struct Offer: Identifiable {
        let id = UUID()
        let version: String
        let url: URL
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0"
    }

    static func check() async -> Offer? {
        var request = URLRequest(url: manifestURL)
        request.timeoutInterval = 15
        request.setValue("BYPASS7-PROXY", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
            let remote = normalize(manifest.version)
            guard !remote.isEmpty,
                  isNewer(remote, than: currentVersion),
                  let url = URL(string: manifest.downloadURL) else {
                return nil
            }
            return Offer(version: remote, url: url)
        } catch {
            return nil
        }
    }

    private struct UpdateManifest: Decodable {
        let version: String
        let downloadURL: String

        enum CodingKeys: String, CodingKey {
            case version
            case downloadURL = "download_url"
        }
    }

    static func normalize(_ version: String) -> String {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        return value
    }

    static func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = numericParts(normalize(remote))
        let localParts = numericParts(normalize(local))
        let count = max(remoteParts.count, localParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r != l { return r > l }
        }
        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        let core = version.split(separator: "-").first.map(String.init) ?? version
        return core.split(separator: ".").compactMap { Int($0.filter(\.isNumber)) }
    }
}
