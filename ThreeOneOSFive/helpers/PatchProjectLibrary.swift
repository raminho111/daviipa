import Foundation

struct PatchLibraryItem: Identifiable {
    let summary: PatchPackageSummary
    var project: PatchProject?
    var contentKey: Data?
    var packageURL: URL
    let isOfficialPreset: Bool

    var id: UUID { summary.packageID }
    var isLocked: Bool { project == nil }
    var workspaceURL: URL? {
        PatchWorkspaceService.workspaceURL(projectID: id)
    }
}

struct PatchPasswordRequest: Identifiable {
    let summary: PatchPackageSummary
    var id: UUID { summary.packageID }
}

enum PatchProjectLibrary {
    static func packageRootURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("PatchProjects", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try packageRootURL(fileManager: fileManager)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func load(fileManager: FileManager = .default) -> [PatchLibraryItem] {
        var byID: [UUID: PatchLibraryItem] = [:]

        for url in officialPresetPackageURLs() {
            do {
                let item = try makeItem(at: url, isOfficialPreset: true, fileManager: fileManager)
                byID[item.id] = item
                log("patch: loaded bundled official preset \(item.summary.packageID) from \(url.lastPathComponent)")
            } catch {
                log("patch: skipped invalid bundled preset \(url.lastPathComponent)")
            }
        }

        guard let root = try? packageRootURL(fileManager: fileManager),
              let urls = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
              ) else {
            return byID.values.sorted(by: librarySort)
        }

        for url in urls where url.pathExtension.lowercased() == "3105" {
            do {
                let item = try makeItem(at: url, isOfficialPreset: false, fileManager: fileManager)
                if let existing = byID[item.id] {
                    if existing.isOfficialPreset {
                        log("patch: skipped disk package \(url.lastPathComponent) — official preset \(item.id) always wins")
                    }
                    continue
                }
                byID[item.id] = item
            } catch {
                log("patch: skipped invalid local package \(url.lastPathComponent)")
            }
        }
        return byID.values.sorted(by: librarySort)
    }

    static func officialPresetPackageURLs() -> [URL] {
        Bundle.main.urls(forResourcesWithExtension: "3105", subdirectory: nil)?
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
    }

    private static func makeItem(
        at url: URL,
        isOfficialPreset: Bool,
        fileManager: FileManager
    ) throws -> PatchLibraryItem {
        let data = try readPackage(at: url)
        let summary = try PatchPackageCodec.inspect(data)
        let decoded: DecodedPatchPackage?
        if let contentKey = try PatchKeyStore.load(for: summary) {
            decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
        } else if summary.isPasswordProtected {
            decoded = nil
        } else {
            decoded = try PatchPackageCodec.decode(data, password: nil)
        }
        let item = PatchLibraryItem(
            summary: summary,
            project: decoded?.project,
            contentKey: decoded?.contentKey,
            packageURL: url,
            isOfficialPreset: isOfficialPreset
        )
        if summary.schemaVersion >= 2, let project = decoded?.project {
            do {
                _ = try PatchWorkspaceService.ensureWorkspace(for: project)
            } catch {
                log("patch: workspace unavailable for \(project.id.uuidString)")
            }
        }
        return item
    }

    private static func librarySort(_ a: PatchLibraryItem, _ b: PatchLibraryItem) -> Bool {
        if a.isOfficialPreset != b.isOfficialPreset {
            return a.isOfficialPreset
        }
        return (a.project?.updatedAt ?? .distantPast) > (b.project?.updatedAt ?? .distantPast)
    }

    static func readPackage(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isDirectory != true,
              values.isSymbolicLink != true,
              values.isRegularFile == true else {
            throw PatchPackageError.invalidProject
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    static func save(
        data: Data,
        projectName: String,
        existingURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let destination: URL
        if let existingURL {
            destination = existingURL
        } else {
            let root = try packageRootURL(fileManager: fileManager)
            let baseName = sanitizedFilename(projectName)
            var candidate = root.appendingPathComponent(baseName).appendingPathExtension("3105")
            var suffix = 2
            while fileManager.fileExists(atPath: candidate.path) {
                candidate = root.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("3105")
                suffix += 1
            }
            destination = candidate
        }
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    static func installImportedPackage(
        data: Data,
        decoded: DecodedPatchPackage,
        summary: PatchPackageSummary,
        existingURL: URL?,
        fileManager: FileManager = .default
    ) throws {
        let previousData = try existingURL.map { try readPackage(at: $0) }
        var savedURL: URL?
        do {
            savedURL = try save(
                data: data,
                projectName: decoded.project.name,
                existingURL: existingURL,
                fileManager: fileManager
            )
            if summary.schemaVersion >= 2 {
                _ = try PatchWorkspaceService.replaceWorkspace(
                    with: decoded.project,
                    fileManager: fileManager
                )
            } else {
                try? PatchWorkspaceService.deleteWorkspace(
                    projectID: decoded.project.id,
                    fileManager: fileManager
                )
            }
        } catch {
            if let previousData, let existingURL {
                try? previousData.write(
                    to: existingURL,
                    options: [.atomic, .completeFileProtection]
                )
            } else if let savedURL, fileManager.fileExists(atPath: savedURL.path) {
                try? fileManager.removeItem(at: savedURL)
            }
            throw error
        }
    }

    static func delete(_ item: PatchLibraryItem, fileManager: FileManager = .default) throws {
        guard !item.isOfficialPreset else { return }
        if fileManager.fileExists(atPath: item.packageURL.path) {
            try fileManager.removeItem(at: item.packageURL)
        }
        try? PatchWorkspaceService.deleteWorkspace(projectID: item.id, fileManager: fileManager)
        try? PatchKeyStore.delete(for: item.summary)
    }

    static func synchronizeWorkspace(
        item: PatchLibraryItem,
        fileManager: FileManager = .default
    ) throws -> PatchProject {
        guard item.summary.schemaVersion >= 2,
              let baseProject = item.project,
              let contentKey = item.contentKey else {
            throw PatchPackageError.invalidProject
        }
        let workspace = try PatchWorkspaceService.ensureWorkspace(
            for: baseProject,
            fileManager: fileManager
        )
        let project = try PatchWorkspaceService.snapshot(
            baseProject: baseProject,
            workspaceURL: workspace,
            fileManager: fileManager
        )
        let original = try readPackage(at: item.packageURL)
        let updated = try PatchPackageCodec.update(
            original,
            project: project,
            contentKey: contentKey,
            schemaVersion: PatchPackageCodec.latestSchemaVersion
        )
        _ = try save(
            data: updated,
            projectName: project.name,
            existingURL: item.packageURL,
            fileManager: fileManager
        )
        return project
    }

    private static func sanitizedFilename(_ rawName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = rawName.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let result = String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        return result.isEmpty ? "Patch" : String(result)
    }
}
