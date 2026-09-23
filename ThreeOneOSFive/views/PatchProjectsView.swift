import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum PatchPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
    static let copiesSelectedDocument = true
}

struct PatchProjectsView: View {
    @StateObject private var store = PatchProjectStore()

    var body: some View {
        InjectFeaturesView(store: store)
    }
}

private struct InjectFeaturesView: View {
    private enum GameEdition: Equatable {
        case max
        case normal

        var label: String {
            switch self {
            case .max: return "MAX"
            case .normal: return "NORMAL"
            }
        }
    }

    private enum Preset: CaseIterable, Identifiable {
        case headshot
        case saci
        case fps144
        case neckLegit
        case neckHigh
        case legitMax
        case umbigo
        case headBodyMax
        case altoNesquik
        case barrigaNesquik
        case pescocoNesquik

        var id: UUID {
            let packageID: String
            switch self {
            case .headshot: packageID = "5E07EA32-72BC-441D-94FE-3050EB124150"
            case .saci: packageID = "C11E1C4D-CAC4-4FC7-ACF2-4E6BECA09CEB"
            case .fps144: packageID = "0856F902-5DD8-4721-A5E5-771F1D3EFA0B"
            case .neckLegit: packageID = "4FC10741-9FC5-43CD-B7D5-5516C3A6E3EF"
            case .neckHigh: packageID = "F28F3ADA-BFFB-4174-B4FD-E9D4DE27CF1A"
            case .legitMax: packageID = "D91EC200-F257-465B-8D11-B876BF9270D7"
            case .umbigo: packageID = "F9389CD1-23D1-4A01-B849-B3355F56682D"
            case .headBodyMax: packageID = "674439E6-B83F-4745-879E-5D74CC89F306"
            case .altoNesquik: packageID = "DBC281FE-C31F-43C7-BA15-916F2C336514"
            case .barrigaNesquik: packageID = "07938D44-3F82-485B-B2B3-0C045AD85264"
            case .pescocoNesquik: packageID = "E00C9B3E-D93F-4354-BBA3-3BFDF7C60E63"
            }

            guard let id = UUID(uuidString: packageID) else {
                preconditionFailure("Invalid bundled preset package ID: \(packageID)")
            }

            return id
        }

        var title: String {
            switch self {
                // aba ff max
            case .headshot: return "HS PESCOÇO"
                // aba ff normal
            case .saci: return "HS SACI"
            case .fps144: return "HS PESCOÇO + ALTO"
                // aba ff max
            case .neckLegit: return "HS PESCOÇO LEGIT"
            case .neckHigh: return "HS PESCOÇO+ALTO"
            case .legitMax: return "HS LEGIT"
            case .umbigo: return "HS UMBIGO"
                // aba ff normal
            case .headBodyMax: return "HS PEITO"
            case .altoNesquik: return "HS CEARENSE"
                // aba ff max
            case .barrigaNesquik: return "HS BARRIGA"
            case .pescocoNesquik: return "HS PESCOÇO"
            }
        }


        var symbol: String {
            switch self {
            case .headshot:
                return "scope"
            case .saci:
                return "leaf"
            case .fps144:
                return "speedometer"
            case .neckLegit,
                 .neckHigh,
                 .legitMax,
                 .umbigo,
                 .headBodyMax,
                 .altoNesquik,
                 .barrigaNesquik,
                 .pescocoNesquik:
                return "scope"
            }
        }

        var edition: GameEdition {
            switch self {
            case .headshot:
                return .max
            case .saci, .fps144:
                return .normal
            case .neckLegit, .neckHigh, .legitMax, .umbigo:
                return .max
            case .headBodyMax:
                return .normal
            case .altoNesquik:
                return .normal
            case .barrigaNesquik, .pescocoNesquik:
                return .max
            }
        }
    }

    private enum TexturePreset: CaseIterable, Identifiable {
        case mandela
        case apelapato
        case ruok
        case cria

        private static let targetBundleID = "com.dts.freefireth"
        private static let targetRelativePath =
            "Documents/contentcache/Optional/ios/gameassetbundles/optionalab_avatar_66.DfUs7MzeaoXWJ4jW"
        private static let replacementFilename =
            "optionalab_avatar_66.DfUs7MzeaoXWJ4jW"

        var id: UUID {
            let identifier: String

            switch self {
            case .mandela:
                identifier = "F3620E53-5B72-4734-BFF8-15A76B761601"
            case .apelapato:
                identifier = "0CB74A2A-4B87-4787-861A-5B8ED1D35802"
            case .ruok:
                identifier = "E51D169E-0967-40D5-ACB0-BBFBDE88E803"
            case .cria:
                identifier = "A177DFD5-31A6-4B17-9D16-963A80D2A104"
            }

            guard let id = UUID(uuidString: identifier) else {
                preconditionFailure("Invalid bundled texture ID: \(identifier)")
            }

            return id
        }

        var title: String {
            switch self {
            case .mandela:
                return "MANDELA"
            case .apelapato:
                return "APELAPATO"
            case .ruok:
                return "RUOK"
            case .cria:
                return "CRIA"
            }
        }

        var edition: GameEdition {
            .normal
        }

        private var resourceName: String {
            switch self {
            case .mandela:
                return "mandela_avatar_66.DfUs7MzeaoXWJ4jW"
            case .apelapato:
                return "apelapato_avatar_66.DfUs7MzeaoXWJ4jW"
            case .ruok:
                return "rouk_avatar_66.DfUs7MzeaoXWJ4jW"
            case .cria:
                return "cria_avatar_66.DfUs7MzeaoXWJ4jW"
            }
        }

        func project() throws -> PatchProject {
            guard let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: nil
            ) else {
                throw TextureApplicationError.resourceUnavailable
            }

            let replacementData: Data

            do {
                replacementData = try Data(
                    contentsOf: url,
                    options: .mappedIfSafe
                )
            } catch {
                throw TextureApplicationError.resourceUnavailable
            }

            try verifyTargetExists()

            return PatchProject(
                id: id,
                name: title,
                bundleIdentifiers: [Self.targetBundleID],
                rules: [
                    PatchRule(
                        id: id,
                        bundleID: Self.targetBundleID,
                        relativePath: Self.targetRelativePath,
                        replacementFilename: Self.replacementFilename,
                        replacementData: replacementData
                    )
                ]
            )
        }

        private func verifyTargetExists() throws {
            guard let containerPath = ContainerStore.resolveAppContainerPath(
                bundleID: Self.targetBundleID
            ),
            ContainerStore.isApplicationContainerPath(containerPath)
            else {
                throw PatchPackageError.targetAppUnavailable(
                    Self.targetBundleID
                )
            }

            let containerRoot = PatchPathValidator.canonicalFileURL(
                URL(
                    fileURLWithPath: containerPath,
                    isDirectory: true
                )
            )

            let target = try PatchPathValidator.resolveTargetURL(
                bundleID: Self.targetBundleID,
                relativePath: Self.targetRelativePath,
                containerRoot: containerRoot
            )

            let fileManager = FileManager.default
            let targetExists = fileManager.fileExists(
                atPath: target.path
            )

            guard targetExists else {
                let documentsURL = containerRoot.appendingPathComponent(
                    "Documents",
                    isDirectory: true
                )

                let contentCacheURL = documentsURL.appendingPathComponent(
                    "contentcache",
                    isDirectory: true
                )

                let optionalURL = contentCacheURL.appendingPathComponent(
                    "Optional",
                    isDirectory: true
                )

                let iosURL = optionalURL.appendingPathComponent(
                    "ios",
                    isDirectory: true
                )

                let bundlesURL = iosURL.appendingPathComponent(
                    "gameassetbundles",
                    isDirectory: true
                )

                let compulsoryURL = contentCacheURL.appendingPathComponent(
                    "Compulsory",
                    isDirectory: true
                )

                let compulsoryIOSURL = compulsoryURL.appendingPathComponent(
                    "ios",
                    isDirectory: true
                )

                func directSimilarEntries(at url: URL) -> [String]? {
                    guard fileManager.fileExists(atPath: url.path) else {
                        return nil
                    }

                    let entries = try? fileManager.contentsOfDirectory(
                        atPath: url.path
                    )

                    return entries?.filter { entry in
                        let name = entry.lowercased()

                        return name.contains("avatar")
                            || name.contains("optional")
                            || name.contains("gameasset")
                            || name.contains("bundle")
                            || name.contains("cache")
                    }.sorted()
                }

                let directEntries =
                    (try? fileManager.contentsOfDirectory(
                        atPath: bundlesURL.path
                    ))?.sorted() ?? []

                let matchingEntries = directEntries.filter { entry in
                    let name = entry.lowercased()

                    return name.contains("optionalab")
                        || name.contains("avatar_66")
                }

                log(
                    "patch: texture target diagnostic " +
                    "containerRoot=\(containerRoot.path) " +
                    "targetURL=\(target.path) " +
                    "targetExists=\(targetExists) " +
                    "Documents=\(fileManager.fileExists(atPath: documentsURL.path)) " +
                    "contentcache=\(fileManager.fileExists(atPath: contentCacheURL.path)) " +
                    "Optional=\(fileManager.fileExists(atPath: optionalURL.path)) " +
                    "ios=\(fileManager.fileExists(atPath: iosURL.path)) " +
                    "gameassetbundles=\(fileManager.fileExists(atPath: bundlesURL.path))"
                )

                log(
                    "patch: texture gameassetbundles direct entries=\(directEntries)"
                )

                log(
                    "patch: texture gameassetbundles similar entries=\(matchingEntries)"
                )

                if let entries = directSimilarEntries(at: contentCacheURL) {
                    log(
                        "patch: texture layout contentcache entries=\(entries)"
                    )
                }

                if let entries = directSimilarEntries(at: optionalURL) {
                    log(
                        "patch: texture layout optional entries=\(entries)"
                    )
                }

                if let entries = directSimilarEntries(at: iosURL) {
                    log(
                        "patch: texture layout optional-ios entries=\(entries)"
                    )
                }

                if let entries = directSimilarEntries(at: compulsoryURL) {
                    log(
                        "patch: texture layout compulsory entries=\(entries)"
                    )
                }

                if let entries = directSimilarEntries(at: compulsoryIOSURL) {
                    log(
                        "patch: texture layout compulsory-ios entries=\(entries)"
                    )
                }

                let compulsoryBundlesURL =
                    compulsoryIOSURL.appendingPathComponent(
                        "gameassetbundles",
                        isDirectory: true
                    )

                if fileManager.fileExists(
                    atPath: compulsoryBundlesURL.path
                ) {
                    let entries =
                        (try? fileManager.contentsOfDirectory(
                            atPath: compulsoryBundlesURL.path
                        ))?.sorted() ?? []

                    let similarEntries = entries.filter { entry in
                        let name = entry.lowercased()

                        return name.contains("optionalab")
                            || name.contains("avatar_66")
                            || name.contains("avatar")
                            || name.contains("gameasset")
                    }

                    log(
                        "patch: texture compulsory-gameassetbundles direct entries=\(entries)"
                    )

                    log(
                        "patch: texture compulsory-gameassetbundles similar entries=\(similarEntries)"
                    )

                    let avatarURL =
                        compulsoryBundlesURL.appendingPathComponent(
                            "avatar",
                            isDirectory: true
                        )

                    let avatarExists = fileManager.fileExists(
                        atPath: avatarURL.path
                    )

                    log(
                        "patch: texture compulsory-gameassetbundles avatar exists=\(avatarExists)"
                    )

                    if avatarExists {
                        let avatarEntries =
                            (try? fileManager.contentsOfDirectory(
                                atPath: avatarURL.path
                            ))?.sorted() ?? []

                        let avatarSimilarEntries = avatarEntries.filter {
                            entry in

                            let name = entry.lowercased()

                            return name.contains("optionalab")
                                || name.contains("avatar_66")
                                || name.contains("avatar")
                                || name.contains("dfus7mzeaoxwj4jw")
                        }

                        log(
                            "patch: texture compulsory-gameassetbundles avatar direct entries=\(avatarEntries)"
                        )

                        log(
                            "patch: texture compulsory-gameassetbundles avatar similar entries=\(avatarSimilarEntries)"
                        )
                    }
                }

                throw TextureApplicationError.targetMissing
            }

            let values: URLResourceValues

            do {
                values = try target.resourceValues(
                    forKeys: [
                        .isDirectoryKey,
                        .isSymbolicLinkKey
                    ]
                )
            } catch {
                throw TextureApplicationError.targetUnavailable
            }

            guard values.isDirectory != true,
                  values.isSymbolicLink != true
            else {
                throw TextureApplicationError.targetUnavailable
            }
        }
    }

    private enum TextureApplicationError: Error {
        case resourceUnavailable
        case targetMissing
        case targetUnavailable

        var messageKey: String {
            switch self {
            case .resourceUnavailable:
                return "texture.error.resource_unavailable"
            case .targetMissing:
                return "texture.error.target_missing"
            case .targetUnavailable:
                return "texture.error.target_unavailable"
            }
        }
    }

    private enum FeatureState: Equatable {
        case unknown
        case inactive
        case active(PatchTransactionReceipt)
        case working(isOn: Bool)

        var isOn: Bool {
            if case .active = self {
                return true
            }

            if case .working(let isOn) = self {
                return isOn
            }

            return false
        }

        var isWorking: Bool {
            if case .working = self {
                return true
            }

            return false
        }
    }

    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore

    @State private var states: [UUID: FeatureState] = [:]
    @State private var actionAlert: PatchStoreAlert?
    @State private var isPatchOperationInFlight = false
    @State private var pendingAutoApplyFor: UUID?
    @State private var selectedEdition: GameEdition = .normal

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: AppTheme.sectionSpacing
                ) {
                    header
                    editionPicker

                    featureSection("FUNÇÕES DE AIMBOT") {
                        ForEach(
                            Preset.allCases.filter {
                                $0.edition == selectedEdition
                            }
                        ) { preset in
                            presetRow(preset)
                        }
                    }

                    featureSection("FUNÇÕES HOLOGRAMA") {
                        unavailableRow(
                            title: "HOLOGRAMA ARMAS",
                            symbol: "cube.transparent"
                        )
                    }

                    if selectedEdition == .normal {
                        featureSection("TEXTURAS") {
                            ForEach(TexturePreset.allCases) { texture in
                                textureRow(texture)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.vertical, 16)
            }
            .background(Color.black.ignoresSafeArea())
            .animation(
                .easeInOut(duration: AppTheme.motionDuration),
                value: selectedEdition
            )
            .navigationTitle("INJETAR")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(
                item: $store.passwordRequest,
                onDismiss: store.cancelUnlock
            ) { _ in
                PatchUnlockView(store: store)
            }
            .alert(item: $store.alert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(
                        Text(language.text("common.ok"))
                    )
                )
            }
            .alert(item: $actionAlert) { alert in
                Alert(
                    title: Text(language.text(alert.titleKey)),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(
                        Text(language.text("common.ok"))
                    )
                )
            }
            .onAppear {
                resetToUnknown()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("RECURSOS")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.accent)

            Text("Controle seus recursos")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var editionPicker: some View {
        Picker(
            "Edição do jogo",
            selection: $selectedEdition
        ) {
            Text("FREE FIRE NORMAL")
                .tag(GameEdition.normal)

            Text("FREE FIRE MAX")
                .tag(GameEdition.max)
        }
        .pickerStyle(.segmented)
        .tint(AppTheme.accent)
    }

    private func featureSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                content()
            }
            .background(
                Color.white.opacity(0.07),
                in: RoundedRectangle(
                    cornerRadius: AppTheme.cardCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: AppTheme.cardCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    AppTheme.surfaceBorder,
                    lineWidth: 1
                )
            }
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        let state = states[preset.id] ?? .unknown

        return HStack(spacing: 12) {
            AppRowIcon(
                systemName: preset.symbol,
                tint: AppTheme.accent,
                frameSize: 34
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                titleWithEdition(
                    preset.title,
                    edition: preset.edition
                )

                statusText(for: state)
            }

            Spacer(minLength: 12)

            if state.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.accent)
            }

            Toggle(
                "",
                isOn: toggleBinding(for: preset)
            )
            .labelsHidden()
            .disabled(
                preset.edition == .max ||
                state.isWorking ||
                isPatchOperationInFlight ||
                store.isBusy
            )
            .accessibilityLabel(preset.title)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func textureRow(_ texture: TexturePreset) -> some View {
        let state = states[texture.id] ?? .unknown

        return HStack(spacing: 12) {
            AppRowIcon(
                systemName: "person.crop.square",
                tint: AppTheme.accent,
                frameSize: 34
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                titleWithEdition(
                    texture.title,
                    edition: texture.edition
                )

                statusText(for: state)
            }

            Spacer(minLength: 12)

            if state.isWorking {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.accent)
            }

            Toggle(
                "",
                isOn: textureToggleBinding(for: texture)
            )
            .labelsHidden()
            .disabled(
                state.isWorking ||
                isPatchOperationInFlight ||
                store.isBusy
            )
            .accessibilityLabel(texture.title)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func titleWithEdition(
        _ title: String,
        edition: GameEdition
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(edition.label)
                .font(
                    .system(
                        size: 9,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .tracking(0.35)
                .foregroundStyle(
                    edition == .max
                        ? AppTheme.accent
                        : Color.secondary
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    edition == .max
                        ? AppTheme.accent.opacity(0.16)
                        : Color.white.opacity(0.08),
                    in: RoundedRectangle(
                        cornerRadius: 5,
                        style: .continuous
                    )
                )
                .fixedSize()
        }
    }

    private func statusText(
        for state: FeatureState
    ) -> some View {
        Group {
            switch state {
            case .unknown:
                Label(
                    "Estado não verificado",
                    systemImage: "questionmark.circle"
                )

            case .inactive:
                Text("Desativado")

            case .active:
                Text("Ativado nesta sessão")

            case .working(let isOn):
                Text(
                    isOn
                        ? "Aplicando…"
                        : "Restaurando…"
                )
            }
        }
        .font(
            (state.isWorking || state.isOn)
                ? .caption.weight(.medium)
                : .caption
        )
        .foregroundStyle(
            (state.isWorking || state.isOn)
                ? AppTheme.accent
                : .secondary
        )
    }

    private func unavailableRow(
        title: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 12) {
            AppRowIcon(
                systemName: symbol,
                tint: .secondary,
                frameSize: 34
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text("Em configuração")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Toggle(
                "",
                isOn: .constant(false)
            )
            .labelsHidden()
            .disabled(true)
            .accessibilityLabel(
                "\(title), Em configuração"
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .opacity(0.78)
    }

    private func toggleBinding(
        for preset: Preset
    ) -> Binding<Bool> {
        Binding(
            get: {
                (states[preset.id] ?? .unknown).isOn
            },
            set: { requestedOn in
                performToggle(
                    for: preset,
                    requestedOn: requestedOn
                )
            }
        )
    }

    private func performToggle(
        for preset: Preset,
        requestedOn: Bool
    ) {
        // Bloqueia completamente os presets do FREE FIRE MAX.
        guard preset.edition != .max else {
            return
        }

        let current =
            states[preset.id] ?? .unknown

        guard !current.isWorking,
              !isPatchOperationInFlight,
              !store.isBusy
        else {
            return
        }

        if requestedOn {
            apply(preset)
        } else if case .active(let receipt) = current {
            restore(
                preset,
                receipt: receipt
            )
        }
    }

    private func textureToggleBinding(
        for texture: TexturePreset
    ) -> Binding<Bool> {
        Binding(
            get: {
                (states[texture.id] ?? .unknown).isOn
            },
            set: { requestedOn in
                performTextureToggle(
                    for: texture,
                    requestedOn: requestedOn
                )
            }
        )
    }

    private func performTextureToggle(
        for texture: TexturePreset,
        requestedOn: Bool
    ) {
        let current =
            states[texture.id] ?? .unknown

        guard !current.isWorking,
              !isPatchOperationInFlight,
              !store.isBusy
        else {
            return
        }

        if requestedOn {
            if let active = activeTexture(
                excluding: texture
            ) {
                replaceTexture(
                    active.texture,
                    receipt: active.receipt,
                    with: texture
                )
            } else {
                apply(texture)
            }
        } else if case .active(let receipt) = current {
            restore(
                texture,
                receipt: receipt
            )
        }
    }

    private func activeTexture(
        excluding requested: TexturePreset
    ) -> (
        texture: TexturePreset,
        receipt: PatchTransactionReceipt
    )? {
        for texture in TexturePreset.allCases
        where texture != requested {
            if case .active(let receipt) =
                states[texture.id] ?? .unknown {
                return (
                    texture,
                    receipt
                )
            }
        }

        return nil
    }

    private func apply(_ preset: Preset) {
        guard let item = store.items.first(
            where: { $0.id == preset.id }
        ) else {
            actionAlert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: "patch.error.invalid_project"
            )
            return
        }

        guard !item.isLocked,
              let project = item.project
        else {
            if item.isOfficialPreset {
                pendingAutoApplyFor = preset.id

                store.requestUnlock(
                    for: item
                ) { [self] packageID, success in
                    guard packageID == pendingAutoApplyFor,
                          let preset = Preset.allCases.first(
                            where: { $0.id == packageID }
                          )
                    else {
                        pendingAutoApplyFor = nil
                        return
                    }

                    pendingAutoApplyFor = nil

                    if success,
                       let unlocked = store.items.first(
                        where: { $0.id == preset.id }
                       ),
                       !unlocked.isLocked {
                        apply(preset)
                    }
                }
            } else {
                store.requestUnlock(for: item)
            }

            return
        }

        states[preset.id] = .working(
            isOn: true
        )

        isPatchOperationInFlight = true

        Task.detached(
            priority: .userInitiated
        ) {
            do {
                let receipt =
                    try DevicePatchService.apply(
                        project: project
                    )

                await MainActor.run {
                    states[preset.id] =
                        .active(receipt)

                    isPatchOperationInFlight =
                        false
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    states[preset.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey: error.localizationKey,
                            messageArgument:
                                error.localizationArgument
                        )
                }
            } catch {
                await MainActor.run {
                    states[preset.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                "patch.error.apply"
                        )
                }
            }
        }
    }

    private func apply(
        _ texture: TexturePreset
    ) {
        states[texture.id] =
            .working(isOn: true)

        isPatchOperationInFlight = true

        Task.detached(
            priority: .userInitiated
        ) {
            do {
                let receipt =
                    try DevicePatchService.apply(
                        project: texture.project()
                    )

                await MainActor.run {
                    states[texture.id] =
                        .active(receipt)

                    isPatchOperationInFlight =
                        false
                }
            } catch let error as TextureApplicationError {
                await MainActor.run {
                    states[texture.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                error.messageKey
                        )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    states[texture.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                error.localizationKey,
                            messageArgument:
                                error.localizationArgument
                        )
                }
            } catch {
                await MainActor.run {
                    states[texture.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                "patch.error.apply"
                        )
                }
            }
        }
    }

    private func replaceTexture(
        _ previous: TexturePreset,
        receipt: PatchTransactionReceipt,
        with next: TexturePreset
    ) {
        states[previous.id] =
            .working(isOn: false)

        states[next.id] =
            .working(isOn: true)

        isPatchOperationInFlight = true

        Task.detached(
            priority: .userInitiated
        ) {
            var restoredPrevious = false

            do {
                try DevicePatchService.restore(
                    receipt: receipt
                )

                restoredPrevious = true

                let nextReceipt =
                    try DevicePatchService.apply(
                        project: next.project()
                    )

                await MainActor.run {
                    states[previous.id] =
                        .unknown

                    states[next.id] =
                        .active(nextReceipt)

                    isPatchOperationInFlight =
                        false
                }
            } catch let error as TextureApplicationError {
                await MainActor.run {
                    states[previous.id] =
                        restoredPrevious
                            ? .unknown
                            : .active(receipt)

                    states[next.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                error.messageKey
                        )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    states[previous.id] =
                        restoredPrevious
                            ? .unknown
                            : .active(receipt)

                    states[next.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                error.localizationKey,
                            messageArgument:
                                error.localizationArgument
                        )
                }
            } catch {
                await MainActor.run {
                    states[previous.id] =
                        restoredPrevious
                            ? .unknown
                            : .active(receipt)

                    states[next.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                "patch.error.apply"
                        )
                }
            }
        }
    }

    private func restore(
        _ preset: Preset,
        receipt: PatchTransactionReceipt
    ) {
        states[preset.id] =
            .working(isOn: false)

        isPatchOperationInFlight = true

        Task.detached(
            priority: .userInitiated
        ) {
            do {
                try DevicePatchService.restore(
                    receipt: receipt
                )

                await MainActor.run {
                    states[preset.id] =
                        .inactive

                    isPatchOperationInFlight =
                        false
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    states[preset.id] =
                        .active(receipt)

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                error.localizationKey,
                            messageArgument:
                                error.localizationArgument
                        )
                }
            } catch {
                await MainActor.run {
                    states[preset.id] =
                        .active(receipt)

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                "patch.error.restore"
                        )
                }
            }
        }
    }

    private func restore(
        _ texture: TexturePreset,
        receipt: PatchTransactionReceipt
    ) {
        states[texture.id] =
            .working(isOn: false)

        isPatchOperationInFlight = true

        Task.detached(
            priority: .userInitiated
        ) {
            do {
                try DevicePatchService.restore(
                    receipt: receipt
                )

                await MainActor.run {
                    states[texture.id] =
                        .unknown

                    isPatchOperationInFlight =
                        false
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    states[texture.id] =
                        .active(receipt)

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                error.localizationKey,
                            messageArgument:
                                error.localizationArgument
                        )
                }
            } catch {
                await MainActor.run {
                    states[texture.id] =
                        .active(receipt)

                    isPatchOperationInFlight =
                        false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey: "common.failed",
                            messageKey:
                                "patch.error.restore"
                        )
                }
            }
        }
    }

    private func resetToUnknown() {
        for preset in Preset.allCases
        where states[preset.id] == nil {
            states[preset.id] =
                .unknown
        }

        for texture in TexturePreset.allCases
        where states[texture.id] == nil {
            states[texture.id] =
                .unknown
        }
    }
}

private struct PatchProjectRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            AppRowIcon(
                systemName:
                    item.isLocked
                        ? "lock.doc.fill"
                        : "shippingbox.fill"
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(
                    item.project?.name
                        ?? language.text(
                            "patch.locked_project"
                        )
                )
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

                Text(
                    item.isLocked
                        ? language.text(
                            "patch.tap_to_unlock"
                        )
                        : language.text(
                            item.summary.schemaVersion >= 2
                                ? "patch.workspace_items_count"
                                : "patch.rules_count",
                            Int64(
                                (item.project?.rules.count ?? 0)
                                +
                                (item.project?.directories.count ?? 0)
                            )
                        )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if item.summary.isPasswordProtected {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        language.text(
                            "patch.password_protected"
                        )
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(
                        language.text("patch.password"),
                        text: $password
                    )
                    .textContentType(.password)
                    .submitLabel(.done)
                    .onSubmit(unlock)
                    .onChange(of: password) { _ in
                        store.clearUnlockError()
                    }

                    if let errorKey =
                        store.unlockErrorKey {
                        Text(
                            language.text(errorKey)
                        )
                        .font(.footnote)
                        .foregroundStyle(.red)
                    }
                } footer: {
                    Text(
                        language.text(
                            "patch.password_once_message"
                        )
                    )
                }
            }
            .navigationTitle(
                language.text("patch.unlock")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button(
                        language.text("common.cancel")
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button(
                        language.text("patch.unlock"),
                        action: unlock
                    )
                    .disabled(
                        password.isEmpty ||
                        store.isBusy
                    )
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else {
            return
        }

        store.unlock(password: password)
    }
}

private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID

    @State private var showEditor = false
    @State private var editingRule: PatchRule?
    @State private var showApplyConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var isWorking = false
    @State private var actionAlert: PatchStoreAlert?
    @State private var shareRequest: PatchShareRequest?

    private var item: PatchLibraryItem? {
        store.items.first(
            where: { $0.id == projectID }
        )
    }

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(
            projectID: projectID
        )
    }

    private var isWorkspaceProject: Bool {
        (item?.summary.schemaVersion ?? 1) >= 2
    }

    private var isOfficialProject: Bool {
        item?.isOfficialPreset ?? false
    }

    var body: some View {
        List {
            if let item,
               let project = item.project {

                if isWorkspaceProject {
                    Section {
                        ForEach(
                            project.allBundleIdentifiers,
                            id: \.self
                        ) { bundleID in
                            Label {
                                Text(bundleID)
                                    .font(
                                        .subheadline.monospaced()
                                    )
                            } icon: {
                                Image(
                                    systemName: "app.dashed"
                                )
                                .foregroundStyle(
                                    AppTheme.accent
                                )
                            }
                        }

                        LabeledContent(
                            language.text("patch.files")
                        ) {
                            Text(
                                "\(project.rules.count)"
                            )
                        }

                        LabeledContent(
                            language.text("patch.folders")
                        ) {
                            Text(
                                "\(project.directories.count)"
                            )
                        }

                        if let workspaceURL =
                            item.workspaceURL {
                            NavigationLink {
                                FileBrowserView(
                                    containerPath:
                                        workspaceURL.path,
                                    title:
                                        project.name,
                                    bundleID: nil
                                )
                            } label: {
                                Label(
                                    language.text(
                                        "patch.open_workspace"
                                    ),
                                    systemImage:
                                        "folder"
                                )
                            }
                        }
                    } header: {
                        Text(
                            language.text(
                                "patch.workspace"
                            )
                        )
                    } footer: {
                        Text(
                            language.text(
                                "patch.workspace_detail_footer"
                            )
                        )
                    }
                } else {
                    Section {
                        ForEach(
                            project.rules
                        ) { rule in
                            ruleRow(rule)
                        }
                    } header: {
                        Text(
                            language.text(
                                "patch.rules"
                            )
                        )
                    } footer: {
                        Text(
                            language.text(
                                "patch.legacy_footer"
                            )
                        )
                    }
                }

                Section(
                    language.text("patch.password")
                ) {
                    HStack(spacing: 12) {
                        Image(
                            systemName:
                                item.summary.isPasswordProtected
                                    ? "lock.fill"
                                    : "lock.open"
                        )
                        .foregroundStyle(
                            AppTheme.accent
                        )
                        .frame(width: 24)

                        Text(
                            language.text(
                                item.summary.isPasswordProtected
                                    ? "patch.password_locked"
                                    : "patch.no_password"
                            )
                        )
                        .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        showApplyConfirmation = true
                    } label: {
                        actionLabel(
                            "patch.apply",
                            systemImage:
                                "checkmark.shield.fill"
                        )
                    }
                    .disabled(isWorking)

                    if receipt != nil {
                        Button(role: .destructive) {
                            showRestoreConfirmation = true
                        } label: {
                            actionLabel(
                                "patch.restore",
                                systemImage:
                                    "arrow.uturn.backward.circle"
                            )
                        }
                        .disabled(isWorking)
                    }

                    if !isOfficialProject {
                        Button(
                            action: prepareExport
                        ) {
                            actionLabel(
                                "patch.export",
                                systemImage:
                                    "square.and.arrow.up"
                            )
                        }
                        .disabled(isWorking)
                    }
                } footer: {
                    Text(
                        language.text(
                            "patch.apply_footer"
                        )
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(
            item?.project?.name
                ?? language.text("patch.title")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement: .navigationBarTrailing
            ) {
                if isWorking {
                    ProgressView()
                } else if !isWorkspaceProject &&
                            !isOfficialProject {
                    Button(
                        language.text("patch.edit")
                    ) {
                        showEditor = true
                    }
                    .disabled(
                        item?.project == nil
                    )
                }
            }
        }
        .sheet(
            isPresented: $showEditor
        ) {
            if let item,
               let project = item.project {
                PatchProjectEditorView(
                    existingProject: project,
                    passwordIsProtected:
                        item.summary.isPasswordProtected
                ) { updatedProject, _ in
                    store.update(
                        project: updatedProject
                    )
                }
            }
        }
        .sheet(
            item: $editingRule
        ) { rule in
            PatchRuleEditorView(
                rule: rule
            ) { updatedRule in
                updateRule(updatedRule)
            }
        }
        .confirmationDialog(
            language.text(
                "patch.apply_confirm_title"
            ),
            isPresented:
                $showApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                language.text("patch.apply")
            ) {
                apply()
            }

            Button(
                language.text("common.cancel"),
                role: .cancel
            ) {}
        } message: {
            Text(
                language.text(
                    "patch.apply_confirm_message"
                )
            )
        }
        .confirmationDialog(
            language.text(
                "patch.restore_confirm_title"
            ),
            isPresented:
                $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                language.text("patch.restore"),
                role: .destructive
            ) {
                restore()
            }

            Button(
                language.text("common.cancel"),
                role: .cancel
            ) {}
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(
                    language.text(alert.titleKey)
                ),
                message: Text(
                    alert.message(
                        language: language
                    )
                ),
                dismissButton: .default(
                    Text(
                        language.text("common.ok")
                    )
                )
            )
        }
        .sheet(
            item: $shareRequest
        ) { request in
            PatchActivityView(
                items: [request.url]
            )
            .ignoresSafeArea()
        }
    }

    private func actionLabel(
        _ key: String,
        systemImage: String
    ) -> some View {
        Label(
            language.text(key),
            systemImage: systemImage
        )
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    @ViewBuilder
    private func ruleRow(
        _ rule: PatchRule
    ) -> some View {
        if isOfficialProject {
            HStack(spacing: 10) {
                ruleSummary(rule)
            }
            .contentShape(Rectangle())
        } else {
            Button {
                editingRule = rule
            } label: {
                HStack(spacing: 10) {
                    ruleSummary(rule)

                    Spacer(minLength: 8)

                    Image(
                        systemName: "chevron.right"
                    )
                    .font(
                        .caption.weight(.semibold)
                    )
                    .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                language.text(
                    "patch.edit_rule_hint"
                )
            )
        }
    }

    private func ruleSummary(
        _ rule: PatchRule
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(rule.bundleID)
                .font(
                    .subheadline.weight(.semibold)
                )
                .foregroundStyle(.primary)

            Text(rule.relativePath)
                .font(
                    .caption.monospaced()
                )
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Label(
                rule.replacementFilename,
                systemImage:
                    "arrow.triangle.2.circlepath"
            )
            .font(.caption)
            .foregroundStyle(
                AppTheme.accent
            )
        }
        .padding(.vertical, 3)
    }

    private func updateRule(
        _ updatedRule: PatchRule
    ) {
        guard var project = item?.project,
              let index =
                project.rules.firstIndex(
                    where: {
                        $0.id == updatedRule.id
                    }
                )
        else {
            return
        }

        project.rules[index] =
            updatedRule

        project.updatedAt =
            Date()

        do {
            try PatchPackageCodec.validate(
                project
            )

            store.update(
                project: project
            )
        } catch let error as PatchPackageError {
            actionAlert =
                PatchStoreAlert(
                    titleKey:
                        "common.failed",
                    messageKey:
                        error.localizationKey,
                    messageArgument:
                        error.localizationArgument
                )
        } catch {
            actionAlert =
                PatchStoreAlert(
                    titleKey:
                        "common.failed",
                    messageKey:
                        "patch.error.invalid_project"
                )
        }
    }

    private func apply() {
        guard let item,
              let baseProject = item.project
        else {
            return
        }

        isWorking = true

        Task.detached(
            priority: .userInitiated
        ) {
            do {
                let project =
                    item.summary.schemaVersion >= 2
                        ? try PatchProjectLibrary
                            .synchronizeWorkspace(
                                item: item
                            )
                        : baseProject

                _ = try DevicePatchService.apply(
                    project: project
                )

                await MainActor.run {
                    store.reload()
                    isWorking = false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey:
                                "common.done",
                            messageKey:
                                "patch.applied_message"
                        )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey:
                                "common.failed",
                            messageKey:
                                error.localizationKey,
                            messageArgument:
                                error.localizationArgument
                        )
                }
            } catch {
                await MainActor.run {
                    isWorking = false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey:
                                "common.failed",
                            messageKey:
                                "patch.error.apply"
                        )
                }
            }
        }
    }

    private func prepareExport() {
        guard let item else {
            return
        }

        isWorking = true

        Task.detached(
            priority: .userInitiated
        ) {
            do {
                if item.summary.schemaVersion >= 2 {
                    _ = try PatchProjectLibrary
                        .synchronizeWorkspace(
                            item: item
                        )
                }

                await MainActor.run {
                    store.reload()
                    isWorking = false

                    shareRequest =
                        PatchShareRequest(
                            url: item.packageURL
                        )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey:
                                "common.failed",
                            messageKey:
                                error.localizationKey,
                            messageArgument:
                                error.localizationArgument
                        )
                }
            } catch {
                await MainActor.run {
                    isWorking = false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey:
                                "common.failed",
                            messageKey:
                                "patch.error.invalid_project"
                        )
                }
            }
        }
    }

    private func restore() {
        guard let receipt else {
            return
        }

        isWorking = true

        Task.detached(
            priority: .userInitiated
        ) {
            do {
                try DevicePatchService.restore(
                    receipt: receipt
                )

                await MainActor.run {
                    isWorking = false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey:
                                "common.done",
                            messageKey:
                                "patch.restored_message"
                        )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey:
                                "common.failed",
                            messageKey:
                                error.localizationKey,
                            messageArgument:
                                error.localizationArgument
                        )
                }
            } catch {
                await MainActor.run {
                    isWorking = false

                    actionAlert =
                        PatchStoreAlert(
                            titleKey:
                                "common.failed",
                            messageKey:
                                "patch.error.restore"
                        )
                }
            }
        }
    }
}

private struct PatchShareRequest: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PatchActivityView:
    UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController:
            UIActivityViewController,
        context: Context
    ) {}
}
