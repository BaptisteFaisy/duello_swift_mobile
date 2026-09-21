import SwiftUI
import UIKit

// MARK: - Fenêtre de correction de copie

/// Fenêtre « Correction de copie » (`AnnaleCopyCorrectionModal.tsx`) : dépôt des
/// pages d'une partie, suivi de la correction en cours, compte rendu noté sur 20.
///
/// Découpage des règles de complexité Duello (500 lignes par fichier, 10
/// fonctions, 50 lignes par fonction). Ce fichier porte la déclaration du type —
/// son état, son `init`, son `body` et son en-tête ; les sous-vues sont réparties
/// par responsabilité dans des extensions :
///   • `AnnCopyCorrectionPageCollection` — collecte des pages ;
///   • `AnnCopyCorrectionDeposit` — dépôt d'une partie ;
///   • `AnnCopyCorrectionProgress` — suivi de la correction ;
///   • `AnnCopyCorrectionReport` — compte rendu.
/// Aucun type, propriété, méthode ni signature n'est renommé : seuls les membres
/// `private` relus depuis une autre extension passent `internal` (nom, type et
/// corps inchangés).
struct AnnCopyCorrectionSheet: View {
    let itemId: String
    let title: String
    let subject: String
    let statement: String
    let solution: String?
    let durationMinutes: Int?
    @ObservedObject var monitor: AnnCorrectionMonitor
    var initialJob: AnnCopyJob? = nil
    var onClose: () -> Void
    var onNewAttempt: () -> Void
    var onJobChange: (AnnCopyJob) -> Void

    @EnvironmentObject var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    @State var partLabel = ""
    @State var pages: [AnnCopyPage] = []
    @State var submitting = false
    @State var uploadProgress = 0
    @State var errorMessage = ""
    @State var activePicker: AnnPickerSheet?
    @State private var refreshTick = 0
    @State var job: AnnCopyJob?

    /// Nombre de pages acceptées pour une partie (`slice(0, 24)` côté Expo).
    static let maxPages = 24

    /// Clé d'une tentative : compte, annale et instant de l'ouverture.
    let attemptKey: String

    init(
        itemId: String,
        title: String,
        subject: String,
        statement: String,
        solution: String?,
        durationMinutes: Int?,
        monitor: AnnCorrectionMonitor,
        initialJob: AnnCopyJob? = nil,
        onClose: @escaping () -> Void,
        onNewAttempt: @escaping () -> Void,
        onJobChange: @escaping (AnnCopyJob) -> Void
    ) {
        self.itemId = itemId
        self.title = title
        self.subject = subject
        self.statement = statement
        self.solution = solution
        self.durationMinutes = durationMinutes
        self.monitor = monitor
        self.initialJob = initialJob
        self.onClose = onClose
        self.onNewAttempt = onNewAttempt
        self.onJobChange = onJobChange
        self.attemptKey = "\(itemId):\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.border)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    bodyContent
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.like)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .background(Theme.background)
        .onAppear {
            job = initialJob ?? monitor.jobs(for: itemId).first
        }
        .onChange(of: scenePhase) { phase in
            // Le retour au premier plan relit tout de suite la correction en
            // cours, sans attendre la fin de l'intervalle de rafraîchissement.
            if phase == .active { refreshTick += 1 }
        }
        .task(id: "\(pollingKey)-\(refreshTick)") {
            await pollActiveJob()
        }
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .camera:
                AnnCameraPicker { page in
                    activePicker = nil
                    append(pages: [page])
                }
                .ignoresSafeArea()
            case .library:
                AnnPhotoLibraryPicker(selectionLimit: max(1, Self.maxPages - pages.count)) { picked in
                    activePicker = nil
                    append(pages: picked)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: En-tête

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CORRECTION DE COPIE")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: Corps

    @ViewBuilder
    private var bodyContent: some View {
        if let job {
            if job.status == .ready, let result = job.result {
                readyContent(job: job, result: result)
            } else {
                progressContent(job: job)
            }
        } else {
            depositContent
        }
    }
}
