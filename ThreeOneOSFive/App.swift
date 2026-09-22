import SwiftUI
import UIKit

@main
struct ThreeOneOSFiveApp: App {
    private static let licenseRevalidationInterval: TimeInterval = 5 * 60

    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @State private var updateOffer: AppUpdateChecker.Offer?
    @State private var licenseRevalidationTimer: Timer?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        log("app: BYPASS7 PROXY launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(viewModel: authViewModel)
                .environmentObject(appState)
                .environmentObject(patchDraftCoordinator)
                .environmentObject(fileOperationCoordinator)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .fullScreenCover(item: $updateOffer) { offer in
                    MandatoryUpdateView(offer: offer, language: language)
                        .interactiveDismissDisabled()
                }
                .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
                    guard isAuthenticated else {
                        stopLicenseRevalidationTimer()
                        return
                    }
                    appState.detectSupport()
                    if scenePhase == .active {
                        startLicenseRevalidationTimer()
                    }
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active, authViewModel.isAuthenticated else {
                        stopLicenseRevalidationTimer()
                        return
                    }
                    appState.detectSupport()
                    authViewModel.revalidateInBackground()
                    startLicenseRevalidationTimer()
                }
                .onOpenURL { url in
                    patchDraftCoordinator.presentImport(url)
                }
                .onAppear {
                    checkForUpdate()
                }
        }
    }

    private func startLicenseRevalidationTimer() {
        guard authViewModel.isAuthenticated,
              licenseRevalidationTimer == nil else {
            return
        }

        let viewModel = authViewModel
        let timer = Timer(
            timeInterval: Self.licenseRevalidationInterval,
            repeats: true
        ) { [weak viewModel] _ in
            guard let viewModel, viewModel.isAuthenticated else { return }
            viewModel.revalidateInBackground()
        }
        RunLoop.main.add(timer, forMode: .common)
        licenseRevalidationTimer = timer
    }

    private func stopLicenseRevalidationTimer() {
        licenseRevalidationTimer?.invalidate()
        licenseRevalidationTimer = nil
    }
}

private struct MandatoryUpdateView: View {
    let offer: AppUpdateChecker.Offer
    let language: AppLanguage

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                VStack(spacing: 7) {
                    Text(language.text("update.title"))
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(language.text("update.message", offer.version))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    UIApplication.shared.open(offer.url)
                } label: {
                    Text(language.text("update.agree"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .padding(24)
        }
    }
}

struct MainTabView: View {
    @ObservedObject var viewModel: AuthenticationViewModel

    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                ContentView()
                    .transition(.opacity)
            } else {
                LoginView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAuthenticated)
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}
