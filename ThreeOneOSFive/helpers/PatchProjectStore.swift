import Foundation

struct PatchStoreAlert: Identifiable {
    let id = UUID()
    let titleKey: String
    let messageKey: String
    var messageArgument: String?

    init(titleKey: String, messageKey: String, messageArgument: String? = nil) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.messageArgument = messageArgument
    }

    func message(language: AppLanguage) -> String {
        if let messageArgument {
            return language.text(messageKey, messageArgument)
        }
        return language.text(messageKey)
    }
}

@MainActor
final class PatchProjectStore: ObservableObject {
    @Published private(set) var items: [PatchLibraryItem] = []
    @Published private(set) var isBusy = false
    @Published var passwordRequest: PatchPasswordRequest?
    @Published var alert: PatchStoreAlert?
    @Published var unlockErrorKey: String?

    private struct PendingUnlock {
        let data: Data
        let summary: PatchPackageSummary
        let existingURL: URL?
        let isOfficialPreset: Bool
    }

    private static let autoUnlockableOfficialPackageID = UUID(
        uuidString: "0856F902-5DD8-4721-A5E5-771F1D3EFA0B"
    )!
    private static let autoUnlockableOfficialPassword = "zn"
    private static let autoUnlockablePescocoPackageID = UUID(
        uuidString: "5E07EA32-72BC-441D-94FE-3050EB124150"
    )!
    private static let autoUnlockablePescocoPassword = "EHC XITS"
    private static let autoUnlockableSaciPackageID = UUID(
        uuidString: "A33C711D-7B57-47A4-859E-88284B342205"
    )!
    private static let autoUnlockableSaciPassword = "G7#vQ9!mZ2@rL8$xP4&kN6"
    private static let autoUnlockableNeckLegitPackageID = UUID(
        uuidString: "4FC10741-9FC5-43CD-B7D5-5516C3A6E3EF"
    )!
    private static let autoUnlockableNeckLegitPassword = "davi"
    private static let autoUnlockableNeckHighPackageID = UUID(
        uuidString: "F28F3ADA-BFFB-4174-B4FD-E9D4DE27CF1A"
    )!
    private static let autoUnlockableNeckHighPassword = "bypass7proxy"
    private static let autoUnlockableLegitMaxPackageID = UUID(
        uuidString: "D91EC200-F257-465B-8D11-B876BF9270D7"
    )!
    private static let autoUnlockableLegitMaxPassword = "PROXY"
    private static let autoUnlockableUmbigoPackageID = UUID(
        uuidString: "F9389CD1-23D1-4A01-B849-B3355F56682D"
    )!
    private static let autoUnlockableUmbigoPassword = "davi"
    private static let autoUnlockableHeadBodyPackageID = UUID(
        uuidString: "674439E6-B83F-4745-879E-5D74CC89F306"
    )!
    private static let autoUnlockableHeadBodyPassword = "FILES"
    private static let autoUnlockableAltoNesquikPackageID = UUID(uuidString: "01EEE4BC-5AA0-4F09-82DB-FC3DBE3F1FE3")!
    private static let autoUnlockableBarrigaNesquikPackageID = UUID(uuidString: "07938D44-3F82-485B-B2B3-0C045AD85264")!
    private static let autoUnlockablePescocoNesquikPackageID = UUID(uuidString: "E00C9B3E-D93F-4354-BBA3-3BFDF7C60E63")!
    private static let autoUnlockableNesquikPassword = "001"

    private static func autoUnlockablePassword(for item: PatchLibraryItem) -> String? {
        guard item.isOfficialPreset else { return nil }
        if item.summary.packageID == autoUnlockableOfficialPackageID {
            return autoUnlockableOfficialPassword
        }
        if item.summary.packageID == autoUnlockablePescocoPackageID {
            return autoUnlockablePescocoPassword
        }
        if item.summary.packageID == autoUnlockableSaciPackageID {
            return autoUnlockableSaciPassword
        }
        if item.summary.packageID == autoUnlockableNeckLegitPackageID {
            return autoUnlockableNeckLegitPassword
        }
        if item.summary.packageID == autoUnlockableNeckHighPackageID {
            return autoUnlockableNeckHighPassword
        }
        if item.summary.packageID == autoUnlockableLegitMaxPackageID {
            return autoUnlockableLegitMaxPassword
        }
        if item.summary.packageID == autoUnlockableUmbigoPackageID {
            return autoUnlockableUmbigoPassword
        }
        if item.summary.packageID == autoUnlockableHeadBodyPackageID {
            return autoUnlockableHeadBodyPassword
        }
        if item.summary.packageID == autoUnlockableAltoNesquikPackageID ||
           item.summary.packageID == autoUnlockableBarrigaNesquikPackageID ||
           item.summary.packageID == autoUnlockablePescocoNesquikPackageID {
            return autoUnlockableNesquikPassword
        }
        return nil
    }

    private static func autoUnlockable(item: PatchLibraryItem) -> Bool {
        autoUnlockablePassword(for: item) != nil
    }

    private var pendingUnlock: PendingUnlock?
    private var unlockCompletion: ((UUID, Bool) -> Void)?

    init() {
        reload()
    }

    func reload() {
        items = PatchProjectLibrary.load()
    }

    func create(project: PatchProject, password: String?) {
        runOperation(successMessageKey: "patch.created_message") {
            let encoded = try PatchPackageCodec.encodeNew(project: project, password: password)
            let summary = try PatchPackageCodec.inspect(encoded.data)
            let workspace = try PatchWorkspaceService.createWorkspace(for: project)
            do {
                if summary.isPasswordProtected {
                    try PatchKeyStore.store(encoded.contentKey, for: summary)
                }
                _ = try PatchProjectLibrary.save(data: encoded.data, projectName: project.name)
            } catch {
                try? FileManager.default.removeItem(at: workspace)
                try? PatchKeyStore.delete(for: summary)
                throw error
            }
        }
    }

    func update(project: PatchProject) {
        guard let item = items.first(where: { $0.id == project.id }),
              !item.isOfficialPreset,
              let contentKey = item.contentKey else {
            present(.invalidProject)
            return
        }
        runOperation(successMessageKey: "patch.updated_message") {
            let original = try PatchProjectLibrary.readPackage(at: item.packageURL)
            let updated = try PatchPackageCodec.update(
                original,
                project: project,
                contentKey: contentKey
            )
            _ = try PatchProjectLibrary.save(
                data: updated,
                projectName: project.name,
                existingURL: item.packageURL
            )
        }
    }

    func importPackage(at sourceURL: URL) {
        guard !isBusy else { return }
        isBusy = true
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try PatchProjectLibrary.readPackage(at: sourceURL)
                let summary = try PatchPackageCodec.inspect(data)
                let existingURL = await self?.existingPackageURL(for: summary.packageID)
                if let pending = try Self.persistImportedPackage(
                    data: data,
                    summary: summary,
                    existingURL: existingURL
                ) {
                    await self?.requestPassword(pending: pending)
                } else {
                    await self?.finishOperation(successMessageKey: "patch.imported_message")
                }
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.unsupportedFormat)
            }
        }
    }

    func importPackage(from source: PatchImportSource) {
        switch source {
        case .file(let url):
            importPackage(at: url)
        case .remote(let url):
            importPackage(fromRemoteURL: url)
        case .invalid:
            present(.invalidImportLink)
        }
    }

    private func importPackage(fromRemoteURL remoteURL: URL) {
        guard !isBusy,
              PatchImportRoute.validatedRemoteURL(remoteURL) != nil else {
            if !isBusy { present(.invalidImportLink) }
            return
        }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 60
                configuration.timeoutIntervalForResource = 600
                let session = URLSession(configuration: configuration)
                defer { session.invalidateAndCancel() }

                let (temporaryURL, response) = try await session.download(from: remoteURL)
                defer { try? FileManager.default.removeItem(at: temporaryURL) }
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      let finalURL = response.url,
                      PatchImportRoute.validatedRemoteURL(finalURL) != nil else {
                    throw PatchPackageError.remoteImportFailed
                }

                let data = try PatchProjectLibrary.readPackage(at: temporaryURL)
                let summary = try PatchPackageCodec.inspect(data)
                let existingURL = await self?.existingPackageURL(for: summary.packageID)
                if let pending = try Self.persistImportedPackage(
                    data: data,
                    summary: summary,
                    existingURL: existingURL
                ) {
                    await self?.requestPassword(pending: pending)
                } else {
                    await self?.finishOperation(successMessageKey: "patch.imported_message")
                }
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.remoteImportFailed)
            }
        }
    }

    func requestUnlock(for item: PatchLibraryItem, completion: ((UUID, Bool) -> Void)? = nil) {
        guard item.isLocked, !isBusy else { return }
        do {
            let data = try PatchProjectLibrary.readPackage(at: item.packageURL)
            log("patch: unlock requested for \(item.summary.packageID) — official=\(item.isOfficialPreset) url=\(item.packageURL.lastPathComponent)")
            unlockCompletion = completion
            pendingUnlock = PendingUnlock(
                data: data,
                summary: item.summary,
                existingURL: item.packageURL,
                isOfficialPreset: item.isOfficialPreset
            )
            if let password = Self.autoUnlockablePassword(for: item) {
                unlockOfficial(password: password)
                return
            }
            passwordRequest = PatchPasswordRequest(summary: item.summary)
        } catch let error as PatchPackageError {
            present(error)
        } catch {
            present(.unsupportedFormat)
        }
    }

    func unlock(password: String) {
        performUnlock(password: password)
    }

    private func unlockOfficial(password: String) {
        guard pendingUnlock?.isOfficialPreset == true, !isBusy else { return }
        performUnlock(password: password)
    }

    private func performUnlock(password: String) {
        guard let pending = pendingUnlock, !isBusy else { return }
        let requestedID = pending.summary.packageID
        let completion = unlockCompletion
        unlockCompletion = nil
        isBusy = true
        unlockErrorKey = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let decoded = try PatchPackageCodec.decode(pending.data, password: password)
                try PatchKeyStore.store(decoded.contentKey, for: pending.summary)
                if pending.isOfficialPreset {
                    // Bundled presets live inside the read-only app bundle: remember the
                    // content key, but never write the package or a workspace back to disk.
                } else {
                    do {
                        try PatchProjectLibrary.installImportedPackage(
                            data: pending.data,
                            decoded: decoded,
                            summary: pending.summary,
                            existingURL: pending.existingURL
                        )
                    } catch {
                        try? PatchKeyStore.delete(for: pending.summary)
                        throw error
                    }
                }
                await self?.clearPendingUnlock()
                await self?.finishOperation(successMessageKey: "patch.unlocked_message")
                await self?.emitUnlockCompletion(
                    packageID: requestedID,
                    success: true,
                    completion: completion
                )
            } catch let error as PatchPackageError {
                await self?.emitUnlockCompletion(
                    packageID: requestedID,
                    success: false,
                    completion: completion
                )
                await self?.failUnlock(error)
            } catch {
                await self?.emitUnlockCompletion(
                    packageID: requestedID,
                    success: false,
                    completion: completion
                )
                await self?.failUnlock(.invalidPasswordOrCorruptedPackage)
            }
        }
    }

    private func emitUnlockCompletion(
        packageID: UUID,
        success: Bool,
        completion: ((UUID, Bool) -> Void)?
    ) {
        completion?(packageID, success)
    }

    func cancelUnlock() {
        clearPendingUnlock()
        isBusy = false
    }

    func clearUnlockError() {
        unlockErrorKey = nil
    }

    func delete(_ item: PatchLibraryItem) {
        guard !item.isOfficialPreset else { return }
        do {
            try PatchProjectLibrary.delete(item)
            reload()
        } catch {
            present(.invalidProject)
        }
    }

    func synchronizeWorkspace(projectID: UUID, reportsSuccess: Bool = false) {
        guard let item = items.first(where: { $0.id == projectID }),
              item.summary.schemaVersion >= 2,
              !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                _ = try PatchProjectLibrary.synchronizeWorkspace(item: item)
                await self?.finishWorkspaceSynchronization(reportsSuccess: reportsSuccess)
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.invalidProject)
            }
        }
    }

    private func finishWorkspaceSynchronization(reportsSuccess: Bool) {
        reload()
        isBusy = false
        if reportsSuccess {
            alert = PatchStoreAlert(
                titleKey: "common.done",
                messageKey: "patch.workspace_synced_message"
            )
        }
    }

    private func runOperation(
        successMessageKey: String,
        operation: @escaping () throws -> Void
    ) {
        guard !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try operation()
                await self?.finishOperation(successMessageKey: successMessageKey)
            } catch let error as PatchPackageError {
                await self?.failOperation(error)
            } catch {
                await self?.failOperation(.invalidProject)
            }
        }
    }

    private func requestPassword(pending: PendingUnlock) {
        pendingUnlock = pending
        passwordRequest = PatchPasswordRequest(summary: pending.summary)
        isBusy = false
    }

    private func existingPackageURL(for packageID: UUID) -> URL? {
        items.first(where: { $0.id == packageID })?.packageURL
    }

    private nonisolated static func persistImportedPackage(
        data: Data,
        summary: PatchPackageSummary,
        existingURL: URL?
    ) throws -> PendingUnlock? {
        if let key = try PatchKeyStore.load(for: summary) {
            let decoded = try PatchPackageCodec.decode(data, contentKey: key)
            try PatchProjectLibrary.installImportedPackage(
                data: data,
                decoded: decoded,
                summary: summary,
                existingURL: existingURL
            )
            return nil
        }
        if summary.isPasswordProtected {
            return PendingUnlock(data: data, summary: summary, existingURL: existingURL, isOfficialPreset: false)
        }
        let decoded = try PatchPackageCodec.decode(data, password: nil)
        try PatchProjectLibrary.installImportedPackage(
            data: data,
            decoded: decoded,
            summary: summary,
            existingURL: existingURL
        )
        return nil
    }

    private func clearPendingUnlock() {
        pendingUnlock = nil
        passwordRequest = nil
        unlockErrorKey = nil
    }

    private func finishOperation(successMessageKey: String) {
        reload()
        isBusy = false
        alert = PatchStoreAlert(titleKey: "common.done", messageKey: successMessageKey)
    }

    private func failOperation(_ error: PatchPackageError) {
        isBusy = false
        present(error)
    }

    private func failUnlock(_ error: PatchPackageError) {
        isBusy = false
        // Keep the password sheet open so the user can retry.
        // Presenting an alert while dismissing the sheet swallows the message.
        if case .invalidPasswordOrCorruptedPackage = error {
            unlockErrorKey = "patch.error.wrong_password"
        } else {
            unlockErrorKey = error.localizationKey
        }
    }

    private func present(_ error: PatchPackageError) {
        alert = PatchStoreAlert(
            titleKey: "common.failed",
            messageKey: error.localizationKey,
            messageArgument: error.localizationArgument
        )
    }
}
