import SwiftUI
import UIKit

// NOTE — limite « 500 lignes par fichier » (règles Duello) : ce fichier la
// dépasse, le type `AnnCopyCorrectionSheet` occupant à lui seul 608 lignes.
// C'est un type unique dont tous les membres (dépôt des pages, suivi de la
// correction, compte rendu, aides de données, actions, sondage) partagent l'état
// `private` de la fenêtre (`pages`, `job`, `submitting`, `activePicker`…). Un
// découpage en extensions réparties sur d'autres fichiers exigerait d'élargir
// ces `private` en `internal`, c'est-à-dire de modifier des déclarations
// existantes — ce que ce découpage doit préserver (aucun type, propriété,
// méthode ni signature renommé). Le type reste donc entier ici : il tient dans
// la limite de 10 fonctions (9). En revanche `readyContent` fait 64 lignes : ce
// dépassement de la limite « 50 lignes par fonction » vient de l'original et
// n'est pas corrigé, le découpage devant rester transparent (aucun code réécrit).

// MARK: - Fenêtre de correction de copie

/// Fenêtre « Correction de copie » (`AnnaleCopyCorrectionModal.tsx`) : dépôt des
/// pages d'une partie, suivi de la correction en cours, compte rendu noté sur 20.
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

    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var partLabel = ""
    @State private var pages: [AnnCopyPage] = []
    @State private var submitting = false
    @State private var uploadProgress = 0
    @State private var errorMessage = ""
    @State private var activePicker: AnnPickerSheet?
    @State private var refreshTick = 0
    @State private var job: AnnCopyJob?

    /// Nombre de pages acceptées pour une partie (`slice(0, 24)` côté Expo).
    private static let maxPages = 24

    /// Clé d'une tentative : compte, annale et instant de l'ouverture.
    private let attemptKey: String

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

    // MARK: Dépôt d'une partie

    private var depositContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Parties déjà soumises")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    ForEach(history) { entry in
                        Button {
                            job = entry
                            onJobChange(entry)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.partLabel)
                                        .font(.system(size: 14, weight: .heavy))
                                        .foregroundStyle(Theme.ink)
                                    Text(entry.statusLabel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                Spacer(minLength: 8)
                                if entry.status == .ready, let result = entry.result {
                                    Text("\(result.scoreLabel)/20")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(Theme.ink)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ouvrir la correction \(entry.partLabel)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Partie à faire corriger")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                TextField("Ex. Exercice 1, partie II", text: $partLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Partie à faire corriger")
                Text("Tu pourras revenir un autre jour et soumettre une autre partie séparément.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            Text("Ajoute uniquement les pages de cette partie, dans l’ordre. Vérifie qu’elles sont nettes, cadrées et sans reflet.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)

            VStack(spacing: 10) {
                AnnOutlineButton(title: "Photographier une page", icon: "camera") {
                    requestCamera()
                }
                AnnOutlineButton(title: "Importer plusieurs photos", icon: "photo.on.rectangle") {
                    errorMessage = ""
                    activePicker = .library
                }
            }

            pageGrid

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Tu seras prévenu dans Duello, ou sur ton téléphone si l’application est fermée.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )

            submitButton
        }
    }

    private var pageGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            if let image = page.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Theme.surfaceMuted
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(Theme.inkFaint)
                                }
                            }
                        }
                        .frame(height: 145)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        Text("Page \(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(9)
                    }
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                    Button {
                        removePage(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.like)
                            .padding(7)
                            .background(Theme.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(7)
                    .accessibilityLabel("Supprimer la page \(index + 1)")
                }
            }
        }
    }

    private var submitButton: some View {
        let disabled = pages.isEmpty || partLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitting
        return Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 9) {
                if submitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.surface)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(submitLabel)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var submitLabel: String {
        if submitting { return "Envoi \(uploadProgress)%…" }
        let count = pages.count
        return "Lancer la correction (\(count) page\(count > 1 ? "s" : ""))"
    }

    // MARK: Correction en cours

    private func progressContent(job: AnnCopyJob) -> some View {
        VStack(spacing: 13) {
            if job.status == .failed {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.like)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.ink)
            }
            Text(job.statusLabel)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(job.partLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            if !job.estimateLabel.isEmpty {
                Text("Temps restant estimé : \(job.estimateLabel)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            DuelloProgressTrack(fraction: job.progressFraction, tint: Theme.ink, height: 8)
            Text(job.error ?? "Tu peux quitter cette page : la correction continue sur le serveur.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            if job.status == .failed {
                AnnSolidButton(title: "Relancer la correction", icon: "arrow.clockwise") {
                    Task { await retry(job: job) }
                }
            }
            AnnOutlineButton(title: "Voir ou soumettre une autre partie", icon: "square.stack") {
                onNewAttempt()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: Compte rendu

    private func readyContent(job: AnnCopyJob, result: AnnCopyResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(job.partLabel)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(result.scoreLabel)
                        .font(.system(size: 38, weight: .black))
                    Text(" / 20")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundStyle(Theme.surface)
                Text("Note de cette partie, ramenée sur 20")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.surface)
                    .opacity(0.82)
                Text(LatexToUnicode.toUnicodeMath(result.summary))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.surface)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))

            if !result.strengths.isEmpty {
                resultSection(title: "Points forts", icon: "checkmark.circle", items: result.strengths)
            }
            if !result.improvements.isEmpty {
                resultSection(title: "À retravailler", icon: "wrench.and.screwdriver", items: result.improvements)
            }

            ForEach(result.exerciseFeedback) { exercise in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(exercise.label)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Text(exercise.scoreLabel)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.ink)
                    }
                    Text(LatexToUnicode.toUnicodeMath(exercise.feedback))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .duelloCard()
            }

            AnnOutlineButton(title: "Soumettre une autre partie", icon: "arrow.clockwise") {
                onNewAttempt()
            }
        }
    }

    private func resultSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            ForEach(items, id: \.self) { item in
                Text(LatexToUnicode.toUnicodeMath("• \(item)"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .duelloCard()
    }

    // MARK: Aides de données

    /// Parties déjà soumises pour cette annale, la plus récente d'abord.
    private var history: [AnnCopyJob] {
        monitor.jobs(for: itemId).filter { $0.jobId != job?.jobId }
    }

    private func append(pages additions: [AnnCopyPage]) {
        guard !additions.isEmpty else { return }
        var next = pages
        next.append(contentsOf: additions)
        pages = Array(next.prefix(Self.maxPages))
    }

    private func removePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages.remove(at: index)
    }

    /// Ouvre l'appareil photo, ou la photothèque à défaut.
    ///
    /// `Info.plist` ne déclare pas encore `NSCameraUsageDescription` : sans
    /// cette clé, iOS interrompt l'application dès l'accès à l'appareil photo.
    /// Le bouton se replie donc sur la photothèque en affichant le message de
    /// permission de l'application Expo, plutôt que de rester sans effet.
    private func requestCamera() {
        errorMessage = ""
        let available = UIImagePickerController.isSourceTypeAvailable(.camera)
        let declared = (Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        if available && declared {
            activePicker = .camera
            return
        }
        errorMessage = "Autorise l’appareil photo pour photographier ta copie."
        activePicker = .library
    }

    // MARK: Actions

    private func submit() async {
        let trimmed = partLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if submitting || job != nil || pages.isEmpty { return }
        guard !trimmed.isEmpty else {
            errorMessage = "Indique la partie de l’annale couverte par ces pages."
            return
        }
        submitting = true
        errorMessage = ""
        uploadProgress = 0
        let snapshot = pages
        do {
            let created = try await AnnCopyService.submit(
                attemptKey: attemptKey,
                itemId: itemId,
                title: title,
                partLabel: trimmed,
                subject: subject,
                statement: statement,
                solution: solution,
                durationMinutes: durationMinutes,
                pages: snapshot,
                token: session.token,
                onProgress: { value in
                    Task { @MainActor in uploadProgress = value }
                }
            )
            job = created
            monitor.upsert(created)
            onJobChange(created)
        } catch let error as DirectoryError {
            let message = error.message.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = message.isEmpty ? "La copie n’a pas pu être envoyée." : message
        } catch {
            errorMessage = "La copie n’a pas pu être envoyée."
        }
        submitting = false
    }

    private func retry(job: AnnCopyJob) async {
        do {
            let refreshed = try await AnnCopyService.retry(job: job, token: session.token)
            self.job = refreshed
            monitor.upsert(refreshed)
            onJobChange(refreshed)
        } catch {
            errorMessage = "La correction n’a pas pu être relancée."
        }
    }

    // MARK: Suivi de la correction affichée

    /// Identifiant de suivi : la boucle de rafraîchissement repart dès que la
    /// fiche change (`useVisibleAnnaleCopyJob`).
    private var pollingKey: String {
        guard let job else { return "aucune" }
        return "\(job.jobId)-\(job.status.rawValue)-\(Int(job.updatedAt))"
    }

    /// Une seule lecture à la fois, uniquement tant que la copie est active ;
    /// une coupure réseau n'annule pas le travail du serveur, la boucle repart
    /// donc au tour suivant. Le retour au premier plan relance la boucle via
    /// l'identifiant de tâche, et la fermeture de la fenêtre l'interrompt.
    private func pollActiveJob() async {
        guard let current = job, current.isActive else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(AnnCopyService.visibleRefreshInterval * 1_000_000_000))
            if Task.isCancelled { return }
            guard let refreshed = try? await AnnCopyService.refresh(job: current, token: session.token) else {
                continue
            }
            job = refreshed
            monitor.upsert(refreshed)
            onJobChange(refreshed)
            if !refreshed.isActive { return }
        }
    }
}
